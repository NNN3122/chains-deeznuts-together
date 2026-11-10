class_name StriderBody
extends Node3D
## What chases the cars out of Kettle Hollow (Level 4): the Strider, about nine metres of something
## that was long and thin before it was anything else. It runs on all fours, a gallop on arms longer
## than its legs. Wet near-black hide (a real wrinkled-bark photo laid over it, so it reads as skin
## that has grown too thick), the ribs broken out through the flanks as bare bone, raw wounds where
## the hide has split along the spine and the limbs, strips of skin hanging off the belly, quills down
## the back, a narrow head split top to bottom by a mouth lined with two rows of teeth, and a cluster
## of small cold eyes where a face should be. Modelled at a person's size and drawn SCALE times over.
## The rig Strider animates: hips and chest, the head, and per limb a shoulder (or hip) with an elbow
## (or knee) under it. Forward is -z.

const SCALE: float = 3.6
const SKIN: Color = Color(0.13, 0.125, 0.12)
const SKIN_DARK: Color = Color(0.035, 0.03, 0.032)
const SKIN_PALE: Color = Color(0.3, 0.28, 0.25)  # stretched thin over bone
const RAW: Color = Color(0.3, 0.035, 0.03)
const VEIN: Color = Color(0.11, 0.015, 0.035)
const BONE: Color = Color(0.64, 0.59, 0.47)
const GUM: Color = Color(0.22, 0.01, 0.02)
const TOOTH: Color = Color(0.6, 0.55, 0.42)
const NAIL: Color = Color(0.03, 0.025, 0.02)
const HIPS: Vector3 = Vector3(0.0, 1.12, 0.55)
const CHEST: Vector3 = Vector3(0.0, 1.5, -0.55)
const SHOULDER_X: float = 0.3
const HIP_X: float = 0.22
const UPPER_ARM: float = 0.95
const FOREARM: float = 1.0
const THIGH: float = 0.62
const SHIN: float = 0.72
const EYES: Array[Vector3] = [Vector3(-0.05, 0.1, -0.2), Vector3(0.05, 0.1, -0.2), Vector3(-0.08, 0.05, -0.17), Vector3(0.08, 0.06, -0.17), Vector3(0.0, 0.14, -0.19), Vector3(-0.03, 0.17, -0.17), Vector3(0.04, 0.02, -0.2), Vector3(0.09, 0.13, -0.15), Vector3(-0.1, 0.12, -0.14), Vector3(0.025, 0.2, -0.15), Vector3(-0.06, 0.0, -0.19)]

var chest: Node3D
var hips: Node3D
var head: Node3D
var arms: Array[Node3D] = []  # shoulders; each has its elbow as child 1
var legs: Array[Node3D] = []  # hips; each has its knee as child 1
var eye_light: OmniLight3D


