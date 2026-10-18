class_name Launcher
extends Node3D
## The Jumper (class Launcher, after the move): a spider the size of a sofa, one of the things that
## came up out of the walls of Carrow Heights. It scuttles at 1.3 m/s; inside six
## metres it stops, screeches, and crouches for 0.6 s (the tell), then throws itself 5-6 m
## along the line it had when it crouched. Step out of that line (a sprint, a slide) and it
## lands on nothing. Hit, it pins its victim to the ground: teammates brace beside them, a
## flashlight in its face, an air horn or two Snubby hits get it off; nobody comes in a few
## seconds and the Line is laid off. Three Snubby hits or a bomb kill it.
## Host-authoritative like the Custodian; position, state and grab are replicated.

enum LState { SHAMBLE, WINDUP, LUNGE, RECOVER, GRAB, STUNNED, DEAD, SWING, CLIMB }
const IDLE_CALL_EVERY: Vector2 = Vector2(7.0, 14.0)  # s between its hisses while it scuttles
const IDLE_CALL_REACH: float = 22.0  # m

const SHAMBLE_SPEED: float = 1.3  # m/s
const SIGHT_RANGE: float = 42.0
const LUNGE_MIN: float = 2.6  # m: closer than this it just claws (grabs) instead of jumping
const LUNGE_MAX: float = 6.2  # m: it crouches when a player is inside this
const WINDUP_TIME: float = 0.6
const LUNGE_DIST: float = 5.6  # m it flies, on the line fixed when the crouch began
const LUNGE_TIME: float = 0.5
const LUNGE_ARC: float = 1.1  # m of height at the top of the jump
const HIT_RADIUS: float = 1.05
const RECOVER_TIME: float = 1.0
const GRAB_TIME: float = 5.0  # s pinned before the layoff
const RESCUE_NEEDED: float = 2.5  # resist-seconds from teammates beside the victim (bracing counts double)
const RESCUE_RADIUS: float = 2.6
const BURN_TO_RELEASE: float = 1.0
const BURN_RANGE: float = 16.0
const BURN_ANGLE: float = 0.5
const BURN_DECAY: float = 0.25
const HITS_TO_RELEASE: int = 2
const HITS_TO_DIE: int = 3
const STUN_TIME: float = 3.0
const DEAD_LINGER: float = 25.0
const NOISE_DRAW: float = 30.0  # unseen players this loud draw it over
const TURN_SPEED: float = 5.0  # rad/s
const BODY_H: float = 1.0  # m: the body hangs this high on its legs
const CLIMB_SPEED: float = 3.0  # m/s up a wall face
const CLIMB_MAX: float = 45.0  # m: higher than that and it gives up
const SWING_RANGE: float = 14.0  # m it looks across a gap for the next roof
const SWING_SPEED: float = 8.0  # m/s along the thread
const SWING_SAG: float = 2.2  # m the swing dips under the straight line
const WEB_ANCHOR_H: float = 8.0  # m over the gap the thread hangs from
const DROP_PROBE: float = 16.0  # m it looks down for a floor before calling a step a gap
const STREET_FALL: float = 30.0  # m below its post: it has gone over the edge

var floor_y: float = 0.0  # fallback when no floor is under it
var asleep: bool = false  # the level's call: nobody is on this level yet
var debug_frozen: bool = false

# Replicated.
var synced_position: Vector3 = Vector3.ZERO
var synced_yaw: float = 0.0
var lstate: int = LState.SHAMBLE
var _idle_call_t: float = randf_range(3.0, 9.0)  # every peer: its own ambient timer
var hunt_peer: int = 0
var grab_peer: int = 0
var burn_fraction: float = 0.0
var hits: int = 0
var lunges: int = 0  # stat, replicated so clients can react too
var swing_from: Vector3 = Vector3.ZERO  # the thread: where the swing left from...
var swing_to: Vector3 = Vector3.ZERO  # ...and where it lands (the anchor is over the middle)
var swings: int = 0  # stat

