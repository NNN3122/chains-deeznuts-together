class_name RallyCar
extends CharacterBody3D
## A rally car from Kettle Hollow's night rally, keys still in it (Level 4, the chase). Two of the
## Line ride in each: the driver (W/S throttle and brake, A/D or the turn keys to steer, Ctrl the
## handbrake for a slide) and the navigator, who has the map and calls the turns. The server drives
## it from the driver's input packets with an arcade model: speed along the nose, a sideways slip
## that grips back (slowly with the handbrake on, so the tail comes round), steering that tightens
## as it slows. Pose and speed are replicated; every peer draws it smoothly between packets.

const WIDTH: float = 1.9
const LENGTH: float = 4.1
const HEIGHT: float = 1.4
const MAX_SPEED: float = 36.0  # m/s flat out (about 130 km/h): faster than the Strider at full stride
const REVERSE_SPEED: float = 7.0
const ACCEL: float = 14.0  # m/s^2 on the throttle
const FALL: float = 24.0  # m/s^2 down when nothing is under the wheels (off the edge)
const BRAKE: float = 26.0
const COAST: float = 3.5  # m/s^2 off the throttle
const STEER_RATE: float = 2.1  # rad/s at walking pace and up
const STEER_HIGH_SPEED: float = 0.45  # of the steering left at top speed
const GRIP: float = 11.0  # /s the sideways slip grips back at
const HANDBRAKE_GRIP: float = 1.6
const HANDBRAKE_STEER: float = 1.55  # x the turn rate with the handbrake on
const HANDBRAKE_DRAG: float = 6.0  # m/s^2 the handbrake costs
const SLIP_FROM_TURN: float = 0.32  # of speed x turn rate that becomes a slide
const BANG_SPEED: float = 7.0  # m/s lost in one hit that bangs
const CRASH_SPEED: float = 10.0  # m/s lost in one hit that wrecks it for a moment (a tree, a wall, head on)
const CRASH_STALL: float = 2.6  # s the engine's dead after a crash: the Strider closes in
const ROUGH_TOP: float = 9.0  # m/s it can do off the road (dirt, roots, the ditch)
const SEAT_DRIVER: Vector3 = Vector3(-0.42, 0.45, 0.15)
const SEAT_NAVIGATOR: Vector3 = Vector3(0.42, 0.45, 0.15)
const SEAT_BACK: Vector3 = Vector3(0.0, 0.45, 1.1)
const LIVERIES: Array[Color] = [Color(0.85, 0.12, 0.08), Color(0.08, 0.32, 0.8), Color(0.92, 0.72, 0.08), Color(0.1, 0.55, 0.22), Color(0.88, 0.88, 0.85)]

var index: int = 0
var in_use: bool = false  # replicated: carrying some of the Line
var speed: float = 0.0  # replicated: m/s along the nose
var slip: float = 0.0  # replicated: m/s sideways (the tail out)
var synced_xform: Transform3D = Transform3D.IDENTITY  # replicated
var occupants: PackedInt32Array = PackedInt32Array()  # replicated: peer ids, driver first; -1 the Ballast
var progress: float = 0.0  # replicated: metres along the town's route it has got to (Town)
var finished: bool = false  # server: over the finish line
var locked: bool = false  # server: held on the line (the countdown), or in the Strider's hands
var driver: Player  # server
var autopilot: Array = []  # server, tests: route points to drive by itself
var seats: Array[Node3D] = []
var _steer_vis: float = 0.0
var _wheel_spin: float = 0.0
var _wheels: Array[Node3D] = []
var _engine: AudioStreamPlayer3D
var _brake_mat: StandardMaterial3D
var _bang_cool: float = 0.0
var _skid_cool: float = 0.0
var _auto_i: int = 0
var _vy: float = 0.0  # server: m/s up (falling off the mountain)
var stall_t: float = 0.0  # server: s the engine stays dead after a crash
var rough: bool = false  # server, set by the Town each tick: off the road's surface
var crashes: int = 0  # server: tests


static func create(i: int, at: Transform3D) -> RallyCar:
	var c := RallyCar.new()
	c.name = "Car%d" % i
	c.index = i
	c.transform = at
	c.synced_xform = at
	return c


func _enter_tree() -> void:
	if has_node("Sync"):
		return
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	for prop in ["in_use", "speed", "slip", "synced_xform", "occupants", "progress"]:
		var path := NodePath(".:" + prop)
		cfg.add_property(path)
		cfg.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	sync.replication_config = cfg
	add_child(sync)


