class_name ManorMeshes
extends RefCounted
## Ashgrave Manor's grounds, sculpted: headstones chipped and mossy, a stone cross, an obelisk, a
## ledger slab with its lid shoved aside, gnarled dead trees, a hooded mourner statue weeping black,
## an open coffin, a fresh grave mound with the spade still in it, the four old pump engines you
## repair, the main generator, iron lamp posts, iron fence sections, a broken cart, chapel pews, a
## well with its roof caved in, and dead thorn bushes. Built with Sculpt and cached on disk like the
## other props; drawn by LevelKit.BoxBatch.add_prop (PropMeshes.mesh hands any "manor_" key here).
## Collision is never the mesh: Manor lays plain boxes under them. Every piece stands on its origin
## (y = 0 at its base), centred in x and z, at the native size in NATIVE.

const STONE: Color = Color(0.42, 0.41, 0.38)
const STONE_DARK: Color = Color(0.26, 0.255, 0.245)
const MOSS: Color = Color(0.12, 0.15, 0.07)
const LICHEN: Color = Color(0.4, 0.4, 0.28)
const BARK: Color = Color(0.14, 0.12, 0.1)
const BARK_DARK: Color = Color(0.06, 0.05, 0.045)
const IRON: Color = Color(0.09, 0.085, 0.08)
const RUST: Color = Color(0.3, 0.14, 0.07)
const WOOD: Color = Color(0.21, 0.15, 0.1)
const WOOD_ROT: Color = Color(0.12, 0.09, 0.06)
const EARTH: Color = Color(0.17, 0.13, 0.09)
const BRASS: Color = Color(0.45, 0.35, 0.15)
const PAINT_RED: Color = Color(0.34, 0.07, 0.05)  # the engines' paint, flaking off
const VOID: Color = Color(0.01, 0.01, 0.01)

## Native size of each piece (m): scale a transform by size / NATIVE to fit a box.
const NATIVE: Dictionary = {
	"manor_tomb_round": Vector3(0.7, 1.0, 0.24),
	"manor_tomb_cross": Vector3(0.7, 1.3, 0.28),
	"manor_obelisk": Vector3(0.8, 2.8, 0.8),
	"manor_ledger": Vector3(1.1, 0.42, 2.2),
	"manor_tree": Vector3(5.0, 7.5, 5.0),
	"manor_mourner": Vector3(0.9, 2.3, 0.9),
	"manor_coffin": Vector3(0.9, 0.6, 2.1),
	"manor_mound": Vector3(1.5, 1.5, 2.3),
	"manor_engine": Vector3(1.8, 1.4, 1.1),
	"manor_generator": Vector3(3.2, 2.4, 1.8),
	"manor_lamp": Vector3(0.5, 3.3, 0.5),
	"manor_fence": Vector3(2.0, 1.5, 0.12),
	"manor_cart": Vector3(2.0, 1.4, 2.8),
	"manor_pew": Vector3(2.0, 0.95, 0.6),
	"manor_well": Vector3(2.0, 2.6, 2.0),
	"manor_thorns": Vector3(1.8, 1.2, 1.8),
	"manor_grass": Vector3(1.4, 1.5, 1.4),  # a clump of tall dead grass
	"manor_hang_tree": Vector3(5.0, 7.0, 5.0),  # a dead tree with one long limb out along +x (HANG_POINT)
	"manor_gallows": Vector3(3.4, 3.9, 0.6),  # posts and a beam; nooses at GALLOWS_POINTS
	"manor_hanged": Vector3(0.5, 2.4, 0.45),  # origin at the top of its rope, hanging down -y
	# Set dressing.
	"manor_urn": Vector3(0.8, 1.6, 0.8),
	"manor_bench": Vector3(1.8, 0.5, 0.5),
	"manor_barrel": Vector3(0.66, 0.95, 0.66),
	"manor_crate": Vector3(0.95, 0.7, 0.75),
	"manor_logs": Vector3(1.0, 0.65, 0.9),
	"manor_branch": Vector3(3.2, 0.6, 1.6),
	"manor_wheelbarrow": Vector3(0.7, 0.75, 1.6),
	"manor_column": Vector3(0.8, 2.0, 0.8),
	"manor_angel": Vector3(1.1, 2.3, 0.9),
	"manor_chair": Vector3(0.5, 1.1, 0.5),
	"manor_candelabra": Vector3(0.45, 0.75, 0.1),
	"manor_sheeted": Vector3(1.15, 1.05, 1.05),
	"manor_chest": Vector3(1.0, 0.68, 0.6),
	"manor_shutter": Vector3(0.7, 1.6, 0.06),
	# Furniture: each faces +z (a bed's head and a desk's back toward -z).
	"manor_table": Vector3(3.4, 0.97, 1.9),  # one of three laid end to end in the dining room
	"manor_piano": Vector3(1.5, 1.85, 2.3),  # the keyboard at +z, the lid propped open
	"manor_desk": Vector3(2.2, 0.98, 1.4),
	"manor_bookcase": Vector3(2.0, 4.0, 0.66),
	"manor_clock": Vector3(0.6, 2.34, 0.5),
	"manor_side_table": Vector3(1.2, 0.8, 0.6),
	"manor_bed": Vector3(2.4, 2.7, 2.8),
	"manor_cot": Vector3(1.1, 1.1, 2.1),
	"manor_crib": Vector3(0.9, 1.1, 1.5),
	"manor_wardrobe": Vector3(1.8, 2.4, 0.8),
	"manor_tub": Vector3(2.0, 0.8, 0.9),
}
const MAHOGANY: Color = Color(0.16, 0.075, 0.045)
const EBONY: Color = Color(0.035, 0.032, 0.03)
const IVORY: Color = Color(0.68, 0.63, 0.5)
const LINEN: Color = Color(0.52, 0.49, 0.42)
const LEATHER: Color = Color(0.06, 0.08, 0.055)
const PORCELAIN: Color = Color(0.62, 0.61, 0.56)
const GLASS: Color = Color(0.025, 0.03, 0.035)
const DUST: Color = Color(0.3, 0.29, 0.27)
const SHADOW: Color = Color(0.03, 0.022, 0.016)  # the inside of a cabinet
const BOOK_COLORS: Array[Color] = [Color(0.24, 0.05, 0.04), Color(0.07, 0.11, 0.07), Color(0.1, 0.075, 0.055), Color(0.28, 0.2, 0.11),
	Color(0.05, 0.06, 0.11), Color(0.33, 0.28, 0.2), Color(0.14, 0.035, 0.035), Color(0.04, 0.04, 0.035)]
const VELVET: Color = Color(0.2, 0.05, 0.06)
const WAX: Color = Color(0.82, 0.78, 0.66)
const VERDIGRIS: Color = Color(0.2, 0.32, 0.26)
const SHUTTER: Color = Color(0.12, 0.14, 0.11)  # paint long gone green-black
## Where a rope goes over the hanging tree's limb, and over the gallows' beam (native, from the base).
const HANG_POINT: Vector3 = Vector3(1.75, 3.32, 0.1)
const GALLOWS_POINTS: Array[Vector3] = [Vector3(-0.85, 3.62, 0.0), Vector3(0.0, 3.62, 0.0), Vector3(0.85, 3.62, 0.0)]
const STRAW: Color = Color(0.4, 0.34, 0.19)
const GRASS_DEAD: Color = Color(0.27, 0.25, 0.17)
const GRASS_DARK: Color = Color(0.1, 0.13, 0.06)
const SHROUD: Color = Color(0.48, 0.45, 0.39)
const SHROUD_DIRT: Color = Color(0.22, 0.19, 0.15)
const ROPE: Color = Color(0.3, 0.25, 0.16)
const DEAD_SKIN: Color = Color(0.4, 0.4, 0.37)
const OLD_BLOOD: Color = Color(0.2, 0.02, 0.02)

## Photo detail under a piece's painted colours (Sculpt's `detail`; ambientCG CC0 sets in
## assets/textures/manor/): key -> [folder, mesh units per repeat, strength, bump].
const DETAIL: Dictionary = {
	"manor_tomb_round": ["rock", 0.7, 0.9, 1.3],
	"manor_tomb_cross": ["rock", 0.7, 0.9, 1.3],
	"manor_obelisk": ["rock", 0.9, 0.9, 1.3],
	"manor_ledger": ["rock", 0.9, 0.9, 1.3],
	"manor_mourner": ["rock", 0.6, 0.8, 1.1],
	"manor_well": ["stone_old", 1.4, 0.8, 1.2],
	"manor_tree": ["bark", 0.8, 1.0, 1.6],
	"manor_hang_tree": ["bark", 0.8, 1.0, 1.6],
	"manor_thorns": ["bark", 0.45, 0.7, 1.0],
	"manor_coffin": ["wood", 0.7, 0.8, 1.0],
	"manor_cart": ["wood", 0.8, 0.8, 1.0],
	"manor_pew": ["wood", 0.7, 0.8, 1.0],
	"manor_gallows": ["wood", 0.8, 0.85, 1.1],
	"manor_mound": ["earth_dirt", 1.3, 0.9, 1.4],
	"manor_engine": ["rust", 0.6, 0.85, 1.2],
	"manor_generator": ["rust", 0.9, 0.85, 1.2],
	"manor_lamp": ["rust", 0.4, 0.7, 1.0],
	"manor_fence": ["rust", 0.4, 0.7, 1.0],
	"manor_urn": ["rock", 0.6, 0.85, 1.2],
	"manor_bench": ["rock", 0.7, 0.85, 1.2],
	"manor_column": ["rock", 0.7, 0.85, 1.2],
	"manor_angel": ["rock", 0.6, 0.8, 1.1],
	"manor_barrel": ["wood", 0.6, 0.8, 1.0],
	"manor_crate": ["planks", 0.8, 0.85, 1.0],
	"manor_logs": ["bark", 0.5, 0.9, 1.4],
	"manor_branch": ["bark", 0.6, 1.0, 1.5],
	"manor_wheelbarrow": ["wood", 0.6, 0.8, 1.0],
	"manor_chair": ["wood", 0.4, 0.7, 0.9],
	"manor_chest": ["wood", 0.5, 0.8, 1.0],
	"manor_shutter": ["wood", 0.5, 0.8, 1.0],
	"manor_sheeted": ["cloth", 0.6, 0.8, 1.2],
	"manor_table": ["wood", 0.5, 0.55, 0.8],
	"manor_piano": ["wood", 0.5, 0.3, 0.5],
	"manor_desk": ["wood", 0.5, 0.6, 0.8],
	"manor_bookcase": ["wood", 0.5, 0.55, 0.8],
	"manor_clock": ["wood", 0.45, 0.6, 0.8],
	"manor_side_table": ["wood", 0.45, 0.6, 0.8],
	"manor_bed": ["cloth", 0.5, 0.5, 0.9],
	"manor_cot": ["rust", 0.35, 0.45, 0.8],
	"manor_crib": ["wood", 0.4, 0.55, 0.8],
	"manor_wardrobe": ["wood", 0.55, 0.65, 0.9],
	"manor_tub": ["plaster", 0.6, 0.35, 0.6],
}

static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}


## The material a piece is drawn with: the shared sculpt material with that piece's photo detail.
static func material(key: String) -> Material:
	if not DETAIL.has(key):
		return PropMeshes.material()
	if _materials.has(key):
		return _materials[key]
	var spec: Array = DETAIL[key]
	var m := Sculpt.material(0.0, 0.0, 0.0, 0.0, 0.15)
	var folder := LevelKit.MANOR_TEXTURES + String(spec[0]) + "/"
	m.set_shader_parameter("detail_albedo", load(folder + "color.jpg"))
	m.set_shader_parameter("detail_normal", load(folder + "normal.jpg"))
	m.set_shader_parameter("detail_span", float(spec[1]))
	m.set_shader_parameter("detail", float(spec[2]))
	m.set_shader_parameter("detail_bump", float(spec[3]))
	_materials[key] = m
	return m


static func mesh(key: String) -> ArrayMesh:
	if _meshes.has(key):
		return _meshes[key]
	var m: ArrayMesh
	match key:
		"manor_tomb_round": m = _tomb_round()
		"manor_tomb_cross": m = _tomb_cross()
		"manor_obelisk": m = _obelisk()
		"manor_ledger": m = _ledger()
		"manor_tree": m = _tree()
		"manor_mourner": m = _mourner()
		"manor_coffin": m = _coffin()
		"manor_mound": m = _mound()
		"manor_engine": m = _engine()
		"manor_generator": m = _generator()
		"manor_lamp": m = _lamp()
		"manor_fence": m = _fence()
		"manor_cart": m = _cart()
		"manor_pew": m = _pew()
		"manor_well": m = _well()
		"manor_thorns": m = _thorns()
		"manor_grass": m = _grass()
		"manor_hang_tree": m = _hang_tree()
		"manor_gallows": m = _gallows()
		"manor_hanged": m = _hanged()
		"manor_urn": m = _urn()
		"manor_bench": m = _bench()
		"manor_barrel": m = _barrel()
		"manor_crate": m = _crate()
		"manor_logs": m = _logs()
		"manor_branch": m = _branch()
		"manor_wheelbarrow": m = _wheelbarrow()
		"manor_column": m = _column()
		"manor_angel": m = _angel()
		"manor_chair": m = _chair()
		"manor_candelabra": m = _candelabra()
		"manor_sheeted": m = _sheeted()
		"manor_chest": m = _chest()
		"manor_shutter": m = _shutter()
		"manor_table": m = _table()
		"manor_piano": m = _piano()
		"manor_desk": m = _desk()
		"manor_bookcase": m = _bookcase()
		"manor_clock": m = _clock()
		"manor_side_table": m = _side_table()
		"manor_bed": m = _bed()
		"manor_cot": m = _cot()
		"manor_crib": m = _crib()
		"manor_wardrobe": m = _wardrobe()
		"manor_tub": m = _tub()
		_:
			push_warning("ManorMeshes: no piece '%s'" % key)
			m = Sculpt.new().box(Vector3.ZERO, Vector3.ONE * 0.1, 0.02, Color.MAGENTA).mesh("manor_missing", 0.02, 100)
	_meshes[key] = m
	return m


