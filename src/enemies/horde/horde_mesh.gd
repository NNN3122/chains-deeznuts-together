class_name HordeMesh
extends RefCounted
## Builds the swarm's bodies: one mesh per kind, every vertex tagged with the limb it belongs to
## (UV2.x), a flag for lower limb segments (UV2.y), and the two pivots that limb swings about
## (CUSTOM0 = the leg root, CUSTOM1 = the knee). The vertex shader then scuttles, flaps, rears up,
## hangs on the chain and dies per instance from four floats of INSTANCE_CUSTOM: x gait phase,
## y a per-body seed, z chitin tint (+2 when rearing at someone), w the state.
## Three kinds, all original mutations of what lived in the walls of Carrow Heights:
##   the Roach (a knee-high cockroach, six legs, swarms and climbs the pile),
##   the Weaver (a spider the size of a dog, eight legs, fast, hangs on the chain),
##   the Flitter (a bat with a two-metre span that dives from above; nothing on the ground stops it).

enum Part { THORAX, HEAD, ABDOMEN, EYES, ANTENNA, LEG0 = 20, WING_L = 28, WING_R = 29 }

const KIND_NAMES: Array[String] = ["Roach", "Weaver", "Flitter"]
const KINDS: int = 3

const SHADER: String = """
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_schlick_ggx;
uniform vec3 cloth_a : source_color = vec3(0.25, 0.22, 0.3);
uniform vec3 cloth_b : source_color = vec3(0.5, 0.45, 0.3);
uniform vec3 trouser : source_color = vec3(0.12, 0.12, 0.14);
uniform vec3 skin_col : source_color = vec3(0.55, 0.58, 0.45);
uniform vec3 eye_col : source_color = vec3(1.0, 0.2, 0.1);
uniform float hunch = 0.0;
uniform float stride = 0.6;
uniform float arm_reach = 1.1;
uniform float hip_y = 0.3;
uniform float flying = 0.0;
varying float v_part;
varying float v_tint;
varying float v_seed;
varying vec3 v_wpos;

mat3 rot_x(float a) { float s = sin(a), c = cos(a); return mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, c, s), vec3(0.0, -s, c)); }
mat3 rot_z(float a) { float s = sin(a), c = cos(a); return mat3(vec3(c, s, 0.0), vec3(-s, c, 0.0), vec3(0.0, 0.0, 1.0)); }
mat3 rot_y(float a) { float s = sin(a), c = cos(a); return mat3(vec3(c, 0.0, -s), vec3(0.0, 1.0, 0.0), vec3(s, 0.0, c)); }

void vertex() {
	float part = UV2.x;
	float lower = UV2.y;
	vec3 piv1 = CUSTOM0.xyz;
	vec3 piv2 = CUSTOM1.xyz;
	float ph = INSTANCE_CUSTOM.x;
	float seed = INSTANCE_CUSTOM.y;
	float state = INSTANCE_CUSTOM.w;
	float reach_on = step(1.5, INSTANCE_CUSTOM.z);
	v_part = part;
	v_tint = fract(INSTANCE_CUSTOM.z);
	v_seed = seed;
	float tnow = TIME + seed * 37.0;
	float dead = step(1.5, state) * (1.0 - step(2.5, state));  // state 2
	float grab = step(0.5, state) * (1.0 - step(1.5, state));  // state 1
	float flinch = step(3.5, state) * (1.0 - step(4.5, state)); // state 4
	float lunge = step(4.5, state) * (1.0 - step(5.5, state));  // state 5
	bool leg = part >= 20.0 && part < 28.0;
	bool wing = part == 28.0 || part == 29.0;
	float li = part - 20.0;                 // leg index: 0,1 front pair, left even
	float side = (mod(li, 2.0) < 0.5) ? 1.0 : -1.0;
	float wside = (part == 28.0) ? 1.0 : -1.0;
	// No two alike: a build from the seed (length, width, leg length, head), and a limp.
	float h1 = fract(seed * 13.7);
	float h2 = fract(seed * 29.3);
	float h3 = fract(seed * 47.1);
	float h4 = fract(seed * 71.9);
	float wf = 0.85 + 0.3 * h1;
	float lf = 0.85 + 0.35 * h2;
	float hf = 0.85 + 0.3 * h4;
	vec3 p = VERTEX;
	vec3 n = NORMAL;
	p.x *= wf;
	piv1.x *= wf;
	piv2.x *= wf;
	if (leg) {
		p = piv1 + (p - piv1) * lf;
		piv2 = piv1 + (piv2 - piv1) * lf;
	} else if (part == 1.0 || part == 3.0 || part == 4.0) {
		p = piv1 + (p - piv1) * hf;
	}
	if (leg) {
		// Tripod gait: alternate legs along each side move together, the other set between.
		float row = floor(li / 2.0);
		float off = mod(row + ((side > 0.0) ? 0.0 : 1.0), 2.0) * 3.14159;
		float limp = 1.0 - 0.4 * step(0.75, h3) * step(abs(li - 2.0), 0.5);
		float sweep = sin(ph * 1.6 + off) * 0.45 * stride * limp;
		float lift = max(0.0, cos(ph * 1.6 + off)) * 0.35 * stride;
		// Rearing: the front pair comes up and waves; the others plant.
		float front = step(row, 0.5);
		sweep = mix(sweep, 0.2 * sin(tnow * 11.0), reach_on * front);
		lift = mix(lift, 1.1 + 0.2 * sin(tnow * 9.0 + side), reach_on * front);
		lift = mix(lift, 0.9, lunge * front);
		lift = mix(lift, 0.5 + 0.3 * sin(tnow * 15.0 + li), grab);
		// Dead: legs curled in and up.
		sweep = mix(sweep, 0.3 * side, dead);
		lift = mix(lift, 1.6, dead);
		if (lower > 0.5) {
			mat3 kr = rot_z(-side * (0.6 + 0.3 * lift));
			p = piv2 + kr * (p - piv2);
			n = kr * n;
		}
		mat3 r = rot_y(sweep) * rot_z(side * lift);
		p = piv1 + r * (p - piv1);
		n = r * n;
	}
	if (wing) {
		float flap = sin(tnow * 21.0 + ph * 0.1) * 0.85 + 0.15;
		flap = mix(flap, -0.9 + 0.1 * sin(tnow * 3.0), dead);  // folded, dead
		flap = mix(flap, 0.4 * sin(tnow * 40.0), lunge);        // tucked for the dive, shivering
		mat3 r = rot_z(wside * flap);
		p = piv1 + r * (p - piv1);
		n = r * n;
	}
	if (part == 4.0) {
		// Antennae and feelers never stop.
		mat3 r = rot_x(0.25 * sin(tnow * 7.0 + p.x * 9.0)) * rot_y(0.2 * sin(tnow * 5.0));
		p = piv1 + r * (p - piv1);
		n = r * n;
	}
	// The whole body: a scuttle wobble, a pulse, rearing up at someone, a shudder when hit.
	float lurch = (0.05 + 0.08 * fract(seed * 7.3)) * sin(ph * 0.8 + seed * 11.0) + 0.03 * sin(tnow * 1.7);
	float bob = 0.02 * abs(cos(ph * 1.6)) * (1.0 - flying) + 0.01 * sin(tnow * 2.3);
	float rear = (0.6 + 0.1 * sin(tnow * 6.0)) * reach_on + 0.5 * lunge + 0.25 * grab;
	mat3 body = rot_z(lurch * (1.0 - dead)) * rot_x(-(hunch + rear) * (1.0 - dead));
	if (flying > 0.5) {
		body = rot_x(-0.25 * lunge + 0.08 * sin(tnow * 2.0)) * rot_z(0.15 * sin(tnow * 1.3));
	}
	p = body * p;
	n = body * n;
	p.y += bob * (1.0 - dead);
	// Dead on the ground: on its back, legs in the air (a bat just drops in a heap).
	if (dead > 0.5) {
		mat3 d = rot_z(3.1416) * rot_y(0.5 * sin(seed * 9.0));
		p = d * p;
		n = d * n;
		p.y += hip_y * 2.0 + 0.1;
	}
	if (flinch > 0.5) {
		mat3 f = rot_x(0.3 * sin(tnow * 30.0)) * rot_y(0.6 * sin(seed * 3.0));
		p = f * p;
		n = f * n;
	}
	VERTEX = p;
	NORMAL = n;
	v_wpos = (MODEL_MATRIX * vec4(p, 1.0)).xyz;
}

float hash3(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }

vec3 hue_shift(vec3 c, float a) {
	float y = dot(c, vec3(0.299, 0.587, 0.114));
	float i = dot(c, vec3(0.596, -0.274, -0.322));
	float q = dot(c, vec3(0.211, -0.523, 0.312));
	float ca = cos(a);
	float sa = sin(a);
	float i2 = i * ca - q * sa;
	float q2 = i * sa + q * ca;
	return vec3(y + 0.956 * i2 + 0.621 * q2, y - 0.272 * i2 - 0.647 * q2, y - 1.106 * i2 + 1.703 * q2);
}

void fragment() {
	vec3 col;
	float hue = (fract(v_seed * 3.1) - 0.5) * 0.9;
	bool soft = (v_part == 2.0 || v_part == 1.0);
	bool legs = v_part >= 20.0 && v_part < 28.0;
	bool wings = v_part == 28.0 || v_part == 29.0;
	if (v_part == 3.0) {
		col = eye_col;
		EMISSION = eye_col * 2.5;
	} else if (soft) {
		col = hue_shift(skin_col, hue * 0.5) * (0.8 + 0.4 * fract(v_seed * 17.3));
	} else if (legs || v_part == 4.0) {
		col = hue_shift(trouser, hue * 0.4) * (0.8 + 0.5 * fract(v_seed * 5.7));
	} else if (wings) {
		col = hue_shift(skin_col * 0.6, hue * 0.6);
	} else {
		col = hue_shift(mix(cloth_a, cloth_b, v_tint), hue);
	}
	// Chitin sheen: banded, wet, with the odd pale scar.
	float g = hash3(floor(v_wpos * 11.0));
	col *= 0.7 + 0.45 * g;
	float scar = step(0.95, hash3(floor(v_wpos * 4.0) + v_seed)) * 0.5;
	col = mix(col, vec3(0.7, 0.65, 0.5), scar);
	ALBEDO = col;
	ROUGHNESS = wings ? 0.9 : 0.35;
	METALLIC = 0.0;
	SPECULAR = wings ? 0.2 : 0.6;
}
"""

