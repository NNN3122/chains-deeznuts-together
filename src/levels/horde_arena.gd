class_name HordeArena
extends Node3D
## Carrow Heights: Level 3. The roof of the building (the Loading Lot: asphalt under a night
## sky, the Line's pad at the south end, a hoarding fence to boost over, a chokepoint wall with
## a 12 m gap, and the first of the swarm pouring in from the north) and then the district:
## eleven rooftops north of it, each a jump, a plank, a drop or a climb from the last, laid out
## from the run's seed, with the swarm boiling out of every roof's vents as you land on it and
## the Weavers swinging after you on threads. The twelfth roof is a tower with a fire escape up
## to a helipad, where the helicopter waits: hold the pad while the pilot spins her up, then
## everyone aboard.
## Two ways to exist:
##   - on the roof of the building (LevelStack sets `embedded`, `origin` and `checkpoint_index`:
##     the pizzeria's prop-loft hatch climbs out onto the pad, the crowd sleeps until then);
##   - on its own (`--arena`, or the title's WHERE button): then this node is the "level" the
##     rest of the game talks to, with the same surface as LevelStack.
## Everything is built under a root at `origin`, so positions in here are local to the lot.

const SEED: int = 3117
const SIZE: float = 100.0  # m square, the lot, centred on the origin
const WALL_H: float = 3.5
const PARAPET_H: float = 1.1
const ROOF_PARAPET_H: float = 0.5  # knee-high on the route roofs: a hop clears it
const STREET_DROP: float = 38.0  # m from the lot down to the street
const FENCE_H: float = 3.0
const FENCE_Z: float = 18.0
const GAP_HALF: float = 6.0
const HORDE_COUNT: int = 1000
const PAD_RADIUS: float = 6.0
const LAYOFF_DELAY: float = 1.1
const REGROUP_COOLDOWN_MS: int = 15000
const FLOOR_NAME: String = "THE ROOF: CARROW HEIGHTS"
const SCARE_POOL: Array = [["footsteps", 2], ["breath", 2], ["whisper", 1], ["stalker", 1]]
const PAD_LOCAL: Vector3 = Vector3(0.0, 0.2, 34.0)
const ROOF_COUNT: int = 11  # rooftops between the lot and the tower
const TOWER_W: float = 18.0
const TOWER_RISE: float = 10.5  # m the tower's helipad stands over the last roof (6 ledges)
const STEP_H: float = 1.75  # m up per fire-escape ledge (a standing mantle reaches 2.1)
const HELI_READY: float = 30.0  # s the pilot needs with someone on the pad
const ABOARD_RADIUS: float = 4.5
const JUMPER_ROOFS: Array[int] = [3, 6, 9]  # a Jumper waits on each of these roofs
const CHECKPOINT_ROOFS: Array[int] = [4, 8]  # a checkpoint on each of these, then the helipad
const WAKE_RANGE: float = 55.0  # m: a Jumper further than this from everyone sleeps
const MOON_DIR: Vector3 = Vector3(0.35, 0.42, -0.84)  # where the moon hangs (the sky shader agrees)
const TASKS: Array[String] = [
	"Get over the fence (the dumpster, or a teammate's head)",
	"Reach the gap in the wall",
	"Cross the rooftops to the tower (0 of 11)",
	"Climb the fire escape to the helipad",
	"Hold the pad while the pilot spins her up",
	"Everyone aboard",
]
const TASK_ROOFS: int = 2
const TASK_ESCAPE: int = 3
const TASK_PAD: int = 4
const TASK_ABOARD: int = 5
## How you get onto a roof from the one before it.
enum Link { JUMP, PLANK, DROP, CLIMB, PIPE }
const LINK_NAMES: Array[String] = ["a jump", "a plank", "a drop", "a climb", "a pipe"]
const SLOGANS: Array[String] = [
	"DEEZ INDUSTRIAL FASTENERS\nHOLDING IT TOGETHER SINCE 1931",
	"CARROW HEIGHTS DENTAL\nWE SEE YOU SMILING",
	"NUTBROOK SAVINGS & LOAN\nYOUR FUTURE, CHAINED TO OURS",
	"PAPPY PEPPERONI'S\nOPEN ALL NIGHT (NOT ANY MORE)",
]

## One rooftop of the route. Local coordinates (the lot's centre is the origin, its roof y 0).
class Roof:
	var rect: Rect2  # x, z footprint
	var y: float  # the roof, local
	var link: int = Link.JUMP  # how you arrive from the previous roof
	var gap: float = 0.0  # m of street between this roof's south edge and the previous roof
	var cross_x: float = 0.0  # x of the crossing onto this roof
	var enter: Vector3  # where you land, local
	var exit: Vector3  # where you leave for the next roof (its cross_x, this roof's north edge)
	var vents: Array[Vector3] = []  # the swarm's spawn spots
	var reached: bool = false
	func center() -> Vector3:
		return Vector3(rect.get_center().x, y, rect.get_center().y)

var origin: Vector3 = Vector3.ZERO  # world position of the lot's centre at roof level
var embedded: bool = false  # part of the Stack (LevelStack is the "level"), not a level of its own
var checkpoint_index: int = 0
var spawn_position: Vector3 = PAD_LOCAL
var spawn_facing: float = 0.0  # yaw 0 looks toward -z: at the horde
var test_points: Dictionary = {}
var horde: Horde
var field: HordeField
var launchers: Array[Launcher] = []
var launcher_homes: Array[Vector3] = []
var horde_count: int = HORDE_COUNT  # tests can shrink it
var seed_value: int = YellowRooms.DEFAULT_SEED  # the run's seed: a different district every time
var roofs: Array[Roof] = []  # roofs[0] is the lot; 1..ROOF_COUNT the route; the last the tower
var tower_top: Vector3 = Vector3.ZERO  # local: the centre of the helipad
var escape_dir: float = 1.0  # which way along the tower face the fire escape climbs (+x or -x)
var escape_steps: Array[Vector3] = []  # local: the top centre of each landing, bottom first
var root: Node3D
var furthest_roof: int = 0  # replicated: how far the Line has got (for the HUD and the waves)
var rounds_spawned: int = 0  # replicated: every peer spawns waves up to this
var heli_fraction: float = 0.0  # replicated: 0..1 of the pilot's spin-up
var _waves: Array = []  # [[count, weights, local rect, kinds...], ...] per wave, in order
var _we: WorldEnvironment
var _layoff_pending: bool = false
var _last_layoff_msec: int = -100000
var _last_regroup_msec: int = -100000
var _tasks_set: bool = false
var _task_t: float = 0.0
var _rounds_done: int = 0
var _heli: Node3D
var _rotor: Node3D
var _tail_rotor: Node3D
var _heli_light: OmniLight3D
var _heli_sound: AudioStreamPlayer3D
var _pad_told: bool = false
var _pad_t: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _route_bounds: Rect2  # local x, z of every route roof and the tower, for the city round them
var _been_up: Dictionary = {}  # instance id -> true for every chain body that has stood up here


