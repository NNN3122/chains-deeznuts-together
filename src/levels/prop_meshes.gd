class_name PropMeshes
extends RefCounted
## Office furniture sculpted instead of stacked boxes (the user: "everything is boxes"): rounded
## edges that catch the light, dents, scuffs, stains, a dying plant. Built with Sculpt, cached on
## disk like the bodies, and drawn by LevelKit.BoxBatch as one MultiMesh per prop per floor; the
## boxes they replace stay behind as collision only, so nothing about movement changes.
## Every prop stands on its origin (y = 0 is the floor) facing -Z, except the box-shaped ones
## (BOXED), which are centred and scaled to the box they replace, in any key that uses them.

const CELL_FINE: float = 0.009  # m, grid for props with thin parts
const CELL: float = 0.014

## Box keys that turn into a sculpted prop wherever they are added: key -> [mesh key, native size].
## A box whose size is the native one turned a quarter is drawn turned a quarter.
const BOXED: Dictionary = {
	"cardboard": ["cardboard", Vector3(1.0, 1.0, 1.0)],
	"cardboard_dark": ["cardboard_dark", Vector3(1.0, 1.0, 1.0)],
	"partition": ["partition", Vector3(1.9, 1.3, 0.06)],
	"door": ["door", Vector3(0.68, 2.2, 0.045)],
	"desk": ["slab", Vector3(1.0, 0.05, 1.0)],
}

const LAMINATE: Color = Color(0.6, 0.48, 0.34)
const FABRIC: Color = Color(0.2, 0.22, 0.28)
const PLASTIC: Color = Color(0.07, 0.07, 0.075)
const STEEL: Color = Color(0.46, 0.47, 0.49)
const CARD: Color = Color(0.56, 0.43, 0.28)
const GRIME: Color = Color(0.2, 0.16, 0.1)

static var _material: ShaderMaterial
static var _meshes: Dictionary = {}


static func material() -> ShaderMaterial:
	if _material == null:
		_material = Sculpt.material(0.0, 0.0, 0.0, 0.0, 0.3)
	return _material


## A prop's transform: standing at pos, turned yaw, optionally scaled.
static func at(pos: Vector3, yaw: float, scale: Vector3 = Vector3.ONE) -> Transform3D:
	return Transform3D(Basis.from_euler(Vector3(0.0, yaw, 0.0)) * Basis.from_scale(scale), pos)


static func mesh(key: String) -> ArrayMesh:
	if _meshes.has(key):
		return _meshes[key]
	var m: ArrayMesh
	match key:
		"office_chair": m = _office_chair()
		"desk": m = _desk()
		"monitor": m = _monitor()
		"cabinet": m = _cabinet()
		"partition": m = _partition()
		"shelf_unit": m = _shelf_unit()
		"cardboard": m = _cardboard(CARD, "cardboard")
		"cardboard_dark": m = _cardboard(CARD.darkened(0.3), "cardboard_dark")
		"plant": m = _plant()
		"door": m = _door()
		"slab": m = _slab()
		"long_table": m = _long_table()
		_ when key.begins_with("ruin_"):
			m = RuinMeshes.mesh(key)  # Carrow Heights' wreckage
		_ when key.begins_with("manor_"):
			m = ManorMeshes.mesh(key)  # Ashgrave Manor's grounds
		_:
			push_warning("PropMeshes: no prop '%s'" % key)
			m = Sculpt.new().box(Vector3.ZERO, Vector3.ONE * 0.1, 0.02, Color.MAGENTA).mesh("prop_missing", 0.02, 100)
	_meshes[key] = m
	return m


