class_name Pizzeria
extends Node3D
## Level 2: Pappy Pepperoni's Night Shift. A family pizzeria stacked on the Yellow Rooms: three
## floors (Dining Hall, Kitchen, Stage) laid out from fixed plans and dressed from a fixed seed,
## so every peer builds the identical restaurant before connecting.
## The freight car from B1 rides up into Receiving (Break Room 2.1). Then: the Host Stand's
## camera desk, the EMPLOYEES ONLY shutter, the dumbwaiter up to the Kitchen (Break Room 2.2 Dry
## Storage), the Manager's Office desk, a second shutter, the stage lift up to the wings (Break
## Room 2.3 Coat Check), and across the stage to the prop loft and ROOF ACCESS: the end of this
## build. Pappy Pepperoni walks the floor the Line is on. Server only: populates loot, runs the
## power bank, the night clock, the generator, the jukebox and the exit.

const CELL: float = 6.0
const COLS: int = 6
const ROWS: int = 5
const FLOORS: int = 3
const FLOOR_H: float = 5.0
const SLAB: float = 0.4
const WALL_T: float = 0.2
const DOOR_W: float = 1.5
const DOOR_H: float = 2.3
const STAGE_H: float = 0.7
const LOFT_H: float = 2.0  # above the stage floor: one case (1 m) and one mantle up
const SEED: int = 2207
const DUMB_HOLE: float = 1.7
const DUMB_OFF: Vector3 = Vector3(-1.6, 0.0, -1.6)  # the dumbwaiter shaft sits in its cell's corner
const LIFT_HOLE: float = 3.0
const POWER_MAX: float = 100.0
const GENERATOR_SECONDS: float = 3.0  # standing in a Break Room this long restarts the generator
const EXIT_DELAY: float = 2.5
const CEIL_HS: Array[float] = [3.9, 3.2, 4.6]
const FLOOR_NAMES: Array[String] = ["DINING HALL", "KITCHEN", "STAGE"]
const ROOM_NAMES: Dictionary = {
	"R": "RECEIVING", "H": "HOST STAND", "D": "DINING HALL", "C": "COUNTER", "A": "ARCADE", "W": "RESTROOMS",
	"P": "PARTY ROOM", "L": "EMPLOYEES ONLY", "U": "DUMBWAITER", "S": "STORAGE",
	"B": "DRY STORAGE", "K": "KITCHEN", "F": "WALK-IN FREEZER", "M": "MANAGER'S OFFICE", "T": "STAGE LIFT",
	"N": "BACK HALL", "Y": "PANTRY",
	"X": "DRESSING ROOM", "O": "SOUND BOOTH", "G": "STAGE RIGHT", "E": "COAT CHECK", "V": "FLOOR", "Q": "STAGE LEFT",
}
## Plans: rows are z = 0..4, characters are x = 0..5. '.' is solid.
const PLANS: Array = [
	["ULDDCC", "SLDDCC", "HDDDDA", "HDDDDA", "R.WWPP"],
	["UBKKKF", "UKKKKM", "LLKKKY", "TNNNNN", "......"],
	["XSSSSO", "XSSSSG", "EVVVVG", "QVVVPP", "......"],
]
enum Conn { NONE, DOOR, OPEN, SHUTTER, COUNTER, ARCH }
## Openings between rooms: [x, z, x2, z2, kind]. Cells of the same room are open to each other.
const EDGES: Array = [
	[[0, 4, 0, 3, Conn.DOOR], [0, 2, 1, 2, Conn.ARCH], [0, 3, 1, 3, Conn.ARCH], [1, 2, 1, 1, Conn.DOOR],
		[1, 0, 0, 0, Conn.SHUTTER], [0, 0, 0, 1, Conn.DOOR], [3, 0, 4, 0, Conn.COUNTER], [3, 1, 4, 1, Conn.COUNTER],
		[4, 2, 5, 2, Conn.ARCH], [4, 3, 5, 3, Conn.ARCH], [2, 3, 2, 4, Conn.DOOR], [4, 3, 4, 4, Conn.DOOR]],
	[[0, 0, 1, 0, Conn.DOOR], [1, 0, 1, 1, Conn.DOOR], [0, 1, 1, 1, Conn.ARCH], [4, 0, 5, 0, Conn.DOOR],
		[4, 1, 5, 1, Conn.DOOR], [1, 1, 1, 2, Conn.DOOR], [0, 2, 0, 3, Conn.SHUTTER], [3, 2, 3, 3, Conn.DOOR],
		[4, 2, 5, 2, Conn.DOOR], [5, 2, 5, 3, Conn.DOOR]],
	[[0, 3, 0, 2, Conn.DOOR], [0, 2, 1, 2, Conn.DOOR], [1, 0, 0, 0, Conn.DOOR], [5, 0, 5, 1, Conn.DOOR],
		[4, 2, 5, 2, Conn.DOOR], [4, 1, 5, 1, Conn.DOOR], [3, 3, 4, 3, Conn.DOOR],
		[1, 1, 1, 2, Conn.OPEN], [2, 1, 2, 2, Conn.OPEN], [3, 1, 3, 2, Conn.OPEN], [4, 1, 4, 2, Conn.OPEN]],
]
## Pappy's nodes per floor: [name, x, z, cam]; cam -1 = no camera there. Then links, and home.
const NODES: Array = [
	[["COUNTER", 4.5, 0.5, 1], ["DINING HALL", 2.5, 1.5, 0], ["ARCADE", 5.0, 2.5, 2], ["HOST STAND", 0.0, 2.5, 3],
		["PARTY ROOM", 4.5, 4.0, 4], ["EMPLOYEES ONLY", 1.0, 0.5, -1], ["DUMBWAITER", 0.0, 0.0, -1]],
	[["PANTRY", 5.0, 2.0, 3], ["BACK HALL", 3.0, 3.0, 2], ["KITCHEN", 3.0, 1.0, 0], ["DISH PIT", 0.0, 1.0, 1],
		["EMPLOYEES ONLY", 0.5, 2.0, -1], ["STAGE LIFT", 0.0, 3.0, -1]],
	[["STAGE RIGHT", 5.0, 1.5, -1], ["STAGE", 2.5, 0.5, 0], ["FLOOR", 2.5, 2.5, 1], ["PARTY ROOM", 4.5, 3.0, 2],
		["DRESSING ROOM", 0.0, 0.5, -1]],
]
const LINKS: Array = [
	[[0, 1], [1, 2], [1, 3], [1, 4], [1, 5], [5, 6]],
	[[0, 1], [0, 2], [1, 2], [2, 3], [2, 4], [4, 5]],
	[[0, 1], [0, 2], [1, 2], [2, 3], [1, 4]],
]
const HOME: Array[int] = [0, 0, 0]
const CAM_NAMES: Array = [
	["DINING", "COUNTER", "ARCADE", "LOBBY", "PARTY ROOM"],
	["KITCHEN", "DISH PIT", "BACK HALL", "PANTRY"],
	["STAGE", "FLOOR", "PARTY ROOM"],
]
const SAFE_ROOMS: Array[String] = ["R", "B", "E", "F"]  # Break Rooms and the freezer: he won't go in
const OBJECTIVES: Array[String] = [
	"DINING HALL: the dumbwaiter is past the EMPLOYEES ONLY shutter. One of you on the cameras, one holding the shutter, one rider at a time.",
	"KITCHEN: the stage lift is in the back. Hold the lever to run it; three ride; the last one gets hoisted up on the chain.",
	"STAGE: cross the stage and climb the cases to the prop loft. ROOF ACCESS. Keep your eyes on him.",
]
const FLOOR_LOOT: Array = [
	["popper", "flashlight", "airhorn", "decoy"],
	["airhorn", "popper", "drink", "bomb"],
	["popper", "popper", "flashlight", "airhorn"],
]
## Procedural scares that fit a pizzeria: [kind, weight].
const SCARE_POOL: Array = [
	["jukebox_skip", 2], ["balloon", 2], ["vent_patter", 2], ["pepperoni_eyes", 2], ["bell", 1],
	["static_face", 1], ["whisper", 1], ["figure", 1],
]
const POSTERS: Array[String] = [
	"PAPPY SAYS:\nWASH YOUR HANDS", "EMPLOYEE OF THE MONTH\nPAPPY (AGAIN)", "NO RUNNING\nIN THE DINING HALL",
	"BIRTHDAYS ARE\nFOREVER", "PLEASE DO NOT\nFEED THE BAND", "HE IS WATCHING\nYOU WATCH",
	"NIGHT SHIFT\nCLOCKS OUT AT 6", "THE CAMERAS\nARE FOR YOUR SAFETY",
]

var arrive_center: Vector3 = Vector3.ZERO  # set by LevelStack before _ready: floor-level car center
var checkpoint_base: int = 4
var test_points: Dictionary = {}
var desks: Array[SecurityDesk] = []
var shutters: Array[Shutter] = []
var pappy: PappyPepperoni
var dumbwaiter: Dumbwaiter
var stage_lift: StageLift
## Replicated.
var power: float = POWER_MAX
var jukebox_on: bool = true
var night_seconds: float = 0.0
var generator_t: float = 0.0  # replicated: 0..1 while someone restarts it (HUD)
var _origin: Vector3 = Vector3.ZERO
var _lights: LightController
var _graph: Array = []  # per floor: {nodes: [{name, pos, cam, links}], home}
var _shutter_edges: Array = []  # per floor: {"a-b": Shutter}
var _cams: Array = []  # per floor: [{name, pos, look}]
var _speakers: Array[AudioStreamPlayer3D] = []
var _jukebox_mute_until: int = 0
var _ambience: bool = false
var _exit_area: Area3D
var _exit_t: float = -1.0
var _bell_pos: Vector3 = Vector3.ZERO
var _curtains: Array[Node3D] = []
var _band_lights: Array[OmniLight3D] = []
var _suit_head: Node3D
var _pass_shutter: Node3D
var _office_door_pos: Vector3 = Vector3.ZERO
var _first_desk_seen: bool = false
var _gen_player_t: Dictionary = {}
var _pending_exit_signs: Array = []
var _pending_shutters: Array = []


func _enter_tree() -> void:
	if has_node("Sync"):
		return
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	for prop in ["power", "night_seconds", "generator_t", "jukebox_on"]:
		var path := NodePath(".:" + prop)
		cfg.add_property(path)
		cfg.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	sync.replication_config = cfg
	add_child(sync)


func _ready() -> void:
	_origin = arrive_center - Vector3(0.0 * CELL + CELL * 0.5, 0.0, 4.0 * CELL + CELL * 0.5)
	_lights = LightController.new()
	_lights.name = "Lights"
	add_child(_lights)
	_build_graph()
	for f in FLOORS:
		_build_floor(f)
	pappy = PappyPepperoni.new()
	pappy.name = "Pappy"
	pappy.level = self
	add_child(pappy)
	test_points["p_arrive"] = arrive_center + Vector3(0.0, 0.1, -2.3)


# --- Geometry helpers --------------------------------------------------------------------------

func base_y() -> float:
	return _origin.y


func floor_of(y: float) -> int:
	return clampi(int(floorf((y - _origin.y + 0.6) / FLOOR_H)), 0, FLOORS - 1)


func cell_center(f: int, x: int, z: int) -> Vector3:
	return _origin + Vector3(float(x) * CELL + CELL * 0.5, float(f) * FLOOR_H, float(z) * CELL + CELL * 0.5)


func cell_of(p: Vector3) -> Vector2i:
	var l := p - _origin
	return Vector2i(int(floorf(l.x / CELL)), int(floorf(l.z / CELL)))


func room_at(f: int, c: Vector2i) -> String:
	if c.x < 0 or c.y < 0 or c.x >= COLS or c.y >= ROWS:
		return "."
	return PLANS[f][c.y][c.x]


func ceiling_y(p: Vector3) -> float:
	return _origin.y + float(floor_of(p.y)) * FLOOR_H + CEIL_HS[floor_of(p.y)]


## False under the shafts (the dumbwaiter, the lift, the freight car) and over the stage loft.
func has_ceiling_at(p: Vector3) -> bool:
	var f := floor_of(p.y)
	var c := cell_of(p)
	if f == 0 and c == Vector2i(0, 0):
		return false
	if f == 1 and c == Vector2i(0, 3):
		return false
	return true


func is_safe_spot(p: Vector3) -> bool:
	return SAFE_ROOMS.has(room_at(floor_of(p.y), cell_of(p)))


func blackout() -> bool:
	return power <= 0.0


## True once anyone on the Line has reached the pizzeria (the car counts on its way up).
func anyone_here() -> bool:
	for p in Net.get_players():
		if p.global_position.y > _origin.y - 1.0:
			return true
	return false


