class_name RoadThreats
extends Node3D
## Kettle Hollow's road (Level 4): what stands in the streets ahead of the cars, and the navigator's
## gun. Laid out along the route from the seed: knots of Shamblers (people the town didn't get out,
## standing in the road with their arms out) that a car can run down at a cost (it loses half its
## speed and the glass is red), and Flyers (pale winged things hanging over the road) that come for
## a car that gets close and cling to its windscreen, so the driver is blind and the car can't do
## more than a crawl until the navigator shoots it off or it tears loose. The navigator shoots (held F,
## or Space): the gun picks what's on the glass, else the Strider while it's sprinting at them,
## else the nearest thing in front, else the Strider when it's close. A hit throws the Strider back
## and slows it. In solo the Ballast navigates and shoots for you, a little slower. Host-authoritative:
## the server decides every hit and tells every peer; flyers in flight are flown on every peer from
## the same start toward the same car.

enum Kind { SHAMBLER, FLYER }
enum Fly { HOVER, DIVE, LATCHED, GONE }
const HOW_SHOT: int = 0
const HOW_RUN_OVER: int = 1

const FIRST: float = 170.0  # m along the route to the first of them
const GAP_MIN: float = 70.0
const GAP_MAX: float = 115.0
const SHAMBLER_HIT: float = 1.6  # m (flat) from a car's middle: run down
const RUN_OVER_KEEP: float = 0.55  # of a car's speed left after it hits one
const FLYER_WAKE: float = 42.0  # m: a car this close and it comes for the glass
const FLYER_SPEED: float = 24.0  # m/s diving at a car
const FLYER_GIVE_UP: float = 4.0  # s after it dived, still not on the glass: it gives up
const LATCH_REACH: float = 1.9  # m from the windscreen: it's on
const LATCH_SECONDS: float = 6.0  # on the glass this long and it tears loose by itself
const LATCH_TOP: float = 10.0  # m/s a car can do with one on the glass
const SHOT_COOL: float = 0.28  # s between shots
const MAG: int = 8
const RELOAD: float = 1.8  # s
const AHEAD_RANGE: float = 60.0  # m
const AHEAD_CONE: float = 0.75  # rad either side of the car's nose
const STRIDER_RANGE: float = 75.0  # m along the route behind the car
const STRIDER_KNOCK: float = 6.0  # m along the route a hit throws it back
const STRIDER_SLOW: float = 1.3  # s it runs at a crawl after a hit
const STAGGER_COOL: float = 4.0  # s after a stagger that its hide shrugs rounds off (they hurt it, they don't stop it)
const BOT_SHOT_EVERY: float = 0.6  # s: the Ballast's aim
const BOT_MISS: float = 0.35  # of its shots
const GLASS: Vector3 = Vector3(0.0, 1.2, -0.75)  # car-local: where a Flyer clings

var town: Town
var kinds: PackedInt32Array = PackedInt32Array()
var alive: PackedByteArray = PackedByteArray()
var pos: PackedVector3Array = PackedVector3Array()  # world; flyers move
var home: PackedVector3Array = PackedVector3Array()
var fly: PackedInt32Array = PackedInt32Array()  # Fly state, flyers only
var fly_car: PackedInt32Array = PackedInt32Array()
var fly_t: PackedFloat32Array = PackedFloat32Array()
var strider_slow: float = 0.0  # server: s the Strider still runs at a crawl
var strider_hits: int = 0  # server: staggers (tests)
var _stagger_cool: float = 0.0
var ammo: PackedInt32Array = PackedInt32Array()  # every peer: per car (the server's word)
var shots_seen: int = 0  # every peer: tests
var debug_auto_gun: bool = false  # tests: every navigator shoots like the Ballast
var kills_seen: int = 0
var _nodes: Array[Node3D] = []
var _dead_t: PackedFloat32Array = PackedFloat32Array()  # every peer: s since it died, for the fall
var _how: PackedInt32Array = PackedInt32Array()
var _fling: PackedVector3Array = PackedVector3Array()
var _cool: PackedFloat32Array = PackedFloat32Array()  # server, per car
var _reload: PackedFloat32Array = PackedFloat32Array()
var _jumps: Dictionary = {}  # server: player instance id -> the jump counter last seen
var _t: float = 0.0


