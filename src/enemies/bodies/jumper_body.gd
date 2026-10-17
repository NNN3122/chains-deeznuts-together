class_name JumperBody
extends Node3D
## The Jumper: a spider the size of a sofa. Wet black chitin on the front half, a swollen bristling
## abdomen behind with a pale mark on its back like a face pressed against a window, eight eyes
## in a cluster that brighten before it jumps, chelicerae as thick as forearms ending in hooked
## black fangs, long jointed legs with banded joints and spines.
## The rig Launcher animates: body (at height h), head (on the body), and per leg a root pivot
## (upper leg along +side x) and a knee pivot (lower leg along +side x), left legs even.

const CHITIN: Color = Color(0.07, 0.055, 0.05)
const HAIR: Color = Color(0.14, 0.1, 0.075)
const BAND: Color = Color(0.32, 0.12, 0.08)
const MARK: Color = Color(0.62, 0.57, 0.47)
const FANG: Color = Color(0.02, 0.015, 0.012)
const MOUTH: Color = Color(0.3, 0.05, 0.05)

var body: Node3D
var head: Node3D
var legs: Array[Node3D] = []
var knees: Array[Node3D] = []
var eyes: Array[MeshInstance3D] = []


func build(body_h: float = 1.0) -> void:
	var shell := Sculpt.material(0.45, 0.3, 0.0, 0.0, 0.35)
	body = Node3D.new()
	body.position = Vector3(0.0, body_h, 0.0)
	add_child(body)
	Sculpt.put(body, torso(), shell)
	head = Node3D.new()
	head.position = Vector3(0.0, 0.1, -0.85)
	body.add_child(head)
	Sculpt.put(head, face(), shell)
	var eye_spots: Array = [[Vector3(-0.07, 0.07, -0.205), 0.052], [Vector3(0.07, 0.07, -0.205), 0.052],
		[Vector3(-0.16, 0.1, -0.17), 0.036], [Vector3(0.16, 0.1, -0.17), 0.036],
		[Vector3(-0.05, 0.17, -0.18), 0.026], [Vector3(0.05, 0.17, -0.18), 0.026],
		[Vector3(-0.2, 0.17, -0.1), 0.024], [Vector3(0.2, 0.17, -0.1), 0.024]]
	for spot in eye_spots:
		var e := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radial_segments = 12  # a glowing eye: a few hundred triangles, not four thousand
		sm.rings = 6
		sm.radius = spot[1]
		sm.height = float(spot[1]) * 2.0
		e.mesh = sm
		e.position = spot[0]
		e.material_override = LevelKit.mat("infected_eye")
		head.add_child(e)
		eyes.append(e)
	for row in 4:
		for s: float in [-1.0, 1.0]:
			var z := -0.55 + float(row) * 0.4
			var root := Node3D.new()
			root.position = Vector3(s * 0.5, -0.1, z)
			body.add_child(root)
			var upper := 1.0 + 0.2 * float(row == 0 or row == 3)
			Sculpt.put(root, upper_leg(s, upper), shell)
			var knee := Node3D.new()
			knee.position = Vector3(s * upper, 0.0, 0.0)
			root.add_child(knee)
			Sculpt.put(knee, lower_leg(s), shell)
			root.rotation.z = s * 0.55
			knee.rotation.z = -s * 1.45
			root.rotation.y = -s * (0.5 - float(row) * 0.33)
			legs.append(root)
			knees.append(knee)


## Body-local: the cephalothorax forward, the waist, the abdomen behind (its mark on top), the
## spinnerets under the back.
static func torso() -> ArrayMesh:
	var s := Sculpt.new()
	s.ellipsoid(Vector3(0.0, 0.0, -0.3), Vector3(0.5, 0.3, 0.56), CHITIN, 0.06, 0.3, 0.012)
	s.capsule(Vector3(0.0, 0.05, 0.15), Vector3(0.0, 0.1, 0.35), 0.16, 0.2, CHITIN, 0.08, 0.3)
	s.ellipsoid(Vector3(0.0, 0.18, 0.95), Vector3(0.8, 0.64, 0.95), HAIR, 0.1, 0.9, 0.022)
	s.paint_ellipsoid(Vector3(0.0, 0.62, 0.8), Vector3(0.3, 0.3, 0.35), MARK, 0.7)
	for x: float in [-1.0, 1.0]:
		s.paint_ellipsoid(Vector3(x * 0.12, 0.72, 0.65), Vector3(0.08, 0.1, 0.08), CHITIN, 0.4)  # the mark's "eyes"
	s.paint_capsule(Vector3(-0.1, 0.7, 1.02), Vector3(0.1, 0.7, 1.02), 0.04, 0.04, CHITIN, 0.4)
	for x: float in [-0.1, 0.0, 0.1]:
		s.capsule(Vector3(x, -0.15, 1.7), Vector3(x * 1.4, -0.3, 1.82), 0.06, 0.03, BAND, 0.04, 0.5)
	for k in 7:
		var a := float(k) * 0.9
		s.capsule(Vector3(cos(a) * 0.3, 0.25, -0.3 + sin(a) * 0.3), Vector3(cos(a) * 0.32, 0.3, -0.3 + sin(a) * 0.32), 0.025, 0.012, HAIR, 0.02, 0.9)
	return s.noise_scale(16.0).mesh("jumper_torso", 0.03, 4000)