## The floor most of the Line is on (lower on a tie: the stragglers).
func line_floor() -> int:
	var counts := [0, 0, 0]
	for p in Net.get_players():
		counts[floor_of(p.global_position.y)] += 1
	var best := 0
	for f in FLOORS:
		if counts[f] > counts[best]:
			best = f
	return best


## Badge clock: 12:00 AM at arrival, six real minutes per hour.
func clock_text() -> String:
	var hours := night_seconds / 360.0
	var h := int(hours) % 12
	var m := int(fmod(hours, 1.0) * 60.0)
	return "%d:%02d AM" % [12 if h == 0 else h, m]


# --- Pappy's graph ------------------------------------------------------------------------------

func _build_graph() -> void:
	for f in FLOORS:
		var nodes: Array = []
		for n in NODES[f]:
			var x := float(n[1])
			var z := float(n[2])
			var pos := _origin + Vector3(x * CELL + CELL * 0.5, float(f) * FLOOR_H, z * CELL + CELL * 0.5)
			if f == 2 and String(n[0]) == "STAGE":
				pos.y += STAGE_H
			nodes.append({"name": String(n[0]), "pos": pos, "cam": int(n[3]), "links": []})
		for l in LINKS[f]:
			nodes[int(l[0])]["links"].append(int(l[1]))
			nodes[int(l[1])]["links"].append(int(l[0]))
		_graph.append({"nodes": nodes, "home": HOME[f]})
		_shutter_edges.append({})
		_cams.append([])


func home_node(f: int) -> int:
	return int(_graph[f]["home"])


func node_name(f: int, i: int) -> String:
	return String(_graph[f]["nodes"][i]["name"])


func node_position(f: int, i: int) -> Vector3:
	return _graph[f]["nodes"][i]["pos"]


func node_cam(f: int, i: int) -> int:
	return int(_graph[f]["nodes"][i]["cam"])


func node_count(f: int) -> int:
	return _graph[f]["nodes"].size()


func nearest_node(f: int, p: Vector3) -> int:
	var best := 0
	var best_d := INF
	for i in node_count(f):
		var d := Vector2(p.x - node_position(f, i).x, p.z - node_position(f, i).z).length()
		if d < best_d:
			best_d = d
			best = i
	return best


func node_adjacent_to(f: int, a: int, b: int) -> bool:
	return (_graph[f]["nodes"][a]["links"] as Array).has(b)


## First node on the shortest path from a to goal, or -1.
func next_node(f: int, from: int, goal: int) -> int:
	if from == goal:
		return from
	var prev: Dictionary = {from: from}
	var queue: Array[int] = [from]
	while not queue.is_empty():
		var cur: int = queue.pop_front()
		if cur == goal:
			break
		for n in _graph[f]["nodes"][cur]["links"]:
			if not prev.has(n):
				prev[n] = cur
				queue.append(n)
	if not prev.has(goal):
		return -1
	var c := goal
	while prev[c] != from:
		c = prev[c]
	return c


func shutter_between(f: int, a: int, b: int) -> Shutter:
	return _shutter_edges[f].get("%d-%d" % [mini(a, b), maxi(a, b)]) as Shutter


# --- Building -------------------------------------------------------------------------------------

func _build_floor(f: int) -> void:
	var root := Node3D.new()
	root.name = "Floor%d" % f
	add_child(root)
	var batch := LevelKit.BoxBatch.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + f * 131
	var base := _origin.y + float(f) * FLOOR_H
	var ceil_h: float = CEIL_HS[f]
	var floor_key := "ktile" if f == 1 else "checker"
	for z in ROWS:
		for x in COLS:
			var r := room_at(f, Vector2i(x, z))
			if r == ".":
				continue
			var center := cell_center(f, x, z)
			var fkey := floor_key
			if f == 2 and r == "S":
				fkey = "stage_wood"
			elif f == 0 and r == "R":
				fkey = "concrete"
			elif f == 2 and (r == "Q" or r == "G" or r == "X"):
				fkey = "stage_wood"
			# Floor slab (holed where a shaft arrives), ceiling (holed where one leaves).
			if f == 0 and r == "R":
				_holed_slab(batch, center + Vector3(0.0, -SLAB * 0.5, 0.0), SLAB, fkey, YellowRooms.CAR_HOLE)
				_hazard_ring(batch, center + Vector3(0.0, 0.006, 0.0), YellowRooms.CAR_HOLE)
			elif f == 1 and r == "U" and z == 0:
				_holed_slab(batch, center + Vector3(0.0, -SLAB * 0.5, 0.0), SLAB, fkey, DUMB_HOLE, center + DUMB_OFF)
			elif f == 2 and r == "Q":
				_holed_slab(batch, center + Vector3(0.0, -SLAB * 0.5, 0.0), SLAB, fkey, LIFT_HOLE)
				_hazard_ring(batch, center + Vector3(0.0, 0.006, 0.0), LIFT_HOLE)
			else:
				batch.add(center + Vector3(0.0, -SLAB * 0.5, 0.0), Vector3(CELL, SLAB, CELL), fkey)
			var ceil_key := "ceiling" if not (f == 2 and (r == "S" or r == "Q" or r == "G" or r == "X")) else "dark"
			if f == 0 and r == "U":
				_holed_slab(batch, center + Vector3(0.0, ceil_h + 0.025, 0.0), 0.05, ceil_key, DUMB_HOLE, center + DUMB_OFF)
				_shaft_lining(batch, center + DUMB_OFF, base + ceil_h, FLOOR_H - ceil_h, DUMB_HOLE)
			elif f == 1 and r == "T":
				_holed_slab(batch, center + Vector3(0.0, ceil_h + 0.025, 0.0), 0.05, ceil_key, LIFT_HOLE)
				_shaft_lining(batch, center, base + ceil_h, FLOOR_H - ceil_h, LIFT_HOLE)
			else:
				batch.add(center + Vector3(0.0, ceil_h + 0.025, 0.0), Vector3(CELL, 0.05, CELL), ceil_key)
	_build_walls(batch, f)
	if f == 2:
		_build_stage(root, batch, rng)
	for z in ROWS:
		for x in COLS:
			var r := room_at(f, Vector2i(x, z))
			if r == ".":
				continue
			_dress_cell(root, batch, f, x, z, r, rng)
	_build_room_lights(root, batch, f, rng)
	_build_signs(root, batch, f)
	batch.build(root, "P%d" % f)
	_build_exit_signs(root)
	_build_cameras(root, f)
	_build_scare_triggers(root, f)
	_build_checkpoint(root, f)


## A cell slab with a square hole anywhere inside it (up to 4 strips). hole_c defaults to the center.
func _holed_slab(batch: LevelKit.BoxBatch, center: Vector3, thickness: float, key: String, hole: float, hole_c: Vector3 = Vector3.INF) -> void:
	if hole_c == Vector3.INF:
		hole_c = center
	var x0 := center.x - CELL * 0.5
	var x1 := center.x + CELL * 0.5
	var z0 := center.z - CELL * 0.5
	var z1 := center.z + CELL * 0.5
	var hx0 := hole_c.x - hole * 0.5
	var hx1 := hole_c.x + hole * 0.5
	var hz0 := hole_c.z - hole * 0.5
	var hz1 := hole_c.z + hole * 0.5
	if hx0 > x0 + 0.01:
		batch.add(Vector3((x0 + hx0) * 0.5, center.y, center.z), Vector3(hx0 - x0, thickness, CELL), key)
	if x1 > hx1 + 0.01:
		batch.add(Vector3((hx1 + x1) * 0.5, center.y, center.z), Vector3(x1 - hx1, thickness, CELL), key)
	if hz0 > z0 + 0.01:
		batch.add(Vector3(hole_c.x, center.y, (z0 + hz0) * 0.5), Vector3(hole, thickness, hz0 - z0), key)
	if z1 > hz1 + 0.01:
		batch.add(Vector3(hole_c.x, center.y, (hz1 + z1) * 0.5), Vector3(hole, thickness, z1 - hz1), key)


func _hazard_ring(batch: LevelKit.BoxBatch, center: Vector3, hole: float) -> void:
	var r := hole * 0.5 + 0.12
	for k in 4:
		var horizontal := k < 2
		var s := -1.0 if k % 2 == 0 else 1.0
		var pos := center + (Vector3(0.0, 0.0, s * r) if horizontal else Vector3(s * r, 0.0, 0.0))
		var size := Vector3(hole + 0.48, 0.01, 0.2) if horizontal else Vector3(0.2, 0.01, hole + 0.48)
		batch.add(pos, size, "hazard", false)


## Concrete walls round a shaft through the plenum.
func _shaft_lining(batch: LevelKit.BoxBatch, center: Vector3, from_y: float, h: float, hole: float) -> void:
	var y := from_y + h * 0.5
	var e := hole * 0.5 + 0.05
	batch.add(Vector3(center.x - e, y, center.z), Vector3(0.1, h, hole + 0.2), "concrete")
	batch.add(Vector3(center.x + e, y, center.z), Vector3(0.1, h, hole + 0.2), "concrete")
	batch.add(Vector3(center.x, y, center.z - e), Vector3(hole, h, 0.1), "concrete")
	batch.add(Vector3(center.x, y, center.z + e), Vector3(hole, h, 0.1), "concrete")


func _edge_kind(f: int, a: Vector2i, b: Vector2i) -> int:
	var ra := room_at(f, a)
	var rb := room_at(f, b)
	if ra == "." or rb == ".":
		return Conn.NONE
	if ra == rb:
		return Conn.OPEN
	for e in EDGES[f]:
		var ea := Vector2i(int(e[0]), int(e[1]))
		var eb := Vector2i(int(e[2]), int(e[3]))
		if (ea == a and eb == b) or (ea == b and eb == a):
			return int(e[4])
	return Conn.NONE


func _build_walls(batch: LevelKit.BoxBatch, f: int) -> void:
	var base := _origin.y + float(f) * FLOOR_H
	var h: float = CEIL_HS[f]
	var key := "ktile" if f == 1 else "pizza_wall"
	for z in ROWS:
		for x in COLS:
			var c := Vector2i(x, z)
			var here := room_at(f, c)
			# Each cell owns its -x and -z edges; the outer +x / +z edges are done by the last row/column.
			for d: Vector2i in [Vector2i(-1, 0), Vector2i(0, -1)]:
				var nb := c + d
				var along_x := d.y != 0
				var center := cell_center(f, x, z) - Vector3(float(-d.x) * CELL * 0.5, 0.0, float(-d.y) * CELL * 0.5)
				center.y = base + h * 0.5
				if here == "." and room_at(f, nb) == ".":
					continue
				_wall(batch, f, center, along_x, _edge_kind(f, c, nb), base, key, c, nb)
			for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				var nb := c + d
				if nb.x < COLS and nb.y < ROWS:
					continue  # that cell draws it
				if here == ".":
					continue
				var along_x := d.y != 0
				var center := cell_center(f, x, z) + Vector3(float(d.x) * CELL * 0.5, 0.0, float(d.y) * CELL * 0.5)
				center.y = base + h * 0.5
				_wall(batch, f, center, along_x, Conn.NONE, base, key, c, nb)


