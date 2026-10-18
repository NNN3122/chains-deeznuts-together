class_name HordeArena
extends Node3D
## Carrow Heights: Level 3. The roof of the building (the Loading Lot: asphalt under a night
## sky, the Line's pad at the south end, a hoarding fence to boost over, a chokepoint wall with
## a 12 m gap, and the first of the swarm pouring in from the north) and then the district:
## eleven rooftops north of it, each a jump, a plank, a drop or a climb from the last, laid out
## from the run's seed, with the swarm boiling out of every roof's vents as you land on it and
## the Weavers swinging after you on threads. The twelfth roof is a tower with a fire escape up
## to a helipad: jetpack into the open cabin of a helicopter making repeated flybys.
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
const SCARE_POOL: Array = [["face", 3], ["crawler", 2], ["behind", 2], ["peek", 1], ["hands", 1], ["roof_drop", 1], ["roof_shadow", 2], ["roof_scrape", 2], ["roof_swarm", 1], ["breath", 1]]  # what a RoofDread build can end in
const PAD_LOCAL: Vector3 = Vector3(0.0, 0.2, 34.0)
const ROOF_COUNT: int = 13  # rooftops between the lot and the tower (was 11: the user found it too easy)
const TOWER_W: float = 18.0
const TOWER_RISE: float = 10.5  # m the tower's helipad stands over the last roof (6 ledges)
const STEP_H: float = 1.75  # m up per fire-escape ledge (a standing mantle reaches 2.1)
const FLYBY_SECONDS: float = 22.0  # repeat pass: a miss never strands the team
const FLYBY_HEIGHT: float = 4.2  # above the pad, beyond a normal jump
const FLYBY_WIDTH: float = 12.0
const LOT_JUMPERS: int = 1  # Jumpers in front of the first of the swarm on the lot
const JUMPER_ROOFS: Array[int] = [7]  # a Jumper waits on each of these roofs (rare: a scare, not a wall of spiders)
const SPIDER_ROOFS: Array[int] = [8]  # landing on these drops a spider in someone's face (a scare, not a fight)
const ROUTE_X_LIMIT: float = 80.0  # m either side of the lot's centre the route may wander
const LAYOUT_TRIES: int = 40  # whole-route attempts before the plain northward fallback
const CHECKPOINT_ROOFS: Array[int] = [5, 10]  # a checkpoint on each of these, then the helipad
const WAKE_RANGE: float = 55.0  # m: a Jumper further than this from everyone sleeps
const MOON_DIR: Vector3 = Vector3(0.35, 0.42, -0.84)  # where the moon hangs (the sky shader agrees)
const TASKS: Array[String] = [
	"Get over the fence (the dumpster, or a teammate's head)",
	"Reach the gap in the wall",
	"Cross the rooftops to the tower (0 of 11)",
	"Climb the fire escape to the helipad",
	"Reach the jetpack supply: the helicopter is making passes",
	"Jetpack into the open cabin together (hold F / left click)",
]
const TASK_ROOFS: int = 2
const TASK_ESCAPE: int = 3
const TASK_PAD: int = 4
const TASK_ABOARD: int = 5
## How you get onto a roof from the one before it. LEAP: a running jump UP onto a higher roof.
## STONES: a wide gap with chimney stacks standing in it, jumped one after another.
enum Link { JUMP, PLANK, DROP, CLIMB, PIPE, LEAP, STONES }
const LINK_NAMES: Array[String] = ["a jump", "a plank", "a drop", "a climb", "a pipe", "a leap up", "the stacks"]
const NORTH: Vector2 = Vector2(0.0, -1.0)
const EAST: Vector2 = Vector2(1.0, 0.0)
const WEST: Vector2 = Vector2(-1.0, 0.0)
const STONE_DEPTH: float = 4.2  # m along the run, each chimney stack's top: a sprint jump (about 5.8 m) taken anywhere in the last metre of one lands on the next
const STONE_WIDTH: float = 1.6  # m across
const OPENING_HALF: float = 2.0  # m either side of a crossing left open in the knee-high parapet
const RUN_UP: float = 5.5  # m of clear roof kept straight back from each exit: room to sprint at the edge
# Buildings: most roofs are two-level, a raised part (a setback, an upper floor) along the side
# you leave by, so you land low and have to get up onto it before the next crossing.
const TIER_CHANCE: float = 0.85
const TIER_LOW: Vector2 = Vector2(1.5, 1.9)  # m: one mantle up from the roof
const TIER_HIGH: Vector2 = Vector2(2.6, 3.2)  # m: a unit to climb first, then the mantle
const TIER_DEPTH: Vector2 = Vector2(6.4, 7.4)  # m along the way out (room for the RUN_UP on top)
const LANDING_LAMP_CHANCE: float = 0.45  # of roofs that get a lamp at all (the user: darker)
const ROOF_TOP_MAX: float = 26.0  # m over the lot: the highest a route roof stands (was 14: roofs looked all one height)
const CLIMB_STEP: float = 1.6  # m: each crate in a climb's stack (a mantle from the one below)
const CLIMB_STEP_DEPTH: float = 1.4  # m each crate stands out from the wall
const PLANK_W: float = 0.38  # m: a scaffold board, barely wider than a boot
const PIPE_W: float = 0.36  # m
const MANTLE_REACH: float = 2.0  # m: a tier this tall or less is one mantle (a standing mantle reaches 2.1)
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
	var top: float = 0.0  # where you leave from: y, or the top of the raised part (the tier)
	var tier: Rect2 = Rect2()  # the raised part of the roof along the edge you leave by (empty: none)
	var tier_unit: Vector3 = Vector3.ZERO  # local: a unit to climb onto a tall tier (zero: none needed)
	var climb_steps: int = 1  # CLIMB: crates stacked against the wall, each CLIMB_STEP taller
	var link: int = Link.JUMP  # how you arrive from the previous roof
	var dir: Vector2 = NORTH  # which way you travel to reach it (north, east or west; never back south)
	var gap: float = 0.0  # m of street between the previous roof's edge and this roof's near edge
	var cross: Vector2 = Vector2.ZERO  # x, z on the previous roof's edge where the crossing starts
	var cross_x: float = 0.0  # the tower only: x of the fire escape's foot
	var enter: Vector3  # where you land, local
	var exit: Vector3  # where you leave for the next roof (just inside this roof's far edge)
	var out_dir: Vector2 = NORTH  # which way you leave it
	var stones: Array[Vector3] = []  # STONES: the centre of each stack's top, in order
	var vents: Array[Vector3] = []  # the swarm's spawn spots
	var reached: bool = false
	func center() -> Vector3:
		return Vector3(rect.get_center().x, y, rect.get_center().y)
	## This roof's edge facing d (an axis direction), as a coordinate along d.
	func edge_along(d: Vector2) -> float:
		return maxf(rect.position.dot(d), rect.end.dot(d))

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
var heli_fraction: float = 0.0  # replicated: 1 once the helicopter starts its passes
var heli_elapsed: float = 0.0  # replicated flight clock; clients extrapolate between snapshots
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
var _supply_t: float = 0.0
var lamps: Array[OmniLight3D] = []  # every sodium lamp up here (RoofDread drives their energy)
var beacon: OmniLight3D  # the tower's red light
var dread: RoofDread
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _route_bounds: Rect2  # local x, z of every route roof and the tower, for the city round them
var _been_up: Dictionary = {}  # instance id -> true for every chain body that has stood up here


