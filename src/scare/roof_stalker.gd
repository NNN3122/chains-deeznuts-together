class_name RoofStalker
extends Node3D
## The Tall Tenant: something far too tall and thin, standing just past the edge of a lamp's
## light on a roof across the way, looking at you. Only ever glimpsed: look straight at it, or
## come close, and it steps back off the edge into the dark. It never moves toward you, never
## touches anyone, and is gone in seconds either way. Purely local: every peer spawns it at the
## same spot (the roof's dread picks it), and each peer's own eyes make it leave.

const HEIGHT: float = 3.4  # m, head to heel
const LIFE: float = 7.0  # s it stands there if nobody looks
const STARE_ANGLE: float = 0.16  # rad (about 9 degrees) off the centre of your view counts as looking at it
const STARE_TIME: float = 0.2  # s of looking before it goes
const NEAR: float = 12.0  # m: closer than this and it goes
const LEAVE_TIME: float = 0.3  # s to step back and drop out of sight
const SKIN: Color = Color(0.06, 0.05, 0.055)
const MOUTH: Color = Color(0.01, 0.005, 0.005)

var _t: float = 0.0
var _stare: float = 0.0
var _leaving: bool = false
var _head: Node3D


func _ready() -> void:
	var skin := Sculpt.material(0.1, 0.7, 0.0, 0.0, 0.6)
	skin.set_shader_parameter("rim_col", Color(0.5, 0.58, 0.7))  # the lamp behind it outlining it
	Sculpt.put(self, body_mesh(), skin)
	# The head, small for the rest of it, tilted, with two pale points for eyes that the fog
	# doesn't swallow: in the murk, that's all you might see.
	_head = Node3D.new()
	_head.position = Vector3(0.0, 3.12, -0.22)
	_head.rotation = Vector3(0.25, 0.0, 0.35)
	add_child(_head)
	Sculpt.put(_head, head_mesh(), skin)
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(0.85, 0.9, 0.78)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(0.85, 0.9, 0.78)
	eye_mat.emission_energy_multiplier = 2.4
	eye_mat.disable_fog = true
	for s: float in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radial_segments = 12
		em.rings = 6
		em.radius = 0.018
		em.height = 0.036
		eye.mesh = em
		eye.material_override = eye_mat
		eye.position = Vector3(s * 0.05, 0.02, -0.105)
		_head.add_child(eye)




