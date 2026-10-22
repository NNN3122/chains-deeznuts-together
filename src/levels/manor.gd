class_name Manor
extends HuntGrounds
## Level 4: Ashgrave Manor (the user: "fix four machines to turn on the main generator to open the
## escape gate... a big scary map of a haunted mansion with tombstones and stuff lying around, foggy
## and dark, and a monster chasing us and stopping us fixing the machines"). The estate is a 150 m
## square inside a high stone wall, at night, in a thick low fog: the mansion to the north (ground
## floor open: foyer, dining room, library, parlour, study; low windows you can climb through and
## it can't), the graveyard to the west behind iron railings with the crypt in it, a ruined chapel
## to the south-west, the courtyard with a dry fountain and the main generator in the middle, a
## hedge garden to the south, the dead orchard and a glassless greenhouse to the north-east, and
## the stables to the east where the Line starts. Four old pump engines (ManorMachine) are out
## there: in the library, the crypt, the chapel and the greenhouse. Get all four running (crouch at
## one, hold Ctrl; more of you is faster), throw the main generator's switch, and the south gate
## (ManorGate) grinds open: everyone down the lane past EXIT_Z and you're out.
## The Groundskeeper (a HollowHire kin) walks a grid of the grounds (AStarGrid2D, CELL cells,
## everything solid marked on it with MARGIN round it), patrols the unfinished engines, is sent to
## whichever one is being worked on every DRAW_EVERY seconds, kicks a half-done one it passes (it
## runs back down), and once the gate is open it simply knows where you are. Caught is a layoff
## back to the stables; running engines stay running.
## Built from a seed on every peer like the other levels (only the scatter takes it). Two ways to exist:
##   - in the Stack (LevelStack sets `embedded` and `origin`, far below the building): Level 3's
##     helicopter flies the Line here; the Groundskeeper sleeps and the pickups wait until then;
##   - on its own (--manor, or the title's level button): the "level" with the same surface as
##     LevelStack and HordeArena.
## Everything is built under this node at `origin`, so positions in here are local to the estate;
## what the rest of the game asks (cell_of, cell_center, ceiling_y, test_points...) is in world space.

const FLOOR_NAME: String = "ASHGRAVE MANOR"
const HALF: float = 74.0  # m: the estate wall runs along x and z = +-HALF
const CELL: float = 2.0  # m: the Groundskeeper's grid
const GRID_MIN: float = -75.0  # cell centres fall on even metres, -74 .. 74
const GRID_N: int = 75
const MARGIN: float = 0.3  # m kept clear round anything solid
const WALL_H: float = 3.6
const GATE_Z: float = 74.0
const EXIT_Z: float = 84.0  # past this, down the lane, you're out
const ROOM_H: float = 4.6  # the mansion's ground floor
const UPPER_H: float = 11.0  # its facade, roof starts here
const SPAWN: Vector3 = Vector3(52.0, 0.1, 22.0)
const SPAWN_YAW: float = PI * 0.5  # looking west across the grounds
const KEEPER_HOME: Vector3 = Vector3(-50.0, 0.0, 4.0)  # the graveyard's middle aisle
const DRAW_EVERY: Vector2 = Vector2(14.0, 24.0)  # s between the Groundskeeper being sent to a worked engine
const DRAW_ALERT: float = 14.0  # s it hunts round that engine
const KICK_RANGE: float = 2.6  # m
const KICK_COOLDOWN_MS: int = 30000  # per engine
const RESPAWN_SECONDS: float = 45.0  # a bombed Groundskeeper is back after this, out of sight
const LAYOFF_DELAY: float = 1.1
const REGROUP_COOLDOWN_MS: int = 15000
const ENDGAME_HUNT: float = 9.0  # s between "it knows where you are" once the generator runs
const TASK_ENGINES: int = 0
const TASK_SWITCH: int = 1
const TASK_OUT: int = 2
const TASKS: Array[String] = [
	"Get the four engines running (0 of 4): crouch at one and hold Ctrl",
	"Throw the main generator's switch in the courtyard (hold Ctrl at it)",
	"Out through the south gate and down the lane, together",
]
const SCARE_POOL: Array = [
	["face", 3], ["lunge", 2], ["crawler", 2], ["peek", 2], ["hands", 2], ["behind", 2], ["whisper", 1],
	["figure", 2], ["breath", 2], ["footsteps", 2], ["stalker", 1], ["slam", 1],
]
## The four engines: [position, yaw]. Library, crypt, chapel, greenhouse.
const ENGINE_SPOTS: Array = [
	[Vector3(-17.0, 0.0, -57.0), 0.0],
	[Vector3(-53.0, 0.0, -14.0), PI * 0.5],
	[Vector3(-53.0, 0.0, 40.5), 0.0],
	[Vector3(41.0, 0.0, -62.0), 0.0],
]
const MAIN_SPOT: Vector3 = Vector3(14.0, 0.0, 4.0)
const MANSION: Rect2 = Rect2(-26.0, -62.0, 52.0, 26.0)
const CRYPT: Rect2 = Rect2(-56.0, -19.0, 8.0, 10.0)
const CHAPEL: Rect2 = Rect2(-60.0, 36.0, 22.0, 20.0)
const GRAVEYARD: Rect2 = Rect2(-68.0, -30.0, 34.0, 52.0)
const GREENHOUSE: Rect2 = Rect2(34.0, -66.0, 14.0, 10.0)
const STABLES: Rect2 = Rect2(60.0, 4.0, 12.0, 36.0)

var seed_value: int = YellowRooms.DEFAULT_SEED
var origin: Vector3 = Vector3.ZERO  # world position of the estate's centre at ground level (set before add_child)
var embedded: bool = false  # part of the Stack (LevelStack is the "level"), not a level of its own
var spawn_position: Vector3 = SPAWN
var spawn_facing: float = SPAWN_YAW
var test_points: Dictionary = {}
var machines: Array[ManorMachine] = []  # the four engines
var generator: ManorMachine
var gate: ManorGate
var keeper: Groundskeeper

var _astar: AStarGrid2D
var _batch: LevelKit.BoxBatch
var _root: Node3D
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _we: WorldEnvironment
var _keepout: Array = []  # [Vector2 centre, radius]: the scatter keeps off doors, paths, machines
var _court_lamps: Array = []  # [OmniLight3D, StandardMaterial3D]: dark until the generator runs
var _flickers: Array = []  # [OmniLight3D, StandardMaterial3D, base energy, phase]: candles, dying lamps
var _lamps_on: bool = false
var _t: float = 0.0
var _toll_t: float = 30.0
var _wind: AudioStreamPlayer
var _shown: bool = true  # drawn and heard (in the Stack, only while the camera is down here)
var _populated: bool = false  # server: the estate's pickups are out
var hang_points: Array[Vector3] = []  # where each hanged body's rope is tied (the tour looks at them)
var _hanged: Array = []  # [Node3D pivot at the rope's top, phase, scale]: they sway and turn on every peer
var _fog_banks: Array = []  # [FogVolume, drift m/s]: low banks of fog creeping across the grounds
# Server.
var _arrived: bool = false
var _draw_t: float = 18.0
var _kick_t: float = 0.0
var _kick_cd: Dictionary = {}  # engine index -> msec it may be kicked again
var _respawn_t: float = RESPAWN_SECONDS
var _layoff_pending: bool = false
var _last_layoff_msec: int = -100000
var _last_regroup_msec: int = -100000
var _endgame: bool = false
var _endgame_t: float = 0.0
var _gate_cell_open: bool = false


func _ready() -> void:
	position = origin
	spawn_position = origin + SPAWN
	if not embedded:
		add_to_group("level")
		_we = WorldEnvironment.new()
		_we.name = "WorldEnvironment"
		_we.camera_attributes = LevelKit.make_camera_attributes()
		add_child(_we)
		refresh_environment()
	_rng.seed = seed_value * 5 + 404
	_setup_grid()
	_root = Node3D.new()
	_root.name = "Grounds"
	add_child(_root)
	_batch = LevelKit.BoxBatch.new()
	_build_ground()
	_build_estate_wall()
	_build_mansion()
	_build_graveyard()
	_build_crypt()
	_build_chapel()
	_build_courtyard()
	_build_hedges()
	_build_orchard()
	_build_stables()
	_build_machines()
	_scatter()
	_build_copses()
	_build_hangings()
	_build_grass()
	_build_forest()
	_batch.build(_root, "M")
	_build_fog_banks()
	_build_moon()
	_build_keeper()
	_build_ambience()
	_test_points()
	if embedded:
		set_shown(false)  # the Stack shows it once the camera is down here


func first_objective() -> String:
	return "Ashgrave Manor: four old engines are out on the grounds. Get them all running (crouch at one, hold Ctrl), throw the main generator's switch in the courtyard, and get out through the south gate. Something with a lantern walks the grounds."


# --- The grid the Groundskeeper walks -----------------------------------------------------------

func _setup_grid() -> void:
	_astar = AStarGrid2D.new()
	_astar.region = Rect2i(0, 0, GRID_N, GRID_N)
	_astar.cell_size = Vector2(CELL, CELL)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.update()


## Marks every cell a footprint (turned by yaw, grown by margin) touches as solid.
func _block(center: Vector3, size: Vector3, yaw: float = 0.0, margin: float = MARGIN) -> void:
	var hx := absf(cos(yaw)) * size.x * 0.5 + absf(sin(yaw)) * size.z * 0.5 + margin
	var hz := absf(sin(yaw)) * size.x * 0.5 + absf(cos(yaw)) * size.z * 0.5 + margin
	var c0 := _cell(Vector3(center.x - hx, 0.0, center.z - hz))
	var c1 := _cell(Vector3(center.x + hx, 0.0, center.z + hz))
	for x in range(c0.x, c1.x + 1):
		for z in range(c0.y, c1.y + 1):
			_astar.set_point_solid(Vector2i(x, z), true)


func is_walkable(c: Vector2i) -> bool:
	return _astar.is_in_boundsv(c) and not _astar.is_point_solid(c)


## The nearest walkable cell to c (c itself if it is), searching out a few rings; (-1, -1) if none.
func _nearest_free(c: Vector2i) -> Vector2i:
	var cc := Vector2i(clampi(c.x, 0, GRID_N - 1), clampi(c.y, 0, GRID_N - 1))
	if is_walkable(cc):
		return cc
	for r in range(1, 6):
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue
				var n := cc + Vector2i(dx, dz)
				if is_walkable(n):
					return n
	return Vector2i(-1, -1)


func cell_center(_i: int, c: Vector2i) -> Vector3:
	return origin + Vector3(GRID_MIN + CELL * (float(c.x) + 0.5), 0.0, GRID_MIN + CELL * (float(c.y) + 0.5))


## World position -> cell.
func cell_of(p: Vector3) -> Vector2i:
	return _cell(p - origin)


## The estate's own (local) coordinates -> cell: what the build uses.
func _cell(p: Vector3) -> Vector2i:
	return Vector2i(clampi(floori((p.x - GRID_MIN) / CELL), 0, GRID_N - 1), clampi(floori((p.z - GRID_MIN) / CELL), 0, GRID_N - 1))