# Server.
var _target: Player = null
var _grabbed: Player = null
var _t: float = 0.0
var _lunge_dir: Vector3 = Vector3.ZERO
var _lunge_from: Vector3 = Vector3.ZERO
var _lunge_len: float = 0.0
var _rescue: float = 0.0
var _burn: float = 0.0
var _hiss_t: float = 0.0
var _hits_in_grab: int = 0
var _dead_t: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Visuals.
var _model: Node3D
var _body: Node3D
var _head: Node3D
var _legs: Array[Node3D] = []  # eight root pivots, left legs even
var _knees: Array[Node3D] = []
var _eyes: Array[MeshInstance3D] = []
var _hitbox: Area3D
var _phase: float = 0.0
var _shown_state: int = -1
var _shown_grab: int = 0
var _last_pos: Vector3 = Vector3.ZERO
var _vis_speed: float = 0.0
var _caption_t: float = 0.0
var _crouch: float = 0.0  # 0 standing, 1 coiled
var _swing_dur: float = 1.0
var _climb_from_y: float = 0.0
var _thread: MeshInstance3D
var _thread_mesh: ImmediateMesh


func _enter_tree() -> void:
	if has_node("Sync"):
		return
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	for prop in ["synced_position", "synced_yaw", "lstate", "hunt_peer", "grab_peer", "burn_fraction", "hits", "lunges", "swing_from", "swing_to", "swings"]:
		var path := NodePath(".:" + prop)
		cfg.add_property(path)
		cfg.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	sync.replication_config = cfg
	add_child(sync)


func _ready() -> void:
	add_to_group("monster")
	add_to_group("launcher")
	_rng.seed = hash(name)
	synced_position = global_position
	synced_yaw = rotation.y
	_last_pos = global_position
	_build_visuals()


# --- Visuals: a spider the size of a sofa ------------------------------------------------------------

func _build_visuals() -> void:
	var jb := JumperBody.new()
	jb.name = "Model"
	add_child(jb)
	jb.build(BODY_H)
	_model = jb
	_body = jb.body
	_head = jb.head
	_legs = jb.legs
	_knees = jb.knees
	_eyes = jb.eyes
	_hitbox = Area3D.new()
	_hitbox.collision_layer = ChainBody.LAYER_MONSTER
	_hitbox.collision_mask = 0
	_hitbox.monitoring = false
	var hs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.9
	cap.height = 2.0
	hs.shape = cap
	hs.position = Vector3(0.0, BODY_H, 0.0)
	hs.rotation.x = PI * 0.5  # lying along its body
	_hitbox.add_child(hs)
	add_child(_hitbox)
	# The thread it swings on, drawn while it swings (every peer).
	_thread_mesh = ImmediateMesh.new()
	_thread = MeshInstance3D.new()
	_thread.name = "Thread"
	_thread.mesh = _thread_mesh
	_thread.top_level = true
	var tm := StandardMaterial3D.new()
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.albedo_color = Color(0.85, 0.85, 0.8, 0.75)
	tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_thread.material_override = tm
	add_child(_thread)


func chest_point() -> Vector3:
	return global_position + Vector3(0.0, BODY_H, 0.0)


func head_point() -> Vector3:
	return global_position + Vector3(0.0, BODY_H + 0.3, 0.0)


func is_hunting() -> bool:
	return lstate == LState.WINDUP or lstate == LState.LUNGE or lstate == LState.GRAB or lstate == LState.SWING


func is_dead() -> bool:
	return lstate == LState.DEAD


# --- Server ------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		_server_tick(delta)
	else:
		if lstate == LState.LUNGE:
			global_position = global_position.lerp(synced_position, clampf(delta * 20.0, 0.0, 1.0))
		else:
			global_position = global_position.lerp(synced_position, clampf(delta * 12.0, 0.0, 1.0))
	_update_visuals(delta)


