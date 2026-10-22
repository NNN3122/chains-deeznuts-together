class_name ManorGate
extends Node3D
## The south gate of the Ashgrave estate: two leaves of wrought iron between stone pillars, chained
## shut, a dead lamp on each pillar. When the main generator is thrown (server_open) the lamps burn
## red, the chain drops and the leaves grind open outward over OPEN_SECONDS; once they are open
## the lamps turn green and the way out, down the lane into the fog, is clear. open_t (0..1) is
## replicated and every peer swings the leaves from it.

const WIDTH: float = 6.0  # m between the pillars
const HEIGHT: float = 4.2
const OPEN_SECONDS: float = 7.0
const SWING: float = 1.75  # rad each leaf turns out
const BAR_STEP: float = 0.24

# Replicated.
var open_t: float = 0.0
var opening: bool = false

var _leaves: Array[Node3D] = []
var _bodies: Array[CollisionShape3D] = []
var _lamp_mats: Array[StandardMaterial3D] = []
var _lamps: Array[OmniLight3D] = []
var _chain: Node3D
var _was_open: bool = false


func _enter_tree() -> void:
	if has_node("Sync"):
		return
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	for prop in ["open_t", "opening"]:
		var path := NodePath(".:" + prop)
		cfg.add_property(path)
		cfg.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	sync.replication_config = cfg
	add_child(sync)


func _ready() -> void:
	var iron := LevelKit.mat("iron")
	for side: float in [-1.0, 1.0]:
		# A leaf hinges on its pillar and swings out (+z) through SWING.
		var pivot := Node3D.new()
		pivot.position = Vector3(side * WIDTH * 0.5, 0.0, 0.0)
		add_child(pivot)
		_leaves.append(pivot)
		var w := WIDTH * 0.5 - 0.05
		var dir := -side  # from the hinge toward the middle
		_bar(pivot, Vector3(dir * w * 0.5, 0.2, 0.0), Vector3(w, 0.1, 0.08), iron)
		_bar(pivot, Vector3(dir * w * 0.5, HEIGHT * 0.45, 0.0), Vector3(w, 0.1, 0.08), iron)
		_bar(pivot, Vector3(dir * w * 0.5, HEIGHT - 0.6, 0.0), Vector3(w, 0.1, 0.08), iron)
		var n := int(w / BAR_STEP)
		for k in n + 1:
			var x := dir * (0.06 + float(k) * w / float(n))
			var top := HEIGHT - 0.4 + 0.35 * sin(PI * float(k) / float(n))  # the top arches to the middle
			_bar(pivot, Vector3(x, top * 0.5, 0.0), Vector3(0.04, top, 0.04), iron)
			var tip := MeshInstance3D.new()
			var tb := BoxMesh.new()
			tb.size = Vector3(0.07, 0.07, 0.07)
			tip.mesh = tb
			tip.material_override = iron
			tip.position = Vector3(x, top + 0.05, 0.0)
			tip.rotation = Vector3(0.0, 0.0, PI * 0.25)
			pivot.add_child(tip)
		var body := StaticBody3D.new()
		body.collision_layer = ChainBody.LAYER_WORLD
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(w, HEIGHT, 0.2)
		cs.shape = bs
		cs.position = Vector3(dir * w * 0.5, HEIGHT * 0.5, 0.0)
		body.add_child(cs)
		pivot.add_child(body)
		_bodies.append(cs)
		# The pillar lamp: dead until the generator runs.
		var lm := StandardMaterial3D.new()
		lm.albedo_color = Color(0.05, 0.02, 0.02)
		lm.emission_enabled = true
		lm.emission = Color(1.0, 0.08, 0.04)
		lm.emission_energy_multiplier = 0.0
		_lamp_mats.append(lm)
		var lamp := MeshInstance3D.new()
		var lb := BoxMesh.new()
		lb.size = Vector3(0.32, 0.42, 0.32)
		lamp.mesh = lb
		lamp.material_override = lm
		lamp.position = Vector3(side * (WIDTH * 0.5 + 0.6), HEIGHT + 0.95, 0.0)
		add_child(lamp)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.1, 0.05)
		light.light_energy = 0.0
		light.omni_range = 8.0
		light.light_volumetric_fog_energy = 0.5
		light.position = lamp.position + Vector3(0.0, 0.0, 0.5)
		add_child(light)
		_lamps.append(light)
	# The chain and padlock across the middle.
	_chain = Node3D.new()
	add_child(_chain)
	var cm := LevelKit.mat("chain")
	for k in 7:
		var link := MeshInstance3D.new()
		var lbox := BoxMesh.new()
		lbox.size = Vector3(0.14, 0.05, 0.05)
		link.mesh = lbox
		link.material_override = cm
		link.position = Vector3(-0.42 + 0.14 * float(k), 1.9 - 0.12 * sin(PI * float(k) / 6.0), 0.08)
		link.rotation.x = 0.0 if k % 2 == 0 else PI * 0.5
		_chain.add_child(link)
	var lock := MeshInstance3D.new()
	var lockm := BoxMesh.new()
	lockm.size = Vector3(0.16, 0.2, 0.08)
	lock.mesh = lockm
	lock.material_override = LevelKit.mat("brass")
	lock.position = Vector3(0.0, 1.72, 0.1)
	_chain.add_child(lock)


func _bar(parent: Node3D, at: Vector3, size: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = at
	parent.add_child(mi)


func is_open() -> bool:
	return open_t >= 1.0


## Server: the main generator is running. The chain drops and the leaves start to move.
func server_open() -> void:
	if not multiplayer.is_server() or opening:
		return
	opening = true
	_rpc_opening.rpc()


@rpc("authority", "call_local", "reliable")
func _rpc_opening() -> void:
	Sfx.play_at(self, "clink", global_position + Vector3(0.0, 1.8, 0.0), 4.0, 0.7, 30.0)
	Sfx.play_at(self, "gate", global_position + Vector3(0.0, 2.0, 0.0), 6.0, 0.85, 80.0)
	Sfx.caption(self, "iron grinding: the south gate is opening", global_position)


func _physics_process(delta: float) -> void:
	if multiplayer.is_server() and opening and open_t < 1.0:
		open_t = minf(1.0, open_t + delta / OPEN_SECONDS)
	var u := smoothstep(0.0, 1.0, open_t)
	for i in _leaves.size():
		var side := -1.0 if i == 0 else 1.0
		_leaves[i].rotation.y = side * SWING * u  # both out through the gateway
		_bodies[i].disabled = u > 0.9  # pinned back against the wall: out of the way
	_chain.visible = not opening
	var lit := opening or open_t > 0.0
	for k in _lamps.size():
		var col := Color(0.2, 1.0, 0.3) if open_t >= 1.0 else Color(1.0, 0.08, 0.04)
		_lamps[k].light_color = col
		_lamps[k].light_energy = 0.8 if lit else 0.0
		_lamp_mats[k].emission = col
		_lamp_mats[k].emission_energy_multiplier = 2.2 if lit else 0.0
	if open_t >= 1.0 and not _was_open:
		_was_open = true
		Sfx.play_at(self, "slam", global_position + Vector3(0.0, 1.5, 0.0), 0.0, 0.5, 50.0)
