class_name NightShiftPanel
extends VBoxContainer
## The pizzeria's slice of the HUD: the badge clock and power bank, what Pappy is up to (pinned
## by someone's eyes, or counting down to his next Step), and, when you're clipped into a
## security desk, the handset: a live camera feed rendered by a second camera into a small
## viewport, with scanlines over it. Purely local; it reads replicated state.

const FEED_SIZE: Vector2i = Vector2i(384, 216)
const CRT_SHADER: String = """
shader_type canvas_item;
uniform float static_amount = 0.08;
uniform float face = 0.0;
float rnd(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233)) + TIME * 7.0) * 43758.5453); }
void fragment() {
	vec2 uv = UV;
	uv.x += (rnd(vec2(floor(uv.y * 90.0), 1.0)) - 0.5) * 0.004 * (1.0 + static_amount * 20.0);
	vec4 col = texture(TEXTURE, uv);
	float g = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	col.rgb = mix(col.rgb, vec3(g * 0.75, g * 1.0, g * 0.9), 0.65) * 1.25;
	float scan = 0.85 + 0.15 * sin(uv.y * 216.0 * 3.14159);
	col.rgb *= scan;
	float n = rnd(uv * 300.0);
	col.rgb = mix(col.rgb, vec3(n), static_amount);
	float v = 1.0 - smoothstep(0.5, 1.0, length(uv - 0.5) * 1.4);
	col.rgb *= v;
	if (face > 0.0) {
		vec2 c = uv - vec2(0.5, 0.45);
		float eye1 = smoothstep(0.07, 0.05, length((c - vec2(-0.12, 0.08)) * vec2(1.0, 1.8)));
		float eye2 = smoothstep(0.07, 0.05, length((c - vec2(0.12, 0.08)) * vec2(1.0, 1.8)));
		float grin = smoothstep(0.03, 0.02, abs(c.y + 0.12 - 0.1 * (1.0 - cos(c.x * 9.0)))) * step(abs(c.x), 0.22);
		col.rgb = mix(col.rgb * 0.15, vec3(1.0, 0.1, 0.05), (eye1 + eye2) * face);
		col.rgb = mix(col.rgb, vec3(0.95, 0.9, 0.7), grin * face);
	}
	COLOR = col;
}
"""

var _clock: Label
var _status: Label
var _bar: ProgressBar
var _bar_fill: StyleBoxFlat
var _feed_box: PanelContainer
var _feed: TextureRect
var _feed_label: Label
var _feed_alert: Label
var _sub: SubViewport
var _cam: Camera3D
var _mat: ShaderMaterial
var _static: float = 0.08
var _face_until: int = 0
var _t: float = 0.0


func _ready() -> void:
	add_theme_constant_override("separation", 4)
	_clock = UiTheme.heading("12:00 AM   POWER 100%", 22, UiTheme.PAPER)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_clock)
	_status = UiTheme.text("", 15, UiTheme.YELLOW)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(400.0, 0.0)
	add_child(_status)
	_bar = ProgressBar.new()
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(400.0, 8.0)
	_bar_fill = StyleBoxFlat.new()
	_bar_fill.bg_color = UiTheme.YELLOW
	_bar.add_theme_stylebox_override("fill", _bar_fill)
	_bar.visible = false
	add_child(_bar)
	_feed_box = PanelContainer.new()
	_feed_box.add_theme_stylebox_override("panel", UiTheme.panel_style(0.85))
	_feed_box.size_flags_horizontal = Control.SIZE_SHRINK_END
	_feed_box.visible = false
	add_child(_feed_box)
	var box := VBoxContainer.new()
	_feed_box.add_child(box)
	_feed_label = UiTheme.text("CAM 1: DINING   (F: next camera)", 14, Color(0.6, 0.95, 1.0))
	box.add_child(_feed_label)
	_sub = SubViewport.new()
	_sub.size = FEED_SIZE
	_sub.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_sub.msaa_3d = Viewport.MSAA_DISABLED
	_sub.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	_sub.positional_shadow_atlas_size = 1024
	add_child(_sub)
	_cam = Camera3D.new()
	_cam.fov = 72.0
	_cam.near = 0.1
	_cam.current = true
	_sub.add_child(_cam)
	_feed = TextureRect.new()
	_feed.texture = _sub.get_texture()
	_feed.custom_minimum_size = Vector2(FEED_SIZE)
	_feed.stretch_mode = TextureRect.STRETCH_SCALE
	_feed.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var sh := Shader.new()
	sh.code = CRT_SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_feed.material = _mat
	box.add_child(_feed)
	_feed_alert = UiTheme.heading("", 18, UiTheme.DANGER)
	_feed_alert.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_feed_alert)