## Every peer, once the route exists: where everything stands.
func build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = Town.SEED + town.seed_value + 313
	var s := FIRST
	while s < town.finish_s - 70.0:
		var at := town.route_point(s)
		var tan := town.route_tangent(s)
		var side := Vector3(-tan.z, 0.0, tan.x)
		if rng.randf() < 0.6:
			for k in rng.randi_range(2, 4):
				_add(Kind.SHAMBLER, at + side * rng.randf_range(-3.8, 3.8) + tan * rng.randf_range(-5.0, 5.0), rng)
		else:
			for k in rng.randi_range(1, 2):
				_add(Kind.FLYER, at + side * rng.randf_range(-2.5, 2.5) + tan * rng.randf_range(-4.0, 4.0) + Vector3.UP * rng.randf_range(3.2, 5.0), rng)
		s += rng.randf_range(GAP_MIN, GAP_MAX)
	ammo.resize(Town.CARS)
	ammo.fill(MAG)
	_cool.resize(Town.CARS)
	_reload.resize(Town.CARS)


func _add(kind: int, at: Vector3, rng: RandomNumberGenerator) -> void:
	var i := kinds.size()
	kinds.append(kind)
	alive.append(1)
	pos.append(at)
	home.append(at)
	fly.append(Fly.HOVER)
	fly_car.append(-1)
	fly_t.append(0.0)
	_dead_t.append(0.0)
	_how.append(HOW_SHOT)
	_fling.append(Vector3.ZERO)
	var n := Node3D.new()
	n.name = "T%d" % i
	add_child(n)
	n.global_position = at
	n.rotation.y = rng.randf_range(0.0, TAU)
	if kind == Kind.SHAMBLER:
		Sculpt.put(n, ThreatMeshes.shambler(rng.randi_range(0, ThreatMeshes.SHAMBLER_VARIANTS - 1)), ThreatMeshes.flesh())
	else:
		ThreatMeshes.build_flyer(n)
	n.set_meta("phase", rng.randf_range(0.0, TAU))
	_nodes.append(n)


func count(kind: int) -> int:
	var n := 0
	for k in kinds:
		if k == kind:
			n += 1
	return n


func alive_count() -> int:
	var n := 0
	for a in alive:
		n += a
	return n


## The Flyer clinging to a car's glass, or -1.
func latched_on(car: int) -> int:
	for i in kinds.size():
		if kinds[i] == Kind.FLYER and alive[i] == 1 and fly[i] == Fly.LATCHED and fly_car[i] == car:
			return i
	return -1


# --- Server -------------------------------------------------------------------------------------

## Everything back where it stood (a layoff or a fresh arrival).
func server_reset() -> void:
	strider_slow = 0.0
	_stagger_cool = 0.0
	for k in Town.CARS:
		_cool[k] = 0.0
		_reload[k] = 0.0
	_rpc_reset.rpc()


@rpc("authority", "call_local", "reliable")
func _rpc_reset() -> void:
	ammo.fill(MAG)
	for i in kinds.size():
		alive[i] = 1
		pos[i] = home[i]
		fly[i] = Fly.HOVER
		fly_car[i] = -1
		fly_t[i] = 0.0
		_dead_t[i] = 0.0
		_nodes[i].visible = true
		_nodes[i].global_position = home[i]
		_nodes[i].rotation.x = 0.0
		_nodes[i].rotation.z = 0.0


func server_tick(delta: float) -> void:
	strider_slow = maxf(0.0, strider_slow - delta)
	_stagger_cool = maxf(0.0, _stagger_cool - delta)
	for i in kinds.size():
		if alive[i] == 0:
			continue
		if kinds[i] == Kind.SHAMBLER:
			for c in town.cars:
				if not c.in_use or absf(c.speed) < 3.0:
					continue
				if Vector2(c.global_position.x - pos[i].x, c.global_position.z - pos[i].z).length() < SHAMBLER_HIT:
					var away := (pos[i] - c.global_position).normalized() + Vector3.UP * 0.8
					c.speed *= RUN_OVER_KEEP
					_rpc_kill.rpc(i, HOW_RUN_OVER, away * clampf(absf(c.speed) * 0.6, 4.0, 12.0))
					break
		else:
			_server_flyer(i, delta)
	for c in town.cars:
		if c.in_use and latched_on(c.index) >= 0:
			c.speed = clampf(c.speed, -LATCH_TOP, LATCH_TOP)
		if c.in_use and not c.finished:
			_server_gun(c, delta)