func route(_i: int, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var a := _nearest_free(from)
	var b := _nearest_free(to)
	if a.x < 0 or b.x < 0:
		var none: Array[Vector2i] = []
		return none
	return _astar.get_id_path(a, b)


## Nothing on the grid between a and b (their own cells aside: you can stand in the margin of a
## headstone, and so can it).
func clear_walk(a: Vector3, b: Vector3) -> bool:
	var d := Vector2(b.x - a.x, b.z - a.z)
	var n := int(ceilf(d.length() / 0.8))
	for k in range(1, n):
		var p := a.lerp(b, float(k) / float(n))
		if Vector2(p.x - a.x, p.z - a.z).length() < 1.0 or Vector2(p.x - b.x, p.z - b.z).length() < 1.0:
			continue
		if not is_walkable(cell_of(p)):
			return false
	return true


## It walks between the engines nobody has finished, so you meet it at the work.
func patrol_cells(_i: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for m in machines:
		if not m.done:
			var c := _nearest_free(cell_of(m.global_position + m.global_transform.basis.z * 1.6))
			if c.x >= 0:
				out.append(c)
	if out.is_empty() and generator != null:
		var g := _nearest_free(cell_of(generator.global_position + Vector3(0.0, 0.0, 2.2)))
		if g.x >= 0:
			out.append(g)
		var d := _nearest_free(_cell(Vector3(0.0, 0.0, GATE_Z - 4.0)))
		if d.x >= 0:
			out.append(d)
	return out


func random_cell(rng: RandomNumberGenerator) -> Vector2i:
	for _try in 30:
		var c := Vector2i(rng.randi_range(2, GRID_N - 3), rng.randi_range(2, GRID_N - 3))
		if is_walkable(c):
			return c
	return _cell(KEEPER_HOME)


# --- Building blocks -----------------------------------------------------------------------------

## A solid box: drawn, collides, and kept off on the grid.
func _solid(center: Vector3, size: Vector3, key: String, yaw: float = 0.0) -> void:
	_batch.add(center, size, key, true, yaw)
	_block(center, size, yaw)


## Drawn only: trim, roofs, paths, things far above anyone's head.
func _deco(center: Vector3, size: Vector3, key: String, yaw: float = 0.0) -> void:
	_batch.add(center, size, key, false, yaw)


## Collides but stays off the grid (a lintel over a door, a roof).
func _over(center: Vector3, size: Vector3, key: String, yaw: float = 0.0) -> void:
	_batch.add(center, size, key, true, yaw)


## A sculpted piece standing at base: drawn by the batch; `solid` (centred over the base, zero for
## none) collides and is kept off on the grid. tilt leans it (x, z radians).
func _piece(key: String, base: Vector3, size: Vector3, yaw: float, solid: Vector3 = Vector3.ZERO, tilt: Vector2 = Vector2.ZERO, margin: float = MARGIN) -> void:
	var basis := Basis.from_euler(Vector3(tilt.x, yaw, tilt.y))
	var xf := RuinMeshes.fit(key, base, size, basis) if key.begins_with("ruin_") else ManorMeshes.fit(key, base, size, basis)
	_batch.add_prop(key, xf)
	if solid != Vector3.ZERO:
		var c := base + Vector3(0.0, solid.y * 0.5, 0.0)
		_batch.add_solid(c, solid, yaw)
		_block(c, solid, yaw, margin)


## A wall along z at x from z0 to z1 with openings: [centre, width, "door"|"window"|"gap"]. A door
## keeps a lintel above door_h; a window has a sill to 0.9 m and a head from 2.9 m (you climb
## through it, the grid treats it as wall); a gap is open to the sky.
func _wall_z(x: float, z0: float, z1: float, h: float, thick: float, key: String, gaps: Array = [], door_h: float = 3.2, skin: String = "", skin_side: float = 1.0) -> void:
	var cur := z0
	var sorted := gaps.filter(func(g: Array) -> bool: return float(g[0]) > z0 and float(g[0]) < z1)
	sorted.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for g: Array in sorted:
		var c := float(g[0])
		var w := float(g[1])
		var a := c - w * 0.5
		if a > cur:
			_solid(Vector3(x, h * 0.5, (cur + a) * 0.5), Vector3(thick, h, a - cur), key)
		_opening(Vector3(x, 0.0, c), Vector3(thick, h, w), String(g[2]), key, door_h)
		cur = c + w * 0.5
	if z1 > cur:
		_solid(Vector3(x, h * 0.5, (cur + z1) * 0.5), Vector3(thick, h, z1 - cur), key)
	if skin != "":
		_skin_z(x + skin_side * (thick * 0.5 + 0.03), z0, z1, minf(h, ROOM_H), sorted, skin, door_h)


## The same along x at z.
func _wall_x(z: float, x0: float, x1: float, h: float, thick: float, key: String, gaps: Array = [], door_h: float = 3.2, skin: String = "", skin_side: float = 1.0) -> void:
	var cur := x0
	var sorted := gaps.filter(func(g: Array) -> bool: return float(g[0]) > x0 and float(g[0]) < x1)
	sorted.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for g: Array in sorted:
		var c := float(g[0])
		var w := float(g[1])
		var a := c - w * 0.5
		if a > cur:
			_solid(Vector3((cur + a) * 0.5, h * 0.5, z), Vector3(a - cur, h, thick), key)
		_opening(Vector3(c, 0.0, z), Vector3(w, h, thick), String(g[2]), key, door_h)
		cur = c + w * 0.5
	if x1 > cur:
		_solid(Vector3((cur + x1) * 0.5, h * 0.5, z), Vector3(x1 - cur, h, thick), key)
	if skin != "":
		_skin_x(z + skin_side * (thick * 0.5 + 0.03), x0, x1, minf(h, ROOM_H), sorted, skin, door_h)


## What fills an opening: a lintel over a door, sill and head round a window, nothing in a gap.
## size is the opening's full box (wall thickness and the wall's height included).
func _opening(base: Vector3, size: Vector3, kind: String, key: String, door_h: float) -> void:
	var h := size.y
	match kind:
		"door":
			if h > door_h:
				_over(base + Vector3(0.0, (door_h + h) * 0.5, 0.0), Vector3(size.x, h - door_h, size.z), key)
		"window":
			_solid(base + Vector3(0.0, 0.45, 0.0), Vector3(size.x, 0.9, size.z), key)
			if h > 2.9:
				_over(base + Vector3(0.0, (2.9 + h) * 0.5, 0.0), Vector3(size.x, h - 2.9, size.z), key)
			_deco(base + Vector3(0.0, 0.93, 0.0), Vector3(size.x + 0.1, 0.06, size.z + 0.12), "manor_trim")


## A wallpaper skin on the inside of a wall (drawn only), leaving the openings.
func _skin_z(x: float, z0: float, z1: float, h: float, gaps: Array, key: String, door_h: float) -> void:
	var cur := z0
	for g: Array in gaps:
		var c := float(g[0])
		var w := float(g[1])
		if c - w * 0.5 > cur:
			_deco(Vector3(x, h * 0.5, (cur + c - w * 0.5) * 0.5), Vector3(0.04, h, c - w * 0.5 - cur), key)
		var top := door_h if String(g[2]) == "door" else (2.9 if String(g[2]) == "window" else h)
		if top < h:
			_deco(Vector3(x, (top + h) * 0.5, c), Vector3(0.04, h - top, w), key)
		if String(g[2]) == "window":
			_deco(Vector3(x, 0.45, c), Vector3(0.04, 0.9, w), key)
		cur = c + w * 0.5
	if z1 > cur:
		_deco(Vector3(x, h * 0.5, (cur + z1) * 0.5), Vector3(0.04, h, z1 - cur), key)


func _skin_x(z: float, x0: float, x1: float, h: float, gaps: Array, key: String, door_h: float) -> void:
	var cur := x0
	for g: Array in gaps:
		var c := float(g[0])
		var w := float(g[1])
		if c - w * 0.5 > cur:
			_deco(Vector3((cur + c - w * 0.5) * 0.5, h * 0.5, z), Vector3(c - w * 0.5 - cur, h, 0.04), key)
		var top := door_h if String(g[2]) == "door" else (2.9 if String(g[2]) == "window" else h)
		if top < h:
			_deco(Vector3(c, (top + h) * 0.5, z), Vector3(w, h - top, 0.04), key)
		if String(g[2]) == "window":
			_deco(Vector3(c, 0.45, z), Vector3(w, 0.9, 0.04), key)
		cur = c + w * 0.5
	if x1 > cur:
		_deco(Vector3((cur + x1) * 0.5, h * 0.5, z), Vector3(x1 - cur, h, 0.04), key)


## Somewhere the scatter keeps off.
## hard: a door, a path, a machine (tall grass keeps off those too); soft: something the scatter
## put down (grass grows round it).
func _keep(at: Vector3, radius: float, hard: bool = true) -> void:
	_keepout.append([Vector2(at.x, at.z), radius, hard])


## Room for a scattered thing of `radius` at p: on the grounds, every cell under it walkable, clear
## of the keep-outs and the buildings.
func _room_for(p: Vector3, radius: float) -> bool:
	if absf(p.x) > HALF - 3.0 or absf(p.z) > HALF - 3.0:
		return false
	var p2 := Vector2(p.x, p.z)
	for k: Array in _keepout:
		if p2.distance_to(k[0]) < float(k[1]) + radius:
			return false
	for r: Rect2 in [MANSION, CRYPT, CHAPEL, GREENHOUSE, STABLES]:
		if r.grow(radius + 1.5).has_point(p2):
			return false
	var c0 := _cell(p - Vector3(radius, 0.0, radius))
	var c1 := _cell(p + Vector3(radius, 0.0, radius))
	for x in range(c0.x, c1.x + 1):
		for z in range(c0.y, c1.y + 1):
			if not is_walkable(Vector2i(x, z)):
				return false
	return true


## A lamp post with its glass and light. lit: burning from the start; dying: flickers; neither:
## dark until the main generator runs (the courtyard's).
func _lamp_post(at: Vector3, lit: bool, dying: bool) -> void:
	_piece("manor_lamp", at, ManorMeshes.NATIVE["manor_lamp"], 0.0, Vector3(0.36, 2.0, 0.36))
	var glass := MeshInstance3D.new()
	var gb := BoxMesh.new()
	gb.size = Vector3(0.18, 0.28, 0.18)
	glass.mesh = gb
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.1, 0.08, 0.05)
	gm.emission_enabled = true
	gm.emission = Color(1.0, 0.72, 0.38)
	gm.emission_energy_multiplier = 2.5 if lit or dying else 0.0
	glass.material_override = gm
	glass.position = at + Vector3(0.0, 3.0, 0.0)
	_root.add_child(glass)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.38)
	light.omni_range = 10.0
	light.omni_attenuation = 1.6
	light.light_energy = 0.9 if lit or dying else 0.0
	light.light_volumetric_fog_energy = 1.6
	light.position = at + Vector3(0.0, 2.95, 0.0)
	light.distance_fade_enabled = true
	light.distance_fade_begin = 45.0
	light.distance_fade_length = 8.0
	_root.add_child(light)
	if dying:
		_flickers.append([light, gm, 0.9, _rng.randf() * 10.0])
	elif not lit:
		_court_lamps.append([light, gm])


