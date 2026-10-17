class_name TitleMenu
extends Control
## Title screen: solo, host, join by IP, settings, quit. Drawn over the 3D MenuBackdrop.

signal solo_requested(player_name: String)
signal host_requested(player_name: String, port: int)
signal join_requested(player_name: String, ip: String, port: int)
signal settings_requested

var _name: LineEdit
var _ip: LineEdit
var _status: Label
var _join_box: VBoxContainer
var _title: Label
var _footer: Label
var _level_button: Button
var _arena: bool = false  # PLAY SOLO / HOST build the Loading Lot instead of the building
var _t: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	var shade := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.0, 0.0, 0.0, 0.92))
	grad.set_color(1, Color(0.0, 0.0, 0.0, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0.0, 0.5)
	gt.fill_to = Vector2(0.75, 0.5)
	shade.texture = gt
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE, Control.PRESET_MODE_MINSIZE, 0)
	col.offset_left = 70.0
	col.offset_right = 760.0
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 7)
	add_child(col)
	_title = UiTheme.heading("CHAINS DEEZNUTS\nTOGETHER", 68)
	col.add_child(_title)
	col.add_child(UiTheme.text("You are chained to your friends. Climb out. Stay quiet.", 20, UiTheme.PAPER))
	col.add_child(UiTheme.text("DEEZ Industrial Fasteners: Holding It Together Since 1931", 15, UiTheme.YELLOW_DIM))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 14.0)
	col.add_child(spacer)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	name_row.add_child(UiTheme.text("YOUR NAME", 16, UiTheme.YELLOW_DIM))
	_name = LineEdit.new()
	_name.custom_minimum_size = Vector2(220.0, 38.0)
	_name.text = Settings.player_name if Settings.player_name != "" else "NewHire%d" % (randi() % 900 + 100)
	_name.max_length = 16
	name_row.add_child(_name)
	col.add_child(name_row)
	_level_button = UiTheme.button("", _on_level_toggle)
	_refresh_level_button()
	col.add_child(_level_button)
	col.add_child(UiTheme.button("PLAY SOLO", _on_solo))
	col.add_child(UiTheme.button("HOST CO-OP", _on_host))
	col.add_child(UiTheme.button("JOIN CO-OP", _on_join_toggle))
	_join_box = VBoxContainer.new()
	_join_box.visible = false
	_join_box.add_theme_constant_override("separation", 6)
	_join_box.add_child(UiTheme.text("Paste the invite code your host sent you (or type their IP address).", 15, UiTheme.PAPER))
	var ip_row := HBoxContainer.new()
	ip_row.add_theme_constant_override("separation", 8)
	_ip = LineEdit.new()
	_ip.text = Settings.last_join
	_ip.placeholder_text = "invite code, like K7QM-2XR"
	_ip.custom_minimum_size = Vector2(300.0, 38.0)
	_ip.text_submitted.connect(func(_t2: String) -> void: _on_join())
	ip_row.add_child(_ip)
	ip_row.add_child(UiTheme.button("PASTE", _on_paste, 110.0))
	ip_row.add_child(UiTheme.button("CONNECT", _on_join, 140.0))
	_join_box.add_child(ip_row)
	col.add_child(_join_box)
	col.add_child(UiTheme.button("SETTINGS", func() -> void: settings_requested.emit()))
	col.add_child(UiTheme.button("QUIT", func() -> void: get_tree().quit()))
	_status = UiTheme.text("", 15, UiTheme.YELLOW)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(560.0, 0.0)
	col.add_child(_status)
	_footer = UiTheme.text("", 13, UiTheme.YELLOW_DIM)
	_footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 14)
	_footer.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_footer.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_footer)


func _process(delta: float) -> void:
	_t += delta
	# The sign is on the same dodgy circuit as everything else.
	var f := sin(_t * 17.0) * sin(_t * 5.3)
	_title.modulate.a = 0.35 if f > 0.93 else 1.0
	var where := "Level 3 of 5 straight in: the roof lot" if _arena else "Levels 1-3 of 5: The Yellow Rooms, the Night Shift, the roof lot"
	_footer.text = "%s   |   Remote Controls: %s (Settings)   |   Esc pauses in game   |   build %s" % [where, "ON" if Settings.remote_mode else "OFF", Net.get_build_id()]


func show_status(text: String) -> void:
	_status.text = text


## Which world PLAY SOLO and HOST build: the building (a new layout every run) or the Lot.
func arena_selected() -> bool:
	return _arena


func set_arena(on: bool) -> void:
	_arena = on
	_refresh_level_button()


func _on_level_toggle() -> void:
	set_arena(not _arena)


func _refresh_level_button() -> void:
	if _level_button != null:
		_level_button.text = "START:  THE ROOF, LEVEL 3  (the Loading Lot, straight in)" if _arena else "START:  THE BUILDING, B4  (a new layout every run)"


func player_name() -> String:
	var n := _name.text.strip_edges()
	Settings.player_name = n
	Settings.save_settings()
	return n


func _on_solo() -> void:
	show_status("")
	solo_requested.emit(player_name())


func _on_host() -> void:
	show_status("")
	host_requested.emit(player_name(), Net.DEFAULT_PORT)


func _on_join_toggle() -> void:
	_join_box.visible = not _join_box.visible
	if _join_box.visible:
		_ip.grab_focus()


func _on_paste() -> void:
	_ip.text = DisplayServer.clipboard_get().strip_edges()
	_ip.caret_column = _ip.text.length()


func _on_join() -> void:
	var target := InviteCode.parse(_ip.text, Net.DEFAULT_PORT)
	if target.is_empty():
		show_status("Paste the invite code from your host first (it looks like K7QM-2XR), or type their IP address.")
		return
	Settings.last_join = _ip.text.strip_edges()
	show_status("Connecting ...")
	join_requested.emit(player_name(), String(target["host"]), int(target["port"]))
