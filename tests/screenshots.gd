extends Node
## Visual check: launched windowed with --shots=DIR (solo) or --title-shot=FILE. Teleports the
## player and camera around Level 1 and saves PNGs, then quits. Needs a real window (not headless).

var out_dir: String = ""
var title_only: bool = false
var gallery: bool = false  # --gallery=DIR: lit close-ups of the player and the monsters instead of the tour
var _host: Player
var _stack: LevelStack
var _level: YellowRooms


func _ready() -> void:
	if title_only:
		var title := get_tree().current_scene.get("title") as TitleMenu
		if title != null:
			title.call("_on_join_toggle")  # show the invite-code box too
		await _wait(4.0)
		await _capture_to(out_dir)
		get_tree().quit()
		return
	await _wait(3.0)
	_host = Net.find_player(1)
	var level_node := get_tree().get_first_node_in_group("level")
	if gallery and _host != null:
		await _gallery(level_node)
		get_tree().quit()
		return
	if _host != null and level_node is HordeArena:
		await _tour_arena(level_node as HordeArena)
		get_tree().quit()
		return
	_stack = level_node as LevelStack
	if _host == null or _stack == null:
		get_tree().quit(1)
		return
	_level = _stack.yellow
	_host.bot_controlled = true
	for c in get_tree().get_nodes_in_group("hire"):
		(c as HollowHire).debug_frozen = true
	for c in get_tree().get_nodes_in_group("custodian"):
		(c as Custodian).debug_frozen = true
	var hud := get_tree().current_scene.get("hud") as Hud
	if hud != null:
		hud.set_help_visible(false)
	var spawn: Vector3 = _level.test_points["spawn"]
	await _shot("01_spawn_room", spawn, PI, -0.12, false)
	await _shot("02_spawn_first_person", spawn, PI, -0.05, true)
	var f0: Dictionary = _level.floors[0]
	var cubicle := _find_cell(0, "cubicles")
	if cubicle != Vector2i(-1, -1):
		await _shot("03_cubicles", _level.cell_center(0, cubicle) + Vector3(0.0, 0.1, 2.4), 0.0, -0.1, false)
	var hall := _find_cell(0, "hall")
	if hall != Vector2i(-1, -1):
		await _shot("04_hall", _level.cell_center(0, hall) + Vector3(0.0, 0.1, 2.4), 0.0, 0.0, true)
	await _shot("05_crate_climb", _level.test_points["crates_start"] + Vector3(-0.4, 0.0, -0.8), -0.6, 0.25, false)
	# The cable tray: the optional ledge, seen from its start with the stash at the far end.
	_give("pistol")
	_host.server_give_item(ItemRegistry.get_data("flashlight").create_logic())
	_host.select_slot(0)
	await _shot("05b_cable_tray_and_slots", _level.test_points["crates_start"] + Vector3(1.5, 0.0, 2.6), 0.0, 0.3, false)
	_host.server_drop_all()
	var dark := _find_cell(0, "dark")
	if dark != Vector2i(-1, -1):
		_give("flashlight")
		_use()
		await _shot("06_dark_room_flashlight", _level.cell_center(0, dark) + Vector3(0.0, 0.1, 2.0), 0.0, -0.1, true)
		_host.server_drop_item(false)
	# A Hollow Hire down the hall, then running at you, then on top of you.
	var h0: HollowHire = _level.hires_on(0)[0]
	var path: Array[Vector2i] = f0["path"]
	var cell := _level.cell_center(0, path[mini(2, path.size() - 1)])
	var spot := cell + Vector3(0.0, 0.1, 2.2)  # same room, it at the far side, facing you
	h0.debug_reset(cell + Vector3(0.0, 0.0, -2.2), PI)
	await _shot("07_hollow_hire_seen", spot, 0.0, 0.0, true)
	h0.debug_frozen = false
	await _wait(0.3)
	h0.debug_frozen = true
	await _shot_here("07b_hollow_hire_chasing", 0.0, 0.0, true)
	for b in Net.get_chain_bodies():
		if b != _host:
			b.teleport_to(spot + Vector3(3.5, 0.0, 0.0), 0.0)  # out of rescue range for the shot
	h0.debug_reset(spot + Vector3(0.0, 0.0, -1.0), 0.0)
	# The catch, as the caught player sees it (locked on its face), and once from outside.
	_host.camera_mode = Player.CameraMode.THIRD_PERSON
	_host._apply_camera_mode()
	h0.call("_start_grab", _host)
	await _wait(0.5)
	await _capture_to(out_dir.path_join("08_caught_by_the_throat.png"))
	await _wait(0.36)
	await _capture_to(out_dir.path_join("08b_the_claw_rakes.png"))
	await _wait(0.75)
	_host._apply_camera_mode()  # from outside for a moment
	await _wait(0.1)
	await _capture_to(out_dir.path_join("08c_caught_third_person.png"))
	_host._set_pov_forced(true)
	await _wait(0.95)
	await _capture_to(out_dir.path_join("08d_the_jaw_drops.png"))
	await _wait(0.5)
	await _capture_to(out_dir.path_join("08e_the_bite.png"))
	h0.release(false)
	h0.debug_frozen = true
	await _wait(0.5)
	_host.camera_mode = Player.CameraMode.THIRD_PERSON
	_host._apply_camera_mode()
	await _shot("09_chain_and_ballast", spawn + Vector3(0.0, 0.0, 1.0), PI, -0.3, false)
	var lift_cell := _level.cell_center(1, _level.floors[1]["ascent"])
	await _shot("10_lift_room", lift_cell + Vector3(2.0, 0.1, 2.3), PI * 0.25, 0.1, false)
	await _shot("11_elevator", _level.test_points["exit"] + Vector3(0.0, 0.0, -2.6), 0.0, 0.0, false)
	# The forced route: the jammed door, the alarm station, the hatch and its release, a sweep,
	# and the floor with its power out (the Break Room behind you keeps its lights).
	if _level.test_points.has("door0"):
		var out: Vector3 = _level.test_points["door0_axis"]
		await _shot("11b_jammed_door", _level.test_points["door0"] - out * 1.0, atan2(-out.x, -out.z), 0.0, true)
	var alarm_n: Vector3 = _level.alarm().global_transform.basis.z
	await _shot("11c_fire_alarm_pull", _level.test_points["alarm"] + alarm_n * 0.8, atan2(alarm_n.x, alarm_n.z), 0.05, true)
	var sw_n: Vector3 = _level.hatch().switch_normal
	await _shot("11d_hatch_release", _level.test_points["hatch_switch"] + sw_n * 0.8, atan2(sw_n.x, sw_n.z), 0.05, true)
	await _shot("11e_hatch_over_the_shaft", _level.test_points["hatch"] + Vector3(0.0, 0.0, 2.2), 0.0, 0.9, true)  # yaw 0 looks toward -z: back at the hole
	if hall != Vector2i(-1, -1):
		var hc := _level.cell_center(0, hall)
		h0.debug_reset(hc + Vector3(0.0, 0.0, -1.5), PI)
		h0.debug_frozen = false
		h0.debug_sweep()
		await _wait(0.9)
		h0.debug_frozen = true
		await _shot("11f_hire_sweeping", hc + Vector3(0.0, 0.1, 2.4), 0.0, 0.0, false)
		_level.lights().floor_stutter(0, 0.0, 40.0)
		await _shot("11g_power_out_no_light", hc + Vector3(0.0, 0.1, 2.4), 0.0, 0.0, true)
		_give("flashlight")
		_use()
		await _shot("11h_power_out_flashlight", hc + Vector3(0.0, 0.1, 2.4), 0.0, 0.0, true)
		_host.server_drop_all()
		_level.lights().floor_stutter(0, 0.0, 0.0)
		h0.debug_reset(hc + Vector3(12.0, 0.0, 0.0), 0.0)
	# The body in motion, seen side-on: walk, run, brace.
	if hall != Vector2i(-1, -1):
		var start := _level.cell_center(0, hall) + Vector3(-2.2, 0.1, 0.8)
		for pose in [["12_walk_side", 0], ["13_run_side", Player.FLAG_RUN], ["14_brace", Player.FLAG_BRACE]]:
			var bodies := Net.get_chain_bodies()
			for i in bodies.size():
				bodies[i].teleport_to(start + Vector3(-1.2 * float(i), 0.0, 0.0), -PI * 0.5)
			_host._yaw = 0.35
			_host._pitch = -0.2
			_host.camera_mode = Player.CameraMode.THIRD_PERSON
			_host._apply_camera_mode()
			var move := Vector2(1.0, 0.0) if pose[1] != Player.FLAG_BRACE else Vector2.ZERO
			_host._apply_input(move, 0.35, -0.2, int(pose[1]))
			await _wait(0.75)
			await _capture_to(out_dir.path_join(String(pose[0]) + ".png"))
			_host._apply_input(Vector2.ZERO, 0.35, -0.2, 0)
			await _wait(0.6)
	# The hosting UI, with a staged invite: the tour runs solo, so there's no real one.
	Net.invite = {"state": "ready", "code": "K7QM-2XR", "lan": "192.168.1.20", "tailscale": "", "port": Net.DEFAULT_PORT, "reason": ""}
	Net.invite_changed.emit()
	await _wait(0.7)  # the HUD refreshes its invite line twice a second
	await _capture_to(out_dir.path_join("15_hud_invite.png"))
	var pause := get_tree().current_scene.get("pause_menu") as PauseMenu
	pause.visible = true
	await _wait(0.6)  # give the menu a few frames before the capture
	await _capture_to(out_dir.path_join("16_pause_invite.png"))
	pause.visible = false
	Net.invite = {}
	Net.invite_changed.emit()
	await _tour_pizzeria()
	get_tree().quit()