## Everything below the head, facing -z: long bowed legs, a narrow body bent forward with the spine
## showing, shoulders up round the ears, arms hanging past the knees, fingers longer still.
static func body_mesh() -> ArrayMesh:
	var s := Sculpt.new()
	for x: float in [-1.0, 1.0]:
		s.capsule(Vector3(x * 0.14, 1.78, 0.02), Vector3(x * 0.19, 0.95, -0.04), 0.07, 0.048, SKIN, 0.04, 0.95, 0.005)
		s.ellipsoid(Vector3(x * 0.19, 0.95, -0.05), Vector3(0.05, 0.06, 0.05), SKIN, 0.03, 0.95)
		s.capsule(Vector3(x * 0.19, 0.95, -0.04), Vector3(x * 0.17, 0.08, 0.03), 0.045, 0.034, SKIN, 0.03, 0.95, 0.004)
		s.capsule(Vector3(x * 0.17, 0.05, 0.03), Vector3(x * 0.18, 0.025, -0.22), 0.04, 0.022, SKIN, 0.03, 0.95)
	s.ellipsoid(Vector3(0.0, 1.82, 0.04), Vector3(0.2, 0.12, 0.12), SKIN, 0.05, 0.95)
	s.capsule(Vector3(0.0, 1.85, 0.05), Vector3(0.0, 2.72, -0.12), 0.12, 0.16, SKIN, 0.06, 0.95, 0.006)
	for k in 8:
		var u := float(k) / 7.0
		s.ellipsoid(Vector3(0.0, 1.95 + u * 0.75, 0.15 - u * 0.17 + 0.0), Vector3(0.03, 0.035, 0.03), SKIN, 0.02, 0.95)  # the spine
	s.capsule(Vector3(-0.3, 2.86, -0.1), Vector3(0.3, 2.86, -0.1), 0.08, 0.08, SKIN, 0.06, 0.95)
	s.capsule(Vector3(0.0, 2.82, -0.12), Vector3(0.0, 3.06, -0.21), 0.05, 0.045, SKIN, 0.04, 0.95)
	for x: float in [-1.0, 1.0]:
		s.capsule(Vector3(x * 0.32, 2.85, -0.1), Vector3(x * 0.36, 2.05, -0.05), 0.045, 0.034, SKIN, 0.03, 0.95, 0.004)
		s.capsule(Vector3(x * 0.36, 2.05, -0.05), Vector3(x * 0.38, 1.25, -0.1), 0.034, 0.024, SKIN, 0.03, 0.95, 0.003)
		s.ellipsoid(Vector3(x * 0.38, 1.18, -0.11), Vector3(0.03, 0.055, 0.016), SKIN, 0.02, 0.95)
		for f in 4:
			var o := x * (0.36 + 0.013 * float(f))
			s.tube_add(PackedVector3Array([Vector3(o, 1.13, -0.11), Vector3(o + x * 0.01, 0.98, -0.13), Vector3(o + x * 0.015, 0.84, -0.12), Vector3(o + x * 0.01, 0.72, -0.07)]), PackedFloat32Array([0.008, 0.0065, 0.005, 0.002]), SKIN, 0.95, 5)
	return s.noise_scale(20.0).mesh("tenant_body", 0.014, 5000)


## The head: a long skull, a jaw hanging open far too low, sockets for the eyes.
static func head_mesh() -> ArrayMesh:
	var s := Sculpt.new()
	s.ellipsoid(Vector3(0.0, 0.03, 0.0), Vector3(0.1, 0.16, 0.12), SKIN, 0.03, 0.95, 0.003)
	s.ellipsoid(Vector3(0.0, -0.13, -0.04), Vector3(0.065, 0.09, 0.065), SKIN, 0.04, 0.95)
	s.carve_ellipsoid(Vector3(0.0, -0.13, -0.1), Vector3(0.032, 0.075, 0.04), MOUTH, 0.015)
	for x: float in [-1.0, 1.0]:
		s.carve_ellipsoid(Vector3(x * 0.05, 0.02, -0.11), Vector3(0.028, 0.022, 0.025), MOUTH, 0.01)
	return s.noise_scale(40.0).mesh("tenant_head", 0.008, 1500)


## Turns it to face a point (its face is -z, like the players').
func face(target: Vector3) -> void:
	var to := target - global_position
	rotation.y = atan2(-to.x, -to.z)


func _process(delta: float) -> void:
	_t += delta
	if _leaving:
		return
	# The head keeps tilting, slowly, the wrong way.
	_head.rotation.z = 0.35 + 0.25 * sin(_t * 0.7)
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		var chest := global_position + Vector3.UP * HEIGHT * 0.7
		var to := chest - cam.global_position
		var fwd := -cam.global_transform.basis.z
		if fwd.angle_to(to) < STARE_ANGLE:
			_stare += delta
		else:
			_stare = maxf(0.0, _stare - delta)
		var flat := Vector2(to.x, to.z).length()
		if _stare >= STARE_TIME or flat < NEAR:
			leave()
			return
	if _t >= LIFE:
		leave()


## Back off the edge and gone: a step away, then down out of sight.
func leave() -> void:
	if _leaving:
		return
	_leaving = true
	var back := global_transform.basis.z * 1.4
	var tw := create_tween()
	tw.tween_property(self, "global_position", global_position + back, LEAVE_TIME * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "global_position", global_position + back + Vector3.DOWN * (HEIGHT + 1.0), LEAVE_TIME * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)


func is_leaving() -> bool:
	return _leaving
