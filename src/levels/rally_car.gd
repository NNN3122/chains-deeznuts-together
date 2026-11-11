class_name RallyCar
extends CharacterBody3D
## A rally car from Kettle Hollow's night rally, keys still in it (Level 4, the chase). Two of the
## Line ride in each: the driver (W the throttle, S the brake, A/D to steer, Ctrl the handbrake, and
## the gear lever: E up, Q down, R reverse, N neutral, 1-6 straight to a gear; M hands the box to an
## automatic, where S held at a standstill is reverse) and the navigator, who has the map and calls
## the turns.
##
## The server drives it from the driver's input packets with the model racing games have used
## since Marco Monster's "Car Physics for Games": a single-track ("bicycle") car whose front and
## rear tyres each make a side force from their slip angle (the angle between where the tyre points
## and where it is going) along a curve that climbs to a peak and falls away a little past it, a
## friction circle (what a tyre spends on braking or driving it cannot spend on turning), load that
## shifts forward under the brakes and back under power, and a yaw inertia those forces have to
## turn. Understeer, lift-off rotation, a handbrake slide and catching it with opposite lock all
## fall out of that. Below walking pace the slip-angle maths goes singular, so there the car turns
## by geometry (the kinematic bicycle) and the two are blended.
##
## A keyboard is all-or-nothing, so the steering is assisted the way keyboard steering is in those
## games: the wheel turns at its own pace toward where the key asks, but never further than the
## angle at which the front tyres grip best for the way the car is actually moving (so holding a
## key gives the most turn there is instead of a ploughing slide, and in a slide the same rule is
## opposite lock); let go and the wheel castors back, part of the way toward the slide.
##
## Drawing: the body is stepped by physics 60 times a second, and frames are drawn at any rate, so
## everything you see (shell, wheels, lamps) hangs off a node that every frame is put between the
## last two physics poses (`view_xform`). The camera follows that, never the stepped body: a camera
## chasing a stepping car is what made it judder. Pose and state are replicated to clients.

