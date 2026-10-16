class_name Player
extends ChainBody
## One chained new hire. Simulated ONLY on the server; clients send input by RPC and interpolate
## toward replicated state. Cameras, input and the heartbeat exist only on the local peer.

# --- Tunables (meters, seconds, m/s) ---------------------------------------------
const WALK_SPEED: float = 4.2
const RUN_SPEED: float = 7.0
const SNEAK_SPEED: float = 2.0  # holding Ctrl: brace against the chain AND creep quietly
const GROUND_ACCEL: float = 11.0  # m/s^2 speeding up: a body has weight
const GROUND_DECEL: float = 15.0  # m/s^2 stopping
const AIR_ACCEL: float = 8.0
const TURN_SPEED: float = 9.0  # rad/s the body can swing round to face where it's going
const JUMP_VELOCITY: float = 7.5  # with gravity 18 -> ~1.55 m jump
const GRAVITY: float = 18.0
const MANTLE_MIN_HEIGHT: float = 0.5
const MANTLE_MAX_HEIGHT: float = 2.1  # from standing: jump into a ledge this high to climb it
const MANTLE_AIR_MAX_HEIGHT: float = 1.3  # catching a ledge mid-air
const MANTLE_REACH: float = 0.85
const MANTLE_DURATION: float = 0.38
const MANTLE_COOLDOWN: float = 0.3
const MOUSE_SENSITIVITY: float = 0.0022
const PITCH_LIMIT: float = 1.45
const TP_ARM_LENGTH: float = 2.7
const NOISE_DECAY: float = 30.0  # per second
const NOISE_RUN: float = 55.0
const NOISE_WALK: float = 15.0
const NOISE_SNEAK: float = 3.0
const NOISE_DRAGGED: float = 26.0  # scraping along the carpet on the end of the Line
const NOISE_JUMP: float = 18.0
const NOISE_LAND: float = 30.0
const DRINK_BOOST_TIME: float = 8.0
const DRINK_CRASH_TIME: float = 5.0

enum State { NORMAL, MANTLE, GRABBED }
enum CameraMode { FIRST_PERSON, THIRD_PERSON }

# Input bits, client -> server. Bits 8..15 and 16..23 are press counters (jump, drop) so a lost
# or repeated unreliable packet can never eat or duplicate a press.
const FLAG_RUN: int = 2
const FLAG_BRACE: int = 4
const FLAG_USE: int = 8
const JUMP_SEQ_SHIFT: int = 8
const DROP_SEQ_SHIFT: int = 16

# Replicated state bits, server -> clients.
const SFLAG_GROUNDED: int = 1
const SFLAG_BRACING: int = 2
const SFLAG_MANTLING: int = 4
const SFLAG_USING_ITEM: int = 8
const SFLAG_GRABBED: int = 16
const SFLAG_RUNNING: int = 32

# --- Identity (set by Net.spawn_player_node on every peer) -------------------------
var peer_id: int = 0
var display_name: String = "Player"

# --- Replicated state ----------------------------------------------------------------
var synced_yaw: float = 0.0
var synced_pitch: float = 0.0
var synced_flags: int = 0
var held_item_id: String = ""
var item_charge: float = 0.0
var noise: float = 0.0
var buff_state: int = 0  # 0 normal, 1 energy drink boost, 2 crash

# --- Server-side input -------------------------------------------------------------
var input_move: Vector2 = Vector2.ZERO
var input_yaw: float = 0.0
var input_pitch: float = 0.0
var input_flags: int = 0
var bot_controlled: bool = false  # smoke tests feed _apply_input directly
var _jump_buffer: float = 0.0
var _last_jump_seq: int = 0
var _last_drop_seq: int = 0