static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}


static func mesh_for(kind: int) -> ArrayMesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var m := _build(kind)
	_meshes[kind] = m
	return m


static func material_for(kind: int) -> ShaderMaterial:
	if _materials.has(kind):
		return _materials[kind]
	var sh := Shader.new()
	sh.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("hip_y", _proportions(kind)[2])
	match kind:
		0:  # the Roach: brown-black shell, amber underside, a scuttle
			m.set_shader_parameter("cloth_a", Color(0.22, 0.12, 0.06))
			m.set_shader_parameter("cloth_b", Color(0.45, 0.22, 0.08))
			m.set_shader_parameter("trouser", Color(0.2, 0.12, 0.06))
			m.set_shader_parameter("skin_col", Color(0.55, 0.38, 0.18))
			m.set_shader_parameter("eye_col", Color(1.0, 0.35, 0.1))
			m.set_shader_parameter("hunch", 0.0)
			m.set_shader_parameter("stride", 1.0)
			m.set_shader_parameter("flying", 0.0)
		1:  # the Weaver: grey-green, striped, pale underside, eyes like a cluster of coals
			m.set_shader_parameter("cloth_a", Color(0.16, 0.2, 0.14))
			m.set_shader_parameter("cloth_b", Color(0.3, 0.3, 0.22))
			m.set_shader_parameter("trouser", Color(0.12, 0.14, 0.1))
			m.set_shader_parameter("skin_col", Color(0.5, 0.5, 0.38))
			m.set_shader_parameter("eye_col", Color(1.0, 0.1, 0.05))
			m.set_shader_parameter("hunch", 0.05)
			m.set_shader_parameter("stride", 0.8)
			m.set_shader_parameter("flying", 0.0)
		_:  # the Flitter: sooty fur, leather wings, eyes that catch the light
			m.set_shader_parameter("cloth_a", Color(0.12, 0.1, 0.1))
			m.set_shader_parameter("cloth_b", Color(0.25, 0.18, 0.14))
			m.set_shader_parameter("trouser", Color(0.1, 0.08, 0.08))
			m.set_shader_parameter("skin_col", Color(0.4, 0.25, 0.22))
			m.set_shader_parameter("eye_col", Color(0.9, 0.9, 0.3))
			m.set_shader_parameter("hunch", 0.0)
			m.set_shader_parameter("stride", 0.3)
			m.set_shader_parameter("flying", 1.0)
	_materials[kind] = m
	return m