func _ready() -> void:
	collision_layer = ChainBody.LAYER_WORLD  # the other cars bump it, and the bodies inside never move by physics
	collision_mask = ChainBody.LAYER_WORLD
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	wall_min_slide_angle = 0.0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(WIDTH, 1.0, LENGTH)
	shape.shape = box
	shape.position = Vector3(0.0, 0.7, 0.0)
	add_child(shape)
	_build_visual()
	for p: Vector3 in [SEAT_DRIVER, SEAT_NAVIGATOR, SEAT_BACK]:
		var s := Node3D.new()
		s.position = p
		add_child(s)
		seats.append(s)
	_engine = Sfx.loop_player("engine", -6.0, 45.0)
	_engine.position = Vector3(0.0, 0.6, -1.4)
	add_child(_engine)


func _build_visual() -> void:
	var paint := LIVERIES[index % LIVERIES.size()]
	var body := Sculpt.put(self, car_mesh(paint), Sculpt.material(0.35, 0.0, 0.0, 0.0, 0.05))
	body.name = "Body"
	# Number roundels on the doors.
	for s: float in [-1.0, 1.0]:
		var n := Label3D.new()
		n.text = str(index + 7)
		n.font_size = 120
		n.pixel_size = 0.004
		n.modulate = Color(0.05, 0.05, 0.05)
		n.outline_size = 0
		n.shaded = true
		n.position = Vector3(s * (WIDTH * 0.5 + 0.03), 0.72, 0.1)
		n.rotation.y = s * PI * 0.5
		add_child(n)
	var tyre := StandardMaterial3D.new()
	tyre.albedo_color = Color(0.04, 0.04, 0.045)
	tyre.roughness = 0.9
	var rim := StandardMaterial3D.new()
	rim.albedo_color = Color(0.6, 0.6, 0.62)
	rim.metallic = 0.8
	rim.roughness = 0.35
	for k in 4:
		var pivot := Node3D.new()
		pivot.position = Vector3((-1.0 if k % 2 == 0 else 1.0) * 0.86, 0.34, -1.3 if k < 2 else 1.3)
		add_child(pivot)
		var spin := Node3D.new()
		pivot.add_child(spin)
		var t := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.34
		cm.bottom_radius = 0.34
		cm.height = 0.26
		cm.radial_segments = 18
		t.mesh = cm
		t.rotation.z = PI * 0.5
		t.material_override = tyre
		spin.add_child(t)
		var r := MeshInstance3D.new()
		var rm := CylinderMesh.new()
		rm.top_radius = 0.2
		rm.bottom_radius = 0.2
		rm.height = 0.28
		rm.radial_segments = 10
		r.mesh = rm
		r.rotation.z = PI * 0.5
		r.material_override = rim
		spin.add_child(r)
		_wheels.append(pivot)
	# Headlamps: the only light most of the way, so they matter.
	for s: float in [-1.0, 1.0]:
		var lamp := SpotLight3D.new()
		lamp.position = Vector3(s * 0.62, 0.72, -LENGTH * 0.5 - 0.05)
		lamp.rotation.x = -0.06
		lamp.light_energy = 5.0
		lamp.spot_range = 42.0
		lamp.spot_angle = 26.0
		lamp.spot_attenuation = 0.7
		lamp.light_color = Color(1.0, 0.93, 0.78)
		lamp.light_volumetric_fog_energy = 0.6
		add_child(lamp)
		var lens := MeshInstance3D.new()
		var lm := SphereMesh.new()
		lm.radius = 0.11
		lm.height = 0.12
		lm.radial_segments = 10
		lm.rings = 5
		lens.mesh = lm
		lens.position = lamp.position + Vector3(0.0, 0.0, 0.04)
		lens.material_override = LevelKit.mat("glow")
		add_child(lens)
	_brake_mat = StandardMaterial3D.new()
	_brake_mat.albedo_color = Color(0.5, 0.02, 0.02)
	_brake_mat.emission_enabled = true
	_brake_mat.emission = Color(1.0, 0.05, 0.03)
	_brake_mat.emission_energy_multiplier = 0.6
	for s: float in [-1.0, 1.0]:
		var tail := MeshInstance3D.new()
		var tb := BoxMesh.new()
		tb.size = Vector3(0.36, 0.12, 0.05)
		tail.mesh = tb
		tail.position = Vector3(s * 0.62, 0.8, LENGTH * 0.5 + 0.02)
		tail.material_override = _brake_mat
		add_child(tail)


