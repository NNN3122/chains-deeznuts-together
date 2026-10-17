class_name HordeArena
extends Node3D
## The Loading Lot: Level 3's first block. Asphalt under a sodium dusk, the Line's pad at the
## south end, a hoarding fence to boost over (the dumpster is the solo boost), a chokepoint wall
## with a 12 m gap, a few pillars for cover, and a thousand infected pouring in from the north
## with four Launchers in front of them. Clearing it: the three tasks, then everyone back on the pad.
## Two ways to exist:
##   - on the roof of the building (LevelStack sets `embedded`, `origin` and `checkpoint_index`:
##     the pizzeria's prop-loft hatch climbs out onto the pad, the crowd sleeps until then);
##   - on its own (`--arena`, or the title's WHERE button): then this node is the "level" the
##     rest of the game talks to, with the same surface as LevelStack.
## Everything is built under a root at `origin`, so positions in here are local to the lot.

const SEED: int = 3117
const SIZE: float = 100.0  # m square, centred on the origin
const WALL_H: float = 3.5
const PARAPET_H: float = 1.1
const STREET_DROP: float = 38.0  # m from the roof down to the street
const FALL_LIMIT: float = 12.0  # m below the roof: gone
const FENCE_H: float = 3.0
const FENCE_Z: float = 18.0
const GAP_HALF: float = 6.0
const HORDE_COUNT: int = 1000
const PAD_RADIUS: float = 6.0  # m round the spawn pad: everyone inside with the list done clears the lot
const LAYOFF_DELAY: float = 1.1
const REGROUP_COOLDOWN_MS: int = 15000
const FLOOR_NAME: String = "THE ROOF: CARROW HEIGHTS"
const SCARE_POOL: Array = [["footsteps", 2], ["breath", 2], ["whisper", 1], ["stalker", 1]]
const PAD_LOCAL: Vector3 = Vector3(0.0, 0.2, 34.0)
const TOWER_C: Vector3 = Vector3(39.0, 0.0, -39.0)  # local: the tower in the north-east corner
const TOWER_W: float = 18.0
const TOWER_H: float = 22.0
const STEP_H: float = 1.75  # m up per fire-escape ledge (a standing mantle reaches 2.1)
const HELI_READY: float = 30.0  # s the pilot needs with someone on the pad
const ABOARD_RADIUS: float = 4.5
const TASKS: Array[String] = [
	"Get over the fence (the dumpster, or a teammate's head)",
	"Reach the gap in the wall",
	"Climb the fire escape to the helipad",
	"Hold the pad while the pilot spins her up",
	"Everyone aboard",
]
## The rounds: [count, kind weights (Roach, Weaver, Flitter), where they come from (local rect)].
## Round 1 at arrival, 2 at the gap, 3 when the first of you reaches the helipad.
const ROUNDS: Array = [
	[450, [1.0, 0.0, 0.0], Rect2(-44.0, -46.0, 88.0, 30.0)],
	[350, [0.7, 0.3, 0.0], Rect2(-48.0, -30.0, 96.0, 20.0)],
	[200, [0.0, 0.4, 0.6], Rect2(-48.0, -48.0, 96.0, 24.0)],
]

var origin: Vector3 = Vector3.ZERO  # world position of the lot's centre at ground level
var embedded: bool = false  # part of the Stack (LevelStack is the "level"), not a level of its own
var checkpoint_index: int = 0
var spawn_position: Vector3 = PAD_LOCAL
var spawn_facing: float = 0.0  # yaw 0 looks toward -z: at the horde
var test_points: Dictionary = {}
var horde: Horde
var field: HordeField
var launchers: Array[Launcher] = []
var horde_count: int = HORDE_COUNT  # tests can shrink it
var seed_value: int = YellowRooms.DEFAULT_SEED  # the run's seed: a different crowd every time
var root: Node3D
var _we: WorldEnvironment
var _layoff_pending: bool = false
var _last_layoff_msec: int = -100000
var _last_regroup_msec: int = -100000
var _tasks_set: bool = false
var _task_t: float = 0.0
var _clear_told: bool = false
var rounds_spawned: int = 0  # replicated: every peer spawns rounds up to this
var heli_fraction: float = 0.0  # replicated: 0..1 of the pilot's spin-up
var _rounds_done: int = 0
var _heli: Node3D
var _rotor: Node3D
var _tail_rotor: Node3D
var _heli_light: OmniLight3D
var _heli_sound: AudioStreamPlayer3D
var _pad_told: bool = false
var _pad_t: float = 0.0


func _enter_tree() -> void:
	if has_node("Sync"):
		return
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	for prop in ["rounds_spawned", "heli_fraction"]:
		var path := NodePath(".:" + prop)
		cfg.add_property(path)
		cfg.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	sync.replication_config = cfg
	add_child(sync)


