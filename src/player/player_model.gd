class_name PlayerModel
extends Node3D
## A DEEZ Industrial Fasteners new hire: an articulated body (pelvis, spine, neck, head, two-bone
## arms and legs) built from primitives and animated procedurally from movement alone, so every
## peer animates identically from replicated state.
## Walk/run cycles are distance-driven (feet don't skate), knees bend on the swing, the pelvis bobs
## and sways, the torso counter-twists, the body leans into acceleration and turns, the head stays
## level and looks where you aim, landings compress like a spring. Joints ease toward their targets
## at per-limb rates instead of snapping.

signal footstep(strength: float)
signal landed(strength: float)

const SCALE: float = 0.93
const SKIN_TONES: Array[Color] = [
	Color(0.93, 0.76, 0.62), Color(0.76, 0.55, 0.41), Color(0.52, 0.36, 0.25),
	Color(0.87, 0.68, 0.52), Color(0.4, 0.27, 0.19), Color(0.96, 0.82, 0.7),
]
const VEST_COLORS: Array[Color] = [
	Color(1.0, 0.42, 0.04), Color(0.72, 0.92, 0.08), Color(0.1, 0.6, 0.95),
	Color(0.95, 0.18, 0.4), Color(0.6, 0.32, 0.95), Color(1.0, 0.8, 0.08),
]
const HAIR_COLORS: Array[Color] = [
	Color(0.12, 0.08, 0.05), Color(0.35, 0.22, 0.12), Color(0.05, 0.04, 0.04), Color(0.55, 0.4, 0.22),
]

var pelvis: Node3D
var spine: Node3D
var chest: Node3D
var neck: Node3D
var head: Node3D
var hat: Node3D
var thigh_l: Node3D
var thigh_r: Node3D
var knee_l: Node3D
var knee_r: Node3D
var ankle_l: Node3D
var ankle_r: Node3D
var shoulder_l: Node3D
var shoulder_r: Node3D
var elbow_l: Node3D
var elbow_r: Node3D
var hand_r: Node3D

var _held_root: Node3D
var _held_id: String = ""
var _phase: float = 0.0
var _t: float = 0.0
var _yaw: float = 0.0
var _turn_rate: float = 0.0
var _fwd_speed: float = 0.0
var _accel: float = 0.0
var _air_t: float = 0.0
var _grounded_before: bool = true
var _land: float = 0.0  # landing compression, spring-driven
var _land_v: float = 0.0
var _fall_speed: float = 0.0
var _pelvis_base: Vector3 = Vector3(0.0, 0.95, 0.0)
var _first_person: bool = false
var _walk: float = 0.0


var _was_grabbed: bool = false
var _sliding: bool = false
var _hat_back_t: float = 0.0
var _talking: bool = false
var _talk_glyph: Label3D
const HAT_OFF_SECONDS: float = 6.0


## (gait phase, walk amount 0..1) for camera bob that matches the steps.
func gait() -> Vector2:
	return Vector2(_phase, _walk)


func is_sliding() -> bool:
	return _sliding


## "Hats are physics." Knocks the hard hat off as a tumbling rigid body; it reappears on your
## head a few seconds later. Cosmetic and local to each screen.
func pop_hat(impulse: Vector3) -> void:
	if hat == null or not hat.visible or not is_inside_tree():
		return
	var root := get_tree().current_scene
	if root == null:
		return
	var body := RigidBody3D.new()
	body.collision_layer = 0
	body.collision_mask = ChainBody.LAYER_WORLD
	body.mass = 0.4
	var shape := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 0.13
	shape.shape = s
	shape.position = Vector3(0.0, 0.05, 0.0)
	body.add_child(shape)
	var look := hat.duplicate() as Node3D
	look.transform = Transform3D.IDENTITY
	look.scale = Vector3.ONE * SCALE
	look.visible = true
	body.add_child(look)
	root.add_child(body)
	var gt := hat.global_transform
	body.global_transform = Transform3D(gt.basis.orthonormalized(), gt.origin)
	body.linear_velocity = impulse
	body.angular_velocity = Vector3(randf_range(-9.0, 9.0), randf_range(-6.0, 6.0), randf_range(-9.0, 9.0))
	get_tree().create_timer(HAT_OFF_SECONDS + 2.0).timeout.connect(body.queue_free)
	hat.visible = false
	_hat_back_t = HAT_OFF_SECONDS


