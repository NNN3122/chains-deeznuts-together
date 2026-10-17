class_name Horde
extends Node3D
## The swarm: a thousand mutated insects as arrays, not nodes. Every agent is a few floats
## (position, velocity, heading, gait phase, state, kind) stepped in one tight loop on a flow
## field (HordeField) toward the nearest chained player, with separation so they bunch, jostle
## and pile up at chokepoints. Rendering is one MultiMesh per kind whose vertex shader animates
## each body from four floats of custom data (HordeMesh).
## Kinds: Roaches (the ground swarm, they climb each other), Weavers (dog-sized spiders, faster,
## they hang on the chain), Flitters (bats that circle overhead and dive; walls mean nothing to
## them, and only a gun does).
## LOD: the nearest ACTIVE_COUNT agents are "active": full separation every tick, claws, lunges
## and dives, hands on the chain, shootable. The rest are the visual mass.
## Host-authoritative: the server decides grabs, hits and deaths. Clients run the same mass
## simulation from the same spawn seed and field, and get the active set corrected at 10 Hz
## plus a slow round-robin of everyone else, so a late joiner converges within seconds.
## The chain is the counter: three on one segment stop the team, a jerk (a partner sprinting
## away) or a sprint flings them off, and a lone player in the swarm is pulled down.

enum AState { WALK, GRAB, DEAD, GONE, FLINCH, LUNGE, SWING, CLIMB }

const MAX_AGENTS: int = 2400
const ACTIVE_COUNT: int = 250
const MASS_DIVISOR: int = 3  # the mass updates a third per tick
const ACTIVE_PICK_INTERVAL: float = 0.5
const FIELD_BUDGET: int = 1600  # cell visits per tick for the field build
const FIELD_INTERVAL: float = 0.3  # s between field rebuilds (plus however long a build takes)
const KIND_ROACH: int = 0
const KIND_WEAVER: int = 1
const KIND_FLITTER: int = 2
const SPEEDS: Array[float] = [3.3, 4.7, 7.5]  # m/s by kind: Roach, Weaver, Flitter (a walk is 4.2, a sprint 7)
const KIND_WEIGHTS: Array[float] = [0.8, 0.2, 0.0]  # the default mix (a level spawns rounds with its own)
const FLYING: Array[bool] = [false, false, true]  # Flitters ignore walls and the field's floor
const HIT_HEIGHTS: Array[float] = [0.75, 1.3, 1.1]  # m: the capsule a round has to cross, per kind
const CLIMB_MAXES: Array[float] = [2.6, 1.2, 0.0]  # m a pile lifts one, per kind: roaches climb roaches
const CLIMBER: Array[bool] = [true, true, false]  # roaches and Weavers climb walls and cross the gaps between roofs
const THREADED: Array[bool] = [false, true, false]  # Weavers cross on a thread; roaches leap it
const SWING_RANGES: Array[float] = [9.0, 11.0, 0.0]  # m each kind looks across a gap for the next roof
const LEAP_ARC: float = 1.6  # m a roach leaping a gap rises over the straight line
const LEAP_SPEED: float = 9.0  # m/s along a roach's leap
const CLIMB_SPEED: float = 3.4  # m/s up a wall face
const CLIMB_STEP: float = 0.7  # m onto the roof once over its edge
const SWING_RANGE: float = 11.0  # m a Weaver looks across a gap for the next roof
const SWING_SPEED: float = 7.5  # m/s along the swing
const SWING_SAG: float = 2.4  # m the swing dips below the straight line
const WEB_ANCHOR_H: float = 7.0  # m over the gap the thread hangs from
const FLY_HEIGHT: float = 4.0  # m over the nearest player's feet a Flitter circles
const DIVE_RANGE: float = 9.0  # m: inside this a Flitter folds its wings and comes down at you
const DIVE_SPEED: float = 11.0
const DIVE_TIME: float = 0.7
const DIVE_COOLDOWN: float = 2.8
const SEPARATION: float = 0.72  # m: closer than this and they push apart
const SEPARATION_PUSH: float = 2.4
const MAX_NEIGHBOURS: int = 8
const BUCKET: float = 1.6  # m, the spatial hash cell
const CLIMB_PER_NEIGHBOUR: float = 0.28  # m of pile height per body pressed around one
const CLAW_RANGE: float = 0.95  # m: the capsule overlap that counts as a hit on a player
const CLAW_COOLDOWN: float = 1.1
const CLAW_PUSH: float = 2.2  # m/s shove per claw
const MAUL_CONTACTS: int = 3  # this many on one player at once...
const MAUL_TIME: float = 2.5  # ...for this long, and they're pulled down (a layoff)
const GRAB_RANGE: float = 1.0  # m from the chain itself
const GRAB_MAX_PER_SEGMENT: int = 3
const DRAG_PER_HOLDER: float = 0.3  # of the held bodies' speed: one holder leaves a sprint at 4.9 m/s, three leave a crawl
const FLICK_SPEED: float = 4.6  # m/s of a chained body that flings its holders off (a sprint is 7)
const FLING_SPEED: float = 5.5
const FLINCH_TIME: float = 1.4
const STUN_TIME: float = 2.6
const LUNGE_RANGE: float = 3.2
const LUNGE_SPEED: float = 6.0
const LUNGE_TIME: float = 0.42
const LUNGE_COOLDOWN: float = 3.5
const DEAD_TIME: float = 14.0  # s a body lies there before it's gone
const SNAPSHOT_INTERVAL: float = 0.1
const SNAPSHOT_CHUNK: int = 64  # agents per packet
const MASS_CHUNK: int = 48  # of the mass per snapshot, round-robin
const STEER_RANGE: float = 7.0  # m: inside this an active agent walks straight at the player, no field
const GOAL_NOISE: float = 60.0  # a noise_source this loud (a decoy) is somewhere to walk to
const LEFT_BEHIND: float = 110.0  # m from every chained body: a walker this far back goes back into the walls

var field: HordeField
var base_y: float = 0.0  # the ground where the field says nothing else (the field carries roof heights per cell)
var count: int = 0
var spawn_seed: int = 0
var enabled: bool = true  # off, the crowd sleeps entirely (the level flips it when the Line arrives)
var debug_frozen: bool = false  # tests: nothing moves, nothing claws
var muted: bool = false  # every peer: no chitter (the roof's hush before a scare)
var closest_d2: float = 1.0e12  # m², flat: the nearest living agent to any chained body, as of the last active pick

# Agents.
var px: PackedFloat32Array = PackedFloat32Array()
var pz: PackedFloat32Array = PackedFloat32Array()
var py: PackedFloat32Array = PackedFloat32Array()
var vx: PackedFloat32Array = PackedFloat32Array()
var vz: PackedFloat32Array = PackedFloat32Array()
var yaw: PackedFloat32Array = PackedFloat32Array()
var phase: PackedFloat32Array = PackedFloat32Array()
var spd: PackedFloat32Array = PackedFloat32Array()  # m/s, per body
var scl: PackedFloat32Array = PackedFloat32Array()
var seed_f: PackedFloat32Array = PackedFloat32Array()
var tint: PackedFloat32Array = PackedFloat32Array()
var timer: PackedFloat32Array = PackedFloat32Array()  # state timer
var cool: PackedFloat32Array = PackedFloat32Array()  # claw / lunge cooldown
var gcool: PackedFloat32Array = PackedFloat32Array()  # hands-on-the-chain cooldown (after being flung off)
var climb: PackedFloat32Array = PackedFloat32Array()
var grab_t: PackedFloat32Array = PackedFloat32Array()
var state: PackedByteArray = PackedByteArray()
var kind: PackedByteArray = PackedByteArray()
var active: PackedByteArray = PackedByteArray()
var grab_a: PackedInt32Array = PackedInt32Array()  # join indices of the two bodies whose segment it holds
var grab_b: PackedInt32Array = PackedInt32Array()
var sw_x0: PackedFloat32Array = PackedFloat32Array()  # a swing or a climb: where it started...
var sw_z0: PackedFloat32Array = PackedFloat32Array()
var sw_y0: PackedFloat32Array = PackedFloat32Array()
var sw_x1: PackedFloat32Array = PackedFloat32Array()  # ...and where it lands (a climb: the roof edge it steps onto, y the roof)
var sw_z1: PackedFloat32Array = PackedFloat32Array()
var sw_y1: PackedFloat32Array = PackedFloat32Array()
var sw_dur: PackedFloat32Array = PackedFloat32Array()
var swings: int = 0  # stat: threads in the air right now
var climbs: int = 0

