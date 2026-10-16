class_name LevelStack
extends Node3D
## The Stack: every level of the building, built at once on every peer before connecting, so
## node paths match everywhere and nobody ever loads mid-game. Level 2 sits directly on top of
## Level 1: the freight car on B1 rides 5 m up its shaft into the pizzeria's Receiving room.
## This node is the "level" the rest of the game talks to (group "level"): floors, layoffs,
## regroups, scare pools. It forwards each question to whichever level a position is in.

const KILL_Y: float = -8.0
const LAYOFF_DELAY: float = 1.1
const REGROUP_COOLDOWN_MS: int = 15000
const CULL_INTERVAL: float = 0.25  # s between local visibility passes

var yellow: YellowRooms
var pizzeria: Pizzeria
var spawn_position: Vector3 = Vector3.ZERO
var spawn_facing: float = PI
var test_points: Dictionary = {}
var _we: WorldEnvironment
var _layoff_pending: bool = false
var _last_regroup_msec: int = -100000
var _cull_t: float = 0.0
var _local_level: int = -1


func _ready() -> void:
	add_to_group("level")
	_we = WorldEnvironment.new()
	_we.name = "WorldEnvironment"
	_we.camera_attributes = LevelKit.make_camera_attributes()
	add_child(_we)
	yellow = YellowRooms.new()
	yellow.name = "YellowRooms"
	add_child(yellow)
	# The pizzeria's Receiving room is centered right above the freight car.
	pizzeria = Pizzeria.new()
	pizzeria.name = "Pizzeria"
	pizzeria.arrive_center = yellow.elevator_center() + Vector3(0.0, YellowRooms.FLOOR_H, 0.0)
	pizzeria.checkpoint_base = YellowRooms.FLOORS
	add_child(pizzeria)
	spawn_position = yellow.spawn_position
	spawn_facing = yellow.spawn_facing
	test_points = yellow.test_points.duplicate()
	test_points.merge(pizzeria.test_points)
	refresh_environment()
	GameState.layoff_started.connect(func(_n: int, _r: String) -> void: _on_layoff())


## Which level a world position is in: 0 The Yellow Rooms, 1 the pizzeria.
func level_index_at(p: Vector3) -> int:
	return 1 if p.y > pizzeria.base_y() - 1.0 else 0


func level_at(p: Vector3) -> Node3D:
	return pizzeria if level_index_at(p) == 1 else yellow


## Floor number across the whole Stack (B4 = 0 ... B1 = 3, Dining Hall = 4 ...).
func floor_of(y: float) -> int:
	if y > pizzeria.base_y() - 1.0:
		return YellowRooms.FLOORS + pizzeria.floor_of(y)
	return yellow.floor_of(y)


func floor_name(y: float) -> String:
	if y > pizzeria.base_y() - 1.0:
		return Pizzeria.FLOOR_NAMES[pizzeria.floor_of(y)]
	return YellowRooms.FLOOR_NAMES[yellow.floor_of(y)]


## False where something can't reach down through the ceiling (holes, shafts, the freight car).
func has_ceiling_at(p: Vector3) -> bool:
	return bool(level_at(p).call("has_ceiling_at", p))


## Underside of the ceiling over a position (for falling tiles).
func ceiling_y(p: Vector3) -> float:
	if level_index_at(p) == 1:
		return pizzeria.ceiling_y(p)
	return float(yellow.floor_of(p.y)) * YellowRooms.FLOOR_H + YellowRooms.CEIL_H


## The procedural scares that make sense where the target stands: [[kind, weight], ...].
func scare_pool(p: Vector3) -> Array:
	return Pizzeria.SCARE_POOL if level_index_at(p) == 1 else YellowRooms.SCARE_POOL


## A level's own scare visuals (the pizzeria's); the office has none of its own.
func play_scare(kind: String, pos: Vector3, targeted: bool) -> void:
	pizzeria.play_scare(kind, pos, targeted)


## Rebuilds the lighting look for the level the local camera is in (Settings changes quality).
func refresh_environment() -> void:
	var lvl := maxi(_local_level, 0)
	_we.environment = LevelKit.make_environment(Settings.quality, lvl)


# --- Server -------------------------------------------------------------------------------------

## Spawns every pickup through the network spawner (once on the server after hosting).
func server_populate() -> void:
	yellow.server_populate()
	pizzeria.server_populate()


func request_layoff(reason: String) -> void:
	if not multiplayer.is_server() or _layoff_pending or GameState.escaped:
		return
	_layoff_pending = true
	GameState.layoff(reason)
	await get_tree().create_timer(LAYOFF_DELAY).timeout
	_respawn_group()
	_layoff_pending = false


## Server: "I'm stuck." Brings the whole Line back to the last Break Room without a layoff.
func regroup(requester: String) -> void:
	if not multiplayer.is_server() or _layoff_pending or GameState.escaped:
		return
	if yellow.car_busy():
		GameState.post_message("Hold on, the freight car is moving.", 2.5)
		return
	var now := Time.get_ticks_msec()
	if now - _last_regroup_msec < REGROUP_COOLDOWN_MS:
		GameState.post_message("Regroup is on cooldown. Hold on a few seconds.", 2.5)
		return
	_last_regroup_msec = now
	_respawn_group()
	GameState.post_message("%s called everyone back to the Break Room." % requester, 3.5)


func _respawn_group() -> void:
	var bodies := Net.get_chain_bodies()
	var facing := GameState.checkpoint_facing
	var right := Vector3(cos(facing), 0.0, -sin(facing))
	var n := bodies.size()
	for i in n:
		var offset := right * (float(i) * 1.0 - float(n - 1) * 0.5)
		bodies[i].teleport_to(GameState.checkpoint_position + offset + Vector3(0.0, 0.2, 0.0), facing)
	for c in get_tree().get_nodes_in_group("custodian"):
		c.call("blast")
	yellow.server_on_respawn()
	pizzeria.server_on_respawn()


func _on_layoff() -> void:
	if multiplayer.is_server():
		pizzeria.server_on_layoff()


func _physics_process(_delta: float) -> void:
	if not multiplayer.is_server():
		return
	for b in Net.get_chain_bodies():
		if b.global_position.y < KILL_Y:
			request_layoff("Someone fell out of the building. Somehow.")
			break


# --- Every peer: what to draw ---------------------------------------------------------------------

## Only the floors next to the camera are drawn (the rest of the Stack is behind concrete), and
## each level's ambience and lighting look follow the camera.
func _process(delta: float) -> void:
	_cull_t -= delta
	if _cull_t > 0.0:
		return
	_cull_t = CULL_INTERVAL
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var y := cam.global_position.y
	var cam_floor := floor_of(y)
	yellow.cull_floors(cam_floor)
	pizzeria.cull_floors(cam_floor - YellowRooms.FLOORS)
	var lvl := level_index_at(cam.global_position)
	if lvl != _local_level:
		_local_level = lvl
		refresh_environment()
		yellow.set_ambience(lvl == 0)
		pizzeria.set_ambience(lvl == 1)
