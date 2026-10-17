class_name PappyPepperoni
extends Node3D
## Pappy Pepperoni: the pizzeria's 2.6 m chef animatronic. Pepperoni eyes, human teeth, a
## mustache you could hang a coat on. Guns do nothing. He is never seen moving: every Step
## (14 s, less with more players) he is simply one node closer, but ONLY if nobody is looking at
## him and no live camera shows his node. Someone staring at him pins him. When he reaches the
## Line he lunges and takes the nearest player (a Layoff). A closed shutter stops him: three
## bangs, then he goes back to his end of the floor, and the holder has one Step to catch up.
## Counters: eyes on him, the cameras, the shutters, an air horn (stuns him), a party popper
## (pushes him back a node), a flashlight in his face (drops whoever he's holding).
## Server simulates; position, node and state are replicated; visuals run on every peer.

## RUSH is the one time he is seen moving: a visible charge at walking-plus speed, eyes or no
## eyes. It happens when a shutter's holder lets go while he's banging on it, and for as long as
## the power is out. The answer is running, not staring.
enum PState { DORMANT, ROAM, BANGING, LUNGE, GRAB, STUNNED, TRAVEL, RUSH }

const STEP_BASE: float = 14.0  # s between moves for 1-2 players
const STEP_PER_EXTRA_PLAYER: float = 1.0
const STEP_MIN: float = 8.0
const BLACKOUT_STEP: float = 3.0  # s between moves with the power out: nothing stops him
const DORMANT_SECONDS: float = 45.0  # he wakes at the first camera check, or after this
const TELL_LEAD: float = 2.2  # s before a Step the servo whine starts
const VIEW_HALF_ANGLE: float = 0.95  # rad: how far off-center you can hold him and still "see" him
const VIEW_RANGE: float = 34.0
const LUNGE_RANGE: float = 8.0
const LUNGE_TIME: float = 0.8
const GRAB_TIME: float = 2.2  # s teammates have to get him off you
const BANG_INTERVAL: float = 1.0
const BANGS: int = 3
const RETREAT_GRACE: float = 4.0  # extra seconds after a shutter sends him home
const TRAVEL_TIME: float = 9.0  # s to appear on a new floor
const NOISE_SKIP: float = 70.0  # a noise this loud near him skips his timer
const NOISE_RANGE: float = 22.0
const BURN_TO_RELEASE: float = 1.2  # s of flashlight in his face to make him drop someone
const BURN_RANGE: float = 16.0
const BURN_ANGLE: float = 0.5  # rad: the beam's whole cone counts
const BURN_DECAY: float = 0.25  # per second while the beam is off him
const RUSH_SPEED: float = 2.6  # m/s: the one time he is seen walking (blackout, or after a shutter)
const RUSH_SECONDS: float = 7.0
const RUSH_CHANCE: float = 0.45  # after three bangs and the holder letting go
const QUIET_STEP_CHANCE: float = 0.3  # a Step with no servo tell first
const CHEST_HEIGHT: float = 1.5
const HEAD_HEIGHT: float = 2.35

var level: Pizzeria
var floor_index: int = 0  # replicated
var node_index: int = 0  # replicated
var pstate: int = PState.DORMANT  # replicated
var synced_position: Vector3 = Vector3.ZERO  # replicated
var synced_yaw: float = 0.0  # replicated
var watched: bool = false  # replicated: someone (or a camera) has him right now
var hunt_peer: int = 0  # replicated: who he's going for
var grab_peer: int = 0  # replicated
var step_fraction: float = 0.0  # replicated: 0..1 of the way to his next Step (HUD)
var burn_fraction: float = 0.0  # replicated: 0..1 of the light he has taken (HUD feedback)
var debug_frozen: bool = false  # tests
var steps_taken: int = 0  # server stat
var _hiss_t: float = 0.0
var _rush_t: float = 0.0
var _quiet_step: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _step_t: float = 0.0
var _dormant_t: float = DORMANT_SECONDS
var _told: bool = false
var _bang_t: float = 0.0
var _bangs_done: int = 0
var _lunge_t: float = 0.0
var _lunge_from: Vector3 = Vector3.ZERO
var _grab_t: float = 0.0
var _stun_t: float = 0.0
var _travel_t: float = 0.0
var _travel_to: int = 0
var _noise_cd: float = 0.0
var _burn: float = 0.0
var _grabbed: Player = null
var _bang_shutter: Shutter = null
var _last_node_pos: Vector3 = Vector3.ZERO