## Proportions per kind: [body length, body width, body height off the ground].
static func _proportions(kind: int) -> Array[float]:
	match kind:
		0: return [1.1, 0.5, 0.28]
		1: return [1.3, 0.6, 0.55]
		_: return [0.5, 0.25, 0.3]


static func _build(kind: int) -> ArrayMesh:
	var pr := _proportions(kind)
	var length: float = pr[0]
	var width: float = pr[1]
	var h: float = pr[2]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
	st.set_custom_format(1, SurfaceTool.CUSTOM_RGBA_FLOAT)
	var no := Vector3.ZERO
	var center := Vector3(0.0, h, 0.0)
	match kind:
		0:
			_roach(st, length, width, h, center, no)
		1:
			_weaver(st, length, width, h, center, no)
		_:
			_flitter(st, length, width, h, center, no)
	st.index()
	var mesh := st.commit()
	mesh.custom_aabb = AABB(Vector3(-2.5, -0.6, -2.5), Vector3(5.0, 3.5, 5.0))
	return mesh


## Six legs, a flat shell, a small head with antennae. Faces -z.
static func _roach(st: SurfaceTool, length: float, width: float, h: float, c: Vector3, no: Vector3) -> void:
	_box(st, c + Vector3(0.0, 0.0, 0.1), Vector3(width, h * 0.9, length * 0.65), Part.THORAX, 0.0, c, no)  # the shell
	_box(st, c + Vector3(0.0, -h * 0.25, 0.1), Vector3(width * 0.8, h * 0.4, length * 0.6), Part.ABDOMEN, 0.0, c, no)  # underside
	var head := c + Vector3(0.0, 0.0, -length * 0.42)
	_box(st, head, Vector3(width * 0.55, h * 0.7, length * 0.22), Part.HEAD, 0.0, head, no)
	for s: float in [-1.0, 1.0]:
		_box(st, head + Vector3(s * width * 0.18, h * 0.15, -length * 0.1), Vector3(0.06, 0.06, 0.04), Part.EYES, 0.0, head, no)
		var ant := head + Vector3(s * width * 0.15, h * 0.3, -length * 0.1)
		_box(st, ant + Vector3(s * 0.15, 0.15, -0.35), Vector3(0.025, 0.025, 0.8), Part.ANTENNA, 0.0, ant, no)
	_legs(st, 3, c, width, h, length * 0.5, 0.55, 0.0)