## A transform that fits piece `key` to a box of `size` standing at `base`, turned by `basis`.
static func fit(key: String, base: Vector3, size: Vector3, basis: Basis = Basis.IDENTITY) -> Transform3D:
	var n: Vector3 = NATIVE[key]
	return Transform3D(basis * Basis.from_scale(Vector3(size.x / n.x, size.y / n.y, size.z / n.z)), base)


## A wheel: a rim of tube round `c` in the plane across `axle`, spokes to a hub.
static func _wheel(s: Sculpt, c: Vector3, axle: Vector3, r: float, rim: float, spokes: int, col: Color) -> void:
	var u := axle.cross(Vector3.UP if absf(axle.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT).normalized()
	var w := axle.cross(u).normalized()
	var ring := PackedVector3Array()
	var radii := PackedFloat32Array()
	for k in 25:
		var a := TAU * float(k) / 24.0
		ring.append(c + (u * cos(a) + w * sin(a)) * r)
		radii.append(rim)
	s.tube_add(ring, radii, col, 0.6, 6)
	for k in spokes:
		var a := TAU * float(k) / float(spokes)
		var tip := c + (u * cos(a) + w * sin(a)) * r
		s.tube_add(PackedVector3Array([c, c.lerp(tip, 0.5), tip]), PackedFloat32Array([rim * 0.7, rim * 0.55, rim * 0.5]), col, 0.6, 5)
	s.ellipsoid(c, Vector3.ONE * rim * 2.2, col, 0.01, 0.6)


## The plain headstone: a slab with a rounded top on a plinth, its inscription worn to dashes,
## a bite out of one shoulder, a crack, moss creeping up from the ground and lichen on top.
static func _tomb_round() -> ArrayMesh:
	var s := Sculpt.new().noise_scale(9.0)
	s.box(Vector3(0.0, 0.06, 0.0), Vector3(0.35, 0.06, 0.12), 0.015, STONE_DARK, 0.02, 0.95, 0.01)
	s.box(Vector3(0.0, 0.46, 0.0), Vector3(0.29, 0.38, 0.075), 0.02, STONE, 0.03, 0.93, 0.012)
	s.ellipsoid(Vector3(0.0, 0.82, 0.0), Vector3(0.29, 0.16, 0.075), STONE, 0.03, 0.93, 0.012)
	s.carve_box(Vector3(0.0, 0.56, -0.08), Vector3(0.18, 0.2, 0.012), STONE_DARK, 0.004)
	for k in 4:
		s.paint_box(Vector3(0.0, 0.68 - 0.08 * float(k), -0.07), Vector3(0.13 - 0.03 * float(k % 2), 0.009, 0.012), STONE_DARK.darkened(0.4), 1.0)
	s.carve_ellipsoid(Vector3(0.27, 0.9, 0.0), Vector3(0.13, 0.11, 0.14), STONE_DARK, 0.02)
	s.paint_box(Vector3(-0.07, 0.38, -0.075), Vector3(0.008, 0.26, 0.02), BARK_DARK, 1.0, Basis.from_euler(Vector3(0.0, 0.0, 0.45)))
	s.paint_ellipsoid(Vector3(0.0, 0.1, 0.0), Vector3(0.38, 0.16, 0.16), MOSS, 1.0)
	s.paint_ellipsoid(Vector3(-0.1, 0.88, 0.0), Vector3(0.16, 0.08, 0.12), LICHEN, 1.0)
	return s.mesh("manor_tomb_round", 0.02, 900)


## A stone cross on a stepped base, one arm chipped short.
static func _tomb_cross() -> ArrayMesh:
	var s := Sculpt.new().noise_scale(9.0)
	s.box(Vector3(0.0, 0.07, 0.0), Vector3(0.32, 0.07, 0.14), 0.015, STONE_DARK, 0.02, 0.95, 0.01)
	s.box(Vector3(0.0, 0.19, 0.0), Vector3(0.18, 0.06, 0.1), 0.015, STONE, 0.02, 0.93, 0.01)
	s.box(Vector3(0.0, 0.74, 0.0), Vector3(0.065, 0.5, 0.06), 0.012, STONE, 0.02, 0.93, 0.01)
	s.box(Vector3(0.0, 0.98, 0.0), Vector3(0.3, 0.06, 0.06), 0.012, STONE, 0.02, 0.93, 0.01)
	s.carve_ellipsoid(Vector3(0.31, 1.0, 0.0), Vector3(0.09, 0.1, 0.1), STONE_DARK, 0.015)
	s.paint_ellipsoid(Vector3(0.0, 0.1, 0.0), Vector3(0.34, 0.18, 0.16), MOSS, 1.0)
	s.paint_ellipsoid(Vector3(-0.15, 1.0, 0.0), Vector3(0.12, 0.07, 0.08), LICHEN, 1.0)
	return s.mesh("manor_tomb_cross", 0.02, 900)


## A family obelisk: plinth, die, a shaft that narrows as it climbs, a point; stained and leaning
## a little (the placement leans it more).
static func _obelisk() -> ArrayMesh:
	var s := Sculpt.new().noise_scale(6.0)
	s.box(Vector3(0.0, 0.15, 0.0), Vector3(0.4, 0.15, 0.4), 0.02, STONE_DARK, 0.03, 0.95, 0.015)
	s.box(Vector3(0.0, 0.5, 0.0), Vector3(0.27, 0.22, 0.27), 0.02, STONE, 0.03, 0.93, 0.012)
	for k in 5:
		var y := 0.85 + 0.36 * float(k)
		var hw := 0.17 - 0.016 * float(k)
		s.box(Vector3(0.0, y, 0.0), Vector3(hw, 0.2, hw), 0.01, STONE, 0.06, 0.93, 0.008)
	s.ellipsoid(Vector3(0.0, 2.62, 0.0), Vector3(0.1, 0.17, 0.1), STONE, 0.03, 0.93)
	s.carve_box(Vector3(0.0, 0.5, -0.28), Vector3(0.17, 0.12, 0.012), STONE_DARK, 0.004)
	s.carve_ellipsoid(Vector3(0.4, 0.3, -0.38), Vector3(0.16, 0.14, 0.16), STONE_DARK, 0.02)
	s.paint_ellipsoid(Vector3(0.0, 0.2, 0.0), Vector3(0.45, 0.25, 0.45), MOSS, 1.0)
	s.paint_box(Vector3(0.1, 1.6, -0.15), Vector3(0.04, 0.9, 0.04), BARK_DARK, 1.0)  # a black streak down one face
	return s.mesh("manor_obelisk", 0.03, 1200)


## A ledger grave: a low stone box with its lid shoved askew, a dark gap at one end.
static func _ledger() -> ArrayMesh:
	var s := Sculpt.new().noise_scale(7.0)
	s.box(Vector3(0.0, 0.13, 0.0), Vector3(0.48, 0.13, 1.0), 0.02, STONE_DARK, 0.03, 0.95, 0.015)
	s.carve_box(Vector3(0.0, 0.2, -0.85), Vector3(0.36, 0.12, 0.2), VOID, 0.01)
	s.box(Vector3(0.05, 0.33, 0.12), Vector3(0.52, 0.06, 0.98), 0.02, STONE, 0.02, 0.93, 0.012, Basis.from_euler(Vector3(0.0, 0.08, 0.02)))
	s.carve_box(Vector3(0.35, 0.33, 0.6), Vector3(0.3, 0.1, 0.25), STONE_DARK, 0.02)
	s.paint_box(Vector3(0.0, 0.4, 0.2), Vector3(0.45, 0.01, 0.012), BARK_DARK, 1.0, Basis.from_euler(Vector3(0.0, 0.7, 0.0)))
	s.paint_ellipsoid(Vector3(-0.2, 0.36, -0.3), Vector3(0.35, 0.06, 0.6), MOSS, 1.0)
	return s.mesh("manor_ledger", 0.03, 1000)


## A dead tree: a flared, knotted trunk that leans and twists, a hollow, and bare crooked limbs
## splitting into twigs like fingers.
static func _tree() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4401
	var s := Sculpt.new().noise_scale(3.5)
	for k in 5:
		var a := TAU * float(k) / 5.0 + rng.randf_range(-0.3, 0.3)
		s.ellipsoid(Vector3(cos(a) * 0.42, 0.12, sin(a) * 0.42), Vector3(0.4, 0.16, 0.17), BARK, 0.14, 0.95, 0.05, Basis.from_euler(Vector3(0.0, -a, 0.0)))
	s.capsule(Vector3(0.0, 0.0, 0.0), Vector3(0.16, 2.3, 0.05), 0.44, 0.3, BARK, 0.1, 0.95, 0.06)
	s.capsule(Vector3(0.16, 2.3, 0.05), Vector3(-0.12, 3.7, 0.16), 0.3, 0.2, BARK, 0.08, 0.95, 0.05)
	s.carve_ellipsoid(Vector3(0.0, 1.25, -0.36), Vector3(0.13, 0.26, 0.16), BARK_DARK, 0.03)
	s.paint_ellipsoid(Vector3(0.0, 0.2, 0.0), Vector3(0.7, 0.3, 0.7), MOSS, 1.0)
	var top := Vector3(-0.12, 3.7, 0.16)
	for k in 6:
		var a := TAU * float(k) / 6.0 + rng.randf_range(-0.4, 0.4)
		var out := Vector3(cos(a), 0.0, sin(a))
		var start := Vector3(0.1, 2.0, 0.03).lerp(top, float(k) / 5.0)
		var pts := PackedVector3Array([start])
		var p := start
		var reach := rng.randf_range(1.5, 2.2)
		for j in 4:
			p += out * reach * 0.28 + Vector3(rng.randf_range(-0.25, 0.25), rng.randf_range(0.18, 0.5), rng.randf_range(-0.25, 0.25))
			pts.append(p)
		s.tube_add(pts, PackedFloat32Array([0.16, 0.11, 0.075, 0.045, 0.018]), BARK, 0.9, 6)
		for j in 2:
			var from := pts[2 + j]
			var tw := PackedVector3Array([from])
			var q := from
			for i in 3:
				q += (out + Vector3(rng.randf_range(-0.8, 0.8), rng.randf_range(0.2, 0.9), rng.randf_range(-0.8, 0.8))).normalized() * rng.randf_range(0.25, 0.45)
				tw.append(q)
			s.tube_add(tw, PackedFloat32Array([0.04, 0.026, 0.014, 0.005]), BARK_DARK, 0.9, 4)
	return s.mesh("manor_tree", 0.05, 2500)


## A hooded mourner in stone, head bowed into its hands, black streaks run from under the hood.
static func _mourner() -> ArrayMesh:
	var s := Sculpt.new().noise_scale(8.0)
	s.box(Vector3(0.0, 0.2, 0.0), Vector3(0.42, 0.2, 0.42), 0.02, STONE_DARK, 0.03, 0.95, 0.012)
	s.ellipsoid(Vector3(0.0, 0.62, 0.0), Vector3(0.36, 0.26, 0.34), STONE, 0.1, 0.92, 0.01)
	s.capsule(Vector3(0.0, 0.5, 0.0), Vector3(0.0, 1.6, 0.03), 0.31, 0.19, STONE, 0.08, 0.92, 0.01)
	s.ellipsoid(Vector3(0.0, 1.8, -0.06), Vector3(0.17, 0.2, 0.18), STONE, 0.06, 0.92, 0.008)
	s.capsule(Vector3(0.0, 1.95, 0.05), Vector3(0.0, 1.55, 0.14), 0.15, 0.24, STONE, 0.06, 0.92, 0.008)  # the hood falling down the back
	s.carve_ellipsoid(Vector3(0.0, 1.75, -0.22), Vector3(0.11, 0.13, 0.08), VOID, 0.02)
	for x: float in [-1.0, 1.0]:
		s.capsule(Vector3(x * 0.2, 1.52, 0.0), Vector3(x * 0.08, 1.66, -0.19), 0.07, 0.055, STONE, 0.05, 0.92)
		s.ellipsoid(Vector3(x * 0.05, 1.74, -0.22), Vector3(0.05, 0.075, 0.035), STONE, 0.03, 0.92)
		s.paint_capsule(Vector3(x * 0.04, 1.7, -0.24), Vector3(x * 0.06, 1.15, -0.28), 0.02, 0.012, BARK_DARK, 1.0)
	s.paint_ellipsoid(Vector3(0.0, 0.5, 0.0), Vector3(0.42, 0.3, 0.42), MOSS, 1.0)
	s.paint_ellipsoid(Vector3(0.12, 1.9, 0.0), Vector3(0.12, 0.08, 0.15), LICHEN, 1.0)
	return s.mesh("manor_mourner", 0.025, 2200)


## A coffin dug up and left open, its lid slid half off, brass handles green with age.
static func _coffin() -> ArrayMesh:
	var s := Sculpt.new().noise_scale(10.0)
	s.box(Vector3(0.0, 0.2, 0.0), Vector3(0.32, 0.2, 0.98), 0.03, WOOD_ROT, 0.02, 0.85, 0.008)
	s.carve_box(Vector3(0.0, 0.34, 0.0), Vector3(0.27, 0.2, 0.92), VOID, 0.01)
	s.box(Vector3(0.36, 0.42, 0.18), Vector3(0.33, 0.03, 0.97), 0.02, WOOD, 0.01, 0.8, 0.005, Basis.from_euler(Vector3(0.05, 0.12, -0.45)))
	for z: float in [-0.5, 0.0, 0.5]:
		for x: float in [-1.0, 1.0]:
			s.capsule(Vector3(x * 0.33, 0.22, z - 0.08), Vector3(x * 0.33, 0.22, z + 0.08), 0.015, 0.015, BRASS, 0.005, 0.5)
	s.ellipsoid(Vector3(0.0, 0.0, 0.0), Vector3(0.55, 0.08, 1.15), EARTH, 0.1, 0.98, 0.03)
	return s.mesh("manor_coffin", 0.025, 1200)


## A fresh grave: a heaped mound of wet earth with the spade still standing in it.
static func _mound() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4402
	var s := Sculpt.new().noise_scale(5.0)
	s.ellipsoid(Vector3(0.0, 0.0, 0.0), Vector3(0.72, 0.36, 1.12), EARTH, 0.1, 0.98, 0.06)
	for k in 8:
		s.ellipsoid(Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(0.05, 0.25), rng.randf_range(-1.0, 1.0)), Vector3.ONE * rng.randf_range(0.06, 0.12), EARTH.darkened(0.3), 0.04, 0.98, 0.02)
	s.tube_add(PackedVector3Array([Vector3(0.2, 0.15, 0.3), Vector3(0.24, 0.8, 0.38), Vector3(0.28, 1.42, 0.46)]), PackedFloat32Array([0.025, 0.025, 0.024]), WOOD, 0.8, 6)
	s.box(Vector3(0.2, 0.18, 0.29), Vector3(0.13, 0.17, 0.012), 0.01, RUST, 0.01, 0.6, 0.0, Basis.from_euler(Vector3(-0.12, 0.0, 0.05)))
	return s.mesh("manor_mound", 0.035, 1200)


