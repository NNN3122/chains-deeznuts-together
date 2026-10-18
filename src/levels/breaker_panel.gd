class_name BreakerPanel
extends Node3D
## A breaker panel on an office wall, one per floor, somewhere off the route. When the floor's
## power stutters out (or a lights-out scare kills it) the panel crackles and spits sparks in the
## dark; two cracks of a wrench (it is "repairable") bring the lights back early, loudly. Whether
## it needs fixing is worked out on every peer from the floor's lights, so nothing extra is synced;
## the hits are counted on the server.

const HITS_TO_FIX: int = 2
const SPARK_EVERY: Vector2 = Vector2(0.35, 1.3)  # s between crackles while the power is out
const SIZE: Vector3 = Vector3(0.55, 0.75, 0.14)  # m

var floor_index: int = 0
var level: YellowRooms
var _hits: int = 0
var _led_mat: StandardMaterial3D
var _glow: OmniLight3D
var _buzz: AudioStreamPlayer3D
var _spark_t: float = 0.0
var _was_broken: bool = false


## A panel whose back sits at `at` on a wall, facing into the room along `facing`.
static func create(node_name: String, at: Vector3, facing: Vector3, floor_i: int, lvl: YellowRooms) -> BreakerPanel:
	var p := BreakerPanel.new()
	p.name = node_name
	p.floor_index = floor_i
	p.level = lvl
	p.transform = Transform3D(Basis.looking_at(-facing, Vector3.UP), at)
	return p


func _ready() -> void:
	add_to_group("repairable")
	_part(Vector3(0.0, 0.0, SIZE.z * 0.5), SIZE, LevelKit.mat("steel_dark"))
	_part(Vector3(0.0, 0.0, SIZE.z + 0.002), Vector3(0.008, SIZE.y - 0.08, 0.004), LevelKit.mat("fixture"))  # door seam
	_part(Vector3(0.2, 0.0, SIZE.z + 0.015), Vector3(0.03, 0.12, 0.03), LevelKit.mat("fixture"))  # latch
	_part(Vector3(0.0, -SIZE.y * 0.5 + 0.06, SIZE.z + 0.003), Vector3(SIZE.x - 0.04, 0.05, 0.004), LevelKit.mat("hazard"))
	var led := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.014
	sm.height = 0.028
	sm.radial_segments = 12
	sm.rings = 6
	led.mesh = sm
	_led_mat = StandardMaterial3D.new()
	_led_mat.emission_enabled = true
	_led_mat.albedo_color = Color(0.1, 0.4, 0.1)
	_led_mat.emission = Color(0.1, 0.6, 0.15)
	_led_mat.emission_energy_multiplier = 0.4
	led.material_override = _led_mat
	led.position = Vector3(-0.2, SIZE.y * 0.5 - 0.08, SIZE.z + 0.01)
	add_child(led)
	_glow = OmniLight3D.new()
	_glow.light_color = Color(1.0, 0.6, 0.25)
	_glow.light_energy = 0.0
	_glow.omni_range = 3.0
	_glow.position = Vector3(0.0, 0.0, SIZE.z + 0.25)
	add_child(_glow)
	var body := StaticBody3D.new()
	body.collision_layer = ChainBody.LAYER_WORLD
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = SIZE
	shape.shape = box
	shape.position = Vector3(0.0, 0.0, SIZE.z * 0.5)
	body.add_child(shape)
	add_child(body)
	_buzz = Sfx.loop_player("hum", -16.0, 9.0)
	_buzz.pitch_scale = 0.55
	_buzz.position = Vector3(0.0, 0.0, 0.3)
	add_child(_buzz)


func _part(at: Vector3, size: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = at
	add_child(mi)


## Where the wrench aims: the face of the door.
func fix_point() -> Vector3:
	return global_transform * Vector3(0.0, 0.0, SIZE.z + 0.05)


## The floor is out: its power stutter, or a lights-out scare on this floor.
func needs_fix() -> bool:
	if level == null or not is_inside_tree():
		return false
	var lights := level.lights()
	if lights != null and lights.is_floor_dark(floor_index):
		return true
	return ScareDirector.blackout_active() and absf(ScareDirector.blackout_center.y - float(floor_index) * YellowRooms.FLOOR_H) < 3.0


## Server: a crack of the wrench. The second one throws the breakers back.
func wrench_fix(_by: Node3D) -> void:
	if not multiplayer.is_server():
		return
	_hits += 1
	if _hits >= HITS_TO_FIX:
		_hits = 0
		level.server_restore_power(floor_index, fix_point())


func _process(delta: float) -> void:
	var broken := needs_fix()
	if broken != _was_broken:
		_was_broken = broken
		_hits = 0 if not broken else _hits
		_led_mat.albedo_color = Color(0.5, 0.05, 0.03) if broken else Color(0.1, 0.4, 0.1)
		if broken:
			Sfx.start_loop(_buzz)
		elif _buzz.playing:
			_buzz.stop()
	_glow.light_energy = maxf(0.0, _glow.light_energy - delta * 7.0)
	if not broken:
		_led_mat.emission = Color(0.1, 0.6, 0.15)
		_led_mat.emission_energy_multiplier = 0.4
		return
	_spark_t -= delta
	_led_mat.emission = Color(1.0, 0.1, 0.05)
	_led_mat.emission_energy_multiplier = 2.5 if fposmod(Time.get_ticks_msec() / 250.0, 2.0) < 1.0 else 0.2
	if _spark_t <= 0.0:
		_spark_t = randf_range(SPARK_EVERY.x, SPARK_EVERY.y)
		_glow.light_energy = randf_range(0.8, 1.8)
		Sfx.play_at(self, "click", fix_point(), -4.0, randf_range(1.6, 2.6), 14.0)


## Tests: how many cracks it has taken toward this fix.
func debug_hits() -> int:
	return _hits