## Eight long legs, a big abdomen behind, a cluster of eyes. Faces -z.
static func _weaver(st: SurfaceTool, length: float, width: float, h: float, c: Vector3, no: Vector3) -> void:
	_box(st, c + Vector3(0.0, 0.0, -0.15), Vector3(width, h * 0.8, length * 0.45), Part.THORAX, 0.0, c, no)
	var abd := c + Vector3(0.0, h * 0.25, length * 0.4)
	_box(st, abd, Vector3(width * 1.5, h * 1.3, length * 0.7), Part.ABDOMEN, 0.0, abd, no)
	var head := c + Vector3(0.0, h * 0.1, -length * 0.4)
	_box(st, head, Vector3(width * 0.6, h * 0.6, length * 0.2), Part.HEAD, 0.0, head, no)
	for k in 6:
		var a := float(k) / 6.0 * TAU
		_box(st, head + Vector3(cos(a) * width * 0.2, h * 0.1 + sin(a) * h * 0.15, -length * 0.1), Vector3(0.05, 0.05, 0.04), Part.EYES, 0.0, head, no)
	for s: float in [-1.0, 1.0]:  # fangs
		_box(st, head + Vector3(s * 0.07, -h * 0.25, -length * 0.08), Vector3(0.04, 0.16, 0.04), Part.ANTENNA, 0.0, head, no)
	_legs(st, 4, c, width, h, length * 0.5, 0.95, 0.0)