## Level 2: the freight car's arrival, the rooms, the desk and its feed, Pappy, the climbs.
func _tour_pizzeria() -> void:
	var pz := _stack.pizzeria
	var tp := pz.test_points
	pz.pappy.debug_frozen = true
	var car := _level.get_node_or_null("Floor3/FreightCar") as FreightCar
	if car != null:
		car.server_park_top()
	await _wait(0.3)
	var arrive: Vector3 = tp["p_arrive"]
	await _shot("20_receiving", arrive + Vector3(0.0, 0.0, -0.5), PI, -0.1, false)
	await _shot("21_host_stand", pz.cell_center(0, 0, 3) + Vector3(0.0, 0.1, 1.5), 0.0, -0.05, true)
	var dining := pz.node_position(0, 1)
	pz.pappy.debug_reset(0, 1)
	await _shot("22_dining_hall_pappy", dining + Vector3(0.0, 0.1, 9.0), 0.0, -0.05, true)
	await _shot("23_dining_hall_third_person", dining + Vector3(-5.0, 0.1, 6.0), 0.6, -0.15, false)
	await _shot("24_counter", pz.cell_center(0, 3, 1) + Vector3(0.0, 0.1, 0.0), -PI * 0.5, 0.0, true)
	await _shot("25_arcade", pz.cell_center(0, 4, 2) + Vector3(0.0, 0.1, 1.0), -PI * 0.5, 0.0, true)
	await _shot("26_party_room", pz.cell_center(0, 4, 4) + Vector3(-1.5, 0.1, 1.5), -PI * 0.5 + 0.4, 0.0, true)
	# The camera desk with its feed (the host clips in), Pappy on camera.
	pz.pappy.debug_reset(0, 1)
	var desk := pz.desks[0]
	await _shot("27_desk_clipped_in", desk.spot(), desk.rotation.y + PI, -0.2, true)
	desk.cam_index = pz.node_cam(0, 1)
	await _wait(4.5)  # past the Counter Bell's static
	await _capture_to(out_dir.path_join("28_camera_feed_pappy.png"))
	# The shutter, held, with Pappy banging on it.
	var sh := pz.shutters[0]
	sh.debug_hold = true
	pz.pappy.debug_reset(0, 5)
	pz.pappy.debug_frozen = false
	await _wait(0.2)
	pz.pappy.debug_force_step()
	await _wait(0.6)
	await _shot("29_shutter_held_pappy_banging", sh.pull_point() + Vector3(1.5, 0.0, 1.5), PI * 0.25, -0.05, true)
	pz.pappy.debug_frozen = true
	sh.debug_hold = false
	await _shot("30_dumbwaiter", tp["p_dumbwaiter"] + Vector3(2.5, 0.0, 3.2), 0.6, 0.05, true)
	await _shot("31_kitchen", tp["p_kitchen"], 0.0, -0.05, true)
	await _shot("32_freezer", tp["p_freezer"] + Vector3(0.0, 0.0, 2.0), 0.0, 0.0, true)
	await _shot("33_managers_office", pz.cell_center(1, 5, 1) + Vector3(-1.5, 0.1, 1.5), 0.3, 0.0, true)
	await _shot("34_stage_lift", tp["p_lever"] + Vector3(-0.5, 0.0, 0.0), PI * 0.5 + 0.5, -0.1, false)
	# The stage: curtain scare fired, band lit, Pappy's empty mark, the loft and the hatch.
	pz.play_scare("curtain", tp["p_stage"], true)
	await _wait(3.8)
	await _shot("35_stage_from_floor", tp["p_floor"] + Vector3(0.0, 0.0, 3.0), 0.0, 0.1, true)
	await _shot("36_stage_loft_climb", tp["p_cases"] + Vector3(2.0, 0.0, 3.0), 0.5, 0.25, false)
	pz.pappy.debug_reset(2, 1)
	await _shot("37_pappy_on_stage", tp["p_stage"] + Vector3(0.0, 0.0, 6.0), 0.0, 0.05, true)
	await _shot("38_coat_check", tp["p_checkpoint6"], PI * 0.5, 0.0, false)
	await _shot("39_dressing_room_suit", tp["p_rack"] + Vector3(1.5, 0.0, 0.0), PI * 0.5, 0.0, true)
	var loft: Vector3 = tp["p_loft"]
	await _shot("41_fly_rail", tp["p_rail_start"] + Vector3(0.0, 0.0, 2.2), PI * 0.5 + 0.5, 0.0, false)
	# Pappy rushing across the dining hall toward you: the one time he is seen walking.
	pz.pappy.debug_reset(0, 1)
	_place_all(dining + Vector3(0.0, 0.1, 9.0), 0.0)
	pz.pappy.debug_frozen = false
	pz.pappy.call("_start_rush", 6.0)
	_host._yaw = 0.0
	_host._pitch = -0.05
	_host.camera_mode = Player.CameraMode.FIRST_PERSON
	_host._apply_camera_mode()
	await _wait(1.3)  # mid-charge, still a few meters off
	await _capture_to(out_dir.path_join("42_pappy_rush.png"))
	pz.pappy.debug_frozen = true
	pz.pappy.debug_reset(0, 0)
	await _shot("40_prop_loft_exit", loft + Vector3(-2.0, 0.0, 0.0), -PI * 0.5, 0.3, false)
	# Last: out of the hatch onto the roof, the Loading Lot, the crowd at the far end.
	var lot := _stack.lot
	lot.horde.debug_frozen = true
	for l in lot.launchers:
		l.debug_frozen = true
	await _shot("43_roof_lot", lot.spawn_position, 0.0, -0.05, false)
	await _shot("44_roof_lot_first_person", lot.spawn_position + Vector3(0.0, 0.0, -6.0), 0.0, 0.0, true)