const WIDTH: float = 1.9
const LENGTH: float = 4.1
const HEIGHT: float = 1.4
# The chassis.
const MASS: float = 1250.0  # kg
const YAW_INERTIA: float = 1750.0  # kg m^2
const CG_FRONT: float = 1.25  # m from the centre of gravity to the front axle
const CG_REAR: float = 1.35  # m to the rear axle
const CG_HEIGHT: float = 0.4  # m: how much weight braking and power move
const WHEELBASE: float = 2.6
const GRAVITY: float = 9.81
# The tyres: side force = grip x load x sin(C atan(B x slip angle)), which peaks at TYRE_PEAK.
const GRIP_FRONT: float = 1.7  # peak friction: a racing game's tyres, not a road car's (1.1 felt like ice to the user)
const GRIP_REAR: float = 2.0  # more at the back: it pushes wide before it spins
const TYRE_USE: float = 0.92  # of a tyre's grip that braking or driving may take: the rest is always there to steer with
const CIRCLE_SHARE: float = 0.7  # of the brake or drive force that counts against side grip: flat on the brakes it still turns
const TYRE_B: float = 11.0
const TYRE_C: float = 1.5
const TYRE_PEAK: float = 0.157  # rad (9 degrees): the slip angle with the most grip
const ROUGH_GRIP: float = 0.55  # of the grip off the road
const ROUGH_DRAG: float = 2.5  # m/s^2 the dirt costs
const ROUGH_TOP: float = 9.0  # m/s past which it costs a lot more
const LOW_SPEED: float = 2.0  # m/s: below this the car turns by geometry alone
const HIGH_SPEED: float = 7.0  # m/s: above this by tyre forces alone
const SUBSTEPS: int = 4  # tyre forces are stiff: four small steps a tick keep them calm
# The engine and the box.
const MAX_SPEED: float = 38.0  # m/s where top gear runs out (about 137 km/h)
const REVERSE_SPEED: float = 7.0
const GEARS: int = 6
const GEAR_REVERSE: int = -1
const GEAR_NEUTRAL: int = 0
const GEAR_TOP: Array[float] = [11.5, 18.0, 24.0, 29.5, 34.5, 39.5]  # m/s at the red line in first to sixth
const GEAR_PULL: Array[float] = [9.0, 6.8, 5.1, 3.9, 2.9, 2.05]  # m/s^2 at peak torque in each gear (0-100 km/h in about 6 s)
const CLUTCH_FLOOR: Array[float] = [0.85, 0.55, 0.36, 0.26, 0.2, 0.16]  # of peak torque with no revs at all: the clutch slips first away from a standstill, sixth barely creeps
const REVERSE_PULL: float = 3.5
const OVER_REV: float = 14.0  # m/s^2 the engine holds the car back with per red line's worth past it (a gear too low for the speed)
const OVER_REV_MAX: float = 5.0  # m/s^2 at most
const REVERSE_SHIFT_SPEED: float = 3.0  # m/s forward past which the lever won't go into reverse
# What the lever can be asked (Player sends these from the driver's keys; see PlayerInput.GEAR_ACTIONS).
const REQ_UP: int = 1
const REQ_DOWN: int = 2
const REQ_REVERSE: int = 3
const REQ_NEUTRAL: int = 4
const REQ_FIRST: int = 5  # 5..10: first to sixth
const REQ_AUTO: int = 11  # manual <-> automatic
const SHIFT_UP: float = 0.93  # of the red line: up a gear
const SHIFT_DOWN: float = 0.62  # of the gear below's red line: down one
const SHIFT_TIME: float = 0.14  # s with no drive while it changes
const THROTTLE_DOWN: float = 7.0  # /s the pedal goes down (a key is all or nothing: a foot isn't)
const THROTTLE_UP: float = 10.0
const BRAKE_DOWN: float = 9.0
const BRAKE_UP: float = 12.0
const BRAKE_FORCE: float = 12.5  # m/s^2 asked for with the pedal on the floor (the tyres decide what it gets)
const ENGINE_BRAKE: float = 0.55  # m/s^2 off the throttle (more in the low gears): lift and it rolls on a long way
const ROLL: float = 0.15  # m/s^2 of rolling drag
const DRAG: float = 0.00095  # /m of air drag (x speed squared)
const REVERSE_HOLD: float = 0.3  # s on the brake at a standstill before it goes into reverse
# The wheel in your hands.
const STEER_LOCK: float = 0.6  # rad: full lock
const STEER_SPEED: float = 2.4  # rad/s the wheel turns at a crawl
const STEER_SPEED_FAST: float = 1.0  # rad/s at pace: an eighth of a second to the tyres' best angle
const FRONT_BALANCE: float = 1.05  # the front tyres never turn the car harder than this much of what the rears can hold (hard on the brakes the weight is all on the front: it used to swing the tail out)
const WHEEL_SHOWN: float = 1.6  # the front wheels are drawn turned this much further than they are (at pace the real angle is a few degrees and reads as nothing)
const STEER_BACK: float = 3.2  # rad/s it comes back when let go
const STEER_SLIP: float = 0.125  # rad: a key held is this much front slip angle, just short of the tyres' peak
const COUNTER_ASSIST: float = 0.55  # hands off in a slide, the wheel castors this far toward the slide (opposite lock)
const STABILITY_FREE: float = 0.085  # rad (5 degrees) of body slip the stability assist leaves alone
const STABILITY_PULL: float = 14.0  # rad/s^2 of turn back per rad past it
const STABILITY_DAMP: float = 2.5  # /s it takes off the spin while it works
const STABILITY_BACK: float = 0.6  # s after the handbrake before it is all back
const HAND_GRIP: float = 0.32  # of the rear side grip with the handbrake on: the back lets go
const HAND_BRAKE: float = 0.55  # of the rear tyres' grip the locked wheels brake with
const SKID_SLIP: float = 0.24  # rad: an axle past this is audibly sliding
const FALL: float = 24.0  # m/s^2 down when nothing is under the wheels (off the edge)
const BANG_SPEED: float = 7.0  # m/s lost in one hit that bangs
const CRASH_SPEED: float = 10.0  # m/s lost in one hit that wrecks it for a moment (a tree, a wall, head on)
const CRASH_STALL: float = 2.6  # s the engine's dead after a crash: the Strider closes in
const SEAT_DRIVER: Vector3 = Vector3(-0.42, 0.45, 0.15)
const SEAT_NAVIGATOR: Vector3 = Vector3(0.42, 0.45, 0.15)
const SEAT_BACK: Vector3 = Vector3(0.0, 0.45, 1.1)
const LIVERIES: Array[Color] = [Color(0.85, 0.12, 0.08), Color(0.08, 0.32, 0.8), Color(0.92, 0.72, 0.08), Color(0.1, 0.55, 0.22), Color(0.88, 0.88, 0.85)]

