extends ItemBase
## The Snubby: 8 shots. Two hits make the Custodian let go and retreat, but every shot is the
## loudest thing in the building. Hitting a teammate just shoves them (and the chain with them).

const AMMO: int = 8
const RANGE: float = 60.0
const COOLDOWN: float = 0.3

var ammo: int = AMMO
var _cooldown: float = 0.0


func _tick(delta: float, _held: bool, pressed: bool) -> void:
	_cooldown -= delta
	is_active = false
	if not pressed or _cooldown > 0.0:
		return
	_cooldown = COOLDOWN
	var f := fx()
	if ammo <= 0:
		if f != null:
			f.fx_sound.rpc("click", holder.global_position + Vector3.UP, -6.0, 1.0)
		return
	ammo -= 1
	is_active = true
	var from := holder.eye_position()
	var dir := holder.aim_direction()
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * RANGE,
		ChainBody.LAYER_WORLD | ChainBody.LAYER_BODIES | ChainBody.LAYER_MONSTER)
	q.collide_with_areas = true
	q.exclude = [holder.get_rid()]
	var hit := holder.get_world_3d().direct_space_state.intersect_ray(q)
	var to := from + dir * RANGE
	if not hit.is_empty():
		to = hit["position"]
		var col: Object = hit["collider"]
		if col is Area3D and (col as Node).get_parent() != null and (col as Node).get_parent().has_method("take_hit"):
			(col as Node).get_parent().call("take_hit")
		elif col is ChainBody:
			(col as ChainBody).apply_knockback(dir * 6.0 + Vector3.UP * 2.5)
	holder.add_noise(100.0)
	holder.apply_knockback(-dir * 1.2)
	if f != null:
		f.fx_shot.rpc(from + dir * 0.6, to)


func charge() -> float:
	return float(ammo) / float(AMMO)