## The car's shell, sculpted (rounded, not boxes): a low body with flared arches, a cabin with dark
## glass, a bonnet scoop and a wing, the livery colour with a white stripe and a lot of mud.
static func car_mesh(paint: Color) -> ArrayMesh:
	var s := Sculpt.new()
	var mud := Color(0.2, 0.15, 0.1)
	var glass := Color(0.03, 0.035, 0.045)
	s.box(Vector3(0.0, 0.62, 0.0), Vector3(0.9, 0.3, 2.0), 0.18, paint, 0.08, 0.35)
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.3, 1.3]:
			s.ellipsoid(Vector3(x * 0.82, 0.55, z), Vector3(0.16, 0.36, 0.5), paint, 0.12, 0.35)  # wheel arches
			s.carve_ellipsoid(Vector3(x * 0.9, 0.32, z), Vector3(0.3, 0.4, 0.42), paint, 0.03)
	s.box(Vector3(0.0, 1.08, 0.25), Vector3(0.74, 0.26, 0.95), 0.2, paint, 0.1, 0.35)  # the cabin
	s.paint_box(Vector3(0.0, 1.1, 0.25), Vector3(0.78, 0.17, 0.98), glass, 0.08)  # dark windows all round
	s.paint_box(Vector3(0.0, 1.32, 0.25), Vector3(0.72, 0.05, 0.9), paint, 0.35)  # roof back over them
	s.box(Vector3(0.0, 0.92, -0.95), Vector3(0.24, 0.07, 0.3), 0.05, Color(0.05, 0.05, 0.05), 0.04, 0.5)  # bonnet scoop
	s.box(Vector3(0.0, 1.25, 1.95), Vector3(0.82, 0.03, 0.16), 0.02, Color(0.05, 0.05, 0.05), 0.02, 0.4)  # the wing
	for x: float in [-0.7, 0.7]:
		s.box(Vector3(x, 1.08, 1.92), Vector3(0.03, 0.17, 0.08), 0.01, Color(0.05, 0.05, 0.05), 0.02, 0.4)
	s.paint_box(Vector3(0.0, 0.62, 0.0), Vector3(0.14, 0.95, 2.1), Color(0.92, 0.92, 0.9), 0.3)  # the stripe
	s.paint_box(Vector3(0.0, 0.42, 0.0), Vector3(0.95, 0.14, 2.1), mud, 0.9)  # mud up the sills
	s.paint_ellipsoid(Vector3(0.5, 0.75, 1.6), Vector3(0.4, 0.25, 0.4), mud, 0.9)
	s.paint_ellipsoid(Vector3(-0.6, 0.85, -1.5), Vector3(0.3, 0.2, 0.35), mud, 0.9)
	return s.noise_scale(14.0).mesh("rally_car_%s" % paint.to_html(false), 0.035, 3200)


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		_server_drive(delta)
		synced_xform = global_transform
	else:
		# Clients: ease to the host's pose (packets come a few frames apart).
		var k := clampf(delta * 18.0, 0.0, 1.0)
		var t := global_transform
		t.origin = t.origin.lerp(synced_xform.origin, k)
		t.basis = t.basis.slerp(synced_xform.basis.orthonormalized(), k).orthonormalized()
		global_transform = t
	_animate(delta)


func _driver_input() -> Vector3:
	# x steer (right +), y throttle (forward +), z handbrake (1/0).
	if not autopilot.is_empty():
		return _autopilot_input()
	if driver == null or not is_instance_valid(driver):
		return Vector3(0.0, 0.0, 1.0)  # nobody at the wheel: it rolls to a stop
	var raw := Vector3(driver.input_move.x, 0.0, driver.input_move.y).rotated(Vector3.UP, -driver.input_yaw)
	var hand := 1.0 if (driver.input_flags & Player.FLAG_BRACE) != 0 else 0.0
	return Vector3(clampf(raw.x, -1.0, 1.0), clampf(-raw.z, -1.0, 1.0), hand)


