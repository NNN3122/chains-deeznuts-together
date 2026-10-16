class_name LevelKit
extends RefCounted
## Shared look of the game: procedural materials (shaders, no texture files), the lighting
## environment, and BoxBatch, which turns thousands of level boxes into one draw call per
## material plus one static body for collision.

const NOISE_LIB: String = """
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) { s += a * vnoise(p); p *= 2.03; a *= 0.5; }
	return s;
}
"""

const WALL_SHADER: String = """
shader_type spatial;
uniform vec3 base_color = vec3(0.80, 0.70, 0.36);
uniform vec3 stripe_color = vec3(0.70, 0.60, 0.29);
uniform vec3 board_color = vec3(0.24, 0.17, 0.10);
uniform float floor_height = 5.0;
varying vec3 wpos;
varying vec3 wnrm;
%s
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	float h = mod(wpos.y + 0.001, floor_height);
	float along = abs(wnrm.z) > abs(wnrm.x) ? wpos.x : wpos.z;
	float stripe = smoothstep(0.55, 0.75, abs(fract(along * 2.6) - 0.5) * 2.0);
	vec3 col = mix(base_color, stripe_color, stripe * 0.7);
	col *= 0.88 + 0.22 * fbm(vec2(along, wpos.y) * 1.7);
	// Wallpaper seams every 53 cm, slightly lifted at the edges.
	float seam = 1.0 - smoothstep(0.0, 0.004, abs(fract(along / 0.53) - 0.5) - 0.497);
	col *= 1.0 - 0.18 * seam;
	// Orange-peel plaster texture under the paper.
	float n1 = vnoise(vec2(along, wpos.y) * 90.0);
	float n2 = vnoise(vec2(along, wpos.y) * 90.0 + vec2(17.0, 9.0));
	NORMAL_MAP = vec3(0.5 + (n1 - 0.5) * 0.12, 0.5 + (n2 - 0.5) * 0.12, 1.0);
	NORMAL_MAP_DEPTH = 1.0;
	float damage = fbm(vec2(along * 0.35, floor(wpos.y / floor_height) * 3.1));
	float stain_h = 0.3 + damage * 1.5;
	float blot = smoothstep(0.42, 0.7, fbm(vec2(along * 0.6, h * 0.8)));
	float stain = smoothstep(stain_h, stain_h - 0.7, h) * blot;
	col = mix(col, col * vec3(0.52, 0.42, 0.26), stain * 0.85);
	col *= 1.0 - 0.3 * smoothstep(2.5, 3.2, h);
	float board = step(h, 0.14);
	col = mix(col, board_color, board);
	ALBEDO = col;
	ROUGHNESS = mix(0.88, 0.45, board);
}
"""

# Real photo-sourced maps (TextureCan, CC0) mapped in world space, with procedural stains and
# grime layered on top so the repeat never shows. The normal map is applied in world space
# (horizontal faces only) so it doesn't depend on the box mesh's own tangents.
const CEILING_SHADER: String = """
shader_type spatial;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D ao_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec3 tint = vec3(0.87, 0.83, 0.71);
uniform float texture_span = 9.6;  // one repeat = 16 tiles of 60 cm
uniform vec2 grid_offset = vec2(0.0293, 0.0293);  // lines the texture up with the 0.6 m world grid
varying vec3 wpos;
varying vec3 wnrm;
%s
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	vec2 uv = wpos.xz / texture_span + grid_offset;
	vec3 col = texture(albedo_tex, uv).rgb * tint;
	vec2 p = wpos.xz / 0.6;
	vec2 cell = floor(p);
	vec2 f = fract(p);
	col *= 0.93 + 0.09 * hash(cell * 3.7);  // every tile a slightly different age
	float r = hash(cell + vec2(floor(wpos.y), 0.0));
	if (r > 0.84) {
		vec2 c = vec2(hash(cell * 1.7), hash(cell * 2.3)) * 0.5 + 0.25;
		float d = length(f - c);
		float ring = smoothstep(0.38, 0.3, d) * (0.35 + 0.65 * smoothstep(0.2, 0.3, d));
		col = mix(col, vec3(0.52, 0.40, 0.20), ring * 0.75);
	}
	if (r < 0.012) { col = vec3(0.03); }
	col *= 0.86 + 0.14 * fbm(wpos.xz * 0.15);
	ALBEDO = col;
	ROUGHNESS = max(texture(rough_tex, uv).r, 0.6);  // painted T-bar, not a mirror: no laser streaks
	SPECULAR = 0.3;
	AO = texture(ao_tex, uv).r;
	AO_LIGHT_AFFECT = 0.3;
	if (wnrm.y < -0.5) {
		vec2 nxy = texture(normal_tex, uv).rg * 2.0 - 1.0;
		vec3 nts = vec3(nxy, sqrt(max(0.0, 1.0 - dot(nxy, nxy))));
		NORMAL = normalize((VIEW_MATRIX * vec4(nts.x, -nts.z, -nts.y, 0.0)).xyz);
	}
}
"""

