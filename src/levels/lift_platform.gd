class_name LiftPlatform
extends AnimatableBody3D
## Rises while its PressurePlate is pressed (after a short delay to step on) and sinks otherwise.
## The server moves it; its height is replicated. Bodies standing on it are carried.

const SPEED: float = 1.6  # m/s
const RISE_DELAY: float = 1.5  # s the plate must stay pressed before rising

var low_y: float = 0.0
var high_y: float = 0.0
var plate: PressurePlate
var size: Vector3 = Vector3(2.3, 0.3, 2.3)
var synced_y: float = 0.0  # replicated
var _pressed_for: float = 0.0
var _motor: AudioStreamPlayer3D
var _last_y: float = 0.0


static func create(node_name: String, center: Vector3, low: float, high: float, trigger_plate: PressurePlate, box_size: Vector3) -> LiftPlatform:
	var lift := LiftPlatform.new()
	lift.name = node_name
	lift.position = center
	lift.low_y = low
	lift.high_y = high
	lift.synced_y = center.y
	lift.plate = trigger_plate
	lift.size = box_size
	return lift


func _enter_tree() -> void:
	if has_node("Sync"):
		return
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	var path := NodePath(".:synced_y")
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
	box.size = size
	shape.shape = box
	add_child(shape)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh.mesh = box_mesh
	mesh.material_override = LevelKit.mat("lift")
	add_child(mesh)
	for s: float in [-1.0, 1.0]:
		var stripe := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(size.x, 0.02, 0.12)
		stripe.mesh = sm
		stripe.material_override = LevelKit.mat("hazard")
		stripe.position = Vector3(0.0, size.y * 0.5 + 0.01, s * (size.z * 0.5 - 0.1))
		add_child(stripe)
	_motor = Sfx.loop_player("lift", -6.0, 25.0)
	add_child(_motor)
	_last_y = position.y


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		var is_pressed := plate != null and plate.pressed
		_pressed_for = _pressed_for + delta if is_pressed else 0.0
		var target := high_y if _pressed_for >= RISE_DELAY else low_y
		position.y = move_toward(position.y, target, SPEED * delta)
		synced_y = position.y
	else:
		position.y = synced_y
	var moving := absf(position.y - _last_y) > 0.0005
	_last_y = position.y
	if moving:
		Sfx.start_loop(_motor)
	elif _motor.playing:
		_motor.stop()
