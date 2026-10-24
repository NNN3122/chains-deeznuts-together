class_name LevelStack
extends Node3D
## The Stack: every level of the building, built at once on every peer before connecting, so
## node paths match everywhere and nobody ever loads mid-game. Level 2 sits directly on top of
## Level 1: the freight car on B1 rides 5 m up its shaft into the pizzeria's Receiving room.
## Level 3, the roof, is on top; its helicopter flies the Line to Level 4, Ashgrave Manor, which is
## built far below the building (MANOR_Y: nothing of either is ever drawn, lit or heard from the
## other, and every question asked by height alone still has one answer).
## This node is the "level" the rest of the game talks to (group "level"): floors, layoffs,
## regroups, scare pools. It forwards each question to whichever level a position is in.

const KILL_Y: float = -8.0  # m under a level's floor: fell out of it
const LAYOFF_DELAY: float = 1.1
const REGROUP_COOLDOWN_MS: int = 15000
const CULL_INTERVAL: float = 0.25  # s between local visibility passes
const MANOR_Y: float = -600.0  # m: the manor's ground
const MANOR_TOP: float = 100.0  # m over the manor's ground that still counts as the manor
const DEPART_SECONDS: float = 2.4  # s the helicopter climbs away with the Line before the fade
const AIRLIFT_FADE: float = 1.1  # s into the fade to black when the Line is set down at the manor

var seed_value: int = YellowRooms.DEFAULT_SEED  # set before add_child; the office layout and the pizzeria's dressing come from it
var yellow: YellowRooms
var pizzeria: Pizzeria
var lot: HordeArena  # Level 3's first block, on the roof: the pizzeria's prop-loft hatch climbs out onto its pad
var manor: Manor  # Level 4, far below: the roof's helicopter sets the Line down at its stables
var last_layoff_msec: int = -100000
var spawn_position: Vector3 = Vector3.ZERO
var spawn_facing: float = PI
var test_points: Dictionary = {}
var _we: WorldEnvironment
var _layoff_pending: bool = false
var _last_regroup_msec: int = -100000
var _cull_t: float = 0.0
var _local_level: int = -1
var _airlifting: bool = false


func _ready() -> void:
	add_to_group("level")
	_we = WorldEnvironment.new()
	_we.name = "WorldEnvironment"
	_we.camera_attributes = LevelKit.make_camera_attributes()
	add_child(_we)
	yellow = YellowRooms.new()
	yellow.name = "YellowRooms"
	yellow.seed_value = seed_value
	add_child(yellow)
	# The pizzeria's Receiving room is centered right above the freight car.
	pizzeria = Pizzeria.new()
	pizzeria.name = "Pizzeria"
	pizzeria.seed_value = seed_value
	pizzeria.arrive_center = yellow.elevator_center() + Vector3(0.0, YellowRooms.FLOOR_H, 0.0)
	pizzeria.checkpoint_base = YellowRooms.FLOORS
	add_child(pizzeria)
	# The Loading Lot is the roof: its pad sits right over the prop loft, where the hatch comes out.
	lot = HordeArena.new()
	lot.name = "Lot"
	lot.embedded = true
	lot.seed_value = seed_value
	lot.checkpoint_index = YellowRooms.FLOORS + Pizzeria.FLOORS
	var loft: Vector3 = pizzeria.test_points["p_loft"]
	var roof_y := pizzeria.base_y() + float(Pizzeria.FLOORS) * Pizzeria.FLOOR_H + 1.0
	lot.origin = Vector3(loft.x, roof_y, loft.z) - HordeArena.PAD_LOCAL * Vector3(1.0, 0.0, 1.0)
	add_child(lot)
	pizzeria.top_y = roof_y - 0.5
	pizzeria.roof = Callable(self, "_climb_to_roof")
	lot.airlift = Callable(self, "_airlift")
	manor = Manor.new()
	manor.name = "Manor"
	manor.embedded = true
	manor.seed_value = seed_value
	manor.origin = Vector3(0.0, MANOR_Y, 0.0)
	add_child(manor)
	spawn_position = yellow.spawn_position
	spawn_facing = yellow.spawn_facing
	test_points = yellow.test_points.duplicate()
	test_points.merge(pizzeria.test_points)
	for key in lot.test_points:
		test_points["l_" + String(key)] = lot.test_points[key]
	for key in manor.test_points:
		test_points[String(key) if String(key).begins_with("m_") else "m_" + String(key)] = manor.test_points[key]
	refresh_environment()
	GameState.layoff_started.connect(func(_n: int, _r: String) -> void: _on_layoff())


func first_objective() -> String:
	return YellowRooms.OBJECTIVES[0]


