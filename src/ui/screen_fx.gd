class_name ScreenFx
extends CanvasLayer
## Full-screen post-processing over the 3D view: film grain, vignette, a touch of chromatic
## aberration, and state effects (red pulse when grabbed, jitter on the energy drink, blur on the
## crash, black fade on a Layoff). Main feeds it the local player's state every frame.
## The body cam look (Settings.body_cam, on by default): the picture as a chest camera records it, a
## wide lens bowed at the edges with colour fringing there, crushed blacks and a cold flat grade,
## heavier grain, faint line noise and a timestamp with a blinking REC in the corner.

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
uniform float bodycam = 0.0;
float rnd(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 uv = SCREEN_UV;
	if (bodycam > 0.0) {
		// A wide lens: the middle is pushed out and the edges bowed in.
		vec2 c = uv - vec2(0.5);
		float r2 = dot(c * vec2(1.0, 0.75), c * vec2(1.0, 0.75));
		uv = vec2(0.5) + c * (1.0 - 0.13 * bodycam + 0.32 * bodycam * r2) / (1.0 - 0.13 * bodycam + 0.32 * bodycam * 0.39);
		// The sensor's lines: a sliver of the frame now and then jumps sideways.
		float band = step(0.985, rnd(vec2(floor(uv.y * 90.0), floor(TIME * 12.0))));
		uv.x += band * 0.004 * bodycam;
	}
	if (jitter > 0.0) {
		uv += vec2(sin(TIME * 83.0 + uv.y * 40.0), cos(TIME * 67.0 + uv.x * 30.0)) * 0.0025 * jitter;
	}
	vec2 dir = uv - vec2(0.5);
	float ab = aberration + jitter * 0.004 + red_pulse * 0.004 + bodycam * 0.012 * dot(dir, dir) * 4.0;
	float lod = blur * 3.0;
	vec3 col;
	col.r = textureLod(screen_tex, uv + dir * ab, lod).r;
	col.g = textureLod(screen_tex, uv, lod).g;
	col.b = textureLod(screen_tex, uv - dir * ab, lod).b;
	float n = rnd(uv * vec2(1920.0, 1080.0) + vec2(TIME * 61.0, TIME * 37.0));
	if (bodycam > 0.0) {
		// A cheap sensor at night: blacks crushed, mids lifted a little, cold and flat, grainy.
		float l = dot(col, vec3(0.299, 0.587, 0.114));
		vec3 graded = mix(vec3(l), col, 0.72) * vec3(0.93, 1.0, 1.04);
		graded = max(graded - 0.012, 0.0) * 1.12;
		col = mix(col, graded, bodycam);
		col += (rnd(uv * vec2(640.0, 360.0) + vec2(TIME * 13.0, TIME * 7.0)) - 0.5) * 0.05 * bodycam;
		col *= 1.0 - 0.04 * bodycam * step(0.5, fract(SCREEN_UV.y * 270.0));
		// The lens bowl outside the picture is black.
		if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) { col = vec3(0.0); }
	}
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
var stamp: Label
var mat: ShaderMaterial
var fade: float = 0.0
var _red: float = 0.0
var _jitter: float = 0.0
var _blur: float = 0.0
var _vignette: float = 0.5
static var _jolt_until: int = 0  # msec: a jump scare shakes the picture and floods it red until then


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
	stamp = Label.new()
	stamp.add_theme_font_size_override("font_size", 20)
	stamp.add_theme_color_override("font_color", Color(0.92, 0.92, 0.88, 0.85))
	stamp.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.7))
	stamp.add_theme_constant_override("outline_size", 4)
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["Consolas", "Lucida Console", "Courier New", "monospace"])
	stamp.add_theme_font_override("font", mono)
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stamp.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	stamp.position = Vector2(-420.0, 14.0)
	stamp.size = Vector2(400.0, 60.0)
	add_child(stamp)


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
	var jolting := Time.get_ticks_msec() < _jolt_until
	_jitter = lerpf(_jitter, 1.0 if buff == 1 else 0.0, k)
	if jolting:
		_jitter = 3.0
		_red = 1.0
	_blur = lerpf(_blur, 0.7 if buff == 2 else 0.0, k)
	_vignette = lerpf(_vignette, 1.2 if hunted else 0.5, k * 0.5)
	mat.set_shader_parameter("red_pulse", _red)
	mat.set_shader_parameter("jitter", _jitter)
	mat.set_shader_parameter("blur", _blur)
	mat.set_shader_parameter("desat", _blur * 0.6)
	mat.set_shader_parameter("vignette", _vignette)
	mat.set_shader_parameter("fade", fade)
	var cam := Settings.body_cam and me != null
	mat.set_shader_parameter("bodycam", 1.0 if cam else 0.0)
	mat.set_shader_parameter("grain", 0.08 if cam else 0.05)
	stamp.visible = cam and fade < 0.5
	if stamp.visible:
		var t := Time.get_datetime_dict_from_system()
		var rec := "● REC" if (Time.get_ticks_msec() / 600) % 2 == 0 else "      "
		stamp.text = "%s  %04d-%02d-%02d %02d:%02d:%02d
UNIT %02d   CHAIN CREW" % [rec, int(t.year), int(t.month), int(t.day), int(t.hour), int(t.minute), int(t.second), me.peer_id % 97 if me.peer_id > 1 else 1]
		stamp.position = Vector2(get_viewport().get_visible_rect().size.x - 420.0, 14.0)


## Any peer: a jump scare's jolt on this screen (the picture tears and flushes red) for seconds.
static func jolt(seconds: float) -> void:
	_jolt_until = Time.get_ticks_msec() + int(seconds * 1000.0)
