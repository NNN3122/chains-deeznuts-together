class_name GroundskeeperBody
extends HireBody
## What hunts the grounds of Ashgrave Manor: the Groundskeeper, a head taller than you and hunched
## under a long black oilskin coat caked with grave mud, a noose still round its neck. Its head is
## a burlap sack sewn on with twine: two ragged eyeholes with a pale pinpoint deep in each, a seam
## stitched down the front, and a mouth torn through the sacking, wet and full of teeth. A slouch
## hat. Grey hands, fingers too long, black nails. A lantern hangs at its hip and burns a sickly
## yellow-green, so in the fog you see the light swinging toward you before you see it.
## The same rig as the Hire (hips, head, jaw, hat, arms, legs, same pivots), so HollowHire's whole
## animation, catch and bite play on it unchanged; the whole body is drawn SCALE larger.

const SCALE: float = 1.18
const COAT: Color = Color(0.085, 0.08, 0.068)
const COAT_WORN: Color = Color(0.16, 0.14, 0.11)
const SACK: Color = Color(0.4, 0.34, 0.24)
const SACK_DARK: Color = Color(0.2, 0.16, 0.11)
const TWINE: Color = Color(0.2, 0.16, 0.1)
const GREY: Color = Color(0.42, 0.42, 0.39)
const MUD: Color = Color(0.14, 0.1, 0.065)
const FELT: Color = Color(0.065, 0.06, 0.055)
const BOOT: Color = Color(0.055, 0.045, 0.04)
const ROPE: Color = Color(0.3, 0.25, 0.16)
const PINPOINT: Color = Color(0.85, 0.86, 0.72)
const LANTERN_LIGHT: Color = Color(0.72, 0.85, 0.42)

var lantern_light: OmniLight3D


func build() -> void:
	scale = Vector3.ONE * SCALE
	var cloth := Sculpt.material(0.12, 0.04, 0.0, 0.0, 0.7)
	cloth.set_shader_parameter("rim_col", Color(0.3, 0.4, 0.2))
	var flesh := Sculpt.material(0.08, 0.04, 1.0, 0.02, 1.0)
	hips = Node3D.new()
	hips.position = Vector3(0.0, 0.95, 0.0)
	add_child(hips)
	Sculpt.put(hips, gk_torso(), cloth)
	head = Node3D.new()
	head.position = Vector3(0.0, 0.7, 0.0)
	hips.add_child(head)
	Sculpt.put(head, gk_head(), cloth)
	jaw = Node3D.new()
	jaw.position = JAW_HINGE
	head.add_child(jaw)
	Sculpt.put(jaw, gk_jaw(), cloth)
	hat = Sculpt.put(head, gk_hat(), cloth, Vector3(0.0, 0.4, 0.02), Vector3(0.12, 0.0, 0.08))
	arm_l = _limb(Vector3(-0.24, 0.62, 0.0), gk_arm(-1.0), flesh, hips)
	arm_r = _limb(Vector3(0.24, 0.62, 0.0), gk_arm(1.0), flesh, hips)
	arm_l.rotation.z = -0.1
	arm_r.rotation.z = 0.1
	thigh_l = _limb(Vector3(-0.11, 0.0, 0.0), gk_leg(), cloth, hips)
	thigh_r = _limb(Vector3(0.11, 0.0, 0.0), gk_leg(), cloth, hips)
	# The lantern at its hip: a cage, a glowing wick, a light that swings with it.
	var lantern := Node3D.new()
	lantern.position = Vector3(0.21, -0.02, -0.06)
	hips.add_child(lantern)
	Sculpt.put(lantern, gk_lantern(), cloth)
	var glow := MeshInstance3D.new()
	var gm := SphereMesh.new()
	gm.radius = 0.035
	gm.height = 0.07
	gm.radial_segments = 10
	gm.rings = 5
	glow.mesh = gm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = LANTERN_LIGHT
	gmat.emission_enabled = true
	gmat.emission = LANTERN_LIGHT
	gmat.emission_energy_multiplier = 4.0
	glow.material_override = gmat
	glow.position = Vector3(0.0, -0.13, 0.0)
	lantern.add_child(glow)
	lantern_light = OmniLight3D.new()
	lantern_light.light_color = LANTERN_LIGHT
	lantern_light.light_energy = 0.9
	lantern_light.omni_range = 6.5
	lantern_light.omni_attenuation = 1.6
	lantern_light.light_volumetric_fog_energy = 2.0  # a halo in the fog: you see it before you see it
	lantern_light.position = Vector3(0.0, -0.13, 0.0)
	lantern.add_child(lantern_light)


