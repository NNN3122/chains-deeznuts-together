class_name HireBody
extends Node3D
## What a Hollow Hire looks like: someone who started here and never left. Gaunt and a head too
## tall, grey veined skin over ribs that show through a torn shirt and a faded vest, a lanyard
## still round its neck, arms that hang to its knees and end in long fingers. No face: two empty
## sockets and a lipless slit full of teeth, under a hard hat a size too small.
## The rig HollowHire animates: hips (the torso and head ride on it), head, one pivot per arm and
## per leg. Positions match the old block body so its gameplay points (head, chest) still hold.

const SKIN: Color = Color(0.4, 0.42, 0.39)
const SKIN_DARK: Color = Color(0.22, 0.22, 0.23)
const SHIRT: Color = Color(0.66, 0.64, 0.56)
const VEST: Color = Color(0.72, 0.42, 0.1)
const TROUSERS: Color = Color(0.17, 0.16, 0.15)
const SHOE: Color = Color(0.07, 0.06, 0.05)
const LANYARD: Color = Color(0.9, 0.75, 0.1)
const VOID: Color = Color(0.02, 0.015, 0.015)
const GUM: Color = Color(0.25, 0.04, 0.05)
const TOOTH: Color = Color(0.78, 0.72, 0.55)
const NAIL: Color = Color(0.2, 0.18, 0.14)
const JAW_HINGE: Vector3 = Vector3(0.0, 0.2, 0.0)  # head-local: where the jaw swings from

var hips: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var thigh_l: Node3D
var thigh_r: Node3D
var jaw: Node3D  # rotation.x negative opens it
var hat: Node3D


func build() -> void:
	var flesh := Sculpt.material(0.25, 0.35, 0.75, 0.15, 0.5)
	hips = Node3D.new()
	hips.position = Vector3(0.0, 0.95, 0.0)
	add_child(hips)
	Sculpt.put(hips, torso(), flesh)
	head = Node3D.new()
	head.position = Vector3(0.0, 0.7, 0.0)
	hips.add_child(head)
	Sculpt.put(head, skull(true), flesh)
	jaw = Node3D.new()
	jaw.position = JAW_HINGE
	head.add_child(jaw)
	Sculpt.put(jaw, jaw_mesh(), flesh)
	hat = Sculpt.put(head, PlayerParts.hard_hat(Color(0.85, 0.7, 0.12)), Sculpt.material(0.0, 0.2, 0.0, 0.0, 0.3), Vector3(0.02, 0.35, 0.02), Vector3(0.1, 0.0, -0.18))
	hat.scale = Vector3.ONE * 0.85
	arm_l = _limb(Vector3(-0.24, 0.62, 0.0), arm(-1.0), flesh, hips)
	arm_r = _limb(Vector3(0.24, 0.62, 0.0), arm(1.0), flesh, hips)
	arm_l.rotation.z = -0.1
	arm_r.rotation.z = 0.1
	thigh_l = _limb(Vector3(-0.11, 0.0, 0.0), leg(), flesh, hips)
	thigh_r = _limb(Vector3(0.11, 0.0, 0.0), leg(), flesh, hips)


func _limb(at: Vector3, m: Mesh, mat: Material, parent: Node3D) -> Node3D:
	var p := Node3D.new()
	p.position = at
	parent.add_child(p)
	Sculpt.put(p, m, mat)
	return p


