class_name JumperBody
extends Node3D
## The Jumper: something that was a person once, the size of a sofa, crawling face down on eight
## long human arms. Grey, veined skin stretched over a ribcage and a spine that stands out like
## knuckles; shoulder blades like folded wings; behind, a swollen pale sac with a wet slit in it.
## The head hangs forward on a long neck: a human face with its jaw unhinged and hanging, two rows
## of teeth, no nose, and too many small wet eyes in the sockets and down the cheeks, dim red until
## it means to jump. Every arm ends in a hand with long black-nailed fingers that grip the roof.
## The rig Launcher animates: body (at height h), head (on the body), and per leg a root pivot
## (upper arm along +side x) and a knee pivot (forearm and hand along +side x), left legs even.

const SKIN: Color = Color(0.36, 0.34, 0.31)  # grey, dirty, a little green
const SKIN_DARK: Color = Color(0.18, 0.17, 0.16)
const BRUISE: Color = Color(0.32, 0.2, 0.24)
const BONE: Color = Color(0.66, 0.62, 0.54)
const GUM: Color = Color(0.36, 0.08, 0.09)
const TEETH: Color = Color(0.72, 0.66, 0.5)
const NAIL: Color = Color(0.04, 0.035, 0.03)
const HOLE: Color = Color(0.03, 0.01, 0.012)
const HAIR: Color = Color(0.05, 0.045, 0.04)

var body: Node3D
var head: Node3D
var legs: Array[Node3D] = []
var knees: Array[Node3D] = []
var eyes: Array[MeshInstance3D] = []
var eye_material: StandardMaterial3D


func build(body_h: float = 1.0) -> void:
	var skin := Sculpt.material(0.18, 0.08, 0.85, 0.3, 0.55)  # dry, blotched, veined: not a glossy toy
	body = Node3D.new()
	body.position = Vector3(0.0, body_h, 0.0)
	add_child(body)
	Sculpt.put(body, torso(), skin)
	head = Node3D.new()
	head.position = Vector3(0.0, -0.05, -1.0)
	body.add_child(head)
	Sculpt.put(head, face(), skin)
	# Its own eyes (Launcher dims and flares them): small, wet, too many, a deep red.
	eye_material = StandardMaterial3D.new()
	eye_material.albedo_color = Color(0.25, 0.0, 0.0)
	eye_material.roughness = 0.05
	eye_material.metallic_specular = 1.0
	eye_material.emission_enabled = true
	eye_material.emission = Color(1.0, 0.08, 0.04)
	eye_material.emission_energy_multiplier = 0.6
	# One deep in each socket, and more where no eye belongs, scattered unevenly: a cheek, the brow,
	# a temple, down by the jaw.
	var eye_spots: Array = [[Vector3(-0.07, 0.035, -0.185), 0.024], [Vector3(0.072, 0.03, -0.185), 0.024],
		[Vector3(-0.115, -0.045, -0.15), 0.011], [Vector3(0.03, 0.125, -0.17), 0.012], [Vector3(0.135, 0.07, -0.12), 0.009],
		[Vector3(-0.085, -0.13, -0.15), 0.008], [Vector3(0.1, -0.1, -0.15), 0.01], [Vector3(-0.03, 0.15, -0.15), 0.007]]
	for spot in eye_spots:
		var e := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radial_segments = 10  # a glowing eye: a hundred triangles, not four thousand
		sm.rings = 5
		sm.radius = spot[1]
		sm.height = float(spot[1]) * 2.0
		e.mesh = sm
		e.position = spot[0]
		e.material_override = eye_material
		head.add_child(e)
		eyes.append(e)
	for row in 4:
		for s: float in [-1.0, 1.0]:
			var z := -0.55 + float(row) * 0.4
			var root := Node3D.new()
			root.position = Vector3(s * 0.4, -0.05, z)
			body.add_child(root)
			var upper := 1.0 + 0.2 * float(row == 0 or row == 3)
			Sculpt.put(root, upper_leg(s, upper), skin)
			var knee := Node3D.new()
			knee.position = Vector3(s * upper, 0.0, 0.0)
			root.add_child(knee)
			Sculpt.put(knee, lower_leg(s), skin)
			root.rotation.z = s * 0.55
			knee.rotation.z = -s * 1.45
			root.rotation.y = -s * (0.5 - float(row) * 0.33)
			legs.append(root)
			knees.append(knee)


