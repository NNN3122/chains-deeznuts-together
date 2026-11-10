class_name Town
extends Node3D
## Level 4: Kettle Hollow (the user: "after you escape with the helicopter it crashes into a nearby
## town where there's a giant super fast monster; you and your partner escape world-rally-racing
## style: a driver, and the passenger has the map and gives the driver directions, while the monster
## chases behind"). The helicopter comes down at the edge of a small town at night that was hosting a
## night rally; the rally cars are still on the start line with the keys in. The Line rides two to a
## car (the chain goes PAIRS for it): the driver drives and sees no map; the navigator has the map
## (RallyPanel) and calls the turns, by voice or with the movement keys (A left, D right, W straight
## on, S brake), which flash on the driver's screen. The route through the grid of streets is the
## seed's: a long winding way from the crash site to the bridge out of town, the other streets ending
## in burning wreckage. The Strider gallops the route behind the cars, faster the longer it runs, and
## catches a car it passes (a layoff: everyone back in the cars at the start). Every car over the
## finish and the Line drives on, out of town, to Ashgrave Manor.
## Built far under everything else at `origin` (LevelStack.TOWN_Y), everything local under `root`.

const FLOOR_NAME: String = "KETTLE HOLLOW"
const SEED: int = 4404
const GRID: int = 9  # intersections a side
const SPACING: float = 34.0  # m between intersections
const ROAD: float = 11.0  # m wide streets
const SIDEWALK: float = 1.2
const APPROACH: float = 95.0  # m of road from the crash site to the first corner
const EXIT_LEN: float = 80.0  # m from the last corner to the finish, on the road out
const RUNOFF: float = 90.0  # m of road past the finish
const ROUTE_MIN: int = 24  # corners on the way through
const ROUTE_MAX: int = 34
const MIN_TURNS: int = 12
const CARS: int = 5  # built on every peer; as many as the Line needs are used, two to a car
const CAR_FIRST: float = 45.0  # m along the route where the first car starts
const CAR_GAP: float = 9.0
const WRECK_S: float = -8.0  # the helicopter, burning, behind the cars
const STRIDER_START: float = -70.0  # m along the route it comes from (over the wall at the crash site)
const COUNTDOWN: float = 3.0  # s from sitting in the cars to GO
const STRIDER_DELAY: float = 4.0  # s after GO before it comes over the wall
const STRIDER_SPEED: float = 18.0  # m/s at first (a car flat out does 36, and a clean run through the corners about 22)
const STRIDER_RAMP: float = 0.08  # m/s faster every second it runs
const STRIDER_TOP: float = 27.0
const RUBBER_GAP: float = 75.0  # m: further behind the slowest car than this and it closes faster
const RUBBER_K: float = 0.22
const CATCH_GAP: float = 4.0  # m of route: closer than this behind a car and it has it
const OFF_ROUTE: float = 12.0  # m from the route's line a car stops counting progress (a wrong turn)
const CALL_RANGE: float = 55.0  # m before a corner the solo co-driver calls it
const OUT_SECONDS: float = 2.5  # s after the last car crosses the line before the Line is on its way
const DEAD_END_CHANCE: float = 0.45  # of the streets off the route, blocked by a building that came down across them
const ROUTE_WRECK_CHANCE: float = 0.25  # of the route's streets, a wreck on one side to squeeze past
const LAMP_CHANCE: float = 0.45  # of the corners with a street lamp
enum Call { NONE, LEFT, RIGHT, STRAIGHT, BRAKE, GO }
const STOREY: float = 3.4  # m a floor above the shops
const SHOP_H: float = 4.2  # m: the ground floor, shopfronts on the streets
const BODY_KEYS: Array[String] = ["town_brick", "town_brick", "town_brick_dark", "town_stone", "town_concrete", "town_stucco", "town_stucco_warm"]
const SIGN_KEYS: Array[String] = ["town_sign_red", "town_sign_green", "town_sign_cream", "town_sign_cream"]
const AWNING_KEYS: Array[String] = ["town_awning_red", "town_awning_green", "town_awning_stripe"]
const SHOP_NAMES: Array[String] = ["KETTLE HARDWARE", "DOLLY'S DINER", "HOLLOW PHARMACY", "SUDS LAUNDROMAT", "PAWN & LOAN", "BAIT & TACKLE", "REEL VIDEO", "BARBER", "LIQUOR", "MERCER FUNERAL HOME", "QUARRY BAR", "FIRST HOLLOW BANK", "DONUTS", "TAXIDERMY", "PIZZA", "THRIFT", "GUNS & AMMO", "DRY CLEANING"]
const WARNINGS: Array[String] = ["HELP US", "IT HEARS ENGINES", "DON'T STOP", "NOT SAFE", "3 INSIDE
SEND HELP", "KEEP DRIVING", "STAY OFF
MAIN ST", "IT CAME FROM
THE QUARRY", "WE'RE STILL HERE", "DON'T LOOK UP", "NO WAY OUT", "MOM I'M SORRY"]
const MAX_WARNINGS: int = 18
const MAX_SHOP_SIGNS: int = 70
const SURGE_FIRST: float = 16.0  # s after GO before it first sprints at the cars
const SURGE_EVERY_MIN: float = 22.0
const SURGE_EVERY_MAX: float = 36.0
const SURGE_SECONDS: float = 5.0
const SURGE_BOOST: float = 12.0  # m/s on top of its pace while it sprints: only the navigator's gun holds it off
# The mountain road (after the bridge out of town): narrow, winding, through a dead forest, no lamps.
const MOUNTAIN_ROAD: float = 9.0  # m wide
const MOUNTAIN_SHOULDER: float = 1.6  # m of gravel each side; past it the dirt grabs the car (RallyCar.rough)
const MOUNTAIN_LEN: float = 1100.0  # m of bends before the last straight
const BRIDGE_LEN: float = 60.0
const MTN_STEP: float = 3.0  # m between the road's points
const MTN_FINISH: float = 90.0  # m of straight from the last bend to the line
const MTN_SWING: float = 1.45  # rad: the road never heads further than this off north (it can't fold back on itself)
const MTN_DRIFT: float = 140.0  # m east or west of the bridge before the bends lean back
const RIDGE_TILE: float = 6.0  # m: the ridge's ground squares
const RIDGE_WIDTH: float = 40.0  # m either side of the road the ridge reaches; past it, the drop
const VALLEY_DEPTH: float = 45.0  # m down to the valley
const MTN_CELL: float = 20.0  # m: the lookup grid of the road's points
const ROAD_BLOCKS: int = 7  # things across half the road on the mountain
const FALL_LAYOFF: float = 6.0  # m under the road: that car's gone over
const PACE_RADIUS: Array[float] = [0.0, 13.0, 18.0, 24.0, 31.0]  # grade 1 (a hairpin) to 4: tighter than this; looser is a 5
const PACE_WORDS: Array[String] = ["", "HAIRPIN", "2", "3", "4", "5"]
const CALL_WORDS: Array[String] = ["", "LEFT", "RIGHT", "STRAIGHT ON", "BRAKE!", "GO GO GO"]
const TASKS: Array[String] = [
	"Two to a car: the DRIVER drives, the NAVIGATOR has the map and calls every turn",
	"Don't let the Strider catch a car",
	"Every car over the finish line, out of Kettle Hollow",
]

var seed_value: int = YellowRooms.DEFAULT_SEED
var origin: Vector3 = Vector3.ZERO
var embedded: bool = true
var checkpoint_index: int = 11
var test_points: Dictionary = {}
var spawn_position: Vector3 = Vector3.ZERO
var spawn_facing: float = 0.0
var root: Node3D
var cars: Array[RallyCar] = []
var strider: Strider
var threats: RoadThreats
var escaped: Callable  # the Stack: every car is out, drive on to the manor
var layoff: Callable  # the Stack's request_layoff
var active: bool = false  # replicated: the chase is on (the Line is in the cars)
var countdown: float = -1.0  # replicated: s to GO, < 0 when running
# The street grid and the route, local (under root).
var route: Array[Vector2i] = []  # the corners, in order
var route_pts: PackedVector3Array = PackedVector3Array()  # crash site, the corners, the finish, the run-off
var route_s: PackedFloat32Array = PackedFloat32Array()  # metres along the route at each point
var finish_s: float = 0.0
var turns: Array = []  # [s, Call, grade] for each corner where the route turns (grade 0 in town, 1-5 on the mountain)
var mountain_pts: PackedVector3Array = PackedVector3Array()  # local: the mountain road's middle, from the bridge
var mountain_start_s: float = 0.0  # route metres where the bridge begins
var mountain_corners: Array = []  # [s0, s1 (route metres), Call, grade, radius]
var cliffs: Array = []  # [k0, k1, side]: stretches of the mountain road with a drop on one side
var road_blocks: PackedVector3Array = PackedVector3Array()  # world: what's across half the mountain road
var _ridge: Dictionary = {}  # Vector2i tile -> true: there's ground there
var _mgrid: Dictionary = {}
var _fell: bool = false  # server: a car has gone over (one layoff for it)
var falls: int = 0  # server: tests
var _mp: Vector3 = Vector3.ZERO  # laying the mountain out: where, which way, how far
var _mh: float = 0.0
var _m_len: float = 0.0
var dead_ends: Dictionary = {}  # edge key -> true: a collapsed building across that street
var collapse_points: PackedVector3Array = PackedVector3Array()  # world: the middle of each collapse (tests, the tour)
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _drng: RandomNumberGenerator = RandomNumberGenerator.new()  # the buildings' dressing: its own dice, so the streets stay where they were
var _warnings: int = 0
var _shop_signs: int = 0
var _flicker: Array[OmniLight3D] = []
var _moon: DirectionalLight3D
var _wind: AudioStreamPlayer
var _fires: Array[OmniLight3D] = []
var _cam: Camera3D
var _panel: RallyPanel
var _pairs_on: bool = false
var _run_t: float = 0.0  # server: s since GO
var _surge_at: float = 0.0  # server: _run_t of the next sprint
var _surge_left: float = 0.0  # server: s of this sprint left
var _lunge_car: int = -1
var _out_t: float = -1.0
var _last_call: Dictionary = {}  # server: player instance id -> the Call their keys are making
var _call_cool: Dictionary = {}
var _auto_called: Dictionary = {}  # server: car -> s of the last corner the co-driver called
var _shown: bool = false
var debug_hold_strider: bool = false  # tests: it stays where it is
var debug_cam_free: bool = false  # the screenshot tour: leave whatever camera it made current
var calls_seen: int = 0  # every peer: calls that reached a car this player sits in (tests)


func _enter_tree() -> void:
	if has_node("Sync"):
		return
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	for prop in ["active", "countdown"]:
		var path := NodePath(".:" + prop)
		cfg.add_property(path)
		cfg.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	sync.replication_config = cfg
	add_child(sync)


func _ready() -> void:
	root = Node3D.new()
	root.name = "Root"
	root.position = origin
	add_child(root)
	_rng.seed = SEED + seed_value
	_drng.seed = SEED + seed_value + 7919
	LevelKit.set_town_ground(origin.y)
	_lay_out_route()
	var batch := LevelKit.BoxBatch.new()
	_build_ground(batch)
	_build_blocks(batch)
	_build_edges(batch)
	_build_route_dressing(batch)
	_build_mountain(batch)
	batch.build(root, "Town")
	_build_lights()
	for k in CARS:
		var xf := _start_xform(k)
		var car := RallyCar.create(k, xf)
		root.add_child(car)
		car.global_transform = xf  # create() set it as local; the root sits at the town's origin
		cars.append(car)
	strider = Strider.new()
	strider.name = "Strider"
	strider.town = self
	root.add_child(strider)
	threats = RoadThreats.new()
	threats.name = "Threats"
	threats.town = self
	root.add_child(threats)
	threats.build()
	spawn_position = route_point(CAR_FIRST - 14.0) + Vector3(0.0, 0.1, 0.0)
	spawn_facing = 0.0
	test_points["t_start"] = spawn_position
	test_points["t_finish"] = route_point(finish_s)
	set_shown(false)


func first_objective() -> String:
	return "KETTLE HOLLOW. The helicopter's down and something huge is coming over the wall. Two to a car: the driver drives blind, the navigator has the map. Get out of town."


# --- The route ---------------------------------------------------------------------------------

func corner(c: Vector2i) -> Vector3:
	return Vector3(float(c.x) * SPACING, 0.0, -float(c.y) * SPACING)


static func edge_key(a: Vector2i, b: Vector2i) -> String:
	if a.x < b.x or (a.x == b.x and a.y < b.y):
		return "%d,%d-%d,%d" % [a.x, a.y, b.x, b.y]
	return "%d,%d-%d,%d" % [b.x, b.y, a.x, a.y]


func _inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < GRID and c.y < GRID


## A winding way from the south-west corner to the north-east one: a walk that never crosses itself,
## turns more often than not, and is always able to reach the end.
func _lay_out_route() -> void:
	var start := Vector2i(0, 0)
	var goal := Vector2i(GRID - 1, GRID - 1)
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var best: Array[Vector2i] = []
	for attempt in 600:
		var path: Array[Vector2i] = [start]
		var seen := {start: true}
		var last := Vector2i(0, 1)  # in from the crash site, heading north
		var turns_made := 0
		while path[path.size() - 1] != goal:
			var cur: Vector2i = path[path.size() - 1]
			var options: Array[Vector2i] = []
			var weights: Array[float] = []
			for d in dirs:
				var n := cur + d
				if not _inside(n) or seen.has(n):
					continue
				var steps_left := ROUTE_MAX - path.size()
				if absi(goal.x - n.x) + absi(goal.y - n.y) > steps_left:
					continue
				if not _reaches(n, goal, seen):
					continue
				options.append(d)
				weights.append(1.0 if d == last else 2.6)
			if options.is_empty():
				break
			var total := 0.0
			for w in weights:
				total += w
			var pick := _rng.randf() * total
			var chosen := options[0]
			for k in options.size():
				pick -= weights[k]
				if pick <= 0.0:
					chosen = options[k]
					break
			if chosen != last:
				turns_made += 1
			last = chosen
			var nxt := cur + chosen
			path.append(nxt)
			seen[nxt] = true
		if path[path.size() - 1] == goal and path.size() >= ROUTE_MIN and turns_made >= MIN_TURNS:
			best = path
			break
		if path[path.size() - 1] == goal and path.size() > best.size():
			best = path
	if best.is_empty() or best[best.size() - 1] != goal:
		best = []  # a snake up the grid: it always works
		for y in GRID:
			for x in GRID:
				best.append(Vector2i(x if y % 2 == 0 else GRID - 1 - x, y))
		if best[best.size() - 1] != goal:
			best.append(goal)
	route = best
	route_pts = PackedVector3Array()
	route_pts.append(corner(route[0]) + Vector3(0.0, 0.0, APPROACH))
	for c in route:
		route_pts.append(corner(c))
	var last_corner := corner(route[route.size() - 1])
	var exit_end := last_corner + Vector3(0.0, 0.0, -EXIT_LEN)
	route_pts.append(exit_end)
	var town_n := route_pts.size()
	_lay_out_mountain(exit_end)
	route_pts.append_array(mountain_pts)
	route_s = PackedFloat32Array()
	var acc := 0.0
	for k in route_pts.size():
		if k > 0:
			acc += route_pts[k].distance_to(route_pts[k - 1])
		route_s.append(acc)
	finish_s = route_s[route_pts.size() - 1] - RUNOFF
	mountain_start_s = route_s[town_n - 1]
	turns = []
	for k in range(1, town_n - 1):
		var a := route_pts[k] - route_pts[k - 1]
		var b := route_pts[k + 1] - route_pts[k]
		var cross := a.x * b.z - a.z * b.x
		if absf(cross) > 1.0:
			turns.append([route_s[k], Call.RIGHT if cross > 0.0 else Call.LEFT, 0])
	for mc in mountain_corners:
		mc[0] = float(mc[0]) + mountain_start_s
		mc[1] = float(mc[1]) + mountain_start_s
		turns.append([mc[0], mc[2], mc[3]])


## Out of town over the bridge and up into the hills: straights and bends of every kind (sweepers,
## tight ones, hairpins), never heading back south, leaning back toward the middle when it has
## drifted far east or west. mountain_pts every MTN_STEP metres; mountain_corners in metres from
## the bridge (made route metres by the caller), each graded like a pace note by its radius.
func _lay_out_mountain(start: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + seed_value + 97
	mountain_pts = PackedVector3Array()
	mountain_corners = []
	_mp = start
	_mh = 0.0
	_m_len = 0.0
	_m_step(BRIDGE_LEN, 0.0)
	while _m_len < MOUNTAIN_LEN:
		_m_step(rng.randf_range(22.0, 75.0) if rng.randf() < 0.7 else rng.randf_range(6.0, 14.0), 0.0)
		var a := rng.randf_range(0.55, 2.4)
		var r := rng.randf_range(10.0, 16.0) if a > 1.9 else rng.randf_range(11.0, 44.0)
		var left := rng.randf() < 0.5
		var drift := _mp.x - start.x
		if drift > MTN_DRIFT:
			left = true  # back west
		elif drift < -MTN_DRIFT:
			left = false
		var room_left := MTN_SWING - _mh
		var room_right := MTN_SWING + _mh
		if (left and room_left < a) or (not left and room_right < a):
			if (room_right if left else room_left) >= a:
				left = not left
			else:
				left = room_left >= room_right
				a = minf(a, room_left if left else room_right)
		if a < 0.35:
			continue
		var s0 := _m_len
		_m_step(a * r, (1.0 if left else -1.0) / r)
		mountain_corners.append([s0, _m_len, Call.LEFT if left else Call.RIGHT, pace_grade(r), r])
	_m_step(MTN_FINISH + RUNOFF, 0.0)


func _m_step(length: float, curv: float) -> void:
	var n := maxi(1, int(ceilf(length / MTN_STEP)))
	var d := length / float(n)
	for k in n:
		_mh += curv * d * 0.5
		_mp += Vector3(-sin(_mh), 0.0, -cos(_mh)) * d
		_mh += curv * d * 0.5
		mountain_pts.append(_mp)
		_m_len += d


## A bend's pace note by its radius: 1 is a hairpin, 5 near flat out.
static func pace_grade(radius: float) -> int:
	for g in range(1, PACE_RADIUS.size()):
		if radius < PACE_RADIUS[g]:
			return g
	return 5


## The next bend on the route after s (route metres) within "within", or [].
func next_turn(s: float, within: float) -> Array:
	for t in turns:
		if float(t[0]) > s:
			return t if float(t[0]) - s <= within else []
	return []


## Is a local point on the mountain road's surface (the asphalt and its shoulders)?
func on_mountain_road(p: Vector3, s: float) -> bool:
	var q := route_local(s)
	return Vector2(p.x - q.x, p.z - q.z).length() <= MOUNTAIN_ROAD * 0.5 + MOUNTAIN_SHOULDER


func _reaches(from: Vector2i, goal: Vector2i, seen: Dictionary) -> bool:
	var queue: Array[Vector2i] = [from]
	var visited := {from: true}
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if c == goal:
			return true
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + d
			if _inside(n) and not seen.has(n) and not visited.has(n):
				visited[n] = true
				queue.append(n)
	return false


## Local point s metres along the route (before the start and past the end it carries straight on).
func route_local(s: float) -> Vector3:
	var n := route_pts.size()
	if s <= 0.0:
		return route_pts[0] + (route_pts[0] - route_pts[1]).normalized() * -s
	for k in range(1, n):
		if s <= route_s[k]:
			var u := (s - route_s[k - 1]) / maxf(route_s[k] - route_s[k - 1], 0.001)
			return route_pts[k - 1].lerp(route_pts[k], u)
	return route_pts[n - 1] + (route_pts[n - 1] - route_pts[n - 2]).normalized() * (s - route_s[n - 1])


func route_point(s: float) -> Vector3:
	return origin + route_local(s)


## The way along the route at s (a unit vector, flat), easing round the corners.
func route_tangent(s: float) -> Vector3:
	var a := route_local(s - 4.0)
	var b := route_local(s + 4.0)
	var d := b - a
	d.y = 0.0
	return d.normalized() if d.length() > 0.01 else Vector3(0.0, 0.0, -1.0)


## Metres along the route of a world position, looking only between lo and hi (a car's progress
## moves on from where it was; the route passes close to itself on the grid). -INF off the route.
func project(p: Vector3, lo: float, hi: float) -> float:
	var l := p - origin
	var best := -INF
	var best_d := OFF_ROUTE
	for k in range(1, route_pts.size()):
		if route_s[k] < lo or route_s[k - 1] > hi:
			continue
		var a := route_pts[k - 1]
		var b := route_pts[k]
		var ab := b - a
		var t := clampf((l - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		var q := a + ab * t
		var d := Vector2(l.x - q.x, l.z - q.z).length()
		if d < best_d:
			best_d = d
			best = route_s[k - 1] + ab.length() * t
	return best


func _start_xform(k: int) -> Transform3D:
	var s := CAR_FIRST - float(k) * CAR_GAP
	var at := route_point(s) + Vector3((-2.6 if k % 2 == 0 else 2.6), 0.02, 0.0)
	return Transform3D(Basis.looking_at(route_tangent(s), Vector3.UP), at)


# --- Building it -------------------------------------------------------------------------------

func _build_ground(batch: LevelKit.BoxBatch) -> void:
	var span := float(GRID - 1) * SPACING
	var lo := Vector2(-60.0, -span - EXIT_LEN - MTN_STEP - 0.5)  # the bridge takes over where the town ends
	var hi := Vector2(span + 60.0, APPROACH + 90.0)
	var c := (lo + hi) * 0.5
	batch.add(Vector3(c.x, -0.5, c.y), Vector3(hi.x - lo.x, 1.0, hi.y - lo.y), "town_asphalt")


func _wall(batch: LevelKit.BoxBatch, x0: float, x1: float, z0: float, z1: float) -> void:
	# A row of buildings filling a rectangle: the town's edge, or a road's sides.
	var horizontal := (x1 - x0) >= (z1 - z0)
	var length := (x1 - x0) if horizontal else (z1 - z0)
	var depth := (z1 - z0) if horizontal else (x1 - x0)
	var at := 0.0
	while at < length - 0.5:
		var w := minf(_rng.randf_range(9.0, 22.0), length - at)
		var h := _rng.randf_range(7.0, 26.0)
		var cc := Vector3(x0 + at + w * 0.5, 0.0, (z0 + z1) * 0.5) if horizontal else Vector3((x0 + x1) * 0.5, 0.0, z0 + at + w * 0.5)
		var size := Vector3(w, h, depth) if horizontal else Vector3(depth, h, w)
		_building(batch, cc, size)
		at += w


## One building: a photo-textured body (brick, stone, concrete or stucco), a plinth, a cornice and a
## parapet, roof clutter, and on every face that looks onto a street a real front: shopfronts with
## signs, awnings, shutters and doorways at street level, framed windows above (sills, lintels,
## jambs; some lit, some boarded, some just black holes), string courses between floors, fire
## escapes and downpipes, and now and then something painted on the boards by whoever was left.
func _building(batch: LevelKit.BoxBatch, c: Vector3, size: Vector3) -> void:
	var key: String = BODY_KEYS[_drng.randi_range(0, BODY_KEYS.size() - 1)]
	var trim := "town_stone" if key.begins_with("town_brick") or key == "town_concrete" else "town_concrete"
	batch.add(Vector3(c.x, size.y * 0.5, c.z), size, key)
	batch.add(Vector3(c.x, 0.45, c.z), Vector3(size.x + 0.24, 0.9, size.z + 0.24), trim, false)
	batch.add(Vector3(c.x, size.y - 0.35, c.z), Vector3(size.x + 0.36, 0.5, size.z + 0.36), trim, false)
	batch.add(Vector3(c.x, size.y + 0.08, c.z), Vector3(size.x + 0.6, 0.16, size.z + 0.6), trim, false)
	for f in 4:  # the parapet round the roof
		var n: Vector3 = [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)][f]
		var along_len := size.x if absf(n.z) > 0.5 else size.z
		var off := (size.z if absf(n.z) > 0.5 else size.x) * 0.5 - 0.15
		var box := Vector3(along_len, 0.9, 0.3) if absf(n.z) > 0.5 else Vector3(0.3, 0.9, along_len)
		batch.add(Vector3(c.x, size.y + 0.6, c.z) + n * off, box, key, false)
	_roof_clutter(batch, c, size)
	var floors := maxi(0, int((size.y - SHOP_H - 0.9) / STOREY))
	for f in 4:
		var n: Vector3 = [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)][f]
		var width := size.x if absf(n.z) > 0.5 else size.z
		var half := (size.z if absf(n.z) > 0.5 else size.x) * 0.5
		var face := Vector3(c.x, 0.0, c.z) + n * half
		if width < 3.5 or not _street_at(face + n * 4.0):
			continue
		var fc := Facade.new()
		fc.face = face
		fc.n = n
		fc.along = Vector3(n.z, 0.0, -n.x)
		fc.rot = 0.0 if absf(n.z) > 0.5 else PI * 0.5
		_shopfront(batch, fc, width, trim)
		_windows(batch, fc, width, floors, key, trim)
		if key.begins_with("town_brick") and floors >= 2 and width >= 9.0 and _drng.randf() < 0.35:
			_fire_escape(batch, fc, width, floors)
		if _drng.randf() < 0.55:
			var u := (width * 0.5 - 0.35) * (-1.0 if _drng.randf() < 0.5 else 1.0)
			_on(batch, fc, u, size.y * 0.5, 0.14, size.y, 0.0, 0.16, "town_rust")  # a downpipe


## A face of a building: where it is, which way it looks, the way along it, and the yaw that lays a
## box's x along it.
class Facade:
	var face: Vector3
	var n: Vector3
	var along: Vector3
	var rot: float


## A box on a face: centred u along it and y up, w wide and h tall, standing out from `out0` to
## `out0 + d` in front of the wall. Drawn only.
func _on(batch: LevelKit.BoxBatch, fc: Facade, u: float, y: float, w: float, h: float, out0: float, d: float, key: String) -> void:
	batch.add(fc.face + fc.n * (out0 + d * 0.5) + fc.along * u + Vector3(0.0, y, 0.0), Vector3(w, h, d), key, false, fc.rot)


## A label painted or hung on a face, lit only where light falls.
func _face_label(fc: Facade, u: float, y: float, text: String, color: Color, px: float, out: float) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 64
	l.pixel_size = px
	l.modulate = color
	l.outline_size = 0
	l.shaded = true
	l.double_sided = false
	l.visibility_range_end = 90.0
	l.position = fc.face + fc.n * out + fc.along * u + Vector3(0.0, y, 0.0)
	l.rotation.y = atan2(fc.n.x, fc.n.z)
	root.add_child(l)


func _shopfront(batch: LevelKit.BoxBatch, fc: Facade, width: float, trim: String) -> void:
	var sign_key: String = SIGN_KEYS[_drng.randi_range(0, SIGN_KEYS.size() - 1)]
	_on(batch, fc, 0.0, SHOP_H - 0.55, width - 0.4, 0.8, 0.0, 0.22, sign_key)  # the fascia
	_on(batch, fc, 0.0, SHOP_H - 0.08, width - 0.2, 0.14, 0.0, 0.32, trim)  # its cornice
	if _shop_signs < MAX_SHOP_SIGNS and width > 6.0 and _drng.randf() < 0.55:
		_shop_signs += 1
		var pale := sign_key == "town_sign_cream"
		_face_label(fc, 0.0, SHOP_H - 0.55, SHOP_NAMES[_drng.randi_range(0, SHOP_NAMES.size() - 1)], Color(0.06, 0.05, 0.04) if pale else Color(0.75, 0.68, 0.5), 0.011, 0.24)
	if width > 8.0 and _drng.randf() < 0.08:  # a neon tube still burning in a dead town
		_on(batch, fc, _drng.randf_range(-width * 0.3, width * 0.3), SHOP_H + 0.35, 2.2, 0.08, 0.25, 0.06, "town_neon_red" if _drng.randf() < 0.6 else "town_neon_blue")
	var bays := maxi(1, int((width - 1.0) / 4.5))
	var bay_w := (width - 1.0) / float(bays)
	for b in bays:
		var u := -width * 0.5 + 0.5 + (float(b) + 0.5) * bay_w
		_on(batch, fc, u - bay_w * 0.5, (SHOP_H - 1.0) * 0.5 + 0.05, 0.42, SHOP_H - 1.0, 0.0, 0.14, trim)  # a pilaster
		var roll := _drng.randf()
		var top := SHOP_H - 1.05
		if roll < 0.45:
			var gw := bay_w - 0.9
			var pane := "town_void" if _drng.randf() < 0.2 else ("town_glass_lit" if _drng.randf() < 0.05 else "town_glass")
			_on(batch, fc, u, (0.9 + top) * 0.5, gw, top - 0.9, 0.0, 0.04, pane)
			_on(batch, fc, u, top + 0.05, gw + 0.2, 0.1, 0.0, 0.1, "steel_dark")  # the frame
			_on(batch, fc, u, 0.95, gw + 0.2, 0.1, 0.0, 0.12, "steel_dark")
			_on(batch, fc, u, (0.9 + top) * 0.5, 0.08, top - 0.9, 0.0, 0.08, "steel_dark")  # the mullion
		elif roll < 0.75:
			var shut := bay_w - 0.6
			var down := _drng.randf_range(0.55, 1.0)  # some forced up from the bottom
			var h := (top - 0.05) * down
			_on(batch, fc, u, top - h * 0.5, shut, h, 0.0, 0.1, "town_rust")
			if down < 0.95:
				_on(batch, fc, u, (top - h) * 0.5, shut, top - h, 0.0, 0.02, "town_void")
			_on(batch, fc, u, top + 0.15, shut + 0.2, 0.3, 0.0, 0.3, "steel_dark")  # the shutter box
			if _warnings < MAX_WARNINGS and _drng.randf() < 0.18:
				_warnings += 1
				_face_label(fc, u, top - h * 0.45, WARNINGS[_drng.randi_range(0, WARNINGS.size() - 1)], Color(0.4, 0.03, 0.02), 0.014, 0.12)
		else:
			_on(batch, fc, u, 1.4, 1.4, 2.8, 0.0, 0.02, "town_void")  # a doorway, the door gone
			_on(batch, fc, u, 2.85, 1.7, 0.16, 0.0, 0.16, trim)
			for side: float in [-1.0, 1.0]:
				_on(batch, fc, u + side * 0.78, 1.4, 0.16, 2.8, 0.0, 0.16, trim)
			if _drng.randf() < 0.3:
				_on(batch, fc, u + _drng.randf_range(-0.5, 0.5), 0.13, 1.2, 0.02, 0.0, 1.6, "town_blood")  # something was dragged in
		if _drng.randf() < 0.32:  # an awning, some torn half away
			var aw: String = AWNING_KEYS[_drng.randi_range(0, AWNING_KEYS.size() - 1)]
			var deep := 1.5 if _drng.randf() < 0.75 else 0.7
			_on(batch, fc, u, top + 0.1, bay_w - 0.3, 0.1, 0.0, deep, aw)
			_on(batch, fc, u, top - 0.15, bay_w - 0.3, 0.4, deep - 0.06, 0.06, aw)  # its valance


func _windows(batch: LevelKit.BoxBatch, fc: Facade, width: float, floors: int, key: String, trim: String) -> void:
	var cols := int((width - 1.6) / 2.9)
	if cols < 1:
		return
	var pitch := (width - 1.6) / float(cols)
	for r in floors:
		var y0 := SHOP_H + float(r) * STOREY
		_on(batch, fc, 0.0, y0 - 0.05, width, 0.2, 0.0, 0.14, trim)  # a string course
		for k in cols:
			var u := -width * 0.5 + 0.8 + (float(k) + 0.5) * pitch
			var y := y0 + 1.65
			var roll := _drng.randf()
			var pane := "town_glass"
			if roll < 0.035:
				pane = "town_glass_lit"
			elif roll < 0.045:
				pane = "town_glass_tv"
			elif roll < 0.15:
				pane = "town_void"
			_on(batch, fc, u, y, 1.25, 1.8, 0.0, 0.02, pane)
			if pane != "town_void":
				_on(batch, fc, u, y + 0.05, 1.25, 0.06, 0.0, 0.06, "steel_dark")  # the sash bar
			for side: float in [-1.0, 1.0]:
				_on(batch, fc, u + side * 0.7, y, 0.15, 1.95, 0.0, 0.13, trim)  # the jambs
			_on(batch, fc, u, y - 1.0, 1.65, 0.13, 0.0, 0.2, trim)  # the sill
			_on(batch, fc, u, y + 1.04, 1.65, 0.26, 0.0, 0.12, key if key.begins_with("town_brick") else trim)  # the lintel
			if r < 2 and _drng.randf() < 0.09:  # boarded up from inside, late
				for p in 3:
					var py := y - 0.6 + float(p) * 0.6 + _drng.randf_range(-0.08, 0.08)
					_on(batch, fc, u + _drng.randf_range(-0.08, 0.08), py, 1.5, 0.22, 0.04, 0.05, "town_wood")
				if _warnings < MAX_WARNINGS and _drng.randf() < 0.4:
					_warnings += 1
					_face_label(fc, u, y, WARNINGS[_drng.randi_range(0, WARNINGS.size() - 1)], Color(0.45, 0.04, 0.03), 0.008, 0.1)


func _fire_escape(batch: LevelKit.BoxBatch, fc: Facade, width: float, floors: int) -> void:
	var u := _drng.randf_range(-width * 0.5 + 2.6, width * 0.5 - 2.6)
	for r in floors:
		var y := SHOP_H + float(r) * STOREY - 0.05
		_on(batch, fc, u, y, 3.8, 0.07, 0.0, 1.3, "town_rust")  # the grating
		_on(batch, fc, u, y + 1.0, 3.8, 0.05, 1.22, 0.05, "town_rust")  # the rail
		_on(batch, fc, u, y + 0.5, 3.8, 0.04, 1.22, 0.04, "town_rust")
		for side: float in [-1.0, 1.0]:
			_on(batch, fc, u + side * 1.88, y + 0.5, 0.05, 1.0, 1.22, 0.05, "town_rust")
		if r + 1 < floors:  # the ladder up to the next
			for side: float in [-1.0, 1.0]:
				_on(batch, fc, u + 1.3 + side * 0.2, y + STOREY * 0.5, 0.05, STOREY, 0.75, 0.05, "town_rust")
	_on(batch, fc, u - 1.2, SHOP_H - 1.4, 0.45, 2.6, 0.8, 0.05, "town_rust")  # the drop ladder, hanging


func _roof_clutter(batch: LevelKit.BoxBatch, c: Vector3, size: Vector3) -> void:
	var room := Vector2(size.x * 0.5 - 1.4, size.z * 0.5 - 1.4)
	if room.x < 1.0 or room.y < 1.0:
		return
	for k in _drng.randi_range(1, 3):  # air-conditioning units
		var at := Vector3(c.x + _drng.randf_range(-room.x, room.x), size.y + 0.45, c.z + _drng.randf_range(-room.y, room.y))
		batch.add(at, Vector3(1.3, 0.9, 1.0), "steel_dark", false, _drng.randf_range(0.0, PI))
	if _drng.randf() < 0.35:  # the stair's bulkhead
		batch.add(Vector3(c.x + room.x * 0.4, size.y + 1.2, c.z - room.y * 0.4), Vector3(2.4, 2.4, 3.0), "town_concrete", false)
	if size.y > 10.0 and _drng.randf() < 0.22 and room.x > 2.0 and room.y > 2.0:  # a timber water tank on legs
		var at := Vector3(c.x - room.x * 0.4, size.y, c.z + room.y * 0.4)
		batch.add(at + Vector3(0.0, 3.0, 0.0), Vector3(2.4, 2.8, 2.4), "town_wood", false)
		batch.add(at + Vector3(0.0, 4.55, 0.0), Vector3(1.6, 0.3, 1.6), "town_wood", false)
		for q in 4:
			batch.add(at + Vector3(-0.9 + 1.8 * float(q % 2), 0.8, -0.9 + 1.8 * float(q / 2)), Vector3(0.14, 1.6, 0.14), "steel_dark", false)
	if size.y > 12.0 and _drng.randf() < 0.18:
		batch.add(Vector3(c.x, size.y + 4.0, c.z), Vector3(0.25, 7.0, 0.25), "steel_dark", false)
		batch.add(Vector3(c.x, size.y + 7.6, c.z), Vector3(0.35, 0.35, 0.35), "led_red", false)


## Is q (town-local) out in a street, not round the back or outside the town?
func _street_at(q: Vector3) -> bool:
	var span := float(GRID - 1) * SPACING
	var e := ROAD * 0.5 + SIDEWALK
	if q.x < -e - 1.0 or q.x > span + e + 1.0 or q.z > APPROACH + 31.0 or q.z < -span - EXIT_LEN - RUNOFF:
		return false
	if q.z > e + 1.0:
		return absf(q.x) < e + 1.0  # the road in
	if q.z < -span - e - 1.0:
		return absf(q.x - span) < e + 1.0  # the road out
	var dx := absf(q.x - roundf(q.x / SPACING) * SPACING)
	var dz := absf(q.z - roundf(q.z / SPACING) * SPACING)
	return dx < e + 1.0 or dz < e + 1.0


## The kerbs round a block, and what's left on its pavement: bins, bags, a newspaper box, a bench.
func _kerbs_and_clutter(batch: LevelKit.BoxBatch, c: Vector3) -> void:
	var w := SPACING - ROAD
	for f in 4:
		var n: Vector3 = [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)][f]
		var box := Vector3(w, 0.2, 0.3) if absf(n.z) > 0.5 else Vector3(0.3, 0.2, w)
		batch.add(c + n * (w * 0.5 - 0.15) + Vector3(0.0, 0.1, 0.0), box, "town_concrete", false)
		var along := Vector3(n.z, 0.0, -n.x)
		for k in _drng.randi_range(0, 3):
			var at := c + n * (w * 0.5 - SIDEWALK * 0.5 - 0.25) + along * _drng.randf_range(-w * 0.42, w * 0.42) + Vector3(0.0, 0.12, 0.0)
			var roll := _drng.randf()
			if roll < 0.35:
				batch.add(at + Vector3(0.0, 0.5, 0.0), Vector3(0.62, 1.0, 0.62), "town_rust", false, _drng.randf_range(0.0, PI))  # a bin
			elif roll < 0.7:
				for b in _drng.randi_range(2, 5):  # bin bags, heaped
					var sz := _drng.randf_range(0.45, 0.7)
					batch.add(at + Vector3(_drng.randf_range(-0.5, 0.5), sz * 0.4, _drng.randf_range(-0.5, 0.5)), Vector3(sz, sz * 0.8, sz * 0.9), "town_bag", false, _drng.randf_range(0.0, PI))
			elif roll < 0.85:
				batch.add(at + Vector3(0.0, 0.55, 0.0), Vector3(0.5, 1.1, 0.45), "town_sign_red", false, atan2(n.x, n.z))  # a newspaper box
			else:
				batch.add(at + Vector3(0.0, 0.45, 0.0), Vector3(1.8, 0.08, 0.45) if absf(n.z) > 0.5 else Vector3(0.45, 0.08, 1.8), "town_wood", false)  # a bench
				batch.add(at + Vector3(0.0, 0.22, 0.0), Vector3(1.6, 0.44, 0.1) if absf(n.z) > 0.5 else Vector3(0.1, 0.44, 1.6), "steel_dark", false)


func _build_blocks(batch: LevelKit.BoxBatch) -> void:
	var span := float(GRID - 1) * SPACING
	var lot := SPACING - ROAD - SIDEWALK * 2.0
	for i in GRID - 1:
		for j in GRID - 1:
			var c := Vector3((float(i) + 0.5) * SPACING, 0.0, -(float(j) + 0.5) * SPACING)
			batch.add(c + Vector3(0.0, 0.06, 0.0), Vector3(SPACING - ROAD, 0.12, SPACING - ROAD), "town_paving", false)  # the pavement
			_kerbs_and_clutter(batch, c)
			var split := _rng.randf()
			if split < 0.5:
				_building(batch, c, Vector3(lot, 0.0, lot) + Vector3(0.0, _rng.randf_range(7.0, 24.0), 0.0))
			elif split < 0.85:
				for s: float in [-1.0, 1.0]:
					var half := lot * 0.5 - 0.3
					var off := Vector3(s * lot * 0.25, 0.0, 0.0) if _rng.randf() < 0.5 else Vector3(0.0, 0.0, s * lot * 0.25)
					var size := Vector3(half, _rng.randf_range(7.0, 24.0), lot) if off.x != 0.0 else Vector3(lot, _rng.randf_range(7.0, 24.0), half)
					_building(batch, c + off, size)
			else:
				for q in 4:
					var off := Vector3((-1.0 if q % 2 == 0 else 1.0) * lot * 0.25, 0.0, (-1.0 if q < 2 else 1.0) * lot * 0.25)
					_building(batch, c + off, Vector3(lot * 0.5 - 0.4, _rng.randf_range(6.0, 20.0), lot * 0.5 - 0.4))
	# The town's edge: buildings shoulder to shoulder round the outside, with a gap for the road in
	# from the crash site and the road out over the bridge.
	var e := ROAD * 0.5 + SIDEWALK
	var deep := 24.0
	_wall(batch, -e - deep, -e, e, e + deep)  # south, either side of the way in
	_wall(batch, e, span + e + deep, e, e + deep)
	_wall(batch, -e - deep, span - e, -span - e - deep, -span - e)  # north, up to the way out
	_wall(batch, -e - deep, -e, -span - e, e)  # west
	_wall(batch, span + e, span + e + deep, -span - e - deep, e + deep)  # east
	# The road in, between buildings, and the wall it ends at behind the wreck.
	_wall(batch, -e - deep, -e, e, APPROACH + 30.0)
	_wall(batch, e, e + deep, e, APPROACH + 30.0)
	_wall(batch, -e - deep, e + deep, APPROACH + 30.0, APPROACH + 50.0)
	# The road out, to the bridge and the dark beyond.
	_wall(batch, span - e - deep, span - e, -span - EXIT_LEN, -span - e)
	_wall(batch, span + e, span + e + deep, -span - EXIT_LEN, -span - e)
	test_points["t_way_in"] = origin + Vector3(0.0, 0.1, e + 4.0)


## Every street: dead ends of burning wreckage off the route, a wreck to squeeze past on it, and the
## centre dashes.
func _build_edges(batch: LevelKit.BoxBatch) -> void:
	var on_route := {}
	for k in range(1, route.size()):
		on_route[edge_key(route[k - 1], route[k])] = k
	for i in GRID:
		for j in GRID:
			var a := Vector2i(i, j)
			for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				var b := a + d
				if not _inside(b):
					continue
				var key := edge_key(a, b)
				var pa := corner(a)
				var pb := corner(b)
				var mid := (pa + pb) * 0.5
				var horizontal := d.x != 0
				for t in 4:
					var u := (float(t) + 0.5) / 4.0
					var p := pa.lerp(pb, u)
					var size := Vector3(2.4, 0.02, 0.18) if horizontal else Vector3(0.18, 0.02, 2.4)
					batch.add(p + Vector3(0.0, 0.01, 0.0), size, "road_line", false)
				if on_route.has(key):
					if int(on_route[key]) >= 3 and _rng.randf() < ROUTE_WRECK_CHANCE:
						var side := -1.0 if _rng.randf() < 0.5 else 1.0
						var across := Vector3(0.0, 0.0, 1.0) if horizontal else Vector3(1.0, 0.0, 0.0)
						var at := mid + across * side * (ROAD * 0.5 - 1.6)
						_wreck(batch, at, 0.0 if horizontal else PI * 0.5, _rng.randf() < 0.35)
					continue
				if _rng.randf() < DEAD_END_CHANCE:
					dead_ends[key] = true
					_collapse(batch, mid, horizontal)


## A wrong turn: halfway down this street a building has come down across it. A heap of floor slabs,
## beams and rubble the whole width of the road and higher than the car, dust still hanging, now and
## then something burning in it. Nothing gets through: back out, and the Strider is coming.
func _collapse(batch: LevelKit.BoxBatch, mid: Vector3, horizontal: bool) -> void:
	var along := Vector3(1.0, 0.0, 0.0) if horizontal else Vector3(0.0, 0.0, 1.0)
	var across := Vector3(0.0, 0.0, 1.0) if horizontal else Vector3(1.0, 0.0, 0.0)
	var yaw := 0.0 if horizontal else PI * 0.5
	var width := ROAD + SIDEWALK * 2.0 + 1.0
	collapse_points.append(origin + mid)
	batch.add_solid(mid + Vector3(0.0, 1.9, 0.0), Vector3(7.0, 3.8, width), yaw)
	for k in 7:  # floor slabs, broken and stacked at angles
		var c := mid + along * _drng.randf_range(-3.0, 3.0) + across * _drng.randf_range(-width * 0.4, width * 0.4) + Vector3(0.0, _drng.randf_range(0.6, 3.0), 0.0)
		var b := Basis(Vector3.UP, _drng.randf_range(0.0, TAU)) * Basis(Vector3.RIGHT, _drng.randf_range(-0.9, 0.9)) * Basis(Vector3.FORWARD, _drng.randf_range(-0.7, 0.7))
		batch.add_prop("ruin_slab", RuinMeshes.fit("ruin_slab", c, Vector3(_drng.randf_range(4.0, 7.0), 0.45, _drng.randf_range(3.0, 5.0)), b))
	for k in 5:  # rubble heaped under them
		var c := mid + along * _drng.randf_range(-3.5, 3.5) + across * _drng.randf_range(-width * 0.45, width * 0.45)
		batch.add_prop("ruin_rubble", RuinMeshes.fit("ruin_rubble", c, Vector3(_drng.randf_range(3.0, 5.0), _drng.randf_range(1.2, 2.6), _drng.randf_range(3.0, 5.0)), Basis(Vector3.UP, _drng.randf_range(0.0, TAU))))
	for k in 3:  # girders sticking out of it
		var c := mid + along * _drng.randf_range(-2.0, 2.0) + across * _drng.randf_range(-width * 0.3, width * 0.3) + Vector3(0.0, _drng.randf_range(1.5, 3.0), 0.0)
		var b := Basis(Vector3.UP, yaw + _drng.randf_range(-0.6, 0.6)) * Basis(Vector3.RIGHT, _drng.randf_range(0.2, 0.7))
		batch.add_prop("ruin_beam", RuinMeshes.fit("ruin_beam", c, Vector3(0.4, 0.36, _drng.randf_range(5.0, 8.0)), b))
	if _drng.randf() < 0.35:
		var glow := mid + across * _drng.randf_range(-3.0, 3.0) + Vector3(0.0, 0.4, 0.0)
		batch.add_prop("ruin_embers", RuinMeshes.fit("ruin_embers", glow, Vector3(1.6, 0.5, 1.6)))
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.45, 0.12)
		light.light_energy = 1.8
		light.omni_range = 9.0
		light.position = glow + Vector3(0.0, 1.2, 0.0)
		root.add_child(light)
		_fires.append(light)
	var dust := FogVolume.new()  # the dust hasn't settled
	dust.size = Vector3(width + 4.0, 6.0, 12.0) if not horizontal else Vector3(12.0, 6.0, width + 4.0)
	dust.position = mid + Vector3(0.0, 2.5, 0.0)
	var fm := FogMaterial.new()
	fm.density = 0.12
	fm.albedo = Color(0.55, 0.5, 0.45)
	dust.material = fm
	root.add_child(dust)