## A candle (or a candelabra's worth) burning on something: a flickering warm point.
func _candle(at: Vector3, energy: float = 0.7, range_m: float = 6.0) -> void:
	var c := MeshInstance3D.new()
	var cb := BoxMesh.new()
	cb.size = Vector3(0.05, 0.16, 0.05)
	c.mesh = cb
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.9, 0.85, 0.7)
	cm.emission_enabled = true
	cm.emission = Color(1.0, 0.68, 0.32)
	cm.emission_energy_multiplier = 2.0
	c.material_override = cm
	c.position = at + Vector3(0.0, 0.08, 0.0)
	_root.add_child(c)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.62, 0.3)
	l.omni_range = range_m
	l.omni_attenuation = 1.5
	l.light_energy = energy
	l.light_volumetric_fog_energy = 1.2
	l.position = at + Vector3(0.0, 0.3, 0.0)
	l.distance_fade_enabled = true
	l.distance_fade_begin = 35.0
	l.distance_fade_length = 6.0
	_root.add_child(l)
	_flickers.append([l, cm, energy, _rng.randf() * 10.0])


# --- The grounds ---------------------------------------------------------------------------------

func _build_ground() -> void:
	_over(Vector3(0.0, -0.5, 0.0), Vector3(220.0, 1.0, 220.0), "manor_earth")
	# Gravel: the drive from the mansion door to the south gate, the lane beyond, the east drive to
	# the stables, the path to the graveyard.
	_deco(Vector3(0.0, 0.012, 19.0), Vector3(4.0, 0.025, 110.0), "manor_gravel")
	_deco(Vector3(0.0, 0.012, 88.0), Vector3(5.0, 0.025, 28.0), "manor_gravel")
	_deco(Vector3(30.0, 0.012, 22.0), Vector3(56.0, 0.025, 4.0), "manor_gravel")
	_deco(Vector3(-18.0, 0.012, 0.0), Vector3(32.0, 0.025, 3.0), "manor_gravel")
	for z in range(-34, 76, 6):
		_keep(Vector3(0.0, 0.0, float(z)), 3.5)
	for x in range(4, 58, 6):
		_keep(Vector3(float(x), 0.0, 22.0), 3.0)
	for x in range(-32, -2, 6):
		_keep(Vector3(float(x), 0.0, 0.0), 2.5)


## The estate wall: high stone with iron spikes along the coping, the south gate in the middle of
## the south side, and beyond the gate a lane walled in by hedges, out into the fog.
func _build_estate_wall() -> void:
	var t := 1.0
	_wall_x(-HALF, -HALF - 0.5, HALF + 0.5, WALL_H, t, "manor_stone_dark")
	_wall_z(-HALF, -HALF, HALF, WALL_H, t, "manor_stone_dark")
	_wall_z(HALF, -HALF, HALF, WALL_H, t, "manor_stone_dark")
	_wall_x(HALF, -HALF - 0.5, HALF + 0.5, WALL_H, t, "manor_stone_dark", [[0.0, ManorGate.WIDTH + 2.4, "gap"]])
	# Coping and spikes along every side.
	for s in 4:
		var horizontal := s < 2
		var sign := -1.0 if s % 2 == 0 else 1.0
		for k in range(-37, 38):
			var a := float(k) * 2.0
			var at := Vector3(a, WALL_H + 0.12, sign * HALF) if horizontal else Vector3(sign * HALF, WALL_H + 0.12, a)
			if horizontal and sign > 0.0 and absf(a) < 5.0:
				continue
			_deco(at, Vector3(2.0, 0.24, 1.2) if horizontal else Vector3(1.2, 0.24, 2.0), "manor_stone")
			for j in 4:
				var off := -0.75 + 0.5 * float(j)
				var sp := at + (Vector3(off, 0.45, 0.0) if horizontal else Vector3(0.0, 0.45, off))
				_deco(sp, Vector3(0.04, 0.7, 0.04), "iron")
	# The gate pillars and the gate itself.
	for side: float in [-1.0, 1.0]:
		_solid(Vector3(side * (ManorGate.WIDTH * 0.5 + 0.6), 2.4, GATE_Z), Vector3(1.2, 4.8, 1.4), "manor_stone")
		_deco(Vector3(side * (ManorGate.WIDTH * 0.5 + 0.6), 4.9, GATE_Z), Vector3(1.5, 0.25, 1.7), "manor_stone_dark")
	gate = ManorGate.new()
	gate.name = "Gate"
	gate.position = Vector3(0.0, 0.0, GATE_Z)
	add_child(gate)
	_block(Vector3(0.0, 0.0, GATE_Z), Vector3(ManorGate.WIDTH, 1.0, 0.4))  # shut: the grid ends here too
	# The lane: hedges either side, the fog, and a black wall of trees at the end.
	for side: float in [-1.0, 1.0]:
		_solid(Vector3(side * 5.0, 1.6, 87.5), Vector3(1.4, 3.2, 26.0), "manor_hedge")
	_solid(Vector3(0.0, 2.0, 101.0), Vector3(12.0, 4.0, 1.0), "manor_hedge")
	_keep(Vector3(0.0, 0.0, GATE_Z - 3.0), 5.0)


## The mansion: a long stone house, two storeys of facade with a pitched slate roof and a tower,
## but only the ground floor is open: a foyer with the stair up (it's fallen in), the dining room
## and the library to the west, the parlour and the study to the east. Doors front, back and both
## sides, low windows all round (you climb through; it goes round). The first engine is in the
## library.
func _build_mansion() -> void:
	var x0 := MANSION.position.x
	var x1 := MANSION.end.x
	var z0 := MANSION.position.y
	var z1 := MANSION.end.y
	var t := 0.5
	var stone := "manor_stone"
	var paper := "manor_paper"
	# Outside walls (stone, wallpapered inside).
	_wall_x(z1, x0, x1, ROOM_H, t, stone, [[0.0, 3.2, "door"], [-16.0, 1.8, "window"], [16.0, 1.8, "window"], [-22.0, 1.8, "window"]], 3.4, paper, -1.0)
	_wall_x(z0, x0, x1, ROOM_H, t, stone, [[-18.0, 3.0, "door"], [14.0, 1.8, "window"], [-2.0, 1.8, "window"]], 3.2, paper, 1.0)
	_wall_z(x0, z0, z1, ROOM_H, t, stone, [[-42.0, 3.0, "door"], [-54.0, 1.8, "window"]], 3.2, paper, 1.0)
	_wall_z(x1, z0, z1, ROOM_H, t, stone, [[-54.0, 3.0, "door"], [-42.0, 1.8, "window"]], 3.2, paper, -1.0)
	# Inside walls.
	_wall_z(-8.0, z0, z1, ROOM_H, 0.3, paper, [[-42.0, 3.0, "door"], [-56.0, 3.0, "door"]])
	_wall_z(8.0, z0, z1, ROOM_H, 0.3, paper, [[-42.0, 3.0, "door"], [-56.0, 3.0, "door"]])
	_wall_x(-50.0, x0, -8.0, ROOM_H, 0.3, paper, [[-18.0, 3.0, "door"]])
	_wall_x(-50.0, 8.0, x1, ROOM_H, 0.3, paper, [[18.0, 3.0, "door"]])
	# Floor and ceiling.
	_deco(Vector3((x0 + x1) * 0.5, 0.015, (z0 + z1) * 0.5), Vector3(x1 - x0, 0.03, z1 - z0), "manor_planks")
	_over(Vector3((x0 + x1) * 0.5, ROOM_H + 0.15, (z0 + z1) * 0.5), Vector3(x1 - x0 + 1.0, 0.3, z1 - z0 + 1.0), "manor_trim")
	# The upper storey's facade and the roof.
	var mid := Vector3((x0 + x1) * 0.5, 0.0, (z0 + z1) * 0.5)
	var up_h := UPPER_H - ROOM_H
	_over(mid + Vector3(0.0, ROOM_H + up_h * 0.5, 0.0), Vector3(x1 - x0 + 0.6, up_h, z1 - z0 + 0.6), stone)
	_deco(mid + Vector3(0.0, ROOM_H + 0.2, 0.0), Vector3(x1 - x0 + 1.2, 0.35, z1 - z0 + 1.2), "manor_stone_dark")  # a string course
	for k in 9:
		var wx := x0 + 4.0 + float(k) * 5.5
		for face: float in [z0 - 0.33, z1 + 0.33]:
			var lit := _rng.randf() < 0.18
			_deco(Vector3(wx, 7.6, face), Vector3(1.4, 2.4, 0.08), "manor_window_lit" if lit else "manor_window")
			_deco(Vector3(wx, 6.3, face), Vector3(1.7, 0.18, 0.2), "manor_stone_dark")
	for face_x: float in [x0 - 0.33, x1 + 0.33]:
		for wz in [z0 + 6.0, z1 - 6.0]:
			_deco(Vector3(face_x, 7.6, float(wz)), Vector3(0.08, 2.4, 1.4), "manor_window")
	var depth := z1 - z0 + 1.6
	# Pitch the two roof slabs: drawn as boxes turned about x (BoxBatch only turns about y), so
	# build them by hand.
	for side: float in [-1.0, 1.0]:
		var slab := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(x1 - x0 + 1.6, 0.35, depth * 0.58)
		slab.mesh = bm
		slab.material_override = LevelKit.mat("manor_slate")
		slab.position = mid + Vector3(0.0, UPPER_H + 2.2, side * depth * 0.24)
		slab.rotation.x = side * 0.5
		_root.add_child(slab)
	_deco(mid + Vector3(0.0, UPPER_H + 0.2, 0.0), Vector3(x1 - x0 + 1.0, 0.4, depth), "manor_slate")
	# The tower at the east corner and the chimneys.
	_over(Vector3(x1 - 3.0, ROOM_H + 7.0, z1 - 3.0), Vector3(6.0, 14.0, 6.0), stone)
	for k in 4:
		var a := float(k) * PI * 0.5
		var w := MeshInstance3D.new()
		var wb := BoxMesh.new()
		wb.size = Vector3(1.0, 2.2, 0.1)
		w.mesh = wb
		w.material_override = LevelKit.mat("manor_window_lit" if k == 1 else "manor_window")
		w.position = Vector3(x1 - 3.0 + sin(a) * 3.05, 15.0, z1 - 3.0 + cos(a) * 3.05)
		w.rotation.y = a
		_root.add_child(w)
	var spire := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.05
	cone.bottom_radius = 4.6
	cone.height = 7.5
	cone.radial_segments = 4
	spire.mesh = cone
	spire.material_override = LevelKit.mat("manor_slate")
	spire.position = Vector3(x1 - 3.0, ROOM_H + 14.0 + 3.75, z1 - 3.0)
	spire.rotation.y = PI * 0.25
	_root.add_child(spire)
	for cx in [x0 + 6.0, -4.0, 12.0, x1 - 10.0]:
		_deco(Vector3(float(cx), UPPER_H + 4.5, z0 + 6.0), Vector3(1.4, 4.0, 1.4), "manor_stone_dark")
	# The porch: steps up to nothing (it's all one floor), two columns, a pediment.
	for side: float in [-1.0, 1.0]:
		_solid(Vector3(side * 3.0, ROOM_H * 0.5, z1 + 2.4), Vector3(0.7, ROOM_H, 0.7), stone)
	_over(Vector3(0.0, ROOM_H + 0.3, z1 + 2.0), Vector3(7.6, 0.6, 4.4), "manor_stone_dark")
	_keep(Vector3(0.0, 0.0, z1 + 3.0), 4.0)
	for door: Vector3 in [Vector3(-18.0, 0.0, z0 - 1.5), Vector3(x0 - 1.5, 0.0, -42.0), Vector3(x1 + 1.5, 0.0, -54.0)]:
		_keep(door, 3.0)
	_mansion_rooms()