const CARPET_SHADER: String = """
shader_type spatial;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D ao_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec3 carpet_color = vec3(0.60, 0.48, 0.18);  // the blue source, recoloured mustard
uniform float source_luminance = 0.32;  // average brightness of the source texture
uniform float texture_span = 3.0;  // one repeat = 6 carpet tiles of 50 cm
varying vec3 wpos;
varying vec3 wnrm;
%s
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	vec2 uv = wpos.xz / texture_span;
	vec3 src = texture(albedo_tex, uv).rgb;
	float lum = dot(src, vec3(0.299, 0.587, 0.114));
	vec3 col = carpet_color * (lum / source_luminance);
	col *= 0.86 + 0.26 * fbm(wpos.xz * 0.35);
	float damp = smoothstep(0.56, 0.74, fbm(wpos.xz * 0.22 + vec2(7.0, 3.0)));
	col = mix(col, col * vec3(0.55, 0.5, 0.36), damp * 0.75);
	ALBEDO = col;
	ROUGHNESS = clamp(texture(rough_tex, uv).r + 0.08, 0.0, 1.0);
	AO = texture(ao_tex, uv).r;
	AO_LIGHT_AFFECT = 0.4;
	if (wnrm.y > 0.5) {
		vec2 nxy = texture(normal_tex, uv).rg * 2.0 - 1.0;
		vec3 nts = vec3(nxy, sqrt(max(0.0, 1.0 - dot(nxy, nxy))));
		NORMAL = normalize((VIEW_MATRIX * vec4(nts.x, nts.z, -nts.y, 0.0)).xyz);
	}
}
"""

const CONCRETE_SHADER: String = """
shader_type spatial;
varying vec3 wpos;
varying vec3 wnrm;
%s
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	vec2 p = abs(wnrm.y) > 0.5 ? wpos.xz : (abs(wnrm.x) > 0.5 ? wpos.zy : wpos.xy);
	float n = fbm(p * 1.3);
	float pits = smoothstep(0.7, 0.8, vnoise(p * 18.0));
	vec3 col = vec3(0.42, 0.41, 0.38) * (0.75 + 0.4 * n) - pits * 0.08;
	ALBEDO = col;
	ROUGHNESS = 0.92;
}
"""

const GLOW_SHADER: String = """
shader_type spatial;
render_mode unshaded;
instance uniform float glow = 1.0;
uniform vec3 tint = vec3(1.0, 0.94, 0.76);
varying vec3 wpos;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	// A parabolic louver: a grid of bright cells over two tubes.
	vec2 g = abs(fract(wpos.xz / 0.15) - 0.5);
	float louver = smoothstep(0.42, 0.47, max(g.x, g.y));
	vec2 local = fract(wpos.xz / vec2(1.2, 0.6) + 0.5);
	float tubes = 0.7 + 0.3 * smoothstep(0.25, 0.0, abs(abs(local.y - 0.5) - 0.2));
	float lit = (1.0 - louver * 0.75) * tubes;
	ALBEDO = tint * (0.04 + glow * 2.6 * lit);
}
"""

static var _mats: Dictionary = {}


## Shared material by key. Unknown keys fall back to a plain grey so a typo is visible, not fatal.
static func mat(key: String) -> Material:
	if _mats.has(key):
		return _mats[key]
	var m := _make(key)
	_mats[key] = m
	return m