func _enter_tree() -> void:
	if has_node("Sync"):
		return
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	for prop in ["rounds_spawned", "heli_fraction", "heli_elapsed", "furthest_roof"]:
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
		if r.tier.size.x > 0.0:
			field.set_floor_rect(Rect2(r.tier.position + Vector2(origin.x, origin.z), r.tier.size), origin.y + r.top)
	_build()
	_build_waves()
	horde = Horde.new()
	horde.name = "Horde"
	horde.field = field
	horde.base_y = origin.y
	horde.enabled = not embedded
	add_child(horde)  # not under the root: the agents' positions are world positions already
	# Two Jumpers in front of the first of the swarm, and one lying in wait out on the route.
	var homes: Array[Vector3] = []
	for i in LOT_JUMPERS:
		homes.append(Vector3(-10.0 + 20.0 * float(i), 0.0, -7.0))
	for k in JUMPER_ROOFS:
		if k < roofs.size() - 1:
			var jr := roofs[k]
			var home := jr.enter.lerp(jr.center(), 0.4)
			if jr.tier.grow(1.5).has_point(Vector2(home.x, home.z)):
				home = jr.enter  # never up inside the raised part
			homes.append(Vector3(home.x, jr.y, home.z))
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
			Link.LEAP:
				key = "leap"
			Link.STONES:
				key = "stones"
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
	add_child(Checkpoint.create("Checkpoint%d" % cp, cp, origin + tower_top + Vector3(-5.0, 0.1, 5.0), 0.0, "Take a jetpack. Hold F / left click and steer into the helicopter's open cabin. Missed it? Land, refuel, try the next pass."))


func helipad_checkpoint_index() -> int:
	return checkpoint_index + CHECKPOINT_ROOFS.size() + 1


# --- The route -----------------------------------------------------------------------------------

## Eleven roofs scattered north of the lot, then the tower. Each one is placed off a side of the
## last (north mostly, sometimes east or west, never doubling back), at its own size and its own
## height, and must keep clear of every other roof: the district reads as a city, not a line.
## The links: a long running jump, a leap UP onto a higher roof, a narrow board or a duct over a
## wide gap, a drop a storey down, a climb, or a row of chimney stacks to hop. The whole route is
## retried from the seed until it fits; a plain northward route is the fallback.
func _lay_out_route() -> void:
	var ok := false
	for _attempt in LAYOUT_TRIES:
		if _try_route(false):
			ok = true
			break
	if not ok:
		_try_route(true)
	_finish_route()


## One attempt at the whole route. False if a roof or the tower couldn't be placed clear of the rest.
func _try_route(plain: bool) -> bool:
	roofs.clear()
	var lot := Roof.new()
	lot.rect = Rect2(-SIZE * 0.5, -SIZE * 0.5, SIZE, SIZE)
	lot.y = 0.0
	lot.enter = PAD_LOCAL
	roofs.append(lot)
	var last_link := -1
	var last_dir := NORTH
	for i in range(1, ROOF_COUNT + 1):
		var placed := false
		for _try in 14:
			var r := _roll_roof(i, roofs[i - 1], last_link, last_dir, plain)
			if r != null:
				roofs.append(r)
				last_link = r.link
				last_dir = r.dir
				placed = true
				break
		if not placed:
			return false
	# The tower: butted against the last roof's north edge, the fire escape up its south face.
	var prev := roofs[roofs.size() - 1]
	var tower := Roof.new()
	tower.link = Link.CLIMB
	tower.dir = NORTH
	tower.y = prev.y + TOWER_RISE
	var tx := clampf(prev.rect.get_center().x, prev.rect.position.x + TOWER_W * 0.5 - 2.0, prev.rect.end.x - TOWER_W * 0.5 + 2.0)
	tower.rect = Rect2(tx - TOWER_W * 0.5, prev.rect.position.y - TOWER_W, TOWER_W, TOWER_W)
	for k in roofs.size() - 1:
		if roofs[k].rect.grow(4.0).intersects(tower.rect):
			return false
	tower.cross_x = _escape_x_for(prev, tower)
	tower.cross = Vector2(tower.cross_x, prev.rect.position.y)
	escape_dir = 1.0 if tower.rect.end.x - tower.cross_x >= tower.cross_x - tower.rect.position.x else -1.0
	tower.enter = Vector3(tx, tower.y, prev.rect.position.y - TOWER_W * 0.5)
	prev.exit = Vector3(tower.cross_x, prev.y, prev.rect.position.y + 2.6)
	prev.out_dir = NORTH
	roofs.append(tower)
	tower_top = Vector3(tx, tower.y, tower.rect.get_center().y)
	return true