## What's left in the rooms: the dining table laid for a dinner nobody ate, the library's shelves,
## the parlour's fireplace still glowing, the study's desk, the foyer's fallen stair.
func _mansion_rooms() -> void:
	# Foyer: the grand stair, collapsed at the top, against the back wall; a long-case clock.
	for k in 10:
		var sh := 0.4 * float(k + 1)
		_solid(Vector3(0.0, sh * 0.5, -52.0 - 0.95 * float(k)), Vector3(5.0, sh, 0.95), "manor_trim")
	_piece("ruin_rubble", Vector3(2.8, 0.0, -50.5), Vector3(2.2, 0.9, 2.2), 0.4, Vector3(1.4, 0.6, 1.4))
	_solid(Vector3(-6.6, 1.15, -40.0), Vector3(0.6, 2.3, 0.5), "manor_trim")  # the clock
	_candle(Vector3(-6.6, 2.3, -40.0), 0.5)
	# Dining room: a long table, a candelabra still burning.
	_solid(Vector3(-17.0, 0.4, -43.0), Vector3(10.0, 0.8, 1.8), "manor_trim")
	for k in 6:
		for side: float in [-1.0, 1.0]:
			_piece("manor_pew", Vector3(-21.0 + 1.6 * float(k), 0.0, -43.0 + side * 1.6), Vector3(0.6, 0.95, 0.5), PI * 0.5 + (0.0 if side > 0.0 else PI), Vector3(0.5, 0.5, 0.5))
	_candle(Vector3(-17.0, 0.8, -43.0), 0.8, 7.0)
	_candle(Vector3(-13.0, 0.8, -43.0), 0.4)
	# Library: shelves floor to ceiling along the walls, the engine in the middle, a reading lamp.
	for z in [-60.0, -57.8, -51.2]:
		_solid(Vector3(-24.6, 2.0, float(z)), Vector3(0.6, 4.0, 2.0), "manor_books")
	for z in [-60.2, -52.0]:
		_solid(Vector3(-9.4, 2.0, float(z)), Vector3(0.6, 4.0, 2.0), "manor_books")
	for x in [-23.5, -21.2]:
		_solid(Vector3(float(x), 2.0, -61.2), Vector3(2.2, 4.0, 0.6), "manor_books")
	_candle(Vector3(-11.0, 1.0, -52.0), 0.6)
	_piece("manor_coffin", Vector3(-21.5, 0.0, -53.0), Vector3(0.9, 0.6, 2.1), 0.3, Vector3(0.8, 0.5, 2.0))
	# Parlour: the fireplace on the east wall, still glowing; chairs; a piano under a sheet.
	_solid(Vector3(25.0, 1.3, -46.5), Vector3(1.4, 2.6, 3.0), "manor_stone_dark")
	_piece("ruin_embers", Vector3(24.0, 0.0, -46.5), Vector3(1.2, 0.35, 1.6), 0.0)
	var fire := OmniLight3D.new()
	fire.light_color = Color(1.0, 0.42, 0.15)
	fire.omni_range = 8.0
	fire.light_energy = 1.0
	fire.position = Vector3(23.4, 0.6, -46.5)
	_root.add_child(fire)
	_flickers.append([fire, null, 1.0, 3.3])
	_solid(Vector3(14.0, 0.6, -40.0), Vector3(2.4, 1.2, 1.4), "manor_trim")  # the piano
	_deco(Vector3(14.0, 1.22, -40.0), Vector3(2.6, 0.05, 1.6), "paper")
	for k in 3:
		_piece("manor_pew", Vector3(14.0 + 3.0 * float(k - 1), 0.0, -46.5), Vector3(1.2, 0.95, 0.6), PI, Vector3(1.0, 0.6, 0.5))
	# Study: the desk, papers, a lamp left on.
	_solid(Vector3(17.0, 0.4, -57.0), Vector3(3.0, 0.8, 1.4), "manor_trim")
	_deco(Vector3(17.2, 0.82, -57.0), Vector3(1.2, 0.02, 0.8), "paper", 0.3)
	_candle(Vector3(16.0, 0.8, -57.0), 0.6)
	for k in 2:
		_solid(Vector3(24.6, 2.0, -60.0 + 2.2 * float(k)), Vector3(0.6, 4.0, 2.0), "manor_books")


## The graveyard: iron railings round it with three ways in, rows of headstones, crosses, a few
## obelisks and ledgers, aisles between the rows, dead trees, mourners on plinths, two open graves.
func _build_graveyard() -> void:
	var g := GRAVEYARD
	var gaps_e: Array = [[0.0, 4.0]]
	var gaps_s: Array = [[-50.0, 4.0]]
	var gaps_n: Array = [[-44.0, 4.0]]
	_railing(Vector2(g.position.x, g.position.y), Vector2(g.end.x, g.position.y), gaps_n)
	_railing(Vector2(g.position.x, g.end.y), Vector2(g.end.x, g.end.y), gaps_s)
	_railing(Vector2(g.position.x, g.position.y), Vector2(g.position.x, g.end.y), [])
	_railing(Vector2(g.end.x, g.position.y), Vector2(g.end.x, g.end.y), gaps_e)
	_keep(Vector3(g.end.x, 0.0, 0.0), 3.0)
	_keep(Vector3(-50.0, 0.0, g.end.y), 3.0)
	_keep(Vector3(-44.0, 0.0, g.position.y), 3.0)
	_keep(Vector3(-50.0, 0.0, 0.0), 2.0)
	var z := g.position.y + 4.0
	while z < g.end.y - 2.0:
		var x := g.position.x + 2.2
		var col := 0
		while x < g.end.x - 1.6:
			var p := Vector3(x + _rng.randf_range(-0.3, 0.3), 0.0, z + _rng.randf_range(-0.2, 0.2))
			x += 2.6
			col += 1
			# Every fourth column stays empty: aisles through the rows (on its grid a row of
			# headstones is a wall, so without them the Groundskeeper could only walk the middle).
			if col % 4 == 0:
				continue
			if CRYPT.grow(3.0).has_point(Vector2(p.x, p.z)) or Rect2(-48.0, -18.0, 9.0, 8.0).has_point(Vector2(p.x, p.z)) or absf(p.x + 50.0) < 1.6 or absf(p.z) < 2.0:  # the crypt, the way to its door, the aisle, the path
				continue
			if _rng.randf() < 0.15:
				continue
			var r := _rng.randf()
			var yaw := _rng.randf_range(-0.12, 0.12)
			var lean := Vector2(_rng.randf_range(-0.12, 0.12), _rng.randf_range(-0.16, 0.16))
			if r < 0.55:
				var s := _rng.randf_range(0.85, 1.25)
				_piece("manor_tomb_round", p, ManorMeshes.NATIVE["manor_tomb_round"] * s, yaw, Vector3(0.7, 1.0, 0.3) * s, lean, 0.15)
			elif r < 0.8:
				var s2 := _rng.randf_range(0.9, 1.3)
				_piece("manor_tomb_cross", p, ManorMeshes.NATIVE["manor_tomb_cross"] * s2, yaw, Vector3(0.6, 1.2, 0.3) * s2, lean * 0.6, 0.15)
			elif r < 0.9:
				_piece("manor_ledger", p, ManorMeshes.NATIVE["manor_ledger"], yaw + PI * 0.5, Vector3(1.0, 0.45, 2.1))
			else:
				_piece("manor_obelisk", p, ManorMeshes.NATIVE["manor_obelisk"] * _rng.randf_range(0.9, 1.25), yaw, Vector3(0.8, 2.6, 0.8), lean * 0.3)
		z += 4.0
	for at: Vector3 in [Vector3(-50.0, 0.0, -27.0), Vector3(-64.0, 0.0, 0.0), Vector3(-37.0, 0.0, 19.0)]:
		_piece("manor_mourner", at, ManorMeshes.NATIVE["manor_mourner"] * 1.15, _rng.randf() * TAU, Vector3(0.9, 2.4, 0.9))
	for at: Vector3 in [Vector3(-62.0, 0.0, -22.0), Vector3(-40.0, 0.0, -24.0), Vector3(-63.0, 0.0, 14.0), Vector3(-44.0, 0.0, 10.5)]:
		_piece("manor_tree", at, ManorMeshes.NATIVE["manor_tree"] * _rng.randf_range(0.9, 1.3), _rng.randf() * TAU, Vector3(0.9, 4.0, 0.9))
	# Two open graves: a coffin dug up, the mound beside it, the spade still in it.
	for at: Vector3 in [Vector3(-60.0, 0.0, 6.0), Vector3(-28.0, 0.0, -16.0)]:
		_piece("manor_coffin", at, ManorMeshes.NATIVE["manor_coffin"], 0.1, Vector3(0.9, 0.5, 2.0))
		_piece("manor_mound", at + Vector3(1.6, 0.0, 0.0), ManorMeshes.NATIVE["manor_mound"], 0.0, Vector3(1.3, 0.6, 2.0))


## Iron railings from a to b (axis-aligned), in 2 m sections, with gaps [[centre, width]]; a few
## sections have fallen flat.
func _railing(a: Vector2, b: Vector2, gaps: Array) -> void:
	var along_x := absf(a.y - b.y) < 0.01
	var from := a.x if along_x else a.y
	var to := b.x if along_x else b.y
	var p := from + 1.0
	while p < to:
		var skip := false
		for gp: Array in gaps:
			if absf(p - float(gp[0])) < float(gp[1]) * 0.5 + 0.5:
				skip = true
		if not skip:
			var c := Vector3(p, 0.0, a.y) if along_x else Vector3(a.x, 0.0, p)
			var yaw := 0.0 if along_x else PI * 0.5
			if _rng.randf() < 0.08:
				_piece("manor_fence", c + (Vector3(0.0, 0.05, 0.7) if along_x else Vector3(0.7, 0.05, 0.0)), ManorMeshes.NATIVE["manor_fence"], yaw, Vector3.ZERO, Vector2(PI * 0.5 - 0.05, 0.0))
				_block(c, Vector3(2.0, 1.0, 0.2), yaw)  # flat in the mud: you step over, it walks round
			else:
				_piece("manor_fence", c, ManorMeshes.NATIVE["manor_fence"], yaw, Vector3(2.0, 1.5, 0.12))
		p += 2.0


