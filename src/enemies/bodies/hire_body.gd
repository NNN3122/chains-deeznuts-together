class_name HireBody
extends Node3D
## What a Hollow Hire looks like: someone who started here and never left. Gaunt and a head too
## tall, grey veined skin over ribs that show through a torn shirt and a faded vest, a lanyard
## still round its neck, arms that hang to its knees and end in long fingers. No face: two empty
## sockets and a lipless slit full of teeth, under a hard hat a size too small.
## The rig HollowHire animates: hips (the torso and head ride on it), head, one pivot per arm and
## per leg. Positions match the old block body so its gameplay points (head, chest) still hold.

# Colours (18 Oct, the user: "make the hire color more scary"): a corpse's bloodless grey-white
# that shows up pale in the dark, black-purple bruising and rot, old blood down its face, chest
# and claws, and clothes gone to filth instead of the bright safety orange.
const SKIN: Color = Color(0.5, 0.5, 0.45)
const SKIN_DARK: Color = Color(0.14, 0.08, 0.12)  # bruise and rot
const ROT: Color = Color(0.3, 0.33, 0.22)  # greenish blotches where it's going off
const BLOOD: Color = Color(0.26, 0.015, 0.015)  # old, dark, dried
const BLOOD_WET: Color = Color(0.3, 0.015, 0.02)
const SHIRT: Color = Color(0.36, 0.33, 0.27)
const VEST: Color = Color(0.24, 0.12, 0.05)
const TROUSERS: Color = Color(0.09, 0.085, 0.08)
const SHOE: Color = Color(0.04, 0.035, 0.03)
const LANYARD: Color = Color(0.3, 0.08, 0.06)
const VOID: Color = Color(0.0, 0.0, 0.0)
const GUM: Color = Color(0.2, 0.01, 0.02)
const TOOTH: Color = Color(0.55, 0.47, 0.32)
const NAIL: Color = Color(0.05, 0.03, 0.025)
const HAT: Color = Color(0.42, 0.33, 0.1)  # grimed over, no longer safety yellow
const HAIR: Color = Color(0.05, 0.045, 0.04)
const THREAD: Color = Color(0.04, 0.03, 0.025)  # the stitches someone put in it
const STAPLE: Color = Color(0.35, 0.33, 0.3)
const VEIN: Color = Color(0.2, 0.11, 0.19)
# 19 Oct, the user: "add more color and wrap the body with bones and spikes and veins".
const VEIN_RED: Color = Color(0.34, 0.04, 0.07)  # swollen veins wound round it
const BONE: Color = Color(0.72, 0.66, 0.52)  # stained ivory, pushed out through the skin
const RAW: Color = Color(0.46, 0.07, 0.06)  # flesh where the skin has come away
const BRUISE: Color = Color(0.26, 0.1, 0.28)
const PUS: Color = Color(0.56, 0.5, 0.13)
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
	var flesh := Sculpt.material(0.08, 0.06, 1.0, 0.03, 1.0)  # matte and dry: shine read as latex; the rim emits even in the dark, so only a trace of it
	flesh.set_shader_parameter("rim_col", Color(0.55, 0.06, 0.05))  # a dull red edge where light catches its outline
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
	hat = Sculpt.put(head, PlayerParts.hard_hat(HAT), Sculpt.material(0.0, 0.0, 0.0, 0.0, 0.3), Vector3(0.02, 0.35, 0.02), Vector3(0.1, 0.0, -0.18))
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
	s.box(Vector3(0.0, 0.37, -0.128), Vector3(0.03, 0.04, 0.004), 0.003, Color(0.55, 0.5, 0.42), 0.0, 0.4)  # the ID badge
	# Rot, bruises and blood: down the throat from the mouth onto the chest, soaked into the shirt.
	s.paint_ellipsoid(Vector3(0.09, 0.3, -0.1), Vector3(0.06, 0.08, 0.05), ROT, 0.6)
	s.paint_ellipsoid(Vector3(-0.1, 0.46, 0.08), Vector3(0.07, 0.05, 0.05), SKIN_DARK, 0.6)
	s.paint_ellipsoid(Vector3(0.12, 0.56, -0.02), Vector3(0.05, 0.04, 0.06), SKIN_DARK, 0.6)
	s.paint_capsule(Vector3(0.0, 0.76, -0.05), Vector3(0.01, 0.56, -0.1), 0.015, 0.025, BLOOD, 0.8)
	s.paint_ellipsoid(Vector3(0.02, 0.47, -0.12), Vector3(0.07, 0.06, 0.05), BLOOD, 0.8)
	s.paint_capsule(Vector3(-0.03, 0.4, -0.12), Vector3(-0.05, 0.22, -0.1), 0.018, 0.01, BLOOD, 0.8)
	s.paint_capsule(Vector3(0.06, 0.38, -0.12), Vector3(0.08, 0.26, -0.1), 0.014, 0.008, BLOOD, 0.8)
	# A long wound across the belly, sewn shut badly with black thread, weeping at the ends.
	var ga := Vector3(-0.085, 0.21, -0.104)
	var gb := Vector3(0.075, 0.13, -0.1)
	s.carve_capsule(ga, gb, 0.011, 0.009, GUM, 0.006)
	s.paint_capsule(ga, gb, 0.022, 0.02, BLOOD, 0.7)
	var perp := Vector3(0.08, 0.16, 0.0).normalized() * 0.022
	for k in 6:
		var m := ga.lerp(gb, (float(k) + 0.5) / 6.0) + Vector3(0.0, 0.0, -0.01)
		s.tube_add(PackedVector3Array([m + perp, m - perp]), PackedFloat32Array([0.0028, 0.0028]), THREAD, 0.7, 4)
	# Sores, burst and weeping.
	for at: Vector3 in [Vector3(-0.13, 0.42, -0.07), Vector3(0.1, 0.07, -0.085), Vector3(-0.05, 0.53, -0.1), Vector3(0.14, 0.33, -0.04)]:
		s.carve_ellipsoid(at, Vector3(0.013, 0.011, 0.012), BLOOD_WET, 0.006)
		s.paint_ellipsoid(at, Vector3(0.026, 0.024, 0.026), SKIN_DARK, 0.6)
	# The spine pushing through the skin of its back, up into the neck, a bone spike off each knuckle of it.
	for k in 10:
		var y := 0.3 + 0.047 * float(k)
		var z := 0.112 - 0.012 * maxf(0.0, float(k) - 6.0)
		s.ellipsoid(Vector3(0.0, y, z), Vector3(0.02, 0.016, 0.016), SKIN, 0.018, 0.5)
		if k >= 1:
			var l := 0.045 + 0.02 * sin(float(k) * 1.7)
			s.tube_add(PackedVector3Array([Vector3(0.0, y - 0.004, z + 0.004), Vector3(0.0, y + l * 0.4, z + l * 0.6), Vector3(0.0, y + l * 0.9, z + l * 1.2)]), PackedFloat32Array([0.011, 0.005, 0.0008]), BONE, 0.4, 5)
	# Ribs broken out through the skin and the shirt, a cage round the chest, the front ends snapped.
	for side: float in [-1.0, 1.0]:
		for y: float in [0.5, 0.42, 0.34]:
			var rx := _torso_rx(y) + 0.008
			s.tube_add(PackedVector3Array([Vector3(side * 0.035, y, 0.118), Vector3(side * rx * 0.8, y - 0.012, 0.088), Vector3(side * rx, y - 0.03, 0.0), Vector3(side * rx * 0.8, y - 0.05, -0.082), Vector3(side * 0.07, y - 0.06, -0.118)]), PackedFloat32Array([0.007, 0.0085, 0.0085, 0.007, 0.004]), BONE, 0.4, 6)
		# A spike out of each shoulder, a smaller one behind it.
		s.tube_add(PackedVector3Array([Vector3(side * 0.19, 0.62, 0.0), Vector3(side * 0.225, 0.69, 0.02), Vector3(side * 0.255, 0.77, 0.045)]), PackedFloat32Array([0.017, 0.008, 0.001]), BONE, 0.4, 6)
		s.tube_add(PackedVector3Array([Vector3(side * 0.13, 0.6, 0.07), Vector3(side * 0.155, 0.655, 0.105), Vector3(side * 0.17, 0.7, 0.14)]), PackedFloat32Array([0.012, 0.006, 0.0008]), BONE, 0.4, 5)
	# Veins wound round and round it from the collarbones to the hips, and up the neck.
	for v in 3:
		var pts := PackedVector3Array()
		var rad := PackedFloat32Array()
		for i in 30:
			var t := float(i) / 29.0
			var y := lerpf(0.56, 0.04, t)
			var th := TAU * 1.7 * t + float(v) * TAU / 3.0 + 0.35 * sin(t * 11.0 + float(v) * 2.0)
			pts.append(Vector3(sin(th) * (_torso_rx(y) - 0.002), y, cos(th) * 0.108 + 0.012))
			rad.append(0.0068 + 0.0018 * sin(t * 17.0 + float(v)))
		s.tube_add(pts, rad, VEIN_RED if v != 1 else VEIN, 0.35, 5)
	var neck := PackedVector3Array()
	for i in 12:
		var t := float(i) / 11.0
		var th := TAU * 1.2 * t + 1.0
		neck.append(Vector3(sin(th) * lerpf(0.05, 0.043, t), lerpf(0.58, 0.76, t), cos(th) * lerpf(0.05, 0.043, t) + lerpf(0.02, 0.0, t)))
	s.tube_add(neck, PackedFloat32Array([0.005, 0.005, 0.0045, 0.0045, 0.004, 0.004, 0.004, 0.0035, 0.0035, 0.003, 0.003, 0.0025]), VEIN_RED, 0.35, 5)
	# Colour: skin torn away to the raw meat on a shoulder and a flank, purple bruising, pus blisters.
	s.paint_ellipsoid(Vector3(-0.17, 0.57, -0.02), Vector3(0.05, 0.045, 0.06), RAW, 0.25)
	s.paint_ellipsoid(Vector3(0.12, 0.2, 0.04), Vector3(0.04, 0.06, 0.07), RAW, 0.25)
	s.paint_ellipsoid(Vector3(0.11, 0.48, -0.08), Vector3(0.05, 0.04, 0.05), BRUISE, 0.6)
	s.paint_ellipsoid(Vector3(-0.08, 0.12, 0.09), Vector3(0.06, 0.05, 0.05), BRUISE, 0.6)
	for at: Vector3 in [Vector3(-0.115, 0.3, -0.06), Vector3(0.05, 0.56, -0.08), Vector3(-0.15, 0.48, 0.05), Vector3(0.13, 0.12, -0.03), Vector3(0.0, 0.22, -0.112)]:
		s.ellipsoid(at, Vector3(0.011, 0.01, 0.011), PUS, 0.007, 0.2)
	return s.noise_scale(22.0).mesh("hire_torso", 0.01, 7000)


