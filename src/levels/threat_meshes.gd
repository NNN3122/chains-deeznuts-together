class_name ThreatMeshes
extends RefCounted
## The sculpted things in Kettle Hollow's streets (RoadThreats): the Shamblers, the town's people
## gone wrong (grey, wet, a jaw hanging open, arms out for the cars), and the Flyers (a pale ribbed
## body the size of a dog, a mouth of needles, two leather wings with finger bones through them).
## Origins: a Shambler stands on its feet facing -z; a Flyer's body is centred, its wings hinge at
## its shoulders on nodes "Wing0" (left) and "Wing1" (right).

const SHAMBLER_VARIANTS: int = 3
const SKIN: Color = Color(0.36, 0.35, 0.32)
const SKIN_GREY: Color = Color(0.27, 0.28, 0.27)
const ROT: Color = Color(0.17, 0.2, 0.12)
const RAW: Color = Color(0.32, 0.03, 0.03)
const BLOOD: Color = Color(0.16, 0.0, 0.01)
const HAIR: Color = Color(0.03, 0.025, 0.02)
const TOOTH: Color = Color(0.55, 0.5, 0.38)
const SOCKET: Color = Color(0.02, 0.0, 0.0)
const SHIRTS: Array[Color] = [Color(0.3, 0.3, 0.28), Color(0.12, 0.16, 0.25), Color(0.32, 0.2, 0.12)]
const TROUSERS: Array[Color] = [Color(0.08, 0.08, 0.09), Color(0.16, 0.14, 0.11), Color(0.1, 0.12, 0.16)]
const FLYER_SKIN: Color = Color(0.5, 0.43, 0.42)
const MEMBRANE: Color = Color(0.2, 0.12, 0.11)

static var _flesh: ShaderMaterial
static var _membrane: ShaderMaterial


static func flesh() -> ShaderMaterial:
	if _flesh == null:
		_flesh = Sculpt.material(0.3, 0.05, 0.9, 0.04, 1.0)
		_flesh.set_shader_parameter("rim_col", Color(0.3, 0.05, 0.04))
	return _flesh


static func membrane() -> ShaderMaterial:
	if _membrane == null:
		_membrane = Sculpt.material(0.2, 0.02, 0.6, 0.35, 0.8)
		_membrane.set_shader_parameter("rim_col", Color(0.4, 0.08, 0.05))
	return _membrane


