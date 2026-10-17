class_name PappyBody
extends Node3D
## Pappy Pepperoni as the night shift finds him: a two-and-a-half metre animatronic chef whose latex
## has gone the colour of old dough. The jacket is stained down the front with something that is
## not sauce; one cheek has split open on the metal jaw underneath; the grin is too wide and holds
## too many teeth; the sockets are deep and dark with a red pinpoint glowing at the back of each.
## Gloved hands the size of hams with steel claws through the fingertips. The mustache stayed.
## The rig PappyPepperoni animates: the head (on a neck at y 2.05), one pivot per arm at the
## shoulders. eyes: the two glowing points (PappyPepperoni pulses their emission).

const COAT: Color = Color(0.8, 0.77, 0.68)
const COAT_GRIME: Color = Color(0.52, 0.47, 0.36)
const STAIN: Color = Color(0.28, 0.04, 0.03)
const TROUSER: Color = Color(0.12, 0.11, 0.1)
const BOOT: Color = Color(0.04, 0.035, 0.03)
const LATEX: Color = Color(0.72, 0.56, 0.45)
const LATEX_DARK: Color = Color(0.45, 0.3, 0.25)
const NOSE: Color = Color(0.66, 0.3, 0.25)
const METAL: Color = Color(0.36, 0.36, 0.38)
const DARK: Color = Color(0.015, 0.01, 0.01)
const GUM: Color = Color(0.2, 0.03, 0.03)
const TOOTH: Color = Color(0.82, 0.76, 0.6)
const MUSTACHE: Color = Color(0.06, 0.045, 0.04)
const KERCHIEF: Color = Color(0.55, 0.06, 0.06)
const WIRE_RED: Color = Color(0.5, 0.05, 0.04)

var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var eyes: Array[MeshInstance3D] = []


func build() -> void:
	var mat := Sculpt.material(0.15, 0.2, 0.0, 0.0, 0.5)
	Sculpt.put(self, body(), mat)
	arm_l = Node3D.new()
	arm_l.position = Vector3(-0.7, 1.72, 0.0)
	add_child(arm_l)
	Sculpt.put(arm_l, arm(-1.0), mat)
	arm_r = Node3D.new()
	arm_r.position = Vector3(0.7, 1.72, 0.0)
	add_child(arm_r)
	Sculpt.put(arm_r, arm(1.0), mat)
	arm_l.rotation.z = -0.18
	arm_r.rotation.z = 0.18
	head = Node3D.new()
	head.position = Vector3(0.0, 2.05, 0.0)
	add_child(head)
	Sculpt.put(head, face(), Sculpt.material(0.25, 0.15, 0.0, 0.1, 0.55))
	# The eyes: a small red light deep in each socket.
	for x: float in [-0.14, 0.14]:
		var e := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radial_segments = 12  # a glowing eye: a few hundred triangles, not four thousand
		sm.rings = 6
		sm.radius = 0.022
		sm.height = 0.044
		e.mesh = sm
		e.position = Vector3(x, 0.4, -0.29)
		e.material_override = LevelKit.mat("pepperoni")
		head.add_child(e)
		eyes.append(e)