func _server_tick(delta: float) -> void:
	if (debug_frozen or asleep) and lstate != LState.GRAB:
		return
	match lstate:
		LState.SHAMBLE:
			_tick_shamble(delta)
		LState.WINDUP:
			_t -= delta
			_face_dir(_lunge_dir)
			if _t <= 0.0:
				_launch()
		LState.LUNGE:
			_tick_lunge(delta)
		LState.RECOVER:
			_t -= delta
			if _settle_or_fall(delta) and _t <= 0.0:
				lstate = LState.SHAMBLE
		LState.GRAB:
			_tick_grab(delta)
		LState.STUNNED:
			_t -= delta
			_settle_floor()
			if _t <= 0.0:
				lstate = LState.SHAMBLE
		LState.SWING:
			_tick_swing(delta)
		LState.CLIMB:
			_tick_climb(delta)
		LState.DEAD:
			_dead_t += delta
	if lstate != LState.GRAB:
		burn_fraction = 0.0
	synced_position = global_position
	synced_yaw = _model.rotation.y


func _tick_shamble(delta: float) -> void:
	var p := _pick_target()
	_target = p
	hunt_peer = p.peer_id if p != null else 0
	if p == null:
		# Nobody in sight: drift toward whatever is loud, else sway where it stands.
		var loud := _loudest()
		if loud != null:
			_walk_toward(loud.global_position, delta)
		return
	var to := p.global_position - global_position
	to.y = 0.0
	var d := to.length()
	var level := absf(p.global_position.y - global_position.y) < 2.2  # the same roof, near enough
	if d <= LUNGE_MAX and d >= LUNGE_MIN and p.state == Player.State.NORMAL and level:
		_start_windup(p)
		return
	if d < LUNGE_MIN and p.state == Player.State.NORMAL and absf(p.global_position.y - global_position.y) < 1.6:
		_start_grab(p)  # right on top of someone: it just takes them
		return
	_walk_toward(p.global_position, delta)


func _walk_toward(target: Vector3, delta: float) -> void:
	var to := target - global_position
	to.y = 0.0
	if to.length() < 0.05:
		return
	var dir := to.normalized()
	_face_dir(dir, delta)
	var step := dir * minf(SHAMBLE_SPEED * delta, to.length())
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(chest_point(), chest_point() + step.normalized() * 0.6, ChainBody.LAYER_WORLD)
	if not space.intersect_ray(q).is_empty():
		# A wall in the way. If whoever it wants is up there, it goes up the face.
		if target.y - global_position.y > 1.0:
			_start_climb()
		return
	# Nothing under the next step: the edge of the roof. Look across for the next one.
	var ahead := global_position + dir * 1.1
	var ground := _ground_under(ahead)
	if ground < -1.0e8:
		var land := _find_landing(dir, target)
		if land.y > -1.0e8:
			_start_swing(land)
		return
	global_position += step
	_settle_floor()


## Stands on whatever is under it (a lunge can end on a crate or a car roof; a step off a
## higher roof is a drop). Nothing under it for a long way: it keeps its height.
func _settle_floor() -> void:
	var y := _ground_under(global_position)
	if y > -1.0e8:
		global_position.y = y


## After a jump or a swing that ended over nothing: it falls, and far enough down it's gone.
## Returns false while it is still falling.
func _settle_or_fall(delta: float) -> bool:
	var y := _ground_under(global_position)
	if y > -1.0e8:
		global_position.y = y
		return true
	global_position.y -= 12.0 * delta
	if global_position.y < floor_y - STREET_FALL:
		die()
	return false


## The floor under a point, within DROP_PROBE metres below (and a little above), or -1e9.
func _ground_under(at: Vector3) -> float:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(at + Vector3(0.0, 1.2, 0.0), at - Vector3(0.0, DROP_PROBE, 0.0), ChainBody.LAYER_WORLD)
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return -1.0e9
	return (hit["position"] as Vector3).y


