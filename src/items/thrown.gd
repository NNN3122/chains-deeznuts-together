class_name Thrown
extends Node3D
## A thrown decoy or bomb. Spawned by the server through Net's thrown spawner; the server
## simulates the arc with raycasts (bounces, then rests), clients interpolate the synced position.
## Decoy: squeaks for DECOY_TIME, the loudest thing on the floor, so the Hires (and the horde) go to it.
## Bomb: fuse, then a blast that launches everyone nearby (chain included) and scares it off.

const GRAVITY: float = 18.0
const DECOY_TIME: float = 8.0
const FUSE: float = 2.4
const BLAST_RADIUS: float = 6.5

var kind: String = "decoy"
var vel: Vector3 = Vector3.ZERO
var owner_peer: int = 0
var synced_position: Vector3 = Vector3.ZERO  # replicated
var exploded: bool = false  # replicated
var age: float = 0.0
var _resting: bool = false
var _model: Node3D
var _blink: OmniLight3D
var _squeak_t: float = 0.0


func _enter_tree() -> void:
	if has_node("Sync"):
		return
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	for prop in ["synced_position", "exploded"]:
		var path := NodePath(".:" + prop)
		cfg.add_property(path)
		cfg.property_set_spawn(path, true)
		cfg.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	sync.replication_config = cfg
	add_child(sync)


func _ready() -> void:
	add_to_group("noise_source")
	_model = ItemModels.build(kind)
	_model.scale = Vector3.ONE * 1.6
	add_child(_model)
	if kind == "bomb":
		_blink = OmniLight3D.new()
		_blink.light_color = Color(1.0, 0.2, 0.05)
		_blink.omni_range = 2.5
		_blink.position = Vector3(0.0, 0.3, 0.0)
		add_child(_blink)
	if multiplayer.is_server():
		synced_position = global_position


func noise_level() -> float:
	if kind == "decoy":
		return 100.0 if age < DECOY_TIME else 0.0
	return 100.0 if exploded else 0.0


func _physics_process(delta: float) -> void:
	age += delta
	if multiplayer.is_server():
		_server_tick(delta)
	else:
		global_position = global_position.lerp(synced_position, clampf(delta * 18.0, 0.0, 1.0))
	_local_fx(delta)


func _server_tick(delta: float) -> void:
	if not _resting and not exploded:
		vel.y -= GRAVITY * delta
		var from := global_position
		var to := from + vel * delta
		var q := PhysicsRayQueryParameters3D.create(from, to, ChainBody.LAYER_WORLD)
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if hit.is_empty():
			global_position = to
		else:
			var n: Vector3 = hit["normal"]
			global_position = (hit["position"] as Vector3) + n * 0.12
			vel = vel.bounce(n) * 0.38
			if n.y > 0.7 and vel.length() < 1.5:
				_resting = true
				vel = Vector3.ZERO
			var fx := Effects.find(self)
			if fx != null and vel.length() > 2.0:
				fx.fx_sound.rpc("clink" if kind == "bomb" else "squeak", global_position, -6.0, 0.6)
	synced_position = global_position
	if kind == "decoy" and age > DECOY_TIME + 1.0:
		queue_free()
	elif kind == "bomb":
		if not exploded and age >= FUSE:
			_explode()
		elif exploded and age > FUSE + 0.8:
			queue_free()


func _explode() -> void:
	exploded = true
	var pos := global_position
	var fx := Effects.find(self)
	if fx != null:
		fx.fx_explosion.rpc(pos)
	for body in Net.get_chain_bodies():
		var d := body.global_position.distance_to(pos)
		if d > BLAST_RADIUS:
			continue
		var k := 1.0 - d / BLAST_RADIUS
		var away := (body.global_position - pos)
		away.y = 0.0
		away = away.normalized() if away.length() > 0.05 else Vector3.ZERO
		body.apply_knockback(away * 9.0 * k + Vector3.UP * (5.0 + 6.0 * k))
	for c in get_tree().get_nodes_in_group("monster"):
		var cp := (c as Node3D).global_position
		if c.has_method("stain_point"):
			cp = c.call("stain_point")
		# Same floor only: a blast doesn't kill through a 5 m concrete slab.
		if c.has_method("blast") and cp.distance_to(pos) < BLAST_RADIUS + 3.0 and absf(cp.y - pos.y) < 3.5:
			c.call("blast")
	var horde := get_tree().get_first_node_in_group("horde")
	if horde != null:
		horde.call("blast", pos, BLAST_RADIUS)


func _local_fx(delta: float) -> void:
	if kind == "decoy" and age < DECOY_TIME:
		_squeak_t -= delta
		if _squeak_t <= 0.0:
			_squeak_t = 0.45
			Sfx.play_at(self, "squeak", global_position, -2.0, randf_range(0.9, 1.25), 45.0)
		_model.rotation.y += delta * 6.0
	elif kind == "bomb" and _blink != null:
		var rate := 4.0 + age * 6.0
		_blink.light_energy = 3.0 if fmod(age * rate, 1.0) < 0.5 else 0.0
		_model.visible = not exploded
		_blink.visible = not exploded