## A candidate for roof i off prev, or null if it would sit on (or too near) another roof.
func _roll_roof(i: int, prev: Roof, last_link: int, last_dir: Vector2, plain: bool) -> Roof:
	var r := Roof.new()
	# Which way: north off the lot; then mostly north, sometimes a turn east or west (never
	# straight back the way the last turn came).
	var d := NORTH
	if i > 1 and not plain:
		var roll := _rng.randf()
		if roll < 0.2 and last_dir != WEST:
			d = EAST
		elif roll < 0.4 and last_dir != EAST:
			d = WEST
	# The roof before: raised along the edge you leave it by (a setback, an upper floor), and
	# then everything below is measured from the top of that raised part.
	prev.tier = Rect2()
	prev.tier_unit = Vector3.ZERO
	prev.top = prev.y
	if i > 1 and not plain and _rng.randf() < TIER_CHANCE:
		_raise_tier(prev, d)
	var prev_top := prev.top
	# The link follows a height this roof would like to be (random anywhere in the band): up there
	# is a climb or a leap, down there a drop or a jump down, near enough a level crossing. The
	# first is a plain jump off the lot; no two climbs, drops or stacks in a row.
	var link := Link.JUMP
	var want := 0.0
	if i > 1:
		want = _rng.randf_range(0.0, ROOF_TOP_MAX)
		var roll := _rng.randf()
		if want > prev_top + 2.5:
			link = Link.CLIMB if roll < 0.55 else Link.LEAP
		elif want < prev_top - 3.0 and prev_top >= 4.0:
			link = Link.DROP if roll < 0.65 else Link.JUMP
		elif roll < 0.25:
			link = Link.JUMP
		elif roll < 0.45:
			link = Link.PLANK
		elif roll < 0.6:
			link = Link.PIPE
		elif roll < 0.8:
			link = Link.STONES
		else:
			link = Link.LEAP
		if link == last_link and (link == Link.CLIMB or link == Link.DROP or link == Link.STONES):
			link = Link.LEAP if link == Link.CLIMB else Link.JUMP
		if (link == Link.CLIMB or link == Link.LEAP) and prev_top > ROOF_TOP_MAX - 2.0:
			link = Link.DROP if prev_top >= 4.0 else Link.JUMP
	var gap := 0.0
	var dy := 0.0
	match link:
		Link.JUMP:
			gap = _rng.randf_range(3.4, 4.4)  # a full sprint and a jump from the very edge; a walk-off falls short
			dy = _rng.randf_range(-2.6, -0.6)  # always down a little: no two roofs the same height
		Link.LEAP:
			gap = _rng.randf_range(1.8, 2.4)
			dy = _rng.randf_range(0.9, 1.25)  # jump up and catch the edge
		Link.PLANK:
			gap = _rng.randf_range(6.5, 9.0)
		Link.PIPE:
			gap = _rng.randf_range(5.5, 8.0)
		Link.DROP:
			gap = _rng.randf_range(2.0, 3.0)
			dy = maxf(_rng.randf_range(-8.0, -3.4), -prev_top)  # a long way down
		Link.CLIMB:
			gap = 0.0
			# One crate to three, stacked up the wall like steps; the roof a mantle above the top one.
			r.climb_steps = clampi(int((want - prev_top) / (CLIMB_STEP * 1.6)) + 1, 1, 3) if want > prev_top else 1
			dy = CLIMB_STEP * float(r.climb_steps) + _rng.randf_range(1.0, 1.9)
		Link.STONES:
			dy = _rng.randf_range(-0.6, 0.0)
	var y := prev_top + dy
	if y < 0.0 or y > ROOF_TOP_MAX:
		# Out of the band the Stack reads as the roof: a level jump instead.
		link = Link.JUMP
		gap = _rng.randf_range(3.0, 3.6)
		y = clampf(prev_top + _rng.randf_range(-1.0, 0.0), 0.0, ROOF_TOP_MAX)
	r.link = link
	r.dir = d
	r.y = y
	r.top = y
	# The crossing: somewhere along prev's edge facing d, clear of its corners.
	var side := _side(d)
	var p_lo := minf(prev.rect.position.dot(side), prev.rect.end.dot(side))
	var p_hi := maxf(prev.rect.position.dot(side), prev.rect.end.dot(side))
	if p_hi - p_lo < 7.0:
		return null
	var t := _rng.randf_range(p_lo + 3.5, p_hi - 3.5)
	if i == 1:
		t = _rng.randf_range(-20.0, 20.0)
	var edge := prev.edge_along(d)
	# Chimney stacks: two or three, each a running jump from the last.
	if link == Link.STONES:
		var n := _rng.randi_range(3, 4)
		var a := edge
		for k in n:
			var g := _rng.randf_range(2.2, 2.8)
			var top_y := prev_top + (y - prev_top) * float(k + 1) / float(n + 1) + _rng.randf_range(-0.3, 0.3)
			var mid := a + g + STONE_DEPTH * 0.5
			var c := d * mid + side * t
			r.stones.append(Vector3(c.x, top_y, c.y))
			a += g + STONE_DEPTH
		gap = a - edge + _rng.randf_range(2.0, 2.4)
	r.gap = gap
	var w := _rng.randf_range(9.0, 20.0)  # across the way you came
	var depth := _rng.randf_range(10.0, 17.0)  # along it (deep enough, mostly, for a raised part at the far end)
	var center_t := t + _rng.randf_range(-(w * 0.5 - 3.5), w * 0.5 - 3.5)
	var near := edge + gap
	r.rect = _rect_from(d, near, near + depth, center_t - w * 0.5, center_t + w * 0.5)
	r.cross = d * edge + side * t
	r.cross_x = r.cross.x
	var land := d * (near + 1.6) + side * t
	r.enter = Vector3(land.x, r.y, land.y)
	# Clear of everything: other roofs by 4 m, and the gap you cross free of anything but street.
	if absf(r.rect.position.x) > ROUTE_X_LIMIT or absf(r.rect.end.x) > ROUTE_X_LIMIT:
		return null
	var lane := _rect_from(d, edge, near, t - 2.5, t + 2.5)
	for k in roofs.size():
		var o := roofs[k]
		if o == prev:
			if o.rect.intersects(r.rect):
				return null
			continue
		if o.rect.grow(4.0).intersects(r.rect) or (lane.size.x > 0.01 and lane.size.y > 0.01 and o.rect.intersects(lane)):
			return null
	if prev.tier.size.x > 0.0 and prev_top - prev.y > MANTLE_REACH:
		# Too tall to mantle: a unit against its face, in line with where you leave, to climb first.
		var inner := minf(prev.tier.position.dot(d), prev.tier.end.dot(d))
		var ut := clampf(t, p_lo + 1.6, p_hi - 1.6)
		var u := d * (inner - 0.8) + side * ut
		prev.tier_unit = Vector3(u.x, prev.y, u.y)
	var leave := d * (edge - 1.6) + side * t
	prev.exit = Vector3(leave.x, prev_top, leave.y)
	prev.out_dir = d
	return r


## Raises the part of roof r along its edge facing d by a tier: a band the whole width of the roof,
## TIER_DEPTH deep, kept clear of where you land on it. Nothing if it doesn't fit.
func _raise_tier(r: Roof, d: Vector2) -> void:
	var edge := r.edge_along(d)
	var back := minf(r.rect.position.dot(d), r.rect.end.dot(d))
	var land := Vector2(r.enter.x, r.enter.z).dot(d)
	var depth := _rng.randf_range(TIER_DEPTH.x, TIER_DEPTH.y)
	var h_high := _rng.randf_range(TIER_HIGH.x, TIER_HIGH.y)
	var h_low := _rng.randf_range(TIER_LOW.x, TIER_LOW.y)
	# Tall if it fits, else a low one, else a shallower low one (still room to run up for a jump).
	var tries: Array = [[depth, h_high if _rng.randf() < 0.5 else h_low], [depth, h_low], [5.6, h_low]]
	for t: Array in tries:
		var dep: float = t[0]
		var h: float = t[1]
		# Room between where you land and its face (and the unit in front of a tall one).
		var margin := 4.2 if h > MANTLE_REACH else 2.0
		if edge - dep - back < 3.2 or land > edge - dep - margin or r.y + h > ROOF_TOP_MAX + 1.0:
			continue  # no room for it, or you would land on it
		var side := _side(d)
		var lo := minf(r.rect.position.dot(side), r.rect.end.dot(side))
		var hi := maxf(r.rect.position.dot(side), r.rect.end.dot(side))
		r.tier = _rect_from(d, edge - dep, edge, lo, hi)
		r.top = r.y + h
		return


## The axis across a direction of travel.
func _side(d: Vector2) -> Vector2:
	return Vector2(1.0, 0.0) if d.x == 0.0 else Vector2(0.0, 1.0)


## A footprint from coordinates along d (a0..a1) and across it (t0..t1).
func _rect_from(d: Vector2, a0: float, a1: float, t0: float, t1: float) -> Rect2:
	var side := _side(d)
	var p0 := d * a0 + side * t0
	var p1 := d * a1 + side * t1
	return Rect2(minf(p0.x, p1.x), minf(p0.y, p1.y), absf(p1.x - p0.x), absf(p1.y - p0.y))