## Hips-local: the coat over a hunched back, its skirt hanging to the knees with a slit up the
## front, a rope noose round the neck, grave mud caked up the hem.
static func gk_torso() -> ArrayMesh:
	var s := Sculpt.new()
	s.capsule(Vector3(0.0, -0.02, 0.01), Vector3(0.0, 0.42, 0.03), 0.13, 0.15, COAT, 0.05, 0.75, 0.004)
	s.ellipsoid(Vector3(0.0, 0.43, 0.02), Vector3(0.19, 0.18, 0.13), COAT, 0.05, 0.75, 0.004)
	s.ellipsoid(Vector3(0.0, 0.54, 0.11), Vector3(0.18, 0.15, 0.11), COAT, 0.06, 0.75, 0.004)  # the hunch
	s.capsule(Vector3(-0.23, 0.6, 0.02), Vector3(0.23, 0.6, 0.02), 0.075, 0.075, COAT, 0.05, 0.75)
	s.capsule(Vector3(0.0, 0.58, 0.03), Vector3(0.0, 0.76, 0.0), 0.05, 0.043, GREY, 0.03, 0.6)  # the neck
	s.ellipsoid(Vector3(0.0, 0.66, 0.04), Vector3(0.12, 0.07, 0.1), COAT, 0.03, 0.75)  # the collar, turned up
	# The skirt of the coat to the knees, split up the front so the legs move.
	s.capsule(Vector3(0.0, 0.02, 0.03), Vector3(0.0, -0.5, 0.07), 0.16, 0.23, COAT, 0.06, 0.78, 0.006)
	s.carve_box(Vector3(0.0, -0.33, -0.2), Vector3(0.07, 0.3, 0.12), COAT_WORN, 0.02)
	s.carve_box(Vector3(0.0, -0.4, 0.0), Vector3(0.12, 0.25, 0.14), COAT_WORN, 0.03)  # hollow inside, where the legs swing
	for k in 5:
		var a := -2.4 + 1.2 * float(k)
		s.carve_ellipsoid(Vector3(sin(a) * 0.24, -0.58, cos(a) * 0.24 + 0.07), Vector3(0.08, 0.1, 0.08), COAT_WORN, 0.02)  # a ragged hem
	s.paint_capsule(Vector3(0.0, -0.3, 0.05), Vector3(0.0, -0.55, 0.07), 0.25, 0.26, MUD, 0.9)
	s.paint_ellipsoid(Vector3(0.1, 0.3, -0.13), Vector3(0.07, 0.12, 0.04), COAT_WORN, 0.85)
	s.paint_box(Vector3(0.0, 0.08, 0.0), Vector3(0.16, 0.025, 0.16), Color(0.05, 0.04, 0.03), 0.6)  # a belt
	var noose := PackedVector3Array()
	var radii := PackedFloat32Array()
	for k in 13:
		var a := TAU * float(k) / 12.0
		noose.append(Vector3(sin(a) * 0.062, 0.7 + 0.015 * cos(a), cos(a) * 0.062 + 0.01))
		radii.append(0.014)
	s.tube_add(noose, radii, ROPE, 0.9, 5)
	s.tube_add(PackedVector3Array([Vector3(0.0, 0.69, 0.07), Vector3(0.02, 0.6, 0.15), Vector3(0.0, 0.42, 0.17), Vector3(0.03, 0.3, 0.16)]), PackedFloat32Array([0.014, 0.013, 0.012, 0.01]), ROPE, 0.9, 5)
	return s.noise_scale(18.0).mesh("gk_torso", 0.012, 5000)


