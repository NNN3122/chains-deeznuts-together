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

# --- Level 4: the manor grounds ---------------------------------------------------------------

## The whole estate's ground: two photo-scanned earths (ambientCG, CC0: an overgrown damp one
## and bare dirt with leaf litter), each sampled at two unrelated scales so no repeat shows,
## blended by large patches, darkened toward night, with black standing water in the hollows that
## catches the moon. Planar from above: the ground is one big box and only its top is ever seen.
const MANOR_EARTH_SHADER: String = """
shader_type spatial;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D ao_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D albedo2_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal2_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough2_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D ao2_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec3 overgrown = vec3(0.105, 0.1, 0.06);  // average colour of the grown-over earth
uniform vec3 bare = vec3(0.07, 0.056, 0.042);  // and of the bare mud
uniform float span = 3.0;  // m per repeat of each photo
uniform float span2 = 2.6;
uniform float bump = 1.3;
varying vec3 wpos;
%s
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
float lum(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }
void fragment() {
	vec2 p = wpos.xz;
	float k = smoothstep(0.3, 0.7, vnoise(p * 0.21));  // which of the two scales shows here
	vec2 a1 = p / span;
	vec2 b1 = p / (span * 2.7) + vec2(0.37, 0.11);
	vec2 a2 = p / span2;
	vec2 b2 = p / (span2 * 3.1) + vec2(0.61, 0.29);
	vec3 c1 = mix(texture(albedo_tex, a1).rgb, texture(albedo_tex, b1).rgb, k);
	vec3 c2 = mix(texture(albedo2_tex, a2).rgb, texture(albedo2_tex, b2).rgb, k);
	vec2 n1 = mix(texture(normal_tex, a1).rg, texture(normal_tex, b1).rg, k) * 2.0 - 1.0;
	vec2 n2 = mix(texture(normal2_tex, a2).rg, texture(normal2_tex, b2).rg, k) * 2.0 - 1.0;
	float m1 = max(lum(textureLod(albedo_tex, vec2(0.5), 12.0).rgb), 0.01);
	float m2 = max(lum(textureLod(albedo2_tex, vec2(0.5), 12.0).rgb), 0.01);
	float grown = smoothstep(0.36, 0.64, fbm(p * 0.07 + 5.0));
	vec3 col = mix(bare * pow(lum(c2) / m2, 1.15), overgrown * pow(lum(c1) / m1, 1.15) * mix(vec3(1.0), c1 / max(lum(c1), 0.01), 0.35), grown);
	col *= 0.62 + 0.62 * fbm(p * 0.045);
	float wet = smoothstep(0.66, 0.74, fbm(p * 0.11 + 3.0));
	col = mix(col, vec3(0.02, 0.022, 0.025), wet * 0.85);  // standing water, black
	ALBEDO = col;
	float r = mix(texture(rough2_tex, a2).r, texture(rough_tex, a1).r, grown);
	ROUGHNESS = mix(clamp(r + 0.05, 0.0, 1.0), 0.06, wet);  // the puddles catch the moon
	SPECULAR = mix(0.35, 0.9, wet);
	AO = mix(texture(ao2_tex, a2).r, texture(ao_tex, a1).r, grown);
	AO_LIGHT_AFFECT = 0.6;
	vec2 nm = mix(n2, n1, grown) * bump * (1.0 - wet);
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(vec3(nm.x, 1.0, -nm.y)), 0.0)).xyz);
}
"""

## A photo-scanned surface (ambientCG, CC0) mapped in world space from three sides, so any box at
## any size and turn gets it unstretched and upright: the walls, the mansion, the slate roofs, the
## floorboards, the woodwork, the gravel, the hedges. `tint` is the surface's average colour (night
## dark); the photo only adds the detail round it, so every surface keeps the level's darkness.
## Grime blotches and rain streaks break the repeat, and moss creeps up from the ground.
const MANOR_PBR_SHADER: String = """
shader_type spatial;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D ao_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec3 tint = vec3(0.3);
uniform float saturation = 0.5;  // how much of the photo's own hues survive round the tint
uniform float contrast = 1.1;
uniform float span = 2.0;  // m per repeat of the photo
uniform float bump = 1.0;
uniform float rough_bias = 0.0;
uniform float grime = 0.4;  // dark blotches and streaks that break up the repeat
uniform float moss = 0.0;  // green-black creeping up from the ground
uniform float wobble = 0.0;  // m: a hedge's lumpy outline
uniform float ground_y = 0.0;  // the estate's ground (600 m down in the building's run)
varying vec3 wpos;
varying vec3 wnrm;
%s
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	if (wobble > 0.0) {
		VERTEX += NORMAL * (vnoise(wpos.xz * 2.3 + wpos.y * 1.7) - 0.5) * wobble;
	}
}
float lum(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }
void fragment() {
	vec3 n = normalize(wnrm);
	vec3 w = pow(abs(n), vec3(4.0));
	w /= w.x + w.y + w.z;
	vec3 s = vec3(n.x < 0.0 ? -1.0 : 1.0, n.y < 0.0 ? -1.0 : 1.0, n.z < 0.0 ? -1.0 : 1.0);
	// One projection per axis, each upright and unmirrored seen from outside its face.
	vec2 ux = vec2(-wpos.z * s.x, -wpos.y) / span;
	vec2 uy = vec2(wpos.x * s.y, wpos.z) / span;
	vec2 uz = vec2(wpos.x * s.z, -wpos.y) / span;
	vec3 photo = texture(albedo_tex, ux).rgb * w.x + texture(albedo_tex, uy).rgb * w.y + texture(albedo_tex, uz).rgb * w.z;
	vec3 mean = max(textureLod(albedo_tex, vec2(0.5), 12.0).rgb, vec3(0.01));
	vec3 rel = mix(vec3(lum(photo) / lum(mean)), photo / mean, saturation);
	vec3 col = tint * pow(max(rel, vec3(0.0)), vec3(contrast));
	float h = wpos.y - ground_y;
	vec2 q = abs(n.y) > 0.5 ? wpos.xz : (abs(n.x) > 0.5 ? wpos.zy : wpos.xy);
	col *= mix(1.0, 0.5 + 0.95 * fbm(q * 0.13), grime);
	float along = abs(n.x) > abs(n.z) ? wpos.z : wpos.x;
	float streak = smoothstep(0.55, 0.9, vnoise(vec2(along * 2.5, h * 0.22))) * (1.0 - abs(n.y));
	col *= 1.0 - streak * grime * 0.6;
	float m = moss * clamp(smoothstep(0.5, 0.72, fbm(q * 0.8 + 11.0)) + smoothstep(2.6, 0.0, h) * 0.5 + max(n.y, 0.0) * 0.35, 0.0, 1.0);
	col = mix(col, vec3(0.05, 0.07, 0.035) * (0.6 + 0.8 * lum(photo) / lum(mean)), m * 0.8);
	ALBEDO = col;
	float r = texture(rough_tex, ux).r * w.x + texture(rough_tex, uy).r * w.y + texture(rough_tex, uz).r * w.z;
	ROUGHNESS = clamp(r + rough_bias, 0.04, 1.0);
	AO = texture(ao_tex, ux).r * w.x + texture(ao_tex, uy).r * w.y + texture(ao_tex, uz).r * w.z;
	AO_LIGHT_AFFECT = 0.5;
	// Each projection bends the true normal along its own two axes (green is up in the photo).
	vec2 nx = (texture(normal_tex, ux).rg * 2.0 - 1.0) * bump;
	vec2 ny = (texture(normal_tex, uy).rg * 2.0 - 1.0) * bump;
	vec2 nz = (texture(normal_tex, uz).rg * 2.0 - 1.0) * bump;
	vec3 bend = (vec3(0.0, 0.0, -s.x) * nx.x + vec3(0.0, 1.0, 0.0) * nx.y) * w.x
		+ (vec3(s.y, 0.0, 0.0) * ny.x + vec3(0.0, 0.0, -1.0) * ny.y) * w.y
		+ (vec3(s.z, 0.0, 0.0) * nz.x + vec3(0.0, 1.0, 0.0) * nz.y) * w.z;
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(n + bend), 0.0)).xyz);
}
"""