func _wall(batch: LevelKit.BoxBatch, f: int, center: Vector3, along_x: bool, kind: int, base: float, key: String, a: Vector2i, b: Vector2i) -> void:
	var h: float = CEIL_HS[f]
	var full := Vector3(CELL + WALL_T, h, WALL_T) if along_x else Vector3(WALL_T, h, CELL + WALL_T)
	var dir := Vector3(1.0, 0.0, 0.0) if along_x else Vector3(0.0, 0.0, 1.0)
	var normal := Vector3(0.0, 0.0, 1.0) if along_x else Vector3(1.0, 0.0, 0.0)
	match kind:
		Conn.OPEN:
			return
		Conn.NONE:
			batch.add(center, full, key)
			return
		Conn.ARCH:
			# A wide opening with a header and two short piers.
			var pier := (CELL - 3.6) * 0.5
			var off := 1.8 + pier * 0.5
			var ps := Vector3(pier + WALL_T * 0.5, h, WALL_T) if along_x else Vector3(WALL_T, h, pier + WALL_T * 0.5)
			batch.add(center - dir * off, ps, key)
			batch.add(center + dir * off, ps, key)
			var header_h := h - 2.6
			batch.add(Vector3(center.x, base + 2.6 + header_h * 0.5, center.z), Vector3(3.6, header_h, WALL_T) if along_x else Vector3(WALL_T, header_h, 3.6), key)
			batch.add(Vector3(center.x, base + 2.55, center.z), Vector3(3.8, 0.1, WALL_T + 0.1) if along_x else Vector3(WALL_T + 0.1, 0.1, 3.8), "trim", false)
			return
		Conn.COUNTER:
			# The serving counter fills the opening to 1.1 m; the rest is open air.
			var seg := (CELL - 3.0) * 0.5
			var off := 1.5 + seg * 0.5
			var ss := Vector3(seg + WALL_T * 0.5, h, WALL_T) if along_x else Vector3(WALL_T, h, seg + WALL_T * 0.5)
			batch.add(center - dir * off, ss, key)
			batch.add(center + dir * off, ss, key)
			batch.add(Vector3(center.x, base + 0.55, center.z), Vector3(3.0, 1.1, 0.7) if along_x else Vector3(0.7, 1.1, 3.0), "booth_dark")
			batch.add(Vector3(center.x, base + 1.12, center.z), Vector3(3.1, 0.05, 0.8) if along_x else Vector3(0.8, 0.05, 3.1), "laminate")
			batch.add(Vector3(center.x, base + 1.5, center.z), Vector3(2.4, 0.6, 0.02) if along_x else Vector3(0.02, 0.6, 2.4), "vending_glass", false)
			var soffit := Vector3(CELL, 0.5, WALL_T) if along_x else Vector3(WALL_T, 0.5, CELL)
			batch.add(Vector3(center.x, base + h - 0.25, center.z), soffit, key)
			return
	# DOOR and SHUTTER: a doorway.
	var w := DOOR_W if kind == Conn.DOOR else 2.2
	var seg := (CELL - w) * 0.5
	var off := w * 0.5 + seg * 0.5
	var seg_size := Vector3(seg + WALL_T * 0.5, h, WALL_T) if along_x else Vector3(WALL_T, h, seg + WALL_T * 0.5)
	batch.add(center - dir * off, seg_size, key)
	batch.add(center + dir * off, seg_size, key)
	var lintel_h := h - DOOR_H
	batch.add(Vector3(center.x, base + DOOR_H + lintel_h * 0.5, center.z), Vector3(w, lintel_h, WALL_T) if along_x else Vector3(WALL_T, lintel_h, w), key)
	var jamb := Vector3(0.08, DOOR_H, WALL_T + 0.06) if along_x else Vector3(WALL_T + 0.06, DOOR_H, 0.08)
	for s: float in [-1.0, 1.0]:
		batch.add(Vector3(center.x, base + DOOR_H * 0.5, center.z) + dir * s * (w * 0.5 + 0.04), jamb, "trim", false)
	batch.add(Vector3(center.x, base + DOOR_H + 0.04, center.z), Vector3(w + 0.16, 0.08, WALL_T + 0.06) if along_x else Vector3(WALL_T + 0.06, 0.08, w + 0.16), "trim", false)
	if kind == Conn.SHUTTER:
		# The hall side is the cell the Line comes from (b is the climb room).
		var hall_cell := a if room_at(f, a) == "L" else b
		var hall_center := cell_center(f, hall_cell.x, hall_cell.y)
		var hall_normal := (Vector3(hall_center.x - center.x, 0.0, hall_center.z - center.z)).normalized()
		var sh := Shutter.create("Shutter%d" % f, Vector3(center.x, base, center.z), dir, hall_normal, w, DOOR_H)
		var climb_cell := b if hall_cell == a else a
		_pending_shutter(f, sh, hall_cell, climb_cell)
		test_points["p_shutter%d" % f] = sh.position + hall_normal * 0.55 + dir * (w * 0.5 + 0.35)
	elif _hash(center + Vector3(3.1, 0.0, 7.7)) < 0.5 or room_at(f, a) == "R" or room_at(f, b) == "R":
		_pending_exit_signs.append([Vector3(center.x, base + DOOR_H + 0.3, center.z), normal])


func _pending_shutter(f: int, sh: Shutter, hall_cell: Vector2i, climb_cell: Vector2i) -> void:
	_pending_shutters.append([f, sh, hall_cell, climb_cell])


func _hash(p: Vector3) -> float:
	var h := sin(p.x * 12.9898 + p.y * 4.1414 + p.z * 78.233) * 43758.5453
	return h - floorf(h)


func _build_exit_signs(root: Node3D) -> void:
	var batch := LevelKit.BoxBatch.new()
	for s in _pending_exit_signs:
		PizzeriaProps.exit_sign(root, batch, s[0], s[1])
	_pending_exit_signs.clear()
	batch.build(root, "ExitSigns")
	for e in _pending_shutters:
		var f: int = e[0]
		var sh: Shutter = e[1]
		root.add_child(sh)
		shutters.append(sh)
		# Register the shutter on Pappy's graph edge between the hall node and the climb node.
		var hall_i := nearest_node(f, cell_center(f, (e[2] as Vector2i).x, (e[2] as Vector2i).y))
		var climb_i := nearest_node(f, cell_center(f, (e[3] as Vector2i).x, (e[3] as Vector2i).y))
		_shutter_edges[f]["%d-%d" % [mini(hall_i, climb_i), maxi(hall_i, climb_i)]] = sh
	_pending_shutters.clear()


func _build_stage(root: Node3D, batch: LevelKit.BoxBatch, rng: RandomNumberGenerator) -> void:
	var base := _origin.y + 2.0 * FLOOR_H
	# The raised stage over cells x 1..4, z 0..1, with steps at both front corners.
	var sx := _origin.x + 1.0 * CELL
	var ex := _origin.x + 5.0 * CELL
	var sz := _origin.z
	var ez := _origin.z + 2.0 * CELL
	var c := Vector3((sx + ex) * 0.5, base + STAGE_H * 0.5, (sz + ez) * 0.5)
	batch.add(c, Vector3(ex - sx, STAGE_H, ez - sz), "stage_wood")
	batch.add(Vector3(c.x, base + STAGE_H - 0.02, ez - 0.08), Vector3(ex - sx, 0.04, 0.16), "hazard", false)
	for x: float in [sx + 1.2, ex - 1.2]:
		batch.add(Vector3(x, base + STAGE_H * 0.25, ez + 0.5), Vector3(2.0, STAGE_H * 0.5, 1.0), "stage_wood")
	# Curtain: two halves hanging from a track at the stage front, closed for now.
	for s: float in [-1.0, 1.0]:
		var half := Node3D.new()
		half.name = "Curtain%s" % ("L" if s < 0.0 else "R")
		half.position = Vector3(c.x + s * (ex - sx) * 0.25, base + STAGE_H, ez - 0.4)
		root.add_child(half)
		var m := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3((ex - sx) * 0.5, CEIL_HS[2] - STAGE_H - 0.3, 0.12)
		m.mesh = bm
		m.position = Vector3(0.0, bm.size.y * 0.5, 0.0)
		m.material_override = LevelKit.mat("curtain")
		half.add_child(m)
		_curtains.append(half)
	batch.add(Vector3(c.x, base + CEIL_HS[2] - 0.15, ez - 0.4), Vector3(ex - sx + 0.4, 0.3, 0.3), "steel_dark", false)
	# The band on the back wall, Pappy's empty mark center stage, the prop loft and the exit.
	var back := Vector3(c.x, base + STAGE_H, sz + 1.6)
	_band_lights = PizzeriaProps.band(root, batch, back + Vector3(-5.0, 0.0, 0.0), Vector3(0.0, 0.0, 1.0))
	var mark := Vector3(c.x + 1.0, base + STAGE_H, sz + 7.0)
	batch.add(mark + Vector3(0.0, 0.005, 0.0), Vector3(1.6, 0.01, 1.6), "hazard", false, 0.78)
	var mark_label := Label3D.new()
	mark_label.text = "PAPPY"
	mark_label.font_size = 40
	mark_label.pixel_size = 0.006
	mark_label.modulate = Color(0.1, 0.1, 0.1)
	mark_label.position = mark + Vector3(0.0, 0.012, 0.0)
	mark_label.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	root.add_child(mark_label)
	test_points["p_stage"] = mark + Vector3(0.0, 0.1, 1.5)
	# Loft: along the back wall, right of the band. A thick slab so the mantle probes find its edge.
	var loft_c := Vector3(c.x + 6.5, base + STAGE_H + LOFT_H, sz + 1.5)
	var loft_size := Vector3(9.0, 0.5, 2.8)
	batch.add(loft_c - Vector3(0.0, 0.25, 0.0), loft_size, "metal")
	batch.add(loft_c + Vector3(0.0, 0.5, loft_size.z * 0.5), Vector3(loft_size.x, 1.0, 0.05), "steel_dark", true)  # front railing
	batch.add(loft_c + Vector3(0.0, 1.02, loft_size.z * 0.5), Vector3(loft_size.x, 0.05, 0.08), "hazard", false)
	for k in 5:
		batch.add(Vector3(loft_c.x - loft_size.x * 0.5 + 0.3 + float(k) * 2.1, base + STAGE_H + (LOFT_H - 0.5) * 0.5, sz + 0.4), Vector3(0.12, LOFT_H - 0.5, 0.12), "steel_dark")
	# A speaker case to climb at the loft's left end: 1 m up, then the loft.
	var case_x := loft_c.x - loft_size.x * 0.5 - 0.85
	batch.add(Vector3(case_x, base + STAGE_H + 0.5, sz + 1.5), Vector3(1.4, 1.0, 1.4), "speaker")
	batch.add(Vector3(case_x, base + STAGE_H + 0.75, sz + 0.78), Vector3(1.0, 0.3, 0.02), "steel", false)
	test_points["p_cases"] = Vector3(case_x, base + STAGE_H + 0.1, sz + 3.3)
	test_points["p_case_tops"] = [Vector3(case_x, base + STAGE_H + 1.05, sz + 1.5), loft_c + Vector3(-3.0, 0.1, 0.0)]
	# ROOF ACCESS hatch over the loft: a ladder into a hazard-striped square of light.
	var hatch := Vector3(loft_c.x + 1.0, base + CEIL_HS[2], sz + 1.4)
	batch.add(hatch - Vector3(0.0, 0.03, 0.0), Vector3(1.2, 0.02, 1.2), "hazard", false)
	batch.add(hatch - Vector3(0.0, 0.05, 0.0), Vector3(1.0, 0.02, 1.0), "glow", false)
	for k in 4:
		batch.add(Vector3(hatch.x, loft_c.y + 0.4 + 0.4 * float(k), hatch.z + 0.5), Vector3(0.6, 0.04, 0.04), "steel", false)
	for s: float in [-0.3, 0.3]:
		batch.add(Vector3(hatch.x + s, loft_c.y + (hatch.y - loft_c.y) * 0.5, hatch.z + 0.5), Vector3(0.04, hatch.y - loft_c.y, 0.04), "steel", false)
	var hl := OmniLight3D.new()
	hl.light_color = Color(0.7, 0.9, 1.0)
	hl.light_energy = 2.2
	hl.omni_range = 8.0
	hl.position = hatch - Vector3(0.0, 0.3, 0.0)
	root.add_child(hl)
	_sign(root, "PROP LOFT\nROOF ACCESS\nEVERYONE UP HERE", Vector3(loft_c.x, base + STAGE_H + LOFT_H + 1.6, sz + 0.25), 0.0)
	_sign(root, "ROOF ACCESS\nCLIMB THE CASE", Vector3(case_x, base + STAGE_H + 2.6, sz + 0.25), 0.0, Color(0.6, 1.0, 0.6))
	_exit_area = Area3D.new()
	_exit_area.name = "ExitArea"
	_exit_area.collision_layer = 0
	_exit_area.collision_mask = ChainBody.LAYER_BODIES
	var es := CollisionShape3D.new()
	var eb := BoxShape3D.new()
	eb.size = Vector3(loft_size.x - 0.4, 2.0, loft_size.z + 0.6)
	es.shape = eb
	es.position = Vector3(0.0, 1.0, 0.0)
	_exit_area.add_child(es)
	_exit_area.position = loft_c
	root.add_child(_exit_area)
	test_points["p_loft"] = loft_c + Vector3(0.0, 0.1, 0.0)
	test_points["p_exit"] = loft_c + Vector3(0.0, 0.1, 0.0)
	# Stage lights on the front truss, dim: house lights are off. Two ghost lights over the back
	# of the stage so the loft climb reads.
	for k in 4:
		var l := OmniLight3D.new()
		l.light_color = Color(0.9, 0.3, 0.8) if k % 2 == 0 else Color(0.3, 0.6, 1.0)
		l.light_energy = 0.9
		l.omni_range = 10.0
		l.position = Vector3(sx + 3.0 + 6.0 * float(k), base + CEIL_HS[2] - 0.5, ez + 1.5)
		root.add_child(l)
		batch.add(l.position + Vector3(0.0, 0.2, 0.0), Vector3(0.3, 0.4, 0.3), "steel_dark", false)
	batch.add(Vector3(c.x, base + CEIL_HS[2] - 0.3, ez + 1.5), Vector3(ex - sx + 2.0, 0.15, 0.15), "steel_dark", false)
	for gx: float in [c.x - 7.0, c.x + 5.0]:
		var g := OmniLight3D.new()
		g.light_color = Color(0.75, 0.85, 1.0)
		g.light_energy = 1.0
		g.omni_range = 11.0
		g.position = Vector3(gx, base + CEIL_HS[2] - 0.6, sz + 4.0)
		root.add_child(g)
		batch.add(g.position + Vector3(0.0, 0.25, 0.0), Vector3(0.25, 0.5, 0.25), "steel_dark", false)
		batch.add(g.position - Vector3(0.0, 0.08, 0.0), Vector3(0.3, 0.03, 0.3), "glow", false)
	# Sandbags and fly ropes in both wings.
	for wx: float in [sx - 3.0, ex + 3.0]:
		for k in 3:
			batch.add(Vector3(wx + rng.randf_range(-1.5, 1.5), base + 0.2 + 0.4 * float(k % 2), sz + 1.0 + float(k) * 1.4), Vector3(0.7, 0.4, 0.4), "crate", true, rng.randf())
		for k in 4:
			batch.add(Vector3(wx + 2.4 * signf(c.x - wx), base + CEIL_HS[2] * 0.5, sz + 2.0 + float(k) * 1.2), Vector3(0.03, CEIL_HS[2], 0.03), "rope", false)


