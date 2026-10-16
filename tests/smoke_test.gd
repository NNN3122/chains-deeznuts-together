extends Node
## Headless smoke test. main.gd adds this node when launched with --smoke (host) or --smoke-client.
## The host side drives its own player with scripted input through Level 1 and checks every system;
## the client side checks what replicated to it. Exit code 0 means every check passed.
##   godot --headless --path . --max-fps 60 -- --host --smoke --smoke-players=2
##   godot --headless --path . --max-fps 60 -- --join=127.0.0.1 --smoke-client
##   godot --headless --path . --max-fps 60 -- --solo --smoke       (solo: the Ballast is the partner)

var expected_players: int = 1
var is_client: bool = false
var _passed: int = 0
var _failed: int = 0
var _seq: int = 0
var _level: YellowRooms
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
	_level = get_tree().get_first_node_in_group("level") as YellowRooms
	if _host == null or _level == null:
		_finish()
		return
	_host.bot_controlled = true
	_freeze_custodians(true)  # the monster gets its own test; keep it out of the others
	await _wait(0.6)
	var bodies := Net.get_chain_bodies()
	_mate = bodies[1] if bodies.size() > 1 else null
	_check("level built: 4 floors with test points", _level.floors.size() == 4 and _level.test_points.has("exit"), "%d floors, %d points" % [_level.floors.size(), _level.test_points.size()])
	var chain := _chain()
	var segs := chain.segments.size() if chain != null else -1
	_check("chain links every body (Ballast in solo)", segs == bodies.size() - 1 and segs >= 1, "%d segments, %d bodies" % [segs, bodies.size()])
	_check("pickups spawned", get_tree().get_nodes_in_group("pickups").size() >= 10, "%d pickups" % get_tree().get_nodes_in_group("pickups").size())

	await _test_keyboard()
	await _test_climb()
	await _test_lift()
	await _test_hang()
	await _test_items()
	await _test_custodian()
	await _test_scares()
	await _test_extras()
	_test_invites()
	await _test_exit()
	_finish()


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
	# TeamViewer-style: a held key arrives as a quick tap. Remote Controls keep you walking.
	var was_remote := Settings.remote_mode
	Settings.remote_mode = true
	_place(spawn, PI)
	await _wait(0.5)
	var z1 := _host.global_position.z
	_key(KEY_W, true, false)
	await _wait(0.03)
	_key(KEY_W, false, false)
	await _wait(0.6)
	_check("Remote Controls turn a 30 ms tap into a held key", _host.global_position.z - z1 > 1.2, "walked %.2f m" % (_host.global_position.z - z1))
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
	var dangle_y := hole.y + 0.92 - 4.85 - _mate.anchor_height()
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


func _test_items() -> void:
	var spawn: Vector3 = _level.test_points["spawn"]
	_place(spawn, PI)
	await _wait(0.5)
	# Flashlight.
	_give("flashlight")
	await _press_use()
	_check("flashlight turns on", _host.held_item != null and _host.held_item.is_active and (_host.synced_flags & Player.SFLAG_USING_ITEM) != 0, "flags %d" % _host.synced_flags)
	_host.server_drop_item(false)
	# Pistol.
	_give("pistol")
	_host.noise = 0.0
	await _press_use()
	var ammo: int = _host.held_item.get("ammo") if _host.held_item != null else -1
	_check("pistol fires (ammo down, very loud)", ammo == 7 and _host.noise >= 80.0, "ammo %d, noise %.0f" % [ammo, _host.noise])
	_host.server_drop_item(true)
	await _wait(0.3)
	_check("G-drop leaves a pickup behind", _count_pickups("pistol") >= 1, "%d pistol pickups" % _count_pickups("pistol"))
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