func build(index: int) -> void:
	scale = Vector3.ONE * SCALE
	var vest := _mat(VEST_COLORS[index % VEST_COLORS.size()], 0.75)
	var skin := _mat(SKIN_TONES[(index * 7 + 3) % SKIN_TONES.size()], 0.7)
	skin.subsurf_scatter_enabled = true
	skin.subsurf_scatter_strength = 0.25
	var pants := _mat(Color(0.17, 0.2, 0.27), 0.92)
	var boots := _mat(Color(0.2, 0.13, 0.07), 0.6)
	var sole := _mat(Color(0.06, 0.05, 0.05), 0.9)
	var shirt := _mat(Color(0.78, 0.8, 0.84), 0.9)
	var gloves := _mat(Color(0.62, 0.5, 0.32), 0.85)
	var dark := _mat(Color(0.04, 0.035, 0.03), 0.4)
	var white := _mat(Color(0.95, 0.94, 0.9), 0.3)
	var hair := _mat(HAIR_COLORS[index % HAIR_COLORS.size()], 0.85)
	var strip := StandardMaterial3D.new()
	strip.albedo_color = Color(0.82, 0.85, 0.88)
	strip.metallic = 0.7
	strip.roughness = 0.15
	strip.emission_enabled = true
	strip.emission = Color(0.8, 0.85, 0.9)
	strip.emission_energy_multiplier = 0.25
	var hat_color := Color(1.0, 0.8, 0.06) if index % 2 == 0 else Color(0.95, 0.95, 0.93)
	var hat_mat := _mat(hat_color, 0.5)  # scuffed plastic: glossy enough to catch light, not a mirror

	pelvis = _pivot(self, _pelvis_base)
	_capsule(pelvis, 0.15, 0.42, Vector3(0.0, 0.0, 0.0), pants, Vector3(0.0, 0.0, PI * 0.5), Vector3(1.0, 1.0, 0.75))
	# Legs: thigh -> knee -> shin -> ankle -> boot.
	thigh_l = _pivot(pelvis, Vector3(-0.1, -0.03, 0.0))
	thigh_r = _pivot(pelvis, Vector3(0.1, -0.03, 0.0))
	for side in [[thigh_l, -1.0], [thigh_r, 1.0]]:
		var thigh: Node3D = side[0]
		_capsule(thigh, 0.088, 0.48, Vector3(0.0, -0.21, 0.0), pants)
		var knee := _pivot(thigh, Vector3(0.0, -0.43, 0.0))
		_capsule(knee, 0.072, 0.46, Vector3(0.0, -0.2, 0.0), pants)
		var ankle := _pivot(knee, Vector3(0.0, -0.42, 0.0))
		_box(ankle, Vector3(0.13, 0.11, 0.27), Vector3(0.0, -0.025, -0.05), boots)
		_box(ankle, Vector3(0.135, 0.03, 0.29), Vector3(0.0, -0.085, -0.05), sole)
		_sphere(ankle, 0.066, Vector3(0.0, -0.02, -0.17), boots, Vector3(1.0, 0.8, 1.0))
		if side[1] < 0.0:
			knee_l = knee
			ankle_l = ankle
		else:
			knee_r = knee
			ankle_r = ankle
	# Torso: spine -> chest -> neck -> head.
	spine = _pivot(pelvis, Vector3(0.0, 0.07, 0.0))
	_capsule(spine, 0.155, 0.32, Vector3(0.0, 0.13, 0.0), shirt, Vector3.ZERO, Vector3(1.0, 1.0, 0.8))
	var belt := MeshInstance3D.new()
	var bt := TorusMesh.new()
	bt.inner_radius = 0.15
	bt.outer_radius = 0.185
	belt.mesh = bt
	belt.scale = Vector3(1.0, 1.0, 0.82)
	belt.position = Vector3(0.0, 0.0, 0.0)
	belt.material_override = dark
	spine.add_child(belt)
	var cuff := MeshInstance3D.new()
	var ct := TorusMesh.new()
	ct.inner_radius = 0.028
	ct.outer_radius = 0.055
	cuff.mesh = ct
	cuff.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	cuff.position = Vector3(0.0, -0.01, -0.17)
	cuff.material_override = LevelKit.mat("chain")
	spine.add_child(cuff)
	_box(spine, Vector3(0.1, 0.12, 0.06), Vector3(0.16, 0.0, 0.08), boots)  # tool pouch
	chest = _pivot(spine, Vector3(0.0, 0.28, 0.0))
	_capsule(chest, 0.195, 0.44, Vector3(0.0, 0.1, 0.0), shirt, Vector3.ZERO, Vector3(1.12, 1.0, 0.78))
	# Hi-vis vest wraps the chest; reflective bands wrap the vest.
	var vest_mesh := MeshInstance3D.new()
	var vc := CylinderMesh.new()
	vc.top_radius = 0.205
	vc.bottom_radius = 0.19
	vc.height = 0.46
	vest_mesh.mesh = vc
	vest_mesh.scale = Vector3(1.12, 1.0, 0.82)
	vest_mesh.position = Vector3(0.0, 0.07, 0.0)
	vest_mesh.material_override = vest
	chest.add_child(vest_mesh)
	for y: float in [-0.04, 0.12]:
		var band := MeshInstance3D.new()
		var bc := CylinderMesh.new()
		bc.top_radius = 0.208
		bc.bottom_radius = 0.205
		bc.height = 0.035
		band.mesh = bc
		band.scale = Vector3(1.12, 1.0, 0.82)
		band.position = Vector3(0.0, y, 0.0)
		band.material_override = strip
		chest.add_child(band)
	_box(chest, Vector3(0.09, 0.1, 0.03), Vector3(-0.1, 0.14, -0.165), vest)  # chest pocket
	_box(chest, Vector3(0.02, 0.34, 0.025), Vector3(0.0, 0.08, -0.175), dark)  # zip
	neck = _pivot(chest, Vector3(0.0, 0.33, 0.0))
	_capsule(neck, 0.058, 0.14, Vector3(0.0, 0.04, 0.0), skin)
	head = _pivot(neck, Vector3(0.0, 0.13, 0.0))
	_sphere(head, 0.118, Vector3(0.0, 0.03, 0.0), skin, Vector3(1.0, 1.16, 1.06))
	_sphere(head, 0.075, Vector3(0.0, -0.045, -0.04), skin, Vector3(1.05, 0.9, 1.0))  # jaw
	_capsule(head, 0.022, 0.07, Vector3(0.0, 0.02, -0.122), skin, Vector3(0.25, 0.0, 0.0))  # nose
	for s: float in [-1.0, 1.0]:
		_sphere(head, 0.03, Vector3(s * 0.118, 0.025, 0.005), skin, Vector3(0.45, 1.0, 0.8))  # ear
		_sphere(head, 0.02, Vector3(s * 0.042, 0.055, -0.1), white)
		_sphere(head, 0.011, Vector3(s * 0.042, 0.055, -0.116), dark)
		_box(head, Vector3(0.045, 0.012, 0.015), Vector3(s * 0.043, 0.085, -0.108), hair, Vector3(0.0, 0.0, -s * 0.12))
	_box(head, Vector3(0.05, 0.01, 0.01), Vector3(0.0, -0.035, -0.112), dark)  # mouth
	_sphere(head, 0.122, Vector3(0.0, 0.05, 0.022), hair, Vector3(1.02, 1.0, 1.05))  # hair under the hat
	hat = _pivot(head, Vector3(0.0, 0.1, 0.0))
	var dome := MeshInstance3D.new()
	var dm := SphereMesh.new()
	dm.radius = 0.145
	dm.height = 0.15
	dm.is_hemisphere = true
	dome.mesh = dm
	dome.scale = Vector3(1.0, 1.05, 1.1)
	dome.material_override = hat_mat
	hat.add_child(dome)
	var brim := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.17
	bm.bottom_radius = 0.175
	bm.height = 0.018
	brim.mesh = bm
	brim.scale = Vector3(1.0, 1.0, 1.22)
	brim.position = Vector3(0.0, 0.004, -0.03)
	brim.material_override = hat_mat
	hat.add_child(brim)
	_box(hat, Vector3(0.03, 0.03, 0.26), Vector3(0.0, 0.14, 0.0), hat_mat)  # ridge
	# Arms: shoulder -> elbow -> wrist -> glove.
	shoulder_l = _pivot(chest, Vector3(-0.235, 0.24, 0.0))
	shoulder_r = _pivot(chest, Vector3(0.235, 0.24, 0.0))
	for side in [[shoulder_l, -1.0], [shoulder_r, 1.0]]:
		var sh: Node3D = side[0]
		_sphere(sh, 0.07, Vector3.ZERO, shirt)
		_capsule(sh, 0.062, 0.33, Vector3(0.0, -0.15, 0.0), shirt)
		var elbow := _pivot(sh, Vector3(0.0, -0.3, 0.0))
		_capsule(elbow, 0.052, 0.3, Vector3(0.0, -0.13, 0.0), skin)
		_capsule(elbow, 0.056, 0.1, Vector3(0.0, -0.03, 0.0), shirt)  # rolled sleeve
		var wrist := _pivot(elbow, Vector3(0.0, -0.28, 0.0))
		_box(wrist, Vector3(0.085, 0.1, 0.045), Vector3(0.0, -0.045, 0.0), gloves)
		_capsule(wrist, 0.018, 0.06, Vector3(-side[1] * 0.045, -0.025, -0.01), gloves, Vector3(0.0, 0.0, side[1] * 0.5))
		if side[1] < 0.0:
			elbow_l = elbow
		else:
			elbow_r = elbow
			hand_r = _pivot(wrist, Vector3(0.0, -0.08, -0.02))