## Set dressing per cell, by room letter. ("S" is storage downstairs and the stage upstairs; the
## stage is dressed as one piece in _build_stage.)
func _dress_cell(root: Node3D, batch: LevelKit.BoxBatch, f: int, x: int, z: int, r: String, rng: RandomNumberGenerator) -> void:
	var c := cell_center(f, x, z)
	var base := c.y
	var ceil_y: float = base + CEIL_HS[f]
	if f == 2 and r == "S":
		return
	match r:
		"R":
			_receiving(root, batch, c, rng)
		"H":
			if z == 2:
				_host_stand(root, batch, f, c)
			else:
				batch.add(c + Vector3(2.4, 0.5, 0.0), Vector3(0.6, 1.0, 2.2), "booth_dark")  # waiting bench
				batch.add(c + Vector3(2.4, 1.0, 0.0), Vector3(0.62, 0.08, 2.2), "booth", false)
				PizzeriaProps.neon(root, batch, "PAPPY PEPPERONI'S", c + Vector3(-2.88, 2.6, 0.0), PI * 0.5, Color(1.0, 0.25, 0.2), 64)
				PizzeriaProps.neon(root, batch, "PIZZA . GAMES . BIRTHDAYS", c + Vector3(-2.88, 2.0, 0.0), PI * 0.5, Color(0.3, 1.0, 0.4), 30)
				_poster(root, c, Vector3(0.0, 0.0, 1.0), rng)
		"D":
			_dining_cell(root, batch, f, x, z, c, rng)
		"C":
			_counter_cell(root, batch, x, z, c, rng)
		"A":
			var fwd := Vector3(-1.0, 0.0, 0.0)
			for k in 3:
				PizzeriaProps.arcade_cabinet(root, batch, c + Vector3(2.5, 0.0, -1.8 + 1.8 * float(k)), fwd,
					["DOUGH\nDEFENDER", "SLICE\nRACER", "GRAB-A-NUT"][(k + z) % 3], [Color(0.3, 0.9, 1.0), Color(1.0, 0.4, 0.3), Color(1.0, 0.9, 0.2)][(k + z) % 3])
			if z == 2:
				batch.add(c + Vector3(-1.5, 0.9, -2.3), Vector3(1.1, 1.8, 1.1), "arcade")  # claw machine
				batch.add(c + Vector3(-1.5, 1.2, -2.3), Vector3(1.0, 1.0, 1.0), "vending_glass", false)
				batch.add(c + Vector3(-1.5, 2.0, -2.3), Vector3(1.2, 0.3, 1.2), "neon_pink", false)
			else:
				PizzeriaProps.table(root, batch, c + Vector3(-1.2, 0.0, 1.0), rng, 3)
		"W":
			var side := 1.0 if x == 2 else -1.0
			for k in 2:
				batch.add(c + Vector3(side * 2.0, 1.1, -2.0 + 1.6 * float(k)), Vector3(0.05, 2.2, 1.4), "partition")
				batch.add(c + Vector3(side * 2.5, 0.25, -2.0 + 1.6 * float(k)), Vector3(0.5, 0.5, 0.45), "white")
			batch.add(c + Vector3(-side * 2.4, 0.45, 1.5), Vector3(0.6, 0.9, 1.6), "white")
			batch.add(c + Vector3(-side * 2.85, 1.7, 1.5), Vector3(0.02, 0.9, 1.6), "dark", false)  # mirror
			batch.add(c + Vector3(0.0, 0.3, 2.3), Vector3(0.36, 0.62, 0.03), "sign", false, 0.5)
		"P":
			_party_cell(root, batch, f, x, z, c, rng)
		"L":
			if f == 0 and z == 1:
				batch.add(c + Vector3(2.3, 0.4, 1.5), Vector3(0.5, 0.8, 0.5), "hazard")  # mop bucket
				batch.add(c + Vector3(2.3, 0.8, 1.5), Vector3(0.05, 1.3, 0.05), "desk", false, 0.3)
				batch.add(c + Vector3(-1.5, 0.32, -0.5), Vector3(0.36, 0.62, 0.03), "sign", false, 0.4)
			elif f == 1:
				PizzeriaProps.shelf(batch, c + Vector3(0.0, 0.0, 2.6), true, rng, 2.4)
			_poster(root, c, Vector3(1.0, 0.0, 0.0) if f == 0 else Vector3(0.0, 0.0, -1.0), rng)
			if f == 0 and z == 0:
				_sign(root, "EMPLOYEES ONLY\nDUMBWAITER ->", c + Vector3(2.88, 2.0, 0.0), -PI * 0.5)
			elif f == 1 and x == 1:
				_sign(root, "EMPLOYEES ONLY\n<- STAGE LIFT", c + Vector3(0.0, 2.0, 2.88), PI)
		"U":
			if f == 0:
				_dumbwaiter_bottom(root, batch, c, rng)
			elif z == 0:
				_dumbwaiter_top(root, batch, c, rng)
			else:
				_dish_pit(root, batch, c, rng)
		"S", "Y", "N":
			PizzeriaProps.shelf(batch, c + Vector3(-2.6, 0.0, 0.0), false, rng, 4.0)
			PizzeriaProps.shelf(batch, c + Vector3(2.6, 0.0, 0.0), false, rng, 4.0)
			if r == "N":
				for k in 4:
					batch.add(c + Vector3(-2.0 + 1.0 * float(k), 0.9, 2.65), Vector3(0.45, 1.8, 0.5), "steel_dark")  # lockers
			if r == "S":
				root.add_child(ScareDirector.build_dennis(c + Vector3(1.0, 0.0, -1.5), 2.4))  # Dennis gets everywhere
			_poster(root, c, Vector3(0.0, 0.0, 1.0), rng)
		"B", "E":
			_breakroom(root, batch, f, c, r, rng)
		"K":
			_kitchen_cell(root, batch, x, z, c, rng)
		"F":
			PizzeriaProps.freezer(root, batch, c, rng)
			test_points["p_freezer"] = c + Vector3(0.0, 0.1, 0.0)
			_sign(root, "WALK-IN FREEZER\nHE WON'T COME IN HERE", c + Vector3(-2.88, 2.1, 0.0), PI * 0.5, Color(0.7, 0.9, 1.0))
		"M":
			_office(root, batch, f, c, rng)
		"T":
			_lift_room(root, batch, c)
		"X":
			if z == 0:
				_suit_head = PizzeriaProps.spare_suit(root, batch, c + Vector3(-2.3, 0.0, 0.0), Vector3(1.0, 0.0, 0.0))
				test_points["p_rack"] = c + Vector3(0.0, 0.1, 0.0)
			else:
				batch.add(c + Vector3(-2.5, 0.4, 0.0), Vector3(0.8, 0.8, 3.0), "laminate")
				batch.add(c + Vector3(-2.88, 1.7, 0.0), Vector3(0.02, 1.4, 2.8), "dark", false)  # mirror
				for k in 6:
					batch.add(c + Vector3(-2.82, 1.0 + 0.3 * float(k), -1.5), Vector3(0.08, 0.08, 0.08), "jukebox_glow", false)
					batch.add(c + Vector3(-2.82, 1.0 + 0.3 * float(k), 1.5), Vector3(0.08, 0.08, 0.08), "jukebox_glow", false)
				var ml := OmniLight3D.new()
				ml.light_color = Color(1.0, 0.8, 0.5)
				ml.light_energy = 0.8
				ml.omni_range = 4.0
				ml.position = c + Vector3(-2.0, 1.8, 0.0)
				root.add_child(ml)
			_poster(root, c, Vector3(0.0, 0.0, -1.0), rng)
		"O":
			_sound_booth(root, batch, f, c)
		"G":
			if z == 1:
				PizzeriaProps.shelf(batch, c + Vector3(2.6, 0.0, 0.0), false, rng, 4.0)
			else:
				for k in 3:
					batch.add(c + Vector3(2.2, 0.3 + 0.35 * float(k), -1.0 + 0.8 * float(k)), Vector3(0.7, 0.4, 0.4), "crate", true, rng.randf())
			_sign(root, "STAGE RIGHT", c + Vector3(2.88, 2.4, 0.0), -PI * 0.5, Color(0.9, 0.9, 0.9))
		"V":
			_audience_cell(root, batch, x, z, c, rng)
		"Q":
			_sign(root, "STAGE LEFT", c + Vector3(-2.88, 2.4, 0.0), PI * 0.5, Color(0.9, 0.9, 0.9))
			test_points["p_lift_top"] = c + Vector3(0.0, 0.1, 0.0)
	# Vents and a bit of ceiling clutter everywhere but the shaft cells and the stage.
	if not (f == 2 and (r == "S" or r == "Q")) and not (f == 0 and (r == "U" or r == "R")) and not (f == 1 and (r == "T" or r == "U")):
		var vent := c + Vector3(1.9 * (1.0 if rng.randf() < 0.5 else -1.0), 0.0, 1.6 * (1.0 if rng.randf() < 0.5 else -1.0))
		batch.add(Vector3(vent.x, ceil_y - 0.01, vent.z), Vector3(0.6, 0.02, 0.6), "vent", false)
		batch.add(Vector3(vent.x, ceil_y - 0.016, vent.z), Vector3(0.48, 0.02, 0.48), "dark", false)
		for k in 5:
			batch.add(Vector3(vent.x, ceil_y - 0.022, vent.z - 0.2 + 0.1 * float(k)), Vector3(0.48, 0.012, 0.018), "vent", false)


func _receiving(root: Node3D, batch: LevelKit.BoxBatch, c: Vector3, rng: RandomNumberGenerator) -> void:
	# The freight car parks in the middle; crates along the walls; a dock door painted shut.
	PizzeriaProps.crates(batch, c + Vector3(-2.3, 0.0, -2.2), rng)
	PizzeriaProps.crates(batch, c + Vector3(2.2, 0.0, 2.1), rng)
	PizzeriaProps.shelf(batch, c + Vector3(2.6, 0.0, -1.0), false, rng, 2.6)
	PizzeriaProps.dock_door(root, batch, c + Vector3(0.0, 0.0, 2.9), Vector3(0.0, 0.0, -1.0), "DELIVERIES\nRING BELL\n(BELL MISSING)")
	_punch_clock(root, batch, c + Vector3(-2.9, 0.0, 1.5), PI * 0.5, "RECEIVING")
	_generator(root, batch, c + Vector3(-2.9, 0.0, -0.8), PI * 0.5)
	var sign := Label3D.new()
	sign.text = "PAPPY PEPPERONI'S\nFAMILY PIZZERIA\nNIGHT SHIFT: CLOCK IN\nAND DON'T CLOCK OUT"
	sign.font_size = 40
	sign.pixel_size = 0.005
	sign.modulate = Color(0.95, 0.8, 0.25)
	sign.outline_size = 10
	sign.double_sided = false
	sign.position = c + Vector3(2.88, 2.4, 0.0)
	sign.rotation = Vector3(0.0, -PI * 0.5, 0.0)
	root.add_child(sign)


