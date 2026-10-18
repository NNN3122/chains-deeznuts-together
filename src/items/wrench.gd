class_name Wrench
extends ItemBase
## The Wrench: everyone clocks in with one. F (left click) swings it. A crack across a monster
## that has a teammate makes it let go and reel; one holding nobody only staggers. A swat drops a
## bug of the swarm, a teammate just gets shoved. Held at something broken (group "repairable":
## needs_fix(), wrench_fix(by), fix_point()), the swing fixes it instead. It never runs out, but
## every hit is loud.
## You can aim at the monster or at the teammate it's holding: either way you're hitting the arm.

const REACH: float = 2.4  # m from the eyes
const CONE: float = 0.8  # rad: how far off your aim a swing still connects
const COOLDOWN: float = 0.7  # s between swings
const RESCUE_STUN: float = 2.2  # s a monster reels after a hit that frees someone
const STAGGER: float = 0.8  # s a monster reels from a hit when it holds nobody
const NOISE: float = 70.0  # a hit; a swing at a monster adds HIT_NOISE on top
const HIT_NOISE: float = 25.0

var _cooldown: float = 0.0
var _hit_point: Vector3 = Vector3.ZERO


func _tick(delta: float, _held: bool, pressed: bool) -> void:
	_cooldown -= delta
	is_active = false
	if not pressed or _cooldown > 0.0:
		return
	_cooldown = COOLDOWN
	is_active = true
	holder.rpc_swing.rpc()
	var from := holder.eye_position()
	var dir := holder.aim_direction()
	var f := fx()
	# Something broken in front of you: the swing fixes it.
	var fix := _target_in_reach("repairable", from, dir)
	if fix != null and bool(fix.call("needs_fix")):
		fix.call("wrench_fix", holder)
		holder.add_noise(NOISE)
		if f != null:
			f.fx_sound.rpc("clink", _hit_point, 4.0, randf_range(0.7, 0.85))
			f.fx_dust.rpc(_hit_point)
		return
	var m := _target_in_reach("monster", from, dir)
	if m != null:
		if m.has_method("wrench_hit"):
			m.call("wrench_hit", holder)
		holder.add_noise(NOISE + HIT_NOISE)
		if f != null:
			f.fx_sound.rpc("thump", _hit_point, 4.0, randf_range(0.75, 0.9))
			f.fx_sound.rpc("clink", _hit_point, 0.0, randf_range(0.5, 0.6))
		return
	var horde := holder.get_tree().get_first_node_in_group("horde")
	if horde != null and float(horde.call("hit_ray", from, dir, REACH)) >= 0.0:
		holder.add_noise(NOISE * 0.6)
		if f != null:
			f.fx_sound.rpc("thump", from + dir * 1.5, 0.0, 1.3)
		return
	for b in Net.get_chain_bodies():
		if b == holder:
			continue
		var at := (b as Node3D).global_position + Vector3.UP * 1.0
		if at.distance_to(from) < REACH and dir.angle_to(at - from) < CONE * 0.6:
			b.apply_knockback(dir * 4.0 + Vector3.UP * 1.5)
			if f != null:
				f.fx_sound.rpc("thump", at, -2.0, 1.1)
			return


## The nearest node of a group whose points (or, for a monster, the teammate it holds) are in
## reach, inside the swing's cone and not behind a wall. Leaves the point it found in _hit_point.
func _target_in_reach(group: String, from: Vector3, dir: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d := REACH
	for n in holder.get_tree().get_nodes_in_group(group):
		if not (n is Node3D):
			continue
		if n.has_method("is_dead") and bool(n.call("is_dead")):
			continue
		for p in _points(n as Node3D):
			var d := from.distance_to(p)
			if d >= best_d or dir.angle_to(p - from) > CONE or _blocked(from, p):
				continue
			best_d = d
			best = n as Node3D
			_hit_point = p
	return best


func _points(n: Node3D) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for m in ["fix_point", "face_point", "head_point", "chest_point", "stain_point"]:
		if n.has_method(m):
			out.append(n.call(m))
	if out.is_empty():
		out.append(n.global_position + Vector3.UP * 1.0)
	var gp: Variant = n.get("grab_peer")
	if gp != null and int(gp) != 0:
		var victim := Net.find_player(int(gp))
		if victim != null and victim != holder:
			out.append(victim.global_position + Vector3.UP * 1.2)
	return out


func _blocked(from: Vector3, to: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to, ChainBody.LAYER_WORLD)
	q.exclude = [holder.get_rid()]
	var hit := holder.get_world_3d().direct_space_state.intersect_ray(q)
	return not hit.is_empty() and from.distance_to(hit["position"]) < from.distance_to(to) - 0.35