# Visuals.
var _model: Node3D
var _head: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _eyes: Array[MeshInstance3D] = []
var _sparks: GPUParticles3D
var _shown_state: int = -1
var _shown_grab: int = 0
var _caption_t: float = 0.0
var _creak_t: float = 0.0
var _stomp_t: float = 0.0


func _enter_tree() -> void:
	if has_node("Sync"):
		return
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	# Everything ALWAYS, like the Custodian: a late joiner then sees him where he is at once.
	for prop in ["synced_position", "synced_yaw", "step_fraction", "burn_fraction", "floor_index", "node_index", "pstate", "watched", "hunt_peer", "grab_peer"]:
		var path := NodePath(".:" + prop)
		cfg.add_property(path)
		cfg.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	sync.replication_config = cfg
	add_child(sync)


func _ready() -> void:
	add_to_group("monster")
	add_to_group("pappy")
	_rng.seed = 2207
	_build_visuals()
	if multiplayer.is_server():
		_place_at(0, level.home_node(0))
	global_position = synced_position
	_model.rotation.y = synced_yaw


# --- Visuals ----------------------------------------------------------------------------------------

func _build_visuals() -> void:
	var body := PappyBody.new()
	body.name = "Model"
	add_child(body)
	body.build()
	_model = body
	_head = body.head
	_arm_l = body.arm_l
	_arm_r = body.arm_r
	_eyes = body.eyes
	var eye_glow := OmniLight3D.new()
	eye_glow.light_color = Color(1.0, 0.15, 0.05)
	eye_glow.light_energy = 0.8
	eye_glow.omni_range = 3.0
	eye_glow.position = Vector3(0.0, 0.4, -0.5)
	_head.add_child(eye_glow)
	# Name tag.
	var tag := Label3D.new()
	tag.text = "PAPPY"
	tag.font_size = 30
	tag.pixel_size = 0.004
	tag.modulate = Color(1.0, 0.9, 0.6)
	tag.outline_size = 6
	tag.position = Vector3(0.25, 1.55, -0.62)
	tag.rotation = Vector3(0.0, PI, 0.0)
	_model.add_child(tag)
	_sparks = GPUParticles3D.new()
	_sparks.amount = 40
	_sparks.lifetime = 0.6
	_sparks.emitting = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0.0, 1.0, 0.0)
	pm.spread = 70.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 5.0
	pm.gravity = Vector3(0.0, -9.0, 0.0)
	pm.color = Color(1.0, 0.8, 0.3)
	_sparks.process_material = pm
	var q := SphereMesh.new()
	q.radial_segments = 6  # a spark
	q.rings = 3
	q.radius = 0.02
	q.height = 0.04
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.vertex_color_use_as_albedo = true
	qm.albedo_color = Color(3.0, 2.0, 0.6)
	q.material = qm
	_sparks.draw_pass_1 = q
	_sparks.position = Vector3(0.0, 1.9, 0.0)
	_model.add_child(_sparks)
	# Hitbox so the pistol can clang off him (it does nothing else).
	var hb := Area3D.new()
	hb.collision_layer = ChainBody.LAYER_MONSTER
	hb.collision_mask = 0
	hb.monitoring = false
	var hs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.65
	cap.height = 2.6
	hs.shape = cap
	hs.position = Vector3(0.0, 1.3, 0.0)
	hb.add_child(hs)
	add_child(hb)


func chest_point() -> Vector3:
	return global_position + Vector3(0.0, CHEST_HEIGHT, 0.0)


func head_point() -> Vector3:
	return global_position + Vector3(0.0, HEAD_HEIGHT, 0.0)