func _enter_tree() -> void:
	if has_node("Sync"):
		return
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	for prop in ["rounds_spawned", "heli_fraction", "furthest_roof"]:
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
	_rng.seed = SEED + seed_value * 3 + 11
	_lay_out_route()
	# The field covers the lot and the whole route; everything is the street until a roof is laid.
	var fx0 := minf(-SIZE * 0.5, _route_bounds.position.x) - 6.0
	var fx1 := maxf(SIZE * 0.5, _route_bounds.end.x) + 6.0
	var fz0 := _route_bounds.position.y - 6.0
	var fz1 := SIZE * 0.5 + 1.0
	field = HordeField.new()
	field.setup(Vector2(origin.x + fx0, origin.z + fz0), fx1 - fx0, fz1 - fz0, 1.0, origin.y - STREET_DROP)
	field.fill_void()
	field.set_floor_rect(Rect2(origin.x - SIZE * 0.5, origin.z - SIZE * 0.5, SIZE, SIZE), origin.y)
	for i in range(1, roofs.size()):
		var r := roofs[i]
		field.set_floor_rect(Rect2(r.rect.position + Vector2(origin.x, origin.z), r.rect.size), origin.y + r.y)
	_build()
	_build_waves()
	horde = Horde.new()
	horde.name = "Horde"
	horde.field = field
	horde.base_y = origin.y
	horde.enabled = not embedded
	add_child(horde)  # not under the root: the agents' positions are world positions already
	# Four Jumpers in front of the first of the swarm, and one waiting on a roof here and there.
	var homes: Array[Vector3] = []
	for i in 4:
		homes.append(Vector3(-15.0 + 10.0 * float(i), 0.0, -7.0))
	for k in JUMPER_ROOFS:
		if k < roofs.size() - 1:
			var c := roofs[k].center()
			homes.append(c + Vector3(0.0, 0.0, -roofs[k].rect.size.y * 0.25))
	for i in homes.size():
		var l := Launcher.new()
		l.name = "Launcher%d" % i
		l.position = homes[i]
		l.floor_y = origin.y + homes[i].y
		l.asleep = true
		root.add_child(l)
		launchers.append(l)
		launcher_homes.append(origin + homes[i])
	test_points["spawn"] = spawn_position
	test_points["l_spawn"] = spawn_position
	test_points["gap"] = origin + Vector3(0.0, 0.1, 0.0)
	test_points["fence_dumpster"] = origin + Vector3(-8.0, 0.1, 21.5)
	test_points["fence_top"] = origin + Vector3(-8.0, FENCE_H + 0.1, FENCE_Z)
	test_points["horde_center"] = origin + Vector3(0.0, 0.1, -30.0)
	test_points["north"] = origin + Vector3(0.0, 0.1, -10.0)
	test_points["launcher0"] = origin + homes[0]
	test_points["lot_edge"] = origin + roofs[0].exit + Vector3(0.0, 0.1, 0.0)
	test_points["l_lot_edge"] = test_points["lot_edge"]
	for i in range(1, roofs.size() - 1):
		test_points["roof%d" % i] = origin + roofs[i].enter + Vector3(0.0, 0.1, 0.0)
		test_points["l_roof%d" % i] = test_points["roof%d" % i]
		var key := ""
		match roofs[i].link:
			Link.PLANK, Link.PIPE:
				key = "plank"
			Link.CLIMB:
				key = "climb"
			Link.DROP:
				key = "drop"
		# The first of each kind of crossing: where you stand before it (the previous roof's exit).
		if key != "" and not test_points.has(key):
			test_points[key] = origin + roofs[i - 1].exit + Vector3(0.0, 0.1, 0.0)
			test_points["l_" + key] = test_points[key]
	var last := roofs[roofs.size() - 2]
	test_points["escape_foot"] = origin + Vector3(_escape_x(), last.y + 0.1, last.rect.position.y + 2.6)
	test_points["l_escape_foot"] = test_points["escape_foot"]
	test_points["helipad"] = origin + tower_top + Vector3(0.0, 0.1, 0.0)
	test_points["heli"] = origin + tower_top
	# Checkpoints along the route and on the helipad.
	var cp := checkpoint_index
	for k in CHECKPOINT_ROOFS:
		cp += 1
		var c := roofs[k].center()
		add_child(Checkpoint.create("Checkpoint%d" % cp, cp, origin + c + Vector3(0.0, 0.1, 0.0), 0.0, "Roof %d of %d. Keep going north: the tower with the red light is the way out." % [k, ROOF_COUNT]))
	cp += 1
	add_child(Checkpoint.create("Checkpoint%d" % cp, cp, origin + tower_top + Vector3(-5.0, 0.1, 5.0), 0.0, "The helipad. Hold it while the pilot spins her up, then everyone aboard."))


func helipad_checkpoint_index() -> int:
	return checkpoint_index + CHECKPOINT_ROOFS.size() + 1


# --- The route -----------------------------------------------------------------------------------