## Tests: drive the route by itself (steer for the next point, lift off for the corners).
func _autopilot_input() -> Vector3:
	# Pure pursuit down the middle of the road: a point a little ahead along the route (cutting
	# straight at the next corner ran it into wrecks parked just round it), and slowing for a turn.
	var here := Vector3(global_position.x, 0.0, global_position.z)
	if _auto_i == 0:
		autopilot.push_front(global_position)  # the first leg runs from where the car is
		_auto_i = 1
	var flat := func(v: Vector3) -> Vector3: return Vector3(v.x, 0.0, v.z)
	while _auto_i < autopilot.size() - 1:
		var a: Vector3 = flat.call(autopilot[_auto_i - 1])
		var b: Vector3 = flat.call(autopilot[_auto_i])
		if (here - b).dot((b - a).normalized()) > -1.5:
			_auto_i += 1
		else:
			break
	var a0: Vector3 = flat.call(autopilot[_auto_i - 1])
	var b0: Vector3 = flat.call(autopilot[_auto_i])
	var dir := (b0 - a0).normalized()
	var proj := a0 + dir * clampf((here - a0).dot(dir), 0.0, a0.distance_to(b0))
	var look := clampf(absf(speed) * 0.45, 5.0, 11.0)
	var target := proj
	var k := _auto_i
	var from := proj
	while look > 0.0:
		var nxt: Vector3 = flat.call(autopilot[k])
		var d := from.distance_to(nxt)
		if d >= look or k >= autopilot.size() - 1:
			target = from + (nxt - from).normalized() * minf(look, d)
			break
		look -= d
		from = nxt
		k += 1
	var to := target - here
	var fwd := -global_basis.z
	fwd.y = 0.0
	var ang := fwd.signed_angle_to(to.normalized(), Vector3.UP)  # + is to the left
	var steer := clampf(-ang * 2.2, -1.0, 1.0)
	# Brake for what's coming: every bend in the next 140 m has a speed the steering can hold it at
	# (the car turns tighter slower), and the car has to be down to it by the time it gets there.
	var want := MAX_SPEED
	var dist := -here.distance_to(a0)  # the corner just reached is still being taken
	var j := _auto_i - 1
	if j < 1:
		j = _auto_i
		dist = here.distance_to(b0)
	while j < autopilot.size() - 1 and dist < 140.0:
		var d1: Vector3 = flat.call(autopilot[j]) - flat.call(autopilot[j - 1])
		var d2: Vector3 = flat.call(autopilot[j + 1]) - flat.call(autopilot[j])
		if d1.length() > 0.01 and d2.length() > 0.01:
			var bend := absf(d1.signed_angle_to(d2, Vector3.UP))
			if bend > 0.02:
				var r := minf(d1.length(), d2.length()) / bend
				var hold := maxf(7.0, 0.7 * STEER_RATE * r / (1.0 + STEER_RATE * r * (1.0 - STEER_HIGH_SPEED) / MAX_SPEED))
				if bend > 0.6:
					hold = 10.0  # a street corner: a right angle all at once
				want = minf(want, sqrt(hold * hold + 2.0 * 14.0 * maxf(dist, 0.0)))
		dist += d2.length()
		j += 1
	var throttle := 1.0 if speed < want else -0.7
	return Vector3(steer, throttle, 0.0)


func _server_drive(delta: float) -> void:
	_bang_cool = maxf(0.0, _bang_cool - delta)
	_skid_cool = maxf(0.0, _skid_cool - delta)
	if not in_use or locked:
		speed = 0.0
		slip = 0.0
		return
	var inp := _driver_input()
	var steer := inp.x
	var throttle := inp.y
	if stall_t > 0.0:
		stall_t -= delta
		throttle = 0.0  # the engine coughs and won't catch
	var hand := inp.z > 0.5
	if throttle > 0.05:
		if speed < 0.0:
			speed = move_toward(speed, 0.0, BRAKE * delta)
		else:
			speed = move_toward(speed, MAX_SPEED, ACCEL * throttle * (1.0 - 0.55 * speed / MAX_SPEED) * delta)
	elif throttle < -0.05:
		if speed > 0.0:
			speed = move_toward(speed, 0.0, BRAKE * -throttle * delta)
		else:
			speed = move_toward(speed, -REVERSE_SPEED, ACCEL * 0.6 * delta)
	else:
		speed = move_toward(speed, 0.0, COAST * delta)
	if hand:
		speed = move_toward(speed, 0.0, HANDBRAKE_DRAG * delta)
	if rough and absf(speed) > ROUGH_TOP:
		speed = move_toward(speed, signf(speed) * ROUGH_TOP, 14.0 * delta)  # the dirt grabs the wheels
	var pace := clampf(absf(speed) / 8.0, 0.0, 1.0)
	var high := clampf(absf(speed) / MAX_SPEED, 0.0, 1.0)
	var rate := -steer * STEER_RATE * pace * lerpf(1.0, STEER_HIGH_SPEED, high) * signf(speed if absf(speed) > 0.1 else 1.0)
	if hand:
		rate *= HANDBRAKE_STEER
	rotate_y(rate * delta)
	slip += rate * speed * SLIP_FROM_TURN * delta  # the body turns, the car keeps going: the tail steps out
	slip = move_toward(slip, 0.0, (HANDBRAKE_GRIP if hand else GRIP) * absf(slip) * delta + 0.5 * delta)
	var fwd := -global_basis.z
	var right := global_basis.x
	velocity = fwd * speed + right * slip
	_vy = -1.0 if is_on_floor() else _vy - FALL * delta
	velocity.y = _vy
	var before := Vector2(velocity.x, velocity.z).length()  # the fall is not a crash
	var ahead_before := speed
	move_and_slide()
	var after := Vector3(velocity.x, 0.0, velocity.z)
	if is_on_floor():
		_vy = -1.0
	speed = after.dot(fwd)
	slip = after.dot(right)
	var lost := maxf(before - after.length(), absf(ahead_before) - absf(speed))  # into something, even at an angle (the rest turns into a slide)
	if lost > CRASH_SPEED and stall_t <= 0.0:
		stall_t = CRASH_STALL
		crashes += 1
		_bang_cool = 0.6
		_rpc_crash.rpc(lost)
	elif lost > BANG_SPEED and _bang_cool <= 0.0:
		_bang_cool = 0.6
		_rpc_bang.rpc(lost)
	if absf(slip) > 4.0 and _skid_cool <= 0.0:
		_skid_cool = 0.5
		_rpc_skid.rpc()