static func _shader_mat(code: String) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = code % NOISE_LIB if code.contains("%s") else code
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


## A shader material fed with the color / normal / roughness / ao maps in a texture folder.
static func _textured(code: String, folder: String) -> ShaderMaterial:
	var m := _shader_mat(code)
	for pair in [["albedo_tex", "color.jpg"], ["normal_tex", "normal.png"], ["rough_tex", "roughness.jpg"], ["ao_tex", "ao.jpg"]]:
		var path: String = folder + String(pair[1])
		if ResourceLoader.exists(path):
			m.set_shader_parameter(String(pair[0]), load(path))
		else:
			push_warning("LevelKit: missing texture %s" % path)
	return m


static func _std(color: Color, roughness: float = 0.8, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m


static func _emissive(color: Color, energy: float) -> StandardMaterial3D:
	var m := _std(color, 0.4)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


static func _make(key: String) -> Material:
	match key:
		"wall": return _shader_mat(WALL_SHADER)
		"ceiling": return _textured(CEILING_SHADER, "res://assets/textures/ceiling_tiles/")
		"carpet": return _textured(CARPET_SHADER, "res://assets/textures/carpet/")
		"concrete": return _shader_mat(CONCRETE_SHADER)
		"glow": return _shader_mat(GLOW_SHADER)
		"trim": return _std(Color(0.26, 0.19, 0.11), 0.55)
		"metal": return _std(Color(0.42, 0.44, 0.47), 0.42, 0.75)
		"steel_dark": return _std(Color(0.16, 0.16, 0.17), 0.35, 0.9)
		"desk": return _std(Color(0.64, 0.56, 0.42), 0.45)
		"desk_leg": return _std(Color(0.2, 0.2, 0.21), 0.5, 0.6)
		"partition": return _std(Color(0.33, 0.37, 0.43), 1.0)
		"cardboard": return _std(Color(0.62, 0.47, 0.29), 0.92)
		"cardboard_dark": return _std(Color(0.5, 0.37, 0.22), 0.92)
		"dark": return _std(Color(0.035, 0.035, 0.04), 0.9)
		"black_hole": return _emissive(Color(0.0, 0.0, 0.0), 0.0)
		"white": return _std(Color(0.9, 0.9, 0.88), 0.35)
		"chair": return _std(Color(0.12, 0.12, 0.14), 0.7)
		"vending": return _std(Color(0.58, 0.07, 0.06), 0.35, 0.2)
		"vending_glass": return _emissive(Color(0.95, 0.85, 0.6), 1.4)
		"screen": return _emissive(Color(0.25, 0.45, 0.85), 1.8)
		"screen_off": return _std(Color(0.03, 0.03, 0.035), 0.2)
		"plant": return _std(Color(0.16, 0.32, 0.12), 0.8)
		"pot": return _std(Color(0.45, 0.25, 0.15), 0.7)
		"sign": return _std(Color(0.95, 0.78, 0.05), 0.5)
		"water": return _emissive(Color(0.55, 0.75, 0.95), 0.3)
		"lift": return _std(Color(0.55, 0.44, 0.12), 0.5, 0.6)
		"hazard": return _std(Color(0.9, 0.7, 0.05), 0.6)
		"sign_green": return _emissive(Color(0.05, 0.42, 0.18), 0.6)
		"elevator": return _std(Color(0.5, 0.5, 0.52), 0.3, 0.85)
		"plate": return _std(Color(0.85, 0.7, 0.1), 0.5, 0.4)
		"iron": return _std(Color(0.18, 0.17, 0.16), 0.55, 0.85)
		"chain": return _std(Color(0.5, 0.5, 0.54), 0.3, 0.95)
		"paper": return _std(Color(0.95, 0.93, 0.85), 0.9)
		"door": return _std(Color(0.48, 0.33, 0.19), 0.55)
		"fixture": return _std(Color(0.78, 0.78, 0.76), 0.35, 0.6)
		"vent": return _std(Color(0.55, 0.55, 0.53), 0.5, 0.5)
		"wallplate": return _std(Color(0.92, 0.91, 0.86), 0.4)
		"exit_sign": return _emissive(Color(1.0, 0.12, 0.08), 3.5)
		"extinguisher": return _std(Color(0.75, 0.05, 0.04), 0.3, 0.2)
		"plastic": return _std(Color(0.12, 0.12, 0.13), 0.45)
		"fabric": return _std(Color(0.2, 0.22, 0.28), 1.0)
		"cabinet": return _std(Color(0.58, 0.58, 0.55), 0.4, 0.55)
		"mug": return _std(Color(0.85, 0.83, 0.78), 0.3)
	push_warning("LevelKit: unknown material '%s'" % key)
	return _std(Color(0.5, 0.5, 0.5))


## The lighting look: dark, warm, foggy, with bloom on the tubes. Quality 0-2 trades
## volumetric fog and SSAO for speed.
static func make_environment(quality: int) -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.008, 0.008, 0.01)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.55, 0.4)
	env.ambient_light_energy = 0.16
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.85
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 1.15
	env.ssao_enabled = quality >= 1
	env.ssao_radius = 1.0
	env.ssao_intensity = 2.6
	env.ssao_detail = 0.6
	# Bounce light: the yellow walls tint everything around them, which is most of the look.
	env.sdfgi_enabled = quality >= 2
	env.sdfgi_use_occlusion = true
	env.sdfgi_min_cell_size = 0.15
	env.sdfgi_cascades = 4
	env.sdfgi_energy = 0.9
	env.sdfgi_bounce_feedback = 0.4
	env.ssil_enabled = quality == 1
	env.ssil_intensity = 1.2
	env.volumetric_fog_enabled = quality >= 2
	env.volumetric_fog_density = 0.022
	env.volumetric_fog_albedo = Color(0.92, 0.86, 0.66)
	env.volumetric_fog_length = 48.0
	env.volumetric_fog_anisotropy = 0.3
	env.fog_enabled = quality < 2
	env.fog_light_color = Color(0.22, 0.19, 0.11)
	env.fog_density = 0.018
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 0.9
	env.adjustment_brightness = Settings.brightness
	return env