## For BoxBatch: a box of this key and size as a prop, or an empty array to keep it a box.
## Returns [mesh key, Transform3D] for the box centred at center, turned rot_y.
static func boxed(key: String, center: Vector3, size: Vector3, rot_y: float) -> Array:
	if not BOXED.has(key):
		return []
	var entry: Array = BOXED[key]
	var native: Vector3 = entry[1]
	var yaw := rot_y
	var s := size
	# A box laid the other way round (thin along x instead of z): turn the prop a quarter.
	if (native.x > native.z) != (size.x > size.z) and absf(size.x - size.z) > 0.01:
		yaw += PI * 0.5
		s = Vector3(size.z, size.y, size.x)
	var scale := Vector3(s.x / native.x, s.y / native.y, s.z / native.z)
	return [String(entry[0]), Transform3D(Basis.from_euler(Vector3(0.0, yaw, 0.0)) * Basis.from_scale(scale), center)]


# --- Recipes ---------------------------------------------------------------------------------------

## A worn task chair: a stained fabric seat and back, a gas lift, five legs on casters. Back at +Z.
static func _office_chair() -> ArrayMesh:
	var s := Sculpt.new()
	s.box(Vector3(0.0, 0.47, 0.0), Vector3(0.24, 0.045, 0.23), 0.04, FABRIC, 0.02, 0.95, 0.003)
	s.box(Vector3(0.0, 0.82, 0.235), Vector3(0.21, 0.25, 0.035), 0.045, FABRIC, 0.02, 0.95, 0.003, Basis.from_euler(Vector3(-0.12, 0.0, 0.0)))
	s.paint_ellipsoid(Vector3(0.06, 0.52, -0.04), Vector3(0.09, 0.03, 0.07), FABRIC.darkened(0.45), 0.9)  # a stain
	s.paint_ellipsoid(Vector3(-0.08, 0.86, 0.2), Vector3(0.06, 0.08, 0.05), Color(0.25, 0.12, 0.1), 0.9)
	s.box(Vector3(0.0, 0.42, 0.0), Vector3(0.12, 0.02, 0.12), 0.01, PLASTIC, 0.02, 0.5)
	s.tube_add(PackedVector3Array([Vector3(0.0, 0.43, 0.15), Vector3(0.0, 0.52, 0.24), Vector3(0.0, 0.62, 0.25)]), PackedFloat32Array([0.022, 0.02, 0.02]), PLASTIC, 0.5, 8)
	s.tube_add(PackedVector3Array([Vector3(0.0, 0.08, 0.0), Vector3(0.0, 0.25, 0.0), Vector3(0.0, 0.41, 0.0)]), PackedFloat32Array([0.026, 0.024, 0.022]), STEEL, 0.35, 10)
	for k in 5:
		var a := TAU * float(k) / 5.0
		var d := Vector3(cos(a), 0.0, sin(a))
		s.tube_add(PackedVector3Array([Vector3(0.0, 0.085, 0.0), d * 0.16 + Vector3(0.0, 0.075, 0.0), d * 0.3 + Vector3(0.0, 0.06, 0.0)]), PackedFloat32Array([0.03, 0.022, 0.018]), PLASTIC, 0.5, 8)
		s.ellipsoid(d * 0.31 + Vector3(0.0, 0.03, 0.0), Vector3(0.028, 0.028, 0.02), PLASTIC, 0.01, 0.6, 0.0, Basis.from_euler(Vector3(0.0, -a, 0.0)))
	return s.noise_scale(30.0).mesh("prop_office_chair", CELL_FINE, 1400)


