extends ItemBase
## The Snubby: a 6-round magazine and a pocket of spares. T reloads (or fire on empty). Two hits
## drop a Hollow Hire, but every shot is the loudest thing in the building.
## Hitting a teammate just shoves them (and the chain with them). Ammo boxes top up the pocket.

const MAG: int = 6
const RESERVE_START: int = 12
const RESERVE_MAX: int = 30
const RANGE: float = 60.0
const COOLDOWN: float = 0.3
const RELOAD_TIME: float = 1.6

var ammo: int = MAG
var reserve: int = RESERVE_START
var _cooldown: float = 0.0
var _reload_t: float = 0.0


func _tick(delta: float, _held: bool, pressed: bool) -> void:
	_cooldown -= delta
	is_active = false
	if _reload_t > 0.0:
		_reload_t -= delta
		if _reload_t <= 0.0:
			var take := mini(MAG - ammo, reserve)
			ammo += take
			reserve -= take
			var f0 := fx()
			if f0 != null:
				f0.fx_sound.rpc("click", holder.global_position + Vector3.UP, -4.0, 1.4)
		return
	if not pressed or _cooldown > 0.0:
		return
	_cooldown = COOLDOWN
	var f := fx()
	if ammo <= 0:
		if reserve > 0:
			_reload()
		elif f != null:
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
	# The horde isn't physics: it tests the ray itself, and whichever is nearer takes the round.
	var horde := holder.get_tree().get_first_node_in_group("horde")
	var world_d := from.distance_to(hit["position"]) if not hit.is_empty() else RANGE
	var horde_d := float(horde.call("hit_ray", from, dir, world_d)) if horde != null else -1.0
	if horde_d >= 0.0:
		to = from + dir * horde_d
	elif not hit.is_empty():
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


func _reload() -> void:
	if _reload_t > 0.0 or ammo >= MAG or reserve <= 0:
		return
	_reload_t = RELOAD_TIME
	var f := fx()
	if f != null:
		f.fx_sound.rpc("click", holder.global_position + Vector3.UP, -8.0, 0.7)


func add_reserve(rounds: int) -> int:
	var take := mini(rounds, RESERVE_MAX - reserve)
	reserve += take
	return take


func charge() -> float:
	if _reload_t > 0.0:
		return 1.0 - _reload_t / RELOAD_TIME
	return float(ammo) / float(MAG)


func ammo_text() -> String:
	if _reload_t > 0.0:
		return "RELOADING"
	return "%d / %d" % [ammo, reserve]


func carry_state() -> Dictionary:
	return {"ammo": ammo, "reserve": reserve}


func restore_state(s: Dictionary) -> void:
	ammo = int(s.get("ammo", ammo))
	reserve = int(s.get("reserve", reserve))
