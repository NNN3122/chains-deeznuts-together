class_name SettingsPanel
extends Control
## Settings overlay. Changes apply immediately and are saved when the panel closes.

signal closed

var _remote: CheckBox
var _camera: OptionButton


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(620.0, 0.0)
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(UiTheme.heading("SETTINGS", 48))
	_remote = _check(box, "Remote Controls (TeamViewer / remote desktop): smooth held keys, mouse look that works over remote control", Settings.remote_mode, func(on: bool) -> void: Settings.remote_mode = on)
	_slider(box, "Mouse sensitivity", 0.2, 3.0, 0.05, Settings.mouse_sensitivity, func(v: float) -> void: Settings.mouse_sensitivity = v)
	_check(box, "Invert mouse Y", Settings.invert_y, func(on: bool) -> void: Settings.invert_y = on)
	_slider(box, "Field of view", 60.0, 105.0, 1.0, Settings.fov, func(v: float) -> void: Settings.fov = v)
	_slider(box, "Volume", 0.0, 1.0, 0.01, Settings.volume, func(v: float) -> void:
		Settings.volume = v
		Settings.apply())
	_slider(box, "Brightness", 0.6, 1.8, 0.02, Settings.brightness, func(v: float) -> void:
		Settings.brightness = v
		LevelKit.apply_brightness(get_tree()))
	_check(box, "Sound captions (what you hear, and from which direction)", Settings.captions, func(on: bool) -> void: Settings.captions = on)
	_check(box, "Voice chat: send my microphone to friends nearby (proximity)", Settings.voice_enabled, func(on: bool) -> void: Settings.voice_enabled = on)
	_slider(box, "Friends' voices (x)", 0.0, Settings.MAX_VOICE_VOLUME, 0.1, Settings.voice_volume, func(v: float) -> void: Settings.voice_volume = v)
	_check(box, "Show FPS", Settings.show_fps, func(on: bool) -> void: Settings.show_fps = on)
	_check(box, "When hosting, open my router so friends can join with an invite code (UPnP)", Settings.open_router_port, func(on: bool) -> void: Settings.open_router_port = on)
	_check(box, "Fullscreen", Settings.fullscreen, func(on: bool) -> void:
		Settings.fullscreen = on
		Settings.apply())
	var cam_row := HBoxContainer.new()
	cam_row.add_child(_label("Camera (V flips it in play)"))
	_camera = OptionButton.new()
	_camera.add_item("THIRD PERSON")
	_camera.add_item("FIRST PERSON")
	_camera.selected = 1 if Settings.first_person else 0
	_camera.item_selected.connect(func(i: int) -> void:
		Settings.first_person = i == 1
		var me := Net.get_local_player()
		if me != null:
			me.set_first_person_camera(Settings.first_person))
	cam_row.add_child(_camera)
	box.add_child(cam_row)
	var q_row := HBoxContainer.new()
	q_row.add_child(_label("Graphics quality"))
	var q := OptionButton.new()
	q.add_item("LOW")
	q.add_item("MEDIUM")
	q.add_item("HIGH")
	q.selected = Settings.quality
	q.item_selected.connect(func(i: int) -> void:
		Settings.quality = i
		var level := get_tree().get_first_node_in_group("level")
		if level != null and level.has_method("refresh_environment"):
			level.call("refresh_environment"))
	q_row.add_child(q)
	box.add_child(q_row)
	var h_row := HBoxContainer.new()
	h_row.add_child(_label("HUD"))
	var h := OptionButton.new()
	h.add_item("AUTO (only when needed)")
	h.add_item("ALWAYS")
	h.add_item("OFF")
	h.selected = Settings.hud_mode
	h.item_selected.connect(func(i: int) -> void: Settings.hud_mode = i)
	h_row.add_child(h)
	box.add_child(h_row)
	box.add_child(UiTheme.button("BACK", _close, 200.0))


func open() -> void:
	_remote.button_pressed = Settings.remote_mode
	_camera.selected = 1 if Settings.first_person else 0  # V may have flipped it since
	visible = true


func _close() -> void:
	Settings.save_settings()
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_close()


func _label(t: String) -> Label:
	var l := UiTheme.text(t, 18)
	l.custom_minimum_size = Vector2(220.0, 0.0)
	return l


func _slider(box: VBoxContainer, title: String, lo: float, hi: float, step: float, value: float, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_child(_label(title))
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(300.0, 28.0)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var readout := UiTheme.text("%.2f" % value, 16, UiTheme.YELLOW)
	s.value_changed.connect(func(v: float) -> void:
		readout.text = "%.2f" % v
		on_change.call(v))
	row.add_child(s)
	row.add_child(readout)
	box.add_child(row)


func _check(box: VBoxContainer, title: String, value: bool, on_change: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = title
	c.button_pressed = value
	c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.custom_minimum_size = Vector2(600.0, 0.0)
	c.toggled.connect(func(on: bool) -> void: on_change.call(on))
	box.add_child(c)
	return c