# Stats.
var sim_ms: float = 0.0  # smoothed cost of one physics tick (sim + render buffer)
var last_ms: float = 0.0
var alive: int = 0
var dead: int = 0
var active_count: int = 0
var grabs: int = 0  # how many are hanging on the chain right now
var mauls: int = 0  # players pulled down this run
var snapshots_received: int = 0  # client stat: packets from the host

var _tick: int = 0
var _pick_t: float = 0.0
var _field_t: float = 0.0
var _snap_t: float = 0.0
var _mass_cursor: int = 0
var _bucket_w: int = 0
var _bucket_h: int = 0
var _heads: PackedInt32Array = PackedInt32Array()
var _next: PackedInt32Array = PackedInt32Array()
var _d2: PackedFloat32Array = PackedFloat32Array()  # squared distance to the nearest chained body
var _near_x: PackedFloat32Array = PackedFloat32Array()  # the nearest player (flat) for active agents
var _near_z: PackedFloat32Array = PackedFloat32Array()
var _near_y: PackedFloat32Array = PackedFloat32Array()
var _sx: PackedFloat32Array = PackedFloat32Array()  # last separation push, reused on the ticks it isn't recomputed
var _sz: PackedFloat32Array = PackedFloat32Array()
var _crowd: PackedFloat32Array = PackedFloat32Array()
var _maul_t: Dictionary = {}  # peer -> seconds of being mobbed
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _mms: Array[MultiMesh] = []
var _bufs: Array[PackedFloat32Array] = []
var _slot: PackedInt32Array = PackedInt32Array()  # agent -> instance index within its kind
var _kind_counts: Array[int] = []
var _growl_t: float = 0.0
var _caption_t: float = 0.0
var _chain: ChainSystem
var _web: MeshInstance3D  # the threads of every swing in the air, redrawn each tick
var _web_mesh: ImmediateMesh
var _web_mat: StandardMaterial3D


func _ready() -> void:
	add_to_group("horde")
	_alloc(MAX_AGENTS)
	for k in HordeMesh.KINDS:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = HordeMesh.mesh_for(k)
		mm.instance_count = 0
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Horde_%s" % HordeMesh.KIND_NAMES[k]
		mmi.multimesh = mm
		mmi.material_override = HordeMesh.material_for(k)
		mmi.custom_aabb = AABB(Vector3(-600.0, -50.0, -600.0), Vector3(1200.0, 200.0, 1200.0))
		add_child(mmi)
		_mms.append(mm)
		_bufs.append(PackedFloat32Array())
		_kind_counts.append(0)
	_web_mesh = ImmediateMesh.new()
	_web = MeshInstance3D.new()
	_web.name = "Threads"
	_web.mesh = _web_mesh
	_web.custom_aabb = AABB(Vector3(-600.0, -50.0, -600.0), Vector3(1200.0, 200.0, 1200.0))
	_web_mat = StandardMaterial3D.new()
	_web_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_web_mat.albedo_color = Color(0.85, 0.85, 0.8, 0.7)
	_web_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_web_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	add_child(_web)
	_ensure_chain()


## The Chain node is built after the level, so the first look may find nothing.
func _ensure_chain() -> bool:
	if _chain != null and is_instance_valid(_chain):
		return true
	_chain = get_tree().get_first_node_in_group("chain") as ChainSystem
	if _chain == null:
		return false
	_chain.jerked.connect(_on_jerk)
	return true


func _alloc(n: int) -> void:
	px = _floats(n)
	pz = _floats(n)
	py = _floats(n)
	vx = _floats(n)
	vz = _floats(n)
	yaw = _floats(n)
	phase = _floats(n)
	spd = _floats(n)
	scl = _floats(n)
	seed_f = _floats(n)
	tint = _floats(n)
	timer = _floats(n)
	cool = _floats(n)
	gcool = _floats(n)
	climb = _floats(n)
	grab_t = _floats(n)
	_d2 = _floats(n)
	_near_x = _floats(n)
	_near_z = _floats(n)
	_near_y = _floats(n)
	_sx = _floats(n)
	_sz = _floats(n)
	_crowd = _floats(n)
	state = _bytes(n)
	kind = _bytes(n)
	active = _bytes(n)
	grab_a = _ints(n)
	grab_b = _ints(n)
	sw_x0 = _floats(n)
	sw_z0 = _floats(n)
	sw_y0 = _floats(n)
	sw_x1 = _floats(n)
	sw_z1 = _floats(n)
	sw_y1 = _floats(n)
	sw_dur = _floats(n)
	_next = _ints(n)
	_slot = _ints(n)


static func _floats(n: int) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(n)
	a.fill(0.0)
	return a


static func _bytes(n: int) -> PackedByteArray:
	var a := PackedByteArray()
	a.resize(n)
	a.fill(0)
	return a


static func _ints(n: int) -> PackedInt32Array:
	var a := PackedInt32Array()
	a.resize(n)
	a.fill(-1)
	return a


## Call on every peer with the same arguments: the level's seed makes the same swarm everywhere.
## weights: the kind mix for this round (Roach, Weaver, Flitter).
func spawn_group(n: int, area: Rect2, rng_seed: int, weights: Array[float] = KIND_WEIGHTS) -> void:
	spawn_seed = rng_seed
	_rng.seed = rng_seed
	n = mini(n, MAX_AGENTS - count)
	var total_w := 0.0
	for w in weights:
		total_w += w
	for i in n:
		var a := count
		count += 1
		var r := _rng.randf() * maxf(total_w, 0.0001)
		var k := 0
		var acc := 0.0
		for kk in HordeMesh.KINDS:
			acc += weights[kk] if kk < weights.size() else 0.0
			if r <= acc:
				k = kk
				break
		kind[a] = k
		var x := _rng.randf_range(area.position.x, area.end.x)
		var z := _rng.randf_range(area.position.y, area.end.y)
		var tries := 0
		while field != null and field.is_blocked(x, z) and tries < 20 and not FLYING[k]:
			x = _rng.randf_range(area.position.x, area.end.x)
			z = _rng.randf_range(area.position.y, area.end.y)
			tries += 1
		px[a] = x
		pz[a] = z
		py[a] = _ground(x, z) + (FLY_HEIGHT if FLYING[k] else 0.0)
		spd[a] = SPEEDS[k] * _rng.randf_range(0.8, 1.2)
		scl[a] = _rng.randf_range(0.86, 1.12)
		seed_f[a] = _rng.randf()
		tint[a] = _rng.randf()
		phase[a] = _rng.randf() * TAU
		yaw[a] = _rng.randf() * TAU
		state[a] = AState.WALK
		active[a] = 0
		cool[a] = _rng.randf_range(0.0, 2.0)
	_rebuild_render_slots()
	_rebuild_buckets()


func _rebuild_render_slots() -> void:
	for k in HordeMesh.KINDS:
		_kind_counts[k] = 0
	for i in count:
		var k := kind[i]
		_slot[i] = _kind_counts[k]
		_kind_counts[k] += 1
	for k in HordeMesh.KINDS:
		_mms[k].instance_count = _kind_counts[k]
		var b := PackedFloat32Array()
		b.resize(_kind_counts[k] * 16)
		b.fill(0.0)
		_bufs[k] = b


