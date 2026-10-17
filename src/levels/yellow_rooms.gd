class_name YellowRooms
extends Node3D
## Level 1: The Yellow Rooms. Four floors (B4 at the bottom to B1) of 6 m office cells built
## from a seed the host picks (a new layout every run; the tests use DEFAULT_SEED), so every
## peer builds the identical building before connecting.
## Each floor: a Break Room you arrive in (checkpoint), a maze of halls / cubicles / meeting rooms
## / storage / dark rooms, Hollow Hires walking the halls, loot, scripted scares, and one ascent:
##   B4 crates through a ceiling hole, B3 a plate-and-lift, B2 a shelf shaft (stand on a teammate
##   or use the jetpack), B1 the freight car up to Level 2 (the pizzeria, built right above).
## Lives under LevelStack, which handles layoffs and regroups for the whole building.
## Server only: populates pickups, starts the freight car once everyone is inside.
## The route forces noise and running on every floor: B4 and B1 have a jammed door on the
## path that has to be shouldered open at a sprint (a bang the floor hears), B3's lift is locked
## until the fire alarm is pulled (40 s of the floor awake), B2's shelf-shaft hole is under a
## hatch that stays open 25 s after its release switch two rooms back, and reaching B1's
## freight elevator brings a Hire screaming through the door behind the group. The power on the
## Line's floor stutters out for 12-20 s every 60-90 s; Break Rooms keep their lights.

const CELL: float = 6.0
const GRID: int = 6
const FLOORS: int = 4
const FLOOR_H: float = 5.0
const SLAB: float = 0.4
const CEIL_H: float = 3.2
const WALL_T: float = 0.2
const DOOR_W: float = 1.4
const DOOR_H: float = 2.3
const HOLE: float = 2.6
const CAR_HOLE: float = 3.3  # the freight car's shaft through B1's ceiling
const DEFAULT_SEED: int = 1931
var seed_value: int = DEFAULT_SEED  # set by LevelStack before _ready: the host picks it, joiners get it in the handshake

enum Ascent { CRATES, LIFT, BOOST, ELEVATOR }
enum Conn { NONE, DOOR, OPEN }

const ASCENTS: Array = [Ascent.CRATES, Ascent.LIFT, Ascent.BOOST, Ascent.ELEVATOR]
const FLOOR_NAMES: Array[String] = ["B4", "B3", "B2", "B1"]
const OBJECTIVES: Array[String] = [
	"B4 Orientation: find the maintenance hole in the ceiling and climb to B3. One Hollow Hire walks this floor. If it sees you, run.",
	"B3: the service lift is locked out until the fire alarm is pulled. Then one holds the plate, the lift carries the rest, and the floor is awake.",
	"B2: the shelf shaft is under a hatch. Its release gives you 25 seconds. Stand on a teammate's head, or find the jetpack.",
	"B1: find the freight elevator. Everyone inside to ride it up out of the Yellow Rooms. Don't stop.",
]
const FLOOR_LOOT: Array = [
	["decoy"],  # everyone already clocks in with a flashlight; B4's spare is the decoy
	["pistol", "drink", "decoy"],
	["flashlight", "bomb", "drink"],
	["bomb", "decoy", "ammo"],
]
const POSTERS: Array[String] = [
	"SAFETY IS A\nTEAM SPORT", "HOLD ON TO\nEACH OTHER", "IF YOU HEAR IT,\nIT HEARS YOU",
	"QUIET IS\nPROFESSIONAL", "REPORT ALL\nCEILING STAINS", "DO NOT\nLOOK UP", "THE LINE IS\nYOUR FRIEND",
	"RUNNING IN THE\nHALLS IS LOUD", "YOU ARE BEING\nASSESSED", "BRACE FOR\nSYNERGY",
]
## Procedural scares that fit an office: [kind, weight].
const SCARE_POOL: Array = [
	["lights_out", 2], ["tile", 2], ["whisper", 2], ["slam", 2], ["figure", 2], ["phone", 1], ["dennis", 1],
	["breath", 2], ["footsteps", 2], ["stalker", 1],
]
## What to do on each floor, ticked off on the HUD. [text, ...]; completion is checked in
## _tick_tasks.
const TASKS: Array = [
	["Follow the green signs to MAINTENANCE ACCESS", "Shoulder the jammed door open (sprint into it)", "Climb the crates up through the ceiling (walk into one, tap Space)"],
	["Pull the FIRE ALARM (hold Ctrl at it): it releases the lift", "Find the SERVICE LIFT", "One of you stands on the yellow plate: the lift rises", "Hoist the plate-holder up on the chain"],
	["Throw the HATCH RELEASE (hold Ctrl at it): 25 seconds", "Run to the SHELF SHAFT: jetpack, or stack up on a teammate", "Everyone up through the hatch before it slams"],
	["Find the FREIGHT ELEVATOR", "Shoulder the jammed door open (sprint into it)", "Everyone inside before they catch you: it rides up to the pizzeria"],
]
const HIRES_PER_FLOOR: Array[int] = [1, 1, 3, 3]  # B3 mixes one runner with the original ceiling hunter
const RESPAWN_SECONDS: float = 45.0  # a dead Hire is replaced after this, out of sight
const DOOR_FLOORS: Array[int] = [0, 3]  # floors with a jammed door on the route
const ALARM_FLOOR: int = 1  # the lift floor: locked out until the fire alarm is pulled
const HATCH_FLOOR: int = 2  # the shelf shaft floor: its hole is under the timed hatch
const AMBUSH_FLOOR: int = 3  # reaching this floor's climb room brings a Hire through the door behind you
const STUTTER_MIN: float = 60.0  # s between power stutters on the Line's floor
const STUTTER_MAX: float = 90.0
const STUTTER_DARK_MIN: float = 12.0  # s the floor stays dark (Break Rooms excepted)
const STUTTER_DARK_MAX: float = 20.0
const CALLOUT_MESSAGE_GAP_MS: int = 12000
const SCRIPTED_SCARES: Array = [
	[[2, "footsteps"], [4, "dennis"]],
	[[2, "lights_out"], [4, "phone"]],
	[[2, "lunge"], [4, "whisper"]],
	[[2, "tile"], [4, "figure"]],
]

var spawn_position: Vector3 = Vector3.ZERO
var spawn_facing: float = PI
var test_points: Dictionary = {}
var floors: Array = []  # per floor: {arrive, ascent, conn, types, path}
var _lights: LightController
var _exit_area: Area3D
var _car: FreightCar
var _jetpack_check_t: float = 0.0
var _boost_jetpack_pos: Vector3 = Vector3.ZERO
var _drone: AudioStreamPlayer
var _pending_signs: Array = []
var _tasks_floor: int = -1
var _hire_respawn_t: Array[float] = [RESPAWN_SECONDS, RESPAWN_SECONDS, RESPAWN_SECONDS, RESPAWN_SECONDS]
var _doors: Dictionary = {}  # floor -> StuckDoor
var _alarm: AlarmPull
var _hatch: TimedHatch
var _door_done: Dictionary = {}  # floor -> true once its jammed door was shouldered (task tick)
var _hatch_thrown: bool = false
var _ambush_armed: bool = true
var _stutter_t: float = 45.0  # the first stutter comes a little sooner than the steady gap
var _callout_msec: int = -100000
var _stutter_rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_lights = LightController.new()
	_lights.name = "Lights"
	add_child(_lights)
	_generate_layout()
	for i in FLOORS:
		_build_floor(i)
	_drone = AudioStreamPlayer.new()
	_drone.stream = Sfx.stream("drone")
	_drone.volume_db = -14.0
	add_child(_drone)
	Sfx.start_loop(_drone)
	_stutter_rng.randomize()


# --- Layout ---------------------------------------------------------------------------------

func _generate_layout() -> void:
	var arrive := Vector2i(0, 2)
	for i in FLOORS:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value + i * 101
		var conn := _carve_maze(arrive, rng)
		var dist := _bfs(arrive, conn)
		var ascent := arrive
		var best := -1
		for c in dist:
			var d: int = dist[c]
			if c != arrive and (d > best or (d == best and rng.randf() < 0.5)):
				best = d
				ascent = c
		var path := _path(arrive, ascent, conn)
		var types: Dictionary = {}
		var kinds := ["hall", "cubicles", "cubicles", "meeting", "storage", "hall", "dark", "cubicles"]
		for x in GRID:
			for z in GRID:
				var c := Vector2i(x, z)
				types[c] = kinds[rng.randi() % kinds.size()]
		types[arrive] = "breakroom"
		types[ascent] = "ascent"
		floors.append({"arrive": arrive, "ascent": ascent, "conn": conn, "types": types, "path": path, "rng_seed": seed_value * 7 + i})
		arrive = ascent
	var a0: Vector2i = floors[0]["arrive"]
	spawn_position = cell_center(0, a0) + Vector3(0.0, 0.1, -2.2)
	spawn_facing = PI


func _carve_maze(start: Vector2i, rng: RandomNumberGenerator) -> Dictionary:
	var conn: Dictionary = {}
	var visited: Dictionary = {start: true}
	var stack: Array[Vector2i] = [start]
	while not stack.is_empty():
		var cur: Vector2i = stack[stack.size() - 1]
		var options: Array[Vector2i] = []
		for n in _neighbors(cur):
			if not visited.has(n):
				options.append(n)
		if options.is_empty():
			stack.pop_back()
			continue
		var nxt: Vector2i = options[rng.randi() % options.size()]
		conn[_edge_key(cur, nxt)] = Conn.OPEN if rng.randf() < 0.28 else Conn.DOOR
		visited[nxt] = true
		stack.append(nxt)
	# Extra loops so there's more than one way around the thing in the ceiling.
	for x in GRID:
		for z in GRID:
			var c := Vector2i(x, z)
			for n in [Vector2i(x + 1, z), Vector2i(x, z + 1)]:
				if n.x < GRID and n.y < GRID and not conn.has(_edge_key(c, n)) and rng.randf() < 0.2:
					conn[_edge_key(c, n)] = Conn.DOOR
	return conn


