class_name Sculpt
extends RefCounted
## Organic meshes from blended shapes. A sculpt is a list of signed-distance primitives (tapered
## capsules, ellipsoids, rounded boxes) that melt into each other with a smooth minimum, carves that
## cut sockets and mouths out of them, and paints that only colour what they touch. `build` samples
## the field on a grid and polygonizes it with surface nets: one smooth closed skin, normals from the
## field's gradient, a colour per vertex (alpha = roughness). Thin parts (legs, fingers, claws,
## antennae) come from `tube`: a smooth tapered tube along a curve.
## Every mesh is built once and cached: in memory, then as a .res under res://assets/meshes (when
## the project folder is writable) or user://mesh_cache, keyed by a hash of the recipe, so a change
## to a recipe rebuilds that mesh and nothing else.
## Mesh vertex colour alpha carries roughness for `material()`'s shader.

const VERSION: int = 4
const RES_DIR: String = "res://assets/meshes"
const USER_DIR: String = "user://mesh_cache"
enum Kind { CAPSULE, ELLIPSOID, BOX }
enum Op { ADD, CARVE, PAINT }

const SHADER: String = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform float wet = 0.0;          // 0..1: a slick, glistening coat (flesh, chitin)
uniform float pores = 0.25;       // fine surface grain
uniform float rim = 0.0;          // a cold edge light so a dark shape reads against darker air
uniform vec3 rim_col : source_color = vec3(0.45, 0.55, 0.7);
uniform float veins = 0.0;        // dark branching marks under pale skin
uniform float sss = 0.0;
uniform vec3 tint : source_color = vec3(1.0);
// A photo surface's grain and relief under the painted colours (the manor's stone, bark, wood),
// projected from three sides in the mesh's own space so it rides along when the mesh moves.
uniform sampler2D detail_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D detail_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float detail = 0.0;       // 0 (off: every monster) .. 1
uniform float detail_span = 1.0;  // mesh units per repeat
uniform float detail_bump = 1.0;
varying vec3 v_obj;
varying vec3 v_onrm;