func _rebuild_buckets() -> void:
	if field == null:
		return
	_bucket_w = maxi(1, int(ceil(float(field.w) * field.cell / BUCKET)))
	_bucket_h = maxi(1, int(ceil(float(field.h) * field.cell / BUCKET)))
	_heads.resize(_bucket_w * _bucket_h)


func stats_text() -> String:
	return "SWARM %d  (%d active, %d dead, %d on the chain, %d on threads)   sim %.1f ms" % [alive, active_count, dead, grabs, swings, sim_ms]


func alive_of(k: int) -> int:
	var n := 0
	for i in count:
		if kind[i] == k and state[i] != AState.DEAD and state[i] != AState.GONE:
			n += 1
	return n


# --- The tick ------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if field == null or count == 0:
		return
	if not enabled:
		if _tick == 0:
			_fill_buffers()  # drawn standing where they spawned until the Line arrives
			_tick = 1
		return
	var t0 := Time.get_ticks_usec()
	_tick += 1
	_tick_field(delta)
	_pick_t -= delta
	if _pick_t <= 0.0:
		_pick_t = ACTIVE_PICK_INTERVAL
		_pick_active()
	if not debug_frozen:
		_hash_buckets()
		_simulate(delta)
		if multiplayer.is_server():
			_server_contacts(delta)
			_server_grabs(delta)
			_snap_t -= delta
			if _snap_t <= 0.0 and multiplayer.has_multiplayer_peer() and not multiplayer.get_peers().is_empty():
				_snap_t = SNAPSHOT_INTERVAL
				_send_snapshots()
	_fill_buffers()
	last_ms = float(Time.get_ticks_usec() - t0) * 0.001
	sim_ms = lerpf(sim_ms, last_ms, 0.08)


## Goals are the chained bodies and anything loud enough to be a decoy. The field rebuilds in
## slices; a fresh build starts a moment after the last one lands.
func _tick_field(delta: float) -> void:
	if field.is_building():
		field.step(_field_budget())
		return
	_field_t -= delta
	if _field_t > 0.0:
		return
	_field_t = FIELD_INTERVAL
	var goals := PackedVector2Array()
	for b in Net.get_chain_bodies():
		if b is Player and (b as Player).state == Player.State.GRABBED:
			continue  # someone already down isn't a draw; the rest of the Line is
		goals.append(Vector2(b.global_position.x, b.global_position.z))
	for n in get_tree().get_nodes_in_group("noise_source"):
		if n is Player or not (n is Node3D) or not n.has_method("noise_level"):
			continue
		if float(n.call("noise_level")) >= GOAL_NOISE:
			var p := (n as Node3D).global_position
			goals.append(Vector2(p.x, p.z))
	field.start_build(goals)
	field.step(_field_budget())


## A bigger field (a district of roofs) gets a bigger slice, so a build still lands in under a second.
func _field_budget() -> int:
	return maxi(FIELD_BUDGET, field.cell_count() / 14)


## The nearest ACTIVE_COUNT living agents to any chained body get the full simulation.
func _pick_active() -> void:
	var bodies := Net.get_chain_bodies()
	var bx := PackedFloat32Array()
	var bz := PackedFloat32Array()
	var by := PackedFloat32Array()
	for b in bodies:
		bx.append(b.global_position.x)
		bz.append(b.global_position.z)
		by.append(b.global_position.y)
	var nb := bx.size()
	var n := count
	var sorted := PackedFloat32Array()
	var living := 0
	for i in n:
		var s := state[i]
		if s == AState.DEAD or s == AState.GONE:
			_d2[i] = 1.0e12
			continue
		living += 1
		var best := 1.0e12
		var bk := -1
		var x := px[i]
		var z := pz[i]
		for k in nb:
			var dx := bx[k] - x
			var dz := bz[k] - z
			var d := dx * dx + dz * dz
			if d < best:
				best = d
				bk = k
		_d2[i] = best
		if best > LEFT_BEHIND * LEFT_BEHIND and nb > 0 and not FLYING[kind[i]] and s == AState.WALK:
			# Left behind on a roof the Line has crossed: it's gone back into the walls. The
			# server's snapshots carry the state to clients.
			if multiplayer.is_server():
				state[i] = AState.GONE
				_d2[i] = 1.0e12
				living -= 1
				continue
		if bk >= 0:
			_near_x[i] = bx[bk]
			_near_z[i] = bz[bk]
			_near_y[i] = by[bk]
		sorted.append(best)
	alive = living
	sorted.sort()
	closest_d2 = sorted[0] if sorted.size() > 0 else 1.0e12
	var threshold := 1.0e12
	if sorted.size() > 0:
		threshold = sorted[mini(ACTIVE_COUNT, sorted.size()) - 1]
	var picked := 0
	for i in n:
		var on := _d2[i] <= threshold and picked < ACTIVE_COUNT and state[i] != AState.DEAD and state[i] != AState.GONE
		if on:
			picked += 1
		active[i] = 1 if on else 0
	active_count = picked


func _hash_buckets() -> void:
	_heads.fill(-1)
	var ox := field.origin.x
	var oz := field.origin.y
	var bw := _bucket_w
	var bh := _bucket_h
	var inv := 1.0 / BUCKET
	for i in count:
		var s := state[i]
		if s == AState.GONE or s == AState.DEAD:
			_next[i] = -1
			continue
		var cx := clampi(int((px[i] - ox) * inv), 0, bw - 1)
		var cz := clampi(int((pz[i] - oz) * inv), 0, bh - 1)
		var b := cz * bw + cx
		_next[i] = _heads[b]
		_heads[b] = i