## Head-local: the neck rises from 0, the egg of the skull centred at 0.26. jawless: without the
## lower jaw and its teeth (the body hangs a separate jaw_mesh() on a hinge at JAW_HINGE), the inside of
## the mouth showing where it was.
static func skull(jawless: bool = false) -> ArrayMesh:
	var s := Sculpt.new()
	s.capsule(Vector3(0.0, 0.0, 0.01), Vector3(0.0, 0.15, 0.0), 0.043, 0.045, SKIN, 0.03, 0.55)
	s.ellipsoid(Vector3(0.0, 0.27, 0.01), Vector3(0.105, 0.15, 0.12), SKIN, 0.03, 0.45, 0.004)
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
	s.paint_ellipsoid(Vector3(0.0, 0.27, -0.11), Vector3(0.1, 0.055, 0.035), SKIN_DARK, 0.5)  # bruised black round the sockets
	for x: float in [-1.0, 1.0]:
		s.paint_capsule(Vector3(x * 0.044, 0.25, -0.115), Vector3(x * 0.05, 0.17, -0.1), 0.005, 0.003, BLOOD_WET, 0.6)  # it weeps blood
	s.paint_ellipsoid(Vector3(0.05, 0.36, -0.06), Vector3(0.05, 0.04, 0.06), ROT, 0.6)
	# One cheek torn open from the corner of the slit back toward the ear.
	s.carve_capsule(Vector3(0.06, 0.168, -0.1), Vector3(0.09, 0.19, -0.065), 0.011, 0.007, GUM, 0.005)
	s.paint_capsule(Vector3(0.06, 0.168, -0.1), Vector3(0.09, 0.19, -0.065), 0.02, 0.016, BLOOD, 0.7)
	# A gash across the forehead held shut with office staples.
	var fa := Vector3(-0.055, 0.335, -0.094)
	var fb := Vector3(0.03, 0.31, -0.102)
	s.carve_capsule(fa, fb, 0.0055, 0.0045, BLOOD_WET, 0.004)
	s.paint_capsule(fa, fb, 0.013, 0.011, BLOOD, 0.7)
	for k in 4:
		var m := fa.lerp(fb, (float(k) + 0.5) / 4.0) + Vector3(0.0, 0.0, -0.003)
		s.tube_add(PackedVector3Array([m + Vector3(0.0, 0.008, 0.002), m + Vector3(0.0, 0.007, -0.001), m + Vector3(0.0, -0.007, -0.001), m + Vector3(0.0, -0.008, 0.002)]), PackedFloat32Array([0.0014, 0.0014, 0.0014, 0.0014]), STAPLE, 0.25, 4)
	# Bone spurs out of the back of the skull under the brim, and veins crawling over the temples.
	for x: float in [-0.05, 0.0, 0.05]:
		var root := Vector3(x, 0.28 - absf(x) * 0.4, 0.118)
		s.tube_add(PackedVector3Array([root, root + Vector3(x * 0.4, 0.035, 0.04), root + Vector3(x * 0.9, 0.06, 0.085)]), PackedFloat32Array([0.012, 0.005, 0.0008]), BONE, 0.4, 5)
	for x: float in [-1.0, 1.0]:
		s.tube_add(PackedVector3Array([Vector3(x * 0.088, 0.36, -0.035), Vector3(x * 0.103, 0.3, -0.012), Vector3(x * 0.1, 0.25, -0.035), Vector3(x * 0.085, 0.2, -0.06)]), PackedFloat32Array([0.0028, 0.0035, 0.003, 0.002]), VEIN_RED, 0.35, 4)
	s.paint_ellipsoid(Vector3(-0.07, 0.33, -0.07), Vector3(0.04, 0.035, 0.04), BRUISE, 0.6)
	s.ellipsoid(Vector3(0.075, 0.24, -0.085), Vector3(0.008, 0.008, 0.008), PUS, 0.005, 0.2)
	# Lank hair hanging from under the hat, thin and wet.
	var hrng := RandomNumberGenerator.new()
	hrng.seed = 47
	for k in 26:
		var a := lerpf(-1.95, 1.95, float(k) / 25.0) + hrng.randf_range(-0.08, 0.08)  # round the back of the head
		var root := Vector3(sin(a) * 0.098, 0.34 + hrng.randf_range(-0.02, 0.01), cos(a) * 0.105 + 0.01)
		var out := Vector3(sin(a), 0.0, cos(a))
		var l := hrng.randf_range(0.12, 0.3)
		s.tube_add(PackedVector3Array([root, root + out * 0.012 + Vector3(0.0, -l * 0.35, 0.0), root + out * 0.016 + Vector3(hrng.randf_range(-0.012, 0.012), -l * 0.7, 0.0), root + out * (0.014 + hrng.randf_range(-0.008, 0.012)) + Vector3(hrng.randf_range(-0.01, 0.01), -l, 0.0)]), PackedFloat32Array([0.0032, 0.0026, 0.0018, 0.0008]), HAIR, 0.45, 4)
	return s.noise_scale(55.0).mesh("hire_skull_jawless" if jawless else "hire_skull", 0.0055, 6500)


