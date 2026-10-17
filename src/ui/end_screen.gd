class_name EndScreen
extends Control
## Shown when everyone made it onto the pizzeria's prop loft: the end of this build.

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
	box.add_child(UiTheme.heading("SHIFT COMPLETE: THE YELLOW ROOMS\nAND PAPPY PEPPERONI'S NIGHT SHIFT", 32))
	_stats = UiTheme.text("", 20)
	box.add_child(_stats)
	box.add_child(UiTheme.text("Next on the Stack: Level 3, Carrow Heights, the infected rooftops (coming in a future build).", 16, UiTheme.YELLOW_DIM))
	box.add_child(UiTheme.button("BACK TO MENU", func() -> void: menu_requested.emit()))
	box.add_child(UiTheme.button("QUIT GAME", func() -> void: get_tree().quit()))


func show_results() -> void:
	var t := int(GameState.final_time)
	var rating := "Employee of the Month" if GameState.wipes == 0 else ("Meets Expectations" if GameState.wipes < 3 else "Please See HR")
	var clock := ""
	var level := get_tree().get_first_node_in_group("level")
	if level != null and level.get("pizzeria") != null:
		clock = "\nClocked out of the pizzeria at   %s" % (level.get("pizzeria") as Pizzeria).clock_text()
	if GameState.escape_line != "":
		clock += "\n%s" % GameState.escape_line
	_stats.text = "Time on shift   %d:%02d%s\nLayoffs   %d\nTimes someone yanked the chain   %d\nPerformance review   %s" % [
		t / 60, t % 60, clock, GameState.wipes, GameState.final_jerks, rating]
	visible = true