func _neighbors(c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = c + d
		if n.x >= 0 and n.y >= 0 and n.x < GRID and n.y < GRID:
			out.append(n)
	return out


func _edge_key(a: Vector2i, b: Vector2i) -> String:
	if a.x < b.x or (a.x == b.x and a.y < b.y):
		return "%d,%d-%d,%d" % [a.x, a.y, b.x, b.y]
	return "%d,%d-%d,%d" % [b.x, b.y, a.x, a.y]


func _bfs(start: Vector2i, conn: Dictionary) -> Dictionary:
	var dist: Dictionary = {start: 0}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for n in _neighbors(cur):
			if not dist.has(n) and conn.has(_edge_key(cur, n)):
				dist[n] = int(dist[cur]) + 1
				queue.append(n)
	return dist


func _path(a: Vector2i, b: Vector2i, conn: Dictionary) -> Array[Vector2i]:
	var prev: Dictionary = {a: a}
	var queue: Array[Vector2i] = [a]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		if cur == b:
			break
		for n in _neighbors(cur):
			if not prev.has(n) and conn.has(_edge_key(cur, n)):
				prev[n] = cur
				queue.append(n)
	var path: Array[Vector2i] = []
	var c := b
	while c != a:
		path.push_front(c)
		c = prev[c]
	path.push_front(a)
	return path


# --- Geometry -----------------------------------------------------------------------------------

func cell_center(i: int, c: Vector2i) -> Vector3:
	return Vector3(float(c.x) * CELL + CELL * 0.5, float(i) * FLOOR_H, float(c.y) * CELL + CELL * 0.5)


func floor_of(y: float) -> int:
	return clampi(int(floor((y + 0.6) / FLOOR_H)), 0, FLOORS - 1)


func cell_of(p: Vector3) -> Vector2i:
	return Vector2i(clampi(int(floor(p.x / CELL)), 0, GRID - 1), clampi(int(floor(p.z / CELL)), 0, GRID - 1))


## False where a climb hole is cut through this floor's ceiling (nothing falls from there),
## and inside the freight car.
func has_ceiling_at(p: Vector3) -> bool:
	var i := floor_of(p.y)
	var hole_c: Vector2i = floors[i]["ascent"]
	var center := cell_center(i, hole_c)
	var half := (CAR_HOLE if ASCENTS[i] == Ascent.ELEVATOR else HOLE) * 0.5 + 0.3
	return not (absf(p.x - center.x) < half and absf(p.z - center.z) < half)


## Break Rooms are safe: the Hires stop at the door. So is the inside of the freight car (they
## stand at its open front and stare while the last of you gets in).
func is_safe_spot(p: Vector3) -> bool:
	var i := floor_of(p.y)
	if i < 0 or i >= floors.size():
		return false
	var types: Dictionary = floors[i]["types"]
	if String(types.get(cell_of(p), "")) == "breakroom":
		return true
	if i == FLOORS - 1 and _car != null:
		var c := elevator_center()
		var half := FreightCar.WIDTH * 0.5 - 0.15
		return absf(p.x - c.x) < half and absf(p.z - c.z) < half
	return false


## Floor-level center of the freight car on B1 (the pizzeria is built around the shaft above it).
func elevator_center() -> Vector3:
	return cell_center(FLOORS - 1, floors[FLOORS - 1]["ascent"])


## Local: hide floors far from the camera (they're behind concrete anyway).
func cull_floors(cam_floor: int) -> void:
	for i in FLOORS:
		var root := get_node_or_null("Floor%d" % i) as Node3D
		if root != null:
			root.visible = absi(i - cam_floor) <= 1


func set_ambience(on: bool) -> void:
	if _drone == null:
		return
	if on:
		Sfx.start_loop(_drone)
	else:
		_drone.stop()


func _build_floor(i: int) -> void:
	var root := Node3D.new()
	root.name = "Floor%d" % i
	add_child(root)
	var batch := LevelKit.BoxBatch.new()
	var f: Dictionary = floors[i]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(f["rng_seed"])
	var base := float(i) * FLOOR_H
	var arrive: Vector2i = f["arrive"]
	var ascent: Vector2i = f["ascent"]
	var types: Dictionary = f["types"]
	var conn: Dictionary = f["conn"]
	var floor_hole := i > 0  # the arrive cell has the hole you climbed up through
	var hole_size: float = CAR_HOLE if ASCENTS[i] == Ascent.ELEVATOR else HOLE
	for x in GRID:
		for z in GRID:
			var c := Vector2i(x, z)
			var center := cell_center(i, c)
			if floor_hole and c == arrive:
				_holed_slab(batch, center + Vector3(0.0, -SLAB * 0.5, 0.0), SLAB, "carpet")
				_hazard_ring(batch, center + Vector3(0.0, 0.006, 0.0))
			else:
				batch.add(center + Vector3(0.0, -SLAB * 0.5, 0.0), Vector3(CELL, SLAB, CELL), "carpet")
			if c == ascent:
				_holed_slab(batch, center + Vector3(0.0, CEIL_H + 0.025, 0.0), 0.05, "ceiling", hole_size)
				_hole_lining(batch, center, base, hole_size)
			else:
				batch.add(center + Vector3(0.0, CEIL_H + 0.025, 0.0), Vector3(CELL, 0.05, CELL), "ceiling")
	_build_walls(batch, i, conn)
	_build_signs(root)
	for x in GRID:
		for z in GRID:
			var c := Vector2i(x, z)
			var t: String = types[c]
			var center := cell_center(i, c)
			var holed := (floor_hole and c == arrive) or c == ascent  # keep lights clear of holes and the elevator
			_add_light(root, batch, i, center, t, holed, rng)
			_ceiling_details(batch, center, holed, rng)
			_wall_details(batch, i, c, center, conn, rng)
			match t:
				"breakroom":
					_breakroom(root, batch, i, c, center, rng)
				"ascent":
					_ascent(root, batch, i, c, center)
				"cubicles":
					_cubicles(root, batch, center, rng)
				"meeting":
					_meeting(root, batch, center, rng)
				"storage", "dark":
					_storage(batch, center, rng)
				_:
					_hall(root, batch, center, rng)
			if t != "ascent" and t != "breakroom" and rng.randf() < 0.35:
				_poster(root, i, c, rng)
	_dennis(root, batch, i, rng)
	_wayfinding(root, batch, i)
	batch.build(root, "F%d" % i)
	_build_hires(i)
	_build_events(root, i)
	_build_scare_triggers(root, i)
	if i > 0:
		var cp := Checkpoint.create("Checkpoint%d" % i, i, cell_center(i, arrive) + Vector3(0.0, 0.1, -2.2), PI, OBJECTIVES[i])
		cp.area_center = cell_center(i, arrive)
		root.add_child(cp)
		test_points["checkpoint%d" % i] = cell_center(i, arrive) + Vector3(0.0, 0.1, -2.2)


## A slab with a hole x hole opening in the middle (4 strips).
func _holed_slab(batch: LevelKit.BoxBatch, center: Vector3, thickness: float, key: String, hole: float = HOLE) -> void:
	var side := (CELL - hole) * 0.5
	var off := hole * 0.5 + side * 0.5
	batch.add(center + Vector3(-off, 0.0, 0.0), Vector3(side, thickness, CELL), key)
	batch.add(center + Vector3(off, 0.0, 0.0), Vector3(side, thickness, CELL), key)
	batch.add(center + Vector3(0.0, 0.0, -off), Vector3(hole, thickness, side), key)
	batch.add(center + Vector3(0.0, 0.0, off), Vector3(hole, thickness, side), key)


func _hazard_ring(batch: LevelKit.BoxBatch, center: Vector3) -> void:
	var r := HOLE * 0.5 + 0.12
	for k in 4:
		var horizontal := k < 2
		var s := -1.0 if k % 2 == 0 else 1.0
		var pos := center + (Vector3(0.0, 0.0, s * r) if horizontal else Vector3(s * r, 0.0, 0.0))
		var size := Vector3(HOLE + 0.48, 0.01, 0.2) if horizontal else Vector3(0.2, 0.01, HOLE + 0.48)
		batch.add(pos, size, "hazard", false)


## Concrete walls lining the hole through the plenum, so the shaft is solid to climb against.
func _hole_lining(batch: LevelKit.BoxBatch, center: Vector3, base: float, hole: float = HOLE) -> void:
	var h := FLOOR_H - CEIL_H
	var y := base + CEIL_H + h * 0.5
	var e := hole * 0.5 + 0.05
	batch.add(Vector3(center.x - e, y, center.z), Vector3(0.1, h, hole + 0.2), "concrete")
	batch.add(Vector3(center.x + e, y, center.z), Vector3(0.1, h, hole + 0.2), "concrete")
	batch.add(Vector3(center.x, y, center.z - e), Vector3(hole, h, 0.1), "concrete")
	batch.add(Vector3(center.x, y, center.z + e), Vector3(hole, h, 0.1), "concrete")


func _build_walls(batch: LevelKit.BoxBatch, i: int, conn: Dictionary) -> void:
	var base := float(i) * FLOOR_H
	var y := base + CEIL_H * 0.5
	var span := float(GRID) * CELL
	# Exterior shell.
	for k in GRID:
		var a := float(k) * CELL + CELL * 0.5
		batch.add(Vector3(a, y, 0.0), Vector3(CELL + WALL_T, CEIL_H, WALL_T), "wall")
		batch.add(Vector3(a, y, span), Vector3(CELL + WALL_T, CEIL_H, WALL_T), "wall")
		batch.add(Vector3(0.0, y, a), Vector3(WALL_T, CEIL_H, CELL + WALL_T), "wall")
		batch.add(Vector3(span, y, a), Vector3(WALL_T, CEIL_H, CELL + WALL_T), "wall")
	for x in GRID:
		for z in GRID:
			var c := Vector2i(x, z)
			if x + 1 < GRID:
				var kx: int = conn.get(_edge_key(c, Vector2i(x + 1, z)), Conn.NONE)
				_wall(batch, Vector3(float(x + 1) * CELL, y, float(z) * CELL + CELL * 0.5), false, kx, base)
			if z + 1 < GRID:
				var kz: int = conn.get(_edge_key(c, Vector2i(x, z + 1)), Conn.NONE)
				_wall(batch, Vector3(float(x) * CELL + CELL * 0.5, y, float(z + 1) * CELL), true, kz, base)


## A wall on a cell edge. along_x: the wall runs along x (it separates z neighbors).
func _wall(batch: LevelKit.BoxBatch, center: Vector3, along_x: bool, kind: int, base: float) -> void:
	if kind == Conn.OPEN:
		# A dropped soffit marks the old wall line without blocking anything.
		var soffit := Vector3(CELL, 0.35, WALL_T) if along_x else Vector3(WALL_T, 0.35, CELL)
		batch.add(Vector3(center.x, base + CEIL_H - 0.175, center.z), soffit, "wall")
		return
	if kind == Conn.NONE:
		batch.add(center, Vector3(CELL + WALL_T, CEIL_H, WALL_T) if along_x else Vector3(WALL_T, CEIL_H, CELL + WALL_T), "wall")
		return
	var seg := (CELL - DOOR_W) * 0.5
	var off := DOOR_W * 0.5 + seg * 0.5
	var dir := Vector3(1.0, 0.0, 0.0) if along_x else Vector3(0.0, 0.0, 1.0)
	var seg_size := Vector3(seg + WALL_T * 0.5, CEIL_H, WALL_T) if along_x else Vector3(WALL_T, CEIL_H, seg + WALL_T * 0.5)
	batch.add(center - dir * off, seg_size, "wall")
	batch.add(center + dir * off, seg_size, "wall")
	var lintel_h := CEIL_H - DOOR_H
	var lintel := Vector3(DOOR_W, lintel_h, WALL_T) if along_x else Vector3(WALL_T, lintel_h, DOOR_W)
	batch.add(Vector3(center.x, base + DOOR_H + lintel_h * 0.5, center.z), lintel, "wall")
	# Door frame trim.
	var jamb := Vector3(0.08, DOOR_H, WALL_T + 0.06) if along_x else Vector3(WALL_T + 0.06, DOOR_H, 0.08)
	for s: float in [-1.0, 1.0]:
		batch.add(Vector3(center.x, base + DOOR_H * 0.5, center.z) + dir * s * (DOOR_W * 0.5 + 0.04), jamb, "trim", false)
	var head := Vector3(DOOR_W + 0.16, 0.08, WALL_T + 0.06) if along_x else Vector3(WALL_T + 0.06, 0.08, DOOR_W + 0.16)
	batch.add(Vector3(center.x, base + DOOR_H + 0.04, center.z), head, "trim", false)
	var normal := Vector3(0.0, 0.0, 1.0) if along_x else Vector3(1.0, 0.0, 0.0)
	# Light switch beside the frame, on one face.
	var sw_side := 1.0 if _hash(center + Vector3(2.1, 0.0, 0.3)) < 0.5 else -1.0
	var plate := Vector3(0.08, 0.12, 0.016) if along_x else Vector3(0.016, 0.12, 0.08)
	batch.add(Vector3(center.x, base + 1.2, center.z) + dir * (DOOR_W * 0.5 + 0.28) + normal * sw_side * (WALL_T * 0.5 + 0.008), plate, "wallplate", false)
	# Some doorways keep their door, swung open against the wall.
	if _hash(center) < 0.45:
		var side := 1.0 if _hash(center + Vector3(1.7, 0.0, 3.1)) < 0.5 else -1.0
		var hinge_s := 1.0 if _hash(center + Vector3(5.3, 0.0, 0.7)) < 0.5 else -1.0
		var hinge := Vector3(center.x, base, center.z) + dir * hinge_s * (DOOR_W * 0.5 - 0.02) + normal * side * (WALL_T * 0.5 + 0.03)
		var ang := deg_to_rad(80.0 + 25.0 * _hash(center + Vector3(0.9, 0.0, 8.8)))
		var leaf_dir := (-dir * hinge_s * cos(ang) + normal * side * sin(ang)).normalized()
		var rot := atan2(-leaf_dir.z, leaf_dir.x)
		batch.add(hinge + leaf_dir * 0.34 + Vector3(0.0, 1.11, 0.0), Vector3(0.68, 2.2, 0.045), "door", true, rot)
		var leaf_n := Vector3(-leaf_dir.z, 0.0, leaf_dir.x)
		for s: float in [-1.0, 1.0]:
			batch.add(hinge + leaf_dir * 0.6 + Vector3(0.0, 1.0, 0.0) + leaf_n * s * 0.045, Vector3(0.1, 0.025, 0.03), "fixture", false, rot)
	# A few glowing EXIT signs over doorways (built later with their light and lettering).
	if _hash(center + Vector3(7.7, 0.0, 2.2)) < 0.16:
		var at := Vector3(center.x, base + DOOR_H + 0.3, center.z)
		batch.add(at, Vector3(0.44, 0.17, WALL_T + 0.1) if along_x else Vector3(WALL_T + 0.1, 0.17, 0.44), "exit_sign", false)
		_pending_signs.append([at, normal])


## Deterministic 0..1 from a position, so every peer decorates the same doorways.
func _hash(p: Vector3) -> float:
	var h := sin(p.x * 12.9898 + p.y * 4.1414 + p.z * 78.233) * 43758.5453
	return h - floorf(h)


func _build_signs(root: Node3D) -> void:
	for s in _pending_signs:
		var at: Vector3 = s[0]
		var n: Vector3 = s[1]
		for side: float in [-1.0, 1.0]:
			var l := Label3D.new()
			l.text = "EXIT"
			l.font_size = 30
			l.pixel_size = 0.0042
			l.modulate = Color(1.0, 0.95, 0.9)
			l.outline_size = 0
			l.double_sided = false
			l.position = at + n * side * (WALL_T * 0.5 + 0.052)
			l.rotation = Vector3(0.0, atan2(n.x * side, n.z * side), 0.0)
			root.add_child(l)
		var glow := OmniLight3D.new()
		glow.light_color = Color(1.0, 0.15, 0.08)
		glow.light_energy = 0.7
		glow.omni_range = 2.6
		glow.position = at - Vector3(0.0, 0.25, 0.0)
		root.add_child(glow)
	_pending_signs.clear()


## Ceiling clutter: a return-air vent and a smoke detector, away from the light and any hole.
func _ceiling_details(batch: LevelKit.BoxBatch, center: Vector3, holed: bool, rng: RandomNumberGenerator) -> void:
	if holed:
		return
	var y := center.y + CEIL_H - 0.01
	var vent := center + Vector3(1.8 * (1.0 if rng.randf() < 0.5 else -1.0), 0.0, 1.5 * (1.0 if rng.randf() < 0.5 else -1.0))
	batch.add(Vector3(vent.x, y, vent.z), Vector3(0.6, 0.02, 0.6), "vent", false)
	batch.add(Vector3(vent.x, y - 0.006, vent.z), Vector3(0.48, 0.02, 0.48), "dark", false)
	for k in 5:
		batch.add(Vector3(vent.x, y - 0.012, vent.z - 0.2 + 0.1 * float(k)), Vector3(0.48, 0.012, 0.018), "vent", false)
	var det := center + Vector3(-vent.x + center.x, 0.0, -0.9 * signf(vent.z - center.z)) * 0.5
	batch.add(Vector3(det.x, y - 0.02, det.z), Vector3(0.12, 0.04, 0.12), "white", false)


## Outlets low on the walls, off-center so they never sit in a doorway.
func _wall_details(batch: LevelKit.BoxBatch, i: int, c: Vector2i, center: Vector3, conn: Dictionary, rng: RandomNumberGenerator) -> void:
	for k in 2:
		var side := rng.randi() % 4
		var normal: Vector3 = [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)][side]
		var nb := c - Vector2i(int(normal.x), int(normal.z))
		if nb.x >= 0 and nb.y >= 0 and nb.x < GRID and nb.y < GRID:
			if int(conn.get(_edge_key(c, nb), Conn.NONE)) == Conn.OPEN:
				continue
		var along := Vector3(normal.z, 0.0, normal.x)
		var at := center - normal * (CELL * 0.5 - WALL_T * 0.5 - 0.008) + along * rng.randf_range(1.2, 2.4) * (1.0 if rng.randf() < 0.5 else -1.0)
		var size := Vector3(0.08, 0.12, 0.016) if absf(normal.z) > 0.5 else Vector3(0.016, 0.12, 0.08)
		batch.add(Vector3(at.x, float(i) * FLOOR_H + 0.32, at.z), size, "wallplate", false)