## Model-local, standing on y 0: boots, trousers, the barrel of a chef's jacket with its buttons,
## the stains, a tear down one side to the frame inside, the kerchief, the shoulders.
static func body() -> ArrayMesh:
	var s := Sculpt.new()
	for x: float in [-0.3, 0.3]:
		s.box(Vector3(x, 0.11, -0.05), Vector3(0.17, 0.1, 0.27), 0.08, BOOT, 0.04, 0.35)
		s.capsule(Vector3(x, 0.2, 0.0), Vector3(x * 0.95, 0.78, 0.0), 0.17, 0.2, TROUSER, 0.06, 0.85, 0.006)
	s.ellipsoid(Vector3(0.0, 1.25, 0.0), Vector3(0.62, 0.6, 0.5), COAT, 0.1, 0.7, 0.012)
	s.ellipsoid(Vector3(0.0, 1.0, -0.1), Vector3(0.56, 0.42, 0.46), COAT, 0.12, 0.7, 0.01)
	s.capsule(Vector3(-0.62, 1.72, 0.0), Vector3(0.62, 1.72, 0.0), 0.2, 0.2, COAT, 0.15, 0.7, 0.008)
	s.capsule(Vector3(0.0, 1.8, 0.0), Vector3(0.0, 2.1, 0.0), 0.16, 0.13, METAL, 0.04, 0.35)  # the neck post
	s.ellipsoid(Vector3(0.0, 1.88, -0.03), Vector3(0.32, 0.1, 0.3), KERCHIEF, 0.05, 0.7, 0.006)
	s.ellipsoid(Vector3(0.0, 1.8, -0.31), Vector3(0.09, 0.12, 0.06), KERCHIEF, 0.04, 0.7)  # the knot
	for x: float in [-0.15, 0.15]:
		for y: float in [1.05, 1.3, 1.55]:
			s.ellipsoid(Vector3(x, y, -0.53 + absf(y - 1.25) * 0.12), Vector3(0.04, 0.04, 0.025), DARK, 0.01, 0.3)
	# Grime, and the stains down the front.
	s.paint_box(Vector3(0.0, 0.72, 0.0), Vector3(0.7, 0.12, 0.6), COAT_GRIME, 0.8)
	s.paint_ellipsoid(Vector3(-0.15, 1.15, -0.5), Vector3(0.22, 0.32, 0.1), STAIN, 0.25)
	s.paint_ellipsoid(Vector3(0.18, 0.9, -0.45), Vector3(0.14, 0.22, 0.12), STAIN, 0.25)
	s.paint_ellipsoid(Vector3(0.05, 1.45, -0.52), Vector3(0.08, 0.1, 0.05), STAIN, 0.25)
	# The jacket split at the side, the frame and the wiring behind it.
	s.carve_ellipsoid(Vector3(0.6, 1.2, -0.05), Vector3(0.12, 0.25, 0.14), METAL, 0.03)
	s.capsule(Vector3(0.52, 1.0, -0.05), Vector3(0.52, 1.42, -0.05), 0.035, 0.035, METAL, 0.0, 0.3)
	s.tube_add(PackedVector3Array([Vector3(0.55, 1.35, -0.1), Vector3(0.66, 1.2, -0.12), Vector3(0.68, 1.02, -0.06), Vector3(0.66, 0.9, -0.02)]), PackedFloat32Array([0.012, 0.012, 0.012, 0.01]), WIRE_RED, 0.4, 6)
	s.tube_add(PackedVector3Array([Vector3(0.55, 1.3, 0.0), Vector3(0.65, 1.15, 0.04), Vector3(0.64, 0.98, 0.02)]), PackedFloat32Array([0.01, 0.01, 0.008]), DARK, 0.4, 6)
	return s.noise_scale(9.0).mesh("pappy_body", 0.03, 4000)


## Shoulder-local, hanging down -y: a sleeve, a stained glove the size of a ham, four fat fingers
## with steel claws through the tips. side: +1 right.
static func arm(side: float) -> ArrayMesh:
	var s := Sculpt.new()
	s.capsule(Vector3.ZERO, Vector3(0.0, -0.45, 0.02), 0.15, 0.12, COAT, 0.05, 0.7, 0.006)
	s.capsule(Vector3(0.0, -0.45, 0.02), Vector3(0.0, -0.78, -0.02), 0.12, 0.1, COAT, 0.05, 0.7, 0.006)
	s.ellipsoid(Vector3(0.0, -0.92, -0.02), Vector3(0.15, 0.15, 0.11), COAT, 0.06, 0.6, 0.004)
	s.paint_box(Vector3(0.0, -0.8, 0.0), Vector3(0.2, 0.025, 0.2), METAL, 0.35)  # the wrist joint showing
	s.paint_ellipsoid(Vector3(0.05, -0.98, -0.1), Vector3(0.1, 0.08, 0.06), STAIN, 0.25)
	for k in 4:
		var x := -0.09 + 0.06 * float(k)
		var tip := Vector3(x * 1.1, -1.17 + absf(x) * 0.4, -0.08)
		s.capsule(Vector3(x, -1.0, -0.02), tip, 0.045, 0.038, COAT, 0.03, 0.6, 0.003)
		s.tube_add(PackedVector3Array([tip + Vector3(0.0, 0.01, -0.01), tip + Vector3(0.0, -0.05, -0.04), tip + Vector3(0.0, -0.08, -0.09)]), PackedFloat32Array([0.016, 0.01, 0.002]), METAL, 0.25, 6)
	s.capsule(Vector3(-side * 0.12, -0.88, -0.05), Vector3(-side * 0.16, -1.02, -0.1), 0.05, 0.042, COAT, 0.03, 0.6)
	return s.noise_scale(12.0).mesh("pappy_arm_%d" % int(side), 0.02, 2000)