func _server_flyer(i: int, delta: float) -> void:
	match fly[i]:
		Fly.HOVER:
			for c in town.cars:
				if not c.in_use or c.finished:
					continue
				var to := pos[i] - c.global_position
				var fwd := -c.global_basis.z
				if to.length() < FLYER_WAKE and to.normalized().dot(fwd) > 0.3:
					_rpc_fly.rpc(i, Fly.DIVE, c.index, pos[i])
					break
		Fly.DIVE:
			fly_t[i] += delta
			var c := town.cars[fly_car[i]]
			var glass := c.global_transform * GLASS
			if pos[i].distance_to(glass) < LATCH_REACH:
				_rpc_fly.rpc(i, Fly.LATCHED, c.index, glass)
				GameState.post_message("IT'S ON YOUR GLASS. NAVIGATOR: SHOOT IT OFF (F)", 2.5)
			elif fly_t[i] > FLYER_GIVE_UP:
				_rpc_fly.rpc(i, Fly.GONE, -1, pos[i])
			else:
				pos[i] = _fly_step(pos[i], glass, delta)
		Fly.LATCHED:
			fly_t[i] += delta
			var c := town.cars[fly_car[i]]
			pos[i] = c.global_transform * GLASS
			if fly_t[i] > LATCH_SECONDS or not c.in_use:
				_rpc_fly.rpc(i, Fly.GONE, -1, pos[i])


func _fly_step(from: Vector3, to: Vector3, delta: float) -> Vector3:
	var d := to - from
	var step := FLYER_SPEED * delta
	return to if d.length() <= step else from + d.normalized() * step


@rpc("authority", "call_local", "reliable")
func _rpc_fly(i: int, state: int, car: int, at: Vector3) -> void:
	fly[i] = state
	fly_car[i] = car
	fly_t[i] = 0.0
	pos[i] = at
	if state == Fly.DIVE:
		Sfx.play_at(self, "spider_shriek", at, 4.0, randf_range(1.3, 1.6), 70.0)
	elif state == Fly.LATCHED:
		Sfx.play_at(self, "screech", at, 6.0, randf_range(1.2, 1.5), 40.0)
		var me := Net.get_local_player()
		if me != null and town.local_car() != null and town.local_car().index == car:
			me.add_shake(0.8)
			ScreenFx.jolt(0.5)
	elif state == Fly.GONE:
		_nodes[i].visible = false
		alive[i] = 0


## The navigator's trigger: held F (the use key) or Space; the Ballast shoots by itself.
func _server_gun(c: RallyCar, delta: float) -> void:
	var k := c.index
	_cool[k] = maxf(0.0, _cool[k] - delta)
	if _reload[k] > 0.0:
		_reload[k] -= delta
		if _reload[k] <= 0.0:
			_rpc_ammo.rpc(k, MAG)
		return
	var wants := false
	var bot := true
	for at in range(1, c.occupants.size()):
		var p := Net.find_player(c.occupants[at])
		if p == null:
			continue
		bot = false
		var jump := (p.input_flags >> Player.JUMP_SEQ_SHIFT) & 0xFF
		var id := p.get_instance_id()
		if (p.input_flags & Player.FLAG_USE) != 0 or (_jumps.has(id) and int(_jumps[id]) != jump):
			wants = true
		_jumps[id] = jump
	if debug_auto_gun:
		bot = true
	if bot:
		if c.occupants.size() < 2:
			return  # nobody beside the driver: no gun
		wants = true
	if not wants or _cool[k] > 0.0:
		return
	var target := _pick(c, bot)
	if bot and target == -1:
		return
	_cool[k] = BOT_SHOT_EVERY if bot else SHOT_COOL
	var left := ammo[k] - 1
	var at := c.global_position + (-c.global_basis.z) * 40.0 + Vector3.UP * 1.5
	if target >= 0:
		at = pos[target] + Vector3.UP * (1.3 if kinds[target] == Kind.SHAMBLER else 0.0)
		if bot and randf() < BOT_MISS:
			at += Vector3(randf_range(-1.5, 1.5), randf_range(0.5, 1.5), randf_range(-1.5, 1.5))
			target = -1  # the Ballast is no marksman
	elif target == -2:
		at = town.strider.head_point()
		if _stagger_cool <= 0.0:
			_stagger_cool = STAGGER_COOL
			strider_slow = STRIDER_SLOW
			strider_hits += 1
			town.server_strider_shot()
	_rpc_shot.rpc(k, at, target, left)
	if left <= 0:
		_reload[k] = RELOAD