func build() -> void:
	scale = Vector3.ONE * SCALE
	var hide_mat := Sculpt.material(0.45, 0.05, 1.0, 0.04, 1.0)
	hide_mat.set_shader_parameter("rim_col", Color(0.35, 0.05, 0.04))
	var folder := LevelKit.MANOR_TEXTURES + "bark/"
	hide_mat.set_shader_parameter("detail_albedo", load(folder + "color.jpg"))
	hide_mat.set_shader_parameter("detail_normal", load(folder + "normal.jpg"))
	hide_mat.set_shader_parameter("detail_span", 0.22)  # in its own scale: a hand's width of wrinkles a repeat
	hide_mat.set_shader_parameter("detail", 0.55)
	hide_mat.set_shader_parameter("detail_bump", 1.6)
	hips = Node3D.new()
	hips.position = HIPS
	add_child(hips)
	chest = Node3D.new()
	chest.position = CHEST
	add_child(chest)
	Sculpt.put(self, torso(), hide_mat)
	head = Node3D.new()
	head.position = CHEST + Vector3(0.0, 0.32, -0.62)
	add_child(head)
	Sculpt.put(head, skull(), hide_mat)
	# The eyes: small, cold, too many, and each one a slightly different size.
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.9, 0.95, 0.8)
	glow.emission_enabled = true
	glow.emission = Color(0.85, 0.95, 0.7)
	glow.emission_energy_multiplier = 2.2
	glow.disable_fog = true  # they show through the smoke before anything else does
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	for e in EYES:
		var eye_mesh := SphereMesh.new()
		var r := rng.randf_range(0.009, 0.019)
		eye_mesh.radius = r
		eye_mesh.height = r * 2.0
		eye_mesh.radial_segments = 8
		eye_mesh.rings = 4
		var mi := MeshInstance3D.new()
		mi.mesh = eye_mesh
		mi.material_override = glow
		mi.position = e
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		head.add_child(mi)
	eye_light = OmniLight3D.new()
	eye_light.light_color = Color(0.85, 0.12, 0.08)  # a red glow off the wet hide round the head
	eye_light.light_energy = 1.8
	eye_light.omni_range = 4.0  # in its own scale: about 14 m round the head
	eye_light.light_volumetric_fog_energy = 2.0
	eye_light.position = Vector3(0.0, 0.08, -0.35)
	head.add_child(eye_light)
	for side: float in [-1.0, 1.0]:
		var shoulder := Node3D.new()
		shoulder.position = CHEST + Vector3(side * SHOULDER_X, -0.05, -0.1)
		add_child(shoulder)
		Sculpt.put(shoulder, upper_arm(), hide_mat)
		var elbow := Node3D.new()
		elbow.position = Vector3(0.0, -UPPER_ARM, 0.0)
		shoulder.add_child(elbow)
		Sculpt.put(elbow, forearm(side), hide_mat)
		arms.append(shoulder)
		var hip := Node3D.new()
		hip.position = HIPS + Vector3(side * HIP_X, -0.02, 0.05)
		add_child(hip)
		Sculpt.put(hip, thigh(), hide_mat)
		var knee := Node3D.new()
		knee.position = Vector3(0.0, -THIGH, 0.0)
		hip.add_child(knee)
		Sculpt.put(knee, shin(), hide_mat)
		legs.append(hip)