## The vents (two a roof, never on the walk from where you land to where you leave) and the
## bounds of the whole district.
func _finish_route() -> void:
	for i in range(1, ROOF_COUNT + 1):
		var r := roofs[i]
		for k in 2:
			var best := r.center()
			var best_d := -1.0
			for _try in 10:
				var p := Vector3(_rng.randf_range(r.rect.position.x + 1.6, r.rect.end.x - 1.6), r.y, _rng.randf_range(r.rect.position.y + 1.6, r.rect.end.y - 1.6))
				var dd := _lane_distance(r, p)
				if r.tier.grow(1.0).has_point(Vector2(p.x, p.z)):
					dd = -1.0  # not up on the raised part: the swarm comes out of the roof you land on
				for v in r.vents:
					dd = minf(dd, p.distance_to(v))
				if dd > best_d:
					best_d = dd
					best = p
				if dd > 3.5:
					break
			r.vents.append(best)
	_route_bounds = roofs[1].rect
	for i in range(2, roofs.size()):
		_route_bounds = _route_bounds.merge(roofs[i].rect)


## How far a point on a roof is from the walk across it: from where you land to a straight
## run-up (RUN_UP m) at the edge you leave by, and along that run-up to the edge.
func _lane_distance(r: Roof, p: Vector3) -> float:
	var a := Vector2(r.enter.x, r.enter.z)
	var b := Vector2(r.exit.x, r.exit.z)
	var run := b - r.out_dir * RUN_UP
	var q := Vector2(p.x, p.z)
	return minf(_segment_distance(q, a, run), _segment_distance(q, run, b))