func is_hunting() -> bool:
	return pstate == PState.LUNGE or pstate == PState.GRAB or pstate == PState.RUSH


func is_active() -> bool:
	return pstate != PState.DORMANT and pstate != PState.TRAVEL


func node_name() -> String:
	return level.node_name(floor_index, node_index)


func step_length() -> float:
	if level.blackout():
		return BLACKOUT_STEP
	var n := Net.get_players().size()
	return maxf(STEP_MIN, STEP_BASE - STEP_PER_EXTRA_PLAYER * float(maxi(0, n - 2)))


# --- Server -----------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		_server_tick(delta)
	else:
		if pstate == PState.LUNGE or pstate == PState.GRAB or pstate == PState.RUSH:
			global_position = global_position.lerp(synced_position, clampf(delta * 14.0, 0.0, 1.0))
		else:
			global_position = synced_position
	_update_visuals(delta)


func _server_tick(delta: float) -> void:
	if debug_frozen:
		return
	var players := Net.get_players()
	if players.is_empty():
		return
	_noise_cd = maxf(0.0, _noise_cd - delta)
	match pstate:
		PState.DORMANT:
			_tick_dormant(delta)
		PState.TRAVEL:
			_travel_t -= delta
			if _travel_t <= 0.0:
				_place_at(_travel_to, level.home_node(_travel_to))
				pstate = PState.ROAM
				_step_t = 0.0
				_told = false
				_fx("thump", -4.0, 0.6)
		PState.ROAM:
			_tick_roam(delta)
		PState.BANGING:
			_tick_banging(delta)
		PState.LUNGE:
			_tick_lunge(delta)
		PState.GRAB:
			_tick_grab(delta)
		PState.STUNNED:
			_stun_t -= delta
			if _stun_t <= 0.0:
				pstate = PState.ROAM
				_step_t = 0.0
				_told = false
		PState.RUSH:
			_tick_rush(delta)
	step_fraction = clampf(_step_t / step_length(), 0.0, 1.0) if pstate == PState.ROAM else 0.0
	if pstate != PState.GRAB:
		burn_fraction = 0.0
	synced_position = global_position
	synced_yaw = _model.rotation.y


func _tick_dormant(delta: float) -> void:
	if not level.anyone_here():
		return  # the night shift hasn't clocked in yet
	_dormant_t -= delta
	var awake := _dormant_t <= 0.0
	for d in level.desks:
		if d.is_live():
			awake = true
	if awake:
		pstate = PState.ROAM
		_step_t = 0.0
		_told = false
		level.set_jukebox(true)


func _tick_roam(delta: float) -> void:
	var target_floor := level.line_floor()
	if target_floor != floor_index:
		pstate = PState.TRAVEL
		_travel_to = target_floor
		_travel_t = TRAVEL_TIME
		watched = false
		_fx("servo", -6.0, 0.6)
		return
	watched = _is_observed()
	if level.blackout():
		_start_rush(INF)  # nothing stops him in the dark: he walks, and keeps walking
		return
	if watched:
		return  # pinned: eyes on him, or a camera
	# Loud things on his floor skip his timer.
	if _noise_cd <= 0.0 and _loud_nearby():
		_noise_cd = 3.0
		_step_t = maxf(_step_t, step_length() - 0.3)
	var length := step_length()
	if _step_t <= 0.0 and not _told:
		_quiet_step = _rng.randf() < QUIET_STEP_CHANCE  # some Steps come with no warning at all
	_step_t += delta
	# Anticipation: halfway through a Step, something clatters near him (a pan, a chair).
	if _step_t >= length * 0.5 and _step_t - delta < length * 0.5 and _rng.randf() < 0.6:
		_fx("clink", -4.0, _rng.randf_range(0.4, 0.7))
	if not _told and _step_t >= length - TELL_LEAD:
		_told = true
		if not _quiet_step:
			_fx("servo", 0.0, 1.0)
	if _step_t < length:
		return
	_step_t = 0.0
	_told = false
	_do_step()


# --- The Rush: the one time he walks ------------------------------------------------------------

