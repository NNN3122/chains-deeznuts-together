extends Node
## Headless smoke test. main.gd adds this node when launched with --smoke (host) or --smoke-client.
## The host side drives its own player with scripted input through Level 1 and checks every system;
## the client side checks what replicated to it. Exit code 0 means every check passed.
##   godot --headless --path . --max-fps 60 -- --host --smoke --smoke-players=2
##   godot --headless --path . --max-fps 60 -- --join=127.0.0.1 --smoke-client
##   godot --headless --path . --max-fps 60 -- --solo --smoke       (solo: the Ballast is the partner)

var expected_players: int = 1
var is_client: bool = false
var only: String = ""  # --smoke-only=NAME: run just _test_NAME after the setup checks
var _passed: int = 0
var _failed: int = 0
var _seq: int = 0
var _stack: LevelStack
var _level: YellowRooms
var _pizzeria: Pizzeria
var _host: Player
var _mate: ChainBody  # the other end of the chain: second player, or the Ballast in solo


func _ready() -> void:
	if is_client:
		_run_client()
	else:
		_run_host()


# --- Host ---------------------------------------------------------------------------------------

func _run_host() -> void:
	var players := await _wait_for_players(expected_players, 25.0)
	_check("players spawned", players.size() >= expected_players, "%d of %d" % [players.size(), expected_players])
	_host = Net.find_player(1)
	var level_node := get_tree().get_first_node_in_group("level")
	if _host != null and level_node is HordeArena:
		await _run_arena(level_node as HordeArena)
		return
	_stack = level_node as LevelStack
	if _host == null or _stack == null:
		_finish()
		return
	_level = _stack.yellow
	_pizzeria = _stack.pizzeria
	_host.bot_controlled = true
	_freeze_hires(true)  # the monsters get their own tests; keep them out of the others
	_pizzeria.pappy.debug_frozen = true
	_stack.lot.horde.debug_frozen = true
	for l in _stack.lot.launchers:
		l.debug_frozen = true
	await _wait(0.6)
	var bodies := Net.get_chain_bodies()
	_mate = bodies[1] if bodies.size() > 1 else null
	_check("level built: 4 floors with test points", _level.floors.size() == 4 and _level.test_points.has("exit"), "%d floors, %d points" % [_level.floors.size(), _level.test_points.size()])
	_check("pizzeria built on top: 3 floors, 3 desks, 2 shutters, Pappy", _pizzeria.desks.size() == 3 and _pizzeria.shutters.size() == 2 and _pizzeria.pappy != null and _pizzeria.base_y() > 19.0,
		"desks %d, shutters %d, base y %.1f, points %d" % [_pizzeria.desks.size(), _pizzeria.shutters.size(), _pizzeria.base_y(), _pizzeria.test_points.size()])
	var chain := _chain()
	var segs := chain.segments.size() if chain != null else -1
	_check("chain links every body (Ballast in solo)", segs == bodies.size() - 1 and segs >= 1, "%d segments, %d bodies" % [segs, bodies.size()])
	_check("pickups spawned", get_tree().get_nodes_in_group("pickups").size() >= 10, "%d pickups" % get_tree().get_nodes_in_group("pickups").size())

	if only != "":
		if only.begins_with("p_"):
			var car := _level.get_node_or_null("Floor3/FreightCar") as FreightCar
			if car != null:
				car.server_park_top()
		await call("_test_" + only)
		_finish()
		return
	_test_seeds()
	await _test_keyboard()
	await _test_climb()
	await _test_lift()
	await _test_hang()
	await _test_items()
	await _test_hires()
	await _test_forced()
	await _test_scares()
	await _test_crouch()
	await _test_slide()
	await _test_extras()
	_test_invites()
	await _test_exit()
	await _test_p_desk()
	await _test_p_static()
	await _test_p_pappy()
	await _test_p_shutter()
	await _test_p_dumbwaiter()
	await _test_p_lift()
	await _test_p_power()
	await _test_p_items()
	await _test_p_scares()
	await _test_p_slide()
	await _test_p_exit()
	_finish()


## The building is different every run: other seeds must still produce four floors with every
## climb in place. Built off to the side and thrown away.
func _test_seeds() -> void:
	var ok := 0
	var detail := ""
	for s in [7, 42, 90210, 555555]:
		var y := YellowRooms.new()
		y.seed_value = s
		y.position = Vector3(500.0, 0.0, 500.0)  # well away from the real building
		add_child(y)
		var good := y.floors.size() == 4
		for key in ["spawn", "crates_start", "plate", "lift", "boost_shelf", "exit", "tray_start"]:
			good = good and y.test_points.has(key)
		var layouts := []
		for f in y.floors:
			layouts.append(f["ascent"])
		detail += " %d:%s%s" % [s, "ok" if good else "BAD", layouts]
		if good:
			ok += 1
		for c in y.find_children("*", "HollowHire", true, false):
			c.debug_frozen = true
		y.free()
	var same: bool = _level.floors[0]["ascent"] == _level.floors[1]["arrive"]
	_check("other seeds build whole buildings (a new layout every run), and the fixed test seed is unchanged", ok == 4 and same and _level.seed_value == YellowRooms.DEFAULT_SEED and Net.world_config["seed"] == YellowRooms.DEFAULT_SEED, detail)


func _test_extras() -> void:
	var signs := 0
	for l in _level.find_children("*", "Label3D", true, false):
		if (l as Label3D).text.ends_with("THIS WAY"):
			signs += 1
	_check("wayfinding signs along every floor's route", signs >= 8, "%d signs" % signs)
	# "Stuck?" regroup: everyone back to the last Break Room, no layoff counted.
	var wipes0 := GameState.wipes
	_place(_level.test_points["crates_start"], PI)
	await _wait(0.3)
	GameState.request_regroup("Bot")
	await _wait(0.3)
	var d := _host.global_position.distance_to(GameState.checkpoint_position)
	_check("regroup brings everyone to the checkpoint, no layoff", d < 4.0 and GameState.wipes == wipes0, "%.1f m away, wipes %d -> %d" % [d, wipes0, GameState.wipes])
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null:
		hud.call("caption", "test sound", _host.global_position + Vector3(0.0, 0.0, -5.0))
		var lines: Array = hud.get("_caption_lines")
		_check("sound captions appear with a direction", lines.size() >= 1 and String((lines[lines.size() - 1][0] as Label).text).contains(","), "%d lines" % lines.size())
	_host.model.pop_hat(Vector3.UP * 3.0)
	_check("hard hats come off", not _host.model.hat.visible, "")


func _test_invites() -> void:
	var port := Net.DEFAULT_PORT
	var code := InviteCode.encode("203.0.113.45", port, port)
	var back := InviteCode.parse(code, port)
	_check("invite code round-trips an address", code.length() == 8 and code[4] == "-" and back.get("host", "") == "203.0.113.45" and back.get("port", 0) == port, "%s -> %s" % [code, back])
	var odd := InviteCode.parse(InviteCode.encode("198.51.100.7", 7790, port), port)
	var pasted := InviteCode.parse("Join my CHAINS DEEZNUTS TOGETHER game! Invite code: %s" % code.to_lower(), port)
	var squashed := InviteCode.parse(code.replace("-", "").to_lower(), port)
	_check("invite codes survive odd ports, a pasted message, lowercase, no dash", odd.get("port", 0) == 7790 and pasted.get("host", "") == "203.0.113.45" and squashed.get("host", "") == "203.0.113.45", "%s / %s / %s" % [odd, pasted, squashed])
	var ip := InviteCode.parse("192.168.1.20:7791", port)
	_check("join box still takes IP addresses", ip.get("host", "") == "192.168.1.20" and ip.get("port", 0) == 7791 and InviteCode.parse("hello there", port).is_empty(), "%s" % ip)
	_check("public address check skips home and Tailscale addresses", InviteCode.is_public_ipv4("203.0.113.45") and not InviteCode.is_public_ipv4("192.168.1.20") and not InviteCode.is_public_ipv4("100.100.1.1"), "")
	var build := Net.get_build_id()
	_check("build fingerprint for the version check", build.length() == 12, build)
	if Net.is_solo:
		_check("solo has no invite", Net.invite.is_empty(), "%s" % Net.invite)
	else:
		_check("hosting builds an invite (router left alone when headless)", Net.invite.get("state", "") == "off" and Net.invite.has("lan"), "%s" % Net.invite)


func _test_keyboard() -> void:
	var spawn: Vector3 = _level.test_points["spawn"]
	_host.bot_controlled = false
	for logical_only in [false, true]:
		_place(spawn, PI)
		await _wait(0.5)
		var z0 := _host.global_position.z
		_key(KEY_W, true, logical_only)
		await _wait(0.6)
		_key(KEY_W, false, logical_only)
		await _wait(0.15)
		_check("W walks forward (%s)" % ("key label only" if logical_only else "physical key"), _host.global_position.z - z0 > 1.0, "walked %.2f m" % (_host.global_position.z - z0))
	# A tap must be a tap: let go and you stop within about a step.
	_place(spawn, PI)
	await _wait(0.5)
	var zt := _host.global_position.z
	_key(KEY_W, true, false)
	await _wait(0.12)
	_key(KEY_W, false, false)
	await _wait(0.8)
	var tap_walk := _host.global_position.z - zt
	_check("a quick W tap moves well under a meter (no overshoot)", tap_walk > 0.05 and tap_walk < 0.8, "walked %.2f m" % tap_walk)
	# Remote Controls: before any key flicker has been seen, a tap is still just a tap...
	var was_remote := Settings.remote_mode
	Settings.remote_mode = true
	_host.input.flicker_seen = false
	_place(spawn, PI)
	await _wait(0.5)
	var z1 := _host.global_position.z
	_key(KEY_W, true, false)
	await _wait(0.03)
	_key(KEY_W, false, false)
	await _wait(0.8)
	var remote_tap := _host.global_position.z - z1
	_check("Remote Controls: a 30 ms tap before any flicker is seen stays short", remote_tap < 0.9, "walked %.2f m" % remote_tap)
	# ...and once TeamViewer's tap stream is seen, the taps read as one hold.
	_place(spawn, PI)
	await _wait(0.5)
	z1 = _host.global_position.z
	for k in 6:
		_key(KEY_W, true, false)
		await _wait(0.02)
		_key(KEY_W, false, false)
		await _wait(0.03)
	await _wait(0.5)
	var stream_walk := _host.global_position.z - z1
	_check("Remote Controls turn a stream of 30 ms taps into a held key", _host.input.flicker_seen and stream_walk > 1.2, "flicker %s, walked %.2f m" % [_host.input.flicker_seen, stream_walk])
	# Remote Controls look: plain mouse movement turns the view, no button held.
	var yaw0 := _host._yaw
	_mouse_move(Vector2(120.0, 0.0))
	await _wait(0.4)
	_check("Remote Controls: moving the mouse turns the view, no button needed", _host._yaw < yaw0 - 0.1, "yaw %.2f -> %.2f" % [yaw0, _host._yaw])
	var yaw1 := _host._yaw
	_mouse_move(Vector2(900.0, 0.0))  # TeamViewer re-syncing the cursor, not a flick
	await _wait(0.4)
	var edges := [PlayerInput.edge_strength(0.0), PlayerInput.edge_strength(0.5), PlayerInput.edge_strength(1.0)]
	_check("cursor jumps don't spin the view; the window edges keep turning", absf(_host._yaw - yaw1) < 0.05 and edges == [-1.0, 0.0, 1.0], "yaw moved %.2f, edges %s" % [_host._yaw - yaw1, edges])
	Settings.remote_mode = was_remote
	_host.bot_controlled = true
	_bot(Vector2.ZERO, 0.0, 0)


func _test_climb() -> void:
	var start: Vector3 = _level.test_points["crates_start"]
	_place(start, PI)
	await _wait(0.5)
	var y0 := _host.global_position.y
	_bot(Vector2(0.0, 1.0), PI, 0, true)  # face +z into the first crate
	await _wait(0.42)
	_bot(Vector2.ZERO, PI, 0)  # stop on top, don't walk off the far side
	await _wait(0.4)
	var cell := _level.cell_center(0, _level.floors[0]["ascent"])
	var trace := " start %s" % _rel(cell)
	_check("mantle onto the 1.2 m crate", _host.global_position.y - y0 > 1.0, "rose %.2f m" % (_host.global_position.y - y0))
	_check("the B4 task list is up and 'find MAINTENANCE ACCESS' is ticked on arrival", GameState.tasks.size() == 3 and GameState.task_done(0) and not GameState.task_done(2), str(GameState.tasks))
	for step in 3:
		_bot(Vector2(1.0, 0.0), -PI * 0.5, 0)  # face +x up the steps
		await _wait(0.2)
		_bot(Vector2(1.0, 0.0), -PI * 0.5, 0, true)
		await _wait(0.42)
		if step < 2:
			_bot(Vector2.ZERO, -PI * 0.5, 0)
			await _wait(0.4)
		trace += " | step%d %s" % [step + 1, _rel(cell)]
	# Out of the hole: keep walking away to hoist whoever's below, then brace.
	await _wait(1.2)
	_bot(Vector2.ZERO, 0.0, Player.FLAG_BRACE)
	await _wait(0.6)
	_check("climbed the crates up to B3", _host.global_position.y > 4.8, "host y %.2f;%s | end %s" % [_host.global_position.y, trace, _rel(cell)])
	var cp := get_tree().current_scene.get_node_or_null("World/Level/Floor1/Checkpoint1") as Area3D
	var cp_info := "missing"
	if cp != null:
		cp_info = "cp at %s, overlaps %s, host at %s; f0 asc %s f1 arr %s crates %s" % [cp.global_position, cp.get_overlapping_bodies(), _host.global_position,
			_level.floors[0]["ascent"], _level.floors[1]["arrive"], _level.test_points["crates_start"]]
	_check("B3 checkpoint recorded on arrival", GameState.checkpoint_index >= 1, "index %d; %s" % [GameState.checkpoint_index, cp_info])


func _test_lift() -> void:
	var plate: Vector3 = _level.test_points["plate"]
	var lift: Vector3 = _level.test_points["lift"]
	# Locked out: standing on the plate does nothing until the fire alarm is pulled.
	var plate_node := _level.get_node_or_null("Floor1/PlateLift") as PressurePlate
	_host.teleport_to(plate, 0.0)
	await _wait(0.6)
	var dead := plate_node != null and not plate_node.enabled and not plate_node.pressed
	_level.alarm().server_pull()
	await _wait(0.2)
	_check("B3's plate is dead until the fire alarm releases the lift", dead and plate_node.enabled and _level.alarm().pulled, "enabled %s, pressed %s, pulled %s" % [plate_node.enabled if plate_node != null else null, plate_node.pressed if plate_node != null else null, _level.alarm().pulled])
	if _mate is Player:
		_mate.teleport_to(plate, 0.0)
	else:
		_host.teleport_to(plate, 0.0)  # solo: step on the plate first, it latches
		if _mate != null:
			_mate.teleport_to(plate + Vector3(0.6, 0.2, 0.6), 0.0)
		await _wait(0.4)
	_host.teleport_to(lift + Vector3(0.0, 0.2, 0.0), 0.0)
	await _wait(5.5)
	_check("plate + lift carry a player up to B2", _host.global_position.y > 9.7, "host y %.2f" % _host.global_position.y)