## Eleven roofs north of the lot, then the tower. Each is placed off the last one's north edge:
## a short gap to jump (most of them), a long one with a plank or a pipe across, a drop onto a
## lower roof, or a higher roof butted against this one with a unit to climb. The crossing
## point wanders left and right so the route snakes; heights stay within a storey or three of
## the lot so the city round it reads.
func _lay_out_route() -> void:
	roofs.clear()
	var lot := Roof.new()
	lot.rect = Rect2(-SIZE * 0.5, -SIZE * 0.5, SIZE, SIZE)
	lot.y = 0.0
	lot.cross_x = 0.0
	lot.enter = PAD_LOCAL
	roofs.append(lot)
	var prev := lot
	var last_link := -1
	for i in range(1, ROOF_COUNT + 1):
		var r := Roof.new()
		var w := _rng.randf_range(13.0, 22.0)
		var d := _rng.randf_range(11.0, 18.0)
		# The link: the first is always a plain jump; no two climbs or drops in a row; the height
		# is kept within -14..+9 of the lot.
		var link := Link.JUMP
		if i > 1:
			var roll := _rng.randf()
			if roll < 0.4:
				link = Link.JUMP
			elif roll < 0.58:
				link = Link.PLANK
			elif roll < 0.74:
				link = Link.DROP
			elif roll < 0.92:
				link = Link.CLIMB
			else:
				link = Link.PIPE
			if link == last_link and (link == Link.CLIMB or link == Link.DROP):
				link = Link.JUMP
			if link == Link.DROP and prev.y < 4.0:
				link = Link.CLIMB
			if link == Link.CLIMB and prev.y > 11.0:
				link = Link.JUMP
		var gap := 0.0
		var dy := 0.0
		match link:
			Link.JUMP:
				gap = _rng.randf_range(2.4, 3.4)
				dy = _rng.randf_range(-2.4, 0.5)
			Link.PLANK:
				gap = _rng.randf_range(4.5, 6.5)
			Link.PIPE:
				gap = _rng.randf_range(4.0, 6.0)
			Link.DROP:
				gap = _rng.randf_range(1.4, 2.4)
				dy = _rng.randf_range(-5.0, -3.4)
			Link.CLIMB:
				gap = 0.0
				dy = _rng.randf_range(2.6, 3.5)
		r.link = link
		r.gap = gap
		r.y = clampf(prev.y + dy, 0.0, 14.0)  # never below the lot: the Stack tells the roof from the pizzeria by height
		# The crossing: within the previous roof, near its last crossing, and this roof is placed
		# so it contains it with room either side.
		var cx := clampf(prev.cross_x + _rng.randf_range(-6.0, 6.0), prev.rect.position.x + 3.5, prev.rect.end.x - 3.5)
		if i == 1:
			cx = _rng.randf_range(-20.0, 20.0)
		var center_x := cx + _rng.randf_range(-(w * 0.5 - 4.0), w * 0.5 - 4.0)
		var z_front := prev.rect.position.y - gap
		r.rect = Rect2(center_x - w * 0.5, z_front - d, w, d)
		r.cross_x = cx
		r.enter = Vector3(cx, r.y, z_front - 1.6)
		prev.exit = Vector3(cx, prev.y, prev.rect.position.y + 1.6)
		roofs.append(r)
		prev = r
		last_link = link
	# The tower: butted against the last roof's north edge, the fire escape up its south face.
	var tower := Roof.new()
	tower.link = Link.CLIMB
	tower.y = prev.y + TOWER_RISE
	var tx := clampf(prev.rect.get_center().x, prev.rect.position.x + TOWER_W * 0.5 - 2.0, prev.rect.end.x - TOWER_W * 0.5 + 2.0)
	tower.rect = Rect2(tx - TOWER_W * 0.5, prev.rect.position.y - TOWER_W, TOWER_W, TOWER_W)
	tower.cross_x = _escape_x_for(prev, tower)
	escape_dir = 1.0 if tower.rect.end.x - tower.cross_x >= tower.cross_x - tower.rect.position.x else -1.0
	tower.enter = Vector3(tx, tower.y, prev.rect.position.y - TOWER_W * 0.5)
	prev.exit = Vector3(tower.cross_x, prev.y, prev.rect.position.y + 2.6)
	roofs.append(tower)
	tower_top = Vector3(tx, tower.y, tower.rect.get_center().y)
	# The vents the swarm comes out of: two a roof, never in a crossing lane (they're solid).
	for i in range(1, ROOF_COUNT + 1):
		var r := roofs[i]
		var lanes: Array[float] = [r.enter.x, r.exit.x]
		for k in 2:
			var best_x := r.rect.get_center().x
			var best_d := -1.0
			for _try in 8:
				var x := _rng.randf_range(r.rect.position.x + 1.6, r.rect.end.x - 1.6)
				var d := 1.0e9
				for lx in lanes:
					d = minf(d, absf(x - lx))
				if d > best_d:
					best_d = d
					best_x = x
				if d > 3.0:
					break
			r.vents.append(Vector3(best_x, r.y, r.rect.position.y + r.rect.size.y * (0.3 + 0.4 * float(k))))
	_route_bounds = roofs[1].rect
	for i in range(2, roofs.size()):
		_route_bounds = _route_bounds.merge(roofs[i].rect)


## x of the fire escape: along the tower's south face, inside the last roof.
func _escape_x_for(last: Roof, tower: Roof) -> float:
	return clampf(tower.rect.position.x + 2.5, last.rect.position.x + 3.0, last.rect.end.x - 3.0)



## How wide each fire-escape landing is: the six of them fit along the face from the foot.
func _escape_step_w(tower: Roof) -> float:
	var steps := int(ceil(TOWER_RISE / STEP_H))
	var room := (tower.rect.end.x - tower.cross_x) if escape_dir > 0.0 else (tower.cross_x - tower.rect.position.x)
	return clampf((room - 1.0) / float(steps), 1.8, 2.6)

func _escape_x() -> float:
	return roofs[roofs.size() - 1].cross_x


## The roof a world position stands on: 0 the lot, 1..ROOF_COUNT the route, ROOF_COUNT + 1 the
## tower's helipad, -1 nowhere (the street, the air over a gap).
func roof_at(p: Vector3) -> int:
	var l := p - origin
	for i in roofs.size():
		var r := roofs[i]
		if r.rect.grow(0.8).has_point(Vector2(l.x, l.z)) and l.y > r.y - 1.2 and l.y < r.y + 4.5:
			return i
	return -1


# --- Building it -----------------------------------------------------------------------------------

func _build() -> void:
	var batch := LevelKit.BoxBatch.new()
	# The lot and its walls.
	batch.add(Vector3(0.0, -0.2, 0.0), Vector3(SIZE + 2.0, 0.4, SIZE + 2.0), "asphalt")
	# A parapet round the edge: knee-high, so the city is in view and the drop is real. The crowd
	# can't cross it (blocked cells); you can, if you jump, and then it's a long way down. The
	# north side has an opening where the route leaves.
	var cx1 := roofs[1].cross_x
	var open_half := 3.0
	var north_z := -SIZE * 0.5
	var left_w := (cx1 - open_half) - (-SIZE * 0.5 - 0.3)
	var right_w := (SIZE * 0.5 + 0.3) - (cx1 + open_half)
	_wall(batch, Vector3(-SIZE * 0.5 - 0.3 + left_w * 0.5, PARAPET_H * 0.5, north_z), Vector3(left_w, PARAPET_H, 0.6))
	_wall(batch, Vector3(cx1 + open_half + right_w * 0.5, PARAPET_H * 0.5, north_z), Vector3(right_w, PARAPET_H, 0.6))
	for s: float in [-1.0, 1.0]:
		batch.add(Vector3(cx1 + s * open_half, 0.8, north_z), Vector3(0.3, 1.6, 0.3), "hazard")
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
	# A wrecked van (boxes) near the gap: something to climb and shoot from.
	batch.add(Vector3(10.0, 0.9, 6.0), Vector3(2.2, 1.8, 5.0), "van")
	batch.add(Vector3(10.0, 1.95, 5.0), Vector3(2.0, 0.3, 2.4), "van")
	_block(10.0, 6.0, 2.2, 5.0)
	# The route: the roofs, the links between them, the tower.
	for i in range(1, roofs.size() - 1):
		_build_roof(batch, i)
	_build_tower(batch)
	batch.build(root, "Lot")
	# Light: the moon (the sky shader hangs it in the same place), and sodium floods on posts.
	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.6, 0.66, 0.9)
	moon.light_energy = 0.42
	moon.transform = Transform3D(Basis.looking_at(-MOON_DIR.normalized(), Vector3.UP), Vector3.ZERO)
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 120.0
	root.add_child(moon)
	for p: Vector3 in [Vector3(-12.0, 6.0, 30.0), Vector3(12.0, 6.0, 30.0), Vector3(-10.0, 6.0, -2.0), Vector3(10.0, 6.0, -2.0), Vector3(0.0, 6.0, -22.0), Vector3(cx1, 6.0, -44.0)]:
		_lamp_post(p, 3.0, 22.0)
	add_child(Checkpoint.create("Checkpoint%d" % checkpoint_index, checkpoint_index, origin + PAD_LOCAL, spawn_facing, first_objective()))
	var sign := Label3D.new()
	sign.text = "LOADING LOT  -  HOLD THE GAP"
	sign.font_size = 64
	sign.pixel_size = 0.02
	sign.double_sided = false
	sign.modulate = Color(0.95, 0.8, 0.2)
	sign.outline_size = 12
	sign.position = Vector3(0.0, 4.6, 0.0)
	root.add_child(sign)
	_route_sign(Vector3(cx1, 2.6, north_z + 0.4), "THE HELIPAD  -  %d ROOFS NORTH" % (ROOF_COUNT + 1))