func _start_rush(seconds: float) -> void:
	if pstate == PState.RUSH:
		_rush_t = seconds
		return
	pstate = PState.RUSH
	_rush_t = seconds
	_bang_shutter = null
	hunt_peer = 0
	level.set_jukebox(false)
	_fx("servo", 4.0, 1.5)
	_fx("growl", 2.0, 0.5)
	GameState.post_message("HE'S COMING. RUN. (A Break Room or the freezer is safe.)", 3.0)


## Walks node to node toward the nearest player, through open doors only, and lunges when close.
func _tick_rush(delta: float) -> void:
	if not level.blackout():
		if is_inf(_rush_t):
			_rush_t = 3.0  # the generator came back: a few more steps and he's on his timer again
		_rush_t -= delta
	var target_floor := level.line_floor()
	if target_floor != floor_index:
		_abort_hunt()
		return
	var nearest := _nearest_player()
	if nearest == null or (_rush_t <= 0.0 and not level.blackout()):
		_end_rush()
		return
	var goal := level.nearest_node(floor_index, nearest.global_position)
	var here := level.nearest_node(floor_index, global_position)
	node_index = here
	var dest := nearest.global_position
	if goal != here:
		var next := level.next_node(floor_index, here, goal)
		if next < 0:
			_end_rush()
			return
		var shutter := level.shutter_between(floor_index, here, next)
		if shutter != null and shutter.closed:
			pstate = PState.BANGING  # he met a held shutter at a run: the usual three bangs
			_bang_shutter = shutter
			_bangs_done = 0
			_bang_t = 0.2
			_teleport(shutter.global_position - shutter.normal * 1.2)
			_face(shutter.global_position + shutter.normal * 3.0)
			return
		dest = level.node_position(floor_index, next)
	if level.is_safe_spot(nearest.global_position) and goal == here:
		# They made it somewhere he won't go: he stands at the door and gives up when the time runs out.
		_face(nearest.global_position)
		if level.blackout():
			return
		_rush_t = minf(_rush_t, 2.0)
		return
	var to := dest - global_position
	to.y = 0.0
	if to.length() > 0.05:
		var step := to.normalized() * minf(RUSH_SPEED * delta, to.length())
		global_position += step
		global_position.y = level.node_position(floor_index, here).y
		synced_position = global_position
		_face(dest)
	hunt_peer = nearest.peer_id
	if _can_lunge_at(nearest) and nearest.global_position.distance_to(global_position) < 3.0:
		_start_lunge(nearest)


func _end_rush() -> void:
	pstate = PState.ROAM
	hunt_peer = 0
	_step_t = 0.0
	_told = false
	node_index = level.nearest_node(floor_index, global_position)
	_teleport(level.node_position(floor_index, node_index))
	level.set_jukebox(true)
	GameState.post_message("He stopped. He's back on his timer.", 2.5)


## One Step: toward the Line, through a shutter if it's open, into a lunge if someone is close.
func _do_step() -> void:
	var nearest := _nearest_player()
	if nearest == null:
		return
	if _can_lunge_at(nearest):
		_start_lunge(nearest)
		return
	var goal := level.nearest_node(floor_index, nearest.global_position)
	if goal == node_index:
		var toward := nearest.global_position - global_position
		toward.y = 0.0
		if _has_line_to(nearest):
			# Same room but out of reach: step up next to them.
			if toward.length() > LUNGE_RANGE * 0.6:
				_teleport(global_position + toward.normalized() * (toward.length() - LUNGE_RANGE * 0.5))
				_face(nearest.global_position)
				_fx("thump", -2.0, 0.55)
				steps_taken += 1
			return
		# A wall between us: they're really in the next room. Go round by the graph instead of
		# standing at the wall forever.
		goal = level.nearest_node(floor_index, nearest.global_position, node_index)
	var next := level.next_node(floor_index, node_index, goal)
	if next < 0 or next == node_index:
		return
	var shutter := level.shutter_between(floor_index, node_index, next)
	if shutter != null and shutter.closed:
		pstate = PState.BANGING
		_bang_shutter = shutter
		_bangs_done = 0
		_bang_t = 0.2
		_teleport(shutter.global_position - shutter.normal * 1.2)
		_face(shutter.global_position + shutter.normal * 3.0)
		level.set_jukebox(false)
		return
	_place_at(floor_index, next)
	_face(nearest.global_position)
	steps_taken += 1
	_fx("thump", -3.0, 0.5)
	if level.node_adjacent_to(floor_index, next, goal) or next == goal:
		level.set_jukebox(false)  # the tell: he's at the door