## The crypt: a squat mausoleum of dark stone in the graveyard, a portico of two columns, a
## pitched roof, sarcophagi inside, and the second engine.
func _build_crypt() -> void:
	var c := CRYPT
	var h := 4.2
	var k := "manor_stone_dark"
	_wall_z(c.position.x, c.position.y, c.end.y, h, 0.6, k)
	_wall_z(c.end.x, c.position.y, c.end.y, h, 0.6, k, [[-14.0, 3.2, "door"]], 3.0)
	_wall_x(c.position.y, c.position.x, c.end.x, h, 0.6, k)
	_wall_x(c.end.y, c.position.x, c.end.x, h, 0.6, k)
	_deco(Vector3(c.get_center().x, 0.02, c.get_center().y), Vector3(c.size.x, 0.04, c.size.y), "manor_stone")
	_over(Vector3(c.get_center().x, h + 0.2, c.get_center().y), Vector3(c.size.x + 0.8, 0.4, c.size.y + 0.8), k)
	var ridge := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(c.size.y + 1.0, 2.0, c.size.x + 4.0)
	ridge.mesh = prism
	ridge.material_override = LevelKit.mat("manor_slate")
	ridge.position = Vector3(c.get_center().x + 1.6, h + 1.4, c.get_center().y)
	ridge.rotation.y = PI * 0.5
	_root.add_child(ridge)
	for side: float in [-1.0, 1.0]:
		_solid(Vector3(c.end.x + 1.6, h * 0.5, -14.0 + side * 2.4), Vector3(0.6, h, 0.6), "manor_stone")
	_over(Vector3(c.end.x + 1.4, h + 0.15, -14.0), Vector3(3.0, 0.3, 6.0), k)
	_piece("manor_ledger", Vector3(-55.0, 0.0, -17.6), ManorMeshes.NATIVE["manor_ledger"] * Vector3(0.8, 1.0, 0.7), PI * 0.5, Vector3(1.6, 0.45, 0.9))
	_piece("manor_ledger", Vector3(-55.0, 0.0, -10.4), ManorMeshes.NATIVE["manor_ledger"] * Vector3(0.8, 1.0, 0.7), PI * 0.5, Vector3(1.6, 0.45, 0.9))
	_candle(Vector3(-55.0, 0.45, -10.4), 0.5, 5.0)
	_keep(Vector3(c.end.x + 2.0, 0.0, -14.0), 3.5)


## The chapel: a roofless ruin, its walls broken off at different heights, the north wall caved in,
## pews in rows, the altar at the west end with candles still lit on it, and the third engine.
func _build_chapel() -> void:
	var c := CHAPEL
	var k := "manor_stone"
	_wall_z(c.position.x, c.position.y, c.end.y, 5.5, 0.7, k, [[46.0, 1.8, "window"]])
	_wall_z(c.end.x, c.position.y, c.end.y, 4.0, 0.7, k, [[46.0, 3.2, "door"], [40.0, 1.8, "window"], [52.0, 1.8, "window"]], 3.2)
	_wall_x(c.position.y, c.position.x, c.end.x, 3.2, 0.7, k, [[-48.0, 6.0, "gap"]])
	_wall_x(c.end.y, c.position.x, c.end.x, 4.6, 0.7, k, [[-50.0, 1.8, "window"], [-44.0, 1.8, "window"]])
	# Broken tops: jagged blocks along the walls.
	for i in 14:
		var along := _rng.randf()
		var at := Vector3.ZERO
		match i % 4:
			0: at = Vector3(c.position.x, 5.5, lerpf(c.position.y, c.end.y, along))
			1: at = Vector3(c.end.x, 4.0, lerpf(c.position.y, c.end.y, along))
			2: at = Vector3(lerpf(c.position.x, c.end.x, along), 3.2, c.position.y)
			_: at = Vector3(lerpf(c.position.x, c.end.x, along), 4.6, c.end.y)
		_deco(at + Vector3(0.0, _rng.randf_range(0.2, 0.8), 0.0), Vector3(0.7, _rng.randf_range(0.5, 1.6), _rng.randf_range(0.8, 2.0)) if i % 4 < 2 else Vector3(_rng.randf_range(0.8, 2.0), _rng.randf_range(0.5, 1.6), 0.7), k)
	_deco(Vector3(c.get_center().x, 0.02, c.get_center().y), Vector3(c.size.x, 0.04, c.size.y), "manor_stone_dark")
	_piece("ruin_rubble", Vector3(-48.0, 0.0, 37.6), Vector3(4.0, 1.2, 2.4), 0.2, Vector3(3.0, 0.8, 1.6))
	_piece("ruin_rubble", Vector3(-41.0, 0.0, 54.0), Vector3(2.4, 0.9, 2.0), 1.2, Vector3(1.8, 0.6, 1.4))
	# The altar and its candles.
	_solid(Vector3(-57.6, 0.55, 46.0), Vector3(1.4, 1.1, 3.2), "manor_stone_dark")
	_candle(Vector3(-57.6, 1.1, 45.0), 0.7, 7.0)
	_candle(Vector3(-57.6, 1.1, 47.2), 0.5, 6.0)
	_piece("manor_mourner", Vector3(-59.0, 0.0, 41.0), ManorMeshes.NATIVE["manor_mourner"], PI * 0.5, Vector3(0.9, 2.3, 0.9))
	# Pews either side of the aisle down the middle, some knocked askew.
	for z in [43.0, 49.5, 52.5]:
		for x in [-49.0, -43.0]:
			_piece("manor_pew", Vector3(float(x), 0.0, float(z)), ManorMeshes.NATIVE["manor_pew"], _rng.randf_range(-0.15, 0.15) + (PI if _rng.randf() < 0.5 else 0.0), Vector3(2.0, 0.9, 0.5))
	_keep(Vector3(c.end.x + 2.0, 0.0, 46.0), 3.5)
	_keep(Vector3(-48.0, 0.0, c.position.y - 2.0), 3.5)


## The courtyard: the dry fountain with a mourner on its column, the main generator, and six lamp
## posts that stay dark until the generator runs.
func _build_courtyard() -> void:
	var f := Vector3(0.0, 0.0, -14.0)
	for k in 8:
		var a := TAU * float(k) / 8.0
		var at := f + Vector3(cos(a), 0.0, sin(a)) * 4.4
		_batch.add(at + Vector3(0.0, 0.35, 0.0), Vector3(0.5, 0.7, 3.7), "manor_stone", true, -a)
	_deco(f + Vector3(0.0, 0.3, 0.0), Vector3(7.0, 0.05, 7.0), "manor_water")
	_batch.add(f + Vector3(0.0, 0.75, 0.0), Vector3(1.0, 1.5, 1.0), "manor_stone_dark", true)
	_piece("manor_mourner", f + Vector3(0.0, 1.5, 0.0), ManorMeshes.NATIVE["manor_mourner"] * 0.9, PI)
	_block(f, Vector3(9.6, 1.0, 9.6))
	_keep(f, 6.0)
	for at: Vector3 in [Vector3(-8.0, 0.0, -26.0), Vector3(8.0, 0.0, -26.0), Vector3(-8.0, 0.0, -4.0), Vector3(-8.0, 0.0, 16.0), Vector3(8.0, 0.0, 16.0), Vector3(20.0, 0.0, -4.0)]:
		_lamp_post(at, false, false)
	for at: Vector3 in [Vector3(-16.0, 0.0, -28.0), Vector3(16.0, 0.0, -28.0)]:
		_piece("manor_mourner", at, ManorMeshes.NATIVE["manor_mourner"], PI + _rng.randf_range(-0.3, 0.3), Vector3(0.9, 2.3, 0.9))


## The hedge garden between the courtyard and the south gate: tall black hedges in runs that loop
## back on themselves, the drive straight through the middle.
func _build_hedges() -> void:
	var runs := [
		[Vector2(-30.0, 26.0), Vector2(-6.0, 26.0), [[-16.0, 4.0, "gap"]]],
		[Vector2(-30.0, 26.0), Vector2(-30.0, 66.0), [[46.0, 4.0, "gap"]]],
		[Vector2(-30.0, 66.0), Vector2(-6.0, 66.0), [[-20.0, 4.0, "gap"]]],
		[Vector2(-6.0, 30.0), Vector2(-6.0, 44.0), []],
		[Vector2(-6.0, 50.0), Vector2(-6.0, 62.0), []],
		[Vector2(-24.0, 34.0), Vector2(-12.0, 34.0), []],
		[Vector2(-24.0, 34.0), Vector2(-24.0, 58.0), [[46.0, 4.0, "gap"]]],
		[Vector2(-18.0, 40.0), Vector2(-18.0, 60.0), []],
		[Vector2(-18.0, 52.0), Vector2(-10.0, 52.0), []],
		[Vector2(-12.0, 40.0), Vector2(-12.0, 46.0), []],
	]
	for side: float in [-1.0, 1.0]:
		for r: Array in runs:
			var a: Vector2 = r[0]
			var b: Vector2 = r[1]
			var gaps: Array = []
			for gp: Array in r[2]:
				# The runs are written for the west half; the east half mirrors x (a gap along a
				# run that goes along x mirrors with it).
				gaps.append([float(gp[0]) * (-side if absf(a.y - b.y) < 0.01 else 1.0), gp[1], gp[2]])
			if side > 0.0:
				a = Vector2(-a.x, a.y)
				b = Vector2(-b.x, b.y)
			if absf(a.y - b.y) < 0.01:
				_wall_x(a.y, minf(a.x, b.x), maxf(a.x, b.x), 2.6, 1.2, "manor_hedge", gaps)
			else:
				_wall_z(a.x, minf(a.y, b.y), maxf(a.y, b.y), 2.6, 1.2, "manor_hedge", gaps)
	for at: Vector3 in [Vector3(-21.0, 0.0, 49.0), Vector3(21.0, 0.0, 30.0)]:
		_piece("manor_mourner", at, ManorMeshes.NATIVE["manor_mourner"], _rng.randf() * TAU, Vector3(0.9, 2.3, 0.9))
	_lamp_post(Vector3(-27.0, 0.0, 63.0), false, true)
	_lamp_post(Vector3(27.0, 0.0, 29.0), false, true)