func _segment_distance(q: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var u := 0.0 if ab.length_squared() < 0.001 else clampf((q - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return q.distance_to(a + ab * u)


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


## Which roof's footprint a world position stands over (whatever its height), kept a little in
## from the edges; -1 over the street.
func roof_under(p: Vector3) -> int:
	var l := p - origin
	for i in roofs.size():
		if roofs[i].rect.grow(-0.6).has_point(Vector2(l.x, l.z)):
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
	# A thin, cold moon behind the cloud: enough to make out an edge, not enough to see by.
	moon.light_color = Color(0.5, 0.58, 0.85)
	moon.light_energy = 0.12
	moon.light_volumetric_fog_energy = 0.12
	moon.transform = Transform3D(Basis.looking_at(-MOON_DIR.normalized(), Vector3.UP), Vector3.ZERO)
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 120.0
	root.add_child(moon)
	# Three dim floods on the whole lot: one by the pad, one mid-lot, one at the far edge.
	for p: Vector3 in [Vector3(-12.0, 6.0, 30.0), Vector3(10.0, 6.0, -2.0), Vector3(cx1, 6.0, -44.0)]:
		_lamp_post(p, 1.3, 14.0)
	dread = RoofDread.new()
	dread.name = "Dread"
	dread.arena = self
	add_child(dread)
	add_child(Checkpoint.create("Checkpoint%d" % checkpoint_index, checkpoint_index, origin + PAD_LOCAL, spawn_facing, first_objective()))


func _wall(batch: LevelKit.BoxBatch, center: Vector3, size: Vector3, key: String = "concrete") -> void:
	batch.add(center, size, key)
	_block(center.x, center.z, size.x, size.z)


## A sodium flood on a post. One that `can_die` gutters out when the Line comes near (RoofDread).
func _lamp_post(p: Vector3, energy: float, range_m: float, can_die: bool = false) -> void:
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.66, 0.32)
	lamp.light_energy = energy
	lamp.light_volumetric_fog_energy = 1.6
	lamp.omni_range = range_m
	lamp.omni_attenuation = 1.6  # falls off hard: a pool, then dark
	lamp.shadow_enabled = false
	lamp.position = p
	root.add_child(lamp)
	lamps.append(lamp)
	lamp.set_meta("base_energy", energy)
	lamp.set_meta("can_die", can_die)
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
	lamp.set_meta("head", head)


## A box's size for a piece laid along d: `along` in the direction of travel, `across` sideways.
func _osize(d: Vector2, along: float, across: float, h: float) -> Vector3:
	return Vector3(across, h, along) if d.x == 0.0 else Vector3(along, h, across)


## A Vector3 at height y over a ground point.
func _at(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x, y, p.y)


## One roof of the route: the building under it from the street up, windows, a knee-high
## parapet round every edge (open only where you cross), the link from the roof before it, and
## the dressing: vents the swarm comes out of, units, a bulkhead, a tank, a lamp at the landing.
## No signs: the red light on the tower is the only thing pointing the way.
func _build_roof(batch: LevelKit.BoxBatch, i: int) -> void:
	var r := roofs[i]
	var prev := roofs[i - 1]
	var nxt := roofs[i + 1]
	var last := i == roofs.size() - 2
	var base := -STREET_DROP
	var c2 := r.rect.get_center()
	var size := Vector3(r.rect.size.x, r.y - base, r.rect.size.y)
	var c := Vector3(c2.x, base + size.y * 0.5, c2.y)
	var key: String = ["brick", "tower", "concrete", "brick"][_rng.randi_range(0, 3)]
	batch.add(c, size, key)
	_windows(batch, _rng, c, size, 3.2, 2.6, 0.03 if key != "concrete" else 0.015, true)  # nearly everyone's gone
	batch.add(Vector3(c2.x, r.y + 0.01, c2.y), Vector3(r.rect.size.x, 0.02, r.rect.size.y), "asphalt", false)
	# The parapet: every edge, with an opening where you come in and where you leave. The last
	# roof has none on its north edge: the tower and its fire escape stand there.
	var in_edge := -r.dir
	var in_t := r.cross.dot(_side(r.dir))
	var out_t := nxt.cross.dot(_side(nxt.dir))
	for e: Vector2 in [NORTH, EAST, Vector2(0.0, 1.0), WEST]:
		if last and e == NORTH:
			continue
		var openings: Array[float] = []
		if e == in_edge:
			openings.append(in_t)
		if e == nxt.dir:
			openings.append(out_t)
		_parapet(batch, r, e, openings)
	if r.tier.size.x > 0.0:
		_build_tier(batch, r, nxt, key)
	# Hazard paint where you leave, and where you land.
	var side_in := _side(r.dir)
	batch.add(_at(r.cross + r.dir * (r.gap + 0.25), r.y + 0.02), _osize(r.dir, 0.5, 4.0, 0.02), "hazard", false)
	if not last:
		var leave := nxt.cross - nxt.dir * 0.25
		batch.add(_at(leave, r.top + 0.02), _osize(nxt.dir, 0.5, 4.0, 0.02), "hazard", false)
	# The link from the previous roof.
	var d := r.dir
	match r.link:
		Link.PLANK:
			# A scaffold board, a hand's width wider than a boot, flush with both roofs.
			var top := maxf(prev.top, r.y)
			batch.add(_at(r.cross + d * (r.gap * 0.5), top - 0.07), _osize(d, r.gap + 1.8, PLANK_W, 0.14), "tank")
		Link.PIPE:
			# A ventilation duct laid across, its top flush with both roofs. Narrow, and ribbed.
			var top := maxf(prev.top, r.y)
			batch.add(_at(r.cross + d * (r.gap * 0.5), top - 0.25), _osize(d, r.gap + 1.6, PIPE_W, 0.5), "steel_dark")
			for k in int(r.gap / 1.2):
				batch.add(_at(r.cross + d * (0.6 + 1.2 * float(k)), top - 0.25), _osize(d, 0.08, PIPE_W + 0.06, 0.56), "steel", false)
		Link.CLIMB:
			# Crates stacked up this roof's wall like steps (the tallest against it), each a mantle
			# from the one below, then a mantle onto the roof. A drain pipe beside them, for the look.
			for j in r.climb_steps:
				var ch := CLIMB_STEP * float(r.climb_steps - j)
				var u2 := r.cross - d * (CLIMB_STEP_DEPTH * (float(j) + 0.5))
				batch.add(_at(u2, prev.top + ch * 0.5), _osize(d, CLIMB_STEP_DEPTH, 2.4, ch), "steel" if j % 2 == 0 else "crate")
				batch.add(_at(u2, prev.top + ch + 0.01), _osize(d, CLIMB_STEP_DEPTH - 0.4, 1.6, 0.04), "dark", false)
				var us := _osize(d, CLIMB_STEP_DEPTH, 2.4, 0.0)
				_block(u2.x, u2.y, us.x, us.z)
			batch.add(_at(r.cross + side_in * 2.2 - d * 0.25, (prev.top + r.y) * 0.5), Vector3(0.25, r.y - prev.top, 0.25), "tank", false)
		Link.STONES:
			# Chimney stacks standing up out of the street, each a running jump from the last.
			for s in r.stones:
				var h := s.y - base
				var fs := _osize(d, STONE_DEPTH, STONE_WIDTH, h)
				batch.add(Vector3(s.x, base + h * 0.5, s.z), fs, "brick")
				batch.add(Vector3(s.x, s.y + 0.04, s.z), _osize(d, STONE_DEPTH + 0.1, STONE_WIDTH + 0.1, 0.08), "concrete", false)
				field.set_floor_rect(Rect2(origin.x + s.x - fs.x * 0.5, origin.z + s.z - fs.z * 0.5, fs.x, fs.z), origin.y + s.y)
		_:
			pass
	# Dressing, kept off the walk from the landing to the way out.
	for v in r.vents:
		batch.add(v + Vector3(0.0, 0.35, 0.0), Vector3(0.9, 0.7, 0.9), "steel_dark")
		batch.add(v + Vector3(0.0, 0.72, 0.0), Vector3(0.7, 0.04, 0.7), "dark", false)
		_block(v.x, v.z, 0.9, 0.9)
	var units := _rng.randi_range(1, 3)
	for k in units:
		var p := _spot(r, 1.6)
		if p.y > -1.0e8:
			batch.add(p + Vector3(0.0, 0.7, 0.0), Vector3(1.4, 1.4, 1.4), "steel")
			batch.add(p + Vector3(0.0, 1.41, 0.0), Vector3(1.0, 0.03, 1.0), "dark", false)
			_block(p.x, p.z, 1.4, 1.4)
	if _rng.randf() < 0.4:
		var p := _spot(r, 2.4)
		if p.y > -1.0e8:
			batch.add(p + Vector3(0.0, 1.3, 0.0), Vector3(3.0, 2.6, 3.0), "concrete")
			batch.add(p + Vector3(0.0, 1.0, 1.52), Vector3(0.9, 2.0, 0.06), "dark", false)
			batch.add(p + Vector3(0.0, 2.75, 0.0), Vector3(3.2, 0.3, 3.2), "concrete", false)
			_block(p.x, p.z, 3.0, 3.0)
	if _rng.randf() < 0.3:
		var p := _spot(r, 2.2)
		if p.y > -1.0e8:
			_water_tank(p)
			_block(p.x, p.z, 3.2, 3.2)
	if _rng.randf() < 0.3:
		var p := _spot(r, 1.0)
		if p.y > -1.0e8:
			batch.add(p + Vector3(0.0, 6.0, 0.0), Vector3(0.25, 12.0, 0.25), "steel_dark", false)
			batch.add(p + Vector3(0.0, 12.2, 0.0), Vector3(0.35, 0.35, 0.35), "led_red", false)
	if _rng.randf() < 0.35:
		var p := _spot(r, 1.6)
		if p.y > -1.0e8:
			batch.add(p + Vector3(0.0, 0.2, 0.0), Vector3(2.2, 0.4, 2.2), "heli_glass")  # a skylight; you can stand on it
	# A dim lamp at the landing, so you can see where you land and not much else. Past the second
	# roof, some of them die as you come near.
	if _rng.randf() < LANDING_LAMP_CHANCE:
		var lamp := _at(Vector2(r.enter.x, r.enter.z) + side_in * 3.0 + d * 1.0, r.y + 5.0)
		_lamp_post(lamp, 0.9, 9.0, RoofDread.lamp_dies(seed_value, i))
	if _rng.randf() < 0.25:
		var p := _spot(r, 2.0)
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
			text.shaded = true
			text.position = bb + Vector3(0.0, 0.0, 0.2)
			root.add_child(text)
			_block(p.x, p.z, 6.0, 0.6)


## The raised part of a roof: a block of the building standing up along the edge you leave by,
## its own asphalt and knee-high parapet (open where you leave and on the side facing back, where
## you climb up), windows on its face, and the unit to climb first when it is too tall to mantle.
func _build_tier(batch: LevelKit.BoxBatch, r: Roof, nxt: Roof, key: String) -> void:
	var h := r.top - r.y
	var c2 := r.tier.get_center()
	var size := Vector3(r.tier.size.x, h, r.tier.size.y)
	var c := Vector3(c2.x, r.y + h * 0.5, c2.y)
	batch.add(c, size, key)
	_windows(batch, _rng, c, size, 3.2, 2.6, 0.02, false)
	batch.add(Vector3(c2.x, r.top + 0.01, c2.y), Vector3(size.x, 0.02, size.z), "asphalt", false)
	# A cornice along the top, so the setback reads as its own storey.
	batch.add(Vector3(c2.x, r.top - 0.1, c2.y), Vector3(size.x + 0.3, 0.2, size.z + 0.3), "concrete", false)
	var top := Roof.new()
	top.rect = r.tier
	top.y = r.top
	var out_t := nxt.cross.dot(_side(nxt.dir))
	for e: Vector2 in [NORTH, EAST, Vector2(0.0, 1.0), WEST]:
		if e == -r.out_dir:
			continue  # the face you climb
		var openings: Array[float] = []
		if e == nxt.dir:
			openings.append(out_t)
		_parapet(batch, top, e, openings)
	if r.tier_unit != Vector3.ZERO:
		var u2 := Vector2(r.tier_unit.x, r.tier_unit.z)
		batch.add(_at(u2, r.y + 0.8), _osize(r.out_dir, 1.6, 2.4, 1.6), "steel")
		batch.add(_at(u2, r.y + 1.61), _osize(r.out_dir, 1.0, 1.6, 0.04), "dark", false)
		var us := _osize(r.out_dir, 1.6, 2.4, 0.0)
		_block(u2.x, u2.y, us.x, us.z)

## A knee-high wall along one edge of a roof (e: the way that edge faces), broken by an opening
## OPENING_HALF either side of each crossing coordinate in `openings`.
func _parapet(batch: LevelKit.BoxBatch, r: Roof, e: Vector2, openings: Array[float]) -> void:
	var along := _side(e)  # the edge runs across the way it faces
	var lo := minf(r.rect.position.dot(along), r.rect.end.dot(along))
	var hi := maxf(r.rect.position.dot(along), r.rect.end.dot(along))
	var at := r.edge_along(e) - 0.2  # just inside the edge
	var pieces: Array[Vector2] = [Vector2(lo, hi)]
	for o in openings:
		var next: Array[Vector2] = []
		for piece in pieces:
			if o + OPENING_HALF <= piece.x or o - OPENING_HALF >= piece.y:
				next.append(piece)
				continue
			if o - OPENING_HALF - piece.x > 0.3:
				next.append(Vector2(piece.x, o - OPENING_HALF))
			if piece.y - (o + OPENING_HALF) > 0.3:
				next.append(Vector2(o + OPENING_HALF, piece.y))
		pieces = next
	for piece in pieces:
		var mid := e * at + along * ((piece.x + piece.y) * 0.5)
		_wall(batch, _at(mid, r.y + ROOF_PARAPET_H * 0.5), _osize(e, 0.4, piece.y - piece.x, ROOF_PARAPET_H))


## A spot on a roof clear of the walk across it, its edges and its vents, or (0, -1e9, 0) after a few tries.
func _spot(r: Roof, half: float) -> Vector3:
	for _try in 12:
		var x := _rng.randf_range(r.rect.position.x + 1.2 + half, r.rect.end.x - 1.2 - half)
		var z := _rng.randf_range(r.rect.position.y + 2.0 + half, r.rect.end.y - 2.0 - half)
		var p := Vector3(x, r.y, z)
		var ok := _lane_distance(r, p) > 3.0 + half
		if r.tier.grow(half + 0.4).has_point(Vector2(x, z)):
			ok = false
		for v in r.vents:
			if absf(x - v.x) < 1.2 + half and absf(z - v.z) < 1.2 + half:
				ok = false
		if ok:
			return p
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
	_windows(batch, _rng, c, size, 4.0, 3.0, 0.0, true)  # dark all the way up: only the beacon shows
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
	for side: float in [-1.0, 1.0]:
		batch.add(top + Vector3(0.0, 0.025, side * 6.5), Vector3(7.0, 0.03, 0.5), "hazard", false)
	for k in 12:
		var a := float(k) / 12.0 * TAU
		batch.add(top + Vector3(cos(a) * 6.5, 0.1, sin(a) * 6.5), Vector3(0.3, 0.2, 0.3), "led_red", false)
	# The beacon: a mast with a red light you can see from the lot, through the fog (its material
	# ignores fog). The brightest thing in Carrow Heights, and the way out.
	batch.add(top + Vector3(TOWER_W * 0.5 - 1.5, 6.0, -TOWER_W * 0.5 + 1.5), Vector3(0.3, 12.0, 0.3), "steel_dark", false)
	batch.add(top + Vector3(TOWER_W * 0.5 - 1.5, 12.3, -TOWER_W * 0.5 + 1.5), Vector3(1.0, 1.0, 1.0), "beacon", false)
	beacon = OmniLight3D.new()
	beacon.light_color = Color(1.0, 0.08, 0.06)
	beacon.light_energy = RoofDread.BEACON_ENERGY
	beacon.light_volumetric_fog_energy = 2.5
	beacon.omni_range = 40.0
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
	_lamp_post(Vector3(tower.cross_x + 4.0, last.y + 5.0, south + 3.0), 1.2, 12.0)
	_build_helicopter(top)


func _build_helicopter(top: Vector3) -> void:
	var aircraft := AnimatableBody3D.new()
	aircraft.sync_to_physics = false  # moved in the physics tick, including on clients
	aircraft.collision_layer = ChainBody.LAYER_WORLD
	_heli = aircraft
	_heli.name = "Helicopter"
	_heli.position = top + Vector3(-FLYBY_WIDTH, FLYBY_HEIGHT, 0.0)
	root.add_child(_heli)
	var body := LevelKit.mat("heli_body")
	var glass := LevelKit.mat("heli_glass")
	var dark := LevelKit.mat("rotor")
	# Open rescue cabin: a real moving deck carries the whole Line between passes.
	_hbox(_heli, Vector3(6.0, 0.3, 5.0), Vector3(0.0, 0.55, 0.0), body)
	_hbox(_heli, Vector3(6.0, 0.18, 5.0), Vector3(0.0, 3.0, 0.0), body)
	_hbox(_heli, Vector3(2.8, 1.5, 1.4), Vector3(0.0, 1.7, -3.0), glass)
	var deck := CollisionShape3D.new()
	var deck_shape := BoxShape3D.new()
	deck_shape.size = Vector3(6.0, 0.3, 5.0)
	deck.shape = deck_shape
	deck.position.y = 0.55
	_heli.add_child(deck)
	for side: float in [-1.0, 1.0]:
		_hbox(_heli, Vector3(0.12, 2.3, 0.12), Vector3(side * 2.85, 1.85, 2.3), dark)
		_hbox(_heli, Vector3(0.12, 2.3, 0.12), Vector3(side * 2.85, 1.85, -2.3), dark)
	var cabin := OmniLight3D.new()
	cabin.light_color = Color(0.25, 1.0, 0.45)
	cabin.light_energy = 3.0
	cabin.omni_range = 9.0
	cabin.position.y = 2.0
	_heli.add_child(cabin)
	_hbox(_heli, Vector3(0.5, 0.5, 5.0), Vector3(0.0, 1.9, 4.8), body)  # tail boom
	_hbox(_heli, Vector3(0.1, 1.4, 0.8), Vector3(0.0, 2.6, 7.2), body)  # fin
	for s: float in [-1.0, 1.0]:
		_hbox(_heli, Vector3(0.15, 0.15, 3.6), Vector3(s * 1.2, 0.1, 0.3), dark)  # skids
		_hbox(_heli, Vector3(0.12, 0.6, 0.12), Vector3(s * 1.2, 0.4, -0.8), dark)
		_hbox(_heli, Vector3(0.12, 0.6, 0.12), Vector3(s * 1.2, 0.4, 1.4), dark)
	_hbox(_heli, Vector3(0.6, 0.5, 0.6), Vector3(0.0, 3.25, 0.3), dark)  # above the cabin canopy
	_rotor = Node3D.new()
	_rotor.position = Vector3(0.0, 3.55, 0.3)
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
		_windows(batch, rng, c, Vector3(w, h, w), 7.0, 6.0, 0.03, false)
		if rng.randf() < 0.3:
			batch.add(Vector3(c.x, base + h + 1.0, c.z), Vector3(0.6, 0.6, 0.6), "led_red", false)


## A building nobody walks on: the box, its windows, a parapet, and a tank, a mast or a billboard
## on some.
func _backdrop(batch: LevelKit.BoxBatch, rng: RandomNumberGenerator, c: Vector3, size: Vector3, top: float, base: float) -> void:
	c.y = base + size.y * 0.5
	var key: String = ["brick", "tower", "concrete", "brick"][rng.randi_range(0, 3)]
	batch.add(c, size, key, false)
	_windows(batch, rng, c, size, 3.2, 2.6, 0.08 if key != "concrete" else 0.04, true)
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
		text.shaded = true
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
	return "The roof: north across the rooftops to the tower with the red light. Climb its fire escape, take a jetpack, and fly into the passing helicopter's green cabin together."


## Anyone on the Line up here? (Embedded, the crowd sleeps until then.)
func anyone_here() -> bool:
	for p in Net.get_players():
		if p.global_position.y > origin.y - 1.0:
			return true
	return false


# --- The waves -------------------------------------------------------------------------------------

## Every wave, in the order they can be triggered, the same on every peer: the lot's first two
## (a few hundred roaches, not a thousand: the user found the horde too thick), then a handful out
## of each roof's vents as you land on it. Roaches climb walls and leap the gaps (Horde.CLIMBER),
## so whatever is left behind follows you roof to roof. Spiders and bats never come in waves;
## they're jump scares (roof_drop, roof_swarm). The helipad's entry is empty: it's the mark for
## "everyone made it up". Each entry: [[count, weights, local rect], ...].
func _build_waves() -> void:
	_waves.clear()
	var scale := float(horde_count) / float(HORDE_COUNT)
	# Halved again (the user: still too many): 70 and 45 on the lot, 2-4 out of each roof's vents.
	_waves.append([[int(70.0 * scale), [1.0, 0.0, 0.0], Rect2(-44.0, -46.0, 88.0, 30.0)]])
	_waves.append([[int(45.0 * scale), [1.0, 0.0, 0.0], Rect2(-48.0, -30.0, 96.0, 20.0)]])
	var wrng := RandomNumberGenerator.new()
	wrng.seed = SEED + seed_value * 7 + 3
	for k in range(1, ROOF_COUNT + 1):
		var groups: Array = []
		var r := roofs[k]
		var roaches := int(wrng.randi_range(2, 4) * scale)
		for v in r.vents:  # out of the vents, not from under your feet
			groups.append([roaches / r.vents.size(), [1.0, 0.0, 0.0], Rect2(v.x - 1.6, v.z - 1.6, 3.2, 3.2)])
		_waves.append(groups)
	_waves.append([])


func wave_count() -> int:
	return _waves.size()


## Does any wave bring this kind? (Tests: spiders and bats are scares, never waves.)
func waves_spawn(k: int) -> bool:
	for groups in _waves:
		for g in groups:
			var weights: Array = g[1]
			if k < weights.size() and float(weights[k]) > 0.0:
				return true
	return false


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
		GameState.post_message("MORE OF THEM. Don't stand and fight: the gap, then the edge, then the next roof.", 4.0)


## Tests and the bench: everything at once.
func debug_spawn_all_rounds() -> void:
	rounds_spawned = _waves.size()
	_tick_rounds()


## Screenshot tours: show the helicopter directly over the pad.
func debug_pad_ready() -> void:
	heli_fraction = 1.0
	heli_elapsed = FLYBY_SECONDS * 0.25


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


## The roof paces its own scares (RoofDread): the ScareDirector's timer leaves it alone.
func paces_own_scares(_p: Vector3) -> bool:
	return true


func play_scare(kind: String, pos: Vector3, targeted: bool) -> void:
	if kind == "roof_hush":
		dread.hush(pos, targeted)
		return
	var me := Net.get_local_player()
	if me == null or me.global_position.distance_to(pos) > (60.0 if kind == "roof_glimpse" else 35.0):
		return
	match kind:
		"roof_glimpse":
			dread.spawn_glimpse(pos)
		"roof_scrape":
			Sfx.caption(self, "claws dragging beneath the roof", pos)
			for i in 5:
				var at := pos + Vector3(-4.0 + float(i) * 2.0, -0.8, 2.0)
				get_tree().create_timer(float(i) * 0.35).timeout.connect(func() -> void:
					if is_inside_tree():
						Sfx.play_at(self, "scrape", at, -1.0, 0.65, 24.0))
		"roof_shadow":
			ScareDirector.flicker(pos, 24.0, 2200)
			Sfx.caption(self, "something enormous overhead", pos + Vector3.UP * 5.0)
			Sfx.play_at(self, "creak", pos + Vector3.UP * 5.0, 1.0, 0.5, 30.0)
			_spawn_roof_shadow(pos, Horde.KIND_WEAVER, 3.0)
		"roof_swarm":
			Sfx.caption(self, "wings bursting out behind you", pos)
			Sfx.play_at(self, "roach_chitter", pos, 4.0, 0.8, 30.0)
			if targeted:
				# Not play_at: a positional screech gets the Jumper's "about to jump" caption.
				Sfx.play(self, "screech", -4.0, 2.4)
				Sfx.play(self, "stinger", -3.0)
			me.add_shake(0.35)
			for i in 5:
				_spawn_roof_shadow(pos + Vector3(float(i) - 2.0, float(i) * 0.4, 1.0), Horde.KIND_FLITTER, 1.3)
		"roof_drop":
			# A spider comes down on its thread right in front of your face, hangs there twitching
			# for a breath, and is gone back up into the dark. Nothing to fight: a scare.
			Sfx.caption(self, "something dropping on a thread", pos)
			_spawn_spider_drop(pos)
			if me.global_position.distance_to(pos) < 6.0:
				get_tree().create_timer(0.22).timeout.connect(func() -> void:
					if is_inside_tree():
						Sfx.play(self, "stinger", -2.0)
						me.add_shake(0.55))


func _spawn_roof_shadow(pos: Vector3, kind: int, size: float) -> void:
	var shape := MeshInstance3D.new()
	shape.name = "RoofScare"
	shape.mesh = HordeMesh.mesh_for(kind)
	shape.material_override = HordeMesh.material_for(kind)
	shape.scale = Vector3.ONE * size
	add_child(shape, true)
	shape.global_position = pos + Vector3(-6.0, 6.0, -3.0)
	var tw := shape.create_tween()
	tw.tween_property(shape, "global_position", pos + Vector3(0.0, 2.5, -3.0), 0.45)
	tw.tween_interval(0.35)
	tw.tween_property(shape, "global_position", pos + Vector3(9.0, 9.0, -6.0), 0.7)
	tw.tween_callback(shape.queue_free)


## A Weaver on a thread: drops from high above to face height at pos, twitches, and zips back up.
func _spawn_spider_drop(pos: Vector3) -> void:
	var spider := MeshInstance3D.new()
	spider.name = "RoofScare"
	spider.mesh = HordeMesh.mesh_for(Horde.KIND_WEAVER)
	spider.material_override = HordeMesh.material_for(Horde.KIND_WEAVER)
	spider.scale = Vector3.ONE * 1.6
	add_child(spider, true)
	var thread := MeshInstance3D.new()
	var line := CylinderMesh.new()
	line.top_radius = 0.012
	line.bottom_radius = 0.012
	line.height = 9.0
	thread.mesh = line
	thread.material_override = LevelKit.mat("rotor")
	thread.position = Vector3(0.0, 9.0 * 0.5 / 1.6 + 0.3, 0.0)
	thread.scale = Vector3.ONE / 1.6
	spider.add_child(thread)
	var face := pos + Vector3(0.0, 1.35, 0.0)
	spider.global_position = face + Vector3(0.0, 9.0, 0.0)
	var me := Net.get_local_player()
	if me != null:
		var to := me.global_position - pos
		spider.rotation.y = atan2(-to.x, -to.z) + PI  # its face toward you
	spider.rotation.x = -1.1  # hanging head-down, belly out
	Sfx.play_at(self, "scrape", face, -2.0, 2.2, 20.0)
	var tw := spider.create_tween()
	tw.tween_property(spider, "global_position", face, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	for k in 4:
		tw.tween_property(spider, "rotation:z", 0.25 if k % 2 == 0 else -0.25, 0.12)
	tw.tween_callback(func() -> void: Sfx.play_at(self, "spider_shriek", face, 2.0, 1.25, 20.0))
	tw.tween_property(spider, "global_position", face + Vector3(0.0, 10.0, 0.0), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(spider.queue_free)


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
	Net.spawn_pickup("wrench", s + Vector3(-5.0, 0.0, 1.5), 0)
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
	heli_elapsed = 0.0
	dread.server_reset(RoofDread.FIRST_COOL)
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
	if here:
		if _tasks_set:
			dread.server_tick(delta, players)
		_tick_boarding(players)
		_supply_t -= delta
		if _supply_t <= 0.0:
			_supply_t = 2.0
			_ensure_escape_jetpacks(players)
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
					GameState.post_message("ROOF %d OF %d. %d to go." % [k, ROOF_COUNT, ROOF_COUNT - k], 3.0)
				else:
					GameState.post_message("THE LAST ROOF. The fire escape goes up the tower from here.", 4.0)
					GameState.complete_task(TASK_ROOFS)
				if SPIDER_ROOFS.has(k):
					dread.queue("roof_drop", p, 4.0)  # once it has gone quiet: a spider in your face
		if _on_helipad(p.global_position):
			if not GameState.task_done(TASK_ESCAPE):
				GameState.complete_task(TASK_ROOFS)
				GameState.complete_task(TASK_ESCAPE)
				_start_round(_waves.size())
				dread.queue("roof_swarm", p, 0.0)  # the hush as you top it, then the bats burst up off the tower
	if GameState.task_done(TASK_ESCAPE) and not _pad_told:
		_pad_told = true
		heli_fraction = 1.0
		heli_elapsed = 0.0
		GameState.complete_task(TASK_PAD)
		_ensure_escape_jetpacks(players)
		GameState.post_message("I CAN'T LAND. Jetpack up from a striped launch line, then steer into the GREEN CABIN. Hold F / left click. I'll circle back!", 8.0)


func _ensure_escape_jetpacks(players: Array[Player]) -> void:
	if not GameState.task_done(TASK_ESCAPE) or not _tasks_set:
		return
	var needed := 0
	for p in players:
		if not p.has_item("jetpack"):
			needed += 1
	var supply := origin + tower_top + Vector3(-4.0, 0.1, 3.0)
	var waiting := 0
	for pickup in get_tree().get_nodes_in_group("pickups"):
		if pickup.get("item_id") == "jetpack" and not pickup.is_queued_for_deletion() and pickup.global_position.distance_to(supply) < 8.0:
			waiting += 1
	for i in maxi(0, needed - waiting):
		Net.spawn_pickup("jetpack", supply + Vector3(float((waiting + i) % 3) * 1.8, 0.0, -float((waiting + i) / 3) * 1.8), 0)


func is_aboard(p: Vector3) -> bool:
	var local := _heli.to_local(p)
	return absf(local.x) < 2.9 and absf(local.z) < 2.4 and local.y >= 0.55 and local.y < 2.2


func _tick_boarding(players: Array[Player]) -> void:
	if heli_fraction < 1.0 or not _tasks_set or players.is_empty() or not GameState.task_done(TASK_ESCAPE):
		return
	if _layoff_pending or Time.get_ticks_msec() - last_layoff_msec() < 3000:
		return
	for p in players:
		if p.state != Player.State.NORMAL or not is_aboard(p.global_position):
			return
	GameState.complete_task(TASK_ABOARD)
	GameState.set_escaped("Airlifted off Carrow Heights. Next stop: Level 4, the Hotel Velluto.")


func _on_helipad(p: Vector3) -> bool:
	var l := p - origin - tower_top
	return l.y > -1.0 and l.y < 6.0 and absf(l.x) < TOWER_W * 0.5 and absf(l.z) < TOWER_W * 0.5


## Every peer follows the host's flight clock. The deck is also the boarding volume's frame.
func _tick_helicopter(delta: float) -> void:
	if _rotor == null:
		return
	var spin := lerpf(0.0, 32.0, heli_fraction * heli_fraction)
	if GameState.escaped:
		spin = 40.0
		_heli.position.y += 3.0 * delta  # up and away
		_heli.rotation.x = lerpf(_heli.rotation.x, -0.12, delta)
	elif heli_fraction > 0.0:
		heli_elapsed += delta
		var phase := heli_elapsed / FLYBY_SECONDS * TAU
		_heli.position = tower_top + Vector3(-cos(phase) * FLYBY_WIDTH, FLYBY_HEIGHT + 0.35 * sin(phase * 2.0), sin(phase) * 1.5)
	else:
		_heli.position = tower_top + Vector3(-FLYBY_WIDTH, FLYBY_HEIGHT, 0.0)
	_rotor.rotation.y += spin * delta
	_tail_rotor.rotation.x += spin * 3.0 * delta
	_heli_light.visible = fmod(Time.get_ticks_msec() * 0.001, 1.0) < 0.15
	if heli_fraction > 0.02 and not Sfx.is_silent():
		Sfx.start_loop(_heli_sound)
		_heli_sound.pitch_scale = 0.6 + 0.9 * heli_fraction
		_heli_sound.volume_db = -12.0  # rotor should leave room for proximity voices
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
	heli_elapsed = 0.0
	heli_fraction = 0.0
	_pad_told = false
	dread.server_reset(16.0)


## The Stack asks: is this position in the district (over the route, whatever its height)?
func in_district(p: Vector3) -> bool:
	var l := p - origin
	return _route_bounds.grow(12.0).has_point(Vector2(l.x, l.z))