func _test_hang() -> void:
	if _mate == null or _mate is Player:
		# Floors are 5 m apart and so is the chain: a person who drops through a hole lands on the
		# floor below instead of dangling. The 35 kg Ballast cuffs low enough to dangle.
		print("[smoke] SKIP  dangle test needs the Ballast (a person reaches the floor below)")
		return
	# Floor B1's hole above the B2 shelf shaft: the +z half of the hole drops clear to B2's floor.
	var f2: Dictionary = _level.floors[2]
	var hole := _level.cell_center(3, f2["ascent"])
	var edge := hole + Vector3(0.0, 0.1, YellowRooms.HOLE * 0.5 + 0.5)
	var dangle_y := hole.y + 0.92 - (ChainSystem.MAX_SEGMENT_LENGTH - 0.15) - _mate.anchor_height()
	_level.hatch().debug_open()  # the hatch over this hole is open while someone hangs in it
	_level.hatch().debug_set_clock(60.0)
	_bot(Vector2.ZERO, 0.0, Player.FLAG_BRACE)
	_host.teleport_to(edge, 0.0)
	_mate.teleport_to(Vector3(hole.x, dangle_y, hole.z + 0.6), 0.0)
	await _wait(2.0)
	_check("bracing holds a dangling partner", _host.global_position.y > hole.y - 0.3 and _mate.global_position.y > hole.y - 5.0 + 0.05,
		"host y %.2f, partner y %.2f (floor below %.1f)" % [_host.global_position.y, _mate.global_position.y, hole.y - 5.0])
	_bot(Vector2.ZERO, 0.0, 0)
	var dragged := false
	for i in 16:
		await _wait(0.2)
		if _host.global_position.y < hole.y - 1.0:
			dragged = true
			break
	_check("unbraced: the dangler drags you over the edge", dragged, "host y %.2f" % _host.global_position.y)
	_place(_level.test_points["spawn"], PI)
	await _wait(0.3)
	_level.hatch().server_close()


func _test_items() -> void:
	var spawn: Vector3 = _level.test_points["spawn"]
	_place(spawn, PI)
	await _wait(0.5)
	# Flashlight.
	_give("flashlight")
	await _press_use()
	_check("flashlight turns on", _host.held_item != null and _host.held_item.is_active and (_host.synced_flags & Player.SFLAG_USING_ITEM) != 0, "flags %d" % _host.synced_flags)
	_host.server_drop_item(false)
	# Pistol: finite ammo, a reload, and the pocket topped up by an ammo box.
	_give("pistol")
	_host.noise = 0.0
	await _press_use()
	var ammo: int = _host.held_item.get("ammo") if _host.held_item != null else -1
	_check("pistol fires (ammo down, very loud, HUD shows 5 / 12)", ammo == 5 and _host.noise >= 80.0 and _host.ammo_text == "5 / 12", "ammo %d, noise %.0f, text '%s'" % [ammo, _host.noise, _host.ammo_text])
	_host.held_item.set("ammo", 0)
	await _wait(0.4)  # past the shot cooldown
	await _press_use()  # empty: fire starts a reload instead of a shot
	var reloading := _host.ammo_text == "RELOADING"
	await _wait(1.8)
	var after_reload: int = _host.held_item.get("ammo")
	var reserve: int = _host.held_item.get("reserve")
	_check("empty magazine reloads from the pocket (6 in, pocket down)", reloading and after_reload == 6 and reserve == 6, "reloading %s, ammo %d, reserve %d" % [reloading, after_reload, reserve])
	var box := ItemRegistry.get_data("ammo").create_logic()
	var merged := _host.server_give_item(box)
	reserve = _host.held_item.get("reserve")
	_check("an ammo box pours into a carried Snubby instead of taking a slot", merged and reserve == 18 and _host.free_slot() == 1, "merged %s, reserve %d, free slot %d" % [merged, reserve, _host.free_slot()])
	var state_before: Dictionary = _host.held_item.carry_state()
	_host.server_drop_item(true)
	await _wait(0.3)
	_check("G-drop leaves a pickup behind, remembering its ammo", _count_pickups("pistol") >= 1 and state_before.get("reserve", 0) == 18, "%d pistol pickups, state %s" % [_count_pickups("pistol"), state_before])
	# Three slots: pick up three, the fourth is refused, 1/2/3 select, the selected one answers F.
	_give("flashlight")
	_host.server_give_item(ItemRegistry.get_data("decoy").create_logic())
	_host.server_give_item(ItemRegistry.get_data("airhorn").create_logic())
	var popper := ItemRegistry.get_data("popper").create_logic()
	var fourth := _host.server_give_item(popper)
	if not fourth:
		popper.free()  # refused: nobody owns it (a pickup would free it the same way)
	_check("three slots fill; a fourth item is refused", not fourth and _host.free_slot() < 0 and _host.slot_ids.size() == 3 and "" not in _host.slot_ids, "fourth %s, slots %s" % [fourth, _host.slot_ids])
	_host.select_slot(0)
	await _press_use()
	var light_on := _host.held_item_id == "flashlight" and _host.held_item.is_active
	_host.select_slot(2)
	await _wait(0.1)
	var light_off_when_switched := not _host.find_item("flashlight").is_active and _host.held_item_id == "airhorn"
	_check("selecting a slot switches hands; the flashlight goes off when you switch away", light_on and light_off_when_switched, "on %s, off after switch %s, held '%s'" % [light_on, light_off_when_switched, _host.held_item_id])
	_host.server_drop_all()
	await _wait(0.3)
	_check("dropping everything empties the slots", _host.free_slot() == 0 and _host.held_item == null, "%s" % _host.slot_ids)
	# Energy drink.
	_give("drink")
	await _press_use()
	_check("energy drink: boost, item used up", _host.buff_state == 1 and _host.held_item == null, "buff %d" % _host.buff_state)
	# Decoy.
	_give("decoy")
	await _press_use()
	await _wait(1.5)
	var decoy := _find_thrown("decoy")
	_check("decoy thrown, lands, and is the loudest thing around", decoy != null and decoy.noise_level() >= 100.0, "decoy %s" % (decoy != null))
	# Bomb.
	_give("bomb")
	await _press_use()
	var exploded := false
	var seen := false
	for i in 40:
		await _wait(0.1)
		var b := _find_thrown("bomb")
		if b != null:
			seen = true
			if b.exploded:
				exploded = true
				break
	_check("bomb fuse runs and it explodes", exploded, "seen %s, held '%s', thrown nodes %s" % [seen, _host.held_item_id, _thrown_names()])
	# Jetpack.
	_place(spawn, PI)
	await _wait(0.6)
	_give("jetpack")
	var y0 := _host.global_position.y
	var max_y := y0
	_bot(Vector2.ZERO, PI, Player.FLAG_USE)
	for i in 10:
		await _wait(0.1)
		max_y = maxf(max_y, _host.global_position.y)
	_bot(Vector2.ZERO, PI, 0)
	_check("jetpack lifts the holder (and drags the chain)", max_y - y0 > 1.0, "rose %.2f m" % (max_y - y0))
	await _wait(2.0)
	_host.server_drop_item(false)
	_host.buff_state = 0


func _rel(cell: Vector3) -> String:
	var r := _host.global_position - cell
	return "(%.2f, %.2f, %.2f)" % [r.x, r.y, r.z]


func _freeze_hires(on: bool) -> void:
	for node in get_tree().get_nodes_in_group("hire"):
		(node as HollowHire).debug_frozen = on


## The Hollow Hires: they hunt by sight, crouching only shortens their reach, the flashlight
## stuns, two rounds kill, Break Rooms are safe, the floor sends replacements.
func _test_hires() -> void:
	var hires := _level.hires_on(0)
	_check("B4 has its Hollow Hires, started well away from the Break Room", hires.size() == YellowRooms.HIRES_PER_FLOOR[0] and _level.hires_on(1).size() == YellowRooms.HIRES_PER_FLOOR[1] and hires[0].global_position.distance_to(_level.test_points["spawn"]) > 6.0, "%d on B4, %d on B3, first %.1f m from spawn" % [hires.size(), _level.hires_on(1).size(), hires[0].global_position.distance_to(_level.test_points["spawn"])])
	var h := hires[0]
	var start: Vector3 = _level.test_points["crates_start"]  # out in the office, facing +z
	var far := start + Vector3(0.0, 0.0, 3.2)
	# Seen: it screams and runs you down; unrescued, a layoff.
	_place(start, PI)
	_park_mate(start + Vector3(8.0, 0.0, 0.0))
	await _wait(0.3)
	h.debug_reset(far, 0.0)  # facing -z: at the host
	h.debug_frozen = false
	var wipes0 := GameState.wipes
	var saw_chase := false
	var grabbed := false
	for i in 80:
		await _wait(0.1)
		if h.hstate == HollowHire.HState.CHASE:
			saw_chase = true
		if h.grab_peer == 1:
			grabbed = true
		if GameState.wipes > wipes0:
			break
	_check("a Hire that sees you chases, grabs, and (nobody helping) takes you: a layoff", saw_chase and grabbed and GameState.wipes > wipes0, "chase %s, grabbed %s, wipes %d -> %d, state %d" % [saw_chase, grabbed, wipes0, GameState.wipes, h.hstate])
	await _wait(1.6)
	# The call-out: the one that sees you screams, and the other one on the floor answers and comes.
	var h2: HollowHire = hires[1]
	_place(start, PI)
	_park_mate(start + Vector3(8.0, 0.0, 0.0))
	await _wait(0.3)
	h.debug_frozen = true
	h2.debug_reset(far + Vector3(3.0, 0.0, 0.0), PI)  # off to the side, facing away: it can't see you
	h2.debug_frozen = false
	h.debug_reset(far, 0.0)
	h.debug_frozen = false
	var answered := false
	for i in 12:
		await _wait(0.1)
		if h2.hstate == HollowHire.HState.CHASE and h2.hunt_peer == 1:
			answered = true
			break
	_check("one that sees you calls the floor: the other Hire drops its walk and chases too", answered, "h2 state %d, hunting %d" % [h2.hstate, h2.hunt_peer])
	h2.debug_frozen = true
	h2.respawn_at(start + Vector3(14.0, 0.0, 0.0))
	h.debug_frozen = true
	h.respawn_at(start + Vector3(14.0, 0.0, 3.0))
	await _wait(0.3)
	# The sweep: at the end of a walk it turns through 180 degrees. Standing still behind one is
	# a gamble, and here it loses: the sweep finds you.
	_place(start, PI)
	_host.teleport_to(far + Vector3(2.6, 0.1, 0.0), PI)  # square to its side: out of its cone until it turns
	if _mate != null:
		_mate.teleport_to(far + Vector3(3.8, 0.1, 0.0), PI)  # beside you, so the chain leaves you where you stand
	await _wait(0.3)
	h.debug_reset(far, PI)
	var yaw0 := h.synced_yaw
	h.debug_frozen = false
	h.debug_sweep()
	var sweeping := h.hstate == HollowHire.HState.SWEEP
	var turned := 0.0
	var found := false
	for i in 30:
		await _wait(0.1)
		turned = maxf(turned, absf(wrapf(h.synced_yaw - yaw0, -PI, PI)))
		if h.hstate == HollowHire.HState.CHASE:
			found = true
			break
	h.debug_frozen = true
	h.respawn_at(start + Vector3(14.0, 0.0, 3.0))
	_check("at the end of a walk it sweeps the room through 180 degrees, and the sweep finds whoever stood still beside it", sweeping and turned > 0.8 and found, "swept %s, turned %.2f rad, found %s, state %d" % [sweeping, turned, found, h.hstate])
	await _wait(0.3)
	# Squeaky Dennis: the whole floor goes to him and stands over him for as long as he squeaks.
	_place(start, PI)
	_park_mate(start + Vector3(8.0, 0.0, 0.0))
	await _wait(0.3)
	h.debug_reset(start + Vector3(4.0, 0.0, 3.0), -PI * 0.5)  # same room, far side, facing +x: away from you
	_give("decoy")
	await _press_use()
	await _wait(0.8)
	var dennis := _find_thrown("decoy")
	_place(spawn_of(), PI)  # out of its sight while it walks over
	h.debug_frozen = false
	var went := false
	var held := false
	for i in 60:
		await _wait(0.1)
		if dennis != null and is_instance_valid(dennis) and h.get("_hold") == dennis and (h.hstate == HollowHire.HState.INVESTIGATE or h.hstate == HollowHire.HState.SWEEP):
			went = true
			if h.hstate == HollowHire.HState.SWEEP and h.global_position.distance_to(dennis.global_position) < 2.5:
				held = true
				break
	_check("a squeaky decoy pulls a Hire across the room, and it stands over it staring", went and held, "went %s, held %s, state %d, %.1f m from it" % [went, held, h.hstate, h.global_position.distance_to(dennis.global_position) if dennis != null and is_instance_valid(dennis) else -1.0])
	h.debug_reset(start + Vector3(14.0, 0.0, 3.0), 0.0)
	h.debug_frozen = false  # the checks below reset it into place themselves
	await _wait(0.3)
	# Crouching doesn't hide you at close range.
	_place(start, PI)
	_park_mate(start + Vector3(8.0, 0.0, 0.0))
	_bot(Vector2.ZERO, PI, Player.FLAG_BRACE)
	await _wait(0.4)
	h.debug_reset(far, 0.0)
	await _wait(0.5)
	var seen_crouched := h.hstate == HollowHire.HState.CHASE or h.hstate == HollowHire.HState.GRAB
	_bot(Vector2.ZERO, PI, 0)
	_check("crouching three metres in front of one doesn't hide you", seen_crouched, "state %d" % h.hstate)
	# Behind it: not seen.
	h.debug_reset(far, PI)  # facing +z: away from the host
	await _wait(0.6)
	_check("one looking the other way doesn't see you", h.hstate != HollowHire.HState.CHASE, "state %d" % h.hstate)
	# The flashlight in its face stuns it (and it is wise to it for a few seconds after).
	_place(start, PI)
	_park_mate(start + Vector3(8.0, 0.0, 0.0))
	await _wait(0.3)
	h.debug_reset(far, 0.0)
	_give("flashlight")
	await _press_use()
	var to: Vector3 = h.head_point() - _host.eye_position()
	_host._apply_input(Vector2.ZERO, atan2(-to.x, -to.z), atan2(to.y, Vector2(to.x, to.z).length()), _seq << Player.JUMP_SEQ_SHIFT)
	var stunned := false
	for i in 20:
		await _wait(0.1)
		if h.hstate == HollowHire.HState.STUNNED:
			stunned = true
			break
	_check("a flashlight held in its face stuns it", stunned and GameState.wipes == wipes0 + 1, "state %d after the beam" % h.hstate)
	_host.server_drop_item(false)
	await _wait(HollowHire.STUN_TIME + 0.3)
	_check("...and it comes round again", h.hstate != HollowHire.HState.STUNNED, "state %d" % h.hstate)
	# Two rounds drop it; the floor sends another after a while, out of sight.
	h.debug_reset(start + Vector3(0.0, 0.0, 5.0), 0.0)
	h.debug_frozen = true
	_give("pistol")
	for k in 2:
		to = h.chest_point() - _host.eye_position()
		var yaw := atan2(-to.x, -to.z)
		var pitch := atan2(to.y, Vector2(to.x, to.z).length())
		_host._apply_input(Vector2.ZERO, yaw, pitch, Player.FLAG_USE | (_seq << Player.JUMP_SEQ_SHIFT))
		await _wait(0.1)
		_host._apply_input(Vector2.ZERO, yaw, pitch, _seq << Player.JUMP_SEQ_SHIFT)
		await _wait(0.35)
	_check("two Snubby rounds drop a Hire", h.is_dead() and h.hits >= 2, "hits %d, state %d" % [h.hits, h.hstate])
	_host.server_drop_item(false)
	var before := h.global_position
	_level.debug_force_hire_respawn(0)
	await _wait(0.3)
	var d := h.global_position.distance_to(_host.global_position)
	_check("the floor sends a replacement in somewhere out of sight", not h.is_dead() and d > 12.0 and h.global_position.distance_to(before) > 1.0, "%.1f m away, state %d" % [d, h.hstate])
	# A bomb kills one outright.
	h.blast()
	_check("a blast kills a Hire", h.is_dead(), "state %d" % h.hstate)
	h.respawn_at(far)
	h.debug_frozen = true
	# Break Rooms are safe: it stands at the door and gives up.
	var spawn: Vector3 = _level.test_points["spawn"]
	_place(spawn, PI)
	_park_mate(spawn + Vector3(1.5, 0.0, 0.0))
	await _wait(0.3)
	var wipes2 := GameState.wipes
	h.debug_reset(spawn + Vector3(0.0, 0.0, 3.0), 0.0)
	h.debug_frozen = false
	await _wait(4.5)
	_check("in a Break Room it won't come in: no grab, no layoff", GameState.wipes == wipes2 and not _host.is_grabbed(), "wipes %d -> %d, state %d" % [wipes2, GameState.wipes, h.hstate])
	# A teammate (or the Ballast) beside the victim pulls it off.
	if _mate != null:
		_place(start, PI)
		await _wait(0.3)
		h.debug_reset(start + Vector3(0.0, 0.0, 1.0), 0.0)
		h.call("_start_grab", _host)
		_mate.teleport_to(start + Vector3(1.2, 0.0, 0.0), 0.0)
		if _mate is Player:
			(_mate as Player)._apply_input(Vector2.ZERO, 0.0, 0.0, Player.FLAG_BRACE)
		var wipes3 := GameState.wipes
		var freed := false
		for i in 30:
			await _wait(0.1)
			if not _host.is_grabbed():
				freed = true
				break
		_check("someone braced beside the victim pulls it off before the layoff", freed and GameState.wipes == wipes3, "freed %s, state %d" % [freed, h.hstate])
		if _mate is Player:
			(_mate as Player)._apply_input(Vector2.ZERO, 0.0, 0.0, 0)
	h.debug_frozen = true
	_place(spawn, PI)
	await _wait(0.4)