func _host_stand(root: Node3D, batch: LevelKit.BoxBatch, f: int, c: Vector3) -> void:
	# The podium with the counter bell, and the security desk against the back wall.
	var podium := c + Vector3(1.6, 0.0, -1.8)
	batch.add(podium + Vector3(0.0, 0.6, 0.0), Vector3(0.7, 1.2, 0.5), "jukebox")
	batch.add(podium + Vector3(0.0, 1.22, 0.0), Vector3(0.8, 0.05, 0.6), "laminate")
	batch.add(podium + Vector3(0.0, 1.3, 0.0), Vector3(0.12, 0.1, 0.12), "brass", false)
	_bell_pos = podium + Vector3(0.0, 1.35, 0.0)
	var l := Label3D.new()
	l.text = "PLEASE WAIT\nTO BE SEATED\n(FOREVER)"
	l.font_size = 26
	l.pixel_size = 0.004
	l.modulate = Color(1.0, 0.9, 0.7)
	l.outline_size = 6
	l.position = podium + Vector3(0.0, 0.9, 0.3)
	root.add_child(l)
	_add_desk(root, f, c + Vector3(-2.2, 0.0, 1.0), -PI * 0.5)
	test_points["p_desk0"] = desks[desks.size() - 1].spot()


func _add_desk(root: Node3D, f: int, at: Vector3, facing: float) -> void:
	var cam_list: Array = []
	for i in node_count(f):
		var cam := node_cam(f, i)
		if cam < 0:
			continue
		while cam_list.size() <= cam:
			cam_list.append({})
		var look := node_position(f, i) + Vector3(0.0, 1.0, 0.0)
		var cell := cell_of(node_position(f, i))
		var corner := cell_center(f, cell.x, cell.y) + Vector3(-2.7, CEIL_HS[f] - 0.35, -2.7)
		cam_list[cam] = {"name": String(CAM_NAMES[f][cam]), "pos": corner, "look": look}
	_cams[f] = cam_list
	var d := SecurityDesk.create("Desk%d" % f, at, facing, f, cam_list)
	root.add_child(d)
	desks.append(d)


func _build_cameras(root: Node3D, f: int) -> void:
	var batch := LevelKit.BoxBatch.new()
	for cam in _cams[f]:
		if cam.is_empty():
			continue
		PizzeriaProps.camera_prop(root, batch, cam["pos"], cam["look"])
	batch.build(root, "Cams%d" % f)


func _dining_cell(root: Node3D, batch: LevelKit.BoxBatch, f: int, x: int, z: int, c: Vector3, rng: RandomNumberGenerator) -> void:
	var ceil_y: float = c.y + CEIL_HS[f]
	# Booths along the outer north wall, tables in the middle, the jukebox on the south-ish wall.
	if z == 0:
		for k in 2:
			PizzeriaProps.booth(batch, c + Vector3(-1.5 + 3.0 * float(k), 0.0, -2.85), Vector3(0.0, 0.0, 1.0))
	elif x == 1 and z == 3:
		_speakers.append(PizzeriaProps.jukebox(root, batch, c + Vector3(-1.0, 0.0, 2.5), Vector3(0.0, 0.0, -1.0)))
		PizzeriaProps.table(root, batch, c + Vector3(1.5, 0.0, -1.0), rng)
	elif z == 3:
		for k in 2:
			PizzeriaProps.booth(batch, c + Vector3(-1.5 + 3.0 * float(k), 0.0, 2.85), Vector3(0.0, 0.0, -1.0))
	else:
		PizzeriaProps.table(root, batch, c + Vector3(-1.4, 0.0, -1.2), rng)
		PizzeriaProps.table(root, batch, c + Vector3(1.5, 0.0, 1.3), rng)
	if x == 2 and z == 2:
		PizzeriaProps.balloon_arch(batch, c + Vector3(0.0, 2.2, 0.0), Vector3(1.0, 0.0, 0.0), 5.0, rng)
	if rng.randf() < 0.5:
		PizzeriaProps.pinata(batch, c + Vector3(rng.randf_range(-2.0, 2.0), ceil_y - 1.1, rng.randf_range(-2.0, 2.0)), ceil_y)
	if z == 0 and x == 3:
		_sign(root, "RESTROOMS  -  PARTY ROOM  -  ARCADE", c + Vector3(0.0, 3.2, -2.85), 0.0, Color(0.9, 0.9, 0.85))
	if x == 1 and z == 2:
		_poster(root, c, Vector3(-1.0, 0.0, 0.0), rng)


func _counter_cell(root: Node3D, batch: LevelKit.BoxBatch, x: int, z: int, c: Vector3, rng: RandomNumberGenerator) -> void:
	if x == 4 and z == 0:
		batch.add(c + Vector3(0.0, 0.45, -2.3), Vector3(2.0, 0.9, 0.8), "steel")  # back counter
		batch.add(c + Vector3(1.0, 1.4, -2.6), Vector3(0.8, 1.0, 0.5), "steel")  # dough mixer
		batch.add(c + Vector3(1.0, 2.0, -2.6), Vector3(0.3, 0.2, 0.3), "steel_dark", false)
		for k in 5:
			batch.add(c + Vector3(-1.4 + 0.5 * float(k), 1.05 + 0.1 * float(k % 2), -2.3), Vector3(0.45, 0.05, 0.45), "cardboard", false, rng.randf_range(-0.3, 0.3))
	elif x == 5 and z == 0:
		# The pass window on the back wall: a hatch with its own little shutter (the scare).
		PizzeriaProps.pass_window(batch, c + Vector3(0.0, 0.0, -2.9), Vector3(0.0, 0.0, 1.0))
		_pass_shutter = Node3D.new()
		_pass_shutter.position = c + Vector3(0.0, 2.05, -2.84)
		root.add_child(_pass_shutter)
		var m := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.6, 1.0, 0.04)
		m.mesh = bm
		m.position = Vector3(0.0, -0.5, 0.0)
		m.material_override = LevelKit.mat("shutter")
		_pass_shutter.add_child(m)
		test_points["p_pass"] = c + Vector3(0.0, 0.1, -1.6)
		_sign(root, "ORDER\nWINDOW", c + Vector3(0.0, 2.5, -2.86), 0.0, Color(1.0, 0.8, 0.3))
		batch.add(c + Vector3(2.0, 0.45, 1.5), Vector3(1.0, 0.9, 1.0), "steel")
	else:
		PizzeriaProps.prep_table(batch, c + Vector3(0.0, 0.0, 1.5), Vector3(2.4, 0.9, 0.9), rng)
		batch.add(c + Vector3(2.4, 1.0, 0.0), Vector3(0.8, 2.0, 1.2), "steel")  # fridge
		batch.add(c + Vector3(1.98, 1.2, 0.0), Vector3(0.04, 0.3, 0.4), "steel_dark", false)


func _party_cell(root: Node3D, batch: LevelKit.BoxBatch, f: int, x: int, z: int, c: Vector3, rng: RandomNumberGenerator) -> void:
	var ceil_y: float = c.y + CEIL_HS[f]
	# A long table with party hats and cake; balloons everywhere; a banner.
	batch.add(c + Vector3(0.0, 0.74, 0.0), Vector3(4.0, 0.05, 1.1), "party_cloth")
	for s: float in [-1.7, 1.7]:
		batch.add(c + Vector3(s, 0.36, 0.0), Vector3(0.1, 0.72, 0.9), "steel")
	for k in 6:
		var px := -1.6 + 0.65 * float(k)
		var pz := 0.9 if k % 2 == 0 else -0.9
		PizzeriaProps.chair(batch, c + Vector3(px, 0.0, pz), PI if pz > 0.0 else 0.0)
		batch.add(c + Vector3(px, 0.85, 0.3 * signf(pz)), Vector3(0.16, 0.22, 0.16), PizzeriaProps.BALLOONS[k % 3], false)
	batch.add(c + Vector3(0.0, 0.88, 0.0), Vector3(0.6, 0.25, 0.6), "white", false)
	batch.add(c + Vector3(0.0, 1.05, 0.0), Vector3(0.45, 0.1, 0.45), "party_cloth", false)
	for k in 5:
		batch.add(c + Vector3(-0.2 + 0.1 * float(k), 1.18, 0.0), Vector3(0.01, 0.16, 0.01), "white", false)
	for k in 4:
		PizzeriaProps.balloon(root, batch, c + Vector3(rng.randf_range(-2.5, 2.5), 0.1, rng.randf_range(-2.5, 2.5)), rng, rng.randf_range(1.4, 2.2))
	if (f == 0 and x == 5) or (f == 2 and x == 5):
		PizzeriaProps.big_slice(batch, c + Vector3(1.8, 0.0, 1.8), -0.6)
		PizzeriaProps.pinata(batch, c + Vector3(-1.5, ceil_y - 1.0, -1.5), ceil_y)
	var banner := Label3D.new()
	banner.text = "HAPPY BIRTHDAY %s" % ("BIG SLICE" if f == 2 else "PEPPERONI")
	banner.font_size = 44
	banner.pixel_size = 0.005
	banner.modulate = Color(1.0, 0.4, 0.5)
	banner.outline_size = 8
	banner.double_sided = false
	banner.position = c + Vector3(0.0, 2.4, 2.86)
	banner.rotation = Vector3(0.0, PI, 0.0)
	root.add_child(banner)
	if f == 2 and x == 4:
		_office_door_pos = c + Vector3(-2.9, 0.0, 0.0)
		test_points["p_party"] = c + Vector3(0.0, 0.1, 0.0)


func _dumbwaiter_bottom(root: Node3D, batch: LevelKit.BoxBatch, c: Vector3, rng: RandomNumberGenerator) -> void:
	# The shaft in the north-west corner (open side toward +z), the car at the bottom, the rope.
	var shaft := c + DUMB_OFF
	_shaft_walls(batch, shaft, c.y, CEIL_HS[0])
	var top := cell_center(1, 0, 0) + DUMB_OFF
	var ropes: Array[Vector3] = [shaft + Vector3(1.5, 0.0, 1.0), top + Vector3(1.5, 0.0, 1.0)]
	dumbwaiter = Dumbwaiter.create("Dumbwaiter", shaft, FLOOR_H, ropes)
	root.add_child(dumbwaiter)
	for rp in ropes:
		var l := Label3D.new()
		l.text = "HAND ROPE\nHOLD CTRL HERE\nTO HAUL THE CAR"
		l.font_size = 26
		l.pixel_size = 0.004
		l.modulate = Color(1.0, 0.85, 0.3)
		l.outline_size = 8
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.position = rp + Vector3(0.0, 1.9, 0.0)
		root.add_child(l)
		batch.add(rp + Vector3(0.0, 0.0, 0.0), Vector3(0.9, 0.012, 0.9), "hazard", false)
	batch.add(shaft + Vector3(1.0, 1.4, 0.0), Vector3(0.05, 2.8, 0.05), "rope", false)  # the hand rope
	var sl := OmniLight3D.new()
	sl.light_color = Color(1.0, 0.8, 0.6)
	sl.light_energy = 0.9
	sl.omni_range = 4.0
	sl.position = shaft + Vector3(0.0, 2.6, 0.4)
	root.add_child(sl)
	batch.add(shaft + Vector3(0.0, 2.75, 0.4), Vector3(0.2, 0.08, 0.2), "glow", false)
	PizzeriaProps.shelf(batch, c + Vector3(1.5, 0.0, 2.6), true, rng, 2.8)
	PizzeriaProps.shelf(batch, c + Vector3(2.6, 0.0, 0.0), false, rng, 2.0)
	_sign(root, "DUMBWAITER\nONE RIDER. SOMEONE HAULS.", c + Vector3(1.2, 3.3, -2.86), 0.0)
	test_points["p_dumbwaiter"] = shaft + Vector3(0.0, 0.1, 0.0)
	test_points["p_rope0"] = ropes[0]
	test_points["p_rope1"] = ropes[1]


func _shaft_walls(batch: LevelKit.BoxBatch, shaft: Vector3, base: float, h: float) -> void:
	var e := Dumbwaiter.SIZE * 0.5 + 0.15
	batch.add(Vector3(shaft.x, base + h * 0.5, shaft.z - e), Vector3(Dumbwaiter.SIZE + 0.4, h, 0.1), "steel_dark")
	batch.add(Vector3(shaft.x - e, base + h * 0.5, shaft.z), Vector3(0.1, h, Dumbwaiter.SIZE + 0.4), "steel_dark")
	batch.add(Vector3(shaft.x + e, base + h * 0.5, shaft.z), Vector3(0.1, h, Dumbwaiter.SIZE + 0.4), "steel_dark")
	# A header over the open side, so it reads as a hatch.
	batch.add(Vector3(shaft.x, base + h - 0.4, shaft.z + e), Vector3(Dumbwaiter.SIZE + 0.4, 0.8, 0.1), "steel_dark")