## Body-local: a long starved trunk from the hips back to the chest, the spine a row of knuckles
## with quills, the ribs broken out of the flanks, the hide split raw along the back, veins wound
## over it, and strips of skin hanging under the belly.
static func torso() -> ArrayMesh:
	var s := Sculpt.new()
	s.capsule(HIPS + Vector3(0.0, 0.0, 0.05), CHEST, 0.19, 0.27, SKIN, 0.06, 0.35, 0.008)
	s.ellipsoid(CHEST + Vector3(0.0, -0.02, 0.0), Vector3(0.36, 0.3, 0.32), SKIN, 0.06, 0.35, 0.008)
	s.ellipsoid(HIPS, Vector3(0.24, 0.18, 0.22), SKIN, 0.05, 0.35, 0.006)
	s.capsule(CHEST + Vector3(0.0, 0.05, -0.2), CHEST + Vector3(0.0, 0.3, -0.6), 0.1, 0.075, SKIN, 0.05, 0.35, 0.005)  # the neck
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for k in 13:
		var t := float(k) / 12.0
		var p := HIPS.lerp(CHEST, t)
		var top := p + Vector3(0.0, 0.2 + 0.08 * sin(t * PI), 0.0)
		s.ellipsoid(top, Vector3(0.042, 0.036, 0.045), SKIN_PALE, 0.03, 0.4)  # a knuckle of spine
		var tall := rng.randf_range(0.16, 0.34)
		var lean := rng.randf_range(0.04, 0.14)
		s.tube_add(PackedVector3Array([top, top + Vector3(rng.randf_range(-0.02, 0.02), tall * 0.5, lean * 0.5), top + Vector3(rng.randf_range(-0.04, 0.04), tall, lean)]), PackedFloat32Array([0.028, 0.012, 0.0015]), BONE, 0.3, 6)
	# The hide split open along the back, raw under it.
	s.paint_capsule(HIPS + Vector3(0.0, 0.17, 0.0), CHEST + Vector3(0.0, 0.25, 0.0), 0.06, 0.08, RAW, 0.2)
	s.carve_capsule(HIPS.lerp(CHEST, 0.3) + Vector3(0.05, 0.19, 0.0), HIPS.lerp(CHEST, 0.65) + Vector3(0.05, 0.24, 0.0), 0.02, 0.025, RAW)
	for k in 7:
		var p := HIPS.lerp(CHEST, 0.38 + 0.09 * float(k))
		for side: float in [-1.0, 1.0]:
			if k >= 3:
				# Broken out: the rib leaves the hide halfway down and ends in a split point.
				s.tube_add(PackedVector3Array([p + Vector3(side * 0.05, 0.2, 0.0), p + Vector3(side * 0.27, 0.07, 0.0), p + Vector3(side * 0.32, -0.12, rng.randf_range(-0.03, 0.03)), p + Vector3(side * rng.randf_range(0.26, 0.36), -0.27, rng.randf_range(-0.05, 0.05))]), PackedFloat32Array([0.022, 0.024, 0.017, 0.003]), BONE, 0.3, 6)
				s.paint_ellipsoid(p + Vector3(side * 0.26, 0.0, 0.0), Vector3(0.06, 0.13, 0.05), RAW, 0.2)
			else:
				s.tube_add(PackedVector3Array([p + Vector3(side * 0.04, 0.2, 0.0), p + Vector3(side * 0.25, 0.05, 0.0), p + Vector3(side * 0.23, -0.16, 0.0), p + Vector3(side * 0.06, -0.26, 0.0)]), PackedFloat32Array([0.022, 0.024, 0.02, 0.012]), SKIN_PALE, 0.4, 6)
	# Veins wound over the flanks and down the neck.
	for v in 8:
		var a := HIPS.lerp(CHEST, rng.randf_range(0.0, 0.6))
		var side := -1.0 if v % 2 == 0 else 1.0
		var pts := PackedVector3Array()
		var radii := PackedFloat32Array()
		for q in 5:
			var t := float(q) / 4.0
			var p := a.lerp(CHEST + Vector3(0.0, 0.1, -0.3), t * 0.6)
			pts.append(p + Vector3(side * (0.2 + 0.05 * sin(t * 7.0 + float(v))), 0.05 * cos(t * 9.0 + float(v)), 0.0))
			radii.append(0.011 * (1.0 - t * 0.6))
		s.tube_add(pts, radii, VEIN, 0.25, 5)
	# Strips of hide hanging off the belly, and something wet dripping off them.
	for k in 9:
		var p := HIPS.lerp(CHEST, rng.randf_range(0.1, 0.9)) + Vector3(rng.randf_range(-0.14, 0.14), -0.2, 0.0)
		var len := rng.randf_range(0.12, 0.3)
		s.tube_add(PackedVector3Array([p, p + Vector3(rng.randf_range(-0.02, 0.02), -len * 0.5, 0.02), p + Vector3(rng.randf_range(-0.03, 0.03), -len, 0.05)]), PackedFloat32Array([0.022, 0.012, 0.003]), SKIN if k % 3 else RAW, 0.3, 5)
	s.paint_ellipsoid(CHEST + Vector3(0.0, -0.2, 0.0), Vector3(0.3, 0.15, 0.3), SKIN_DARK, 0.4)
	s.paint_ellipsoid(HIPS + Vector3(0.0, -0.1, 0.0), Vector3(0.2, 0.1, 0.2), SKIN_DARK, 0.4)
	return s.noise_scale(16.0).mesh("strider_torso", 0.02, 8500)