## One of the estate's old pump engines on its skids: a cylinder block in flaking red paint with
## cooling fins, the head, a fuel tank, an exhaust stack, a big flywheel, a brass gauge, and its
## cables trailing off into the dirt.
static func _engine() -> ArrayMesh:
	var s := Sculpt.new().noise_scale(12.0)
	for z: float in [-0.42, 0.42]:
		s.box(Vector3(0.0, 0.05, z), Vector3(0.85, 0.05, 0.06), 0.01, WOOD_ROT, 0.01, 0.9, 0.006)
	s.box(Vector3(0.0, 0.14, 0.0), Vector3(0.76, 0.04, 0.48), 0.01, IRON, 0.01, 0.7, 0.004)
	s.box(Vector3(-0.15, 0.55, 0.0), Vector3(0.32, 0.36, 0.3), 0.04, PAINT_RED, 0.02, 0.7, 0.008)
	for k in 6:
		s.box(Vector3(-0.15, 0.6 + 0.08 * float(k), 0.0), Vector3(0.36, 0.012, 0.34), 0.004, IRON, 0.006, 0.7)
	s.box(Vector3(-0.15, 1.0, 0.0), Vector3(0.27, 0.07, 0.25), 0.02, IRON, 0.02, 0.65, 0.004)
	s.capsule(Vector3(-0.42, 1.18, 0.0), Vector3(0.1, 1.18, 0.0), 0.14, 0.14, RUST, 0.02, 0.7, 0.006)
	for k in 5:
		s.paint_ellipsoid(Vector3(-0.15 + 0.12 * float(k - 2), 0.4 + 0.11 * float(k % 3), 0.31 * (1.0 if k % 2 == 0 else -1.0)), Vector3(0.09, 0.07, 0.04), RUST, 0.9)
	s.ellipsoid(Vector3(-0.15, 0.7, -0.33), Vector3(0.06, 0.06, 0.025), BRASS, 0.01, 0.4)
	s.tube_add(PackedVector3Array([Vector3(-0.38, 0.95, 0.22), Vector3(-0.42, 1.15, 0.24), Vector3(-0.45, 1.38, 0.26)]), PackedFloat32Array([0.045, 0.042, 0.05]), RUST, 0.7, 6)
	_wheel(s, Vector3(0.5, 0.58, 0.0), Vector3.RIGHT, 0.42, 0.045, 5, IRON)
	s.capsule(Vector3(0.17, 0.58, 0.0), Vector3(0.5, 0.58, 0.0), 0.04, 0.04, IRON, 0.01, 0.5)
	s.tube_add(PackedVector3Array([Vector3(-0.4, 0.3, -0.3), Vector3(-0.7, 0.12, -0.45), Vector3(-0.85, 0.02, -0.5)]), PackedFloat32Array([0.02, 0.02, 0.02]), IRON, 0.8, 5)
	s.tube_add(PackedVector3Array([Vector3(-0.3, 0.4, 0.32), Vector3(-0.55, 0.1, 0.5), Vector3(-0.8, 0.02, 0.48)]), PackedFloat32Array([0.016, 0.016, 0.016]), BARK_DARK, 0.8, 5)
	return s.mesh("manor_engine", 0.025, 2600)


## The main generator in the courtyard: a big dynamo drum on a concrete pad, a flywheel taller
## than a man, a control board with gauges and a knife switch, and conduit running into the ground.
static func _generator() -> ArrayMesh:
	var s := Sculpt.new().noise_scale(8.0)
	s.box(Vector3(0.0, 0.1, 0.0), Vector3(1.55, 0.1, 0.88), 0.02, STONE_DARK, 0.02, 0.95, 0.012)
	s.capsule(Vector3(-0.95, 0.9, 0.0), Vector3(0.55, 0.9, 0.0), 0.55, 0.55, IRON, 0.03, 0.65, 0.006)
	for k in 5:
		s.paint_capsule(Vector3(-0.85 + 0.35 * float(k), 0.9, 0.0), Vector3(-0.8 + 0.35 * float(k), 0.9, 0.0), 0.57, 0.57, RUST, 0.85)
	for x: float in [-0.7, 0.3]:
		s.box(Vector3(x, 0.32, 0.0), Vector3(0.12, 0.14, 0.6), 0.02, IRON, 0.02, 0.7)
	s.paint_box(Vector3(-0.2, 1.42, -0.25), Vector3(0.5, 0.04, 0.03), Color(0.5, 0.42, 0.1), 0.8)  # a faded warning stripe
	_wheel(s, Vector3(1.05, 1.08, 0.0), Vector3.RIGHT, 0.82, 0.07, 6, IRON)
	s.capsule(Vector3(0.55, 0.9, 0.0), Vector3(1.05, 1.08, 0.0), 0.08, 0.08, IRON, 0.02, 0.5)
	s.box(Vector3(-1.25, 1.15, 0.55), Vector3(0.22, 0.45, 0.06), 0.02, WOOD_ROT, 0.01, 0.85)
	for k in 3:
		s.ellipsoid(Vector3(-1.25, 1.4 - 0.22 * float(k), 0.6), Vector3(0.06, 0.06, 0.025), BRASS, 0.01, 0.4)
	s.tube_add(PackedVector3Array([Vector3(-1.32, 1.05, 0.63), Vector3(-1.32, 1.25, 0.72), Vector3(-1.32, 1.42, 0.7)]), PackedFloat32Array([0.022, 0.02, 0.02]), IRON, 0.5, 5)
	s.ellipsoid(Vector3(-1.32, 1.44, 0.7), Vector3(0.035, 0.035, 0.035), Color(0.08, 0.06, 0.05), 0.01, 0.6)
	for k in 3:
		var z := -0.5 + 0.25 * float(k)
		s.tube_add(PackedVector3Array([Vector3(-1.0, 0.7, z), Vector3(-1.35, 0.4, z * 1.4), Vector3(-1.5, 0.05, z * 1.7)]), PackedFloat32Array([0.05, 0.05, 0.05]), RUST, 0.7, 6)
	return s.mesh("manor_generator", 0.03, 3500)


## An iron lamp post: a fluted foot, a thin post with collars, a lantern cage and its cap. The
## glass is a separate glowing piece (Manor), so it can go dark.
static func _lamp() -> ArrayMesh:
	var s := Sculpt.new().noise_scale(14.0)
	s.box(Vector3(0.0, 0.15, 0.0), Vector3(0.17, 0.15, 0.17), 0.04, IRON, 0.03, 0.55, 0.004)
	s.capsule(Vector3(0.0, 0.3, 0.0), Vector3(0.0, 2.82, 0.0), 0.06, 0.045, IRON, 0.03, 0.55, 0.002)
	for y: float in [0.45, 1.6, 2.75]:
		s.ellipsoid(Vector3(0.0, y, 0.0), Vector3(0.08, 0.035, 0.08), IRON, 0.02, 0.55)
	for k in 4:
		var a := TAU * float(k) / 4.0 + PI * 0.25
		var c := Vector3(cos(a) * 0.13, 0.0, sin(a) * 0.13)
		s.tube_add(PackedVector3Array([c + Vector3(0.0, 2.82, 0.0), c * 1.15 + Vector3(0.0, 3.0, 0.0), c + Vector3(0.0, 3.18, 0.0)]), PackedFloat32Array([0.012, 0.012, 0.012]), IRON, 0.55, 4)
	s.ellipsoid(Vector3(0.0, 3.23, 0.0), Vector3(0.19, 0.07, 0.19), IRON, 0.02, 0.55)
	s.ellipsoid(Vector3(0.0, 3.3, 0.0), Vector3(0.04, 0.05, 0.04), IRON, 0.02, 0.55)
	s.paint_ellipsoid(Vector3(0.0, 1.0, 0.0), Vector3(0.1, 0.5, 0.1), RUST, 0.8)
	return s.mesh("manor_lamp", 0.02, 1500)


## A two-metre run of iron railings: two rails, spear-tipped bars (two of them bent), end posts.
static func _fence() -> ArrayMesh:
	var s := Sculpt.new().noise_scale(14.0)
	for y: float in [0.25, 1.22]:
		s.tube_add(PackedVector3Array([Vector3(-1.0, y, 0.0), Vector3(1.0, y, 0.0)]), PackedFloat32Array([0.018, 0.018]), IRON, 0.6, 5)
	for k in 9:
		var x := -0.88 + 0.22 * float(k)
		var bend := Vector3(0.0, 0.0, 0.12 if k == 3 else (-0.08 if k == 6 else 0.0))
		s.tube_add(PackedVector3Array([Vector3(x, 0.0, 0.0), Vector3(x, 0.7, 0.0) + bend, Vector3(x, 1.36, 0.0) + bend * 0.4]), PackedFloat32Array([0.014, 0.014, 0.014]), RUST if k % 4 == 1 else IRON, 0.6, 4)
		s.ellipsoid(Vector3(x, 1.41, 0.0) + bend * 0.4, Vector3(0.024, 0.07, 0.024), IRON, 0.005, 0.6)
	for x: float in [-1.0, 1.0]:
		s.box(Vector3(x * 0.98, 0.72, 0.0), Vector3(0.04, 0.72, 0.04), 0.01, IRON, 0.01, 0.6)
		s.ellipsoid(Vector3(x * 0.98, 1.48, 0.0), Vector3(0.05, 0.05, 0.05), IRON, 0.01, 0.6)
	return s.mesh("manor_fence", 0.02, 1800)


## A farm cart that lost a wheel and came down on its axle, the wheel lying flat in the mud.
static func _cart() -> ArrayMesh:
	var s := Sculpt.new().noise_scale(9.0)
	var tilt := Basis.from_euler(Vector3(0.0, 0.0, -0.22))
	s.box(Vector3(0.05, 0.62, 0.0), Vector3(0.72, 0.05, 1.2), 0.01, WOOD, 0.01, 0.85, 0.006, tilt)
	for x: float in [-1.0, 1.0]:
		s.box(Vector3(x * 0.68 + 0.05, 0.85 - x * 0.16, 0.0), Vector3(0.03, 0.22, 1.2), 0.01, WOOD_ROT, 0.01, 0.85, 0.006, tilt)
	s.box(Vector3(0.05, 0.85, 1.18), Vector3(0.7, 0.2, 0.03), 0.01, WOOD_ROT, 0.01, 0.85, 0.006, tilt)
	_wheel(s, Vector3(0.82, 0.5, 0.15), Vector3.RIGHT, 0.48, 0.04, 8, WOOD)
	_wheel(s, Vector3(-0.55, 0.05, -1.05), Vector3.UP, 0.48, 0.04, 8, WOOD_ROT)
	for x: float in [-0.35, 0.45]:
		s.tube_add(PackedVector3Array([Vector3(x, 0.55, -1.2), Vector3(x, 0.3, -1.6), Vector3(x + 0.05, 0.02, -1.95)]), PackedFloat32Array([0.035, 0.035, 0.03]), WOOD, 0.85, 5)
	return s.mesh("manor_cart", 0.035, 2200)


## A chapel pew, the seat split and one end broken.
static func _pew() -> ArrayMesh:
	var s := Sculpt.new().noise_scale(10.0)
	s.box(Vector3(0.0, 0.45, 0.0), Vector3(0.95, 0.035, 0.2), 0.01, WOOD, 0.01, 0.8, 0.004)
	s.box(Vector3(0.0, 0.74, 0.18), Vector3(0.95, 0.24, 0.025), 0.01, WOOD, 0.01, 0.8, 0.004)
	for x: float in [-1.0, 1.0]:
		s.box(Vector3(x * 0.93, 0.45, 0.04), Vector3(0.035, 0.45, 0.25), 0.01, WOOD_ROT, 0.01, 0.85, 0.005)
	s.carve_ellipsoid(Vector3(0.95, 0.85, 0.1), Vector3(0.15, 0.25, 0.35), WOOD_ROT, 0.02)
	s.paint_box(Vector3(0.2, 0.485, 0.0), Vector3(0.6, 0.01, 0.006), BARK_DARK, 1.0)
	return s.mesh("manor_pew", 0.025, 1200)