## A cubicle desk: a laminate top with a worn front edge and a coffee ring, grey side panels, a
## modesty panel at +Z. The chair side is -Z.
static func _desk() -> ArrayMesh:
	var s := Sculpt.new()
	s.box(Vector3(0.0, 0.73, 0.0), Vector3(0.75, 0.02, 0.375), 0.008, LAMINATE, 0.0, 0.5, 0.0006)
	s.paint_box(Vector3(0.0, 0.75, -0.33), Vector3(0.6, 0.03, 0.05), LAMINATE.lightened(0.15), 0.7)  # the edge your arms wore
	s.paint_ellipsoid(Vector3(-0.42, 0.75, 0.05), Vector3(0.05, 0.01, 0.05), LAMINATE.darkened(0.4), 0.4)
	for x: float in [-0.7, 0.7]:
		s.box(Vector3(x, 0.36, 0.0), Vector3(0.02, 0.35, 0.34), 0.006, Color(0.3, 0.3, 0.32), 0.0, 0.55, 0.0005)
		s.paint_box(Vector3(x, 0.03, 0.0), Vector3(0.03, 0.04, 0.35), GRIME, 0.9)  # kicked
	s.box(Vector3(0.0, 0.45, 0.33), Vector3(0.68, 0.25, 0.01), 0.005, Color(0.3, 0.3, 0.32), 0.0, 0.55)
	return s.noise_scale(14.0).mesh("prop_desk", CELL_FINE, 900)


## An old flat monitor's shell, neck and foot (the screen itself is a separate glowing box). The
## screen faces -Z.
static func _monitor() -> ArrayMesh:
	var s := Sculpt.new()
	s.box(Vector3(0.0, 1.06, 0.03), Vector3(0.3, 0.19, 0.02), 0.012, PLASTIC, 0.0, 0.45)
	s.box(Vector3(0.0, 1.05, 0.06), Vector3(0.18, 0.12, 0.025), 0.02, PLASTIC, 0.02, 0.5)
	s.box(Vector3(0.0, 0.84, 0.06), Vector3(0.025, 0.11, 0.018), 0.01, PLASTIC, 0.01, 0.5)
	s.box(Vector3(0.0, 0.752, 0.05), Vector3(0.12, 0.008, 0.085), 0.006, PLASTIC, 0.01, 0.5)
	s.paint_box(Vector3(0.0, 1.06, 0.0), Vector3(0.3, 0.19, 0.01), Color(0.05, 0.05, 0.055), 0.2)
	return s.mesh("prop_monitor", CELL_FINE, 500)


## A two-drawer filing cabinet, dented, rust at the foot, handles on the -Z front.
static func _cabinet() -> ArrayMesh:
	var s := Sculpt.new()
	s.box(Vector3(0.0, 0.33, 0.0), Vector3(0.21, 0.33, 0.275), 0.012, STEEL, 0.0, 0.45, 0.002)
	s.carve_box(Vector3(0.0, 0.33, -0.275), Vector3(0.2, 0.004, 0.006), STEEL.darkened(0.6))
	for h: float in [0.2, 0.47]:
		s.box(Vector3(0.0, h, -0.288), Vector3(0.07, 0.009, 0.011), 0.006, PLASTIC, 0.004, 0.4)
	s.paint_box(Vector3(0.0, 0.02, 0.0), Vector3(0.22, 0.05, 0.28), Color(0.4, 0.22, 0.12), 0.9)
	s.paint_ellipsoid(Vector3(0.12, 0.5, -0.27), Vector3(0.06, 0.08, 0.03), STEEL.darkened(0.35), 0.7)
	return s.noise_scale(9.0).mesh("prop_cabinet", CELL_FINE, 600)


## A cubicle partition along X (1.9 x 1.3 x 0.06, centred), fuzzy fabric in a grey frame, with a
## water stain spreading up from the floor.
static func _partition() -> ArrayMesh:
	var s := Sculpt.new()
	s.box(Vector3.ZERO, Vector3(0.95, 0.65, 0.03), 0.012, Color(0.34, 0.36, 0.41), 0.0, 0.95, 0.0015)
	s.capsule(Vector3(-0.95, 0.64, 0.0), Vector3(0.95, 0.64, 0.0), 0.028, 0.028, Color(0.5, 0.5, 0.52), 0.005, 0.5)
	for x: float in [-0.95, 0.95]:
		s.capsule(Vector3(x, -0.65, 0.0), Vector3(x, 0.64, 0.0), 0.03, 0.03, Color(0.5, 0.5, 0.52), 0.005, 0.5)
	s.paint_ellipsoid(Vector3(0.3, -0.62, 0.0), Vector3(0.45, 0.28, 0.06), Color(0.26, 0.22, 0.17), 0.95)
	return s.noise_scale(22.0).mesh("prop_partition", CELL, 500)