## The lower jaw, hinge-local (the hinge is JAW_HINGE in the head): a long chin and a row of teeth
## pointing up. Rotated negative about x, it drops open, far wider than a jaw should.
static func jaw_mesh() -> ArrayMesh:
	var s := Sculpt.new()
	var h := JAW_HINGE
	s.ellipsoid(Vector3(0.0, 0.16, -0.045) - h, Vector3(0.068, 0.045, 0.07), SKIN, 0.03, 0.5, 0.002)
	s.ellipsoid(Vector3(0.0, 0.135, -0.085) - h, Vector3(0.036, 0.03, 0.03), SKIN, 0.03, 0.5)
	s.carve_box(Vector3(0.0, 0.2, -0.06) - h, Vector3(0.055, 0.03, 0.05), GUM, 0.01)
	s.paint_ellipsoid(Vector3(0.0, 0.13, -0.09) - h, Vector3(0.035, 0.04, 0.02), BLOOD, 0.8)  # down the chin
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
	s.paint_capsule(Vector3(0.0, -0.8, -0.02), Vector3(0.0, -0.95, -0.04), 0.045, 0.045, BLOOD, 0.8)  # stained to the wrist
	s.paint_ellipsoid(Vector3(0.0, -0.44, 0.02), Vector3(0.05, 0.06, 0.05), SKIN_DARK, 0.6)
	s.paint_ellipsoid(Vector3(side * 0.02, -0.62, 0.0), Vector3(0.04, 0.07, 0.04), ROT, 0.6)
	# Veins standing out dark along the forearm, and knuckles like stones under the skin.
	for v: float in [-1.0, 1.0]:
		s.tube_add(PackedVector3Array([Vector3(v * 0.008, -0.48, -0.012), Vector3(v * 0.014, -0.6, -0.027), Vector3(v * 0.004, -0.72, -0.04), Vector3(v * 0.012, -0.85, -0.052)]), PackedFloat32Array([0.004, 0.0048, 0.004, 0.003]), VEIN, 0.5, 5)
	for k in 4:
		s.ellipsoid(Vector3(-0.024 + 0.016 * float(k), -0.955, -0.046), Vector3(0.009, 0.009, 0.008), SKIN, 0.008, 0.5)
	# A vein wound round the upper arm and another round the forearm.
	_wrap(s, Vector3(0.0, -0.03, 0.0), Vector3(0.0, -0.42, 0.02), 0.045, 0.035, 1.6, side, VEIN_RED, 0.0045)
	_wrap(s, Vector3(0.0, -0.48, 0.022), Vector3(0.0, -0.86, -0.03), 0.033, 0.026, 1.9, side + 2.0, VEIN, 0.004)
	# The elbow broken out backward into a spike, two spurs along the forearm, and the ulna showing
	# through a strip of raw meat down the back of it.
	s.tube_add(PackedVector3Array([Vector3(0.0, -0.44, 0.04), Vector3(0.0, -0.42, 0.09), Vector3(0.0, -0.39, 0.14)]), PackedFloat32Array([0.016, 0.007, 0.001]), BONE, 0.4, 6)
	for y: float in [-0.6, -0.73]:
		s.tube_add(PackedVector3Array([Vector3(side * 0.024, y, 0.006), Vector3(side * 0.05, y + 0.012, 0.022), Vector3(side * 0.075, y + 0.03, 0.035)]), PackedFloat32Array([0.009, 0.004, 0.0007]), BONE, 0.4, 5)
	s.paint_capsule(Vector3(0.0, -0.5, 0.03), Vector3(0.0, -0.8, -0.005), 0.024, 0.02, RAW, 0.25)
	s.tube_add(PackedVector3Array([Vector3(0.0, -0.5, 0.044), Vector3(0.0, -0.65, 0.03), Vector3(0.0, -0.8, 0.012)]), PackedFloat32Array([0.009, 0.008, 0.008]), BONE, 0.4, 6)
	s.paint_ellipsoid(Vector3(side * -0.02, -0.25, -0.03), Vector3(0.04, 0.06, 0.04), BRUISE, 0.6)
	s.ellipsoid(Vector3(side * 0.03, -0.33, -0.02), Vector3(0.009, 0.009, 0.009), PUS, 0.006, 0.2)
	for k in 4:
		var x := -0.024 + 0.016 * float(k)
		var l := 1.0 - absf(x) * 4.0
		var pts := PackedVector3Array([Vector3(x, -0.95, -0.035), Vector3(x * 1.1, -1.03 * l - 0.0 * (1.0 - l), -0.055), Vector3(x * 1.15, -1.1 * l - 0.01, -0.09), Vector3(x * 1.15, -1.14 * l - 0.01, -0.125)])
		s.tube_add(pts, PackedFloat32Array([0.009, 0.0075, 0.006, 0.003]), SKIN, 0.5, 6)
		s.paint_ellipsoid(pts[3], Vector3.ONE * 0.012, NAIL, 0.3)
		s.paint_ellipsoid(pts[2], Vector3.ONE * 0.022, BLOOD, 0.8)  # fingers dark with it
	s.tube_add(PackedVector3Array([Vector3(-side * 0.03, -0.9, -0.04), Vector3(-side * 0.045, -0.96, -0.06), Vector3(-side * 0.048, -1.01, -0.085)]), PackedFloat32Array([0.01, 0.0075, 0.004]), SKIN, 0.5, 6)
	return s.noise_scale(40.0).mesh("hire_arm_%d" % int(side), 0.007, 3800)