func _wall(batch: LevelKit.BoxBatch, center: Vector3, size: Vector3, key: String = "concrete") -> void:
	batch.add(center, size, key)
	_block(center.x, center.z, size.x, size.z)


## A sodium flood on a post.
func _lamp_post(p: Vector3, energy: float, range_m: float) -> void:
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.7, 0.35)
	lamp.light_energy = energy
	lamp.omni_range = range_m
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
	var head := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.5, 0.2, 0.5)
	head.mesh = hm
	head.position = p + Vector3(0.0, 0.1, 0.0)
	head.material_override = LevelKit.mat("street_lamp")
	root.add_child(head)


func _route_sign(at: Vector3, text: String) -> void:
	var sign := Label3D.new()
	sign.text = text
	sign.font_size = 48
	sign.pixel_size = 0.0065
	sign.double_sided = false  # read from the side you come from, not mirrored from the roof ahead
	sign.modulate = Color(0.4, 1.0, 0.5)
	sign.outline_size = 8
	sign.position = at
	root.add_child(sign)


## One roof of the route: the building under it from the street up, windows, a knee-high
## parapet down both sides (never across the crossings), the link from the roof before it, and
## the dressing: vents the swarm comes out of, units, a bulkhead, a tank, a lamp, a sign.
func _build_roof(batch: LevelKit.BoxBatch, i: int) -> void:
	var r := roofs[i]
	var prev := roofs[i - 1]
	var base := -STREET_DROP
	var c2 := r.rect.get_center()
	var size := Vector3(r.rect.size.x, r.y - base, r.rect.size.y)
	var c := Vector3(c2.x, base + size.y * 0.5, c2.y)
	var key: String = ["brick", "tower", "concrete", "brick"][_rng.randi_range(0, 3)]
	batch.add(c, size, key)
	_windows(batch, _rng, c, size, 3.2, 2.6, 0.3 if key != "concrete" else 0.18, true)
	# Gravel on top, a parapet down the east and west edges.
	batch.add(Vector3(c2.x, r.y + 0.01, c2.y), Vector3(r.rect.size.x, 0.02, r.rect.size.y), "asphalt", false)
	for s: float in [-1.0, 1.0]:
		var px := c2.x + s * (r.rect.size.x * 0.5 - 0.2)
		_wall(batch, Vector3(px, r.y + ROOF_PARAPET_H * 0.5, c2.y), Vector3(0.4, ROOF_PARAPET_H, r.rect.size.y))
	# Hazard paint along the crossing edges.
	batch.add(Vector3(r.cross_x, r.y + 0.02, r.rect.position.y + 0.25), Vector3(5.0, 0.02, 0.5), "hazard", false)
	if i < roofs.size() - 2:
		batch.add(Vector3(r.exit.x, r.y + 0.02, r.rect.position.y + 0.25), Vector3(5.0, 0.02, 0.5), "hazard", false)
	# The link from the previous roof.
	var south := r.rect.end.y  # this roof's south edge (max z)
	match r.link:
		Link.PLANK:
			# A scaffold board across, flush with both roofs (no lip to trip on), chocked at the ends.
			var top := maxf(prev.y, r.y)
			batch.add(Vector3(r.cross_x, top - 0.07, south + r.gap * 0.5), Vector3(0.7, 0.14, r.gap + 1.8), "tank")
			for s: float in [-1.0, 1.0]:
				for e: float in [-1.0, 1.0]:
					batch.add(Vector3(r.cross_x + e * 0.5, top + 0.06, south + r.gap * 0.5 + s * (r.gap * 0.5 + 0.6)), Vector3(0.18, 0.12, 0.3), "cardboard", false)
		Link.PIPE:
			# A ventilation duct laid across, its top flush with both roofs.
			var top := maxf(prev.y, r.y)
			batch.add(Vector3(r.cross_x, top - 0.25, south + r.gap * 0.5), Vector3(0.6, 0.5, r.gap + 1.6), "steel_dark")
			for k in int(r.gap / 1.2):
				batch.add(Vector3(r.cross_x, top - 0.25, south + 0.6 + 1.2 * float(k)), Vector3(0.66, 0.56, 0.08), "steel", false)
		Link.CLIMB:
			# A unit against this roof's wall on the lower roof: a mantle up, then a mantle onto
			# the roof. A drain pipe beside it, for the look.
			var unit := Vector3(r.cross_x, prev.y + 0.8, south + 1.0)
			batch.add(unit, Vector3(2.4, 1.6, 1.6), "steel")
			batch.add(unit + Vector3(0.0, 0.81, 0.0), Vector3(1.6, 0.04, 1.0), "dark", false)
			_block(unit.x, unit.z, 2.4, 1.6)
			batch.add(Vector3(r.cross_x + 2.2, (prev.y + r.y) * 0.5, south + 0.25), Vector3(0.25, r.y - prev.y, 0.25), "tank", false)
		Link.DROP:
			batch.add(Vector3(prev.exit.x, prev.y + 0.02, prev.rect.position.y + 0.25), Vector3(5.0, 0.02, 0.5), "hazard", false)
		_:
			pass
	# Dressing, kept out of the strips you cross on.
	var keep: Array[float] = [r.enter.x, r.exit.x]
	for v in r.vents:
		batch.add(v + Vector3(0.0, 0.35, 0.0), Vector3(0.9, 0.7, 0.9), "steel_dark")
		batch.add(v + Vector3(0.0, 0.72, 0.0), Vector3(0.7, 0.04, 0.7), "dark", false)
		_block(v.x, v.z, 0.9, 0.9)
	var units := _rng.randi_range(1, 3)
	for k in units:
		var p := _spot(r, keep, 1.6)
		if p.y > -1.0e8:
			batch.add(p + Vector3(0.0, 0.7, 0.0), Vector3(1.4, 1.4, 1.4), "steel")
			batch.add(p + Vector3(0.0, 1.41, 0.0), Vector3(1.0, 0.03, 1.0), "dark", false)
			_block(p.x, p.z, 1.4, 1.4)
	if _rng.randf() < 0.4:
		var p := _spot(r, keep, 2.4)
		if p.y > -1.0e8:
			batch.add(p + Vector3(0.0, 1.3, 0.0), Vector3(3.0, 2.6, 3.0), "concrete")
			batch.add(p + Vector3(0.0, 1.0, 1.52), Vector3(0.9, 2.0, 0.06), "dark", false)
			batch.add(p + Vector3(0.0, 2.75, 0.0), Vector3(3.2, 0.3, 3.2), "concrete", false)
			_block(p.x, p.z, 3.0, 3.0)
	if _rng.randf() < 0.3:
		var p := _spot(r, keep, 2.2)
		if p.y > -1.0e8:
			_water_tank(p)
			_block(p.x, p.z, 3.2, 3.2)
	if _rng.randf() < 0.3:
		var p := _spot(r, keep, 1.0)
		if p.y > -1.0e8:
			batch.add(p + Vector3(0.0, 6.0, 0.0), Vector3(0.25, 12.0, 0.25), "steel_dark", false)
			batch.add(p + Vector3(0.0, 12.2, 0.0), Vector3(0.35, 0.35, 0.35), "led_red", false)
	if _rng.randf() < 0.35:
		var p := _spot(r, keep, 1.6)
		if p.y > -1.0e8:
			batch.add(p + Vector3(0.0, 0.2, 0.0), Vector3(2.2, 0.4, 2.2), "heli_glass")  # a skylight; you can stand on it
	# A lamp at the landing so you can see where you land, and a sign at the exit.
	_lamp_post(r.enter + Vector3(3.0 if r.enter.x < c2.x else -3.0, 5.0, -1.0), 2.4, 18.0)
	if i < roofs.size() - 2:
		var nxt := roofs[i + 1]
		_route_sign(r.exit + Vector3(0.0, 2.6, -1.0), "%d / %d   ->   %s" % [i, ROOF_COUNT, LINK_NAMES[nxt.link].to_upper()])
	else:
		_route_sign(r.exit + Vector3(0.0, 2.6, -1.0), "%d / %d   ->   THE FIRE ESCAPE" % [i, ROOF_COUNT])
	if _rng.randf() < 0.25:
		var p := _spot(r, keep, 2.0)
		if p.y > -1.0e8:
			var bb := Vector3(p.x, r.y + 4.0, p.z)
			batch.add(bb, Vector3(7.0, 3.6, 0.3), "billboard", false)
			for s: float in [-1.0, 1.0]:
				batch.add(bb + Vector3(s * 2.6, -2.6, 0.0), Vector3(0.2, 1.6, 0.2), "steel_dark", false)
			var text := Label3D.new()
			text.text = SLOGANS[_rng.randi_range(0, SLOGANS.size() - 1)]
			text.font_size = 72
			text.pixel_size = 0.011
			text.modulate = Color(0.08, 0.06, 0.05)
			text.position = bb + Vector3(0.0, 0.0, 0.2)
			root.add_child(text)
			_block(p.x, p.z, 6.0, 0.6)