## A potted office plant: a tapered pot and clumps of leaves, slightly droopy from neglect.
func _plant(root: Node3D, batch: LevelKit.BoxBatch, at: Vector3, rng: RandomNumberGenerator) -> void:
	batch.add(at + Vector3(0.0, 0.25, 0.0), Vector3(0.38, 0.5, 0.38), "pot")  # collision + base
	var pot := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.24
	pm.bottom_radius = 0.17
	pm.height = 0.52
	pot.mesh = pm
	pot.position = at + Vector3(0.0, 0.26, 0.0)
	pot.material_override = LevelKit.mat("pot")
	root.add_child(pot)
	var soil := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.22
	sm.bottom_radius = 0.22
	sm.height = 0.02
	soil.mesh = sm
	soil.position = at + Vector3(0.0, 0.5, 0.0)
	soil.material_override = LevelKit.mat("dark")
	root.add_child(soil)
	var leaf := StandardMaterial3D.new()
	leaf.albedo_color = Color(0.13, 0.28, 0.1)
	leaf.roughness = 0.6
	for k in 7:
		var clump := MeshInstance3D.new()
		var cm := SphereMesh.new()
		cm.radius = rng.randf_range(0.14, 0.22)
		cm.height = cm.radius * 1.3
		cm.radial_segments = 12
		cm.rings = 6
		clump.mesh = cm
		var a := TAU * float(k) / 7.0 + rng.randf_range(-0.3, 0.3)
		var rr := rng.randf_range(0.05, 0.22)
		clump.position = at + Vector3(cos(a) * rr, rng.randf_range(0.65, 1.15), sin(a) * rr)
		clump.rotation = Vector3(rng.randf_range(-0.5, 0.5), a, rng.randf_range(-0.5, 0.5))
		clump.material_override = leaf
		root.add_child(clump)


