class_name RallyCar
extends CharacterBody3D
## A rally car from Kettle Hollow's night rally, keys still in it (Level 4, the chase). Two of the
## Line ride in each: the driver (W the throttle, S the brake and then reverse, A/D to steer, Ctrl the
## handbrake for a slide) and the navigator, who has the map and calls the turns. The server drives
## it from the driver's input packets with a real car's outline (see _server_drive): gears, pedals,
## brakes that need distance, tyres with a grip limit, a handbrake that lets the back go. Pose and speed are replicated; every peer draws it smoothly between packets.

const WIDTH: float = 1.9
const LENGTH: float = 4.1
const HEIGHT: float = 1.4
const MAX_SPEED: float = 38.0  # m/s where top gear runs out (about 137 km/h)
const REVERSE_SPEED: float = 7.0
const GEAR_TOP: Array[float] = [13.0, 21.0, 28.0, 34.0, 39.5]  # m/s at the red line in each gear
const GEAR_PULL: Array[float] = [6.2, 4.6, 3.4, 2.5, 1.9]  # m/s^2 at peak torque in each gear (0-100 km/h in about 7 s)
const REVERSE_PULL: float = 3.5
const SHIFT_UP: float = 0.93  # of the red line: up a gear
const SHIFT_DOWN: float = 0.62  # of the gear below's red line: down one
const SHIFT_TIME: float = 0.22  # s with no drive while it changes
const THROTTLE_DOWN: float = 4.5  # /s the pedal goes down (a key is all or nothing: a foot isn't)
const THROTTLE_UP: float = 9.0
const BRAKE_DOWN: float = 6.0
const BRAKE_UP: float = 10.0
const BRAKE_FORCE: float = 10.0  # m/s^2 with the pedal on the floor (about 1 g: 130 km/h to a stop takes 65 m)
const ENGINE_BRAKE: float = 0.55  # m/s^2 off the throttle (more in the low gears): lift and it rolls on a long way
const ROLL: float = 0.15  # m/s^2 of rolling drag
const DRAG: float = 0.00095  # /m of air drag (x speed squared)
const GRIP: float = 10.5  # m/s^2: all the tyres have, shared between turning, braking and driving
const ROUGH_GRIP: float = 0.55  # of it off the road
const ROUGH_DRAG: float = 2.5  # m/s^2 the dirt costs
const WHEELBASE: float = 2.6
const STEER_LOCK: float = 0.55  # rad: full lock
const STEER_OVER: float = 1.2  # full lock at speed asks this much of the grip: held too fast, it pushes wide
const STEER_SPEED: float = 1.5  # rad/s the wheel turns
const STEER_BACK: float = 2.6  # rad/s it centres when let go
const TURN_OVER: float = 1.1  # the car can be turned this much past what the tyres hold (the rest is a slide)
const HAND_GRIP: float = 0.38  # of the side grip with the handbrake on: the back lets go
const HAND_TURN: float = 2.6  # and it rotates this much faster
const HAND_DRAG: float = 3.0  # m/s^2 the handbrake costs
const SLIDE_SPEED: float = 2.5  # m/s sideways: past this the tyres are sliding
const SLIDE_GRIP: float = 0.8  # of the grip left to sliding tyres
const SLIDE_SCRUB: float = 0.5  # /s of the slide that comes off the speed
const REVERSE_HOLD: float = 0.3  # s on the brake at a standstill before it goes into reverse
const FALL: float = 24.0  # m/s^2 down when nothing is under the wheels (off the edge)
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
var wheel: float = 0.0  # replicated: rad the front wheels are turned (+ right)
var rpm: float = 0.0  # replicated: the engine, 0 to 1 (the red line)
var gear: int = 0  # replicated: 0 is first
var pedal: float = 0.0  # replicated: the throttle (+) or the brake (-)
var _throttle: float = 0.0
var _brake: float = 0.0
var _shift_t: float = 0.0
var _reverse_t: float = 0.0
var _body: Node3D
var _last_speed: float = 0.0
var _lean: Vector2 = Vector2.ZERO  # pitch, roll
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
	for prop in ["in_use", "speed", "slip", "synced_xform", "occupants", "progress", "wheel", "rpm", "gear", "pedal"]:
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
	_body = body
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
	# x steer (right +), y throttle (forward +, back is the brake), z handbrake (1/0).
	if not autopilot.is_empty():
		return _autopilot_input()
	if driver == null or not is_instance_valid(driver):
		return Vector3(0.0, 0.0, 1.0)  # nobody at the wheel: it rolls to a stop
	# The keys as they are: where the driver happens to be looking has nothing to do with the car.
	var hand := 1.0 if (driver.input_flags & Player.FLAG_BRACE) != 0 else 0.0
	return Vector3(clampf(driver.input_move.x, -1.0, 1.0), clampf(-driver.input_move.y, -1.0, 1.0), hand)


## The most the front wheels turn at a speed (rad): full lock at a crawl, and at pace about what
## the tyres can use (a little more, so full lock too fast pushes wide).
static func steer_limit(v: float) -> float:
	return minf(STEER_LOCK, atan(STEER_OVER * GRIP * WHEELBASE / maxf(v * v, 1.0)))


