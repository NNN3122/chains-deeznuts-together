extends ItemBase
## Flashlight: F toggles it. Lights the dark rooms, and holding the beam on a monster's face (a Hire,
## a Launcher, Pappy while he holds someone) stuns it or makes it let go. The burn checks live
## in the monsters, which look for players whose flashlight is_active.


func _tick(_delta: float, _held: bool, pressed: bool) -> void:
	if pressed:
		is_active = not is_active
		var f := fx()
		if f != null:
			f.fx_sound.rpc("flashlight", holder.global_position + Vector3.UP, -10.0, 1.0)