func _dumbwaiter_top(root: Node3D, batch: LevelKit.BoxBatch, c: Vector3, rng: RandomNumberGenerator) -> void:
	var shaft := c + DUMB_OFF
	_shaft_walls(batch, shaft, c.y, 2.2)
	batch.add(Vector3(shaft.x, c.y + 2.25, shaft.z), Vector3(Dumbwaiter.SIZE + 0.5, 0.1, Dumbwaiter.SIZE + 0.5), "steel_dark")  # shaft cap
	batch.add(shaft + Vector3(0.0, 1.0, 0.0), Vector3(0.05, 2.0, 0.05), "rope", false)
	PizzeriaProps.prep_table(batch, c + Vector3(1.8, 0.0, 1.8), Vector3(2.0, 0.9, 1.0), rng)
	_sign(root, "DUMBWAITER\nHAUL FROM UP HERE TOO", c + Vector3(0.6, 2.5, -2.86), 0.0)
	test_points["p_dumbwaiter_top"] = shaft + Vector3(0.0, 0.1, 1.6)


func _dish_pit(_root: Node3D, batch: LevelKit.BoxBatch, c: Vector3, rng: RandomNumberGenerator) -> void:
	batch.add(c + Vector3(-2.3, 0.45, 0.0), Vector3(1.0, 0.9, 4.0), "steel")
	for k in 3:
		batch.add(c + Vector3(-2.3, 0.75, -1.3 + 1.3 * float(k)), Vector3(0.7, 0.4, 0.9), "dark", false)  # sinks
	batch.add(c + Vector3(-2.3, 1.3, 0.0), Vector3(0.05, 0.6, 0.05), "steel", false)
	for k in 4:
		batch.add(c + Vector3(1.5 + 0.5 * float(k % 2), 0.1 + 0.45 * float(k), 1.5), Vector3(0.5, 0.1, 0.5), "steel", false, rng.randf())
	PizzeriaProps.shelf(batch, c + Vector3(1.5, 0.0, -2.6), true, rng, 2.4)


func _breakroom(root: Node3D, batch: LevelKit.BoxBatch, f: int, c: Vector3, r: String, rng: RandomNumberGenerator) -> void:
	_punch_clock(root, batch, c + Vector3(2.9, 0.0, -1.5), -PI * 0.5, ROOM_NAMES[r])
	_generator(root, batch, c + Vector3(2.9, 0.0, 1.2), -PI * 0.5)
	if r == "B":
		PizzeriaProps.shelf(batch, c + Vector3(-2.6, 0.0, 0.0), false, rng, 4.0)
		for k in 4:
			batch.add(c + Vector3(-0.5 + 0.6 * float(k % 2), 0.2 + 0.32 * float(k / 2), 2.2), Vector3(0.7, 0.32, 0.45), "flour", true, rng.randf_range(-0.3, 0.3))
	else:
		batch.add(c + Vector3(-2.5, 1.0, 0.0), Vector3(0.1, 0.05, 4.0), "steel", false)
		for k in 7:
			batch.add(c + Vector3(-2.5, 1.5, -1.8 + 0.6 * float(k)), Vector3(0.3, 0.9, 0.2), ["fabric", "party_cloth", "chef_white"][k % 3], false, rng.randf_range(-0.2, 0.2))
		batch.add(c + Vector3(-1.2, 0.5, 2.2), Vector3(2.0, 1.0, 0.6), "laminate")
	var tb := c + Vector3(0.8, 0.0, -1.5)
	batch.add(tb + Vector3(0.0, 0.74, 0.0), Vector3(1.2, 0.06, 1.2), "laminate")
	batch.add(tb + Vector3(0.0, 0.37, 0.0), Vector3(0.12, 0.74, 0.12), "steel")
	PizzeriaProps.chair(batch, tb + Vector3(0.9, 0.0, 0.0), -PI * 0.5)
	PizzeriaProps.chair(batch, tb + Vector3(-0.9, 0.0, 0.2), PI * 0.5)
	batch.add(tb + Vector3(0.1, 0.8, 0.1), Vector3(0.45, 0.04, 0.45), "pizza_crust", false)
	var vm := c + Vector3(-1.0, 0.0, -2.5)
	batch.add(vm + Vector3(0.0, 0.95, 0.0), Vector3(0.8, 1.9, 0.9), "vending")
	batch.add(vm + Vector3(0.0, 1.15, 0.46), Vector3(0.7, 1.2, 0.02), "vending_glass", false)
	var vl := OmniLight3D.new()
	vl.light_color = Color(1.0, 0.7, 0.5)
	vl.light_energy = 0.6
	vl.omni_range = 2.5
	vl.position = vm + Vector3(0.0, 1.2, 1.0)
	root.add_child(vl)
	_poster(root, c, Vector3(0.0, 0.0, 1.0), rng)
	if f == 2:
		test_points["p_checkpoint6"] = c + Vector3(0.0, 0.1, 0.0)
	else:
		test_points["p_checkpoint5"] = c + Vector3(0.0, 0.1, 0.0)


func _punch_clock(root: Node3D, batch: LevelKit.BoxBatch, at: Vector3, yaw: float, room: String) -> void:
	var clock := Label3D.new()
	clock.text = "PUNCH CLOCK\n%s" % room
	clock.font_size = 40
	clock.pixel_size = 0.005
	clock.modulate = Color(1.0, 0.85, 0.3)
	clock.outline_size = 8
	clock.double_sided = false
	clock.position = at + Vector3(0.0, 1.8, 0.0) + Vector3(-sin(yaw), 0.0, -cos(yaw)) * 0.02
	clock.rotation = Vector3(0.0, yaw, 0.0)
	root.add_child(clock)
	batch.add(at + Vector3(0.0, 1.75, 0.0), Vector3(0.06, 0.6, 0.8) if absf(sin(yaw)) > 0.5 else Vector3(0.8, 0.6, 0.06), "trim", false)


## The generator panel: standing in a Break Room restarts it (power back to 100%).
func _generator(root: Node3D, batch: LevelKit.BoxBatch, at: Vector3, yaw: float) -> void:
	var n := Vector3(-sin(yaw), 0.0, -cos(yaw))
	batch.add(at + n * 0.2 + Vector3(0.0, 1.3, 0.0), Vector3(0.4, 1.0, 0.7) if absf(n.x) > 0.5 else Vector3(0.7, 1.0, 0.4), "steel_dark")
	batch.add(at + n * 0.41 + Vector3(0.0, 1.5, 0.0), Vector3(0.02, 0.1, 0.1) if absf(n.x) > 0.5 else Vector3(0.1, 0.1, 0.02), "neon_green", false)
	var l := Label3D.new()
	l.text = "GENERATOR\nSTAND IN THIS ROOM\nTO RESTART POWER"
	l.font_size = 24
	l.pixel_size = 0.004
	l.modulate = Color(0.5, 1.0, 0.6)
	l.outline_size = 6
	l.double_sided = false
	l.position = at + n * 0.42 + Vector3(0.0, 1.0, 0.0)
	l.rotation = Vector3(0.0, yaw, 0.0)
	root.add_child(l)


func _kitchen_cell(root: Node3D, batch: LevelKit.BoxBatch, x: int, z: int, c: Vector3, rng: RandomNumberGenerator) -> void:
	if z == 0:
		PizzeriaProps.oven(root, batch, c + Vector3(-1.5, 0.0, -2.4), Vector3(0.0, 0.0, 1.0), x % 2 == 0)
		PizzeriaProps.oven(root, batch, c + Vector3(1.5, 0.0, -2.4), Vector3(0.0, 0.0, 1.0), x % 2 == 1)
		batch.add(c + Vector3(0.0, 2.9, -2.2), Vector3(5.8, 0.6, 1.6), "steel")  # extractor hood
		batch.add(c + Vector3(0.0, 2.55, -2.2), Vector3(5.4, 0.1, 1.2), "dark", false)
	elif z == 1:
		PizzeriaProps.prep_table(batch, c + Vector3(0.0, 0.0, 0.0), Vector3(3.6, 0.9, 1.1), rng)
		for k in 4:
			batch.add(c + Vector3(-1.2 + 0.8 * float(k), 2.1, 0.0), Vector3(0.1, 0.5, 0.05), "steel", false)  # hanging utensils
		batch.add(c + Vector3(0.0, 2.4, 0.0), Vector3(3.2, 0.04, 0.04), "steel", false)
	else:
		PizzeriaProps.prep_table(batch, c + Vector3(-1.5, 0.0, 0.5), Vector3(1.6, 0.9, 2.4), rng)
		batch.add(c + Vector3(2.2, 1.0, -1.5), Vector3(0.9, 2.0, 1.4), "steel")  # fridge
		batch.add(c + Vector3(1.74, 1.2, -1.5), Vector3(0.04, 0.3, 0.5), "steel_dark", false)
		for k in 3:
			batch.add(c + Vector3(1.5, 0.25 + 0.5 * float(k), 1.8), Vector3(0.5, 0.5, 0.5), "cardboard", true, rng.randf())
	if x == 2 and z == 1:
		test_points["p_kitchen"] = c + Vector3(0.0, 0.1, 2.2)
		_speakers.append(PizzeriaProps.speaker(root, batch, c + Vector3(0.0, 2.9, -2.9)))


func _office(root: Node3D, batch: LevelKit.BoxBatch, f: int, c: Vector3, rng: RandomNumberGenerator) -> void:
	_add_desk(root, f, c + Vector3(1.4, 0.0, -1.8), 0.0)
	test_points["p_desk1"] = desks[desks.size() - 1].spot()
	batch.add(c + Vector3(-2.4, 0.6, -2.3), Vector3(0.8, 1.2, 0.8), "steel_dark")  # the safe
	batch.add(c + Vector3(-1.98, 0.6, -2.3), Vector3(0.05, 0.3, 0.3), "brass", false)
	batch.add(c + Vector3(-2.4, 1.0, 1.5), Vector3(0.8, 2.0, 1.2), "cabinet")
	batch.add(c + Vector3(-1.0, 0.5, 2.2), Vector3(0.2, 1.0, 0.2), "pot", true)
	_poster(root, c, Vector3(0.0, 0.0, -1.0), rng)
	_sign(root, "MANAGER'S OFFICE\nTHE CAMERAS ARE IN HERE", c + Vector3(0.0, 2.0, 2.88), PI)


func _lift_room(root: Node3D, _batch: LevelKit.BoxBatch, c: Vector3) -> void:
	var lever := c + Vector3(2.6, 0.0, 2.2)
	stage_lift = StageLift.create("StageLift", c + Vector3(0.0, -0.15 + 0.01, 0.0), FLOOR_H, lever)
	stage_lift.bind_power(get_power, drain_power)
	root.add_child(stage_lift)
	_sign(root, "STAGE LIFT\nHOLD THE LEVER. 3 RIDE.\nTHE LAST ONE GETS HOISTED.", c + Vector3(0.0, 2.1, 2.88), PI)
	test_points["p_lift"] = c + Vector3(0.0, 0.1, 0.0)
	test_points["p_lever"] = lever


func _sound_booth(root: Node3D, batch: LevelKit.BoxBatch, f: int, c: Vector3) -> void:
	_add_desk(root, f, c + Vector3(1.5, 0.0, 1.2), 0.0)
	test_points["p_desk2"] = desks[desks.size() - 1].spot()
	batch.add(c + Vector3(-1.5, 0.5, -2.2), Vector3(3.0, 1.0, 0.9), "steel_dark")  # mixing console
	for k in 12:
		batch.add(c + Vector3(-2.8 + 0.24 * float(k), 1.02, -2.2), Vector3(0.04, 0.05, 0.6), "white", false)
		batch.add(c + Vector3(-2.8 + 0.24 * float(k), 1.04, -2.0 + 0.08 * float(k % 4)), Vector3(0.06, 0.04, 0.06), "hazard", false)
	for k in 2:
		batch.add(c + Vector3(-2.4 + 1.6 * float(k), 1.9, -2.6), Vector3(0.5, 0.7, 0.4), "speaker")
	_speakers.append(PizzeriaProps.speaker(root, batch, c + Vector3(0.0, 3.0, -2.9)))
	_sign(root, "SOUND BOOTH\nLAST CAMERA DESK", c + Vector3(0.0, 2.3, 2.88), PI)