func _office_chair(batch: LevelKit.BoxBatch, pos: Vector3, yaw: float) -> void:
	var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
	batch.add(pos + Vector3(0.0, 0.47, 0.0), Vector3(0.48, 0.08, 0.46), "fabric", true, yaw)
	batch.add(pos - fwd * 0.24 + Vector3(0.0, 0.8, 0.0), Vector3(0.44, 0.52, 0.06), "fabric", false, yaw)
	batch.add(pos - fwd * 0.2 + Vector3(0.0, 0.58, 0.0), Vector3(0.05, 0.2, 0.05), "plastic", false, yaw)
	batch.add(pos + Vector3(0.0, 0.26, 0.0), Vector3(0.05, 0.38, 0.05), "metal", false)
	for k in 5:
		var a := yaw + TAU * float(k) / 5.0
		var d := Vector3(cos(a), 0.0, -sin(a))
		batch.add(pos + d * 0.16 + Vector3(0.0, 0.07, 0.0), Vector3(0.32, 0.035, 0.045), "plastic", false, a)
		batch.add(pos + d * 0.31 + Vector3(0.0, 0.03, 0.0), Vector3(0.05, 0.05, 0.05), "plastic", false)


func _add_light(root: Node3D, batch: LevelKit.BoxBatch, i: int, center: Vector3, t: String, holed: bool, rng: RandomNumberGenerator) -> void:
	var at := center + (Vector3(-1.9, 0.0, -1.9) if holed else Vector3.ZERO)
	var kind := 0
	var r := rng.randf()
	# Dark rooms are dead; storage is dying; of the rest, close to half are flickering, dying or
	# dead, so the floor is pools of light with dark between them and a flashlight is the way
	# across. Break Rooms and the climbs stay lit so the route always reads.
	if t == "dark":
		kind = 3 if r < 0.75 else 2
	elif t == "storage":
		kind = 2 if r < 0.6 else (3 if r < 0.75 else 1)
	elif t != "breakroom" and t != "ascent":
		if r < 0.2:
			kind = 1
		elif r < 0.36:
			kind = 2
		elif r < 0.44:
			kind = 3
	var panel := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(1.2, 0.04, 0.6)
	panel.mesh = pm
	panel.material_override = LevelKit.mat("glow")
	panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	panel.position = at + Vector3(0.0, CEIL_H - 0.02, 0.0)
	root.add_child(panel)
	# Troffer frame: a metal lip round the diffuser.
	var fy := at.y + CEIL_H - 0.025
	batch.add(Vector3(at.x, fy, at.z - 0.32), Vector3(1.28, 0.05, 0.04), "fixture", false)
	batch.add(Vector3(at.x, fy, at.z + 0.32), Vector3(1.28, 0.05, 0.04), "fixture", false)
	batch.add(Vector3(at.x - 0.62, fy, at.z), Vector3(0.04, 0.05, 0.6), "fixture", false)
	batch.add(Vector3(at.x + 0.62, fy, at.z), Vector3(0.04, 0.05, 0.6), "fixture", false)
	var light := OmniLight3D.new()
	light.position = at + Vector3(0.0, CEIL_H - 0.35, 0.0)
	light.omni_range = 8.0
	light.omni_attenuation = 1.4
	light.light_energy = 0.85 if t != "breakroom" else 1.5
	light.light_color = Color(1.0, 0.9, 0.66) if t != "breakroom" else Color(0.95, 0.96, 0.88)
	light.light_volumetric_fog_energy = 0.6
	light.light_specular = 0.35
	light.light_size = 0.45  # soft shadow penumbra, like a wide tube fixture
	light.shadow_blur = 1.2
	root.add_child(light)
	var hum := Sfx.loop_player("hum", -22.0, 9.0)
	hum.position = panel.position
	root.add_child(hum)
	_lights.register(light, panel, i, kind, hum, t == "breakroom")


# --- Rooms ---------------------------------------------------------------------------------

func _quadrants() -> Array[Vector3]:
	return [Vector3(-1.75, 0.0, -1.75), Vector3(1.75, 0.0, -1.75), Vector3(-1.75, 0.0, 1.75), Vector3(1.75, 0.0, 1.75)]


func _cubicles(root: Node3D, batch: LevelKit.BoxBatch, center: Vector3, rng: RandomNumberGenerator) -> void:
	for q in _quadrants():
		if rng.randf() > 0.85:
			continue
		var p := center + q
		var sx := signf(q.x)
		var sz := signf(q.z)
		# L-shaped partition on the outer sides of the quadrant.
		batch.add(p + Vector3(0.0, 0.65, sz * 0.95), Vector3(1.9, 1.3, 0.06), "partition")
		batch.add(p + Vector3(sx * 0.95, 0.65, 0.0), Vector3(0.06, 1.3, 1.9), "partition")
		var desk := p + Vector3(0.0, 0.0, sz * 0.5)
		batch.add(desk + Vector3(0.0, 0.73, 0.0), Vector3(1.5, 0.04, 0.75), "desk")
		batch.add(desk + Vector3(0.0, 0.7, 0.0), Vector3(1.46, 0.03, 0.71), "desk_leg", false)
		batch.add(desk + Vector3(-0.7, 0.36, 0.0), Vector3(0.04, 0.7, 0.68), "desk_leg")
		batch.add(desk + Vector3(0.7, 0.36, 0.0), Vector3(0.04, 0.7, 0.68), "desk_leg")
		batch.add(desk + Vector3(0.0, 0.45, sz * 0.33), Vector3(1.36, 0.5, 0.02), "desk_leg", false)  # modesty panel
		# Monitor on a stand, keyboard, mouse, a mug.
		var on := rng.randf() < 0.35
		var mon := desk + Vector3(rng.randf_range(-0.2, 0.2), 0.0, sz * 0.18)
		batch.add(mon + Vector3(0.0, 1.06, 0.0), Vector3(0.56, 0.34, 0.025), "screen" if on else "screen_off", false)
		batch.add(mon + Vector3(0.0, 1.06, sz * 0.02), Vector3(0.6, 0.38, 0.02), "plastic", false)
		batch.add(mon + Vector3(0.0, 0.84, sz * 0.05), Vector3(0.05, 0.2, 0.04), "plastic", false)
		batch.add(mon + Vector3(0.0, 0.755, sz * 0.05), Vector3(0.24, 0.015, 0.17), "plastic", false)
		batch.add(desk + Vector3(0.0, 0.76, -sz * 0.12), Vector3(0.44, 0.02, 0.14), "plastic", false)
		batch.add(desk + Vector3(0.32, 0.76, -sz * 0.12), Vector3(0.06, 0.025, 0.09), "plastic", false)
		if rng.randf() < 0.5:
			batch.add(desk + Vector3(-0.5, 0.8, rng.randf_range(-0.15, 0.15)), Vector3(0.08, 0.1, 0.08), "mug", false)
		if on:
			var glow := OmniLight3D.new()
			glow.light_color = Color(0.4, 0.6, 1.0)
			glow.light_energy = 0.35
			glow.omni_range = 1.8
			glow.position = mon + Vector3(0.0, 1.0, -sz * 0.2)
			root.add_child(glow)
		_office_chair(batch, p + Vector3(rng.randf_range(-0.3, 0.3), 0.0, -sz * 0.3), (0.0 if sz > 0.0 else PI) + rng.randf_range(-0.7, 0.7))
		# Filing cabinet and a bin under the desk.
		batch.add(desk + Vector3(sx * 0.48, 0.33, 0.02), Vector3(0.42, 0.66, 0.55), "cabinet")
		for h: float in [0.2, 0.45]:
			batch.add(desk + Vector3(sx * 0.48, h, -sz * 0.27), Vector3(0.14, 0.02, 0.02), "plastic", false)
		batch.add(desk + Vector3(-sx * 0.45, 0.17, 0.0), Vector3(0.26, 0.34, 0.26), "plastic", false)
		if rng.randf() < 0.4:
			batch.add(desk + Vector3(rng.randf_range(-0.5, 0.5), 0.76, 0.1), Vector3(0.3, 0.02, 0.22), "paper", false, rng.randf_range(-0.6, 0.6))


func _meeting(root: Node3D, batch: LevelKit.BoxBatch, center: Vector3, rng: RandomNumberGenerator) -> void:
	batch.add(center + Vector3(0.0, 0.74, 0.0), Vector3(3.2, 0.06, 1.2), "desk")
	for x: float in [-1.4, 1.4]:
		batch.add(center + Vector3(x, 0.36, 0.0), Vector3(0.08, 0.72, 0.9), "desk_leg")
	for k in 6:
		var x := -1.1 + float(k % 3) * 1.1
		var z := -1.0 if k < 3 else 1.0
		if rng.randf() < 0.8:
			_office_chair(batch, center + Vector3(x + rng.randf_range(-0.2, 0.2), 0.0, z * 1.15), (PI if z < 0.0 else 0.0) + rng.randf_range(-0.5, 0.5))
	var board := Label3D.new()
	board.text = ["Q3 SYNERGY\n\n   ???", "WHO IS IN\nTHE CEILING", "TEAM BUILDING\n= CHAINS", "DONT\nRUN"][rng.randi() % 4]
	board.font_size = 48
	board.pixel_size = 0.006
	board.modulate = Color(0.15, 0.2, 0.55)
	board.outline_size = 0
	board.double_sided = false
	board.position = center + Vector3(0.0, 1.6, -2.85)  # on the -z wall, text faces +z into the room
	root.add_child(board)
	batch.add(center + Vector3(0.0, 1.6, -2.88), Vector3(1.8, 1.0, 0.03), "white", false)