## Body-local, face down, head toward -z: the ribcage under stretched skin, the spine standing out
## along the top, the shoulder blades, a long neck forward, the swollen sac behind with its slit.
static func torso() -> ArrayMesh:
	var s := Sculpt.new()
	s.ellipsoid(Vector3(0.0, 0.0, -0.25), Vector3(0.4, 0.26, 0.68), SKIN, 0.08, 0.55, 0.01)
	# Ribs: grooves carved round the sides, so each one shows.
	for k in 7:
		var z := -0.75 + float(k) * 0.17
		for x: float in [-1.0, 1.0]:
			s.carve_capsule(Vector3(x * 0.2, 0.2, z + 0.06), Vector3(x * 0.42, -0.05, z + 0.09), 0.028, 0.02, SKIN_DARK, 0.02)
	# The spine: a row of knuckles down the back, standing out.
	for k in 11:
		var z := -0.95 + float(k) * 0.16
		s.ellipsoid(Vector3(0.0, 0.25 - 0.02 * absf(float(k) - 5.0) * 0.1, z), Vector3(0.05, 0.045, 0.05), BONE, 0.03, 0.6, 0.004)
	for x: float in [-1.0, 1.0]:
		s.ellipsoid(Vector3(x * 0.2, 0.2, -0.6), Vector3(0.16, 0.05, 0.22), SKIN, 0.05, 0.6, 0.006, Basis.from_euler(Vector3(0.0, x * 0.4, x * 0.3)))  # shoulder blades
	s.capsule(Vector3(0.0, 0.0, -0.8), Vector3(0.0, -0.05, -1.05), 0.12, 0.08, SKIN, 0.06, 0.55)  # the neck
	# The sac behind: swollen, pale, veined, a wet slit down its end.
	s.ellipsoid(Vector3(0.0, 0.08, 0.75), Vector3(0.55, 0.48, 0.7), SKIN.lightened(0.12), 0.14, 0.4, 0.03)
	s.carve_capsule(Vector3(0.0, 0.32, 1.38), Vector3(0.0, -0.18, 1.4), 0.05, 0.03, GUM, 0.03)
	s.paint_ellipsoid(Vector3(0.0, 0.1, 1.35), Vector3(0.12, 0.3, 0.08), GUM, 0.2)
	for k in 6:
		var a := float(k) * 1.05
		s.paint_ellipsoid(Vector3(cos(a) * 0.4, 0.15 + sin(a) * 0.3, 0.75), Vector3(0.12, 0.08, 0.2), BRUISE, 0.7)
	for k in 4:
		s.paint_ellipsoid(Vector3(0.18 * float(k % 2 * 2 - 1), 0.0, -0.4 + 0.2 * float(k)), Vector3(0.09, 0.15, 0.1), BRUISE, 0.75)
	return s.noise_scale(18.0).mesh("jumper2_torso", 0.028, 4500)