## One pass over the agents, every one of them every tick (anything less and the crowd steps
## at 20 Hz, which reads as lag). What is sliced is the expensive part: the mass recomputes its
## separation a third per tick and reuses the last push in between.
## Rooftops: every walker stands on the ground of its cell. A Weaver whose next cell is a wall
## of a higher roof climbs it; one whose next cell is the street looks across for the next roof
## and swings over on a thread; one with no field under it (the Line is on another roof) walks
## straight at the nearest player, and the edges sort out the rest.
func _simulate(delta: float) -> void:
	var n := count
	var fld := field
	var ox := fld.origin.x
	var oz := fld.origin.y
	var fw := fld.w
	var fh := fld.h
	var cell := fld.cell
	var inv_cell := 1.0 / cell
	var dirx := fld.dir_x
	var dirz := fld.dir_z
	var blocked := fld.blocked
	var terrain := fld.terrain
	var heights := fld.height
	var costs := fld.cost
	var bw := _bucket_w
	var bh := _bucket_h
	var inv_b := 1.0 / BUCKET
	var sep2 := SEPARATION * SEPARATION
	var slice := _tick % MASS_DIVISOR
	var bodies := Net.get_chain_bodies()
	var nbodies := bodies.size()
	var bxs := PackedFloat32Array()
	var bzs := PackedFloat32Array()
	for b in bodies:
		bxs.append(b.global_position.x)
		bzs.append(b.global_position.z)
	var me := Net.get_local_player()
	var mex := me.global_position.x if me != null else 1.0e9
	var mez := me.global_position.z if me != null else 1.0e9
	var grab_count := 0
	var swing_count := 0
	var climb_count := 0
	for i in n:
		var s := state[i]
		if s == AState.GONE:
			continue
		var is_active := active[i] != 0
		var dt := delta
		var do_sep := is_active or (i + slice) % MASS_DIVISOR == 0
		if s == AState.DEAD:
			timer[i] += dt
			if timer[i] >= DEAD_TIME:
				state[i] = AState.GONE
			continue
		if s == AState.GRAB:
			grab_count += 1
			phase[i] += dt * 2.0
			continue  # placed by _server_grabs / the snapshot
		if s == AState.SWING:
			# Along the thread: eased, dipping below the line, legs out, facing the landing.
			swing_count += 1
			timer[i] -= dt
			var dur := maxf(sw_dur[i], 0.05)
			var u := clampf(1.0 - timer[i] / dur, 0.0, 1.0)
			var ue := u * u * (3.0 - 2.0 * u)
			px[i] = lerpf(sw_x0[i], sw_x1[i], ue)
			pz[i] = lerpf(sw_z0[i], sw_z1[i], ue)
			if THREADED[kind[i]]:
				py[i] = lerpf(sw_y0[i], sw_y1[i], ue) - SWING_SAG * sin(u * PI) * minf(1.0, dur / 1.2)
			else:
				py[i] = lerpf(sw_y0[i], sw_y1[i], ue) + LEAP_ARC * sin(u * PI)  # a roach leaps it
			phase[i] += dt * 1.5
			var hx := sw_x1[i] - sw_x0[i]
			var hz := sw_z1[i] - sw_z0[i]
			if hx * hx + hz * hz > 0.01:
				yaw[i] = atan2(-hx, -hz)
			if timer[i] <= 0.0:
				state[i] = AState.WALK
				px[i] = sw_x1[i]
				pz[i] = sw_z1[i]
				py[i] = sw_y1[i]
				climb[i] = 0.0
				cool[i] = maxf(cool[i], 0.4)
			continue
		if s == AState.CLIMB:
			# Straight up the face, legs working, then a step onto the roof.
			climb_count += 1
			py[i] += CLIMB_SPEED * dt
			phase[i] += CLIMB_SPEED * dt * 3.2
			if py[i] >= sw_y1[i] - 0.02:
				py[i] = sw_y1[i]
				px[i] = sw_x1[i]
				pz[i] = sw_z1[i]
				state[i] = AState.WALK
				climb[i] = 0.0
			continue
		cool[i] = maxf(0.0, cool[i] - dt)
		gcool[i] = maxf(0.0, gcool[i] - dt)
		var x := px[i]
		var z := pz[i]
		var wx := 0.0
		var wz := 0.0
		var speed := spd[i]
		var k := kind[i]
		var flies := FLYING[k]
		var climber := CLIMBER[k]
		var cx0 := clampi(int((x - ox) * inv_cell), 0, fw - 1)
		var cz0 := clampi(int((z - oz) * inv_cell), 0, fh - 1)
		var ci0 := cz0 * fw + cx0
		if s == AState.FLINCH:
			timer[i] -= dt
			if timer[i] <= 0.0:
				state[i] = AState.WALK
			wx = vx[i] * 0.9
			wz = vz[i] * 0.9
			speed = 0.0
		elif s == AState.LUNGE:
			timer[i] -= dt
			if timer[i] <= 0.0:
				state[i] = AState.WALK
				cool[i] = LUNGE_COOLDOWN
			wx = vx[i]
			wz = vz[i]
			speed = 0.0
		else:
			# Where to: straight at the nearest player when close (and active), else the field.
			var steered := false
			if is_active and _d2[i] < STEER_RANGE * STEER_RANGE and _d2[i] > 0.01:
				var tx := _near_x[i] - x
				var tz := _near_z[i] - z
				var l := sqrt(tx * tx + tz * tz)
				if l > 0.6:
					wx = tx / l
					wz = tz / l
					steered = true
					if flies and _d2[i] < 16.0:
						# A Flitter close in circles rather than parks over your head.
						var ox2 := wx
						wx = -wz * 0.85 + ox2 * 0.3
						wz = ox2 * 0.85 + wz * 0.3
			if not steered:
				wx = dirx[ci0]
				wz = dirz[ci0]
				if costs[ci0] >= HordeField.UNREACHED and not flies:
					# No field here: the Line is on another roof. A climber heads straight for
					# them (the edge is where it swings); a roach mills about where it is.
					var tx := _near_x[i] - x
					var tz := _near_z[i] - z
					var l := sqrt(tx * tx + tz * tz)
					if climber and l > 0.6:
						wx = tx / l
						wz = tz / l
					else:
						var a := phase[i] * 0.05 + seed_f[i] * 20.0
						wx = sin(a) * 0.3
						wz = cos(a) * 0.3
			# A wobble so a column never marches in step.
			var wob := sin(phase[i] * 0.37 + seed_f[i] * 20.0) * 0.25
			var nx := wx - wz * wob
			var nz := wz + wx * wob
			wx = nx
			wz = nz
		# Separation: push off everyone pressed against this one; count the crush for climbing.
		var sx := _sx[i]
		var sz := _sz[i]
		var crowd := int(_crowd[i])
		if do_sep:
			sx = 0.0
			sz = 0.0
			crowd = 0
			var bcx := clampi(int((x - ox) * inv_b), 0, bw - 1)
			var bcz := clampi(int((z - oz) * inv_b), 0, bh - 1)
			var seen := 0
			for dz in range(-1, 2):
				var zz := bcz + dz
				if zz < 0 or zz >= bh:
					continue
				for dx in range(-1, 2):
					var xx := bcx + dx
					if xx < 0 or xx >= bw:
						continue
					var j := _heads[zz * bw + xx]
					while j >= 0 and seen < MAX_NEIGHBOURS:
						if j != i:
							var ddx := x - px[j]
							var ddz := z - pz[j]
							var d2 := ddx * ddx + ddz * ddz
							if d2 < sep2 and absf(py[j] - py[i]) < 2.5:
								seen += 1
								crowd += 1
								var d := sqrt(d2)
								if d < 0.001:
									ddx = sin(seed_f[i] * 50.0)
									ddz = cos(seed_f[i] * 50.0)
									d = 1.0
								var kk := (SEPARATION - d) / d
								sx += ddx * kk
								sz += ddz * kk
						j = _next[j]
			if is_active:
				for b in nbodies:
					var ddx := x - bxs[b]
					var ddz := z - bzs[b]
					var d2 := ddx * ddx + ddz * ddz
					if d2 < 0.5 and d2 > 0.0001:
						var d := sqrt(d2)
						var kk := (0.7 - d) / d
						sx += ddx * kk * 1.5
						sz += ddz * kk * 1.5
			_sx[i] = sx
			_sz[i] = sz
			_crowd[i] = float(crowd)
		var vxx := wx * speed + sx * SEPARATION_PUSH
		var vzz := wz * speed + sz * SEPARATION_PUSH
		if s == AState.LUNGE or s == AState.FLINCH:
			vxx = wx + sx * SEPARATION_PUSH * 0.3
			vzz = wz + sz * SEPARATION_PUSH * 0.3
		vx[i] = vxx
		vz[i] = vzz
		var nxp := x + vxx * dt
		var nzp := z + vzz * dt
		# Walls: slide along them rather than stop. A Flitter goes over everything, but not out
		# of the field. A Weaver at the edge of its roof swings or climbs instead.
		var cxn := int((nxp - ox) * inv_cell)
		var czn := int((nzp - oz) * inv_cell)
		var inside := cxn >= 0 and czn >= 0 and cxn < fw and czn < fh
		if flies:
			if not inside:
				nxp = x
				nzp = z
		elif climber and inside and s == AState.WALK and (cxn != cx0 or czn != cz0):
			var cin := czn * fw + cxn
			var tnext := terrain[cin]
			var hl := sqrt(vxx * vxx + vzz * vzz)
			if tnext == HordeField.VOID and hl > 0.1:
				var land := fld.floor_ahead(x, z, vxx / hl, vzz / hl, SWING_RANGES[k])
				if land.is_empty() and _d2[i] < 1.0e11:
					# Not that way: straight at whoever is nearest, then.
					var tx := _near_x[i] - x
					var tz := _near_z[i] - z
					var tl := sqrt(tx * tx + tz * tz)
					if tl > 0.5:
						land = fld.floor_ahead(x, z, tx / tl, tz / tl, SWING_RANGES[k])
				if land.size() == 3:
					_start_swing(i, land[0], land[2], land[1])
					if is_active and (x - mex) * (x - mex) + (z - mez) * (z - mez) < 900.0:
						Sfx.play_at(self, "click", Vector3(x, py[i] + 0.5, z), -8.0, 0.55, 30.0)
					continue
				nxp = x
				nzp = z
			elif tnext == HordeField.FLOOR and heights[cin] - py[i] > 0.6 and heights[cin] - py[i] < 40.0 and hl > 0.1:
				# A higher roof butts against this one: up the face.
				state[i] = AState.CLIMB
				sw_x0[i] = x
				sw_z0[i] = z
				sw_y0[i] = py[i]
				sw_x1[i] = x + vxx / hl * CLIMB_STEP
				sw_z1[i] = z + vzz / hl * CLIMB_STEP
				sw_y1[i] = heights[cin]
				yaw[i] = atan2(-vxx, -vzz)
				continue
			elif blocked[cin] != 0:
				nxp = x
				nzp = z
		elif not inside or blocked[czn * fw + cxn] != 0 or (heights[czn * fw + cxn] - py[i] > 0.6 and (cxn != cx0 or czn != cz0)):  # a wall, or a step up no roach can take
			var cx2 := int((nxp - ox) * inv_cell)
			var cz2 := int((z - oz) * inv_cell)
			if cx2 >= 0 and cz2 >= 0 and cx2 < fw and cz2 < fh and blocked[cz2 * fw + cx2] == 0:
				nzp = z
			else:
				cx2 = int((x - ox) * inv_cell)
				cz2 = int((nzp - oz) * inv_cell)
				if cx2 >= 0 and cz2 >= 0 and cx2 < fw and cz2 < fh and blocked[cz2 * fw + cx2] == 0:
					nxp = x
				else:
					nxp = x
					nzp = z
		px[i] = nxp
		pz[i] = nzp
		var moved := sqrt((nxp - x) * (nxp - x) + (nzp - z) * (nzp - z))
		# The walk cycle follows the ground covered (no skating); one pressed against a wall or
		# a crowd still works its legs at most of its meant pace, so a pile never freezes.
		var meant := sqrt(vxx * vxx + vzz * vzz) * dt
		phase[i] += maxf(moved, meant * 0.7) * 3.2 + dt * 0.3
		# Face where it's going, turning at a rate: no snapping.
		var hx := vxx
		var hz := vzz
		if hx * hx + hz * hz > 0.01:
			var want := atan2(-hx, -hz)
			yaw[i] += clampf(wrapf(want - yaw[i], -PI, PI), -5.0 * dt, 5.0 * dt)
		if flies:
			# Flitters circle a few metres over whoever is nearest and fold their wings to dive;
			# the dive ends at head height, then they climb away again.
			var floor_y := _near_y[i] if _d2[i] < 1.0e11 else heights[ci0]
			var want_y := floor_y + FLY_HEIGHT + 0.8 * sin(phase[i] * 0.35 + seed_f[i] * 9.0)
			if s == AState.LUNGE:
				want_y = _near_y[i] + 1.0
			py[i] = lerpf(py[i], want_y, minf(1.0, (6.0 if s == AState.LUNGE else 1.6) * dt))
			if is_active and s == AState.WALK and cool[i] <= 0.0 and _d2[i] < DIVE_RANGE * DIVE_RANGE:
				if fmod(seed_f[i] * 97.0 + float(_tick) * 0.01, 1.0) < 0.3:
					var tx := _near_x[i] - x
					var tz := _near_z[i] - z
					var l := sqrt(tx * tx + tz * tz)
					if l > 0.1:
						state[i] = AState.LUNGE
						timer[i] = DIVE_TIME
						vx[i] = tx / l * DIVE_SPEED
						vz[i] = tz / l * DIVE_SPEED
				cool[i] = 0.5
			continue
		# The crush lifts them: a pile of roaches climbs itself. The ground is the cell's: a
		# small step up is taken at once, a drop is a fall.
		var want_climb := minf(CLIMB_MAXES[k], maxf(0.0, float(crowd - 3)) * CLIMB_PER_NEIGHBOUR)
		climb[i] = lerpf(climb[i], want_climb, minf(1.0, 2.0 * dt))
		var cxa := clampi(int((nxp - ox) * inv_cell), 0, fw - 1)
		var cza := clampi(int((nzp - oz) * inv_cell), 0, fh - 1)
		var gy := heights[cza * fw + cxa] + climb[i]
		if py[i] > gy + 0.3:
			py[i] = maxf(gy, py[i] - 9.0 * dt)
		else:
			py[i] = gy
		# Active and close: the odd lunge, from a couple of metres out. Any closer and it's hands
		# on the chain or claws instead.
		if is_active and s == AState.WALK and cool[i] <= 0.0 and _d2[i] < LUNGE_RANGE * LUNGE_RANGE and _d2[i] > 4.0:
			if fmod(seed_f[i] * 97.0 + float(_tick) * 0.01, 1.0) < 0.35:
				var tx := _near_x[i] - x
				var tz := _near_z[i] - z
				var l := sqrt(tx * tx + tz * tz)
				if l > 0.1:
					state[i] = AState.LUNGE
					timer[i] = LUNGE_TIME
					vx[i] = tx / l * LUNGE_SPEED
					vz[i] = tz / l * LUNGE_SPEED
			cool[i] = 0.6
	grabs = grab_count
	swings = swing_count
	climbs = climb_count