func set_first_person(fp: bool) -> void:
	_first_person = fp
	neck.visible = not fp  # neck carries the head, hair and hat


## Voice chat: a little speech glyph over the head while this player talks.
func set_talking(on: bool) -> void:
	if on == _talking:
		return
	_talking = on
	if _talk_glyph == null:
		_talk_glyph = Label3D.new()
		_talk_glyph.text = "((  ))"
		_talk_glyph.font_size = 28
		_talk_glyph.pixel_size = 0.005
		_talk_glyph.modulate = Color(0.6, 1.0, 0.7)
		_talk_glyph.outline_size = 6
		_talk_glyph.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_talk_glyph.no_depth_test = true
		_talk_glyph.position = Vector3(0.0, 2.55, 0.0)
		add_child(_talk_glyph)
	_talk_glyph.visible = on and not _first_person


func set_held_item(id: String) -> void:
	if id == _held_id:
		return
	_held_id = id
	if _held_root != null:
		_held_root.queue_free()
		_held_root = null
	if id == "":
		return
	_held_root = ItemModels.build(id)
	if id == "jetpack":
		chest.add_child(_held_root)
		_held_root.position = Vector3(0.0, 0.08, 0.26)
		_held_root.scale = Vector3.ONE * 0.95
	else:
		hand_r.add_child(_held_root)
		_held_root.rotation = Vector3(-PI * 0.5, 0.0, 0.0)  # tool points along the forearm
		_held_root.scale = Vector3.ONE * 0.9


