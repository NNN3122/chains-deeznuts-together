class_name ItemPickup
extends Area3D
## A floating, glowing item you walk into. Spawned by the server through Net's pickup spawner, so
## clients and late joiners always see the same pickups; taking one frees it everywhere.

const REPICK_DELAY_MS: int = 1500  # the player who dropped it can't instantly re-grab it

var item_id: String = ""
var data: ItemData
var ignore_peer: int = 0
var ignore_until_msec: int = 0
var _visual: Node3D
var _t: float = 0.0


func _ready() -> void:
	add_to_group("pickups")
	data = ItemRegistry.get_data(item_id)
	collision_layer = 0
	collision_mask = ChainBody.LAYER_BODIES
	monitoring = true
	monitorable = false
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.85
	shape.shape = sphere
	shape.position = Vector3(0.0, 0.6, 0.0)
	add_child(shape)
	_visual = Node3D.new()
	add_child(_visual)
	var model := ItemModels.build(item_id)
	model.scale = Vector3.ONE * 2.2
	_visual.add_child(model)
	var color := data.color if data != null else Color.WHITE
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 0.9
	light.omni_range = 2.2
	light.position = Vector3(0.0, 0.3, 0.0)
	_visual.add_child(light)
	var label := Label3D.new()
	label.text = data.display_name if data != null else item_id
	label.position = Vector3(0.0, 0.55, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 30
	label.pixel_size = 0.005
	label.outline_size = 8
	label.modulate = color.lightened(0.3)
	_visual.add_child(label)
	_t = randf() * TAU
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_t += delta
	_visual.rotation.y = _t * 1.4
	_visual.position.y = 0.55 + sin(_t * 2.2) * 0.1


func _physics_process(_delta: float) -> void:
	# Someone already standing in the pickup when it became available (or after dropping it).
	if multiplayer.is_server() and Engine.get_physics_frames() % 15 == 0:
		for b in get_overlapping_bodies():
			_on_body_entered(b)


func _on_body_entered(body: Node3D) -> void:
	if not multiplayer.is_server() or is_queued_for_deletion() or data == null:
		return
	var player := body as Player
	if player == null or player.held_item != null or player.is_grabbed():
		return
	if player.peer_id == ignore_peer and Time.get_ticks_msec() < ignore_until_msec:
		return
	var logic := data.create_logic()
	if logic == null:
		return
	if player.server_give_item(logic):
		var fx := Effects.find(self)
		if fx != null:
			fx.fx_sound.rpc("pickup", global_position, -4.0, 1.0)
		GameState.post_message("%s grabbed the %s. %s" % [player.display_name, data.display_name, data.hud_hint], 3.0)
		queue_free()
	else:
		logic.free()
