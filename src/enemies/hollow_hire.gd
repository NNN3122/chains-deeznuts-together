class_name HollowHire
extends Node3D
## The Hollow Hires: Level 1's roaming threat. Former new hires still in their vests and hard
## hats, faces smoothed over, heads tilted a little too far. They wander the office cell to cell
## and look. One that SEES you (view cone, line of sight, closer if you crouch, farther if your
## flashlight is on) screams, the lights gutter, and it runs you down faster than you can walk.
## Caught, you're pinned: teammates brace beside you, a flashlight in its face, or a shot gets
## it off; nobody comes in a few seconds and the Line is laid off. A flashlight held on its face
## stuns it for a moment (then it's wise to the trick for a few seconds); two Snubby rounds or a
## bomb drop it for good, and the floor sends a replacement in from somewhere you aren't looking.
## Loud noises draw them over to look. Break Rooms are safe: they stop at the door.
## They walk the route through the doorways (a straight line from the side of a room to the next
## room's centre would cut the wall). Every floor's first Hire keeps to the rooms round the way up, the rest
## lean toward the green-sign path, so you meet one. At the end of a walk they stop and sweep
## the room through 180 degrees, so standing still in front of one is a gamble. One that sees
## you screams, and every other Hire on the floor answers and comes running: a sighting is a
## chase, not a hide. A loud event (a shouldered door, the fire alarm) wakes the floor: they
## hunt actively for a while. A squeaky decoy pulls every one of them to it, and they stand
## over it staring for as long as it squeaks.
## Host-authoritative like the rest; position, state and grab are replicated.

enum HState { WANDER, INVESTIGATE, CHASE, GRAB, STUNNED, DEAD, SWEEP }

const WANDER_SPEED: float = 1.3  # m/s
const INVESTIGATE_SPEED: float = 2.6
const ALERT_SPEED: float = 3.4  # m/s while the floor is awake: faster than a walk, slower than a run
const CHASE_SPEED: float = 5.6  # walking is 4.2, sprinting 7: you can outrun it, loudly
const SIGHT_RANGE: float = 17.0
const CROUCH_SIGHT: float = 0.5  # of the range: sneaking helps (pass behind one), it doesn't hide you
const TORCH_SIGHT: float = 1.6  # a flashlight on makes you visible from much farther
const ALERT_SIGHT: float = 1.25  # of the range while the floor is awake
const SWEEP_TIME: float = 2.4  # s to turn through 180 degrees at the end of a walk
const SWEEP_CHANCE: float = 0.55  # of wander walks that end in a sweep (investigations always do)
const PATROL_BIAS: float = 0.65  # of wander targets picked on the route, for the ones that aren't the sentry
const VIEW_HALF_ANGLE: float = 1.05  # rad: about 60 degrees to each side
const LOSE_SIGHT_TIME: float = 3.5  # s out of sight before it gives up on where you were
const GRAB_RANGE: float = 1.3
const GRAB_TIME: float = 3.5  # s pinned before the layoff
const RESCUE_NEEDED: float = 2.0  # resist-seconds from teammates beside the victim (bracing counts double)
const RESCUE_RADIUS: float = 2.5
const BURN_TO_STUN: float = 0.45  # s of a flashlight on its face
const BURN_RANGE: float = 15.0
const BURN_ANGLE: float = 0.45
const STUN_TIME: float = 3.0
const STUN_IMMUNE: float = 4.0  # s after a stun during which the light does nothing
const HITS_TO_DIE: int = 2
const DEAD_LINGER: float = 20.0
const HEAR_RADIUS: float = 22.0
const INVESTIGATE_NOISE: float = 20.0  # effective loudness that turns its head
const TURN_SPEED: float = 7.0  # rad/s
const SAFE_WAIT: float = 3.0  # s it stands at a Break Room door before wandering off
const HEAD_H: float = 1.62
const BODY_RADIUS: float = 0.32  # m kept clear of a wall: a 1.4 m doorway still lets it through
const CLEAR_H: float = 1.15  # m: over desks and chair backs, through a doorway, into a real wall
const STUCK_TIME: float = 1.2  # s of not moving before a wander picks somewhere else

var level: YellowRooms
var floor_index: int = 0
var floor_y: float = 0.0
var sentry: bool = false  # keeps to the rooms round the way up instead of the whole floor
var debug_frozen: bool = false

# Replicated.
var synced_position: Vector3 = Vector3.ZERO
var synced_yaw: float = 0.0
var hstate: int = HState.WANDER
var hunt_peer: int = 0
var grab_peer: int = 0
var burn_fraction: float = 0.0
var hits: int = 0

