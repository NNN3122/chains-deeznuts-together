class_name Dumbwaiter
extends AnimatableBody3D
## The dumbwaiter: a 1.3 m car on a hand rope in a shaft from the Dining Hall up to the Kitchen.
## One rider at a time. It climbs while someone BRACES (Ctrl) at the rope, at the bottom or the
## top; let go and it sinks. Everyone else is on 5 m of chain to the rider, so the hauler steps
## in as the car rises, and whoever rode up hauls from the top for the next one.
## Solo: the rope latches when you brace at it (nobody can hold it for you), and your Ballast is
## dragged up the shaft on the chain behind you.
## The server moves it; its height is replicated.

const SIZE: float = 1.3  # car width, meters
const RISE_SPEED: float = 0.75  # m/s when hauled
const SINK_SPEED: float = 0.55  # m/s with a rider but nobody on the rope
const RETURN_SPEED: float = 1.2  # m/s empty
const HAUL_RADIUS: float = 1.6  # m from a rope point a bracing player counts as hauling
const MAX_RIDERS: int = 1

var low_y: float = 0.0
var high_y: float = 0.0
var rope_points: Array[Vector3] = []  # where to brace: bottom landing and top landing
var synced_y: float = 0.0  # replicated
var hauled: bool = false  # replicated (HUD / sound)
var overloaded: bool = false  # replicated: too many riders
var _area: Area3D
var _latched: bool = false
var _motor: AudioStreamPlayer3D
var _last_y: float = 0.0
var _klaxon_t: float = 0.0


static func create(node_name: String, bottom_center: Vector3, rise: float, ropes: Array[Vector3]) -> Dumbwaiter:
	var d := Dumbwaiter.new()
	d.name = node_name
	d.position = bottom_center
	d.low_y = bottom_center.y
	d.high_y = bottom_center.y + rise
	d.synced_y = bottom_center.y
	d.rope_points = ropes
	return d


func _enter_tree() -> void:
	if has_node("Sync"):
		return
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	for prop in ["synced_y", "hauled", "overloaded"]:
		var path := NodePath(".:" + prop)
		cfg.add_property(path)
		cfg.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	sync.replication_config = cfg
	add_child(sync)


func _ready() -> void:
	sync_to_physics = true
	collision_layer = ChainBody.LAYER_WORLD
	collision_mask = 0
	# Floor plate (2 cm proud of the landing, so a rider stands on the car and not the floor),
	# three low walls (open toward -z), a roof hoop the rope runs through.
	_part(Vector3(0.0, -0.05, 0.0), Vector3(SIZE, 0.14, SIZE), "steel")
	_part(Vector3(0.0, 0.5, SIZE * 0.5 - 0.02), Vector3(SIZE, 1.0, 0.04), "steel_dark")
	for s: float in [-1.0, 1.0]:
		_part(Vector3(s * (SIZE * 0.5 - 0.02), 0.5, 0.0), Vector3(0.04, 1.0, SIZE), "steel_dark")
	_part(Vector3(0.0, 1.9, 0.0), Vector3(0.3, 0.06, 0.3), "brass", false)
	var rope := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 0.025
	rm.bottom_radius = 0.025
	rm.height = 12.0
	rope.mesh = rm
	rope.position = Vector3(0.0, 6.0, 0.0)
	rope.material_override = LevelKit.mat("rope")
	add_child(rope)
	_area = Area3D.new()
	_area.collision_layer = 0
	_area.collision_mask = ChainBody.LAYER_BODIES
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(SIZE - 0.1, 1.6, SIZE - 0.1)
	cs.shape = bs
	cs.position = Vector3(0.0, 0.8, 0.0)
	_area.add_child(cs)
	add_child(_area)
	_motor = Sfx.loop_player("scrape", -10.0, 20.0)
	_motor.pitch_scale = 0.7
	add_child(_motor)
	_last_y = position.y


func _part(at: Vector3, size: Vector3, key: String, collide: bool = true) -> void:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.position = at
	m.material_override = LevelKit.mat(key)
	add_child(m)
	if collide:
		var c := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = size
		c.shape = b
		c.position = at
		add_child(c)


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
	if overloaded:
		_klaxon_t -= delta
		if _klaxon_t <= 0.0:
			_klaxon_t = 1.4
			Sfx.play_at(self, "klaxon", global_position + Vector3.UP, -8.0, 1.3, 20.0)


func _server_tick(delta: float) -> void:
	var on_board := riders()
	var solo := Net.get_players().size() <= 1
	var n := 0
	for p in Net.get_players():
		if not p.wants_brace():
			continue
		for rp in rope_points:
			if p.global_position.distance_to(rp) < HAUL_RADIUS:
				n += 1
				break
		if solo and n == 0 and on_board.has(p):
			n += 1  # solo: haul yourself hand over hand from inside the car
	if solo and n > 0:
		_latched = true
	var people := 0
	for b in on_board:
		if b is Player:
			people += 1
	overloaded = people > MAX_RIDERS
	hauled = (n > 0 or _latched) and not overloaded
	var target := position.y
	if hauled:
		target = high_y
	elif on_board.is_empty():
		target = low_y
		_latched = false
	else:
		target = low_y  # a rider with nobody on the rope sinks
	var speed := RISE_SPEED if target > position.y else (RETURN_SPEED if on_board.is_empty() else SINK_SPEED)
	position.y = move_toward(position.y, target, speed * delta)
	if _latched and position.y >= high_y - 0.01 and on_board.is_empty():
		_latched = false
	synced_y = position.y


## Server: back to the bottom (layoff).
func server_reset() -> void:
	position.y = low_y
	synced_y = low_y
	_latched = false