func _ready() -> void:
	if not embedded:
		add_to_group("level")
		_we = WorldEnvironment.new()
		_we.name = "WorldEnvironment"
		_we.camera_attributes = LevelKit.make_camera_attributes()
		add_child(_we)
		refresh_environment()
	root = Node3D.new()
	root.name = "Lot"
	root.position = origin
	add_child(root)
	spawn_position = origin + PAD_LOCAL
	field = HordeField.new()
	field.setup(Vector2(origin.x - SIZE * 0.5, origin.z - SIZE * 0.5), SIZE, SIZE, 1.0)
	_build()
	horde = Horde.new()
	horde.name = "Horde"
	horde.field = field
	horde.base_y = origin.y
	horde.enabled = not embedded
	add_child(horde)  # not under the root: the agents' positions are world positions already
	for i in 4:
		var l := Launcher.new()
		l.name = "Launcher%d" % i
		l.position = Vector3(-15.0 + 10.0 * float(i), 0.0, -7.0)
		l.floor_y = origin.y
		l.asleep = embedded
		root.add_child(l)
		launchers.append(l)
	test_points["spawn"] = spawn_position
	test_points["l_spawn"] = spawn_position
	test_points["gap"] = origin + Vector3(0.0, 0.1, 0.0)
	test_points["fence_dumpster"] = origin + Vector3(-8.0, 0.1, 21.5)
	test_points["fence_top"] = origin + Vector3(-8.0, FENCE_H + 0.1, FENCE_Z)
	test_points["horde_center"] = origin + Vector3(0.0, 0.1, -30.0)
	test_points["north"] = origin + Vector3(0.0, 0.1, -10.0)
	test_points["launcher0"] = origin + launchers[0].position
	test_points["escape_foot"] = origin + Vector3(TOWER_C.x - TOWER_W * 0.5 + 2.0, 0.1, TOWER_C.z + TOWER_W * 0.5 + 2.5)
	test_points["l_escape_foot"] = test_points["escape_foot"]
	test_points["helipad"] = origin + TOWER_C + Vector3(0.0, TOWER_H + 0.1, 0.0)
	test_points["heli"] = origin + TOWER_C + Vector3(0.0, TOWER_H, 0.0)
	add_child(Checkpoint.create("Checkpoint%d" % (checkpoint_index + 1), checkpoint_index + 1, origin + TOWER_C + Vector3(-5.0, TOWER_H + 0.1, 5.0), 0.0, "The helipad. Hold it while the pilot spins her up, then everyone aboard."))