## Head-local (the neck pivot): the face centred at y 0.3, the chef's hat on top.
static func face() -> ArrayMesh:
	var s := Sculpt.new()
	s.ellipsoid(Vector3(0.0, 0.3, 0.0), Vector3(0.36, 0.4, 0.36), LATEX, 0.04, 0.5, 0.006)
	for x: float in [-1.0, 1.0]:
		s.ellipsoid(Vector3(x * 0.2, 0.2, -0.22), Vector3(0.14, 0.12, 0.12), LATEX, 0.06, 0.45, 0.004)
		s.ellipsoid(Vector3(x * 0.35, 0.33, 0.0), Vector3(0.05, 0.1, 0.07), LATEX, 0.03, 0.5)  # ears
	s.ellipsoid(Vector3(0.0, 0.27, -0.38), Vector3(0.11, 0.095, 0.1), NOSE, 0.04, 0.35)
	s.capsule(Vector3(-0.22, 0.47, -0.3), Vector3(0.22, 0.47, -0.3), 0.06, 0.06, LATEX, 0.05, 0.5)  # the brow
	for x: float in [-0.14, 0.14]:
		s.carve_ellipsoid(Vector3(x, 0.4, -0.33), Vector3(0.085, 0.072, 0.09), DARK, 0.02)
	s.paint_ellipsoid(Vector3(0.0, 0.4, -0.33), Vector3(0.3, 0.12, 0.1), LATEX_DARK, 0.5)
	# The grin: far too wide, up at the corners, full of teeth, gums showing.
	s.carve_capsule(Vector3(-0.21, 0.08, -0.3), Vector3(0.21, 0.08, -0.3), 0.072, 0.072, GUM, 0.02)
	for x: float in [-1.0, 1.0]:
		s.carve_capsule(Vector3(x * 0.2, 0.08, -0.28), Vector3(x * 0.3, 0.17, -0.2), 0.05, 0.03, GUM, 0.02)
	for k in 13:
		var x := -0.18 + 0.03 * float(k)
		var zz := -0.28 - 0.035 * (1.0 - pow(absf(x) / 0.2, 2.0))  # set back inside the cut, following the face
		s.tube_add(PackedVector3Array([Vector3(x, 0.15, zz + 0.04), Vector3(x, 0.095, zz + 0.005)]), PackedFloat32Array([0.014, 0.008]), TOOTH, 0.3, 6)
		s.tube_add(PackedVector3Array([Vector3(x + 0.015, 0.005, zz + 0.04), Vector3(x + 0.015, 0.06, zz + 0.005)]), PackedFloat32Array([0.013, 0.007]), TOOTH, 0.3, 6)
	# The left cheek split open on the metal jaw: a piston, a hinge, a wire.
	s.carve_ellipsoid(Vector3(-0.26, 0.18, -0.2), Vector3(0.1, 0.1, 0.1), METAL, 0.02)
	s.ellipsoid(Vector3(-0.24, 0.17, -0.18), Vector3(0.05, 0.05, 0.05), METAL, 0.0, 0.25)
	s.capsule(Vector3(-0.3, 0.26, -0.15), Vector3(-0.22, 0.08, -0.22), 0.018, 0.018, METAL, 0.0, 0.25)
	s.tube_add(PackedVector3Array([Vector3(-0.28, 0.24, -0.2), Vector3(-0.3, 0.14, -0.26), Vector3(-0.27, 0.04, -0.28)]), PackedFloat32Array([0.008, 0.008, 0.006]), WIRE_RED, 0.4, 5)
	# The mustache, curled.
	for x: float in [-1.0, 1.0]:
		s.capsule(Vector3(0.0, 0.2, -0.42), Vector3(x * 0.2, 0.19, -0.37), 0.045, 0.036, MUSTACHE, 0.03, 0.85, 0.004)
		s.capsule(Vector3(x * 0.2, 0.19, -0.37), Vector3(x * 0.31, 0.27, -0.28), 0.036, 0.018, MUSTACHE, 0.02, 0.85)
	# The hat: a band, a puffed top.
	s.ellipsoid(Vector3(0.0, 0.72, 0.0), Vector3(0.31, 0.1, 0.31), COAT, 0.03, 0.75)
	s.ellipsoid(Vector3(0.0, 0.93, 0.0), Vector3(0.36, 0.2, 0.36), COAT, 0.06, 0.75, 0.01)
	for k in 4:
		var a := TAU * float(k) / 4.0 + 0.4
		s.ellipsoid(Vector3(cos(a) * 0.2, 0.98, sin(a) * 0.2), Vector3(0.19, 0.17, 0.19), COAT, 0.08, 0.75, 0.01)
	s.paint_ellipsoid(Vector3(0.15, 0.75, -0.3), Vector3(0.12, 0.08, 0.06), COAT_GRIME, 0.8)
	return s.noise_scale(14.0).mesh("pappy_face", 0.014, 6000)