## The mansion's rooms, both floors: dark wood wainscot to a chair rail (raised panels, a skirting,
## the grain of a real dark wood), and above it a faded patterned wallpaper (a different dark colour
## room by room) that has broken away in patches to the plaster and brick underneath: the paint of a
## real broken painted plaster wall (ambientCG CC0) is recoloured as the paper, its broken patches
## are left as they are. A picture rail, a cornice, damp rising from the floor.
const MANOR_WALL_SHADER: String = """
shader_type spatial;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D ao_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D albedo2_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal2_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough2_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float ground_y = 0.0;  // the estate's ground (600 m down in the building's run)
uniform float floor2_y = 5.0;  // the upper floor, measured from the ground
uniform float span = 2.2;  // m per repeat of the plaster photo
uniform float wood_span = 1.6;
uniform float panel_top = 1.15;  // m: the chair rail
varying vec3 wpos;
varying vec3 wnrm;
%s
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
float lum(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }
// 1 on the wainscot's frame (stiles, rail, skirting), 0 on the panels sunk between them.
float frame_at(float a, float y) {
	float u = fract(a / 0.9);
	float stile = 1.0 - smoothstep(0.06, 0.1, min(u, 1.0 - u));
	float rail = smoothstep(panel_top - 0.18, panel_top - 0.13, y);
	float skirt = 1.0 - smoothstep(0.2, 0.25, y);
	return max(max(stile, rail), skirt);
}
void fragment() {
	vec3 n = normalize(wnrm);
	bool side = abs(n.x) > 0.5;
	float along = side ? wpos.z : wpos.x;
	vec3 across = side ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
	float h = wpos.y - ground_y;
	float storey = h >= floor2_y - 0.3 ? 1.0 : 0.0;
	float hl = h - storey * floor2_y;  // height above this storey's floor
	vec2 bend = vec2(0.0);
	vec3 col;
	float rough;
	float ao = 1.0;
	if (hl < panel_top) {
		// Wainscot: raised panels between stiles, a rail on top, a skirting at the foot.
		vec2 uv = vec2(along, -hl) / wood_span;
		vec3 wood = texture(albedo2_tex, uv).rgb;
		float wm = max(lum(textureLod(albedo2_tex, vec2(0.5), 12.0).rgb), 0.01);
		float frame = frame_at(along, hl);
		// The bevels where each panel drops behind its frame catch the light like real mouldings:
		// the normal leans off the slope of the frame's height (15 mm proud of the panel).
		float e = 0.006;
		vec2 grad = vec2(frame_at(along + e, hl) - frame_at(along - e, hl), frame_at(along, hl + e) - frame_at(along, hl - e)) / (2.0 * e);
		bend = -grad * 0.015 + (texture(normal2_tex, uv).rg * 2.0 - 1.0) * 0.6;
		col = vec3(0.085, 0.052, 0.032) * clamp(lum(wood) / wm, 0.3, 1.8) * mix(0.8, 1.15, frame);
		col *= 0.75 + 0.5 * fbm(vec2(along, hl) * 0.7);  // scuffs and water marks
		rough = clamp(texture(rough2_tex, uv).r - 0.15 * frame, 0.2, 1.0);
	} else {
		vec2 uv = vec2(along, -h) / span;
		vec3 photo = texture(albedo_tex, uv).rgb;
		float pm = max(lum(textureLod(albedo_tex, vec2(0.5), 12.0).rgb), 0.01);
		float rel = lum(photo) / pm;
		float sat = max(max(photo.r, photo.g), photo.b) - min(min(photo.r, photo.g), photo.b);
		float paint = smoothstep(0.92, 1.08, rel) * (1.0 - smoothstep(0.08, 0.18, sat));  // the white paint is the paper now
		// A faded damask, and the paper's colour by room.
		vec2 c = fract(vec2(along, hl) / vec2(0.53, 0.74)) - 0.5;
		float motif = smoothstep(0.21, 0.17, length(c * vec2(1.0, 0.72)) + 0.07 * sin(atan(c.y, c.x) * 6.0));
		vec2 room = floor(vec2(wpos.x / 17.0, wpos.z / 13.0)) + vec2(storey * 3.0, 0.0);
		float pick = hash(room + 0.5);
		vec3 paper = pick < 0.25 ? vec3(0.15, 0.045, 0.04) : (pick < 0.5 ? vec3(0.05, 0.085, 0.058) : (pick < 0.75 ? vec3(0.052, 0.062, 0.095) : vec3(0.1, 0.05, 0.085)));
		paper *= mix(1.0, 1.55, motif) * clamp(rel, 0.6, 1.25);
		vec3 bare = photo * 0.32;  // the plaster and brick under it, in the dark
		col = mix(bare, paper, paint);
		float damp = smoothstep(1.9, panel_top, hl) * (0.5 + 0.5 * fbm(vec2(along, hl) * 1.6));
		col *= 1.0 - damp * 0.5;
		float pr = 1.0 - smoothstep(0.0, 0.03, abs(hl - 2.95));
		col = mix(col, vec3(0.06, 0.04, 0.025), pr);  // the picture rail
		float ceiling = storey > 0.5 ? 4.0 : 4.6;
		col *= mix(1.0, 0.55, smoothstep(ceiling - 0.45, ceiling - 0.1, hl));  // the cornice in shadow
		rough = clamp(texture(rough_tex, uv).r + (paint > 0.5 ? 0.05 : 0.15), 0.0, 1.0);
		ao = texture(ao_tex, uv).r;
		bend = (texture(normal_tex, uv).rg * 2.0 - 1.0) * mix(1.4, 0.5, paint);
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	AO = ao;
	AO_LIGHT_AFFECT = 0.5;
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(n + across * bend.x + vec3(0.0, 1.0, 0.0) * bend.y), 0.0)).xyz);
}
"""

