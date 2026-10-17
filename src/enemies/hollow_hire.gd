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
## They walk the route: every floor's first Hire keeps to the rooms round the way up, the rest
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
const GRAB_REACH: float = 0.85  # m in front of it a caught player is held
const GRAB_LIFT: float = 0.12  # m off the floor: just onto its toes, its face a little above yours
# The catch, seconds into the hold (every peer plays it from when it sees the grab start):
const SLASHES: Array[float] = [0.55, 1.1, 1.65]  # each: the claw goes up, then rakes across
const SLASH_WINDUP: float = 0.26
const SLASH_SWIPE: float = 0.12
const BITE_OPEN: float = 2.15  # the jaw drops, the head draws back
const BITE_LUNGE: float = 2.85  # the head comes for your face
const BITE_SNAP: float = 3.3  # and closes
const SCREAM_NEAR: float = 5.5  # m: chasing you, it screams once as it closes this near
const IDLE_CALL_EVERY: Vector2 = Vector2(9.0, 20.0)  # s between its gurgles while it walks the floor
const IDLE_CALL_REACH: float = 20.0  # m
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
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Visuals.
var _model: Node3D
var _hips: Node3D
var _head: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _thigh_l: Node3D
var _thigh_r: Node3D
var _jaw: Node3D
var _catch_t: float = 0.0  # every peer: seconds into the catch it is playing
var _catch_prev: float = 0.0
var _screamed_near: bool = false  # every peer: this chase has had its close-in scream
var _idle_call_t: float = randf_range(4.0, 12.0)  # every peer: its own ambient timer
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
	_model.rotation.y = synced_yaw
	if multiplayer.is_server():
		_pick_wander()


# --- Visuals -----------------------------------------------------------------------------------

func _build_visuals() -> void:
	var body := HireBody.new()
	body.name = "Model"
	add_child(body)
	body.build()
	_model = body
	_hips = body.hips
	_head = body.head
	_arm_l = body.arm_l
	_arm_r = body.arm_r
	_thigh_l = body.thigh_l
	_thigh_r = body.thigh_r
	_jaw = body.jaw
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


## Where its face is right now (the caught player's view locks on it).
func face_point() -> Vector3:
	# During the bite, the mouth: that's what is coming for you.
	if hstate == HState.GRAB and _catch_t >= BITE_OPEN:
		return _head.to_global(Vector3(0.0, 0.15, -0.12))
	return _head.to_global(Vector3(0.0, 0.25, -0.1))


## The catch, as a pose at _catch_t seconds into it: [left arm, right arm, head, lean, jaw, head z].
## The left hand has you by the throat the whole time; the right claw goes up and rakes across you
## three times; then the jaw drops open far too wide, the head draws back, and comes for your face.
func _catch_pose(t: float) -> Array:
	var g := _catch_t
	var arm_l := Vector3(2.15 + 0.05 * sin(t * 17.0), 0.0, -0.12)  # by the throat, squeezing
	var arm_r := Vector3(1.3, 0.0, 0.45)
	var head := Vector3(0.3 + 0.06 * sin(t * 11.0), 0.0, 0.25 * sin(t * 3.0))  # tipped up, studying your face
	var lean := 0.15
	var jaw := -0.2 - 0.1 * sin(t * 9.0)
	var head_z := 0.0
	if g < 0.35:
		arm_l = Vector3(2.15 * g / 0.35, 0.0, -0.12)
	for at in SLASHES:
		var u := g - at
		if u >= 0.0 and u < SLASH_WINDUP:
			arm_r = Vector3(3.0, 0.0, 0.55)  # up and out, the claws over its head
			jaw = -0.5
		elif u >= SLASH_WINDUP and u < SLASH_WINDUP + SLASH_SWIPE + 0.1:
			arm_r = Vector3(1.1, 0.0, -0.65)  # raked down and across you
			lean = 0.4
	if g >= BITE_OPEN and g < BITE_LUNGE:
		arm_r = Vector3(2.3, 0.0, 0.2)  # both hands on you now
		head = Vector3(0.75, 0.0, 0.0)  # head back
		jaw = -1.15  # the jaw hanging wide
		lean = 0.15
	elif g >= BITE_LUNGE:
		arm_r = Vector3(2.3, 0.0, 0.2)
		head = Vector3(0.35, 0.0, 0.0)  # level: the open mouth comes at you, not the top of its head
		head_z = -0.2  # the face comes into yours
		lean = 0.35
		jaw = -1.15 if g < BITE_SNAP else 0.05  # ...and snaps shut
	return [arm_l, arm_r, head, lean, jaw, head_z]


