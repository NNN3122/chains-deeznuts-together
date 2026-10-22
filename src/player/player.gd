class_name Player
extends ChainBody
## One chained new hire. Simulated ONLY on the server; clients send input by RPC and interpolate
## toward replicated state. Cameras, input and the heartbeat exist only on the local peer.
## Carries up to SLOTS items (1/2/3 or the wheel selects; only the selected one answers F).

# --- Tunables (meters, seconds, m/s) ---------------------------------------------
const WALK_SPEED: float = 4.2
const RUN_SPEED: float = 7.0
const SNEAK_SPEED: float = 2.0  # holding Ctrl: brace against the chain AND creep quietly
const GROUND_ACCEL: float = 11.0  # m/s^2 speeding up: a body has weight
const GROUND_DECEL: float = 26.0  # m/s^2 stopping: let go of the key and you stop within a step
const GROUND_TURN_DECEL: float = 34.0  # m/s^2 bleeding off the part of your speed that isn't where you now steer: a sprint turns, it doesn't drift (the user: "it adds a couple of steps")
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
const STAND_HEIGHT: float = 1.8  # capsule, meters
const STARTING_KIT: Array[String] = ["flashlight", "wrench"]  # every player clocks in with these, slot 1 and 2
const GRAB_LOOK_RATE: float = 10.0  # 1/s, how hard a caught player's view swings onto the face that has them
const GRAB_LOOK_TIME: float = 0.6  # s the view is swung onto its face before the mouse is yours again
const GRAB_PULL_RATE: float = 2.5  # 1/s, the softer pull back onto its face while you leave the mouse alone
const GRAB_PULL_DELAY: float = 0.6  # s without looking around before that pull starts
const CHASE_RANGE: float = 22.0  # m: a hunter further off than this doesn't bring the chase music
const CHASE_DB: float = -7.0  # the chase music at full
const CHASE_FADE_IN: float = 1.5  # 1/s
const CHASE_FADE_OUT: float = 0.3  # 1/s: it lingers after the thing gives up
const CHASE_PITCH: Dictionary = {"hire": 1.0, "custodian": 1.12, "pappy": 0.82, "launcher": 1.25}  # each its own key
const ORPHAN_GRAB_TIME: float = 0.4  # s held by nothing before the grab is dropped
const CROUCH_HEIGHT: float = 1.25
const EYE_HEIGHT: float = 1.55
const CROUCH_EYE_HEIGHT: float = 1.05
const CAMERA_BALL: float = 0.2  # m: the third-person camera's clearance from whatever its arm meets
const NOISE_DECAY: float = 30.0  # per second
const NOISE_RUN: float = 55.0
const NOISE_WALK: float = 15.0
const NOISE_SNEAK: float = 3.0
const NOISE_DRAGGED: float = 26.0  # scraping along the carpet on the end of the Line
const NOISE_JUMP: float = 18.0
const NOISE_LAND: float = 30.0
const HARD_LAND_SPEED: float = 18.0  # m/s falling (about 9 m): land harder and you're knocked flat for a second or two
const DRINK_BOOST_TIME: float = 8.0
const DRINK_CRASH_TIME: float = 5.0
const SLOTS: int = 4  # three for loot, and KEY_SLOT
const ITEM_SLOTS: int = 3  # the ones pickups go in
const KEY_SLOT: int = 3  # the Shackle Key's own (the second player clocks in with it; 4 selects it)
const KEY_HOLDER: int = 1  # join index that clocks in with the Shackle Key: the second player
const SFLAG_UNCHAINED: int = 2048  # off the Line (the Shackle Key)
const SLIDE_MIN_SPEED: float = 4.5  # m/s: you have to be sprinting for Ctrl to drop you into a slide (a walk is 4.2)
const SLIDE_SPEED: float = 8.4  # m/s at the start of a slide (a sprint is 7)
const SLIDE_TIME: float = 1.0  # s the slide carries before it ends
const SLIDE_END_SPEED: float = 1.6  # m/s: a slide that has slowed this far is over
const SLIDE_COOLDOWN: float = 0.35
const NOISE_SLIDE: float = 24.0
const SPRINT_SECONDS: float = 8.0  # s of flat-out running from a full breath
const RECOVER_SECONDS: float = 7.0  # s from empty back to full, standing still (walking is slower)
const WINDED_UNTIL: float = 0.35  # run dry and you can't sprint or slide again until this much is back
const SLIDE_STAMINA: float = 0.12  # a slide costs this much
const PANT_BELOW: float = 0.3  # from here down you pant, and panting is noise
const NOISE_PANT: float = 28.0  # gasping for air: enough for something to come and look
const SFLAG_WINDED: int = 256
const SFLAG_DOWNED: int = 512  # knocked flat (a tackle, a wall)
const SFLAG_KNOCKED: int = 1024  # no control: thrown, sliding, or down
const KNOCK_FRICTION: float = 7.0  # m/s^2: a thrown body skids along the floor this hard
const WALL_SLAM_SPEED: float = 5.0  # m/s into a wall to be slammed against it
const WALL_DAZE: float = 1.3  # s on the floor after a slam

enum State { NORMAL, MANTLE, GRABBED }
enum CameraMode { FIRST_PERSON, THIRD_PERSON }

# Input bits, client -> server. Every press is a counter so a lost or repeated unreliable packet
# can never eat or duplicate it: jump (8..15), drop (16..23), use taps (24..31), slot changes
# (32..39) with the slot asked for (40..42), reload (43..50).
const FLAG_RUN: int = 2
const FLAG_BRACE: int = 4
const FLAG_USE: int = 8
const JUMP_SEQ_SHIFT: int = 8
const DROP_SEQ_SHIFT: int = 16
const USE_SEQ_SHIFT: int = 24
const SLOT_SEQ_SHIFT: int = 32
const SLOT_REQ_SHIFT: int = 40
const RELOAD_SEQ_SHIFT: int = 43

# Replicated state bits, server -> clients.
const SFLAG_GROUNDED: int = 1
const SFLAG_BRACING: int = 2
const SFLAG_MANTLING: int = 4
const SFLAG_USING_ITEM: int = 8
const SFLAG_GRABBED: int = 16
const SFLAG_RUNNING: int = 32
const SFLAG_TALKING: int = 64
const SFLAG_SLIDING: int = 128