func _storage(batch: LevelKit.BoxBatch, center: Vector3, rng: RandomNumberGenerator) -> void:
	for q in _quadrants():
		var p := center + q
		if rng.randf() < 0.55:
			# A metal shelf unit with boxes on it.
			var along_x := rng.randf() < 0.5
			var size := Vector3(1.8, 2.0, 0.5) if along_x else Vector3(0.5, 2.0, 1.8)
			var at := p + (Vector3(0.0, 1.0, signf(q.z) * 0.7) if along_x else Vector3(signf(q.x) * 0.7, 1.0, 0.0))
			for h: float in [0.05, 0.7, 1.35, 1.98]:
				batch.add(Vector3(at.x, center.y + h, at.z), Vector3(size.x, 0.04, size.z), "metal")
			for cx: float in [-1.0, 1.0]:
				for cz: float in [-1.0, 1.0]:
					var leg := Vector3(cx * (size.x * 0.5 - 0.03), 0.0, cz * (size.z * 0.5 - 0.03))
					batch.add(Vector3(at.x + leg.x, center.y + 1.0, at.z + leg.z), Vector3(0.04, 2.0, 0.04), "metal")
			for h: float in [0.07, 0.72, 1.37]:
				if rng.randf() < 0.7:
					var bs := rng.randf_range(0.3, 0.5)
					batch.add(Vector3(at.x, center.y + h + bs * 0.5, at.z), Vector3(bs * 1.3, bs, bs), "cardboard", false, rng.randf_range(-0.3, 0.3))
		else:
			var n := rng.randi_range(1, 3)
			var y := 0.0
			for k in n:
				var s := rng.randf_range(0.45, 0.8)
				batch.add(p + Vector3(rng.randf_range(-0.2, 0.2), y + s * 0.5, rng.randf_range(-0.2, 0.2)), Vector3(s, s, s), "cardboard" if k % 2 == 0 else "cardboard_dark", true, rng.randf_range(-0.4, 0.4))
				y += s


func _hall(root: Node3D, batch: LevelKit.BoxBatch, center: Vector3, rng: RandomNumberGenerator) -> void:
	var q: Vector3 = _quadrants()[rng.randi() % 4] * 1.3
	var r := rng.randf()
	if r < 0.3:
		_plant(root, batch, center + q, rng)
	elif r < 0.55:
		batch.add(center + q + Vector3(0.0, 0.55, 0.0), Vector3(0.35, 1.1, 0.35), "white")
		batch.add(center + q + Vector3(0.0, 1.3, 0.0), Vector3(0.3, 0.4, 0.3), "water", false)
	elif r < 0.8:
		# Wet floor sign: two leaning yellow boards.
		batch.add(center + q * 0.6 + Vector3(0.0, 0.32, 0.12), Vector3(0.36, 0.62, 0.03), "sign", false, 0.0)
		batch.add(center + q * 0.6 + Vector3(0.0, 0.32, -0.12), Vector3(0.36, 0.62, 0.03), "sign", false, 0.0)
	# A fire extinguisher on its bracket, on some hall walls.
	if rng.randf() < 0.45:
		var x := 2.82 * (1.0 if rng.randf() < 0.5 else -1.0)
		var at := center + Vector3(x, 0.0, 1.9 * (1.0 if rng.randf() < 0.5 else -1.0))
		batch.add(at + Vector3(0.0, 0.62, 0.0), Vector3(0.15, 0.48, 0.15), "extinguisher", false)
		batch.add(at + Vector3(0.0, 0.9, 0.0), Vector3(0.07, 0.08, 0.07), "plastic", false)
		batch.add(at + Vector3(-signf(x) * 0.0, 0.66, 0.0), Vector3(0.17, 0.04, 0.17), "metal", false)


func _breakroom(root: Node3D, batch: LevelKit.BoxBatch, i: int, c: Vector2i, center: Vector3, rng: RandomNumberGenerator) -> void:
	# Vending machine on the -x wall, away from the door line.
	var vm := center + Vector3(-2.45, 0.0, 1.9)
	batch.add(vm + Vector3(0.0, 0.95, 0.0), Vector3(0.8, 1.9, 0.9), "vending")
	batch.add(vm + Vector3(0.41, 1.15, 0.0), Vector3(0.02, 1.2, 0.7), "vending_glass", false)
	var vlight := OmniLight3D.new()
	vlight.light_color = Color(1.0, 0.7, 0.5)
	vlight.light_energy = 0.6
	vlight.omni_range = 2.5
	vlight.position = vm + Vector3(0.9, 1.2, 0.0)
	root.add_child(vlight)
	# Table and chairs.
	var tb := center + Vector3(1.9, 0.0, 1.9)
	batch.add(tb + Vector3(0.0, 0.74, 0.0), Vector3(1.2, 0.06, 1.2), "desk")
	batch.add(tb + Vector3(0.0, 0.37, 0.0), Vector3(0.12, 0.74, 0.12), "desk_leg")
	for k in 3:
		var a := TAU * float(k) / 3.0 + 0.4
		batch.add(tb + Vector3(cos(a) * 0.95, 0.45, sin(a) * 0.95), Vector3(0.45, 0.08, 0.45), "chair", false, a)
	# Punch clock and posters.
	var clock := Label3D.new()
	clock.text = "PUNCH CLOCK\n%s" % FLOOR_NAMES[i]
	clock.font_size = 40
	clock.pixel_size = 0.005
	clock.modulate = Color(1.0, 0.85, 0.3)
	clock.outline_size = 8
	clock.double_sided = false
	clock.position = center + Vector3(2.88, 1.8, -1.9)
	clock.rotation = Vector3(0.0, -PI * 0.5, 0.0)
	root.add_child(clock)
	batch.add(center + Vector3(2.92, 1.75, -1.9), Vector3(0.06, 0.6, 0.8), "trim", false)
	_poster(root, i, c, rng)
	if i == 0:
		var sign := Label3D.new()
		sign.text = "DEEZ INDUSTRIAL FASTENERS\nORIENTATION DAY\nCHAINS. DEEZ NUTS. TOGETHER."
		sign.font_size = 46
		sign.pixel_size = 0.005
		sign.modulate = Color(0.95, 0.8, 0.25)
		sign.outline_size = 10
		sign.double_sided = false
		sign.position = center + Vector3(-2.88, 2.2, -0.4)  # side wall, clear of the doorway signs
		sign.rotation = Vector3(0.0, PI * 0.5, 0.0)
		root.add_child(sign)
		test_points["spawn"] = spawn_position


func _ascent(root: Node3D, batch: LevelKit.BoxBatch, i: int, c: Vector2i, center: Vector3) -> void:
	var base := float(i) * FLOOR_H
	match ASCENTS[i]:
		Ascent.CRATES:
			batch.add(center + Vector3(-2.0, 0.6, 0.0), Vector3(1.2, 1.2, 1.2), "cardboard")
			batch.add(center + Vector3(-0.6, 1.1, 0.0), Vector3(1.2, 2.2, 1.2), "metal")
			batch.add(center + Vector3(0.6, 1.6, 0.0), Vector3(1.2, 3.2, 1.2), "metal")
			for h: float in [0.6, 1.4, 2.2, 3.0]:
				batch.add(center + Vector3(0.6, h, -0.61), Vector3(1.2, 0.08, 0.02), "hazard", false)
			_sign(root, "MAINTENANCE ACCESS\nCLIMB ->", center + Vector3(-2.88, 2.0, 0.0), PI * 0.5)
			test_points["crates_start"] = center + Vector3(-2.0, 0.1, -1.4)  # in front of the first crate, facing +z
			test_points["crates"] = [center + Vector3(-2.0, 1.25, 0.0), center + Vector3(-0.6, 2.25, 0.0), center + Vector3(0.6, 3.25, 0.0)]
			# The cable tray: an optional 0.5 m ledge hung from the ceiling at 1.9 m, a step from the
			# first crate, with a stash at its far end. Narrow enough that the chain decides it.
			var tray_y := 1.9
			var tray_z := -1.2
			batch.add(center + Vector3(0.2, tray_y - 0.03, tray_z), Vector3(5.2, 0.06, 0.5), "metal")
			batch.add(center + Vector3(0.2, tray_y + 0.001, tray_z), Vector3(5.2, 0.005, 0.5), "hazard", false)
			for k in 4:
				var hx := -1.6 + 1.2 * float(k)
				batch.add(center + Vector3(hx, tray_y + (CEIL_H - tray_y) * 0.5, tray_z), Vector3(0.04, CEIL_H - tray_y, 0.04), "steel_dark", false)
			batch.add(center + Vector3(2.5, tray_y + 0.08, tray_z), Vector3(0.6, 0.1, 0.4), "cardboard", false)
			_sign(root, "CABLE TRAY\nNOT A WALKWAY", center + Vector3(1.5, 2.65, -2.88), 0.0)
			test_points["tray_start"] = center + Vector3(-1.9, tray_y + 0.1, tray_z)
			test_points["tray_end"] = center + Vector3(2.4, tray_y + 0.1, tray_z)
		Ascent.LIFT:
			var plate := PressurePlate.create("PlateLift", center + Vector3(-2.0, 0.0, -2.0))
			plate.enabled = i != ALARM_FLOOR  # locked out until the fire alarm releases it
			root.add_child(plate)
			var lift := LiftPlatform.create("Lift", center + Vector3(0.0, base - 0.15 + 0.01, 0.0), base - 0.15 + 0.01, base + FLOOR_H - 0.15, plate, Vector3(2.3, 0.3, 2.3))
			root.add_child(lift)
			_sign(root, "SERVICE LIFT\nONE ON THE PLATE" if i != ALARM_FLOOR else "SERVICE LIFT\nLOCKED OUT: PULL THE\nFIRE ALARM TO RELEASE", center + Vector3(-2.88, 2.0, -0.5), PI * 0.5)
			test_points["plate"] = center + Vector3(-2.0, 0.1, -2.0)
			test_points["lift"] = center + Vector3(0.0, base + 0.1, 0.0)
			test_points["lift_top_edge"] = center + Vector3(0.0, base + FLOOR_H + 0.1, -HOLE * 0.5 - 0.45)
		Ascent.BOOST:
			batch.add(center + Vector3(0.0, 0.6, -2.0), Vector3(1.2, 1.2, 1.2), "cardboard")
			batch.add(center + Vector3(0.0, 1.3, -0.6), Vector3(2.4, 2.6, 1.2), "metal")
			for h: float in [0.9, 1.8, 2.5]:
				batch.add(center + Vector3(0.0, h, -1.21), Vector3(2.4, 0.08, 0.02), "hazard", false)
			_sign(root, "SHELF SHAFT\nTOO TALL? STAND ON\nA COLLEAGUE" if i != HATCH_FLOOR else "SHELF SHAFT\nHATCH ABOVE: RELEASE\nIS TWO ROOMS BACK", center + Vector3(0.0, 2.2, -2.88), 0.0)
			_boost_jetpack_pos = center + Vector3(2.0, 0.1, 2.0)
			test_points["boost_shelf"] = center + Vector3(0.0, 2.7, -0.6)
		Ascent.ELEVATOR:
			_build_elevator(root, batch, i, center)


