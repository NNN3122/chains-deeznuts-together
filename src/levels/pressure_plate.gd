class_name PressurePlate
extends Area3D
## Pressed while any chained body (a player, or the Ballast) stands on it. In solo play it latches
## on the first step, since nobody can hold it for you. "pressed" is replicated.

var pressed: bool = false  # replicated
var _latched: bool = false
var _plate_mesh: MeshInstance3D
var _mat: StandardMaterial3D
var _was_pressed: bool = false


static func create(node_name: String, at: Vector3) -> PressurePlate:
	var p := PressurePlate.new()
	p.name = node_name
	p.position = at
	return p


func _enter_tree() -> void:
	if has_node("Sync"):
		return
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	var path := NodePath(".:pressed")
	cfg.add_property(path)
	cfg.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	sync.replication_config = cfg
	add_child(sync)


func _ready() -> void:
	collision_layer = 0
	collision_mask = ChainBody.LAYER_BODIES
	monitoring = true
	monitorable = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.3, 1.0, 1.3)
	shape.shape = box
	shape.position = Vector3(0.0, 0.5, 0.0)
	add_child(shape)
	_plate_mesh = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.3, 0.06, 1.3)
	_plate_mesh.mesh = mesh
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.85, 0.7, 0.1)
	_mat.metallic = 0.5
	_mat.roughness = 0.4
	_mat.emission_enabled = true
	_mat.emission = Color(0.9, 0.6, 0.1)
	_mat.emission_energy_multiplier = 0.3
	_plate_mesh.material_override = _mat
	add_child(_plate_mesh)
	var label := Label3D.new()
	label.text = "STAND HERE"
	label.position = Vector3(0.0, 0.9, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 32
	label.pixel_size = 0.005
	label.outline_size = 8
	label.modulate = Color(1.0, 0.85, 0.3)
	add_child(label)
	body_entered.connect(_on_body_entered)


func _physics_process(_delta: float) -> void:
	if multiplayer.is_server():
		var count := 0
		for b in get_overlapping_bodies():
			if b is ChainBody:
				count += 1
		pressed = count > 0 or _latched
	_plate_mesh.position.y = 0.0 if pressed else 0.03
	_mat.albedo_color = Color(0.3, 0.9, 0.3) if pressed else Color(0.85, 0.7, 0.1)
	_mat.emission = _mat.albedo_color
	if pressed != _was_pressed:
		_was_pressed = pressed
		Sfx.play_at(self, "click", global_position, -2.0, 0.6 if pressed else 0.45)


func _on_body_entered(body: Node3D) -> void:
	if multiplayer.is_server() and body is ChainBody and Net.get_players().size() <= 1:
		_latched = true