var index: int = 0
var in_use: bool = false  # replicated: carrying some of the Line
var speed: float = 0.0  # replicated: m/s along the nose
var slip: float = 0.0  # replicated: m/s sideways, + to the right (the car sliding)
var synced_xform: Transform3D = Transform3D.IDENTITY  # replicated
var occupants: PackedInt32Array = PackedInt32Array()  # replicated: peer ids, driver first; -1 the Ballast
var progress: float = 0.0  # replicated: metres along the town's route it has got to (Town)
var wheel: float = 0.0  # replicated: rad the front wheels are turned (+ right)
var rpm: float = 0.0  # replicated: the engine, 0 to 1 (the red line)
var gear: int = 1  # replicated: -1 reverse, 0 neutral, 1 to 6
var auto_box: bool = false  # replicated: the box changes gear by itself (M; the driver's lever does nothing then)
var pedal: float = 0.0  # replicated: the throttle (+) or the brake (-)
var skid: float = 0.0  # replicated: 0..1, how hard the tyres are sliding (the sound)
var yaw_rate: float = 0.0  # server: rad/s, + turning left
var finished: bool = false  # server: over the finish line
var locked: bool = false  # server: held on the line (the countdown), or in the Strider's hands
var driver: Player  # server
var autopilot: Array = []  # server, tests: route points to drive by itself
var debug_input: Variant = null  # tests: a Vector3 (steer, throttle, handbrake) instead of the driver's keys
var seats: Array[Node3D] = []
var stall_t: float = 0.0  # server: s the engine stays dead after a crash
var rough: bool = false  # server, set by the Town each tick: off the road's surface
var crashes: int = 0  # server: tests
var _vis: Node3D  # everything drawn, put between physics poses every frame
var _prev_xform: Transform3D = Transform3D.IDENTITY
var _cur_xform: Transform3D = Transform3D.IDENTITY
var _body: Node3D
var _wheel_spin: float = 0.0
var _wheels: Array[Node3D] = []
var _engine: AudioStreamPlayer3D
var _skid_loop: AudioStreamPlayer3D
var _brake_mat: StandardMaterial3D
var _bang_cool: float = 0.0
var _auto_i: int = 0
var _vy: float = 0.0  # server: m/s up (falling off the mountain)
var _throttle: float = 0.0
var _brake: float = 0.0
var _shift_t: float = 0.0
var _reverse_t: float = 0.0
var _ax: float = 0.0  # server: m/s^2 along the car, smoothed (the weight it moves)
var _assist: float = 1.0  # server: 0..1, how much of the stability assist is on
var _last_speed: float = 0.0
var _last_yaw: float = 0.0
var _gear_seen: int = 1  # every peer: the gear last heard going in
var _turn_vis: float = 0.0  # every peer: rad/s the body is seen to turn at
var _lean: Vector2 = Vector2.ZERO  # pitch, roll


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
	for prop in ["in_use", "speed", "slip", "synced_xform", "occupants", "progress", "wheel", "rpm", "gear", "auto_box", "pedal", "skid"]:
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
	_vis = Node3D.new()
	_vis.name = "Vis"
	_vis.top_level = true
	add_child(_vis)
	_build_visual()
	for p: Vector3 in [SEAT_DRIVER, SEAT_NAVIGATOR, SEAT_BACK]:
		var s := Node3D.new()
		s.position = p
		add_child(s)
		seats.append(s)
	_engine = Sfx.loop_player("engine", -6.0, 45.0)
	_engine.position = Vector3(0.0, 0.6, -1.4)
	_vis.add_child(_engine)
	_skid_loop = Sfx.loop_player("scrape", -40.0, 40.0)
	_skid_loop.position = Vector3(0.0, 0.2, 1.0)
	_vis.add_child(_skid_loop)
	snap_view()