func spawn_of() -> Vector3:
	return _level.test_points["spawn"]


## The route's forced events: the jammed door that opens to a sprint and wakes the floor, the
## fire alarm that releases B3's lift, the 25 s hatch over B2's shaft, and B1's ambush.
func _test_forced() -> void:
	print("[smoke] forced: host %s (%d), mate %s, bodies %s" % [_host.name, _host.join_index, _mate.name if _mate != null else "-", Net.get_chain_bodies()])
	# The jammed door on B4: a walk doesn't move it, a sprint bangs it open, and the floor comes.
	var door := _level.stuck_door(0)
	if door == null:
		_check("B4 has a jammed door on the route", false, "none on this seed")
	else:
		var at: Vector3 = _level.test_points["door0"]
		var out: Vector3 = _level.test_points["door0_axis"]
		var yaw := atan2(-out.x, -out.z)
		var plane := door.global_position
		for hh in _level.hires_on(0):
			hh.respawn_at(_level.test_points["crates_start"] + Vector3(14.0, 0.0, 3.0))  # parked far off, frozen (so none sees you first; not in the Break Room, whose tube it would dim); alert() still sets their state
		var move := Vector2(out.x, out.z)  # input_move is world space
		_host.teleport_to(at, yaw)
		if _mate != null:
			_mate.teleport_to(at - out * 2.0, yaw)
		await _wait(0.3)
		_bot(move, yaw, 0)  # walk into it
		await _wait(1.4)
		var through_walk := (_host.global_position - plane).dot(out)
		var walked_open := door.open
		_bot(Vector2.ZERO, yaw, 0)
		var side := Vector3(out.z, 0.0, out.x)
		if _mate != null:
			_mate.teleport_to(at - out * 2.0 + side * 1.3, yaw)  # beside the run-up, never in it
		await _wait(0.2)
		_host.teleport_to(at - out * 2.0, yaw)
		await _wait(0.3)
		_bot(move, yaw, Player.FLAG_RUN)  # shoulder it
		var opened := false
		var trace := ""
		for i in 25:
			await _wait(0.1)
			if i % 3 == 0:
				trace += " %.1f/%.1f/s%d" % [(_host.global_position - plane).dot(out), Vector2(_host.velocity.x, _host.velocity.z).length(), _host.state]
				if i == 0:
					trace += " host %s mate %s flags %d by %s" % [_host.global_position, _mate.global_position if _mate != null else Vector3.ZERO, _host.input_flags, _host.grabbed_by]
			if door.open:
				opened = true
				break
		await _wait(0.3)
		_bot(Vector2.ZERO, yaw, 0)
		var through_run := (_host.global_position - plane).dot(out)
		var loud := door.noise_level() >= 100.0
		var woke := 0
		for hh in _level.hires_on(0):
			if hh.is_alerted() and hh.hstate == HollowHire.HState.INVESTIGATE:
				woke += 1
		_check("B4's jammed door stops a walk, bangs open to a sprint (the shoulderer stumbles through), and wakes every Hire on the floor",
			through_walk < 0.0 and not walked_open and opened and through_run > 0.0 and loud and woke == _level.hires_on(0).size(),
			"walk %.2f m (open %s), sprint opened %s, %.2f m past, loud %s, woke %d of %d, trace%s" % [through_walk, walked_open, opened, through_run, loud, woke, _level.hires_on(0).size(), trace])
		await _wait(0.4)
		var done: Dictionary = _level.get("_door_done")
		var ticked := GameState.task_done(1) if GameState.checkpoint_index == 0 else true  # another floor's list may be up by now
		_check("...and the B4 checklist ticks the door", done.get(0, false) and ticked, "door done %s, tasks %s" % [done, GameState.tasks])
		_freeze_hires(true)
	# B3: the plate is covered in _test_lift; here, the pull itself (hold Ctrl at the station).
	var alarm := _level.alarm()
	alarm.pulled = false
	alarm.seconds_left = 0.0
	var plate1 := _level.get_node_or_null("Floor1/PlateLift") as PressurePlate
	plate1.set_enabled(false)
	var a_at: Vector3 = _level.test_points["alarm"]
	_host.teleport_to(a_at, 0.0)
	if _mate != null:
		_mate.teleport_to(a_at + Vector3(0.0, 0.0, 1.2), 0.0)
	await _wait(0.3)
	_bot(Vector2.ZERO, 0.0, Player.FLAG_BRACE)
	var pulled := false
	for i in 20:
		await _wait(0.1)
		if alarm.pulled:
			pulled = true
			break
	_bot(Vector2.ZERO, 0.0, 0)
	await _wait(0.2)
	var awake := 0
	var eligible := 0
	for hh in _level.hires_on(1):
		if hh.is_dead() or hh.is_hunting() or hh.hstate == HollowHire.HState.STUNNED:
			continue  # one already on someone, or down, has other things to do
		eligible += 1
		if hh.is_alerted():
			awake += 1
	_check("holding Ctrl at the fire alarm pulls it: klaxon, strobe, the plate goes live, the floor wakes for 40 s",
		pulled and alarm.sounding() and alarm.seconds_left > 35.0 and plate1.enabled and _level.lights().is_floor_flickering(1) and awake == eligible and eligible > 0,
		"pulled %s, left %.1f, plate %s, strobe %s, awake %d of %d" % [pulled, alarm.seconds_left, plate1.enabled, _level.lights().is_floor_flickering(1), awake, eligible])
	_freeze_hires(true)
	# B2: the hatch. Closed, it is solid over the hole; the switch opens it for 25 s; it slams when
	# the time is up unless someone is in the hole.
	var hatch := _level.hatch()
	if hatch.open:
		hatch.server_close()
	await _wait(0.2)
	var hole_c: Vector3 = _level.test_points["hatch"]
	var space: PhysicsDirectSpaceState3D = _host.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(hole_c + Vector3(0.0, 2.0, 0.0), hole_c + Vector3(0.0, 4.5, 0.0), ChainBody.LAYER_WORLD)
	var solid := not space.intersect_ray(q).is_empty()
	var sw_at: Vector3 = _level.test_points["hatch_switch"]
	_host.teleport_to(sw_at, 0.0)
	if _mate != null:
		_mate.teleport_to(sw_at + Vector3(0.0, 0.0, 1.2), 0.0)
	await _wait(0.3)
	_bot(Vector2.ZERO, 0.0, Player.FLAG_BRACE)
	var released := false
	for i in 20:
		await _wait(0.1)
		if hatch.open:
			released = true
			break
	_bot(Vector2.ZERO, 0.0, 0)
	await _wait(0.3)
	var clear := space.intersect_ray(q).is_empty()
	var clock := hatch.seconds_left
	hatch.debug_set_clock(0.3)
	await _wait(0.7)
	var slammed := not hatch.open
	_check("B2's hatch is solid over the shaft; Ctrl at the release opens it for 25 s; it slams when time's up",
		solid and released and clear and clock > 23.0 and clock <= TimedHatch.OPEN_SECONDS and slammed,
		"solid %s, released %s, clear %s, clock %.1f, slammed %s" % [solid, released, clear, clock, slammed])
	hatch.debug_open()
	_host.teleport_to(hole_c + Vector3(0.0, YellowRooms.FLOOR_H + 0.1, YellowRooms.HOLE * 0.5 + 0.3), PI)  # on B1, at the lip of the hole
	if _mate != null:
		_mate.teleport_to(hole_c + Vector3(1.5, YellowRooms.FLOOR_H + 0.1, YellowRooms.HOLE * 0.5 + 0.6), PI)  # beside, so the chain doesn't drag the host off the lip
	await _wait(0.3)
	var in_hole: bool = hatch.call("_body_in_hole")
	var where := _host.global_position - hatch.global_position
	hatch.debug_set_clock(0.3)
	await _wait(0.8)
	var waited := hatch.open
	_host.teleport_to(sw_at, 0.0)
	await _wait(0.5)
	_check("...but never on someone in the hole: it waits until the shaft is clear", in_hole and waited and not hatch.open, "in hole %s (%s), open with a body in it %s, after %s" % [in_hole, where, waited, hatch.open])
	# B1: the first one into the elevator room brings a Hire through the door behind the group.
	var f3: Dictionary = _level.floors[3]
	var cp_was := GameState.checkpoint_index
	GameState.checkpoint_index = 3
	_level.call("server_on_respawn")  # re-arms the ambush, parks the Hires away from the checkpoint
	for hh in _level.hires_on(3):
		hh.debug_frozen = false
	var room := _level.cell_center(3, f3["ascent"]) + Vector3(0.0, 0.1, -2.6)  # in the room, outside the car
	_host.teleport_to(room, 0.0)
	if _mate != null:
		_mate.teleport_to(room + Vector3(1.0, 0.0, 0.0), 0.0)
	var ambusher: HollowHire = null
	var d_door := -1.0
	var doorway := (_level.cell_center(3, f3["path"][f3["path"].size() - 2]) + _level.cell_center(3, f3["ascent"])) * 0.5
	for i in 40:
		await _wait(0.05)
		if bool(_level.get("_ambush_armed")):
			continue  # not fired yet
		for hh in _level.hires_on(3):
			var d := hh.global_position.distance_to(doorway)
			if hh.is_hunting() and (ambusher == null or d < d_door):  # the one that came through the door, not one that spotted you on its own
				ambusher = hh
				d_door = d
		if ambusher != null:
			break
	_check("B1: stepping into the elevator room brings a Hire screaming through the door behind you", ambusher != null and d_door < 6.0, "ambusher %s, %.1f m from the doorway, state %d" % [ambusher != null, d_door, ambusher.hstate if ambusher != null else -1])
	_freeze_hires(true)
	if ambusher != null:
		ambusher.release(false)
	for hh in _level.hires_on(3):
		hh.respawn_at(_level.cell_center(3, f3["arrive"]) + Vector3(12.0, 0.0, 0.0))
	GameState.checkpoint_index = cp_was
	_place(_level.test_points["spawn"], PI)
	await _wait(0.4)


func _thrown_names() -> String:
	var w := get_tree().current_scene.get_node_or_null("World/Thrown")
	if w == null:
		return "-"
	var names: PackedStringArray = []
	for t in w.get_children():
		names.append(t.name)
	return ",".join(names)