## Shelves of rotting books: spines in faded leathers, gaps where some fell.
const MANOR_BOOKS_SHADER: String = """
shader_type spatial;
varying vec3 wpos;
varying vec3 wnrm;
%s
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	float along = abs(wnrm.x) > 0.5 ? wpos.z : wpos.x;
	float shelf = fract(wpos.y / 0.5);
	float board = step(shelf, 0.08);
	float spine = floor(along / 0.07);
	float h = hash(vec2(spine, floor(wpos.y / 0.5)));
	float tall = step(shelf, 0.55 + 0.4 * h);
	float gap = step(0.9, hash(vec2(spine * 1.7, floor(wpos.y / 0.5) + 4.0)));
	vec3 leather = mix(vec3(0.22, 0.06, 0.04), vec3(0.08, 0.12, 0.07), step(0.5, h));
	leather = mix(leather, vec3(0.2, 0.15, 0.08), step(0.8, h));
	vec3 col = leather * (0.6 + 0.6 * fbm(vec2(along * 30.0, wpos.y * 4.0)));
	col = mix(col, vec3(0.02), (1.0 - tall) + gap);
	col = mix(col, vec3(0.1, 0.07, 0.045), board);
	if (abs(wnrm.y) > 0.5) { col = vec3(0.1, 0.07, 0.045); }
	ALBEDO = col;
	ROUGHNESS = 0.8;
}
"""

# --- Level 2: the pizzeria -------------------------------------------------------------------

const CHECKER_SHADER: String = """
shader_type spatial;
uniform vec3 light_color = vec3(0.86, 0.80, 0.62);
uniform vec3 dark_color = vec3(0.09, 0.07, 0.07);
varying vec3 wpos;
%s
void fragment() {
	vec2 cell = floor(wpos.xz / 0.45);
	float k = mod(cell.x + cell.y, 2.0);
	vec3 col = mix(dark_color, light_color, k);
	// Grout lines, scuffs, and years of spilled soda.
	vec2 f = abs(fract(wpos.xz / 0.45) - 0.5);
	float grout = smoothstep(0.47, 0.5, max(f.x, f.y));
	col = mix(col, vec3(0.3, 0.27, 0.24), grout * 0.6);
	col *= 0.8 + 0.3 * fbm(wpos.xz * 0.6);
	float sticky = smoothstep(0.58, 0.75, fbm(wpos.xz * 0.3 + vec2(3.0, 9.0)));
	col = mix(col, col * vec3(0.6, 0.5, 0.35), sticky * 0.7);
	ALBEDO = col;
	ROUGHNESS = mix(0.35, 0.7, sticky);
	SPECULAR = 0.4;
}
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
"""

const PIZZA_WALL_SHADER: String = """
shader_type spatial;
uniform vec3 base_color = vec3(0.82, 0.74, 0.56);
uniform vec3 stripe_a = vec3(0.6, 0.1, 0.08);
uniform vec3 stripe_b = vec3(0.12, 0.35, 0.18);
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
	vec3 col = base_color * (0.9 + 0.2 * fbm(vec2(along, wpos.y) * 2.1));
	// A red-and-green party band at eye height, wainscot below it.
	float band = step(1.25, h) * step(h, 1.55);
	float seg = step(0.5, fract(along * 0.8));
	col = mix(col, mix(stripe_a, stripe_b, seg), band);
	float wain = step(h, 1.0);
	col = mix(col, vec3(0.3, 0.17, 0.1) * (0.85 + 0.3 * fbm(vec2(along * 3.0, wpos.y * 6.0))), wain);
	float rail = step(1.0, h) * step(h, 1.08);
	col = mix(col, vec3(0.2, 0.12, 0.07), rail);
	// Grease and sauce low down, soot up high.
	float grime = smoothstep(0.45, 0.75, fbm(vec2(along * 0.5, h * 0.9) + vec2(5.0, 1.0)));
	col = mix(col, col * vec3(0.5, 0.42, 0.3), grime * 0.7 * (1.0 - wain));
	col *= 1.0 - 0.35 * smoothstep(3.0, 4.2, h);
	ALBEDO = col;
	ROUGHNESS = mix(0.85, 0.5, wain + rail);
}
"""