## What the gun on car c is pointing at: a threat's index, -2 the Strider, -1 nothing.
func _pick(c: RallyCar, bot: bool = false) -> int:
	var on_glass := latched_on(c.index)
	if on_glass >= 0:
		return on_glass
	var strider := town.strider
	var behind := c.progress - strider.s
	var strider_ok := strider.active and behind < STRIDER_RANGE and behind > -5.0
	if strider_ok and town.surging():
		return -2
	var eye := c.global_position + Vector3.UP * 1.3
	var fwd := -c.global_basis.z
	var best := -1
	var best_d := AHEAD_RANGE
	for i in kinds.size():
		if alive[i] == 0 or (kinds[i] == Kind.FLYER and fly[i] == Fly.GONE):
			continue
		var to := pos[i] - c.global_position
		var d := to.length()
		if d >= best_d or d < 0.5:
			continue
		var flat := Vector3(to.x, 0.0, to.z).normalized()
		if flat.angle_to(fwd) > AHEAD_CONE:
			continue
		if not _clear(eye, pos[i] + Vector3.UP * (1.2 if kinds[i] == Kind.SHAMBLER else 0.0), c):
			continue
		best = i
		best_d = d
	if best >= 0:
		return best
	if strider_ok and behind < STRIDER_RANGE * 0.6 and not bot:  # the Ballast only fights it off while it sprints
		return -2
	return -1


