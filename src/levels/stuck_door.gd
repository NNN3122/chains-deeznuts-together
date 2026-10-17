class_name StuckDoor
extends Node3D
## A door on the route that is jammed in its frame. Walking into it does nothing but tell you
## so; a body hitting it at a sprint shoulders it open with a BANG that is the loudest thing on
## the floor for a few seconds: every Hollow Hire on the floor comes to look, awake. The one
## who shouldered it stumbles through, which yanks the chain, so the whole Line goes with them.
## Server decides "open" (replicated); every peer swings the leaf and hears the bang.

const SHOULDER_SPEED: float = 5.0  # m/s toward it: a sprint (7) does it, a walk (4.2) doesn't
const BANG_SECONDS: float = 3.0  # s the bang counts as noise for the Hires
const WAKE_SECONDS: float = 14.0  # s the floor's Hires hunt after the bang
const STUMBLE: float = 5.5  # m/s the shoulderer is thrown through the doorway
const TELL_GAP_MS: int = 3500

var axis: Vector3 = Vector3.RIGHT  # along the doorway
var normal: Vector3 = Vector3.FORWARD  # across it
var width: float = 1.4
var height: float = 2.3
var level: YellowRooms
var floor_index: int = 0
var open: bool = false  # replicated
var _pivot: Node3D
var _shape: CollisionShape3D
var _area: Area3D
var _peak: Dictionary = {}  # body instance id -> fastest approach seen while in the area (m/s)
var _bang_left: float = 0.0
var _told_msec: int = -100000
var _shown_open: bool = false
var _swing_dir: Vector3 = Vector3.ZERO


static func create(node_name: String, at: Vector3, door_axis: Vector3, w: float, h: float) -> StuckDoor:
	var d := StuckDoor.new()
	d.name = node_name
	d.position = at  # floor level, center of the doorway
	d.axis = door_axis.normalized()
	d.normal = d.axis.cross(Vector3.UP).normalized()
	d.width = w
	d.height = h
	return d


func _enter_tree() -> void:
	if has_node("Sync"):
		return
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	var path := NodePath(".:open")
	cfg.add_property(path)
	cfg.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	sync.replication_config = cfg
	add_child(sync)


func _ready() -> void:
	add_to_group("noise_source")
	add_to_group("stuck_doors")
	var basis := Basis(axis, Vector3.UP, normal).orthonormalized()
	# The leaf hangs from a hinge on one jamb and fills the frame.
	_pivot = Node3D.new()
	_pivot.basis = basis
	_pivot.position = axis * (-width * 0.5)
	add_child(_pivot)
	var leaf := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(width - 0.04, height - 0.04, 0.05)
	leaf.mesh = lm
	leaf.position = Vector3(width * 0.5, height * 0.5, 0.0)
	leaf.material_override = LevelKit.mat("door")
	_pivot.add_child(leaf)
	for s: float in [-1.0, 1.0]:
		var handle := MeshInstance3D.new()
		var hm := BoxMesh.new()
		hm.size = Vector3(0.12, 0.025, 0.03)
		handle.mesh = hm
		handle.position = Vector3(width - 0.22, 1.0, s * 0.045)
		handle.material_override = LevelKit.mat("fixture")
		_pivot.add_child(handle)
		# A yellow notice on both faces: the building knows about it.
		var tag := Label3D.new()
		tag.text = "DOOR JAMMED\nSHOULDER IT\n(sprint into it)"
		tag.font_size = 26
		tag.pixel_size = 0.0036
		tag.modulate = Color(1.0, 0.85, 0.3)
		tag.outline_size = 6
		tag.double_sided = false
		tag.position = Vector3(width * 0.5, 1.55, s * 0.03)
		tag.rotation = Vector3(0.0, 0.0 if s > 0.0 else PI, 0.0)
		_pivot.add_child(tag)
	var body := StaticBody3D.new()
	body.collision_layer = ChainBody.LAYER_WORLD
	body.collision_mask = 0
	body.basis = basis
	_shape = CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(width + 0.1, height, 0.14)
	_shape.shape = bs
	_shape.position = Vector3(0.0, height * 0.5, 0.0)
	body.add_child(_shape)
	add_child(body)
	# Who is coming at it, from either side.
	_area = Area3D.new()
	_area.collision_layer = 0
	_area.collision_mask = ChainBody.LAYER_BODIES
	_area.monitoring = true
	_area.monitorable = false
	_area.basis = basis
	var as_ := CollisionShape3D.new()
	var ab := BoxShape3D.new()
	ab.size = Vector3(width + 1.0, 2.4, 3.0)
	as_.shape = ab
	as_.position = Vector3(0.0, 1.2, 0.0)
	_area.add_child(as_)
	add_child(_area)