## A thread across the gap: from where it stands to a point on the next roof.
func _start_swing(i: int, tx: float, ty: float, tz: float) -> void:
	state[i] = AState.SWING
	sw_x0[i] = px[i]
	sw_z0[i] = pz[i]
	sw_y0[i] = py[i]
	sw_x1[i] = tx
	sw_z1[i] = tz
	sw_y1[i] = ty
	var d := sqrt((tx - px[i]) * (tx - px[i]) + (tz - pz[i]) * (tz - pz[i]) + (ty - py[i]) * (ty - py[i]))
	sw_dur[i] = clampf(d / (SWING_SPEED if THREADED[kind[i]] else LEAP_SPEED), 0.35, 2.2)
	timer[i] = sw_dur[i]
	climb[i] = 0.0
	grab_a[i] = -1
	grab_b[i] = -1


## The ground under a world position: the field's cell height, or the flat base.
func _ground(x: float, z: float) -> float:
	if field == null:
		return base_y
	return field.height_at(x, z)


## Where a swing's thread hangs from: over the middle of the gap, high.
func swing_anchor(i: int) -> Vector3:
	return Vector3((sw_x0[i] + sw_x1[i]) * 0.5, maxf(sw_y0[i], sw_y1[i]) + WEB_ANCHOR_H, (sw_z0[i] + sw_z1[i]) * 0.5)


# --- Server: claws, mauling, the chain ----------------------------------------------------------