## Tests: drive the route by itself (pure pursuit down the middle of the road, braking for bends).
func _autopilot_input() -> Vector3:
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
	var reach := clampf(absf(speed) * 0.55, 6.0, 15.0)
	var look := reach
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
	# The wheel angle whose arc passes through the point ahead, as a share of what the wheel can do.
	var wheel_want := atan(2.0 * WHEELBASE * sin(ang) / maxf(to.length(), 1.0))
	var steer := clampf(-wheel_want / steer_limit(absf(speed)) * 1.3, -1.0, 1.0)
	# Brake for what's coming: every bend in the next stretch has a speed the tyres can hold it at,
	# and the car has to be down to it by the time it gets there (it brakes far gentler than it could).
	var want := MAX_SPEED
	var dist := -here.distance_to(a0)  # the corner just reached is still being taken
	var j := _auto_i - 1
	if j < 1:
		j = _auto_i
		dist = here.distance_to(b0)
	while j < autopilot.size() - 1 and dist < 200.0:
		var d1: Vector3 = flat.call(autopilot[j]) - flat.call(autopilot[j - 1])
		var d2: Vector3 = flat.call(autopilot[j + 1]) - flat.call(autopilot[j])
		if d1.length() > 0.01 and d2.length() > 0.01:
			var bend := absf(d1.signed_angle_to(d2, Vector3.UP))
			if bend > 0.02:
				var r := minf(d1.length(), d2.length()) / bend
				var hold := maxf(6.0, sqrt(0.6 * GRIP * r))
				if bend > 0.6:
					hold = 8.0  # a street corner: a right angle all at once
				want = minf(want, sqrt(hold * hold + 2.0 * 5.5 * maxf(dist - 4.0, 0.0)))
		dist += d2.length()
		j += 1
	var throttle := 1.0 if speed < want - 0.5 else (-0.8 if speed > want + 0.5 else 0.0)
	return Vector3(steer, throttle, 0.0)