# --- Server-side simulation --------------------------------------------------------
var state: State = State.NORMAL
var body_yaw: float = 0.0
var ignore_gravity_this_tick: bool = false
var held_item: ItemBase = null
var grabbed_by: Node = null
var _mantle_t: float = 0.0
var _mantle_start: Vector3 = Vector3.ZERO
var _mantle_target: Vector3 = Vector3.ZERO
var _mantle_cooldown: float = 0.0
var _buff_time: float = 0.0
var _was_on_floor: bool = true
var _fall_speed: float = 0.0

# --- Local-only ----------------------------------------------------------------------
var camera_mode: CameraMode = CameraMode.THIRD_PERSON
var input: PlayerInput
var _rig: Node3D
var _pitch_pivot: Node3D
var _fp_camera: Camera3D
var _spring_arm: SpringArm3D
var _tp_camera: Camera3D
var _yaw: float = 0.0
var _pitch: float = -0.15
var _shake: float = 0.0
var _heartbeat_t: float = 0.0
var _rig_pos: Vector3 = Vector3.ZERO
var _land_off: float = 0.0
var _land_v: float = 0.0
var _roll: float = 0.0
var _fov_kick: float = 0.0

# --- Visuals (every peer) --------------------------------------------------------------
var model: PlayerModel
var _name_label: Label3D
var _flashlight: SpotLight3D
var _jet_fx: GPUParticles3D
var _jet_sound: AudioStreamPlayer3D
var _last_visual_pos: Vector3
var _visual_speed: float = 0.0
var _visual_vel: Vector3 = Vector3.ZERO
# Physics runs at 60 Hz; the screen may not. Render between the last two physics positions.
var _phys_prev: Vector3 = Vector3.ZERO
var _phys_curr: Vector3 = Vector3.ZERO

var is_local: bool:
	get:
		return peer_id == multiplayer.get_unique_id()


# --- Setup -------------------------------------------------------------------------

func _enter_tree() -> void:
	if has_node("Sync"):
		return
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	for prop in ["synced_position", "synced_yaw", "synced_pitch", "synced_flags", "item_charge", "noise"]:
		_cfg_add(cfg, prop, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	for prop in ["held_item_id", "display_name", "buff_state"]:
		_cfg_add(cfg, prop, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	sync.replication_config = cfg
	add_child(sync)


func _cfg_add(cfg: SceneReplicationConfig, prop: String, mode: SceneReplicationConfig.ReplicationMode) -> void:
	var path := NodePath(".:" + prop)
	cfg.add_property(path)
	cfg.property_set_spawn(path, true)
	cfg.property_set_replication_mode(path, mode)


func _ready() -> void:
	add_to_group("players")
	add_to_group("noise_source")
	_setup_body_layers()
	model = PlayerModel.new()
	model.name = "Model"
	add_child(model)
	model.build(join_index)
	model.footstep.connect(_on_footstep)
	model.landed.connect(_on_landed)
	_phys_prev = global_position
	_phys_curr = global_position
	_name_label = Label3D.new()
	_name_label.text = display_name
	_name_label.position = Vector3(0.0, 2.3, 0.0)
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.font_size = 40
	_name_label.pixel_size = 0.006
	_name_label.outline_size = 10
	_name_label.no_depth_test = true
	_name_label.visible = not is_local
	add_child(_name_label)
	_build_flashlight()
	_build_jet_fx()
	body_yaw = synced_yaw
	_last_visual_pos = global_position
	if multiplayer.is_server():
		synced_position = global_position
	if is_local:
		input = PlayerInput.new()
		input.name = "Input"
		add_child(input)
		_setup_cameras()


func _build_flashlight() -> void:
	_flashlight = SpotLight3D.new()
	_flashlight.name = "Flashlight"
	_flashlight.spot_range = 18.0
	_flashlight.spot_angle = 24.0
	_flashlight.spot_attenuation = 0.8
	_flashlight.light_energy = 4.5
	_flashlight.light_color = Color(1.0, 0.95, 0.84)
	_flashlight.light_volumetric_fog_energy = 2.0
	_flashlight.shadow_enabled = true
	_flashlight.visible = false
	add_child(_flashlight)


func _build_jet_fx() -> void:
	_jet_fx = GPUParticles3D.new()
	_jet_fx.amount = 48
	_jet_fx.lifetime = 0.35
	_jet_fx.emitting = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0.0, -1.0, 0.0)
	pm.spread = 12.0
	pm.initial_velocity_min = 5.0
	pm.initial_velocity_max = 7.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.85, 0.4, 1.0))
	ramp.set_color(1, Color(1.0, 0.25, 0.05, 0.0))
	var rt := GradientTexture1D.new()
	rt.gradient = ramp
	pm.color_ramp = rt
	_jet_fx.process_material = pm
	var quad := SphereMesh.new()
	quad.radius = 0.07
	quad.height = 0.14
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.vertex_color_use_as_albedo = true
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.albedo_color = Color(2.0, 1.4, 0.6)
	quad.material = qm
	_jet_fx.draw_pass_1 = quad
	_jet_fx.position = Vector3(0.0, 1.0, 0.36)
	model.add_child(_jet_fx)  # on the model, so the flames stay on your back as you turn
	_jet_sound = Sfx.loop_player("jet", -4.0, 35.0)
	_jet_sound.position = Vector3(0.0, 1.2, 0.3)
	model.add_child(_jet_sound)