func _audience_cell(root: Node3D, batch: LevelKit.BoxBatch, x: int, z: int, c: Vector3, rng: RandomNumberGenerator) -> void:
	if z == 2:
		PizzeriaProps.table(root, batch, c + Vector3(-1.4, 0.0, 1.0), rng, 3)
		PizzeriaProps.table(root, batch, c + Vector3(1.5, 0.0, 1.6), rng, 3)
	else:
		PizzeriaProps.table(root, batch, c + Vector3(-1.2, 0.0, -1.2), rng)
		PizzeriaProps.table(root, batch, c + Vector3(1.6, 0.0, 1.4), rng)
	if x == 2 and z == 2:
		test_points["p_floor"] = c + Vector3(0.0, 0.1, 1.0)
	if x == 1 and z == 3:
		_poster(root, c, Vector3(0.0, 0.0, 1.0), rng)


func _build_room_lights(root: Node3D, batch: LevelKit.BoxBatch, f: int, rng: RandomNumberGenerator) -> void:
	var ceil_h: float = CEIL_HS[f]
	for z in ROWS:
		for x in COLS:
			var r := room_at(f, Vector2i(x, z))
			if r == "." or (f == 2 and r == "S"):
				continue
			var c := cell_center(f, x, z)
			var drop := 0.9 if (r == "D" or r == "P" or r == "V" or r == "A") else 0.05
			var color := Color(1.0, 0.75, 0.5)
			var energy := 0.8
			var kind := 0
			if f == 1 or r == "L" or r == "N" or r == "S" or r == "Y" or r == "U":
				color = Color(0.9, 0.95, 0.85)  # kitchen fluorescents
				energy = 0.95
				kind = 1 if rng.randf() < 0.3 else 0
			if r == "R" or r == "B" or r == "E":
				color = Color(0.95, 0.96, 0.88)
				energy = 1.3
			if r == "W" or r == "X":
				kind = 2 if rng.randf() < 0.5 else 1
			var at := c + Vector3(0.0, ceil_h - drop, 0.0)
			if (f == 0 and r == "R") or (f == 2 and r == "Q") or (f == 1 and r == "T"):
				at += Vector3(-2.0, 0.0, -2.0)  # off the shaft
			elif f == 0 and r == "U":
				at += Vector3(2.0, 0.0, 2.0)  # the dumbwaiter is in the other corner
			var parts := PizzeriaProps.pendant(root, batch, at, c.y + ceil_h, color, energy)
			var hum := Sfx.loop_player("hum", -26.0, 8.0)
			hum.position = at
			root.add_child(hum)
			_lights.register(parts[0], parts[1], checkpoint_base + f, kind, hum)


func _build_signs(root: Node3D, batch: LevelKit.BoxBatch, f: int) -> void:
	# Green route signs over the doorways on the way to this floor's climb, like the office.
	var routes: Array = [
		[[0, 3, 0, 2], [1, 2, 1, 1], [1, 1, 1, 0]],
		[[0, 0, 1, 0], [1, 0, 1, 1], [1, 1, 1, 2], [1, 2, 0, 2]],
		[[0, 3, 0, 2], [0, 2, 1, 2]],  # the stage itself has its own CLIMB THE CASE sign
	]
	var names: Array[String] = ["DUMBWAITER", "STAGE LIFT", "ROOF ACCESS"]
	var base := _origin.y + float(f) * FLOOR_H
	for e in routes[f]:
		var a := Vector2i(int(e[0]), int(e[1]))
		var b := Vector2i(int(e[2]), int(e[3]))
		var out := Vector3(float(b.x - a.x), 0.0, float(b.y - a.y))
		var kind := _edge_kind(f, a, b)
		var at := cell_center(f, a.x, a.y) + out * (CELL * 0.5 - WALL_T * 0.5 - 0.03)
		at.y = base + (DOOR_H + 0.45 if (kind == Conn.DOOR or kind == Conn.SHUTTER) else 2.5)
		if f == 2 and a.y >= 2 and b.y < 2:
			at.y = base + 2.6
		var yaw := atan2(-out.x, -out.z)
		var plate := Vector3(1.25, 0.36, 0.03) if absf(out.z) > 0.5 else Vector3(0.03, 0.36, 1.25)
		batch.add(at - out * 0.01, plate, "sign_green", false)
		var l := Label3D.new()
		l.text = "%s\nTHIS WAY" % names[f]
		l.font_size = 32
		l.pixel_size = 0.0042
		l.modulate = Color(0.95, 1.0, 0.95)
		l.outline_size = 0
		l.double_sided = false
		l.position = at - out * 0.03
		l.rotation = Vector3(0.0, yaw, 0.0)
		root.add_child(l)


func _sign(root: Node3D, text: String, at: Vector3, yaw: float, color: Color = Color(1.0, 0.82, 0.15)) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 40
	l.pixel_size = 0.005
	l.modulate = color
	l.outline_size = 10
	l.double_sided = false
	l.position = at
	l.rotation = Vector3(0.0, yaw, 0.0)
	root.add_child(l)


func _poster(root: Node3D, c: Vector3, normal: Vector3, rng: RandomNumberGenerator) -> void:
	var along := Vector3(normal.z, 0.0, normal.x)
	var pos := c - normal * 2.88 + along * (1.6 if rng.randf() < 0.5 else -1.6) + Vector3(0.0, 1.75, 0.0)
	var paper := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.9, 0.62, 0.01)
	paper.mesh = pm
	var colors := [Color(0.95, 0.9, 0.8), Color(0.85, 0.25, 0.2), Color(0.2, 0.55, 0.3), Color(0.95, 0.8, 0.2)]
	var col: Color = colors[rng.randi() % colors.size()]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.8
	paper.material_override = mat
	var basis := Basis.looking_at(-normal, Vector3.UP)
	paper.transform = Transform3D(basis, pos)
	root.add_child(paper)
	var label := Label3D.new()
	label.text = POSTERS[rng.randi() % POSTERS.size()]
	label.font_size = 34
	label.pixel_size = 0.0045
	label.modulate = Color(0.08, 0.06, 0.05) if col.get_luminance() > 0.5 else Color(1.0, 0.97, 0.9)
	label.outline_size = 0
	label.double_sided = false
	label.transform = Transform3D(basis, pos + normal * 0.012)
	root.add_child(label)


func _build_scare_triggers(root: Node3D, f: int) -> void:
	var list: Array = []
	match f:
		0:
			list = [["order_window", test_points.get("p_pass", Vector3.ZERO), Vector3(3.5, 2.4, 3.0)]]
		2:
			var stage: Vector3 = test_points["p_stage"]
			list = [["curtain", Vector3(stage.x, stage.y, stage.z + 4.5), Vector3(20.0, 2.4, 2.5)],
				["costume_rack", test_points.get("p_rack", Vector3.ZERO), Vector3(5.0, 2.4, 5.0)],
				["birthday_song", test_points.get("p_party", Vector3.ZERO), Vector3(5.0, 2.4, 5.0)]]
	for s in list:
		var at: Vector3 = s[1]
		var t := ScareTrigger.create("ScareP%d_%s" % [f, s[0]], at + Vector3(0.0, 1.2, 0.0), s[2], s[0])
		root.add_child(t)


func _build_checkpoint(root: Node3D, f: int) -> void:
	var cell: Vector2i = [Vector2i(0, 4), Vector2i(1, 0), Vector2i(0, 2)][f]
	var c := cell_center(f, cell.x, cell.y)
	var respawn := c + Vector3(0.0, 0.1, -2.3) if f == 0 else c + Vector3(0.0, 0.1, 0.0)
	# Yaw 0 looks toward -z: out of the car toward the Host Stand; Coat Check faces its door (+x).
	var facing := 0.0 if f == 0 else (PI * 0.5 if f == 1 else -PI * 0.5)
	var cp := Checkpoint.create("CheckpointP%d" % f, checkpoint_base + f, respawn, facing, OBJECTIVES[f])
	cp.area_center = c
	root.add_child(cp)
	test_points["p_checkpoint%d" % (checkpoint_base + f)] = respawn


# --- Server -------------------------------------------------------------------------------------------

func server_populate() -> void:
	for f in FLOORS:
		var spots: Array = []
		match f:
			0:
				spots = [cell_center(0, 0, 3) + Vector3(1.0, 0.1, 0.0), cell_center(0, 2, 1) + Vector3(0.0, 0.1, 0.0),
					cell_center(0, 5, 2) + Vector3(-1.0, 0.1, 0.0), cell_center(0, 0, 1) + Vector3(0.0, 0.1, 0.0)]
			1:
				spots = [cell_center(1, 1, 0) + Vector3(0.0, 0.1, -1.0), cell_center(1, 3, 1) + Vector3(0.0, 0.1, 2.0),
					cell_center(1, 5, 2) + Vector3(0.0, 0.1, 0.0), cell_center(1, 3, 3) + Vector3(0.0, 0.1, 0.0)]
			_:
				spots = [cell_center(2, 0, 2) + Vector3(1.0, 0.1, 0.0), cell_center(2, 2, 3) + Vector3(0.0, 0.1, 0.0),
					cell_center(2, 0, 1) + Vector3(1.0, 0.1, 0.0), cell_center(2, 5, 3) + Vector3(-1.5, 0.1, 0.0)]
		var loot: Array = FLOOR_LOOT[f]
		for k in loot.size():
			Net.spawn_pickup(loot[k], spots[k % spots.size()], 0)


func get_power() -> float:
	return power


func drain_power(amount: float) -> void:
	power = maxf(0.0, power - amount)


func set_jukebox(on: bool) -> void:
	if not multiplayer.is_server() or jukebox_on == on:
		return
	jukebox_on = on
	if not on:
		_rpc_jukebox_stop.rpc()


@rpc("authority", "call_local", "reliable")
func _rpc_jukebox_stop() -> void:
	GameState.post_message_local("...the jukebox stopped.", 2.5)
	Sfx.caption(self, "the jukebox stops", Vector3.INF)


## Server: after a layoff, everything on this level resets round the checkpoint.
func server_on_layoff() -> void:
	power = POWER_MAX
	if dumbwaiter != null:
		dumbwaiter.server_reset()
	if stage_lift != null:
		stage_lift.server_reset()
	set_jukebox(true)
	_exit_t = -1.0


## Server: the Line was put back at its checkpoint (layoff or regroup): Pappy goes home.
func server_on_respawn() -> void:
	if pappy != null and GameState.checkpoint_index >= checkpoint_base:
		var f := line_floor_for_checkpoint()
		pappy.debug_reset(f, home_node(f))


func line_floor_for_checkpoint() -> int:
	return clampi(GameState.checkpoint_index - checkpoint_base, 0, FLOORS - 1)


func _physics_process(delta: float) -> void:
	_tick_jukebox()
	if not multiplayer.is_server() or GameState.escaped:
		return
	var players := Net.get_players()
	if not anyone_here():
		return
	night_seconds += delta
	# Power: the cameras drain it; the lift drains it; a Break Room restarts the generator.
	var was_out := power <= 0.0
	for d in desks:
		if d.is_live():
			power = maxf(0.0, power - SecurityDesk.DRAIN_PER_SECOND * delta)
	if power <= 0.0 and not was_out:
		_rpc_power_out.rpc()
	_lights.blackout = power <= 0.0
	_tick_generator(delta, players)
	# The Counter Bell: the first time anyone clips into the Host Stand.
	if not _first_desk_seen and not desks.is_empty() and desks[0].is_live():
		_first_desk_seen = true
		var who := desks[0].occupant()
		if who != null:
			ScareDirector.trigger("counter_bell", _bell_pos, who.peer_id)
	_tick_exit(delta)


func _tick_generator(delta: float, players: Array[Player]) -> void:
	var best := 0.0
	for p in players:
		var f := floor_of(p.global_position.y)
		var r := room_at(f, cell_of(p.global_position))
		var in_break := (r == "R" or r == "B" or r == "E") and p.global_position.y > _origin.y - 0.5
		if in_break and power < POWER_MAX - 0.5:
			var t: float = float(_gen_player_t.get(p.peer_id, 0.0)) + delta
			_gen_player_t[p.peer_id] = t
			best = maxf(best, t / GENERATOR_SECONDS)
			if t >= GENERATOR_SECONDS:
				power = POWER_MAX
				_gen_player_t.clear()
				_rpc_generator.rpc(p.display_name)
				best = 0.0
				break
		else:
			_gen_player_t.erase(p.peer_id)
	generator_t = clampf(best, 0.0, 1.0)


func _tick_exit(delta: float) -> void:
	if _exit_area == null:
		return
	if _exit_t < 0.0:
		var bodies := Net.get_chain_bodies()
		if bodies.is_empty():
			return
		var inside := _exit_area.get_overlapping_bodies()
		for b in bodies:
			if not inside.has(b):
				return
		_exit_t = 0.0
		_rpc_exit_fx.rpc()
		GameState.post_message("Everyone's on the loft. The hatch is opening. Don't look back.", 3.0)
		return
	_exit_t += delta
	if _exit_t >= EXIT_DELAY:
		GameState.set_escaped()