const KITCHEN_TILE_SHADER: String = """
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
	vec2 cell = floor(p / 0.15);
	vec2 f = abs(fract(p / 0.15) - 0.5);
	float grout = smoothstep(0.44, 0.48, max(f.x, f.y));
	vec3 col = vec3(0.78, 0.8, 0.76) * (0.9 + 0.12 * hash(cell));
	col = mix(col, vec3(0.42, 0.4, 0.36), grout);
	float grease = smoothstep(0.5, 0.8, fbm(p * 0.7 + vec2(2.0, 7.0)));
	col = mix(col, col * vec3(0.55, 0.5, 0.35), grease * 0.8);
	ALBEDO = col;
	ROUGHNESS = mix(0.25, 0.65, grease + grout * 0.5);
	SPECULAR = 0.5;
}
"""

const CURTAIN_SHADER: String = """
shader_type spatial;
uniform vec3 color = vec3(0.45, 0.04, 0.05);
varying vec3 wpos;
varying vec3 wnrm;
%s
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	float along = abs(wnrm.z) > abs(wnrm.x) ? wpos.x : wpos.z;
	float fold = 0.55 + 0.45 * sin(along * 14.0) * sin(along * 3.7 + 1.0);
	vec3 col = color * (0.45 + 0.7 * fold) * (0.9 + 0.2 * fbm(vec2(along, wpos.y) * 3.0));
	col *= 0.85 + 0.15 * smoothstep(0.0, 0.6, wpos.y - floor(wpos.y / 5.0) * 5.0);
	ALBEDO = col;
	ROUGHNESS = 0.95;
}
"""

const SHUTTER_SHADER: String = """
shader_type spatial;
varying vec3 wpos;
varying vec3 wnrm;
%s
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	// Corrugated galvanized steel: horizontal slats, scuffed and dented.
	float slat = 0.6 + 0.4 * abs(sin(wpos.y * 31.0));
	vec3 col = vec3(0.5, 0.52, 0.54) * slat;
	float along = abs(wnrm.z) > abs(wnrm.x) ? wpos.x : wpos.z;
	float rust = smoothstep(0.55, 0.8, fbm(vec2(along, wpos.y) * 2.3));
	col = mix(col, vec3(0.35, 0.2, 0.12), rust * 0.7);
	ALBEDO = col;
	ROUGHNESS = 0.5 + 0.4 * rust;
	METALLIC = 0.7 * (1.0 - rust);
}
"""

## The night over Carrow Heights: a sky shader instead of a flat colour. A gradient from the
## city's sodium glow at the horizon up to near-black, a field of stars that twinkle, a half
## moon with a halo, and two layers of value-noise cloud drifting with TIME, lit from below by
## the city where they're low. Stars hide behind the cloud.
const NIGHT_SKY_SHADER: String = """
shader_type sky;
uniform vec3 horizon_col : source_color = vec3(0.19, 0.08, 0.07);
uniform vec3 zenith_col : source_color = vec3(0.012, 0.013, 0.035);
uniform vec3 moon_dir = vec3(0.35, 0.42, -0.84);
uniform float cloud_cover = 0.5;
uniform float cloud_speed = 0.006;
uniform float star_density = 0.988;

// No sin() in the hash: at large inputs sin rounds differently for the same corner seen from two
// cells, and every cell edge becomes a hard seam. Cells wrap at 256 so the inputs stay exact.
float hash2(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float hash3(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec2 p) {
	vec2 i = mod(floor(p), 256.0);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);  // quintic: no creases at the cell edges
	float a = hash2(i);
	float b = hash2(mod(i + vec2(1.0, 0.0), 256.0));
	float c = hash2(mod(i + vec2(0.0, 1.0), 256.0));
	float d = hash2(mod(i + vec2(1.0, 1.0), 256.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	// Each octave rotated and shifted so the noise grid never lines up into squares.
	mat2 rot = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	float v = 0.0;
	float a = 0.5;
	for (int k = 0; k < 6; k++) {
		v += a * vnoise(p);
		p = rot * p * 2.02 + vec2(17.3, 9.1);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	float up = clamp(h, 0.0, 1.0);
	// The gradient, with the city's glow bleeding up from the horizon.
	vec3 col = mix(horizon_col, zenith_col, pow(up, 0.4));
	col += vec3(0.3, 0.14, 0.06) * exp(-abs(h) * 7.0) * 0.9;
	// Clouds on a plane overhead; a second, slower layer underneath for depth.
	float cov = 0.0;
	vec3 cloud_col = vec3(0.0);
	if (h > 0.01) {
		vec2 uv = d.xz / (h + 0.12);
		float c1 = fbm(uv * 1.3 + TIME * cloud_speed * vec2(1.0, 0.35));
		float c2 = fbm(uv * 2.9 - TIME * cloud_speed * 1.7 * vec2(0.6, 1.0) + 40.0);
		float c = c1 * 0.7 + c2 * 0.3;
		cov = smoothstep(1.0 - cloud_cover - 0.1, 1.0 - cloud_cover + 0.45, c + 0.12) * 0.92;
		cov *= smoothstep(0.0, 0.12, h);
		// Lit from below near the horizon (the streets), grey-blue above (the moon).
		float low = exp(-up * 3.5);
		cloud_col = mix(vec3(0.06, 0.06, 0.08), vec3(0.3, 0.17, 0.11), low);
		cloud_col += vec3(0.08, 0.09, 0.12) * (0.4 + 0.6 * c);
	}
	// Stars: one per cell of a quantised direction, most cells empty; they twinkle.
	if (h > 0.0) {
		vec3 sd = d * 220.0;
		vec3 cell = floor(sd);
		vec3 f = fract(sd) - 0.5;
		float r = hash3(cell);
		float on = step(star_density, r);
		float pt = smoothstep(0.22, 0.02, length(f));
		float tw = 0.55 + 0.45 * sin(TIME * (1.5 + 4.0 * fract(r * 31.0)) + r * 60.0);
		float bright = 0.6 + 1.4 * fract(r * 13.0);
		col += vec3(0.9, 0.92, 1.0) * on * pt * tw * bright * pow(up, 0.6) * (1.0 - cov);
	}
	// The moon: a disc, a soft halo, and its light on the cloud.
	vec3 md = normalize(moon_dir);
	float m = dot(d, md);
	float disc = smoothstep(0.99905, 0.99935, m);
	float crater = 0.85 + 0.15 * vnoise(d.xz * 900.0);
	float halo = pow(max(m, 0.0), 160.0) * 0.35 + pow(max(m, 0.0), 24.0) * 0.06;
	vec3 moon = vec3(0.95, 0.93, 0.82) * disc * crater * 2.6 + vec3(0.35, 0.36, 0.42) * halo;
	cloud_col += vec3(0.12, 0.12, 0.14) * pow(max(m, 0.0), 12.0);
	col = mix(col, cloud_col, cov);
	col += moon * (1.0 - cov * 0.85);
	COLOR = col;
}
"""