## A burnt-out car (on its roof now and then), maybe still burning.
func _wreck(batch: LevelKit.BoxBatch, at: Vector3, yaw: float, burning: bool) -> void:
	var xf := Transform3D(Basis(Vector3.UP, yaw + PI * 0.5), at)
	if _rng.randf() < 0.4:
		xf.basis = xf.basis * Basis(Vector3.FORWARD, PI)
		xf.origin.y += 1.35
	batch.add_prop("town_wreck", xf)
	batch.add_solid(at + Vector3(0.0, 0.7, 0.0), Vector3(RallyCar.LENGTH, 1.4, RallyCar.WIDTH), yaw)
	if burning:
		var glow := at + Vector3(0.0, 1.2, 0.0)
		batch.add(glow, Vector3(1.2, 0.6, 1.2), "embers", false)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.45, 0.12)
		light.light_energy = 2.2
		light.omni_range = 11.0
		light.position = glow + Vector3(0.0, 1.0, 0.0)
		root.add_child(light)
		_fires.append(light)


## The crash site, the start and finish arches, the cars' grid.
func _build_route_dressing(batch: LevelKit.BoxBatch) -> void:
	var wreck_at := route_local(WRECK_S)
	batch.add_prop("town_heli", Transform3D(Basis(Vector3.UP, 0.7) * Basis(Vector3.FORWARD, 0.35), wreck_at + Vector3(1.5, 1.2, 0.0)))
	batch.add_solid(wreck_at + Vector3(1.5, 1.5, 0.0), Vector3(4.0, 3.0, 8.0), 0.7)
	batch.add(wreck_at + Vector3(-1.0, 0.4, 3.0), Vector3(3.0, 0.8, 3.0), "embers", false)
	for k in 2:
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.42, 0.1)
		light.light_energy = 4.0
		light.omni_range = 22.0
		light.position = wreck_at + Vector3(-1.0 + 3.0 * float(k), 3.0, 2.0 - 3.0 * float(k))
		root.add_child(light)
		_fires.append(light)
	_arch(batch, route_local(CAR_FIRST + 10.0), "KETTLE HOLLOW NIGHT RALLY\nSTART", route_tangent(CAR_FIRST + 10.0))
	_arch(batch, route_local(finish_s), "FINISH", route_tangent(finish_s))


