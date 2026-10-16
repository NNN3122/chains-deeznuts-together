class_name Hud
extends CanvasLayer
## In-game overlay. Reads the local player and GameState every frame; owns the Layoff sequence
## (black fade + Foreman notice) through ScreenFx.

const HELP_TEXT: String = """CONTROLS  (H hides this)
Move: WASD, or Up/Down arrows to walk and Left/Right or Q/E to turn
Run: Shift     Jump: Space (jump into a ledge to climb it)
Brace / sneak: hold Ctrl or C (anchor the chain, move quietly)
Look: move the mouse (push it against the side of the window to keep turning)
Use item: F or left click     Drop: G     Camera: V
Auto-walk: R     Pause and settings: Esc

The thing in the ceiling hunts by sound. Running, shooting, falling and a rattling chain are loud. If it grabs someone, stand next to them and BRACE."""

var screen_fx: ScreenFx
var _objective: Label
var _floor: Label
var _message_panel: PanelContainer
var _message: Label
var _message_left: float = 0.0
var _item_name: Label
var _item_hint: Label
var _item_bar: ProgressBar
var _item_panel: PanelContainer
var _noise_bar: ProgressBar
var _noise_fill: StyleBoxFlat
var _noise_label: Label
var _chain_label: Label
var _crosshair: ColorRect
var _grab_label: Label
var _help: PanelContainer
var _help_auto: float = 25.0
var _remote_badge: Label
var _layoff_label: Label
var _layoff_t: float = -1.0
var _t: float = 0.0
var _captions_box: VBoxContainer
var _caption_lines: Array = []  # [Label, seconds left]
var _caption_recent: Dictionary = {}  # line -> msec last shown
var _fps_label: Label
var _fps_t: float = 0.0
var _invite_label: Label  # host waiting alone: the invite code, until a friend joins
var _hints_shown: Dictionary = {}