## A spot on a roof clear of its crossing strips and edges, or (0, -1e9, 0) after a few tries.
func _spot(r: Roof, keep: Array[float], half: float) -> Vector3:
	for _try in 12:
		var x := _rng.randf_range(r.rect.position.x + 1.2 + half, r.rect.end.x - 1.2 - half)
		var z := _rng.randf_range(r.rect.position.y + 2.0 + half, r.rect.end.y - 2.0 - half)
		var ok := true
		for kx in keep:
			if absf(x - kx) < 3.0 + half:
				ok = false
		for v in r.vents:
			if absf(x - v.x) < 1.2 + half and absf(z - v.z) < 1.2 + half:
				ok = false
		if ok:
			return Vector3(x, r.y, z)
	return Vector3(0.0, -1.0e9, 0.0)


## The way out: the tower at the end of the route, butted against the last roof, with a fire
## escape of ledges zigzagging up its south face to the helipad, where the helicopter waits.
## Nothing on six legs climbs it; the Weavers do, and what flies.
func _build_tower(batch: LevelKit.BoxBatch) -> void:
	var tower := roofs[roofs.size() - 1]
	var last := roofs[roofs.size() - 2]
	var base := -STREET_DROP
	var c2 := tower.rect.get_center()
	var size := Vector3(TOWER_W, tower.y - base, TOWER_W)
	var c := Vector3(c2.x, base + size.y * 0.5, c2.y)
	batch.add(c, size, "concrete")
	_windows(batch, _rng, c, size, 4.0, 3.0, 0.2, true)
	# The helipad: a parapet (with a gap over the fire escape's last landing), the painted ring
	# and letter, and the lights round it.
	var top := tower_top
	var steps_n := int(ceil(TOWER_RISE / STEP_H))
	var gap_x := tower.cross_x + escape_dir * _escape_step_w(tower) * float(steps_n - 1) - top.x
	for s: float in [-1.0, 1.0]:
		batch.add(top + Vector3(s * (TOWER_W * 0.5 - 0.2), 0.5, 0.0), Vector3(0.4, 1.0, TOWER_W), "concrete")
	batch.add(top + Vector3(0.0, 0.5, -(TOWER_W * 0.5 - 0.2)), Vector3(TOWER_W - 0.8, 1.0, 0.4), "concrete")
	var x0 := -(TOWER_W * 0.5 - 0.4)
	var x1 := TOWER_W * 0.5 - 0.4
	var g0 := gap_x - 1.6
	var g1 := gap_x + 1.6
	if g0 - x0 > 0.1:
		batch.add(top + Vector3((x0 + g0) * 0.5, 0.5, TOWER_W * 0.5 - 0.2), Vector3(g0 - x0, 1.0, 0.4), "concrete")
	if x1 - g1 > 0.1:
		batch.add(top + Vector3((g1 + x1) * 0.5, 0.5, TOWER_W * 0.5 - 0.2), Vector3(x1 - g1, 1.0, 0.4), "concrete")
	batch.add(top + Vector3(0.0, 0.01, 0.0), Vector3(12.0, 0.02, 12.0), "helipad", false)
	for s: float in [-1.0, 1.0]:
		batch.add(top + Vector3(s * 1.8, 0.02, 0.0), Vector3(0.5, 0.02, 5.0), "paint", false)
	batch.add(top + Vector3(0.0, 0.02, 0.0), Vector3(3.6, 0.02, 0.5), "paint", false)
	for k in 12:
		var a := float(k) / 12.0 * TAU
		batch.add(top + Vector3(cos(a) * 6.5, 0.1, sin(a) * 6.5), Vector3(0.3, 0.2, 0.3), "street_lamp", false)
	# The beacon: a mast with a red light you can see from the lot.
	batch.add(top + Vector3(TOWER_W * 0.5 - 1.5, 6.0, -TOWER_W * 0.5 + 1.5), Vector3(0.3, 12.0, 0.3), "steel_dark", false)
	batch.add(top + Vector3(TOWER_W * 0.5 - 1.5, 12.3, -TOWER_W * 0.5 + 1.5), Vector3(0.7, 0.7, 0.7), "led_red", false)
	var beacon := OmniLight3D.new()
	beacon.light_color = Color(1.0, 0.1, 0.1)
	beacon.light_energy = 3.0
	beacon.omni_range = 30.0
	beacon.position = top + Vector3(TOWER_W * 0.5 - 1.5, 12.3, -TOWER_W * 0.5 + 1.5)
	root.add_child(beacon)
	# The fire escape: a staircase of landings up the south face from the last roof, each a
	# mantle (STEP_H) above the last and a step to the side, so you walk into the next one's
	# side and tap Space. Solid from the street up: nothing to hit your head on, nothing to fall
	# through. It runs toward the side of the tower with more room; the last landing is level
	# with the helipad, where the parapet has a gap.
	var south := tower.rect.end.y
	var steps := int(ceil(TOWER_RISE / STEP_H))
	var dir := escape_dir

	var w := _escape_step_w(tower)
	for i in steps:
		var y := last.y + STEP_H * float(i + 1)
		if i == steps - 1:
			y = tower.y
		var x := tower.cross_x + dir * w * float(i)
		var h := y - base
		batch.add(Vector3(x, base + h * 0.5, south + 0.8), Vector3(w, h, 1.6), "fire_escape")
		batch.add(Vector3(x, y + 0.55, south + 1.63), Vector3(w, 0.9, 0.06), "fire_escape", false)  # the railing, outside
		batch.add(Vector3(x, y - 0.06, south + 1.62), Vector3(w + 0.02, 0.12, 0.05), "hazard", false)
		# A floor at its own height: no roach takes a 1.75 m step, a Weaver climbs it after you.
		field.set_floor_rect(Rect2(origin.x + x - w * 0.5, origin.z + south, w, 1.6), origin.y + y)
		escape_steps.append(Vector3(x, y, south + 0.8))
	# A dumpster at the foot: the first ledge is a mantle from its lid.
	batch.add(Vector3(tower.cross_x, last.y + 0.6, south + 2.6), Vector3(2.0, 1.2, 1.2), "dumpster")
	_block(tower.cross_x, south + 2.6, 2.0, 1.2)
	_route_sign(Vector3(tower.cross_x - escape_dir * 2.6, last.y + 2.4, south + 0.05), "FIRE ESCAPE  ->  HELIPAD")
	_lamp_post(Vector3(tower.cross_x + 4.0, last.y + 5.0, south + 3.0), 2.4, 18.0)
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


