class_name ChainSystem
extends Node3D
## The Line: chain topology (line / ring / pairs), ledge wrapping, a verlet rope per segment
## rendered as interlocking steel links (simulated on every peer from replicated positions), and
## the pull that keeps chained bodies within reach (server only: it moves authoritative bodies).

const MAX_SEGMENT_LENGTH: float = 5.0  # meters of chain between two partners before it bites
const ROPE_POINTS: int = 12
const ROPE_ITERATIONS: int = 6
const ROPE_GRAVITY: float = 9.8
const ROPE_DAMPING: float = 0.985
const ROPE_SLACK: float = 0.92  # rest length factor so the rope sags when partners are close
const PULL_ITERATIONS: int = 2
const RESET_DISTANCE: float = 8.0  # an anchor jumping this far means a teleport: re-lay the rope
const HANG_DRAG_SPEED: float = 2.2  # m/s a dangling partner drags a standing one toward the drop
const BRACE_DRAG_FACTOR: float = 0.1  # bracing (Ctrl) cuts the drag to this fraction
const HANG_HEIGHT: float = 0.75  # m below the partner's cuff before a body counts as dangling
const HANG_SLACK: float = 0.3  # m of slack still counted as hanging (the dangler refills it by falling)
const EDGE_REACH: float = 0.3  # m from the ledge at which the drag switches to "over the edge"
const PIVOT_OFFSET: float = 0.05
const TELEPORT_DISTANCE: float = 3.0
const EDGE_SEARCH_STEP: float = 0.1
const EDGE_SEARCH_MAX: float = 3.0
const LINK_SPACING: float = 0.11  # m between link centers (links overlap so they interlock)
const MAX_LINKS_PER_SEGMENT: int = 60
const JERK_NOISE: float = 22.0


class Segment:
	var a: ChainBody
	var b: ChainBody
	var points: PackedVector3Array = PackedVector3Array()
	var prev: PackedVector3Array = PackedVector3Array()
	var has_pivot: bool = false
	var pivot: Vector3 = Vector3.ZERO
	# Horizontal unit vector out over the last ledge wrapped. Kept after unwrapping: once a holder
	# leans past the lip the line clears the ledge, but "out" is still the way they're going.
	var pivot_out: Vector3 = Vector3.ZERO
	var last_a: Vector3 = Vector3.ZERO
	var last_b: Vector3 = Vector3.ZERO
	var slack_time: float = 0.0  # seconds since this segment was last clearly slack (jerk detection)
	var rattle_time: float = 0.0

	func _init(pa: ChainBody, pb: ChainBody) -> void:
		a = pa
		b = pb

	func valid() -> bool:
		return is_instance_valid(a) and is_instance_valid(b) \
			and not a.is_queued_for_deletion() and not b.is_queued_for_deletion()

	func path_length() -> float:
		var pa := a.chain_anchor()
		var pb := b.chain_anchor()
		if has_pivot:
			return pa.distance_to(pivot) + pivot.distance_to(pb)
		return pa.distance_to(pb)


var segments: Array[Segment] = []
var jerks: int = 0  # server: how many times someone yanked the Line taut this run
var _mm: MultiMesh
var _topology_key: String = ""


func _ready() -> void:
	add_to_group("chain")
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	var link := TorusMesh.new()
	link.inner_radius = 0.026
	link.outer_radius = 0.046
	link.rings = 12
	link.ring_segments = 8
	_mm.mesh = link
	_mm.instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "ChainLinks"
	mmi.multimesh = _mm
	mmi.material_override = LevelKit.mat("chain")
	mmi.custom_aabb = AABB(Vector3(-500.0, -500.0, -500.0), Vector3(1000.0, 1000.0, 1000.0))
	add_child(mmi)


func _physics_process(delta: float) -> void:
	var bodies := Net.get_chain_bodies()
	_rebuild_topology(bodies)
	_update_wraps(bodies)
	if multiplayer.is_server():
		_apply_pulls(delta)
	_simulate_ropes(delta)
	_detect_jerks(delta)
	_render()


## 0 = slack, 1 = at full length: the tightest segment touching this body (for the HUD).
func tension_for(body: ChainBody) -> float:
	var t := 0.0
	for s in segments:
		if s.valid() and (s.a == body or s.b == body):
			t = maxf(t, s.path_length() / MAX_SEGMENT_LENGTH)
	return t