## One-time tips the first time you reach each climb: [test point, co-op text, solo text].
const HINTS: Array = [
	["crates_start", "CLIMB: walk into the crate and tap Space. Do the same at each ledge.",
		"CLIMB: walk into the crate and tap Space. Your Ballast follows on the chain."],
	["plate", "THE LIFT: one of you stands on the yellow plate; the lift rises a moment later. Then hoist that person up with the chain.",
		"THE LIFT: step on the yellow plate (it locks), then hop onto the lift."],
	["boost_shelf", "TOO TALL: from the shelf, climb onto a teammate's head. Or use the jetpack in this room.",
		"TOO TALL: grab the jetpack in this room, stand under the hole and hold F."],
	["exit", "THE WAY OUT: everyone into the freight elevator to clock out.",
		"THE WAY OUT: step into the freight elevator. Bring your Ballast."],
]


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.get_theme()
	add_child(root)

	var top_left := VBoxContainer.new()
	top_left.position = Vector2(20.0, 14.0)
	top_left.custom_minimum_size = Vector2(430.0, 0.0)
	root.add_child(top_left)
	_floor = UiTheme.heading("B4", 34)
	top_left.add_child(_floor)
	_objective = UiTheme.text("", 15)
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective.custom_minimum_size = Vector2(430.0, 0.0)
	top_left.add_child(_objective)
	_invite_label = UiTheme.text("", 15, UiTheme.YELLOW)
	_invite_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_invite_label.custom_minimum_size = Vector2(430.0, 0.0)
	_invite_label.visible = false
	top_left.add_child(_invite_label)

	_remote_badge = UiTheme.text("REMOTE CONTROLS ON: move the mouse to look, hold it at the screen edge to keep turning", 15, UiTheme.YELLOW)
	_remote_badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
	_remote_badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_remote_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_remote_badge)

	_message_panel = PanelContainer.new()
	_message_panel.add_theme_stylebox_override("panel", UiTheme.panel_style(0.75))
	_message_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 140)
	_message_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_message_panel.visible = false
	root.add_child(_message_panel)
	_message = UiTheme.text("", 22)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_panel.add_child(_message)

	_item_panel = PanelContainer.new()
	_item_panel.add_theme_stylebox_override("panel", UiTheme.panel_style(0.7))
	_item_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 20)
	_item_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(_item_panel)
	var item_box := VBoxContainer.new()
	item_box.custom_minimum_size = Vector2(300.0, 0.0)
	_item_panel.add_child(item_box)
	item_box.add_child(UiTheme.text("LANYARD", 13, UiTheme.YELLOW_DIM))
	_item_name = UiTheme.heading("EMPTY", 26, UiTheme.PAPER)
	item_box.add_child(_item_name)
	_item_bar = ProgressBar.new()
	_item_bar.min_value = 0.0
	_item_bar.max_value = 1.0
	_item_bar.show_percentage = false
	_item_bar.custom_minimum_size = Vector2(280.0, 10.0)
	var fill := StyleBoxFlat.new()
	fill.bg_color = UiTheme.YELLOW
	_item_bar.add_theme_stylebox_override("fill", fill)
	item_box.add_child(_item_bar)
	_item_hint = UiTheme.text("walk into a glowing item to grab it", 14)
	item_box.add_child(_item_hint)

	var right := VBoxContainer.new()
	right.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 20)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.grow_vertical = Control.GROW_DIRECTION_BEGIN
	right.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(right)
	_noise_label = UiTheme.heading("NOISE", 20, UiTheme.PAPER)
	_noise_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_noise_label)
	_noise_bar = ProgressBar.new()
	_noise_bar.min_value = 0.0
	_noise_bar.max_value = 100.0
	_noise_bar.show_percentage = false
	_noise_bar.custom_minimum_size = Vector2(240.0, 14.0)
	_noise_fill = StyleBoxFlat.new()
	_noise_fill.bg_color = Color(0.4, 0.9, 0.4)
	_noise_bar.add_theme_stylebox_override("fill", _noise_fill)
	right.add_child(_noise_bar)
	_chain_label = UiTheme.text("CHAIN: SLACK", 16)
	_chain_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_chain_label)

	_crosshair = ColorRect.new()
	_crosshair.color = Color(1.0, 1.0, 1.0, 0.7)
	_crosshair.custom_minimum_size = Vector2(4.0, 4.0)
	_crosshair.size = Vector2(4.0, 4.0)
	_crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_crosshair)

	_grab_label = UiTheme.heading("IT HAS YOU\nshine a light up at it, shoot it, or get your team to BRACE beside you", 30, UiTheme.DANGER)
	_grab_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_grab_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 150)
	_grab_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_grab_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_grab_label.visible = false
	root.add_child(_grab_label)

	_help = PanelContainer.new()
	_help.add_theme_stylebox_override("panel", UiTheme.panel_style(0.72))
	_help.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE, 18)
	_help.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_help.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(_help)
	var help_label := UiTheme.text(HELP_TEXT, 13)
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_label.custom_minimum_size = Vector2(400.0, 0.0)
	_help.add_child(help_label)

	_layoff_label = UiTheme.heading("", 54, UiTheme.DANGER)
	_layoff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_layoff_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_layoff_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_layoff_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_layoff_label.visible = false
	root.add_child(_layoff_label)

	_captions_box = VBoxContainer.new()
	_captions_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 30)
	_captions_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_captions_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_captions_box.alignment = BoxContainer.ALIGNMENT_END
	_captions_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_captions_box)
	_fps_label = UiTheme.text("", 14, UiTheme.YELLOW_DIM)
	_fps_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
	_fps_label.offset_top = 40.0
	_fps_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_fps_label)
	add_to_group("hud")
	GameState.message_posted.connect(_on_message)
	GameState.objective_changed.connect(func(t: String) -> void: _objective.text = t)
	GameState.layoff_started.connect(_on_layoff)
	_objective.text = GameState.objective


func set_help_visible(on: bool) -> void:
	_help_auto = 0.0
	_help.visible = on


## A caption for something you can hear, with where it is relative to your view.
func caption(text: String, pos: Vector3) -> void:
	if not visible or not Settings.captions:
		return
	var where := ""
	var cam := get_viewport().get_camera_3d()
	if cam != null and pos != Vector3.INF:
		var to := pos - cam.global_position
		var dist := to.length()
		if dist > 45.0:
			return
		var fwd := -cam.global_transform.basis.z
		fwd.y = 0.0
		var flat := Vector3(to.x, 0.0, to.z)
		if to.y > 1.8 and flat.length() < 5.0:
			where = "above you"
		elif flat.length() < 1.2:
			where = "right here"
		elif fwd.length() > 0.01:
			var ang := rad_to_deg(fwd.normalized().signed_angle_to(flat.normalized(), Vector3.UP))
			if absf(ang) < 40.0:
				where = "ahead"
			elif absf(ang) > 140.0:
				where = "behind you"
			elif ang > 0.0:
				where = "to your left"
			else:
				where = "to your right"
		if dist > 18.0:
			where += ", far off"
	var line := "[%s, %s]" % [text, where] if where != "" else "[%s]" % text
	var now := Time.get_ticks_msec()
	if now - int(_caption_recent.get(line, -100000)) < 1800:
		return
	_caption_recent[line] = now
	var l := UiTheme.text(line, 18, Color(0.95, 0.95, 0.9))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.0, 0.0, 0.0, 0.55)
	bg.set_content_margin_all(4)
	l.add_theme_stylebox_override("normal", bg)
	_captions_box.add_child(l)
	_caption_lines.append([l, 3.5])
	while _caption_lines.size() > 3:
		(_caption_lines.pop_front()[0] as Label).queue_free()


func _tick_captions(delta: float) -> void:
	for entry in _caption_lines.duplicate():
		entry[1] = float(entry[1]) - delta
		var l: Label = entry[0]
		l.modulate.a = clampf(float(entry[1]) / 0.6, 0.0, 1.0)
		if float(entry[1]) <= 0.0:
			l.queue_free()
			_caption_lines.erase(entry)


func _check_hints(me: Player, level: Node) -> void:
	var tp: Dictionary = level.get("test_points")
	var solo := Net.get_players().size() == 1
	for h in HINTS:
		var key: String = h[0]
		if _hints_shown.has(key) or not tp.has(key):
			continue
		var p: Vector3 = tp[key]
		var d := Vector2(p.x - me.global_position.x, p.z - me.global_position.z).length()
		if d < 4.0 and absf(p.y - me.global_position.y) < 3.0:
			_hints_shown[key] = true
			_on_message(String(h[2] if solo else h[1]), 8.0)


func reset() -> void:
	_hints_shown.clear()
	for entry in _caption_lines:
		(entry[0] as Label).queue_free()
	_caption_lines.clear()
	_help_auto = 25.0
	_help.visible = true
	_layoff_t = -1.0
	_layoff_label.visible = false
	if screen_fx != null:
		screen_fx.fade = 0.0


func toggle_help() -> void:
	_help_auto = 0.0
	_help.visible = not _help.visible