## The car, one tick. A real one in outline: an engine pulling through five gears (hard off the
## line, less and less up the box, an automatic shift with a gap in the drive), pedals that take a
## moment to go down, brakes that need distance, air and rolling drag, and tyres with only so much
## grip to share between braking, driving and turning. The wheel turns at its own pace and less at
## speed; ask for more than the tyres have and the car pushes wide, sliding (and scrubbing speed);
## the handbrake lets the back go so it rotates. Off the road the dirt halves the grip.
func _server_drive(delta: float) -> void:
	_bang_cool = maxf(0.0, _bang_cool - delta)
	_skid_cool = maxf(0.0, _skid_cool - delta)
	if not in_use or locked:
		speed = 0.0
		slip = 0.0
		pedal = 0.0
		rpm = 0.12 if in_use else 0.0
		gear = 0
		_throttle = 0.0
		_brake = 0.0
		wheel = move_toward(wheel, 0.0, STEER_SPEED * delta)
		_settle(delta)
		return
	var inp := _driver_input()
	var hand := inp.z > 0.5
	var want_go := maxf(inp.y, 0.0)
	var want_stop := maxf(-inp.y, 0.0)
	# Back on the brake at a standstill, held a moment: reverse.
	if want_stop > 0.1 and speed < 0.6:
		_reverse_t += delta
	elif want_stop < 0.1:
		_reverse_t = 0.0
	var reversing := _reverse_t > REVERSE_HOLD and speed < 0.6
	if reversing:
		want_go = want_stop
		want_stop = 0.0
	elif speed < -0.3 and inp.y > 0.1:
		want_stop = want_go  # rolling backwards with the throttle down: it's the brake first
		want_go = 0.0
	if stall_t > 0.0:
		stall_t -= delta
		want_go = 0.0  # the engine coughs and won't catch
	_throttle = move_toward(_throttle, want_go, (THROTTLE_DOWN if want_go > _throttle else THROTTLE_UP) * delta)
	_brake = move_toward(_brake, want_stop, (BRAKE_DOWN if want_stop > _brake else BRAKE_UP) * delta)
	pedal = _throttle - _brake
	# The gearbox.
	var v := absf(speed)
	_shift_t = maxf(0.0, _shift_t - delta)
	if not reversing and _shift_t <= 0.0:
		if gear < GEAR_TOP.size() - 1 and v > GEAR_TOP[gear] * SHIFT_UP:
			gear += 1
			_shift_t = SHIFT_TIME
		elif gear > 0 and v < GEAR_TOP[gear - 1] * SHIFT_DOWN:
			gear -= 1
			_shift_t = SHIFT_TIME * 0.6
	if reversing:
		gear = 0
	var top: float = REVERSE_SPEED * 1.6 if reversing else GEAR_TOP[gear]
	var rev := clampf(v / top, 0.0, 1.05)
	rpm = lerpf(rpm, maxf(maxf(rev, 0.12), 0.35 * _throttle if v < 4.0 else 0.0), clampf(delta * 14.0, 0.0, 1.0))  # the clutch slips off the line
	# Along the car: the engine, the brakes, the drag.
	var along := 0.0
	if _throttle > 0.0 and _shift_t <= 0.0 and rev < 1.02:
		var torque := clampf(1.0 - 1.7 * (rev - 0.62) * (rev - 0.62), 0.45, 1.0)
		along += _throttle * (REVERSE_PULL if reversing else GEAR_PULL[gear]) * torque * (-1.0 if reversing else 1.0)
	var drag := ROLL + DRAG * v * v + (ENGINE_BRAKE * (1.0 - _throttle) * (1.6 - 0.25 * float(gear)) if v > 1.0 else 0.0)
	var grip := GRIP * (ROUGH_GRIP if rough else 1.0)
	if rough:
		drag += ROUGH_DRAG + (9.0 if v > ROUGH_TOP else 0.0)
	var stop := _brake * BRAKE_FORCE + (HAND_DRAG if hand else 0.0) + drag
	stop = minf(stop, grip + drag)
	along = clampf(along, -grip, grip)  # wheelspin: the tyres can only push so hard
	speed += along * delta
	speed = move_toward(speed, 0.0, stop * delta)
	# The wheel: it turns at its own pace, and less far the faster the car goes.
	var limit := steer_limit(v)
	wheel = move_toward(wheel, inp.x * limit, (STEER_SPEED if absf(inp.x) > 0.05 else STEER_BACK) * delta)
	wheel = clampf(wheel, -limit * 1.15, limit * 1.15)
	# What the tyres have left for turning, after what braking and driving take.
	var used := clampf((absf(along) + _brake * BRAKE_FORCE) / grip, 0.0, 0.92)
	var side_grip := grip * sqrt(1.0 - used * used)
	if hand:
		side_grip *= HAND_GRIP
	if absf(slip) > SLIDE_SPEED:
		side_grip *= SLIDE_GRIP  # tyres that are sliding grip less than tyres that are rolling
	var omega := -speed * tan(wheel) / WHEELBASE
	var omega_max := side_grip * (HAND_TURN if hand else TURN_OVER) / maxf(v, 2.5)
	omega = clampf(omega, -omega_max, omega_max)
	var world := -global_basis.z * speed + global_basis.x * slip
	rotate_y(omega * delta)
	var fwd := -global_basis.z
	var right := global_basis.x
	speed = world.dot(fwd)
	slip = world.dot(right)
	slip = move_toward(slip, 0.0, side_grip * delta)
	speed = move_toward(speed, 0.0, absf(slip) * SLIDE_SCRUB * delta)  # a slide costs speed
	velocity = fwd * speed + right * slip
	velocity.y = _settle(delta)
	var before := Vector2(velocity.x, velocity.z).length()  # the fall is not a crash
	var ahead_before := speed
	move_and_slide()
	var after := Vector3(velocity.x, 0.0, velocity.z)
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
	if absf(slip) > SLIDE_SPEED and v > 6.0 and _skid_cool <= 0.0:
		_skid_cool = 0.45
		_rpc_skid.rpc()


## The ground under the car (a ray down: the body floats, it has no floor of its own): on it, the
## car sits at its height; with nothing there (off the mountain's edge) it falls. Returns m/s up.
func _settle(delta: float) -> float:
	var from := global_position + Vector3.UP * 1.0
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 1.5, ChainBody.LAYER_WORLD)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		_vy -= FALL * delta
		return _vy
	_vy = 0.0
	var gy: float = (hit.position as Vector3).y + 0.02
	global_position.y = move_toward(global_position.y, gy, 6.0 * delta)
	return 0.0


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
	_wheel_spin += speed * delta / 0.34
	for k in _wheels.size():
		var w := _wheels[k]
		w.rotation.y = -wheel if k < 2 else 0.0
		(w.get_child(0) as Node3D).rotation.x = -_wheel_spin
	# The body on its springs: the nose up under power and down under the brakes, and it leans out
	# of a bend.
	var accel := clampf((speed - _last_speed) / maxf(delta, 0.001), -14.0, 14.0)
	_last_speed = speed
	var side := clampf(speed * speed * tan(wheel) / WHEELBASE, -12.0, 12.0)
	_lean = _lean.lerp(Vector2(accel * 0.0065, side * 0.007 + slip * 0.01), clampf(delta * 6.0, 0.0, 1.0))
	if _body != null:
		_body.rotation = Vector3(_lean.x, 0.0, _lean.y)
		_body.position.y = -absf(_lean.x) * 0.25
	_brake_mat.emission_energy_multiplier = 3.0 if (in_use and pedal < -0.08) else 0.6
	if in_use:
		Sfx.start_loop(_engine)
		_engine.pitch_scale = 0.5 + 1.25 * clampf(rpm, 0.0, 1.05)
		_engine.volume_db = -9.0 + 5.0 * clampf(pedal, 0.0, 1.0)
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
	wheel = 0.0
	gear = 0
	_throttle = 0.0
	_brake = 0.0
	_reverse_t = 0.0
	stall_t = 0.0
	rough = false