func _arch(batch: LevelKit.BoxBatch, at: Vector3, text: String, tan: Vector3) -> void:
	var right := Vector3(-tan.z, 0.0, tan.x)
	var yaw := atan2(-tan.x, -tan.z)
	for s: float in [-1.0, 1.0]:
		batch.add(at + right * s * (ROAD * 0.5 + 0.4) + Vector3(0.0, 3.5, 0.0), Vector3(0.5, 7.0, 0.5), "steel_dark", true, yaw)
	batch.add(at + Vector3(0.0, 7.4, 0.0), Vector3(ROAD + 1.4, 1.6, 0.3), "billboard", false, yaw)
	var label := Label3D.new()
	label.text = text
	label.font_size = 64
	label.pixel_size = 0.012
	label.modulate = Color(0.08, 0.06, 0.05)
	label.shaded = true
	label.position = at + Vector3(0.0, 7.4, 0.0) - tan * 0.2
	label.rotation.y = yaw
	root.add_child(label)
	for k in 8:
		var col := "checker_dark" if k % 2 == 0 else "concrete"
		batch.add(at + right * (-ROAD * 0.5 + (float(k) + 0.5) * ROAD / 8.0) + Vector3(0.0, 0.05, 0.0), Vector3(ROAD / 8.0, 0.03, 0.9), col, false, yaw)


