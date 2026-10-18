extends ItemBase
## Party Popper: F fires it. A bang, confetti, and Pappy Pepperoni (within reach) is shoved one
## node back toward his end of the floor; whoever he's holding gets dropped. Anyone standing
## right in front of you gets a shove too, and the chain with them. One shot.

const RANGE: float = 10.0
const NOISE: float = 55.0


func _tick(_delta: float, _held: bool, pressed: bool) -> void:
	if not pressed:
		return
	var f := fx()
	var from := holder.eye_position()
	var dir := holder.aim_direction()
	if f != null:
		f.fx_sound.rpc("popper", from, 4.0, 1.0)
		f.fx_confetti.rpc(from + dir * 0.8)
	holder.add_noise(NOISE)
	for m in holder.get_tree().get_nodes_in_group("pappy"):
		var pappy := m as PappyPepperoni
		if pappy != null and pappy.global_position.distance_to(holder.global_position) < RANGE:
			pappy.push_back()
	for b in Net.get_chain_bodies():
		if b == holder:
			continue
		var to := b.global_position - holder.global_position
		if to.length() < 2.2 and to.normalized().dot(dir) > 0.4:
			b.apply_knockback(dir * 4.0 + Vector3.UP * 2.0)
	consume()