## Head-local, face toward -z: a human skull shape under thin skin, no nose (two holes), deep
## sockets, the jaw unhinged and hanging open with two rows of teeth, a few strands of hair.
static func face() -> ArrayMesh:
	var s := Sculpt.new()
	s.ellipsoid(Vector3(0.0, 0.05, 0.0), Vector3(0.15, 0.17, 0.18), SKIN, 0.04, 0.5, 0.004)
	s.ellipsoid(Vector3(0.0, -0.06, -0.08), Vector3(0.12, 0.11, 0.12), SKIN, 0.05, 0.5, 0.004)
	# The jaw: dropped far too low, hanging open.
	s.capsule(Vector3(-0.09, -0.08, -0.06), Vector3(-0.07, -0.36, -0.14), 0.035, 0.03, SKIN, 0.04, 0.55)
	s.capsule(Vector3(0.09, -0.08, -0.06), Vector3(0.07, -0.36, -0.14), 0.035, 0.03, SKIN, 0.04, 0.55)
	s.ellipsoid(Vector3(0.0, -0.38, -0.15), Vector3(0.085, 0.035, 0.06), SKIN, 0.04, 0.55)
	s.carve_ellipsoid(Vector3(0.0, -0.2, -0.16), Vector3(0.075, 0.16, 0.08), GUM, 0.03)  # the mouth hole between
	for k in 9:
		var x := -0.06 + 0.015 * float(k)
		s.tube_add(PackedVector3Array([Vector3(x, -0.07, -0.17), Vector3(x, -0.115, -0.175)]), PackedFloat32Array([0.008, 0.002]), TEETH, 0.3, 4)
		s.tube_add(PackedVector3Array([Vector3(x * 0.9, -0.355, -0.18), Vector3(x * 0.9, -0.31, -0.185)]), PackedFloat32Array([0.008, 0.002]), TEETH, 0.3, 4)
	for x: float in [-1.0, 1.0]:
		s.carve_ellipsoid(Vector3(x * 0.07, 0.04, -0.17), Vector3(0.05, 0.045, 0.05), HOLE, 0.02)  # sockets
		s.carve_ellipsoid(Vector3(x * 0.016, -0.02, -0.19), Vector3(0.011, 0.016, 0.02), HOLE, 0.005)  # no nose
		for k in 3:
			var hx := x * (0.05 + 0.04 * float(k))
			s.tube_add(PackedVector3Array([Vector3(hx, 0.2, 0.02), Vector3(hx * 1.2, 0.12, -0.12), Vector3(hx * 1.1, -0.1, -0.16)]), PackedFloat32Array([0.006, 0.004, 0.001]), HAIR, 0.9, 4)
	s.paint_ellipsoid(Vector3(0.0, -0.05, -0.15), Vector3(0.14, 0.08, 0.06), BRUISE, 0.6)
	return s.noise_scale(36.0).mesh("jumper2_face", 0.011, 3500)


## Root-local, along +side x for `length`: a long thin human upper arm, the elbow a knob of bone.
static func upper_leg(side: float, length: float) -> ArrayMesh:
	var s := Sculpt.new()
	s.capsule(Vector3.ZERO, Vector3(side * length * 0.45, 0.04, 0.0), 0.085, 0.06, SKIN, 0.05, 0.55, 0.005)
	s.capsule(Vector3(side * length * 0.45, 0.04, 0.0), Vector3(side * length, 0.0, 0.0), 0.06, 0.05, SKIN, 0.04, 0.55, 0.005)
	s.ellipsoid(Vector3(side * length, 0.02, 0.0), Vector3(0.065, 0.06, 0.06), BONE, 0.03, 0.6)
	s.paint_capsule(Vector3(side * length * 0.2, 0.05, 0.03), Vector3(side * length * 0.8, 0.04, 0.03), 0.03, 0.03, BRUISE, 0.7)
	return s.noise_scale(22.0).mesh("jumper2_upper_%d_%d" % [int(side), int(length * 10.0)], 0.02, 900)


## Knee-local, along +side x: the forearm, the wrist, and a hand with four long fingers bent down to
## grip the roof, black nails.
static func lower_leg(side: float) -> ArrayMesh:
	var s := Sculpt.new()
	s.capsule(Vector3.ZERO, Vector3(side * 0.8, -0.02, 0.0), 0.055, 0.04, SKIN, 0.04, 0.55, 0.004)
	s.ellipsoid(Vector3(side * 0.86, -0.02, 0.0), Vector3(0.09, 0.03, 0.065), SKIN, 0.03, 0.55, 0.003)  # the back of the hand
	for f in 4:
		var z := -0.045 + 0.03 * float(f)
		var base := Vector3(side * 0.92, -0.02, z)
		var mid := Vector3(side * 1.03, -0.03, z * 1.3)
		var tip := Vector3(side * 1.1, -0.12, z * 1.4)
		s.tube_add(PackedVector3Array([base, mid, tip]), PackedFloat32Array([0.016, 0.012, 0.008]), SKIN, 0.55, 6)
		s.tube_add(PackedVector3Array([tip, tip + Vector3(side * 0.02, -0.04, 0.0)]), PackedFloat32Array([0.008, 0.001]), NAIL, 0.2, 5)
	s.tube_add(PackedVector3Array([Vector3(side * 0.86, -0.02, 0.06), Vector3(side * 0.92, -0.06, 0.1), Vector3(side * 0.96, -0.12, 0.1)]), PackedFloat32Array([0.016, 0.011, 0.006]), SKIN, 0.55, 6)  # thumb
	return s.noise_scale(26.0).mesh("jumper2_lower_%d" % int(side), 0.016, 1200)