func _build_visual() -> void:
	var paint := LIVERIES[index % LIVERIES.size()]
	var body := Sculpt.put(_vis, car_mesh(paint), Sculpt.material(0.35, 0.0, 0.0, 0.0, 0.05))
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
		body.add_child(n)
	var tyre_mat := StandardMaterial3D.new()
	tyre_mat.albedo_color = Color(0.04, 0.04, 0.045)
	tyre_mat.roughness = 0.9
	var rim := StandardMaterial3D.new()
	rim.albedo_color = Color(0.6, 0.6, 0.62)
	rim.metallic = 0.8
	rim.roughness = 0.35
	for k in 4:
		var pivot := Node3D.new()
		pivot.position = Vector3((-1.0 if k % 2 == 0 else 1.0) * 0.86, 0.34, -1.3 if k < 2 else 1.3)
		_vis.add_child(pivot)
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
		t.material_override = tyre_mat
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
	# Headlamps: the only light most of the way, so they matter. On the shell, so they dip and
	# lean with it.
	for s: float in [-1.0, 1.0]:
		var lamp := SpotLight3D.new()
		lamp.position = Vector3(s * 0.62, 0.72, -LENGTH * 0.5 - 0.05)
		lamp.rotation.x = -0.06
		lamp.light_energy = 5.0
		lamp.spot_range = 46.0
		lamp.spot_angle = 28.0
		lamp.spot_attenuation = 0.7
		lamp.light_color = Color(1.0, 0.93, 0.78)
		lamp.light_volumetric_fog_energy = 0.6
		body.add_child(lamp)
		var lens := MeshInstance3D.new()
		var lm := SphereMesh.new()
		lm.radius = 0.11
		lm.height = 0.12
		lm.radial_segments = 10
		lm.rings = 5
		lens.mesh = lm
		lens.position = lamp.position + Vector3(0.0, 0.0, 0.04)
		lens.material_override = LevelKit.mat("glow")
		body.add_child(lens)
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
		body.add_child(tail)


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
	_prev_xform = _cur_xform
	_cur_xform = global_transform
	if _prev_xform.origin.distance_to(_cur_xform.origin) > 6.0:
		_prev_xform = _cur_xform  # put somewhere else (parked, a respawn): no smear across the map
	var yaw := global_rotation.y
	_turn_vis = lerpf(_turn_vis, angle_difference(_last_yaw, yaw) / maxf(delta, 0.001), 0.35)
	_last_yaw = yaw
	_animate(delta)


## Every frame: everything drawn sits between the last two physics poses, by how far this frame is
## into the tick. This is the whole of "smooth": the body itself only moves 60 times a second.
func _process(_delta: float) -> void:
	if _vis != null:
		_vis.global_transform = view_xform()


## Where the car is drawn this frame (cameras and anything shown on it follow this).
func view_xform() -> Transform3D:
	if not is_inside_tree():
		return _cur_xform
	return _prev_xform.interpolate_with(_cur_xform, clampf(Engine.get_physics_interpolation_fraction(), 0.0, 1.0))  # worked out here, so whoever asks first in a frame gets this frame's


## Its velocity over the ground, world space (the camera looks where it is going).
func ground_velocity() -> Vector3:
	var b := view_xform().basis
	return -b.z * speed + b.x * slip


## Drop the drawn car onto the body at once (after it has been put somewhere).
func snap_view() -> void:
	_prev_xform = global_transform
	_cur_xform = global_transform
	if _vis != null:
		_vis.global_transform = global_transform


func _driver_input() -> Vector3:
	# x steer (right +), y throttle (forward +, back is the brake), z handbrake (1/0).
	if debug_input != null:
		return debug_input
	if not autopilot.is_empty():
		return _autopilot_input()
	if driver == null or not is_instance_valid(driver):
		return Vector3(0.0, 0.0, 1.0)  # nobody at the wheel: it rolls to a stop
	# A seated player's packets carry the keys as they are (Player._send_input), each axis on its
	# own: W with A is full throttle and full left, not 70% of each.
	# A pedal key is all of the pedal at any strength (Remote Controls sends 0.45 for the first half
	# second of a hold: that was half a brake when it mattered); the pedals ramp by themselves.
	var hand := 1.0 if (driver.input_flags & Player.FLAG_BRACE) != 0 else 0.0
	var feet := -driver.input_move.y
	return Vector3(clampf(driver.input_move.x, -1.0, 1.0), signf(feet) if absf(feet) > 0.2 else 0.0, hand)


