class_name HordeField
extends RefCounted
## A flow field on a flat grid: every walkable cell knows which way to step to reach the nearest
## goal (a chained player, or something loud). The horde never pathfinds: an agent reads the
## direction of the cell it stands in. The field is rebuilt continuously in slices, a few hundred
## cells per physics tick, so a thousand agents never wait on a frame-long search:
##   phase 1  multi-source breadth-first flood (4-neighbour) from every goal cell
##   phase 2  per-cell direction: the sum of the down-slope steps to its 8 neighbours, so diagonal
##            flow is smooth instead of staircased
## The finished arrays are swapped in at once, so agents always read a complete field.
## Blocked cells come from the level (walls, fences); diagonals never cut a blocked corner.
## Terrain: every cell is FLOOR (walkable, with a ground height), WALL (a thing in the way) or
## VOID (the street between rooftops: blocked for anything that walks, but a climber can look
## across it for the next roof and swing). Heights let a swarm live on rooftops at different
## levels: a walker reads the ground under it from its cell.

const UNREACHED: int = 0x3FFFFFFF
const FLOOR: int = 0
const WALL: int = 1
const VOID: int = 2

var cell: float = 1.0  # meters
var origin: Vector2 = Vector2.ZERO  # world (x, z) of the corner of cell (0, 0)
var w: int = 0
var h: int = 0
var blocked: PackedByteArray = PackedByteArray()
var terrain: PackedByteArray = PackedByteArray()  # FLOOR / WALL / VOID per cell
var height: PackedFloat32Array = PackedFloat32Array()  # ground y per cell (world)
var base_y: float = 0.0  # the ground where nothing else is said
var cost: PackedInt32Array = PackedInt32Array()  # steps to the nearest goal, UNREACHED beyond walls
var dir_x: PackedFloat32Array = PackedFloat32Array()
var dir_z: PackedFloat32Array = PackedFloat32Array()
var builds: int = 0  # how many complete fields have been produced (tests, stats)

var _next_cost: PackedInt32Array = PackedInt32Array()
var _next_dx: PackedFloat32Array = PackedFloat32Array()
var _next_dz: PackedFloat32Array = PackedFloat32Array()
var _queue: PackedInt32Array = PackedInt32Array()
var _q_head: int = 0
var _q_tail: int = 0
var _phase: int = 0  # 0 idle, 1 flooding, 2 directions
var _dir_i: int = 0


func setup(world_origin: Vector2, width_m: float, depth_m: float, cell_size: float = 1.0, ground_y: float = 0.0) -> void:
	base_y = ground_y
	cell = cell_size
	origin = world_origin
	w = maxi(1, int(ceil(width_m / cell)))
	h = maxi(1, int(ceil(depth_m / cell)))
	var n := w * h
	blocked = PackedByteArray()
	blocked.resize(n)
	blocked.fill(0)
	terrain = PackedByteArray()
	terrain.resize(n)
	terrain.fill(FLOOR)
	height = PackedFloat32Array()
	height.resize(n)
	height.fill(base_y)
	cost = PackedInt32Array()
	cost.resize(n)
	cost.fill(UNREACHED)
	dir_x = PackedFloat32Array()
	dir_x.resize(n)
	dir_x.fill(0.0)
	dir_z = PackedFloat32Array()
	dir_z.resize(n)
	dir_z.fill(0.0)
	_next_cost = cost.duplicate()
	_next_dx = dir_x.duplicate()
	_next_dz = dir_z.duplicate()
	_queue = PackedInt32Array()
	_queue.resize(n)
	_phase = 0


func cell_count() -> int:
	return w * h


func cell_x(x: float) -> int:
	return clampi(int(floorf((x - origin.x) / cell)), 0, w - 1)


func cell_z(z: float) -> int:
	return clampi(int(floorf((z - origin.y) / cell)), 0, h - 1)


func index_at(x: float, z: float) -> int:
	return cell_z(z) * w + cell_x(x)


func in_bounds(x: float, z: float) -> bool:
	return x >= origin.x and z >= origin.y and x < origin.x + float(w) * cell and z < origin.y + float(h) * cell