## Capsule overlap against the players, no physics: a shove per claw, and a crowd that keeps
## three sets of hands on someone for a few seconds pulls them down.
func _server_contacts(delta: float) -> void:
	var players := Net.get_players()
	var r2 := CLAW_RANGE * CLAW_RANGE
	var fx := Effects.find(self)
	for p in players:
		var ppos := p.global_position
		var contacts := 0
		var push := Vector3.ZERO
		var claw := Vector3.ZERO
		var clawed := false
		for i in count:
			if active[i] == 0:
				continue
			var s := state[i]
			if s != AState.WALK and s != AState.LUNGE:
				continue
			var dx := px[i] - ppos.x
			var dz := pz[i] - ppos.z
			var d2 := dx * dx + dz * dz
			if d2 > r2 or absf(py[i] - ppos.y) > 1.6:
				continue
			contacts += 1
			var d := sqrt(d2)
			var away := Vector3(-dx, 0.0, -dz) / maxf(d, 0.05)
			push += away
			if cool[i] <= 0.0 and s == AState.WALK:
				cool[i] = CLAW_COOLDOWN
				clawed = true
				claw += away * CLAW_PUSH
				if fx != null and _rng.randf() < 0.5:
					fx.fx_sound.rpc("growl", Vector3(px[i], py[i] + 1.2, pz[i]), -8.0, _rng.randf_range(1.2, 1.8))
			elif s == AState.LUNGE and p.state == Player.State.NORMAL:
				state[i] = AState.WALK
				cool[i] = LUNGE_COOLDOWN
				p.apply_knockback(away * 4.0 + Vector3.UP * 1.5)
				p.add_noise(20.0)
				p.model.pop_hat(away * 2.0 + Vector3.UP * 4.0)
		if p.state == Player.State.NORMAL and contacts > 0:
			if clawed:
				p.add_noise(10.0)
			if contacts < MAUL_CONTACTS:
				# Flesh is a wall: at the edge of the crowd the claws and the press shove you back
				# out. Three sets of hands and nobody shoves: they hold, and the timer runs.
				var shove := claw + (push.normalized() * 0.5 * minf(1.0, push.length()) if push.length() > 0.5 else Vector3.ZERO)
				if clawed:
					shove += Vector3.UP * 0.6
				p.apply_knockback(shove)
		var t := float(_maul_t.get(p.peer_id, 0.0))
		if contacts >= MAUL_CONTACTS and p.state == Player.State.NORMAL:
			if t <= 0.0:
				GameState.post_message("THEY'RE ON %s. Pull them out: sprint, shoot, or bomb the crowd." % p.display_name.to_upper(), 3.0)
			t += delta
			if t >= MAUL_TIME:
				t = -3.0  # grace after the layoff
				mauls += 1
				var level := get_tree().get_first_node_in_group("level")
				if level != null and level.has_method("request_layoff"):
					level.call("request_layoff", "%s was pulled down by the crowd." % p.display_name)
		elif t < 0.0:
			t = minf(0.0, t + delta)  # the grace after a layoff runs out
		else:
			t = maxf(0.0, t - delta)
		_maul_t[p.peer_id] = t


## Hands on the chain itself: an active agent within reach of a segment hangs on. Each holder
## takes a third of both ends' speed; three stop them. A sprint, a slide or a jerk flings them off.
func _server_grabs(_delta: float) -> void:
	if not _ensure_chain():
		return
	var segs := _chain.segments
	var nseg := segs.size()
	if nseg == 0:
		return
	var ax := PackedFloat32Array()
	var az := PackedFloat32Array()
	var ay := PackedFloat32Array()
	var bx := PackedFloat32Array()
	var bz := PackedFloat32Array()
	var by := PackedFloat32Array()
	var ja := PackedInt32Array()
	var jb := PackedInt32Array()
	var holders := PackedInt32Array()
	holders.resize(nseg)
	holders.fill(0)
	for s in segs:
		var pa := s.a.chain_anchor() if s.valid() else Vector3.ZERO
		var pb := s.b.chain_anchor() if s.valid() else Vector3.ZERO
		ax.append(pa.x)
		ay.append(pa.y)
		az.append(pa.z)
		bx.append(pb.x)
		by.append(pb.y)
		bz.append(pb.z)
		ja.append(s.a.join_index if s.valid() else -1)
		jb.append(s.b.join_index if s.valid() else -1)
	# Holders first: find their segment again (topology may have changed), place them, count them.
	for i in count:
		if state[i] != AState.GRAB:
			continue
		var si := -1
		for k in nseg:
			if ja[k] == grab_a[i] and jb[k] == grab_b[i]:
				si = k
				break
		if si < 0 or not segs[si].valid():
			_release(i, Vector2(sin(seed_f[i] * 40.0), cos(seed_f[i] * 40.0)), FLING_SPEED * 0.5)
			continue
		var seg: ChainSystem.Segment = segs[si]
		# A sprint, or a slide (your whole weight thrown down the chain), flings them off.
		var fast := _flat_speed(seg.a) > FLICK_SPEED or _flat_speed(seg.b) > FLICK_SPEED
		for body in [seg.a, seg.b]:
			if body is Player and (body as Player).is_sliding():
				fast = true
		if fast:
			var va := Vector3(seg.a.velocity.x, 0.0, seg.a.velocity.z) + Vector3(seg.b.velocity.x, 0.0, seg.b.velocity.z)
			var dir := Vector2(va.x, va.z)
			if dir.length() < 0.1:
				dir = Vector2(sin(seed_f[i] * 40.0), cos(seed_f[i] * 40.0))
			_release(i, dir.normalized() * -1.0, FLING_SPEED)
			continue
		holders[si] += 1
		var t := grab_t[i]
		px[i] = lerpf(ax[si], bx[si], t) + sin(seed_f[i] * 30.0) * 0.35
		pz[i] = lerpf(az[si], bz[si], t) + cos(seed_f[i] * 30.0) * 0.35
		py[i] = maxf(_ground(px[i], pz[i]), lerpf(ay[si], by[si], t) - 0.95)
		var to_a := Vector2(ax[si] - px[i], az[si] - pz[i])
		if to_a.length() > 0.05:
			yaw[i] = atan2(-to_a.x, -to_a.y)
	# The drag on both ends: three hands and you can only inch.
	for k in nseg:
		if holders[k] <= 0 or not segs[k].valid():
			continue
		var drag := minf(1.0, float(holders[k]) * DRAG_PER_HOLDER)
		for body in [segs[k].a, segs[k].b]:
			if body is Player:
				var p := body as Player
				p.hold_drag = maxf(p.hold_drag, drag)
			else:
				body.velocity.x *= 1.0 - drag
				body.velocity.z *= 1.0 - drag
	# New grabs: active walkers within reach of a segment that still has room. One already at a
	# player's feet claws instead (a fresh distance: the active pick's is up to half a second old).
	var players := Net.get_players()
	var plx := PackedFloat32Array()
	var plz := PackedFloat32Array()
	for p in players:
		plx.append(p.global_position.x)
		plz.append(p.global_position.z)
	var claw2 := CLAW_RANGE * CLAW_RANGE
	for i in count:
		if active[i] == 0 or state[i] != AState.WALK or gcool[i] > 0.0 or _d2[i] > 36.0 or FLYING[kind[i]]:
			continue
		var x := px[i]
		var z := pz[i]
		var at_feet := false
		for pi in plx.size():
			var pdx := plx[pi] - x
			var pdz := plz[pi] - z
			if pdx * pdx + pdz * pdz < claw2:
				at_feet = true
				break
		if at_feet:
			continue
		for k in nseg:
			if holders[k] >= GRAB_MAX_PER_SEGMENT or not segs[k].valid():
				continue
			var ex := bx[k] - ax[k]
			var ez := bz[k] - az[k]
			var l2 := ex * ex + ez * ez
			if l2 < 0.25:
				continue
			var t := clampf(((x - ax[k]) * ex + (z - az[k]) * ez) / l2, 0.08, 0.92)
			var cx := ax[k] + ex * t
			var cz := az[k] + ez * t
			var dx := x - cx
			var dz := z - cz
			if dx * dx + dz * dz > GRAB_RANGE * GRAB_RANGE:
				continue
			if absf(lerpf(ay[k], by[k], t) - py[i]) > 1.7:
				continue
			state[i] = AState.GRAB
			grab_t[i] = t
			grab_a[i] = ja[k]
			grab_b[i] = jb[k]
			holders[k] += 1
			if holders[k] == 1 or holders[k] == GRAB_MAX_PER_SEGMENT:
				var fx := Effects.find(self)
				if fx != null:
					fx.fx_sound.rpc("clink", Vector3(cx, lerpf(ay[k], by[k], t), cz), -2.0, 0.7)
				if holders[k] == GRAB_MAX_PER_SEGMENT:
					GameState.post_message("THREE ON THE CHAIN, chewing. You're stuck: someone SPRINT to jerk it, shoot them, bomb them, or the horn.", 3.5)
			break


