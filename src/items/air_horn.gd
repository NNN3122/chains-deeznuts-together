extends ItemBase
## Air Horn: F blasts it. The loudest thing in the building: Pappy Pepperoni locks up for a few
## seconds and drops whoever he's holding, and everything that hunts by sound comes running.
## Three blasts in the can.

const BLASTS: int = 3
const RANGE: float = 24.0
const STUN: float = 3.0
const COOLDOWN: float = 1.4

var blasts: int = BLASTS
var _cooldown: float = 0.0


func _tick(delta: float, _held: bool, pressed: bool) -> void:
	_cooldown -= delta
	is_active = false
	if not pressed or _cooldown > 0.0:
		return
	_cooldown = COOLDOWN
	var f := fx()
	if blasts <= 0:
		if f != null:
			f.fx_sound.rpc("click", holder.global_position + Vector3.UP, -6.0, 0.8)
		return
	blasts -= 1
	is_active = true
	holder.add_noise(100.0)
	if f != null:
		f.fx_sound.rpc("airhorn", holder.eye_position(), 6.0, randf_range(0.95, 1.05))
	for m in holder.get_tree().get_nodes_in_group("monster"):
		if not m.has_method("stun") or (m as Node3D).global_position.distance_to(holder.global_position) >= RANGE:
			continue
		m.call("stun", STUN)
	var horde := holder.get_tree().get_first_node_in_group("horde")
	if horde != null:
		horde.call("stun", holder.global_position, RANGE * 0.5)
	for p in Net.get_players():
		if p != holder and p.global_position.distance_to(holder.global_position) < 3.0:
			p.model.pop_hat(Vector3.UP * 5.0 + (p.global_position - holder.global_position).normalized() * 3.0)


func charge() -> float:
	return float(blasts) / float(BLASTS)