## Server: the gear lever (a REQ_ code from the driver's keys). Manual: up and down go one place
## through R, N, 1..6; R, N and the numbers go straight there. Reverse won't go in while the car is
## still rolling forward at any pace. A gear too low for the speed is allowed: the engine screams
## past its red line and holds the car back. With the automatic on the lever does nothing.
func server_shift(req: int) -> void:
	if req == REQ_AUTO:
		auto_box = not auto_box
		_reverse_t = 0.0
		if auto_box and gear < 1:
			gear = 1
		_rpc_lever.rpc(1 if auto_box else 2)
		return
	if auto_box:
		_rpc_lever.rpc(3)
		return
	var want := gear
	if req == REQ_UP:
		want = mini(gear + 1, GEARS)
	elif req == REQ_DOWN:
		want = maxi(gear - 1, GEAR_REVERSE)
	elif req == REQ_REVERSE:
		want = GEAR_REVERSE
	elif req == REQ_NEUTRAL:
		want = GEAR_NEUTRAL
	elif req >= REQ_FIRST and req < REQ_FIRST + GEARS:
		want = req - REQ_FIRST + 1
	if want == gear:
		return
	if want == GEAR_REVERSE and speed > REVERSE_SHIFT_SPEED:
		_rpc_lever.rpc(0)
		return
	gear = want
	_shift_t = SHIFT_TIME


## What the lever has to say, to whoever is driving this car.
@rpc("authority", "call_local", "reliable")
func _rpc_lever(what: int) -> void:
	if occupants.is_empty() or occupants[0] != multiplayer.get_unique_id():
		return
	match what:
		0:
			Sfx.play_at(self, "scrape", global_position + Vector3.UP, -6.0, 1.6, 20.0)
			GameState.post_message_local("TOO FAST FOR REVERSE. BRAKE FIRST.", 1.6)
		1:
			GameState.post_message_local("GEARBOX: AUTOMATIC (M for manual)", 2.0)
		2:
			GameState.post_message_local("GEARBOX: MANUAL. E up, Q down, R reverse, N neutral, 1-6.", 2.6)
		3:
			GameState.post_message_local("IT'S IN AUTOMATIC. M for manual.", 1.6)


## The tyre curve: 0 at no slip, 1 at TYRE_PEAK, a little less past it (a sliding tyre).
static func tyre(slip_angle: float) -> float:
	return sin(TYRE_C * atan(TYRE_B * slip_angle))


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
	# The wheel angle whose arc passes through the point ahead, as a share of full lock.
	var wheel_want := atan(2.0 * WHEELBASE * sin(ang) / maxf(to.length(), 1.0))
	var steer := clampf(-wheel_want / STEER_LOCK * 1.25, -1.0, 1.0)
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
				var hold := maxf(6.0, sqrt(0.6 * GRAVITY * r))
				if bend > 0.6:
					hold = 8.0  # a street corner: a right angle all at once
				want = minf(want, sqrt(hold * hold + 2.0 * 5.5 * maxf(dist - 4.0, 0.0)))
		dist += d2.length()
		j += 1
	var throttle := 1.0 if speed < want - 0.5 else (-0.8 if speed > want + 0.5 else 0.0)
	return Vector3(steer, throttle, 0.0)