static var _mats: Dictionary = {}
static var _sky: Sky = null


## The roof's sky: built once and shared (the shader animates itself with TIME).
static func make_night_sky() -> Sky:
	if _sky != null:
		return _sky
	var sh := Shader.new()
	sh.code = NIGHT_SKY_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	var sky := Sky.new()
	sky.sky_material = m
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL  # the clouds drift slowly: reflections can catch up over a few frames
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	_sky = sky
	return sky


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
	_feed(m, folder, "")
	return m


## Sets albedo<suffix>_tex, normal<suffix>_tex, rough<suffix>_tex and ao<suffix>_tex from a texture
## folder (the normal map may be a .png or a .jpg; a set without an AO map leaves it white).
static func _feed(m: ShaderMaterial, folder: String, suffix: String) -> void:
	for pair in [["albedo", "color.jpg"], ["normal", "normal.png"], ["rough", "roughness.jpg"], ["ao", "ao.jpg"]]:
		var path: String = folder + String(pair[1])
		if not ResourceLoader.exists(path) and String(pair[0]) == "normal":
			path = folder + "normal.jpg"
		if ResourceLoader.exists(path):
			m.set_shader_parameter("%s%s_tex" % [pair[0], suffix], load(path))
		elif String(pair[0]) != "ao":
			push_warning("LevelKit: missing texture %s" % path)


const MANOR_TEXTURES: String = "res://assets/textures/manor/"
## The manor's photo surfaces (MANOR_PBR_SHADER): key -> [folder, tint, span m, bump, grime, moss,
## saturation, roughness bias]. The tints are the old hand-tuned night colours.
const MANOR_SURFACES: Dictionary = {
	"manor_stone": ["stone_dressed", Color(0.3, 0.29, 0.275), 2.4, 1.2, 0.45, 0.45, 0.35, 0.0],
	"manor_stone_dark": ["stone_old", Color(0.2, 0.195, 0.185), 2.2, 1.3, 0.5, 0.7, 0.35, 0.0],
	"manor_slate": ["slate", Color(0.075, 0.08, 0.09), 1.8, 1.0, 0.35, 0.3, 0.3, -0.1],
	"manor_planks": ["planks", Color(0.16, 0.105, 0.068), 2.6, 1.0, 0.35, 0.0, 0.2, 0.0],
	"manor_trim": ["wood", Color(0.11, 0.072, 0.05), 1.4, 1.0, 0.25, 0.0, 0.4, 0.0],
	"manor_gravel": ["gravel", Color(0.24, 0.232, 0.22), 1.4, 1.2, 0.3, 0.15, 0.3, 0.0],
	"manor_hedge": ["leaves", Color(0.075, 0.105, 0.05), 1.6, 1.4, 0.3, 0.0, 0.6, 0.0],
	"manor_ceiling": ["plaster", Color(0.2, 0.19, 0.175), 3.0, 1.1, 0.6, 0.0, 0.25, 0.05],
	"manor_ivy": ["leaves", Color(0.05, 0.075, 0.035), 0.9, 1.5, 0.3, 0.0, 0.6, 0.0],
	"manor_rug": ["rug", Color(0.13, 0.035, 0.035), 1.3, 1.0, 0.25, 0.0, 0.3, 0.0],
	"manor_rug_edge": ["rug", Color(0.11, 0.08, 0.035), 1.3, 1.0, 0.25, 0.0, 0.3, 0.0],
	"manor_sheet": ["cloth", Color(0.32, 0.31, 0.28), 0.9, 1.2, 0.35, 0.0, 0.15, 0.0],
	"manor_runner": ["rug", Color(0.14, 0.035, 0.03), 1.0, 1.0, 0.3, 0.0, 0.3, 0.0],  # the grand stair's carpet
}


static func _manor_surface(key: String) -> ShaderMaterial:
	var spec: Array = MANOR_SURFACES[key]
	var m := _textured(MANOR_PBR_SHADER, MANOR_TEXTURES + String(spec[0]) + "/")
	var c: Color = spec[1]
	m.set_shader_parameter("tint", Vector3(c.r, c.g, c.b))
	m.set_shader_parameter("span", float(spec[2]))
	m.set_shader_parameter("bump", float(spec[3]))
	m.set_shader_parameter("grime", float(spec[4]))
	m.set_shader_parameter("moss", float(spec[5]))
	m.set_shader_parameter("saturation", float(spec[6]))
	m.set_shader_parameter("rough_bias", float(spec[7]))
	if key == "manor_hedge" or key == "manor_ivy":
		m.set_shader_parameter("wobble", 0.12 if key == "manor_hedge" else 0.05)
	return m