## The mountain road out of town (the last stretch before the finish) runs along a ridge: a strip of
## forested ground either side of it, and past that, and on the outside of the tight bends, a drop
## of VALLEY_DEPTH metres into a valley of dead trees (a car that goes over is a layoff). The road is
## asphalt with its lines and gravel shoulders (ribbons along mountain_pts); the bridge out of town
## crosses the valley on piers; the forest crowds the verges, every trunk solid; rock cut on the
## inside of the bends; a broken wooden fence along the cliff edges (a gap and you're over, a post at
## speed and the engine dies); chevron boards that show only in the headlights; and here and there
## something across half the road just past a bend: a fallen tree, a rockslide, an abandoned car.
func _build_mountain(batch: LevelKit.BoxBatch) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + seed_value + 191
	var pts := mountain_pts
	var n := pts.size()
	var half := MOUNTAIN_ROAD * 0.5
	var edge := half + MOUNTAIN_SHOULDER
	var bridge_n := int(BRIDGE_LEN / MTN_STEP)
	_lay_out_cliffs()
	# The ridge: ground in RIDGE_TILE squares, solid all the way down to the valley, kept within
	# RIDGE_WIDTH of the road except where a cliff zone takes it away (never under the road itself).
	_ridge = {}
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in pts:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
	var t0 := Vector2i(floori((lo.x - RIDGE_WIDTH) / RIDGE_TILE), floori((lo.y - RIDGE_WIDTH) / RIDGE_TILE))
	var t1 := Vector2i(floori((hi.x + RIDGE_WIDTH) / RIDGE_TILE), floori((hi.y + RIDGE_WIDTH) / RIDGE_TILE))
	var start_z := pts[0].z
	for tx in range(t0.x, t1.x + 1):
		for tz in range(t0.y, t1.y + 1):
			var c := Vector3((float(tx) + 0.5) * RIDGE_TILE, 0.0, (float(tz) + 0.5) * RIDGE_TILE)
			if c.z > start_z - 1.0:
				continue  # the town's own ground
			var near := _nearest_mountain(c)
			var k: int = near[0]
			var d: float = near[1]
			if d > RIDGE_WIDTH or k <= bridge_n + 1:
				continue  # the valley (and under the bridge)
			if d > edge + RIDGE_TILE * 0.75 and _in_cliff(k, c):
				continue  # the drop on the outside of a bend
			_ridge[Vector2i(tx, tz)] = true
			batch.add(Vector3(c.x, -VALLEY_DEPTH * 0.5, c.z), Vector3(RIDGE_TILE, VALLEY_DEPTH, RIDGE_TILE), "town_forest")
	# The valley floor far below, and its dead trees (nothing down there to hit: you're done by then).
	batch.add(Vector3((lo.x + hi.x) * 0.5, -VALLEY_DEPTH - 0.5, (lo.y + hi.y) * 0.5), Vector3(hi.x - lo.x + 400.0, 1.0, hi.y - lo.y + 400.0), "town_forest")
	for k in 260:
		var at := Vector3(rng.randf_range(lo.x - 150.0, hi.x + 150.0), -VALLEY_DEPTH, rng.randf_range(lo.y - 150.0, hi.y + 150.0))
		batch.add_prop("town_tree", Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * rng.randf_range(1.6, 2.6)), at))
	# The road: asphalt, gravel shoulders, white edge lines, a dashed middle.
	var road := MeshInstance3D.new()
	road.name = "MountainRoad"
	road.mesh = _ribbons([[-half, half, 0.03, "town_asphalt", 0.0], [half, edge, 0.02, "town_gravel", 0.0], [-edge, -half, 0.02, "town_gravel", 0.0],
		[half - 0.35, half - 0.2, 0.04, "road_line", 0.0], [-half + 0.2, -half + 0.35, 0.04, "road_line", 0.0], [-0.08, 0.08, 0.04, "road_line", 3.0]])
	road.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(road)
	for k in range(1, n):
		var a := pts[k - 1]
		var b := pts[k]
		var mid := (a + b) * 0.5
		var d := (b - a)
		var yaw := atan2(-d.x, -d.z)
		var side := Vector3(-d.z, 0.0, d.x).normalized()  # to the right of the way up
		if k <= bridge_n + 1:
			# The bridge over the valley: a deck, concrete parapets, a pier now and then.
			batch.add(mid + Vector3(0.0, -0.6, 0.0), Vector3(MOUNTAIN_ROAD + 1.6, 1.2, d.length() + 0.1), "town_concrete", true, yaw)
			for sgn: float in [-1.0, 1.0]:
				batch.add(mid + side * sgn * (half + 0.45) + Vector3(0.0, 0.55, 0.0), Vector3(0.4, 1.1, d.length() + 0.05), "town_concrete", true, yaw)
			if k % 7 == 0:
				batch.add(mid + Vector3(0.0, -VALLEY_DEPTH * 0.5, 0.0), Vector3(4.0, VALLEY_DEPTH, 3.0), "town_concrete", true, yaw)
			continue
		# The forest: trunks either side, thick at the verge, none on the road or over the drop.
		for sgn: float in [-1.0, 1.0]:
			for t in 3:
				if rng.randf() > [0.6, 0.5, 0.45][t]:
					continue
				var off: float = edge + [rng.randf_range(1.0, 3.0), rng.randf_range(3.0, 10.0), rng.randf_range(10.0, RIDGE_WIDTH - 2.0)][t]
				var at := mid + side * sgn * off + d.normalized() * rng.randf_range(-1.5, 1.5)
				if not on_ridge(at) or _mountain_gap(at, k) < edge + 0.9:
					continue
				var sc := rng.randf_range(0.75, 1.35)
				batch.add_prop("town_tree", Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * sc), at))
				batch.add_solid(at + Vector3(0.0, 2.5, 0.0), Vector3(0.7 * sc, 5.0, 0.7 * sc))
		# A cliff edge: a broken wooden fence along it (some of it gone: that's where cars went over).
		for sgn: float in [-1.0, 1.0]:
			var lip := mid + side * sgn * (edge + 0.6)
			if not _in_cliff(k, mid + side * sgn * (edge + RIDGE_TILE)):
				continue
			if rng.randf() < 0.3:
				continue
			batch.add(lip + Vector3(0.0, 0.55, 0.0), Vector3(0.18, 1.1, 0.18), "town_wood", true, yaw)
			if rng.randf() < 0.7:
				batch.add(lip + Vector3(0.0, 0.85, 0.0), Vector3(0.08, 0.16, d.length()), "town_wood", true, yaw + rng.randf_range(-0.05, 0.05))
				batch.add(lip + Vector3(0.0, 0.45, 0.0), Vector3(0.08, 0.16, d.length()), "town_wood", false, yaw + rng.randf_range(-0.08, 0.08))
		if rng.randf() < 0.05:  # a stump on the verge
			var at := mid + side * (1.0 if rng.randf() < 0.5 else -1.0) * (edge + rng.randf_range(0.5, 3.0))
			if on_ridge(at):
				batch.add_prop("manor_stump", Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)), at))
	# The bends: rock cut on the inside, chevrons on the outside of the tight ones.
	for mc in mountain_corners:
		var s0: float = mc[0]
		var s1: float = mc[1]
		var grade: int = mc[3]
		var inside := -1.0 if int(mc[2]) == Call.LEFT else 1.0  # -1: the inside is to the left
		var s := s0 - 4.0
		while s < s1 + 4.0:
			var p := route_local(s)
			var tan := route_tangent(s)
			var right := Vector3(-tan.z, 0.0, tan.x)
			var yaw := atan2(-tan.x, -tan.z)
			var h := rng.randf_range(5.0, 13.0) if grade <= 3 else rng.randf_range(3.0, 7.0)
			var deep := rng.randf_range(3.0, 6.0)
			batch.add(p + right * inside * (edge + 1.6 + deep * 0.5) + Vector3(0.0, h * 0.5 - 0.3, 0.0), Vector3(deep, h, 6.8), "town_rock", true, yaw + rng.randf_range(-0.12, 0.12))
			s += 6.0
		if grade <= 3:
			for k in 3:  # chevrons, out where the headlights find them late
				var sc2 := s0 + (s1 - s0) * (0.2 + 0.3 * float(k))
				var p := route_local(sc2)
				var tan := route_tangent(sc2)
				var right := Vector3(-tan.z, 0.0, tan.x)
				var at := p - right * inside * (edge + 0.9)
				var face := (route_local(sc2 - 25.0) - at)
				var fy := atan2(face.x, face.z)
				batch.add(at + Vector3(0.0, 0.8, 0.0), Vector3(0.1, 1.6, 0.1), "steel_dark", false)
				batch.add(at + Vector3(0.0, 1.75, 0.0), Vector3(0.9, 0.6, 0.05), "town_chevron", false, fy)
				var l := Label3D.new()
				l.text = "<<<" if int(mc[2]) == Call.LEFT else ">>>"
				l.font_size = 72
				l.pixel_size = 0.008
				l.modulate = Color(0.02, 0.02, 0.02)
				l.outline_size = 0
				l.shaded = true
				l.double_sided = false
				l.position = at + Vector3(0.0, 1.75, 0.0) + Vector3(sin(fy), 0.0, cos(fy)) * 0.035
				l.rotation.y = fy
				root.add_child(l)
	_build_road_blocks(batch, rng)
	var sign := Label3D.new()
	sign.text = "YOU ARE NOW LEAVING\nKETTLE HOLLOW\nDRIVE SAFELY"
	sign.font_size = 64
	sign.pixel_size = 0.01
	sign.modulate = Color(0.85, 0.85, 0.8)
	sign.shaded = true
	var at0 := pts[mini(bridge_n + 4, n - 1)] + Vector3(half + 3.0, 2.4, 0.0)
	sign.position = at0
	root.add_child(sign)
	batch.add(at0 + Vector3(0.0, 0.0, -0.06), Vector3(3.6, 1.8, 0.08), "town_sign_green", false)
	batch.add(at0 + Vector3(0.0, -1.7, -0.1), Vector3(0.12, 1.8, 0.12), "steel_dark", false)