func _build() -> void:
	var batch := LevelKit.BoxBatch.new()
	# The lot and its walls.
	batch.add(Vector3(0.0, -0.2, 0.0), Vector3(SIZE + 2.0, 0.4, SIZE + 2.0), "asphalt")
	# A parapet round the edge: knee-high, so the city is in view and the drop is real. The crowd
	# can't cross it (blocked cells); you can, if you jump, and then it's a long way down.
	_wall(batch, Vector3(0.0, PARAPET_H * 0.5, -SIZE * 0.5), Vector3(SIZE + 0.6, PARAPET_H, 0.6))
	_wall(batch, Vector3(0.0, PARAPET_H * 0.5, SIZE * 0.5), Vector3(SIZE + 0.6, PARAPET_H, 0.6))
	_wall(batch, Vector3(-SIZE * 0.5, PARAPET_H * 0.5, 0.0), Vector3(0.6, PARAPET_H, SIZE))
	_wall(batch, Vector3(SIZE * 0.5, PARAPET_H * 0.5, 0.0), Vector3(0.6, PARAPET_H, SIZE))
	_build_city(batch)
	# Painted bays on the asphalt, for scale, and the pad itself.
	for i in 12:
		var x := -44.0 + 8.0 * float(i)
		batch.add(Vector3(x, 0.005, 36.0), Vector3(0.12, 0.01, 10.0), "paint", false)
	batch.add(Vector3(0.0, 0.005, 41.0), Vector3(90.0, 0.01, 0.12), "paint", false)
	for s: float in [-1.0, 1.0]:
		batch.add(Vector3(s * PAD_RADIUS, 0.006, PAD_LOCAL.z), Vector3(0.14, 0.01, PAD_RADIUS * 2.0), "hazard", false)
		batch.add(Vector3(0.0, 0.006, PAD_LOCAL.z + s * PAD_RADIUS), Vector3(PAD_RADIUS * 2.0, 0.01, 0.14), "hazard", false)
	# The hatch you climbed out of (embedded): a raised steel lid beside the pad.
	if embedded:
		batch.add(Vector3(-3.0, 0.15, PAD_LOCAL.z + 2.0), Vector3(1.6, 0.3, 1.6), "steel_dark")
		batch.add(Vector3(-3.0, 0.9, PAD_LOCAL.z + 2.9), Vector3(1.6, 1.5, 0.08), "steel_dark", false, 0.0)
	# The chokepoint wall: a 12 m gap in the middle.
	var span := SIZE * 0.5 - GAP_HALF
	_wall(batch, Vector3(-(GAP_HALF + span * 0.5), WALL_H * 0.5, 0.0), Vector3(span, WALL_H, 0.7))
	_wall(batch, Vector3(GAP_HALF + span * 0.5, WALL_H * 0.5, 0.0), Vector3(span, WALL_H, 0.7))
	batch.add(Vector3(-GAP_HALF - 0.1, WALL_H + 0.2, 0.0), Vector3(0.5, 0.4, 0.9), "hazard")
	batch.add(Vector3(GAP_HALF + 0.1, WALL_H + 0.2, 0.0), Vector3(0.5, 0.4, 0.9), "hazard")
	# The hoarding fence with posts, open only at the far east end.
	var fence_len := SIZE - 16.0
	_wall(batch, Vector3(-8.0, FENCE_H * 0.5, FENCE_Z), Vector3(fence_len, FENCE_H, 0.14), "hoarding")
	var posts := int(fence_len / 3.0)
	for i in posts + 1:
		batch.add(Vector3(-8.0 - fence_len * 0.5 + 3.0 * float(i), FENCE_H * 0.5 + 0.1, FENCE_Z), Vector3(0.16, FENCE_H + 0.2, 0.3), "steel_dark", false)
	batch.add(Vector3(-8.0, FENCE_H + 0.05, FENCE_Z), Vector3(fence_len, 0.1, 0.22), "steel_dark", false)
	# The dumpster against the fence (the solo boost), and a crate or two.
	batch.add(Vector3(-8.0, 0.7, 19.6), Vector3(2.2, 1.4, 1.3), "dumpster")
	_block(-8.0, 19.6, 2.2, 1.3)
	batch.add(Vector3(-8.0, 1.42, 19.6), Vector3(2.3, 0.06, 1.4), "dark", false)
	batch.add(Vector3(-6.4, 0.3, 21.4), Vector3(0.8, 0.6, 0.8), "cardboard")
	_block(-6.4, 21.4, 0.8, 0.8)
	# Cover in the north half.
	for p: Vector3 in [Vector3(-22.0, 0.0, -18.0), Vector3(16.0, 0.0, -24.0), Vector3(-6.0, 0.0, -34.0), Vector3(28.0, 0.0, -10.0)]:
		_wall(batch, p + Vector3(0.0, 2.0, 0.0), Vector3(2.2, 4.0, 2.2), "concrete")
	_wall(batch, Vector3(-22.0, 1.5, -12.0), Vector3(16.0, 3.0, 0.6), "concrete")
	_build_tower(batch)
	# A wrecked van (boxes) near the gap: something to climb and shoot from.
	batch.add(Vector3(10.0, 0.9, 6.0), Vector3(2.2, 1.8, 5.0), "van")
	batch.add(Vector3(10.0, 1.95, 5.0), Vector3(2.0, 0.3, 2.4), "van")
	_block(10.0, 6.0, 2.2, 5.0)
	batch.build(root, "Lot")
	# Lights: sodium floods on posts, the sky a bruise.
	var sun := DirectionalLight3D.new()
	sun.name = "Dusk"
	sun.light_color = Color(1.0, 0.62, 0.3)
	sun.light_energy = 0.55
	sun.rotation = Vector3(-0.5, 0.6, 0.0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	root.add_child(sun)
	for p: Vector3 in [Vector3(-12.0, 6.0, 30.0), Vector3(12.0, 6.0, 30.0), Vector3(-10.0, 6.0, -2.0), Vector3(10.0, 6.0, -2.0), Vector3(0.0, 6.0, -22.0)]:
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.7, 0.35)
		lamp.light_energy = 3.0
		lamp.omni_range = 22.0
		lamp.shadow_enabled = false
		lamp.position = p
		root.add_child(lamp)
		var post := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.08
		pm.bottom_radius = 0.1
		pm.height = 6.0
		post.mesh = pm
		post.position = p - Vector3(0.0, 3.0, 0.0)
		post.material_override = LevelKit.mat("steel_dark")
		root.add_child(post)
	add_child(Checkpoint.create("Checkpoint%d" % checkpoint_index, checkpoint_index, origin + PAD_LOCAL, spawn_facing, first_objective()))
	var sign := Label3D.new()
	sign.text = "LOADING LOT  -  HOLD THE GAP"
	sign.font_size = 64
	sign.pixel_size = 0.02
	sign.modulate = Color(0.95, 0.8, 0.2)
	sign.outline_size = 12
	sign.position = Vector3(0.0, 4.6, 0.0)
	root.add_child(sign)


func _wall(batch: LevelKit.BoxBatch, center: Vector3, size: Vector3, key: String = "concrete") -> void:
	batch.add(center, size, key)
	_block(center.x, center.z, size.x, size.z)