## Head-local: the head, the chelicerae and the hooked fangs, two little feeler legs.
static func face() -> ArrayMesh:
	var s := Sculpt.new()
	s.ellipsoid(Vector3.ZERO, Vector3(0.3, 0.24, 0.24), CHITIN, 0.04, 0.3, 0.006)
	for x: float in [-1.0, 1.0]:
		s.capsule(Vector3(x * 0.1, -0.08, -0.14), Vector3(x * 0.09, -0.38, -0.22), 0.075, 0.05, HAIR, 0.04, 0.85, 0.008)
		s.tube_add(PackedVector3Array([Vector3(x * 0.09, -0.4, -0.22), Vector3(x * 0.07, -0.5, -0.22), Vector3(x * 0.02, -0.55, -0.17)]), PackedFloat32Array([0.028, 0.016, 0.002]), FANG, 0.1, 7)
		s.tube_add(PackedVector3Array([Vector3(x * 0.2, -0.1, -0.12), Vector3(x * 0.3, -0.18, -0.3), Vector3(x * 0.26, -0.36, -0.4)]), PackedFloat32Array([0.035, 0.025, 0.012]), HAIR, 0.8, 7)
	s.carve_ellipsoid(Vector3(0.0, -0.17, -0.2), Vector3(0.06, 0.05, 0.04), MOUTH, 0.02)
	return s.noise_scale(30.0).mesh("jumper_face", 0.014, 3000)


## Root-local, along +side x for `length`: a thick upper leg, a banded joint, spines.
static func upper_leg(side: float, length: float) -> ArrayMesh:
	var s := Sculpt.new()
	s.capsule(Vector3.ZERO, Vector3(side * length * 0.5, 0.06, 0.0), 0.09, 0.075, CHITIN, 0.04, 0.3, 0.006)
	s.capsule(Vector3(side * length * 0.5, 0.06, 0.0), Vector3(side * length, 0.0, 0.0), 0.075, 0.07, CHITIN, 0.04, 0.3, 0.006)
	s.ellipsoid(Vector3(side * length, 0.0, 0.0), Vector3(0.085, 0.085, 0.085), BAND, 0.03, 0.4)
	for k in 5:
		var x := side * length * (0.15 + 0.17 * float(k))
		s.tube_add(PackedVector3Array([Vector3(x, 0.08, 0.0), Vector3(x + side * 0.05, 0.2, 0.02 * float(k % 2) - 0.01)]), PackedFloat32Array([0.012, 0.001]), HAIR, 0.8, 4)
	return s.noise_scale(20.0).mesh("jumper_upper_%d_%d" % [int(side), int(length * 10.0)], 0.022, 900)


## Knee-local, along +side x: the long lower leg tapering to a hooked claw.
static func lower_leg(side: float) -> ArrayMesh:
	var s := Sculpt.new()
	s.capsule(Vector3.ZERO, Vector3(side * 0.55, 0.0, 0.0), 0.065, 0.045, CHITIN, 0.03, 0.3, 0.005)
	s.ellipsoid(Vector3(side * 0.55, 0.0, 0.0), Vector3(0.055, 0.055, 0.055), BAND, 0.02, 0.4)
	s.capsule(Vector3(side * 0.55, 0.0, 0.0), Vector3(side * 1.02, 0.0, 0.0), 0.045, 0.022, CHITIN, 0.02, 0.3)
	s.tube_add(PackedVector3Array([Vector3(side * 1.0, 0.0, 0.0), Vector3(side * 1.1, -0.02, 0.0), Vector3(side * 1.15, -0.08, 0.0)]), PackedFloat32Array([0.022, 0.012, 0.002]), FANG, 0.15, 6)
	for k in 4:
		var x := side * (0.12 + 0.2 * float(k))
		s.tube_add(PackedVector3Array([Vector3(x, 0.05, 0.0), Vector3(x + side * 0.04, 0.14, 0.0)]), PackedFloat32Array([0.009, 0.001]), HAIR, 0.8, 4)
	return s.noise_scale(24.0).mesh("jumper_lower_%d" % int(side), 0.018, 900)