func _sign(root: Node3D, text: String, at: Vector3, yaw: float) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 40
	l.pixel_size = 0.005
	l.modulate = Color(1.0, 0.82, 0.15)
	l.outline_size = 10
	l.double_sided = false
	l.position = at
	l.rotation = Vector3(0.0, yaw, 0.0)
	root.add_child(l)


func _poster(root: Node3D, _i: int, c: Vector2i, rng: RandomNumberGenerator) -> void:
	# Pick a wall side and hang it off-center so it never covers a doorway.
	var side := rng.randi() % 4
	var center := cell_center(_i, c)
	var normal: Vector3 = [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)][side]
	var nb := c - Vector2i(int(normal.x), int(normal.z))
	if nb.x >= 0 and nb.y >= 0 and nb.x < GRID and nb.y < GRID:
		if int(floors[_i]["conn"].get(_edge_key(c, nb), Conn.NONE)) == Conn.OPEN:
			return  # open-plan side: there is no wall to hang it on
	var along := Vector3(normal.z, 0.0, normal.x)
	var pos := center - normal * 2.88 + along * (1.9 if rng.randf() < 0.5 else -1.9) + Vector3(0.0, 1.65, 0.0)
	var paper := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.9, 0.62, 0.01)
	paper.mesh = pm
	var colors := [Color(0.9, 0.88, 0.78), Color(0.85, 0.3, 0.25), Color(0.3, 0.45, 0.75), Color(0.95, 0.8, 0.2)]
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
	label.font_size = 36
	label.pixel_size = 0.0045
	label.modulate = Color(0.08, 0.06, 0.05) if col.get_luminance() > 0.5 else Color(1.0, 0.97, 0.9)
	label.outline_size = 0
	label.double_sided = false
	label.transform = Transform3D(basis, pos + normal * 0.012)
	root.add_child(label)


## Dennis from Accounts: a cardboard Employee-of-the-Month standee, once per floor, somewhere wrong.
func _dennis(root: Node3D, _batch: LevelKit.BoxBatch, i: int, rng: RandomNumberGenerator) -> void:
	var f: Dictionary = floors[i]
	var options: Array[Vector2i] = []
	for c in f["types"]:
		if f["types"][c] != "ascent" and f["types"][c] != "breakroom":
			options.append(c)
	if options.is_empty():
		return
	var c: Vector2i = options[rng.randi() % options.size()]
	var pos := cell_center(i, c) + Vector3(rng.randf_range(-0.4, 0.4), 0.0, 1.1)
	root.add_child(ScareDirector.build_dennis(pos, rng.randf() * TAU))


func _build_elevator(root: Node3D, _batch: LevelKit.BoxBatch, _i: int, center: Vector3) -> void:
	# Centered in its cell with a 1.5 m corridor all round, so any doorway can reach the open front.
	_car = FreightCar.create("FreightCar", center, FLOOR_H)
	root.add_child(_car)
	var w := FreightCar.WIDTH
	_exit_area = Area3D.new()
	_exit_area.name = "ExitArea"
	_exit_area.collision_layer = 0
	_exit_area.collision_mask = ChainBody.LAYER_BODIES
	var es := CollisionShape3D.new()
	var eb := BoxShape3D.new()
	eb.size = Vector3(w - 0.2, 2.5, w - 0.2)
	es.shape = eb
	es.position = Vector3(0.0, 1.25, 0.0)
	_exit_area.add_child(es)
	_exit_area.position = center
	root.add_child(_exit_area)
	test_points["exit"] = center + Vector3(0.0, 0.1, 0.0)


## The floor's Hollow Hires: HIRES_PER_FLOOR of them, started in cells well away from the Break
## Room you arrive in. A dead one is replaced after RESPAWN_SECONDS somewhere nobody can see.
func _build_hires(i: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(floors[i]["rng_seed"]) + 77
	var spots := _hire_spawn_cells(i, rng, HIRES_PER_FLOOR[i], Vector3.INF)
	for k in HIRES_PER_FLOOR[i]:
		var h := HollowHire.new()
		h.name = "Hire%d_%d" % [i, k]
		h.level = self
		h.floor_index = i
		h.floor_y = float(i) * FLOOR_H
		h.sentry = k == 0  # the first on each floor keeps to the rooms round the way up
		var c: Vector2i = spots[k % spots.size()]
		h.position = cell_center(i, c) + Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0))
		h.rotation.y = rng.randf() * TAU
		add_child(h)
	if i == ALARM_FLOOR:
		var custodian := Custodian.new()
		custodian.name = "CustodianB3"
		custodian.floor_index = i
		custodian.floor_y = global_position.y + float(i) * FLOOR_H
		custodian.bounds = Rect2(global_position.x, global_position.z, GRID * CELL, GRID * CELL)
		add_child(custodian)


## Cells a Hire can start in: not the Break Room, not the climb, at least three rooms from the
## arrival, and (when a position is given) out of everyone's sight and more than 12 m off.
func _hire_spawn_cells(i: int, rng: RandomNumberGenerator, want: int, _near: Vector3) -> Array[Vector2i]:
	var f: Dictionary = floors[i]
	var dist := _bfs(f["arrive"], f["conn"])
	var out: Array[Vector2i] = []
	var pool: Array[Vector2i] = []
	for c in dist:
		var cell: Vector2i = c
		if cell == f["arrive"] or cell == f["ascent"] or int(dist[cell]) < 3:
			continue
		pool.append(cell)
	if pool.is_empty():
		for c in dist:
			if c != f["arrive"]:
				pool.append(c)
	while out.size() < want and not pool.is_empty():
		var k := rng.randi_range(0, pool.size() - 1)
		out.append(pool[k])
		pool.remove_at(k)
	return out