## The Static Face scare: a second of snow, then him, 30 cm from the lens.
func static_face() -> void:
	_static = 1.0
	_face_until = Time.get_ticks_msec() + 1600
	if _feed_box.visible:
		Sfx.play(self, "static", 0.0, 1.0)


## Called by the HUD every frame while the local player is in the pizzeria.
func refresh(delta: float, me: Player, pizzeria: Pizzeria) -> void:
	_t += delta
	var power := int(ceilf(pizzeria.power))
	_clock.text = "%s   POWER %d%%" % [pizzeria.clock_text(), power]
	_clock.add_theme_color_override("font_color", UiTheme.DANGER if power <= 15 else UiTheme.PAPER)
	_refresh_status(me, pizzeria)
	_refresh_feed(me, pizzeria)


func _refresh_status(me: Player, pizzeria: Pizzeria) -> void:
	var pappy := pizzeria.pappy
	var my_floor := pizzeria.floor_of(me.global_position.y)
	var text := ""
	var color := UiTheme.YELLOW
	var show_bar := false
	if pizzeria.generator_t > 0.0:
		text = "Restarting the generator... %d%%" % int(pizzeria.generator_t * 100.0)
		color = Color(0.5, 1.0, 0.6)
	elif pizzeria.blackout():
		text = "POWER OUT. He walks in the dark. Generator: any Break Room."
		color = UiTheme.DANGER
	elif pappy == null:
		text = ""
	else:
		match pappy.pstate:
			PappyPepperoni.PState.DORMANT:
				text = "Pappy hasn't noticed you. Yet."
				color = UiTheme.YELLOW_DIM
			PappyPepperoni.PState.TRAVEL:
				text = "Servos on the service stairs. He's coming to this floor."
			PappyPepperoni.PState.STUNNED:
				text = "HE'S LOCKED UP. MOVE."
				color = Color(0.5, 1.0, 0.6)
			PappyPepperoni.PState.BANGING:
				text = "HE'S AT THE SHUTTER. HOLD IT (CTRL)."
				color = UiTheme.DANGER
			PappyPepperoni.PState.LUNGE, PappyPepperoni.PState.GRAB:
				var who := Net.find_player(pappy.hunt_peer)
				text = "HE HAS %s. Air horn, popper, or light in his face." % (who.display_name.to_upper() if who != null else "SOMEONE")
				color = UiTheme.DANGER
			_:
				if pappy.floor_index != my_floor:
					text = "Pappy is on the %s." % Pizzeria.FLOOR_NAMES[pappy.floor_index]
					color = UiTheme.YELLOW_DIM
				elif pappy.watched:
					text = "EYES ON HIM (%s): he can't move." % pappy.node_name()
					color = Color(0.5, 1.0, 0.6)
				else:
					text = "NOBODY IS WATCHING HIM (%s). Next step in %d s." % [pappy.node_name(), int(ceilf(pappy.step_length() * (1.0 - pappy.step_fraction)))]
					color = UiTheme.DANGER if pappy.step_fraction > 0.7 else UiTheme.YELLOW
					show_bar = true
	_status.text = text
	_status.add_theme_color_override("font_color", color)
	_bar.visible = show_bar
	if show_bar:
		_bar.value = pappy.step_fraction
		_bar_fill.bg_color = UiTheme.YELLOW.lerp(UiTheme.DANGER, pappy.step_fraction)


func _refresh_feed(me: Player, pizzeria: Pizzeria) -> void:
	var desk: SecurityDesk = null
	for d in pizzeria.desks:
		if d.occupant_peer == me.peer_id:
			desk = d
			break
	var show := desk != null and not pizzeria.blackout()
	_feed_box.visible = show
	_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS if show else SubViewport.UPDATE_DISABLED
	if not show:
		return
	var cam := desk.current_cam()
	if not cam.is_empty():
		_cam.global_position = cam["pos"]
		_cam.look_at(cam["look"], Vector3.UP)
		_feed_label.text = "CAM %d: %s   (F: next camera)" % [desk.cam_index + 1, cam["name"]]
	var pappy := pizzeria.pappy
	var on_cam := pappy != null and pappy.is_active() and pappy.floor_index == desk.floor_index \
		and pizzeria.node_cam(pappy.floor_index, pappy.node_index) == desk.cam_index
	_feed_alert.text = "PAPPY ON CAMERA: HE CAN'T MOVE" if on_cam else ""
	_feed_alert.visible = on_cam and fmod(_t, 0.8) < 0.55
	var face := 1.0 if Time.get_ticks_msec() < _face_until and Time.get_ticks_msec() > _face_until - 700 else 0.0
	_static = lerpf(_static, 0.08, 0.05)
	_mat.set_shader_parameter("static_amount", _static + (0.3 if face > 0.0 else 0.0))
	_mat.set_shader_parameter("face", face)
