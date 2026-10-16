extends Node
## Visual check: launched windowed with --shots=DIR (solo) or --title-shot=FILE. Teleports the
## player and camera around Level 1 and saves PNGs, then quits. Needs a real window (not headless).

var out_dir: String = ""
var title_only: bool = false
var _host: Player
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
	_level = get_tree().get_first_node_in_group("level") as YellowRooms
	if _host == null or _level == null:
		get_tree().quit(1)
		return
	_host.bot_controlled = true
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
	var dark := _find_cell(0, "dark")
	if dark != Vector2i(-1, -1):
		_give("flashlight")
		_use()
		await _shot("06_dark_room_flashlight", _level.cell_center(0, dark) + Vector3(0.0, 0.1, 2.0), 0.0, -0.1, true)
		_host.server_drop_item(false)
	# The Custodian hunting overhead, then grabbing.
	var c0: Custodian = null
	for c in get_tree().get_nodes_in_group("custodian"):
		if (c as Custodian).floor_index == 0:
			c0 = c
	var path: Array[Vector2i] = f0["path"]
	var spot := _level.cell_center(0, path[mini(2, path.size() - 1)]) + Vector3(0.0, 0.1, 0.0)
	c0.debug_reset(spot + Vector3(0.0, 0.0, -3.0))
	c0.cstate = Custodian.CState.HUNT
	await _shot("07_stain_overhead", spot, 0.0, 0.75, true)
	c0.debug_reset(spot)
	c0.call("_start_grab", _host)
	await _wait(0.9)
	await _shot_here("08_grabbed_first_person", 0.0, 1.1, true)
	c0.release(false)
	await _wait(0.5)
	_host.camera_mode = Player.CameraMode.THIRD_PERSON
	_host._apply_camera_mode()
	await _shot("09_chain_and_ballast", spawn + Vector3(0.0, 0.0, 1.0), PI, -0.3, false)
	var lift_cell := _level.cell_center(1, _level.floors[1]["ascent"])
	await _shot("10_lift_room", lift_cell + Vector3(2.0, 0.1, 2.3), PI * 0.25, 0.1, false)
	await _shot("11_elevator", _level.test_points["exit"] + Vector3(0.0, 0.0, -2.6), 0.0, 0.0, false)
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
	get_tree().quit()


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


func _capture_to(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("[shots] saved ", path)


func _give(id: String) -> void:
	if _host.held_item != null:
		_host.server_drop_item(false)
	_host.server_give_item(ItemRegistry.get_data(id).create_logic())


func _use() -> void:
	_host.held_item.is_active = true


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout
