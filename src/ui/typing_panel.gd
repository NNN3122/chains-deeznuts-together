class_name TypingPanel
extends PanelContainer
## Level 4's engine repair, for the local player (the user: "make it harder than just holding ctrl,
## instead make them type along a paragraph"). Crouch (Ctrl) at an engine that needs work and this
## opens on a page of its maintenance book (ManorMachine.TYPE_TEXTS): type it out. The next letter is
## lit, punctuation types itself, case doesn't matter. Every key goes to the host (ManorMachine
## rpc_key), which keeps the engine's progress and your place; your own screen moves on at once and
## follows the host's word. A wrong key flashes red here and clangs out there. While it's open the
## keys type instead of moving you (GameState.typing); Esc steps away.

const FLASH: float = 0.35  # s a wrong key stays red
const TEXT_SIZE: int = 22

var machine: ManorMachine  # the engine you're typing at; null when closed
var page: int = -1  # into ManorMachine.TYPE_TEXTS; -1 until the host hands you one
var cursor: int = 0
var _hold_off: bool = false  # just closed with Ctrl still down: wait for the crouch to come up
var _flash: float = 0.0
var _text: RichTextLabel
var _bar: ProgressBar
var _pace_label: Label
var _pace: Array = ManorMachine.new_pace()  # your own pace, kept the way the host keeps it
var _slow: bool = false


func _ready() -> void:
	add_to_group("typing_panel")
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := UiTheme.hud_panel(0.82)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 14.0
	add_theme_stylebox_override("panel", style)
	custom_minimum_size = Vector2(940.0, 0.0)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 120)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	box.add_child(UiTheme.text("REPAIRING THE ENGINE: type the page out, %d words a minute or faster. Too slow it grinds, a wrong key clangs: it hears both.     Esc: step away" % int(ManorMachine.WPM_MIN), 15, Color(1.0, 0.86, 0.55)))
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(900.0, 0.0)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_font_override("normal_font", UiTheme.body_font())
	_text.add_theme_font_size_override("normal_font_size", TEXT_SIZE)
	box.add_child(_text)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.max_value = 1.0
	_bar.custom_minimum_size = Vector2(900.0, 8.0)
	box.add_child(_bar)
	_pace_label = UiTheme.text("", 16, Color(0.75, 0.75, 0.72))
	box.add_child(_pace_label)


func _process(delta: float) -> void:
	var me := Net.get_local_player()
	if machine == null:
		if me == null or GameState.ui_blocking:
			return
		var crouched := (me.synced_flags & Player.SFLAG_BRACING) != 0
		if _hold_off:
			_hold_off = crouched
			return
		if not crouched or me.state != Player.State.NORMAL:
			return
		for n in get_tree().get_nodes_in_group("machine"):
			var m := n as ManorMachine
			if m != null and not m.is_main and m.needs_fix() and m.in_reach(me):
				_open(m)
				break
		return
	if not is_instance_valid(machine) or machine.done or me == null or me.state != Player.State.NORMAL or not machine.in_reach(me):
		close(false)
		return
	if GameState.ui_blocking:
		close(true)  # a menu came up
		return
	_bar.value = machine.progress
	_show_pace()
	if _flash > 0.0:
		_flash -= delta
		if _flash <= 0.0:
			_refresh()


## Your words a minute, red under the pace (the engine is grinding out there).
func _show_pace() -> void:
	var text := "-- WPM"
	var col := Color(0.75, 0.75, 0.72)
	var idle := _pace.is_empty() or float(Time.get_ticks_msec() - int(_pace[_pace.size() - 1])) / 1000.0 > ManorMachine.KEY_GAP_PAUSE
	if not idle and _pace.size() >= 3:
		text = "%d WPM" % int(ManorMachine.pace_wpm(_pace))
		col = Color(0.65, 0.9, 0.6)
		if _slow:
			text += "   TOO SLOW: THE ENGINE GRINDS, AND SOMETHING HEARS IT"
			col = Color(1.0, 0.35, 0.3)
	if text != _pace_label.text:  # only when it changes: a restyle every frame is work for nothing
		_pace_label.text = text
		_pace_label.add_theme_color_override("font_color", col)


func _open(m: ManorMachine) -> void:
	machine = m
	page = -1
	cursor = 0
	_flash = 0.0
	_pace = ManorMachine.new_pace()
	_slow = false
	GameState.typing = true
	if not m.typing_changed.is_connected(_on_typing):
		m.typing_changed.connect(_on_typing)
	m.rpc_begin_typing.rpc_id(1)
	visible = true
	_refresh()


## Closes the page (tell_host: you stepped away; otherwise the host already knows).
func close(tell_host: bool) -> void:
	if machine != null and is_instance_valid(machine):
		if machine.typing_changed.is_connected(_on_typing):
			machine.typing_changed.disconnect(_on_typing)
		if tell_host:
			machine.rpc_end_typing.rpc_id(1)
	machine = null
	page = -1
	visible = false
	GameState.typing = false
	_hold_off = true


## The host's word on your page and place.
func _on_typing(missed: bool) -> void:
	if machine == null:
		return
	if machine.local_text < 0:
		close(false)
		return
	if machine.local_text != page:
		page = machine.local_text
		cursor = machine.local_cursor
	elif missed:
		cursor = machine.local_cursor
	else:
		cursor = maxi(cursor, machine.local_cursor)
	if missed:
		_flash = FLASH
	_refresh()


func _input(event: InputEvent) -> void:
	if machine == null or not (event is InputEventKey):
		return
	get_viewport().set_input_as_handled()  # the keys are for the page now, not for walking or the menus
	var k := event as InputEventKey
	if not k.pressed or k.echo:
		return
	if k.keycode == KEY_ESCAPE or k.physical_keycode == KEY_ESCAPE:
		close(true)
		return
	var c := k.unicode
	if c < 32 or page < 0:
		return
	var now := Time.get_ticks_msec()  # your own clock: the host times your pace by it, not by when the key gets there
	var text: String = ManorMachine.TYPE_TEXTS[page]
	var at := ManorMachine.skip_untyped(text, cursor)
	if at < text.length() and ManorMachine.same_key(text.unicode_at(at), c):
		cursor = ManorMachine.skip_untyped(text, at + 1)
		_slow = ManorMachine.pace_step(_pace, now)
	else:
		_flash = FLASH
	var m := machine
	_refresh()
	m.rpc_key.rpc_id(1, c, now)  # last: on the host it answers at once (and may close the page)


func _refresh() -> void:
	if page < 0:
		_text.text = "[color=#8c8c8c]...[/color]"
		return
	var t: String = ManorMachine.TYPE_TEXTS[page]
	var at := ManorMachine.skip_untyped(t, cursor)
	var bb := "[color=#a6d9a0]%s[/color]" % t.substr(0, at)
	if at < t.length():
		var mark := "#c0302099" if _flash > 0.0 else "#ffffff40"
		bb += "[bgcolor=%s][color=#ffffff]%s[/color][/bgcolor]" % [mark, t.substr(at, 1)]
		bb += "[color=#7f7a72]%s[/color]" % t.substr(at + 1)
	_text.text = bb