func noise_level() -> float:
	return 100.0 if _bang_left > 0.0 else 0.0


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		_server_tick(delta)
	if open != _shown_open:
		_shown_open = open
		_shape.disabled = open
		if open:
			_swing()


func _server_tick(delta: float) -> void:
	_bang_left = maxf(0.0, _bang_left - delta)
	if open:
		return
	var seen: Dictionary = {}
	for b in _area.get_overlapping_bodies():
		var cb := b as ChainBody
		if cb == null:
			continue
		var id := cb.get_instance_id()
		seen[id] = true
		var off := (cb.global_position - global_position).dot(normal)  # which side it is on
		var side := -1.0 if off < 0.0 else 1.0
		var approach := -cb.velocity.dot(normal) * side  # m/s toward the leaf
		var peak := maxf(float(_peak.get(id, 0.0)), approach)
		_peak[id] = peak
		if absf(off) > 0.8:
			continue
		if peak >= SHOULDER_SPEED:
			_server_open(cb, -normal * side)
			return
		if approach > 0.6 and Time.get_ticks_msec() - _told_msec > TELL_GAP_MS:
			_told_msec = Time.get_ticks_msec()
			GameState.post_message("The door's jammed. SHOULDER IT: sprint into it. It'll be loud.", 3.0)
	for id in _peak.keys():
		if not seen.has(id):
			_peak.erase(id)


## Server: it gives. The shoulderer stumbles through (the chain follows), the floor hears it.
func _server_open(by: ChainBody, through: Vector3) -> void:
	open = true
	_shape.disabled = true
	_bang_left = BANG_SECONDS
	by.apply_knockback(through * STUMBLE + Vector3.UP * 1.5)
	if level != null:
		level.wake_floor(floor_index, global_position, WAKE_SECONDS)
		level.on_door_shouldered(floor_index)
	_rpc_bang.rpc(through)
	var who: Variant = by.get("display_name")
	GameState.post_message("%s put a shoulder through it. Everything on this floor heard that." % (String(who) if who != null else "Someone"), 3.5)


## Tests: open it without a body.
func debug_open() -> void:
	open = true
	_shape.disabled = true
	_bang_left = BANG_SECONDS


@rpc("authority", "call_local", "reliable")
func _rpc_bang(through: Vector3) -> void:
	_swing_dir = through
	Sfx.play_at(self, "bang", global_position + Vector3.UP, 6.0, 0.9, 60.0)
	Sfx.caption(self, "a door bangs open", global_position)
	var me := Net.get_local_player()
	if me != null and me.global_position.distance_to(global_position) < 18.0:
		me.add_shake(0.5)


func _swing() -> void:
	var toward := _swing_dir if _swing_dir.length() > 0.1 else normal
	# Rotating the pivot by +angle about Y moves the leaf's free end toward -normal (local -z).
	var ang := deg_to_rad(105.0) * (1.0 if toward.dot(normal) < 0.0 else -1.0)
	var tw := create_tween()
	tw.tween_property(_pivot, "rotation:y", ang, 0.28).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
