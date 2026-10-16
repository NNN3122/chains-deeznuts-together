class_name SecurityDesk
extends Node3D
## A Night Shift security desk: a CRT handset wired to this floor's cameras. Stand in the chair
## spot to clip in; F flips through the cameras (items are paused while you hold the handset).
## While a camera shows Pappy Pepperoni's node he can't move, so the Desk Jockey keeps him pinned
## while the rest of the Line climbs, at 0.3% of the power bank per second. Server decides who is
## clipped in and which camera they're on; every peer sees the little screen glow.

const CLIP_RADIUS: float = 1.1
const DRAIN_PER_SECOND: float = 0.3  # % of the power bank while someone is clipped in

var floor_index: int = 0
var cams: Array = []  # [{name, pos, look}] in world space, in order
var occupant_peer: int = 0  # replicated
var cam_index: int = 0  # replicated
var _spot: Vector3 = Vector3.ZERO
var _facing: float = 0.0
var _screen: MeshInstance3D
var _glow: OmniLight3D
var _label: Label3D
var _was_use: Dictionary = {}
var _first_clip_done: bool = false
var _whine: AudioStreamPlayer3D


static func create(node_name: String, at: Vector3, facing: float, floor_i: int, cam_list: Array) -> SecurityDesk:
	var d := SecurityDesk.new()
	d.name = node_name
	d.position = at
	d._facing = facing
	d.floor_index = floor_i
	d.cams = cam_list
	return d


func _enter_tree() -> void:
	if has_node("Sync"):
		return
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	for prop in ["occupant_peer", "cam_index"]:
		var path := NodePath(".:" + prop)
		cfg.add_property(path)
		cfg.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	sync.replication_config = cfg
	add_child(sync)


func _ready() -> void:
	add_to_group("desks")
	rotation.y = _facing
	# Desk, the CRT handset on a stand, a swivel chair spot in front, a "SECURITY" sign.
	_part(Vector3(0.0, 0.74, 0.0), Vector3(1.8, 0.06, 0.8), "laminate")
	_part(Vector3(0.0, 0.37, 0.0), Vector3(1.7, 0.7, 0.7), "booth_dark")
	_part(Vector3(0.0, 1.02, 0.1), Vector3(0.6, 0.5, 0.45), "plastic")
	_screen = _part(Vector3(0.0, 1.03, -0.13), Vector3(0.46, 0.36, 0.02), "crt_off", false)
	_part(Vector3(0.55, 0.78, 0.15), Vector3(0.4, 0.03, 0.2), "plastic", false)  # keyboard
	_part(Vector3(-0.6, 0.82, 0.1), Vector3(0.1, 0.12, 0.1), "mug", false)
	_part(Vector3(-0.3, 0.77, 0.25), Vector3(0.3, 0.02, 0.22), "paper", false)
	for s: float in [-1.0, 1.0]:
		_part(Vector3(s * 0.8, 0.3, 0.0), Vector3(0.06, 0.6, 0.7), "steel_dark")
	_glow = OmniLight3D.new()
	_glow.light_color = Color(0.5, 0.8, 1.0)
	_glow.light_energy = 0.0
	_glow.omni_range = 3.5
	_glow.position = Vector3(0.0, 1.2, -0.5)
	add_child(_glow)
	_label = Label3D.new()
	_label.text = "SECURITY DESK\nSTAND HERE: CAMERAS\nF FLIPS CAMERAS"
	_label.font_size = 26
	_label.pixel_size = 0.004
	_label.modulate = Color(0.6, 0.9, 1.0)
	_label.outline_size = 8
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position = Vector3(0.0, 1.8, -0.9)
	add_child(_label)
	_part(Vector3(0.0, 0.0, -0.85), Vector3(1.0, 0.012, 0.8), "hazard", false)  # painted chair spot
	_whine = Sfx.loop_player("hum", -30.0, 6.0)
	_whine.pitch_scale = 2.6
	_whine.position = Vector3(0.0, 1.0, 0.0)
	add_child(_whine)
	_spot = global_position + Basis.from_euler(Vector3(0.0, _facing, 0.0)) * Vector3(0.0, 0.0, -0.85)


func _part(at: Vector3, size: Vector3, key: String, collide: bool = true) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.position = at
	m.material_override = LevelKit.mat(key)
	add_child(m)
	if collide:
		var body := StaticBody3D.new()
		body.collision_layer = ChainBody.LAYER_WORLD
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		cs.position = at
		body.add_child(cs)
		add_child(body)
	return m


func spot() -> Vector3:
	return _spot


func is_live() -> bool:
	return occupant_peer != 0


## The camera the Jockey is on right now (world transform data), or empty.
func current_cam() -> Dictionary:
	if cams.is_empty():
		return {}
	return cams[clampi(cam_index, 0, cams.size() - 1)]


func occupant() -> Player:
	return Net.find_player(occupant_peer) if occupant_peer != 0 else null


## Server: who stands in the chair spot, and did they press F to flip cameras.
func _physics_process(_delta: float) -> void:
	if multiplayer.is_server():
		var who: Player = null
		var cur := occupant()
		if cur != null and cur.state == Player.State.NORMAL and cur.global_position.distance_to(_spot) < CLIP_RADIUS + 0.4:
			who = cur
		else:
			for p in Net.get_players():
				if p.state == Player.State.NORMAL and p.global_position.distance_to(_spot) < CLIP_RADIUS:
					who = p
					break
		var new_peer := who.peer_id if who != null else 0
		if new_peer != occupant_peer:
			occupant_peer = new_peer
			if who != null:
				_rpc_clip.rpc(who.display_name, not _first_clip_done)
				_first_clip_done = true
		if who != null:
			var use := (who.input_flags & Player.FLAG_USE) != 0
			if use and not bool(_was_use.get(who.peer_id, false)) and not cams.is_empty():
				cam_index = (cam_index + 1) % cams.size()
				_rpc_flip.rpc()
			_was_use[who.peer_id] = use
	var live := is_live()
	_glow.light_energy = (0.35 + 0.1 * sin(Time.get_ticks_msec() * 0.02)) if live else 0.0
	_screen.material_override = LevelKit.mat("crt" if live else "crt_off")
	if live:
		Sfx.start_loop(_whine)
	elif _whine.playing:
		_whine.stop()


@rpc("authority", "call_local", "reliable")
func _rpc_clip(who: String, first: bool) -> void:
	Sfx.play_at(self, "click", global_position + Vector3.UP, -4.0, 1.3)
	Sfx.play_at(self, "static", global_position + Vector3.UP, -12.0, 1.0, 8.0)
	var me := Net.get_local_player()
	if me != null and me.peer_id == occupant_peer:
		GameState.post_message_local("You're on cameras. F flips through them. While a camera shows HIM, he can't move.", 5.0)
	elif first:
		GameState.post_message_local("%s is on the cameras." % who, 3.0)


@rpc("authority", "call_local", "unreliable")
func _rpc_flip() -> void:
	Sfx.play_at(self, "click", global_position + Vector3.UP, -6.0, 0.9)