## Marks every cell touched by a world-space rectangle (x, z, width, depth) as a wall.
func block_rect(r: Rect2) -> void:
	var x0 := cell_x(r.position.x + 0.001)
	var x1 := cell_x(r.end.x - 0.001)
	var z0 := cell_z(r.position.y + 0.001)
	var z1 := cell_z(r.end.y - 0.001)
	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			blocked[z * w + x] = 1
			terrain[z * w + x] = WALL


## A box footprint centred at (cx, cz) with size (sx, sz), padded so bodies don't clip the wall.
func block_box(cx: float, cz: float, sx: float, sz: float, pad: float = 0.3) -> void:
	block_rect(Rect2(cx - sx * 0.5 - pad, cz - sz * 0.5 - pad, sx + pad * 2.0, sz + pad * 2.0))



## Every cell becomes the street: nothing walks until a roof is laid over it.
func fill_void() -> void:
	blocked.fill(1)
	terrain.fill(VOID)
	height.fill(base_y)


## A rooftop (or any floor) over a world-space rectangle at a height: walkable again.
func set_floor_rect(r: Rect2, y: float) -> void:
	var x0 := cell_x(r.position.x + 0.001)
	var x1 := cell_x(r.end.x - 0.001)
	var z0 := cell_z(r.position.y + 0.001)
	var z1 := cell_z(r.end.y - 0.001)
	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			var i := z * w + x
			blocked[i] = 0
			terrain[i] = FLOOR
			height[i] = y


func height_at(x: float, z: float) -> float:
	if not in_bounds(x, z):
		return base_y
	return height[index_at(x, z)]


func terrain_at(x: float, z: float) -> int:
	if not in_bounds(x, z):
		return VOID
	return terrain[index_at(x, z)]


func is_void(x: float, z: float) -> bool:
	return terrain_at(x, z) == VOID