## Somewhere to land across the gap: the first roof along the way it was going, else along the
## straight line to its target, within SWING_RANGE. A roof is a floor found from well above.
func _find_landing(dir: Vector3, target: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var dirs: Array[Vector3] = [dir]
	var to := target - global_position
	to.y = 0.0
	if to.length() > 0.5:
		dirs.append(to.normalized())
	for d in dirs:
		var seen_gap := false
		var k := 2.0
		while k <= SWING_RANGE:
			var p := global_position + d * k
			var q := PhysicsRayQueryParameters3D.create(p + Vector3(0.0, 9.0, 0.0), p - Vector3(0.0, DROP_PROBE, 0.0), ChainBody.LAYER_WORLD)
			var hit := space.intersect_ray(q)
			if hit.is_empty():
				seen_gap = true
			elif seen_gap and (hit["normal"] as Vector3).y > 0.7:
				var y := (hit["position"] as Vector3).y
				if absf(y - global_position.y) < 12.0:
					return Vector3(p.x, y, p.z)
			k += 1.0
	return Vector3(0.0, -1.0e9, 0.0)


func _start_swing(land: Vector3) -> void:
	lstate = LState.SWING
	swings += 1
	swing_from = global_position
	swing_to = land
	_swing_dur = clampf(swing_from.distance_to(swing_to) / SWING_SPEED, 0.5, 2.4)
	_t = 0.0
	var to := land - global_position
	to.y = 0.0
	if to.length() > 0.05:
		_face_dir(to.normalized())
	_fx("click", -2.0, 0.5)
	_fx("scrape", -8.0, 2.2)


func _tick_swing(delta: float) -> void:
	_t += delta
	var u := clampf(_t / _swing_dur, 0.0, 1.0)
	var ue := u * u * (3.0 - 2.0 * u)
	var p := swing_from.lerp(swing_to, ue)
	p.y -= SWING_SAG * sin(u * PI) * minf(1.0, _swing_dur / 1.2)
	global_position = p
	# Whoever is under the swing gets knocked flat, not taken: the landing is where it bites.
	for pl in Net.get_players():
		if pl.state != Player.State.NORMAL:
			continue
		var d := Vector2(pl.global_position.x - global_position.x, pl.global_position.z - global_position.z).length()
		if d < HIT_RADIUS and absf(pl.global_position.y - global_position.y) < 1.5:
			var away := (pl.global_position - global_position)
			away.y = 0.0
			pl.apply_knockback(away.normalized() * 3.0 + Vector3.UP * 2.0)
	if u >= 1.0:
		global_position = swing_to
		_settle_floor()
		lstate = LState.RECOVER
		_t = RECOVER_TIME * 0.4
		_fx("thump", -4.0, 0.9)


func _start_climb() -> void:
	lstate = LState.CLIMB
	_climb_from_y = global_position.y
	_t = 0.0
	_fx("scrape", -6.0, 1.6)


## Up the face while there is one in front of it; over the top, a step forward onto the roof.
func _tick_climb(delta: float) -> void:
	global_position.y += CLIMB_SPEED * delta
	var fwd := Vector3(-sin(_model.rotation.y), 0.0, -cos(_model.rotation.y))
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0.0, 0.3, 0.0), global_position + Vector3(0.0, 0.3, 0.0) + fwd * 1.2, ChainBody.LAYER_WORLD)
	if space.intersect_ray(q).is_empty():
		# Over the edge: onto the roof.
		global_position += fwd * 1.6 + Vector3(0.0, 0.2, 0.0)
		_settle_floor()
		lstate = LState.RECOVER
		_t = RECOVER_TIME * 0.5
		_fx("thump", -6.0, 1.1)
	elif global_position.y - _climb_from_y > CLIMB_MAX:
		global_position.y = _climb_from_y
		_settle_floor()
		lstate = LState.SHAMBLE


## Where the thread hangs from while it swings.
func thread_anchor() -> Vector3:
	return (swing_from + swing_to) * 0.5 + Vector3(0.0, maxf(swing_from.y, swing_to.y) - (swing_from.y + swing_to.y) * 0.5 + WEB_ANCHOR_H, 0.0)


func _start_windup(p: Player) -> void:
	lstate = LState.WINDUP
	_t = WINDUP_TIME
	hunt_peer = p.peer_id
	_target = p
	var to := p.global_position - global_position
	to.y = 0.0
	_lunge_dir = to.normalized() if to.length() > 0.05 else Vector3(-sin(_model.rotation.y), 0.0, -cos(_model.rotation.y))
	_lunge_len = clampf(to.length() + 0.6, 3.0, LUNGE_DIST)
	_face_dir(_lunge_dir)
	_fx("screech", 4.0, _rng.randf_range(0.9, 1.15))