## The Loading Lot (--arena --shots=DIR): the lot, the fence, the crowd at the gap, a Launcher
## mid-crouch and on top of someone, the slide, hands on the chain.
func _tour_arena(arena: HordeArena) -> void:
	_host.bot_controlled = true
	var hud := get_tree().current_scene.get("hud") as Hud
	if hud != null:
		hud.set_help_visible(false)
	var horde := arena.horde
	for l in arena.launchers:
		l.debug_frozen = true
	var spawn: Vector3 = arena.test_points["spawn"]
	await _shot("50_lot_spawn", spawn, 0.0, -0.05, false)
	await _shot("51_fence_and_dumpster", arena.test_points["fence_dumpster"] + Vector3(3.0, 0.0, 2.5), 0.5, 0.15, true)
	# Let the crowd walk a while, then look at it from the gap and from inside it.
	_place_all(arena.test_points["north"], 0.0)
	await _wait(6.0)
	await _shot("52_horde_from_the_gap", arena.test_points["gap"], 0.0, 0.0, true)
	await _shot("53_horde_third_person", arena.test_points["north"] + Vector3(0.0, 0.0, -4.0), 0.0, -0.2, false)
	var i := horde.nearest_agent(arena.test_points["north"])
	if i >= 0:
		var inside := horde.agent_position(i) + Vector3(0.0, 0.0, -5.0)
		await _shot("54_inside_the_crowd", inside, PI, 0.0, true)
	# A Launcher: the crouch (the tell), then on top of someone.
	horde.debug_frozen = true
	var l := arena.launchers[0]
	_place_all(spawn, 0.0)
	await _wait(0.3)
	l.debug_reset(spawn + Vector3(0.0, 0.0, -5.0))
	l.debug_frozen = false
	for k in 30:
		await _wait(0.05)
		if l.lstate == Launcher.LState.WINDUP:
			break
	l.debug_frozen = true
	_host._yaw = 0.0
	_host._pitch = 0.0
	_host.camera_mode = Player.CameraMode.FIRST_PERSON
	_host._apply_camera_mode()
	await _wait(0.4)
	await _capture_to(out_dir.path_join("55_launcher_crouch.png"))
	l.debug_reset(spawn + Vector3(0.0, 0.0, -1.5))
	l.call("_start_grab", _host)
	await _wait(0.6)
	await _shot_here("56_launcher_pinned_first_person", 0.0, 0.3, true)
	_host.camera_mode = Player.CameraMode.THIRD_PERSON
	_host._apply_camera_mode()
	await _wait(0.3)
	await _capture_to(out_dir.path_join("57_launcher_pinned_third_person.png"))
	l.release(false)
	l.debug_reset(spawn + Vector3(0.0, 0.0, -40.0))
	await _wait(0.6)
	# The slide, side on.
	_place_all(spawn + Vector3(-4.0, 0.0, -6.0), -PI * 0.5)
	await _wait(0.4)
	_host._yaw = 0.0
	_host._pitch = -0.15
	_host.camera_mode = Player.CameraMode.THIRD_PERSON
	_host._apply_camera_mode()
	_host._apply_input(Vector2(1.0, 0.0), 0.0, -0.15, Player.FLAG_RUN)
	await _wait(0.6)
	_host._apply_input(Vector2(1.0, 0.0), 0.0, -0.15, Player.FLAG_RUN | Player.FLAG_BRACE)
	await _wait(0.3)
	await _capture_to(out_dir.path_join("58_slide.png"))
	_host._apply_input(Vector2.ZERO, 0.0, -0.15, 0)
	await _wait(1.2)
	# Hands on the chain.
	_place_all(spawn, 0.0)
	var bodies := Net.get_chain_bodies()
	if bodies.size() > 1:
		bodies[1].teleport_to(spawn + Vector3(0.0, 0.0, 3.2), 0.0)
	await _wait(0.3)
	for k in 3:
		horde.place(k, spawn + Vector3(-0.4 + 0.4 * float(k), 0.0, 1.6))
	horde.debug_frozen = false
	await _wait(1.0)
	await _shot_here("59_hands_on_the_chain", PI, -0.35, false)
	horde.debug_frozen = true
	# The way out: the fire escape, the helipad with the helicopter.
	arena.debug_spawn_all_rounds()
	await _shot("60_fire_escape", arena.test_points["escape_foot"] + Vector3(2.0, 0.0, 4.0), -0.4, 0.35, false)
	_place_all(arena.test_points["helipad"] + Vector3(-5.0, 0.0, 6.0), -0.7)
	await _wait(0.7)
	arena.debug_pad_ready()
	await _shot_here("61_helipad", -0.7, 0.35, false)
	# A spider dropping on its thread into your face (a jump scare, not a wave).
	_place_all(arena.origin + arena.roofs[2].center() + Vector3(0.0, 0.1, 0.0), 0.0)
	await _wait(0.4)
	_host._yaw = 0.0
	_host._pitch = 0.05
	_host.camera_mode = Player.CameraMode.FIRST_PERSON
	_host._apply_camera_mode()
	arena.play_scare("roof_drop", _host.global_position + Vector3(0.0, 0.0, -1.3), true)
	await _wait(0.3)
	await _capture_to(out_dir.path_join("62_spider_drop.png"))
	await _wait(1.2)
	# The district: the sky, the route from the lot's edge, the first of each kind of link, a
	# spider swinging a gap on a thread, the Jumper crossing, the tower from a few roofs back.
	await _shot("63_night_sky", spawn + Vector3(0.0, 0.0, -10.0), 0.4, 0.75, true)
	await _shot("64_route_from_the_lot_edge", arena.test_points["lot_edge"] + Vector3(0.0, 0.0, 3.0), 0.0, -0.08, false)
	await _link_shot(arena, HordeArena.Link.PLANK, "65_plank", -0.35, true)
	await _link_shot(arena, HordeArena.Link.CLIMB, "66_climb", 0.2, false)
	await _link_shot(arena, HordeArena.Link.LEAP, "66b_leap", -0.05, true)
	await _link_shot(arena, HordeArena.Link.STONES, "66c_stacks", -0.2, true)
	await _link_shot(arena, HordeArena.Link.DROP, "66d_drop", -0.45, true)
	# A Weaver swinging the gap between roof 1 and roof 2, seen from roof 2.
	var wk := 2
	while wk < arena.roofs.size() - 2 and (arena.roofs[wk].link == HordeArena.Link.CLIMB or arena.roofs[wk].link == HordeArena.Link.STONES):
		wk += 1
	var r1: HordeArena.Roof = arena.roofs[wk - 1]
	var r2: HordeArena.Roof = arena.roofs[wk]
	var d2 := Vector3(r2.dir.x, 0.0, r2.dir.y)
	var back_yaw := atan2(d2.x, d2.z)  # looking back the way you came
	_place_all(arena.origin + r2.enter + d2 * 2.5, back_yaw)
	var from := arena.origin + r1.exit - d2 * 0.8
	horde.spawn_group(1, Rect2(from.x - 0.5, from.z - 0.5, 1.0, 1.0), 4242, [0.0, 1.0, 0.0] as Array[float])
	var weaver := -1
	for k in horde.count:
		if horde.kind[k] == Horde.KIND_WEAVER and horde.state[k] == Horde.AState.WALK:
			weaver = k
	if weaver >= 0:
		horde.place(weaver, from)
		_host._yaw = back_yaw
		_host._pitch = 0.05
		_host.camera_mode = Player.CameraMode.FIRST_PERSON
		_host._apply_camera_mode()
		horde.debug_frozen = false
		for k in 60:
			await _wait(0.05)
			if horde.state[weaver] == Horde.AState.SWING and horde.timer[weaver] < horde.sw_dur[weaver] * 0.55:
				break
		horde.debug_frozen = true
		await _capture_to(out_dir.path_join("67_weaver_swinging_the_gap.png"))
	# The route's Jumper on a thread.
	var jk: int = HordeArena.JUMPER_ROOFS[0]
	var jumper := arena.launchers[HordeArena.LOT_JUMPERS]
	var r3: HordeArena.Roof = arena.roofs[jk]
	var r4: HordeArena.Roof = arena.roofs[jk + 1]
	var d4 := Vector3(r4.dir.x, 0.0, r4.dir.y)
	var yaw4 := atan2(d4.x, d4.z)
	_place_all(arena.origin + r4.enter + d4 * 6.0, yaw4)
	await _wait(0.4)
	jumper.debug_reset(arena.origin + r3.exit - d4 * 2.0)
	jumper.debug_frozen = false
	_host._yaw = yaw4
	_host._pitch = 0.1
	_host.camera_mode = Player.CameraMode.THIRD_PERSON
	_host._apply_camera_mode()
	for k in 120:
		await _wait(0.05)
		if jumper.lstate == Launcher.LState.SWING or jumper.lstate == Launcher.LState.CLIMB:
			await _wait(0.25)
			break
	jumper.debug_frozen = true
	await _capture_to(out_dir.path_join("68_jumper_crossing.png"))
	jumper.debug_reset(arena.launcher_homes[HordeArena.LOT_JUMPERS])
	var back := arena.roofs[maxi(1, arena.roofs.size() - 4)]
	await _shot("69_the_tower_from_three_roofs_back", arena.origin + back.center() + Vector3(0.0, 0.1, 0.0), 0.0, 0.12, false)
	arena.play_scare("roof_shadow", _host.global_position + Vector3(0.0, 0.0, -4.0), true)
	await _wait(0.5)
	await _capture_to(out_dir.path_join("70_roof_shadow.png"))
	# The whole district from above: scattered, not a line.
	var mid := arena.origin + Vector3(arena._route_bounds.get_center().x, 0.0, arena._route_bounds.get_center().y)
	_place_all(arena.origin + arena.roofs[0].exit + Vector3(0.0, 0.1, 0.0), 0.0)
	await _wait(0.3)
	_host.camera_mode = Player.CameraMode.FIRST_PERSON
	_host._apply_camera_mode()
	var cam := _host.local_camera()
	var cam_local := cam.transform
	cam.top_level = true
	cam.global_position = mid + Vector3(0.0, 120.0, 40.0)
	cam.look_at(mid, Vector3.UP)
	await _wait(0.4)
	await _capture_to(out_dir.path_join("71_district_from_above.png"))
	cam.top_level = false
	cam.transform = cam_local
	# The horror pass: the Tall Tenant past the edge of a lamp (a little off the centre of the
	# view: looked at straight, it goes), and the beacon through the fog from the lot.
	var dr := arena.dread
	dr._glimpse_t = 999.0
	dr._cool = 999.0
	_place_all(arena.origin + arena.roofs[3].center() + Vector3(0.0, 0.1, 0.0), 0.0)
	await _wait(0.5)
	var gs := dr.glimpse_spot(_host)
	if gs != Vector3.INF:
		var to := gs - _host.global_position
		dr.spawn_glimpse(gs)
		await _shot_here("72_tall_tenant", atan2(-to.x, -to.z) + 0.22, 0.06, true)
	var edge: Vector3 = arena.test_points["lot_edge"] + Vector3(0.0, 0.0, 4.0)
	var tw := arena.origin + arena.tower_top - edge
	await _shot("73_beacon_from_the_lot", edge, atan2(-tw.x, -tw.z), 0.08, true)


