class_name Ballast
extends ChainBody
## The Ballast: a 35 kg cast-iron hex nut with a smiley face, chained to you when you play solo,
## so the chain still matters. It drags, it falls off ledges and pulls you, it gets hoisted, it
## scrapes loudly enough for the Custodian to hear, and it holds you down when you're grabbed.
## Lives in every world on every peer; the server turns it on only when exactly one player is in.

const GRAVITY: float = 18.0
const GROUND_FRICTION: float = 9.0  # m/s^2 of horizontal slowdown while resting on the floor
const RADIUS: float = 0.42
const HEIGHT: float = 0.38
const SNAG_TIME: float = 1.3  # seconds stuck at full chain length before it clanks loose

var active: bool = false  # replicated
var _mesh_root: Node3D
var _scrape: AudioStreamPlayer3D
var _speed: float = 0.0
var _last_pos: Vector3
var _snag_t: float = 0.0
var _snag_pos: Vector3 = Vector3.ZERO
var _dangle_t: float = 0.0
var _hint_cooldown: float = 0.0


func _enter_tree() -> void:
	if has_node("Sync"):
		return
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	for prop in ["synced_position", "active"]:
		var path := NodePath(".:" + prop)
		cfg.add_property(path)
		cfg.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	sync.replication_config = cfg
	add_child(sync)


func _ready() -> void:
	join_index = 999
	_setup_body_layers()
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = RADIUS
	cyl.height = HEIGHT
	shape.shape = cyl
	shape.position = Vector3(0.0, HEIGHT * 0.5, 0.0)
	add_child(shape)
	_build_visual()
	_scrape = Sfx.loop_player("scrape", -8.0, 25.0)
	add_child(_scrape)
	_last_pos = global_position
	_apply_active()


func _build_visual() -> void:
	_mesh_root = Node3D.new()
	add_child(_mesh_root)
	var nut := MeshInstance3D.new()
	var hex := CylinderMesh.new()
	hex.top_radius = RADIUS
	hex.bottom_radius = RADIUS
	hex.height = HEIGHT
	hex.radial_segments = 6
	hex.rings = 1
	nut.mesh = hex
	nut.position = Vector3(0.0, HEIGHT * 0.5, 0.0)
	nut.material_override = LevelKit.mat("iron")
	_mesh_root.add_child(nut)
	# The hole through the middle.
	var hole := MeshInstance3D.new()
	var hole_mesh := CylinderMesh.new()
	hole_mesh.top_radius = 0.16
	hole_mesh.bottom_radius = 0.16
	hole_mesh.height = HEIGHT + 0.02
	hole.mesh = hole_mesh
	hole.position = nut.position
	hole.material_override = LevelKit.mat("dark")
	_mesh_root.add_child(hole)
	# Painted smiley on one flat face.
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.95, 0.8, 0.1)
	paint.emission_enabled = true
	paint.emission = Color(0.95, 0.8, 0.1)
	paint.emission_energy_multiplier = 0.25
	var face_z := -RADIUS * 0.866 - 0.005
	for ex: float in [-0.09, 0.09]:
		var eye := MeshInstance3D.new()
		var em := BoxMesh.new()
		em.size = Vector3(0.05, 0.07, 0.01)
		eye.mesh = em
		eye.position = Vector3(ex, HEIGHT * 0.62, face_z)
		eye.material_override = paint
		_mesh_root.add_child(eye)
	for i in 5:
		var t := float(i) / 4.0
		var dot := MeshInstance3D.new()
		var dm := BoxMesh.new()
		dm.size = Vector3(0.04, 0.03, 0.01)
		dot.mesh = dm
		var x := lerpf(-0.12, 0.12, t)
		dot.position = Vector3(x, HEIGHT * 0.33 - 0.06 * sin(PI * t), face_z)
		dot.material_override = paint
		_mesh_root.add_child(dot)
	var tag := Label3D.new()
	tag.text = "BALLAST"
	tag.font_size = 28
	tag.pixel_size = 0.004
	tag.position = Vector3(0.0, HEIGHT + 0.25, 0.0)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.modulate = Color(0.95, 0.8, 0.2)
	tag.outline_size = 6
	_mesh_root.add_child(tag)


func anchor_height() -> float:
	return HEIGHT * 0.5