## A furry body, two long wings, a snub face with ears. Faces -z, flies.
static func _flitter(st: SurfaceTool, length: float, width: float, h: float, c: Vector3, no: Vector3) -> void:
	_box(st, c, Vector3(width, width * 0.9, length), Part.THORAX, 0.0, c, no)
	_box(st, c + Vector3(0.0, -width * 0.3, 0.1), Vector3(width * 0.7, width * 0.3, length * 0.7), Part.ABDOMEN, 0.0, c, no)
	var head := c + Vector3(0.0, width * 0.2, -length * 0.55)
	_box(st, head, Vector3(width * 0.8, width * 0.7, length * 0.35), Part.HEAD, 0.0, head, no)
	for s: float in [-1.0, 1.0]:
		_box(st, head + Vector3(s * width * 0.25, 0.0, -length * 0.15), Vector3(0.05, 0.05, 0.03), Part.EYES, 0.0, head, no)
		_box(st, head + Vector3(s * width * 0.3, width * 0.5, 0.0), Vector3(0.08, 0.25, 0.04), Part.ANTENNA, 0.0, head, no)  # ears
	for s: float in [1.0, -1.0]:
		var root := c + Vector3(s * width * 0.5, width * 0.2, 0.0)
		var part := Part.WING_L if s > 0.0 else Part.WING_R
		_box(st, root + Vector3(s * 0.55, 0.0, 0.05), Vector3(1.1, 0.03, length * 1.3), part, 0.0, root, no)
		_box(st, root + Vector3(s * 0.55, 0.02, -length * 0.6), Vector3(1.1, 0.04, 0.05), part, 0.0, root, no)  # the leading edge bone
		_box(st, root + Vector3(s * 0.25, 0.0, -length * 0.3), Vector3(0.05, 0.05, 0.4), part, 0.0, root, no)  # finger
	for s: float in [1.0, -1.0]:  # tiny hanging legs
		var root := c + Vector3(s * width * 0.2, -width * 0.4, length * 0.3)
		_box(st, root + Vector3(0.0, -0.1, 0.0), Vector3(0.04, 0.2, 0.04), Part.LEG0 + (0 if s > 0.0 else 1), 0.0, root, root)


## Legs in pairs down each side: an upper segment angled up and out from the root, a lower one
## down to the ground. Left legs get even indices.
static func _legs(st: SurfaceTool, pairs: int, c: Vector3, width: float, h: float, half_len: float, reach: float, _y: float) -> void:
	for row in pairs:
		var z := -half_len * 0.8 + (float(row) + 0.5) * half_len * 1.6 / float(pairs)
		for s: float in [1.0, -1.0]:
			var idx := row * 2 + (0 if s > 0.0 else 1)
			var root := c + Vector3(s * width * 0.5, h * 0.1, z)
			var knee := root + Vector3(s * reach * 0.55, h * 0.6, 0.0)
			var foot := knee + Vector3(s * reach * 0.45, -h * 0.6 - h - 0.02, 0.0)
			_segment(st, root, knee, 0.045, Part.LEG0 + idx, 0.0, root, knee)
			_segment(st, knee, foot, 0.035, Part.LEG0 + idx, 1.0, root, knee)


