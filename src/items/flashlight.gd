extends ItemBase
## Flashlight: F toggles it. Lights the dark rooms, and holding the beam on the Custodian's stain
## (or on it while it has someone) burns it until it lets go and retreats. The burn check lives
## in the Custodian, which looks for players whose flashlight is_active.


func _tick(_delta: float, _held: bool, pressed: bool) -> void:
	if pressed:
		is_active = not is_active
		var f := fx()
		if f != null:
			f.fx_sound.rpc("flashlight", holder.global_position + Vector3.UP, -10.0, 1.0)