## The first link of a kind, seen from where you stand to take it.
func _link_shot(arena: HordeArena, link: int, file: String, pitch: float, first_person: bool) -> void:
	for i in range(1, arena.roofs.size() - 1):
		var r: HordeArena.Roof = arena.roofs[i]
		if r.link != link:
			continue
		var prev: HordeArena.Roof = arena.roofs[i - 1]
		var d := Vector3(r.dir.x, 0.0, r.dir.y)
		await _shot(file, arena.origin + prev.exit + Vector3(0.0, 0.1, 0.0) - d * 1.5, atan2(-d.x, -d.z), pitch, first_person)
		return


func _place_all(pos: Vector3, yaw: float) -> void:
	var bodies := Net.get_chain_bodies()
	for i in bodies.size():
		bodies[i].teleport_to(pos + Vector3(1.1 * float(i), 0.0, -0.6 * float(i)), yaw)


func _find_cell(i: int, kind: String) -> Vector2i:
	var types: Dictionary = _level.floors[i]["types"]
	for c in types:
		if types[c] == kind:
			return c
	return Vector2i(-1, -1)


func _shot(file: String, pos: Vector3, yaw: float, pitch: float, first_person: bool) -> void:
	var bodies := Net.get_chain_bodies()
	for i in bodies.size():
		bodies[i].teleport_to(pos + Vector3(1.1 * float(i), 0.0, -0.6 * float(i)), yaw)
	await _shot_here(file, yaw, pitch, first_person)