## The catch's hits, on every peer: each rake, the jaw dropping, the bite. Whoever is caught gets
## them in the face: the sound, the screen flash and shake.
func _tick_catch_events() -> void:
	var a := _catch_prev
	var b := _catch_t
	_catch_prev = b
	var victim := Net.find_player(grab_peer)
	var mine := victim != null and victim.is_local
	var at := victim.global_position + Vector3(0.0, 1.3, 0.0) if victim != null else chest_point()
	for s in SLASHES:
		var hit := s + SLASH_WINDUP + SLASH_SWIPE * 0.5
		if a < s and b >= s:
			_fx_local("hire_gurgle", at, -2.0, 1.3)
		if a < hit and b >= hit:
			Sfx.play_at(self, "scrape", at, 2.0, 0.55, 22.0)
			_blood(at)
			if mine:
				Sfx.play(self, "stinger", -4.0, 1.4)
				ScareDirector.call("_flash", 0.4)
				ScreenFx.jolt(0.22)
				victim.add_shake(0.7)
	if a < BITE_OPEN and b >= BITE_OPEN:
		(_model as HireBody).hat.visible = false  # knocked off as the head goes back
		Sfx.play_at(self, "roar", head_point(), 6.0, 1.0, 26.0)
		if mine:
			victim.add_shake(0.4)
	if a < BITE_SNAP and b >= BITE_SNAP:
		Sfx.play_at(self, "thump", at, 4.0, 0.5, 22.0)
		_blood(at + Vector3(0.0, 0.3, 0.0))
		if mine:
			Sfx.play(self, "stinger", 4.0, 0.7)
			ScareDirector.call("_flash", 0.9)
			ScreenFx.jolt(0.6)
			victim.add_shake(1.2)


func _fx_local(bank: String, at: Vector3, db: float, pitch: float) -> void:
	Sfx.play_at(self, bank, at, db, pitch, 22.0)


## A burst of dark red, local to every peer (it's only spray: nothing stays on the floor).
func _blood(at: Vector3) -> void:
	if not is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 26
	p.lifetime = 0.7
	p.explosiveness = 0.95
	p.direction = Vector3(0.0, 0.4, 1.0)
	p.spread = 70.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 4.0
	p.gravity = Vector3(0.0, -9.0, 0.0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var m := SphereMesh.new()
	m.radius = 0.018
	m.height = 0.036
	m.radial_segments = 6
	m.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.01, 0.02)
	mat.roughness = 0.2
	m.material = mat
	p.mesh = m
	get_tree().current_scene.add_child(p)
	p.global_position = at
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)


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
		_fx("hire_gurgle", 4.0, _rng.randf_range(0.9, 1.0))
		_rpc_seen.rpc()
		if level != null:
			level.hire_callout(self, p)


@rpc("authority", "call_local", "reliable")
func _rpc_seen() -> void:
	Sfx.play_at(self, "scream", head_point(), 4.0, randf_range(0.95, 1.08), 50.0)
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
	_fx("hire_gurgle", 2.0, _rng.randf_range(0.82, 0.92))
	_rpc_answered.rpc()


@rpc("authority", "call_local", "reliable")
func _rpc_answered() -> void:
	Sfx.play_at(self, "scream", head_point(), -2.0, randf_range(0.85, 0.95), 45.0)
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
	if seen and _has_clear_floor_line(goal):
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
	_fx("hire_gurgle", 6.0, 0.8)
	GameState.post_message("IT HAS %s. Everyone beside them: HOLD CTRL. Or a light in its face, or shoot it." % p.display_name.to_upper(), 4.0)


func _tick_grab(delta: float) -> void:
	if _grabbed == null or not is_instance_valid(_grabbed) or not _grabbed.is_grabbed():
		release(false)
		return
	_t += delta
	# Held out at arm's length by the throat, lifted off its feet.
	var lift := GRAB_LIFT * smoothstep(0.0, 0.35, _t)
	_grabbed.global_position = global_position + facing() * GRAB_REACH + Vector3(0.0, 0.05 + lift, 0.0)
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
	_fx("hire_gurgle", 0.0, 1.4)


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
	_fx("hire_gurgle", 2.0, 0.6)
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


## Walks the route one cell centre at a time. Returns true when there is nothing left to walk.
func _follow_route(speed: float, delta: float) -> bool:
	if _route.is_empty():
		if hstate == HState.INVESTIGATE or hstate == HState.CHASE:
			if _flat_dist(_goal) > 0.4:
				_move_toward(_goal, speed, delta)
				return false
		return true
	var next := level.cell_center(floor_index, _route[0]) + Vector3(0.0, 0.0, 0.0)
	_move_toward(next, speed, delta)
	if _flat_dist(next) < 0.35:
		_route.pop_front()
	return false