static func _manor_walls() -> ShaderMaterial:
	var m := _textured(MANOR_WALL_SHADER, MANOR_TEXTURES + "plaster_painted/")
	_feed(m, MANOR_TEXTURES + "wood/", "2")
	return m


static func _manor_earth() -> ShaderMaterial:
	var m := _textured(MANOR_EARTH_SHADER, MANOR_TEXTURES + "earth_moss/")
	_feed(m, MANOR_TEXTURES + "earth_dirt/", "2")
	return m


## Every manor surface that measures height from the ground learns where the estate's ground is
## (y 0 on its own, far below the building in the Stack). Called by the Manor as it builds.
static func set_manor_ground(y: float) -> void:
	for key in MANOR_SURFACES.keys() + ["manor_paper"]:
		(mat(String(key)) as ShaderMaterial).set_shader_parameter("ground_y", y)


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


## The tower's red light: bright enough to bloom, and out of the fog, so it reads from the far
## end of the route.
static func _beacon() -> StandardMaterial3D:
	var m := _emissive(Color(1.0, 0.04, 0.03), 9.0)
	m.disable_fog = true
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
		"manor_frame": return _std(Color(0.3, 0.22, 0.08), 0.45, 0.6)  # tarnished gilt
		"manor_canvas": return _std(Color(0.05, 0.045, 0.035), 0.55)  # a portrait gone black under its varnish
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
		# Level 2: the pizzeria.
		"checker": return _shader_mat(CHECKER_SHADER)
		"pizza_wall": return _shader_mat(PIZZA_WALL_SHADER)
		"ktile": return _shader_mat(KITCHEN_TILE_SHADER)
		"curtain": return _shader_mat(CURTAIN_SHADER)
		"shutter": return _shader_mat(SHUTTER_SHADER)
		"stage_wood": return _std(Color(0.22, 0.13, 0.08), 0.6)
		"booth": return _std(Color(0.55, 0.06, 0.06), 0.45)
		"booth_dark": return _std(Color(0.3, 0.04, 0.04), 0.5)
		"laminate": return _std(Color(0.9, 0.86, 0.72), 0.3)
		"steel": return _std(Color(0.62, 0.64, 0.66), 0.3, 0.9)
		"rubber": return _std(Color(0.06, 0.06, 0.06), 0.9)
		"neon_red": return _emissive(Color(1.0, 0.1, 0.1), 3.0)
		"neon_green": return _emissive(Color(0.2, 1.0, 0.3), 2.5)
		"neon_pink": return _emissive(Color(1.0, 0.3, 0.7), 2.5)
		"crt": return _emissive(Color(0.45, 0.75, 0.95), 0.9)
		"crt_off": return _std(Color(0.08, 0.1, 0.1), 0.2)
		"chef_white": return _std(Color(0.88, 0.86, 0.8), 0.7)
		"chef_skin": return _std(Color(0.82, 0.62, 0.5), 0.55)
		"pepperoni": return _emissive(Color(1.0, 0.12, 0.05), 4.0)
		"teeth": return _std(Color(0.9, 0.85, 0.7), 0.35)
		"mustache": return _std(Color(0.05, 0.04, 0.04), 0.8)
		"kerchief": return _std(Color(0.7, 0.08, 0.08), 0.6)
		"dough": return _std(Color(0.85, 0.75, 0.5), 0.9)
		"balloon_red": return _std(Color(0.85, 0.1, 0.1), 0.2)
		"balloon_yellow": return _std(Color(0.95, 0.8, 0.1), 0.2)
		"balloon_blue": return _std(Color(0.15, 0.4, 0.9), 0.2)
		"arcade": return _std(Color(0.1, 0.08, 0.14), 0.5)
		"arcade_screen": return _emissive(Color(0.3, 0.9, 1.0), 2.2)
		"jukebox": return _std(Color(0.35, 0.1, 0.08), 0.35)
		"jukebox_glow": return _emissive(Color(1.0, 0.5, 0.15), 2.0)
		"freezer": return _std(Color(0.7, 0.72, 0.75), 0.35, 0.6)
		"frost": return _std(Color(0.85, 0.9, 0.95), 0.9)
		"pizza_crust": return _std(Color(0.8, 0.6, 0.3), 0.8)
		"pizza_sauce": return _std(Color(0.6, 0.12, 0.05), 0.5)
		"crate": return _std(Color(0.55, 0.45, 0.28), 0.9)
		"flour": return _std(Color(0.9, 0.88, 0.82), 1.0)
		"brass": return _std(Color(0.75, 0.6, 0.25), 0.3, 0.9)
		# Level 4: the manor grounds.
		"manor_earth": return _manor_earth()
		"manor_stone", "manor_stone_dark", "manor_hedge", "manor_planks", "manor_slate", "manor_gravel", "manor_trim", "manor_ceiling", "manor_ivy", "manor_rug", "manor_rug_edge", "manor_sheet", "manor_runner": return _manor_surface(key)
		"manor_paper": return _manor_walls()
		"manor_books": return _shader_mat(MANOR_BOOKS_SHADER)
		"manor_window": return _std(Color(0.015, 0.018, 0.022), 0.08, 0.4)
		"manor_window_lit": return _emissive(Color(0.95, 0.55, 0.22), 0.9)
		"manor_candle": return _emissive(Color(1.0, 0.7, 0.35), 3.0)
		"manor_bulb": return _emissive(Color(1.0, 0.72, 0.4), 2.2)
		"manor_bulb_red": return _emissive(Color(1.0, 0.08, 0.04), 4.0)
		"manor_water": return _std(Color(0.02, 0.03, 0.03), 0.05, 0.3)
		"rope": return _std(Color(0.6, 0.5, 0.3), 0.95)
		"hazard_dark": return _std(Color(0.15, 0.14, 0.1), 0.7)
		"gold": return _std(Color(0.9, 0.75, 0.3), 0.3, 0.8)
		"speaker": return _std(Color(0.1, 0.1, 0.1), 0.8)
		"stage_light": return _emissive(Color(1.0, 0.85, 0.6), 2.5)
		"party_cloth": return _std(Color(0.95, 0.35, 0.5), 0.8)
		"camera": return _std(Color(0.85, 0.85, 0.82), 0.4, 0.3)
		"led_red": return _emissive(Color(1.0, 0.05, 0.05), 5.0)
		"beacon": return _beacon()
		# Level 3 tech: the Loading Lot and the infected.
		"asphalt": return _std(Color(0.09, 0.09, 0.1), 0.97)
		"paint": return _std(Color(0.85, 0.8, 0.5), 0.8)
		"hoarding": return _std(Color(0.2, 0.32, 0.26), 0.55, 0.4)
		"dumpster": return _std(Color(0.1, 0.3, 0.18), 0.6, 0.3)
		"van": return _std(Color(0.7, 0.7, 0.68), 0.45, 0.5)
		"brick": return _std(Color(0.32, 0.17, 0.13), 0.95)
		"tower": return _std(Color(0.16, 0.18, 0.22), 0.6, 0.3)
		"tower_far": return _std(Color(0.05, 0.05, 0.07), 0.9)
		"window_lit": return _emissive(Color(1.0, 0.8, 0.5), 1.6)
		"window_dark": return _std(Color(0.04, 0.05, 0.07), 0.25, 0.4)
		"billboard": return _emissive(Color(0.95, 0.85, 0.3), 0.9)
		"tank": return _std(Color(0.3, 0.2, 0.15), 0.85)
		"street_lamp": return _emissive(Color(1.0, 0.6, 0.2), 4.0)
		"jumper_shell": return _std(Color(0.14, 0.16, 0.12), 0.3, 0.2)
		"jumper_fur": return _std(Color(0.24, 0.2, 0.14), 0.95)
		"helipad": return _std(Color(0.12, 0.12, 0.13), 0.9)
		"heli_body": return _std(Color(0.8, 0.78, 0.7), 0.4, 0.4)
		"heli_glass": return _std(Color(0.1, 0.15, 0.2), 0.1, 0.6)
		"rotor": return _std(Color(0.08, 0.08, 0.08), 0.5, 0.5)
		"fire_escape": return _std(Color(0.18, 0.1, 0.08), 0.6, 0.7)
		"hire_skin": return _std(Color(0.78, 0.74, 0.7), 0.9)
		"hire_shirt": return _std(Color(0.6, 0.62, 0.66), 0.9)
		"hire_vest": return _emissive(Color(0.95, 0.42, 0.08), 0.25)
		"infected_skin": return _std(Color(0.5, 0.55, 0.42), 0.85)
		"infected_cloth": return _std(Color(0.18, 0.2, 0.26), 0.95)
		"courier_sash": return _emissive(Color(0.75, 0.85, 0.12), 0.5)
		"infected_eye": return _emissive(Color(0.9, 0.95, 0.8), 2.5)
	push_warning("LevelKit: unknown material '%s'" % key)
	return _std(Color(0.5, 0.5, 0.5))