## The Ballast always gives way: it is dragged after you and never drags you across a floor
## (that's what made solo climbs impossible). It still pulls you toward an edge when it dangles
## (ChainSystem's hang drag), and it pops loose when it snags (see _tick_snag).
func chain_weight() -> float:
	return 50.0


func hang_mass() -> float:
	return 0.5  # 35 kg of iron: half a colleague


func resist_value() -> float:
	return 1.5 if is_on_floor() and active else 0.0


func noise_level() -> float:
	if not active or not is_on_floor():
		return 0.0
	# Scraping iron across carpet: quiet at a walk, loud if you sprint and drag it.
	return clampf((_speed - 2.5) * 12.0, 0.0, 30.0)


## Server only.
func set_active(on: bool, near: Vector3) -> void:
	if on == active:
		return
	active = on
	if on:
		teleport_to(near, 0.0)
	_apply_active()


func _apply_active() -> void:
	visible = active
	if active:
		add_to_group("noise_source")
		_setup_body_layers()
	else:
		remove_from_group("noise_source")
		collision_layer = 0
		collision_mask = 0
		if multiplayer.is_server():
			global_position = Vector3(0.0, -500.0, 0.0)
			synced_position = global_position


func _physics_process(delta: float) -> void:
	if visible != active:
		_apply_active()
	if multiplayer.is_server():
		if active:
			_server_tick(delta)
	else:
		client_interpolate(delta)
	_speed = global_position.distance_to(_last_pos) / maxf(delta, 0.0001)
	_last_pos = global_position
	if active and _speed > 0.8 and is_on_floor_visual():
		Sfx.start_loop(_scrape)
		_scrape.volume_db = lerpf(-14.0, -4.0, clampf(_speed / 4.0, 0.0, 1.0))
	elif _scrape.playing:
		_scrape.stop()


func is_on_floor_visual() -> bool:
	if multiplayer.is_server():
		return is_on_floor()
	return true


func _server_tick(delta: float) -> void:
	dragged_this_tick = 0.0
	velocity.y -= GRAVITY * delta
	if is_on_floor():
		var h := Vector3(velocity.x, 0.0, velocity.z)
		h = h.move_toward(Vector3.ZERO, GROUND_FRICTION * delta)
		velocity.x = h.x
		velocity.z = h.z
	velocity += external_velocity
	external_velocity = Vector3.ZERO
	move_and_slide()
	_tick_snag(delta)
	synced_position = global_position


## Snagged under a ceiling, on a crate lip, or dangling at full length: after SNAG_TIME it
## scrambles loose and lands at your feet with a clang. Keeps every climb doable solo.
func _tick_snag(delta: float) -> void:
	var chain := get_tree().get_first_node_in_group("chain") as ChainSystem
	var partner: Player = null
	for p in Net.get_players():
		partner = p
		break
	if chain == null or partner == null or chain.tension_for(self) < 0.97:
		_snag_t = 0.0
		_snag_pos = global_position
		_dangle_t = 0.0
		return
	# Dangling below you: tell the player how to deal with it (solo, so the server is local).
	if not is_on_floor() and global_position.y < partner.global_position.y - 0.8:
		_dangle_t += delta
		_hint_cooldown -= delta
		if _dangle_t > 0.5 and _hint_cooldown <= 0.0:
			_hint_cooldown = 10.0
			GameState.post_message_local("Your Ballast is dangling: keep walking away to hoist it, or hold Ctrl to brace.", 4.0)
	else:
		_dangle_t = 0.0
	if global_position.distance_to(_snag_pos) > 0.6:
		_snag_t = 0.0
		_snag_pos = global_position
		return
	_snag_t += delta
	if _snag_t < SNAG_TIME or partner.is_grabbed() or not partner.is_on_floor():
		return
	_snag_t = 0.0
	var behind := Vector3(sin(partner.body_yaw), 0.0, cos(partner.body_yaw)) * 0.9
	teleport_to(partner.global_position + behind + Vector3(0.0, 0.6, 0.0), 0.0)
	_snag_pos = global_position
	var fx := Effects.find(self)
	if fx != null:
		fx.fx_sound.rpc("clink", global_position, 0.0, 0.7)
		fx.fx_sound.rpc("thump", global_position, -6.0, 1.4)
