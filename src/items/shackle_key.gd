class_name ShackleKey
extends ItemBase
## The Shackle Key: the second player to clock in carries it in a slot of its own (4). F unlocks
## your cuff: you're off the Line, the others stay chained and the chain closes up between them.
## F again within REJOIN_RANGE of a chained teammate locks you back on. For the parts of a run one
## of you is better doing alone (scouting ahead, working a lever, the dumbwaiter); off the chain
## nobody can haul you up or pull you back from an edge. It can't be dropped or replaced, and a
## layoff or a regroup locks everyone back on.

const REJOIN_RANGE: float = 2.6  # m: how close to a chained teammate you lock back on
const COOLDOWN: float = 0.8  # s


var _cooldown: float = 0.0


func _tick(delta: float, _held: bool, pressed: bool) -> void:
	_cooldown -= delta
	is_active = false
	if not pressed or _cooldown > 0.0 or holder.state != Player.State.NORMAL:
		return
	_cooldown = COOLDOWN
	var f := fx()
	if not holder.unchained:
		holder.set_unchained(true)
		is_active = true
		if f != null:
			f.fx_sound.rpc("clink", holder.global_position + Vector3.UP * 1.0, 4.0, 0.6)
		GameState.post_tip("unchained", "%s is OFF THE CHAIN. Nobody can haul them up now. F next to a teammate locks back on." % holder.display_name, 4.0)
		return
	if _near_chained() == null:
		GameState.post_message("%s has to be next to a teammate to lock back on." % holder.display_name, 2.5)
		return
	holder.set_unchained(false)
	is_active = true
	if f != null:
		f.fx_sound.rpc("clink", holder.global_position + Vector3.UP * 1.0, 4.0, 1.1)


## The nearest teammate still on the chain within REJOIN_RANGE, or null.
func _near_chained() -> ChainBody:
	var best: ChainBody = null
	var best_d := REJOIN_RANGE
	for b in Net.get_chain_bodies():
		if b == holder or (b is Player and (b as Player).unchained):
			continue
		var d := (b as Node3D).global_position.distance_to(holder.global_position)
		if d < best_d:
			best_d = d
			best = b
	return best


func charge() -> float:
	return 1.0


func ammo_text() -> String:
	return "OFF" if holder != null and holder.unchained else "ON"