## A thin box from a to b (the leg segments), tagged.
static func _segment(st: SurfaceTool, a: Vector3, b: Vector3, r: float, part: int, lower: float, piv1: Vector3, piv2: Vector3) -> void:
	var d := b - a
	var l := d.length()
	if l < 0.001:
		return
	var mid := (a + b) * 0.5
	var basis := Basis.looking_at(d / l, Vector3.UP if absf(d.normalized().y) < 0.95 else Vector3.RIGHT)
	var hx := r
	var hy := r
	var hz := l * 0.5
	var corners := [
		Vector3(-hx, -hy, -hz), Vector3(hx, -hy, -hz), Vector3(hx, hy, -hz), Vector3(-hx, hy, -hz),
		Vector3(-hx, -hy, hz), Vector3(hx, -hy, hz), Vector3(hx, hy, hz), Vector3(-hx, hy, hz),
	]
	var faces := [[0, 1, 2, 3], [5, 4, 7, 6], [4, 0, 3, 7], [1, 5, 6, 2], [3, 2, 6, 7], [4, 5, 1, 0]]
	var c0 := Color(piv1.x, piv1.y, piv1.z, 0.0)
	var c1 := Color(piv2.x, piv2.y, piv2.z, 0.0)
	var uv2 := Vector2(float(part), lower)
	for f in faces:
		var v0: Vector3 = basis * corners[f[0]]
		var v1: Vector3 = basis * corners[f[1]]
		var v2: Vector3 = basis * corners[f[2]]
		var n := (v1 - v0).cross(v2 - v0).normalized()
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_normal(n)
			st.set_uv2(uv2)
			st.set_custom(0, c0)
			st.set_custom(1, c1)
			st.add_vertex(mid + basis * (corners[f[idx]] as Vector3))


## One box: 6 quads, flat normals, tagged for the shader.
static func _box(st: SurfaceTool, center: Vector3, size: Vector3, part: int, lower: float, piv1: Vector3, piv2: Vector3) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	var faces := [
		[Vector3(0, 0, -1), [Vector3(-hx, -hy, -hz), Vector3(-hx, hy, -hz), Vector3(hx, hy, -hz), Vector3(hx, -hy, -hz)]],
		[Vector3(0, 0, 1), [Vector3(hx, -hy, hz), Vector3(hx, hy, hz), Vector3(-hx, hy, hz), Vector3(-hx, -hy, hz)]],
		[Vector3(-1, 0, 0), [Vector3(-hx, -hy, hz), Vector3(-hx, hy, hz), Vector3(-hx, hy, -hz), Vector3(-hx, -hy, -hz)]],
		[Vector3(1, 0, 0), [Vector3(hx, -hy, -hz), Vector3(hx, hy, -hz), Vector3(hx, hy, hz), Vector3(hx, -hy, hz)]],
		[Vector3(0, 1, 0), [Vector3(-hx, hy, -hz), Vector3(-hx, hy, hz), Vector3(hx, hy, hz), Vector3(hx, hy, -hz)]],
		[Vector3(0, -1, 0), [Vector3(-hx, -hy, hz), Vector3(-hx, -hy, -hz), Vector3(hx, -hy, -hz), Vector3(hx, -hy, hz)]],
	]
	var c0 := Color(piv1.x, piv1.y, piv1.z, 0.0)
	var c1 := Color(piv2.x, piv2.y, piv2.z, 0.0)
	var uv2 := Vector2(float(part), lower)
	for f in faces:
		var n: Vector3 = f[0]
		var v: Array = f[1]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_normal(n)
			st.set_uv2(uv2)
			st.set_custom(0, c0)
			st.set_custom(1, c1)
			st.add_vertex(center + (v[idx] as Vector3))