## Which level a world position is in: 0 The Yellow Rooms, 1 the pizzeria, 2 the roof lot,
## 3 Ashgrave Manor (everything far enough down).
func level_index_at(p: Vector3) -> int:
	if _at_manor(p.y):
		return 3
	if p.y > lot.origin.y - 1.0 or lot.in_district(p):
		return 2
	return 1 if p.y > pizzeria.base_y() - 1.0 else 0


func level_at(p: Vector3) -> Node3D:
	match level_index_at(p):
		3:
			return manor
		2:
			return lot
		1:
			return pizzeria
	return yellow


func _at_manor(y: float) -> bool:
	return y < MANOR_Y + MANOR_TOP


## Floor number across the whole Stack (B4 = 0 ... B1 = 3, Dining Hall = 4 ... the roof = 8,
## one past the stage so the culling never draws the two together; the manor 10, clear of both).
func floor_of(y: float) -> int:
	if _at_manor(y):
		return manor_floor()
	if y > lot.origin.y - 1.0:
		return YellowRooms.FLOORS + Pizzeria.FLOORS + 1
	if y > pizzeria.base_y() - 1.0:
		return YellowRooms.FLOORS + pizzeria.floor_of(y)
	return yellow.floor_of(y)


func manor_floor() -> int:
	return YellowRooms.FLOORS + Pizzeria.FLOORS + 3


## The checkpoint the helicopter sets the Line down on: one past the helipad's.
func manor_checkpoint_index() -> int:
	return lot.helipad_checkpoint_index() + 1


func floor_name(y: float) -> String:
	if _at_manor(y):
		return Manor.FLOOR_NAME
	if y > lot.origin.y - 1.0:
		return HordeArena.FLOOR_NAME
	if y > pizzeria.base_y() - 1.0:
		return Pizzeria.FLOOR_NAMES[pizzeria.floor_of(y)]
	return YellowRooms.FLOOR_NAMES[yellow.floor_of(y)]


## Server: every player is on the prop loft and the hatch has opened. Out onto the roof: the
## pad of the Loading Lot, the next checkpoint, the next list.
func _climb_to_roof() -> void:
	if not multiplayer.is_server():
		return
	var pad := lot.spawn_position
	var facing := lot.spawn_facing
	var bodies := Net.get_chain_bodies()
	var n := bodies.size()
	var spots := GameState.line_spots(n, pad, facing)
	for i in n:
		bodies[i].teleport_to(spots[i] + Vector3(0.0, 0.2, 0.0), facing)
	GameState.set_checkpoint(lot.checkpoint_index, pad, facing, lot.first_objective())
	lot.server_arrive()
	_rpc_roof_fx.rpc()


@rpc("authority", "call_local", "reliable")
func _rpc_roof_fx() -> void:
	Sfx.play(self, "slam", -2.0, 0.6)
	var me := Net.get_local_player()
	if me != null:
		me.add_shake(0.4)


## Server: everyone is in the helicopter's cabin (HordeArena._tick_boarding). It climbs away off the
## tower with the Line aboard, the screen goes black, and it sets them down at the manor's stables:
## the next checkpoint, the manor's list, its pickups, and the Groundskeeper wakes.
func _airlift() -> void:
	if not multiplayer.is_server() or _airlifting:
		return
	_airlifting = true
	GameState.post_message("EVERYONE'S IN. HOLD ON.", 3.0)
	await get_tree().create_timer(DEPART_SECONDS).timeout
	_rpc_airlift_fx.rpc()
	await get_tree().create_timer(AIRLIFT_FADE).timeout
	server_land_at_manor()
	_airlifting = false


## Server: the Line onto the manor's stables, now (the tests and the bench call it straight).
func server_land_at_manor() -> void:
	if not multiplayer.is_server():
		return
	var spawn := manor.spawn_position
	var facing := manor.spawn_facing
	var bodies := Net.get_chain_bodies()
	var n := bodies.size()
	var spots := GameState.line_spots(n, spawn, facing)
	for i in n:
		bodies[i].teleport_to(spots[i] + Vector3(0.0, 0.2, 0.0), facing)
	# Over the estate wall on a jetpack is no way to play the manor: the pilot keeps them.
	var took := false
	for p in Net.get_players():
		p.set_unchained(false)
		if p.server_take_items("jetpack"):
			took = true
	lot.server_airlifted()
	GameState.set_checkpoint(manor_checkpoint_index(), spawn, facing, manor.first_objective())
	manor.server_arrive()
	if took:
		GameState.post_message("The pilot kept the jetpacks.", 3.0)
	_rpc_manor_fx.rpc()