## A stone well, black water a long way down, its little roof caved in on one side.
static func _well() -> ArrayMesh:
	var s := Sculpt.new().noise_scale(7.0)
	s.capsule(Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.75, 0.0), 0.85, 0.85, STONE, 0.04, 0.93, 0.02)
	s.carve_capsule(Vector3(0.0, 0.2, 0.0), Vector3(0.0, 1.2, 0.0), 0.62, 0.62, VOID, 0.02)
	s.paint_ellipsoid(Vector3(0.0, 0.2, 0.0), Vector3(0.9, 0.3, 0.9), MOSS, 1.0)
	for x: float in [-1.0, 1.0]:
		s.tube_add(PackedVector3Array([Vector3(x * 0.78, 0.7, 0.0), Vector3(x * 0.78, 1.5, 0.0), Vector3(x * 0.76, 2.25, 0.0)]), PackedFloat32Array([0.06, 0.055, 0.05]), WOOD, 0.85, 6)
	s.tube_add(PackedVector3Array([Vector3(-0.8, 2.1, 0.0), Vector3(0.8, 2.1, 0.0)]), PackedFloat32Array([0.045, 0.045]), WOOD, 0.85, 6)
	s.tube_add(PackedVector3Array([Vector3(0.1, 2.08, 0.0), Vector3(0.12, 1.4, 0.03), Vector3(0.1, 0.9, 0.0)]), PackedFloat32Array([0.01, 0.01, 0.01]), BARK, 0.9, 4)
	s.box(Vector3(0.0, 2.38, 0.2), Vector3(0.95, 0.03, 0.55), 0.01, WOOD_ROT, 0.01, 0.85, 0.006, Basis.from_euler(Vector3(0.45, 0.0, 0.18)))
	return s.mesh("manor_well", 0.03, 1800)


## A dead thorn bush: a knot of black stems splaying out and up, thorny and bare.
static func _thorns() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4403
	var s := Sculpt.new().noise_scale(6.0)
	s.ellipsoid(Vector3(0.0, 0.05, 0.0), Vector3(0.3, 0.12, 0.3), BARK_DARK, 0.05, 0.95, 0.03)
	for k in 22:
		var a := rng.randf() * TAU
		var out := Vector3(cos(a), rng.randf_range(0.5, 1.4), sin(a)).normalized()
		var p := Vector3(rng.randf_range(-0.1, 0.1), 0.08, rng.randf_range(-0.1, 0.1))
		var pts := PackedVector3Array([p])
		for j in 3:
			p += (out + Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.1, 0.3), rng.randf_range(-0.4, 0.4))).normalized() * rng.randf_range(0.2, 0.36)
			pts.append(p)
		s.tube_add(pts, PackedFloat32Array([0.02, 0.014, 0.008, 0.003]), BARK_DARK if k % 3 != 0 else BARK, 0.9, 4)
	return s.mesh("manor_thorns", 0.03, 1600)


## A clump of tall grass gone to straw: forty-odd blades fanning out of a tussock, bent over at
## the tips, a few still dark green at the root.
static func _grass() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4404
	var s := Sculpt.new().noise_scale(8.0)
	s.ellipsoid(Vector3(0.0, -0.03, 0.0), Vector3(0.24, 0.07, 0.24), Color(0.21, 0.19, 0.13), 0.05, 0.98, 0.02)  # the tussock, mostly sunk
	for k in 44:
		var a := rng.randf() * TAU
		var r0 := rng.randf_range(0.0, 0.22)
		var base := Vector3(cos(a) * r0, 0.02, sin(a) * r0)
		var out := Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(0.15, 0.55)
		var h := rng.randf_range(0.7, 1.45)
		var bend := Vector3(rng.randf_range(-0.2, 0.2), 0.0, rng.randf_range(-0.2, 0.2))
		var col := STRAW if k % 3 != 0 else (GRASS_DEAD if k % 2 == 0 else GRASS_DARK)
		s.tube_add(PackedVector3Array([base, base + out * 0.35 + Vector3(0.0, h * 0.55, 0.0), base + out + bend + Vector3(0.0, h * 0.92, 0.0), base + out * 1.4 + bend * 2.0 + Vector3(0.0, h * 0.8, 0.0)]), PackedFloat32Array([0.012, 0.009, 0.005, 0.0015]), col, 0.9, 3)
	return s.mesh("manor_grass", 0.03, 1200)


## A dead tree with one long, thick limb reaching out flat along +x at the height of a hanging:
## the rope goes over it at HANG_POINT. A few crooked limbs elsewhere so it isn't a gibbet.
static func _hang_tree() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4405
	var s := Sculpt.new().noise_scale(3.5)
	for k in 5:
		var a := TAU * float(k) / 5.0 + rng.randf_range(-0.3, 0.3)
		s.ellipsoid(Vector3(cos(a) * 0.42, 0.12, sin(a) * 0.42), Vector3(0.4, 0.16, 0.17), BARK, 0.14, 0.95, 0.05, Basis.from_euler(Vector3(0.0, -a, 0.0)))
	s.capsule(Vector3(0.0, 0.0, 0.0), Vector3(-0.1, 2.6, 0.04), 0.46, 0.32, BARK, 0.1, 0.95, 0.06)
	s.capsule(Vector3(-0.1, 2.6, 0.04), Vector3(-0.25, 4.6, 0.1), 0.32, 0.2, BARK, 0.08, 0.95, 0.05)
	s.carve_ellipsoid(Vector3(-0.05, 1.3, -0.38), Vector3(0.12, 0.24, 0.15), BARK_DARK, 0.03)
	s.paint_ellipsoid(Vector3(0.0, 0.2, 0.0), Vector3(0.7, 0.3, 0.7), MOSS, 1.0)
	# The limb: thick at the trunk, out flat, the bark rubbed pale where the rope went over.
	s.tube_add(PackedVector3Array([Vector3(-0.05, 2.9, 0.03), Vector3(0.7, 3.32, 0.06), Vector3(1.4, 3.42, 0.1), Vector3(2.15, 3.48, 0.12), Vector3(2.6, 3.7, 0.15)]), PackedFloat32Array([0.2, 0.15, 0.11, 0.08, 0.035]), BARK, 0.9, 7)
	s.ellipsoid(Vector3(1.75, 3.45, 0.11), Vector3(0.1, 0.11, 0.11), ROPE, 0.01, 0.9)  # the rope's turns round it
	for k in 4:
		var a := PI * 0.5 + TAU * float(k) / 4.0 + rng.randf_range(-0.3, 0.3)
		var out := Vector3(cos(a), 0.0, sin(a))
		var start := Vector3(-0.15, 3.4 + 0.3 * float(k), 0.07)
		var pts := PackedVector3Array([start])
		var q := start
		for j in 3:
			q += out * 0.45 + Vector3(rng.randf_range(-0.2, 0.2), rng.randf_range(0.25, 0.5), rng.randf_range(-0.2, 0.2))
			pts.append(q)
		s.tube_add(pts, PackedFloat32Array([0.12, 0.07, 0.04, 0.012]), BARK, 0.9, 5)
	return s.mesh("manor_hang_tree", 0.05, 2200)


## A gallows of grey timber: two posts with braces, a beam across, the bark long gone.
static func _gallows() -> ArrayMesh:
	var s := Sculpt.new().noise_scale(10.0)
	for x: float in [-1.5, 1.5]:
		s.box(Vector3(x, 1.85, 0.0), Vector3(0.1, 1.85, 0.1), 0.02, WOOD_ROT, 0.01, 0.9, 0.008)
		s.box(Vector3(x, 0.1, 0.0), Vector3(0.18, 0.1, 0.25), 0.02, WOOD_ROT, 0.01, 0.9, 0.008)
		s.tube_add(PackedVector3Array([Vector3(x, 3.0, 0.0), Vector3(x * 0.72, 3.62, 0.0)]), PackedFloat32Array([0.05, 0.05]), WOOD_ROT, 0.9, 5)
		for z: float in [-1.0, 1.0]:
			s.tube_add(PackedVector3Array([Vector3(x, 1.2, 0.0), Vector3(x, 0.0, z * 0.5)]), PackedFloat32Array([0.045, 0.05]), WOOD_ROT, 0.9, 5)
	s.box(Vector3(0.0, 3.72, 0.0), Vector3(1.7, 0.09, 0.1), 0.02, WOOD_ROT, 0.01, 0.9, 0.008)
	for pt: Vector3 in GALLOWS_POINTS:
		s.ellipsoid(pt + Vector3(0.0, 0.1, 0.0), Vector3(0.08, 0.12, 0.13), ROPE, 0.01, 0.9)
	return s.mesh("manor_gallows", 0.03, 1600)


## Someone hanged and left: a rope from the top (the origin) down to the noose, the head fallen
## forward and to one side, the body bound in a filthy burial shroud with cords round it, bare grey
## feet hanging out of the bottom, a dark stain soaked through.
static func _hanged() -> ArrayMesh:
	var s := Sculpt.new().noise_scale(14.0)
	s.tube_add(PackedVector3Array([Vector3(0.0, 0.0, 0.0), Vector3(0.005, -0.45, 0.0), Vector3(0.01, -0.92, 0.01)]), PackedFloat32Array([0.016, 0.016, 0.016]), ROPE, 0.9, 5)
	s.ellipsoid(Vector3(0.02, -0.97, 0.06), Vector3(0.05, 0.05, 0.05), ROPE, 0.01, 0.9)  # the knot
	s.capsule(Vector3(0.0, -0.95, 0.02), Vector3(0.02, -1.02, 0.0), 0.042, 0.04, DEAD_SKIN, 0.02, 0.6)  # the neck, stretched
	s.ellipsoid(Vector3(0.05, -1.07, -0.05), Vector3(0.1, 0.12, 0.11), SHROUD, 0.03, 0.85, 0.006, Basis.from_euler(Vector3(0.5, 0.0, 0.35)))  # the head, wrapped, fallen forward
	s.capsule(Vector3(0.0, -1.16, 0.0), Vector3(0.0, -1.5, 0.01), 0.15, 0.17, SHROUD, 0.06, 0.85, 0.01)
	s.capsule(Vector3(0.0, -1.5, 0.01), Vector3(0.0, -2.02, 0.0), 0.17, 0.12, SHROUD, 0.06, 0.85, 0.01)
	for k in 5:
		s.carve_ellipsoid(Vector3(cos(float(k) * 1.3) * 0.13, -2.06, sin(float(k) * 1.3) * 0.11), Vector3(0.06, 0.08, 0.06), SHROUD_DIRT, 0.02)  # a ragged hem
	for y: float in [-1.32, -1.62, -1.9]:
		var ring := PackedVector3Array()
		var rr := PackedFloat32Array()
		var r := 0.165 if y > -1.7 else 0.145
		for k in 13:
			var a := TAU * float(k) / 12.0
			ring.append(Vector3(cos(a) * r, y + 0.02 * sin(a * 2.0), sin(a) * r + 0.005))
			rr.append(0.012)
		s.tube_add(ring, rr, ROPE, 0.9, 4)
	s.paint_capsule(Vector3(0.0, -1.7, 0.0), Vector3(0.0, -2.05, 0.0), 0.2, 0.15, SHROUD_DIRT, 0.95)  # filth up from the hem
	s.paint_ellipsoid(Vector3(0.04, -1.42, -0.15), Vector3(0.09, 0.14, 0.05), OLD_BLOOD, 0.6)
	s.paint_ellipsoid(Vector3(0.03, -1.0, -0.1), Vector3(0.06, 0.05, 0.04), OLD_BLOOD, 0.6)
	for x: float in [-1.0, 1.0]:
		s.capsule(Vector3(x * 0.05, -2.0, 0.0), Vector3(x * 0.06, -2.28, -0.02), 0.034, 0.03, DEAD_SKIN, 0.02, 0.6)
		s.ellipsoid(Vector3(x * 0.06, -2.33, -0.05), Vector3(0.035, 0.03, 0.06), DEAD_SKIN, 0.02, 0.6, 0.0, Basis.from_euler(Vector3(0.9, 0.0, 0.0)))  # toes down
		s.paint_ellipsoid(Vector3(x * 0.06, -2.37, -0.09), Vector3(0.03, 0.02, 0.02), Color(0.04, 0.03, 0.03), 0.4)
	return s.mesh("manor_hanged", 0.016, 3000)


# --- Set dressing (the estate's clutter and the rooms' furniture) -------------------------------