# --- Topology -----------------------------------------------------------------------

func _rebuild_topology(bodies: Array[ChainBody]) -> void:
	var key := "%d:" % GameState.chain_config
	for p in bodies:
		key += "%d," % p.join_index
	if key == _topology_key:
		return
	_topology_key = key
	var old: Dictionary = {}
	for s in segments:
		if s.valid():
			old["%d-%d" % [s.a.join_index, s.b.join_index]] = s
	segments.clear()
	for pair in _links_for(bodies):
		var a: ChainBody = pair[0]
		var b: ChainBody = pair[1]
		var k := "%d-%d" % [a.join_index, b.join_index]
		if old.has(k):
			segments.append(old[k])
		else:
			segments.append(Segment.new(a, b))
	_mm.instance_count = segments.size() * MAX_LINKS_PER_SEGMENT


## Which bodies are chained to which, by configuration. Bodies are in join order.
func _links_for(bodies: Array[ChainBody]) -> Array:
	var links: Array = []
	var n := bodies.size()
	var config: int = GameState.chain_config
	if config == GameState.ChainConfig.PAIRS:
		var i := 0
		while i + 1 < n:
			links.append([bodies[i], bodies[i + 1]])
			i += 2
		if n % 2 == 1 and n >= 3:
			links.append([bodies[n - 2], bodies[n - 1]])
		return links
	for i in range(n - 1):
		links.append([bodies[i], bodies[i + 1]])
	if config == GameState.ChainConfig.RING and n >= 3:
		links.append([bodies[n - 1], bodies[0]])
	return links


# --- Ledge wrapping (every peer) ----------------------------------------------------------

## When world geometry blocks the straight line between two partners, the chain bends at one
## pivot. Without this a body that falls off a thin floor swings underneath its partner through
## the floor, and nobody gets dragged toward the drop.
func _update_wraps(bodies: Array[ChainBody]) -> void:
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = []
	for p in bodies:
		exclude.append(p.get_rid())
	for s in segments:
		if not s.valid():
			continue
		var pa := s.a.chain_anchor()
		var pb := s.b.chain_anchor()
		if pa.distance_to(s.last_a) > TELEPORT_DISTANCE or pb.distance_to(s.last_b) > TELEPORT_DISTANCE:
			s.has_pivot = false
			s.pivot_out = Vector3.ZERO
			s.slack_time = 0.0
		s.last_a = pa
		s.last_b = pb
		var hi := pa if pa.y >= pb.y else pb
		var lo := pb if pa.y >= pb.y else pa
		var hit := _ray(space, hi, lo, exclude)
		if hit.is_empty():
			s.has_pivot = false
		elif not s.has_pivot:
			_wrap(s, space, hit, lo, exclude)


func _ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, exclude: Array[RID]) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, ChainBody.LAYER_WORLD)
	q.exclude = exclude
	return space.intersect_ray(q)


## Sets the segment's pivot from the first blocking hit. A hit on a floor-like surface is usually
## some way back from the edge, so slide toward the lower partner until the floor ends.
func _wrap(s: Segment, space: PhysicsDirectSpaceState3D, hit: Dictionary, lo: Vector3, exclude: Array[RID]) -> void:
	var p: Vector3 = hit["position"]
	var nrm: Vector3 = hit["normal"]
	s.has_pivot = true
	var flat := Vector3(nrm.x, 0.0, nrm.z)
	s.pivot_out = flat.normalized() if flat.length() > 0.05 else Vector3.ZERO
	s.pivot = p + nrm * PIVOT_OFFSET
	if nrm.y < 0.7:
		return
	var dir := Vector3(lo.x - p.x, 0.0, lo.z - p.z)
	if dir.length() < 0.05:
		return
	dir = dir.normalized()
	var edge := p
	var d := EDGE_SEARCH_STEP
	while d <= EDGE_SEARCH_MAX:
		var probe := p + dir * d
		var down := _ray(space, probe + Vector3(0.0, 0.3, 0.0), probe - Vector3(0.0, 0.3, 0.0), exclude)
		if down.is_empty():
			break
		edge = probe
		d += EDGE_SEARCH_STEP
	s.pivot_out = dir
	s.pivot = edge + dir * EDGE_SEARCH_STEP + Vector3(0.0, PIVOT_OFFSET, 0.0)