func _shot_here(file: String, yaw: float, pitch: float, first_person: bool) -> void:
	_host._yaw = yaw
	_host._pitch = pitch
	_host.camera_mode = Player.CameraMode.FIRST_PERSON if first_person else Player.CameraMode.THIRD_PERSON
	_host._apply_camera_mode()
	await _wait(1.4)
	await _capture_to(out_dir.path_join(file + ".png"))


## --gallery: the player and every monster's body on its own in an empty studio far below the
## level, under a rig of three lights, from a camera of our own.
const STUDIO: Vector3 = Vector3(0.0, -300.0, 0.0)


func _gallery(level_node: Node) -> void:  # the Stack, or the Lot on its own
	_host.bot_controlled = true
	var hud := get_tree().current_scene.get("hud") as CanvasLayer
	if hud != null:
		hud.visible = false
	var cam := Camera3D.new()
	cam.fov = 45.0
	cam.far = 200.0
	get_tree().current_scene.add_child(cam)
	cam.current = true
	var floor_mi := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(30.0, 0.2, 30.0)
	floor_mi.mesh = fm
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.16, 0.16, 0.17)
	fmat.roughness = 0.8
	floor_mi.material_override = fmat
	get_tree().current_scene.add_child(floor_mi)
	floor_mi.global_position = STUDIO - Vector3(0.0, 0.1, 0.0)
	# Every player colour, so all six are baked into the mesh cache that ships with the game.
	for i in 6:
		var pm := PlayerModel.new()
		pm.build(i)
		pm.free()
	var subjects: Array = gallery_subjects()
	for s in subjects:
		var node: Node3D = s[1]
		get_tree().current_scene.add_child(node)
		node.global_position = STUDIO
		if node is RoofStalker:
			node.set_process(false)  # it steps away the moment a camera stares at it
		if node is PlayerModel:
			(node as PlayerModel).build(int(node.get_meta("index")))
		elif node.has_method("build"):
			node.call("build")
		if node is PlayerModel:
			for k in 30:
				(node as PlayerModel).animate(1.0 / 30.0, Vector3.ZERO, 0.0, true, false, false, false, false, 0.0)
		var shots: Array = s[2]
		for sh in shots:
			var sub: Vector3 = STUDIO + (sh[0] as Vector3)
			var eye: Vector3 = STUDIO + (sh[1] as Vector3)
			await _studio(cam, sub, eye, "%s_%s" % [s[0], sh[2]])
		node.queue_free()
		await _wait(0.1)
	cam.fov = Settings.fov  # the scares as a player sees them
	# The face jump scare of each level, caught as it fills the screen.
	var spots: Array[Vector3] = [STUDIO]
	if level_node is LevelStack:
		var stack := level_node as LevelStack
		spots.append(Vector3(0.0, stack.pizzeria.base_y() + 2.0, 0.0))
		spots.append(stack.lot.origin + Vector3.UP)
	for k in spots.size():
		cam.global_position = STUDIO + Vector3(0.0, 1.6, -3.0)
		cam.look_at(STUDIO + Vector3(0.0, 1.6, 0.0), Vector3.UP)
		ScareDirector.call("_spawn_face", spots[k])
		await _wait(0.24)
		await _capture_to(out_dir.path_join("g10_face_scare_%d.png" % k))
		await _wait(0.6)
	# The other jump scares, each caught at its worst moment (the Hire's versions).
	var kinds: Array = [["ceiling_drop", 0.3], ["crawler", 0.55], ["peek", 1.0], ["hands", 0.3], ["behind", 0.0]]
	for e in kinds:
		cam.global_position = STUDIO + Vector3(0.0, 1.6, 3.0)
		cam.look_at(STUDIO + Vector3(0.0, 1.6, 0.0), Vector3.UP)
		ScareDirector.call("_spawn_" + String(e[0]), STUDIO + Vector3(0.0, 0.0, 3.0))
		if e[0] == "behind":
			await _wait(0.5)
			cam.rotate_y(PI)  # turn round
			await _wait(0.12)
		else:
			await _wait(float(e[1]))
		await _capture_to(out_dir.path_join("g11_%s.png" % e[0]))
		await _wait(1.6)
	cam.queue_free()
	floor_mi.queue_free()