## The rooms on the green-sign route (the Break Room excepted), arrival first: where the Hires
## patrol, so the Line meets one.
func patrol_cells(i: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if i < 0 or i >= floors.size():
		return out
	var path: Array[Vector2i] = floors[i]["path"]
	for k in range(1, path.size()):
		out.append(path[k])
	return out


## Server: a Hire saw someone and screamed; every other one on the floor answers and comes.
## The tubes on the floor gutter first: you hear it, then the lights tell you it's coming.
func hire_callout(caller: HollowHire, target: Player) -> void:
	if not multiplayer.is_server():
		return
	var answered := 0
	for h in hires_on(caller.floor_index):
		if h != caller and not h.is_dead() and not h.is_hunting():
			h.join_chase(target)
			answered += 1
	if answered > 0:
		_rpc_floor_stutter.rpc(caller.floor_index, 2.2, 1.4, "the lights gutter: something's coming")
		var now := Time.get_ticks_msec()
		if now - _callout_msec > CALLOUT_MESSAGE_GAP_MS:
			_callout_msec = now
			GameState.post_message("IT CALLED THE OTHERS. RUN.", 3.0)


## Server: something loud on a floor (a shouldered door, the alarm, the hatch slamming): every
## Hire there goes to look and stays awake for a while. The lights flicker out ahead of them.
func wake_floor(i: int, pos: Vector3, seconds: float) -> void:
	if not multiplayer.is_server():
		return
	for h in hires_on(i):
		h.alert(pos, seconds)
	_rpc_floor_stutter.rpc(i, 1.6, 1.0, "the lights gutter: they're coming to look")


## Server: the tubes on a floor strobe for a while (the fire alarm).
func floor_strobe(i: int, seconds: float) -> void:
	if multiplayer.is_server():
		_rpc_floor_stutter.rpc(i, seconds, 0.0, "")


## Every peer: flicker, then dark, on one floor (Break Rooms keep their lights).
@rpc("authority", "call_local", "reliable")
func _rpc_floor_stutter(i: int, flicker_s: float, dark_s: float, caption: String) -> void:
	_lights.floor_stutter(i, flicker_s, dark_s)
	if caption != "":
		var me := Net.get_local_player()
		if me != null and floor_of(me.global_position.y) == i:
			Sfx.caption(self, caption, me.global_position + Vector3.UP * 3.0)


## Server: every 60-90 s the power on the Line's floor stutters out for 12-20 s. Not in the
## middle of a chase (that would be unfair, and the Hires already gutter the lights).
func _tick_stutter(delta: float) -> void:
	_stutter_t -= delta
	if _stutter_t > 0.0:
		return
	var players := Net.get_players()
	if players.is_empty() or GameState.checkpoint_index >= FLOORS:
		_stutter_t = 10.0
		return
	var i := floor_of(players[0].global_position.y)
	for h in hires_on(i):
		if h.is_hunting():
			_stutter_t = 8.0
			return
	_stutter_t = _stutter_rng.randf_range(STUTTER_MIN, STUTTER_MAX)
	power_stutter(i, _stutter_rng.randf_range(STUTTER_DARK_MIN, STUTTER_DARK_MAX))


## Server: the floor's tubes flicker for a second and a half, then stay out for `seconds`.
func power_stutter(i: int, seconds: float) -> void:
	if not multiplayer.is_server():
		return
	_rpc_floor_stutter.rpc(i, 1.5, seconds, "the power stutters out")
	_rpc_breaker.rpc(i)


@rpc("authority", "call_local", "reliable")
func _rpc_breaker(i: int) -> void:
	var me := Net.get_local_player()
	if me != null and floor_of(me.global_position.y) == i:
		Sfx.play_at(self, "slam", me.global_position + Vector3(randf_range(-6.0, 6.0), 3.0, randf_range(-6.0, 6.0)), -4.0, 0.5, 30.0)


## Tests: a stutter now, on a floor.
func debug_power_stutter(i: int, seconds: float = 14.0) -> void:
	power_stutter(i, seconds)


func lights() -> LightController:
	return _lights


func stuck_door(i: int) -> StuckDoor:
	return _doors.get(i, null) as StuckDoor


func alarm() -> AlarmPull:
	return _alarm


func hatch() -> TimedHatch:
	return _hatch


func on_door_shouldered(i: int) -> void:
	_door_done[i] = true


func on_hatch_released(_i: int) -> void:
	_hatch_thrown = true


## The route's forced events: a jammed door on the path (B4 and B1), the fire alarm that
## releases B3's lift, and the hatch over B2's shelf shaft with its release two rooms back.
func _build_events(root: Node3D, i: int) -> void:
	var f: Dictionary = floors[i]
	var path: Array[Vector2i] = f["path"]
	var base := float(i) * FLOOR_H
	if i in DOOR_FLOORS:
		var k := _door_edge(i)
		if k >= 0:
			var a: Vector2i = path[k]
			var b: Vector2i = path[k + 1]
			var out := Vector3(float(b.x - a.x), 0.0, float(b.y - a.y))
			var at := cell_center(i, a) + out * (CELL * 0.5)
			at.y = base
			var axis := Vector3(out.z, 0.0, out.x)  # along the doorway
			var door := StuckDoor.create("StuckDoor%d" % i, at, axis, DOOR_W, DOOR_H)
			door.level = self
			door.floor_index = i
			root.add_child(door)
			_doors[i] = door
			test_points["door%d" % i] = at - out * 1.5 + Vector3(0.0, 0.1, 0.0)  # the arrival side, facing the door
			test_points["door%d_axis" % i] = out
	if i == ALARM_FLOOR:
		var c: Vector2i = path[maxi(1, path.size() - 3)]
		var spot := _wall_spot(i, c)
		_alarm = AlarmPull.create("AlarmPull", spot[0], spot[1])
		_alarm.level = self
		_alarm.floor_index = i
		var plate := root.get_node_or_null("PlateLift") as PressurePlate
		if plate != null:
			_alarm.on_pulled = Callable(plate, "set_enabled").bind(true)
		root.add_child(_alarm)
		test_points["alarm"] = spot[0] + spot[1] * 0.6 + Vector3(0.0, 0.1, 0.0)
	if i == HATCH_FLOOR:
		var c: Vector2i = path[maxi(1, path.size() - 3)]
		var spot := _wall_spot(i, c)
		var hole_c := cell_center(i, f["ascent"])
		_hatch = TimedHatch.create("Hatch", hole_c, base + CEIL_H, HOLE, spot[0], spot[1])
		_hatch.level = self
		_hatch.floor_index = i
		root.add_child(_hatch)
		test_points["hatch_switch"] = spot[0] + spot[1] * 0.6 + Vector3(0.0, 0.1, 0.0)
		test_points["hatch"] = hole_c + Vector3(0.0, 0.1, 0.0)


## Which doorway on the route gets the jammed door: a real door (not an open-plan gap) that is
## the only way through, nearest the middle of the path; failing that, any real door on it.
func _door_edge(i: int) -> int:
	var f: Dictionary = floors[i]
	var path: Array[Vector2i] = f["path"]
	var conn: Dictionary = f["conn"]
	var best := -1
	var best_score := -INF
	for k in range(path.size() - 1):
		var a: Vector2i = path[k]
		var b: Vector2i = path[k + 1]
		if int(conn.get(_edge_key(a, b), Conn.NONE)) != Conn.DOOR:
			continue
		var cut := conn.duplicate()
		cut.erase(_edge_key(a, b))
		var bridge := not _bfs(f["arrive"], cut).has(f["ascent"])
		var score := (10.0 if bridge else 0.0) - absf(float(k) - float(path.size() - 1) * 0.5)
		if score > best_score:
			best_score = score
			best = k
	return best


## A wall face in a cell to hang a fixture on: [position at floor level on the face, normal
## into the room]. Picks a side with a real wall and keeps clear of the doorway line.
func _wall_spot(i: int, c: Vector2i) -> Array:
	var conn: Dictionary = floors[i]["conn"]
	var center := cell_center(i, c)
	var sides: Array[Vector3] = [Vector3(-1, 0, 0), Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 0, 1)]
	for side in sides:
		var nb := c + Vector2i(int(side.x), int(side.z))
		var inside := nb.x >= 0 and nb.y >= 0 and nb.x < GRID and nb.y < GRID
		if inside and int(conn.get(_edge_key(c, nb), Conn.NONE)) == Conn.OPEN:
			continue
		var along := Vector3(side.z, 0.0, side.x)
		var pos: Vector3 = center + side * (CELL * 0.5 - WALL_T * 0.5) + along * 1.7
		return [Vector3(pos.x, center.y, pos.z), -side]
	return [center + Vector3(-CELL * 0.5 + WALL_T * 0.5, 0.0, 1.7), Vector3(1, 0, 0)]


## Server: the first player into B1's elevator room brings a Hire through the door behind them,
## screaming (which calls the rest). Once per visit; a layoff re-arms it.
func _tick_ambush() -> void:
	if not _ambush_armed or GameState.checkpoint_index != AMBUSH_FLOOR or Engine.get_physics_frames() % 5 != 0:
		return
	var f: Dictionary = floors[AMBUSH_FLOOR]
	var ascent: Vector2i = f["ascent"]
	var victim: Player = null
	for p in Net.get_players():
		if p.state == Player.State.NORMAL and floor_of(p.global_position.y) == AMBUSH_FLOOR and cell_of(p.global_position) == ascent:
			victim = p
			break
	if victim == null:
		return
	var hires := hires_on(AMBUSH_FLOOR)
	var pick: HollowHire = null
	for h in hires:
		if not h.is_dead() and (pick == null or (pick.is_hunting() and not h.is_hunting())):
			pick = h
	if pick == null:
		return
	_ambush_armed = false
	var path: Array[Vector2i] = f["path"]
	var before: Vector2i = path[maxi(0, path.size() - 2)]
	var door := (cell_center(AMBUSH_FLOOR, before) + cell_center(AMBUSH_FLOOR, ascent)) * 0.5
	var back := (cell_center(AMBUSH_FLOOR, before) - cell_center(AMBUSH_FLOOR, ascent)).normalized()
	pick.ambush(door + back * 0.9, victim)
	GameState.post_message("BEHIND YOU. Everyone in the elevator. NOW.", 3.0)