func _test_scares() -> void:
	var before := ScareDirector.scares_played
	var kinds := ["lunge", "lights_out", "tile", "figure", "whisper", "phone", "slam", "dennis", "breath", "footsteps", "stalker"]
	for kind in kinds:
		ScareDirector.trigger_for(kind, _host)
		await _wait(0.15)
	await _wait(0.5)
	_check("every scare type plays", ScareDirector.scares_played - before >= kinds.size(), "%d played" % (ScareDirector.scares_played - before))
	# Variety: the director leans away from what it just played.
	var picks: Dictionary = {}
	for i in 40:
		var k: String = ScareDirector.call("_pick_kind", _host.global_position)
		picks[k] = int(picks.get(k, 0)) + 1
	_check("the procedural director spreads its picks across kinds", picks.size() >= 6, "%s" % picks)
	_check("a task checklist is up for the current floor", GameState.tasks.size() >= 2, str(GameState.tasks))
	# Dark that lasts: lights_out holds for 12-20 s, and the floor's power stutters out on its
	# own (flicker, then dark) with the Break Room tubes left on.
	_place(_level.test_points["spawn"], PI)
	await _wait(0.3)
	ScareDirector.trigger_for("lights_out", _host)
	await _wait(10.5)
	var long_dark := ScareDirector.blackout_active()
	var msec := ScareDirector.lights_out_msec(_host.global_position)
	_check("lights_out keeps the lights out for 12-20 s (a flashlight is the way across)", long_dark and msec >= 12000 and msec <= 20000, "still dark after 10.5 s %s, this spot %d ms" % [long_dark, msec])
	var lights := _level.lights()
	_level.debug_power_stutter(0, 14.0)
	await _wait(0.2)
	var flick := lights.is_floor_flickering(0)
	await _wait(1.6)
	var dark := lights.is_floor_dark(0)
	var safe_lit := -1.0
	var hall_dark := INF
	for i in 2:
		for t in lights.tubes:
			if t.floor_index != 0 or not t.light.visible:
				continue
			if t.safe:
				safe_lit = maxf(safe_lit, t.light.light_energy)
			elif t.kind == 0:
				hall_dark = minf(hall_dark, t.light.light_energy)
		await _wait(0.3)
	_check("a power stutter: the floor flickers, then goes dark, and the Break Room keeps its lights", flick and dark and safe_lit > 0.5 and hall_dark < 0.3, "flicker %s, dark %s, break room %.2f, darkest hall tube %.2f" % [flick, dark, safe_lit, hall_dark])


func _test_crouch() -> void:
	# Crouch: the capsule shrinks, the eye drops, and letting go stands you back up.
	_place(_level.test_points["spawn"], PI)
	await _wait(0.4)
	_bot(Vector2.ZERO, PI, Player.FLAG_BRACE)
	await _wait(0.4)
	var crouched_h := (_host._shape.shape as CapsuleShape3D).height
	var eye_low := _host.eye_position().y - _host.global_position.y
	_bot(Vector2.ZERO, PI, 0)
	await _wait(0.5)
	var after := (_host._shape.shape as CapsuleShape3D).height
	_check("Ctrl crouches: the capsule shrinks and the eyes drop; letting go stands back up", crouched_h < 1.4 and eye_low < 1.3 and after > 1.7,
		"crouched %.2f m, eye %.2f, after %.2f, crouched flag %s, headroom %s" % [crouched_h, eye_low, after, _host._crouched, _host._headroom()])
	# Under something low you stay down until there's room (the Break Room table is 0.74 m: too
	# low to crawl under, so use the cable tray: 1.9 m of headroom, less than a standing body).
	var under: Vector3 = _level.test_points["tray_start"] + Vector3(0.0, -1.8, 0.0)
	_host.teleport_to(under, PI)
	await _wait(0.3)
	_bot(Vector2.ZERO, PI, Player.FLAG_BRACE)
	await _wait(0.4)
	_bot(Vector2.ZERO, PI, 0)
	await _wait(0.4)
	var stuck_low := (_host._shape.shape as CapsuleShape3D).height
	_check("no headroom under the cable tray: you stay crouched until you move out", stuck_low < 1.4 and _host._crouched, "height %.2f, crouched %s" % [stuck_low, _host._crouched])
	_place(_level.test_points["spawn"], PI)
	await _wait(0.5)


## Sprint, then Ctrl: the slide. The Break Room is 5 m deep, so this checks the drop into the
## slide and the stand-up; the long carry and the chain jerk are checked in the Dining Hall.
func _test_slide() -> void:
	var spawn: Vector3 = _level.test_points["spawn"]
	_place(spawn, PI)
	await _wait(0.4)
	_bot(Vector2(0.0, 1.0), PI, Player.FLAG_RUN)  # sprint toward +z
	await _wait(0.55)
	var sprint_speed := Vector2(_host.velocity.x, _host.velocity.z).length()
	var z0 := _host.global_position.z
	_bot(Vector2(0.0, 1.0), PI, Player.FLAG_RUN | Player.FLAG_BRACE)  # Ctrl: slide
	await _wait(0.1)
	var sliding := _host.is_sliding()
	var flagged := (_host.synced_flags & Player.SFLAG_SLIDING) != 0
	var low := (_host._shape.shape as CapsuleShape3D).height
	var slide_speed := Vector2(_host.velocity.x, _host.velocity.z).length()
	_bot(Vector2.ZERO, PI, 0)  # let go of everything: the slide carries on by itself
	await _wait(0.25)
	var carried := _host.global_position.z - z0
	var still_sliding := _host.is_sliding()
	_check("sprint + Ctrl drops you into a slide: crouch capsule, faster than the sprint, carries with no keys held",
		sprint_speed > 4.5 and sliding and flagged and low < 1.4 and slide_speed > sprint_speed and still_sliding and carried > 1.5,
		"sprint %.1f m/s, sliding %s, flag %s, capsule %.2f, slide %.1f m/s, carried %.2f m in 0.35 s, still %s" % [sprint_speed, sliding, flagged, low, slide_speed, carried, still_sliding])
	await _wait(1.0)
	var after := (_host._shape.shape as CapsuleShape3D).height
	_check("the slide ends on its own and you stand back up", not _host.is_sliding() and after > 1.7, "sliding %s, capsule %.2f" % [_host.is_sliding(), after])
	# Ctrl still held when it ends: you stay crouched (so a slide can end under something low).
	_place(spawn, PI)
	await _wait(0.4)
	_bot(Vector2(0.0, 1.0), PI, Player.FLAG_RUN)
	await _wait(0.55)
	_bot(Vector2(0.0, 1.0), PI, Player.FLAG_RUN | Player.FLAG_BRACE)
	await _wait(0.1)
	var began := _host.is_sliding()
	_bot(Vector2.ZERO, PI, Player.FLAG_BRACE)
	await _wait(1.3)
	var held_low := (_host._shape.shape as CapsuleShape3D).height
	_bot(Vector2.ZERO, PI, 0)
	await _wait(0.4)
	_check("Ctrl held through the end of a slide leaves you crouched", began and not _host.is_sliding() and held_low < 1.4 and (_host._shape.shape as CapsuleShape3D).height > 1.7, "began %s, capsule %.2f" % [began, held_low])
	_place(spawn, PI)
	await _wait(0.4)


func _test_exit() -> void:
	var exit: Vector3 = _level.test_points["exit"]
	var bodies := Net.get_chain_bodies()
	for i in bodies.size():
		bodies[i].teleport_to(exit + Vector3(-0.6 + 0.6 * float(i), 0.1, 0.0), 0.0)
	var car := _level.get_node_or_null("Floor3/FreightCar") as FreightCar
	var closed := false
	for i in 160:
		await _wait(0.1)
		if car != null and car.door_closed:
			closed = true
		if car != null and car.has_arrived() and not car.door_closed:
			break
	var top := _pizzeria.base_y()
	_check("everyone in the freight elevator: the door shuts and the car rides up into the pizzeria",
		closed and car != null and car.has_arrived() and _host.global_position.y > top - 0.5,
		"door shut %s, phase %d, host y %.2f (pizzeria floor %.1f)" % [closed, car.phase if car != null else -1, _host.global_position.y, top])
	await _wait(0.5)
	_check("Receiving checkpoint (2.1) recorded on arrival", GameState.checkpoint_index >= 4, "index %d" % GameState.checkpoint_index)
	_check("night clock runs from 12:00 AM", _pizzeria.clock_text().ends_with("AM") and _pizzeria.night_seconds > 0.0, _pizzeria.clock_text())
	await _wait(0.4)
	_check("the Dining Hall task list replaces the office one on arrival", GameState.tasks.size() == 3 and String(GameState.tasks[0][0]).begins_with("Clip into"), str(GameState.tasks))


func _test_p_static() -> void:
	# The camera scare: static that must end. Count looping one-shot players under the root
	# before and after; a leftover player with a looping stream is the bug.
	var hud := get_tree().get_first_node_in_group("hud")
	var desk := _pizzeria.desks[0]
	_place(_p("p_desk0"), 0.0)
	await _wait(0.5)
	var leak_before := _looping_players()
	for i in 3:
		ScareDirector.trigger_for("static_face", _host)
		await _wait(0.2)
	ScareDirector.trigger_for("counter_bell", _host)
	await _wait(0.3)
	_place(_p("p_arrive"), PI)  # walk off mid-scare
	await _wait(2.6)
	var leak_after := _looping_players()
	var panel = hud.get("_night") if hud != null else null
	var static_left: float = float(panel.get("_static")) if panel != null else 0.0
	_check("camera static scares leave no looping sound behind, even when interrupted", leak_after <= leak_before and static_left < 0.2 and desk.occupant_peer == 0, "loopers %d -> %d, static %.2f" % [leak_before, leak_after, static_left])
	var one := Sfx.one_shot("static")
	_check("one-shot sounds never loop (the root cause: a looping 'static' bank played as a one-shot)", one.loop_mode == AudioStreamWAV.LOOP_DISABLED and Sfx.stream("static").loop_mode != AudioStreamWAV.LOOP_DISABLED, "")


