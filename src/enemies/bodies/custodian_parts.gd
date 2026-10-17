class_name CustodianParts
extends RefCounted
## The Custodian's arm out of the ceiling: segments of a wet, sinewy, too-long limb (each built
## along y, 0.7 m, centred, like the capsule Custodian stretches between joints) and the hand that
## closes round a hard hat: a knuckled palm and five long fingers hooked down and in.

const FLESH: Color = Color(0.06, 0.045, 0.05)
const SINEW: Color = Color(0.16, 0.06, 0.07)
const NAIL: Color = Color(0.02, 0.015, 0.015)


static func material() -> ShaderMaterial:
	var m := Sculpt.material(0.7, 0.9, 0.4, 0.0, 0.5)
	m.set_shader_parameter("rim_col", Color(0.9, 0.15, 0.08))  # the hole's red light catching its edges
	return m


## One length of arm, the long axis along y. thick: radius at the thick end.
static func segment(thick: float) -> ArrayMesh:
	var s := Sculpt.new()
	s.capsule(Vector3(0.0, -0.33, 0.0), Vector3(0.0, 0.33, 0.0), thick * 0.85, thick, FLESH, 0.03, 0.4, 0.008)
	s.ellipsoid(Vector3(0.0, 0.3, 0.0), Vector3.ONE * thick * 1.15, FLESH, 0.04, 0.4)  # the joint
	for k in 3:
		var a := TAU * float(k) / 3.0
		var off := Vector3(cos(a), 0.0, sin(a)) * thick * 0.75
		s.capsule(off + Vector3(0.0, -0.28, 0.0), off * 1.1 + Vector3(0.0, 0.26, 0.0), thick * 0.3, thick * 0.25, SINEW, 0.025, 0.5)
	return s.noise_scale(26.0).mesh("cust_seg_%d" % int(thick * 1000.0), 0.012, 600)


## The hand, hanging down -y from the wrist at the origin, fingers curling under.
static func hand() -> ArrayMesh:
	var s := Sculpt.new()
	s.ellipsoid(Vector3(0.0, -0.06, 0.0), Vector3(0.09, 0.08, 0.05), FLESH, 0.04, 0.4, 0.004)
	for k in 5:
		var a := TAU * float(k) / 5.0
		var dir := Vector3(cos(a), 0.0, sin(a))
		var root := dir * 0.07 + Vector3(0.0, -0.1, 0.0)
		s.ellipsoid(root, Vector3.ONE * 0.028, FLESH, 0.02, 0.4)  # knuckle
		s.tube_add(PackedVector3Array([root, root + dir * 0.09 + Vector3(0.0, -0.08, 0.0), root + dir * 0.13 + Vector3(0.0, -0.2, 0.0), root + dir * 0.08 + Vector3(0.0, -0.3, 0.0), root + dir * 0.01 + Vector3(0.0, -0.35, 0.0)]), PackedFloat32Array([0.022, 0.018, 0.014, 0.008, 0.002]), FLESH, 0.4, 6)
	return s.noise_scale(40.0).mesh("cust_hand", 0.01, 1500)