func _move_toward(target: Vector3, speed: float, delta: float) -> void:
	var to := target - global_position
	to.y = 0.0
	if to.length() < 0.02:
		return
	_face(target, delta)
	var step := to.normalized() * minf(speed * delta, to.length())
	global_position += step
	global_position.y = floor_y


## Straight to the target without a wall in the way, at knee height (desks don't count).
func _has_clear_floor_line(target: Vector3) -> bool:
	var from := global_position + Vector3(0.0, 1.2, 0.0)
	var to := Vector3(target.x, global_position.y + 1.2, target.z)
	var q := PhysicsRayQueryParameters3D.create(from, to, ChainBody.LAYER_WORLD)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


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
	_idle_call_t -= delta
	if _idle_call_t <= 0.0:
		_idle_call_t = randf_range(IDLE_CALL_EVERY.x, IDLE_CALL_EVERY.y)
		if hstate == HState.WANDER or hstate == HState.SWEEP or hstate == HState.INVESTIGATE:
			Sfx.idle_call(self, "hire_gurgle", head_point(), -9.0, randf_range(0.75, 0.95), IDLE_CALL_REACH, "a wet gurgle, somewhere")
	var moved := global_position.distance_to(_last_pos) / maxf(delta, 0.0001)
	_last_pos = global_position
	_vis_speed = lerpf(_vis_speed, moved, clampf(delta * 8.0, 0.0, 1.0))
	if not multiplayer.is_server():
		_model.rotation.y = lerp_angle(_model.rotation.y, synced_yaw, clampf(delta * 12.0, 0.0, 1.0))
	# Screams, on every peer from the replicated state: once as it closes on whoever it's after,
	# and in your face when it has you.
	if hstate == HState.CHASE and not _screamed_near:
		var prey := Net.find_player(hunt_peer)
		if prey != null and prey.global_position.distance_to(global_position) < SCREAM_NEAR:
			_screamed_near = true
			Sfx.play_at(self, "scream", head_point(), 7.0, randf_range(1.0, 1.12), 45.0)
			if prey.is_local:
				prey.add_shake(0.5)
	elif hstate != HState.CHASE:
		_screamed_near = false
	if hstate != _shown_state and hstate == HState.GRAB:
		Sfx.play_at(self, "scream", head_point(), 8.0, 1.15, 40.0)
		var caught := Net.find_player(grab_peer)
		if caught != null and caught.is_local:
			Sfx.play(self, "scream", 0.0, 1.15)  # inside your head as well
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
	var jaw_t := -0.04 - 0.03 * maxf(0.0, sin(t * 0.9))  # never quite closed
	var head_z := 0.0
	if hstate == HState.GRAB:
		_catch_t += delta
		_tick_catch_events()
	else:
		_catch_t = 0.0
		(_model as HireBody).hat.visible = true
		_catch_prev = 0.0
	var cam := get_viewport().get_camera_3d()
	if cam != null and _model.visible and hstate != HState.DEAD:
		var local := _model.to_local(cam.global_position) - _hips.position - _head.position
		if local.length() < 16.0:
			head_t.y = clampf(atan2(-local.x, -local.z), -1.2, 1.2)
	match hstate:
		HState.CHASE:
			# Arms out ahead (positive x swings an arm forward), jaw hanging open.
			arm_l = Vector3(1.9 + 0.2 * s, 0.0, -0.3)
			arm_r = Vector3(1.9 - 0.2 * s, 0.0, 0.3)
			head_t = Vector3(-0.3, head_t.y, 0.5 * sin(t * 9.0))
			jaw_t = -0.45 - 0.15 * sin(t * 13.0)
		HState.GRAB:
			var pose := _catch_pose(t)
			arm_l = pose[0]
			arm_r = pose[1]
			head_t = pose[2]
			lean = pose[3]
			jaw_t = pose[4]
			head_z = pose[5]
		HState.STUNNED:
			arm_l = Vector3(2.6, 0.0, -0.4)  # hands over the face
			arm_r = Vector3(2.6, 0.0, 0.4)
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
	var kf := 1.0 - exp(-24.0 * delta)  # the jaw and the bite are quick
	_jaw.rotation.x = lerpf(_jaw.rotation.x, jaw_t, kf)
	_head.position.z = lerpf(_head.position.z, head_z, kf)
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
