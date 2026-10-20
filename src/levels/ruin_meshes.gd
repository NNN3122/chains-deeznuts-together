class_name RuinMeshes
extends RefCounted
## Carrow Heights' wreckage, sculpted (the user: "don't make it look like just blocks... make it look
## like it's part of the building that somewhat got destroyed"): broken floor slabs bristling with
## rebar, a rusted I-beam torn at one end, snapped concrete columns and crumbled chimney crowns,
## rubble heaps, a toppled utility pole, a split water main, a collapsed slab leaning on a wall, and
## crumbled chunks of parapet. Built with Sculpt and cached on disk like the props; drawn by
## LevelKit.BoxBatch.add_prop (PropMeshes.mesh hands any "ruin_" key here). Collision is never the
## mesh: HordeArena lays plain boxes and cylinders under them, a little inside the broken edges.
## Every piece is centred on its origin unless noted, its length along Z, native sizes in NATIVE.

const CELL: float = 0.04
const CELL_FINE: float = 0.022
const CONCRETE: Color = Color(0.44, 0.42, 0.39)
const CONCRETE_DARK: Color = Color(0.24, 0.23, 0.22)
const BRICK: Color = Color(0.4, 0.19, 0.13)
const RUST: Color = Color(0.33, 0.15, 0.07)
const STEEL: Color = Color(0.22, 0.21, 0.21)
const SOOT: Color = Color(0.06, 0.055, 0.05)
const WOOD: Color = Color(0.2, 0.14, 0.09)
const SAC: Color = Color(0.78, 0.74, 0.6)
const HOLE: Color = Color(0.015, 0.01, 0.01)

## Native size of each piece (m): scale a transform by size / NATIVE to fit a box.
const NATIVE: Dictionary = {
	"ruin_slab": Vector3(2.0, 0.32, 2.0),
	"ruin_beam": Vector3(0.42, 0.36, 3.0),
	"ruin_stump": Vector3(1.0, 0.7, 1.0),  # its top at +0.35: a broken crown with a flat-ish middle
	"ruin_chimney": Vector3(1.0, 0.7, 1.0),
	"ruin_rubble": Vector3(2.0, 0.9, 2.0),  # origin at its base
	"ruin_pole": Vector3(0.4, 0.4, 8.0),
	"ruin_main": Vector3(0.6, 0.6, 8.0),
	"ruin_ramp": Vector3(2.4, 0.36, 6.0),
	"ruin_lip": Vector3(0.4, 0.5, 1.6),  # a stretch of knee-high parapet, cracked and chipped
	"ruin_lip_broken": Vector3(0.4, 0.5, 1.6),  # the same, half of it fallen away
	"ruin_breach": Vector3(3.0, 2.6, 0.9),  # a hole blown in a facade, +Z out of the wall, origin on the wall's face
	"ruin_embers": Vector3(1.0, 0.35, 1.0),  # a smouldering heap (drawn glowing), origin at its base
	"ruin_nest": Vector3(1.8, 0.7, 1.8),  # a vent burst open from inside, egg sacs round it; origin at its base
}

static var _meshes: Dictionary = {}


static func mesh(key: String) -> ArrayMesh:
	if _meshes.has(key):
		return _meshes[key]
	var m: ArrayMesh
	match key:
		"ruin_slab": m = _slab()
		"ruin_beam": m = _beam()
		"ruin_stump": m = _stump(CONCRETE, "ruin_stump")
		"ruin_chimney": m = _stump(BRICK, "ruin_chimney")
		"ruin_rubble": m = _rubble()
		"ruin_pole": m = _pole()
		"ruin_main": m = _main()
		"ruin_ramp": m = _ramp()
		"ruin_lip": m = _lip(false)
		"ruin_lip_broken": m = _lip(true)
		"ruin_breach": m = _breach()
		"ruin_embers": m = _embers()
		"ruin_nest": m = _nest()
		_:
			push_warning("RuinMeshes: no piece '%s'" % key)
			m = Sculpt.new().box(Vector3.ZERO, Vector3.ONE * 0.1, 0.02, Color.MAGENTA).mesh("ruin_missing", 0.02, 100)
	_meshes[key] = m
	return m


