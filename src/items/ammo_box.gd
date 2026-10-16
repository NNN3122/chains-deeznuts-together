extends ItemBase
## A box of Snubby rounds. Picked up with a pistol in any slot it pours straight into the pocket;
## otherwise it rides in a slot until you find one. Holding it: F does nothing.

const ROUNDS: int = 12

var rounds: int = ROUNDS


## Called before a slot is taken: true when the rounds went into a carried gun.
func merge_into(player: Player) -> bool:
	var gun := player.find_item("pistol")
	if gun == null:
		return false
	var took: int = gun.call("add_reserve", rounds)
	if took <= 0:
		return false
	rounds -= took
	if rounds <= 0:
		queue_free()
		return true
	return false


func _tick(_delta: float, _held: bool, _pressed: bool) -> void:
	# A gun picked up later takes the rounds out of this box.
	if holder == null:
		return
	var gun := holder.find_item("pistol")
	if gun != null:
		var took: int = gun.call("add_reserve", rounds)
		rounds -= took
		if rounds <= 0:
			consume()


func charge() -> float:
	return float(rounds) / float(ROUNDS)


func ammo_text() -> String:
	return "%d rounds" % rounds


func carry_state() -> Dictionary:
	return {"rounds": rounds}


func restore_state(s: Dictionary) -> void:
	rounds = int(s.get("rounds", rounds))