## Where the ground falls away: the outside of every tight bend (a 1 or a 2) from a little before it
## to well past it, and the outside of a third of the 3s. [k0, k1, side (+1 right of the way up)].
func _lay_out_cliffs() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + seed_value + 211
	cliffs = []
	for mc in mountain_corners:
		var grade: int = mc[3]
		if grade > 3 or (grade == 3 and rng.randf() > 0.35):
			continue
		var outside := 1.0 if int(mc[2]) == Call.LEFT else -1.0
		var k0 := int((float(mc[0]) - mountain_start_s - 12.0) / MTN_STEP)
		var k1 := int((float(mc[1]) - mountain_start_s + 30.0) / MTN_STEP)
		cliffs.append([maxi(k0, 0), mini(k1, mountain_pts.size() - 1), outside])


## Is local point c (near road point k) over a cliff zone's drop?
func _in_cliff(k: int, c: Vector3) -> bool:
	for z in cliffs:
		if k < int(z[0]) or k > int(z[1]):
			continue
		var r := _side_at(k)
		if signf((c - mountain_pts[k]).dot(r)) == float(z[2]):
			return true
	return false


## Is there ridge ground under a local point (the mountain's forest, not the drop)?
func on_ridge(p: Vector3) -> bool:
	return _ridge.has(Vector2i(floori(p.x / RIDGE_TILE), floori(p.z / RIDGE_TILE)))