## A transform that fits piece `key` to a box of `size` at `center`, turned by `basis`.
static func fit(key: String, center: Vector3, size: Vector3, basis: Basis = Basis.IDENTITY) -> Transform3D:
	var n: Vector3 = NATIVE[key]
	return Transform3D(basis * Basis.from_scale(Vector3(size.x / n.x, size.y / n.y, size.z / n.z)), center)


## A few bars of rebar out of a broken face: bent, rusted, splayed.
static func _rebar(s: Sculpt, rng: RandomNumberGenerator, at: Vector3, out: Vector3, count: int, length: float) -> void:
	var side := out.cross(Vector3.UP).normalized()
	if side.length() < 0.1:
		side = Vector3.RIGHT
	for k in count:
		var base := at + side * rng.randf_range(-0.6, 0.6) * 0.5 + Vector3.UP * rng.randf_range(-0.05, 0.05)
		var l := length * rng.randf_range(0.5, 1.0)
		var bend := Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.5, 0.15), rng.randf_range(-0.3, 0.3))
		var mid := base + out * l * 0.5
		var tip := base + out * l + bend * l
		s.tube_add(PackedVector3Array([base - out * 0.05, mid, tip]), PackedFloat32Array([0.014, 0.013, 0.011]), RUST, 0.7, 5)


## A chunk of floor slab: a thick concrete plate with bites taken out of its edges, cracks, a
## scorch, and rebar sticking out of the breaks.
static func _slab() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 911
	var s := Sculpt.new().noise_scale(6.0)
	s.box(Vector3.ZERO, Vector3(1.0, 0.16, 1.0), 0.03, CONCRETE, 0.02, 0.9, 0.025)
	# Bites out of the edges: the floor broke, it wasn't cut.
	for k in 7:
		var a := rng.randf() * TAU
		var e := Vector3(cos(a), 0.0, sin(a))
		e = e / maxf(absf(e.x), absf(e.z))  # out to the square's edge
		s.carve_ellipsoid(e * 1.0 + Vector3(0.0, rng.randf_range(-0.1, 0.1), 0.0), Vector3(rng.randf_range(0.2, 0.42), 0.3, rng.randf_range(0.2, 0.42)), CONCRETE_DARK, 0.04)
		if k < 4:
			_rebar(s, rng, e * 0.82, e, 3, 0.45)
	for k in 3:
		var c := Vector3(rng.randf_range(-0.7, 0.7), 0.16, rng.randf_range(-0.7, 0.7))
		s.paint_ellipsoid(c, Vector3(rng.randf_range(0.15, 0.4), 0.06, rng.randf_range(0.15, 0.4)), CONCRETE_DARK, 0.95)
	s.paint_ellipsoid(Vector3(0.3, 0.16, -0.2), Vector3(0.5, 0.05, 0.3), SOOT, 1.0)
	# A crack across the top, a dark seam.
	s.paint_box(Vector3(0.0, 0.16, 0.1), Vector3(0.9, 0.02, 0.015), SOOT, 1.0, Basis.from_euler(Vector3(0.0, 0.4, 0.0)))
	return s.mesh("ruin_slab", CELL, 1400)