func held_root() -> Node3D:
	return _held_root


## facing: yaw the body should face. vel: world velocity. aim_pitch: where the head looks.
func animate(delta: float, vel: Vector3, facing: float, grounded: bool, bracing: bool, grabbed: bool,
		mantling: bool, aiming: bool, aim_pitch: float, sliding: bool = false) -> void:
	_t += delta
	_sliding = sliding
	# Facing: ease toward the target, remember how fast we're turning (for leaning into turns).
	var prev_yaw := _yaw
	_yaw = lerp_angle(_yaw, facing, 1.0 - exp(-11.0 * delta))
	rotation.y = _yaw
	_turn_rate = lerpf(_turn_rate, wrapf(_yaw - prev_yaw, -PI, PI) / maxf(delta, 0.0001), 1.0 - exp(-8.0 * delta))
	var fwd := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	var flat := Vector3(vel.x, 0.0, vel.z)
	var speed := flat.length()
	var new_fwd := flat.dot(fwd)
	_accel = lerpf(_accel, (new_fwd - _fwd_speed) / maxf(delta, 0.0001), 1.0 - exp(-6.0 * delta))
	_fwd_speed = new_fwd
	var walk := clampf(speed / 3.8, 0.0, 1.0) if grounded else 0.0
	var run := clampf((speed - 4.6) / 2.2, 0.0, 1.0) if grounded else 0.0
	_walk = walk
	# Distance-driven gait: one cycle = two steps.
	var stride := lerpf(1.35, 2.3, run)
	var prev_phase := _phase
	_phase += signf(new_fwd if absf(new_fwd) > 0.2 else speed) * speed * delta * TAU / stride
	if grounded and walk > 0.25 and not grabbed:
		for strike in [PI * 0.5, PI * 1.5]:
			if _crossed(prev_phase, _phase, strike):
				footstep.emit(run)
	# Landing spring.
	if not grounded:
		_air_t += delta
		_fall_speed = maxf(_fall_speed, -vel.y)
	elif not _grounded_before:
		if _air_t > 0.2:
			var hit := clampf(_fall_speed / 12.0, 0.25, 1.0)
			_land_v -= hit * 5.0
			landed.emit(hit)
			if hit >= 0.95:
				pop_hat(fwd * 1.5 + Vector3.UP * 3.5)  # a proper fall knocks your hat off
		_air_t = 0.0
		_fall_speed = 0.0
	_grounded_before = grounded
	if grabbed and not _was_grabbed:
		pop_hat(Vector3(randf_range(-1.5, 1.5), 4.5, randf_range(-1.5, 1.5)))
	_was_grabbed = grabbed
	if _hat_back_t > 0.0:
		_hat_back_t -= delta
		if _hat_back_t <= 0.0:
			hat.visible = true
	_land_v += (-_land * 140.0 - _land_v * 17.0) * delta
	_land += _land_v * delta
	var land := clampf(-_land, 0.0, 1.0)

	var s := sin(_phase)
	var c := cos(_phase)
	var amp_hip := lerpf(0.42, 0.78, run) * walk
	var amp_knee := lerpf(0.9, 1.65, run) * walk
	var hip_l := s * amp_hip
	var hip_r := -s * amp_hip
	var knee_l_t := -(0.06 * walk + amp_knee * maxf(0.0, c) + 0.18 * walk * maxf(0.0, -c))
	var knee_r_t := -(0.06 * walk + amp_knee * maxf(0.0, -c) + 0.18 * walk * maxf(0.0, c))
	var pelvis_pos := _pelvis_base + Vector3(0.025 * s * walk * (1.0 - run * 0.6), lerpf(0.022, 0.05, run) * walk * cos(2.0 * _phase) - 0.02 * walk, 0.0)
	var pelvis_rot := Vector3(0.0, 0.13 * s * walk, 0.03 * c * walk)
	var lean_fwd := clampf(_accel * 0.025, -0.15, 0.15) + 0.05 * walk + 0.16 * run
	var spine_rot := Vector3(-lean_fwd, -0.17 * s * walk, clampf(-_turn_rate * 0.045 * clampf(speed / 4.0, 0.0, 1.5), -0.28, 0.28))
	var arm_amp := lerpf(0.38, 0.85, run) * walk
	var sh_l := Vector3(-s * arm_amp, 0.0, -0.09 - 0.05 * run)
	var sh_r := Vector3(s * arm_amp, 0.0, 0.09 + 0.05 * run)
	var el_l := 0.2 + lerpf(0.12, 1.35, run) * walk + 0.22 * walk * maxf(0.0, s)
	var el_r := 0.2 + lerpf(0.12, 1.35, run) * walk + 0.22 * walk * maxf(0.0, -s)
	# Idle life: breathing, weight shift, the odd glance around.
	var idle := 1.0 - walk
	pelvis_pos.x += 0.015 * sin(_t * 0.55) * idle
	spine_rot.x += 0.015 * sin(_t * 1.7) * idle
	var head_yaw := 0.18 * sin(_t * 0.31) * sin(_t * 0.13) * idle
	var head_pitch := clampf(aim_pitch, -0.7, 0.7) * 0.6

	if grabbed:
		pelvis_pos = _pelvis_base
		sh_l = Vector3(0.2, 0.0, -2.75 + 0.2 * sin(_t * 9.0))
		sh_r = Vector3(0.2, 0.0, 2.75 + 0.2 * sin(_t * 8.0))
		el_l = 0.5 + 0.3 * sin(_t * 11.0)
		el_r = 0.5 + 0.3 * sin(_t * 10.0)
		hip_l = 0.5 * sin(_t * 9.0)
		hip_r = -0.5 * sin(_t * 9.0)
		knee_l_t = -0.6 - 0.5 * maxf(0.0, sin(_t * 9.0))
		knee_r_t = -0.6 - 0.5 * maxf(0.0, -sin(_t * 9.0))
		spine_rot = Vector3(0.15, 0.0, 0.18 * sin(_t * 5.0))
		head_pitch = 0.9
	elif mantling:
		hip_l = 1.1
		hip_r = 0.2
		knee_l_t = -1.4
		knee_r_t = -0.5
		sh_l = Vector3(2.4, 0.0, -0.2)
		sh_r = Vector3(2.4, 0.0, 0.2)
		el_l = 0.3
		el_r = 0.3
		spine_rot = Vector3(-0.35, 0.0, 0.0)
	elif not grounded:
		if vel.y > -3.0 or _air_t < 0.45:
			hip_l = 0.55
			hip_r = -0.15
			knee_l_t = -1.0
			knee_r_t = -0.5
			sh_l = Vector3(0.5, 0.0, -0.55)
			sh_r = Vector3(0.3, 0.0, 0.55)
			el_l = 0.6
			el_r = 0.6
		else:
			# A long fall: windmilling, the universal language of "oh no".
			var w := _t * 11.0
			sh_l = Vector3(sin(w) * 1.3, 0.0, -1.35)
			sh_r = Vector3(-sin(w) * 1.3, 0.0, 1.35)
			el_l = 0.4
			el_r = 0.4
			hip_l = 0.6 * sin(_t * 9.0)
			hip_r = -0.6 * sin(_t * 9.0)
			knee_l_t = -0.7
			knee_r_t = -0.7
			head_pitch = -0.3
	elif sliding:
		# Lying back on one hip, the lead leg straight out ahead, the trail leg tucked under, one
		# hand on the floor behind: a baseball slide in a hi-vis vest.
		pelvis_pos.y -= 0.6
		pelvis_pos.z += 0.05
		pelvis_rot = Vector3(0.0, 0.0, 0.12)
		hip_l = 1.45  # forward and straight
		knee_l_t = -0.15
		hip_r = 0.35
		knee_r_t = -2.1  # tucked
		spine_rot = Vector3(0.62, 0.0, -0.1)  # leaning back
		sh_l = Vector3(-2.3, 0.0, -0.5)  # arm back, hand on the floor
		el_l = 0.3
		sh_r = Vector3(0.9, 0.0, 0.7)  # the other out for balance
		el_r = 0.5
		head_pitch = -0.35  # chin up, eyes on where you're going
	elif bracing:
		# A real crouch: hips low, knees deep, chest forward, head still level. The legs keep a
		# short creeping gait so a crouch-walk reads as one.
		pelvis_pos.y -= 0.42
		pelvis_pos.z += 0.1  # hips back (+z is behind), chest over the knees: a crouch, not a chair
		hip_l = 0.85 + 0.3 * s * walk
		hip_r = 0.75 - 0.3 * s * walk
		knee_l_t = -1.3 - 0.25 * walk * maxf(0.0, c)
		knee_r_t = -1.2 - 0.25 * walk * maxf(0.0, -c)
		spine_rot.x = -0.45  # negative x leans forward
		sh_l = Vector3(0.6 - 0.25 * s * walk, 0.0, 0.25)
		sh_r = Vector3(0.6 + 0.25 * s * walk, 0.0, -0.25)
		el_l = 0.9
		el_r = 0.9
		head_pitch = clampf(aim_pitch, -0.7, 0.7) * 0.6 - 0.15
	# Landing compression rides on top of whatever pose we're in.
	pelvis_pos.y -= 0.16 * land
	knee_l_t -= 0.9 * land
	knee_r_t -= 0.9 * land
	hip_l += 0.45 * land
	hip_r += 0.45 * land
	spine_rot.x -= 0.25 * land
	if aiming and not grabbed:
		sh_r = Vector3(1.5 + clampf(aim_pitch, -1.0, 1.0) * 0.8, 0.0, 0.06)
		el_r = 0.08
		if _held_id == "pistol":
			sh_l = Vector3(1.35 + clampf(aim_pitch, -1.0, 1.0) * 0.7, 0.0, 0.45)
			el_l = 0.45

	# In first person your raised arms would fill the screen while you're lifted: hide them so you
	# see what's pulling you.
	var arms_on := not (_first_person and grabbed)
	shoulder_l.visible = arms_on
	shoulder_r.visible = arms_on
	var k_leg := 1.0 - exp(-24.0 * delta)
	var k_arm := 1.0 - exp(-15.0 * delta)
	var k_body := 1.0 - exp(-12.0 * delta)
	var k_head := 1.0 - exp(-9.0 * delta)
	pelvis.position = pelvis.position.lerp(pelvis_pos, k_body)
	pelvis.rotation = pelvis.rotation.lerp(pelvis_rot, k_body)
	spine.rotation = spine.rotation.lerp(spine_rot, k_body)
	thigh_l.rotation.x = lerpf(thigh_l.rotation.x, hip_l, k_leg)
	thigh_r.rotation.x = lerpf(thigh_r.rotation.x, hip_r, k_leg)
	knee_l.rotation.x = lerpf(knee_l.rotation.x, knee_l_t, k_leg)
	knee_r.rotation.x = lerpf(knee_r.rotation.x, knee_r_t, k_leg)
	# Keep the soles roughly flat: undo hip + knee at the ankle.
	ankle_l.rotation.x = lerpf(ankle_l.rotation.x, -(hip_l + knee_l_t) * 0.75, k_leg)
	ankle_r.rotation.x = lerpf(ankle_r.rotation.x, -(hip_r + knee_r_t) * 0.75, k_leg)
	shoulder_l.rotation = shoulder_l.rotation.lerp(sh_l, k_arm)
	shoulder_r.rotation = shoulder_r.rotation.lerp(sh_r, k_arm)
	elbow_l.rotation.x = lerpf(elbow_l.rotation.x, el_l, k_arm)
	elbow_r.rotation.x = lerpf(elbow_r.rotation.x, el_r, k_arm)
	# The head counters the torso so it stays level, then looks where you aim.
	var head_t := Vector3(head_pitch - spine_rot.x - pelvis_rot.x, head_yaw - spine_rot.y - pelvis_rot.y, -spine_rot.z * 0.6)
	head.rotation = head.rotation.lerp(head_t, k_head)
	chest.scale = Vector3.ONE * (1.0 + 0.012 * sin(_t * 1.7) * idle)