## Carrow Heights round the route: a street canyon below the parapets, a near ring of tenements
## round the lot (not to the north: that's the route), buildings flanking the route down both
## sides, a billboard or two, and a far skyline. All boxes in the batch (one MultiMesh per
## material), nothing the crowd walks on.
func _build_city(batch: LevelKit.BoxBatch) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + seed_value + 5
	var base := -STREET_DROP
	var avoid := _route_bounds.grow(9.0).merge(Rect2(-SIZE * 0.5 - 9.0, -SIZE * 0.5 - 9.0, SIZE + 18.0, SIZE + 18.0))
	# The street, far below, with its lamps along the canyon round the lot.
	batch.add(Vector3(0.0, base - 0.2, 0.0), Vector3(1000.0, 0.4, 1000.0), "asphalt", false)
	for i in 40:
		var a := float(i) / 40.0 * TAU
		var r := SIZE * 0.5 + 8.0 + 4.0 * sin(a * 3.0)
		var p := Vector3(cos(a) * r, base + 4.0, sin(a) * r)
		if avoid.has_point(Vector2(p.x, p.z)) and p.z < -SIZE * 0.5:
			continue
		batch.add(p, Vector3(0.3, 0.3, 0.3), "street_lamp", false)
		batch.add(p - Vector3(0.0, 2.0, 0.0), Vector3(0.12, 4.0, 0.12), "steel_dark", false)
	# The near ring: 3-4 buildings a side, across a street from the parapet, not to the north.
	for side in range(1, 4):
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
				1:
					c = Vector3(along, 0.0, out + d * 0.5)
					size = Vector3(w, top - base, d)
				2:
					c = Vector3(-(out + d * 0.5), 0.0, along)
					size = Vector3(d, top - base, w)
				_:
					c = Vector3(out + d * 0.5, 0.0, along)
					size = Vector3(d, top - base, w)
			_backdrop(batch, rng, c, size, top, base)
	# Flanking the route: a row of buildings down each side, across a street from the roofs.
	var z := -SIZE * 0.5 - 4.0
	var z_end := _route_bounds.position.y - 10.0
	while z > z_end:
		var d := rng.randf_range(14.0, 26.0)
		var zc := z - d * 0.5
		for s: float in [-1.0, 1.0]:
			if rng.randf() < 0.15:
				continue
			var w := rng.randf_range(14.0, 28.0)
			var edge := _route_bounds.end.x if s > 0.0 else _route_bounds.position.x
			var xc := edge + s * (rng.randf_range(9.0, 24.0) + w * 0.5)
			var top := rng.randf_range(-16.0, 34.0)
			_backdrop(batch, rng, Vector3(xc, 0.0, zc), Vector3(w, top - base, d), top, base)
		z -= d + rng.randf_range(3.0, 9.0)
	# Beyond the tower: more of the city, so the end of the route isn't the end of the world.
	for k in 6:
		var w := rng.randf_range(18.0, 34.0)
		var top := rng.randf_range(-10.0, 40.0)
		var xc := _route_bounds.get_center().x + rng.randf_range(-70.0, 70.0)
		var zc := z_end - 14.0 - rng.randf_range(0.0, 60.0) - w * 0.5
		_backdrop(batch, rng, Vector3(xc, 0.0, zc), Vector3(w, top - base, w), top, base)
	# The far skyline: big dark slabs with a few lights on, a long way off, clear of the route.
	for i in 26:
		var a := float(i) / 26.0 * TAU + rng.randf_range(-0.1, 0.1)
		var r := rng.randf_range(190.0, 300.0)
		var w := rng.randf_range(28.0, 56.0)
		var h := rng.randf_range(40.0, 130.0)
		var c := Vector3(cos(a) * r, base + h * 0.5, sin(a) * r)
		if avoid.grow(30.0).intersects(Rect2(c.x - w * 0.5, c.z - w * 0.5, w, w)):
			continue
		batch.add(c, Vector3(w, h, w), "tower_far", false)
		_windows(batch, rng, c, Vector3(w, h, w), 7.0, 6.0, 0.12, false)
		if rng.randf() < 0.3:
			batch.add(Vector3(c.x, base + h + 1.0, c.z), Vector3(0.6, 0.6, 0.6), "led_red", false)