## [index, flat distance] of the mountain road's point nearest a local point (a coarse grid of the
## points by MTN_CELL squares, built the first time).
func _nearest_mountain(p: Vector3) -> Array:
	if _mgrid.is_empty():
		for k in mountain_pts.size():
			var key := Vector2i(floori(mountain_pts[k].x / MTN_CELL), floori(mountain_pts[k].z / MTN_CELL))
			if not _mgrid.has(key):
				_mgrid[key] = PackedInt32Array()
			var list: PackedInt32Array = _mgrid[key]
			list.append(k)
			_mgrid[key] = list
	var cell := Vector2i(floori(p.x / MTN_CELL), floori(p.z / MTN_CELL))
	var best := -1
	var bd := INF
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			var key := cell + Vector2i(dx, dz)
			if not _mgrid.has(key):
				continue
			for k in (_mgrid[key] as PackedInt32Array):
				var q := mountain_pts[k]
				var d := Vector2(p.x - q.x, p.z - q.z).length()
				if d < bd:
					bd = d
					best = k
	return [best, bd]


## Across half the road just past a bend, where the headlights find it late: a fallen tree, a
## rockslide, an abandoned car. Solid: at speed it wrecks the car; the navigator's picture shows it.
func _build_road_blocks(batch: LevelKit.BoxBatch, rng: RandomNumberGenerator) -> void:
	road_blocks = PackedVector3Array()
	var half := MOUNTAIN_ROAD * 0.5
	var picks := 0
	for mc in mountain_corners:
		if picks >= ROAD_BLOCKS or rng.randf() > 0.55:
			continue
		var s := float(mc[1]) + rng.randf_range(18.0, 40.0)
		if s > finish_s - 40.0:
			continue
		picks += 1
		var p := route_local(s)
		var tan := route_tangent(s)
		var right := Vector3(-tan.z, 0.0, tan.x)
		var yaw := atan2(-tan.x, -tan.z)
		var sgn := -1.0 if rng.randf() < 0.5 else 1.0
		var at := p + right * sgn * (half * 0.5 + 0.2)
		road_blocks.append(origin + at)
		match rng.randi_range(0, 2):
			0:  # a dead tree come down across the lane, its roots on the verge
				var lie := Basis(Vector3.UP, yaw + PI * 0.5 + rng.randf_range(-0.25, 0.25)) * Basis(Vector3.FORWARD, PI * 0.5 * sgn)
				batch.add_prop("town_tree", Transform3D(lie, p + right * sgn * (half + 2.0) + Vector3(0.0, 0.6, 0.0)))
				batch.add_solid(at + Vector3(0.0, 0.6, 0.0), Vector3(half + 1.2, 1.2, 1.0), yaw + PI * 0.5)
			1:  # a rockslide off the cut
				for r in 4:
					var c := at + right * rng.randf_range(-1.2, 1.2) + tan * rng.randf_range(-2.0, 2.0)
					batch.add_prop("ruin_rubble", RuinMeshes.fit("ruin_rubble", c, Vector3(rng.randf_range(1.8, 3.0), rng.randf_range(0.9, 1.6), rng.randf_range(1.8, 3.0)), Basis(Vector3.UP, rng.randf_range(0.0, TAU))))
				batch.add_solid(at + Vector3(0.0, 0.7, 0.0), Vector3(half + 0.8, 1.4, 4.0), yaw)
			2:  # somebody else's car, left with its door open
				_wreck(batch, at, yaw + rng.randf_range(-0.3, 0.3), false)