## A steel shelf unit along X (1.8 x 2.0 x 0.5), four boards on angle posts, rusting.
static func _shelf_unit() -> ArrayMesh:
	var s := Sculpt.new()
	for h: float in [0.05, 0.7, 1.35, 1.98]:
		s.box(Vector3(0.0, h, 0.0), Vector3(0.9, 0.018, 0.25), 0.006, STEEL, 0.0, 0.4, 0.0008)
		s.paint_ellipsoid(Vector3(0.4 - h * 0.3, h + 0.02, 0.05), Vector3(0.18, 0.02, 0.12), Color(0.42, 0.24, 0.12), 0.9)
	for cx: float in [-0.88, 0.88]:
		for cz: float in [-0.23, 0.23]:
			s.box(Vector3(cx, 1.0, cz), Vector3(0.018, 1.0, 0.018), 0.004, STEEL.darkened(0.2), 0.004, 0.4)
	return s.mesh("prop_shelf_unit", CELL_FINE, 1200)


## A cardboard box, centred, 1 m a side before scaling: soft edges, a sagging lid, packing tape,
## crushed corners and grime.
static func _cardboard(col: Color, key: String) -> ArrayMesh:
	var s := Sculpt.new()
	s.box(Vector3.ZERO, Vector3(0.5, 0.5, 0.5), 0.03, col, 0.0, 0.85, 0.012)
	s.carve_box(Vector3(0.0, 0.5, 0.0), Vector3(0.006, 0.01, 0.5), col.darkened(0.5))  # the flaps' seam
	s.paint_box(Vector3(0.0, 0.5, 0.0), Vector3(0.07, 0.02, 0.52), col.lightened(0.25), 0.3)  # tape
	s.paint_box(Vector3(0.0, 0.0, 0.5), Vector3(0.07, 0.52, 0.02), col.lightened(0.25), 0.3)
	s.paint_box(Vector3(0.0, -0.46, 0.0), Vector3(0.52, 0.06, 0.52), col.darkened(0.45), 0.95)  # damp from the floor
	s.paint_ellipsoid(Vector3(0.35, 0.2, -0.5), Vector3(0.15, 0.2, 0.05), col.darkened(0.3), 0.9)
	return s.noise_scale(4.0).mesh("prop_" + key, 0.03, 400)


## A potted office plant left to die: a cracked pot, dry soil, drooping blades gone brown at the tips.
static func _plant() -> ArrayMesh:
	var s := Sculpt.new()
	s.capsule(Vector3(0.0, 0.02, 0.0), Vector3(0.0, 0.48, 0.0), 0.17, 0.235, Color(0.5, 0.26, 0.17), 0.01, 0.8, 0.002)
	s.carve_capsule(Vector3(0.0, 0.5, 0.0), Vector3(0.0, 0.62, 0.0), 0.2, 0.2, Color(0.12, 0.09, 0.06))
	s.paint_box(Vector3(0.12, 0.25, -0.2), Vector3(0.01, 0.2, 0.05), Color(0.18, 0.1, 0.07), 0.9)  # the crack
	var r := RandomNumberGenerator.new()
	r.seed = 4242
	for k in 14:
		var a := TAU * float(k) / 14.0 + r.randf_range(-0.2, 0.2)
		var d := Vector3(cos(a), 0.0, sin(a))
		var h := r.randf_range(0.45, 0.85)
		var dead := r.randf() < 0.35
		var green := Color(0.16, 0.26, 0.1) if not dead else Color(0.36, 0.28, 0.14)
		var pts := PackedVector3Array([
			d * 0.03 + Vector3(0.0, 0.46, 0.0), d * 0.1 + Vector3(0.0, 0.46 + h * 0.6, 0.0),
			d * (0.22 + h * 0.2) + Vector3(0.0, 0.46 + h, 0.0), d * (0.36 + h * 0.25) + Vector3(0.0, 0.46 + h * (0.55 if dead else 0.8), 0.0),
		])
		s.tube_add(pts, PackedFloat32Array([0.012, 0.016, 0.012, 0.003]), green, 0.7, 5)
	return s.mesh("prop_plant", CELL, 1800)


