class_name ScareTrigger
extends Area3D
## A scripted scare: the first player into the volume fires it once (server decides, every peer
## plays it). The ScareDirector does the actual scaring.

var scare_id: String = "lunge"
var box_size: Vector3 = Vector3(3.0, 2.5, 1.5)
var fired: bool = false


static func create(node_name: String, at: Vector3, size: Vector3, id: String) -> ScareTrigger:
	var t := ScareTrigger.new()
	t.name = node_name
	t.position = at
	t.box_size = size
	t.scare_id = id
	return t


func _ready() -> void:
	collision_layer = 0
	collision_mask = ChainBody.LAYER_BODIES
	monitoring = true
	monitorable = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = box_size
	shape.shape = box
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not multiplayer.is_server() or fired:
		return
	var p := body as Player
	if p == null:
		return
	fired = true
	ScareDirector.trigger_for(scare_id, p)