func _tick_banging(delta: float) -> void:
	_bang_t -= delta
	if _bang_t > 0.0:
		return
	if _bang_shutter == null or not _bang_shutter.closed:
		# They let go mid-bang: through he comes, at a run. Hold it for all three or don't hold it.
		_start_rush(RUSH_SECONDS)
		return
	_bangs_done += 1
	_bang_t = BANG_INTERVAL
	_rpc_bang.rpc(_bang_shutter.get_path())
	for p in Net.get_players():
		if p.global_position.distance_to(_bang_shutter.global_position) < 12.0:
			p.add_noise(40.0)
	if _bangs_done >= BANGS:
		_retreat_home()


func _retreat_home() -> void:
	_place_at(floor_index, level.home_node(floor_index))
	pstate = PState.ROAM
	_step_t = -RETREAT_GRACE
	_told = false
	_bang_shutter = null
	level.set_jukebox(true)
	GameState.post_message("He gave up on the shutter. He'll be back. MOVE.", 3.5)


func _can_lunge_at(p: Player) -> bool:
	if p.state != Player.State.NORMAL:
		return false
	var d := p.global_position.distance_to(global_position)
	if d > LUNGE_RANGE or absf(p.global_position.y - global_position.y) > 2.5:
		return false
	if level.is_safe_spot(p.global_position):
		return false
	return _has_line_to(p)


func _has_line_to(p: Player) -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(chest_point(), p.global_position + Vector3.UP, ChainBody.LAYER_WORLD)
	return space.intersect_ray(q).is_empty()


func _start_lunge(p: Player) -> void:
	pstate = PState.LUNGE
	hunt_peer = p.peer_id
	_lunge_t = 0.0
	_lunge_from = global_position
	_grabbed = p
	_face(p.global_position)
	level.set_jukebox(false)
	_fx("growl", 3.0, 0.55)
	_fx("servo", 2.0, 1.6)


func _tick_lunge(delta: float) -> void:
	_lunge_t += delta
	if _grabbed == null or not is_instance_valid(_grabbed) or _grabbed.state != Player.State.NORMAL and not _grabbed.is_grabbed():
		_abort_hunt()
		return
	var goal := _grabbed.global_position
	var to := goal - _lunge_from
	to.y = 0.0
	var stop := maxf(0.0, to.length() - 1.1)
	var u := clampf(_lunge_t / LUNGE_TIME, 0.0, 1.0)
	var eased := u * u * (3.0 - 2.0 * u)
	global_position = _lunge_from + (to.normalized() * stop * eased if to.length() > 0.01 else Vector3.ZERO)
	global_position.y = goal.y
	_face(goal)
	if u >= 1.0:
		if _grabbed.global_position.distance_to(global_position) > 2.6 or level.is_safe_spot(_grabbed.global_position):
			_abort_hunt()  # they got away (or into the freezer)
			return
		pstate = PState.GRAB
		grab_peer = _grabbed.peer_id
		_grab_t = 0.0
		_burn = 0.0
		_grabbed.grab_start(self)
		_fx("growl", 6.0, 0.7)
		GameState.post_message("HE HAS %s. Air horn, party popper or a flashlight in his face. NOW." % _grabbed.display_name.to_upper(), 4.0)