func _process(delta: float) -> void:
	_t += delta
	var me := Net.get_local_player()
	_remote_badge.visible = Settings.remote_mode
	if _help_auto > 0.0:
		_help_auto -= delta
		if _help_auto <= 0.0:
			_help.visible = false
	if _message_left > 0.0:
		_message_left -= delta
		_message_panel.modulate.a = clampf(_message_left / 0.4, 0.0, 1.0)
		if _message_left <= 0.0:
			_message_panel.visible = false
	_tick_layoff(delta)
	_tick_captions(delta)
	_fps_t -= delta
	if _fps_t <= 0.0:
		_fps_t = 0.5
		_fps_label.visible = Settings.show_fps
		_fps_label.text = "%d FPS" % Engine.get_frames_per_second()
		_update_invite_label()
	if me == null:
		return
	var level := get_tree().get_first_node_in_group("level")
	if level != null:
		var f: int = level.call("floor_of", me.global_position.y)
		_floor.text = YellowRooms.FLOOR_NAMES[f]
		_check_hints(me, level)
	# Item card.
	if me.held_item_id != "":
		var data := ItemRegistry.get_data(me.held_item_id)
		_item_name.text = data.display_name.to_upper() if data != null else me.held_item_id.to_upper()
		_item_hint.text = (data.hud_hint if data != null else "F to use") + "   G drops it"
		_item_bar.value = me.item_charge
		_item_bar.visible = true
	else:
		_item_name.text = "EMPTY"
		_item_hint.text = "walk into a glowing item to grab it"
		_item_bar.visible = false
	# Noise meter.
	_noise_bar.value = me.noise
	var n := clampf(me.noise / 60.0, 0.0, 1.0)
	_noise_fill.bg_color = Color(0.4, 0.9, 0.4).lerp(Color(1.0, 0.2, 0.15), n)
	var hunted := false
	for c in get_tree().get_nodes_in_group("custodian"):
		if c.get("hunt_peer") == me.peer_id:
			hunted = true
	if hunted:
		_noise_label.text = "IT HEARS YOU"
		_noise_label.add_theme_color_override("font_color", UiTheme.DANGER if fmod(_t, 0.5) < 0.3 else UiTheme.PAPER)
	else:
		_noise_label.text = "NOISE"
		_noise_label.add_theme_color_override("font_color", UiTheme.PAPER)
	# Chain tension.
	var chain := get_tree().get_first_node_in_group("chain") as ChainSystem
	if chain != null and not chain.segments.is_empty():
		var t := chain.tension_for(me)
		if t > 0.98:
			_chain_label.text = "CHAIN: TAUT"
			_chain_label.add_theme_color_override("font_color", UiTheme.DANGER)
		elif t > 0.8:
			_chain_label.text = "CHAIN: TIGHT"
			_chain_label.add_theme_color_override("font_color", UiTheme.YELLOW)
		else:
			_chain_label.text = "CHAIN: SLACK"
			_chain_label.add_theme_color_override("font_color", Color(0.6, 0.95, 0.6))
	else:
		_chain_label.text = ""
	_crosshair.visible = me.camera_mode == Player.CameraMode.FIRST_PERSON or me.held_item_id == "pistol" or me.held_item_id == "flashlight" or me.held_item_id in ["bomb", "decoy"]
	_grab_label.visible = (me.synced_flags & Player.SFLAG_GRABBED) != 0


func _update_invite_label() -> void:
	var inv := Net.invite
	_invite_label.visible = not inv.is_empty() and Net.get_players().size() <= 1
	if not _invite_label.visible:
		return
	match String(inv["state"]):
		"ready":
			_invite_label.text = "Waiting for friends? Invite code: %s  (Esc to copy)" % inv["code"]
		"opening":
			_invite_label.text = "Opening your router for friends ..."
		_:
			_invite_label.text = "No invite code. Esc shows how friends can still join."


func _on_message(text: String, seconds: float) -> void:
	_message.text = text
	_message_panel.visible = true
	_message_panel.modulate.a = 1.0
	_message_left = seconds


func _on_layoff(count: int, reason: String) -> void:
	_layoff_label.text = "LAYOFF #%d\n%s\nReport to your last Break Room." % [count, reason]
	_layoff_label.add_theme_font_size_override("font_size", 40)
	_layoff_t = 0.0
	Sfx.play(self, "slam", 0.0, 0.5)


func _tick_layoff(delta: float) -> void:
	if _layoff_t < 0.0:
		return
	_layoff_t += delta
	var fade := 0.0
	if _layoff_t < 0.5:
		fade = _layoff_t / 0.5
	elif _layoff_t < 2.6:
		fade = 1.0
	elif _layoff_t < 3.2:
		fade = 1.0 - (_layoff_t - 2.6) / 0.6
	else:
		_layoff_t = -1.0
	if screen_fx != null:
		screen_fx.fade = fade
	_layoff_label.visible = _layoff_t >= 0.2 and _layoff_t < 2.8