## The way out: a plant tower in the corner with a fire escape of ledges zigzagging up its
## south face to the helipad, where the helicopter waits. Nothing on six or eight legs climbs
## it; what flies does.
func _build_tower(batch: LevelKit.BoxBatch) -> void:
	var c := TOWER_C
	_wall(batch, c + Vector3(0.0, TOWER_H * 0.5, 0.0), Vector3(TOWER_W, TOWER_H, TOWER_W), "concrete")
	_windows(batch, RandomNumberGenerator.new(), c + Vector3(0.0, TOWER_H * 0.5, 0.0), Vector3(TOWER_W, TOWER_H, TOWER_W), 4.0, 3.0, 0.2, true)
	# The helipad: a parapet, the painted ring and letter, and the lights round it.
	var top := c + Vector3(0.0, TOWER_H, 0.0)
	for s: float in [-1.0, 1.0]:
		batch.add(top + Vector3(s * (TOWER_W * 0.5 - 0.2), 0.5, 0.0), Vector3(0.4, 1.0, TOWER_W), "concrete")
		batch.add(top + Vector3(0.0, 0.5, s * (TOWER_W * 0.5 - 0.2)), Vector3(TOWER_W - 0.8, 1.0, 0.4), "concrete")
	batch.add(top + Vector3(0.0, 0.01, 0.0), Vector3(12.0, 0.02, 12.0), "helipad", false)
	for s: float in [-1.0, 1.0]:
		batch.add(top + Vector3(s * 1.8, 0.02, 0.0), Vector3(0.5, 0.02, 5.0), "paint", false)
	batch.add(top + Vector3(0.0, 0.02, 0.0), Vector3(3.6, 0.02, 0.5), "paint", false)
	for k in 12:
		var a := float(k) / 12.0 * TAU
		batch.add(top + Vector3(cos(a) * 6.5, 0.1, sin(a) * 6.5), Vector3(0.3, 0.2, 0.3), "street_lamp", false)
	# The fire escape: ledges up the south face, each a mantle above the last, switching back
	# every four so the Line can keep within reach of itself. A railing on the outside.
	var south := c.z + TOWER_W * 0.5
	var steps := int(ceil(TOWER_H / STEP_H))
	var x := c.x - TOWER_W * 0.5 + 2.5
	var dir := 1.0
	for i in steps:
		var y := STEP_H * float(i + 1)
		if i == steps - 1:
			y = TOWER_H
		var ledge := Vector3(x, y - 0.1, south + 0.8)
		batch.add(ledge, Vector3(4.6, 0.2, 1.6), "fire_escape")
		batch.add(ledge + Vector3(0.0, 0.55, 0.85), Vector3(4.6, 0.9, 0.06), "fire_escape", false)
		batch.add(ledge + Vector3(0.0, 0.0, 0.4), Vector3(0.1, 0.1, 0.1), "steel_dark", false)
		if (i + 1) % 4 == 0:
			dir = -dir  # the switchback
		else:
			x += dir * 3.2
		if i == 0:
			_block(x - dir * 3.2, south + 0.8, 4.6, 1.6)
	# A dumpster at the foot: the first ledge is a mantle from its lid.
	batch.add(Vector3(c.x - TOWER_W * 0.5 + 2.5, 0.6, south + 2.6), Vector3(2.0, 1.2, 1.2), "dumpster")
	_block(c.x - TOWER_W * 0.5 + 2.5, south + 2.6, 2.0, 1.2)
	var sign := Label3D.new()
	sign.text = "FIRE ESCAPE  ->  HELIPAD"
	sign.font_size = 48
	sign.pixel_size = 0.014
	sign.modulate = Color(0.4, 1.0, 0.5)
	sign.outline_size = 8
	sign.position = Vector3(c.x - TOWER_W * 0.5 + 2.5, 4.0, south + 0.05)
	root.add_child(sign)
	_build_helicopter(top)


func _build_helicopter(top: Vector3) -> void:
	_heli = Node3D.new()
	_heli.name = "Helicopter"
	_heli.position = top
	root.add_child(_heli)
	var body := LevelKit.mat("heli_body")
	var glass := LevelKit.mat("heli_glass")
	var dark := LevelKit.mat("rotor")
	_hbox(_heli, Vector3(2.0, 1.7, 4.2), Vector3(0.0, 1.55, 0.3), body)
	_hbox(_heli, Vector3(1.8, 1.2, 1.4), Vector3(0.0, 1.7, -2.2), glass)  # the nose
	_hbox(_heli, Vector3(0.5, 0.5, 5.0), Vector3(0.0, 1.9, 4.8), body)  # tail boom
	_hbox(_heli, Vector3(0.1, 1.4, 0.8), Vector3(0.0, 2.6, 7.2), body)  # fin
	for s: float in [-1.0, 1.0]:
		_hbox(_heli, Vector3(0.15, 0.15, 3.6), Vector3(s * 1.2, 0.1, 0.3), dark)  # skids
		_hbox(_heli, Vector3(0.12, 0.6, 0.12), Vector3(s * 1.2, 0.4, -0.8), dark)
		_hbox(_heli, Vector3(0.12, 0.6, 0.12), Vector3(s * 1.2, 0.4, 1.4), dark)
	_hbox(_heli, Vector3(0.6, 0.5, 0.6), Vector3(0.0, 2.6, 0.3), dark)  # the mast
	_rotor = Node3D.new()
	_rotor.position = Vector3(0.0, 2.9, 0.3)
	_heli.add_child(_rotor)
	for k in 4:
		var blade := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.3, 0.05, 5.4)
		blade.mesh = bm
		blade.position = Vector3(0.0, 0.0, 2.7).rotated(Vector3.UP, float(k) * PI * 0.5)
		blade.rotation.y = float(k) * PI * 0.5
		blade.material_override = dark
		_rotor.add_child(blade)
	_tail_rotor = Node3D.new()
	_tail_rotor.position = Vector3(0.35, 2.6, 7.2)
	_heli.add_child(_tail_rotor)
	for k in 2:
		var blade := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.05, 1.3, 0.15)
		blade.mesh = bm
		blade.rotation.x = float(k) * PI * 0.5
		blade.material_override = dark
		_tail_rotor.add_child(blade)
	_heli_light = OmniLight3D.new()
	_heli_light.light_color = Color(1.0, 0.1, 0.1)
	_heli_light.light_energy = 2.0
	_heli_light.omni_range = 9.0
	_heli_light.position = Vector3(0.0, 2.4, 1.6)
	_heli.add_child(_heli_light)
	_heli_sound = Sfx.loop_player("jet", -10.0, 60.0)
	_heli_sound.position = Vector3(0.0, 2.5, 0.3)
	_heli.add_child(_heli_sound)