func _launch() -> void:
	lstate = LState.LUNGE
	lunges += 1
	_t = 0.0
	_lunge_from = global_position
	_fx("thump", -2.0, 1.4)


func _tick_lunge(delta: float) -> void:
	_t += delta
	var u := clampf(_t / LUNGE_TIME, 0.0, 1.0)
	var flat := _lunge_from + _lunge_dir * _lunge_len * u
	var want := Vector3(flat.x, _lunge_from.y + 4.0 * LUNGE_ARC * u * (1.0 - u), flat.z)
	# A wall in the way ends the jump early.
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, want + Vector3.UP, ChainBody.LAYER_WORLD)
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		global_position = (hit["position"] as Vector3) - Vector3.UP + (hit["normal"] as Vector3) * 0.4
		_land(false)
		return
	global_position = want
	# The hit test is a capsule overlap, not physics: whoever is in the line and not under it.
	for p in Net.get_players():
		if p.state != Player.State.NORMAL or p.is_sliding():
			continue  # a slide goes under it
		var d := Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z).length()
		if d < HIT_RADIUS and absf(p.global_position.y - global_position.y) < 1.8:
			_start_grab(p)
			return
	if u >= 1.0:
		_land(true)


func _land(missed: bool) -> void:
	lstate = LState.RECOVER
	_t = RECOVER_TIME
	_settle_floor()
	_fx("thump", 0.0, 0.7)


func _start_grab(p: Player) -> void:
	lstate = LState.GRAB
	_grabbed = p
	grab_peer = p.peer_id
	hunt_peer = p.peer_id
	_t = 0.0
	_rescue = 0.0
	_burn = 0.0
	_hits_in_grab = 0
	_settle_floor()
	var to := p.global_position - global_position
	to.y = 0.0
	if to.length() > 0.05:
		_face_dir(to.normalized())
	p.grab_start(self)
	_fx("spider_hiss", 4.0, 0.9)
	GameState.post_tip("grab_jumper", "IT'S ON %s. Everyone beside them: HOLD CTRL. Or a light in its face, the air horn, or two shots." % p.display_name.to_upper(), 4.0)


func _tick_grab(delta: float) -> void:
	if _grabbed == null or not is_instance_valid(_grabbed) or not _grabbed.is_grabbed():
		release(false)
		return
	_t += delta
	var fwd := Vector3(-sin(_model.rotation.y), 0.0, -cos(_model.rotation.y))
	_grabbed.global_position = global_position + fwd * 0.5 + Vector3(0.0, 0.05, 0.0)
	_grabbed.synced_position = _grabbed.global_position
	for b in Net.get_chain_bodies():
		if b != _grabbed and b.global_position.distance_to(_grabbed.global_position) < RESCUE_RADIUS:
			_rescue += b.resist_value() * delta
	if _rescue >= RESCUE_NEEDED:
		release(false)
		stun(1.6)
		return
	if _tick_burn(delta):
		release(false)
		stun(2.0)
		return
	if _t >= GRAB_TIME:
		var victim := _grabbed.display_name
		release(true)
		var level := get_tree().get_first_node_in_group("level")
		if level != null and level.has_method("request_layoff"):
			level.call("request_layoff", "%s was taken by a Jumper." % victim)


## Server. Lets go of whoever it pins. killed: the victim was taken.
func release(killed: bool) -> void:
	var victim := _grabbed
	_grabbed = null
	grab_peer = 0
	if victim != null and is_instance_valid(victim) and victim.is_grabbed():
		victim.grab_end()
		if not killed:
			victim.apply_knockback(Vector3(-sin(_model.rotation.y), 0.0, -cos(_model.rotation.y)) * 3.0 + Vector3.UP * 3.0)
	if lstate == LState.GRAB:
		lstate = LState.RECOVER
		_t = RECOVER_TIME