## The lighting look: dark, warm, foggy, with bloom on the tubes. Quality 0-2 trades
## volumetric fog and SSAO for speed. level 1 (the pizzeria) is colder: house lights off, red
## exit signs and screens doing the work.
static func make_environment(quality: int, level: int = 0) -> Environment:
	if level == 3:
		return _manor_environment(quality)
	var env := Environment.new()
	var pizzeria := level == 1
	var outdoors := level == 2  # the roof: a night sky over the city, no bounce light to speak of
	env.background_mode = Environment.BG_SKY if outdoors else Environment.BG_COLOR
	if outdoors:
		env.sky = make_night_sky()
		env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.background_color = Color(0.07, 0.035, 0.03) if outdoors else Color(0.008, 0.008, 0.01)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.42, 0.42) if pizzeria else Color(0.62, 0.55, 0.4)
	env.ambient_light_energy = 0.11 if pizzeria else 0.045  # rooms are lit by their own tubes, or not at all; the office is pools of light
	if outdoors:
		# The horror pass: a cold, starved ambient and a fog that eats the city past a roof or two,
		# so the landing lamps are pools you run between and the tower's red light (which ignores
		# fog) is the only bright thing out there.
		env.ambient_light_color = Color(0.34, 0.38, 0.5)
		env.ambient_light_energy = 0.05  # darker again (the user: Level 3 still too bright)
		env.tonemap_mode = Environment.TONE_MAPPER_AGX
		env.tonemap_exposure = 0.95
		env.glow_enabled = true
		env.glow_intensity = 0.75
		env.glow_bloom = 0.04
		env.glow_hdr_threshold = 1.1
		env.ssao_enabled = quality >= 1
		env.fog_enabled = true
		env.fog_light_color = Color(0.022, 0.028, 0.04)
		env.fog_density = 0.032
		env.fog_sky_affect = 0.55
		# Lamps hang halos in the murk on high; the moon barely lights it (Moon's volumetric energy).
		env.volumetric_fog_enabled = quality >= 2
		env.volumetric_fog_density = 0.014
		env.volumetric_fog_albedo = Color(0.55, 0.58, 0.64)
		env.volumetric_fog_length = 56.0
		env.volumetric_fog_anisotropy = 0.45
		env.volumetric_fog_ambient_inject = 0.0
		env.adjustment_enabled = true
		env.adjustment_contrast = 1.06
		env.adjustment_saturation = 0.85
		env.adjustment_brightness = Settings.brightness
		return env
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
	env.volumetric_fog_density = 0.028 if pizzeria else 0.022
	env.volumetric_fog_albedo = Color(0.8, 0.62, 0.6) if pizzeria else Color(0.92, 0.86, 0.66)
	env.volumetric_fog_length = 48.0
	env.volumetric_fog_anisotropy = 0.3
	env.fog_enabled = quality < 2
	env.fog_light_color = Color(0.16, 0.1, 0.1) if pizzeria else Color(0.22, 0.19, 0.11)
	env.fog_density = 0.018
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 0.9
	env.adjustment_brightness = Settings.brightness
	return env