## A building nobody walks on: the box, its windows, a parapet, and a tank, a mast or a billboard
## on some.
func _backdrop(batch: LevelKit.BoxBatch, rng: RandomNumberGenerator, c: Vector3, size: Vector3, top: float, base: float) -> void:
	c.y = base + size.y * 0.5
	var key: String = ["brick", "tower", "concrete", "brick"][rng.randi_range(0, 3)]
	batch.add(c, size, key, false)
	_windows(batch, rng, c, size, 3.2, 2.6, 0.38 if key != "concrete" else 0.22, true)
	batch.add(Vector3(c.x, top + 0.5, c.z), Vector3(size.x + 0.4, 1.0, size.z + 0.4), "concrete", false)
	var roll := rng.randf()
	if roll < 0.3:
		_water_tank(Vector3(c.x + rng.randf_range(-3.0, 3.0), top + 1.0, c.z + rng.randf_range(-3.0, 3.0)))
	elif roll < 0.48:
		batch.add(Vector3(c.x, top + 9.0, c.z), Vector3(0.3, 16.0, 0.3), "steel_dark", false)
		batch.add(Vector3(c.x, top + 17.2, c.z), Vector3(0.4, 0.4, 0.4), "led_red", false)
	elif roll < 0.6 and top > 0.0:
		# A billboard facing the route (or the lot).
		var toward_x := c.x > _route_bounds.get_center().x
		var bb := Vector3(c.x + (-1.0 if toward_x else 1.0) * (size.x * 0.5 - 0.4), top + 5.5, c.z)
		batch.add(bb, Vector3(0.4, 7.0, 16.0), "billboard", false)
		var text := Label3D.new()
		text.text = SLOGANS[rng.randi_range(0, SLOGANS.size() - 1)]
		text.font_size = 96
		text.pixel_size = 0.018
		text.modulate = Color(0.08, 0.06, 0.05)
		text.position = bb + Vector3((-1.0 if toward_x else 1.0) * 0.25, 0.0, 0.0)
		text.rotation.y = PI * 0.5 if toward_x else -PI * 0.5
		root.add_child(text)


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
	return "The roof: over the fence, through the gap, then north across the rooftops to the tower with the red light. Up its fire escape to the helipad; hold the pad, then everyone aboard."


## Anyone on the Line up here? (Embedded, the crowd sleeps until then.)
func anyone_here() -> bool:
	for p in Net.get_players():
		if p.global_position.y > origin.y - 1.0:
			return true
	return false


# --- The waves -------------------------------------------------------------------------------------

## Every wave, in the order they can be triggered, the same on every peer: the lot's first two,
## then one per roof as you land on it (roaches out of its vents; from the third roof, Weavers
## waiting on the roof ahead to swing at you; from the seventh, Flitters over it), then the
## helipad's bats. Each entry: [[count, weights, local rect], ...].
func _build_waves() -> void:
	_waves.clear()
	var scale := float(horde_count) / float(HORDE_COUNT)
	_waves.append([[int(400.0 * scale), [1.0, 0.0, 0.0], Rect2(-44.0, -46.0, 88.0, 30.0)]])
	_waves.append([[int(250.0 * scale), [0.7, 0.3, 0.0], Rect2(-48.0, -30.0, 96.0, 20.0)]])
	var wrng := RandomNumberGenerator.new()
	wrng.seed = SEED + seed_value * 7 + 3
	for k in range(1, ROOF_COUNT + 1):
		var groups: Array = []
		var r := roofs[k]
		var roaches := int(wrng.randi_range(36, 52) * scale)
		for v in r.vents:  # out of the vents, not from under your feet
			groups.append([roaches / r.vents.size(), [1.0, 0.0, 0.0], Rect2(v.x - 1.6, v.z - 1.6, 3.2, 3.2)])
		if k >= 3:
			var ahead := roofs[mini(k + 1, ROOF_COUNT)]
			groups.append([int(wrng.randi_range(8, 12) * scale), [0.0, 1.0, 0.0], ahead.rect.grow(-1.5)])
		if k >= 7:
			groups.append([int(wrng.randi_range(10, 14) * scale), [0.0, 0.0, 1.0], r.rect.grow(-1.0)])
		_waves.append(groups)
	var tower := roofs[roofs.size() - 1]
	_waves.append([[int(100.0 * scale), [0.0, 0.0, 1.0], tower.rect.grow(14.0)]])


func wave_count() -> int:
	return _waves.size()


## Every peer: spawn waves up to the replicated count, identically.
func _tick_rounds() -> void:
	while _rounds_done < rounds_spawned and _rounds_done < _waves.size():
		var groups: Array = _waves[_rounds_done]
		for g in groups.size():
			var r: Array = groups[g]
			var area: Rect2 = r[2]
			var weights: Array[float] = []
			for w in r[1]:
				weights.append(float(w))
			horde.spawn_group(int(r[0]), Rect2(area.position + Vector2(origin.x, origin.z), area.size), SEED + seed_value + _rounds_done * 7 + g * 131, weights)
		_rounds_done += 1


## Server: waves up to and including this one pour in (every peer spawns from the count).
func _start_round(k: int) -> void:
	if not multiplayer.is_server() or rounds_spawned >= k:
		return
	rounds_spawned = k
	if k == 2:
		GameState.post_message("MORE OF THEM. The spiders are faster than you: shoot, or keep moving.", 4.0)
	elif k == _waves.size():
		GameState.post_message("WINGS. They come down from above; only a gun stops them. Hold the pad.", 4.0)


## Tests and the bench: everything at once.
func debug_spawn_all_rounds() -> void:
	rounds_spawned = _waves.size()
	_tick_rounds()


