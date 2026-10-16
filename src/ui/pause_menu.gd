class_name PauseMenu
extends Control
## In-game menu. The game keeps running underneath (it's online), the monster included.
## While hosting it also shows the invite code friends paste into JOIN CO-OP.

signal resume_requested
signal settings_requested
signal leave_requested
signal regroup_requested

const COPIED_SECONDS: float = 1.6  # how long the button says COPIED!

const INVITE_PROBLEMS: Dictionary = {
	"off": "Opening the router is switched off in Settings.",
	"no_router": "Your router didn't answer. Its UPnP setting may be off.",
	"refused": "Your router wouldn't open the port. Its UPnP setting may be off.",
	"double_nat": "Your internet provider blocks incoming connections, so invite codes can't work here.",
}

var _invite_box: VBoxContainer
var _invite_code: Label
var _invite_info: Label
var _copy_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(UiTheme.heading("BREAK TIME", 52))
	box.add_child(UiTheme.text("The building doesn't pause. Neither does the ceiling.", 16, UiTheme.YELLOW_DIM))
	_build_invite(box)
	box.add_child(UiTheme.button("RESUME", func() -> void: resume_requested.emit()))
	box.add_child(UiTheme.button("STUCK? REGROUP AT BREAK ROOM", func() -> void: regroup_requested.emit()))
	box.add_child(UiTheme.button("SETTINGS", func() -> void: settings_requested.emit()))
	box.add_child(UiTheme.button("LEAVE TO MENU", func() -> void: leave_requested.emit()))
	box.add_child(UiTheme.button("QUIT GAME", func() -> void: get_tree().quit()))
	Net.invite_changed.connect(_refresh_invite)
	visibility_changed.connect(_refresh_invite)
	_refresh_invite()


func _build_invite(box: VBoxContainer) -> void:
	_invite_box = VBoxContainer.new()
	_invite_box.add_theme_constant_override("separation", 4)
	box.add_child(_invite_box)
	_invite_box.add_child(UiTheme.text("INVITE FRIENDS", 15, UiTheme.YELLOW_DIM))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_invite_code = UiTheme.heading("", 40, UiTheme.PAPER)
	_invite_code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_invite_code)
	_copy_button = UiTheme.button("COPY INVITE", _on_copy, 220.0)
	_copy_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_copy_button)
	_invite_box.add_child(row)
	_invite_info = UiTheme.text("", 15)
	_invite_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_invite_info.custom_minimum_size = Vector2(540.0, 0.0)
	_invite_box.add_child(_invite_info)


func _refresh_invite() -> void:
	var inv := Net.invite
	_invite_box.visible = not inv.is_empty()
	if inv.is_empty():
		return
	var nearby := PackedStringArray()
	if String(inv["lan"]) != "":
		nearby.append("Same Wi-Fi: %s" % inv["lan"])
	if String(inv["tailscale"]) != "":
		nearby.append("Tailscale: %s" % inv["tailscale"])
	var addresses := "   ".join(nearby)
	match String(inv["state"]):
		"ready":
			_invite_code.text = String(inv["code"])
			_copy_button.text = "COPY INVITE"
			_copy_button.disabled = false
			_invite_info.text = "Send the code to your friends. They click JOIN CO-OP, paste it and connect. Your router lets them in while you host."
			if addresses != "":
				_invite_info.text += "\nIn the same house, if the code doesn't work: %s" % addresses
		"opening":
			_invite_code.text = "..."
			_copy_button.text = "COPY INVITE"
			_copy_button.disabled = true
			_invite_info.text = "Asking your router to let friends in ..."
		_:
			_invite_code.text = "NO CODE"
			_copy_button.text = "COPY ADDRESS"
			_copy_button.disabled = Net.invite_text() == ""
			var why := String(INVITE_PROBLEMS.get(inv["state"] if inv["state"] == "off" else inv["reason"], "Your router couldn't be opened."))
			_invite_info.text = "%s Friends in your house can join with your Wi-Fi address; over the internet, use Tailscale.\n%s" % [why, addresses]


func _on_copy() -> void:
	DisplayServer.clipboard_set(Net.invite_text())
	var label := _copy_button.text
	_copy_button.text = "COPIED!"
	get_tree().create_timer(COPIED_SECONDS).timeout.connect(func() -> void:
		if _copy_button.text == "COPIED!":
			_copy_button.text = label)