# --- Pull (server) --------------------------------------------------------------------

func _apply_pulls(delta: float) -> void:
	for s in segments:
		if s.valid():
			_apply_hang_drag(s, s.a, s.b, delta)
			_apply_hang_drag(s, s.b, s.a, delta)
	for _it in PULL_ITERATIONS:
		for s in segments:
			if not s.valid():
				continue
			var pa := s.a.chain_anchor()
			var pb := s.b.chain_anchor()
			var da: Vector3
			var db: Vector3
			var length: float
			if s.has_pivot:
				var to_pivot_a := s.pivot - pa
				var to_pivot_b := s.pivot - pb
				length = to_pivot_a.length() + to_pivot_b.length()
				da = to_pivot_a.normalized()
				db = to_pivot_b.normalized()
			else:
				var d := pb - pa
				length = d.length()
				if length < 0.001:
					continue
				da = d / length
				db = -da
			if length <= MAX_SEGMENT_LENGTH:
				continue
			var excess := length - MAX_SEGMENT_LENGTH
			var wa := s.a.chain_weight()
			var wb := s.b.chain_weight()
			var total := wa + wb
			if total <= 0.0:
				continue
			var share_a := wa / total
			var share_b := wb / total
			s.a.chain_move(da * excess * share_a)
			s.b.chain_move(db * excess * share_b)
			var growing := -s.a.velocity.dot(da) - s.b.velocity.dot(db)
			if growing > 0.0:
				s.a.velocity += da * growing * share_a
				s.b.velocity += db * growing * share_b
			s.a.synced_position = s.a.global_position
			s.b.synced_position = s.b.global_position


## A body hanging off a ledge drags a standing partner toward the drop unless they brace.
## Walking away (4 m/s) beats the drag, which is how you hoist someone back up.
func _apply_hang_drag(s: Segment, holder: ChainBody, hanger: ChainBody, delta: float) -> void:
	if not holder.is_on_floor() or hanger.is_on_floor() or holder.chain_weight() <= 0.0:
		return
	var ha := holder.chain_anchor()
	var hb := hanger.chain_anchor()
	if s.path_length() < MAX_SEGMENT_LENGTH - HANG_SLACK or hb.y > ha.y - HANG_HEIGHT:
		return
	var edge := s.pivot if s.has_pivot else hb
	var toward := Vector3(edge.x - ha.x, 0.0, edge.z - ha.z)
	if toward.length() < EDGE_REACH and s.pivot_out != Vector3.ZERO:
		toward = s.pivot_out
	if toward.length() < 0.05:
		return
	var speed := HANG_DRAG_SPEED * hanger.hang_mass() * (BRACE_DRAG_FACTOR if holder.is_bracing() else 1.0)
	holder.chain_move(toward.normalized() * speed * delta)
	holder.synced_position = holder.global_position


# --- Jerks and rattle (every peer for sound; server for noise) -----------------------------

func _detect_jerks(delta: float) -> void:
	for s in segments:
		if not s.valid() or s.points.size() != ROPE_POINTS:
			continue
		var len_now := s.path_length()
		var mid := s.points[ROPE_POINTS / 2]
		if len_now < MAX_SEGMENT_LENGTH - 0.7:
			s.slack_time = 0.0
		else:
			s.slack_time += delta
		# Snapped from slack to taut in under a quarter second: that's a Jerk.
		if len_now >= MAX_SEGMENT_LENGTH - 0.05 and s.slack_time > 0.0 and s.slack_time < 0.25:
			s.slack_time = 1.0  # one jerk per tightening
			Sfx.play_at(self, "clink", mid, -2.0, randf_range(0.8, 1.1))
			Sfx.play_at(self, "clink", mid, -6.0, randf_range(1.2, 1.4))
			if multiplayer.is_server():
				jerks += 1
				for body in [s.a, s.b]:
					if body is Player:
						(body as Player).add_noise(JERK_NOISE)
		# Idle rattle while the chain swings.
		s.rattle_time -= delta
		var speed := (s.points[ROPE_POINTS / 2] - s.prev[ROPE_POINTS / 2]).length() / maxf(delta, 0.0001)
		if speed > 2.5 and s.rattle_time <= 0.0:
			s.rattle_time = randf_range(0.15, 0.35)
			Sfx.play_at(self, "clink", mid, -16.0, randf_range(0.9, 1.5))


