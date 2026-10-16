class_name Shutter
extends Node3D
## A roll-down steel shutter across the hall that leads to a floor's climb. It only stays down
## while someone on the hall side holds the pull chain: stand at it and BRACE (Ctrl). Let go and
## it rolls straight back up. Pappy Pepperoni can't pass a closed shutter: he bangs on it three
## times and goes back to his end of the floor, which is the window the holder has to catch up.
## Server decides "closed"; it is replicated; every peer animates and plays the sound.

const HOLD_RADIUS: float = 1.7  # m from the pull chain a bracing player counts as holding it
const THICK: float = 0.08

var width: float = 1.4
var height: float = 2.3
var axis: Vector3 = Vector3.RIGHT  # along the doorway
var normal: Vector3 = Vector3.FORWARD  # toward the hall side (where the chain hangs)
var closed: bool = false  # replicated
var holders: int = 0  # replicated: how many are holding it (HUD)
var dented: bool = false  # replicated: he's been at it
var debug_hold: bool = false  # tests: held down with nobody at the chain
var _leaf: Node3D
var _body: StaticBody3D
var _shape: CollisionShape3D
var _shown_closed: bool = false
var _dent: MeshInstance3D
var _hand: MeshInstance3D
var _pull_point: Vector3 = Vector3.ZERO


static func create(node_name: String, at: Vector3, door_axis: Vector3, hall_normal: Vector3, w: float, h: float) -> Shutter:
	var s := Shutter.new()
	s.name = node_name
	s.position = at  # floor level, center of the doorway
	s.axis = door_axis.normalized()
	s.normal = hall_normal.normalized()
	s.width = w
	s.height = h
	return s


func _enter_tree() -> void:
	if has_node("Sync"):
		return
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	for prop in ["closed", "holders", "dented"]:
		var path := NodePath(".:" + prop)
		cfg.add_property(path)
		cfg.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	sync.replication_config = cfg
	add_child(sync)


func _ready() -> void:
	add_to_group("shutters")
	var basis := Basis(axis, Vector3.UP, axis.cross(Vector3.UP)).orthonormalized()
	# Housing over the doorway and guide rails.
	_box(Vector3(0.0, height + 0.2, 0.0), Vector3(width + 0.4, 0.4, 0.36), "steel_dark", basis)
	for s: float in [-1.0, 1.0]:
		_box(axis * s * (width * 0.5 + 0.05), Vector3(0.1, height, 0.16), "steel_dark", basis, height * 0.5)
	# The curtain itself: scaled from the header down.
	_leaf = Node3D.new()
	_leaf.position = Vector3(0.0, height, 0.0)
	_leaf.basis = basis
	add_child(_leaf)
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(width + 0.1, height, THICK)
	m.mesh = bm
	m.position = Vector3(0.0, -height * 0.5, 0.0)
	m.material_override = LevelKit.mat("shutter")
	_leaf.add_child(m)
	_dent = MeshInstance3D.new()
	var dm := SphereMesh.new()
	dm.radius = 0.32
	dm.height = 0.2
	_dent.mesh = dm
	_dent.position = Vector3(0.15, -height * 0.45, -THICK * 0.5)
	_dent.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	_dent.material_override = LevelKit.mat("shutter")
	_dent.visible = false
	_leaf.add_child(_dent)
	_hand = MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.3, 0.38, 0.01)
	_hand.mesh = hm
	_hand.position = Vector3(-0.25, -height * 0.4, THICK * 0.5 + 0.006)
	_hand.material_override = LevelKit.mat("dough")
	_hand.visible = false
	_leaf.add_child(_hand)
	_leaf.scale = Vector3(1.0, 0.04, 1.0)
	_body = StaticBody3D.new()
	_body.collision_layer = ChainBody.LAYER_WORLD
	_body.collision_mask = 0
	_shape = CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(width + 0.1, height, THICK + 0.04)
	_shape.shape = bs
	_shape.position = Vector3(0.0, height * 0.5, 0.0)
	_shape.disabled = true
	_body.basis = basis
	_body.add_child(_shape)
	add_child(_body)
	# The pull chain hangs on the hall side, beside the doorway.
	_pull_point = global_position + normal * 0.55 + axis * (width * 0.5 + 0.35)
	var chain := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.02
	cm.bottom_radius = 0.02
	cm.height = height - 0.6
	chain.mesh = cm
	chain.material_override = LevelKit.mat("chain")
	chain.position = to_local(_pull_point) + Vector3(0.0, height * 0.5 + 0.1, 0.0)
	add_child(chain)
	var handle := MeshInstance3D.new()
	var hb := BoxMesh.new()
	hb.size = Vector3(0.12, 0.2, 0.12)
	handle.mesh = hb
	handle.material_override = LevelKit.mat("hazard")
	handle.position = to_local(_pull_point) + Vector3(0.0, 0.75, 0.0)
	add_child(handle)
	var tag := Label3D.new()
	tag.text = "SHUTTER\nHOLD CTRL HERE\nTO KEEP IT DOWN"
	tag.font_size = 26
	tag.pixel_size = 0.004
	tag.modulate = Color(1.0, 0.85, 0.3)
	tag.outline_size = 8
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.position = to_local(_pull_point) + Vector3(0.0, 1.9, 0.0)
	add_child(tag)


func _box(at: Vector3, size: Vector3, key: String, basis: Basis, lift: float = 0.0) -> void:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.material_override = LevelKit.mat(key)
	m.transform = Transform3D(basis, at + Vector3(0.0, lift, 0.0))
	add_child(m)


func pull_point() -> Vector3:
	return _pull_point


## Server: who's holding the chain this tick.
func _physics_process(_delta: float) -> void:
	if multiplayer.is_server():
		var n := 0
		for p in Net.get_players():
			if p.is_bracing() and p.global_position.distance_to(_pull_point) < HOLD_RADIUS:
				n += 1
		holders = n
		closed = n > 0 or debug_hold
	_shape.disabled = not closed
	_dent.visible = dented
	_hand.visible = dented
	if closed != _shown_closed:
		_shown_closed = closed
		var tw := create_tween()
		if closed:
			tw.tween_property(_leaf, "scale:y", 1.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		else:
			tw.tween_property(_leaf, "scale:y", 0.04, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		Sfx.play_at(self, "shutter", global_position + Vector3.UP * 1.5, -2.0, 0.9 if closed else 1.15)


## Every peer: one of Pappy's three bangs.
func play_bang() -> void:
	dented = true
	Sfx.play_at(self, "bang", global_position + Vector3.UP * 1.2, 4.0, randf_range(0.9, 1.1), 50.0)
	var tw := create_tween()
	tw.tween_property(_leaf, "position", Vector3(0.0, height, 0.0) + normal * 0.12, 0.05)
	tw.tween_property(_leaf, "position", Vector3(0.0, height, 0.0), 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var me := Net.get_local_player()
	if me != null and me.global_position.distance_to(global_position) < 12.0:
		me.add_shake(0.6)