## The dead orchard: rows of black fruit trees long dead, a well, a cart that lost a wheel, and the
## greenhouse, its glass long gone, a low brick wall round an iron frame: the fourth engine.
func _build_orchard() -> void:
	var gh := GREENHOUSE
	_wall_x(gh.end.y, gh.position.x, gh.end.x, 0.7, 0.4, "manor_stone", [[42.0, 3.2, "gap"]])
	_wall_x(gh.position.y, gh.position.x, gh.end.x, 0.7, 0.4, "manor_stone")
	_wall_z(gh.position.x, gh.position.y, gh.end.y, 0.7, 0.4, "manor_stone", [[-62.0, 3.2, "gap"]])
	_wall_z(gh.end.x, gh.position.y, gh.end.y, 0.7, 0.4, "manor_stone")
	var px := gh.position.x
	while px <= gh.end.x + 0.01:
		for pz: float in [gh.position.y, gh.end.y]:
			if absf(px - 42.0) > 2.0:
				_solid(Vector3(px, 1.9, pz), Vector3(0.14, 3.8, 0.14), "iron")
		px += 3.5
	for pz in [gh.position.y + 3.4, gh.position.y + 6.7]:
		_deco(Vector3(gh.get_center().x, 3.85, float(pz)), Vector3(gh.size.x, 0.1, 0.1), "iron")
	_deco(Vector3(gh.get_center().x, 4.4, gh.get_center().y), Vector3(gh.size.x, 0.12, 0.12), "iron")
	for k in 7:
		_deco(Vector3(gh.position.x + 1.0 + 2.0 * float(k), 3.8, gh.get_center().y), Vector3(0.08, 0.1, gh.size.y), "iron")
	for k in 10:
		_deco(Vector3(_rng.randf_range(gh.position.x + 1.0, gh.end.x - 1.0), 0.03, _rng.randf_range(gh.position.y + 1.0, gh.end.y - 1.0)), Vector3(_rng.randf_range(0.2, 0.6), 0.02, _rng.randf_range(0.2, 0.5)), "manor_window", _rng.randf() * TAU)
	_keep(Vector3(42.0, 0.0, gh.end.y + 2.0), 3.0)
	_keep(Vector3(gh.position.x - 2.0, 0.0, -62.0), 3.0)
	_lamp_post(Vector3(46.0, 0.0, -52.0), false, true)
	# The trees, in rows that have lost their order.
	var x := 34.0
	while x < 70.0:
		var z := -68.0
		while z < -24.0:
			var p := Vector3(x + _rng.randf_range(-1.2, 1.2), 0.0, z + _rng.randf_range(-1.2, 1.2))
			z += 7.0
			if GREENHOUSE.grow(2.5).has_point(Vector2(p.x, p.z)) or _rng.randf() < 0.2:
				continue
			_piece("manor_tree", p, ManorMeshes.NATIVE["manor_tree"] * _rng.randf_range(0.7, 1.0), _rng.randf() * TAU, Vector3(0.8, 4.0, 0.8))
		x += 7.0
	_piece("manor_well", Vector3(57.0, 0.0, -38.0), ManorMeshes.NATIVE["manor_well"], 0.4, Vector3(1.8, 1.0, 1.8))
	_piece("manor_cart", Vector3(49.0, 0.0, -30.0), ManorMeshes.NATIVE["manor_cart"], 1.1, Vector3(1.6, 1.1, 2.4))


## The stables against the east wall where the Line comes in: a long open-fronted shed, stalls,
## a lantern on a hook, a cart.
func _build_stables() -> void:
	var s := STABLES
	_wall_x(s.position.y, s.position.x, s.end.x, 3.6, 0.4, "manor_trim")
	_wall_x(s.end.y, s.position.x, s.end.x, 3.6, 0.4, "manor_trim")
	var z := s.position.y + 4.0
	while z < s.end.y - 1.0:
		_solid(Vector3(68.0, 0.8, z), Vector3(8.0, 1.6, 0.2), "manor_trim")
		_solid(Vector3(s.position.x, 1.8, z - 0.1), Vector3(0.3, 3.6, 0.3), "manor_trim")
		z += 4.0
	var roof := MeshInstance3D.new()
	var rb := BoxMesh.new()
	rb.size = Vector3(s.size.x + 1.2, 0.2, s.size.y + 0.6)
	roof.mesh = rb
	roof.material_override = LevelKit.mat("manor_slate")
	roof.position = Vector3(s.get_center().x, 4.0, s.get_center().y)
	roof.rotation.z = -0.18
	_root.add_child(roof)
	_deco(Vector3(s.get_center().x, 0.015, s.get_center().y), Vector3(s.size.x, 0.03, s.size.y), "manor_planks")
	_candle(Vector3(61.0, 2.4, 21.0), 1.0, 9.0)
	_piece("manor_cart", Vector3(54.0, 0.0, 32.0), ManorMeshes.NATIVE["manor_cart"], -0.6, Vector3(1.6, 1.1, 2.4))
	for k in 4:
		_batch.add(Vector3(63.0 + 0.7 * float(k % 2), 0.4 + 0.8 * float(k / 2), 10.0 + 0.4 * float(k)), Vector3(0.8, 0.8, 0.8), "cardboard_dark", true, _rng.randf_range(-0.3, 0.3))
	_keep(SPAWN, 6.0)


func _build_machines() -> void:
	for i in ENGINE_SPOTS.size():
		var spot: Array = ENGINE_SPOTS[i]
		var m := ManorMachine.create("Engine%d" % i, i, false, spot[0], float(spot[1]), self)
		add_child(m)
		machines.append(m)
		_block(spot[0] + Vector3(0.0, 0.5, 0.0), ManorMachine.ENGINE_SIZE * Vector3(0.9, 1.0, 0.9), float(spot[1]), 0.1)
		_keep(spot[0], 3.5)
	generator = ManorMachine.create("MainGenerator", 4, true, MAIN_SPOT, 0.0, self)
	add_child(generator)
	_block(MAIN_SPOT + Vector3(0.0, 0.5, 0.0), ManorMachine.MAIN_SIZE * Vector3(0.9, 1.0, 0.9), 0.0, 0.1)
	_keep(MAIN_SPOT, 4.5)


## Everything lying about, from the seed: dead trees, thorns, family plots, open graves, rubble,
## a cart, dying lamps along the ways.
func _scatter() -> void:
	var placed := 0
	var tries := 0
	while placed < 75 and tries < 2400:
		tries += 1
		var p := Vector3(_rng.randf_range(-70.0, 70.0), 0.0, _rng.randf_range(-70.0, 70.0))
		if GRAVEYARD.grow(1.0).has_point(Vector2(p.x, p.z)) or not _room_for(p, 2.2):
			continue
		_piece("manor_tree", p, ManorMeshes.NATIVE["manor_tree"] * _rng.randf_range(0.8, 1.35), _rng.randf() * TAU, Vector3(0.9, 4.0, 0.9))
		_keep(p, 1.5, false)
		placed += 1
	placed = 0
	tries = 0
	while placed < 55 and tries < 2400:
		tries += 1
		var p := Vector3(_rng.randf_range(-70.0, 70.0), 0.0, _rng.randf_range(-70.0, 70.0))
		if not _room_for(p, 1.2):
			continue
		var s := _rng.randf_range(0.7, 1.3)
		_piece("manor_thorns", p, ManorMeshes.NATIVE["manor_thorns"] * s, _rng.randf() * TAU, Vector3(1.2, 0.9, 1.2) * s)
		_keep(p, 0.8, false)
		placed += 1
	# Family plots: a few headstones huddled together out in the grounds.
	for plot in 4:
		for _try in 40:
			var c := Vector3(_rng.randf_range(-60.0, 66.0), 0.0, _rng.randf_range(-66.0, 66.0))
			if GRAVEYARD.grow(4.0).has_point(Vector2(c.x, c.z)) or not _room_for(c, 4.0):
				continue
			for k in _rng.randi_range(3, 6):
				var p := c + Vector3(float(k % 3) * 1.9 - 1.9, 0.0, float(k / 3) * 2.4 - 1.2) + Vector3(_rng.randf_range(-0.2, 0.2), 0.0, _rng.randf_range(-0.2, 0.2))
				var key := "manor_tomb_round" if _rng.randf() < 0.65 else "manor_tomb_cross"
				_piece(key, p, ManorMeshes.NATIVE[key] * _rng.randf_range(0.85, 1.2), _rng.randf_range(-0.2, 0.2), Vector3(0.7, 1.1, 0.3), Vector2(_rng.randf_range(-0.15, 0.15), _rng.randf_range(-0.2, 0.2)))
			_keep(c, 4.0, false)
			break
	# Open graves, rubble, carts, crates: the estate going to ruin.
	var kinds := [["grave", 5], ["rubble", 8], ["cart", 2]]
	for kd: Array in kinds:
		var left := int(kd[1])
		tries = 0
		while left > 0 and tries < 400:
			tries += 1
			var p := Vector3(_rng.randf_range(-68.0, 68.0), 0.0, _rng.randf_range(-68.0, 68.0))
			if not _room_for(p, 2.0):
				continue
			match String(kd[0]):
				"grave":
					var yaw := _rng.randf() * TAU
					_piece("manor_coffin", p, ManorMeshes.NATIVE["manor_coffin"], yaw, Vector3(0.9, 0.5, 2.0))
					var side := Basis.from_euler(Vector3(0.0, yaw, 0.0)) * Vector3(1.6, 0.0, 0.0)
					_piece("manor_mound", p + side, ManorMeshes.NATIVE["manor_mound"], yaw, Vector3(1.3, 0.6, 2.0))
				"rubble":
					_piece("ruin_rubble", p, Vector3(2.0, 0.9, 2.0) * _rng.randf_range(0.7, 1.3), _rng.randf() * TAU, Vector3(1.4, 0.6, 1.4))
				_:
					_piece("manor_cart", p, ManorMeshes.NATIVE["manor_cart"], _rng.randf() * TAU, Vector3(1.6, 1.1, 2.4))
			_keep(p, 2.5, false)
			left -= 1
	# Dying lamps along the ways: pools of guttering light you run between.
	for at: Vector3 in [Vector3(4.0, 0.0, 44.0), Vector3(-4.0, 0.0, 66.0), Vector3(36.0, 0.0, 19.0), Vector3(-28.0, 0.0, -3.0), Vector3(30.0, 0.0, -30.0), Vector3(-30.0, 0.0, 30.0)]:
		_lamp_post(at, false, true)


## Thick copses in the empty corners: the strip behind the manor, the west edge past the chapel,
## the south-east field. Trees close together, thorns between them.
func _build_copses() -> void:
	var areas: Array[Rect2] = [Rect2(-66.0, -71.0, 132.0, 7.0), Rect2(-72.0, 18.0, 9.0, 52.0), Rect2(42.0, 44.0, 28.0, 26.0), Rect2(-72.0, -70.0, 6.0, 38.0)]
	for area: Rect2 in areas:
		var x := area.position.x
		while x < area.end.x:
			var z := area.position.y
			while z < area.end.y:
				var p := Vector3(x + _rng.randf_range(-1.6, 1.6), 0.0, z + _rng.randf_range(-1.6, 1.6))
				z += 4.6
				if not _room_for(p, 1.2):
					continue
				if _rng.randf() < 0.7:
					_piece("manor_tree", p, ManorMeshes.NATIVE["manor_tree"] * _rng.randf_range(0.85, 1.4), _rng.randf() * TAU, Vector3(0.9, 4.0, 0.9))
					_keep(p, 1.2, false)
				else:
					var sc := _rng.randf_range(0.8, 1.3)
					_piece("manor_thorns", p, ManorMeshes.NATIVE["manor_thorns"] * sc, _rng.randf() * TAU, Vector3(1.2, 0.9, 1.2) * sc)
					_keep(p, 0.8, false)
			x += 4.6