## [name, node, [[subject offset, eye offset, shot name], ...]] for every body in the gallery.
## Bodies face -z, so the camera stands on the -z side for their fronts.
func gallery_subjects() -> Array:
	var list: Array = []
	var pm := PlayerModel.new()
	pm.set_meta("index", 0)
	list.append(["g01_player", pm, [[Vector3(0.0, 0.95, 0.0), Vector3(0.9, 1.3, -2.6), "front"], [Vector3(0.0, 1.62, 0.0), Vector3(0.12, 1.66, -0.6), "face"], [Vector3(0.0, 1.0, 0.0), Vector3(-1.4, 1.5, 2.2), "back"]]])
	list.append(["g02_hollow_hire", HireBody.new(), [[Vector3(0.0, 1.0, 0.0), Vector3(0.8, 1.45, -2.8), "front"], [Vector3(0.0, 1.9, 0.0), Vector3(0.12, 1.9, -0.75), "face"], [Vector3(0.0, 1.0, 0.0), Vector3(-2.2, 1.2, -0.6), "side"]]])
	list.append(["g03_pappy", PappyBody.new(), [[Vector3(0.0, 1.4, 0.0), Vector3(1.0, 1.9, -4.2), "front"], [Vector3(0.0, 2.35, 0.0), Vector3(0.2, 2.35, -1.3), "face"]]])
	list.append(["g04_jumper", JumperBody.new(), [[Vector3(0.0, 0.9, 0.0), Vector3(2.2, 1.9, -3.4), "front"], [Vector3(0.0, 1.0, -0.9), Vector3(0.25, 1.15, -2.0), "face"]]])
	var arm := Node3D.new()
	var flesh := CustodianParts.material()
	for i in 3:
		Sculpt.put(arm, CustodianParts.segment(0.075 - 0.01 * float(i)), flesh, Vector3(0.0, 2.6 - 0.62 * float(i), 0.0))
	Sculpt.put(arm, CustodianParts.hand(), flesh, Vector3(0.0, 0.95, 0.0))
	list.append(["g05_custodian_arm", arm, [[Vector3(0.0, 1.4, 0.0), Vector3(0.6, 1.3, -2.4), "front"], [Vector3(0.0, 0.8, 0.0), Vector3(0.3, 0.75, -0.9), "hand"]]])
	var names: Array[String] = ["roach", "weaver", "flitter"]
	for k in 3:
		var mi := MeshInstance3D.new()
		mi.mesh = HordeMesh.mesh_for(k)
		mi.material_override = HordeMesh.material_for(k)
		list.append(["g%02d_%s" % [6 + k, names[k]], mi, [[Vector3(0.0, 0.3, 0.0), Vector3(1.1, 0.9, -1.8), "front"], [Vector3(0.0, 0.3, -0.4), Vector3(0.2, 0.45, -1.1), "face"]]])
	list.append(["g09_tall_tenant", RoofStalker.new(), [[Vector3(0.0, 1.8, 0.0), Vector3(0.8, 1.9, -5.0), "front"], [Vector3(0.0, 3.1, -0.2), Vector3(0.15, 3.1, -1.2), "face"]]])
	return list