## Hips-local: the pelvis at 0, shoulders at 0.62, the base of the skull at 0.7.
static func torso() -> ArrayMesh:
	var s := Sculpt.new()
	s.ellipsoid(Vector3(0.0, 0.05, 0.0), Vector3(0.15, 0.1, 0.1), TROUSERS, 0.04, 0.9, 0.003)
	s.capsule(Vector3(0.0, 0.05, 0.01), Vector3(0.0, 0.42, 0.03), 0.095, 0.125, SKIN, 0.05, 0.55, 0.004)
	s.ellipsoid(Vector3(0.0, 0.42, 0.0), Vector3(0.16, 0.17, 0.11), SKIN, 0.05, 0.55, 0.004)
	for k in 5:
		var y := 0.5 - 0.045 * float(k)
		for x: float in [-1.0, 1.0]:
			s.capsule(Vector3(x * 0.03, y, -0.105), Vector3(x * 0.15, y - 0.035, -0.02), 0.012, 0.01, SKIN, 0.016, 0.5)
	for x: float in [-1.0, 1.0]:
		s.ellipsoid(Vector3(x * 0.08, 0.5, 0.09), Vector3(0.06, 0.075, 0.03), SKIN, 0.03, 0.55)  # shoulder blades
		s.capsule(Vector3(x * 0.02, 0.6, -0.07), Vector3(x * 0.18, 0.62, -0.03), 0.016, 0.014, SKIN, 0.02, 0.5)  # collarbones
	s.capsule(Vector3(-0.22, 0.6, 0.0), Vector3(0.22, 0.6, 0.0), 0.058, 0.058, SKIN, 0.05, 0.55)
	s.capsule(Vector3(0.0, 0.58, 0.02), Vector3(0.0, 0.76, 0.0), 0.05, 0.042, SKIN, 0.04, 0.55)  # the long neck
	s.capsule(Vector3(-0.012, 0.66, -0.035), Vector3(-0.03, 0.6, -0.06), 0.012, 0.012, SKIN, 0.01, 0.5)  # a tendon
	# Clothes, torn: the shirt and the vest are paint on the body, with holes back to the skin.
	s.paint_box(Vector3(0.0, 0.34, 0.0), Vector3(0.24, 0.22, 0.16), SHIRT, 0.85)
	s.paint_box(Vector3(0.0, 0.44, 0.0), Vector3(0.24, 0.12, 0.16), VEST, 0.8)
	s.paint_ellipsoid(Vector3(0.07, 0.4, -0.11), Vector3(0.075, 0.1, 0.07), SKIN, 0.5)
	s.paint_ellipsoid(Vector3(-0.11, 0.24, -0.06), Vector3(0.06, 0.07, 0.08), SKIN, 0.5)
	s.paint_ellipsoid(Vector3(-0.04, 0.5, 0.11), Vector3(0.09, 0.06, 0.05), SKIN, 0.5)
	s.paint_box(Vector3(0.0, -0.05, 0.0), Vector3(0.26, 0.14, 0.2), TROUSERS, 0.9)
	s.paint_capsule(Vector3(0.0, 0.6, -0.085), Vector3(0.0, 0.4, -0.125), 0.012, 0.012, LANYARD, 0.6)
	s.box(Vector3(0.0, 0.37, -0.128), Vector3(0.03, 0.04, 0.004), 0.003, Color(0.85, 0.85, 0.8), 0.0, 0.4)  # the ID badge
	return s.noise_scale(22.0).mesh("hire_torso", 0.012, 3500)


## Head-local: the neck rises from 0, the egg of the skull centred at 0.26. jawless: without the
## lower jaw and its teeth (the body hangs a separate jaw_mesh() on a hinge at JAW_HINGE), the inside of
## the mouth showing where it was.
static func skull(jawless: bool = false) -> ArrayMesh:
	var s := Sculpt.new()
	s.capsule(Vector3(0.0, 0.0, 0.01), Vector3(0.0, 0.15, 0.0), 0.043, 0.045, SKIN, 0.03, 0.55)
	s.ellipsoid(Vector3(0.0, 0.27, 0.01), Vector3(0.105, 0.15, 0.12), SKIN, 0.03, 0.45, 0.002)
	if not jawless:
		s.ellipsoid(Vector3(0.0, 0.17, -0.045), Vector3(0.07, 0.06, 0.07), SKIN, 0.04, 0.5)
	for x: float in [-1.0, 1.0]:
		s.ellipsoid(Vector3(x * 0.055, 0.215, -0.08), Vector3(0.03, 0.02, 0.03), SKIN, 0.02, 0.45)  # cheekbones under the skin
		s.carve_ellipsoid(Vector3(x * 0.042, 0.27, -0.105), Vector3(0.027, 0.023, 0.032), VOID, 0.014)
	# A lipless slit right across, too many teeth, none of them straight.
	s.carve_capsule(Vector3(-0.062, 0.17, -0.098), Vector3(0.062, 0.166, -0.098), 0.017, 0.016, GUM, 0.006)
	if jawless:
		s.carve_box(Vector3(0.0, 0.1, -0.085), Vector3(0.085, 0.07, 0.07), GUM, 0.012)  # the throat behind the jaw
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for k in 11:
		var x := -0.05 + 0.01 * float(k)
		var lu := rng.randf_range(0.011, 0.02)
		var ll := rng.randf_range(0.009, 0.017)
		s.tube_add(PackedVector3Array([Vector3(x, 0.186, -0.106), Vector3(x + rng.randf_range(-0.002, 0.002), 0.186 - lu, -0.112)]), PackedFloat32Array([0.0045, 0.0008]), TOOTH, 0.3, 5)
		if not jawless:
			s.tube_add(PackedVector3Array([Vector3(x + 0.005, 0.15, -0.104), Vector3(x + 0.005 + rng.randf_range(-0.002, 0.002), 0.15 + ll, -0.11)]), PackedFloat32Array([0.004, 0.0008]), TOOTH, 0.3, 5)
	s.paint_ellipsoid(Vector3(0.0, 0.27, -0.11), Vector3(0.09, 0.05, 0.03), SKIN_DARK, 0.5)  # bruised round the sockets
	return s.noise_scale(55.0).mesh("hire_skull_jawless" if jawless else "hire_skull", 0.006, 4000)


