class_name EndScreen
extends Control
## Shown when everyone made it into the freight elevator.

signal menu_requested

var _stats: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.8)
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
	box.add_child(UiTheme.heading("ESCAPED", 96, Color(0.45, 1.0, 0.5)))
	box.add_child(UiTheme.heading("SHIFT COMPLETE: THE YELLOW ROOMS", 32))
	_stats = UiTheme.text("", 20)
	box.add_child(_stats)
	box.add_child(UiTheme.text("Next on the Stack: Level 2, The Pizzeria Night Shift (coming in a future build).", 16, UiTheme.YELLOW_DIM))
	box.add_child(UiTheme.button("BACK TO MENU", func() -> void: menu_requested.emit()))
	box.add_child(UiTheme.button("QUIT GAME", func() -> void: get_tree().quit()))


func show_results() -> void:
	var t := int(GameState.final_time)
	var rating := "Employee of the Month" if GameState.wipes == 0 else ("Meets Expectations" if GameState.wipes < 3 else "Please See HR")
	_stats.text = "Time on shift   %d:%02d\nLayoffs   %d\nTimes someone yanked the chain   %d\nPerformance review   %s" % [
		t / 60, t % 60, GameState.wipes, GameState.final_jerks, rating]
	visible = true