## A stone garden urn on a square pedestal, the stalks of something long dead still in it.
static func _urn() -> ArrayMesh:
	var s := Sculpt.new().noise_scale(8.0)
	s.box(Vector3(0.0, 0.3, 0.0), Vector3(0.26, 0.3, 0.26), 0.02, STONE_DARK, 0.02, 0.95, 0.01)
	s.box(Vector3(0.0, 0.63, 0.0), Vector3(0.31, 0.04, 0.31), 0.015, STONE, 0.01, 0.93, 0.006)
	s.capsule(Vector3(0.0, 0.66, 0.0), Vector3(0.0, 0.82, 0.0), 0.1, 0.13, STONE, 0.03, 0.92)
	s.ellipsoid(Vector3(0.0, 1.02, 0.0), Vector3(0.36, 0.24, 0.36), STONE, 0.06, 0.92, 0.008)
	s.capsule(Vector3(0.0, 1.18, 0.0), Vector3(0.0, 1.24, 0.0), 0.38, 0.39, STONE, 0.03, 0.92)
	s.carve_ellipsoid(Vector3(0.0, 1.24, 0.0), Vector3(0.32, 0.2, 0.32), EARTH, 0.02)
	s.carve_ellipsoid(Vector3(0.36, 1.25, 0.1), Vector3(0.1, 0.08, 0.12), STONE_DARK, 0.01)  # a chip off the rim
	s.ellipsoid(Vector3(0.0, 1.1, 0.0), Vector3(0.31, 0.07, 0.31), EARTH, 0.02, 0.98)
	for k in 5:
		var a := float(k) * 1.26
		var tip := Vector3(cos(a) * 0.3, 1.55 + 0.1 * float(k % 2), sin(a) * 0.3)
		s.tube_add(PackedVector3Array([Vector3(cos(a) * 0.05, 1.12, sin(a) * 0.05), Vector3(cos(a) * 0.15, 1.35, sin(a) * 0.15), tip]), PackedFloat32Array([0.012, 0.008, 0.004]), BARK_DARK, 0.9, 4)
	s.paint_box(Vector3(0.0, 0.08, 0.0), Vector3(0.3, 0.12, 0.3), MOSS, 1.0)
	s.paint_ellipsoid(Vector3(-0.2, 1.22, -0.2), Vector3(0.2, 0.08, 0.2), LICHEN, 1.0)
	return s.mesh("manor_urn", 0.025, 1800)


## A stone garden bench: a slab on two scrolled legs, cracked across, green with moss.
static func _bench() -> ArrayMesh:
	var s := Sculpt.new().noise_scale(9.0)
	for x: float in [-1.0, 1.0]:
		s.box(Vector3(x * 0.68, 0.19, 0.0), Vector3(0.09, 0.19, 0.19), 0.03, STONE_DARK, 0.02, 0.95, 0.008)
		s.ellipsoid(Vector3(x * 0.68, 0.36, 0.0), Vector3(0.12, 0.07, 0.21), STONE_DARK, 0.03, 0.95)
	s.box(Vector3(0.0, 0.44, 0.0), Vector3(0.88, 0.05, 0.23), 0.02, STONE, 0.02, 0.93, 0.006)
	s.carve_box(Vector3(0.18, 0.47, 0.0), Vector3(0.012, 0.06, 0.25), VOID, 0.0, Basis.from_euler(Vector3(0.0, 0.3, 0.0)))
	s.paint_ellipsoid(Vector3(-0.4, 0.5, 0.05), Vector3(0.35, 0.06, 0.2), MOSS, 1.0)
	s.paint_box(Vector3(0.0, 0.05, 0.0), Vector3(0.9, 0.08, 0.3), MOSS, 1.0)
	return s.mesh("manor_bench", 0.022, 1000)


## A cask: bellied staves, three iron hoops, the head stained dark.
static func _barrel() -> ArrayMesh:
	var s := Sculpt.new().noise_scale(12.0)
	s.ellipsoid(Vector3(0.0, 0.47, 0.0), Vector3(0.33, 0.52, 0.33), WOOD, 0.0, 0.85, 0.004)
	s.carve_box(Vector3(0.0, 1.05, 0.0), Vector3(0.5, 0.1, 0.5), WOOD, 0.0)
	s.carve_box(Vector3(0.0, -0.1, 0.0), Vector3(0.5, 0.1, 0.5), WOOD, 0.0)
	for y: float in [0.12, 0.47, 0.82]:
		s.paint_box(Vector3(0.0, y, 0.0), Vector3(0.4, 0.03, 0.4), IRON, 0.55)
	for k in 10:
		var a := float(k) * TAU / 10.0
		s.paint_box(Vector3(cos(a) * 0.3, 0.47, sin(a) * 0.3), Vector3(0.008, 0.5, 0.008), WOOD_ROT, 0.9)
	s.paint_box(Vector3(0.0, 0.94, 0.0), Vector3(0.4, 0.02, 0.4), WOOD_ROT, 0.9)
	return s.mesh("manor_barrel", 0.02, 1100)


## A packing crate of rough boards, one board of the lid gone.
static func _crate() -> ArrayMesh:
	var s := Sculpt.new().noise_scale(12.0)
	s.box(Vector3(0.0, 0.35, 0.0), Vector3(0.45, 0.35, 0.35), 0.01, WOOD, 0.0, 0.85, 0.003)
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			s.box(Vector3(x * 0.44, 0.35, z * 0.34), Vector3(0.035, 0.35, 0.035), 0.005, WOOD_ROT, 0.0, 0.85, 0.003)
	for y: float in [0.23, 0.47]:
		s.paint_box(Vector3(0.0, y, 0.0), Vector3(0.5, 0.006, 0.4), BARK_DARK, 1.0)
	s.carve_box(Vector3(0.12, 0.7, 0.0), Vector3(0.1, 0.04, 0.33), VOID, 0.0)
	return s.mesh("manor_crate", 0.02, 900)


## A stack of split firewood, end grain pale against the bark.
static func _logs() -> ArrayMesh:
	var s := Sculpt.new().noise_scale(10.0)
	for row in 3:
		for k in 4 - row:
			var x := -0.36 + (float(k) + float(row) * 0.5) * 0.24
			var y := 0.12 + float(row) * 0.2
			var r := 0.11 + 0.015 * float((k + row) % 2)
			s.capsule(Vector3(x, y, -0.4), Vector3(x + 0.02, y, 0.4), r, r * 0.95, BARK, 0.0, 0.92, 0.006)
	s.paint_box(Vector3(0.0, 0.3, 0.44), Vector3(0.6, 0.4, 0.06), WOOD, 0.9)
	s.paint_box(Vector3(0.0, 0.3, -0.44), Vector3(0.6, 0.4, 0.06), WOOD, 0.9)
	return s.mesh("manor_logs", 0.022, 1400)


## A dead branch come down in a storm, its twigs still reaching up.
static func _branch() -> ArrayMesh:
	var s := Sculpt.new().noise_scale(6.0)
	s.ellipsoid(Vector3(-1.45, 0.12, 0.0), Vector3(0.14, 0.13, 0.14), BARK, 0.02, 0.95, 0.01)  # the torn end
	s.tube_add(PackedVector3Array([Vector3(-1.5, 0.12, 0.0), Vector3(-0.5, 0.17, 0.1), Vector3(0.6, 0.12, -0.05), Vector3(1.5, 0.08, 0.2)]), PackedFloat32Array([0.12, 0.09, 0.06, 0.03]), BARK, 0.95, 7)
	for twig: Array in [[Vector3(-0.6, 0.17, 0.08), Vector3(-0.35, 0.45, 0.55), Vector3(-0.15, 0.52, 0.78)], [Vector3(0.2, 0.15, 0.0), Vector3(0.45, 0.4, -0.45), Vector3(0.62, 0.45, -0.72)],
			[Vector3(0.9, 0.11, 0.05), Vector3(1.15, 0.3, 0.45), Vector3(1.3, 0.34, 0.62)], [Vector3(-1.0, 0.15, 0.05), Vector3(-0.95, 0.42, -0.4), Vector3(-0.8, 0.5, -0.6)]]:
		s.tube_add(PackedVector3Array(twig), PackedFloat32Array([0.04, 0.022, 0.01]), BARK_DARK, 0.95, 5)
	return s.mesh("manor_branch", 0.03, 1200)


## A wheelbarrow tipped forward on its iron wheel, its tray rotted through in one corner.
static func _wheelbarrow() -> ArrayMesh:
	var s := Sculpt.new().noise_scale(10.0)
	var tip := Basis.from_euler(Vector3(-0.18, 0.0, 0.0))
	s.box(Vector3(0.0, 0.5, 0.15), Vector3(0.32, 0.17, 0.42), 0.03, WOOD_ROT, 0.01, 0.88, 0.006, tip)
	s.carve_box(Vector3(0.0, 0.6, 0.15), Vector3(0.28, 0.17, 0.38), VOID, 0.0, tip)
	s.carve_ellipsoid(Vector3(0.25, 0.45, 0.4), Vector3(0.1, 0.1, 0.12), VOID, 0.01)
	_wheel(s, Vector3(0.0, 0.22, 0.62), Vector3.RIGHT, 0.22, 0.03, 6, IRON)
	for x: float in [-1.0, 1.0]:
		s.tube_add(PackedVector3Array([Vector3(x * 0.22, 0.4, 0.55), Vector3(x * 0.25, 0.45, -0.3), Vector3(x * 0.3, 0.55, -0.95)]), PackedFloat32Array([0.025, 0.025, 0.022]), WOOD, 0.85, 5)
		s.tube_add(PackedVector3Array([Vector3(x * 0.22, 0.42, -0.25), Vector3(x * 0.24, 0.2, -0.28), Vector3(x * 0.25, 0.0, -0.3)]), PackedFloat32Array([0.02, 0.02, 0.02]), IRON, 0.6, 5)
	s.paint_box(Vector3(0.0, 0.4, 0.15), Vector3(0.3, 0.05, 0.4), RUST, 0.9)
	return s.mesh("manor_wheelbarrow", 0.022, 1600)


## A fluted column broken off above a man's height on its plinth, a drum of it at its foot.
static func _column() -> ArrayMesh:
	var s := Sculpt.new().noise_scale(8.0)
	s.box(Vector3(0.0, 0.15, 0.0), Vector3(0.4, 0.15, 0.4), 0.02, STONE_DARK, 0.02, 0.95, 0.01)
	s.capsule(Vector3(0.0, 0.32, 0.0), Vector3(0.0, 0.36, 0.0), 0.32, 0.31, STONE, 0.02, 0.93)
	s.capsule(Vector3(0.0, 0.35, 0.0), Vector3(0.0, 1.9, 0.0), 0.26, 0.24, STONE, 0.02, 0.92, 0.006)
	s.carve_ellipsoid(Vector3(0.12, 2.0, 0.0), Vector3(0.4, 0.22, 0.4), STONE_DARK, 0.03, Basis.from_euler(Vector3(0.0, 0.0, 0.4)))
	for k in 12:
		var a := float(k) * TAU / 12.0
		s.paint_box(Vector3(cos(a) * 0.25, 1.1, sin(a) * 0.25), Vector3(0.012, 0.75, 0.012), STONE_DARK, 1.0)
	s.paint_box(Vector3(0.0, 0.2, 0.0), Vector3(0.45, 0.25, 0.45), MOSS, 1.0)
	s.paint_ellipsoid(Vector3(-0.15, 1.6, 0.15), Vector3(0.15, 0.3, 0.12), LICHEN, 1.0)
	return s.mesh("manor_column", 0.025, 1500)


## A grieving winged figure on a plinth, head bowed over hands folded on a wreath; one wing broken.
static func _angel() -> ArrayMesh:
	var s := Sculpt.new().noise_scale(8.0)
	s.box(Vector3(0.0, 0.22, 0.0), Vector3(0.45, 0.22, 0.42), 0.02, STONE_DARK, 0.03, 0.95, 0.012)
	s.capsule(Vector3(0.0, 0.48, 0.0), Vector3(0.0, 1.65, 0.0), 0.32, 0.2, STONE, 0.08, 0.92, 0.01)
	s.ellipsoid(Vector3(0.0, 1.62, -0.03), Vector3(0.27, 0.16, 0.2), STONE, 0.08, 0.92)
	s.ellipsoid(Vector3(0.0, 1.86, -0.12), Vector3(0.12, 0.15, 0.13), STONE, 0.04, 0.92, 0.006)
	s.capsule(Vector3(0.0, 1.96, -0.06), Vector3(0.0, 1.7, 0.05), 0.12, 0.14, STONE, 0.05, 0.92)  # hair down the back
	for x: float in [-1.0, 1.0]:
		s.capsule(Vector3(x * 0.22, 1.55, 0.0), Vector3(x * 0.07, 1.22, -0.2), 0.06, 0.05, STONE, 0.04, 0.92)
	s.capsule(Vector3(-0.15, 1.18, -0.24), Vector3(0.15, 1.18, -0.24), 0.07, 0.07, MOSS, 0.03, 0.95, 0.02)  # the wreath
	s.ellipsoid(Vector3(0.36, 1.65, 0.22), Vector3(0.11, 0.62, 0.36), STONE, 0.04, 0.92, 0.006, Basis.from_euler(Vector3(0.25, 0.0, -0.3)))
	s.ellipsoid(Vector3(-0.36, 1.3, 0.22), Vector3(0.11, 0.36, 0.33), STONE, 0.04, 0.92, 0.006, Basis.from_euler(Vector3(0.25, 0.0, 0.5)))  # the broken one
	s.carve_box(Vector3(-0.45, 1.62, 0.22), Vector3(0.2, 0.06, 0.4), STONE_DARK, 0.02, Basis.from_euler(Vector3(0.0, 0.0, 0.6)))
	s.paint_ellipsoid(Vector3(0.0, 0.45, 0.0), Vector3(0.45, 0.3, 0.45), MOSS, 1.0)
	s.paint_ellipsoid(Vector3(0.3, 2.0, 0.25), Vector3(0.15, 0.25, 0.2), LICHEN, 1.0)
	for x: float in [-1.0, 1.0]:
		s.paint_capsule(Vector3(x * 0.04, 1.84, -0.24), Vector3(x * 0.05, 1.35, -0.3), 0.015, 0.01, BARK_DARK, 1.0)  # black streaks down from the eyes
	return s.mesh("manor_angel", 0.025, 2400)


## A high-backed dining chair, the seat's velvet worn to the canvas.
static func _chair() -> ArrayMesh:
	var s := Sculpt.new().noise_scale(12.0)
	s.box(Vector3(0.0, 0.46, 0.0), Vector3(0.22, 0.03, 0.21), 0.01, WOOD, 0.0, 0.8, 0.003)
	s.box(Vector3(0.0, 0.5, -0.01), Vector3(0.2, 0.025, 0.19), 0.02, VELVET, 0.01, 0.95, 0.004)
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			s.capsule(Vector3(x * 0.19, 0.0, z * 0.18), Vector3(x * 0.19, 0.45, z * 0.18), 0.022, 0.025, WOOD, 0.0, 0.8)
		s.capsule(Vector3(x * 0.19, 0.46, 0.18), Vector3(x * 0.2, 1.08, 0.22), 0.025, 0.02, WOOD, 0.0, 0.8)
	s.box(Vector3(0.0, 1.03, 0.21), Vector3(0.21, 0.05, 0.022), 0.012, WOOD, 0.01, 0.8)
	s.box(Vector3(0.0, 0.76, 0.2), Vector3(0.07, 0.24, 0.015), 0.01, WOOD_ROT, 0.01, 0.8)
	return s.mesh("manor_chair", 0.016, 1200)


## A three-branched candelabrum gone green, the candles burned down crooked.
static func _candelabra() -> ArrayMesh:
	var s := Sculpt.new().noise_scale(14.0)
	s.ellipsoid(Vector3(0.0, 0.02, 0.0), Vector3(0.09, 0.025, 0.09), BRASS, 0.01, 0.45)
	s.capsule(Vector3(0.0, 0.02, 0.0), Vector3(0.0, 0.46, 0.0), 0.022, 0.014, BRASS, 0.01, 0.45)
	s.ellipsoid(Vector3(0.0, 0.2, 0.0), Vector3(0.035, 0.03, 0.035), BRASS, 0.01, 0.45)
	for x: float in [-1.0, 1.0]:
		s.tube_add(PackedVector3Array([Vector3(0.0, 0.38, 0.0), Vector3(x * 0.12, 0.4, 0.0), Vector3(x * 0.17, 0.5, 0.0)]), PackedFloat32Array([0.012, 0.011, 0.01]), BRASS, 0.45, 6)
	for x: float in [-0.17, 0.0, 0.17]:
		var top := 0.5 if x != 0.0 else 0.47
		s.capsule(Vector3(x, top, 0.0), Vector3(x, top + 0.02, 0.0), 0.028, 0.028, BRASS, 0.005, 0.45)
		var h := 0.12 + absf(x) * 0.4
		s.capsule(Vector3(x, top + 0.02, 0.0), Vector3(x + 0.01, top + h, 0.0), 0.018, 0.016, WAX, 0.005, 0.7)
		s.ellipsoid(Vector3(x + 0.014, top + h * 0.5, 0.012), Vector3(0.008, h * 0.35, 0.008), WAX, 0.004, 0.7)  # a drip
	s.paint_box(Vector3(0.0, 0.1, 0.0), Vector3(0.2, 0.1, 0.2), VERDIGRIS, 0.7)
	return s.mesh("manor_candelabra", 0.008, 1400)


## An armchair under a dust sheet: soft lumps, the hem pooled on the floor.
static func _sheeted() -> ArrayMesh:
	var s := Sculpt.new().noise_scale(5.0)
	s.box(Vector3(0.0, 0.25, 0.0), Vector3(0.44, 0.25, 0.4), 0.08, SHROUD, 0.0, 0.95, 0.01)
	s.box(Vector3(0.0, 0.72, 0.32), Vector3(0.42, 0.3, 0.1), 0.08, SHROUD, 0.12, 0.95, 0.012)
	for x: float in [-1.0, 1.0]:
		s.ellipsoid(Vector3(x * 0.4, 0.58, 0.0), Vector3(0.11, 0.1, 0.4), SHROUD, 0.12, 0.95, 0.01)
	s.ellipsoid(Vector3(0.0, 0.03, 0.0), Vector3(0.58, 0.04, 0.52), SHROUD, 0.08, 0.95, 0.01)
	s.paint_box(Vector3(0.0, 0.08, 0.0), Vector3(0.6, 0.1, 0.55), SHROUD_DIRT, 1.0)
	return s.mesh("manor_sheeted", 0.022, 1400)


## A travelling trunk with a domed lid, iron straps and a lock gone green.
static func _chest() -> ArrayMesh:
	var s := Sculpt.new().noise_scale(12.0)
	s.box(Vector3(0.0, 0.2, 0.0), Vector3(0.48, 0.2, 0.28), 0.015, WOOD, 0.01, 0.82, 0.003)
	s.capsule(Vector3(-0.47, 0.4, 0.0), Vector3(0.47, 0.4, 0.0), 0.27, 0.27, WOOD, 0.01, 0.82, 0.003)
	s.carve_box(Vector3(0.0, 0.2, 0.0), Vector3(0.6, 0.2, 0.4), VOID, 0.0)
	s.box(Vector3(0.0, 0.2, 0.0), Vector3(0.48, 0.2, 0.28), 0.015, WOOD, 0.01, 0.82, 0.003)
	for x: float in [-0.3, 0.3]:
		s.paint_box(Vector3(x, 0.4, 0.0), Vector3(0.035, 0.4, 0.4), IRON, 0.55)
	s.box(Vector3(0.0, 0.38, 0.28), Vector3(0.05, 0.05, 0.015), 0.005, VERDIGRIS, 0.0, 0.5)
	return s.mesh("manor_chest", 0.018, 1200)


## A window shutter of slats, warped, one slat gone.
static func _shutter() -> ArrayMesh:
	var s := Sculpt.new().noise_scale(12.0)
	s.box(Vector3(0.0, 0.8, 0.0), Vector3(0.34, 0.8, 0.025), 0.01, SHUTTER, 0.0, 0.85, 0.003)
	for k in 17:
		s.paint_box(Vector3(0.0, 0.12 + float(k) * 0.08, 0.0), Vector3(0.29, 0.006, 0.04), BARK_DARK, 1.0)
	s.carve_box(Vector3(0.05, 0.92, 0.0), Vector3(0.24, 0.02, 0.04), VOID, 0.0)
	for y: float in [0.25, 1.35]:
		s.box(Vector3(-0.3, y, 0.03), Vector3(0.05, 0.02, 0.008), 0.004, IRON, 0.0, 0.6)
	return s.mesh("manor_shutter", 0.012, 1000)


## A straight rod (iron rail, crib slat) as a tube: two rings, crisp at any grid spacing.
static func _rod(s: Sculpt, a: Vector3, b: Vector3, r: float, col: Color, rough: float = 0.55) -> void:
	s.tube_add(PackedVector3Array([a, b]), PackedFloat32Array([r, r]), col, rough, 6, 1)


## A dining table under its cloth: turned legs, the cloth hanging down both long sides, two places
## laid each side (plates, pewter cups, one knocked over) and wine dried black where it spilled.
static func _table() -> ArrayMesh:
	var s := Sculpt.new().noise_scale(10.0)
	s.box(Vector3(0.0, 0.775, 0.0), Vector3(1.7, 0.025, 0.9), 0.012, MAHOGANY, 0.0, 0.5, 0.002)
	s.box(Vector3(0.0, 0.69, 0.0), Vector3(1.58, 0.06, 0.78), 0.01, MAHOGANY, 0.0, 0.6)
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			var at := Vector3(x * 1.52, 0.0, z * 0.72)
			s.capsule(at + Vector3(0.0, 0.04, 0.0), at + Vector3(0.0, 0.66, 0.0), 0.04, 0.055, MAHOGANY, 0.02, 0.55)
			s.ellipsoid(at + Vector3(0.0, 0.26, 0.0), Vector3(0.07, 0.1, 0.07), MAHOGANY, 0.03, 0.55)
			s.ellipsoid(at + Vector3(0.0, 0.035, 0.0), Vector3(0.055, 0.035, 0.055), MAHOGANY, 0.02, 0.55)
	for z: float in [-1.0, 1.0]:
		s.box(Vector3(0.0, 0.66, z * 0.918), Vector3(1.6, 0.15, 0.016), 0.01, LINEN, 0.0, 0.85, 0.008)  # the cloth's drop
	s.paint_box(Vector3(0.0, 0.795, 0.0), Vector3(1.6, 0.012, 0.94), LINEN, 0.85)
	for k in 4:
		var x := -0.8 if k < 2 else 0.8
		var z := -1.0 if k % 2 == 0 else 1.0
		s.ellipsoid(Vector3(x, 0.81, z * 0.55), Vector3(0.14, 0.02, 0.14), PORCELAIN, 0.0, 0.3)
		s.carve_ellipsoid(Vector3(x, 0.84, z * 0.55), Vector3(0.1, 0.022, 0.1), PORCELAIN)
		if k == 2:  # knocked over, the wine run out across the cloth
			s.capsule(Vector3(x + 0.18, 0.835, z * 0.3), Vector3(x + 0.34, 0.835, z * 0.22), 0.03, 0.04, BRASS, 0.0, 0.45)
			s.paint_ellipsoid(Vector3(x + 0.45, 0.8, z * 0.15), Vector3(0.28, 0.03, 0.16), OLD_BLOOD, 0.4)
		else:
			s.capsule(Vector3(x + 0.22, 0.81, z * 0.33), Vector3(x + 0.22, 0.93, z * 0.33), 0.028, 0.04, BRASS, 0.0, 0.45)
			s.carve_ellipsoid(Vector3(x + 0.22, 0.95, z * 0.33), Vector3(0.022, 0.06, 0.022), VOID)
	s.paint_ellipsoid(Vector3(0.3, 0.8, -0.1), Vector3(0.22, 0.03, 0.14), OLD_BLOOD, 0.4)
	s.paint_ellipsoid(Vector3(-1.1, 0.8, 0.2), Vector3(0.35, 0.03, 0.3), SHROUD_DIRT, 0.9)
	return s.mesh("manor_table", 0.016, 3200)


## A grand piano with its lid propped open, black lacquer grey with dust: the straight bass side
## at -x, the bentside cut round to the tail at -z, three turned legs on brass castors, the lyre and
## pedals, the keys gone yellow and two of them missing, a page of music still on the desk.
static func _piano() -> ArrayMesh:
	var s := Sculpt.new().noise_scale(10.0)
	s.box(Vector3(0.0, 0.79, -0.125), Vector3(0.72, 0.15, 0.975), 0.03, EBONY, 0.0, 0.25)
	s.carve_box(Vector3(1.03, 0.79, -0.397), Vector3(0.5, 0.3, 0.9), EBONY, 0.05, Basis.from_euler(Vector3(0.0, 0.405, 0.0)))
	s.carve_box(Vector3(0.402, 0.79, -1.212), Vector3(0.5, 0.3, 0.6), EBONY, 0.05, Basis.from_euler(Vector3(0.0, 0.884, 0.0)))
	# The lid on its hinge along the straight side, the same outline cut out of it.
	var hinge := Vector3(-0.72, 0.95, 0.0)
	var lid := Basis.from_euler(Vector3(0.0, 0.0, 0.65))
	s.box(hinge + lid * Vector3(0.72, 0.016, -0.125), Vector3(0.72, 0.016, 0.975), 0.01, EBONY, 0.0, 0.25, 0.0, lid)
	s.carve_box(hinge + lid * Vector3(1.75, 0.0, -0.397), Vector3(0.5, 0.1, 0.9), EBONY, 0.03, lid * Basis.from_euler(Vector3(0.0, 0.405, 0.0)))
	s.carve_box(hinge + lid * Vector3(1.122, 0.0, -1.212), Vector3(0.5, 0.1, 0.6), EBONY, 0.03, lid * Basis.from_euler(Vector3(0.0, 0.884, 0.0)))
	s.paint_box(hinge + lid * Vector3(0.72, 0.035, -0.1), Vector3(0.6, 0.02, 0.8), DUST, 0.9, lid)
	s.tube_add(PackedVector3Array([Vector3(0.55, 0.94, 0.0), Vector3(0.34, 1.73, 0.0)]), PackedFloat32Array([0.013, 0.011]), EBONY, 0.3, 6, 1)
	# Inside: the soundboard and the iron frame.
	s.paint_box(Vector3(-0.05, 0.94, -0.2), Vector3(0.62, 0.02, 0.88), Color(0.3, 0.2, 0.11), 0.6)
	s.paint_ellipsoid(Vector3(-0.15, 0.94, -0.35), Vector3(0.42, 0.03, 0.62), BRASS, 0.45)
	# The keyboard.
	s.box(Vector3(0.0, 0.69, 0.98), Vector3(0.7, 0.035, 0.16), 0.01, EBONY, 0.0, 0.25)
	s.box(Vector3(0.0, 0.74, 1.0), Vector3(0.63, 0.016, 0.12), 0.004, IVORY, 0.0, 0.35)
	var w := 1.26 / 52.0
	for i in 51:
		if i % 7 in [0, 1, 3, 4, 5]:
			s.paint_box(Vector3(-0.63 + float(i + 1) * w, 0.76, 0.95), Vector3(0.006, 0.02, 0.06), EBONY, 0.3)
	for x: float in [0.17, -0.31]:
		s.carve_box(Vector3(x, 0.75, 1.0), Vector3(0.012, 0.02, 0.13), VOID)  # keys gone
	for x: float in [-1.0, 1.0]:
		s.box(Vector3(x * 0.67, 0.77, 0.98), Vector3(0.035, 0.05, 0.16), 0.01, EBONY, 0.0, 0.25)
	s.box(Vector3(0.0, 0.86, 0.84), Vector3(0.62, 0.07, 0.012), 0.005, EBONY, 0.0, 0.25, 0.0, Basis.from_euler(Vector3(-0.2, 0.0, 0.0)))
	var tilt := Basis.from_euler(Vector3(-0.3, 0.0, 0.0))
	s.box(Vector3(0.0, 1.08, 0.74), Vector3(0.34, 0.13, 0.012), 0.005, EBONY, 0.0, 0.25, 0.0, tilt)
	s.paint_box(Vector3(0.0, 1.1, 0.755), Vector3(0.2, 0.11, 0.012), WAX, 0.9, tilt)
	# Legs, castors, the lyre and its pedals.
	for at: Vector3 in [Vector3(-0.6, 0.0, 0.62), Vector3(0.6, 0.0, 0.62), Vector3(-0.45, 0.0, -0.9)]:
		s.capsule(at + Vector3(0.0, 0.06, 0.0), at + Vector3(0.0, 0.66, 0.0), 0.05, 0.075, EBONY, 0.02, 0.3)
		s.ellipsoid(at + Vector3(0.0, 0.58, 0.0), Vector3(0.09, 0.05, 0.09), EBONY, 0.02, 0.3)
		s.ellipsoid(at + Vector3(0.0, 0.035, 0.0), Vector3(0.04, 0.035, 0.04), BRASS, 0.0, 0.4)
	for x: float in [-0.05, 0.05]:
		_rod(s, Vector3(x, 0.65, 0.45), Vector3(x * 1.6, 0.08, 0.52), 0.016, EBONY, 0.3)
	s.box(Vector3(0.0, 0.06, 0.55), Vector3(0.1, 0.015, 0.05), 0.005, BRASS, 0.0, 0.4)
	return s.mesh("manor_piano", 0.016, 3400)


## A pedestal writing desk: a worn green leather top, three drawers a side (one pulled out, papers
## in it), the knee-hole drawer, an inkwell, a pile of books and a skull for a paperweight.
static func _desk() -> ArrayMesh:
	var s := Sculpt.new().noise_scale(10.0)
	s.box(Vector3(0.0, 0.775, 0.0), Vector3(1.1, 0.025, 0.55), 0.012, MAHOGANY, 0.0, 0.5, 0.002)
	s.paint_box(Vector3(0.0, 0.8, 0.0), Vector3(0.92, 0.012, 0.4), LEATHER, 0.8)
	for x: float in [-1.0, 1.0]:
		s.box(Vector3(x * 0.72, 0.4, 0.0), Vector3(0.36, 0.35, 0.5), 0.01, MAHOGANY, 0.0, 0.55)
		s.box(Vector3(x * 0.72, 0.03, 0.0), Vector3(0.38, 0.03, 0.52), 0.01, WOOD_ROT, 0.0, 0.7)
		for y: float in [0.28, 0.52]:
			s.carve_box(Vector3(x * 0.72, y, 0.5), Vector3(0.33, 0.006, 0.012), VOID)  # the drawers' seams
		for y: float in [0.16, 0.4, 0.63]:
			if not (x > 0.0 and y == 0.4):
				s.ellipsoid(Vector3(x * 0.72, y, 0.515), Vector3(0.05, 0.014, 0.014), BRASS, 0.0, 0.4)
	s.box(Vector3(0.0, 0.7, 0.0), Vector3(0.38, 0.06, 0.5), 0.005, MAHOGANY, 0.0, 0.55)  # over the knees
	s.box(Vector3(0.0, 0.42, -0.47), Vector3(0.38, 0.3, 0.02), 0.005, MAHOGANY, 0.0, 0.6)
	s.ellipsoid(Vector3(0.0, 0.7, 0.505), Vector3(0.06, 0.014, 0.014), BRASS, 0.0, 0.4)
	# The middle drawer on the right, out on its runners.
	s.carve_box(Vector3(0.72, 0.4, 0.47), Vector3(0.31, 0.1, 0.04), SHADOW)
	s.box(Vector3(0.72, 0.4, 0.66), Vector3(0.31, 0.1, 0.18), 0.005, MAHOGANY, 0.0, 0.55)
	s.carve_box(Vector3(0.72, 0.47, 0.64), Vector3(0.28, 0.08, 0.15), SHADOW)
	s.ellipsoid(Vector3(0.72, 0.4, 0.845), Vector3(0.05, 0.014, 0.014), BRASS, 0.0, 0.4)
	s.box(Vector3(0.7, 0.4, 0.64), Vector3(0.24, 0.02, 0.13), 0.004, WAX, 0.0, 0.9, 0.004, Basis.from_euler(Vector3(0.08, 0.2, 0.0)))  # papers
	# On top: an inkwell, books, the skull.
	s.ellipsoid(Vector3(0.45, 0.83, -0.15), Vector3(0.045, 0.035, 0.045), GLASS, 0.0, 0.1)
	s.box(Vector3(-0.2, 0.83, -0.38), Vector3(0.15, 0.03, 0.11), 0.006, BOOK_COLORS[0], 0.0, 0.75, 0.0, Basis.from_euler(Vector3(0.0, 0.2, 0.0)))
	s.box(Vector3(-0.2, 0.885, -0.38), Vector3(0.13, 0.025, 0.1), 0.006, BOOK_COLORS[4], 0.0, 0.75, 0.0, Basis.from_euler(Vector3(0.0, -0.15, 0.0)))
	var sk := Vector3(-0.6, 0.8, -0.15)
	s.ellipsoid(sk + Vector3(0.0, 0.1, -0.02), Vector3(0.075, 0.075, 0.095), IVORY, 0.0, 0.7)
	s.ellipsoid(sk + Vector3(0.0, 0.05, 0.05), Vector3(0.06, 0.04, 0.05), IVORY, 0.03, 0.7)
	for x: float in [-1.0, 1.0]:
		s.carve_ellipsoid(sk + Vector3(x * 0.03, 0.085, 0.075), Vector3(0.022, 0.022, 0.03), VOID)
	s.carve_ellipsoid(sk + Vector3(0.0, 0.055, 0.095), Vector3(0.01, 0.018, 0.02), VOID)
	s.paint_box(sk + Vector3(0.0, 0.025, 0.09), Vector3(0.04, 0.01, 0.02), Color(0.5, 0.45, 0.33), 0.7)
	return s.mesh("manor_desk", 0.014, 3200)


## A bookcase floor to ceiling: six shelves of old books, gaps where some were taken, a few leaning
## over and some stacked flat, dust along the top.
static func _bookcase() -> ArrayMesh:
	var s := Sculpt.new().noise_scale(10.0)
	s.box(Vector3(0.0, 1.95, 0.0), Vector3(1.0, 1.95, 0.3), 0.01, MAHOGANY, 0.0, 0.6, 0.002)
	s.carve_box(Vector3(0.0, 2.02, 0.07), Vector3(0.92, 1.78, 0.3), SHADOW)
	s.box(Vector3(0.0, 0.1, 0.01), Vector3(1.02, 0.1, 0.31), 0.01, MAHOGANY, 0.0, 0.6)
	s.box(Vector3(0.0, 3.92, 0.02), Vector3(1.05, 0.08, 0.33), 0.015, MAHOGANY, 0.0, 0.55)
	s.box(Vector3(0.0, 3.82, 0.01), Vector3(1.02, 0.025, 0.31), 0.01, MAHOGANY, 0.0, 0.55)
	s.paint_box(Vector3(0.0, 4.0, 0.02), Vector3(1.06, 0.02, 0.34), DUST, 0.9)
	for k in range(1, 6):
		s.box(Vector3(0.0, 0.24 + float(k) * 0.593, 0.04), Vector3(0.92, 0.018, 0.26), 0.005, MAHOGANY, 0.0, 0.6)
	var r := RandomNumberGenerator.new()
	r.seed = 4111
	for c in 6:
		var y0 := 0.24 + float(c) * 0.593 + (0.018 if c > 0 else 0.0)
		var x := -0.9
		if r.randf() < 0.15:  # a stack lying flat at one end
			for k in r.randi_range(3, 5):
				s.box(Vector3(-0.76, y0 + 0.022 + float(k) * 0.044, 0.05), Vector3(r.randf_range(0.11, 0.14), 0.02, r.randf_range(0.13, 0.16)), 0.005,
					BOOK_COLORS[r.randi_range(0, BOOK_COLORS.size() - 1)], 0.0, 0.75, 0.0, Basis.from_euler(Vector3(0.0, r.randf_range(-0.2, 0.2), 0.0)))
			x = -0.6
		var lean := false
		while x < 0.86:
			if r.randf() < 0.07:
				x += r.randf_range(0.12, 0.3)  # some taken
				lean = true
				continue
			var bw := r.randf_range(0.035, 0.07)
			if x + bw > 0.9:
				break
			var bh := r.randf_range(0.2, 0.36)
			var bd := r.randf_range(0.085, 0.11)
			var col: Color = BOOK_COLORS[r.randi_range(0, BOOK_COLORS.size() - 1)]
			if lean:  # the first one after a gap has fallen against the next
				s.box(Vector3(x + bw * 0.5 + 0.06, y0 + bh * 0.47, 0.27 - bd), Vector3(bw * 0.5, bh * 0.5, bd), 0.006, col, 0.0, 0.75, 0.0, Basis.from_euler(Vector3(0.0, 0.0, -0.35)))
				x += bw + 0.12
				lean = false
				continue
			s.box(Vector3(x + bw * 0.5, y0 + bh * 0.5, 0.27 - bd), Vector3(bw * 0.5, bh * 0.5, bd), 0.006, col, 0.0, 0.75)
			x += bw + 0.002
	return s.mesh("manor_bookcase", 0.02, 5000)


## A long-case clock: bun feet, the trunk's glass door with the pendulum hanging still behind it,
## the hood on its turned columns, a yellowed dial stopped at three o'clock.
static func _clock() -> ArrayMesh:
	var s := Sculpt.new().noise_scale(12.0)
	s.box(Vector3(0.0, 0.22, 0.0), Vector3(0.28, 0.18, 0.23), 0.012, MAHOGANY, 0.0, 0.55)
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			s.ellipsoid(Vector3(x * 0.24, 0.03, z * 0.19), Vector3(0.045, 0.035, 0.045), MAHOGANY, 0.01, 0.6)
	s.box(Vector3(0.0, 0.43, 0.0), Vector3(0.3, 0.03, 0.25), 0.01, MAHOGANY, 0.0, 0.55)
	s.box(Vector3(0.0, 1.07, -0.01), Vector3(0.21, 0.62, 0.17), 0.01, MAHOGANY, 0.0, 0.55)
	s.carve_box(Vector3(0.0, 1.1, 0.17), Vector3(0.11, 0.38, 0.04), GLASS)
	s.ellipsoid(Vector3(0.0, 0.84, 0.135), Vector3(0.065, 0.065, 0.015), BRASS, 0.0, 0.35)
	s.tube_add(PackedVector3Array([Vector3(0.0, 1.46, 0.135), Vector3(0.0, 0.88, 0.135)]), PackedFloat32Array([0.006, 0.006]), BRASS, 0.35, 5, 1)
	s.box(Vector3(0.0, 1.71, 0.0), Vector3(0.27, 0.03, 0.23), 0.01, MAHOGANY, 0.0, 0.55)
	s.box(Vector3(0.0, 1.97, -0.01), Vector3(0.24, 0.24, 0.19), 0.01, MAHOGANY, 0.0, 0.55)
	s.box(Vector3(0.0, 2.24, 0.01), Vector3(0.29, 0.035, 0.24), 0.01, MAHOGANY, 0.0, 0.55)
	for x: float in [-1.0, 1.0]:
		s.capsule(Vector3(x * 0.235, 1.75, 0.2), Vector3(x * 0.235, 2.2, 0.2), 0.022, 0.022, MAHOGANY, 0.0, 0.5)
		s.ellipsoid(Vector3(x * 0.24, 2.3, 0.15), Vector3(0.03, 0.045, 0.03), BRASS, 0.0, 0.4)
	s.ellipsoid(Vector3(0.0, 1.97, 0.18), Vector3(0.16, 0.16, 0.012), IVORY, 0.0, 0.45)
	for k in 12:
		var a := TAU * float(k) / 12.0
		s.paint_ellipsoid(Vector3(sin(a) * 0.13, 1.97 + cos(a) * 0.13, 0.19), Vector3(0.012, 0.012, 0.02), EBONY, 0.4)
	s.paint_box(Vector3(0.045, 1.97, 0.192), Vector3(0.05, 0.007, 0.012), EBONY, 0.4)  # stopped at three
	s.paint_box(Vector3(0.0, 2.03, 0.192), Vector3(0.007, 0.07, 0.012), EBONY, 0.4)
	s.paint_box(Vector3(0.0, 2.27, 0.01), Vector3(0.3, 0.012, 0.25), DUST, 0.9)
	return s.mesh("manor_clock", 0.01, 2400)


## A side table on bowed legs with a drawer and a shelf low down.
static func _side_table() -> ArrayMesh:
	var s := Sculpt.new().noise_scale(12.0)
	s.box(Vector3(0.0, 0.78, 0.0), Vector3(0.6, 0.02, 0.3), 0.012, MAHOGANY, 0.0, 0.5, 0.002)
	s.box(Vector3(0.0, 0.69, 0.0), Vector3(0.53, 0.07, 0.24), 0.008, MAHOGANY, 0.0, 0.55)
	s.paint_box(Vector3(0.0, 0.69, 0.245), Vector3(0.3, 0.05, 0.01), WOOD_ROT, 0.6)
	s.ellipsoid(Vector3(0.0, 0.69, 0.25), Vector3(0.02, 0.02, 0.015), BRASS, 0.0, 0.4)
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			s.tube_add(PackedVector3Array([Vector3(x * 0.5, 0.64, z * 0.21), Vector3(x * 0.53, 0.42, z * 0.24), Vector3(x * 0.5, 0.18, z * 0.21), Vector3(x * 0.54, 0.02, z * 0.25)]),
				PackedFloat32Array([0.035, 0.028, 0.022, 0.03]), MAHOGANY, 0.55, 7)
	s.box(Vector3(0.0, 0.2, 0.0), Vector3(0.5, 0.012, 0.21), 0.005, MAHOGANY, 0.0, 0.6)
	s.paint_ellipsoid(Vector3(0.2, 0.8, -0.05), Vector3(0.3, 0.02, 0.2), DUST, 0.9)
	return s.mesh("manor_side_table", 0.012, 1600)


## A four-poster with a torn canopy, the counterpane gone to rags at the sides, and someone still in
## it under the sheet, lying very straight; a stain spreading through.
static func _bed() -> ArrayMesh:
	var s := Sculpt.new().noise_scale(8.0)
	s.box(Vector3(0.0, 0.3, 0.0), Vector3(1.12, 0.12, 1.34), 0.02, MAHOGANY, 0.0, 0.55)
	s.box(Vector3(0.0, 0.5, 0.03), Vector3(1.06, 0.1, 1.28), 0.07, LINEN, 0.0, 0.9, 0.008)
	s.box(Vector3(0.0, 0.62, 0.25), Vector3(1.14, 0.035, 1.05), 0.03, VELVET, 0.02, 0.9, 0.012)
	for x: float in [-1.0, 1.0]:
		s.box(Vector3(x * 1.15, 0.45, 0.25), Vector3(0.025, 0.2, 1.05), 0.02, VELVET, 0.02, 0.9, 0.015)
	s.ellipsoid(Vector3(0.0, 0.64, -1.0), Vector3(0.75, 0.09, 0.22), LINEN, 0.04, 0.9, 0.01)
	s.ellipsoid(Vector3(0.0, 0.73, -0.72), Vector3(0.13, 0.11, 0.15), SHROUD, 0.06, 0.95, 0.005)
	s.ellipsoid(Vector3(0.0, 0.7, -0.35), Vector3(0.3, 0.1, 0.22), SHROUD, 0.08, 0.95, 0.006)
	s.ellipsoid(Vector3(0.0, 0.68, 0.25), Vector3(0.26, 0.09, 0.6), SHROUD, 0.1, 0.95, 0.006)
	for x: float in [-1.0, 1.0]:
		s.ellipsoid(Vector3(x * 0.1, 0.72, 0.95), Vector3(0.07, 0.1, 0.07), SHROUD, 0.05, 0.95)
	s.paint_ellipsoid(Vector3(0.05, 0.78, -0.65), Vector3(0.1, 0.06, 0.1), SHROUD_DIRT, 0.95)
	s.paint_ellipsoid(Vector3(0.12, 0.72, 0.0), Vector3(0.22, 0.1, 0.28), OLD_BLOOD, 0.8)
	s.box(Vector3(0.0, 1.0, -1.33), Vector3(1.08, 0.55, 0.04), 0.01, MAHOGANY, 0.0, 0.55)
	s.ellipsoid(Vector3(0.0, 1.5, -1.33), Vector3(0.75, 0.22, 0.04), MAHOGANY, 0.02, 0.55)
	s.box(Vector3(0.0, 0.62, 1.33), Vector3(1.05, 0.22, 0.035), 0.01, MAHOGANY, 0.0, 0.55)
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			var at := Vector3(x * 1.13, 0.0, z * 1.33)
			s.capsule(at, at + Vector3(0.0, 2.62, 0.0), 0.06, 0.045, MAHOGANY, 0.02, 0.55)
			s.ellipsoid(at + Vector3(0.0, 0.75, 0.0), Vector3(0.085, 0.13, 0.085), MAHOGANY, 0.03, 0.55)
			s.ellipsoid(at + Vector3(0.0, 1.6, 0.0), Vector3(0.06, 0.08, 0.06), MAHOGANY, 0.03, 0.55)
			s.ellipsoid(at + Vector3(0.0, 2.66, 0.0), Vector3(0.05, 0.06, 0.05), MAHOGANY, 0.02, 0.55)
		s.capsule(Vector3(x * 1.13, 2.58, -1.33), Vector3(x * 1.13, 2.58, 1.33), 0.035, 0.035, MAHOGANY, 0.01, 0.55)
		s.capsule(Vector3(-1.13, 2.58, x * 1.33), Vector3(1.13, 2.58, x * 1.33), 0.035, 0.035, MAHOGANY, 0.01, 0.55)
		s.box(Vector3(x * 1.1, 1.75, -1.15), Vector3(0.02, 0.8, 0.16), 0.01, VELVET, 0.0, 0.9, 0.02)  # what is left of the curtains
	s.box(Vector3(0.0, 2.6, 0.0), Vector3(1.1, 0.02, 1.3), 0.01, VELVET, 0.0, 0.9, 0.025)  # the canopy, rotted through
	return s.mesh("manor_bed", 0.022, 4200)


## An iron bedstead: brass knobs on the posts, a stained mattress, the sheet thrown back and half
## off the side, a pillow flat as a board.
static func _cot() -> ArrayMesh:
	var s := Sculpt.new().noise_scale(10.0)
	for x: float in [-1.0, 1.0]:
		_rod(s, Vector3(x * 0.52, 0.0, -1.02), Vector3(x * 0.52, 1.06, -1.02), 0.024, IRON)
		_rod(s, Vector3(x * 0.52, 0.0, 1.02), Vector3(x * 0.52, 0.78, 1.02), 0.024, IRON)
		s.ellipsoid(Vector3(x * 0.52, 1.08, -1.02), Vector3(0.04, 0.04, 0.04), BRASS, 0.0, 0.4)
		s.ellipsoid(Vector3(x * 0.52, 0.8, 1.02), Vector3(0.04, 0.04, 0.04), BRASS, 0.0, 0.4)
		_rod(s, Vector3(x * 0.52, 0.36, -1.02), Vector3(x * 0.52, 0.36, 1.02), 0.02, IRON)
	for z: float in [-1.02, 1.02]:
		var top := 1.0 if z < 0.0 else 0.72
		for y: float in [top, 0.42]:
			_rod(s, Vector3(-0.52, y, z), Vector3(0.52, y, z), 0.016, IRON)
		for k in 7:
			var x := -0.39 + float(k) * 0.13
			_rod(s, Vector3(x, 0.42, z), Vector3(x, top, z), 0.011, RUST if k % 3 == 1 else IRON)
	s.box(Vector3(0.0, 0.47, 0.0), Vector3(0.49, 0.08, 1.0), 0.05, LINEN, 0.0, 0.9, 0.008)
	s.paint_ellipsoid(Vector3(0.1, 0.55, -0.3), Vector3(0.3, 0.06, 0.4), OLD_BLOOD, 0.9)
	s.paint_ellipsoid(Vector3(-0.2, 0.55, 0.4), Vector3(0.25, 0.06, 0.3), SHROUD_DIRT, 0.9)
	s.box(Vector3(0.15, 0.565, 0.45), Vector3(0.42, 0.018, 0.55), 0.01, SHROUD, 0.0, 0.95, 0.008)  # the sheet, thrown back
	s.box(Vector3(0.57, 0.38, 0.45), Vector3(0.016, 0.2, 0.5), 0.01, SHROUD, 0.03, 0.95, 0.01)
	s.ellipsoid(Vector3(0.0, 0.58, -0.82), Vector3(0.32, 0.05, 0.13), LINEN, 0.03, 0.9)
	return s.mesh("manor_cot", 0.014, 2600)


## A crib of turned slats, one snapped off; a small shape under the blanket.
static func _crib() -> ArrayMesh:
	var s := Sculpt.new().noise_scale(10.0)
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			_rod(s, Vector3(x * 0.42, 0.0, z * 0.72), Vector3(x * 0.42, 1.04, z * 0.72), 0.03, WOOD)
			s.ellipsoid(Vector3(x * 0.42, 1.07, z * 0.72), Vector3(0.04, 0.045, 0.04), WOOD, 0.0, 0.6)
	for y: float in [0.34, 0.96]:
		for x: float in [-1.0, 1.0]:
			_rod(s, Vector3(x * 0.42, y, -0.72), Vector3(x * 0.42, y, 0.72), 0.022, WOOD)
			_rod(s, Vector3(-0.42, y, x * 0.72), Vector3(0.42, y, x * 0.72), 0.022, WOOD)
	for k in 11:
		var z := -0.6 + float(k) * 0.12
		for x: float in [-1.0, 1.0]:
			if x > 0.0 and k == 6:
				_rod(s, Vector3(0.42, 0.34, z), Vector3(0.43, 0.52, z + 0.02), 0.011, WOOD_ROT)
			else:
				_rod(s, Vector3(x * 0.42, 0.34, z), Vector3(x * 0.42, 0.96, z), 0.011, WOOD)
	for k in 6:
		for z: float in [-1.0, 1.0]:
			_rod(s, Vector3(-0.3 + float(k) * 0.12, 0.34, z * 0.72), Vector3(-0.3 + float(k) * 0.12, 0.96, z * 0.72), 0.011, WOOD)
	s.box(Vector3(0.0, 0.4, 0.0), Vector3(0.4, 0.05, 0.7), 0.03, LINEN, 0.0, 0.9, 0.006)
	s.ellipsoid(Vector3(0.05, 0.48, 0.15), Vector3(0.14, 0.06, 0.24), SHROUD, 0.05, 0.95, 0.008)
	s.ellipsoid(Vector3(0.0, 0.47, -0.5), Vector3(0.18, 0.04, 0.1), LINEN, 0.03, 0.9)
	s.paint_ellipsoid(Vector3(0.05, 0.53, 0.0), Vector3(0.08, 0.04, 0.08), SHROUD_DIRT, 0.95)
	return s.mesh("manor_crib", 0.012, 3000)


## A wardrobe: plinth and cornice, two doors of raised panels, one not quite shut on the dark.
static func _wardrobe() -> ArrayMesh:
	var s := Sculpt.new().noise_scale(10.0)
	s.box(Vector3(0.0, 1.2, 0.0), Vector3(0.88, 1.08, 0.38), 0.01, MAHOGANY, 0.0, 0.55, 0.002)
	s.box(Vector3(0.0, 0.07, 0.01), Vector3(0.91, 0.07, 0.4), 0.01, MAHOGANY, 0.0, 0.6)
	s.box(Vector3(0.0, 2.33, 0.02), Vector3(0.93, 0.05, 0.41), 0.012, MAHOGANY, 0.0, 0.55)
	s.box(Vector3(0.0, 2.26, 0.01), Vector3(0.9, 0.025, 0.4), 0.008, MAHOGANY, 0.0, 0.55)
	s.carve_box(Vector3(0.02, 1.2, 0.36), Vector3(0.03, 1.02, 0.06), SHADOW)
	for x: float in [-1.0, 1.0]:
		for y: float in [0.62, 1.68]:
			s.box(Vector3(x * 0.45, y, 0.385), Vector3(0.32, 0.4 if y > 1.0 else 0.34, 0.012), 0.01, WOOD, 0.0, 0.5)
		s.ellipsoid(Vector3(x * 0.09, 1.2, 0.395), Vector3(0.015, 0.04, 0.02), BRASS, 0.0, 0.4)
	s.paint_box(Vector3(0.0, 2.39, 0.02), Vector3(0.94, 0.012, 0.42), DUST, 0.9)
	return s.mesh("manor_wardrobe", 0.015, 2200)


## A claw-foot tub full to the waterline of something black and still, a rust stain run down from
## the tap and a dark ring where it has stood for years.
static func _tub() -> ArrayMesh:
	var s := Sculpt.new().noise_scale(10.0)
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			s.ellipsoid(Vector3(x * 0.68, 0.14, z * 0.28), Vector3(0.06, 0.12, 0.06), IRON, 0.02, 0.5)
			s.ellipsoid(Vector3(x * 0.7, 0.035, z * 0.29), Vector3(0.05, 0.035, 0.05), IRON, 0.02, 0.5)
	s.box(Vector3(0.0, 0.47, 0.0), Vector3(0.95, 0.27, 0.42), 0.26, PORCELAIN, 0.02, 0.3, 0.002)
	s.box(Vector3(0.0, 0.72, 0.0), Vector3(0.98, 0.03, 0.45), 0.03, PORCELAIN, 0.02, 0.3)
	s.carve_ellipsoid(Vector3(0.0, 0.78, 0.0), Vector3(0.9, 0.52, 0.37), PORCELAIN, 0.02)
	s.box(Vector3(0.0, 0.5, 0.0), Vector3(0.86, 0.015, 0.33), 0.0, Color(0.015, 0.02, 0.015), 0.0, 0.08)  # the water
	s.paint_box(Vector3(0.0, 0.54, 0.0), Vector3(0.9, 0.025, 0.4), Color(0.2, 0.13, 0.07), 0.6)
	s.paint_box(Vector3(0.0, 0.24, 0.0), Vector3(1.0, 0.1, 0.5), SHROUD_DIRT, 0.8)
	s.tube_add(PackedVector3Array([Vector3(-0.93, 0.7, 0.0), Vector3(-1.0, 0.88, 0.0), Vector3(-0.95, 0.98, 0.0), Vector3(-0.84, 0.92, 0.0)]), PackedFloat32Array([0.022, 0.02, 0.018, 0.016]), BRASS, 0.4, 7)
	s.paint_capsule(Vector3(-0.86, 0.7, 0.0), Vector3(-0.55, 0.52, 0.0), 0.05, 0.03, RUST, 0.6)
	return s.mesh("manor_tub", 0.015, 2400)