## Head-local: the sack drawn over the skull and tied at the neck, the seam sewn down its front,
## two ragged eyeholes with a pale pinpoint in each, the mouth torn through it with teeth showing.
## The lower jaw is separate (gk_jaw), hinged at JAW_HINGE like the Hire's.
static func gk_head() -> ArrayMesh:
	var s := Sculpt.new()
	s.capsule(Vector3(0.0, 0.0, 0.01), Vector3(0.0, 0.14, 0.0), 0.046, 0.05, SACK, 0.03, 0.9, 0.003)
	s.ellipsoid(Vector3(0.0, 0.27, 0.01), Vector3(0.12, 0.165, 0.13), SACK, 0.03, 0.92, 0.007)
	s.ellipsoid(Vector3(0.02, 0.42, 0.04), Vector3(0.07, 0.07, 0.07), SACK, 0.05, 0.92, 0.006, Basis.from_euler(Vector3(0.4, 0.0, 0.3)))  # the bunched top
	for x: float in [-1.0, 1.0]:
		s.carve_ellipsoid(Vector3(x * 0.047, 0.29, -0.118), Vector3(0.027, 0.021, 0.03), Color(0.0, 0.0, 0.0), 0.006)
		s.ellipsoid(Vector3(x * 0.047, 0.29, -0.1), Vector3(0.008, 0.008, 0.006), PINPOINT, 0.002, 0.3)
		s.paint_ellipsoid(Vector3(x * 0.047, 0.29, -0.118), Vector3(0.045, 0.04, 0.03), SACK_DARK, 0.95)  # filthy round the holes
	s.carve_capsule(Vector3(-0.07, 0.17, -0.105), Vector3(0.07, 0.165, -0.105), 0.019, 0.017, GUM, 0.006)
	var rng := RandomNumberGenerator.new()
	rng.seed = 51
	for k in 12:
		var x := -0.058 + 0.0105 * float(k)
		var lu := rng.randf_range(0.012, 0.022)
		s.tube_add(PackedVector3Array([Vector3(x, 0.188, -0.112), Vector3(x + rng.randf_range(-0.003, 0.003), 0.188 - lu, -0.118)]), PackedFloat32Array([0.0045, 0.0008]), TOOTH, 0.3, 5)
	s.paint_ellipsoid(Vector3(0.0, 0.16, -0.11), Vector3(0.1, 0.045, 0.03), BLOOD, 0.4)  # soaked through round the mouth
	# The seam up the front, sewn with coarse twine.
	s.paint_box(Vector3(0.0, 0.36, -0.12), Vector3(0.006, 0.07, 0.02), SACK_DARK, 1.0)
	for k in 5:
		var y := 0.31 + 0.025 * float(k)
		s.tube_add(PackedVector3Array([Vector3(-0.012, y, -0.122), Vector3(0.012, y + 0.008, -0.124)]), PackedFloat32Array([0.0025, 0.0025]), TWINE, 0.9, 4)
	# Tied off at the neck.
	var tie := PackedVector3Array()
	var tr := PackedFloat32Array()
	for k in 13:
		var a := TAU * float(k) / 12.0
		tie.append(Vector3(sin(a) * 0.054, 0.09, cos(a) * 0.054 + 0.01))
		tr.append(0.007)
	s.tube_add(tie, tr, TWINE, 0.9, 4)
	s.paint_ellipsoid(Vector3(0.06, 0.2, 0.05), Vector3(0.06, 0.08, 0.08), MUD, 0.95)
	return s.noise_scale(60.0).mesh("gk_head", 0.006, 5500)