@rpc("authority", "call_local", "reliable")
func _rpc_airlift_fx() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("show_card"):
		hud.call("show_card", "ASHGRAVE MANOR\nThe helicopter sets you down in the fog\nand is gone.")


@rpc("authority", "call_local", "reliable")
func _rpc_manor_fx() -> void:
	Sfx.play(self, "toll", -8.0, 0.8)
	var me := Net.get_local_player()
	if me != null:
		me.add_shake(0.25)


## False where something can't reach down through the ceiling (holes, shafts, the freight car).
func has_ceiling_at(p: Vector3) -> bool:
	return bool(level_at(p).call("has_ceiling_at", p))


## Break Rooms (and the pizzeria's freezer): monsters leave you alone there.
func is_safe_spot(p: Vector3) -> bool:
	return bool(level_at(p).call("is_safe_spot", p))


## Underside of the ceiling over a position (for falling tiles).
func ceiling_y(p: Vector3) -> float:
	match level_index_at(p):
		3:
			return manor.ceiling_y(p)
		2:
			return lot.ceiling_y(p)
		1:
			return pizzeria.ceiling_y(p)
	return float(yellow.floor_of(p.y)) * YellowRooms.FLOOR_H + YellowRooms.CEIL_H


## The procedural scares that make sense where the target stands: [[kind, weight], ...].
func scare_pool(p: Vector3) -> Array:
	match level_index_at(p):
		3:
			return Manor.SCARE_POOL
		2:
			return HordeArena.SCARE_POOL
		1:
			return Pizzeria.SCARE_POOL
	return YellowRooms.SCARE_POOL


## The roof paces its own scares (RoofDread); the building's are the ScareDirector's.
func paces_own_scares(p: Vector3) -> bool:
	return level_index_at(p) == 2


## A level's own scare visuals (the pizzeria's); the office has none of its own.
func play_scare(kind: String, pos: Vector3, targeted: bool) -> void:
	if kind.begins_with("roof_"):
		lot.play_scare(kind, pos, targeted)
	else:
		pizzeria.play_scare(kind, pos, targeted)


## Rebuilds the lighting look for the level the local camera is in (Settings changes quality).
func refresh_environment() -> void:
	var lvl := maxi(_local_level, 0)
	var env := LevelKit.make_environment(Settings.quality, lvl)
	if lvl == 3:
		env.fog_height += MANOR_Y  # height fog is in world metres, and the manor's ground is down here
	_we.environment = env


# --- Server -------------------------------------------------------------------------------------

## Spawns every pickup through the network spawner (once on the server after hosting).
func server_populate() -> void:
	yellow.server_populate()
	pizzeria.server_populate()
	lot.server_populate()
	manor.server_populate()  # nothing yet: the manor's pickups come out when the helicopter lands


func request_layoff(reason: String) -> void:
	if not multiplayer.is_server() or _layoff_pending or GameState.escaped:
		return
	_layoff_pending = true
	GameState.layoff(reason)
	await get_tree().create_timer(LAYOFF_DELAY).timeout
	_respawn_group()
	_layoff_pending = false
	last_layoff_msec = Time.get_ticks_msec()


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
	var where := "the stables" if GameState.checkpoint_index >= manor_checkpoint_index() else "the Break Room"
	GameState.post_message("%s called everyone back to %s." % [requester, where], 3.5)


func _respawn_group() -> void:
	var bodies := Net.get_chain_bodies()
	var facing := GameState.checkpoint_facing
	var n := bodies.size()
	var spots := GameState.line_spots(n, GameState.checkpoint_position, facing)
	for i in n:
		bodies[i].teleport_to(spots[i] + Vector3(0.0, 0.2, 0.0), facing)
	yellow.server_on_respawn()
	pizzeria.server_on_respawn()
	if GameState.checkpoint_index >= manor_checkpoint_index():
		manor.server_on_respawn()
	elif GameState.checkpoint_index >= lot.checkpoint_index:
		lot.server_on_respawn()


func _on_layoff() -> void:
	if multiplayer.is_server():
		pizzeria.server_on_layoff()


func _physics_process(_delta: float) -> void:
	if not multiplayer.is_server():
		return
	for b in Net.get_chain_bodies():
		var y := b.global_position.y
		var at_manor := _at_manor(y)
		if y < (MANOR_Y if at_manor else 0.0) + KILL_Y:
			request_layoff("Someone fell off the edge of the world. Somehow." if at_manor else "Someone fell out of the building. Somehow.")
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
	lot.set_shown(lvl == 2)
	manor.set_shown(lvl == 3)
	if lvl != _local_level:
		_local_level = lvl
		refresh_environment()
		yellow.set_ambience(lvl == 0)
		pizzeria.set_ambience(lvl == 1)