# --- Identity (set by Net.spawn_player_node on every peer) -------------------------
var peer_id: int = 0
var display_name: String = "Player"

# --- Replicated state ----------------------------------------------------------------
var synced_yaw: float = 0.0
var synced_pitch: float = 0.0
var synced_flags: int = 0
var held_item_id: String = ""  # the selected slot's item
var slot_ids: PackedStringArray = ["", "", "", ""]
var selected_slot: int = 0
var item_charge: float = 0.0
var ammo_text: String = ""  # "8 / 24" for guns, "" otherwise
var noise: float = 0.0
var buff_state: int = 0  # 0 normal, 1 energy drink boost, 2 crash
var stamina: float = 1.0  # server, replicated: 0..1 of a sprint left
var _winded: bool = false  # server: ran dry; no sprint until WINDED_UNTIL
var unchained: bool = false  # server: unlocked from the Line with the Shackle Key
var _knock_t: float = 0.0  # server: s left without control after a monster's hit
var _downed: bool = false  # server: flat on the floor for it
var _flung: bool = false  # server: in flight, and a wall will hurt
var _down_amt: float = 0.0  # every peer: 0..1 of the lying-down pose
static var debug_infinite_stamina: bool = false  # tests that are about routes, not breath
const BEAM_FOG: float = 2.0  # the flashlight beam's glow in volumetric fog (the roof's thin fog)
static var beam_fog: float = BEAM_FOG  # every peer, for the level the camera is in: the manor's thick fog wants less (Manor.set_shown)

# --- Server-side input -------------------------------------------------------------
var input_move: Vector2 = Vector2.ZERO
var input_yaw: float = 0.0
var input_pitch: float = 0.0
var input_flags: int = 0
var bot_controlled: bool = false  # smoke tests feed _apply_input directly
var _jump_buffer: float = 0.0
var _last_jump_seq: int = 0
var _last_drop_seq: int = 0
var _last_use_seq: int = 0
var _last_slot_seq: int = 0
var _last_reload_seq: int = 0
var _use_taps: int = 0  # taps not yet handed to the item
var _reload_taps: int = 0

# --- Server-side simulation --------------------------------------------------------
var state: State = State.NORMAL
var body_yaw: float = 0.0
var ignore_gravity_this_tick: bool = false
var slots: Array[ItemBase] = [null, null, null, null]
var grabbed_by: Node = null
var _grab_origin: Vector3 = Vector3.ZERO  # where the grab caught you: a spot known to be clear
var _orphan_grab_t: float = 0.0  # seconds held by something that no longer says it holds you
var _mantle_t: float = 0.0
var _mantle_start: Vector3 = Vector3.ZERO
var _mantle_target: Vector3 = Vector3.ZERO
var _mantle_cooldown: float = 0.0
var _buff_time: float = 0.0
var _was_on_floor: bool = true
var _fall_speed: float = 0.0
var _crouched: bool = false  # server: the capsule is short (wants to brace, or no headroom to stand)
var _slide_t: float = 0.0  # server: seconds left in the slide, 0 when not sliding
var _slide_dir: Vector3 = Vector3.ZERO
var _slide_cooldown: float = 0.0
var _brace_was: bool = false  # server: Ctrl state last tick (a slide starts on the press, not the hold)
var hold_drag: float = 0.0  # server: 0..1 of your speed something hanging on the chain takes this tick (set and consumed)

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
var _was_grabbed: bool = false
var _grab_look_t: float = 0.0  # s since this grab began, on this peer's camera
var _grab_idle: float = 0.0  # s since the caught player last looked around
var _chase_player: AudioStreamPlayer
var _chase_level: float = 0.0  # 0..1, how far in the chase music is
var _pov_forced: bool = false  # caught while playing in third person: the view is your own eyes until it lets go
var _rig_pos: Vector3 = Vector3.ZERO
var _land_off: float = 0.0
var _land_v: float = 0.0
var _roll: float = 0.0
var _fov_kick: float = 0.0
var _eye_h: float = EYE_HEIGHT
var _slide_tilt: float = 0.0
var _was_sliding: bool = false

# --- Visuals (every peer) --------------------------------------------------------------
var model: PlayerModel
var _name_label: Label3D
var _flashlight: SpotLight3D
var _jet_fx: GPUParticles3D
var _jet_sound: AudioStreamPlayer3D
var _breath: AudioStreamPlayer3D
var _breath_level: float = 0.0  # every peer: 0..1 how hard this body is panting
var _shape: CollisionShape3D
var _last_visual_pos: Vector3
var _visual_speed: float = 0.0
var _visual_vel: Vector3 = Vector3.ZERO
# Physics runs at 60 Hz; the screen may not. Render between the last two physics positions.
var _phys_prev: Vector3 = Vector3.ZERO
var _phys_curr: Vector3 = Vector3.ZERO

var is_local: bool:
	get:
		return peer_id == multiplayer.get_unique_id()

## The selected slot's item logic (server), for everything that asks "what are they holding".
var held_item: ItemBase:
	get:
		return slots[selected_slot] if selected_slot >= 0 and selected_slot < slots.size() else null


# --- Setup -------------------------------------------------------------------------