## Head-local: a narrow skull a metre long in its own scale, split top to bottom by a mouth with two
## rows of teeth, the skin peeled back off the brow to the bone, sockets sunk round the eyes.
static func skull() -> ArrayMesh:
	var s := Sculpt.new()
	s.ellipsoid(Vector3(0.0, 0.08, -0.06), Vector3(0.12, 0.15, 0.22), SKIN, 0.04, 0.35, 0.005)
	s.capsule(Vector3(0.0, 0.0, 0.05), Vector3(0.0, -0.05, -0.24), 0.08, 0.05, SKIN, 0.05, 0.35)
	s.carve_box(Vector3(0.0, -0.02, -0.22), Vector3(0.026, 0.19, 0.1), GUM, 0.012)  # the mouth, top to bottom
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	for row in 2:
		for k in 16:
			var y := -0.19 + float(k) * 0.024
			for side: float in [-1.0, 1.0]:
				var root := Vector3(side * (0.036 - 0.012 * float(row)), y, -0.25 + 0.03 * float(row))
				var reach := rng.randf_range(0.016, 0.034) * (1.0 - 0.3 * float(row))
				s.tube_add(PackedVector3Array([root, root + Vector3(-side * reach, rng.randf_range(-0.006, 0.006), -0.01)]), PackedFloat32Array([0.006, 0.0008]), TOOTH, 0.25, 5)
	s.paint_box(Vector3(0.0, -0.02, -0.25), Vector3(0.06, 0.21, 0.035), GUM, 0.3)
	# Sunken sockets round the eyes, and the skin peeled off the brow.
	for e in EYES:
		s.carve_ellipsoid(e + Vector3(0.0, 0.0, -0.005), Vector3(0.024, 0.022, 0.016), SKIN_DARK, 0.008)
	s.paint_ellipsoid(Vector3(0.0, 0.09, -0.2), Vector3(0.13, 0.1, 0.06), SKIN_DARK, 0.4)
	s.paint_ellipsoid(Vector3(0.0, 0.2, -0.05), Vector3(0.08, 0.05, 0.12), BONE, 0.3)
	s.paint_ellipsoid(Vector3(0.0, 0.19, -0.05), Vector3(0.1, 0.07, 0.15), RAW, 0.25)
	for side: float in [-1.0, 1.0]:  # horns of bone swept back off the skull
		s.tube_add(PackedVector3Array([Vector3(side * 0.06, 0.18, 0.08), Vector3(side * 0.11, 0.28, 0.2), Vector3(side * 0.13, 0.32, 0.36), Vector3(side * 0.12, 0.3, 0.46)]), PackedFloat32Array([0.026, 0.016, 0.006, 0.001]), BONE, 0.3, 6)
		s.tube_add(PackedVector3Array([Vector3(side * 0.09, 0.0, -0.08), Vector3(side * 0.14, -0.04, 0.0), Vector3(side * 0.16, -0.1, 0.08)]), PackedFloat32Array([0.012, 0.006, 0.001]), BONE, 0.3, 5)  # spurs off the cheek
	return s.noise_scale(30.0).mesh("strider_skull", 0.008, 7000)


## Shoulder-local, hanging down -y: the long upper arm, split raw on the outside.
static func upper_arm() -> ArrayMesh:
	var s := Sculpt.new()
	s.ellipsoid(Vector3.ZERO, Vector3(0.12, 0.12, 0.12), SKIN, 0.04, 0.35)
	s.capsule(Vector3.ZERO, Vector3(0.0, -UPPER_ARM, 0.0), 0.085, 0.055, SKIN, 0.04, 0.35, 0.006)
	s.ellipsoid(Vector3(0.0, -0.35, -0.03), Vector3(0.08, 0.2, 0.08), SKIN, 0.05, 0.35)
	s.paint_capsule(Vector3(0.07, -0.15, 0.0), Vector3(0.05, -0.6, 0.0), 0.03, 0.02, RAW, 0.2)
	s.tube_add(PackedVector3Array([Vector3(0.0, 0.05, 0.06), Vector3(0.0, 0.15, 0.14), Vector3(0.0, 0.18, 0.24)]), PackedFloat32Array([0.025, 0.01, 0.001]), BONE, 0.3, 6)  # a spur off the shoulder
	return s.noise_scale(20.0).mesh("strider_upper_arm", 0.015, 2000)