## Applies the brightness setting to whatever world is showing (level or title backdrop).
static func apply_brightness(tree: SceneTree) -> void:
	for we in tree.root.find_children("*", "WorldEnvironment", true, false):
		var env := (we as WorldEnvironment).environment
		if env != null:
			env.adjustment_brightness = Settings.brightness


## Auto exposure: your eyes adjust between dark rooms and lit halls.
static func make_camera_attributes() -> CameraAttributesPractical:
	var ca := CameraAttributesPractical.new()
	ca.auto_exposure_enabled = true
	ca.auto_exposure_scale = 0.45
	ca.auto_exposure_speed = 1.2
	ca.auto_exposure_min_sensitivity = 50.0
	ca.auto_exposure_max_sensitivity = 220.0  # dark stays dark: don't brighten the scary bits
	return ca


## Batches boxes per material into one MultiMesh each, plus one StaticBody3D for collision.
class BoxBatch:
	var boxes: Dictionary = {}  # material key -> Array of Transform3D (unit box scaled)
	var shapes: Array = []  # [Transform3D, Vector3 size]

	func add(center: Vector3, size: Vector3, key: String, collide: bool = true, rot_y: float = 0.0) -> void:
		var rot := Basis.from_euler(Vector3(0.0, rot_y, 0.0))
		if not boxes.has(key):
			boxes[key] = []
		boxes[key].append(Transform3D(rot * Basis.from_scale(size), center))
		if collide:
			shapes.append([Transform3D(rot, center), size])

	func build(parent: Node3D, prefix: String) -> void:
		var unit := BoxMesh.new()
		for key in boxes:
			var list: Array = boxes[key]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = unit
			mm.instance_count = list.size()
			for i in list.size():
				mm.set_instance_transform(i, list[i])
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "%s_%s" % [prefix, key]
			mmi.multimesh = mm
			mmi.material_override = LevelKit.mat(key)
			parent.add_child(mmi)
		if shapes.is_empty():
			return
		var body := StaticBody3D.new()
		body.name = "%s_collision" % prefix
		body.collision_layer = 1
		body.collision_mask = 0
		parent.add_child(body)
		for s in shapes:
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = s[1]
			cs.shape = bs
			cs.transform = s[0]
			body.add_child(cs)