## Server: air horn, a rescue. It reels and drops whoever it holds.
func stun(seconds: float) -> void:
	if lstate == LState.DEAD:
		return
	if _grabbed != null:
		release(false)
	var left := _t if lstate == LState.STUNNED else 0.0
	lstate = LState.STUNNED
	_t = maxf(left, seconds)
	hunt_peer = 0
	_fx("spider_hiss", 0.0, 1.35)


## Snubby hit (server): two while it holds someone make it let go; three kill it.
func take_hit() -> void:
	if lstate == LState.DEAD:
		return
	hits += 1
	_hits_in_grab += 1
	_fx("thump", -6.0, 1.8)
	if hits >= HITS_TO_DIE:
		die()
	elif lstate == LState.GRAB and _hits_in_grab >= HITS_TO_RELEASE:
		release(false)
		stun(1.2)
	elif lstate == LState.WINDUP:
		lstate = LState.STUNNED  # a shot mid-crouch spoils the jump
		_t = 0.8


func blast() -> void:
	die()


func die() -> void:
	if lstate == LState.DEAD:
		return
	if _grabbed != null:
		release(false)
	lstate = LState.DEAD
	hunt_peer = 0
	grab_peer = 0
	_dead_t = 0.0
	_fx("spider_hiss", 2.0, 0.7)


## Tests and respawns: back on its feet at a spot.
func debug_reset(at: Vector3) -> void:
	if _grabbed != null:
		release(false)
	global_position = at
	synced_position = at
	lstate = LState.SHAMBLE
	hits = 0
	_hits_in_grab = 0
	hunt_peer = 0
	grab_peer = 0
	_t = 0.0
	_burn = 0.0
	burn_fraction = 0.0
	_settle_floor()


func _pick_target() -> Player:
	var best: Player = null
	var best_d := INF
	var space := get_world_3d().direct_space_state
	for p in Net.get_players():
		if p.state == Player.State.GRABBED:
			continue
		var d := p.global_position.distance_to(global_position)
		if d > SIGHT_RANGE or d >= best_d:
			continue
		var q := PhysicsRayQueryParameters3D.create(chest_point(), p.eye_position(), ChainBody.LAYER_WORLD)
		if space.intersect_ray(q).is_empty():
			best = p
			best_d = d
	return best


func _loudest() -> Node3D:
	var best: Node3D = null
	var best_eff := NOISE_DRAW
	for n in get_tree().get_nodes_in_group("noise_source"):
		var n3 := n as Node3D
		if n3 == null or not n3.is_inside_tree() or not n3.has_method("noise_level"):
			continue
		var d := n3.global_position.distance_to(global_position)
		if d > 40.0:
			continue
		var eff := float(n3.call("noise_level")) * (1.0 - d / 40.0)
		if eff > best_eff:
			best_eff = eff
			best = n3
	return best


func _face_dir(dir: Vector3, delta: float = -1.0) -> void:
	if Vector2(dir.x, dir.z).length() < 0.01:
		return
	var want := atan2(-dir.x, -dir.z)
	if delta < 0.0:
		_model.rotation.y = want
	else:
		_model.rotation.y += clampf(wrapf(want - _model.rotation.y, -PI, PI), -TURN_SPEED * delta, TURN_SPEED * delta)
	synced_yaw = _model.rotation.y


func _tick_burn(delta: float) -> bool:
	var lit := false
	var space := get_world_3d().direct_space_state
	for p in Net.get_players():
		if p.held_item == null or p.held_item.data.id != "flashlight" or not p.held_item.is_active:
			continue
		var eye := p.eye_position()
		for target: Vector3 in [head_point(), chest_point()]:
			var to := target - eye
			var d := to.length()
			if d > BURN_RANGE or d < 0.1 or p.aim_direction().angle_to(to / d) > BURN_ANGLE:
				continue
			var q := PhysicsRayQueryParameters3D.create(eye, target - (to / d) * 0.3, ChainBody.LAYER_WORLD)
			q.exclude = [p.get_rid()]
			if space.intersect_ray(q).is_empty():
				lit = true
				break
		if lit:
			break
	if lit:
		_burn += delta
		_hiss_t -= delta
		if _hiss_t <= 0.0:
			_hiss_t = 0.35
			_fx("scrape", -6.0, 1.9)
	else:
		_burn = maxf(0.0, _burn - delta * BURN_DECAY)
	burn_fraction = clampf(_burn / BURN_TO_RELEASE, 0.0, 1.0)
	return _burn >= BURN_TO_RELEASE