func _looping_players() -> int:
	var n := 0
	for c in get_tree().root.get_children():
		var s: AudioStream = null
		if c is AudioStreamPlayer:
			s = (c as AudioStreamPlayer).stream
		elif c is AudioStreamPlayer3D:
			s = (c as AudioStreamPlayer3D).stream
		if s is AudioStreamWAV and (s as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED:
			n += 1
	return n


# --- Level 2 ------------------------------------------------------------------------------------------

func _p(key: String) -> Vector3:
	return _pizzeria.test_points[key]


func _test_p_desk() -> void:
	var desk := _pizzeria.desks[0]
	_place(_p("p_desk0"), 0.0)
	await _wait(0.5)
	_check("standing at the Host Stand desk clips you into the cameras", desk.occupant_peer == 1, "occupant %d" % desk.occupant_peer)
	var cam0 := desk.cam_index
	var power0 := _pizzeria.power
	await _press_use()
	await _wait(0.6)
	_check("F flips to the next camera; the cameras drain the power bank", desk.cam_index == (cam0 + 1) % desk.cams.size() and _pizzeria.power < power0,
		"cam %d -> %d, power %.1f -> %.1f" % [cam0, desk.cam_index, power0, _pizzeria.power])
	_pizzeria.pappy.debug_frozen = false
	await _wait(0.3)
	_check("the first camera check wakes Pappy", _pizzeria.pappy.pstate != PappyPepperoni.PState.DORMANT, "state %d" % _pizzeria.pappy.pstate)
	_pizzeria.pappy.debug_frozen = true
	_place(_p("p_arrive"), PI)
	await _wait(0.4)
	_check("walking away unclips you", desk.occupant_peer == 0, "occupant %d" % desk.occupant_peer)


func _test_p_pappy() -> void:
	var pappy := _pizzeria.pappy
	var node := _pizzeria.node_position(0, 1)  # the Dining Hall
	pappy.debug_reset(0, 1)
	pappy.debug_frozen = false
	_place(node + Vector3(0.0, 0.1, 9.0), 0.0)  # 9 m away, looking at him (yaw 0 = toward -z)
	await _wait(1.0)
	_check("Pappy is pinned while someone looks at him", pappy.watched and pappy.pstate == PappyPepperoni.PState.ROAM, "watched %s, state %d" % [pappy.watched, pappy.pstate])
	pappy.debug_force_step()
	await _wait(0.5)
	_check("...and he doesn't move while watched, even on a full timer", pappy.node_index == 1 and pappy.steps_taken == 0, "node %d, steps %d" % [pappy.node_index, pappy.steps_taken])
	# A live camera on his node pins him too: clip into the desk with your back to him.
	pappy.debug_reset(0, 1)
	var desk := _pizzeria.desks[0]
	_place(_p("p_desk0"), PI * 0.5)  # facing -x: away from the dining hall
	await _wait(0.4)
	desk.cam_index = _pizzeria.node_cam(0, 1)
	await _wait(0.4)
	var cam_pins := pappy.watched and desk.occupant_peer == 1
	_place(node + Vector3(0.0, 0.1, 9.0), PI)  # back in the hall, back turned
	await _wait(0.4)
	_check("a camera showing his room pins him; looking away with no camera frees him", cam_pins and not pappy.watched, "camera %s, after %s" % [cam_pins, pappy.watched])
	pappy.debug_reset(0, 1)
	await _wait(0.2)
	var d0 := pappy.global_position.distance_to(_host.global_position)
	pappy.debug_force_step()
	await _wait(0.4)
	var d1 := pappy.global_position.distance_to(_host.global_position)
	_check("unwatched, his Step brings him closer (never seen moving)", pappy.steps_taken >= 1 and d1 < d0 - 2.0, "%.1f m -> %.1f m, steps %d" % [d0, d1, pappy.steps_taken])
	# The popper shoves him back a room; the air horn locks him up.
	_give("popper")
	await _press_use()
	await _wait(0.3)
	_check("party popper pushes him back toward his end of the floor", pappy.node_index == 0, "node %d (%s)" % [pappy.node_index, pappy.node_name()])
	pappy.debug_reset(0, 1)
	pappy.debug_force_step()
	await _wait(0.4)
	_give("airhorn")
	await _press_use()
	await _wait(0.2)
	_check("air horn stuns him", pappy.pstate == PappyPepperoni.PState.STUNNED, "state %d" % pappy.pstate)
	_host.server_drop_item(false)
	# Within reach and unwatched: lunge, grab, and (unrescued) a layoff.
	var wipes0 := GameState.wipes
	pappy.debug_reset(0, 1)
	_place(node + Vector3(0.0, 0.1, 4.0), PI)  # back turned, 4 m away
	await _wait(0.3)
	pappy.debug_force_step()
	var grabbed := false
	for i in 60:
		await _wait(0.1)
		if pappy.grab_peer == 1:
			grabbed = true
		if GameState.wipes > wipes0:
			break
	_check("unwatched and close: he lunges, grabs, and takes you (layoff)", grabbed and GameState.wipes > wipes0, "grabbed %s, wipes %d -> %d" % [grabbed, wipes0, GameState.wipes])
	await _wait(1.6)
	_check("the layoff resets Pappy and the power bank", pappy.pstate == PappyPepperoni.PState.ROAM and pappy.node_index == 0 and _pizzeria.power >= 99.0, "state %d, node %d, power %.0f" % [pappy.pstate, pappy.node_index, _pizzeria.power])
	# A rescue: a flashlight in his face while he holds someone.
	if _mate is Player:
		pappy.debug_reset(0, 1)
		_mate.teleport_to(node + Vector3(0.0, 0.1, 3.0), PI)
		_host.teleport_to(node + Vector3(0.0, 0.1, 7.0), PI)  # back turned too, so nobody pins him
		_give("flashlight")
		await _press_use()
		pappy.debug_force_step()
		var released := false
		for i in 40:
			await _wait(0.1)
			if pappy.grab_peer != 0:
				_host._apply_input(Vector2.ZERO, 0.0, 0.0, _seq << Player.JUMP_SEQ_SHIFT)
			if pappy.pstate == PappyPepperoni.PState.STUNNED:
				released = true
				break
		_check("a flashlight in his face makes him drop a teammate", released, "state %d" % pappy.pstate)
		_host.server_drop_item(false)
	pappy.debug_frozen = true


func _test_p_shutter() -> void:
	var sh := _pizzeria.shutters[0]
	var pappy := _pizzeria.pappy
	_place(_p("p_shutter0"), 0.0)
	_bot(Vector2.ZERO, 0.0, Player.FLAG_BRACE)
	await _wait(0.4)
	var held := sh.closed and sh.holders >= 1
	_bot(Vector2.ZERO, 0.0, 0)
	await _wait(0.4)
	_check("bracing at the pull chain rolls the shutter down; letting go rolls it up", held and not sh.closed, "held %s, after %s" % [held, sh.closed])
	# Pappy at a held shutter: three bangs, then back to his end of the floor.
	sh.debug_hold = true
	_place(_p("p_dumbwaiter") + Vector3(1.5, 0.0, 1.5), 0.0)  # past the shutter, in the dumbwaiter room
	pappy.debug_reset(0, 5)  # the hall outside it
	pappy.debug_frozen = false
	await _wait(0.3)
	pappy.debug_force_step()
	await _wait(0.5)
	var banging := pappy.pstate == PappyPepperoni.PState.BANGING
	await _wait(3.5)
	_check("a closed shutter stops him: three bangs, dented, then he goes home", banging and sh.dented and pappy.node_index == 0 and pappy.pstate == PappyPepperoni.PState.ROAM,
		"banging %s, dented %s, node %d, state %d" % [banging, sh.dented, pappy.node_index, pappy.pstate])
	# Let go while he's banging and he comes through at a run: visible, eyes or no eyes.
	var wipes_rush := GameState.wipes
	sh.debug_hold = true
	_place(_pizzeria.cell_center(0, 0, 1) + Vector3(0.0, 0.1, 1.0), PI)  # the storage room past the dumbwaiter, backs turned: nobody pins him
	pappy.debug_reset(0, 5)
	await _wait(0.3)
	pappy.debug_force_step()
	await _wait(0.5)
	var at_shutter := pappy.pstate == PappyPepperoni.PState.BANGING
	var p0 := pappy.global_position
	sh.debug_hold = false  # the holder let go
	var rushing := false
	var states := []
	for i in 22:
		await _wait(0.1)
		states.append(pappy.pstate)
		if pappy.pstate == PappyPepperoni.PState.RUSH:
			rushing = true
	var moved := p0.distance_to(pappy.global_position)
	# He rushes, and the rush ends in a lunge once he's close: either way he came through, walking.
	var aims := ""
	for p in Net.get_players():
		aims += " %s yaw %.2f d %.1f" % [p.display_name, p.input_yaw, p.global_position.distance_to(pappy.global_position)]
	_check("letting go of the shutter mid-bang makes him RUSH: he walks visibly toward you while watched", at_shutter and rushing and moved > 1.0 and pappy.is_hunting(), "banging %s, rush %s, moved %.2f m, states %s, watched %s, node %d,%s" % [at_shutter, rushing, moved, states, pappy.watched, pappy.node_index, aims])
	_place(_p("p_arrive"), PI)  # into Receiving, a Break Room: he won't come in
	await _wait(PappyPepperoni.RUSH_SECONDS + 1.5)
	_check("the rush ends on its own (he won't enter a Break Room) and he goes back to his timer", pappy.pstate == PappyPepperoni.PState.ROAM and GameState.wipes == wipes_rush, "state %d, wipes %d -> %d" % [pappy.pstate, wipes_rush, GameState.wipes])
	pappy.debug_reset(0, 0)
	pappy.debug_frozen = true


func _test_p_dumbwaiter() -> void:
	var dw := _pizzeria.dumbwaiter
	var top_y := _pizzeria.base_y() + Pizzeria.FLOOR_H
	if _mate is Player:
		_mate.teleport_to(_p("p_dumbwaiter") + Vector3(0.0, 0.3, 0.0), 0.0)
		_host.teleport_to(_p("p_rope0"), 0.0)
		_bot(Vector2.ZERO, 0.0, Player.FLAG_BRACE)
		await _wait(8.5)
		var rider_y := _mate.global_position.y
		_bot(Vector2.ZERO, 0.0, 0)
		await _wait(1.5)
		_check("dumbwaiter: a teammate hauling at the rope carries the rider up; let go and it sinks", rider_y > top_y - 0.6 and dw.position.y < top_y - 0.3,
			"rider y %.2f (kitchen %.1f), car y after %.2f" % [rider_y, top_y, dw.position.y])
	else:
		_host.teleport_to(_p("p_dumbwaiter") + Vector3(0.0, 0.3, 0.0), 0.0)
		if _mate != null:
			_mate.teleport_to(_p("p_dumbwaiter") + Vector3(0.0, 0.3, 2.0), 0.0)
		_bot(Vector2.ZERO, 0.0, Player.FLAG_BRACE)
		await _wait(8.5)
		_bot(Vector2.ZERO, 0.0, 0)
		_check("dumbwaiter solo: brace inside the car to haul yourself up to the Kitchen", _host.global_position.y > top_y - 0.6, "host y %.2f (kitchen %.1f)" % [_host.global_position.y, top_y])
	_place(_p("p_checkpoint5"), 0.0)
	await _wait(0.5)
	_check("Dry Storage checkpoint (2.2) recorded", GameState.checkpoint_index >= 5, "index %d" % GameState.checkpoint_index)


func _test_p_lift() -> void:
	var lift := _pizzeria.stage_lift
	var top_y := _pizzeria.base_y() + Pizzeria.FLOOR_H * 2.0
	var power0 := _pizzeria.power
	if _mate is Player:
		_mate.teleport_to(_p("p_lift") + Vector3(0.0, 0.4, 0.0), 0.0)
		_host.teleport_to(_p("p_lever"), 0.0)
		_bot(Vector2.ZERO, 0.0, Player.FLAG_BRACE)
		await _wait(10.5)
		var rider_y := _mate.global_position.y
		var moved := lift.position.y
		_bot(Vector2.ZERO, 0.0, 0)
		await _wait(2.0)
		_check("stage lift: holding the lever runs it up; it drinks power; letting go sinks it", rider_y > top_y - 0.6 and moved > top_y - 0.6 and lift.position.y < moved - 0.5 and _pizzeria.power < power0 - 4.0,
			"rider y %.2f (stage %.1f), lift %.2f -> %.2f, power %.0f -> %.0f" % [rider_y, top_y, moved, lift.position.y, power0, _pizzeria.power])
	else:
		_host.teleport_to(_p("p_lever"), 0.0)
		if _mate != null:
			_mate.teleport_to(_p("p_lever") + Vector3(0.0, 0.3, 1.0), 0.0)
		_bot(Vector2.ZERO, 0.0, Player.FLAG_BRACE)
		await _wait(0.5)
		_bot(Vector2.ZERO, 0.0, 0)
		_host.teleport_to(_p("p_lift") + Vector3(0.0, 0.4, 0.0), 0.0)
		await _wait(10.5)
		_check("stage lift solo: the lever locks, the lift carries you up, and it drinks power", _host.global_position.y > top_y - 0.6 and _pizzeria.power < power0 - 4.0,
			"host y %.2f (stage %.1f), power %.0f -> %.0f" % [_host.global_position.y, top_y, power0, _pizzeria.power])
	_place(_p("p_checkpoint6"), 0.0)
	await _wait(0.5)
	_check("Coat Check checkpoint (2.3) recorded", GameState.checkpoint_index >= 6, "index %d" % GameState.checkpoint_index)


func _test_p_power() -> void:
	var pappy := _pizzeria.pappy
	_place(_pizzeria.node_position(2, 2) + Vector3(0.0, 0.1, 0.0), 0.0)  # the Stage floor, out in the open
	pappy.debug_reset(2, 0)
	pappy.debug_frozen = false
	_pizzeria.power = 0.0
	await _wait(0.6)
	var p0 := pappy.global_position
	await _wait(1.0)
	var walked := p0.distance_to(pappy.global_position)
	_check("at 0% the power is out: blackout, and he walks the floor in the dark, eyes or no eyes", _pizzeria.blackout() and pappy.pstate == PappyPepperoni.PState.RUSH and walked > 1.0, "blackout %s, state %d, walked %.2f m" % [_pizzeria.blackout(), pappy.pstate, walked])
	pappy.debug_frozen = true
	pappy.debug_reset(2, 0)
	_place(_p("p_checkpoint6"), 0.0)
	await _wait(Pizzeria.GENERATOR_SECONDS + 0.8)
	_check("standing in a Break Room restarts the generator", _pizzeria.power >= 99.0, "power %.0f" % _pizzeria.power)


func _test_p_items() -> void:
	_check("Level 2 items are registered", ItemRegistry.get_data("popper") != null and ItemRegistry.get_data("airhorn") != null and ItemRegistry.get_data("ammo") != null, str(ItemRegistry.all_ids()))
	var n := 0
	for p in get_tree().get_nodes_in_group("pickups"):
		if (p as ItemPickup).global_position.y > _pizzeria.base_y() - 1.0:
			n += 1
	_check("pizzeria loot spawned on its floors", n >= 10, "%d pickups upstairs" % n)


func _test_p_scares() -> void:
	var before := ScareDirector.scares_played
	var kinds := ["jukebox_skip", "balloon", "vent_patter", "pepperoni_eyes", "bell", "static_face", "counter_bell", "order_window", "curtain", "costume_rack", "birthday_song"]
	for kind in kinds:
		ScareDirector.trigger_for(kind, _host)
		await _wait(0.15)
	await _wait(0.5)
	_check("every pizzeria scare type plays", ScareDirector.scares_played - before >= kinds.size(), "%d played" % (ScareDirector.scares_played - before))
	var pool: Array = _stack.scare_pool(_host.global_position)
	_check("the procedural pool follows the level you're on", pool == Pizzeria.SCARE_POOL and _stack.scare_pool(Vector3.ZERO) == YellowRooms.SCARE_POOL, "%d kinds upstairs" % pool.size())


## The Dining Hall has room: a slide away from your partner snaps the chain taut (a jerk) and
## drags them after you, exactly as a sprint would.
func _test_p_slide() -> void:
	var node := _pizzeria.node_position(0, 1)
	_pizzeria.pappy.debug_frozen = true
	_host.teleport_to(node + Vector3(0.0, 0.1, 7.0), 0.0)  # facing -z, 7 m of hall ahead
	if _mate != null:
		_mate.teleport_to(node + Vector3(0.0, 0.1, 9.4), 0.0)  # 2.4 m behind
	_bot(Vector2.ZERO, 0.0, 0)
	await _wait(0.5)
	var chain := _chain()
	var jerks0 := chain.jerks
	var mate_z0 := _mate.global_position.z if _mate != null else 0.0
	var z0 := _host.global_position.z
	_bot(Vector2(0.0, -1.0), 0.0, Player.FLAG_RUN)  # sprint toward -z
	await _wait(0.55)
	_bot(Vector2(0.0, -1.0), 0.0, Player.FLAG_RUN | Player.FLAG_BRACE)
	await _wait(0.1)
	var began := _host.is_sliding()
	_bot(Vector2.ZERO, 0.0, 0)
	await _wait(1.3)
	var travelled := z0 - _host.global_position.z
	var mate_dragged := mate_z0 - _mate.global_position.z if _mate != null else 99.0
	_check("Level 2: a slide carries you a few metres and yanks your partner along on the chain",
		began and travelled > 4.0 and chain.jerks > jerks0 and mate_dragged > 0.8,
		"began %s, travelled %.2f m, jerks %d -> %d, partner dragged %.2f m" % [began, travelled, jerks0, chain.jerks, mate_dragged])


func _test_p_exit() -> void:
	# The last climb: the case, then the loft, like the crates downstairs.
	_place(_p("p_cases"), PI)
	await _wait(0.5)
	var y0 := _host.global_position.y
	_bot(Vector2(0.0, -1.0), PI, 0, true)  # face -z into the case
	await _wait(0.5)
	_bot(Vector2.ZERO, PI, 0)
	await _wait(0.4)
	_check("mantle onto the speaker case", _host.global_position.y - y0 > 0.8, "rose %.2f m" % (_host.global_position.y - y0))
	_bot(Vector2(1.0, 0.0), -PI * 0.5, 0, true)  # +x onto the loft
	await _wait(0.5)
	_bot(Vector2.ZERO, -PI * 0.5, 0)
	await _wait(0.4)
	_check("...and from the case onto the prop loft", _host.global_position.y - y0 > 1.8, "rose %.2f m" % (_host.global_position.y - y0))
	_check("the Stage task list is up with the case and loft tasks ticked", GameState.tasks.size() == 3 and GameState.task_done(0) and GameState.task_done(1) and not GameState.task_done(2), str(GameState.tasks))
	var loft: Vector3 = _p("p_loft")
	# Only the players need to be up: the Ballast (solo) is hauled through the hatch after you.
	var players := Net.get_players()
	for i in players.size():
		players[i].teleport_to(loft + Vector3(-1.0 + 1.0 * float(i), 0.1, 0.0), 0.0)
	if _mate != null and not (_mate is Player):
		_mate.teleport_to(_p("p_stage"), 0.0)
	var lot := _stack.lot
	var crowd_asleep := not lot.horde.enabled
	for i in 70:
		await _wait(0.1)
		if GameState.checkpoint_index >= lot.checkpoint_index:
			break
	await _wait(0.6)
	var up := _host.global_position.y > lot.origin.y - 0.5
	_check("every player on the prop loft: the hatch opens and the Line climbs out onto the roof (checkpoint 7, the Lot's list, no escape yet)",
		GameState.checkpoint_index == lot.checkpoint_index and up and not GameState.escaped and GameState.tasks.size() == 6 and String(GameState.tasks[0][0]).begins_with("Get over"),
		"checkpoint %d, host y %.1f (roof %.1f), escaped %s, tasks %s" % [GameState.checkpoint_index, _host.global_position.y, lot.origin.y, GameState.escaped, str(GameState.tasks)])
	_check("the crowd slept until the Line reached the roof, and is awake now", crowd_asleep and lot.horde.enabled and not _pizzeria.anyone_here(), "asleep before %s, enabled now %s" % [crowd_asleep, lot.horde.enabled])
	await _test_roof()


## Level 3 on the roof: the Lot clears from inside the Stack exactly as it does on its own.
## Level 3 on the roof: the whole escape from inside the Stack, the same as the lot on its own.
func _test_roof() -> void:
	var lot := _stack.lot
	_check("the roof is its own level for names, scares and the sky", _stack.floor_name(_host.global_position.y) == HordeArena.FLOOR_NAME and _stack.level_index_at(_host.global_position) == 2 and _stack.scare_pool(_host.global_position) == HordeArena.SCARE_POOL and not _stack.is_safe_spot(_host.global_position), _stack.floor_name(_host.global_position.y))
	await _escape_by_helicopter(lot, _stack.test_points, "l_")


## The whole way out: fence, gap (wave two, the spiders), the last roof (every roof's wave), the
## helipad (the last wave, the bats, and its checkpoint), hold the pad, aboard.
func _escape_by_helicopter(lot: HordeArena, tp: Dictionary, prefix: String) -> void:
	lot.horde.debug_frozen = true
	for l in lot.launchers:
		l.debug_frozen = true
	await _wait(1.6)  # a layoff the swarm started a moment ago lands before we move anyone
	var bodies := Net.get_chain_bodies()
	for i in bodies.size():
		bodies[i].teleport_to(tp[prefix + "gap"] + Vector3(1.0 * float(i), 0.0, 0.0), 0.0)
	await _wait(1.2)
	var two_done := GameState.task_done(0) and GameState.task_done(1)
	var round2 := lot.rounds_spawned >= 2 and lot.horde.spawned_of(Horde.KIND_WEAVER) > 50
	var last_key := prefix + "roof%d" % HordeArena.ROOF_COUNT
	for i in bodies.size():
		bodies[i].teleport_to(tp[last_key] + Vector3(-1.0 + 1.0 * float(i), 0.0, -2.0), 0.0)
	await _wait(1.2)
	var crossed := lot.furthest_roof == HordeArena.ROOF_COUNT and GameState.task_done(HordeArena.TASK_ROOFS) and lot.rounds_spawned >= HordeArena.ROOF_COUNT + 2
	var roof_text := String(GameState.tasks[HordeArena.TASK_ROOFS][0])
	_check("the last roof: the count on the task reaches %d of %d and every roof's wave is in" % [HordeArena.ROOF_COUNT, HordeArena.ROOF_COUNT], crossed and roof_text.contains("%d of %d" % [HordeArena.ROOF_COUNT, HordeArena.ROOF_COUNT]),
		"furthest %d, task '%s', waves %d of %d" % [lot.furthest_roof, roof_text, lot.rounds_spawned, lot.wave_count()])
	for i in bodies.size():
		bodies[i].teleport_to(tp[prefix + "helipad"] + Vector3(-4.0 + 1.0 * float(i), 0.0, 4.0), 0.0)
	await _wait(1.2)
	var climbed := GameState.task_done(HordeArena.TASK_ESCAPE)
	var round3 := lot.rounds_spawned >= lot.wave_count() and lot.horde.alive_of(Horde.KIND_FLITTER) > 50
	var cp_ok := GameState.checkpoint_index == lot.helipad_checkpoint_index()
	_check("the gap brings wave two (spiders), the helipad the last wave (bats) and the helipad checkpoint", two_done and round2 and climbed and round3 and cp_ok,
		"tasks %s, waves %d, weavers %d, flitters %d, checkpoint %d (want %d)" % [str(GameState.tasks), lot.rounds_spawned, lot.horde.alive_of(Horde.KIND_WEAVER), lot.horde.alive_of(Horde.KIND_FLITTER), GameState.checkpoint_index, lot.helipad_checkpoint_index()])
	# Hold the pad: the pilot spins up while someone stands there (sped up for the test).
	await _wait(1.0)
	var spinning := lot.heli_fraction > 0.0 and not GameState.task_done(HordeArena.TASK_PAD)
	lot.debug_pad_ready()
	await _wait(0.8)
	var ready := GameState.task_done(HordeArena.TASK_PAD) and lot.heli_fraction >= 1.0
	var heli: Vector3 = lot.heli_position()
	for i in bodies.size():
		bodies[i].teleport_to(heli + Vector3(-1.5 + 1.0 * float(i), 0.1, 2.0), 0.0)
	for i in 30:
		await _wait(0.1)
		if GameState.escaped:
			break
	_check("holding the pad spins the pilot up, and everyone aboard is ESCAPED to Level 4", spinning and ready and GameState.escaped and GameState.escape_line.begins_with("Airlifted"),
		"spinning %s, ready %s, escaped %s, line '%s'" % [spinning, ready, GameState.escaped, GameState.escape_line])
	await _wait(2.0)


## Playable end to end: the bot crosses every link of the route the way a player would (a run
## and a jump for a gap, a walk for a plank, a duct or a drop, a walk with Space taps for a
## climb), with the partner on the chain behind, and must land on each next roof without a layoff.
func _test_route() -> void:
	var arena := _arena
	_horde.debug_frozen = true
	for l in arena.launchers:
		l.debug_frozen = true
	var failed := ""
	var wipes0 := GameState.wipes
	for i in range(1, arena.roofs.size() - 1):
		var r: HordeArena.Roof = arena.roofs[i]
		var prev: HordeArena.Roof = arena.roofs[i - 1]
		var edge_z := arena.origin.z + prev.rect.position.y
		var start := arena.origin + Vector3(r.cross_x, prev.y + 0.1, prev.rect.position.y + 5.0)
		_host.teleport_to(start, 0.0)
		if _mate != null:
			_mate.teleport_to(start + Vector3(0.0, 0.0, 2.2), 0.0)
		_bot(Vector2.ZERO, 0.0, 0)
		await _wait(0.4)
		var run := r.link == HordeArena.Link.JUMP
		var flags := Player.FLAG_RUN if run else 0
		var jumped := false
		var mate_jumped := false
		var landed := false
		var mate_p := _mate as Player
		var mate_landed := mate_p == null
		for k in 120:
			await _wait(0.05)
			var z := _host.global_position.z
			var tap := false
			if run and not jumped and z < edge_z + 0.8:
				tap = true
				jumped = true
			elif r.link == HordeArena.Link.CLIMB and k % 6 == 0:
				tap = true  # Space into the unit, then the roof
			var floor_ok := z < arena.origin.z + r.rect.end.y - 4.0  # well clear of the edge: the teammate is coming over behind
			if not landed and arena.roof_at(_host.global_position) == i and _host.is_on_floor() and floor_ok:
				landed = true
			_bot(Vector2.ZERO if landed else Vector2(0.0, -1.0), 0.0, 0 if landed else flags, tap and not landed)
			# A teammate (co-op) crosses the same way, jumping at their own edge.
			if mate_p != null:
				var mz := mate_p.global_position.z
				var mtap := false
				if run and not mate_jumped and mz < edge_z + 0.8:
					mtap = true
					mate_jumped = true
				elif r.link == HordeArena.Link.CLIMB and k % 6 == 3:
					mtap = true
				if not mate_landed and arena.roof_at(mate_p.global_position) == i and mate_p.is_on_floor() and mz < arena.origin.z + r.rect.end.y - 1.0:
					mate_landed = true
				_drive_mate(Vector2.ZERO if mate_landed else Vector2(0.0, -1.0), 0 if mate_landed else flags, mtap and not mate_landed)
			if landed and mate_landed:
				break
		_bot(Vector2.ZERO, 0.0, 0)
		_drive_mate(Vector2.ZERO, 0, false)
		await _wait(0.6)
		if not landed or arena.roof_at(_host.global_position) != i or not mate_landed:
			failed += "roof %d (%s) not reached: host at %s on roof %d, mate landed %s; " % [i, HordeArena.LINK_NAMES[r.link], _host.global_position, arena.roof_at(_host.global_position), mate_landed]
	_check("every link of the route can be crossed by running, jumping, walking and climbing, with the partner on the chain (no layoffs)", failed == "" and GameState.wipes == wipes0, failed + "wipes %d -> %d" % [wipes0, GameState.wipes])
	# And the fire escape: landing by landing up the tower to the helipad, the way a player does it
	# (walk into the side of the next landing and tap Space; off the last one onto the pad).
	var steps: Array[Vector3] = arena.escape_steps
	var foot: Vector3 = arena.test_points["escape_foot"]
	var tower: HordeArena.Roof = arena.roofs[arena.roofs.size() - 1]
	_host.teleport_to(foot + Vector3(0.0, 0.0, 2.0), 0.0)
	if _mate != null:
		_mate.teleport_to(foot + Vector3(0.0, 0.0, 4.0), 0.0)
	await _wait(0.4)
	var highest := 0
	var on_pad := false
	var on := -1  # the landing the bot is standing on (-1: the roof at the foot)
	var pad: Vector3 = arena.test_points["helipad"]
	for k in 240:
		await _wait(0.05)
		var lp := _host.global_position - arena.origin
		if _host.is_on_floor():
			on = -1
			for s in steps.size():
				if absf(lp.y - steps[s].y) < 0.3 and absf(lp.x - steps[s].x) < 1.6 and absf(lp.z - steps[s].z) < 1.2:
					on = s
		highest = maxi(highest, on + 1)
		# Steer at the next landing (or the pad from the last one) and tap Space as you meet it.
		var target: Vector3 = (pad - arena.origin) if on >= steps.size() - 1 else steps[on + 1]
		var to := Vector2(target.x - lp.x, target.z - lp.z)
		var move := to.normalized() if to.length() > 0.2 else Vector2.ZERO
		_bot(move, 0.0, 0, k % 6 == 0)
		if _mate is Player:
			# The teammate follows up the landings behind you.
			var mt := Vector2(_host.global_position.x - _mate.global_position.x, _host.global_position.z - _mate.global_position.z)
			_drive_mate(mt.normalized() if mt.length() > 1.4 else Vector2.ZERO, 0, k % 6 == 3)
		if arena.roof_at(_host.global_position) == arena.roofs.size() - 1 and _host.global_position.z < arena.origin.z + tower.rect.end.y - 1.5:
			on_pad = true
			break
	_drive_mate(Vector2.ZERO, 0, false)
	_bot(Vector2.ZERO, 0.0, 0)
	await _wait(0.5)
	_check("the fire escape climbs, landing by landing, onto the helipad (the partner hauled up on the chain)", on_pad, "host at %s (pad at %s), reached landing %d of %d" % [_host.global_position, arena.test_points["helipad"], highest, steps.size()])


## The district: eleven roofs laid out from the seed with jumpable links, the field knowing
## roof from street, a run-and-jump across the first gap, a Weaver swinging a gap and climbing
## the tower, and a Jumper crossing to the roof you're on.
func _test_district() -> void:
	var arena := _arena
	_horde.debug_frozen = true  # the tick-budget check before this one leaves a crowd on the Line
	for l in _arena.launchers:
		l.debug_frozen = true
	await _wait(1.8)  # and any layoff it started lands now, not mid-test
	var links_ok := true
	var why := ""
	for i in range(1, arena.roofs.size()):
		var r: HordeArena.Roof = arena.roofs[i]
		var prev: HordeArena.Roof = arena.roofs[i - 1]
		var dy := r.y - prev.y
		var inside := r.cross_x > prev.rect.position.x + 2.0 and r.cross_x < prev.rect.end.x - 2.0 and r.cross_x > r.rect.position.x + 2.0 and r.cross_x < r.rect.end.x - 2.0
		var ok := inside and r.y >= 0.0
		if i < arena.roofs.size() - 1:
			for v in r.vents:
				if absf(v.x - r.enter.x) < 1.4 or absf(v.x - r.exit.x) < 1.4:
					ok = false
					why += "roof %d has a vent in a crossing lane; " % i
		match r.link:
			HordeArena.Link.JUMP:
				ok = ok and r.gap >= 2.3 and r.gap <= 3.5 and dy <= 0.6 and dy >= -2.5
			HordeArena.Link.PLANK, HordeArena.Link.PIPE:
				ok = ok and r.gap >= 3.9 and r.gap <= 6.6 and absf(dy) < 0.01
			HordeArena.Link.DROP:
				ok = ok and r.gap >= 1.3 and r.gap <= 2.5 and dy <= -3.3
			HordeArena.Link.CLIMB:
				ok = ok and r.gap == 0.0 and dy >= 2.5 and dy <= (HordeArena.TOWER_RISE + 0.01 if i == arena.roofs.size() - 1 else 3.6)
		if not ok:
			links_ok = false
			why += "roof %d link %d gap %.1f dy %.1f inside %s; " % [i, r.link, r.gap, dy, inside]
	_check("eleven roofs and the tower, every link within reach (jump 2.3-3.5 m, plank 4-6.5 m level, drop a storey, climb two mantles), the crossing inside both roofs and clear of vents, nothing below the lot", links_ok and arena.roofs.size() == HordeArena.ROOF_COUNT + 2, why)
	var f := arena.field
	var r1: HordeArena.Roof = arena.roofs[1]
	var mid := arena.origin + Vector3(r1.cross_x, 0.0, r1.rect.end.y + r1.gap * 0.5)
	var enter := arena.origin + r1.enter
	_check("the field knows the street between roofs from the roofs, and each roof's height", f.is_void(mid.x, mid.z) and not f.is_void(enter.x, enter.z) and absf(f.height_at(enter.x, enter.z) - (arena.origin.y + r1.y)) < 0.01 and f.height_at(mid.x, mid.z) < arena.origin.y - 30.0,
		"void at gap %s, void at roof %s, height %.1f (want %.1f)" % [f.is_void(mid.x, mid.z), f.is_void(enter.x, enter.z), f.height_at(enter.x, enter.z), arena.origin.y + r1.y])
	await _wait(1.6)  # a layoff the swarm started a moment ago lands before we move anyone
	# Run and jump the first gap, from the lot's edge. The partner runs behind (co-op: and jumps
	# at the edge too; solo: the Ballast comes over on the chain).
	_horde.debug_frozen = true
	var edge: Vector3 = arena.test_points["lot_edge"]
	_host.teleport_to(edge + Vector3(0.0, 0.0, 6.0), 0.0)
	if _mate != null:
		_mate.teleport_to(edge + Vector3(1.0, 0.0, 8.5), 0.0)
	_bot(Vector2.ZERO, 0.0, 0)
	await _wait(0.4)
	var wipes0 := GameState.wipes
	var jumped := false
	var mate_jumped := false
	var host_stop := false
	var mate_stop := false
	for i in 70:
		await _wait(0.05)
		var tap := not jumped and _host.global_position.z < edge.z + 0.9
		jumped = jumped or tap
		if jumped and _host.is_on_floor() and arena.roof_at(_host.global_position) == 1 and _host.global_position.z < arena.origin.z + r1.rect.end.y - 1.0:
			host_stop = true
		_bot(Vector2.ZERO if host_stop else Vector2(0.0, -1.0), 0.0, 0 if host_stop else Player.FLAG_RUN, tap)
		if _mate is Player:
			var mtap := not mate_jumped and _mate.global_position.z < edge.z + 0.9
			mate_jumped = mate_jumped or mtap
			if mate_jumped and _mate.is_on_floor() and arena.roof_at(_mate.global_position) == 1:
				mate_stop = true
			_drive_mate(Vector2.ZERO if mate_stop else Vector2(0.0, -1.0), 0 if mate_stop else Player.FLAG_RUN, mtap)
		if host_stop and (mate_stop or not (_mate is Player)) and i > 30:
			break
	_bot(Vector2.ZERO, 0.0, 0)
	_drive_mate(Vector2.ZERO, 0, false)
	await _wait(0.6)
	var landed := arena.roof_at(_host.global_position)
	_check("a run and a jump off the lot's edge lands on the first roof, and the chain brings the partner (no layoff)", landed == 1 and GameState.wipes == wipes0 and arena.furthest_roof >= 1,
		"on roof %d at %s (roof 1 enters at %s), wipes %d -> %d, furthest %d" % [landed, _host.global_position, enter, wipes0, GameState.wipes, arena.furthest_roof])
	# A Weaver on the roof behind you swings the gap on a thread.
	arena.debug_spawn_all_rounds()
	var r2: HordeArena.Roof = arena.roofs[2]
	var stand := arena.origin + r2.enter
	_host.teleport_to(stand, 0.0)
	if _mate != null:
		_mate.teleport_to(stand + Vector3(1.5, 0.0, -2.0), 0.0)
	var weaver := -1
	for i in _horde.count:
		if _horde.kind[i] == Horde.KIND_WEAVER and _horde.state[i] == Horde.AState.WALK:
			weaver = i
			break
	_horde.place(weaver, arena.origin + r1.exit + Vector3(0.0, 0.0, 1.0))
	await _wait(0.6)
	_horde.debug_frozen = false
	var swung := false
	var arrived := false
	for i in 60:
		await _wait(0.1)
		if _horde.state[weaver] == Horde.AState.SWING:
			swung = true
		if swung and _horde.state[weaver] == Horde.AState.WALK and arena.roof_at(_horde.agent_position(weaver)) == 2:
			arrived = true
			break
	_check("a Weaver at the edge of the roof behind you swings the gap on a thread and lands on yours", swung and arrived, "swung %s, arrived %s, state %d, at %s" % [swung, arrived, _horde.state[weaver], _horde.agent_position(weaver)])
	# ...and climbs the tower's face to the helipad.
	_horde.debug_frozen = true
	var tower: HordeArena.Roof = arena.roofs[arena.roofs.size() - 1]
	var last: HordeArena.Roof = arena.roofs[arena.roofs.size() - 2]
	var pad: Vector3 = arena.test_points["helipad"]
	_host.teleport_to(pad + Vector3(0.0, 0.0, 3.0), 0.0)
	if _mate != null:
		_mate.teleport_to(pad + Vector3(1.5, 0.0, 1.0), 0.0)
	_horde.place(weaver, arena.origin + Vector3(tower.rect.get_center().x + 4.0, last.y, tower.rect.end.y + 1.5))
	await _wait(0.6)
	_horde.debug_frozen = false
	var climbed := false
	var up := false
	for i in 80:
		await _wait(0.1)
		if _horde.state[weaver] == Horde.AState.CLIMB:
			climbed = true
		if climbed and _horde.state[weaver] != Horde.AState.CLIMB and _horde.py[weaver] > pad.y - 0.5:
			up = true
			break
	_check("a Weaver below the helipad climbs the tower's face up to it", climbed and up, "climbed %s, up %s, state %d, y %.1f (pad %.1f)" % [climbed, up, _horde.state[weaver], _horde.py[weaver], pad.y])
	_horde.debug_frozen = true
	# The Jumper on the third roof crosses to you on the fourth (a thread, or up the wall).
	var jumper: Launcher = arena.launchers[4]
	var r3: HordeArena.Roof = arena.roofs[3]
	var r4: HordeArena.Roof = arena.roofs[4]
	var there := arena.origin + r4.enter
	_host.teleport_to(there + Vector3(0.0, 0.0, -minf(8.0, r4.rect.size.y - 3.0)), 0.0)  # out of lunge range: it has to cross first
	if _mate != null:
		_mate.teleport_to(_host.global_position + Vector3(1.5, 0.0, -1.0), 0.0)
	_bot(Vector2.ZERO, 0.0, 0)
	await _wait(0.3)
	jumper.debug_reset(arena.origin + r3.exit + Vector3(0.0, 0.0, 2.0))
	jumper.debug_frozen = false
	var crossed := false
	var how := ""
	for i in 100:
		await _wait(0.1)
		if jumper.lstate == Launcher.LState.SWING:
			how = "swing"
		elif jumper.lstate == Launcher.LState.LUNGE and how == "":
			how = "jump"
		elif jumper.lstate == Launcher.LState.CLIMB and how == "":
			how = "climb"
		if how != "" and arena.roof_at(jumper.global_position) == 4:
			crossed = true
			break
	jumper.debug_frozen = true
	_check("the Jumper on the roof behind crosses to yours (link: %s)" % HordeArena.LINK_NAMES[r4.link], crossed and how != "", "crossed %s by %s, state %d, at roof %d" % [crossed, how, jumper.lstate, arena.roof_at(jumper.global_position)])
	jumper.debug_reset(arena.launcher_homes[4])
	jumper.release(false)
	await _wait(0.5)


# --- The Loading Lot (--arena): the Level 3 tech ------------------------------------------------------

var _arena: HordeArena
var _horde: Horde


func _run_arena(arena: HordeArena) -> void:
	_arena = arena
	_horde = arena.horde
	_host.bot_controlled = true
	await _wait(0.6)
	var bodies := Net.get_chain_bodies()
	_mate = bodies[1] if bodies.size() > 1 else null
	_check("arena built: field, the first wave of the swarm, the Jumpers, the route, loot", _horde.count >= 350 and _horde.count < arena.horde_count and arena.launchers.size() >= 4 and arena.field.cell_count() > 9000 and arena.roofs.size() == HordeArena.ROOF_COUNT + 2 and get_tree().get_nodes_in_group("pickups").size() >= 10,
		"agents %d, launchers %d, cells %d, pickups %d" % [_horde.count, arena.launchers.size(), arena.field.cell_count(), get_tree().get_nodes_in_group("pickups").size()])
	var chain := _chain()
	_check("chain links every body", chain != null and chain.segments.size() == bodies.size() - 1, "%d segments" % (chain.segments.size() if chain != null else -1))
	for l in arena.launchers:
		l.debug_frozen = true
	if only != "":
		await call("_test_" + only)
		_finish()
		return
	await _test_horde_field()
	await _test_horde()
	await _test_launcher()
	await _test_horde_perf()
	await _test_district()
	await _test_route()
	await _test_lot_clear()
	_finish()


## Clearing the lot: the three tasks done, then everyone back on the pad clocks out.
func _test_lot_clear() -> void:
	await _escape_by_helicopter(_arena, _arena.test_points, "")


func _test_horde_field() -> void:
	var f := _arena.field
	await _wait(1.0)
	var dir := f.direction_at(0.0, -20.0)
	_check("the flow field builds in slices and points the north half toward the Line", f.builds >= 1 and dir.length() > 0.9 and dir.y > 0.3, "builds %d, dir at (0,-20) = %s, cost %d" % [f.builds, dir, f.cost_at(0.0, -20.0)])
	_check("walls, the fence and the dumpster are blocked; the fence gap and the lot are open", f.is_blocked(0.0, 18.0) and f.is_blocked(-20.0, 0.0) and f.is_blocked(-8.0, 19.6) and not f.is_blocked(40.0, 18.0) and not f.is_blocked(0.0, 0.0) and not f.is_blocked(0.0, -20.0), "")
	var z_before := _mean_z()
	await _wait(5.0)
	var z_after := _mean_z()
	_check("the mass moves on the field toward the players", z_after - z_before > 3.0, "mean z %.1f -> %.1f over 5 s" % [z_before, z_after])


func _mean_z() -> float:
	var sum := 0.0
	var n := 0
	for i in _horde.count:
		if _horde.state[i] == Horde.AState.WALK:
			sum += _horde.pz[i]
			n += 1
	return sum / maxf(1.0, float(n))


func _test_horde() -> void:
	var spawn: Vector3 = _arena.test_points["spawn"]
	_horde.debug_frozen = true
	# Three on the chain stop the team.
	_host.teleport_to(spawn, 0.0)
	if _mate != null:
		_mate.teleport_to(spawn + Vector3(0.0, 0.0, 3.0), 0.0)  # 3 m behind: the chain runs along z
	_bot(Vector2.ZERO, 0.0, 0)
	await _wait(0.5)
	var placed: Array[int] = [0, 1, 2]  # three from the back of the crowd
	for k in 3:
		_horde.place(placed[k], spawn + Vector3(-0.4 + 0.4 * float(k), 0.0, 1.5))  # on the segment
	_horde.debug_frozen = false
	for w in 20:  # they take hold within a tick or two of being picked active; a loaded machine is slower
		await _wait(0.1)
		if _horde.grabs >= 3 and w >= 7:
			break
	var holders := _horde.grabs
	var z0 := _host.global_position.z
	_bot(Vector2(0.0, -1.0), 0.0, Player.FLAG_RUN)  # try to sprint away
	await _wait(1.0)
	var moved := z0 - _host.global_position.z
	_check("three on the chain: they hang on and the team is stopped, sprint or not", holders >= 3 and moved < 0.9, "holders %d, moved %.2f m in 1 s of sprinting" % [holders, moved])
	# The air horn shakes them off; then the team moves (the partner steps ahead and aside so
	# the chain itself doesn't stop the sprint).
	_bot(Vector2.ZERO, 0.0, 0)
	_give("airhorn")
	await _press_use()
	await _wait(0.3)
	var after_horn := _horde.grabs
	if _mate != null:
		_mate.teleport_to(spawn + Vector3(2.0, 0.0, -3.0), 0.0)
	z0 = _host.global_position.z
	_bot(Vector2(0.0, -1.0), 0.0, Player.FLAG_RUN)
	await _wait(1.0)
	var moved2 := z0 - _host.global_position.z
	_bot(Vector2.ZERO, 0.0, 0)
	_check("the air horn knocks them off the chain and the team can run again", after_horn == 0 and moved2 > 3.0, "holders %d, moved %.2f m" % [after_horn, moved2])
	_host.server_drop_item(false)
	# One holder: a sprint flicks it off on its own.
	_horde.debug_frozen = true
	_host.teleport_to(spawn, 0.0)
	if _mate != null:
		_mate.teleport_to(spawn + Vector3(0.0, 0.0, 3.0), 0.0)
	await _wait(0.4)
	for k in 3:
		_horde.place(placed[k], spawn + Vector3(30.0 + float(k), 0.0, -30.0))
	_horde.place(placed[0], spawn + Vector3(0.0, 0.0, 1.5))
	_horde.debug_frozen = false
	await _wait(0.8)
	var one := _horde.grabs
	_bot(Vector2(0.0, -1.0), 0.0, Player.FLAG_RUN)
	await _wait(1.6)
	_bot(Vector2.ZERO, 0.0, 0)
	_check("one on the chain: sprinting flicks it off", one == 1 and _horde.grabs == 0 and _horde.state[placed[0]] != Horde.AState.GRAB, "holders %d -> %d, state %d" % [one, _horde.grabs, _horde.state[placed[0]]])
	# A Snubby round drops one (no physics: the horde tests the ray itself).
	_horde.debug_frozen = true
	_host.teleport_to(spawn, 0.0)
	if _mate != null:
		_mate.teleport_to(spawn + Vector3(1.5, 0.0, 1.0), 0.0)
	await _wait(0.3)
	var target := placed[1]
	_horde.place(target, spawn + Vector3(0.0, 0.0, -2.5))  # the nearest thing in the lane
	await _wait(0.6)  # the active pick runs twice a second
	_horde.debug_frozen = false
	_give("pistol")
	var dead0 := _horde.dead
	var aim: Vector3 = _horde.agent_position(target) + Vector3(0.0, 0.4, 0.0) - _host.eye_position()  # a roach is knee-high: aim down at it
	var aim_yaw := atan2(-aim.x, -aim.z)
	var aim_pitch := atan2(aim.y, Vector2(aim.x, aim.z).length())
	_host._apply_input(Vector2.ZERO, aim_yaw, aim_pitch, Player.FLAG_USE | (_seq << Player.JUMP_SEQ_SHIFT))
	await _wait(0.1)
	_host._apply_input(Vector2.ZERO, aim_yaw, aim_pitch, _seq << Player.JUMP_SEQ_SHIFT)
	await _wait(0.2)
	_check("a Snubby round drops the roach it's aimed at", _horde.dead == dead0 + 1 and _horde.state[target] == Horde.AState.DEAD and _horde.active[target] == 0, "dead %d -> %d, state %d, active %d, d2 %.1f" % [dead0, _horde.dead, _horde.state[target], _horde.active[target], _horde._d2[target]])
	_host.server_drop_item(false)
	# A bomb clears a circle.
	_horde.debug_frozen = true
	for k in 6:
		_horde.place(10 + k, spawn + Vector3(cos(float(k)) * 1.5, 0.0, -6.0 + sin(float(k)) * 1.5))
	var dead1 := _horde.dead
	_horde.blast(spawn + Vector3(0.0, 0.0, -6.0), Thrown.BLAST_RADIUS)
	_check("a blast kills everything in its radius", _horde.dead >= dead1 + 6, "dead %d -> %d" % [dead1, _horde.dead])
	# Three sets of claws on one player for a few seconds: pulled down (a layoff).
	_horde.debug_frozen = true
	_host.teleport_to(spawn, 0.0)
	if _mate != null:
		_mate.teleport_to(spawn + Vector3(0.0, 0.0, 3.0), 0.0)
	await _wait(0.3)
	for k in 4:
		_horde.place(20 + k, spawn + Vector3(cos(float(k) * 1.57) * 0.6, 0.0, sin(float(k) * 1.57) * 0.6))
	await _wait(0.6)
	_horde.debug_frozen = false
	var wipes0 := GameState.wipes
	for i in 60:
		await _wait(0.1)
		if GameState.wipes > wipes0:
			break
	_check("a crowd on one player pulls them down: a layoff, and the respawn is clear of them", GameState.wipes > wipes0, "wipes %d -> %d, mauls %d" % [wipes0, GameState.wipes, _horde.mauls])
	await _wait(1.6)
	var near := 0
	for i in _horde.count:
		if _horde.state[i] == Horde.AState.WALK and Vector2(_horde.px[i] - spawn.x, _horde.pz[i] - spawn.z).length() < 15.0:
			near += 1
	_check("...and the respawn pad is clear of them", near == 0, "%d within 15 m" % near)
	_horde.debug_frozen = true
	# The Flitters: they fly, they dive at you, and they never hang on the chain.
	_arena.debug_spawn_all_rounds()
	var bat := -1
	for i in _horde.count:
		if _horde.kind[i] == Horde.KIND_FLITTER and _horde.state[i] == Horde.AState.WALK:
			bat = i
			break
	_host.teleport_to(spawn, 0.0)
	if _mate != null:
		_mate.teleport_to(spawn + Vector3(0.0, 0.0, 3.0), 0.0)
	await _wait(0.3)
	_horde.place(bat, spawn + Vector3(0.0, 0.0, 1.5))  # right on the chain, where a roach would grab
	_horde.py[bat] = spawn.y + Horde.FLY_HEIGHT
	await _wait(0.6)
	_horde.debug_frozen = false
	var dived := false
	var high := 0.0
	for i in 40:
		await _wait(0.1)
		high = maxf(high, _horde.py[bat] - spawn.y)
		if _horde.state[bat] == Horde.AState.LUNGE:
			dived = true
	_check("a Flitter circles overhead, dives at you, and never takes the chain", high > 2.5 and dived and _horde.state[bat] != Horde.AState.GRAB and _horde.grab_a[bat] < 0, "height %.1f, dived %s, state %d" % [high, dived, _horde.state[bat]])
	_horde.debug_frozen = true


func _test_launcher() -> void:
	var spawn: Vector3 = _arena.test_points["spawn"]
	_horde.debug_frozen = true
	var l := _arena.launchers[0]
	# Stand still in its line: screech, crouch, jump, pinned, and (nobody helping) a layoff.
	_host.teleport_to(spawn, 0.0)
	if _mate != null:
		_mate.teleport_to(spawn + Vector3(8.0, 0.0, 6.0), 0.0)  # well out of rescue range
	_bot(Vector2.ZERO, 0.0, 0)
	await _wait(0.3)
	l.debug_reset(spawn + Vector3(0.0, 0.0, -5.0))
	l.debug_frozen = false
	var saw_windup := false
	var saw_lunge := false
	var grabbed := false
	var wipes0 := GameState.wipes
	for i in 80:
		await _wait(0.1)
		if l.lstate == Launcher.LState.WINDUP:
			saw_windup = true
		if l.lstate == Launcher.LState.LUNGE:
			saw_lunge = true
		if l.grab_peer == 1:
			grabbed = true
		if GameState.wipes > wipes0:
			break
	_check("Launcher: screech and crouch, then a jump that pins whoever stood in the line; unrescued, a layoff", saw_windup and saw_lunge and grabbed and GameState.wipes > wipes0,
		"windup %s, lunge %s, grabbed %s, wipes %d -> %d, state %d" % [saw_windup, saw_lunge, grabbed, wipes0, GameState.wipes, l.lstate])
	await _wait(1.6)
	l.debug_frozen = true
	# Sprint out of the line while it's crouched and it lands on nothing. The partner waits off
	# to the side the host runs toward, so the chain doesn't drag them through the landing.
	_host.teleport_to(spawn, 0.0)
	if _mate != null:
		_mate.teleport_to(spawn + Vector3(3.0, 0.0, 2.0), 0.0)
	_bot(Vector2.ZERO, 0.0, 0)
	await _wait(0.3)
	l.debug_reset(spawn + Vector3(0.0, 0.0, -5.0))
	var lunges0 := l.lunges
	l.debug_frozen = false
	for i in 20:
		await _wait(0.05)
		if l.lstate == Launcher.LState.WINDUP:
			break
	_bot(Vector2(1.0, 0.0), 0.0, Player.FLAG_RUN)  # sprint sideways, out of the line
	await _wait(1.4)
	_bot(Vector2.ZERO, 0.0, 0)
	l.debug_frozen = true
	_check("sprinting out of the line dodges the jump", l.lunges > lunges0 and not _host.is_grabbed() and l.grab_peer == 0, "lunges %d -> %d, grabbed %s, state %d" % [lunges0, l.lunges, _host.is_grabbed(), l.lstate])
	await _wait(0.5)
	# A teammate (or the Ballast) right beside the victim gets it off them.
	_host.teleport_to(spawn, 0.0)
	await _wait(0.3)
	l.debug_reset(spawn + Vector3(0.0, 0.0, -1.5))
	l.call("_start_grab", _host)
	if _mate != null:
		_mate.teleport_to(spawn + Vector3(1.2, 0.0, 0.0), 0.0)
		if _mate is Player:
			(_mate as Player)._apply_input(Vector2.ZERO, 0.0, 0.0, Player.FLAG_BRACE)
	var wipes1 := GameState.wipes
	var freed := false
	for i in 45:
		await _wait(0.1)
		if not _host.is_grabbed():
			freed = true
			break
	_check("someone braced beside the victim pulls it off before the layoff", freed and GameState.wipes == wipes1, "freed %s, wipes %d -> %d, state %d" % [freed, wipes1, GameState.wipes, l.lstate])
	if _mate is Player:
		(_mate as Player)._apply_input(Vector2.ZERO, 0.0, 0.0, 0)
	await _wait(0.5)
	# Three Snubby hits kill it (its hitbox is physics, like the Hires').
	l.debug_reset(spawn + Vector3(0.0, 0.0, -6.0))
	l.debug_frozen = true
	_host.teleport_to(spawn, 0.0)
	if _mate != null:
		_mate.teleport_to(spawn + Vector3(1.5, 0.0, 1.5), 0.0)
	await _wait(0.3)
	_give("pistol")
	for k in 3:
		var to: Vector3 = l.chest_point() - _host.eye_position()
		var yaw := atan2(-to.x, -to.z)
		var pitch := atan2(to.y, Vector2(to.x, to.z).length())
		_host._apply_input(Vector2.ZERO, yaw, pitch, Player.FLAG_USE | (_seq << Player.JUMP_SEQ_SHIFT))
		await _wait(0.1)
		_host._apply_input(Vector2.ZERO, yaw, pitch, _seq << Player.JUMP_SEQ_SHIFT)
		await _wait(0.35)
	_check("three Snubby hits drop a Launcher", l.is_dead() and l.hits >= 3, "hits %d, state %d" % [l.hits, l.lstate])
	_host.server_drop_item(false)
	var l2 := _arena.launchers[1]
	l2.debug_reset(spawn + Vector3(0.0, 0.0, -4.0))
	l2.blast()
	_check("a bomb kills one outright", l2.is_dead(), "state %d" % l2.lstate)
	await _wait(0.6)


## The budget: a thousand agents, all walking, with the active set in full, in well under a frame.
func _test_horde_perf() -> void:
	_arena.debug_spawn_all_rounds()
	_horde.debug_frozen = false
	for l in _arena.launchers:
		l.debug_frozen = true
	_host.teleport_to(_arena.test_points["north"], 0.0)
	if _mate != null:
		_mate.teleport_to(_arena.test_points["north"] + Vector3(1.5, 0.0, 1.0), 0.0)
	await _wait(2.5)
	var samples: Array[float] = []
	for i in 40:
		await get_tree().physics_frame
		samples.append(_horde.last_ms)
	samples.sort()
	var median := samples[samples.size() / 2]
	var worst := samples[samples.size() - 1]
	var sum := 0.0
	for s in samples:
		sum += s
	var mean := sum / float(samples.size())
	_check("1000 agents (250 active) update and fill their buffers in under 8 ms a tick (half the 60 Hz budget)", mean < 8.0 and median < 8.0, "mean %.2f ms, median %.2f ms, worst %.2f ms, alive %d, active %d, field builds %d" % [mean, median, worst, _horde.alive, _horde.active_count, _arena.field.builds])
	_check("the flow field keeps rebuilding while they walk", _arena.field.builds >= 4, "builds %d" % _arena.field.builds)


# --- Client ------------------------------------------------------------------------------------

func _run_client() -> void:
	var me: Player = null
	var t := 0.0
	while t < 25.0 and me == null:
		await _wait(0.25)
		t += 0.25
		me = Net.get_local_player()
	_check("client: own player spawned and is local", me != null, "peer %d" % multiplayer.get_unique_id())
	if me != null:
		me.bot_controlled = true  # the host's script drives this body; our own input packets would fight it
	await _wait(1.5)
	var lvl := get_tree().get_first_node_in_group("level")
	if lvl is HordeArena:
		await _run_client_arena(lvl as HordeArena)
		return
	var chain := get_tree().get_first_node_in_group("chain") as ChainSystem
	var segs := chain.segments.size() if chain != null else -1
	_check("client: chain rebuilt from replicated players", segs >= 1, "%d segments" % segs)
	_check("client: pickups replicated", get_tree().get_nodes_in_group("pickups").size() >= 10, "%d" % get_tree().get_nodes_in_group("pickups").size())
	var saw_thrown := false
	var saw_grab := false
	var saw_pappy := false
	var saw_shutter := false
	var saw_car_top := false
	var pappy := get_tree().get_first_node_in_group("pappy") as PappyPepperoni
	var pappy_node0 := pappy.node_index if pappy != null else -1
	t = 0.0
	while t < 320.0 and not GameState.escaped:
		await _wait(0.2)
		t += 0.2
		if _find_thrown("decoy") != null or _find_thrown("bomb") != null:
			saw_thrown = true
		for c in get_tree().get_nodes_in_group("hire"):
			if int(c.get("grab_peer")) != 0:
				saw_grab = true
		if pappy != null and (pappy.grab_peer != 0 or pappy.node_index != pappy_node0):
			saw_pappy = true
		for s in get_tree().get_nodes_in_group("shutters"):
			if (s as Shutter).closed:
				saw_shutter = true
		var car := get_tree().current_scene.get_node_or_null("World/Level/YellowRooms/Floor3/FreightCar") as FreightCar
		if car != null and car.has_arrived():
			saw_car_top = true
	_check("client: received ESCAPED", GameState.escaped, "after %.1f s" % t)
	_check("client: saw thrown items replicate", saw_thrown, "")
	_check("client: saw a Hollow Hire grab replicate", saw_grab, "")
	_check("client: received the layoff and checkpoints", GameState.wipes >= 1 and GameState.checkpoint_index >= 6, "wipes %d, checkpoint %d" % [GameState.wipes, GameState.checkpoint_index])
	_check("client: played the scares", ScareDirector.scares_played >= 20, "%d" % ScareDirector.scares_played)
	_check("client: rode the freight car up and saw Pappy and the shutter replicate", saw_car_top and saw_pappy and saw_shutter, "car %s, pappy %s, shutter %s" % [saw_car_top, saw_pappy, saw_shutter])
	_finish()


## A joiner who started with the default building and was handed the host's Loading Lot.
func _run_client_arena(arena: HordeArena) -> void:
	var main := get_tree().current_scene
	_check("client: the host's world config arrived and the Lot was rebuilt (joined with no --arena)", bool(Net.world_config.get("arena", false)) and arena.horde.count >= 400 and bool(main.get("_rejoined")), "config %s, rejoined %s" % [Net.world_config, main.get("_rejoined")])
	var horde := arena.horde
	var z0 := _mean_z_of(horde)
	var saw_launcher := false
	var saw_grab := false
	var t := 0.0
	while t < 300.0 and not GameState.escaped:
		await _wait(0.25)
		t += 0.25
		for l in arena.launchers:
			if l.lunges > 0:
				saw_launcher = true
			if l.grab_peer != 0:
				saw_grab = true
	_check("client: horde snapshots keep arriving from the host", horde.snapshots_received > 50, "%d packets" % horde.snapshots_received)
	_check("client: the crowd walks on the client too", absf(_mean_z_of(horde) - z0) > 2.0, "mean z %.1f -> %.1f" % [z0, _mean_z_of(horde)])
	_check("client: saw a Launcher jump and pin someone (replicated)", saw_launcher and saw_grab, "jump %s, grab %s" % [saw_launcher, saw_grab])
	_check("client: received the layoffs and ESCAPED from the Lot", GameState.escaped and GameState.wipes >= 1, "escaped %s after %.0f s, wipes %d" % [GameState.escaped, t, GameState.wipes])
	_finish()


func _mean_z_of(horde: Horde) -> float:
	var sum := 0.0
	var n := 0
	for i in horde.count:
		if horde.state[i] == Horde.AState.WALK:
			sum += horde.pz[i]
			n += 1
	return sum / maxf(1.0, float(n))


# --- Helpers -----------------------------------------------------------------------------------

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _wait_for_players(count: int, timeout: float) -> Array[Player]:
	var t := 0.0
	while t < timeout:
		if Net.get_players().size() >= count:
			await _wait(0.5)
			break
		await _wait(0.25)
		t += 0.25
	return Net.get_players()


func _chain() -> ChainSystem:
	return get_tree().get_first_node_in_group("chain") as ChainSystem


## Host at pos facing yaw, everyone else in a row beside them.
func _place(pos: Vector3, yaw: float) -> void:
	var bodies := Net.get_chain_bodies()
	for i in bodies.size():
		bodies[i].teleport_to(pos + Vector3(1.0 * float(i), 0.0, 0.0), yaw)
	_bot(Vector2.ZERO, yaw, 0)


## Puts the partner a few meters off (still within chain reach, so it still resists a little).
func _park_mate(_far: Vector3) -> void:
	if _mate == null:
		return
	_mate.teleport_to(_host.global_position + Vector3(0.0, 0.0, -2.2), 0.0)


func _bot(move: Vector2, yaw: float, flags: int, jump: bool = false) -> void:
	if jump:
		_seq = (_seq + 1) & 0xFF
	_host._apply_input(move, yaw, 0.0, flags | (_seq << Player.JUMP_SEQ_SHIFT))


func _key(code: Key, pressed: bool, logical_only: bool) -> void:
	var ev := InputEventKey.new()
	if logical_only:
		ev.keycode = code
	else:
		ev.physical_keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _mouse_move(relative: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.relative = relative
	Input.parse_input_event(ev)


func _give(id: String) -> void:
	_host.server_drop_all(false)  # no pickups left underfoot to be re-grabbed mid-test
	var data := ItemRegistry.get_data(id)
	_host.server_give_item(data.create_logic())


func _press_use() -> void:
	var yaw := _host.input_yaw
	_host._apply_input(Vector2.ZERO, yaw, _host.input_pitch, Player.FLAG_USE | (_seq << Player.JUMP_SEQ_SHIFT))
	await _wait(0.1)
	_host._apply_input(Vector2.ZERO, yaw, _host.input_pitch, _seq << Player.JUMP_SEQ_SHIFT)
	await _wait(0.1)


func _count_pickups(id: String) -> int:
	var n := 0
	for p in get_tree().get_nodes_in_group("pickups"):
		if p.get("item_id") == id:
			n += 1
	return n


func _find_thrown(kind: String) -> Thrown:
	var w := get_tree().current_scene.get_node_or_null("World/Thrown")
	if w == null:
		return null
	for t in w.get_children():
		if t is Thrown and (t as Thrown).kind == kind:
			return t
	return null


func _check(label: String, ok: bool, detail: String) -> void:
	print("[smoke] %s  %s  (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if ok:
		_passed += 1
	else:
		_failed += 1


func _finish() -> void:
	print("[smoke] %s: %d passed, %d failed" % ["CLIENT" if is_client else "HOST", _passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


## Co-op tests: the teammate is a real Player whose client lets the host's script drive it.
var _mate_seq: int = 0


func _drive_mate(move: Vector2, flags: int, jump: bool) -> void:
	var m := _mate as Player
	if m == null:
		return
	if jump:
		_mate_seq = (_mate_seq + 1) & 0xFF
	m._apply_input(move, 0.0, 0.0, flags | (_mate_seq << Player.JUMP_SEQ_SHIFT))