## Hip-local, down to the floor at -0.95: thin legs in trousers worn through at the shins, shoes.
static func leg() -> ArrayMesh:
	var s := Sculpt.new()
	s.capsule(Vector3.ZERO, Vector3(0.0, -0.45, 0.01), 0.07, 0.05, TROUSERS, 0.03, 0.9, 0.003)
	s.ellipsoid(Vector3(0.0, -0.45, -0.005), Vector3(0.05, 0.05, 0.045), TROUSERS, 0.03, 0.9)
	s.capsule(Vector3(0.0, -0.45, 0.01), Vector3(0.0, -0.87, 0.02), 0.046, 0.034, TROUSERS, 0.03, 0.9, 0.003)
	s.paint_box(Vector3(0.0, -0.82, 0.0), Vector3(0.08, 0.06, 0.08), SKIN, 0.5)  # a bare, bony ankle
	s.box(Vector3(0.0, -0.91, -0.04), Vector3(0.045, 0.034, 0.11), 0.03, SHOE, 0.03, 0.45)
	# The shinbone snapped and out through a tear in the trousers, the meat round it showing.
	s.paint_ellipsoid(Vector3(0.0, -0.64, -0.035), Vector3(0.035, 0.07, 0.025), RAW, 0.25)
	s.paint_ellipsoid(Vector3(0.0, -0.64, -0.03), Vector3(0.045, 0.09, 0.03), BLOOD, 0.6)
	s.tube_add(PackedVector3Array([Vector3(0.004, -0.56, -0.03), Vector3(0.002, -0.64, -0.048), Vector3(0.0, -0.7, -0.075)]), PackedFloat32Array([0.011, 0.01, 0.003]), BONE, 0.4, 6)
	_wrap(s, Vector3(0.0, -0.7, 0.012), Vector3(0.0, -0.86, 0.02), 0.04, 0.035, 1.2, 0.5, VEIN_RED, 0.0035)
	return s.noise_scale(26.0).mesh("hire_leg", 0.011, 1800)


## Half-width of the torso at hips-local height y (the chest ellipsoid up top, the waist below),
## for things wound round it.
static func _torso_rx(y: float) -> float:
	return lerpf(0.105, 0.155, smoothstep(0.22, 0.44, y))


## A vein wound turns times round the limb segment a -> b (radius ra at a, rb at b), starting at
## angle phase, tube radius thick.
static func _wrap(s: Sculpt, a: Vector3, b: Vector3, ra: float, rb: float, turns: float, phase: float, color: Color, thick: float) -> void:
	var axis := (b - a).normalized()
	var u := axis.cross(Vector3.FORWARD).normalized()
	var w := axis.cross(u)
	var pts := PackedVector3Array()
	var rad := PackedFloat32Array()
	var n := int(ceilf(turns * 10.0)) + 2
	for i in n:
		var t := float(i) / float(n - 1)
		var th := TAU * turns * t + phase
		pts.append(a.lerp(b, t) + (u * cos(th) + w * sin(th)) * lerpf(ra, rb, t))
		rad.append(thick * (1.0 - 0.4 * t))
	s.tube_add(pts, rad, color, 0.35, 5)
