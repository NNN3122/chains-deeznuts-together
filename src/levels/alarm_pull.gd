class_name AlarmPull
extends Node3D
## A red fire-alarm pull station on the wall a couple of rooms before B3's service lift. The lift
## is locked out until the alarm releases it: stand at the station and hold Ctrl for a moment.
## Then the klaxon runs for ALARM_SECONDS, the tubes on the floor strobe, and every Hollow Hire
## on the floor is awake and hunting for the same stretch. One holds the plate, the rest ride,
## and the hoist happens with the floor coming for you.
## Server decides "pulled" and the clock (replicated); every peer plays the klaxon and strobe.

const PULL_TIME: float = 0.6  # s of holding Ctrl at it
const HOLD_RADIUS: float = 1.5  # m from the handle
const ALARM_SECONDS: float = 40.0

var level: YellowRooms
var floor_index: int = 0
var on_pulled: Callable = Callable()
var pulled: bool = false  # replicated
var seconds_left: float = 0.0  # replicated: of the alarm
var _hold_t: float = 0.0
var _klaxon: AudioStreamPlayer3D
var _strobe: OmniLight3D
var _handle: MeshInstance3D
var _told_msec: int = -100000


static func create(node_name: String, at: Vector3, wall_normal: Vector3) -> AlarmPull:
	var a := AlarmPull.new()
	a.name = node_name
	a.position = at  # on the wall face at floor level
	a.rotation.y = atan2(wall_normal.x, wall_normal.z)  # local +z points out from the wall
	return a


func _enter_tree() -> void:
	if has_node("Sync"):
		return
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	for prop in ["pulled", "seconds_left"]:
		var path := NodePath(".:" + prop)
		cfg.add_property(path)
		cfg.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	sync.replication_config = cfg
	add_child(sync)


func _ready() -> void:
	add_to_group("alarm_pulls")
	var box := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.3, 0.36, 0.1)
	box.mesh = bm
	box.position = Vector3(0.0, 1.3, 0.05)
	box.material_override = LevelKit.mat("extinguisher")
	add_child(box)
	_handle = MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.2, 0.1, 0.05)
	_handle.mesh = hm
	_handle.position = Vector3(0.0, 1.22, 0.12)
	_handle.material_override = LevelKit.mat("white")
	add_child(_handle)
	var plate := Label3D.new()
	plate.text = "FIRE\nALARM"
	plate.font_size = 26
	plate.pixel_size = 0.0032
	plate.modulate = Color(1.0, 1.0, 1.0)
	plate.outline_size = 0
	plate.double_sided = false
	plate.position = Vector3(0.0, 1.4, 0.102)
	add_child(plate)
	var tag := Label3D.new()
	tag.text = "LIFT LOCKED OUT\nPULL THE ALARM\nHOLD CTRL HERE"
	tag.font_size = 26
	tag.pixel_size = 0.004
	tag.modulate = Color(1.0, 0.85, 0.3)
	tag.outline_size = 8
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.position = Vector3(0.0, 2.0, 0.5)
	add_child(tag)
	_strobe = OmniLight3D.new()
	_strobe.light_color = Color(1.0, 0.1, 0.05)
	_strobe.light_energy = 0.0
	_strobe.omni_range = 9.0
	_strobe.position = Vector3(0.0, 2.6, 0.4)
	add_child(_strobe)
	_klaxon = Sfx.loop_player("klaxon", -4.0, 40.0)
	_klaxon.position = Vector3(0.0, 2.4, 0.2)
	add_child(_klaxon)


func handle_point() -> Vector3:
	return global_position + global_transform.basis.z * 0.5 + Vector3(0.0, 1.2, 0.0)


func sounding() -> bool:
	return pulled and seconds_left > 0.0


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		_server_tick(delta)
	var on := sounding()
	if on:
		Sfx.start_loop(_klaxon)
		_strobe.light_energy = 2.5 if fmod(seconds_left, 0.5) < 0.12 else 0.0
	else:
		if _klaxon.playing:
			_klaxon.stop()
		_strobe.light_energy = 0.0
	_handle.position.y = 1.08 if pulled else 1.22


func _server_tick(delta: float) -> void:
	if pulled:
		seconds_left = maxf(0.0, seconds_left - delta)
		return
	var holding := false
	var near := false
	var hp := handle_point()
	for p in Net.get_players():
		if p.global_position.distance_to(hp) > HOLD_RADIUS or absf(p.global_position.y - global_position.y) > 1.5:
			continue
		near = true
		if p.wants_brace():
			holding = true
	if near and not holding and Time.get_ticks_msec() - _told_msec > 4000:
		_told_msec = Time.get_ticks_msec()
		GameState.post_message("FIRE ALARM: hold Ctrl here to pull it. It releases the lift. It also wakes the floor.", 3.5)
	_hold_t = _hold_t + delta if holding else maxf(0.0, _hold_t - delta * 2.0)
	if _hold_t >= PULL_TIME:
		server_pull()


## Server: the handle comes down.
func server_pull() -> void:
	if pulled:
		return
	pulled = true
	seconds_left = ALARM_SECONDS
	if on_pulled.is_valid():
		on_pulled.call()
	if level != null:
		level.wake_floor(floor_index, global_position, ALARM_SECONDS)
		level.floor_strobe(floor_index, ALARM_SECONDS)
	_rpc_pulled.rpc()
	GameState.post_message("FIRE ALARM. The lift is live. So is everything else on this floor: %d seconds of it. GO." % int(ALARM_SECONDS), 4.0)


@rpc("authority", "call_local", "reliable")
func _rpc_pulled() -> void:
	Sfx.play_at(self, "click", handle_point(), 2.0, 0.5)
	Sfx.caption(self, "the fire alarm", global_position)