## A rolled-steel I-beam, rusted through in patches, bolt heads along the flange, one end torn and
## curled where it tore off its column.
static func _beam() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 912
	var s := Sculpt.new().noise_scale(10.0)
	for y: float in [0.155, -0.155]:
		s.box(Vector3(0.0, y, 0.0), Vector3(0.21, 0.025, 1.5), 0.008, STEEL, 0.01, 0.6, 0.004)
	s.box(Vector3.ZERO, Vector3(0.028, 0.14, 1.5), 0.006, STEEL, 0.015, 0.6, 0.003)
	for k in 6:
		s.paint_ellipsoid(Vector3(rng.randf_range(-0.2, 0.2), rng.randf_range(-0.18, 0.18), rng.randf_range(-1.4, 1.4)), Vector3(0.18, 0.12, rng.randf_range(0.15, 0.4)), RUST, 0.85)
	for k in 5:
		s.ellipsoid(Vector3(0.15 if k % 2 == 0 else -0.15, 0.18, -1.2 + 0.6 * float(k)), Vector3(0.022, 0.012, 0.022), RUST, 0.005, 0.7)
	# The torn end: the flanges ripped ragged.
	s.carve_ellipsoid(Vector3(0.12, 0.16, 1.52), Vector3(0.16, 0.06, 0.18), RUST, 0.02)
	s.carve_ellipsoid(Vector3(-0.15, -0.16, 1.5), Vector3(0.12, 0.06, 0.14), RUST, 0.02)
	s.tube_add(PackedVector3Array([Vector3(-0.18, 0.155, 1.42), Vector3(-0.2, 0.2, 1.56), Vector3(-0.14, 0.3, 1.62)]), PackedFloat32Array([0.018, 0.014, 0.008]), RUST, 0.7, 5)
	return s.mesh("ruin_beam", CELL_FINE, 1600)


## The broken top of a column or a chimney: a square shaft whose crown crumbled, chunks bitten off
## the corners, rebar (concrete) or a sooted flue (brick) showing. The middle stays flat enough to
## land on.
static func _stump(col: Color, name: String) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 913 if col == CONCRETE else 914
	var s := Sculpt.new().noise_scale(7.0)
	s.box(Vector3.ZERO, Vector3(0.5, 0.35, 0.5), 0.03, col, 0.02, 0.92, 0.02)
	for k in 4:
		var a := (float(k) + rng.randf_range(0.1, 0.9)) / 4.0 * TAU
		var c := Vector3(cos(a) * 0.55, 0.38, sin(a) * 0.55)
		s.carve_ellipsoid(c, Vector3(rng.randf_range(0.18, 0.3), rng.randf_range(0.15, 0.3), rng.randf_range(0.18, 0.3)), col.darkened(0.3), 0.03)
	if col == CONCRETE:
		for k in 4:
			var cx := 0.38 if k % 2 == 0 else -0.38
			var cz := 0.38 if k < 2 else -0.38
			_rebar(s, rng, Vector3(cx, 0.3, cz), Vector3(0.0, 1.0, 0.0), 1, 0.5)
	else:
		# Bricks: courses picked out in mortar, soot round the old flue.
		for y in 4:
			s.paint_box(Vector3(0.0, -0.3 + 0.17 * float(y), 0.0), Vector3(0.52, 0.012, 0.52), Color(0.32, 0.3, 0.28), 0.95)
		s.paint_ellipsoid(Vector3(0.0, 0.35, 0.0), Vector3(0.28, 0.12, 0.28), SOOT, 1.0)
	s.paint_ellipsoid(Vector3(0.2, 0.0, 0.5), Vector3(0.2, 0.3, 0.08), SOOT, 1.0)  # a scorch down one face
	return s.mesh(name, CELL, 1000)


## A heap of broken concrete and brick, a slab end sticking up, rebar.
static func _rubble() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 915
	var s := Sculpt.new().noise_scale(8.0)
	s.ellipsoid(Vector3(0.0, 0.0, 0.0), Vector3(0.95, 0.32, 0.9), CONCRETE_DARK, 0.1, 0.95, 0.05)
	for k in 9:
		var c := Vector3(rng.randf_range(-0.7, 0.7), rng.randf_range(0.1, 0.45), rng.randf_range(-0.7, 0.7))
		var h := Vector3(rng.randf_range(0.12, 0.28), rng.randf_range(0.08, 0.18), rng.randf_range(0.12, 0.28))
		var b := Basis.from_euler(Vector3(rng.randf_range(-0.6, 0.6), rng.randf() * TAU, rng.randf_range(-0.6, 0.6)))
		s.box(c, h, 0.02, CONCRETE if k % 3 != 0 else BRICK, 0.03, 0.9, 0.015, b)
	s.box(Vector3(0.3, 0.45, -0.2), Vector3(0.45, 0.06, 0.3), 0.02, CONCRETE, 0.03, 0.9, 0.015, Basis.from_euler(Vector3(0.0, 0.5, 0.9)))
	_rebar(s, rng, Vector3(0.2, 0.5, -0.1), Vector3(0.3, 1.0, 0.2).normalized(), 3, 0.6)
	return s.mesh("ruin_rubble", CELL, 1400)