# --- Rope visual (every peer) -------------------------------------------------------------

func _simulate_ropes(delta: float) -> void:
	for s in segments:
		if not s.valid():
			continue
		var pa := s.a.chain_anchor()
		var pb := s.b.chain_anchor()
		if s.points.size() != ROPE_POINTS or pa.distance_to(s.points[0]) > RESET_DISTANCE \
				or pb.distance_to(s.points[ROPE_POINTS - 1]) > RESET_DISTANCE:
			_lay_rope(s, pa, pb)
		var pts: PackedVector3Array = s.points
		var prev: PackedVector3Array = s.prev
		var n := ROPE_POINTS
		var k := -1
		if s.has_pivot:
			var la := pa.distance_to(s.pivot)
			var lb := s.pivot.distance_to(pb)
			if la + lb > 0.001:
				k = clampi(roundi(float(n - 1) * la / (la + lb)), 1, n - 2)
		var rest := MAX_SEGMENT_LENGTH * ROPE_SLACK / float(n - 1)
		var gravity_step := Vector3(0.0, -ROPE_GRAVITY, 0.0) * delta * delta
		for i in range(1, n - 1):
			var p := pts[i]
			var v := (p - prev[i]) * ROPE_DAMPING
			prev[i] = p
			pts[i] = p + v + gravity_step
		pts[0] = pa
		pts[n - 1] = pb
		prev[0] = pa
		prev[n - 1] = pb
		if k >= 0:
			pts[k] = s.pivot
			prev[k] = s.pivot
		for _it in ROPE_ITERATIONS:
			for i in range(n - 1):
				var p0 := pts[i]
				var p1 := pts[i + 1]
				var d := p1 - p0
				var dist := d.length()
				if dist < 0.0001:
					continue
				var correction := d * ((dist - rest) / dist)
				var pinned0 := i == 0 or i == k
				var pinned1 := i + 1 == n - 1 or i + 1 == k
				if pinned0 and pinned1:
					continue
				elif pinned0:
					pts[i + 1] = p1 - correction
				elif pinned1:
					pts[i] = p0 + correction
				else:
					pts[i] = p0 + correction * 0.5
					pts[i + 1] = p1 - correction * 0.5
		s.points = pts
		s.prev = prev


func _lay_rope(s: Segment, pa: Vector3, pb: Vector3) -> void:
	var pts := PackedVector3Array()
	pts.resize(ROPE_POINTS)
	for i in ROPE_POINTS:
		pts[i] = pa.lerp(pb, float(i) / float(ROPE_POINTS - 1))
	s.points = pts
	s.prev = pts.duplicate()


## Walks each rope polyline at a fixed spacing and drops an oval link there, every other link
## rolled 90 degrees so they read as interlocking chain.
func _render() -> void:
	var idx := 0
	var stretch := Basis.from_scale(Vector3(1.0, 1.0, 1.65))
	for s in segments:
		var n := s.points.size()
		if not s.valid() or n < 2:
			continue
		var pts := s.points
		var placed := 0
		var next_at := LINK_SPACING * 0.5
		var walked := 0.0
		for i in range(n - 1):
			var p0 := pts[i]
			var p1 := pts[i + 1]
			var seg := p1 - p0
			var seg_len := seg.length()
			if seg_len < 0.0001:
				continue
			var dir := seg / seg_len
			var up := Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
			var basis := Basis.looking_at(dir, up)
			while next_at <= walked + seg_len and placed < MAX_LINKS_PER_SEGMENT:
				var pos := p0 + dir * (next_at - walked)
				var b := basis
				if placed % 2 == 1:
					b = basis.rotated(dir, PI * 0.5)
				_mm.set_instance_transform(idx, Transform3D(b * stretch, pos))
				idx += 1
				placed += 1
				next_at += LINK_SPACING
			walked += seg_len
	_mm.visible_instance_count = idx