func _setup_cameras() -> void:
	_rig = Node3D.new()
	_rig.name = "CameraRig"
	_rig.top_level = true  # follows the body through a spring, not rigidly
	add_child(_rig)
	_rig_pos = global_position + Vector3(0.0, 1.55, 0.0)
	_rig.global_position = _rig_pos
	_pitch_pivot = Node3D.new()
	_rig.add_child(_pitch_pivot)
	_fp_camera = Camera3D.new()
	_fp_camera.position = Vector3(0.0, 0.12, -0.08)
	_fp_camera.near = 0.05
	_pitch_pivot.add_child(_fp_camera)
	_spring_arm = SpringArm3D.new()
	_spring_arm.spring_length = TP_ARM_LENGTH
	_spring_arm.margin = 0.25
	_spring_arm.collision_mask = ChainBody.LAYER_WORLD
	_pitch_pivot.add_child(_spring_arm)
	_tp_camera = Camera3D.new()
	_tp_camera.near = 0.05
	_spring_arm.add_child(_tp_camera)
	_yaw = synced_yaw
	_apply_camera_mode()


func _apply_camera_mode() -> void:
	var fp := camera_mode == CameraMode.FIRST_PERSON
	_tp_camera.current = not fp
	_fp_camera.current = fp
	model.set_first_person(fp)


func local_camera() -> Camera3D:
	if _rig == null:
		return null
	return _fp_camera if camera_mode == CameraMode.FIRST_PERSON else _tp_camera


func add_shake(amount: float) -> void:
	_shake = minf(1.0, _shake + amount)


# --- Local input ------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not is_local or GameState.ui_blocking:
		return
	if event.is_action_pressed("toggle_camera"):
		camera_mode = CameraMode.FIRST_PERSON if camera_mode == CameraMode.THIRD_PERSON else CameraMode.THIRD_PERSON
		_apply_camera_mode()
		GameState.post_message_local("Camera: %s (V)" % ("first person" if camera_mode == CameraMode.FIRST_PERSON else "third person"), 1.5)


func _process(delta: float) -> void:
	if is_local and _rig != null:
		_update_local_camera(delta)
	_update_visuals(delta)