func _enter_tree() -> void:
	if has_node("Sync"):
		return
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	for prop in ["synced_position", "synced_yaw", "synced_pitch", "synced_flags", "item_charge", "noise", "stamina"]:
		_cfg_add(cfg, prop, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	for prop in ["held_item_id", "slot_ids", "selected_slot", "ammo_text", "display_name", "buff_state"]:
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
	for c in get_children():
		if c is CollisionShape3D:
			_shape = c
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
	# Faint and hidden by walls: a teammate's name, not a glowing caption over the scene.
	_name_label.font_size = 30
	_name_label.pixel_size = 0.005
	_name_label.outline_size = 6
	_name_label.modulate = Color(1.0, 1.0, 1.0, 0.4)
	_name_label.outline_modulate = Color(0.0, 0.0, 0.0, 0.3)
	_name_label.no_depth_test = false
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
	if multiplayer.is_server():
		_grant_starting_kit()
		_grant_key()
		# A layoff puts everyone back on the Line: nobody is left unchained at a checkpoint.
		GameState.layoff_started.connect(func(_c: int, _r: String) -> void: set_unchained(false))


func _build_flashlight() -> void:
	_flashlight = SpotLight3D.new()
	_flashlight.name = "Flashlight"
	_flashlight.spot_range = 18.0
	_flashlight.spot_angle = 24.0
	_flashlight.spot_attenuation = 0.8
	_flashlight.light_energy = 4.5
	_flashlight.light_color = Color(1.0, 0.95, 0.84)
	_flashlight.light_volumetric_fog_energy = beam_fog
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
	_breath = Sfx.loop_player("pant", -40.0, 14.0)
	_breath.position = Vector3(0.0, 1.55, -0.1)
	model.add_child(_breath)


func _setup_cameras() -> void:
	_rig = Node3D.new()
	_rig.name = "CameraRig"
	_rig.top_level = true  # follows the body through a spring, not rigidly
	add_child(_rig)
	_rig_pos = global_position + Vector3(0.0, EYE_HEIGHT, 0.0)
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
	# A ball, not the camera's own view pyramid (what it sweeps with no shape): that went straight
	# through the manor's height-field ground, and the camera came up under the map.
	var ball := SphereShape3D.new()
	ball.radius = CAMERA_BALL
	_spring_arm.shape = ball
	_pitch_pivot.add_child(_spring_arm)
	_tp_camera = Camera3D.new()
	_tp_camera.near = 0.05
	_spring_arm.add_child(_tp_camera)
	_yaw = synced_yaw
	camera_mode = CameraMode.FIRST_PERSON if Settings.first_person else CameraMode.THIRD_PERSON
	_apply_camera_mode()


## Settings and the V key share one switch: either one changes the camera and the saved default.
func set_first_person_camera(fp: bool) -> void:
	camera_mode = CameraMode.FIRST_PERSON if fp else CameraMode.THIRD_PERSON
	Settings.first_person = fp
	if _rig != null:
		_apply_camera_mode()


func _apply_camera_mode() -> void:
	var fp := camera_mode == CameraMode.FIRST_PERSON
	_tp_camera.current = not fp
	_fp_camera.current = fp
	model.set_first_person(fp)


## Caught: through your own eyes whatever camera you chose; let go: back to it.
func _set_pov_forced(on: bool) -> void:
	if _rig == null:
		return
	_pov_forced = on and camera_mode == CameraMode.THIRD_PERSON
	if _pov_forced:
		_tp_camera.current = false
		_fp_camera.current = true
		model.visible = true
		model.set_first_person(true)
	else:
		_apply_camera_mode()


func local_camera() -> Camera3D:
	if _pov_forced:
		return _fp_camera
	if _rig == null:
		return null
	return _fp_camera if camera_mode == CameraMode.FIRST_PERSON else _tp_camera


func add_shake(amount: float) -> void:
	_shake = minf(1.0, _shake + amount)


# --- Local input ------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not is_local or GameState.ui_blocking or GameState.typing:
		return
	if event.is_action_pressed("toggle_camera"):
		set_first_person_camera(camera_mode == CameraMode.THIRD_PERSON)
		Settings.save_settings()
		GameState.post_message_local("Camera: %s (V, or Settings)" % ("first person" if camera_mode == CameraMode.FIRST_PERSON else "third person"), 1.5)


func _process(delta: float) -> void:
	if is_local and _rig != null:
		_update_local_camera(delta)
	_update_visuals(delta)


func _update_local_camera(delta: float) -> void:
	var look := input.consume_look() * MOUSE_SENSITIVITY * Settings.mouse_sensitivity
	var keys := input.key_look(delta)
	# Caught: you look at it. The view is your own eyes (first person, whichever camera you play
	# with), swung onto its face for GRAB_LOOK_TIME; after that the mouse is yours (the user could not
	# look down when it held the view the whole time), and if you leave it alone the view drifts back
	# onto its face. When it lets go (or you are taken) the camera you chose comes back.
	var grabbed_now := (synced_flags & SFLAG_GRABBED) != 0
	if grabbed_now != _was_grabbed:
		_was_grabbed = grabbed_now
		_set_pov_forced(grabbed_now)
		_grab_look_t = 0.0
		_grab_idle = 0.0
		input.reset_look()  # what you did with the mouse before (or during) the grab is spent
		look = Vector2.ZERO
		keys = Vector2.ZERO
	if grabbed_now:
		add_shake(delta * 0.8)
		_grab_look_t += delta
		if _grab_look_t < GRAB_LOOK_TIME:
			input.reset_look()
			_turn_toward_grabber(delta, GRAB_LOOK_RATE)
		else:
			_apply_look(look, keys)
			_grab_idle = 0.0 if look.length_squared() + keys.length_squared() > 1e-8 else _grab_idle + delta
			if _grab_idle > GRAB_PULL_DELAY:
				_turn_toward_grabber(delta, GRAB_PULL_RATE)
	else:
		_apply_look(look, keys)
	var fp := camera_mode == CameraMode.FIRST_PERSON or _pov_forced
	# The eye drops with a crouch, smoothly, so the view never pops.
	var crouching := (synced_flags & SFLAG_BRACING) != 0
	var sliding := (synced_flags & SFLAG_SLIDING) != 0
	var eye_target := EYE_HEIGHT
	var downed := (synced_flags & SFLAG_DOWNED) != 0
	if downed:
		eye_target = 0.35  # flat on the floor, looking up at it
	elif sliding:
		eye_target = CROUCH_EYE_HEIGHT - 0.2  # lower than a crouch: you're on your back
	elif crouching:
		eye_target = CROUCH_EYE_HEIGHT
	_eye_h = lerpf(_eye_h, eye_target, 1.0 - exp(-(16.0 if sliding else 10.0) * delta))
	if sliding and not _was_sliding:
		_land_v -= 2.0  # the drop into the slide
	_was_sliding = sliding
	# The view cants over while you slide, like a head tipped back on one shoulder.
	_slide_tilt = lerpf(_slide_tilt, 0.11 if sliding else (0.45 if downed else 0.0), 1.0 - exp(-8.0 * delta))
	# Follow the (render-interpolated) body through a spring: tight sideways, softer vertically so
	# steps, mantles and landings don't jolt the view.
	var target := _visual_position() + Vector3(0.0, _eye_h, 0.0)
	if _rig_pos.distance_to(target) > 3.0:
		_rig_pos = target  # teleport / respawn
	var kh := 1.0 - exp(-(60.0 if fp else 26.0) * delta)
	var kv := 1.0 - exp(-(22.0 if fp else 12.0) * delta)
	_rig_pos = Vector3(lerpf(_rig_pos.x, target.x, kh), lerpf(_rig_pos.y, target.y, kv), lerpf(_rig_pos.z, target.z, kh))
	_land_v += (-_land_off * 160.0 - _land_v * 18.0) * delta
	_land_off += _land_v * delta
	var g := model.gait()
	var bob_y := (0.032 if fp else 0.012) * g.y * cos(2.0 * g.x)
	var right := Vector3(cos(_yaw), 0.0, -sin(_yaw))
	var bob_x := (0.016 if fp else 0.0) * g.y * sin(g.x)
	_rig.global_position = _rig_pos + Vector3(0.0, _land_off + bob_y, 0.0) + right * bob_x
	_rig.global_rotation = Vector3(0.0, _yaw, 0.0)
	# Out of breath, the view heaves with each gasp.
	_pitch_pivot.rotation.x = _pitch + sin(float(Time.get_ticks_msec()) * 0.001 * TAU * 1.6) * 0.014 * _breath_level
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
	_fp_camera.rotation.z = _roll + _slide_tilt
	_tp_camera.h_offset = 0.5 + randf_range(-s, s)
	_tp_camera.v_offset = 0.3 + randf_range(-s, s)
	_tp_camera.rotation.z = _roll + _slide_tilt * 0.5
	if camera_mode == CameraMode.THIRD_PERSON and not _pov_forced:
		# A wall behind you pulls the camera in: hide your own head (or all of you) so it never
		# fills the screen.
		var arm := _spring_arm.get_hit_length()
		model.visible = arm > 0.95
		model.set_first_person(arm < 1.3)
	else:
		model.visible = true
	_tick_heartbeat(delta)


func _apply_look(look: Vector2, keys: Vector2) -> void:
	_yaw -= look.x + keys.x
	var pitch_in := look.y * (-1.0 if Settings.invert_y else 1.0)
	_pitch = clampf(_pitch - pitch_in + keys.y, -PITCH_LIMIT, PITCH_LIMIT)


## Eases the local view toward the monster whose grab_peer is us (grab_peer reaches every peer).
func _turn_toward_grabber(delta: float, rate: float) -> void:
	var grabber: Node3D = null
	var candidates := get_tree().get_nodes_in_group("monster") + get_tree().get_nodes_in_group("custodian")
	for m in candidates:
		var gp: Variant = m.get("grab_peer")
		if m is Node3D and gp != null and int(gp) == peer_id:
			grabber = m as Node3D
			break
	if grabber == null:
		return
	var head := grabber.global_position + Vector3(0.0, 1.5, 0.0)
	if grabber.has_method("face_point"):
		head = grabber.call("face_point")
	elif grabber.has_method("head_point"):
		head = grabber.call("head_point")
	elif grabber.has_method("stain_point"):
		head = grabber.call("stain_point")
	var eye := _visual_position() + Vector3(0.0, _eye_h, 0.0)
	var to := head - eye
	var flat := Vector2(to.x, to.z).length()
	if flat < 0.05 and absf(to.y) < 0.05:
		return
	var want_yaw := atan2(-to.x, -to.z)
	var want_pitch := clampf(atan2(to.y, maxf(flat, 0.01)), -PITCH_LIMIT, PITCH_LIMIT)
	var k := 1.0 - exp(-rate * delta)
	_yaw += wrapf(want_yaw - _yaw, -PI, PI) * k
	_pitch = lerpf(_pitch, want_pitch, k)


func _tick_heartbeat(delta: float) -> void:
	var period := 0.0
	var hunter: Node3D = null
	var grabbed := (synced_flags & SFLAG_GRABBED) != 0
	if grabbed:
		period = 0.45
	else:
		for c in get_tree().get_nodes_in_group("monster"):
			if c.get("hunt_peer") == peer_id:
				period = 0.8
				if c is Node3D and (c as Node3D).global_position.distance_to(global_position) < CHASE_RANGE \
						and (not c.has_method("is_chasing") or bool(c.call("is_chasing"))):
					hunter = c as Node3D
	_tick_chase(delta, hunter, grabbed)
	if period <= 0.0:
		_heartbeat_t = 0.0
		return
	_heartbeat_t -= delta
	if _heartbeat_t <= 0.0:
		_heartbeat_t = period
		Sfx.play(self, "heartbeat", -2.0)


## The chase music: in while something close is hunting you (or has you), at that monster's own
## pitch, and out slowly once it gives up.
func _tick_chase(delta: float, hunter: Node3D, grabbed: bool) -> void:
	if Sfx.is_silent():
		return
	var want := 1.0 if hunter != null or grabbed else 0.0
	_chase_level = move_toward(_chase_level, want, delta * (CHASE_FADE_IN if want > _chase_level else CHASE_FADE_OUT))
	if _chase_level <= 0.0:
		if _chase_player != null and _chase_player.playing:
			_chase_player.stop()
		return
	if _chase_player == null:
		_chase_player = AudioStreamPlayer.new()
		_chase_player.stream = Sfx.stream("chase")
		add_child(_chase_player)
	if hunter != null:
		for g: String in CHASE_PITCH:
			if hunter.is_in_group(g):
				_chase_player.pitch_scale = CHASE_PITCH[g]
	_chase_player.volume_db = CHASE_DB + linear_to_db(_chase_level)
	if not _chase_player.playing:
		_chase_player.play()


## Where the body should be drawn this frame: between the last two physics positions.
func _visual_position() -> Vector3:
	if _phys_prev.distance_to(_phys_curr) > 2.0:
		return _phys_curr
	return _phys_prev.lerp(_phys_curr, clampf(Engine.get_physics_interpolation_fraction(), 0.0, 1.0))


func _update_visuals(delta: float) -> void:
	_tick_breath(delta)
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
	var sliding := (synced_flags & SFLAG_SLIDING) != 0
	if sliding and not model.is_sliding():
		Sfx.play_at(self, "scrape", global_position, -4.0, randf_range(1.1, 1.3), 30.0)
	var yaw := body_yaw if multiplayer.is_server() else synced_yaw
	var p := _pitch if is_local else synced_pitch
	var yw := _yaw if is_local else synced_yaw
	model.set_held_item(held_item_id)
	model.set_talking((synced_flags & SFLAG_TALKING) != 0)
	var aiming := held_item_id == "pistol" or (held_item_id == "flashlight" and using)
	if aiming:
		yaw = yw  # turn to face where you point it
	model.animate(delta, _visual_vel, yaw, grounded, bracing, grabbed, mantling, aiming, p, sliding)
	# Knocked flat, the whole body goes over on its back (thrown, it tips partway).
	var down_want := 1.0 if (synced_flags & SFLAG_DOWNED) != 0 else (0.35 if (synced_flags & SFLAG_KNOCKED) != 0 else 0.0)
	_down_amt = lerpf(_down_amt, down_want, 1.0 - exp(-10.0 * delta))
	model.rotation.x = 1.45 * _down_amt
	# Flashlight beam follows your view (local) or the replicated aim (everyone else).
	var on := held_item_id == "flashlight" and using
	_flashlight.visible = on
	if on:
		_flashlight.light_volumetric_fog_energy = beam_fog
		var b := Basis.from_euler(Vector3(p, yw, 0.0))
		_flashlight.global_transform = Transform3D(b, vis + Vector3(0.0, (1.0 if bracing else 1.45), 0.0) + b * Vector3(0.22, -0.1, -0.3))
	var jet_on := held_item_id == "jetpack" and using
	_jet_fx.emitting = jet_on
	if jet_on:
		Sfx.start_loop(_jet_sound)
	elif _jet_sound.playing:
		_jet_sound.stop()
	# The capsule follows the replicated crouch (or slide) on every peer, so collisions match what you see.
	_apply_capsule(bracing or sliding)


func _apply_capsule(crouched: bool) -> void:
	if _shape == null:
		return
	var cap := _shape.shape as CapsuleShape3D
	if cap == null:
		return
	var want := CROUCH_HEIGHT if crouched else STAND_HEIGHT
	if absf(cap.height - want) < 0.001:
		return
	# Every player shares the scene's capsule resource: give this body its own before resizing.
	if cap.resource_local_to_scene == false and _shape.shape.get_reference_count() > 1:
		cap = cap.duplicate() as CapsuleShape3D
		_shape.shape = cap
	cap.height = want
	_shape.position.y = want * 0.5  # feet stay on the floor


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
	flags |= (input.use_count() & 0xFF) << USE_SEQ_SHIFT
	flags |= (input.slot_count() & 0xFF) << SLOT_SEQ_SHIFT
	flags |= (input.slot_request() & 0x7) << SLOT_REQ_SHIFT
	flags |= (input.reload_count() & 0xFF) << RELOAD_SEQ_SHIFT
	if multiplayer.is_server():
		_apply_input(move, _yaw, _pitch, flags)
	else:
		rpc_input.rpc_id(1, move, _yaw, _pitch, flags)


## Server: a wrench swing, played on every peer's copy of the body.
@rpc("authority", "call_local", "reliable")
func rpc_swing() -> void:
	model.swing()


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
	var use := (flags >> USE_SEQ_SHIFT) & 0xFF
	if use != _last_use_seq:
		_use_taps += (use - _last_use_seq) & 0xFF
		_last_use_seq = use
	var slot := (flags >> SLOT_SEQ_SHIFT) & 0xFF
	if slot != _last_slot_seq:
		_last_slot_seq = slot
		var req := (flags >> SLOT_REQ_SHIFT) & 0x7
		match req:
			1, 2, 3:
				select_slot(req - 1)
			4:
				select_slot(_wheel_slot(1))
			5:
				select_slot(_wheel_slot(-1))
			6:
				if slots[KEY_SLOT] != null:
					select_slot(KEY_SLOT)
	var reload := (flags >> RELOAD_SEQ_SHIFT) & 0xFF
	if reload != _last_reload_seq:
		_reload_taps += (reload - _last_reload_seq) & 0xFF
		_last_reload_seq = reload


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
	_tick_items(delta)
	match state:
		State.MANTLE:
			_tick_mantle(delta)
		State.GRABBED:
			velocity = Vector3.ZERO
			external_velocity = Vector3.ZERO
			_tick_orphan_grab(delta)
		_:
			if _knock_t > 0.0:
				_tick_knocked(delta)
			else:
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
	var item := held_item
	if item != null and item.is_active:
		f |= SFLAG_USING_ITEM
	if (input_flags & FLAG_RUN) != 0:
		f |= SFLAG_RUNNING
	if _slide_t > 0.0 and state == State.NORMAL:
		f |= SFLAG_SLIDING
	if _winded:
		f |= SFLAG_WINDED
	if unchained:
		f |= SFLAG_UNCHAINED
	if _knock_t > 0.0 and state == State.NORMAL:
		f |= SFLAG_KNOCKED
		if _downed:
			f |= SFLAG_DOWNED
	if Voice.is_peer_talking(peer_id):
		f |= SFLAG_TALKING
	synced_flags = f


## The selected item gets the use input (held, plus any taps that arrived); the others idle
## so their cooldowns and fuel still tick.
func _tick_items(delta: float) -> void:
	var hands_free := state != State.GRABBED and _knock_t <= 0.0  # nothing in your hands works while you're thrown
	var use_held := (input_flags & FLAG_USE) != 0 and hands_free
	var taps := _use_taps if hands_free else 0
	_use_taps = 0
	var reloads := _reload_taps
	_reload_taps = 0
	for i in slots.size():
		var item := slots[i]
		if item == null:
			continue
		if i == selected_slot:
			item.server_tick(delta, use_held, taps > 0, reloads > 0)
		else:
			item.server_tick(delta, false, false, false)
	var sel := held_item
	item_charge = sel.charge() if sel != null else 0.0
	ammo_text = sel.ammo_text() if sel != null else ""


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
	_slide_cooldown = maxf(0.0, _slide_cooldown - delta)
	var brace_now := (input_flags & FLAG_BRACE) != 0
	var brace_pressed := brace_now and not _brace_was
	_brace_was = brace_now
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	# Sprint, then Ctrl: a slide. The speed carries for about a second and bleeds off on a curve,
	# the capsule is crouch-height so you fit under low things, and the chain yanks whoever you
	# slide away from exactly as a sprint does.
	if brace_pressed and on_floor and _slide_t <= 0.0 and _slide_cooldown <= 0.0 \
			and (input_flags & FLAG_RUN) != 0 and horizontal.length() >= SLIDE_MIN_SPEED and not _winded:
		_slide_t = SLIDE_TIME
		stamina = maxf(0.0, stamina - SLIDE_STAMINA)
		_slide_dir = horizontal.normalized()
		_crouched = true
		horizontal = _slide_dir * maxf(horizontal.length(), SLIDE_SPEED * _speed_multiplier())
		add_noise(NOISE_SLIDE)
	_tick_crouch(on_floor)
	var bracing := _crouched and on_floor
	var wish := Vector3(input_move.x, 0.0, input_move.y)
	var drag := clampf(hold_drag, 0.0, 1.0)
	hold_drag = 0.0
	if _slide_t > 0.0:
		_slide_t -= delta
		# Ease-out curve: fast at first, then it dies away. Steering is a nudge, not a turn.
		var u := clampf(_slide_t / SLIDE_TIME, 0.0, 1.0)
		var speed := lerpf(SLIDE_END_SPEED, SLIDE_SPEED * _speed_multiplier(), u * u) * (1.0 - drag)
		if wish.length() > 0.1:
			_slide_dir = _slide_dir.lerp(wish.normalized(), 1.5 * delta).normalized()
		horizontal = _slide_dir * speed
		if _slide_t <= 0.0 or not on_floor or speed <= SLIDE_END_SPEED + 0.01:
			_end_slide()
	else:
		var target_speed := WALK_SPEED
		if bracing:
			target_speed = SNEAK_SPEED
		elif (input_flags & FLAG_RUN) != 0 and not _winded:
			target_speed = RUN_SPEED
		target_speed *= _speed_multiplier() * (1.0 - drag)
		if on_floor and wish.length() > 0.1:
			# Split the speed into along the new heading and across it. The across part (and any of
			# it still going backwards) dies like a stop; only the along part has to build up, so a
			# change of direction at a sprint plants a foot instead of skating the old way.
			var dir := wish.normalized()
			var along := horizontal.dot(dir)
			var across := (horizontal - dir * along).move_toward(Vector3.ZERO, GROUND_TURN_DECEL * delta)
			var want_along := wish.length() * target_speed
			along = move_toward(along, want_along, (GROUND_ACCEL if along < want_along and along >= 0.0 else GROUND_DECEL) * delta)
			horizontal = dir * along + across
		else:
			horizontal = horizontal.move_toward(wish * target_speed, (GROUND_DECEL if on_floor else AIR_ACCEL) * delta)
	var sprinting := on_floor and _slide_t <= 0.0 and (input_flags & FLAG_RUN) != 0 and not _winded \
			and wish.length() > 0.1 and horizontal.length() > WALK_SPEED * 1.05
	_tick_stamina(delta, sprinting, horizontal.length())
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
	if _jump_buffer > 0.0 and on_floor and not _crouched:
		velocity.y = JUMP_VELOCITY * (1.15 if buff_state == 1 else 1.0)
		_jump_buffer = 0.0
		add_noise(NOISE_JUMP)
	var face := _slide_dir if _slide_t > 0.0 else wish
	if face.length() > 0.1:
		var want := atan2(-face.x, -face.z)
		body_yaw += clampf(wrapf(want - body_yaw, -PI, PI), -TURN_SPEED * delta, TURN_SPEED * delta)
	if not on_floor:
		_fall_speed = maxf(_fall_speed, -velocity.y)
	move_and_slide()
	var landed := is_on_floor() and not _was_on_floor
	if landed and _fall_speed > 9.0:
		add_noise(NOISE_LAND)
	if landed and _fall_speed > HARD_LAND_SPEED and multiplayer.is_server():
		# A long drop (about 9 m and more) puts you on the floor for a moment: climb down the
		# wreckage instead, or eat it with whatever's behind you.
		knock(Vector3.ZERO, clampf(0.9 + (_fall_speed - HARD_LAND_SPEED) * 0.12, 0.9, 2.2), true)
		rpc_slammed.rpc(global_position, _fall_speed)
	if is_on_floor():
		_fall_speed = 0.0
	_was_on_floor = is_on_floor()


## Server: a monster's hit. v is the throw (m/s); for `seconds` you have no control. downed:
## flat on the floor (a tackle). A fast enough throw that meets a wall slams you into it.
func knock(v: Vector3, seconds: float, downed: bool) -> void:
	if state != State.NORMAL:
		return
	velocity = v
	external_velocity = Vector3.ZERO
	_knock_t = maxf(_knock_t, seconds)
	_downed = downed
	_flung = Vector2(v.x, v.z).length() > WALL_SLAM_SPEED
	_slide_t = 0.0
	_jump_buffer = 0.0
	add_noise(40.0)


func is_downed() -> bool:
	return _knock_t > 0.0 and _downed


func is_knocked() -> bool:
	return _knock_t > 0.0


## Server: thrown or down. No input; the body flies, lands and skids; a wall at speed is a slam.
func _tick_knocked(delta: float) -> void:
	_knock_t -= delta
	velocity += external_velocity
	external_velocity = Vector3.ZERO
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if is_on_floor() and velocity.y <= 0.1:
		horizontal = horizontal.move_toward(Vector3.ZERO, KNOCK_FRICTION * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y -= GRAVITY * delta
	var speed := horizontal.length()
	move_and_slide()
	if _flung:
		for i in get_slide_collision_count():
			var c := get_slide_collision(i)
			if absf(c.get_normal().y) < 0.5 and speed > WALL_SLAM_SPEED:
				_wall_slam(c.get_position(), horizontal.normalized(), speed)
				break
		if _flung and is_on_floor() and speed < 1.0:
			_flung = false
	if _knock_t <= 0.0:
		_knock_t = 0.0
		_downed = false
		_flung = false
	_was_on_floor = is_on_floor()


## Server: you hit the wall. You bounce off a little and slump down it, dazed, and the whole floor
## heard it.
func _wall_slam(at: Vector3, dir: Vector3, speed: float) -> void:
	_flung = false
	_downed = true
	_knock_t = maxf(_knock_t, WALL_DAZE)
	velocity = -dir * 1.2 + Vector3(0.0, -1.0, 0.0)
	add_noise(80.0)
	rpc_slammed.rpc(at, speed)


## Every peer: the slam: a thud, your hat off, and for you the screen jolting.
@rpc("authority", "call_local", "reliable")
func rpc_slammed(at: Vector3, speed: float) -> void:
	Sfx.play_at(self, "slam", at, 4.0, randf_range(0.7, 0.85), 30.0)
	Sfx.play_at(self, "thump", at, 4.0, 0.6, 30.0)
	model.pop_hat(Vector3.UP * 3.0 + (global_position - at).normalized() * 2.0)
	if is_local:
		add_shake(clampf(speed / 12.0, 0.5, 1.0))
		ScreenFx.jolt(0.5)


## Every peer: the panting you hear from a body follows its stamina (louder the emptier).
func _tick_breath(delta: float) -> void:
	if _breath == null:
		return
	var winded := (synced_flags & SFLAG_WINDED) != 0
	var want := 1.0 if winded else clampf((PANT_BELOW + 0.2 - stamina) / (PANT_BELOW + 0.2), 0.0, 1.0)
	_breath_level = lerpf(_breath_level, want, 1.0 - exp(-3.0 * delta))
	if _breath_level < 0.03:
		if _breath.playing:
			_breath.stop()
		return
	_breath.volume_db = linear_to_db(_breath_level) - 2.0
	_breath.pitch_scale = 0.95 + 0.12 * _breath_level
	Sfx.start_loop(_breath)


## Server: running drains the breath, anything else brings it back (faster standing still). Run
## it dry and you are winded: no sprint, no slide, and you pant until a third of it is back.
func _tick_stamina(delta: float, sprinting: bool, speed: float) -> void:
	if debug_infinite_stamina or buff_state == 1:
		stamina = 1.0
		_winded = false
		return
	if sprinting:
		stamina = maxf(0.0, stamina - delta / SPRINT_SECONDS)
		if stamina <= 0.0:
			_winded = true
			GameState.post_tip("winded", "Out of breath: no sprinting until you get it back. And they can hear you gasping.", 3.5)
	else:
		var rate := 1.0 / RECOVER_SECONDS
		if speed > 2.6:
			rate *= 0.55
		if buff_state == 2:
			rate *= 0.5  # the drink's crash
		stamina = minf(1.0, stamina + rate * delta)
	if _winded and stamina >= WINDED_UNTIL:
		_winded = false


func is_winded() -> bool:
	return _winded


## Crouch down whenever you brace; stand back up only when there's headroom.
func _tick_crouch(on_floor: bool) -> void:
	var want := ((input_flags & FLAG_BRACE) != 0 and on_floor) or _slide_t > 0.0
	if want:
		_crouched = true
	elif _crouched and _headroom():
		_crouched = false


## The slide is over: stand up if there's headroom and Ctrl is up, else stay crouched.
func _end_slide() -> void:
	_slide_t = 0.0
	_slide_cooldown = SLIDE_COOLDOWN
	if (input_flags & FLAG_BRACE) == 0 and _headroom():
		_crouched = false


func is_sliding() -> bool:
	return _slide_t > 0.0 and state == State.NORMAL


func _headroom() -> bool:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3(0.0, CROUCH_HEIGHT - 0.1, 0.0)
	var q := PhysicsRayQueryParameters3D.create(from, global_position + Vector3(0.0, STAND_HEIGHT + 0.05, 0.0), ChainBody.LAYER_WORLD)
	q.exclude = [get_rid()]
	return space.intersect_ray(q).is_empty()


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
	if _winded or stamina < PANT_BELOW:
		target = maxf(target, NOISE_PANT)
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
	return _crouched and is_on_floor() and state == State.NORMAL and _slide_t <= 0.0


## Holding Ctrl with intent (levers, ropes, shutter chains): counts even on the tick the body is
## being pushed clear of the fixture it's leaning on, when is_on_floor() flickers.
func wants_brace() -> bool:
	return (input_flags & FLAG_BRACE) != 0 and state == State.NORMAL


func resist_value() -> float:
	if state != State.NORMAL or not is_on_floor():
		return 0.0
	return 2.0 if is_bracing() else 1.0


func teleport_to(pos: Vector3, yaw: float) -> void:
	super.teleport_to(pos, yaw)
	body_yaw = yaw
	synced_yaw = yaw
	input_yaw = yaw  # the aim follows the body: a respawned player faces the room, not where they last looked
	input_pitch = 0.0
	if state == State.GRABBED and grabbed_by != null and grabbed_by.has_method("release"):
		grabbed_by.call("release", false)
	state = State.NORMAL
	grabbed_by = null
	_jump_buffer = 0.0
	_fall_speed = 0.0
	_slide_t = 0.0
	noise = 0.0


func grab_start(by: Node) -> void:
	if state != State.GRABBED:
		_grab_origin = global_position
	_knock_t = 0.0
	_downed = false
	_flung = false
	state = State.GRABBED
	grabbed_by = by
	_orphan_grab_t = 0.0
	velocity = Vector3.ZERO
	_slide_t = 0.0


func grab_end() -> void:
	if state == State.GRABBED:
		state = State.NORMAL
		# A monster can let go with you lifted into the ceiling tiles or pressed into a wall; a
		# capsule left inside the world can't move again. Back to where it caught you.
		if _capsule_blocked(global_position) and not _capsule_blocked(_grab_origin):
			global_position = _grab_origin
			synced_position = global_position
	grabbed_by = null
	_orphan_grab_t = 0.0
	_fall_speed = 0.0
	velocity = Vector3(0.0, -1.0, 0.0)


## Server: held, but the monster that grabbed you is gone or says it holds someone else (two
## grabbed the same player and one let go, a floor reset, a freed node). Never stay pinned to nothing.
func _tick_orphan_grab(delta: float) -> void:
	var holder := grabbed_by
	var holds := holder != null and is_instance_valid(holder) and holder.is_inside_tree()
	if holds:
		var gp: Variant = holder.get("grab_peer")
		holds = gp == null or int(gp) == peer_id
	if holds:
		_orphan_grab_t = 0.0
		return
	_orphan_grab_t += delta
	if _orphan_grab_t >= ORPHAN_GRAB_TIME:
		grab_end()


## True when this body's capsule, stood at pos, would overlap level geometry.
func _capsule_blocked(pos: Vector3) -> bool:
	if _shape == null or _shape.shape == null or not is_inside_tree():
		return false
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _shape.shape
	# A few cm up: standing on the floor isn't being stuck in it.
	q.transform = Transform3D(_shape.basis, pos + _shape.position + Vector3(0.0, 0.06, 0.0))
	q.collision_mask = ChainBody.LAYER_WORLD
	q.exclude = [get_rid()]
	return not get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


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
	return global_position + Vector3(0.0, 1.15 if _crouched else 1.6, 0.0)


func aim_direction() -> Vector3:
	return Basis.from_euler(Vector3(input_pitch, input_yaw, 0.0)) * Vector3.FORWARD


# --- Items (server) ---------------------------------------------------------------------

func has_item(id: String) -> bool:
	for item in slots:
		if item != null and item.data.id == id:
			return true
	return false


func find_item(id: String) -> ItemBase:
	for item in slots:
		if item != null and item.data.id == id:
			return item
	return null


## The mouse wheel walks the loot slots, and the key's slot too when you carry it.
func _wheel_slot(step: int) -> int:
	var n := SLOTS if slots[KEY_SLOT] != null else ITEM_SLOTS
	return (mini(selected_slot, n - 1) + step + n) % n


## Server: off the Line (or back on it). The chain is rebuilt on every peer from SFLAG_UNCHAINED.
func set_unchained(on: bool) -> void:
	if unchained == on:
		return
	unchained = on
	if on:
		synced_flags |= SFLAG_UNCHAINED
	else:
		synced_flags &= ~SFLAG_UNCHAINED


## Every peer: is this body off the Line? (The server knows; clients read the replicated flag.)
func is_unchained() -> bool:
	return unchained if multiplayer.is_server() else (synced_flags & SFLAG_UNCHAINED) != 0


## The second player to clock in carries the Shackle Key, in its own slot.
func _grant_key() -> void:
	if join_index != KEY_HOLDER or has_item("shackle_key"):
		return
	var data := ItemRegistry.get_data("shackle_key")
	if data != null:
		server_give_item(data.create_logic())


func free_slot() -> int:
	for i in ITEM_SLOTS:
		if slots[i] == null:
			return i
	return -1


## The office run hands every player a flashlight and a wrench (the Break Room used to have one
## flashlight between the whole Line); a late joiner gets them too, and the flashlight stays in
## hand. The Loading Lot keeps its own stash.
func _grant_starting_kit() -> void:
	var level := get_tree().get_first_node_in_group("level")
	if not (level is LevelStack or level is Manor):
		return
	for id: String in STARTING_KIT:
		var data := ItemRegistry.get_data(id)
		if data != null and not has_item(id):
			server_give_item(data.create_logic())
	select_slot(0)


## Puts an item in the first free slot and selects it. False when every slot is full.
func server_give_item(item: ItemBase) -> bool:
	if state == State.GRABBED:
		return false
	# The Shackle Key has a slot of its own and never takes the one in your hand.
	if item.data.id == "shackle_key":
		if slots[KEY_SLOT] != null:
			return false
		slots[KEY_SLOT] = item
		item.name = "Item_%d_%s" % [KEY_SLOT, item.data.id]
		add_child(item)
		item.on_equip(self)
		_refresh_slot_ids()
		return true
	# Ammo goes straight into a carried gun instead of taking a slot.
	if item.has_method("merge_into") and bool(item.call("merge_into", self)):
		return true
	var i := free_slot()
	if i < 0:
		return false
	slots[i] = item
	item.name = "Item_%d_%s" % [i, item.data.id]
	add_child(item)
	item.on_equip(self)
	select_slot(i)
	_refresh_slot_ids()
	return true


func select_slot(i: int) -> void:
	i = clampi(i, 0, SLOTS - 1)
	if i == selected_slot:
		return
	var old := held_item
	if old != null:
		old.on_deselect()
	selected_slot = i
	var now := held_item
	if now != null:
		now.on_select()
	_refresh_slot_ids()


## Drops the selected item. With spawn_pickup it lands in front of you for anyone to grab;
## without it the item is used up.
func server_drop_item(spawn_pickup: bool = true) -> void:
	var item := held_item
	if item == null:
		return
	if selected_slot == KEY_SLOT:
		return  # the key is yours for the run
	var id := item.data.id
	item.on_unequip()
	item.queue_free()
	slots[selected_slot] = null
	_refresh_slot_ids()
	if spawn_pickup:
		var fwd := Vector3(-sin(body_yaw), 0.0, -cos(body_yaw))
		Net.spawn_pickup(id, global_position + fwd * 0.9 + Vector3(0.0, 0.2, 0.0), peer_id, item.carry_state())
	# Fall back to another carried item so the hands aren't empty.
	if free_slot() == selected_slot:
		for k in slots.size():
			if slots[k] != null:
				select_slot(k)
				break


## Drops everything (a layoff does not: items survive respawns, only grabs make you drop).
func server_drop_all(spawn_pickups: bool = true) -> void:
	for k in ITEM_SLOTS:
		if slots[k] != null:
			select_slot(k)
			server_drop_item(spawn_pickups)


## Takes every carried `id` away for good, keeping whatever else was in hand (the helicopter's pilot
## keeps the jetpacks). True if there was one.
func server_take_items(id: String) -> bool:
	var keep := selected_slot
	var took := false
	for k in ITEM_SLOTS:
		if slots[k] != null and slots[k].data.id == id:
			select_slot(k)
			server_drop_item(false)
			took = true
	if took and slots[keep] != null:
		select_slot(keep)
	return took


func _refresh_slot_ids() -> void:
	var ids := PackedStringArray()
	for item in slots:
		ids.append(item.data.id if item != null else "")
	slot_ids = ids
	var sel := held_item
	held_item_id = sel.data.id if sel != null else ""
	item_charge = sel.charge() if sel != null else 0.0
	ammo_text = sel.ammo_text() if sel != null else ""