# Server.
var _target: Player = null
var _grabbed: Player = null
var _route: Array[Vector2i] = []
var _goal: Vector3 = Vector3.ZERO
var _last_seen: Vector3 = Vector3.ZERO
var _lose_t: float = 0.0
var _t: float = 0.0
var _rescue: float = 0.0
var _burn: float = 0.0
var _hiss_t: float = 0.0
var _immune_t: float = 0.0
var _safe_t: float = 0.0
var _dead_t: float = 0.0
var _alert_t: float = 0.0  # s left of "the floor is awake": it hunts the nearest player's room
var _sweep_base: float = 0.0
var _sweep_dir: float = 1.0
var _hold: Node3D = null  # the decoy it is standing over
var _stuck_t: float = 0.0  # s the last step didn't move it (a wall, a shelf)
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Visuals.
var _model: Node3D
var _hips: Node3D
var _head: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _thigh_l: Node3D
var _thigh_r: Node3D
var _hitbox: Area3D
var _phase: float = 0.0
var _shown_state: int = -1
var _shown_grab: int = 0
var _last_pos: Vector3 = Vector3.ZERO
var _vis_speed: float = 0.0
var _caption_t: float = 0.0


func _enter_tree() -> void:
	if has_node("Sync"):
		return
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	for prop in ["synced_position", "synced_yaw", "hstate", "hunt_peer", "grab_peer", "burn_fraction", "hits"]:
		var path := NodePath(".:" + prop)
		cfg.add_property(path)
		cfg.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	sync.replication_config = cfg
	add_child(sync)


func _ready() -> void:
	add_to_group("monster")
	add_to_group("hire")
	_rng.seed = hash(name)
	synced_position = global_position
	_last_pos = global_position
	_build_visuals()
	if multiplayer.is_server():
		_pick_wander()


# --- Visuals -----------------------------------------------------------------------------------

func _build_visuals() -> void:
	_model = Node3D.new()
	_model.name = "Model"
	add_child(_model)
	var skin := LevelKit.mat("hire_skin")
	var shirt := LevelKit.mat("hire_shirt")
	var vest := LevelKit.mat("hire_vest")
	var pants := LevelKit.mat("fabric")
	var dark := LevelKit.mat("rubber")
	_hips = Node3D.new()
	_hips.position = Vector3(0.0, 0.95, 0.0)
	_model.add_child(_hips)
	_box(_hips, Vector3(0.34, 0.2, 0.22), Vector3(0.0, 0.08, 0.0), pants)
	_box(_hips, Vector3(0.38, 0.5, 0.24), Vector3(0.0, 0.43, 0.0), shirt)
	_box(_hips, Vector3(0.42, 0.44, 0.27), Vector3(0.0, 0.45, 0.0), vest)
	_box(_hips, Vector3(0.44, 0.04, 0.28), Vector3(0.0, 0.36, 0.0), LevelKit.mat("fixture"))  # a reflective band
	_box(_hips, Vector3(0.06, 0.3, 0.03), Vector3(0.0, 0.5, -0.145), LevelKit.mat("hazard"))  # the lanyard
	# The head: a smooth egg, no face, a hard hat a size too small, tilted.
	_head = Node3D.new()
	_head.position = Vector3(0.0, 0.7, 0.0)
	_hips.add_child(_head)
	_cyl(_head, 0.05, 0.12, Vector3(0.0, 0.05, 0.0), skin)
	_sphere(_head, 0.13, Vector3(0.0, 0.24, 0.0), skin, Vector3(0.9, 1.2, 1.0))
	var hat := MeshInstance3D.new()
	var dm := SphereMesh.new()
	dm.radius = 0.12
	dm.height = 0.12
	dm.is_hemisphere = true
	hat.mesh = dm
	hat.position = Vector3(0.0, 0.34, 0.0)
	hat.material_override = LevelKit.mat("sign")
	_head.add_child(hat)
	_arm_l = _arm(-1.0, shirt, skin)
	_arm_r = _arm(1.0, shirt, skin)
	_thigh_l = _leg(-1.0, pants, dark)
	_thigh_r = _leg(1.0, pants, dark)
	_hitbox = Area3D.new()
	_hitbox.collision_layer = ChainBody.LAYER_MONSTER
	_hitbox.collision_mask = 0
	_hitbox.monitoring = false
	var hs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 1.8
	hs.shape = cap
	hs.position = Vector3(0.0, 0.95, 0.0)
	_hitbox.add_child(hs)
	add_child(_hitbox)


