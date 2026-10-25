class_name ItemPickup
extends Area3D
## An item lying where it was left: on the floor, a desk or a shelf, at rest on its flattest side
## (the user: "the items kinda just float around and not very realistic"). Walk into it to take it.
## One dropped by a player falls out of their hand and settles. Spawned by the server through Net's
## pickup spawner, so clients and late joiners always see the same pickups; taking one frees it
## everywhere.

const REPICK_DELAY_MS: int = 1500  # the player who dropped it can't instantly re-grab it
const FULL_MESSAGE_GAP_MS: int = 2500  # "hands full" at most this often per player
const SCALE: float = 1.35  # the hand-sized models, a little bigger so they read on a dark floor (they floated at 2.2)
const REST_PROBE_UP: float = 0.6  # m above the spawn point the search for a surface starts (a desk it was set on)
const REST_PROBE_DOWN: float = 3.0  # m below the spawn point it looks
const REST_TILT: float = 0.06  # rad of lean either way, so a row of them doesn't look placed by a machine
const DROP_HEIGHT: float = 1.0  # m: a dropped item falls from about hand height
const DROP_GRAVITY: float = 14.0
const DROP_BOUNCE: float = 0.25  # of the landing speed it bounces back up with
const DROP_SPIN: float = 5.0  # rad/s it tumbles while it falls

var item_id: String = ""
var data: ItemData
var ignore_peer: int = 0
var ignore_until_msec: int = 0
var carry_state: Dictionary = {}  # ammo counts etc. from whoever dropped it
var _visual: Node3D
var _rest: Transform3D  # the visual's resting place, under this node
var _settled: bool = false  # every peer: found the surface it rests on (the first physics frame)
var _fall_y: float = 0.0  # m above the rest it still is (a dropped item falling)
var _fall_v: float = 0.0
var _tumble: Vector3 = Vector3.ZERO
var _full_told: Dictionary = {}  # peer -> msec of the last "hands full" notice


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
	model.scale = Vector3.ONE * SCALE
	_visual.add_child(model)
	_visual.visible = false  # until it has found what it lies on
	body_entered.connect(_on_body_entered)


## Every peer works out the same resting place (the same world, the same hash of where it is).
func _settle() -> void:
	_settled = true
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i((global_position * 10.0).round())) ^ hash(item_id)
	# Lying on its flattest side: its thinnest axis straight up, then turned any way round.
	var box := _model_box()
	var thin := 1
	if box.size.x <= box.size.y and box.size.x <= box.size.z:
		thin = 0
	elif box.size.z <= box.size.y and box.size.z <= box.size.x:
		thin = 2
	var lie := Basis.IDENTITY
	if thin == 0:
		lie = Basis(Vector3.FORWARD, PI * 0.5)  # x up
	elif thin == 2:
		lie = Basis(Vector3.RIGHT, -PI * 0.5)  # z up
	var turn := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-REST_TILT, REST_TILT)) * Basis(Vector3.FORWARD, rng.randf_range(-REST_TILT, REST_TILT))
	var basis := turn * lie
	# Its lowest point on whatever is under it.
	var low := INF
	for k in 8:
		var corner := box.position + box.size * Vector3(k & 1, (k >> 1) & 1, (k >> 2) & 1)
		low = minf(low, (basis * corner).y)
	var ground := 0.0
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3(0.0, REST_PROBE_UP, 0.0)
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, global_position - Vector3(0.0, REST_PROBE_DOWN, 0.0), ChainBody.LAYER_WORLD))
	if not hit.is_empty():
		ground = (hit["position"] as Vector3).y - global_position.y
	_rest = Transform3D(basis, Vector3(0.0, ground - low + 0.004, 0.0))
	_visual.transform = _rest
	_visual.visible = true
	if ignore_peer != 0:
		# Out of someone's hand: it falls and tumbles, bounces once, and lies still.
		_fall_y = DROP_HEIGHT
		_tumble = Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.5, 0.5), rng.randf_range(-1.0, 1.0)).normalized() * DROP_SPIN
		_visual.transform = Transform3D(_rest.basis, _rest.origin + Vector3(0.0, _fall_y, 0.0))


## The model's bounds in its own space (scaled), from its meshes.
func _model_box() -> AABB:
	var out := AABB()
	var first := true
	for mi in _visual.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var to_visual := _visual.global_transform.affine_inverse() * m.global_transform
		var b := to_visual * m.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out if not first else AABB(Vector3(-0.1, -0.1, -0.1), Vector3(0.2, 0.2, 0.2))


func _process(delta: float) -> void:
	if _fall_y <= 0.0 and _fall_v == 0.0:
		return
	_fall_v -= DROP_GRAVITY * delta
	_fall_y += _fall_v * delta
	if _fall_y <= 0.0:
		_fall_y = 0.0
		_fall_v = -_fall_v * DROP_BOUNCE if _fall_v < -1.5 else 0.0
		_tumble *= 0.35
	var spin := Basis.IDENTITY
	if _fall_y > 0.0 or _fall_v != 0.0:
		spin = Basis.from_euler(_tumble * _fall_y * 0.6)  # the tumble unwinds as it comes to rest
	_visual.transform = Transform3D(spin * _rest.basis, _rest.origin + Vector3(0.0, _fall_y, 0.0))


func _physics_process(_delta: float) -> void:
	if not _settled:
		_settle()
	# Someone already standing in the pickup when it became available (or after dropping it).
	if multiplayer.is_server() and Engine.get_physics_frames() % 15 == 0:
		for b in get_overlapping_bodies():
			_on_body_entered(b)


func _on_body_entered(body: Node3D) -> void:
	if not multiplayer.is_server() or is_queued_for_deletion() or data == null:
		return
	var player := body as Player
	if player == null or player.is_grabbed():
		return
	if player.peer_id == ignore_peer and Time.get_ticks_msec() < ignore_until_msec:
		return
	var logic := data.create_logic()
	if logic == null:
		return
	if not carry_state.is_empty():
		logic.restore_state(carry_state)
	if player.server_give_item(logic):
		var fx := Effects.find(self)
		if fx != null:
			fx.fx_sound.rpc("pickup", global_position, -4.0, 1.0)
		if logic.is_queued_for_deletion():
			GameState.post_message("%s pocketed the %s." % [player.display_name, data.display_name], 2.5)
		else:
			GameState.post_message("%s grabbed the %s. %s" % [player.display_name, data.display_name, data.hud_hint], 3.0)
		queue_free()
	else:
		logic.free()
		var now := Time.get_ticks_msec()
		if now - int(_full_told.get(player.peer_id, -100000)) > FULL_MESSAGE_GAP_MS:
			_full_told[player.peer_id] = now
			_rpc_hands_full.rpc_id(player.peer_id, data.display_name)


@rpc("authority", "call_local", "reliable")
func _rpc_hands_full(what: String) -> void:
	GameState.post_message_local("Hands full: you carry 3 things. G drops the selected one to take the %s." % what, 3.0)