func _flat_speed(b: ChainBody) -> float:
	return Vector2(b.velocity.x, b.velocity.z).length()


func _release(i: int, dir: Vector2, speed: float) -> void:
	state[i] = AState.FLINCH
	timer[i] = FLINCH_TIME
	cool[i] = 2.5
	gcool[i] = 2.5
	vx[i] = dir.x * speed
	vz[i] = dir.y * speed
	grab_a[i] = -1
	grab_b[i] = -1


## The chain snapped taut on this segment: everyone hanging on it is thrown off.
func _on_jerk(seg: ChainSystem.Segment) -> void:
	if not multiplayer.is_server() or not seg.valid():
		return
	var n := 0
	for i in count:
		if state[i] == AState.GRAB and grab_a[i] == seg.a.join_index and grab_b[i] == seg.b.join_index:
			var mid := (seg.a.chain_anchor() + seg.b.chain_anchor()) * 0.5
			var away := Vector2(px[i] - mid.x, pz[i] - mid.z)
			if away.length() < 0.1:
				away = Vector2(sin(seed_f[i] * 40.0), cos(seed_f[i] * 40.0))
			_release(i, away.normalized(), FLING_SPEED * 1.3)
			n += 1
	if n > 0:
		GameState.post_message("The jerk threw %d of them off the chain." % n, 2.5)


# --- Server: weapons ------------------------------------------------------------------------------

## A shot along a ray. Returns the distance to the agent it dropped, or -1.0 for a miss.
## Only the active set can be hit: the mass is scenery until it's close.
func hit_ray(from: Vector3, dir: Vector3, max_dist: float) -> float:
	var best := -1.0
	var best_i := -1
	var r := 0.42
	for i in count:
		if active[i] == 0:
			continue
		var s := state[i]
		if s == AState.DEAD or s == AState.GONE:
			continue
		var cx := px[i] - from.x
		var cy := py[i] + 0.9 - from.y
		var cz := pz[i] - from.z
		var t := cx * dir.x + cy * dir.y + cz * dir.z
		if t < 0.0 or t > max_dist or (best >= 0.0 and t > best):
			continue
		var qx := from.x + dir.x * t - px[i]
		var qy := from.y + dir.y * t - py[i]
		var qz := from.z + dir.z * t - pz[i]
		if qy < -0.3 or qy > HIT_HEIGHTS[kind[i]] + climb[i] + 0.3:
			continue
		if qx * qx + qz * qz > r * r:
			continue
		best = t
		best_i = i
	if best_i >= 0:
		kill(best_i)
	return best


func kill(i: int) -> void:
	if state[i] == AState.DEAD or state[i] == AState.GONE:
		return
	if state[i] == AState.GRAB:
		grab_a[i] = -1
		grab_b[i] = -1
	state[i] = AState.DEAD
	timer[i] = 0.0
	active[i] = 0
	climb[i] = 0.0
	py[i] = _ground(px[i], pz[i])
	dead += 1


## A bomb: everything in the radius dies, a little further is thrown back.
func blast(pos: Vector3, radius: float) -> void:
	var r2 := radius * radius
	var far2 := (radius + 2.5) * (radius + 2.5)
	for i in count:
		var s := state[i]
		if s == AState.DEAD or s == AState.GONE:
			continue
		var dx := px[i] - pos.x
		var dz := pz[i] - pos.z
		var d2 := dx * dx + dz * dz
		if d2 <= r2:
			kill(i)
		elif d2 <= far2:
			var d := sqrt(maxf(d2, 0.01))
			_release(i, Vector2(dx / d, dz / d), FLING_SPEED)


## Air horn: everything near it reels for a moment and lets go of the chain.
func stun(pos: Vector3, radius: float) -> void:
	var r2 := radius * radius
	for i in count:
		var s := state[i]
		if s == AState.DEAD or s == AState.GONE:
			continue
		var dx := px[i] - pos.x
		var dz := pz[i] - pos.z
		if dx * dx + dz * dz > r2:
			continue
		var d := sqrt(maxf(dx * dx + dz * dz, 0.01))
		_release(i, Vector2(dx / d, dz / d), 1.5)
		timer[i] = STUN_TIME


## Tests and respawns: put an agent somewhere, walking.
func place(i: int, pos: Vector3) -> void:
	px[i] = pos.x
	pz[i] = pos.z
	py[i] = _ground(pos.x, pos.z)
	state[i] = AState.WALK
	cool[i] = 0.0
	gcool[i] = 0.0
	climb[i] = 0.0
	grab_a[i] = -1
	grab_b[i] = -1


## A layoff: nobody respawns into a crowd. Everything within the radius is walked back out.
func push_away_from(center: Vector3, radius: float, to: Vector3) -> void:
	var r2 := radius * radius
	for i in count:
		var s := state[i]
		if s == AState.GONE:
			continue
		var dx := px[i] - center.x
		var dz := pz[i] - center.z
		if dx * dx + dz * dz < r2:
			var jitter := Vector3(_rng.randf_range(-6.0, 6.0), 0.0, _rng.randf_range(-6.0, 6.0))
			place(i, to + jitter)
			if s == AState.DEAD:
				state[i] = AState.DEAD
	_maul_t.clear()


func agent_position(i: int) -> Vector3:
	return Vector3(px[i], py[i], pz[i])


func nearest_agent(pos: Vector3, only_active: bool = false) -> int:
	var best := -1
	var bd := 1.0e12
	for i in count:
		var s := state[i]
		if s == AState.DEAD or s == AState.GONE or (only_active and active[i] == 0):
			continue
		var dx := px[i] - pos.x
		var dz := pz[i] - pos.z
		var d := dx * dx + dz * dz
		if d < bd:
			bd = d
			best = i
	return best


# --- Net: the server corrects the active set at 10 Hz, the rest slowly --------------------------

func _send_snapshots() -> void:
	var idx := PackedInt32Array()
	var half := _tick % 2
	var k := 0
	for i in count:
		if active[i] != 0:
			# The near half of the active set every send; the far half every other send.
			if _d2[i] < 144.0 or k % 2 == half:
				idx.append(i)
			k += 1
	# Round-robin over the mass, dead ones included so a late joiner learns who's down.
	var added := 0
	var guard := 0
	while added < MASS_CHUNK and guard < count:
		var i := _mass_cursor
		_mass_cursor = (_mass_cursor + 1) % count
		guard += 1
		if active[i] == 0:
			idx.append(i)
			added += 1
	var at := 0
	while at < idx.size():
		var n := mini(SNAPSHOT_CHUNK, idx.size() - at)
		var bytes := PackedByteArray()
		bytes.resize(n * 8)
		for j in n:
			var i := idx[at + j]
			var o := j * 8
			bytes.encode_u16(o, i)
			bytes.encode_u16(o + 2, clampi(int((px[i] - field.origin.x) * 100.0), 0, 65535))
			bytes.encode_u16(o + 4, clampi(int((pz[i] - field.origin.y) * 100.0), 0, 65535))
			bytes.encode_u8(o + 6, int(wrapf(yaw[i], 0.0, TAU) / TAU * 255.0) & 0xFF)
			bytes.encode_u8(o + 7, state[i])
		_rpc_snapshot.rpc(bytes)
		at += n