## A utility pole that came down across the gap: tarred wood, a cross-arm near one end with its
## glass insulators, a snapped end.
static func _pole() -> ArrayMesh:
	var s := Sculpt.new().noise_scale(9.0)
	s.capsule(Vector3(0.0, 0.0, -3.9), Vector3(0.0, 0.0, 3.9), 0.2, 0.17, WOOD, 0.02, 0.85, 0.012)
	for k in 6:
		s.paint_ellipsoid(Vector3(0.0, 0.12, -3.2 + 1.3 * float(k)), Vector3(0.24, 0.12, 0.35), WOOD.darkened(0.4), 0.9)
	s.box(Vector3(0.0, 0.0, 3.2), Vector3(0.75, 0.05, 0.06), 0.01, WOOD.darkened(0.2), 0.02, 0.8, 0.004, Basis.from_euler(Vector3(0.0, 0.0, 0.5)))
	for x: float in [-0.6, 0.6]:
		s.ellipsoid(Vector3(x * cos(0.5), x * sin(0.5) + 0.07, 3.2), Vector3(0.035, 0.05, 0.035), Color(0.3, 0.4, 0.35), 0.01, 0.15)
	# The snapped end: splinters.
	s.carve_ellipsoid(Vector3(0.12, 0.05, -4.0), Vector3(0.14, 0.2, 0.25), WOOD.darkened(0.5), 0.03)
	return s.mesh("ruin_pole", CELL_FINE, 1400)


## A water main torn out of the street and dropped across: a fat rusted pipe, bolted collars every
## two metres, split open along one seam.
static func _main() -> ArrayMesh:
	var s := Sculpt.new().noise_scale(9.0)
	s.capsule(Vector3(0.0, 0.0, -3.9), Vector3(0.0, 0.0, 3.9), 0.3, 0.3, STEEL.lerp(RUST, 0.5), 0.02, 0.75, 0.01)
	for k in 4:
		var z := -3.0 + 2.0 * float(k)
		s.capsule(Vector3(0.0, 0.0, z - 0.05), Vector3(0.0, 0.0, z + 0.05), 0.34, 0.34, RUST, 0.01, 0.8, 0.004)
	for k in 5:
		s.paint_ellipsoid(Vector3(0.0, 0.0, -3.5 + 1.7 * float(k)), Vector3(0.35, 0.35, 0.4), RUST.darkened(0.3), 0.9)
	s.carve_box(Vector3(0.25, -0.1, 1.0), Vector3(0.08, 0.08, 1.1), SOOT, 0.02)  # the split
	return s.mesh("ruin_main", CELL_FINE, 1600)