func _clear(a: Vector3, b: Vector3, c: RallyCar) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b, 1)
	q.exclude = [c.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


@rpc("authority", "call_local", "reliable")
func _rpc_ammo(car: int, n: int) -> void:
	ammo[car] = n


@rpc("authority", "call_local", "reliable")
func _rpc_shot(car: int, at: Vector3, target: int, left: int) -> void:
	ammo[car] = maxi(0, left)
	shots_seen += 1
	var c := town.cars[car]
	var muzzle := c.global_transform * Vector3(0.95, 1.25, -0.3)
	Sfx.play_at(self, "shot", muzzle, 4.0, randf_range(0.8, 0.95), 80.0)
	_flash(muzzle)
	_tracer(muzzle, at)
	if target >= 0 and target < kinds.size():
		_blood(at, 1.4)
		_kill_local(target, HOW_SHOT, (at - muzzle).normalized() * 6.0)
	elif target == -2:
		_blood(at, 3.0)
		Sfx.play_at(self, "screech", at, 10.0, randf_range(0.45, 0.6), 120.0)


@rpc("authority", "call_local", "reliable")
func _rpc_kill(i: int, how: int, fling: Vector3) -> void:
	_blood(pos[i] + Vector3.UP * 1.0, 2.0)
	Sfx.play_at(self, "thump", pos[i], 6.0, 0.7, 50.0)
	_kill_local(i, how, fling)
	var mine := town.local_car()
	if how == HOW_RUN_OVER and mine != null and mine.global_position.distance_to(pos[i]) < 6.0:
		var me := Net.get_local_player()
		if me != null:
			me.add_shake(0.6)
		ScreenFx.jolt(0.4)


func _kill_local(i: int, how: int, fling: Vector3) -> void:
	if alive[i] == 0:
		return
	alive[i] = 0
	kills_seen += 1
	_how[i] = how
	_fling[i] = fling
	_dead_t[i] = 0.0
	if kinds[i] == Kind.FLYER:
		Sfx.play_at(self, "spider_shriek", pos[i], 2.0, 0.8, 50.0)


# --- Every peer ---------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not town._shown:
		return
	_t += delta
	var cam := get_viewport().get_camera_3d()
	for i in kinds.size():
		var n := _nodes[i]
		if not n.visible:
			continue
		if cam != null and pos[i].distance_squared_to(cam.global_position) > 180.0 * 180.0:  # where it is now, not where its node was last drawn
			continue
		var ph: float = n.get_meta("phase")
		if alive[i] == 0:
			_dead_t[i] += delta
			_animate_dead(i, n, delta)
			continue
		if kinds[i] == Kind.SHAMBLER:
			# It turns to the nearest car and sways, arms out, mouth open.
			var near := _nearest_car(n.global_position)
			if near != null:
				var to := near.global_position - n.global_position
				var want := atan2(-to.x, -to.z)
				n.rotation.y = lerp_angle(n.rotation.y, want, clampf(delta * 1.5, 0.0, 1.0))
			n.rotation.z = 0.09 * sin(_t * 1.3 + ph)
			n.rotation.x = 0.07 * sin(_t * 0.9 + ph * 2.0) + 0.05
		else:
			if fly[i] == Fly.DIVE and fly_car[i] >= 0:
				var glass := town.cars[fly_car[i]].global_transform * GLASS
				if not multiplayer.is_server():
					pos[i] = _fly_step(pos[i], glass, delta)
			elif fly[i] == Fly.LATCHED and fly_car[i] >= 0:
				pos[i] = town.cars[fly_car[i]].global_transform * GLASS
			var bob := Vector3.UP * (0.35 * sin(_t * 2.1 + ph)) if fly[i] == Fly.HOVER else Vector3.ZERO
			n.global_position = pos[i] + bob
			var look := cam.global_position if cam != null and fly[i] == Fly.HOVER else (town.cars[fly_car[i]].global_position if fly_car[i] >= 0 else n.global_position - Vector3.FORWARD)
			var to := look - n.global_position
			if Vector2(to.x, to.z).length() > 0.1:
				n.rotation.y = atan2(-to.x, -to.z)
			var lit := n.get_node_or_null("GlassLight") as OmniLight3D
			if fly[i] == Fly.LATCHED:
				var car := town.cars[fly_car[i]]
				n.global_rotation = Vector3(-1.2, car.global_rotation.y + PI, 0.0)  # spread over the glass, facing in
				if cam != null and town.local_car() == car and town.local_seat() == 0:
					# The driver sees it from the inside: right up against the camera, mouth working.
					var at := cam.global_transform * Vector3(sin(_t * 17.0) * 0.05, -0.1 + cos(_t * 13.0) * 0.04, -1.15)
					n.global_transform = Transform3D(Basis.looking_at(cam.global_position - at, Vector3.UP).rotated(Vector3.UP, 0.0), at)
					n.scale = Vector3.ONE * 1.4
					if lit == null:
						lit = OmniLight3D.new()
						lit.name = "GlassLight"
						lit.light_color = Color(1.0, 0.55, 0.45)
						lit.light_energy = 0.45
						lit.omni_range = 1.6
						lit.position = Vector3(0.0, 0.3, -1.0)
						n.add_child(lit)
					lit.visible = true
			elif lit != null:
				lit.visible = false
			var rate := 14.0 if fly[i] == Fly.HOVER else 22.0
			var flap := sin(_t * rate + ph)
			for w in 2:
				var wing := n.get_node_or_null("Wing%d" % w) as Node3D
				if wing != null:
					wing.rotation.z = (0.75 * flap + 0.1) * (1.0 if w == 0 else -1.0)


func _animate_dead(i: int, n: Node3D, delta: float) -> void:
	var t := _dead_t[i]
	if kinds[i] == Kind.FLYER or _how[i] == HOW_RUN_OVER:
		# Thrown: up and over, then lying where it came down.
		if t < 1.2:
			_fling[i].y -= 18.0 * delta
			var p := n.global_position + _fling[i] * delta
			var floor_y := town.origin.y + 0.15
			if p.y < floor_y:
				p.y = floor_y
				_fling[i] = Vector3(_fling[i].x * 0.4, 0.0, _fling[i].z * 0.4)
			n.global_position = p
			n.rotation.x = minf(n.rotation.x + delta * 9.0, PI * 0.5)
			n.rotation.z += delta * 3.0
	else:
		# Shot: it goes over backwards and lies there.
		n.rotation.x = maxf(n.rotation.x - delta * 4.5, -PI * 0.5)


func _nearest_car(p: Vector3) -> RallyCar:
	var best: RallyCar = null
	var bd := 90.0
	for c in town.cars:
		if not c.in_use:
			continue
		var d := c.global_position.distance_to(p)
		if d < bd:
			bd = d
			best = c
	return best


func _flash(at: Vector3) -> void:
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.75, 0.4)
	l.light_energy = 6.0
	l.omni_range = 9.0
	add_child(l)
	l.global_position = at
	get_tree().create_timer(0.06).timeout.connect(l.queue_free)


func _tracer(a: Vector3, b: Vector3) -> void:
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	im.surface_add_vertex(a)
	im.surface_add_vertex(b)
	im.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.85, 0.5)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_transform = Transform3D.IDENTITY
	get_tree().create_timer(0.05).timeout.connect(mi.queue_free)


## A burst of dark red, local to every peer.
func _blood(at: Vector3, amount: float) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = int(24.0 * amount)
	p.lifetime = 0.8
	p.explosiveness = 0.95
	p.direction = Vector3(0.0, 0.5, 0.0)
	p.spread = 80.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.0 * amount
	p.gravity = Vector3(0.0, -9.0, 0.0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4 * amount
	var m := SphereMesh.new()
	m.radius = 0.03
	m.height = 0.06
	m.radial_segments = 6
	m.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.01, 0.02)
	mat.roughness = 0.2
	m.material = mat
	p.mesh = m
	add_child(p)
	p.global_position = at
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)