func _arm(side: float, shirt: Material, skin: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(side * 0.24, 0.62, 0.0)
	_hips.add_child(pivot)
	_cyl(pivot, 0.05, 0.34, Vector3(0.0, -0.17, 0.0), shirt)
	_cyl(pivot, 0.042, 0.34, Vector3(0.0, -0.5, 0.0), skin)
	_box(pivot, Vector3(0.08, 0.1, 0.05), Vector3(0.0, -0.72, 0.0), skin)
	pivot.rotation.z = side * 0.1
	return pivot


func _leg(side: float, pants: Material, dark: Material) -> Node3D:
	var thigh := Node3D.new()
	thigh.position = Vector3(side * 0.11, 0.0, 0.0)
	_hips.add_child(thigh)
	_cyl(thigh, 0.075, 0.46, Vector3(0.0, -0.23, 0.0), pants)
	_cyl(thigh, 0.065, 0.42, Vector3(0.0, -0.68, 0.0), pants)
	_box(thigh, Vector3(0.12, 0.08, 0.28), Vector3(0.0, -0.91, -0.05), dark)
	return thigh


func _box(parent: Node3D, size: Vector3, at: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = at
	mi.material_override = m
	parent.add_child(mi)


func _sphere(parent: Node3D, r: float, at: Vector3, m: Material, scl: Vector3 = Vector3.ONE) -> void:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	mi.mesh = s
	mi.position = at
	mi.scale = scl
	mi.material_override = m
	parent.add_child(mi)


func _cyl(parent: Node3D, r: float, h: float, at: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r * 0.9
	c.height = h
	mi.mesh = c
	mi.position = at
	mi.material_override = m
	parent.add_child(mi)


func head_point() -> Vector3:
	return global_position + Vector3(0.0, HEAD_H, 0.0)


func chest_point() -> Vector3:
	return global_position + Vector3(0.0, 1.3, 0.0)


func is_hunting() -> bool:
	return hstate == HState.CHASE or hstate == HState.GRAB


func is_dead() -> bool:
	return hstate == HState.DEAD


func is_alerted() -> bool:
	return _alert_t > 0.0


func facing() -> Vector3:
	return Vector3(-sin(_model.rotation.y), 0.0, -cos(_model.rotation.y))


# --- Server ------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		_server_tick(delta)
	else:
		var k := 16.0 if hstate == HState.CHASE else 10.0
		global_position = global_position.lerp(synced_position, clampf(delta * k, 0.0, 1.0))
	_update_visuals(delta)


func _server_tick(delta: float) -> void:
	if debug_frozen and hstate != HState.GRAB:
		return
	_immune_t = maxf(0.0, _immune_t - delta)
	_alert_t = maxf(0.0, _alert_t - delta)
	if hstate != HState.GRAB:
		burn_fraction = 0.0
	match hstate:
		HState.WANDER:
			_look_for_players()
			if hstate == HState.WANDER:
				_listen()
			if hstate == HState.WANDER:
				if _follow_route(WANDER_SPEED, delta):
					if _rng.randf() < SWEEP_CHANCE:
						_start_sweep()
					else:
						_pick_wander()
		HState.INVESTIGATE:
			_look_for_players()
			if hstate == HState.INVESTIGATE:
				_listen()
			if hstate == HState.INVESTIGATE and _follow_route(ALERT_SPEED if _alert_t > 0.0 else INVESTIGATE_SPEED, delta):
				_start_sweep()
		HState.SWEEP:
			_look_for_players()
			if hstate == HState.SWEEP:
				_listen()
			if hstate == HState.SWEEP:
				_tick_sweep(delta)
		HState.CHASE:
			_tick_chase(delta)
		HState.GRAB:
			_tick_grab(delta)
		HState.STUNNED:
			_t -= delta
			if _t <= 0.0:
				hstate = HState.WANDER
				_immune_t = STUN_IMMUNE
				_look_for_players()
		HState.DEAD:
			_dead_t += delta
	if hstate != HState.DEAD and hstate != HState.STUNNED and hstate != HState.GRAB:
		_tick_burn(delta)
	synced_position = global_position
	synced_yaw = _model.rotation.y


## Anyone in its view cone with a clear line gets chased. Crouching shrinks the range; a lit
## flashlight grows it.
func _look_for_players() -> void:
	var best: Player = null
	var best_d := INF
	for p in Net.get_players():
		if p.state != Player.State.NORMAL or not _on_floor(p.global_position):
			continue
		var d := _can_see(p)
		if d >= 0.0 and d < best_d:
			best_d = d
			best = p
	if best != null:
		_start_chase(best)


## Distance if visible, else -1.
func _can_see(p: Player) -> float:
	var to := p.eye_position() - head_point()
	var d := to.length()
	var range_m := SIGHT_RANGE
	if _alert_t > 0.0:
		range_m *= ALERT_SIGHT
	if p.is_bracing():
		range_m *= CROUCH_SIGHT
	if p.held_item != null and p.held_item.data.id == "flashlight" and p.held_item.is_active:
		range_m *= TORCH_SIGHT
	if d > range_m or d < 0.05:
		return -1.0
	if facing().angle_to(Vector3(to.x, 0.0, to.z).normalized()) > VIEW_HALF_ANGLE:
		return -1.0
	var q := PhysicsRayQueryParameters3D.create(head_point(), p.eye_position(), ChainBody.LAYER_WORLD)
	if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
		return -1.0
	return d


func _start_chase(p: Player) -> void:
	if hstate == HState.CHASE and _target == p:
		return
	var fresh := hstate != HState.CHASE
	hstate = HState.CHASE
	_target = p
	hunt_peer = p.peer_id
	_last_seen = p.global_position
	_lose_t = 0.0
	_route.clear()
	_safe_t = 0.0
	_hold = null
	if fresh:
		_fx("growl", 4.0, _rng.randf_range(0.6, 0.75))
		_rpc_seen.rpc()
		if level != null:
			level.hire_callout(self, p)


@rpc("authority", "call_local", "reliable")
func _rpc_seen() -> void:
	Sfx.caption(self, "a scream: it's seen you", head_point())
	var me := Net.get_local_player()
	if me != null and me.global_position.distance_to(global_position) < 20.0:
		me.add_shake(0.35)


## Server: a colleague on this floor screamed. It drops whatever it was doing and runs to where
## the victim was; from there it hunts like any chase (the victim in view keeps it on them).
func join_chase(p: Player) -> void:
	if hstate == HState.CHASE or hstate == HState.GRAB or hstate == HState.STUNNED or hstate == HState.DEAD or debug_frozen:
		return
	hstate = HState.CHASE
	_target = p
	hunt_peer = p.peer_id
	_last_seen = p.global_position
	_lose_t = 0.0
	_route.clear()
	_safe_t = 0.0
	_hold = null
	_alert_t = maxf(_alert_t, 20.0)
	_fx("growl", 2.0, _rng.randf_range(0.55, 0.7))
	_rpc_answered.rpc()


@rpc("authority", "call_local", "reliable")
func _rpc_answered() -> void:
	Sfx.caption(self, "another scream answers", head_point())


## Server: something loud happened on this floor (a shouldered door, the fire alarm, a scream).
## It goes to look, and for `seconds` it hunts: sharper eyes, a faster walk, and when it finds
## nothing it heads for the room the nearest player is in.
func alert(pos: Vector3, seconds: float) -> void:
	if hstate == HState.CHASE or hstate == HState.GRAB or hstate == HState.STUNNED or hstate == HState.DEAD:
		return
	_alert_t = maxf(_alert_t, seconds)
	_hold = null
	hstate = HState.INVESTIGATE
	_route_toward(pos)


## The sweep: it stops where it is and turns through 180 degrees, looking. Standing still in
## front of it is a gamble. Over a squeaking decoy it keeps sweeping until the squeaks stop.
func _start_sweep() -> void:
	hstate = HState.SWEEP
	_t = 0.0
	_sweep_dir = 1.0 if _rng.randf() < 0.5 else -1.0
	_sweep_base = _model.rotation.y + PI * 0.5 * _sweep_dir  # start a quarter turn to one side...
	_route.clear()


func _tick_sweep(delta: float) -> void:
	_t += delta
	var u := clampf(_t / SWEEP_TIME, 0.0, 1.0)
	# ...and turn the other way through half a circle. Ease at the ends like a head would.
	var s := 0.5 - 0.5 * cos(u * PI)
	_model.rotation.y = _sweep_base - PI * s * _sweep_dir
	synced_yaw = _model.rotation.y
	if u < 1.0:
		return
	if _hold != null and is_instance_valid(_hold) and _hold.is_inside_tree() and float(_hold.call("noise_level")) > 0.0:
		_start_sweep()  # still squeaking: keep staring at it
		return
	_hold = null
	if _alert_t > 0.0:
		var p := _nearest_player()
		if p != null:
			hstate = HState.INVESTIGATE
			_route_toward(p.global_position)
			return
	hstate = HState.WANDER
	_pick_wander()


func _nearest_player() -> Player:
	var best: Player = null
	var best_d := INF
	for p in Net.get_players():
		if p.state != Player.State.NORMAL or not _on_floor(p.global_position) or level.is_safe_spot(p.global_position):
			continue
		var d := _flat_dist(p.global_position)
		if d < best_d:
			best_d = d
			best = p
	return best


## Tests: start a sweep now.
func debug_sweep() -> void:
	_start_sweep()


func _tick_chase(delta: float) -> void:
	if _target == null or not is_instance_valid(_target) or _target.state != Player.State.NORMAL:
		_give_up()
		return
	var seen := _can_see(_target) >= 0.0
	if seen:
		_last_seen = _target.global_position
		_lose_t = 0.0
	else:
		_lose_t += delta
		if _lose_t > LOSE_SIGHT_TIME and global_position.distance_to(_last_seen) < 1.5:
			_give_up()
			return
	# Someone else in plain view and much closer steals its attention.
	for p in Net.get_players():
		if p != _target and p.state == Player.State.NORMAL:
			var d := _can_see(p)
			if d >= 0.0 and d < _target.global_position.distance_to(global_position) * 0.5:
				_start_chase(p)
				return
	var safe := level.is_safe_spot(_target.global_position)
	if safe and global_position.distance_to(_target.global_position) < 4.0:
		# It won't go in. It stands at the door and stares, then loses interest.
		_face(_target.global_position, delta)
		_safe_t += delta
		if _safe_t > SAFE_WAIT:
			_give_up()
		return
	var goal := _last_seen
	# A thin line of sight can still cut the corner of a doorway. Only run straight when the
	# whole body fits; otherwise go room to room through the openings.
	if seen and _body_fits(goal):
		_route.clear()
		_move_toward(goal, CHASE_SPEED, delta)
	else:
		_route_toward(goal)
		_follow_route(CHASE_SPEED, delta)
	if seen and not safe and _flat_dist(_target.global_position) < GRAB_RANGE and absf(_target.global_position.y - global_position.y) < 1.6:
		_start_grab(_target)


func _give_up() -> void:
	hstate = HState.INVESTIGATE
	hunt_peer = 0
	_target = null
	_route_toward(_last_seen)
	_safe_t = 0.0
	_alert_t = maxf(_alert_t, 12.0)  # it lost you, it hasn't forgotten you
	if _route.is_empty() and _flat_dist(_goal) < 0.5:
		_start_sweep()


func _start_grab(p: Player) -> void:
	hstate = HState.GRAB
	_grabbed = p
	grab_peer = p.peer_id
	hunt_peer = p.peer_id
	_t = 0.0
	_rescue = 0.0
	_burn = 0.0
	_face(p.global_position, -1.0)
	p.grab_start(self)
	_fx("growl", 6.0, 0.5)
	GameState.post_message("IT HAS %s. Everyone beside them: HOLD CTRL. Or a light in its face, or shoot it." % p.display_name.to_upper(), 4.0)


func _tick_grab(delta: float) -> void:
	if _grabbed == null or not is_instance_valid(_grabbed) or not _grabbed.is_grabbed():
		release(false)
		return
	_t += delta
	_grabbed.global_position = global_position + facing() * 0.55 + Vector3(0.0, 0.05, 0.0)
	_grabbed.synced_position = _grabbed.global_position
	for b in Net.get_chain_bodies():
		if b != _grabbed and b.global_position.distance_to(_grabbed.global_position) < RESCUE_RADIUS:
			_rescue += b.resist_value() * delta
	if _rescue >= RESCUE_NEEDED:
		GameState.post_message("They pulled it off %s. RUN." % _grabbed.display_name, 3.0)
		release(false)
		stun(2.0)
		return
	if _tick_burn(delta):
		return  # the light stunned it, and the stun let go
	if _t >= GRAB_TIME:
		var victim := _grabbed.display_name
		release(true)
		var lvl := get_tree().get_first_node_in_group("level")
		if lvl != null and lvl.has_method("request_layoff"):
			lvl.call("request_layoff", "%s was clocked out by a Hollow Hire." % victim)


## Server. Lets go of whoever it holds. killed: the victim was taken.
func release(killed: bool) -> void:
	var victim := _grabbed
	_grabbed = null
	grab_peer = 0
	if victim != null and is_instance_valid(victim) and victim.is_grabbed():
		victim.grab_end()
		if not killed:
			victim.apply_knockback(facing() * 3.0 + Vector3.UP * 2.5)
	if hstate == HState.GRAB:
		hstate = HState.WANDER
		hunt_peer = 0
		_pick_wander()


## Server: a flashlight in its face, the air horn, a rescue. It covers its face and stands there.
func stun(seconds: float) -> void:
	if hstate == HState.DEAD:
		return
	if _grabbed != null:
		release(false)
	var left := _t if hstate == HState.STUNNED else 0.0
	hstate = HState.STUNNED
	hunt_peer = 0
	_t = maxf(left, seconds)
	_burn = 0.0
	burn_fraction = 0.0
	_fx("growl", 0.0, 1.4)


## Snubby hit (server): one while it holds someone frees them; two kill it.
func take_hit() -> void:
	if hstate == HState.DEAD:
		return
	hits += 1
	_fx("thump", -6.0, 1.7)
	if hits >= HITS_TO_DIE:
		die()
	elif hstate == HState.GRAB:
		GameState.post_message("Shot. It dropped them.", 2.5)
		release(false)
		stun(1.5)


func blast() -> void:
	die()


func die() -> void:
	if hstate == HState.DEAD:
		return
	if _grabbed != null:
		release(false)
	hstate = HState.DEAD
	hunt_peer = 0
	grab_peer = 0
	_dead_t = 0.0
	_fx("growl", 2.0, 0.4)
	GameState.post_message("One down. The floor will send another.", 2.5)


## Server: back on its feet somewhere (a respawn, a test, a regroup pushing it away).
func respawn_at(pos: Vector3) -> void:
	if _grabbed != null:
		release(false)
	global_position = Vector3(pos.x, floor_y, pos.z)
	synced_position = global_position
	hstate = HState.WANDER
	hits = 0
	hunt_peer = 0
	grab_peer = 0
	_target = null
	_t = 0.0
	_burn = 0.0
	_immune_t = 0.0
	_dead_t = 0.0
	_alert_t = 0.0
	_hold = null
	_stuck_t = 0.0
	burn_fraction = 0.0
	_pick_wander()


func debug_reset(pos: Vector3, yaw: float = 0.0) -> void:
	respawn_at(pos)
	_model.rotation.y = yaw
	synced_yaw = yaw
	_route.clear()


## Server: put it at a spot facing a target and set it on them (the B1 ambush through the door
## behind the group).
func ambush(at: Vector3, p: Player) -> void:
	if hstate == HState.DEAD or debug_frozen:
		return
	if _grabbed != null:
		release(false)
	global_position = Vector3(at.x, floor_y, at.z)
	synced_position = global_position
	hstate = HState.WANDER
	_face(p.global_position, -1.0)
	_start_chase(p)


func debug_face(target: Vector3) -> void:
	_face(target, -1.0)


# --- Getting about: cell to cell through the doorways, straight lines when the floor is clear ---

## The sentry keeps to the last rooms of the route (the way up and the two before it); the
## others go to a route room more often than not, and anywhere on the floor the rest of the time.
func _pick_wander() -> void:
	var here := level.cell_of(global_position)
	var patrol := level.patrol_cells(floor_index)
	for _try in 12:
		var c: Vector2i
		if not patrol.is_empty() and sentry:
			c = patrol[_rng.randi_range(maxi(0, patrol.size() - 3), patrol.size() - 1)]
		elif not patrol.is_empty() and _rng.randf() < PATROL_BIAS:
			c = patrol[_rng.randi_range(0, patrol.size() - 1)]
		else:
			c = Vector2i(_rng.randi_range(0, YellowRooms.GRID - 1), _rng.randi_range(0, YellowRooms.GRID - 1))
		if c == here or level.is_safe_cell(floor_index, c):
			continue
		_route = level.route(floor_index, here, c)
		if _route.size() > 1:
			_route.pop_front()
			return
	_route.clear()


func _route_toward(p: Vector3) -> void:
	var here := level.cell_of(global_position)
	var there := level.cell_of(p)
	_route = level.route(floor_index, here, there)
	if not _route.is_empty():
		_route.pop_front()
	_goal = p


## Walks the route one room at a time, through the doorway between them. A straight line from
## wherever it is standing to the next room's centre cuts the wall beside the door, so the
## doorway is the waypoint until it has passed through. Returns true when there is nothing left.
func _follow_route(speed: float, delta: float) -> bool:
	if _route.is_empty():
		if (hstate == HState.INVESTIGATE or hstate == HState.CHASE) and _flat_dist(_goal) > 0.4:
			_move_toward(_goal, speed, delta)
			return false
		return true
	var next: Vector2i = _route[0]
	var here := level.cell_of(global_position)
	var dest := level.cell_center(floor_index, next)
	if here != next:
		var door := level.doorway_between(floor_index, here, next)
		if door.y < 0.0:
			# The route's next room isn't a neighbour of where it's actually standing.
			if hstate == HState.WANDER:
				_pick_wander()
			else:
				_route_toward(_goal if _goal != Vector3.ZERO else dest)
			return false
		if _flat_dist(door) > 0.45:
			var center := level.cell_center(floor_index, here)
			if _body_fits(door):
				dest = door
			elif _flat_dist(center) > 0.5 and _body_fits(center):
				dest = center  # back into the room, then out through the opening
			else:
				dest = door
	var before := global_position
	_move_toward(dest, speed, delta)
	if global_position.distance_to(before) < 0.002:
		_stuck_t += delta
		if _stuck_t > STUCK_TIME and hstate == HState.WANDER:
			_stuck_t = 0.0
			_pick_wander()
	else:
		_stuck_t = 0.0
	if level.cell_of(global_position) == next and _flat_dist(level.cell_center(floor_index, next)) < 0.45:
		_route.pop_front()
	return false


func _move_toward(target: Vector3, speed: float, delta: float) -> void:
	var to := target - global_position
	to.y = 0.0
	if to.length() < 0.02:
		return
	_face(target, delta)
	var step := to.normalized() * minf(speed * delta, to.length())
	if _step_fits(step):
		global_position += step
	else:
		# A wall takes the component that would enter it; the other slides along it.
		var along_x := Vector3(step.x, 0.0, 0.0)
		var along_z := Vector3(0.0, 0.0, step.z)
		if absf(step.x) >= absf(step.z) and _step_fits(along_x):
			global_position += along_x
		elif _step_fits(along_z):
			global_position += along_z
		elif _step_fits(along_x):
			global_position += along_x
	global_position.y = floor_y


## The centre of this one step. A long path uses _body_fits (the shoulders too); the step itself
## is a centre ray so it can still slide along a wall it isn't allowed to enter. At chase speed
## a tick is shorter than a wall is thick, and the ray catches a step that would come out the other side.
func _step_fits(step: Vector3) -> bool:
	if step.length() < 0.0001:
		return true
	var from := global_position + Vector3(0.0, CLEAR_H, 0.0)
	var q := PhysicsRayQueryParameters3D.create(from, from + step, ChainBody.LAYER_WORLD)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## True when the capsule can walk the straight line to target without entering a wall.
func _body_fits(target: Vector3) -> bool:
	var flat := Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
	var len := flat.length()
	if len < 0.02:
		return true
	var dir := flat / len
	var side := Vector3(-dir.z, 0.0, dir.x) * BODY_RADIUS
	var space := get_world_3d().direct_space_state
	for offset in [Vector3.ZERO, side, -side]:
		var from := global_position + offset + Vector3(0.0, CLEAR_H, 0.0)
		var to := Vector3(target.x, global_position.y + CLEAR_H, target.z) + offset
		var q := PhysicsRayQueryParameters3D.create(from, to, ChainBody.LAYER_WORLD)
		if not space.intersect_ray(q).is_empty():
			return false
	return true


func _face(target: Vector3, delta: float) -> void:
	var d := target - global_position
	if Vector2(d.x, d.z).length() < 0.02:
		return
	var want := atan2(-d.x, -d.z)
	if delta < 0.0:
		_model.rotation.y = want
	else:
		_model.rotation.y += clampf(wrapf(want - _model.rotation.y, -PI, PI), -TURN_SPEED * delta, TURN_SPEED * delta)
	synced_yaw = _model.rotation.y


func _flat_dist(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()


func _on_floor(p: Vector3) -> bool:
	return p.y > floor_y - 0.6 and p.y < floor_y + 4.2


## Loud things on its floor turn its head: it walks over to look. A squeaking decoy carries
## across the whole floor and holds it there.
func _listen() -> void:
	var best: Node3D = null
	var best_eff := INVESTIGATE_NOISE
	for n in get_tree().get_nodes_in_group("noise_source"):
		var n3 := n as Node3D
		if n3 == null or not n3.is_inside_tree() or not n3.has_method("noise_level") or not _on_floor(n3.global_position):
			continue
		var d := _flat_dist(n3.global_position)
		var decoy := n3 is Thrown and (n3 as Thrown).kind == "decoy"
		if d > HEAR_RADIUS and not decoy:
			continue
		var eff := float(n3.call("noise_level")) * (1.0 if decoy else 1.0 - d / HEAR_RADIUS)
		if eff > best_eff:
			best_eff = eff
			best = n3
	if best == null:
		return
	if best == _hold and hstate == HState.SWEEP:
		return  # already standing over it
	if hstate == HState.INVESTIGATE and _goal.distance_to(best.global_position) < 1.5:
		return  # already on the way
	hstate = HState.INVESTIGATE
	_route_toward(best.global_position)
	_hold = best if best is Thrown else null


## A flashlight on its face: stuns it (and frees whoever it holds). Returns true when it did.
func _tick_burn(delta: float) -> bool:
	if _immune_t > 0.0:
		burn_fraction = 0.0
		return false
	var lit := false
	var space := get_world_3d().direct_space_state
	for p in Net.get_players():
		if p.held_item == null or p.held_item.data.id != "flashlight" or not p.held_item.is_active:
			continue
		var eye := p.eye_position()
		var to := head_point() - eye
		var d := to.length()
		if d > BURN_RANGE or d < 0.1 or p.aim_direction().angle_to(to / d) > BURN_ANGLE:
			continue
		var q := PhysicsRayQueryParameters3D.create(eye, head_point() - (to / d) * 0.25, ChainBody.LAYER_WORLD)
		q.exclude = [p.get_rid()]
		if space.intersect_ray(q).is_empty():
			lit = true
			break
	if lit:
		_burn += delta
		_hiss_t -= delta
		if _hiss_t <= 0.0:
			_hiss_t = 0.3
			_fx("scrape", -8.0, 2.0)
	else:
		_burn = maxf(0.0, _burn - delta * 0.5)
	burn_fraction = clampf(_burn / BURN_TO_STUN, 0.0, 1.0)
	if _burn >= BURN_TO_STUN:
		var holding := _grabbed != null
		stun(STUN_TIME)
		GameState.post_message("The light stops it. For a moment." + (" It let go. GO." if holding else ""), 2.5)
		return true
	return false


func _fx(id: String, vol: float, pitch: float) -> void:
	var fx := Effects.find(self)
	if fx != null:
		fx.fx_sound.rpc(id, chest_point(), vol, pitch)


# --- Visuals (every peer) --------------------------------------------------------------------------

func _update_visuals(delta: float) -> void:
	var moved := global_position.distance_to(_last_pos) / maxf(delta, 0.0001)
	_last_pos = global_position
	_vis_speed = lerpf(_vis_speed, moved, clampf(delta * 8.0, 0.0, 1.0))
	if not multiplayer.is_server():
		_model.rotation.y = lerp_angle(_model.rotation.y, synced_yaw, clampf(delta * 12.0, 0.0, 1.0))
	if hstate != _shown_state:
		_shown_state = hstate
		if hstate == HState.DEAD:
			var tw := create_tween()
			tw.tween_property(_model, "rotation:x", PI * 0.5 - 0.1, 0.6).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(_model, "position:y", 0.2, 0.6)
		elif _model.rotation.x != 0.0:
			_model.rotation.x = 0.0
			_model.position.y = 0.0
	if grab_peer != _shown_grab:
		_shown_grab = grab_peer
		var victim := Net.find_player(grab_peer)
		if victim != null and victim.is_local:
			Sfx.play(self, "stinger", 0.0)
	_model.visible = hstate != HState.DEAD or _dead_t < DEAD_LINGER
	_hitbox.collision_layer = 0 if hstate == HState.DEAD else ChainBody.LAYER_MONSTER
	var t := Time.get_ticks_msec() * 0.001
	var walking := _vis_speed > 0.2
	_phase += delta * (_vis_speed * 3.6 + 0.5)
	var s := sin(_phase)
	var c := cos(_phase)
	var chase := hstate == HState.CHASE
	var hip_l := (s * (0.75 if chase else 0.4)) if walking else 0.0
	var hip_r := (-s * (0.75 if chase else 0.4)) if walking else 0.0
	var lean := 0.42 if chase else (0.08 + 0.03 * sin(t * 1.1))
	var arm_l := Vector3(-0.3 * s, 0.0, -0.1) if walking else Vector3(0.05 * sin(t * 0.9), 0.0, -0.1)
	var arm_r := Vector3(0.3 * s, 0.0, 0.1) if walking else Vector3(0.05 * sin(t * 1.3), 0.0, 0.1)
	# The head: always tilted a little too far, and it keeps turning to whoever is looking at it.
	var head_t := Vector3(0.1 * sin(t * 0.7), 0.0, 0.35 + 0.1 * sin(t * 0.5))
	var cam := get_viewport().get_camera_3d()
	if cam != null and _model.visible and hstate != HState.DEAD:
		var local := _model.to_local(cam.global_position) - _hips.position - _head.position
		if local.length() < 16.0:
			head_t.y = clampf(atan2(-local.x, -local.z), -1.2, 1.2)
	match hstate:
		HState.CHASE:
			arm_l = Vector3(-1.9 + 0.2 * s, 0.0, -0.3)
			arm_r = Vector3(-1.9 - 0.2 * s, 0.0, 0.3)
			head_t = Vector3(-0.3, head_t.y, 0.5 * sin(t * 9.0))
		HState.GRAB:
			arm_l = Vector3(-1.5, 0.0, -0.5 + 0.1 * sin(t * 12.0))
			arm_r = Vector3(-1.5, 0.0, 0.5 - 0.1 * sin(t * 12.0))
			lean = 0.3
			head_t = Vector3(-0.4, 0.3 * sin(t * 7.0), 0.0)
		HState.STUNNED:
			arm_l = Vector3(-2.6, 0.0, -0.4)  # hands over the face
			arm_r = Vector3(-2.6, 0.0, 0.4)
			lean = -0.2
			head_t = Vector3(0.5, 0.0, 0.6 * sin(t * 11.0))
		HState.INVESTIGATE:
			head_t.y += 0.6 * sin(t * 2.2)
		HState.SWEEP:
			# The body turns; the head leads it a little and keeps its tilt.
			head_t = Vector3(0.05, 0.25 * sin(t * 1.7), 0.45)
			arm_l = Vector3(0.1, 0.0, -0.15)
			arm_r = Vector3(0.1, 0.0, 0.15)
	var k := 1.0 - exp(-14.0 * delta)
	_hips.rotation.x = lerpf(_hips.rotation.x, -lean, k)
	_hips.position.y = lerpf(_hips.position.y, 0.95 - (0.08 if chase else 0.0), k)
	_thigh_l.rotation.x = lerpf(_thigh_l.rotation.x, hip_l, k)
	_thigh_r.rotation.x = lerpf(_thigh_r.rotation.x, hip_r, k)
	_arm_l.rotation = _arm_l.rotation.lerp(arm_l + Vector3(0.0, 0.0, -0.1), k)
	_arm_r.rotation = _arm_r.rotation.lerp(arm_r + Vector3(0.0, 0.0, 0.1), k)
	_head.rotation = _head.rotation.lerp(head_t, k)
	# Footsteps (quick and wrong while chasing), and a caption now and then while it wanders.
	if walking and _model.visible:
		_caption_t -= delta
		var me := Net.get_local_player()
		if me != null and me.global_position.distance_to(global_position) < 16.0:
			if _caption_t <= 0.0:
				_caption_t = 5.0 if chase else 8.0
				Sfx.caption(self, "running footsteps" if chase else "footsteps, somewhere", chest_point())
			if fmod(_phase, PI) < delta * (_vis_speed * 3.6 + 0.5):
				Sfx.play_at(self, "step", global_position, -6.0 if chase else -16.0, 1.1 if chase else 0.9, 22.0)