func _tick_grab(delta: float) -> void:
	if _grabbed == null or not is_instance_valid(_grabbed) or not _grabbed.is_grabbed():
		_abort_hunt()
		return
	_grab_t += delta
	_grabbed.global_position = global_position + Vector3(-sin(_model.rotation.y), 0.0, -cos(_model.rotation.y)) * 0.9 + Vector3(0.0, 0.2 + 0.5 * clampf(_grab_t / GRAB_TIME, 0.0, 1.0), 0.0)
	_grabbed.synced_position = _grabbed.global_position
	if _tick_burn(delta):
		GameState.post_message("The light in his face. He dropped them. Go!", 3.0)
		release(false)
		stun(1.5)
		return
	if _grab_t >= GRAB_TIME:
		var victim := _grabbed.display_name
		release(true)
		var lvl := get_tree().get_first_node_in_group("level")
		if lvl != null and lvl.has_method("request_layoff"):
			lvl.call("request_layoff", "%s was taken by Pappy Pepperoni." % victim)


func _abort_hunt() -> void:
	_grabbed = null
	hunt_peer = 0
	grab_peer = 0
	pstate = PState.ROAM
	_step_t = 0.0
	_told = false
	node_index = level.nearest_node(floor_index, global_position)
	_teleport(level.node_position(floor_index, node_index))


## Server. Lets go of whoever he holds. killed: they were taken.
func release(killed: bool) -> void:
	var victim := _grabbed
	_grabbed = null
	grab_peer = 0
	hunt_peer = 0
	if victim != null and is_instance_valid(victim) and victim.is_grabbed():
		victim.grab_end()
		if not killed:
			victim.apply_knockback(Vector3(-sin(_model.rotation.y), 0.0, -cos(_model.rotation.y)) * 5.0 + Vector3.UP * 3.0)
	if pstate == PState.GRAB or pstate == PState.LUNGE:
		pstate = PState.ROAM
		_step_t = 0.0
		_told = false
		node_index = level.nearest_node(floor_index, global_position)
		_teleport(level.node_position(floor_index, node_index))


## Server: air horn, blast. He locks up for a few seconds and drops whoever he holds.
func stun(seconds: float) -> void:
	if pstate == PState.DORMANT or pstate == PState.TRAVEL:
		return
	if _grabbed != null:
		release(false)
	pstate = PState.STUNNED
	_stun_t = maxf(_stun_t, seconds)
	_bang_shutter = null
	_rpc_stun_fx.rpc()


## Server: party popper. One node back toward his end of the floor, and his timer restarts.
func push_back() -> void:
	if pstate == PState.DORMANT or pstate == PState.TRAVEL:
		return
	if _grabbed != null:
		release(false)
	var home := level.home_node(floor_index)
	var back := level.next_node(floor_index, node_index, home)
	if back >= 0 and back != node_index:
		_place_at(floor_index, back)
	elif node_index == home:
		_teleport(level.node_position(floor_index, home))
	pstate = PState.ROAM
	_step_t = -2.0
	_told = false
	_bang_shutter = null
	_fx("thump", -2.0, 0.5)


func blast() -> void:
	stun(4.0)


## Pistol: a clang, and he knows where you are.
func take_hit() -> void:
	_fx("clink", 2.0, 0.5)
	if pstate == PState.ROAM:
		_step_t = maxf(_step_t, step_length() - 0.5)


## Tests: put him at a node, roaming, with a fresh timer.
func debug_reset(floor_i: int, node_i: int) -> void:
	if _grabbed != null:
		release(false)
	_place_at(floor_i, node_i)
	pstate = PState.ROAM
	_step_t = 0.0
	_told = false
	_stun_t = 0.0
	_bang_shutter = null
	hunt_peer = 0
	grab_peer = 0
	_rush_t = 0.0
	burn_fraction = 0.0


func debug_force_step() -> void:
	_step_t = step_length()


func debug_wake() -> void:
	_dormant_t = 0.0


func _place_at(floor_i: int, node_i: int) -> void:
	floor_index = floor_i
	node_index = node_i
	_teleport(level.node_position(floor_i, node_i))
	var p := _nearest_player()
	if p != null:
		_face(p.global_position)  # he is always facing you when you find him


func _teleport(p: Vector3) -> void:
	global_position = p
	synced_position = p
	_last_node_pos = p


func _face(target: Vector3) -> void:
	var d := target - global_position
	if Vector2(d.x, d.z).length() > 0.05:
		_model.rotation.y = atan2(-d.x, -d.z)
		synced_yaw = _model.rotation.y