func _test_custodian() -> void:
	var c := get_tree().get_first_node_in_group("custodian") as Custodian
	for node in get_tree().get_nodes_in_group("custodian"):
		if (node as Custodian).floor_index == 0:
			c = node
	var spawn: Vector3 = _level.test_points["spawn"]
	var far := spawn + Vector3(0.0, 0.0, 30.0) if spawn.z < 18.0 else spawn - Vector3(0.0, 0.0, 30.0)
	# Hearing: a loud noise nearby starts a hunt.
	_place(spawn, PI)
	_park_mate(far)
	await _wait(0.3)
	c.debug_reset(spawn + Vector3(4.0, 0.0, 0.0))
	c.debug_frozen = false
	_host.add_noise(80.0)
	await _wait(0.3)
	_check("Custodian hears a loud noise and hunts", c.cstate == Custodian.CState.HUNT and c.hunt_peer == 1, "state %d" % c.cstate)
	# A grab with nobody holding on ends in a layoff.
	var wipes0 := GameState.wipes
	await _wait(2.0)
	var grabbed := c.grab_peer == 1 or GameState.wipes > wipes0
	for i in 40:
		if GameState.wipes > wipes0:
			break
		await _wait(0.1)
	_check("it grabs a still player and, unopposed, takes them (layoff)", grabbed and GameState.wipes > wipes0, "wipes %d -> %d" % [wipes0, GameState.wipes])
	await _wait(1.6)
	# Flashlight held up at it burns it off.
	_place(spawn, PI)
	_park_mate(far)
	await _wait(0.4)
	c.debug_reset(spawn)
	_give("flashlight")
	await _press_use()
	_host._apply_input(Vector2.ZERO, PI, Player.PITCH_LIMIT, _seq << Player.JUMP_SEQ_SHIFT)  # look straight up
	var wipes1 := GameState.wipes
	c.call("_start_grab", _host)
	var released := false
	for i in 25:
		await _wait(0.1)
		if not _host.is_grabbed():
			released = true
			break
	_check("a flashlight on it makes it let go", released and GameState.wipes == wipes1 and c.cstate == Custodian.CState.RETREAT, "released %s, state %d" % [released, c.cstate])
	_host.server_drop_item(false)
	_bot(Vector2.ZERO, PI, 0)
	# A partner standing beside you slows the lift.
	if _mate != null:
		await _wait(0.5)
		_place(spawn, PI)
		await _wait(0.4)
		_mate.teleport_to(_host.global_position + Vector3(1.0, 0.0, 0.0), 0.0)
		await _wait(0.4)
		c.debug_reset(_host.global_position)
		c.call("_start_grab", _host)
		await _wait(1.0)
		var lift := c.grab_lift
		_check("a partner beside you slows the lift", lift > 0.0 and lift < 0.8, "lifted %.2f m in 1 s (alone: 1.0)" % lift)
		c.call("take_hit")
		c.call("take_hit")
		await _wait(0.2)
		_check("two pistol hits make it let go", not _host.is_grabbed(), "grabbed %s" % _host.is_grabbed())
	c.debug_frozen = true


func _rel(cell: Vector3) -> String:
	var r := _host.global_position - cell
	return "(%.2f, %.2f, %.2f)" % [r.x, r.y, r.z]


func _freeze_custodians(on: bool) -> void:
	for node in get_tree().get_nodes_in_group("custodian"):
		(node as Custodian).debug_frozen = on


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
	for kind in ["lunge", "lights_out", "tile", "figure", "whisper", "phone", "slam", "dennis", "stain_pass"]:
		ScareDirector.trigger_for(kind, _host)
		await _wait(0.15)
	await _wait(0.5)
	_check("every scare type plays", ScareDirector.scares_played - before >= 9, "%d played" % (ScareDirector.scares_played - before))


func _test_exit() -> void:
	var exit: Vector3 = _level.test_points["exit"]
	var bodies := Net.get_chain_bodies()
	for i in bodies.size():
		bodies[i].teleport_to(exit + Vector3(-0.6 + 0.6 * float(i), 0.1, 0.0), 0.0)
	for i in 70:
		await _wait(0.1)
		if GameState.escaped:
			break
	_check("everyone in the freight elevator: ESCAPED", GameState.escaped, "escaped=%s" % GameState.escaped)
	await _wait(2.0)


# --- Client ------------------------------------------------------------------------------------

func _run_client() -> void:
	var me: Player = null
	var t := 0.0
	while t < 25.0 and me == null:
		await _wait(0.25)
		t += 0.25
		me = Net.get_local_player()
	_check("client: own player spawned and is local", me != null, "peer %d" % multiplayer.get_unique_id())
	await _wait(1.5)
	var chain := get_tree().get_first_node_in_group("chain") as ChainSystem
	var segs := chain.segments.size() if chain != null else -1
	_check("client: chain rebuilt from replicated players", segs >= 1, "%d segments" % segs)
	_check("client: pickups replicated", get_tree().get_nodes_in_group("pickups").size() >= 10, "%d" % get_tree().get_nodes_in_group("pickups").size())
	var saw_thrown := false
	var saw_grab := false
	t = 0.0
	while t < 180.0 and not GameState.escaped:
		await _wait(0.2)
		t += 0.2
		if _find_thrown("decoy") != null or _find_thrown("bomb") != null:
			saw_thrown = true
		for c in get_tree().get_nodes_in_group("custodian"):
			if int(c.get("grab_peer")) != 0:
				saw_grab = true
	_check("client: received ESCAPED", GameState.escaped, "after %.1f s" % t)
	_check("client: saw thrown items replicate", saw_thrown, "")
	_check("client: saw the Custodian grab replicate", saw_grab, "")
	_check("client: received the layoff and checkpoints", GameState.wipes >= 1 and GameState.checkpoint_index >= 1, "wipes %d, checkpoint %d" % [GameState.wipes, GameState.checkpoint_index])
	_check("client: played the scares", ScareDirector.scares_played >= 9, "%d" % ScareDirector.scares_played)
	_finish()


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
	if _host.held_item != null:
		_host.server_drop_item(false)
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