## Level 4, the manor grounds at night: the roof's sky, but a thick, low, grey-green fog that
## swallows everything past a few tombstones, a starved ambient, and lamps that hang halos in it.
static func _manor_environment(quality: int) -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = make_night_sky()
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.36, 0.42, 0.44)
	env.ambient_light_energy = 0.085  # enough to read the stone and bark out of the beam; still a dark night
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.05
	env.ssao_enabled = quality >= 1
	env.fog_enabled = true
	# Far things fade into grey mist, not into black: at night unlit fog only reads as more dark.
	env.fog_light_color = Color(0.075, 0.085, 0.085)
	# With volumetric fog on, it carries the fog (the mansion and the crypt take it away indoors);
	# the depth fog, which nothing can take away, only fades the distance.
	env.fog_density = 0.016 if quality >= 1 else 0.09
	env.fog_sky_affect = 0.85
	env.fog_height = 1.8
	env.fog_height_density = 0.03 if quality >= 1 else 0.15  # thicker still near the ground
	# The moving mist and banks (Manor._build_fog_banks) are fog volumes: they need volumetric fog,
	# so the manor has it from Medium up, not only on High.
	env.volumetric_fog_enabled = quality >= 1
	env.volumetric_fog_density = 0.04
	env.volumetric_fog_albedo = Color(0.74, 0.78, 0.78)
	env.volumetric_fog_emission = Color(0.012, 0.014, 0.014)
	env.volumetric_fog_length = 64.0
	env.volumetric_fog_anisotropy = 0.45
	env.volumetric_fog_ambient_inject = 0.35
	env.volumetric_fog_temporal_reprojection_amount = 0.8  # less smearing behind the moving banks
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 0.72
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
	ca.auto_exposure_max_sensitivity = 105.0  # dark stays dark: a blackout is not undone by your eyes adjusting
	return ca


## Batches boxes per material into one MultiMesh each, plus one StaticBody3D for collision.
class BoxBatch:
	const PROP_CHUNK: float = 12.0  # m: props are batched per square this size (two rooms)
	const PROP_DRAW_RANGE: float = 34.0  # m: further than this a prop chunk isn't drawn (it's dark there anyway)
	var boxes: Dictionary = {}  # material key -> Array of Transform3D (unit box scaled)
	var shapes: Array = []  # [Transform3D, Vector3 size]
	var props: Dictionary = {}  # PropMeshes key -> Array of Transform3D (sculpted furniture)

	func add(center: Vector3, size: Vector3, key: String, collide: bool = true, rot_y: float = 0.0) -> void:
		var rot := Basis.from_euler(Vector3(0.0, rot_y, 0.0))
		# Box-shaped furniture (cardboard, partitions, doors, tops) is drawn sculpted instead.
		var prop := PropMeshes.boxed(key, center, size, rot_y)
		if not prop.is_empty():
			add_prop(prop[0], prop[1])
			if collide:
				shapes.append([Transform3D(rot, center), size])
			return
		if not boxes.has(key):
			boxes[key] = []
		boxes[key].append(Transform3D(rot * Basis.from_scale(size), center))
		if collide:
			shapes.append([Transform3D(rot, center), size])

	## A sculpted prop (PropMeshes) at xform. Its collision, if any, goes in with add_solid.
	func add_prop(key: String, xform: Transform3D) -> void:
		if not props.has(key):
			props[key] = []
		props[key].append(xform)

	## Collision only: the shape of a prop that is drawn by add_prop.
	func add_solid(center: Vector3, size: Vector3, rot_y: float = 0.0) -> void:
		shapes.append([Transform3D(Basis.from_euler(Vector3(0.0, rot_y, 0.0)), center), size])

	func build(parent: Node3D, prefix: String) -> void:
		var unit := BoxMesh.new()
		# Props are drawn in PROP_CHUNK squares, not one batch per floor: a floor-wide batch can't
		# be culled, takes no LOD, and every shadow pass drew all of it.
		for key in props:
			var chunks: Dictionary = {}
			for xf: Transform3D in props[key]:
				var ck := Vector2i(floori(xf.origin.x / PROP_CHUNK), floori(xf.origin.z / PROP_CHUNK))
				if not chunks.has(ck):
					chunks[ck] = []
				chunks[ck].append(xf)
			for ck: Vector2i in chunks:
				var plist: Array = chunks[ck]
				var pmm := MultiMesh.new()
				pmm.transform_format = MultiMesh.TRANSFORM_3D
				pmm.mesh = PropMeshes.mesh(key)
				pmm.instance_count = plist.size()
				for i in plist.size():
					pmm.set_instance_transform(i, plist[i])
				var pmi := MultiMeshInstance3D.new()
				pmi.name = "%s_prop_%s_%d_%d" % [prefix, key, ck.x, ck.y]
				pmi.multimesh = pmm
				pmi.material_override = PropMeshes.material_for(key)
				pmi.visibility_range_end = PROP_DRAW_RANGE
				pmi.visibility_range_end_margin = 4.0
				pmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
				if key.begins_with("manor_grass"):
					pmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # thousands of blades: their shadows cost more than they show
				parent.add_child(pmi)
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