## The lower jaw, hinge-local (the hinge is JAW_HINGE in the head): a long chin and a row of teeth
## pointing up. Rotated negative about x, it drops open, far wider than a jaw should.
static func jaw_mesh() -> ArrayMesh:
	var s := Sculpt.new()
	var h := JAW_HINGE
	s.ellipsoid(Vector3(0.0, 0.16, -0.045) - h, Vector3(0.068, 0.045, 0.07), SKIN, 0.03, 0.5, 0.002)
	s.ellipsoid(Vector3(0.0, 0.135, -0.085) - h, Vector3(0.036, 0.03, 0.03), SKIN, 0.03, 0.5)
	s.carve_box(Vector3(0.0, 0.2, -0.06) - h, Vector3(0.055, 0.03, 0.05), GUM, 0.01)
	var rng := RandomNumberGenerator.new()
	rng.seed = 43
	for k in 11:
		var x := -0.05 + 0.01 * float(k) + 0.005
		var ll := rng.randf_range(0.011, 0.02)
		s.tube_add(PackedVector3Array([Vector3(x, 0.155, -0.102) - h, Vector3(x + rng.randf_range(-0.002, 0.002), 0.155 + ll, -0.108) - h]), PackedFloat32Array([0.0042, 0.0008]), TOOTH, 0.3, 5)
	return s.noise_scale(55.0).mesh("hire_jaw", 0.006, 1500)


## Shoulder-local, hanging down -y: a thin arm, a knob of an elbow, a hand with long fingers that
## reach its knees. side: +1 right, -1 left (the thumb on the inside).
static func arm(side: float) -> ArrayMesh:
	var s := Sculpt.new()
	s.capsule(Vector3.ZERO, Vector3(0.0, -0.44, 0.02), 0.046, 0.034, SKIN, 0.03, 0.55, 0.003)
	s.ellipsoid(Vector3(0.0, -0.44, 0.025), Vector3(0.038, 0.04, 0.04), SKIN, 0.025, 0.5)
	s.capsule(Vector3(0.0, -0.44, 0.025), Vector3(0.0, -0.86, -0.03), 0.034, 0.026, SKIN, 0.025, 0.55, 0.003)
	s.ellipsoid(Vector3(0.0, -0.92, -0.035), Vector3(0.034, 0.052, 0.016), SKIN, 0.025, 0.5)
	s.paint_capsule(Vector3(0.0, 0.03, 0.0), Vector3(0.0, -0.2, 0.01), 0.07, 0.065, SHIRT, 0.85)  # what's left of a sleeve
	for k in 4:
		var x := -0.024 + 0.016 * float(k)
		var l := 1.0 - absf(x) * 4.0
		var pts := PackedVector3Array([Vector3(x, -0.95, -0.035), Vector3(x * 1.1, -1.03 * l - 0.0 * (1.0 - l), -0.055), Vector3(x * 1.15, -1.1 * l - 0.01, -0.09), Vector3(x * 1.15, -1.14 * l - 0.01, -0.125)])
		s.tube_add(pts, PackedFloat32Array([0.009, 0.0075, 0.006, 0.003]), SKIN, 0.5, 6)
		s.paint_ellipsoid(pts[3], Vector3.ONE * 0.012, NAIL, 0.3)
	s.tube_add(PackedVector3Array([Vector3(-side * 0.03, -0.9, -0.04), Vector3(-side * 0.045, -0.96, -0.06), Vector3(-side * 0.048, -1.01, -0.085)]), PackedFloat32Array([0.01, 0.0075, 0.004]), SKIN, 0.5, 6)
	return s.noise_scale(40.0).mesh("hire_arm_%d" % int(side), 0.008, 2000)


## Hip-local, down to the floor at -0.95: thin legs in trousers worn through at the shins, shoes.
static func leg() -> ArrayMesh:
	var s := Sculpt.new()
	s.capsule(Vector3.ZERO, Vector3(0.0, -0.45, 0.01), 0.07, 0.05, TROUSERS, 0.03, 0.9, 0.003)
	s.ellipsoid(Vector3(0.0, -0.45, -0.005), Vector3(0.05, 0.05, 0.045), TROUSERS, 0.03, 0.9)
	s.capsule(Vector3(0.0, -0.45, 0.01), Vector3(0.0, -0.87, 0.02), 0.046, 0.034, TROUSERS, 0.03, 0.9, 0.003)
	s.paint_box(Vector3(0.0, -0.82, 0.0), Vector3(0.08, 0.06, 0.08), SKIN, 0.5)  # a bare, bony ankle
	s.box(Vector3(0.0, -0.91, -0.04), Vector3(0.045, 0.034, 0.11), 0.03, SHOE, 0.03, 0.45)
	return s.noise_scale(26.0).mesh("hire_leg", 0.011, 1200)
