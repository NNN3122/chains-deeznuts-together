extends ItemBase
## DEEZ Juice: F to chug. 8 s of speed and higher jumps with a jittery screen, then a 5 s crash
## where you're slow and blurry. Being fast on a chain mostly means dragging everyone else.


func _tick(_delta: float, _held: bool, pressed: bool) -> void:
	if not pressed:
		return
	holder.apply_energy_drink()
	var f := fx()
	if f != null:
		f.fx_sound.rpc("gulp", holder.global_position + Vector3.UP, -2.0, 1.0)
	GameState.post_message("%s chugged a DEEZ Juice. Everyone hold on." % holder.display_name, 3.0)
	consume()