## The hanged: bodies in burial shrouds on ropes from the long limbs of dead trees and from two
## gallows, turning slowly, the ropes creaking. Each is its own node (they move); the trees and the
## gallows go in the batch. A body is solid (you don't walk through it) and on the grid.
func _build_hangings() -> void:
	var tree_spots: Array[Vector3] = [Vector3(-30.0, 0.0, -20.0), Vector3(-66.0, 0.0, 28.0), Vector3(36.0, 0.0, -20.0), Vector3(62.0, 0.0, -10.0),
		Vector3(-8.0, 0.0, 68.0), Vector3(50.0, 0.0, 58.0), Vector3(-40.0, 0.0, -40.0), Vector3(24.0, 0.0, -66.0), Vector3(-44.0, 0.0, 30.0)]
	for at: Vector3 in tree_spots:
		for _try in 6:
			var yaw := _rng.randf() * TAU
			var sc := _rng.randf_range(0.95, 1.12)
			var basis := Basis.from_euler(Vector3(0.0, yaw, 0.0))
			var hang := at + basis * (ManorMeshes.HANG_POINT * sc)
			if not _room_for(at, 1.5) or not _room_for(Vector3(hang.x, 0.0, hang.z), 0.6):
				at += Vector3(_rng.randf_range(-3.0, 3.0), 0.0, _rng.randf_range(-3.0, 3.0))
				continue
			_piece("manor_hang_tree", at, ManorMeshes.NATIVE["manor_hang_tree"] * sc, yaw, Vector3(0.9, 4.0, 0.9))
			_keep(at, 1.5, false)
			_hang_body(hang, _rng.randf_range(0.95, 1.08))
			break
	for g: Array in [[Vector3(-46.0, 0.0, 64.0), 0.2, 3], [Vector3(40.0, 0.0, 9.0), -0.3, 2]]:
		var at: Vector3 = g[0]
		var yaw := float(g[1])
		var basis := Basis.from_euler(Vector3(0.0, yaw, 0.0))
		_piece("manor_gallows", at, ManorMeshes.NATIVE["manor_gallows"], yaw)
		for x: float in [-1.5, 1.5]:
			var post := at + basis * Vector3(x, 0.0, 0.0)
			_batch.add_solid(post + Vector3(0.0, 1.9, 0.0), Vector3(0.24, 3.8, 0.24), yaw)
			_block(post, Vector3(0.3, 1.0, 0.3), yaw)
		var n := int(g[2])
		for k in n:
			var pt: Vector3 = ManorMeshes.GALLOWS_POINTS[k if n == 3 else k * 2]
			_hang_body(at + basis * pt, _rng.randf_range(0.95, 1.06))
		_keep(at, 3.0, false)


func _hang_body(top: Vector3, sc: float) -> void:
	var pivot := Node3D.new()
	pivot.position = top
	_root.add_child(pivot)
	var mi := MeshInstance3D.new()
	mi.mesh = PropMeshes.mesh("manor_hanged")
	mi.material_override = PropMeshes.material()
	mi.scale = Vector3.ONE * sc
	pivot.add_child(mi)
	_hanged.append([pivot, _rng.randf() * TAU, sc])
	hang_points.append(top)
	var feet := top - Vector3(0.0, 1.6 * sc, 0.0)
	var body := StaticBody3D.new()
	body.collision_layer = ChainBody.LAYER_WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.36, 1.3 * sc, 0.36)
	cs.shape = box
	body.add_child(cs)
	body.position = feet
	_root.add_child(body)
	_block(Vector3(feet.x, 0.0, feet.z), Vector3(0.4, 1.0, 0.4))
	var creak := Sfx.loop_player("creak", -26.0, 11.0)
	creak.pitch_scale = _rng.randf_range(0.45, 0.7)
	creak.position = top - Vector3(0.0, 0.2, 0.0)
	_root.add_child(creak)
	Sfx.start_loop(creak)


## Tall dead grass in fields all over the grounds (round the trees and headstones, never on a
## path, a doorway or a machine): drawn only, you wade through it.
func _build_grass() -> void:
	var fields := 0
	var tries := 0
	while fields < 70 and tries < 900:
		tries += 1
		var c := Vector3(_rng.randf_range(-70.0, 70.0), 0.0, _rng.randf_range(-70.0, 70.0))
		if not _grass_ok(c):
			continue
		fields += 1
		if fields == 1:
			test_points["grass"] = c + Vector3(0.0, 0.1, 0.0)
		var radius := _rng.randf_range(3.0, 7.5)
		for k in _rng.randi_range(34, 60):  # thick: a field you wade through, not tufts
			var a := _rng.randf() * TAU
			var q := c + Vector3(cos(a), 0.0, sin(a)) * radius * _rng.randf()  # bunched toward the middle
			if not _grass_ok(q):
				continue
			var sc := _rng.randf_range(0.7, 1.35)
			_batch.add_prop("manor_grass", ManorMeshes.fit("manor_grass", q, ManorMeshes.NATIVE["manor_grass"] * Vector3(sc, sc * _rng.randf_range(0.85, 1.2), sc), Basis.from_euler(Vector3(0.0, _rng.randf() * TAU, 0.0))))
	# A fringe along the foot of the estate wall, where nobody ever cut it.
	for k in 160:
		var side := k % 4
		var a := _rng.randf_range(-HALF + 2.0, HALF - 2.0)
		var d := HALF - _rng.randf_range(1.2, 3.0)
		var q := Vector3(a, 0.0, -d) if side == 0 else (Vector3(a, 0.0, d) if side == 1 else (Vector3(-d, 0.0, a) if side == 2 else Vector3(d, 0.0, a)))
		if _grass_ok(q):
			var sc := _rng.randf_range(0.8, 1.4)
			_batch.add_prop("manor_grass", ManorMeshes.fit("manor_grass", q, ManorMeshes.NATIVE["manor_grass"] * sc, Basis.from_euler(Vector3(0.0, _rng.randf() * TAU, 0.0))))


func _grass_ok(q: Vector3) -> bool:
	if absf(q.x) > HALF - 1.0 or absf(q.z) > HALF - 1.0:
		return false
	var q2 := Vector2(q.x, q.z)
	for r: Rect2 in [MANSION, CRYPT, CHAPEL, GREENHOUSE, STABLES]:
		if r.grow(0.6).has_point(q2):
			return false
	for k: Array in _keepout:
		if bool(k[2]) and q2.distance_to(k[0]) < float(k[1]):
			return false
	return is_walkable(_cell(q))


## Low banks of fog creeping across the grounds on the wind (volumetric fog, high quality): thick
## at knee height, thinning upward, drifting through each other.
func _build_fog_banks() -> void:
	for k in 24:
		var fv := FogVolume.new()
		fv.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
		fv.size = Vector3(_rng.randf_range(14.0, 26.0), _rng.randf_range(2.2, 3.6), _rng.randf_range(10.0, 18.0))
		var fm := FogMaterial.new()
		fm.density = _rng.randf_range(0.22, 0.45)
		fm.albedo = Color(0.62, 0.66, 0.66)
		fm.height_falloff = 0.5
		fm.edge_fade = 0.75
		fv.material = fm
		fv.position = Vector3(_rng.randf_range(-HALF, HALF), 0.7, _rng.randf_range(-HALF, HALF))
		_root.add_child(fv)
		_fog_banks.append([fv, _rng.randf_range(0.25, 0.6)])


## Beyond the wall: a black wood, dead trunks crowding up to the stone, more and more of them lost
## in the fog. Drawn only; the wall keeps you in.
func _build_forest() -> void:
	var d := HALF + 4.0
	while d < 100.0:
		var step := 4.5 + (d - HALF) * 0.08
		var a := -100.0
		while a < 100.0:
			for side in 4:
				var p := Vector3.ZERO
				match side:
					0: p = Vector3(a, 0.0, -d)
					1: p = Vector3(a, 0.0, d)
					2: p = Vector3(-d, 0.0, a)
					_: p = Vector3(d, 0.0, a)
				if side == 1 and absf(a) < 9.0:
					continue  # the lane out
				p += Vector3(_rng.randf_range(-1.5, 1.5), 0.0, _rng.randf_range(-1.5, 1.5))
				_batch.add_prop("manor_tree", ManorMeshes.fit("manor_tree", p, ManorMeshes.NATIVE["manor_tree"] * _rng.randf_range(1.1, 1.8), Basis.from_euler(Vector3(0.0, _rng.randf() * TAU, 0.0))))
			a += step
		d += 6.0


func _build_moon() -> void:
	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.55, 0.62, 0.82)
	moon.light_energy = 0.1
	moon.light_volumetric_fog_energy = 0.25
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 60.0
	moon.rotation = Vector3(deg_to_rad(-32.0), deg_to_rad(-140.0), 0.0)
	add_child(moon)


func _build_keeper() -> void:
	keeper = Groundskeeper.new()
	keeper.name = "Groundskeeper"
	keeper.level = self
	keeper.floor_index = 0
	keeper.floor_y = origin.y
	keeper.position = KEEPER_HOME
	keeper.synced_yaw = _rng.randf() * TAU
	keeper.asleep = embedded  # in the Stack it waits in the graveyard until the helicopter brings the Line
	add_child(keeper)


func _build_ambience() -> void:
	_wind = AudioStreamPlayer.new()
	_wind.stream = Sfx.stream("wind")
	_wind.volume_db = -20.0
	add_child(_wind)
	Sfx.start_loop(_wind)


## Every test point is a world position (the build's own ones, like "grass", are local until here,
## and so are the hanging points).
func _test_points() -> void:
	for key in test_points:
		if test_points[key] is Vector3:
			test_points[key] = origin + (test_points[key] as Vector3)
	for i in hang_points.size():
		hang_points[i] += origin
	test_points["spawn"] = spawn_position
	test_points["m_spawn"] = spawn_position
	for i in machines.size():
		var m := machines[i]
		test_points["engine%d" % i] = m.global_position + m.global_transform.basis.z * 1.3 + Vector3(0.0, 0.1, 0.0)
	test_points["m_engine"] = test_points["engine0"]
	test_points["generator"] = origin + MAIN_SPOT + Vector3(0.0, 0.1, 1.8)
	test_points["m_generator"] = test_points["generator"]
	test_points["gate_inside"] = origin + Vector3(0.0, 0.1, GATE_Z - 3.0)
	test_points["m_gate"] = test_points["gate_inside"]
	test_points["exit"] = origin + Vector3(0.0, 0.1, EXIT_Z + 4.0)
	test_points["m_mansion"] = origin + Vector3(0.0, 0.1, MANSION.end.y + 2.5)
	test_points["m_graveyard"] = origin + Vector3(GRAVEYARD.end.x + 2.0, 0.1, 0.0)
	test_points["foyer"] = origin + Vector3(0.0, 0.1, -44.0)
	test_points["keeper_home"] = origin + KEEPER_HOME


