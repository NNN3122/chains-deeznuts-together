class_name Checkpoint
extends Area3D
## The Break Room you arrive in on each floor. A player entering it clocks the whole group in:
## the next Layoff respawns everyone here, and the floor's objective is announced.

var index: int = 0
var respawn: Vector3 = Vector3.ZERO
var facing: float = 0.0
var objective: String = ""
var area_center: Vector3 = Vector3.ZERO


static func create(node_name: String, idx: int, respawn_at: Vector3, face: float, objective_text: String) -> Checkpoint:
	var c := Checkpoint.new()
	c.name = node_name
	c.index = idx
	c.respawn = respawn_at
	c.facing = face
	c.objective = objective_text
	c.area_center = respawn_at
	return c


func _ready() -> void:
	position = area_center
	collision_layer = 0
	collision_mask = ChainBody.LAYER_BODIES
	monitoring = true
	monitorable = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(5.6, 2.6, 5.6)
	shape.shape = box
	shape.position = Vector3(0.0, 1.5, 0.0)
	add_child(shape)
	body_entered.connect(_on_body_entered)


## You usually enter the volume head-first while still climbing out of the hole below, when your
## feet don't count yet, so keep checking whoever is standing in here.
func _physics_process(_delta: float) -> void:
	if multiplayer.is_server() and GameState.checkpoint_index < index and Engine.get_physics_frames() % 10 == 0:
		for b in get_overlapping_bodies():
			_on_body_entered(b)


func _on_body_entered(body: Node3D) -> void:
	if multiplayer.is_server() and body is Player and body.global_position.y > global_position.y - 0.3:
		GameState.set_checkpoint(index, respawn, facing, objective)
