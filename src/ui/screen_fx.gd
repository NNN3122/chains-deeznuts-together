class_name ScreenFx
extends CanvasLayer
## Full-screen post-processing over the 3D view: film grain, vignette, a touch of chromatic
## aberration, and state effects (red pulse when grabbed, jitter on the energy drink, blur on the
## crash, black fade on a Layoff). Main feeds it the local player's state every frame.

const SHADER: String = """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float grain = 0.05;
uniform float vignette = 0.5;
uniform float aberration = 0.0012;
uniform float red_pulse = 0.0;
uniform float jitter = 0.0;
uniform float blur = 0.0;
uniform float fade = 0.0;
uniform float desat = 0.0;
float rnd(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 uv = SCREEN_UV;
	if (jitter > 0.0) {
		uv += vec2(sin(TIME * 83.0 + uv.y * 40.0), cos(TIME * 67.0 + uv.x * 30.0)) * 0.0025 * jitter;
	}
	vec2 dir = uv - vec2(0.5);
	float ab = aberration + jitter * 0.004 + red_pulse * 0.004;
	float lod = blur * 3.0;
	vec3 col;
	col.r = textureLod(screen_tex, uv + dir * ab, lod).r;
	col.g = textureLod(screen_tex, uv, lod).g;
	col.b = textureLod(screen_tex, uv - dir * ab, lod).b;
	float n = rnd(uv * vec2(1920.0, 1080.0) + vec2(TIME * 61.0, TIME * 37.0));
	col += (n - 0.5) * grain;
	float v = 1.0 - smoothstep(0.35, 0.95, length(dir * vec2(1.0, 0.8)) * (1.0 + vignette));
	col *= mix(1.0, v, 0.85);
	float g = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(g), desat);
	float pulse = red_pulse * (0.4 + 0.35 * sin(TIME * 9.0));
	col = mix(col, col * vec3(1.5, 0.35, 0.3) + vec3(0.15, 0.0, 0.0) * (1.0 - v), pulse);
	col = mix(col, vec3(0.0), clamp(fade, 0.0, 1.0));
	COLOR = vec4(col, 1.0);
}
"""

var rect: ColorRect
var mat: ShaderMaterial
var fade: float = 0.0
var _red: float = 0.0
var _jitter: float = 0.0
var _blur: float = 0.0
var _vignette: float = 0.5


func _ready() -> void:
	layer = 5
	rect = ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = SHADER
	mat = ShaderMaterial.new()
	mat.shader = sh
	rect.material = mat
	add_child(rect)


func _process(delta: float) -> void:
	var me := Net.get_local_player()
	var grabbed := false
	var buff := 0
	var hunted := false
	if me != null:
		grabbed = (me.synced_flags & Player.SFLAG_GRABBED) != 0
		buff = me.buff_state
		for c in get_tree().get_nodes_in_group("monster"):
			if c.get("hunt_peer") == me.peer_id:
				hunted = true
	var k := clampf(delta * 4.0, 0.0, 1.0)
	_red = lerpf(_red, 1.0 if grabbed else 0.0, k)
	_jitter = lerpf(_jitter, 1.0 if buff == 1 else 0.0, k)
	_blur = lerpf(_blur, 0.7 if buff == 2 else 0.0, k)
	_vignette = lerpf(_vignette, 1.2 if hunted else 0.5, k * 0.5)
	mat.set_shader_parameter("red_pulse", _red)
	mat.set_shader_parameter("jitter", _jitter)
	mat.set_shader_parameter("blur", _blur)
	mat.set_shader_parameter("desat", _blur * 0.6)
	mat.set_shader_parameter("vignette", _vignette)
	mat.set_shader_parameter("fade", fade)