# --- Every peer ----------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not _shown:
		return  # in the Stack, with the camera up in the building
	_t += delta
	# The hanged turn slowly on their ropes and sway a little; the fog creeps along on the wind.
	for h: Array in _hanged:
		var pivot := h[0] as Node3D
		var ph := float(h[1])
		pivot.rotation = Vector3(0.05 * sin(_t * 0.7 + ph), 0.5 * sin(_t * 0.23 + ph * 2.0), 0.06 * sin(_t * 0.55 + ph * 1.3))
	for f: Array in _fog_banks:
		var fv := f[0] as FogVolume
		fv.position.x += float(f[1]) * delta
		fv.position.z += float(f[1]) * 0.3 * delta
		if fv.position.x > HALF + 12.0:
			fv.position.x -= (HALF + 12.0) * 2.0
		if fv.position.z > HALF + 12.0:
			fv.position.z -= (HALF + 12.0) * 2.0
	for f: Array in _flickers:
		var light := f[0] as OmniLight3D
		var base := float(f[2])
		var ph := float(f[3])
		var n := 0.75 + 0.25 * sin(_t * 9.0 + ph) * sin(_t * 3.7 + ph * 2.0)
		if fmod(_t * 0.37 + ph, 5.0) < 0.12:
			n *= 0.15  # a gutter
		light.light_energy = base * n
		if f[1] != null:
			(f[1] as StandardMaterial3D).emission_energy_multiplier = 0.4 + 2.2 * n
	for l: Array in _court_lamps:
		var on := 1.0 if _lamps_on else 0.0
		(l[0] as OmniLight3D).light_energy = lerpf((l[0] as OmniLight3D).light_energy, 1.1 * on, clampf(delta * 2.0, 0.0, 1.0))
		(l[1] as StandardMaterial3D).emission_energy_multiplier = (l[0] as OmniLight3D).light_energy * 2.6
	# A bell tolls now and then, somewhere off in the fog.
	_toll_t -= delta
	if _toll_t <= 0.0:
		_toll_t = randf_range(55.0, 95.0)
		var me := Net.get_local_player()
		if me != null:
			var a := randf() * TAU
			Sfx.play_at(self, "toll", me.global_position + Vector3(cos(a) * 40.0, 8.0, sin(a) * 40.0), -6.0, randf_range(0.9, 1.0), 120.0)


@rpc("authority", "call_local", "reliable")
func _rpc_toll() -> void:
	Sfx.play_at(self, "toll", generator.global_position + Vector3(0.0, 6.0, 0.0), 6.0, 0.85, 200.0)
	Sfx.caption(self, "a bell tolls: the generator can be thrown", generator.global_position)


@rpc("authority", "call_local", "reliable")
func _rpc_lights_on() -> void:
	_lamps_on = true
	Sfx.play_at(self, "toll", generator.global_position + Vector3(0.0, 6.0, 0.0), 8.0, 0.7, 200.0)
	var me := Net.get_local_player()
	if me != null:
		me.add_shake(0.4)


# --- The level surface (the same as LevelStack's and HordeArena's) ------------------------------

func level_index_at(_p: Vector3) -> int:
	return 3


func floor_of(_y: float) -> int:
	return 0


func floor_name(_y: float) -> String:
	return FLOOR_NAME


func in_mansion(p: Vector3) -> bool:
	var l := Vector2(p.x - origin.x, p.z - origin.z)
	return MANSION.has_point(l) or CRYPT.has_point(l)


func has_ceiling_at(p: Vector3) -> bool:
	return in_mansion(p)


func is_safe_spot(_p: Vector3) -> bool:
	return false


func ceiling_y(p: Vector3) -> float:
	var l := Vector2(p.x - origin.x, p.z - origin.z)
	return origin.y + ROOM_H if MANSION.has_point(l) else (origin.y + 4.2 if CRYPT.has_point(l) else p.y + 40.0)


func scare_pool(_p: Vector3) -> Array:
	return SCARE_POOL


func paces_own_scares(_p: Vector3) -> bool:
	return false


func play_scare(_kind: String, _pos: Vector3, _targeted: bool) -> void:
	pass


func refresh_environment() -> void:
	if _we != null:
		_we.environment = LevelKit.make_environment(Settings.quality, 3)


## Every peer: the Stack hides the estate (and hushes its wind) while the camera is in the building.
func set_shown(on: bool) -> void:
	if on == _shown:
		return
	_shown = on
	visible = on
	if on:
		Sfx.start_loop(_wind)
	else:
		_wind.stop()


func car_busy() -> bool:
	return false


func last_layoff_msec() -> int:
	return _last_layoff_msec


func engines_running() -> int:
	var n := 0
	for m in machines:
		if m.done:
			n += 1
	return n


# --- Server --------------------------------------------------------------------------------------

## On its own the Line starts here; in the Stack the pickups wait for the helicopter (server_arrive).
func server_populate() -> void:
	if not multiplayer.is_server() or embedded:
		return
	server_arrive()


func _spawn_pickups() -> void:
	_populated = true
	for p: Array in [["decoy", Vector3(56.0, 0.0, 30.0)], ["flashlight", SPAWN + Vector3(-2.0, 0.0, 2.0)], ["drink", Vector3(4.0, 0.0, -44.0)],
			["pistol", Vector3(17.0, 0.0, -59.0)], ["ammo", Vector3(19.0, 0.0, -59.0)], ["airhorn", Vector3(-44.0, 0.0, 50.0)],
			["ammo", Vector3(-40.0, 0.0, 16.0)], ["decoy", Vector3(-20.0, 0.0, 44.0)], ["bomb", Vector3(66.0, 0.0, -66.0)]]:
		Net.spawn_pickup(String(p[0]), origin + (p[1] as Vector3), 0)


## Server: the Line is on the grounds (at once on its own; off the helicopter in the Stack). The
## pickups come out, the checklist goes up, and the Groundskeeper wakes and starts its rounds.
func server_arrive() -> void:
	if not multiplayer.is_server():
		return
	if not _populated:
		_spawn_pickups()
	GameState.set_tasks(PackedStringArray(TASKS))
	_arrived = true
	keeper.asleep = false
	_draw_t = 20.0
	GameState.post_message("ASHGRAVE MANOR. Four old engines are out there in the fog. Get them all running, then the main generator, then the gate.", 6.0)


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or not _arrived or keeper == null:
		return
	_tick_draw(delta)
	_tick_kick(delta)
	_tick_respawn(delta)
	_tick_endgame(delta)
	if gate.is_open() and not _gate_cell_open:
		_gate_cell_open = true
		_astar.set_point_solid(_cell(Vector3(0.0, 0.0, GATE_Z)), false)
	_tick_escape()


## Work on an engine carries: every so often the Groundskeeper is sent to one being worked on.
func _tick_draw(delta: float) -> void:
	if keeper.is_hunting() or keeper.is_dead() or keeper.hstate == HollowHire.HState.STUNNED:
		return
	var worked: Array[ManorMachine] = []
	for m in machines:
		if m.working:
			worked.append(m)
	if generator.working:
		worked.append(generator)
	if worked.is_empty():
		return
	_draw_t -= delta
	if _draw_t > 0.0:
		return
	_draw_t = _rng.randf_range(DRAW_EVERY.x, DRAW_EVERY.y)
	var m: ManorMachine = worked[_rng.randi_range(0, worked.size() - 1)]
	keeper.alert(m.global_position, DRAW_ALERT)


## A half-done engine it passes with nobody at it gets the boot.
func _tick_kick(delta: float) -> void:
	_kick_t -= delta
	if _kick_t > 0.0:
		return
	_kick_t = 0.4
	var hs := keeper.hstate
	if hs != HollowHire.HState.WANDER and hs != HollowHire.HState.INVESTIGATE and hs != HollowHire.HState.SWEEP:
		return
	var now := Time.get_ticks_msec()
	for m in machines:
		if m.done or m.progress <= 0.0 or m.working or m.regressing:
			continue
		if now < int(_kick_cd.get(m.index, 0)):
			continue
		var d := Vector2(m.global_position.x - keeper.global_position.x, m.global_position.z - keeper.global_position.z).length()
		if d < KICK_RANGE and m.server_kick():
			_kick_cd[m.index] = now + KICK_COOLDOWN_MS
			keeper.debug_face(m.global_position)
			keeper.debug_sweep()  # and it stands there looking for whoever was at it


func _tick_respawn(delta: float) -> void:
	if not keeper.is_dead():
		_respawn_t = RESPAWN_SECONDS
		return
	_respawn_t -= delta
	if _respawn_t > 0.0:
		return
	_respawn_t = RESPAWN_SECONDS
	var spot := _hidden_spot()
	if spot != Vector3.INF:
		keeper.respawn_at(spot)


## Somewhere on the grounds nobody can see and nobody is near.
func _hidden_spot() -> Vector3:
	var space := get_world_3d().direct_space_state
	for _try in 60:
		var c := random_cell(_rng)
		var at := cell_center(0, c)
		var ok := true
		for p in Net.get_players():
			if p.global_position.distance_to(at) < 30.0:
				ok = false
				break
			var q := PhysicsRayQueryParameters3D.create(p.eye_position(), at + Vector3(0.0, 1.6, 0.0), ChainBody.LAYER_WORLD)
			if space.intersect_ray(q).is_empty() and p.global_position.distance_to(at) < 45.0:
				ok = false
				break
		if ok:
			return at
	return Vector3.INF


## Once the generator runs it simply knows where you are.
func _tick_endgame(delta: float) -> void:
	if not _endgame:
		return
	_endgame_t -= delta
	if _endgame_t > 0.0:
		return
	_endgame_t = ENDGAME_HUNT
	if keeper.is_hunting() or keeper.is_dead():
		return
	var ps := Net.get_players()
	if not ps.is_empty():
		keeper.alert(ps[_rng.randi_range(0, ps.size() - 1)].global_position, ENDGAME_HUNT + 3.0)


func _tick_escape() -> void:
	if GameState.escaped or not gate.is_open():
		return
	var ps := Net.get_players()
	if ps.is_empty():
		return
	for p in ps:
		if p.global_position.z - origin.z < EXIT_Z or p.is_grabbed():
			return
	GameState.complete_task(TASK_OUT)
	GameState.set_escaped("Out of Ashgrave Manor's south gate and down the lane, with the Groundskeeper's lantern swinging behind you in the fog.")


## Server: an engine (or the main generator) just finished.
func on_machine_done(m: ManorMachine) -> void:
	if not multiplayer.is_server():
		return
	if m.is_main:
		_on_generator_started()
		return
	var n := engines_running()
	GameState.set_task_text(TASK_ENGINES, "Get the four engines running (%d of 4): crouch at one and hold Ctrl" % n)
	if n >= machines.size():
		GameState.complete_task(TASK_ENGINES)
		generator.server_arm()
		_rpc_toll.rpc()
		GameState.post_message("ALL FOUR ENGINES ARE RUNNING. The main generator in the courtyard is live: hold Ctrl at it to throw the switch.", 6.0)
		keeper.alert(generator.global_position, 25.0)
	else:
		GameState.post_message("An engine is running. %d of 4." % n, 3.5)


func _on_generator_started() -> void:
	GameState.complete_task(TASK_SWITCH)
	gate.server_open()
	_rpc_lights_on.rpc()
	_endgame = true
	_endgame_t = 2.0
	GameState.post_message("THE GATE IS OPENING. South down the drive and out, all of you. It knows where you are now.", 6.0)


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
	GameState.post_message("%s called everyone back to the stables." % requester, 3.5)


func _respawn_group() -> void:
	var bodies := Net.get_chain_bodies()
	var facing := GameState.checkpoint_facing
	var right := Vector3(cos(facing), 0.0, -sin(facing))
	var n := bodies.size()
	for i in n:
		var offset := right * (float(i) * 1.0 - float(n - 1) * 0.5)
		bodies[i].teleport_to(GameState.checkpoint_position + offset + Vector3(0.0, 0.2, 0.0), facing)
	server_on_respawn()


## Server: the Line is back at the stables. The engines that run keep running; the Groundskeeper
## goes back to the graveyard.
func server_on_respawn() -> void:
	if keeper != null and not keeper.is_dead():
		keeper.release(false)
		keeper.debug_reset(origin + KEEPER_HOME, _rng.randf() * TAU)
	_draw_t = 20.0