@rpc("authority", "call_local", "reliable")
func _rpc_exit_fx() -> void:
	var at: Vector3 = test_points["p_loft"]
	Sfx.play_at(self, "shutter", at + Vector3.UP * 2.0, 0.0, 0.7)
	Sfx.play_at(self, "ding", at + Vector3.UP * 2.0, 2.0, 1.1)


@rpc("authority", "call_local", "reliable")
func _rpc_power_out() -> void:
	Sfx.play(self, "slam", 0.0, 0.4)
	Sfx.play(self, "static", -4.0, 0.5)
	GameState.post_message_local("POWER OUT. Cameras dead, lift locked. He doesn't need the lights. Restart the generator in a Break Room.", 6.0)
	var me := Net.get_local_player()
	if me != null:
		me.add_shake(0.5)


@rpc("authority", "call_local", "reliable")
func _rpc_generator(who: String) -> void:
	Sfx.play(self, "lift", -6.0, 1.4)
	Sfx.play(self, "ding", -4.0, 0.9)
	GameState.post_message_local("%s restarted the generator. POWER 100%%." % who, 3.0)


# --- Every peer --------------------------------------------------------------------------------------

func set_ambience(on: bool) -> void:
	_ambience = on
	_tick_jukebox()


func _tick_jukebox() -> void:
	var play := _ambience and jukebox_on and Time.get_ticks_msec() >= _jukebox_mute_until and not Sfx.is_silent()
	for s in _speakers:
		if play:
			Sfx.start_loop(s)
		elif s.playing:
			s.stop()


func cull_floors(cam_floor: int) -> void:
	for i in FLOORS:
		var root := get_node_or_null("Floor%d" % i) as Node3D
		if root != null:
			root.visible = absi(i - cam_floor) <= 1


## Pizzeria-specific scares, played on every peer (ScareDirector hands off kinds it doesn't know).
func play_scare(kind: String, pos: Vector3, targeted: bool) -> void:
	var me := Net.get_local_player()
	match kind:
		"jukebox_skip":
			_jukebox_mute_until = Time.get_ticks_msec() + 2000
			_tick_jukebox()
			Sfx.play_at(self, "static", pos + Vector3.UP, -8.0, 1.0, 20.0)
		"balloon":
			Sfx.play_at(self, "popper", pos + Vector3.UP * 1.4, 4.0, 1.4, 30.0)
			if targeted and me != null:
				me.add_shake(0.7)
		"vent_patter":
			var top := Vector3(pos.x, ceiling_y(pos) - 0.05, pos.z)
			for k in 5:
				get_tree().create_timer(0.12 * float(k)).timeout.connect(func() -> void:
					if is_inside_tree():
						Sfx.play_at(self, "thump", top + Vector3(float(k) * 0.6, 0.0, 0.0), -8.0, 1.8 + 0.1 * float(k), 20.0))
			var fx := Effects.find(self)
			if fx != null:
				fx.fx_dust_local(top, 24)
			Sfx.caption(self, "feet running in the vent", top)
		"pepperoni_eyes":
			_eyes_flash(pos + Vector3(0.0, 1.5, 0.0), 1.6, false)
			if targeted:
				Sfx.play_at(self, "whisper", pos + Vector3.UP * 1.5, 2.0, 0.8, 16.0)
		"bell":
			for k in 3:
				get_tree().create_timer(0.5 * float(k)).timeout.connect(func() -> void:
					if is_inside_tree():
						Sfx.play_at(self, "bell", _bell_pos, 0.0, 1.0, 40.0))
		"static_face":
			var hud := get_tree().get_first_node_in_group("hud")
			if hud != null and hud.has_method("night_static_face"):
				hud.call("night_static_face")
		"counter_bell":
			for k in 3:
				get_tree().create_timer(0.6 * float(k)).timeout.connect(func() -> void:
					if is_inside_tree():
						Sfx.play_at(self, "bell", _bell_pos, 2.0, 1.0, 40.0))
			get_tree().create_timer(2.0).timeout.connect(func() -> void:
				if not is_inside_tree():
					return
				var d := desks[0] if not desks.is_empty() else null
				if d != null:
					_eyes_flash(d.global_position + Basis.from_euler(Vector3(0.0, d.rotation.y, 0.0)) * Vector3(0.0, 2.3, 1.8), 0.8, true)
				var hud := get_tree().get_first_node_in_group("hud")
				if hud != null and hud.has_method("night_static_face"):
					hud.call("night_static_face")
				if me != null and d != null and me.peer_id == d.occupant_peer:
					Sfx.play(self, "stinger", 0.0)
					me.add_shake(1.0))
		"order_window":
			if _pass_shutter != null:
				var tw := create_tween()
				tw.tween_property(_pass_shutter, "scale:y", 0.08, 0.35)
				tw.tween_interval(6.0)
				tw.tween_property(_pass_shutter, "scale:y", 1.0, 0.8)
			Sfx.play_at(self, "shutter", pos + Vector3.UP * 2.0, 2.0, 1.3, 30.0)
			get_tree().create_timer(0.4).timeout.connect(func() -> void:
				if is_inside_tree():
					_tomato_drop(_pass_shutter.global_position + Vector3(0.0, -0.3, 0.6) if _pass_shutter != null else pos + Vector3.UP * 1.5))
			if targeted and me != null:
				me.add_shake(1.0)
		"curtain":
			for k in _curtains.size():
				var half := _curtains[k]
				var s := -1.0 if k == 0 else 1.0
				var tw := create_tween()
				tw.tween_property(half, "position:x", half.position.x + s * 9.5, 3.5).set_trans(Tween.TRANS_SINE)
				tw.parallel().tween_property(half, "scale:x", 0.25, 3.5)
			for l in _band_lights:
				var tw2 := create_tween()
				tw2.tween_property(l, "light_energy", 1.4, 2.0)
			Sfx.play_at(self, "scrape", pos + Vector3.UP * 3.0, -4.0, 0.5, 40.0)
			get_tree().create_timer(2.5).timeout.connect(func() -> void:
				if is_inside_tree():
					Sfx.play_at(self, "birthday", pos + Vector3(0.0, 2.0, -5.0), -6.0, 0.9, 45.0)
					GameState.post_message_local("The band is playing. His mark is empty.", 3.5))
			_jukebox_mute_until = Time.get_ticks_msec() + 15000
			_tick_jukebox()
		"costume_rack":
			if _suit_head != null:
				var cam := get_viewport().get_camera_3d()
				if cam != null:
					var look := Vector3(cam.global_position.x, _suit_head.global_position.y, cam.global_position.z)
					var yaw := atan2(_suit_head.global_position.x - look.x, _suit_head.global_position.z - look.z)
					var tw := create_tween()
					tw.tween_property(_suit_head, "rotation:y", yaw, 1.2).set_trans(Tween.TRANS_QUAD)
				Sfx.play_at(self, "servo", _suit_head.global_position, 2.0, 0.7, 20.0)
			if targeted and me != null:
				me.add_shake(0.9)
		"birthday_song":
			ScareDirector.blackout(pos, 14.0, 6500)
			var spot := OmniLight3D.new()
			spot.light_color = Color(1.0, 0.9, 0.6)
			spot.light_energy = 2.0
			spot.omni_range = 4.0
			add_child(spot)
			spot.global_position = pos + Vector3.UP * 2.5
			get_tree().create_timer(6.5).timeout.connect(spot.queue_free)
			Sfx.play_at(self, "birthday", pos + Vector3(2.0, 2.0, 0.0), 0.0, 0.85, 40.0)
			get_tree().create_timer(5.6).timeout.connect(func() -> void:
				if is_inside_tree():
					var door := _office_door_pos if _office_door_pos != Vector3.ZERO else pos
					_eyes_flash(door + Vector3(0.0, 2.2, 0.0), 0.9, true)
					Sfx.play(self, "stinger", 0.0)
					if me != null:
						me.add_shake(1.0))
		_:
			pass


## Two pepperoni glints (and a chef's silhouette, for the face) that vanish after a moment.
func _eyes_flash(at: Vector3, seconds: float, with_face: bool) -> void:
	var root := Node3D.new()
	add_child(root)
	root.global_position = at
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		var look := Vector3(cam.global_position.x, at.y, cam.global_position.z)
		if look.distance_to(at) > 0.05:
			root.look_at(look, Vector3.UP)
	for s: float in [-0.14, 0.14]:
		var e := MeshInstance3D.new()
		var em := CylinderMesh.new()
		em.top_radius = 0.07
		em.bottom_radius = 0.07
		em.height = 0.02
		e.mesh = em
		e.position = Vector3(s, 0.0, 0.3)
		e.rotation = Vector3(PI * 0.5, 0.0, 0.0)
		e.material_override = LevelKit.mat("pepperoni")
		root.add_child(e)
	if with_face:
		var black := StandardMaterial3D.new()
		black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		black.albedo_color = Color(0.0, 0.0, 0.0)
		var head := MeshInstance3D.new()
		var hm := SphereMesh.new()
		hm.radius = 0.4
		hm.height = 0.85
		head.mesh = hm
		head.material_override = black
		root.add_child(head)
		var hat := MeshInstance3D.new()
		var hatm := CylinderMesh.new()
		hatm.top_radius = 0.34
		hatm.bottom_radius = 0.24
		hatm.height = 0.5
		hat.mesh = hatm
		hat.position = Vector3(0.0, 0.55, 0.0)
		hat.material_override = black
		root.add_child(hat)
		var body := MeshInstance3D.new()
		var bm := CapsuleMesh.new()
		bm.radius = 0.6
		bm.height = 2.0
		body.mesh = bm
		body.position = Vector3(0.0, -1.4, 0.0)
		body.material_override = black
		root.add_child(body)
		var teeth := MeshInstance3D.new()
		var tm := BoxMesh.new()
		tm.size = Vector3(0.3, 0.06, 0.02)
		teeth.mesh = tm
		teeth.position = Vector3(0.0, -0.2, 0.38)
		teeth.material_override = LevelKit.mat("teeth")
		root.add_child(teeth)
	get_tree().create_timer(seconds).timeout.connect(root.queue_free)


## A Tiny Tomato drops out of the hatch, squeals, and scurries off along the floor.
func _tomato_drop(from: Vector3) -> void:
	var t := Node3D.new()
	add_child(t)
	t.global_position = from
	var body := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.32
	sm.height = 0.6
	body.mesh = sm
	body.material_override = LevelKit.mat("vending")
	t.add_child(body)
	var stem := MeshInstance3D.new()
	var stm := BoxMesh.new()
	stm.size = Vector3(0.25, 0.08, 0.25)
	stem.mesh = stm
	stem.position = Vector3(0.0, 0.32, 0.0)
	stem.material_override = LevelKit.mat("neon_green")
	t.add_child(stem)
	for k in 4:
		var a := TAU * float(k) / 4.0 + 0.4
		var leg := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(0.05, 0.4, 0.05)
		leg.mesh = lm
		leg.position = Vector3(cos(a) * 0.28, -0.25, sin(a) * 0.28)
		leg.rotation = Vector3(sin(a) * 0.5, 0.0, -cos(a) * 0.5)
		leg.material_override = LevelKit.mat("steel_dark")
		t.add_child(leg)
	for s: float in [-0.12, 0.12]:
		var e := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.06
		em.height = 0.12
		e.mesh = em
		e.position = Vector3(s, 0.05, 0.3)
		e.material_override = LevelKit.mat("white")
		t.add_child(e)
	var floor_y := from.y - 1.6
	var cam := get_viewport().get_camera_3d()
	var away := Vector3(1.0, 0.0, 0.0)
	if cam != null:
		away = (from - cam.global_position)
		away.y = 0.0
		away = away.normalized() if away.length() > 0.1 else Vector3(1.0, 0.0, 0.0)
	var tw := create_tween()
	tw.tween_property(t, "global_position", Vector3(from.x, floor_y + 0.4, from.z) + Vector3(0.0, 0.0, 0.0), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(t, "global_position", Vector3(from.x, floor_y + 0.4, from.z) - away * 9.0, 1.4)
	tw.tween_callback(t.queue_free)
	for k in 3:
		get_tree().create_timer(0.2 + 0.25 * float(k)).timeout.connect(func() -> void:
			if is_inside_tree():
				Sfx.play_at(self, "squeak", from, 2.0, 1.6 + 0.2 * float(k), 30.0))
	Sfx.play_at(self, "thump", Vector3(from.x, floor_y, from.z), 0.0, 1.3, 20.0)
	Sfx.caption(self, "something small hits the floor and runs", from)