## Tests: the pilot is ready now.
func debug_pad_ready() -> void:
	_pad_t = HELI_READY


func heli_position() -> Vector3:
	return _heli.global_position


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
	# A little more along the way: ammo on every third roof, a bomb on the fifth, a drink midway.
	for k in range(1, ROOF_COUNT + 1):
		var c := roofs[k].center()
		if k % 3 == 0:
			Net.spawn_pickup("ammo", origin + c + Vector3(1.5, 0.0, 0.0), 0)
		if k == 5:
			Net.spawn_pickup("bomb", origin + c + Vector3(-1.5, 0.0, 0.0), 0)
		if k == 6:
			Net.spawn_pickup("drink", origin + c + Vector3(0.0, 0.0, 1.5), 0)
		if k == 9:
			Net.spawn_pickup("airhorn", origin + c + Vector3(0.0, 0.0, -1.5), 0)
	if not embedded:
		server_arrive()


## Server: the Line has reached the lot (at once standalone; through the hatch in the Stack).
## The checklist goes up and the crowd wakes.
func server_arrive() -> void:
	if not multiplayer.is_server():
		return
	GameState.set_tasks(PackedStringArray(TASKS))
	_tasks_set = true
	_pad_told = false
	heli_fraction = 0.0
	if rounds_spawned < 1:
		rounds_spawned = 1
	GameState.post_message("THE ROOF. They came up out of the walls. Keep moving: north, roof to roof, to the tower with the red light.", 6.0)


func _physics_process(delta: float) -> void:
	_tick_rounds()
	_tick_helicopter(delta)
	# The swarm wakes when anyone is up here, on every peer (clients run the mass); a Jumper
	# wakes when someone is within range of it.
	var here := anyone_here()
	horde.enabled = here
	var players := Net.get_players()
	for l in launchers:
		var near := false
		if here:
			for p in players:
				if p.global_position.distance_to(l.global_position) < WAKE_RANGE:
					near = true
					break
		l.asleep = not near
	if not multiplayer.is_server() or GameState.escaped:
		return
	# Over the edge is a long way down: the street (which has no floor to stand on; nobody is
	# meant to). Only bodies that have been up here count, so nobody in the building below does.
	for b in Net.get_chain_bodies():
		if b.global_position.y > origin.y - 1.0:
			_been_up[b.get_instance_id()] = true
		elif b.global_position.y < origin.y - STREET_DROP + 1.5 and _been_up.has(b.get_instance_id()):
			var lvl := get_tree().get_first_node_in_group("level")
			if lvl != null and lvl.has_method("request_layoff"):
				lvl.call("request_layoff", "%s went over the edge. It's a long way down." % (b.display_name if b is Player else "The Ballast"))
			break
	_task_t -= delta
	if _task_t > 0.0 or not _tasks_set or not here:
		return
	_task_t = 0.5
	var on_pad := 0
	for p in players:
		var l := p.global_position - origin
		if l.z < FENCE_Z - 0.5 and l.y > -1.0 and l.y < 3.0:
			GameState.complete_task(0)
		if Vector2(l.x, l.z).length() < 5.0:
			GameState.complete_task(1)
			_start_round(2)
		var k := roof_at(p.global_position)
		if k >= 1 and k <= ROOF_COUNT and not roofs[k].reached:
			roofs[k].reached = true
			_start_round(k + 2)
			if k > furthest_roof:
				furthest_roof = k
				GameState.set_task_text(TASK_ROOFS, "Cross the rooftops to the tower (%d of %d)" % [k, ROOF_COUNT])
				if k < ROOF_COUNT:
					GameState.post_message("ROOF %d OF %d. %d to go: %s next." % [k, ROOF_COUNT, ROOF_COUNT - k, LINK_NAMES[roofs[k + 1].link]], 3.0)
				else:
					GameState.post_message("THE LAST ROOF. The fire escape goes up the tower from here; the bats will follow you up.", 4.0)
					GameState.complete_task(TASK_ROOFS)
		if _on_helipad(p.global_position):
			on_pad += 1
			if not GameState.task_done(TASK_ESCAPE):
				GameState.complete_task(TASK_ROOFS)
				GameState.complete_task(TASK_ESCAPE)
				_start_round(_waves.size())
	# The pad: someone on it spins the pilot up; everyone off it and she winds down.
	if GameState.task_done(TASK_ESCAPE) and not GameState.task_done(TASK_PAD):
		if on_pad > 0:
			if not _pad_told:
				_pad_told = true
				GameState.post_message("The pilot's spinning her up. HOLD THE PAD: %d seconds. Everything with wings is coming." % int(HELI_READY), 5.0)
			_pad_t += 0.5
		else:
			_pad_t = maxf(0.0, _pad_t - 0.5)
		heli_fraction = clampf(_pad_t / HELI_READY, 0.0, 1.0)
		if heli_fraction >= 1.0:
			GameState.complete_task(TASK_PAD)
			GameState.post_message("SHE'S READY. EVERYONE ABOARD.", 4.0)
	# Everyone aboard: all players at the helicopter, and off we go.
	if not GameState.task_done(TASK_PAD) or players.is_empty():
		return
	if _layoff_pending or Time.get_ticks_msec() - last_layoff_msec() < 3000:
		return
	var heli := heli_position()
	for p in players:
		if p.global_position.distance_to(heli) > ABOARD_RADIUS:
			return
	GameState.complete_task(TASK_ABOARD)
	GameState.set_escaped("Airlifted off Carrow Heights. Next stop: Level 4, the Hotel Velluto.")


func _on_helipad(p: Vector3) -> bool:
	var l := p - origin - tower_top
	return l.y > -1.0 and l.y < 6.0 and absf(l.x) < TOWER_W * 0.5 and absf(l.z) < TOWER_W * 0.5


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
	GameState.post_message("%s called everyone back to the checkpoint." % requester, 3.5)


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
## into a crowd (on the lot it's walked off; on a roof it goes back into the walls), and the
## Jumpers go back to their posts.
func server_on_respawn() -> void:
	for m in get_tree().get_nodes_in_group("monster"):
		if m is Launcher:
			(m as Launcher).release(false)
	if GameState.checkpoint_index <= checkpoint_index:
		horde.push_away_from(GameState.checkpoint_position, 24.0, test_points["horde_center"])
	else:
		horde.clear_near(GameState.checkpoint_position, 22.0)
	for i in launchers.size():
		if not launchers[i].is_dead():
			launchers[i].debug_reset(launcher_homes[i])
	_pad_t = 0.0
	heli_fraction = 0.0
	_pad_told = false


## The Stack asks: is this position in the district (over the route, whatever its height)?
func in_district(p: Vector3) -> bool:
	var l := p - origin
	return _route_bounds.grow(12.0).has_point(Vector2(l.x, l.z))
