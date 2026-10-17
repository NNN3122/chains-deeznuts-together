class_name StageLift
extends AnimatableBody3D
## The stage lift: a 2.4 m platform that rises from the kitchen's back hall up into the stage
## wing. It runs only while someone BRACES at the control box beside it (a lever you have to
## lean on), drinks 1% of the power bank per second on the way up, and is rated for three bodies:
## a fourth stalls it with a klaxon Pappy can hear from anywhere on the floor. Let go of the lever
## and it sinks, so the last person down rides it up on the chain: the riders at the top hoist.
## Solo: the lever latches (like the plate in the Yellow Rooms). Server moves it; height replicated.

const SPEED: float = 0.6  # m/s rising
const SINK_SPEED: float = 0.9
const SIZE: Vector3 = Vector3(2.4, 0.3, 2.4)
const LEVER_RADIUS: float = 1.5
const MAX_LOAD: int = 3
const DRAIN_PER_SECOND: float = 1.0  # % of the power bank while rising
const START_DELAY: float = 0.8  # s of holding the lever before it moves

var low_y: float = 0.0
var high_y: float = 0.0
var lever_point: Vector3 = Vector3.ZERO
var synced_y: float = 0.0  # replicated
var powered: bool = false  # replicated: lever held (or latched) and power left
var overloaded: bool = false  # replicated
var _area: Area3D
var _latched: bool = false
var _held_for: float = 0.0
var _motor: AudioStreamPlayer3D
var _last_y: float = 0.0
var _klaxon_t: float = 0.0
var _lever: MeshInstance3D
var _lever_shown: bool = false
var _get_power: Callable = Callable()
var _drain: Callable = Callable()


static func create(node_name: String, center: Vector3, rise: float, lever: Vector3) -> StageLift:
	var l := StageLift.new()
	l.name = node_name
	l.position = center
	l.low_y = center.y
	l.high_y = center.y + rise
	l.synced_y = center.y
	l.lever_point = lever
	return l


## Hooks into the floor's power bank: get_power() -> float, drain(amount: float).
func bind_power(get_power: Callable, drain: Callable) -> void:
	_get_power = get_power
	_drain = drain


func _enter_tree() -> void:
	if has_node("Sync"):
		return
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	for prop in ["synced_y", "powered", "overloaded"]:
		var path := NodePath(".:" + prop)
		cfg.add_property(path)
		cfg.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	sync.replication_config = cfg
	add_child(sync)


func _ready() -> void:
	sync_to_physics = true
	collision_layer = ChainBody.LAYER_WORLD
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = SIZE
	shape.shape = box
	add_child(shape)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = SIZE
	mesh.mesh = bm
	mesh.material_override = LevelKit.mat("stage_wood")
	add_child(mesh)
	for s: float in [-1.0, 1.0]:
		for stripe_axis in 2:
			var st := MeshInstance3D.new()
			var sm := BoxMesh.new()
			sm.size = Vector3(SIZE.x, 0.02, 0.12) if stripe_axis == 0 else Vector3(0.12, 0.02, SIZE.z)
			st.mesh = sm
			st.material_override = LevelKit.mat("hazard")
			st.position = Vector3(0.0, SIZE.y * 0.5 + 0.01, s * (SIZE.z * 0.5 - 0.1)) if stripe_axis == 0 else Vector3(s * (SIZE.x * 0.5 - 0.1), SIZE.y * 0.5 + 0.01, 0.0)
			add_child(st)
	_area = Area3D.new()
	_area.collision_layer = 0
	_area.collision_mask = ChainBody.LAYER_BODIES
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(SIZE.x - 0.1, 1.8, SIZE.z - 0.1)
	cs.shape = bs
	cs.position = Vector3(0.0, SIZE.y * 0.5 + 0.9, 0.0)
	_area.add_child(cs)
	add_child(_area)
	_motor = Sfx.loop_player("lift", -5.0, 25.0)
	_motor.pitch_scale = 0.8
	add_child(_motor)
	_last_y = position.y
	# Control box with a lever, on the wall beside the shaft (world space: it doesn't ride).
	var box_root := Node3D.new()
	box_root.name = "ControlBox"
	box_root.top_level = true
	add_child(box_root)
	box_root.global_position = lever_point
	var cab := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(0.5, 0.7, 0.3)
	cab.mesh = cm
	cab.position = Vector3(0.0, 1.1, 0.0)
	cab.material_override = LevelKit.mat("steel_dark")
	box_root.add_child(cab)
	var body := StaticBody3D.new()
	body.collision_layer = ChainBody.LAYER_WORLD
	var bcs := CollisionShape3D.new()
	var bbs := BoxShape3D.new()
	bbs.size = Vector3(0.5, 0.7, 0.3)
	bcs.shape = bbs
	bcs.position = Vector3(0.0, 1.1, 0.0)
	body.add_child(bcs)
	box_root.add_child(body)
	_lever = MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(0.05, 0.4, 0.05)
	_lever.mesh = lm
	_lever.position = Vector3(0.0, 1.3, -0.2)
	_lever.rotation = Vector3(0.6, 0.0, 0.0)
	_lever.material_override = LevelKit.mat("hazard")
	box_root.add_child(_lever)
	var knob := MeshInstance3D.new()
	var km := SphereMesh.new()
	km.radius = 0.06
	km.height = 0.12
	knob.mesh = km
	knob.position = Vector3(0.0, 0.2, 0.0)
	knob.material_override = LevelKit.mat("vending")
	_lever.add_child(knob)