func _update_local_camera(delta: float) -> void:
	var look := input.consume_look() * MOUSE_SENSITIVITY * Settings.mouse_sensitivity
	var keys := input.key_look(delta)
	_yaw -= look.x + keys.x
	var pitch_in := look.y * (-1.0 if Settings.invert_y else 1.0)
	_pitch = clampf(_pitch - pitch_in + keys.y, -PITCH_LIMIT, PITCH_LIMIT)
	if synced_flags & SFLAG_GRABBED:
		_pitch = lerpf(_pitch, 1.15, clampf(delta * 3.0, 0.0, 1.0))  # it makes you look up
		add_shake(delta * 0.8)
	var fp := camera_mode == CameraMode.FIRST_PERSON
	# Follow the (render-interpolated) body through a spring: tight sideways, softer vertically so
	# steps, mantles and landings don't jolt the view.
	var target := _visual_position() + Vector3(0.0, 1.55, 0.0)
	if _rig_pos.distance_to(target) > 3.0:
		_rig_pos = target  # teleport / respawn
	var kh := 1.0 - exp(-(34.0 if fp else 14.0) * delta)
	var kv := 1.0 - exp(-(16.0 if fp else 8.0) * delta)
	_rig_pos = Vector3(lerpf(_rig_pos.x, target.x, kh), lerpf(_rig_pos.y, target.y, kv), lerpf(_rig_pos.z, target.z, kh))
	_land_v += (-_land_off * 160.0 - _land_v * 18.0) * delta
	_land_off += _land_v * delta
	var g := model.gait()
	var bob_y := (0.032 if fp else 0.012) * g.y * cos(2.0 * g.x)
	var right := Vector3(cos(_yaw), 0.0, -sin(_yaw))
	var bob_x := (0.016 if fp else 0.0) * g.y * sin(g.x)
	_rig.global_position = _rig_pos + Vector3(0.0, _land_off + bob_y, 0.0) + right * bob_x
	_rig.global_rotation = Vector3(0.0, _yaw, 0.0)
	_pitch_pivot.rotation.x = _pitch
	# Lean the view into strafes; widen it a touch when you run.
	_roll = lerpf(_roll, -_visual_vel.dot(right) * (0.006 if fp else 0.01), 1.0 - exp(-6.0 * delta))
	_fov_kick = lerpf(_fov_kick, 7.0 if _visual_speed > 5.5 else 0.0, 1.0 - exp(-4.0 * delta))
	var fov := Settings.fov + _fov_kick + (12.0 if buff_state == 1 else 0.0) - (6.0 if buff_state == 2 else 0.0)
	var cam := local_camera()
	cam.fov = lerpf(cam.fov, fov, 1.0 - exp(-6.0 * delta))
	_shake = maxf(0.0, _shake - delta * 1.6)
	var s := _shake * _shake * 0.35
	_fp_camera.h_offset = randf_range(-s, s)
	_fp_camera.v_offset = randf_range(-s, s)
	_fp_camera.rotation.z = _roll
	_tp_camera.h_offset = 0.5 + randf_range(-s, s)
	_tp_camera.v_offset = 0.3 + randf_range(-s, s)
	_tp_camera.rotation.z = _roll
	if camera_mode == CameraMode.THIRD_PERSON:
		# A wall behind you pulls the camera in: hide your own head (or all of you) so it never
		# fills the screen.
		var arm := _spring_arm.get_hit_length()
		model.visible = arm > 0.95
		model.set_first_person(arm < 1.3)
	else:
		model.visible = true
	_tick_heartbeat(delta)


func _tick_heartbeat(delta: float) -> void:
	var period := 0.0
	if synced_flags & SFLAG_GRABBED:
		period = 0.45
	else:
		for c in get_tree().get_nodes_in_group("custodian"):
			if c.get("hunt_peer") == peer_id:
				period = 0.8
	if period <= 0.0:
		_heartbeat_t = 0.0
		return
	_heartbeat_t -= delta
	if _heartbeat_t <= 0.0:
		_heartbeat_t = period
		Sfx.play(self, "heartbeat", -2.0)