## A floor slab that came down and lies against a wall: long, cracked across, its top end broken
## off ragged, rebar out of the break, scuffed where things slid down it.
static func _ramp() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 916
	var s := Sculpt.new().noise_scale(5.0)
	s.box(Vector3.ZERO, Vector3(1.2, 0.18, 3.0), 0.03, CONCRETE, 0.02, 0.9, 0.03)
	for k in 5:
		var sx := -1.0 if k % 2 == 0 else 1.0
		s.carve_ellipsoid(Vector3(sx * 1.25, rng.randf_range(-0.1, 0.1), rng.randf_range(-2.6, 2.6)), Vector3(0.22, 0.3, rng.randf_range(0.3, 0.6)), CONCRETE_DARK, 0.04)
	s.carve_ellipsoid(Vector3(-0.5, 0.0, 3.1), Vector3(0.6, 0.3, 0.3), CONCRETE_DARK, 0.04)
	s.carve_ellipsoid(Vector3(0.7, 0.0, 3.05), Vector3(0.4, 0.3, 0.25), CONCRETE_DARK, 0.04)
	_rebar(s, rng, Vector3(0.0, 0.0, 2.8), Vector3(0.0, 0.0, 1.0), 6, 0.55)
	s.paint_box(Vector3(0.0, 0.18, 0.4), Vector3(1.1, 0.02, 0.02), SOOT, 1.0, Basis.from_euler(Vector3(0.0, 0.25, 0.0)))
	s.paint_box(Vector3(0.0, 0.18, -1.6), Vector3(1.1, 0.02, 0.02), SOOT, 1.0, Basis.from_euler(Vector3(0.0, -0.4, 0.0)))
	s.paint_ellipsoid(Vector3(0.2, 0.18, -0.5), Vector3(0.35, 0.05, 1.8), CONCRETE.lightened(0.15), 0.8)
	return s.mesh("ruin_ramp", CELL, 1800)


## A hole blown through a facade: a ragged rim of broken concrete standing a hand proud of the wall,
## the burnt-out room behind it black, the floor slab inside snapped and sagging out of the hole
## with its rebar, scorch licking up the wall above.
static func _breach() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 919
	var s := Sculpt.new().noise_scale(6.0)
	s.box(Vector3(0.0, 0.0, 0.3), Vector3(1.5, 1.3, 0.1), 0.03, CONCRETE_DARK, 0.02, 0.95, 0.03)
	# The opening: overlapping bites, so its edge is ragged, not round.
	s.carve_ellipsoid(Vector3(0.0, 0.0, 0.3), Vector3(0.95, 0.8, 0.2), SOOT, 0.05)
	for k in 7:
		var a := float(k) / 7.0 * TAU + rng.randf_range(-0.3, 0.3)
		s.carve_ellipsoid(Vector3(cos(a) * 0.8, sin(a) * 0.65, 0.3), Vector3(rng.randf_range(0.2, 0.42), rng.randf_range(0.18, 0.38), 0.2), SOOT, 0.04)
	# The dark room behind.
	s.box(Vector3(0.0, 0.0, 0.06), Vector3(1.25, 1.05, 0.04), 0.02, SOOT, 0.02, 1.0, 0.0)
	# The floor slab inside, snapped and sagging out over the sill, rebar hanging off it.
	s.box(Vector3(0.0, -0.55, 0.32), Vector3(0.9, 0.08, 0.3), 0.02, CONCRETE, 0.03, 0.9, 0.02, Basis.from_euler(Vector3(0.35, 0.1, 0.0)))
	_rebar(s, rng, Vector3(0.0, -0.66, 0.55), Vector3(0.0, -0.6, 1.0).normalized(), 5, 0.6)
	# Scorch up the wall above it.
	s.paint_ellipsoid(Vector3(0.0, 1.0, 0.4), Vector3(1.0, 0.7, 0.2), SOOT, 1.0)
	s.paint_ellipsoid(Vector3(0.0, 0.0, 0.4), Vector3(1.25, 1.1, 0.2), SOOT.lerp(CONCRETE_DARK, 0.5), 1.0)
	return s.mesh("ruin_breach", CELL, 1800)