## The car, one tick (see the top of the file for the model).
func _server_drive(delta: float) -> void:
	_bang_cool = maxf(0.0, _bang_cool - delta)
	if in_use and driver != null and is_instance_valid(driver):
		for req in driver.take_gear_requests():
			server_shift(req)
	if not in_use or locked:
		speed = 0.0
		slip = 0.0
		yaw_rate = 0.0
		pedal = 0.0
		skid = 0.0
		rpm = 0.12 if in_use else 0.0
		if not in_use:
			gear = 1
		_throttle = 0.0
		_brake = 0.0
		_ax = 0.0
		wheel = move_toward(wheel, 0.0, STEER_BACK * delta)
		_settle(delta)
		return
	var inp := _driver_input()
	var hand := inp.z > 0.5
	var want_go := maxf(inp.y, 0.0)
	var want_stop := maxf(-inp.y, 0.0)
	var auto := auto_box or not autopilot.is_empty()
	var reversing := false
	if auto:
		# Automatic: back on the brake at a standstill, held a moment, is reverse (S is its throttle).
		if want_stop > 0.1 and speed < 0.6:
			_reverse_t += delta
		elif want_stop < 0.1:
			_reverse_t = 0.0
		reversing = _reverse_t > REVERSE_HOLD and speed < 0.6
		if reversing:
			gear = GEAR_REVERSE
			want_go = want_stop
			want_stop = 0.0
		else:
			if gear < 1:
				gear = 1
			if speed < -0.3 and inp.y > 0.1:
				want_stop = want_go  # rolling backwards with the throttle down: it's the brake first
				want_go = 0.0
	else:
		# Manual: the lever says which way W goes. S is only ever the brake.
		_reverse_t = 0.0
		reversing = gear == GEAR_REVERSE
		if want_go > 0.1 and ((gear > 0 and speed < -0.3) or (reversing and speed > 0.3)):
			want_stop = maxf(want_stop, want_go)  # still rolling the other way: the tyres stop it first
			want_go = 0.0
	if stall_t > 0.0:
		stall_t -= delta
		want_go = 0.0  # the engine coughs and won't catch
	_throttle = move_toward(_throttle, want_go, (THROTTLE_DOWN if want_go > _throttle else THROTTLE_UP) * delta)
	_brake = move_toward(_brake, want_stop, (BRAKE_DOWN if want_stop > _brake else BRAKE_UP) * delta)
	pedal = _throttle - _brake
	# The gearbox.
	var pace := absf(speed)
	_shift_t = maxf(0.0, _shift_t - delta)
	if auto and not reversing and _shift_t <= 0.0:
		if gear < GEARS and pace > GEAR_TOP[gear - 1] * SHIFT_UP:
			gear += 1
			_shift_t = SHIFT_TIME
		elif gear > 1 and pace < GEAR_TOP[gear - 2] * SHIFT_DOWN:
			gear -= 1
			_shift_t = SHIFT_TIME * 0.6
	var in_gear := gear != GEAR_NEUTRAL
	var top: float = REVERSE_SPEED * 1.6 if reversing else GEAR_TOP[maxi(gear, 1) - 1]
	var over := maxf(pace / top - 1.0, 0.0) if in_gear else 0.0  # how far past the red line the wheels are turning the engine
	var rev := clampf(pace / top, 0.0, 1.05) if in_gear else 0.12 + 0.9 * _throttle  # out of gear it revs free
	rpm = lerpf(rpm, maxf(maxf(rev, 0.12), 0.35 * _throttle if pace < 4.0 else 0.0), clampf(delta * 14.0, 0.0, 1.0))  # the clutch slips off the line
	# What the engine and the brakes ask of the tyres, as accelerations of the whole car.
	var drive := 0.0
	if in_gear and _throttle > 0.0 and _shift_t <= 0.0 and rev < 1.02:
		# The torque curve: most of it from the middle of the revs up, falling away near the red
		# line, and little at the bottom (a gear too high bogs). Off the line the clutch slips to
		# hold the revs up: in first that is nearly everything, in sixth nearly nothing.
		var lug := lerpf(0.3, 1.0, smoothstep(0.05, 0.4, rev))
		var torque := clampf((1.0 - 1.7 * (rev - 0.62) * (rev - 0.62)) * lug, CLUTCH_FLOOR[0] if reversing else CLUTCH_FLOOR[gear - 1], 1.0)
		drive = _throttle * (REVERSE_PULL if reversing else GEAR_PULL[gear - 1]) * torque * (-1.0 if reversing else 1.0)
	var engine_drag := 0.0  # m/s^2 the engine holds the car back with: off the throttle (more in the low gears), and hard past the red line
	if in_gear:
		engine_drag = ENGINE_BRAKE * (1.0 - _throttle) * (1.5 if reversing else 1.75 - 0.22 * float(gear)) + minf(over * OVER_REV, OVER_REV_MAX)
	var surface := ROUGH_GRIP if rough else 1.0
	var mu_f := GRIP_FRONT * surface
	var mu_r := GRIP_REAR * surface
	var u := speed  # along the nose
	var v := -slip  # to the left
	var r := yaw_rate  # turning left
	var steer_in := -inp.x  # left + (a part-strength key, a remote desktop's first half second of a hold, is that part of the turn: it used to be the square of it, a fifth)
	var wl := -wheel  # the front wheels' angle, left +
	var turned := 0.0
	var worst := 0.0
	var h := delta / float(SUBSTEPS)
	for i in SUBSTEPS:
		var dyn := smoothstep(LOW_SPEED, HIGH_SPEED, u)  # 0: by geometry (and all of reverse); 1: by tyre forces
		var ahead := maxf(u, 1.0)
		# The wheel: toward the key, never past the angle the front tyres grip best at for the way
		# the car is going; hands off, it castors back (and toward a slide).
		var flow := atan2(v + CG_FRONT * r, ahead)  # which way the front axle is really travelling
		# At pace the key asks for a front slip angle, up to the one with the most grip.
		var at_pace := flow * COUNTER_ASSIST if absf(steer_in) < 0.05 else flow + steer_in * STEER_SLIP
		var target := clampf(lerpf(steer_in * STEER_LOCK, at_pace, dyn), -STEER_LOCK, STEER_LOCK)
		var rate := STEER_BACK if absf(steer_in) < 0.05 else lerpf(STEER_SPEED, STEER_SPEED_FAST, smoothstep(4.0, 24.0, absf(u)))
		wl = move_toward(wl, target, rate * h)
		# The load on each axle: it moves forward under the brakes, back under power.
		var shift := MASS * _ax * CG_HEIGHT / WHEELBASE
		var load_f := maxf(MASS * GRAVITY * CG_REAR / WHEELBASE - shift, MASS * GRAVITY * 0.1)
		var load_r := maxf(MASS * GRAVITY * CG_FRONT / WHEELBASE + shift, MASS * GRAVITY * 0.1)
		# Along the tyres: four-wheel drive, brakes biased to the front, the handbrake on the rears,
		# none of them more than the tyre has (which is the traction control and the ABS).
		var way := signf(u) if absf(u) > 0.05 else 0.0
		# Drive and brakes go to each axle in proportion to the grip it has right now (four-wheel
		# drive with a centre diff; brakes with the balance a modern car's electronics keep), and
		# never more than TYRE_USE of it: both ends reach their limit together, and there is always
		# something left to steer with. That is the ABS and the traction control.
		var have_f := mu_f * load_f
		var have_r := mu_r * load_r
		var asked := MASS * (drive - way * _brake * BRAKE_FORCE)
		var share := clampf(asked / (have_f + have_r), -TYRE_USE, TYRE_USE)
		var fx_f := share * have_f
		var fx_r := share * have_r
		if hand:
			fx_r = clampf(fx_r - way * HAND_BRAKE * have_r, -have_r, have_r)
		# Across them: from each axle's slip angle, with what the friction circle has left.
		var slip_f := wl - atan2(v + CG_FRONT * r, ahead)
		var slip_r := -atan2(v - CG_REAR * r, ahead)
		var left_f := sqrt(maxf(1.0 - pow(CIRCLE_SHARE * fx_f / (mu_f * load_f), 2.0), 0.06))
		var left_r := sqrt(maxf(1.0 - pow(CIRCLE_SHARE * fx_r / (mu_r * load_r), 2.0), 0.06)) * (HAND_GRIP if hand else 1.0)
		var fy_f := mu_f * load_f * left_f * tyre(slip_f) * dyn  # (slow, it turns by geometry: no slip, no side force)
		var fy_r := mu_r * load_r * left_r * tyre(slip_r) * dyn
		if _assist > 0.0:
			var most := CG_REAR * mu_r * load_r * left_r / CG_FRONT * FRONT_BALANCE / _assist
			fy_f = clampf(fy_f, -most, most)
		# The stability assist: once the body is more than a few degrees out of line with the way
		# it is going, it is turned back toward it (what the electronics do with single brakes).
		# The handbrake switches it off, and it comes back in over a moment after.
		_assist = 0.0 if hand else minf(1.0, _assist + h / STABILITY_BACK)
		var out := atan2(v, ahead)
		var settle_spin := (signf(out) * maxf(absf(out) - STABILITY_FREE, 0.0) * STABILITY_PULL - (r - u * tan(wl) / WHEELBASE) * STABILITY_DAMP * clampf((absf(out) - STABILITY_FREE) * 12.0, 0.0, 1.0)) * _assist * dyn
		# Drag: rolling, the air, the engine off the throttle, the dirt.
		var resist := ROLL + DRAG * u * u + (engine_drag if absf(u) > 1.0 else 0.0)
		if rough:
			resist += ROUGH_DRAG + (9.0 if absf(u) > ROUGH_TOP else 0.0)
		var along := (fx_f * cos(wl) + fx_r - fy_f * sin(wl)) / MASS - way * resist
		var across := (fy_f * cos(wl) + fx_f * sin(wl) + fy_r) / MASS
		var spin := (CG_FRONT * (fy_f * cos(wl) + fx_f * sin(wl)) - CG_REAR * fy_r) / YAW_INERTIA + settle_spin
		_ax = lerpf(_ax, along, 0.15)
		var u_next := u + (along + r * v) * h
		if u * u_next < 0.0 and absf(drive) < 0.01:
			u_next = 0.0  # the brakes stop it: they don't push it backwards
		v += (across - r * u) * h
		r += spin * h
		u = u_next
		# Slow, it turns by geometry: the rear axle follows the front.
		var r_geo := u * tan(wl) / WHEELBASE
		r = lerpf(r_geo, r, dyn)
		v = lerpf(r_geo * CG_REAR, v, dyn)
		turned += r * h
		worst = maxf(worst, maxf(absf(slip_f), absf(slip_r)) * dyn)
	if absf(u) < 0.05 and absf(drive) < 0.01:
		u = 0.0
		v = 0.0
		r = 0.0
	rotate_y(turned)
	wheel = -wl
	yaw_rate = r
	var target_skid := clampf((worst - SKID_SLIP) / 0.2, 0.0, 1.0) if absf(u) > 5.0 else 0.0
	skid = lerpf(skid, target_skid, clampf(delta * 10.0, 0.0, 1.0))
	var fwd := -global_basis.z
	var right := global_basis.x
	velocity = fwd * u - right * v
	velocity.y = _settle(delta)
	var before := Vector2(velocity.x, velocity.z).length()  # the fall is not a crash
	move_and_slide()
	var after := Vector3(velocity.x, 0.0, velocity.z)
	speed = after.dot(fwd)
	slip = after.dot(right)
	var lost := maxf(before - after.length(), absf(u) - absf(speed))  # into something, even at an angle
	if lost > 1.0:
		yaw_rate *= 0.5  # a hit takes the turn out of it too
	if lost > CRASH_SPEED and stall_t <= 0.0:
		stall_t = CRASH_STALL
		crashes += 1
		_bang_cool = 0.6
		_rpc_crash.rpc(lost)
	elif lost > BANG_SPEED and _bang_cool <= 0.0:
		_bang_cool = 0.6
		_rpc_bang.rpc(lost)


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