## Where the body should be drawn this frame: between the last two physics positions.
func _visual_position() -> Vector3:
	if _phys_prev.distance_to(_phys_curr) > 2.0:
		return _phys_curr
	return _phys_prev.lerp(_phys_curr, clampf(Engine.get_physics_interpolation_fraction(), 0.0, 1.0))


func _update_visuals(delta: float) -> void:
	var vis := _visual_position()
	model.position = vis - global_position  # the body itself doesn't rotate, so this is local
	_name_label.position = model.position + Vector3(0.0, 2.3, 0.0)
	var moved := vis - _last_visual_pos
	_last_visual_pos = vis
	if moved.length() > 2.0:
		moved = Vector3.ZERO
	_visual_vel = _visual_vel.lerp(moved / maxf(delta, 0.0001), 1.0 - exp(-14.0 * delta))
	_visual_speed = Vector2(_visual_vel.x, _visual_vel.z).length()
	var grounded := (synced_flags & SFLAG_GROUNDED) != 0
	var grabbed := (synced_flags & SFLAG_GRABBED) != 0
	var bracing := (synced_flags & SFLAG_BRACING) != 0
	var mantling := (synced_flags & SFLAG_MANTLING) != 0
	var using := (synced_flags & SFLAG_USING_ITEM) != 0
	var yaw := body_yaw if multiplayer.is_server() else synced_yaw
	var p := _pitch if is_local else synced_pitch
	var yw := _yaw if is_local else synced_yaw
	model.set_held_item(held_item_id)
	var aiming := held_item_id == "pistol" or (held_item_id == "flashlight" and using)
	if aiming:
		yaw = yw  # turn to face where you point it
	model.animate(delta, _visual_vel, yaw, grounded, bracing, grabbed, mantling, aiming, p)
	# Flashlight beam follows your view (local) or the replicated aim (everyone else).
	var on := held_item_id == "flashlight" and using
	_flashlight.visible = on
	if on:
		var b := Basis.from_euler(Vector3(p, yw, 0.0))
		_flashlight.global_transform = Transform3D(b, vis + Vector3(0.0, 1.45, 0.0) + b * Vector3(0.22, -0.1, -0.3))
	var jet_on := held_item_id == "jetpack" and using
	_jet_fx.emitting = jet_on
	if jet_on:
		Sfx.start_loop(_jet_sound)
	elif _jet_sound.playing:
		_jet_sound.stop()


func _on_footstep(strength: float) -> void:
	var bracing := (synced_flags & SFLAG_BRACING) != 0
	var vol := -20.0 if bracing else lerpf(-13.0, -7.0, strength)
	Sfx.play_at(self, "step", global_position, vol, randf_range(0.85, 1.15), 25.0)


func _on_landed(strength: float) -> void:
	Sfx.play_at(self, "thump", global_position, lerpf(-15.0, -4.0, strength), randf_range(0.9, 1.2))
	if is_local:
		_land_v -= strength * 2.4  # the camera dips with your knees


func _send_input() -> void:
	var raw := input.move_vector()
	var dir := Vector3(raw.x, 0.0, raw.y).rotated(Vector3.UP, _yaw)
	var move := Vector2(dir.x, dir.z).limit_length(1.0)
	var flags := 0
	if input.held("run"):
		flags |= FLAG_RUN
	if input.held("brace"):
		flags |= FLAG_BRACE
	if input.use_held():
		flags |= FLAG_USE
	flags |= (input.jump_count() & 0xFF) << JUMP_SEQ_SHIFT
	flags |= (input.drop_count() & 0xFF) << DROP_SEQ_SHIFT
	if multiplayer.is_server():
		_apply_input(move, _yaw, _pitch, flags)
	else:
		rpc_input.rpc_id(1, move, _yaw, _pitch, flags)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func rpc_input(move: Vector2, yaw: float, pitch: float, flags: int) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != peer_id:
		return
	_apply_input(move, yaw, pitch, flags)