## A vent burst open from inside: its steel housing split and peeled back, a black hole going down,
## and round the hole pale wet egg sacs in clusters, strands of something stretched between them.
static func _nest() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 921
	var s := Sculpt.new().noise_scale(9.0)
	# The housing, split into four leaves peeled outward.
	for k in 4:
		var a := float(k) * TAU / 4.0 + 0.4
		var out := Vector3(cos(a), 0.0, sin(a))
		s.box(out * 0.5 + Vector3.UP * 0.22, Vector3(0.3, 0.2, 0.03), 0.01, STEEL, 0.02, 0.6, 0.006, Basis(Vector3.UP, -a + PI * 0.5) * Basis.from_euler(Vector3(-0.9, 0.0, 0.0)))
	s.ellipsoid(Vector3(0.0, 0.05, 0.0), Vector3(0.7, 0.12, 0.7), CONCRETE_DARK, 0.06, 0.95, 0.03)
	s.carve_ellipsoid(Vector3(0.0, 0.1, 0.0), Vector3(0.38, 0.4, 0.38), HOLE, 0.05)
	# Egg sacs: pale, glistening, in clumps round the rim.
	for k in 14:
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.42, 0.8)
		var c := Vector3(cos(a) * r, rng.randf_range(0.08, 0.2), sin(a) * r)
		var sz := rng.randf_range(0.06, 0.12)
		s.ellipsoid(c, Vector3(sz, sz * 1.3, sz), SAC, 0.03, 0.15, 0.004)
	for k in 6:
		var a := rng.randf() * TAU
		var b := a + rng.randf_range(0.5, 1.5)
		s.tube_add(PackedVector3Array([Vector3(cos(a) * 0.5, 0.2, sin(a) * 0.5), Vector3(cos((a + b) * 0.5) * 0.35, 0.32, sin((a + b) * 0.5) * 0.35), Vector3(cos(b) * 0.55, 0.18, sin(b) * 0.55)]), PackedFloat32Array([0.006, 0.004, 0.006]), SAC.darkened(0.2), 0.2, 4)
	return s.mesh("ruin_nest", CELL_FINE, 1600)


## Smouldering rubble: a low heap of broken bits. It is drawn with a glowing material.
static func _embers() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 920
	var s := Sculpt.new().noise_scale(10.0)
	s.ellipsoid(Vector3.ZERO, Vector3(0.48, 0.12, 0.45), SOOT, 0.06, 1.0, 0.03)
	for k in 7:
		var c := Vector3(rng.randf_range(-0.35, 0.35), rng.randf_range(0.05, 0.18), rng.randf_range(-0.35, 0.35))
		s.box(c, Vector3(rng.randf_range(0.06, 0.14), rng.randf_range(0.04, 0.08), rng.randf_range(0.06, 0.14)), 0.015, Color(1.0, 0.45, 0.12), 0.03, 0.8, 0.01, Basis.from_euler(Vector3(rng.randf(), rng.randf() * TAU, rng.randf())))
	return s.mesh("ruin_embers", CELL_FINE, 700)


## A stretch of parapet: chipped along its coping, cracked; the broken one has its top half fallen
## away into a ragged step.
static func _lip(broken: bool) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 917 if broken else 918
	var s := Sculpt.new().noise_scale(9.0)
	s.box(Vector3.ZERO, Vector3(0.2, 0.25, 0.8), 0.025, CONCRETE, 0.01, 0.92, 0.012)
	s.box(Vector3(0.0, 0.25, 0.0), Vector3(0.23, 0.03, 0.8), 0.01, CONCRETE.lightened(0.08), 0.01, 0.85, 0.006)
	for k in 3:
		s.carve_ellipsoid(Vector3(rng.randf_range(-0.2, 0.2), 0.27, rng.randf_range(-0.7, 0.7)), Vector3(0.08, 0.06, 0.1), CONCRETE_DARK, 0.02)
	if broken:
		s.carve_ellipsoid(Vector3(0.0, 0.32, rng.randf_range(-0.2, 0.3)), Vector3(0.4, 0.28, 0.55), CONCRETE_DARK, 0.04)
	s.paint_box(Vector3(0.2, 0.0, 0.1), Vector3(0.02, 0.2, 0.01), SOOT, 1.0, Basis.from_euler(Vector3(0.3, 0.0, 0.0)))
	return s.mesh("ruin_lip_broken" if broken else "ruin_lip", CELL_FINE, 700)