## The route between two cells through the doorways (the maze), for the Hires.
func route(i: int, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	if i < 0 or i >= floors.size():
		return []
	var conn: Dictionary = floors[i]["conn"]
	var dist := _bfs(from, conn)
	if not dist.has(to):
		return []
	return _path(from, to, conn)


func is_safe_cell(i: int, c: Vector2i) -> bool:
	if i < 0 or i >= floors.size():
		return false
	var types: Dictionary = floors[i]["types"]
	return String(types.get(c, "")) == "breakroom"


func hires_on(i: int) -> Array[HollowHire]:
	var out: Array[HollowHire] = []
	for h in get_tree().get_nodes_in_group("hire"):
		if h is HollowHire and (h as HollowHire).floor_index == i:
			out.append(h)
	return out


## Server: a dead Hire comes back somewhere out of sight once its timer runs out.
func _tick_hires(delta: float) -> void:
	for i in FLOORS:
		var dead: Array[HollowHire] = []
		for h in hires_on(i):
			if h.is_dead():
				dead.append(h)
		if dead.is_empty():
			_hire_respawn_t[i] = RESPAWN_SECONDS
			continue
		_hire_respawn_t[i] = float(_hire_respawn_t[i]) - delta
		if float(_hire_respawn_t[i]) > 0.0:
			continue
		_hire_respawn_t[i] = RESPAWN_SECONDS
		var h: HollowHire = dead[0]
		var spot := _hidden_cell(i)
		if spot != Vector2i(-1, -1):
			h.respawn_at(cell_center(i, spot))


## A cell on this floor nobody can see into and nobody is near (-1,-1 when there is none).
func _hidden_cell(i: int) -> Vector2i:
	var f: Dictionary = floors[i]
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var cells: Array = f["types"].keys()
	cells.shuffle()
	var space := get_world_3d().direct_space_state
	for c in cells:
		var cell: Vector2i = c
		if cell == f["arrive"] or is_safe_cell(i, cell):
			continue
		var at := cell_center(i, cell) + Vector3(0.0, 1.6, 0.0)
		var ok := true
		for p in Net.get_players():
			if p.global_position.distance_to(at) < 12.0:
				ok = false
				break
			if floor_of(p.global_position.y) != i:
				continue
			var q := PhysicsRayQueryParameters3D.create(p.eye_position(), at, ChainBody.LAYER_WORLD)
			if space.intersect_ray(q).is_empty():
				ok = false
				break
		if ok:
			return cell
	return Vector2i(-1, -1)


## Tests: the next dead Hire on a floor comes back at once.
func debug_force_hire_respawn(i: int) -> void:
	_hire_respawn_t[i] = 0.0
	_tick_hires(0.0)


## Green building signs over the doorways along the route to this floor's way up, so the maze is
## explorable without being a guessing game. Every other room, plus always the last doorway.
func _wayfinding(root: Node3D, batch: LevelKit.BoxBatch, i: int) -> void:
	var names: Array[String] = ["MAINTENANCE ACCESS", "SERVICE LIFT", "SHELF SHAFT", "FREIGHT ELEVATOR"]
	var path: Array[Vector2i] = floors[i]["path"]
	var conn: Dictionary = floors[i]["conn"]
	var base := float(i) * FLOOR_H
	for k in range(path.size() - 1):
		if k % 2 == 1 and k != path.size() - 2:
			continue
		var a: Vector2i = path[k]
		var b: Vector2i = path[k + 1]
		var out := Vector3(float(b.x - a.x), 0.0, float(b.y - a.y))  # from room a toward the doorway
		var kind: int = conn.get(_edge_key(a, b), Conn.NONE)
		var at := cell_center(i, a) + out * (CELL * 0.5 - WALL_T * 0.5 - 0.03)
		at.y = base + (DOOR_H + 0.45 if kind == Conn.DOOR else CEIL_H - 0.55)
		var yaw := atan2(-out.x, -out.z)  # face back into room a
		var along := Vector3(out.z, 0.0, out.x)
		var plate := Vector3(1.25, 0.36, 0.03) if absf(out.z) > 0.5 else Vector3(0.03, 0.36, 1.25)
		batch.add(at - out * 0.01, plate, "sign_green", false)
		if kind == Conn.OPEN:
			batch.add(at + Vector3(0.0, 0.3, 0.0) + along * 0.3, Vector3(0.015, 0.3, 0.015), "metal", false)
			batch.add(at + Vector3(0.0, 0.3, 0.0) - along * 0.3, Vector3(0.015, 0.3, 0.015), "metal", false)
		var l := Label3D.new()
		l.text = "%s\nTHIS WAY" % names[i]
		l.font_size = 32
		l.pixel_size = 0.0042
		l.modulate = Color(0.95, 1.0, 0.95)
		l.outline_size = 0
		l.double_sided = false
		l.position = at - out * 0.03
		l.rotation = Vector3(0.0, yaw, 0.0)
		root.add_child(l)


func _build_scare_triggers(root: Node3D, i: int) -> void:
	var path: Array[Vector2i] = floors[i]["path"]
	for entry in SCRIPTED_SCARES[i]:
		var idx: int = entry[0]
		if idx >= path.size() - 1:
			idx = maxi(1, path.size() - 2)
		var c: Vector2i = path[idx]
		var at := cell_center(i, c)
		var t := ScareTrigger.create("Scare%d_%s" % [i, entry[1]], at + Vector3(0.0, 1.2, 0.0), Vector3(5.0, 2.4, 5.0), entry[1])
		root.add_child(t)
		test_points["scare_%d_%s" % [i, entry[1]]] = at


# --- Server --------------------------------------------------------------------------------------

## Spawns every pickup through the network spawner (call once on the server after hosting).
func server_populate() -> void:
	for i in FLOORS:
		var f: Dictionary = floors[i]
		var path: Array[Vector2i] = f["path"]
		var loot: Array = FLOOR_LOOT[i]
		for k in loot.size():
			var idx := clampi(1 + int(float(k + 1) * float(path.size() - 2) / float(loot.size() + 1)), 1, maxi(1, path.size() - 2))
			var c: Vector2i = path[idx]
			Net.spawn_pickup(loot[k], cell_center(i, c) + Vector3(0.0, 0.1, 1.0), 0)
	if _boost_jetpack_pos != Vector3.ZERO:
		Net.spawn_pickup("jetpack", _boost_jetpack_pos, 0)
	if test_points.has("tray_end"):
		var te: Vector3 = test_points["tray_end"]
		Net.spawn_pickup("drink", te + Vector3(-0.4, 0.0, 0.0), 0)
		Net.spawn_pickup("ammo", te + Vector3(0.2, 0.0, 0.0), 0)
	# Spare rounds for the Snubby, one box per floor after the first, off the main path.
	for i in range(1, FLOORS):
		var f: Dictionary = floors[i]
		var path: Array[Vector2i] = f["path"]
		var c: Vector2i = path[maxi(1, path.size() / 2)]
		Net.spawn_pickup("ammo", cell_center(i, c) + Vector3(-1.2, 0.1, -1.2), 0)
	_tasks_floor = -1


## The HUD checklist for the floor the Line is on (by its last checkpoint), ticked as it's done.
func _tick_tasks() -> void:
	if GameState.checkpoint_index >= FLOORS:
		return  # upstairs: the pizzeria keeps its own list
	var i := clampi(GameState.checkpoint_index, 0, FLOORS - 1)
	if i != _tasks_floor:
		_tasks_floor = i
		GameState.set_tasks(PackedStringArray(TASKS[i]))
	if Engine.get_physics_frames() % 10 != 0:
		return
	var players := Net.get_players()
	match i:
		0:
			if _anyone_near("crates_start", players, 5.0):
				GameState.complete_task(0)
			if _door_done.get(0, false):
				GameState.complete_task(1)
		1:
			if _alarm != null and _alarm.pulled:
				GameState.complete_task(0)
			if _anyone_near("plate", players, 5.0):
				GameState.complete_task(1)
			var lift := get_node_or_null("Floor1/Lift") as LiftPlatform
			if lift != null and lift.position.y >= lift.high_y - 0.05:
				GameState.complete_task(2)
		2:
			if _hatch_thrown:
				GameState.complete_task(0)
			if _anyone_near("boost_shelf", players, 5.0):
				GameState.complete_task(1)
		3:
			if _anyone_near("exit", players, 5.0):
				GameState.complete_task(0)
			if _door_done.get(3, false):
				GameState.complete_task(1)
			if _car != null and _car.phase != FreightCar.Phase.WAITING:
				GameState.complete_task(2)
	# A checkpoint above means everything on the floor below was done.
	if GameState.checkpoint_index > i:
		for k in TASKS[i].size():
			GameState.complete_task(k)


func _anyone_near(key: String, players: Array[Player], radius: float) -> bool:
	if not test_points.has(key) or not (test_points[key] is Vector3):
		return false
	var at: Vector3 = test_points[key]
	for p in players:
		if Vector2(p.global_position.x - at.x, p.global_position.z - at.z).length() < radius and absf(p.global_position.y - at.y) < 3.0:
			return true
	return false


## Server: the Line was sent back to a checkpoint. Still in the Yellow Rooms: the car comes back down.
func server_on_respawn() -> void:
	for c in get_tree().get_nodes_in_group("custodian"):
		c.release(false)
	if _car != null and GameState.checkpoint_index < FLOORS:
		_car.server_reset()
	_ambush_armed = true
	# Nobody respawns into a Hire's arms: the ones near the checkpoint go back to a far cell.
	for h in get_tree().get_nodes_in_group("hire"):
		var hire := h as HollowHire
		if hire == null:
			continue
		hire.release(false)
		if not hire.is_dead() and hire.global_position.distance_to(GameState.checkpoint_position) < 16.0:
			var rng := RandomNumberGenerator.new()
			rng.randomize()
			var spots := _hire_spawn_cells(hire.floor_index, rng, 1, Vector3.INF)
			if not spots.is_empty():
				hire.respawn_at(cell_center(hire.floor_index, spots[0]))


func car_busy() -> bool:
	return _car != null and _car.is_busy()


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_jetpack_check_t -= delta
	if _jetpack_check_t <= 0.0:
		_jetpack_check_t = 6.0
		_ensure_boost_jetpack()
	_tick_hires(delta)
	_tick_stutter(delta)
	_tick_ambush()
	_tick_tasks()
	_tick_exit()


## The shelf shaft must stay solvable solo: if no jetpack exists anywhere, put one back.
func _ensure_boost_jetpack() -> void:
	if _boost_jetpack_pos == Vector3.ZERO or GameState.escaped:
		return
	for p in Net.get_players():
		if p.has_item("jetpack"):
			return
	for pk in get_tree().get_nodes_in_group("pickups"):
		if pk.get("item_id") == "jetpack":
			return
	Net.spawn_pickup("jetpack", _boost_jetpack_pos, 0)


## Everyone on the Line inside the freight car: up to the pizzeria.
func _tick_exit() -> void:
	if _exit_area == null or _car == null or _car.phase != FreightCar.Phase.WAITING:
		return
	var bodies := Net.get_chain_bodies()
	if bodies.is_empty():
		return
	var inside := _exit_area.get_overlapping_bodies()
	for b in bodies:
		if not inside.has(b):
			return
	_car.server_start_ride()
	# Whatever was chasing you loses you: it lets go and goes back to its rounds.
	for h in hires_on(FLOORS - 1):
		if h.is_hunting():
			h.release(false)
			h.stun(2.0)
	GameState.post_message("Everyone's in. The doors are closing. Going up.", 3.0)