func _apply_input(move: Vector2, yaw: float, pitch: float, flags: int) -> void:
	input_move = move.limit_length(1.0)
	input_yaw = yaw
	input_pitch = clampf(pitch, -PITCH_LIMIT, PITCH_LIMIT)
	input_flags = flags
	var seq := (flags >> JUMP_SEQ_SHIFT) & 0xFF
	if seq != _last_jump_seq:
		_last_jump_seq = seq
		_jump_buffer = 0.15
	var drop := (flags >> DROP_SEQ_SHIFT) & 0xFF
	if drop != _last_drop_seq:
		_last_drop_seq = drop
		if state == State.NORMAL:
			server_drop_item(true)


# --- Simulation ------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	# The position at the end of last tick (after the chain moved us too) is the newest
	# render target; rendering then blends between it and the one before.
	_phys_prev = _phys_curr
	_phys_curr = global_position
	if is_local and not bot_controlled and input != null:
		_send_input()
	if multiplayer.is_server():
		_server_tick(delta)
	else:
		client_interpolate(delta)
		body_yaw = synced_yaw


func _server_tick(delta: float) -> void:
	var dragged := dragged_this_tick
	dragged_this_tick = 0.0
	_mantle_cooldown = maxf(0.0, _mantle_cooldown - delta)
	_jump_buffer = maxf(0.0, _jump_buffer - delta)
	_tick_buff(delta)
	if held_item != null:
		held_item.server_tick(delta, (input_flags & FLAG_USE) != 0 and state != State.GRABBED)
	match state:
		State.MANTLE:
			_tick_mantle(delta)
		State.GRABBED:
			velocity = Vector3.ZERO
			external_velocity = Vector3.ZERO
		_:
			_tick_normal(delta)
	_tick_noise(delta, dragged)
	synced_position = global_position
	synced_yaw = body_yaw
	synced_pitch = input_pitch
	var f := 0
	if is_on_floor() and state != State.GRABBED:
		f |= SFLAG_GROUNDED
	if is_bracing():
		f |= SFLAG_BRACING
	if state == State.MANTLE:
		f |= SFLAG_MANTLING
	if state == State.GRABBED:
		f |= SFLAG_GRABBED
	if held_item != null and held_item.is_active:
		f |= SFLAG_USING_ITEM
	if (input_flags & FLAG_RUN) != 0:
		f |= SFLAG_RUNNING
	synced_flags = f


func _speed_multiplier() -> float:
	if buff_state == 1:
		return 1.55
	if buff_state == 2:
		return 0.6
	return 1.0


func _tick_buff(delta: float) -> void:
	if buff_state == 0:
		return
	_buff_time -= delta
	if _buff_time > 0.0:
		return
	if buff_state == 1:
		buff_state = 2
		_buff_time = DRINK_CRASH_TIME
	else:
		buff_state = 0