## Flat distance from a local point to the mountain road's middle, looking near point k.
func _mountain_gap(p: Vector3, k: int) -> float:
	var best := INF
	for j in range(maxi(1, k - 40), mini(mountain_pts.size(), k + 40)):
		var a := mountain_pts[j - 1]
		var b := mountain_pts[j]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		var q := a + ab * t
		best = minf(best, Vector2(p.x - q.x, p.z - q.z).length())
	return best


## Strips laid along the mountain road, one surface per material: each spec is [from, to (m across,
## + to the right), y, material key, dash (m on, m off; 0 solid)].
func _ribbons(specs: Array) -> ArrayMesh:
	var am := ArrayMesh.new()
	var pts := mountain_pts
	for spec in specs:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var acc := 0.0
		for k in range(1, pts.size()):
			var a := pts[k - 1]
			var b := pts[k]
			acc += a.distance_to(b)
			var dash: float = spec[4]
			if dash > 0.0 and fmod(acc, dash * 2.0) > dash:
				continue
			var ra := _side_at(k - 1)
			var rb := _side_at(k)
			var y := Vector3(0.0, float(spec[2]), 0.0)
			var a0 := a + ra * float(spec[0]) + y
			var a1 := a + ra * float(spec[1]) + y
			var b0 := b + rb * float(spec[0]) + y
			var b1 := b + rb * float(spec[1]) + y
			for v in [a0, b0, b1, a0, b1, a1, a0, b1, b0, a0, a1, b1]:  # both windings: seen from above either way
				st.set_normal(Vector3.UP)
				st.add_vertex(v)
		st.set_material(LevelKit.mat(String(spec[3])))
		st.commit(am)
	return am


func _side_at(k: int) -> Vector3:
	var pts := mountain_pts
	var a := pts[maxi(k - 1, 0)]
	var b := pts[mini(k + 1, pts.size() - 1)]
	var d := b - a
	return Vector3(-d.z, 0.0, d.x).normalized()


func _build_lights() -> void:
	for i in GRID:
		for j in GRID:
			if _rng.randf() >= LAMP_CHANCE:
				continue
			var c := corner(Vector2i(i, j)) + Vector3(ROAD * 0.5 + 0.6, 0.0, ROAD * 0.5 + 0.6)
			var pole := MeshInstance3D.new()
			var pm := BoxMesh.new()
			pm.size = Vector3(0.18, 6.5, 0.18)
			pole.mesh = pm
			pole.material_override = LevelKit.mat("steel_dark")
			pole.position = c + Vector3(0.0, 3.25, 0.0)
			root.add_child(pole)
			var arm := MeshInstance3D.new()
			var am := BoxMesh.new()
			am.size = Vector3(1.3, 0.1, 0.1)
			arm.mesh = am
			arm.material_override = LevelKit.mat("steel_dark")
			arm.position = c + Vector3(-0.55, 6.45, -0.55)
			arm.rotation.y = PI * 0.25
			root.add_child(arm)
			var head := MeshInstance3D.new()
			var hm := BoxMesh.new()
			hm.size = Vector3(0.6, 0.16, 0.36)
			head.mesh = hm
			head.material_override = LevelKit.mat("street_lamp")
			head.position = c + Vector3(-0.8, 6.5, -0.8)
			root.add_child(head)
			var light := OmniLight3D.new()
			light.light_color = Color(1.0, 0.62, 0.3)
			light.light_energy = 1.6
			light.omni_range = 15.0
			light.position = c + Vector3(-0.8, 6.2, -0.8)
			light.distance_fade_enabled = true
			light.distance_fade_begin = 90.0
			light.distance_fade_length = 20.0
			light.light_volumetric_fog_energy = 1.6
			root.add_child(light)
			if _drng.randf() < 0.3:
				_flicker.append(light)
	_moon = DirectionalLight3D.new()
	_moon.light_color = Color(0.55, 0.62, 0.85)
	_moon.light_energy = 0.14
	_moon.rotation = Vector3(-0.9, 0.5, 0.0)
	_moon.shadow_enabled = false
	add_child(_moon)
	_wind = AudioStreamPlayer.new()
	_wind.stream = Sfx.stream("wind")
	_wind.volume_db = -14.0
	add_child(_wind)


## Every peer: drawn, lit and heard only while the camera is down here.
func set_shown(on: bool) -> void:
	_shown = on
	root.visible = on
	if _moon != null:
		_moon.visible = on
	if _wind != null:
		if on:
			Sfx.start_loop(_wind)
		else:
			_wind.stop()


func has_ceiling_at(_p: Vector3) -> bool:
	return false


func is_safe_spot(_p: Vector3) -> bool:
	return false


func ceiling_y(p: Vector3) -> float:
	return p.y + 100.0


# --- Server: the chase --------------------------------------------------------------------------

## The Line has crashed here: into the cars, the countdown, the Strider over the wall behind.
func server_arrive() -> void:
	if not multiplayer.is_server():
		return
	GameState.set_tasks(PackedStringArray(TASKS))
	_reset()
	GameState.post_message("KETTLE HOLLOW. The rally cars still have their keys in. TWO TO A CAR: the driver drives blind, the navigator reads the map and calls the turns.", 6.0)


## A layoff (or a regroup) brings everyone back to the start line, in the cars.
func server_on_respawn() -> void:
	if multiplayer.is_server() and active:
		_reset()


## The Line has gone on (out of town, or a Continue past it): nobody is in the cars any more.
func server_depart() -> void:
	if not multiplayer.is_server():
		return
	active = false
	countdown = -1.0
	strider.active = false
	strider.lunge = -1.0
	for b in Net.get_chain_bodies():
		b.seat = null
	for k in cars.size():
		cars[k].in_use = false
		cars[k].driver = null
		cars[k].occupants = PackedInt32Array()
		cars[k].autopilot = []
		cars[k].server_park(_start_xform(k))


func _reset() -> void:
	active = true
	countdown = COUNTDOWN
	_run_t = 0.0
	_surge_at = SURGE_FIRST
	_surge_left = 0.0
	_fell = false
	_lunge_car = -1
	_out_t = -1.0
	_auto_called.clear()
	strider.s = STRIDER_START
	strider.active = false
	strider.lunge = -1.0
	for k in cars.size():
		cars[k].server_park(_start_xform(k))
		cars[k].progress = CAR_FIRST - float(k) * CAR_GAP
		cars[k].finished = false
	_seat_everyone()
	threats.server_reset()


func _seat_everyone() -> void:
	var bodies := Net.get_chain_bodies()
	var n := bodies.size()
	var used := clampi(n / 2, 1, CARS)
	for k in cars.size():
		cars[k].in_use = k < used
		cars[k].driver = null
		cars[k].occupants = PackedInt32Array()
	for i in n:
		var k := mini(i / 2, used - 1)
		_seat(bodies[i], cars[k])


func _seat(b: ChainBody, car: RallyCar) -> void:
	var at := mini(car.occupants.size(), car.seats.size() - 1)
	b.seat = car.seats[at]
	b.teleport_to(car.seats[at].global_position, car.global_rotation.y)
	var occ := car.occupants
	occ.append((b as Player).peer_id if b is Player else -1)
	car.occupants = occ
	car.in_use = true
	if at == 0 and b is Player:
		car.driver = b as Player
	if b is Player:
		(b as Player).set_unchained(false)


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or not active:
		return
	# Anyone who joined mid-chase gets a seat: a free one in a car on the road, or a car of their own.
	for b in Net.get_chain_bodies():
		if b.seat == null:
			var home: RallyCar = null
			for c in cars:
				if c.in_use and c.occupants.size() < c.seats.size():
					home = c
					break
			if home == null:
				for c in cars:
					if not c.in_use:
						home = c
						break
			if home != null:
				_seat(b, home)
	var running := countdown < 0.0
	if not running:
		countdown -= delta
		for c in cars:
			c.locked = true
		if countdown <= 0.0:
			countdown = -1.0
			for c in cars:
				c.locked = false
			GameState.complete_task(0)
			_rpc_call.rpc(-1, Call.GO, 0)
		return
	_run_t += delta
	_tick_rough()
	_tick_fallen()
	_tick_progress()
	_tick_calls()
	threats.server_tick(delta)
	_tick_strider(delta)
	_tick_finish(delta)