func _nearest_player() -> Player:
	var best: Player = null
	var best_d := INF
	for p in Net.get_players():
		if p.state == Player.State.GRABBED:
			continue
		var d := p.global_position.distance_to(global_position)
		if absf(p.global_position.y - global_position.y) > 3.5:
			d += 100.0  # another floor: last resort
		if d < best_d:
			best_d = d
			best = p
	return best


## True while any player has line of sight on him inside their view, or a live camera shows
## his node. In a blackout nothing counts.
func _is_observed() -> bool:
	if level.blackout():
		return false
	var space := get_world_3d().direct_space_state
	var chest := chest_point()
	var head := head_point()
	for p in Net.get_players():
		if p.state != Player.State.NORMAL:
			continue
		var eye := p.eye_position()
		var to := chest - eye
		var d := to.length()
		if d > VIEW_RANGE or d < 0.3:
			continue
		if p.aim_direction().angle_to(to / d) > VIEW_HALF_ANGLE:
			continue
		for target in [chest, head]:
			var q := PhysicsRayQueryParameters3D.create(eye, target, ChainBody.LAYER_WORLD)
			q.exclude = [p.get_rid()]
			if space.intersect_ray(q).is_empty():
				return true
	var cam := level.node_cam(floor_index, node_index)
	if cam >= 0:
		for d in level.desks:
			if d.is_live() and d.floor_index == floor_index and d.cam_index == cam:
				return true
	return false


func _loud_nearby() -> bool:
	for n in get_tree().get_nodes_in_group("noise_source"):
		var n3 := n as Node3D
		if n3 == null or not n3.is_inside_tree() or not n3.has_method("noise_level"):
			continue
		var d := n3.global_position.distance_to(global_position)
		if d > NOISE_RANGE or absf(n3.global_position.y - global_position.y) > 3.5:
			continue
		var lvl: float = n3.call("noise_level")
		if lvl * (1.0 - d / NOISE_RANGE) > NOISE_SKIP * 0.5:
			return true
	return false


## A flashlight held in his face while he holds someone makes him drop them. His face or his
## chest both count (he's 2.6 m tall: nobody aims at the hat), and only walls block the beam.
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
			_fx("scrape", -4.0, 1.8)
	else:
		_burn = maxf(0.0, _burn - delta * BURN_DECAY)
	burn_fraction = clampf(_burn / BURN_TO_RELEASE, 0.0, 1.0)
	return _burn >= BURN_TO_RELEASE


func _fx(id: String, vol: float, pitch: float) -> void:
	var fx := Effects.find(self)
	if fx != null:
		fx.fx_sound.rpc(id, chest_point(), vol, pitch)


@rpc("authority", "call_local", "reliable")
func _rpc_bang(shutter_path: NodePath) -> void:
	var s := get_node_or_null(shutter_path) as Shutter
	if s != null:
		s.play_bang()


@rpc("authority", "call_local", "reliable")
func _rpc_stun_fx() -> void:
	Sfx.play_at(self, "static", chest_point(), 2.0, 0.6, 30.0)
	Sfx.play_at(self, "servo", chest_point(), 0.0, 0.4, 30.0)
	_sparks.restart()
	_sparks.emitting = true


# --- Visuals (every peer) ---------------------------------------------------------------------------