## A door leaf, centred (0.68 x 2.2 x 0.045, width along X): two recessed panels each side, a lever
## handle on both faces at the free end (+X), kick marks low, a dark smear where a hand dragged.
static func _door() -> ArrayMesh:
	var s := Sculpt.new()
	var wood := Color(0.42, 0.29, 0.17)
	s.box(Vector3.ZERO, Vector3(0.34, 1.1, 0.0225), 0.008, wood, 0.0, 0.55, 0.0008)
	for side: float in [-1.0, 1.0]:
		for y: float in [0.45, -0.45]:
			s.carve_box(Vector3(0.0, y, side * 0.0225), Vector3(0.24, 0.42, 0.005), wood.darkened(0.25))
		s.box(Vector3(0.26, -0.11, side * 0.04), Vector3(0.05, 0.008, 0.008), 0.006, STEEL, 0.006, 0.3)
		s.box(Vector3(0.29, -0.11, side * 0.03), Vector3(0.012, 0.012, 0.012), 0.006, STEEL, 0.006, 0.3)
		s.paint_box(Vector3(0.0, -1.0, side * 0.0225), Vector3(0.3, 0.1, 0.01), wood.darkened(0.5), 0.9)
	s.paint_ellipsoid(Vector3(0.18, 0.1, -0.0225), Vector3(0.05, 0.35, 0.01), Color(0.12, 0.06, 0.05), 0.6)
	return s.mesh("prop_door", 0.006, 700)


## A tabletop slab, centred, 1 x 0.05 x 1 before scaling (desk and table tops of every size).
static func _slab() -> ArrayMesh:
	var s := Sculpt.new()
	s.box(Vector3.ZERO, Vector3(0.5, 0.025, 0.5), 0.012, LAMINATE, 0.0, 0.5, 0.0008)
	s.paint_box(Vector3(0.0, 0.025, -0.45), Vector3(0.45, 0.01, 0.05), LAMINATE.lightened(0.12), 0.7)
	s.paint_ellipsoid(Vector3(0.25, 0.025, 0.1), Vector3(0.04, 0.01, 0.04), LAMINATE.darkened(0.4), 0.4)
	return s.mesh("prop_slab", 0.01, 300)


## A meeting table (3.2 x 1.2 top at 0.74 m) on two pedestal legs.
static func _long_table() -> ArrayMesh:
	var s := Sculpt.new()
	s.box(Vector3(0.0, 0.74, 0.0), Vector3(1.6, 0.03, 0.6), 0.02, LAMINATE.darkened(0.15), 0.0, 0.45, 0.0006)
	for x: float in [-1.4, 1.4]:
		s.box(Vector3(x, 0.36, 0.0), Vector3(0.04, 0.36, 0.45), 0.015, Color(0.25, 0.25, 0.27), 0.0, 0.5)
		s.box(Vector3(x, 0.02, 0.0), Vector3(0.07, 0.02, 0.5), 0.01, Color(0.2, 0.2, 0.22), 0.01, 0.5)
	s.paint_ellipsoid(Vector3(-0.5, 0.77, 0.2), Vector3(0.05, 0.01, 0.05), LAMINATE.darkened(0.5), 0.4)
	return s.mesh("prop_long_table", CELL, 700)