## A person who didn't get out, standing in the road, arms out, head lolled, jaw hanging.
static func shambler(v: int) -> ArrayMesh:
	var s := Sculpt.new()
	var shirt: Color = SHIRTS[v % SHIRTS.size()]
	var legs: Color = TROUSERS[v % TROUSERS.size()]
	var skin := SKIN if v != 1 else SKIN_GREY
	for side: float in [-1.0, 1.0]:
		s.capsule(Vector3(side * 0.11, 0.92, 0.0), Vector3(side * 0.13, 0.48, 0.03), 0.085, 0.065, legs, 0.03, 0.8)
		s.capsule(Vector3(side * 0.13, 0.48, 0.03), Vector3(side * 0.14, 0.08, 0.0), 0.065, 0.05, legs, 0.03, 0.8)
		s.box(Vector3(side * 0.14, 0.04, -0.05), Vector3(0.06, 0.04, 0.13), 0.02, Color(0.05, 0.04, 0.03), 0.02, 0.6)
	s.capsule(Vector3(0.0, 0.95, 0.0), Vector3(0.0, 1.38, -0.08), 0.17, 0.2, shirt, 0.05, 0.85, 0.004)  # leaning in
	s.ellipsoid(Vector3(0.0, 1.38, -0.08), Vector3(0.22, 0.12, 0.13), shirt, 0.05, 0.85)
	s.paint_ellipsoid(Vector3(0.05, 1.2, -0.17), Vector3(0.12, 0.2, 0.08), BLOOD, 0.3)  # down the front
	s.paint_ellipsoid(Vector3(-0.1, 1.05, -0.12), Vector3(0.08, 0.06, 0.06), RAW, 0.25)  # torn open
	s.carve_ellipsoid(Vector3(-0.1, 1.05, -0.17), Vector3(0.05, 0.04, 0.03), RAW, 0.01)
	s.capsule(Vector3(0.0, 1.45, -0.1), Vector3(0.02, 1.55, -0.14), 0.05, 0.045, skin, 0.03, 0.5)  # the neck
	# The head, lolled to one side, the jaw hanging off it.
	var h := Vector3(0.05, 1.66, -0.16)
	s.ellipsoid(h, Vector3(0.095, 0.115, 0.105), skin, 0.03, 0.45, 0.004)
	s.carve_ellipsoid(h + Vector3(0.0, -0.05, -0.08), Vector3(0.045, 0.06, 0.04), SOCKET, 0.01)
	s.ellipsoid(h + Vector3(0.0, -0.13, -0.04), Vector3(0.06, 0.03, 0.06), skin, 0.02, 0.45)  # the jaw, dropped
	for k in 6:
		var x := -0.03 + float(k) * 0.012
		s.tube_add(PackedVector3Array([h + Vector3(x, -0.02, -0.08), h + Vector3(x, -0.04, -0.085)]), PackedFloat32Array([0.005, 0.001]), TOOTH, 0.3, 4)
	for side: float in [-1.0, 1.0]:
		s.carve_ellipsoid(h + Vector3(side * 0.035, 0.02, -0.09), Vector3(0.02, 0.018, 0.015), SOCKET, 0.006)
		s.paint_capsule(h + Vector3(side * 0.035, 0.0, -0.1), h + Vector3(side * 0.04, -0.09, -0.1), 0.006, 0.004, BLOOD, 0.2)  # weeping
	s.paint_ellipsoid(h + Vector3(0.06, 0.05, 0.0), Vector3(0.05, 0.04, 0.06), ROT, 0.5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 900 + v
	for k in 14:  # lank hair
		var a := rng.randf_range(-2.4, 2.4)
		var root := h + Vector3(sin(a) * 0.08, 0.08, cos(a) * 0.08)
		s.tube_add(PackedVector3Array([root, root + Vector3(sin(a) * 0.03, -0.08, cos(a) * 0.03), root + Vector3(sin(a) * 0.04, -rng.randf_range(0.14, 0.24), cos(a) * 0.04)]), PackedFloat32Array([0.008, 0.005, 0.001]), HAIR, 0.2, 4)
	# The arms, out in front, reaching.
	for side: float in [-1.0, 1.0]:
		var sh := Vector3(side * 0.22, 1.38, -0.06)
		var el := sh + Vector3(side * 0.04, -0.08, -0.28)
		var wr := el + Vector3(side * -0.02, rng.randf_range(-0.12, 0.02), -0.27)
		s.capsule(sh, el, 0.055, 0.045, shirt, 0.03, 0.85)
		s.capsule(el, wr, 0.04, 0.032, skin, 0.03, 0.5, 0.003)
		s.ellipsoid(wr + Vector3(0.0, -0.01, -0.05), Vector3(0.04, 0.02, 0.06), skin, 0.02, 0.5)
		for f in 4:
			var fx := (float(f) - 1.5) * 0.018
			s.tube_add(PackedVector3Array([wr + Vector3(fx, -0.01, -0.09), wr + Vector3(fx, -0.04, -0.15), wr + Vector3(fx, -0.07, -0.17)]), PackedFloat32Array([0.009, 0.007, 0.003]), skin, 0.5, 4)
		s.paint_capsule(el, wr, 0.045, 0.036, BLOOD if side > 0.0 else ROT, 0.3)
	return s.noise_scale(28.0).mesh("town_shambler_%d" % v, 0.012, 4200)


## The Flyer's body: a pale ribbed thing the size of a dog, a head that is mostly mouth, hooked
## feet hanging under it and a whip of a tail.
static func flyer_body() -> ArrayMesh:
	var s := Sculpt.new()
	s.ellipsoid(Vector3(0.0, 0.0, 0.0), Vector3(0.2, 0.17, 0.42), FLYER_SKIN, 0.05, 0.4, 0.006)
	for k in 6:
		var z := -0.25 + float(k) * 0.1
		s.tube_add(PackedVector3Array([Vector3(-0.18, 0.02, z), Vector3(0.0, 0.18, z), Vector3(0.18, 0.02, z)]), PackedFloat32Array([0.015, 0.02, 0.015]), FLYER_SKIN.lightened(0.15), 0.4, 5)
	var head := Vector3(0.0, 0.03, -0.48)
	s.ellipsoid(head, Vector3(0.13, 0.12, 0.16), FLYER_SKIN, 0.04, 0.4)
	s.carve_ellipsoid(head + Vector3(0.0, -0.02, -0.12), Vector3(0.09, 0.08, 0.08), SOCKET, 0.01)  # the mouth
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for k in 18:
		var a := float(k) / 18.0 * TAU
		var root := head + Vector3(cos(a) * 0.085, -0.02 + sin(a) * 0.075, -0.15)
		s.tube_add(PackedVector3Array([root, root + Vector3(-cos(a) * 0.04, -sin(a) * 0.04, -0.01)]), PackedFloat32Array([0.007, 0.0008]), TOOTH, 0.25, 4)
	s.paint_ellipsoid(head + Vector3(0.0, 0.0, -0.1), Vector3(0.11, 0.1, 0.06), RAW, 0.2)
	for side: float in [-1.0, 1.0]:  # a pair of small black eyes set back on the head
		s.ellipsoid(head + Vector3(side * 0.08, 0.07, -0.06), Vector3(0.022, 0.022, 0.022), Color(0.0, 0.0, 0.0), 0.005, 0.05)
		s.tube_add(PackedVector3Array([Vector3(side * 0.08, -0.12, 0.1), Vector3(side * 0.1, -0.3, 0.12), Vector3(side * 0.08, -0.42, 0.05)]), PackedFloat32Array([0.025, 0.015, 0.003]), FLYER_SKIN, 0.4, 5)  # hooked feet
	s.tube_add(PackedVector3Array([Vector3(0.0, 0.0, 0.4), Vector3(0.0, -0.05, 0.7), Vector3(0.0, 0.05, 1.0), Vector3(0.0, -0.02, 1.25)]), PackedFloat32Array([0.07, 0.035, 0.015, 0.002]), FLYER_SKIN, 0.4, 6)
	return s.noise_scale(24.0).mesh("town_flyer_body", 0.016, 3200)


## A wing, hinged at its root, spreading out along +x: a membrane with finger bones run through it.
static func flyer_wing() -> ArrayMesh:
	var s := Sculpt.new()
	s.box(Vector3(0.48, 0.0, 0.08), Vector3(0.46, 0.012, 0.3), 0.01, MEMBRANE, 0.02, 0.6)
	s.carve_ellipsoid(Vector3(0.6, 0.0, 0.42), Vector3(0.18, 0.05, 0.14), MEMBRANE, 0.02)  # a scalloped trailing edge
	s.carve_ellipsoid(Vector3(0.25, 0.0, 0.43), Vector3(0.14, 0.05, 0.1), MEMBRANE, 0.02)
	s.carve_ellipsoid(Vector3(0.82, 0.0, 0.3), Vector3(0.12, 0.05, 0.12), MEMBRANE, 0.02)
	s.carve_ellipsoid(Vector3(0.55, 0.0, 0.0), Vector3(0.04, 0.05, 0.05), MEMBRANE, 0.01)  # torn through
	s.tube_add(PackedVector3Array([Vector3(0.0, 0.0, 0.0), Vector3(0.4, 0.02, -0.18), Vector3(0.95, 0.0, -0.1)]), PackedFloat32Array([0.03, 0.02, 0.006]), FLYER_SKIN, 0.4, 5)
	for k in 3:
		var tip := Vector3(0.45 + 0.2 * float(k), 0.0, 0.32 - 0.05 * float(k))
		s.tube_add(PackedVector3Array([Vector3(0.4, 0.02, -0.18), tip]), PackedFloat32Array([0.014, 0.004]), FLYER_SKIN, 0.4, 4)
	s.tube_add(PackedVector3Array([Vector3(0.95, 0.0, -0.1), Vector3(1.02, 0.0, -0.16)]), PackedFloat32Array([0.01, 0.001]), Color(0.05, 0.04, 0.03), 0.2, 4)  # a claw at the wrist
	return s.noise_scale(20.0).mesh("town_flyer_wing", 0.014, 1600)


static func build_flyer(n: Node3D) -> void:
	Sculpt.put(n, flyer_body(), flesh())
	var wing := flyer_wing()
	for w in 2:
		var p := Node3D.new()
		p.name = "Wing%d" % w
		p.position = Vector3(0.15 if w == 1 else -0.15, 0.1, -0.12)
		if w == 0:
			p.scale = Vector3(-1.0, 1.0, 1.0)  # the left is the right one mirrored
		n.add_child(p)
		var mi := Sculpt.put(p, wing, membrane())
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.scale = Vector3.ONE * 1.4