func _update_visuals(delta: float) -> void:
	_model.visible = pstate != PState.DORMANT and pstate != PState.TRAVEL
	if not multiplayer.is_server():
		_model.rotation.y = lerp_angle(_model.rotation.y, synced_yaw, clampf(delta * 10.0, 0.0, 1.0))
	if pstate != _shown_state:
		_shown_state = pstate
		if pstate == PState.GRAB:
			# A scream through a broken speaker: deep, torn, too loud.
			Sfx.play_at(self, "scream", head_point(), 9.0, 0.72, 40.0)
			var caught := Net.find_player(grab_peer)
			if caught != null and caught.is_local:
				Sfx.play(self, "roar", 0.0, 0.8)
		if pstate == PState.LUNGE:
			Sfx.play_at(self, "scream", head_point(), 8.0, 0.68, 40.0)
			var tw := create_tween()
			tw.tween_property(_arm_l, "rotation:x", 2.4, 0.2)  # positive x swings an arm forward
			tw.parallel().tween_property(_arm_r, "rotation:x", 2.4, 0.2)
		elif pstate == PState.RUSH:
			var tw := create_tween()
			tw.tween_property(_arm_l, "rotation:x", 1.4, 0.3)
			tw.parallel().tween_property(_arm_r, "rotation:x", 1.4, 0.3)
			Sfx.caption(self, "heavy footsteps, fast", chest_point())
		elif pstate != PState.GRAB:
			var tw := create_tween()
			tw.tween_property(_arm_l, "rotation:x", 0.0, 0.6)
			tw.parallel().tween_property(_arm_r, "rotation:x", 0.0, 0.6)
	if pstate == PState.RUSH:
		# Stomps: he's the heaviest thing in the building, and now he's running.
		_stomp_t -= delta
		if _stomp_t <= 0.0:
			_stomp_t = 0.46
			Sfx.play_at(self, "thump", global_position, 2.0, 0.55, 40.0)
			var me := Net.get_local_player()
			if me != null and me.global_position.distance_to(global_position) < 14.0:
				me.add_shake(0.2)
		_model.position.y = absf(sin(Time.get_ticks_msec() * 0.0137)) * 0.08
	else:
		_model.position.y = 0.0
	if grab_peer != _shown_grab:
		_shown_grab = grab_peer
		var victim := Net.find_player(grab_peer)
		if victim != null and victim.is_local:
			Sfx.play(self, "stinger", 0.0)
	var t := Time.get_ticks_msec() * 0.001
	# Servo jitter: he's never quite still. Stunned, he twitches hard and the eyes flicker.
	var jitter := 0.012 if pstate != PState.STUNNED else 0.06
	_head.rotation = Vector3(sin(t * 17.0) * jitter, sin(t * 11.0) * jitter * 2.0, cos(t * 13.0) * jitter)
	var eye_e := 4.0
	if pstate == PState.STUNNED:
		eye_e = 6.0 if fmod(t, 0.2) < 0.1 else 0.3
	elif watched:
		eye_e = 5.5 + 1.0 * sin(t * 6.0)
	for e in _eyes:
		(e.material_override as StandardMaterial3D).emission_energy_multiplier = eye_e
	# The head turns to the nearest camera: he's looking at you looking at him.
	if _model.visible and pstate != PState.STUNNED:
		var cam := get_viewport().get_camera_3d()
		if cam != null and cam.global_position.distance_to(global_position) < 18.0:
			var local := _model.to_local(cam.global_position) - _head.position
			var yaw := clampf(atan2(-local.x, -local.z), -0.9, 0.9)
			var pitch := clampf(atan2(local.y - 0.3, Vector2(local.x, local.z).length()), -0.5, 0.5)
			_head.rotation.y = lerp_angle(_head.rotation.y, yaw, clampf(delta * 1.5, 0.0, 1.0))
			_head.rotation.x = lerpf(_head.rotation.x, -pitch, clampf(delta * 1.5, 0.0, 1.0))
	_sparks.emitting = pstate == PState.STUNNED
	# Captions and the odd creak so you know roughly where he is.
	if _model.visible:
		_caption_t -= delta
		var me := Net.get_local_player()
		if me != null and _caption_t <= 0.0 and me.global_position.distance_to(global_position) < 24.0:
			_caption_t = 6.0
			if pstate == PState.BANGING:
				Sfx.caption(self, "he's at the shutter", chest_point())
			elif pstate == PState.ROAM and not watched:
				Sfx.caption(self, "a servo ticks over", chest_point())
		_creak_t -= delta
		if _creak_t <= 0.0 and pstate == PState.ROAM:
			_creak_t = randf_range(5.0, 11.0)
			Sfx.play_at(self, "click", chest_point(), -10.0, 0.35, 22.0)