@rpc("authority", "call_remote", "unreliable")
func _rpc_snapshot(bytes: PackedByteArray) -> void:
	snapshots_received += 1
	var n := bytes.size() / 8
	for j in n:
		var o := j * 8
		var i := bytes.decode_u16(o)
		if i >= count:
			continue
		var sx := field.origin.x + float(bytes.decode_u16(o + 2)) * 0.01
		var sz := field.origin.y + float(bytes.decode_u16(o + 4)) * 0.01
		var sy := float(bytes.decode_u8(o + 6)) / 255.0 * TAU
		var st := bytes.decode_u8(o + 7)
		if st == AState.SWING:
			# The host has it on a thread: swing toward where the host says it is (a short arc
			# each packet; the landing cell gives the height). The thread draws from the start.
			if state[i] != AState.SWING:
				_start_swing(i, sx, _ground(sx, sz) if not field.is_void(sx, sz) else py[i], sz)
			else:
				sw_x1[i] = sx
				sw_z1[i] = sz
				if not field.is_void(sx, sz):
					sw_y1[i] = _ground(sx, sz)
				sw_dur[i] = maxf(timer[i], 0.12)
			yaw[i] = sy
			continue
		var dx := sx - px[i]
		var dz := sz - pz[i]
		if dx * dx + dz * dz > 4.0 or st == AState.GRAB or state[i] == AState.SWING:
			px[i] = sx
			pz[i] = sz
		else:
			px[i] += dx * 0.5
			pz[i] += dz * 0.5
		yaw[i] = sy
		if st != state[i]:
			if st == AState.DEAD and state[i] != AState.GONE:
				dead += 1
				py[i] = _ground(px[i], pz[i])
				climb[i] = 0.0
			if st == AState.CLIMB:
				# Up the face until the host says otherwise: the roof it's climbing to is the
				# higher ground round it.
				sw_x1[i] = px[i]
				sw_z1[i] = pz[i]
				sw_y1[i] = py[i] + 40.0
				for dz2 in range(-1, 2):
					for dx2 in range(-1, 2):
						var hy := _ground(px[i] + float(dx2) * field.cell, pz[i] + float(dz2) * field.cell)
						if hy > py[i] + 0.6 and hy < sw_y1[i]:
							sw_y1[i] = hy
				if sw_y1[i] > py[i] + 39.0:
					sw_y1[i] = py[i] + 2.0
			state[i] = st
			timer[i] = 0.0 if st == AState.DEAD else FLINCH_TIME


# --- Render: one buffer write per kind per tick ------------------------------------------------

func _fill_buffers() -> void:
	var n := count
	var threads := 0
	for i in n:
		var k := kind[i]
		var buf := _bufs[k]
		var o := _slot[i] * 16
		var s := state[i]
		if s == AState.GONE:
			buf[o] = 0.0
			buf[o + 5] = 0.0
			buf[o + 10] = 0.0
			continue
		var sc := scl[i]
		if s == AState.CLIMB or s == AState.SWING:
			# Pitched: nose up the wall, or hanging under the thread and swaying.
			var pitch := PI * 0.5 if s == AState.CLIMB else -0.35 + 0.25 * sin(phase[i] * 2.0)
			var b := Basis(Vector3.UP, yaw[i]) * Basis(Vector3.RIGHT, pitch) * Basis.from_scale(Vector3(sc, sc, sc))
			buf[o] = b.x.x
			buf[o + 1] = b.y.x
			buf[o + 2] = b.z.x
			buf[o + 4] = b.x.y
			buf[o + 5] = b.y.y
			buf[o + 6] = b.z.y
			buf[o + 8] = b.x.z
			buf[o + 9] = b.y.z
			buf[o + 10] = b.z.z
			if s == AState.SWING:
				threads += 1
		else:
			var cy := cos(yaw[i]) * sc
			var sy := sin(yaw[i]) * sc
			buf[o] = cy
			buf[o + 1] = 0.0
			buf[o + 2] = sy
			buf[o + 4] = 0.0
			buf[o + 5] = sc
			buf[o + 6] = 0.0
			buf[o + 8] = -sy
			buf[o + 9] = 0.0
			buf[o + 10] = cy
		buf[o + 3] = px[i]
		buf[o + 7] = py[i]
		buf[o + 11] = pz[i]
		buf[o + 12] = phase[i]
		buf[o + 13] = seed_f[i]
		# z packs the clothing tint (0..1) with the reach flag (+2): active and within three
		# metres of someone, the arms come up.
		buf[o + 14] = tint[i] + (2.0 if active[i] != 0 and _d2[i] < 9.0 else 0.0)
		buf[o + 15] = float(s)
	for k in HordeMesh.KINDS:
		if _kind_counts[k] > 0:
			_mms[k].buffer = _bufs[k]
	_draw_threads(threads)


## The silk of every swing in the air: one line each from its anchor over the gap, redrawn
## every tick (a handful at a time; nothing to batch).
func _draw_threads(threads: int) -> void:
	if _web_mesh == null:
		return
	_web_mesh.clear_surfaces()
	if threads == 0:
		return
	var silk := 0  # only Weavers hang from silk; a leaping roach has none
	for i in count:
		if state[i] == AState.SWING and THREADED[kind[i]]:
			silk += 1
	if silk == 0:
		return
	_web_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _web_mat)
	for i in count:
		if state[i] != AState.SWING or not THREADED[kind[i]]:
			continue
		_web_mesh.surface_add_vertex(swing_anchor(i))
		_web_mesh.surface_add_vertex(Vector3(px[i], py[i] + 0.35 * scl[i], pz[i]))
	_web_mesh.surface_end()


## Tests and respawns: everything within the radius of a spot is gone (back into the walls),
## so nobody respawns into a crowd on a roof too small to walk it off to.
func clear_near(center: Vector3, radius: float) -> void:
	var r2 := radius * radius
	for i in count:
		var s := state[i]
		if s == AState.GONE:
			continue
		var dx := px[i] - center.x
		var dz := pz[i] - center.z
		if dx * dx + dz * dz < r2:
			state[i] = AState.GONE
			grab_a[i] = -1
			grab_b[i] = -1
			active[i] = 0
	_maul_t.clear()


func _process(delta: float) -> void:
	if count == 0 or not enabled or muted or Sfx.is_silent():
		return
	var me := Net.get_local_player()
	if me == null:
		return
	_growl_t -= delta
	_caption_t -= delta
	if _growl_t > 0.0:
		return
	_growl_t = _rng.randf_range(0.5, 1.1)
	# A moan from somewhere in the crowd near you, now and then.
	var i := nearest_agent(me.global_position + Vector3(_rng.randf_range(-8.0, 8.0), 0.0, _rng.randf_range(-8.0, 8.0)))
	if i < 0:
		return
	var p := agent_position(i)
	var d := p.distance_to(me.global_position)
	if d > 35.0:
		return
	# Chitter and click from the swarm; a screech from a Flitter overhead.
	if FLYING[kind[i]]:
		Sfx.play_at(self, "screech", p, -18.0 + 6.0 * (1.0 - d / 35.0), _rng.randf_range(1.6, 2.2), 40.0)
	else:
		Sfx.play_at(self, "click", p + Vector3.UP * 0.4, -10.0 + 6.0 * (1.0 - d / 35.0), _rng.randf_range(1.4, 2.6), 30.0)
		Sfx.play_at(self, "growl", p + Vector3.UP * 0.4, -20.0 + 6.0 * (1.0 - d / 35.0), _rng.randf_range(1.5, 2.1), 30.0)
	if _caption_t <= 0.0:
		_caption_t = 7.0
		Sfx.caption(self, "wings overhead" if FLYING[kind[i]] else "the swarm chitters", p)


## Tests: how many of a kind were ever spawned (dead, gone back into the walls, or alive).
func spawned_of(k: int) -> int:
	var n := 0
	for i in count:
		if kind[i] == k:
			n += 1
	return n