## Hinge-local: the sacking over its chin, a row of teeth, blood soaked through.
static func gk_jaw() -> ArrayMesh:
	var s := Sculpt.new()
	var h := JAW_HINGE
	s.ellipsoid(Vector3(0.0, 0.158, -0.045) - h, Vector3(0.075, 0.048, 0.075), SACK, 0.03, 0.92, 0.004)
	s.ellipsoid(Vector3(0.0, 0.133, -0.085) - h, Vector3(0.04, 0.032, 0.032), SACK, 0.03, 0.92)
	s.carve_box(Vector3(0.0, 0.2, -0.06) - h, Vector3(0.06, 0.03, 0.05), GUM, 0.01)
	var rng := RandomNumberGenerator.new()
	rng.seed = 53
	for k in 11:
		var x := -0.05 + 0.01 * float(k) + 0.005
		var ll := rng.randf_range(0.011, 0.02)
		s.tube_add(PackedVector3Array([Vector3(x, 0.155, -0.106) - h, Vector3(x + rng.randf_range(-0.002, 0.002), 0.155 + ll, -0.112) - h]), PackedFloat32Array([0.0042, 0.0008]), TOOTH, 0.3, 5)
	s.paint_ellipsoid(Vector3(0.0, 0.135, -0.1) - h, Vector3(0.06, 0.04, 0.03), BLOOD, 0.5)
	return s.noise_scale(60.0).mesh("gk_jaw", 0.006, 1500)


## A slouch hat of rotten felt, the brim drooping, a hole worn through it.
static func gk_hat() -> ArrayMesh:
	var s := Sculpt.new()
	s.ellipsoid(Vector3.ZERO, Vector3(0.27, 0.018, 0.26), FELT, 0.02, 0.95, 0.004)
	s.ellipsoid(Vector3(0.0, 0.065, 0.0), Vector3(0.13, 0.09, 0.13), FELT, 0.04, 0.95, 0.004)
	s.carve_ellipsoid(Vector3(0.0, 0.16, 0.0), Vector3(0.08, 0.03, 0.06), FELT, 0.02)  # the dent in the crown
	s.carve_ellipsoid(Vector3(0.2, 0.0, -0.1), Vector3(0.04, 0.05, 0.03), FELT, 0.01)
	s.paint_ellipsoid(Vector3(0.0, 0.03, 0.0), Vector3(0.14, 0.02, 0.14), Color(0.03, 0.025, 0.02), 0.9)  # the band
	return s.noise_scale(30.0).mesh("gk_hat", 0.008, 1200)


## Shoulder-local, hanging down -y: a coat sleeve to the wrist, then a grey hand whose fingers are
## far too long, black nails, mud to the knuckles. side: +1 right, -1 left.
static func gk_arm(side: float) -> ArrayMesh:
	var s := Sculpt.new()
	s.capsule(Vector3.ZERO, Vector3(0.0, -0.44, 0.02), 0.072, 0.062, COAT, 0.03, 0.78, 0.004)
	s.ellipsoid(Vector3(0.0, -0.44, 0.025), Vector3(0.062, 0.06, 0.062), COAT, 0.025, 0.78)
	s.capsule(Vector3(0.0, -0.44, 0.025), Vector3(0.0, -0.8, -0.02), 0.06, 0.055, COAT, 0.025, 0.78, 0.004)
	s.carve_ellipsoid(Vector3(side * 0.05, -0.79, -0.05), Vector3(0.04, 0.05, 0.04), COAT_WORN, 0.01)  # a torn cuff
	s.capsule(Vector3(0.0, -0.78, -0.02), Vector3(0.0, -0.88, -0.03), 0.028, 0.026, GREY, 0.02, 0.6)
	s.ellipsoid(Vector3(0.0, -0.93, -0.035), Vector3(0.036, 0.055, 0.017), GREY, 0.025, 0.6)
	for k in 4:
		var x := -0.024 + 0.016 * float(k)
		var l := 1.0 - absf(x) * 4.0
		var pts := PackedVector3Array([Vector3(x, -0.96, -0.035), Vector3(x * 1.1, -1.06 * l, -0.06), Vector3(x * 1.15, -1.15 * l - 0.01, -0.1), Vector3(x * 1.15, -1.2 * l - 0.01, -0.14)])
		s.tube_add(pts, PackedFloat32Array([0.009, 0.0075, 0.006, 0.003]), GREY, 0.5, 6)
		s.paint_ellipsoid(pts[3], Vector3.ONE * 0.013, NAIL, 0.3)
	s.tube_add(PackedVector3Array([Vector3(-side * 0.03, -0.91, -0.04), Vector3(-side * 0.046, -0.97, -0.06), Vector3(-side * 0.05, -1.02, -0.088)]), PackedFloat32Array([0.01, 0.0075, 0.004]), GREY, 0.5, 6)
	s.paint_ellipsoid(Vector3(0.0, -0.95, -0.03), Vector3(0.045, 0.05, 0.03), MUD, 0.9)
	s.paint_ellipsoid(Vector3(side * 0.03, -0.25, 0.04), Vector3(0.06, 0.08, 0.05), MUD, 0.9)
	return s.noise_scale(40.0).mesh("gk_arm_%d" % int(side), 0.008, 2400)