## Each car's way along the route: it only moves on while the car is on the route's streets, so a
## wrong turn holds it back while the Strider keeps coming.
## A car that has gone off the edge: it's at the bottom of the valley, and the run starts over.
func _tick_fallen() -> void:
	if _fell:
		return
	for c in cars:
		if c.in_use and c.global_position.y < origin.y - FALL_LAYOFF:
			_fell = true
			falls += 1
			c.locked = true
			GameState.post_message("CAR %d WENT OVER THE EDGE" % (c.index + 7), 2.5)
			if layoff.is_valid():
				layoff.call("Car %d went off the mountain. Everyone back to the start line." % (c.index + 7))
			return


## On the mountain, a car off the asphalt and its shoulders is in the dirt (RallyCar.rough).
func _tick_rough() -> void:
	for c in cars:
		if not c.in_use:
			continue
		var off := false
		if c.progress > mountain_start_s + BRIDGE_LEN:
			var s := project(c.global_position, c.progress - 25.0, c.progress + 40.0)
			off = s == -INF or not on_mountain_road(c.global_position - origin, s)
		c.rough = off


func _tick_progress() -> void:
	for c in cars:
		if not c.in_use:
			continue
		var s := project(c.global_position, c.progress - 25.0, c.progress + 70.0)
		if s > c.progress:
			c.progress = s
		if not c.finished and c.progress >= finish_s:
			c.finished = true
			_rpc_finished.rpc(c.index)


func _tick_strider(delta: float) -> void:
	var slowest := INF
	var hunted := 0
	for c in cars:
		if c.in_use and not c.finished and c.progress < slowest:
			slowest = c.progress
			hunted = c.driver.peer_id if c.driver != null and is_instance_valid(c.driver) else 0
	strider.hunt_peer = hunted
	if strider.lunge >= 0.0:
		strider.lunge = minf(1.0, strider.lunge + delta / Strider.LUNGE_TIME)
		if strider.lunge >= 1.0 and _lunge_car >= 0:
			var caught := _lunge_car
			_lunge_car = -1
			if layoff.is_valid():
				layoff.call("The Strider caught car %d. Everyone back to the start line." % (caught + 7))
		return
	if _run_t < STRIDER_DELAY or slowest == INF or debug_hold_strider:
		return
	strider.active = true
	var speed := minf(STRIDER_SPEED + STRIDER_RAMP * (_run_t - STRIDER_DELAY), STRIDER_TOP)
	var gap := slowest - strider.s
	if gap > RUBBER_GAP:
		speed += (gap - RUBBER_GAP) * RUBBER_K
	# Now and then it sprints at the cars: the navigators have to shoot it back.
	if _surge_left > 0.0:
		_surge_left -= delta
		speed += SURGE_BOOST
	elif _run_t >= _surge_at:
		_surge_left = SURGE_SECONDS
		_surge_at = _run_t + SURGE_SECONDS + randf_range(SURGE_EVERY_MIN, SURGE_EVERY_MAX)
		GameState.post_message("IT'S SPRINTING AT YOU. NAVIGATOR: SHOOT IT (F)", 3.0)
		strider.server_roar()
	if threats.strider_slow > 0.0:
		speed *= 0.3
	strider.s = minf(strider.s + speed * delta, finish_s - 10.0)
	var head := strider.global_position
	for c in cars:
		if not c.in_use or c.finished:
			continue
		var close := Vector2(c.global_position.x - head.x, c.global_position.z - head.z).length() < Strider.CATCH_REACH
		if strider.s >= c.progress - CATCH_GAP or close:
			_lunge_car = c.index
			strider.lunge_to = c.global_position
			strider.lunge = 0.0
			c.locked = true
			GameState.post_message("IT'S GOT CAR %d" % (c.index + 7), 2.0)
			break


## The Strider is sprinting at the cars (the navigators' guns go for it first).
func surging() -> bool:
	return _surge_left > 0.0


## A navigator's round hit it: it's thrown back down the street, and if it was reaching into a car
## it lets go.
func server_strider_shot() -> void:
	strider.s -= RoadThreats.STRIDER_KNOCK
	if strider.lunge >= 0.0 and strider.lunge < 0.6 and _lunge_car >= 0:
		cars[_lunge_car].locked = false
		GameState.post_message("SHOT IT OFF CAR %d. GO." % (_lunge_car + 7), 2.0)
		_lunge_car = -1
		strider.lunge = -1.0
		strider.s -= RoadThreats.STRIDER_KNOCK


func _tick_finish(delta: float) -> void:
	var all_out := true
	for c in cars:
		if c.in_use and not c.finished:
			all_out = false
	if not all_out:
		return
	if _out_t < 0.0:
		_out_t = OUT_SECONDS
		strider.active = false
		GameState.complete_task(1)
		GameState.complete_task(2)
		GameState.post_message("OVER THE BRIDGE. It stops at the town's edge and screams after you.", 4.0)
		return
	_out_t -= delta
	if _out_t <= 0.0:
		_out_t = INF
		if escaped.is_valid():
			escaped.call()


## The navigator's calls: their movement keys, read off the input packets they already send (the
## driver can't see the map, so this is how the turns get to them besides talking).
func _tick_calls() -> void:
	for c in cars:
		if not c.in_use:
			continue
		var human_nav := false
		for at in range(1, c.occupants.size()):
			var p := Net.find_player(c.occupants[at])
			if p == null:
				continue
			human_nav = true
			var raw := Vector3(p.input_move.x, 0.0, p.input_move.y).rotated(Vector3.UP, -p.input_yaw)
			var kind := Call.NONE
			if raw.x < -0.6:
				kind = Call.LEFT
			elif raw.x > 0.6:
				kind = Call.RIGHT
			elif -raw.z > 0.6:
				kind = Call.STRAIGHT
			elif -raw.z < -0.6:
				kind = Call.BRAKE
			var id := p.get_instance_id()
			var was := int(_last_call.get(id, Call.NONE))
			_last_call[id] = kind
			if kind != Call.NONE and kind != was and Time.get_ticks_msec() > int(_call_cool.get(id, 0)):
				_call_cool[id] = Time.get_ticks_msec() + 300
				var grade := 0
				var nt := next_turn(c.progress, 160.0)
				if (kind == Call.LEFT or kind == Call.RIGHT) and not nt.is_empty() and int(nt[1]) == kind:
					grade = int(nt[2])  # the map shows the bend's note: it goes out with the call
				_rpc_call.rpc(c.index, kind, grade)
		if not human_nav:
			_auto_call(c)


## No navigator who can read (the Ballast in solo): the turns are called for the driver anyway.
func _auto_call(c: RallyCar) -> void:
	var reach := maxf(CALL_RANGE, absf(c.speed) * 3.4)  # at speed on the mountain the calls come early
	for t in turns:
		var s: float = t[0]
		if s <= c.progress + 2.0:
			continue
		if s - c.progress < reach and float(_auto_called.get(c.index, -1.0)) != s:
			_auto_called[c.index] = s
			_rpc_call.rpc(c.index, int(t[1]), int(t[2]))
		return


@rpc("authority", "call_local", "reliable")
func _rpc_call(car: int, kind: int, grade: int = 0) -> void:
	var me := multiplayer.get_unique_id()
	var mine := car < 0
	if car >= 0 and car < cars.size():
		mine = cars[car].occupants.has(me)
	if not mine:
		return
	calls_seen += 1
	if _panel != null:
		_panel.show_call(kind, grade)
	Sfx.play(self, "ding" if kind != Call.GO else "stinger", -4.0, 1.4 if kind == Call.LEFT else (1.7 if kind == Call.RIGHT else 1.2))


@rpc("authority", "call_local", "reliable")
func _rpc_finished(car: int) -> void:
	if car >= 0 and car < cars.size() and cars[car].occupants.has(multiplayer.get_unique_id()):
		Sfx.play(self, "ding", -2.0, 0.9)


# --- Every peer ----------------------------------------------------------------------------------

func _process(delta: float) -> void:
	# The chain runs two to a car while the Line is in the cars, and back in a line after.
	if active != _pairs_on:
		_pairs_on = active
		GameState.chain_config = GameState.ChainConfig.PAIRS if active else GameState.ChainConfig.LINE
	if Net.ballast != null and is_instance_valid(Net.ballast) and Net.ballast._mesh_root != null:
		Net.ballast._mesh_root.visible = not active
	if not _shown:
		_release_camera()
		return
	for f in _fires:
		f.light_energy = f.light_energy * 0.8 + randf_range(1.4, 3.2) * 0.2
	var tf := float(Time.get_ticks_msec()) * 0.001
	for i in _flicker.size():
		# A dying sodium lamp: mostly on, a stutter now and then, out for a second or two.
		var v := sin(tf * 1.7 + float(i) * 5.1) + sin(tf * 23.0 + float(i) * 2.7) * 0.35

		_flicker[i].light_energy = 0.08 if v > 1.05 else 1.6
	var car := local_car()
	if car == null or not active:
		_release_camera()
		return
	if _cam == null:
		_cam = Camera3D.new()
		_cam.name = "ChaseCam"
		_cam.fov = 70.0
		_cam.far = 400.0
		add_child(_cam)
		_cam.global_transform = _cam_target(car)
	if not debug_cam_free:
		_cam.current = true
	var want := _cam_target(car)
	var k := clampf(delta * 6.0, 0.0, 1.0)
	_cam.global_position = _cam.global_position.lerp(want.origin, k)
	_cam.global_basis = _cam.global_basis.slerp(want.basis, clampf(delta * 8.0, 0.0, 1.0)).orthonormalized()
	if _panel == null:
		var hud := get_tree().get_first_node_in_group("hud")
		if hud != null:
			_panel = RallyPanel.new()
			_panel.town = self
			hud.add_child(_panel)


func _cam_target(car: RallyCar) -> Transform3D:
	var fwd := -car.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var eye := car.global_position - fwd * 7.5 + Vector3.UP * 3.3
	var look := car.global_position + fwd * 6.0 + Vector3.UP * 1.0
	return Transform3D(Basis.looking_at(look - eye, Vector3.UP), eye)


func _release_camera() -> void:
	if _cam == null:
		return
	var was_current := _cam.current
	_cam.queue_free()
	_cam = null
	var me := Net.get_local_player()
	if was_current and me != null:
		me._apply_camera_mode()


## The car the local player sits in, or null.
func local_car() -> RallyCar:
	if not is_inside_tree() or multiplayer == null or multiplayer.multiplayer_peer == null:
		return null  # leaving
	var me := multiplayer.get_unique_id()
	for c in cars:
		if c.in_use and c.occupants.has(me):
			return c
	return null


## 0 driver, 1 navigator, 2 back seat; -1 not in a car.
func local_seat() -> int:
	var c := local_car()
	return c.occupants.find(multiplayer.get_unique_id()) if c != null else -1  # local_car checked the peer