@rpc("authority", "call_local", "unreliable")
func _rpc_bang(hard: float) -> void:
	Sfx.play_at(self, "slam", global_position + Vector3.UP, clampf(hard - 10.0, -8.0, 4.0), randf_range(0.6, 0.85), 40.0)
	if _local_inside():
		var me := Net.get_local_player()
		if me != null:
			me.add_shake(clampf(hard / 20.0, 0.15, 0.6))


## A crash: glass and metal, steam out of the bonnet, and inside, the world jumps.
@rpc("authority", "call_local", "reliable")
func _rpc_crash(hard: float) -> void:
	Sfx.play_at(self, "slam", global_position + Vector3.UP, 6.0, 0.5, 60.0)
	Sfx.play_at(self, "bang", global_position + Vector3.UP, 0.0, 0.7, 60.0)
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 40
	p.lifetime = 2.2
	p.explosiveness = 0.4
	p.direction = Vector3.UP
	p.spread = 35.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 3.0
	p.gravity = Vector3(0.0, 0.6, 0.0)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 5.0
	var m := SphereMesh.new()
	m.radius = 0.12
	m.height = 0.24
	m.radial_segments = 6
	m.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.55, 0.55, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.material = mat
	p.mesh = m
	add_child(p)
	p.position = Vector3(0.0, 1.0, -1.6)
	p.emitting = true
	get_tree().create_timer(3.0).timeout.connect(p.queue_free)
	if _local_inside():
		var me := Net.get_local_player()
		if me != null:
			me.add_shake(clampf(hard / 15.0, 0.6, 1.4))
		ScreenFx.jolt(0.5)
		GameState.post_message_local("YOU HIT IT AT %d km/h. THE ENGINE'S DEAD. COME ON..." % int(hard * 3.6), 2.2)


@rpc("authority", "call_local", "unreliable")
func _rpc_skid() -> void:
	Sfx.play_at(self, "scrape", global_position, -6.0, randf_range(1.3, 1.6), 30.0)


func _local_inside() -> bool:
	return occupants.has(multiplayer.get_unique_id())


func _animate(delta: float) -> void:
	var steer_target := 0.0
	if multiplayer.is_server():
		steer_target = _driver_input().x if in_use else 0.0
	else:
		steer_target = clampf(slip * -0.08, -0.6, 0.6)
	_steer_vis = lerpf(_steer_vis, steer_target * 0.45, clampf(delta * 10.0, 0.0, 1.0))
	_wheel_spin += speed * delta / 0.34
	for k in _wheels.size():
		var w := _wheels[k]
		w.rotation.y = -_steer_vis if k < 2 else 0.0
		(w.get_child(0) as Node3D).rotation.x = -_wheel_spin
	_brake_mat.emission_energy_multiplier = 3.0 if (in_use and speed > 1.0 and multiplayer.is_server() and _driver_input().y < -0.1) else 0.6
	if in_use:
		Sfx.start_loop(_engine)
		_engine.pitch_scale = 0.55 + 1.1 * clampf(absf(speed) / MAX_SPEED, 0.0, 1.0)
	elif _engine.playing:
		_engine.stop()


## Server: put it at `at`, stopped.
func server_park(at: Transform3D) -> void:
	global_transform = at
	synced_xform = at
	speed = 0.0
	slip = 0.0
	velocity = Vector3.ZERO
	_auto_i = 0
	_vy = 0.0
	stall_t = 0.0
	rough = false