func _hbox(parent: Node3D, size: Vector3, at: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = at
	mi.material_override = m
	parent.add_child(mi)


## Carrow Heights round the lot: a street canyon below the parapets, a near ring of tenements,
## a car park and towers with lit windows, water tanks, masts and one billboard, and a far
## skyline. All boxes in the batch (one MultiMesh per material), nothing the crowd walks on.
func _build_city(batch: LevelKit.BoxBatch) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + seed_value + 5
	var base := -STREET_DROP
	# The street, far below, with its lamps along the canyon.
	batch.add(Vector3(0.0, base - 0.2, 0.0), Vector3(800.0, 0.4, 800.0), "asphalt", false)
	for i in 40:
		var a := float(i) / 40.0 * TAU
		var r := SIZE * 0.5 + 8.0 + 4.0 * sin(a * 3.0)
		var p := Vector3(cos(a) * r, base + 4.0, sin(a) * r)
		batch.add(p, Vector3(0.3, 0.3, 0.3), "street_lamp", false)
		batch.add(p - Vector3(0.0, 2.0, 0.0), Vector3(0.12, 4.0, 0.12), "steel_dark", false)
	# The near ring: 3-4 buildings a side, across a street from the parapet.
	var near: Array = []
	for side in 4:
		var count := rng.randi_range(3, 4)
		for k in count:
			var along := -58.0 + (float(k) + 0.5) * 116.0 / float(count) + rng.randf_range(-4.0, 4.0)
			var out := SIZE * 0.5 + rng.randf_range(16.0, 30.0)
			var w := rng.randf_range(14.0, 30.0)
			var d := rng.randf_range(14.0, 26.0)
			var top := rng.randf_range(-18.0, 38.0)  # some roofs below ours, some towering over it
			var c: Vector3
			var size: Vector3
			match side:
				0:
					c = Vector3(along, 0.0, -(out + d * 0.5))
					size = Vector3(w, top - base, d)
				1:
					c = Vector3(along, 0.0, out + d * 0.5)
					size = Vector3(w, top - base, d)
				2:
					c = Vector3(-(out + d * 0.5), 0.0, along)
					size = Vector3(d, top - base, w)
				_:
					c = Vector3(out + d * 0.5, 0.0, along)
					size = Vector3(d, top - base, w)
			c.y = base + size.y * 0.5
			var key: String = ["brick", "tower", "concrete", "brick"][rng.randi_range(0, 3)]
			batch.add(c, size, key, false)
			near.append([c, size, top])
			_windows(batch, rng, c, size, 3.2, 2.6, 0.38 if key != "concrete" else 0.22, true)
			# Roof furniture: a parapet, a water tank or a mast on some.
			batch.add(Vector3(c.x, top + 0.5, c.z), Vector3(size.x + 0.4, 1.0, size.z + 0.4), "concrete", false)
			var roll := rng.randf()
			if roll < 0.35:
				_water_tank(Vector3(c.x + rng.randf_range(-3.0, 3.0), top + 1.0, c.z + rng.randf_range(-3.0, 3.0)))
			elif roll < 0.55:
				batch.add(Vector3(c.x, top + 9.0, c.z), Vector3(0.3, 16.0, 0.3), "steel_dark", false)
				batch.add(Vector3(c.x, top + 17.2, c.z), Vector3(0.4, 0.4, 0.4), "led_red", false)
	# The billboard: on the nearest tall roof to the north, facing the lot.
	var best: Array = []
	for b in near:
		var c: Vector3 = b[0]
		if c.z < -40.0 and float(b[2]) > 6.0 and (best.is_empty() or c.z > (best[0] as Vector3).z):
			best = b
	if not best.is_empty():
		var c: Vector3 = best[0]
		var top: float = best[2]
		batch.add(Vector3(c.x, top + 5.5, c.z), Vector3(16.0, 7.0, 0.4), "billboard", false)
		for s: float in [-1.0, 1.0]:
			batch.add(Vector3(c.x + s * 6.0, top + 1.0, c.z), Vector3(0.3, 2.0, 0.3), "steel_dark", false)
		var text := Label3D.new()
		text.text = "DEEZ INDUSTRIAL FASTENERS\nHOLDING IT TOGETHER SINCE 1931"
		text.font_size = 96
		text.pixel_size = 0.018
		text.modulate = Color(0.08, 0.06, 0.05)
		text.position = Vector3(c.x, top + 5.5, c.z + 0.25)
		root.add_child(text)
	# The far skyline: big dark slabs with a few lights on, a long way off.
	for i in 22:
		var a := float(i) / 22.0 * TAU + rng.randf_range(-0.1, 0.1)
		var r := rng.randf_range(170.0, 280.0)
		var w := rng.randf_range(28.0, 56.0)
		var h := rng.randf_range(40.0, 130.0)
		var c := Vector3(cos(a) * r, base + h * 0.5, sin(a) * r)
		batch.add(c, Vector3(w, h, w), "tower_far", false)
		_windows(batch, rng, c, Vector3(w, h, w), 7.0, 6.0, 0.12, false)
		if rng.randf() < 0.3:
			batch.add(Vector3(c.x, base + h + 1.0, c.z), Vector3(0.6, 0.6, 0.6), "led_red", false)


## Window boxes on a building's faces: lit ones glow, the rest are dark glass.
func _windows(batch: LevelKit.BoxBatch, rng: RandomNumberGenerator, c: Vector3, size: Vector3, row_step: float, col_step: float, lit_chance: float, all_sides: bool) -> void:
	var y0 := c.y - size.y * 0.5 + 2.0
	var y1 := c.y + size.y * 0.5 - 2.0
	var faces: Array = []
	# Faces toward the lot always; the others only on the near ring.
	faces.append([Vector3(0.0, 0.0, -1.0 if c.z > 0.0 else 1.0), size.x])
	faces.append([Vector3(-1.0 if c.x > 0.0 else 1.0, 0.0, 0.0), size.z])
	if all_sides:
		faces.append([Vector3(0.0, 0.0, 1.0 if c.z > 0.0 else -1.0), size.x])
		faces.append([Vector3(1.0 if c.x > 0.0 else -1.0, 0.0, 0.0), size.z])
	for f in faces:
		var n: Vector3 = f[0]
		var width: float = f[1]
		var along := Vector3(n.z, 0.0, -n.x)
		var half := (size.x if absf(n.z) > 0.5 else size.z) * 0.5
		var cols := int((width - 2.0) / col_step)
		var y := y0
		while y <= y1:
			for k in cols:
				var u := -width * 0.5 + 1.0 + (float(k) + 0.5) * col_step
				var p := c + n * (half + 0.05) + along * u
				p.y = y
				var lit := rng.randf() < lit_chance
				var box := Vector3(1.4, 1.8, 0.1) if absf(n.z) > 0.5 else Vector3(0.1, 1.8, 1.4)
				batch.add(p, box, "window_lit" if lit else "window_dark", false)
			y += row_step


func _water_tank(at: Vector3) -> void:
	var tank := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 2.2
	cm.bottom_radius = 2.2
	cm.height = 3.2
	tank.mesh = cm
	tank.position = at + Vector3(0.0, 3.6, 0.0)
	tank.material_override = LevelKit.mat("tank")
	root.add_child(tank)
	var cone := MeshInstance3D.new()
	var cn := CylinderMesh.new()
	cn.top_radius = 0.2
	cn.bottom_radius = 2.3
	cn.height = 1.2
	cone.mesh = cn
	cone.position = at + Vector3(0.0, 5.8, 0.0)
	cone.material_override = LevelKit.mat("tank")
	root.add_child(cone)
	for i in 4:
		var leg := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(0.2, 2.0, 0.2)
		leg.mesh = lm
		leg.position = at + Vector3(cos(float(i) * 1.57) * 1.5, 1.0, sin(float(i) * 1.57) * 1.5)
		leg.material_override = LevelKit.mat("steel_dark")
		root.add_child(leg)


func _block(cx: float, cz: float, sx: float, sz: float) -> void:
	field.block_box(origin.x + cx, origin.z + cz, sx, sz)


func first_objective() -> String:
	return "The roof: over the fence, through the gap, up the fire escape to the helipad. Hold the pad, then everyone aboard."


## Anyone on the Line up here? (Embedded, the crowd sleeps until then.)
func anyone_here() -> bool:
	for p in Net.get_players():
		if p.global_position.y > origin.y - 1.0:
			return true
	return false


# --- The level surface (standalone, or forwarded by LevelStack) -------------------------------------

func level_index_at(_p: Vector3) -> int:
	return 2


func floor_of(_y: float) -> int:
	return 0


func floor_name(_y: float) -> String:
	return FLOOR_NAME


func has_ceiling_at(_p: Vector3) -> bool:
	return false


func is_safe_spot(_p: Vector3) -> bool:
	return false


func ceiling_y(p: Vector3) -> float:
	return p.y + 40.0


func scare_pool(_p: Vector3) -> Array:
	return SCARE_POOL


func play_scare(_kind: String, _pos: Vector3, _targeted: bool) -> void:
	pass


func refresh_environment() -> void:
	if _we != null:
		_we.environment = LevelKit.make_environment(Settings.quality, 2)


func car_busy() -> bool:
	return false


## Every peer: the Stack hides the lot while the camera is in the building.
func set_shown(on: bool) -> void:
	root.visible = on
	horde.visible = on


# --- Server --------------------------------------------------------------------------------------

func server_populate() -> void:
	if not multiplayer.is_server():
		return
	var s := spawn_position
	Net.spawn_pickup("pistol", s + Vector3(-2.0, 0.0, -2.0), 0)
	Net.spawn_pickup("pistol", s + Vector3(2.0, 0.0, -2.0), 0)
	Net.spawn_pickup("ammo", s + Vector3(-3.0, 0.0, -3.0), 0)
	Net.spawn_pickup("ammo", s + Vector3(3.0, 0.0, -3.0), 0)
	Net.spawn_pickup("ammo", s + Vector3(0.0, 0.0, -4.0), 0)
	Net.spawn_pickup("airhorn", s + Vector3(-1.0, 0.0, -3.5), 0)
	Net.spawn_pickup("bomb", s + Vector3(1.0, 0.0, -3.5), 0)
	Net.spawn_pickup("bomb", s + Vector3(4.0, 0.0, -1.0), 0)
	Net.spawn_pickup("flashlight", s + Vector3(-4.0, 0.0, -1.0), 0)
	Net.spawn_pickup("jetpack", s + Vector3(0.0, 0.0, 3.0), 0)
	Net.spawn_pickup("drink", s + Vector3(5.0, 0.0, 1.0), 0)
	if not embedded:
		server_arrive()


## Server: the Line has reached the lot (at once standalone; through the hatch in the Stack).
## The checklist goes up and the crowd wakes.
func server_arrive() -> void:
	if not multiplayer.is_server():
		return
	GameState.set_tasks(PackedStringArray(TASKS))
	_tasks_set = true
	_clear_told = false
	_pad_told = false
	heli_fraction = 0.0
	if rounds_spawned < 1:
		rounds_spawned = 1
	GameState.post_message("THE ROOF. They came up out of the walls. Keep moving; get to the fire escape and the helipad.", 6.0)


## Server: the next round pours in (every peer spawns it from the replicated count).
func _start_round(k: int) -> void:
	if not multiplayer.is_server() or rounds_spawned >= k:
		return
	rounds_spawned = k
	match k:
		2:
			GameState.post_message("MORE OF THEM. The spiders are faster than you: shoot, or climb.", 4.0)
		3:
			GameState.post_message("WINGS. They come down from above; only a gun stops them. Hold the pad.", 4.0)


## Every peer: spawn rounds up to the replicated count, identically.
func _tick_rounds() -> void:
	while _rounds_done < rounds_spawned and _rounds_done < ROUNDS.size():
		var r: Array = ROUNDS[_rounds_done]
		var area: Rect2 = r[2]
		var weights: Array[float] = []
		for w in r[1]:
			weights.append(float(w))
		horde.spawn_group(int(r[0]), Rect2(area.position + Vector2(origin.x, origin.z), area.size), SEED + seed_value + _rounds_done * 7, weights)
		_rounds_done += 1


## Tests and the bench: everything at once.
func debug_spawn_all_rounds() -> void:
	rounds_spawned = ROUNDS.size()
	_tick_rounds()


## Tests: the pilot is ready now.
func debug_pad_ready() -> void:
	_pad_t = HELI_READY


func heli_position() -> Vector3:
	return _heli.global_position


func _physics_process(delta: float) -> void:
	_tick_rounds()
	_tick_helicopter(delta)
	# The swarm and the Jumpers wake when anyone is up here, on every peer (clients run the mass).
	var here := anyone_here()
	horde.enabled = here
	for l in launchers:
		l.asleep = not here
	if not multiplayer.is_server() or GameState.escaped:
		return
	# Over the parapet is a long way down.
	if here:
		for b in Net.get_chain_bodies():
			if b.global_position.y < origin.y - FALL_LIMIT:
				var lvl := get_tree().get_first_node_in_group("level")
				if lvl != null and lvl.has_method("request_layoff"):
					lvl.call("request_layoff", "%s went over the parapet." % (b.display_name if b is Player else "The Ballast"))
				break
	_task_t -= delta
	if _task_t > 0.0 or not _tasks_set or not here:
		return
	_task_t = 0.5
	var players := Net.get_players()
	var on_pad := 0
	for p in players:
		var l := p.global_position - origin
		if l.z < FENCE_Z - 0.5 and l.y > -1.0:
			GameState.complete_task(0)
		if Vector2(l.x, l.z).length() < 5.0:
			GameState.complete_task(1)
			_start_round(2)
		if _on_helipad(p.global_position):
			on_pad += 1
			if not GameState.task_done(2):
				GameState.complete_task(2)
				_start_round(3)
	# The pad: someone on it spins the pilot up; everyone off it and she winds down.
	if GameState.task_done(2) and not GameState.task_done(3):
		if on_pad > 0:
			if not _pad_told:
				_pad_told = true
				GameState.post_message("The pilot's spinning her up. HOLD THE PAD: %d seconds. Everything with wings is coming." % int(HELI_READY), 5.0)
			_pad_t += 0.5
		else:
			_pad_t = maxf(0.0, _pad_t - 0.5)
		heli_fraction = clampf(_pad_t / HELI_READY, 0.0, 1.0)
		if heli_fraction >= 1.0:
			GameState.complete_task(3)
			GameState.post_message("SHE'S READY. EVERYONE ABOARD.", 4.0)
	# Everyone aboard: all players at the helicopter, and off we go.
	if not GameState.task_done(3) or players.is_empty():
		return
	if _layoff_pending or Time.get_ticks_msec() - last_layoff_msec() < 3000:
		return
	var heli := heli_position()
	for p in players:
		if p.global_position.distance_to(heli) > ABOARD_RADIUS:
			return
	GameState.complete_task(4)
	GameState.set_escaped("Airlifted off Carrow Heights. Next stop: Level 4, the Hotel Velluto.")


func _on_helipad(p: Vector3) -> bool:
	var l := p - origin - TOWER_C
	return l.y > TOWER_H - 1.0 and absf(l.x) < TOWER_W * 0.5 and absf(l.z) < TOWER_W * 0.5


## Every peer: the rotor follows the pilot's spin-up; the strobe blinks; the sound rises.
func _tick_helicopter(delta: float) -> void:
	if _rotor == null:
		return
	var spin := lerpf(0.0, 32.0, heli_fraction * heli_fraction)
	if GameState.escaped:
		spin = 40.0
		_heli.position.y += 3.0 * delta  # up and away
		_heli.rotation.x = lerpf(_heli.rotation.x, -0.12, delta)
	_rotor.rotation.y += spin * delta
	_tail_rotor.rotation.x += spin * 3.0 * delta
	_heli_light.visible = fmod(Time.get_ticks_msec() * 0.001, 1.0) < 0.15
	if heli_fraction > 0.02 and not Sfx.is_silent():
		Sfx.start_loop(_heli_sound)
		_heli_sound.pitch_scale = 0.6 + 0.9 * heli_fraction
		_heli_sound.volume_db = -14.0 + 12.0 * heli_fraction
	elif _heli_sound.playing:
		_heli_sound.stop()


func last_layoff_msec() -> int:
	if embedded:
		var stack := get_parent() as LevelStack
		if stack != null:
			return stack.last_layoff_msec
	return _last_layoff_msec


func request_layoff(reason: String) -> void:
	if not multiplayer.is_server() or _layoff_pending or GameState.escaped:
		return
	_layoff_pending = true
	GameState.layoff(reason)
	await get_tree().create_timer(LAYOFF_DELAY).timeout
	_respawn_group()
	_layoff_pending = false
	_last_layoff_msec = Time.get_ticks_msec()


func regroup(requester: String) -> void:
	if not multiplayer.is_server() or _layoff_pending or GameState.escaped:
		return
	var now := Time.get_ticks_msec()
	if now - _last_regroup_msec < REGROUP_COOLDOWN_MS:
		GameState.post_message("Regroup is on cooldown. Hold on a few seconds.", 2.5)
		return
	_last_regroup_msec = now
	_respawn_group()
	GameState.post_message("%s called everyone back to the pad." % requester, 3.5)


func _respawn_group() -> void:
	var bodies := Net.get_chain_bodies()
	var facing := GameState.checkpoint_facing
	var right := Vector3(cos(facing), 0.0, -sin(facing))
	var n := bodies.size()
	for i in n:
		var offset := right * (float(i) * 1.0 - float(n - 1) * 0.5)
		bodies[i].teleport_to(GameState.checkpoint_position + offset + Vector3(0.0, 0.2, 0.0), facing)
	server_on_respawn()


## Server: the Line is back on its checkpoint (standalone or through the Stack): nobody respawns
## into a crowd, and the Launchers go back to their posts.
func server_on_respawn() -> void:
	for m in get_tree().get_nodes_in_group("monster"):
		if m is Launcher:
			(m as Launcher).release(false)
	horde.push_away_from(GameState.checkpoint_position, 24.0, test_points["horde_center"])
	for i in launchers.size():
		if not launchers[i].is_dead():
			launchers[i].debug_reset(origin + Vector3(-15.0 + 10.0 * float(i), 0.0, -7.0))
	_pad_t = 0.0
	heli_fraction = 0.0
	_pad_told = false