func riders() -> Array[ChainBody]:
	var out: Array[ChainBody] = []
	for b in _area.get_overlapping_bodies():
		if b is ChainBody:
			out.append(b)
	return out


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		_server_tick(delta)
	else:
		position.y = synced_y
	var moving := absf(position.y - _last_y) > 0.0005
	_last_y = position.y
	if moving:
		Sfx.start_loop(_motor)
	elif _motor.playing:
		_motor.stop()
	if powered != _lever_shown:
		_lever_shown = powered
		var tw := create_tween()
		tw.tween_property(_lever, "rotation:x", -0.6 if powered else 0.6, 0.25)
		Sfx.play_at(self, "click", lever_point + Vector3.UP * 1.3, 0.0, 0.7 if powered else 0.5)
	if overloaded:
		_klaxon_t -= delta
		if _klaxon_t <= 0.0:
			_klaxon_t = 1.4
			Sfx.play_at(self, "klaxon", global_position + Vector3.UP, 0.0, 1.0, 40.0)


func _server_tick(delta: float) -> void:
	var held := false
	for p in Net.get_players():
		if p.wants_brace() and p.global_position.distance_to(lever_point) < LEVER_RADIUS:
			held = true
			break
	var solo := Net.get_players().size() <= 1
	if held and solo:
		_latched = true
	_held_for = _held_for + delta if (held or _latched) else 0.0
	var on_board := riders()
	overloaded = on_board.size() > MAX_LOAD
	var power: float = _get_power.call() if _get_power.is_valid() else 100.0
	powered = _held_for >= START_DELAY and power > 0.0 and not overloaded
	if powered and position.y < high_y:
		position.y = move_toward(position.y, high_y, SPEED * delta)
		if _drain.is_valid():
			_drain.call(DRAIN_PER_SECOND * delta)
	elif not powered and not _latched:
		position.y = move_toward(position.y, low_y, SINK_SPEED * delta)
	if _latched and position.y >= high_y - 0.01 and on_board.is_empty():
		_latched = false  # solo: it sinks for the Ballast once you've stepped off
	synced_y = position.y


func is_rising() -> bool:
	return powered and position.y < high_y - 0.01


## Someone is on the lever (or it's latched) and the lift isn't at the top yet.
func wants_power() -> bool:
	return _held_for > 0.0 and position.y < high_y - 0.01


func server_reset() -> void:
	position.y = low_y
	synced_y = low_y
	_latched = false
	_held_for = 0.0