func _local_inside() -> bool:
	return occupants.has(multiplayer.get_unique_id())


## Every peer, every physics tick: the wheels, the body on its springs, the lamps, the sounds.
func _animate(delta: float) -> void:
	_wheel_spin += speed * delta / 0.34
	for k in _wheels.size():
		var w := _wheels[k]
		w.rotation.y = clampf(-wheel * WHEEL_SHOWN, -STEER_LOCK, STEER_LOCK) if k < 2 else 0.0
		(w.get_child(0) as Node3D).rotation.x = -_wheel_spin
	# The body on its springs: the nose up under power and down under the brakes, and it leans out
	# of a bend (by how hard it is really turning).
	var accel := clampf((speed - _last_speed) / maxf(delta, 0.001), -12.0, 12.0)
	_last_speed = speed
	var side := clampf(speed * _turn_vis, -12.0, 12.0)  # m/s^2 toward the inside of the bend, + left
	_lean = _lean.lerp(Vector2(accel * 0.0055, -side * 0.0065), clampf(delta * 7.0, 0.0, 1.0))
	if _body != null:
		_body.rotation = Vector3(_lean.x, 0.0, _lean.y)
		_body.position.y = -absf(_lean.x) * 0.2
	_brake_mat.emission_energy_multiplier = 3.0 if (in_use and pedal < -0.08) else 0.6
	if gear != _gear_seen:
		_gear_seen = gear
		if in_use:
			Sfx.play_at(self, "click", global_position + Vector3.UP * 0.6, -7.0, 0.55, 18.0)  # the lever going home
	if in_use:
		Sfx.start_loop(_engine)
		_engine.pitch_scale = 0.5 + 1.25 * clampf(rpm, 0.0, 1.05)
		_engine.volume_db = -9.0 + 5.0 * clampf(pedal, 0.0, 1.0)
		Sfx.start_loop(_skid_loop)
		_skid_loop.volume_db = lerpf(-50.0, -7.0, clampf(skid, 0.0, 1.0))
		_skid_loop.pitch_scale = 1.15 + 0.3 * clampf(absf(speed) / MAX_SPEED, 0.0, 1.0)
	else:
		if _engine.playing:
			_engine.stop()
		if _skid_loop.playing:
			_skid_loop.stop()


## Server: put it at `at`, stopped.
func server_park(at: Transform3D) -> void:
	global_transform = at
	synced_xform = at
	speed = 0.0
	slip = 0.0
	yaw_rate = 0.0
	velocity = Vector3.ZERO
	_auto_i = 0
	_vy = 0.0
	_ax = 0.0
	wheel = 0.0
	gear = 1
	_shift_t = 0.0
	skid = 0.0
	_throttle = 0.0
	_brake = 0.0
	_reverse_t = 0.0
	stall_t = 0.0
	rough = false
	snap_view()