static func _crossed(a: float, b: float, at: float) -> bool:
	if absf(b - a) < 0.000001:
		return false
	var lo := minf(a, b)
	var hi := maxf(a, b)
	var k := ceilf((lo - at) / TAU)
	return at + k * TAU <= hi


# --- Builders ---------------------------------------------------------------------------------

func _mat(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


func _pivot(parent: Node3D, at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = at
	parent.add_child(n)
	return n


func _capsule(parent: Node3D, r: float, h: float, at: Vector3, m: Material, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> void:
	var mi := MeshInstance3D.new()
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = maxf(h, r * 2.0)
	c.radial_segments = 16
	c.rings = 6
	mi.mesh = c
	mi.position = at
	mi.rotation = rot
	mi.scale = scl
	mi.material_override = m
	parent.add_child(mi)


func _sphere(parent: Node3D, r: float, at: Vector3, m: Material, scl: Vector3 = Vector3.ONE) -> void:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 20
	s.rings = 10
	mi.mesh = s
	mi.position = at
	mi.scale = scl
	mi.material_override = m
	parent.add_child(mi)


func _box(parent: Node3D, size: Vector3, at: Vector3, m: Material, rot: Vector3 = Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = at
	mi.rotation = rot
	mi.material_override = m
	parent.add_child(mi)