func _fx(id: String, vol: float, pitch: float) -> void:
	var fx := Effects.find(self)
	if fx != null:
		fx.fx_sound.rpc(id, chest_point(), vol, pitch)


# --- Visuals (every peer) --------------------------------------------------------------------------

func _update_visuals(delta: float) -> void:
	_idle_call_t -= delta
	if _idle_call_t <= 0.0:
		_idle_call_t = randf_range(IDLE_CALL_EVERY.x, IDLE_CALL_EVERY.y)
		if lstate == LState.SHAMBLE and not asleep:
			Sfx.idle_call(self, "spider_hiss", head_point(), -8.0, randf_range(0.8, 1.0), IDLE_CALL_REACH, "a dry hiss", 8.0)
	var moved := global_position.distance_to(_last_pos) / maxf(delta, 0.0001)
	_last_pos = global_position
	_vis_speed = lerpf(_vis_speed, moved, clampf(delta * 8.0, 0.0, 1.0))
	if not multiplayer.is_server():
		_model.rotation.y = lerp_angle(_model.rotation.y, synced_yaw, clampf(delta * 12.0, 0.0, 1.0))
	if lstate != _shown_state:
		_shown_state = lstate
		if lstate == LState.DEAD:
			var tw := create_tween()
			tw.tween_property(_model, "rotation:z", PI, 0.6).set_ease(Tween.EASE_IN)  # on its back
			tw.parallel().tween_property(_model, "position:y", BODY_H * 0.6, 0.6)
			Sfx.caption(self, "it goes down", chest_point())
		elif _shown_state == LState.SHAMBLE and _model.rotation.z != 0.0:
			_model.rotation.z = 0.0
			_model.position.y = 0.0
	if grab_peer != _shown_grab:
		_shown_grab = grab_peer
		if grab_peer != 0:
			Sfx.play_at(self, "spider_shriek", head_point(), 8.0, 1.0, 40.0)  # a shriek no throat should make
		var victim := Net.find_player(grab_peer)
		if victim != null and victim.is_local:
			Sfx.play(self, "stinger", 0.0)
	_model.visible = lstate != LState.DEAD or _dead_t < DEAD_LINGER
	_hitbox.collision_layer = 0 if lstate == LState.DEAD else ChainBody.LAYER_MONSTER
	var t := Time.get_ticks_msec() * 0.001
	var walking := (lstate == LState.SHAMBLE and _vis_speed > 0.2) or lstate == LState.CLIMB
	_phase += delta * (_vis_speed * 4.0 + 0.6)
	# The thread: a line from the anchor over the gap down to its body while it swings.
	_thread_mesh.clear_surfaces()
	if lstate == LState.SWING:
		_thread_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		_thread_mesh.surface_add_vertex(thread_anchor())
		_thread_mesh.surface_add_vertex(chest_point())
		_thread_mesh.surface_end()
	var crouch_want := 1.0 if lstate == LState.WINDUP else 0.0
	_crouch = lerpf(_crouch, crouch_want, 1.0 - exp(-14.0 * delta))
	# Body height and pitch by state: low and coiled before the jump, flat in flight, over the
	# victim when it has one, twitching on its back when stunned.
	var body_y := BODY_H
	var pitch := 0.0
	match lstate:
		LState.WINDUP:
			body_y = BODY_H * 0.45
			pitch = 0.35
		LState.LUNGE:
			body_y = BODY_H
			pitch = -0.35
		LState.GRAB:
			body_y = BODY_H * 0.75
			pitch = 0.3
		LState.STUNNED:
			body_y = BODY_H * 0.8
			pitch = 0.2 * sin(t * 23.0)
		LState.SWING:
			body_y = BODY_H * 1.1
			pitch = -0.3 + 0.2 * sin(t * 3.0)
		LState.CLIMB:
			body_y = BODY_H * 0.8
			pitch = 1.45  # nose up the wall
		LState.RECOVER:
			body_y = BODY_H * 0.7
	var k := 1.0 - exp(-14.0 * delta)
	_body.position.y = lerpf(_body.position.y, body_y + (0.02 * sin(t * 2.1) if lstate == LState.SHAMBLE else 0.0), k)
	_body.rotation.x = lerpf(_body.rotation.x, pitch, k)
	# Legs: a sweeping gait in two sets, coiled under for the wind-up, flung wide in the jump,
	# the front pair holding whoever it has.
	for i in _legs.size():
		var root := _legs[i]
		var knee := _knees[i]
		var s := 1.0 if i % 2 == 1 else -1.0  # the side the leg points to
		var row := i / 2
		var set_off := PI if (row + i) % 2 == 0 else 0.0
		var fan := -s * (0.5 - float(row) * 0.33)
		var sweep := 0.0
		var lift := 0.55
		var bend := 1.45
		if walking:
			sweep = sin(_phase + set_off) * 0.35
			lift = 0.55 + maxf(0.0, cos(_phase + set_off)) * 0.3
		match lstate:
			LState.WINDUP:
				lift = 1.3 + 0.1 * sin(t * 40.0 + float(i))
				bend = 2.4
			LState.LUNGE:
				lift = -0.1 if row < 2 else 0.9
				bend = 0.6 if row < 2 else 2.2
				sweep = -0.4 if row < 2 else 0.3
			LState.GRAB:
				if row == 0:
					lift = -0.3
					bend = 1.9
					sweep = -0.5 + 0.1 * sin(t * 13.0 + float(i))
				else:
					lift = 0.7
			LState.STUNNED:
				lift = 0.9 + 0.3 * sin(t * 27.0 + float(i) * 1.7)
				sweep = 0.3 * sin(t * 31.0 + float(i))
			LState.SWING:
				lift = 1.0 + 0.1 * sin(t * 5.0 + float(i))
				bend = 1.2
				sweep = 0.15 * sin(t * 4.0 + float(i))
			LState.CLIMB:
				sweep = sin(_phase * 1.5 + set_off) * 0.35
				lift = 0.5 + maxf(0.0, cos(_phase * 1.5 + set_off)) * 0.3
			LState.DEAD:
				lift = 1.2
				bend = 2.3
				sweep = 0.2 * s
		root.rotation.z = lerpf(root.rotation.z, s * lift, k)
		root.rotation.y = lerpf(root.rotation.y, fan + sweep, k)
		knee.rotation.z = lerpf(knee.rotation.z, -s * bend, k)
	# The head: the eye cluster brightens before the jump; the fangs work.
	var eye_e := 2.5
	if lstate == LState.WINDUP:
		eye_e = 8.0
	elif lstate == LState.DEAD:
		eye_e = 0.0
	for e in _eyes:
		(e.material_override as StandardMaterial3D).emission_energy_multiplier = eye_e
	_head.rotation.x = 0.15 * sin(t * 1.9) + (0.3 * absf(sin(t * 25.0)) if lstate == LState.WINDUP else 0.0)
	# Captions: the screech has its own; the scuttle gets one when it's near.
	_caption_t -= delta
	if _caption_t <= 0.0 and lstate == LState.SHAMBLE and walking:
		var me := Net.get_local_player()
		if me != null and me.global_position.distance_to(global_position) < 22.0:
			_caption_t = 6.0
			Sfx.caption(self, "legs on the asphalt, big ones", chest_point())


## For the chase music: hunting, not stunned or dead.
func is_chasing() -> bool:
	return lstate != LState.DEAD and lstate != LState.STUNNED


## A wrench across it (server): drops whoever it pins and reels; otherwise a stagger (which
## also spoils a jump it was coiling for). True when it freed someone.
func wrench_hit(_by: Node3D) -> bool:
	if lstate == LState.DEAD:
		return false
	var held := _grabbed != null
	if held or lstate != LState.STUNNED:
		stun(Wrench.RESCUE_STUN if held else Wrench.STAGGER)
	return held