## For a climber at a roof's edge: the first FLOOR cell along a direction within `range_m`, as
## (world x, world z, ground y), or an empty array when there's nothing to swing to. Cells of
## WALL on the way don't stop the look (a parapet on the far roof is fine to land behind).
func floor_ahead(x: float, z: float, dx: float, dz: float, range_m: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var steps := int(range_m / cell)
	var sx := x
	var sz := z
	var seen_void := false
	for k in steps:
		sx += dx * cell
		sz += dz * cell
		if not in_bounds(sx, sz):
			return out
		var i := index_at(sx, sz)
		var t := terrain[i]
		if t == VOID:
			seen_void = true
		elif t == FLOOR and seen_void:
			var cx := origin.x + (floorf((sx - origin.x) / cell) + 0.5) * cell
			var cz := origin.y + (floorf((sz - origin.y) / cell) + 0.5) * cell
			out.append(cx)
			out.append(cz)
			out.append(height[i])
			return out
	return out

func is_blocked(x: float, z: float) -> bool:
	if not in_bounds(x, z):
		return true
	return blocked[index_at(x, z)] != 0


## Unit (x, z) step toward the nearest goal from a world position; zero at a goal or where
## nothing is reachable.
func direction_at(x: float, z: float) -> Vector2:
	if not in_bounds(x, z):
		return Vector2.ZERO
	var i := index_at(x, z)
	return Vector2(dir_x[i], dir_z[i])


func cost_at(x: float, z: float) -> int:
	if not in_bounds(x, z):
		return UNREACHED
	return cost[index_at(x, z)]


func is_building() -> bool:
	return _phase != 0


## Starts a fresh build from these goal positions (world x, z). Any build in progress is dropped.
func start_build(goals: PackedVector2Array) -> void:
	var n := w * h
	_next_cost.fill(UNREACHED)
	_q_head = 0
	_q_tail = 0
	for g in goals:
		if not in_bounds(g.x, g.y):
			continue
		var i := index_at(g.x, g.y)
		if blocked[i] != 0 or _next_cost[i] == 0:
			continue
		_next_cost[i] = 0
		_queue[_q_tail] = i
		_q_tail += 1
	_phase = 1 if _q_tail > 0 else 0
	_dir_i = 0
	if _phase == 0:
		# Nobody to walk to: a blank field, swapped in at once so agents stop.
		_next_dx.fill(0.0)
		_next_dz.fill(0.0)
		_swap()
	elif n == 0:
		_phase = 0


## Does up to `budget` cell visits of the current build. Returns true when a build completed
## this call (and the new field is live).
func step(budget: int) -> bool:
	if _phase == 1:
		var left := budget
		var ncost := _next_cost
		var q := _queue
		var blk := blocked
		var width := w
		var height := h
		while _q_head < _q_tail and left > 0:
			var i := q[_q_head]
			_q_head += 1
			left -= 1
			var c := ncost[i] + 1
			var x := i % width
			var z := i / width
			if x > 0:
				var j := i - 1
				if blk[j] == 0 and ncost[j] > c:
					ncost[j] = c
					q[_q_tail] = j
					_q_tail += 1
			if x < width - 1:
				var j := i + 1
				if blk[j] == 0 and ncost[j] > c:
					ncost[j] = c
					q[_q_tail] = j
					_q_tail += 1
			if z > 0:
				var j := i - width
				if blk[j] == 0 and ncost[j] > c:
					ncost[j] = c
					q[_q_tail] = j
					_q_tail += 1
			if z < height - 1:
				var j := i + width
				if blk[j] == 0 and ncost[j] > c:
					ncost[j] = c
					q[_q_tail] = j
					_q_tail += 1
		_next_cost = ncost
		_queue = q
		if _q_head >= _q_tail:
			_phase = 2
			_dir_i = 0
		return false
	if _phase == 2:
		var left := budget
		var ncost := _next_cost
		var ndx := _next_dx
		var ndz := _next_dz
		var blk := blocked
		var width := w
		var height := h
		var n := width * height
		while _dir_i < n and left > 0:
			var i := _dir_i
			_dir_i += 1
			left -= 1
			var c := ncost[i]
			if blk[i] != 0 or c >= UNREACHED or c == 0:
				ndx[i] = 0.0
				ndz[i] = 0.0
				continue
			var x := i % width
			var z := i / width
			var sx := 0.0
			var sz := 0.0
			var open_l := x > 0 and blk[i - 1] == 0
			var open_r := x < width - 1 and blk[i + 1] == 0
			var open_u := z > 0 and blk[i - width] == 0
			var open_d := z < height - 1 and blk[i + width] == 0
			if open_l:
				var d := c - ncost[i - 1]
				if d > 0:
					sx -= float(d)
			if open_r:
				var d := c - ncost[i + 1]
				if d > 0:
					sx += float(d)
			if open_u:
				var d := c - ncost[i - width]
				if d > 0:
					sz -= float(d)
			if open_d:
				var d := c - ncost[i + width]
				if d > 0:
					sz += float(d)
			# Diagonals count only where both orthogonal neighbours are open: no corner cutting.
			if open_l and open_u and blk[i - width - 1] == 0:
				var d := c - ncost[i - width - 1]
				if d > 0:
					sx -= float(d) * 0.7071
					sz -= float(d) * 0.7071
			if open_r and open_u and blk[i - width + 1] == 0:
				var d := c - ncost[i - width + 1]
				if d > 0:
					sx += float(d) * 0.7071
					sz -= float(d) * 0.7071
			if open_l and open_d and blk[i + width - 1] == 0:
				var d := c - ncost[i + width - 1]
				if d > 0:
					sx -= float(d) * 0.7071
					sz += float(d) * 0.7071
			if open_r and open_d and blk[i + width + 1] == 0:
				var d := c - ncost[i + width + 1]
				if d > 0:
					sx += float(d) * 0.7071
					sz += float(d) * 0.7071
			var l := sqrt(sx * sx + sz * sz)
			if l > 0.0001:
				ndx[i] = sx / l
				ndz[i] = sz / l
			else:
				ndx[i] = 0.0
				ndz[i] = 0.0
		_next_dx = ndx
		_next_dz = ndz
		if _dir_i >= n:
			_swap()
			return true
	return false


func _swap() -> void:
	var c := cost
	cost = _next_cost
	_next_cost = c
	var dx := dir_x
	dir_x = _next_dx
	_next_dx = dx
	var dz := dir_z
	dir_z = _next_dz
	_next_dz = dz
	_phase = 0
	builds += 1