func _tick_normal(delta: float) -> void:
	var on_floor := is_on_floor()
	var bracing := (input_flags & FLAG_BRACE) != 0 and on_floor
	var target_speed := WALK_SPEED
	if bracing:
		target_speed = SNEAK_SPEED
	elif (input_flags & FLAG_RUN) != 0:
		target_speed = RUN_SPEED
	target_speed *= _speed_multiplier()
	var wish := Vector3(input_move.x, 0.0, input_move.y)
	var accel := AIR_ACCEL
	if on_floor:
		accel = GROUND_ACCEL if wish.length() > 0.1 else GROUND_DECEL
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	horizontal = horizontal.move_toward(wish * target_speed, accel * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if not ignore_gravity_this_tick:
		velocity.y -= GRAVITY * delta
	ignore_gravity_this_tick = false
	velocity += external_velocity
	external_velocity = Vector3.ZERO
	var wants_mantle := _jump_buffer > 0.0 or (not on_floor and wish.length() > 0.5 and velocity.y < 2.0)
	if wants_mantle and _mantle_cooldown <= 0.0 and _try_mantle(wish, on_floor):
		_jump_buffer = 0.0
		return
	if _jump_buffer > 0.0 and on_floor:
		velocity.y = JUMP_VELOCITY * (1.15 if buff_state == 1 else 1.0)
		_jump_buffer = 0.0
		add_noise(NOISE_JUMP)
	if wish.length() > 0.1:
		var want := atan2(-wish.x, -wish.z)
		body_yaw += clampf(wrapf(want - body_yaw, -PI, PI), -TURN_SPEED * delta, TURN_SPEED * delta)
	if not on_floor:
		_fall_speed = maxf(_fall_speed, -velocity.y)
	move_and_slide()
	var landed := is_on_floor() and not _was_on_floor
	if landed and _fall_speed > 9.0:
		add_noise(NOISE_LAND)
	if is_on_floor():
		_fall_speed = 0.0
	_was_on_floor = is_on_floor()


func _tick_noise(delta: float, dragged: float) -> void:
	var target := 0.0
	if is_on_floor() and state == State.NORMAL:
		var h := Vector2(velocity.x, velocity.z).length()
		if h > 5.2:
			target = NOISE_RUN
		elif h > 2.6:
			target = NOISE_WALK
		elif h > 0.4:
			target = NOISE_SNEAK
		if dragged > 0.02:
			target = maxf(target, NOISE_DRAGGED)
	noise = maxf(target, noise - NOISE_DECAY * delta)


func add_noise(amount: float) -> void:
	noise = minf(100.0, noise + amount)


func noise_level() -> float:
	return noise


func _try_mantle(wish: Vector3, from_ground: bool) -> bool:
	var max_height := MANTLE_MAX_HEIGHT if from_ground else MANTLE_AIR_MAX_HEIGHT
	var fwd := wish.normalized() if wish.length() > 0.1 else Vector3(-sin(body_yaw), 0.0, -cos(body_yaw))
	var space := get_world_3d().direct_space_state
	var mask := ChainBody.LAYER_WORLD | ChainBody.LAYER_BODIES  # you can climb onto teammates
	# Probe at knee, waist and chest height so short ledges (desks, crates) count too.
	var wall: Dictionary = {}
	for h: float in [0.35, 0.8, 1.25]:
		var from := global_position + Vector3(0.0, h, 0.0)
		var q := PhysicsRayQueryParameters3D.create(from, from + fwd * MANTLE_REACH, mask)
		q.exclude = [get_rid()]
		wall = space.intersect_ray(q)
		if not wall.is_empty() and (wall["normal"] as Vector3).y < 0.5:
			break
		wall = {}
	if wall.is_empty():
		return false
	var wall_point: Vector3 = wall["position"]
	var probe := wall_point + fwd * 0.45
	var top_start := Vector3(probe.x, global_position.y + max_height + 0.4, probe.z)
	var top_end := Vector3(probe.x, global_position.y + MANTLE_MIN_HEIGHT, probe.z)
	var q2 := PhysicsRayQueryParameters3D.create(top_start, top_end, mask)
	q2.exclude = [get_rid()]
	var top := space.intersect_ray(q2)
	if top.is_empty():
		return false
	var top_point: Vector3 = top["position"]
	var top_normal: Vector3 = top["normal"]
	var height := top_point.y - global_position.y
	if height < MANTLE_MIN_HEIGHT or height > max_height or top_normal.y < 0.7:
		return false
	var q3 := PhysicsRayQueryParameters3D.create(top_point + Vector3(0.0, 0.1, 0.0), top_point + Vector3(0.0, 1.85, 0.0), mask)
	q3.exclude = [get_rid()]
	if not space.intersect_ray(q3).is_empty():
		return false
	_mantle_start = global_position
	_mantle_target = top_point + Vector3(0.0, 0.05, 0.0)
	_mantle_t = 0.0
	velocity = Vector3.ZERO
	body_yaw = atan2(-fwd.x, -fwd.z)
	state = State.MANTLE
	return true


func _tick_mantle(delta: float) -> void:
	_mantle_t += delta / MANTLE_DURATION
	var t := clampf(_mantle_t, 0.0, 1.0)
	var rise := smoothstep(0.0, 1.0, clampf(t / 0.6, 0.0, 1.0))
	var step := smoothstep(0.0, 1.0, clampf((t - 0.6) / 0.4, 0.0, 1.0))
	var y := lerpf(_mantle_start.y, _mantle_target.y, rise)
	var xz := Vector3(_mantle_start.x, 0.0, _mantle_start.z).lerp(Vector3(_mantle_target.x, 0.0, _mantle_target.z), step)
	global_position = Vector3(xz.x, y, xz.z)
	velocity = Vector3.ZERO
	external_velocity = Vector3.ZERO
	if t >= 1.0:
		state = State.NORMAL
		_mantle_cooldown = MANTLE_COOLDOWN


# --- Chain interface (server) ---------------------------------------------------------

func chain_weight() -> float:
	if state == State.MANTLE or state == State.GRABBED:
		return 0.0
	if not is_on_floor():
		return 1.0
	if is_bracing():
		return 0.08
	return 0.35


func is_bracing() -> bool:
	return (input_flags & FLAG_BRACE) != 0 and is_on_floor() and state == State.NORMAL


func resist_value() -> float:
	if state != State.NORMAL or not is_on_floor():
		return 0.0
	return 2.0 if is_bracing() else 1.0


func teleport_to(pos: Vector3, yaw: float) -> void:
	super.teleport_to(pos, yaw)
	body_yaw = yaw
	synced_yaw = yaw
	if state == State.GRABBED and grabbed_by != null and grabbed_by.has_method("release"):
		grabbed_by.call("release", false)
	state = State.NORMAL
	grabbed_by = null
	_jump_buffer = 0.0
	_fall_speed = 0.0
	noise = 0.0


func grab_start(by: Node) -> void:
	state = State.GRABBED
	grabbed_by = by
	velocity = Vector3.ZERO


func grab_end() -> void:
	if state == State.GRABBED:
		state = State.NORMAL
	grabbed_by = null
	velocity = Vector3(0.0, -1.0, 0.0)


func is_grabbed() -> bool:
	return state == State.GRABBED


func apply_knockback(v: Vector3) -> void:
	if state == State.GRABBED:
		return
	if state == State.MANTLE:
		state = State.NORMAL
	super.apply_knockback(v)


func apply_energy_drink() -> void:
	buff_state = 1
	_buff_time = DRINK_BOOST_TIME


func eye_position() -> Vector3:
	return global_position + Vector3(0.0, 1.6, 0.0)


func aim_direction() -> Vector3:
	return Basis.from_euler(Vector3(input_pitch, input_yaw, 0.0)) * Vector3.FORWARD


# --- Items (server) ---------------------------------------------------------------------

func server_give_item(item: ItemBase) -> bool:
	if held_item != null or state == State.GRABBED:
		return false
	held_item = item
	item.name = "Item_" + item.data.id
	add_child(item)
	item.on_equip(self)
	held_item_id = item.data.id
	item_charge = item.charge()
	return true


## Drops the held item. With spawn_pickup it lands in front of you for anyone to grab;
## without it the item is used up.
func server_drop_item(spawn_pickup: bool = true) -> void:
	if held_item == null:
		return
	var id := held_item.data.id
	held_item.on_unequip()
	held_item.queue_free()
	held_item = null
	held_item_id = ""
	item_charge = 0.0
	if spawn_pickup:
		var fwd := Vector3(-sin(body_yaw), 0.0, -cos(body_yaw))
		Net.spawn_pickup(id, global_position + fwd * 0.9 + Vector3(0.0, 0.2, 0.0), peer_id)