## Elbow-local: the forearm, the elbow broken back into a spike, and a hand of long fingers ending in
## hooked black claws, splayed where it lands.
static func forearm(side: float) -> ArrayMesh:
	var s := Sculpt.new()
	s.capsule(Vector3.ZERO, Vector3(0.0, -FOREARM, 0.0), 0.06, 0.04, SKIN, 0.04, 0.35, 0.006)
	s.tube_add(PackedVector3Array([Vector3(0.0, 0.0, 0.03), Vector3(0.0, 0.06, 0.12), Vector3(0.0, 0.1, 0.22)]), PackedFloat32Array([0.03, 0.012, 0.001]), BONE, 0.3, 6)
	for k in 3:
		var y := -0.25 - 0.22 * float(k)
		s.tube_add(PackedVector3Array([Vector3(0.0, y, 0.035), Vector3(0.0, y + 0.03, 0.08)]), PackedFloat32Array([0.012, 0.001]), BONE, 0.3, 5)
	s.ellipsoid(Vector3(0.0, -FOREARM - 0.03, -0.04), Vector3(0.07, 0.03, 0.08), SKIN, 0.03, 0.35)
	for k in 5:
		var a := (float(k) - 2.0) * 0.32
		var base := Vector3(0.0, -FOREARM - 0.04, -0.06)
		var dir := Vector3(sin(a) * side * -1.0, 0.0, -cos(a))
		s.tube_add(PackedVector3Array([base, base + dir * 0.14 + Vector3(0.0, -0.02, 0.0), base + dir * 0.26 + Vector3(0.0, -0.06, 0.0)]), PackedFloat32Array([0.016, 0.011, 0.005]), SKIN, 0.35, 6)
		var tip := base + dir * 0.26 + Vector3(0.0, -0.06, 0.0)
		s.tube_add(PackedVector3Array([tip, tip + dir * 0.05 + Vector3(0.0, -0.02, 0.0), tip + dir * 0.08 + Vector3(0.0, -0.06, 0.0)]), PackedFloat32Array([0.006, 0.004, 0.0005]), NAIL, 0.15, 5)
	return s.noise_scale(20.0).mesh("strider_forearm_%s" % ("l" if side < 0.0 else "r"), 0.013, 2600)


## Hip-local: the thigh, bent back, a vein wound round it.
static func thigh() -> ArrayMesh:
	var s := Sculpt.new()
	s.capsule(Vector3.ZERO, Vector3(0.0, -THIGH, 0.0), 0.1, 0.06, SKIN, 0.04, 0.35, 0.006)
	var pts := PackedVector3Array()
	var radii := PackedFloat32Array()
	for q in 7:
		var t := float(q) / 6.0
		var a := t * TAU * 1.2
		pts.append(Vector3(cos(a) * 0.09, -t * THIGH, sin(a) * 0.09))
		radii.append(0.01)
	s.tube_add(pts, radii, VEIN, 0.25, 5)
	return s.noise_scale(20.0).mesh("strider_thigh", 0.015, 1500)


## Knee-local: the shin, the bone showing through raw down its front, and a long splayed foot.
static func shin() -> ArrayMesh:
	var s := Sculpt.new()
	s.capsule(Vector3.ZERO, Vector3(0.0, -SHIN, 0.0), 0.06, 0.04, SKIN, 0.04, 0.35, 0.006)
	s.paint_capsule(Vector3(0.0, -0.1, -0.05), Vector3(0.0, -0.5, -0.04), 0.03, 0.025, RAW, 0.2)
	s.capsule(Vector3(0.0, -0.12, -0.055), Vector3(0.0, -0.45, -0.045), 0.014, 0.012, BONE, 0.01, 0.3)
	s.capsule(Vector3(0.0, -SHIN, 0.0), Vector3(0.0, -SHIN - 0.03, -0.24), 0.045, 0.02, SKIN, 0.04, 0.35)
	s.tube_add(PackedVector3Array([Vector3(0.0, -SHIN - 0.03, -0.24), Vector3(0.0, -SHIN - 0.05, -0.3), Vector3(0.0, -SHIN - 0.09, -0.32)]), PackedFloat32Array([0.012, 0.007, 0.0005]), NAIL, 0.15, 5)
	return s.noise_scale(20.0).mesh("strider_shin", 0.015, 1500)