## One lit close-up: key, rim and fill lights round the subject, the camera at eye looking at it.
func _studio(cam: Camera3D, subject: Vector3, eye: Vector3, file: String) -> void:
	var rig := Node3D.new()
	get_tree().current_scene.add_child(rig)
	var side := (subject - eye).cross(Vector3.UP).normalized()
	var specs := [[eye + side * 2.0 + Vector3.UP * 1.5, Color(1.0, 0.9, 0.8), 1.3], [subject - (eye - subject).normalized() * 2.0 + Vector3.UP * 1.2, Color(0.6, 0.75, 1.0), 2.0], [eye - side * 2.0, Color(0.8, 0.85, 1.0), 0.35]]
	for sp in specs:
		var o := OmniLight3D.new()
		o.light_color = sp[1]
		o.light_energy = sp[2]
		o.omni_range = 8.0
		o.shadow_enabled = true
		rig.add_child(o)
		o.global_position = sp[0]
	cam.global_position = eye
	cam.look_at(subject, Vector3.UP)
	await _wait(0.35)
	await _capture_to(out_dir.path_join(file + ".png"))
	rig.queue_free()


func _capture_to(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("[shots] saved ", path)


func _give(id: String) -> void:
	_host.server_drop_all()
	_host.server_give_item(ItemRegistry.get_data(id).create_logic())


func _use() -> void:
	_host.held_item.is_active = true


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout
