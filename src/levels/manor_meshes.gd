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
}
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

static var _meshes: Dictionary = {}


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
	s.ellipsoid(Vector3(0.0, 0.03, 0.0), Vector3(0.28, 0.08, 0.28), EARTH, 0.05, 0.98, 0.02)
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