## Hip-local, down to the floor at -0.95: trousers into tall boots caked with grave mud.
static func gk_leg() -> ArrayMesh:
	var s := Sculpt.new()
	s.capsule(Vector3.ZERO, Vector3(0.0, -0.45, 0.01), 0.075, 0.055, COAT_WORN, 0.03, 0.9, 0.003)
	s.ellipsoid(Vector3(0.0, -0.45, -0.005), Vector3(0.055, 0.055, 0.05), COAT_WORN, 0.03, 0.9)
	s.capsule(Vector3(0.0, -0.45, 0.01), Vector3(0.0, -0.6, 0.015), 0.052, 0.05, COAT_WORN, 0.03, 0.9)
	s.capsule(Vector3(0.0, -0.6, 0.015), Vector3(0.0, -0.88, 0.02), 0.06, 0.052, BOOT, 0.03, 0.55, 0.003)
	s.box(Vector3(0.0, -0.915, -0.045), Vector3(0.05, 0.035, 0.12), 0.03, BOOT, 0.03, 0.55)
	s.paint_capsule(Vector3(0.0, -0.75, 0.015), Vector3(0.0, -0.95, -0.04), 0.07, 0.07, MUD, 0.95)
	return s.noise_scale(26.0).mesh("gk_leg", 0.011, 1400)


## Belt-hook-local: a tin lantern cage hanging from a ring (the glowing wick is separate).
static func gk_lantern() -> ArrayMesh:
	var s := Sculpt.new()
	s.tube_add(PackedVector3Array([Vector3(0.0, 0.0, 0.0), Vector3(0.0, -0.05, 0.0)]), PackedFloat32Array([0.006, 0.006]), BOOT, 0.5, 4)
	s.ellipsoid(Vector3(0.0, -0.06, 0.0), Vector3(0.045, 0.02, 0.045), BOOT, 0.01, 0.5)
	for k in 4:
		var a := TAU * float(k) / 4.0 + PI * 0.25
		var c := Vector3(cos(a) * 0.045, 0.0, sin(a) * 0.045)
		s.tube_add(PackedVector3Array([c + Vector3(0.0, -0.07, 0.0), c * 1.15 + Vector3(0.0, -0.13, 0.0), c + Vector3(0.0, -0.2, 0.0)]), PackedFloat32Array([0.004, 0.004, 0.004]), BOOT, 0.5, 4)
	s.ellipsoid(Vector3(0.0, -0.205, 0.0), Vector3(0.05, 0.015, 0.05), BOOT, 0.01, 0.5)
	return s.mesh("gk_lantern", 0.006, 800)