float hash(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float vnoise(vec3 x) {
	vec3 i = floor(x); vec3 f = fract(x); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1,0,0)), f.x), mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x), mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y), f.z);
}
void vertex() { v_obj = VERTEX; v_onrm = NORMAL; }
void fragment() {
	// Vertex colours are authored in sRGB; lighting wants linear.
	vec3 srgb = COLOR.rgb;
	vec3 col = mix(srgb / 12.92, pow((srgb + 0.055) / 1.055, vec3(2.4)), step(0.04045, srgb)) * tint;
	float n1 = vnoise(v_obj * 38.0);
	float n2 = vnoise(v_obj * 9.0);
	col *= 1.0 - pores * 0.35 + pores * 0.5 * n1;
	col *= 0.9 + 0.2 * n2;
	if (veins > 0.0) {
		float v = abs(vnoise(v_obj * 14.0) - 0.5) + abs(vnoise(v_obj * 31.0 + 7.0) - 0.5) * 0.5;
		col = mix(col, col * vec3(0.35, 0.3, 0.4), veins * (1.0 - smoothstep(0.02, 0.07, v)));
	}
	if (detail > 0.0) {
		vec3 an = normalize(v_onrm);
		vec3 w = pow(abs(an), vec3(4.0));
		w /= w.x + w.y + w.z;
		vec3 s = vec3(an.x < 0.0 ? -1.0 : 1.0, an.y < 0.0 ? -1.0 : 1.0, an.z < 0.0 ? -1.0 : 1.0);
		vec2 ux = vec2(-v_obj.z * s.x, -v_obj.y) / detail_span;
		vec2 uy = vec2(v_obj.x * s.y, v_obj.z) / detail_span;
		vec2 uz = vec2(v_obj.x * s.z, -v_obj.y) / detail_span;
		vec3 photo = texture(detail_albedo, ux).rgb * w.x + texture(detail_albedo, uy).rgb * w.y + texture(detail_albedo, uz).rgb * w.z;
		vec3 lw = vec3(0.299, 0.587, 0.114);
		float ml = max(dot(textureLod(detail_albedo, vec2(0.5), 12.0).rgb, lw), 0.01);
		col *= mix(1.0, clamp(dot(photo, lw) / ml, 0.15, 2.2), detail);
		vec2 nx = (texture(detail_normal, ux).rg * 2.0 - 1.0) * detail_bump;
		vec2 ny = (texture(detail_normal, uy).rg * 2.0 - 1.0) * detail_bump;
		vec2 nz = (texture(detail_normal, uz).rg * 2.0 - 1.0) * detail_bump;
		vec3 bend = (vec3(0.0, 0.0, -s.x) * nx.x + vec3(0.0, 1.0, 0.0) * nx.y) * w.x
			+ (vec3(s.y, 0.0, 0.0) * ny.x + vec3(0.0, 0.0, -1.0) * ny.y) * w.y
			+ (vec3(s.z, 0.0, 0.0) * nz.x + vec3(0.0, 1.0, 0.0) * nz.y) * w.z;
		NORMAL = normalize((VIEW_MATRIX * vec4(normalize(MODEL_NORMAL_MATRIX * normalize(an + bend * detail)), 0.0)).xyz);
	}
	ALBEDO = col;
	float r = clamp(COLOR.a, 0.04, 1.0);
	ROUGHNESS = mix(r, r * 0.25, wet * (0.6 + 0.4 * n2));
	SPECULAR = 0.5 + 0.4 * wet;
	if (sss > 0.0) { SSS_STRENGTH = sss; }
	if (rim > 0.0) {
		float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
		EMISSION = rim_col * f * rim;
	}
}
"""

static var _cache: Dictionary = {}
static var _shader: Shader

var _prims: Array = []  # [kind, op, blend, color, roughness, noise, data...]
var _noise_freq: float = 18.0
var _tubes: Array = []  # [points, radii, colour, roughness, sides]: thin parts added to the skin as tubes


# --- Recipe -----------------------------------------------------------------------------------

## A capsule from a to b, radius ra at a and rb at b (a round cone). blend: how far it melts into
## what is already there (m). noise: lumps on its surface (m).
func capsule(a: Vector3, b: Vector3, ra: float, rb: float, color: Color, blend: float = 0.03, rough: float = 0.6, noise: float = 0.0, op: int = Op.ADD) -> Sculpt:
	_prims.append([Kind.CAPSULE, op, blend, color, rough, noise, a, b, ra, rb])
	return self


## An ellipsoid at c with half-extents r, turned by basis b.
func ellipsoid(c: Vector3, r: Vector3, color: Color, blend: float = 0.03, rough: float = 0.6, noise: float = 0.0, b: Basis = Basis.IDENTITY, op: int = Op.ADD) -> Sculpt:
	_prims.append([Kind.ELLIPSOID, op, blend, color, rough, noise, c, r, b.inverse()])
	return self


## A box at c with half-extents h, its edges rounded by round, turned by basis b.
func box(c: Vector3, h: Vector3, round: float, color: Color, blend: float = 0.02, rough: float = 0.6, noise: float = 0.0, b: Basis = Basis.IDENTITY, op: int = Op.ADD) -> Sculpt:
	_prims.append([Kind.BOX, op, blend, color, round, noise, c, h, b.inverse(), rough])
	return self


func carve_capsule(a: Vector3, b: Vector3, ra: float, rb: float, color: Color, blend: float = 0.01) -> Sculpt:
	return capsule(a, b, ra, rb, color, blend, 0.8, 0.0, Op.CARVE)


func carve_ellipsoid(c: Vector3, r: Vector3, color: Color, blend: float = 0.01, b: Basis = Basis.IDENTITY) -> Sculpt:
	return ellipsoid(c, r, color, blend, 0.8, 0.0, b, Op.CARVE)


func carve_box(c: Vector3, h: Vector3, color: Color, blend: float = 0.0, b: Basis = Basis.IDENTITY) -> Sculpt:
	return box(c, h, 0.0, color, blend, 0.8, 0.0, b, Op.CARVE)


## Colour (and roughness) for whatever surface lies inside this ellipsoid; no shape of its own.
func paint_ellipsoid(c: Vector3, r: Vector3, color: Color, rough: float = 0.6, b: Basis = Basis.IDENTITY) -> Sculpt:
	return ellipsoid(c, r, color, 0.0, rough, 0.0, b, Op.PAINT)


func paint_box(c: Vector3, h: Vector3, color: Color, rough: float = 0.6, b: Basis = Basis.IDENTITY) -> Sculpt:
	_prims.append([Kind.BOX, Op.PAINT, 0.0, color, 0.0, 0.0, c, h, b.inverse(), rough])
	return self


func paint_capsule(a: Vector3, b: Vector3, ra: float, rb: float, color: Color, rough: float = 0.6) -> Sculpt:
	return capsule(a, b, ra, rb, color, 0.0, rough, 0.0, Op.PAINT)


## A thin tapered tube through the points (fingers, claws, legs, fangs), part of this mesh. steps:
## rings per stretch between points (1 for a straight rod).
func tube_add(points: PackedVector3Array, radii: PackedFloat32Array, color: Color, rough: float = 0.5, sides: int = 8, steps: int = 4) -> Sculpt:
	# The default is left out of the entry so recipes written before steps existed keep their hash.
	_tubes.append([points, radii, color, rough, sides] if steps == 4 else [points, radii, color, rough, sides, steps])
	return self


## Arrays plus every tube of the recipe.
func _with_tubes(arrays: Array) -> Array:
	if _tubes.is_empty():
		return arrays
	var b := Builder.new()
	b.add(arrays)
	for t in _tubes:
		b.add(tube(t[0], t[1], t[2], t[3], t[4], t[5] if t.size() > 5 else 4))
	return [b.verts, b.norms, b.cols, b.idx]


## The scale of the surface lumps (cycles per metre).
func noise_scale(freq: float) -> Sculpt:
	_noise_freq = freq
	return self


# --- Building ---------------------------------------------------------------------------------

## The mesh for this recipe at this grid spacing, from the cache when it has been built before.
func mesh(name: String, cell: float, max_tris: int = 3000) -> ArrayMesh:
	var key := "%s_%08x" % [name, hash(str(_prims) + str(_tubes) + "|%.4f|%.2f|%d|%d" % [cell, _noise_freq, VERSION, max_tris]) & 0xFFFFFFFF]
	if _cache.has(key):
		return _cache[key]
	var m: ArrayMesh = null
	for dir in [RES_DIR, USER_DIR]:
		var path := "%s/%s.res" % [dir, key]
		if ResourceLoader.exists(path):
			m = load(path) as ArrayMesh
			if m != null:
				break
	if m == null:
		m = to_mesh(build(cell), max_tris)
		_save(m, key)
	_cache[key] = m
	return m


## A mesh built some other way (several sculpts and tubes put together), cached under key like a
## sculpt: in memory, then on disk. Change the key when the recipe changes.
static func cached(key: String, make: Callable) -> ArrayMesh:
	if _cache.has(key):
		return _cache[key]
	var m: ArrayMesh = null
	for dir in [RES_DIR, USER_DIR]:
		var path := "%s/%s.res" % [dir, key]
		if ResourceLoader.exists(path):
			m = load(path) as ArrayMesh
			if m != null:
				break
	if m == null:
		m = make.call()
		_save(m, key)
	_cache[key] = m
	return m


static func _save(m: ArrayMesh, key: String) -> void:
	for dir in [RES_DIR, USER_DIR]:
		if DirAccess.make_dir_recursive_absolute(dir) != OK and not DirAccess.dir_exists_absolute(dir):
			continue
		if ResourceSaver.save(m, "%s/%s.res" % [dir, key], ResourceSaver.FLAG_COMPRESS) == OK:
			return


## Samples the field and polygonizes it. Returns [vertices, normals, colours, indices].
func build(cell: float) -> Array:
	# Bounds: every added shape, grown by its blend and lumps, plus a margin.
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for p in _prims:
		if p[1] != Op.ADD:
			continue
		var bb := _prim_aabb(p)
		lo = lo.min(bb.position)
		hi = hi.max(bb.end)
	if lo == Vector3.INF:
		return _with_tubes([PackedVector3Array(), PackedVector3Array(), PackedColorArray(), PackedInt32Array()])
	lo -= Vector3.ONE * cell * 2.0
	hi += Vector3.ONE * cell * 2.0
	var nx := int(ceil((hi.x - lo.x) / cell)) + 1
	var ny := int(ceil((hi.y - lo.y) / cell)) + 1
	var nz := int(ceil((hi.z - lo.z) / cell)) + 1
	var total := nx * ny * nz
	var g := PackedFloat32Array()
	g.resize(total)
	g.fill(1.0e3)
	# Each shape only touches the grid points inside its own box: far cheaper than every shape at
	# every point.
	for p in _prims:
		var op: int = p[1]
		if op == Op.PAINT:
			continue
		var bb := _prim_aabb(p)
		# Two cells past the shape's box: the corners just outside its skin need true distances too.
		var x0 := clampi(int(floor((bb.position.x - lo.x) / cell)) - 2, 0, nx - 1)
		var y0 := clampi(int(floor((bb.position.y - lo.y) / cell)) - 2, 0, ny - 1)
		var z0 := clampi(int(floor((bb.position.z - lo.z) / cell)) - 2, 0, nz - 1)
		var x1 := clampi(int(ceil((bb.end.x - lo.x) / cell)) + 2, 0, nx - 1)
		var y1 := clampi(int(ceil((bb.end.y - lo.y) / cell)) + 2, 0, ny - 1)
		var z1 := clampi(int(ceil((bb.end.z - lo.z) / cell)) + 2, 0, nz - 1)
		var k: float = p[2]
		var amp: float = p[5]
		for z in range(z0, z1 + 1):
			var pz := lo.z + float(z) * cell
			for y in range(y0, y1 + 1):
				var py := lo.y + float(y) * cell
				var row := nx * (y + ny * z)
				for x in range(x0, x1 + 1):
					var q := Vector3(lo.x + float(x) * cell, py, pz)
					var d := _sdf(p, q)
					if amp > 0.0:
						d += amp * (_noise(q * _noise_freq) - 0.5) * 2.0
					var i := row + x
					var v := g[i]
					if op == Op.ADD:
						g[i] = _smin(v, d, k) if k > 0.0 else minf(v, d)
					else:
						g[i] = -_smin(-v, d, k) if k > 0.0 else maxf(v, -d)
	return _with_tubes(_surface_nets(g, nx, ny, nz, lo, cell))


func _surface_nets(g: PackedFloat32Array, nx: int, ny: int, nz: int, lo: Vector3, cell: float) -> Array:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var cell_vert := PackedInt32Array()
	cell_vert.resize(nx * ny * nz)
	cell_vert.fill(-1)
	var sx := 1
	var sy := nx
	var sz := nx * ny
	# A cell can only hold surface if its first corner is within reach of it. Lumps make the field
	# steeper than one metre per metre, so they widen the reach.
	var steep := 0.0
	for p in _prims:
		steep = maxf(steep, float(p[5]) * 2.0 * _noise_freq * 1.6)
	var skip := cell * 2.0 * (1.0 + steep)
	# Corner offsets and the 12 edges of a cell.
	var co: Array[Vector3i] = [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(1, 1, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 1), Vector3i(0, 1, 1), Vector3i(1, 1, 1)]
	var edges: Array[Vector2i] = [Vector2i(0, 1), Vector2i(2, 3), Vector2i(4, 5), Vector2i(6, 7), Vector2i(0, 2), Vector2i(1, 3), Vector2i(4, 6), Vector2i(5, 7), Vector2i(0, 4), Vector2i(1, 5), Vector2i(2, 6), Vector2i(3, 7)]
	var cv := PackedFloat32Array()
	cv.resize(8)
	for z in nz - 1:
		for y in ny - 1:
			for x in nx - 1:
				var i0 := x + sy * y + sz * z
				var v0 := g[i0]
				if absf(v0) > skip:
					continue  # the field moves at most one metre per metre: no surface in this cell
				var mask := 0
				for c in 8:
					var o := co[c]
					var v := g[i0 + o.x * sx + o.y * sy + o.z * sz]
					cv[c] = v
					if v < 0.0:
						mask |= 1 << c
				if mask == 0 or mask == 255:
					continue
				var acc := Vector3.ZERO
				var n := 0
				for e in edges:
					var a := cv[e.x]
					var b := cv[e.y]
					if (a < 0.0) == (b < 0.0):
						continue
					var t := a / (a - b)
					acc += Vector3(co[e.x]).lerp(Vector3(co[e.y]), t)
					n += 1
				var local := acc / float(n)
				var pos := lo + (Vector3(x, y, z) + local) * cell
				cell_vert[i0] = verts.size()
				verts.append(pos)
				norms.append(_grad(g, nx, ny, nz, Vector3(x, y, z) + local))
				# Quads across the three edges leaving this cell's first corner.
				var in0 := v0 < 0.0
				if y > 0 and z > 0 and (in0 != (cv[1] < 0.0)):
					_quad(idx, cell_vert, i0, i0 - sy, i0 - sy - sz, i0 - sz, in0, verts, norms)
				if x > 0 and z > 0 and (in0 != (cv[2] < 0.0)):
					_quad(idx, cell_vert, i0, i0 - sz, i0 - sx - sz, i0 - sx, in0, verts, norms)
				if x > 0 and y > 0 and (in0 != (cv[4] < 0.0)):
					_quad(idx, cell_vert, i0, i0 - sx, i0 - sx - sy, i0 - sy, in0, verts, norms)
	for v in verts:
		cols.append(_color_at(v, cell * 0.9))
	return [verts, norms, cols, idx]


static func _quad(idx: PackedInt32Array, cell_vert: PackedInt32Array, a: int, b: int, c: int, d: int, flip: bool, verts: PackedVector3Array, norms: PackedVector3Array) -> void:
	var ia := cell_vert[a]
	var ib := cell_vert[b]
	var ic := cell_vert[c]
	var id := cell_vert[d]
	if ia < 0 or ib < 0 or ic < 0 or id < 0:
		return
	var tri: Array[int] = [ia, ib, ic, ia, ic, id]
	# Godot's front faces wind clockwise as seen from outside: check against the field's normal.
	var nrm := norms[ia] + norms[ic]
	var geo := (verts[ib] - verts[ia]).cross(verts[ic] - verts[ia])
	if geo.dot(nrm) > 0.0:
		tri = [ia, ic, ib, ia, id, ic]
	for t in tri:
		idx.append(t)


static func _grad(g: PackedFloat32Array, nx: int, ny: int, nz: int, p: Vector3) -> Vector3:
	var x := clampi(int(round(p.x)), 1, nx - 2)
	var y := clampi(int(round(p.y)), 1, ny - 2)
	var z := clampi(int(round(p.z)), 1, nz - 2)
	var sy := nx
	var sz := nx * ny
	var i := x + sy * y + sz * z
	var n := Vector3(g[i + 1] - g[i - 1], g[i + sy] - g[i - sy], g[i + sz] - g[i - sz])
	return n.normalized() if n.length_squared() > 1.0e-12 else Vector3.UP


## The colour of the surface at p: the shape it is closest to (a carve's own colour inside the cut),
## then any paint over it.
func _color_at(p: Vector3, soft: float) -> Color:
	var b1 := 1.0e9
	var b2 := 1.0e9
	var c1 := Color(0.5, 0.5, 0.5, 0.6)
	var c2 := c1
	for q in _prims:
		var op: int = q[1]
		if op == Op.PAINT:
			continue
		var d := absf(_sdf(q, p))
		if op == Op.CARVE:
			d *= 0.8  # the lining of a cut wins at the rim
		var c := _prim_color(q)
		if d < b1:
			b2 = b1
			c2 = c1
			b1 = d
			c1 = c
		elif d < b2 and c != c1:
			b2 = d
			c2 = c
	# Where two colours meet, blend over a band a little wider than a grid cell: no stair steps.
	var col := c1.lerp(c2, clampf(0.5 - (b2 - b1) / (2.0 * soft), 0.0, 0.5))
	for q in _prims:
		if q[1] == Op.PAINT:
			col = col.lerp(_prim_color(q), clampf(0.5 - _sdf(q, p) / (2.0 * soft), 0.0, 1.0))
	return col


static func _prim_color(q: Array) -> Color:
	var c: Color = q[3]
	var rough: float = q[9] if q[0] == Kind.BOX else q[4]
	return Color(c.r, c.g, c.b, rough)


static func _prim_aabb(p: Array) -> AABB:
	var grow: float = p[2] + p[5] + 0.002
	match p[0]:
		Kind.CAPSULE:
			var a: Vector3 = p[6]
			var b: Vector3 = p[7]
			var r := maxf(p[8], p[9]) + grow
			return AABB(a.min(b) - Vector3.ONE * r, (a.max(b) - a.min(b)) + Vector3.ONE * r * 2.0)
		Kind.ELLIPSOID:
			var c: Vector3 = p[6]
			var r: Vector3 = p[7]
			var m := maxf(r.x, maxf(r.y, r.z)) + grow
			return AABB(c - Vector3.ONE * m, Vector3.ONE * m * 2.0)
		_:
			# The turned box's own extent: a bounding cube of its diagonal made every long thin board
			# (a table top, a shelf) sample a cube metres high.
			var c: Vector3 = p[6]
			var h: Vector3 = p[7]
			var b: Basis = (p[8] as Basis).inverse()
			var e := Vector3(
				absf(b.x.x) * h.x + absf(b.y.x) * h.y + absf(b.z.x) * h.z,
				absf(b.x.y) * h.x + absf(b.y.y) * h.y + absf(b.z.y) * h.z,
				absf(b.x.z) * h.x + absf(b.y.z) * h.y + absf(b.z.z) * h.z) + Vector3.ONE * grow
			return AABB(c - e, e * 2.0)


static func _sdf(p: Array, q: Vector3) -> float:
	match p[0]:
		Kind.CAPSULE:
			return _round_cone(q, p[6], p[7], p[8], p[9])
		Kind.ELLIPSOID:
			var inv: Basis = p[8]
			var l: Vector3 = inv * (q - (p[6] as Vector3))
			var r: Vector3 = p[7]
			var k0 := (l / r).length()
			var k1 := (l / (r * r)).length()
			return k0 * (k0 - 1.0) / maxf(k1, 1.0e-6)
		_:
			var inv: Basis = p[8]
			var l: Vector3 = inv * (q - (p[6] as Vector3))
			var rr: float = p[4]
			var d := l.abs() - (p[7] as Vector3) + Vector3.ONE * rr
			return d.max(Vector3.ZERO).length() + minf(maxf(d.x, maxf(d.y, d.z)), 0.0) - rr


static func _round_cone(p: Vector3, a: Vector3, b: Vector3, r1: float, r2: float) -> float:
	var ba := b - a
	var l2 := ba.dot(ba)
	if l2 < 1.0e-8:
		return p.distance_to(a) - maxf(r1, r2)
	var rr := r1 - r2
	var a2 := l2 - rr * rr
	var il2 := 1.0 / l2
	var pa := p - a
	var y := pa.dot(ba)
	var z := y - l2
	var xv := pa * l2 - ba * y
	var x2 := xv.dot(xv)
	var y2 := y * y * l2
	var z2 := z * z * l2
	var k := signf(rr) * rr * rr * x2
	if signf(z) * a2 * z2 > k:
		return sqrt(x2 + z2) * il2 - r2
	if signf(y) * a2 * y2 < k:
		return sqrt(x2 + y2) * il2 - r1
	return (sqrt(x2 * a2 * il2) + y * rr) * il2 - r1


static func _smin(a: float, b: float, k: float) -> float:
	var h := maxf(k - absf(a - b), 0.0) / k
	return minf(a, b) - h * h * k * 0.25


static func _hash3(x: int, y: int, z: int) -> float:
	var h := (x * 374761393 + y * 668265263 + z * 2147483647) & 0x7FFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7FFFFFFF
	return float(h & 0xFFFF) / 65535.0


static func _noise(p: Vector3) -> float:
	var ix := int(floor(p.x))
	var iy := int(floor(p.y))
	var iz := int(floor(p.z))
	var f := p - Vector3(ix, iy, iz)
	f = f * f * (Vector3.ONE * 3.0 - f * 2.0)
	var a := lerpf(_hash3(ix, iy, iz), _hash3(ix + 1, iy, iz), f.x)
	var b := lerpf(_hash3(ix, iy + 1, iz), _hash3(ix + 1, iy + 1, iz), f.x)
	var c := lerpf(_hash3(ix, iy, iz + 1), _hash3(ix + 1, iy, iz + 1), f.x)
	var d := lerpf(_hash3(ix, iy + 1, iz + 1), _hash3(ix + 1, iy + 1, iz + 1), f.x)
	return lerpf(lerpf(a, b, f.y), lerpf(c, d, f.y), f.z)


# --- Tubes ------------------------------------------------------------------------------------

## A smooth tapered tube through the points (a Catmull-Rom curve), radius per point, round caps.
## Returns the same arrays as build(). For thin parts the grid can't resolve.
static func tube(points: PackedVector3Array, radii: PackedFloat32Array, color: Color, rough: float = 0.5, sides: int = 8, steps: int = 4) -> Array:
	var path := PackedVector3Array()
	var rad := PackedFloat32Array()
	var n := points.size()
	for i in n - 1:
		var p0 := points[maxi(i - 1, 0)]
		var p1 := points[i]
		var p2 := points[i + 1]
		var p3 := points[mini(i + 2, n - 1)]
		for s in steps:
			var t := float(s) / float(steps)
			path.append(_catmull(p0, p1, p2, p3, t))
			rad.append(lerpf(radii[i], radii[i + 1], t))
	path.append(points[n - 1])
	rad.append(radii[n - 1])
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var col := Color(color.r, color.g, color.b, rough)
	var m := path.size()
	var up := Vector3.UP
	var rings: Array[PackedVector3Array] = []
	for i in m:
		var fwd := (path[mini(i + 1, m - 1)] - path[maxi(i - 1, 0)]).normalized()
		if absf(fwd.dot(up)) > 0.95:
			up = Vector3.RIGHT
		var side := fwd.cross(up).normalized()
		var up2 := side.cross(fwd).normalized()
		var ring := PackedVector3Array()
		for s in sides:
			var a := TAU * float(s) / float(sides)
			ring.append(side * cos(a) + up2 * sin(a))
		rings.append(ring)
	for i in m:
		for s in sides:
			verts.append(path[i] + rings[i][s] * rad[i])
			norms.append(rings[i][s])
			cols.append(col)
	for i in m - 1:
		for s in sides:
			var a := i * sides + s
			var b := i * sides + (s + 1) % sides
			var c := a + sides
			var d := b + sides
			idx.append_array(PackedInt32Array([a, b, c, b, d, c]))
	# Caps: a point a little past each end.
	for end in 2:
		var ci := 0 if end == 0 else m - 1
		var dir := (path[0] - path[1]).normalized() if end == 0 else (path[m - 1] - path[m - 2]).normalized()
		var tip := verts.size()
		verts.append(path[ci] + dir * rad[ci] * 0.8)
		norms.append(dir)
		cols.append(col)
		for s in sides:
			var a := ci * sides + s
			var b := ci * sides + (s + 1) % sides
			if end == 0:
				idx.append_array(PackedInt32Array([tip, b, a]))
			else:
				idx.append_array(PackedInt32Array([tip, a, b]))
	_fix_winding(verts, norms, idx)
	return [verts, norms, cols, idx]


## Turns every triangle to face along its vertices' normals (Godot's clockwise front faces).
static func _fix_winding(verts: PackedVector3Array, norms: PackedVector3Array, idx: PackedInt32Array) -> void:
	var i := 0
	while i < idx.size():
		var a := idx[i]
		var b := idx[i + 1]
		var c := idx[i + 2]
		var geo := (verts[b] - verts[a]).cross(verts[c] - verts[a])
		if geo.dot(norms[a] + norms[b] + norms[c]) > 0.0:
			idx[i + 1] = c
			idx[i + 2] = b
		i += 3


static func _catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


# --- Meshes and materials ----------------------------------------------------------------------

## Several parts into one set of arrays (each optionally with its own UV2 and two custom vectors,
## for meshes a shader animates by part).
class Builder:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var uv2 := PackedVector2Array()
	var c0 := PackedFloat32Array()
	var c1 := PackedFloat32Array()
	var tagged: bool = false

	func add(arrays: Array, tag: Vector2 = Vector2.ZERO, piv1: Vector3 = Vector3.ZERO, piv2: Vector3 = Vector3.ZERO) -> void:
		var base := verts.size()
		var v: PackedVector3Array = arrays[0]
		verts.append_array(v)
		norms.append_array(arrays[1])
		cols.append_array(arrays[2])
		var ii: PackedInt32Array = arrays[3]
		for i in ii:
			idx.append(base + i)
		for _k in v.size():
			uv2.append(tag)
			c0.append_array(PackedFloat32Array([piv1.x, piv1.y, piv1.z, 0.0]))
			c1.append_array(PackedFloat32Array([piv2.x, piv2.y, piv2.z, 0.0]))

	## max_tris > 0: first simplified to about that many triangles (meshoptimizer: the surface is
	## smooth and the normals come from the field, so it barely shows), then given distance LODs
	## that Godot swaps in on its own.
	func commit(max_tris: int = 0) -> ArrayMesh:
		var a := []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = verts
		a[Mesh.ARRAY_NORMAL] = norms
		a[Mesh.ARRAY_COLOR] = cols
		a[Mesh.ARRAY_INDEX] = idx
		var flags := 0
		if tagged:
			a[Mesh.ARRAY_TEX_UV2] = uv2
			a[Mesh.ARRAY_CUSTOM0] = c0
			a[Mesh.ARRAY_CUSTOM1] = c1
			flags = (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
		var m := ArrayMesh.new()
		if verts.size() == 0:
			return m
		if max_tris <= 0:
			m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a, [], {}, flags)
			return m
		if idx.size() / 3 > max_tris:
			var st := SurfaceTool.new()
			var plain := []
			plain.resize(Mesh.ARRAY_MAX)
			plain[Mesh.ARRAY_VERTEX] = verts
			plain[Mesh.ARRAY_NORMAL] = norms
			plain[Mesh.ARRAY_INDEX] = idx
			st.create_from_arrays(plain)
			var fewer := st.generate_lod(0.06, max_tris * 3)
			if fewer.size() >= 3:
				a[Mesh.ARRAY_INDEX] = fewer
		var im := ImporterMesh.new()
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, a, [], {}, null, "", flags)
		im.generate_lods(25.0, 60.0, [])
		return im.get_mesh()



static func to_mesh(arrays: Array, max_tris: int = 0) -> ArrayMesh:
	var b := Builder.new()
	b.add(arrays)
	return b.commit(max_tris)


## The sculpt shader with these settings (vertex colours are the albedo, alpha the roughness).
static func material(wet: float = 0.0, rim: float = 0.0, veins: float = 0.0, sss: float = 0.0, pores: float = 0.25, tint: Color = Color.WHITE) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("wet", wet)
	m.set_shader_parameter("rim", rim)
	m.set_shader_parameter("veins", veins)
	m.set_shader_parameter("sss", sss)
	m.set_shader_parameter("pores", pores)
	m.set_shader_parameter("tint", tint)
	return m


## A cached tube mesh.
static func tube_mesh(name: String, points: PackedVector3Array, radii: PackedFloat32Array, color: Color, rough: float = 0.5, sides: int = 8, steps: int = 4) -> ArrayMesh:
	var key := "tube_%s_%08x" % [name, hash(str(points) + str(radii) + str(color) + "%.2f%d%d%d" % [rough, sides, steps, VERSION]) & 0xFFFFFFFF]
	if _cache.has(key):
		return _cache[key]
	var m := to_mesh(tube(points, radii, color, rough, sides, steps))
	_cache[key] = m
	return m


## A MeshInstance3D of the mesh under parent at a position.
static func put(parent: Node3D, m: Mesh, mat: Material, at: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = at
	mi.rotation = rot
	parent.add_child(mi)
	return mi
