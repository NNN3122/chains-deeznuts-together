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
	Player.debug_infinite_stamina = true  # the route tests sprint for minutes; _test_stamina turns breath back on
	HollowHire.debug_force_plan = "grab"  # the old tests expect a grab; _test_hire_attacks covers the rest
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
	var missing_kit := ""
	for p in Net.get_players():
		if not p.has_item("flashlight") or not p.has_item("wrench") or p.held_item == null or p.held_item.data.id != "flashlight":
			missing_kit = p.display_name
	_check("every player starts with a flashlight (in hand) and a wrench", missing_kit == "", missing_kit)
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
	await _test_playtest()
	await _test_grab_release()
	await _test_wrench()
	await _test_hire_attacks()
	await _test_shackle_key()
	await _test_forced()
	await _test_scares()
	await _test_crouch()
	await _test_slide()
	await _test_stamina()
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


## Breath: a sprint runs dry, winded you only walk and you pant (noise something hears), and a
## rest brings the sprint back.
func _test_stamina() -> void:
	Player.debug_infinite_stamina = false
	var spawn_at: Vector3 = _level.test_points["spawn"]
	_place(spawn_at, PI)
	_park_mate(spawn_at)
	await _wait(0.3)
	_host._tick_stamina(Player.SPRINT_SECONDS + 0.1, true, Player.RUN_SPEED)
	var winded := _host.is_winded() and _host.stamina <= 0.0
	var from := _host.global_position
	var speed := 0.0
	for k in 10:
		_bot(Vector2(0.0, 1.0), PI, Player.FLAG_RUN)  # world space: +z, into the room
		await _wait(0.06)
		speed = maxf(speed, Vector2(_host.velocity.x, _host.velocity.z).length())
	var moved := Vector2(_host.global_position.x - from.x, _host.global_position.z - from.z).length()
	var loud := _host.noise >= Player.NOISE_PANT - 1.0
	_bot(Vector2.ZERO, PI, 0)
	await _wait(Player.WINDED_UNTIL * Player.RECOVER_SECONDS + 0.6)
	var back := not _host.is_winded()
	_check("a sprint runs dry: winded you can only walk and you pant loud enough to be heard, and rest brings it back", winded and moved > 0.8 and speed <= Player.WALK_SPEED * 1.05 and loud and back,
		"winded %s, moved %.2f m, top speed %.2f, noise %.0f, recovered %s (stamina %.2f)" % [winded, moved, speed, _host.noise, back, _host.stamina])
	Player.debug_infinite_stamina = true
	_place(spawn_at, PI)
	await _wait(0.3)


## The Shackle Key: only the second player clocks in with it, in its own slot, and can't drop it.
## F unlocks you from the Line (the chain closes up without you); F again only next to a teammate
## locks you back on; a regroup puts everyone back on. Exercised on the host (given one for the test).
func _test_shackle_key() -> void:
	var mate_player := _mate as Player
	_check("only the second player clocks in with the Shackle Key", not _host.has_item("shackle_key") and (mate_player == null or (mate_player.join_index == Player.KEY_HOLDER and mate_player.has_item("shackle_key") and mate_player.slots[Player.KEY_SLOT] != null)), "host %s, mate %s" % [_host.has_item("shackle_key"), mate_player.has_item("shackle_key") if mate_player != null else "none"])
	_host.server_give_item(ItemRegistry.get_data("shackle_key").create_logic())
	var key := _host.find_item("shackle_key") as ShackleKey
	var in_own_slot := key != null and _host.slots[Player.KEY_SLOT] == key and _host.selected_slot != Player.KEY_SLOT
	_host.select_slot(Player.KEY_SLOT)
	_host.server_drop_item(true)
	var kept := _host.has_item("shackle_key")
	_check("the key sits in its own slot (4) and can't be dropped", in_own_slot and kept, "own slot %s, kept %s" % [in_own_slot, kept])
	var spawn_at: Vector3 = _level.test_points["spawn"]
	_place(spawn_at, PI)
	await _wait(0.4)
	var chain := _chain()
	var segs0 := chain.segments.size()
	key._tick(0.1, true, true)
	await _wait(0.2)
	var off := _host.unchained and _host.is_unchained() and chain.segments.size() == segs0 - 1
	_host.teleport_to(spawn_at + Vector3(0.0, 0.0, 3.6), PI)
	await _wait(ShackleKey.COOLDOWN + 0.2)
	key._tick(0.1, true, true)
	await _wait(0.2)
	var refused := _host.unchained
	_host.teleport_to(spawn_at + Vector3(1.0, 0.0, 0.0), PI)
	for b in Net.get_chain_bodies():
		if b != _host:
			b.teleport_to(spawn_at, PI)
	await _wait(ShackleKey.COOLDOWN + 0.2)
	key._tick(0.1, true, true)
	await _wait(0.2)
	var back := not _host.unchained and chain.segments.size() == segs0
	_check("F unlocks you from the Line; away from everyone it won't lock back on; next to a teammate it does", off and refused and back, "off %s (segments %d -> %d), refused %s, back %s" % [off, segs0, chain.segments.size(), refused, back])
	_host.set_unchained(true)
	GameState.call("_do_regroup", "test")
	await _wait(0.4)
	_check("a regroup puts everyone back on the Line", not _host.unchained, "")
	# Hand the test key back: the host doesn't carry one in a real run.
	_host.slots[Player.KEY_SLOT].queue_free()
	_host.slots[Player.KEY_SLOT] = null
	_host.select_slot(0)
	_host.call("_refresh_slot_ids")
	_place(spawn_at, PI)
	await _wait(1.0)


## The Hire's other attacks: a tackle puts you down and then it takes you by the throat; a charge
## throws you; a slap sends you sideways across the room; thrown into a wall you slam and slump;
## a charge that misses runs into the wall and stuns it.
func _test_hire_attacks() -> void:
	var h: HollowHire = _level.hires_on(0)[0]
	var stand: Vector3 = _level.test_points["breaker0"]
	var mid := _level.cell_center(0, _level.cell_of(stand)) + Vector3(0.0, 0.1, 0.0)
	var out := mid + Vector3(30.0, 0.0, 0.0)
	# Tackle: down, then pinned and grabbed.
	_place(mid, 0.0)
	_park_mate(mid)
	await _wait(0.3)
	h.debug_reset(mid + Vector3(0.0, 0.0, -2.6), PI)
	h.debug_attack(HollowHire.HState.TACKLE, _host)
	var downed := false
	var grabbed := false
	for i in 30:
		await _wait(0.05)
		downed = downed or _host.is_downed()
		if _host.is_grabbed():
			grabbed = true
			break
	_check("a tackle puts you on the floor, then it takes you by the throat", downed and grabbed, "downed %s, grabbed %s, state %d" % [downed, grabbed, h.hstate])
	h.release(false)
	h.debug_frozen = true
	h.respawn_at(out)
	await _wait(0.8)
	# Charge: thrown.
	_place(mid, 0.0)
	_park_mate(mid)
	await _wait(0.3)
	h.debug_reset(mid + Vector3(0.0, 0.0, -4.0), PI)
	h.debug_attack(HollowHire.HState.CHARGE, _host)
	var thrown := false
	var top := 0.0
	for i in 30:
		await _wait(0.05)
		top = maxf(top, Vector2(_host.velocity.x, _host.velocity.z).length())
		thrown = thrown or _host.is_knocked()
	_check("a charge throws you", thrown and top > 6.0, "knocked %s, top speed %.1f m/s" % [thrown, top])
	h.debug_frozen = true
	h.respawn_at(out)
	await _wait(2.0)
	# Slap: across the room, sideways.
	_place(mid, 0.0)
	_park_mate(mid)
	await _wait(0.3)
	h.debug_reset(mid + Vector3(0.0, 0.0, -1.4), PI)
	var before := _host.global_position
	h.debug_attack(HollowHire.HState.SLAP, _host)
	var slapped := false
	for i in 16:
		await _wait(0.05)
		slapped = slapped or _host.is_knocked()
	await _wait(0.4)
	var side := absf(_host.global_position.x - before.x)
	_check("a slap sends you sideways across the room", slapped and side > 1.0, "knocked %s, %.1f m sideways" % [slapped, side])
	h.debug_frozen = true
	h.respawn_at(out)
	await _wait(2.0)
	# Thrown into a wall: slammed, slumped.
	var spawn_at: Vector3 = _level.test_points["spawn"]
	_place(spawn_at, PI)
	_park_mate(spawn_at)
	await _wait(0.3)
	_host.knock(Vector3(0.0, 1.5, -14.0), 1.0, false)
	var slam := false
	for i in 12:
		await _wait(0.05)
		slam = slam or _host.is_downed()
	_check("thrown into a wall you slam into it and slump down it", slam, "downed %s" % slam)
	await _wait(Player.WALL_DAZE + 0.5)
	_check("...and you get up again", not _host.is_knocked(), "")
	# A charge you dodge: it runs into the wall and reels.
	var wall_at := spawn_at + Vector3(0.0, 0.0, 3.6)
	_place(spawn_at + Vector3(2.0, 0.0, 1.0), PI)
	_park_mate(spawn_at)
	h.debug_reset(wall_at, 0.0)  # facing -z, the wall behind spawn
	h.debug_attack(HollowHire.HState.CHARGE, _host)
	h.set("_attack_dir", Vector3(0.0, 0.0, -1.0))
	h.set("_t", HollowHire.CHARGE_WINDUP)  # already committed, at the wall
	var reeled := false
	for i in 30:
		await _wait(0.05)
		if h.hstate == HollowHire.HState.STUNNED:
			reeled = true
			break
	_check("a charge that misses runs into the wall and stuns itself", reeled, "state %d" % h.hstate)
	h.debug_frozen = true
	h.respawn_at(out)
	_place(spawn_at, PI)
	await _wait(0.5)


## The wrench: a swing staggers a Hire; a crack across one that holds a teammate frees them (dealt
## directly in solo, where the only other body is the Ballast; swung for real in co-op); two cracks
## at a floor's breaker panel during a power stutter bring its lights back.
func _test_wrench() -> void:
	var h: HollowHire = _level.hires_on(0)[0]
	var spawn_at: Vector3 = _level.test_points["spawn"]
	_place(spawn_at, PI)
	_park_mate(spawn_at)
	await _wait(0.3)
	_give("wrench")
	h.debug_reset(spawn_at + Vector3(0.0, 0.0, 1.8), 0.0)
	h.debug_frozen = true
	await _wait(0.2)
	var to := h.chest_point() - _host.eye_position()
	await _swing(atan2(-to.x, -to.z), atan2(to.y, Vector2(to.x, to.z).length()))
	_check("a wrench swing staggers a Hire in front of you", h.hstate == HollowHire.HState.STUNNED, "state %d, %.1f m" % [h.hstate, to.length()])
	await _wait(Wrench.COOLDOWN)
	h.debug_reset(spawn_at + Vector3(0.0, 0.0, 2.6), 0.0)
	h.debug_frozen = true
	await _wait(0.2)
	var freed := false
	var victim: Player = _mate as Player if _mate is Player else _host
	h._start_grab(victim)
	await _wait(0.4)
	var held := victim.is_grabbed()
	if victim == _host:
		freed = h.wrench_hit(null)
	else:
		to = victim.global_position + Vector3.UP * 1.2 - _host.eye_position()
		await _swing(atan2(-to.x, -to.z), atan2(to.y, Vector2(to.x, to.z).length()))
		freed = not victim.is_grabbed()
	_check("a crack of the wrench makes a Hire drop the teammate it holds, and it reels", held and freed and not victim.is_grabbed() and h.hstate == HollowHire.HState.STUNNED,
		"held %s, freed %s, state %d (%s)" % [held, freed, h.hstate, "swung" if victim != _host else "direct"])
	h.respawn_at(spawn_at + Vector3(20.0, 0.0, 0.0))
	h.debug_frozen = true
	await _wait(Wrench.COOLDOWN)
	# The breaker panel: out with the power, two cracks bring it back.
	var panel: BreakerPanel = _level.breakers[0]
	_level.debug_power_stutter(0, 30.0)
	await _wait(1.8)
	var was_dark := _level.lights().is_floor_dark(0) and panel.needs_fix()
	var stand: Vector3 = _level.test_points["breaker0"]
	_place(stand, 0.0)
	_park_mate(stand)
	await _wait(0.3)
	to = panel.fix_point() - _host.eye_position()
	var yaw := atan2(-to.x, -to.z)
	var pitch := atan2(to.y, Vector2(to.x, to.z).length())
	await _swing(yaw, pitch)
	var one := panel.debug_hits()
	var still_dark := _level.lights().is_floor_dark(0)
	await _wait(Wrench.COOLDOWN)
	await _swing(yaw, pitch)
	await _wait(0.2)
	_check("two cracks of the wrench at the breaker panel bring the floor's lights back", was_dark and one == 1 and still_dark and not _level.lights().is_floor_dark(0) and not panel.needs_fix(),
		"dark %s, after one %d (still dark %s), dark now %s" % [was_dark, one, still_dark, _level.lights().is_floor_dark(0)])
	_place(spawn_at, PI)
	await _wait(0.3)


func _swing(yaw: float, pitch: float) -> void:
	_host._apply_input(Vector2.ZERO, yaw, pitch, Player.FLAG_USE | (_seq << Player.JUMP_SEQ_SHIFT))
	await _wait(0.1)
	_host._apply_input(Vector2.ZERO, yaw, pitch, _seq << Player.JUMP_SEQ_SHIFT)
	await _wait(0.05)


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
	# No glowing words in the building (the user: "way less scary"): print is shaded, so it only
	# reads where light falls. Light fixtures (EXIT signs, neon, arcade marquees) still glow.
	var glowing: Array[String] = []
	for n in _level.find_children("*", "Label3D", true, false):
		var l := n as Label3D
		if not l.shaded and l.text != "EXIT" and not l.has_meta("light_fixture"):
			glowing.append(l.text.replace("\n", " "))
	_check("no glowing writing in the building", glowing.is_empty(), "%d: %s" % [glowing.size(), str(glowing.slice(0, 6))])
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
	var z_let_go := _host.global_position.z
	await _wait(0.5)
	var stream_walk := _host.global_position.z - z1
	_check("Remote Controls turn a stream of 30 ms taps into a held key", _host.input.flicker_seen and stream_walk > 1.0, "flicker %s, walked %.2f m" % [_host.input.flicker_seen, stream_walk])
	var after_walk := _host.global_position.z - z_let_go
	_check("...and when the stream stops you stop within a step (no long grace once the hold is proven)", after_walk < 1.6, "%.2f m after the last tap" % after_walk)
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
	# A release we never heard (a menu was up) must not leave the view turning for ever.
	_host.input._down["turn_left"] = true
	await _wait(0.5)
	var yaw2 := _host._yaw
	await _wait(0.4)
	_check("a key released while we weren't listening doesn't keep turning", absf(_host._yaw - yaw2) < 0.02, "yaw moved %.2f" % (_host._yaw - yaw2))
	Settings.remote_mode = was_remote
	_host.bot_controlled = true
	_bot(Vector2.ZERO, 0.0, 0)
	# A sprint that turns round plants a foot: the old way's speed dies like a stop.
	_place(spawn, PI)
	await _wait(0.4)
	_bot(Vector2(0.0, 1.0), PI, Player.FLAG_RUN)  # +z, into the room
	await _wait(0.7)
	var run_v := _host.velocity.z
	_bot(Vector2(0.0, -1.0), PI, Player.FLAG_RUN)
	await _wait(0.35)
	var back_v := -_host.velocity.z
	_bot(Vector2.ZERO, PI, 0)
	_check("a sprint reversed is going the other way within 0.35 s (no skating on)", run_v > 4.5 and back_v > 0.5, "%.2f m/s, then %.2f m/s back" % [run_v, back_v])


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
	_check("three loot slots fill; a fourth item is refused (slot 4 is only the Shackle Key's)", not fourth and _host.free_slot() < 0 and _host.slot_ids.size() == Player.SLOTS and "" not in _host.slot_ids.slice(0, Player.ITEM_SLOTS), "fourth %s, slots %s" % [fourth, _host.slot_ids])
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


func _test_playtest() -> void:
	var monsters := get_tree().get_nodes_in_group("custodian")
	_check("one roaming Hire on the first floor, two on the second (no sentry on either), and the original Custodian on the second", _level.hires_on(0).size() == 1 and _level.hires_on(1).size() == 2 and not _level.hires_on(1)[0].sentry and not _level.hires_on(0)[0].sentry and monsters.size() == 1 and monsters[0].floor_index == 1, "B4 %d, B3 %d, custodians %d" % [_level.hires_on(0).size(), _level.hires_on(1).size(), monsters.size()])
	if not monsters.is_empty():
		var c := monsters[0] as Custodian
		var at: Vector3 = _level.test_points["plate"]
		_place(at, 0.0)
		await _wait(0.2)
		c.debug_reset(at + Vector3(0.0, 0.0, 4.0))
		_host.add_noise(100.0)
		c.debug_frozen = false
		await _wait(0.2)
		_check("the restored ceiling hunter follows loud noise", c.is_hunting() and c.hunt_peer == 1, "state %d" % c.cstate)
		c.take_hit()
		c.take_hit()
		_check("two shots drive the Custodian back", c.cstate == Custodian.CState.RETREAT, "state %d" % c.cstate)
		var safe := _level.cell_center(1, _level.floors[1]["arrive"])
		_place(safe, 0.0)
		_host.add_noise(100.0)
		_check("the Custodian respects break rooms", c._effective(_host) == 0.0 and not c._ceiling_above(safe), "")
		c.debug_frozen = true
		c.release(false)
	var saved_volume := Settings.voice_volume
	Settings.voice_volume = 1.0
	var baseline := Voice.playback_volume_db(false)
	Settings.voice_volume = Settings.MAX_VOICE_VOLUME
	var boosted := Voice.playback_volume_db(false)
	_check("voice boosts existing settings and provides eightfold extra gain", baseline == 6.0 and boosted - baseline > 18.0 and Voice.playback_volume_db(true) > baseline, "base %.1f dB, max %.1f dB" % [baseline, boosted])
	var voice: Dictionary = Voice._voice_for(1)
	var playback := voice["player"] as AudioStreamPlayer3D
	var limiter_bus := AudioServer.get_bus_index("VoicePlayback")
	_check("voice playback permits boosted gain and routes through a shared limiter", playback.max_db >= 24.0 and AudioServer.get_bus_send(int(voice["bus_index"])) == "VoicePlayback" and AudioServer.get_bus_effect(limiter_bus, 0) is AudioEffectLimiter, "")
	Voice._drop_voice(1)
	Settings.voice_volume = 0.0
	_check("voice volume zero remains silent", Voice.playback_volume_db(false) <= -80.0, "")
	Settings.voice_volume = saved_volume
	_place(_level.test_points["spawn"], 0.0)


## The caught-camera bug: a grab must never leave you stuck. A release with your head in the
## ceiling tiles puts you back where you were caught; a holder that vanishes (or says it holds
## someone else) lets go on its own; and the view is only pulled toward the monster briefly.
func _test_grab_release() -> void:
	var monsters := get_tree().get_nodes_in_group("custodian")
	var at: Vector3 = _level.test_points["plate"]
	_freeze_hires(true)
	_place(at, 0.0)
	await _wait(0.4)
	if not monsters.is_empty():
		var c := monsters[0] as Custodian
		c.debug_reset(at + Vector3(0.0, 0.0, 6.0))
		c.debug_frozen = true
		var base_y := _host.global_position.y
		c._start_grab(_host)
		c.grab_lift = 1.7
		_host.global_position = Vector3(at.x, base_y + 1.7, at.z)  # head through the ceiling tiles
		var embedded := _host._capsule_blocked(_host.global_position)
		c.release(false)
		await _wait(0.3)
		var moved := 0.0  # the best of four directions: the spot may have a wall or the lift beside it
		for dir: Vector2 in [Vector2(1.0, 0.0), Vector2(-1.0, 0.0), Vector2(0.0, 1.0), Vector2(0.0, -1.0)]:
			var start := _host.global_position
			_bot(dir, 0.0, 0)
			await _wait(0.5)
			_bot(Vector2.ZERO, 0.0, 0)
			await _wait(0.2)
			moved = maxf(moved, Vector2(_host.global_position.x - start.x, _host.global_position.z - start.z).length())
		_check("let go with your head in the ceiling, you are back on your feet and can walk", not _host.is_grabbed() and not _host._capsule_blocked(_host.global_position) and moved > 0.8 and absf(_host.global_position.y - base_y) < 0.5,
			"embedded %s, y %.2f (floor %.2f), moved %.2f m" % [embedded, _host.global_position.y, base_y, moved])
		c.debug_reset(at + Vector3(0.0, 0.0, 14.0))
	# A holder that vanishes mid-grab.
	_place(at, 0.0)
	await _wait(0.3)
	var ghost := Node3D.new()
	add_child(ghost)
	_host.grab_start(ghost)
	_host._pitch = -0.4
	await _wait(0.2)
	ghost.queue_free()
	await _wait(0.8)
	_check("a grab whose monster is gone lets go by itself", not _host.is_grabbed() and _host.state == Player.State.NORMAL, "state %d" % _host.state)
	# A Hire that says it holds someone else no longer holds you.
	var hire: HollowHire = _level.hires_on(1)[0]  # the B3 runner, on this floor
	hire.grab_peer = 0
	_host.grab_start(hire)
	await _wait(0.8)
	_check("a grab the monster no longer claims lets go by itself", not _host.is_grabbed(), "state %d" % _host.state)
	# The catch: held up by the throat, raked, then the jaw drops for the bite; the caught player
	# sees it through their own eyes, pulled back onto its face, and the camera comes back after.
	hire.debug_reset(at + Vector3(0.0, 0.0, -3.0), PI)
	hire.debug_frozen = true
	var was_mode := _host.camera_mode
	_host.camera_mode = Player.CameraMode.THIRD_PERSON
	_host._apply_camera_mode()
	for b in Net.get_chain_bodies():
		if b != _host:
			b.teleport_to(at + Vector3(4.0, 0.0, 0.0), 0.0)  # out of rescue reach: let it play out
	var floor_y := _host.global_position.y
	hire._start_grab(_host)
	await _wait(1.0)
	# After the swing onto its face the mouse is yours: you can look down.
	var pitch_before := _host._pitch
	_host.input.look_delta = Vector2(0.0, 400.0)
	await _wait(0.2)
	var looked_down := pitch_before - _host._pitch
	_host._yaw += 1.0  # and away
	await _wait(1.4)  # left alone, the view drifts back onto its face
	_check("caught, the mouse still looks around (down too)", looked_down > 0.15, "pitch moved %.2f rad" % looked_down)
	var cam := _host.local_camera()
	var to_face := (hire.face_point() - cam.global_position).normalized()
	var aim := -cam.global_transform.basis.z
	var looking := aim.angle_to(to_face)
	var pov := _host._pov_forced and cam == _host._fp_camera
	var lifted := _host.global_position.y - floor_y
	var jaw_open := 0.0
	for i in 30:
		await _wait(0.05)
		jaw_open = minf(jaw_open, hire._jaw.rotation.x)
		if not _host.is_grabbed():
			break
	hire.release(false)
	await _wait(0.3)
	_check("caught by a Hire: lifted by the throat, the view your own eyes locked on its face, the jaw opening for the bite", looking < 0.3 and pov and lifted > 0.08 and jaw_open < -0.6,
		"off its face %.2f rad, first person %s, lifted %.2f m, jaw %.2f" % [looking, pov, lifted, jaw_open])
	_check("let go, the camera you chose comes back", not _host._pov_forced and _host._tp_camera.current, "")
	_host.camera_mode = was_mode
	_host._apply_camera_mode()
	await _wait(0.5)
	hire.respawn_at(at + Vector3(20.0, 0.0, 0.0))
	_place(_level.test_points["spawn"], 0.0)
	await _wait(0.3)


func _rel(cell: Vector3) -> String:
	var r := _host.global_position - cell
	return "(%.2f, %.2f, %.2f)" % [r.x, r.y, r.z]


func _freeze_hires(on: bool) -> void:
	for node in get_tree().get_nodes_in_group("custodian"):
		(node as Custodian).debug_frozen = on
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
	_park_mate_clear()
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
	# B3 has the mixed encounter; B2 still has runners that answer a call-out.
	var upstairs := _level.hires_on(2)
	var plate: Vector3 = _level.test_points["boost_shelf"]
	_place(plate, PI)
	_park_mate(plate + Vector3(8.0, 0.0, 0.0))
	await _wait(0.3)
	h.debug_frozen = true
	var caller: HollowHire = upstairs[0]
	var h2: HollowHire = upstairs[1]
	caller.debug_frozen = true
	h2.debug_reset(plate + Vector3(3.0, 0.0, 3.2), PI)  # off to the side, facing away: it can't see you
	h2.debug_frozen = false
	caller.debug_reset(plate + Vector3(0.0, 0.0, 3.2), 0.0)
	caller.debug_frozen = false
	caller._start_chase(_host)  # trigger a sighting explicitly: B2's shelves block this test's sightline
	var answered := false
	for i in 12:
		await _wait(0.1)
		if h2.hstate == HollowHire.HState.CHASE and h2.hunt_peer == 1:
			answered = true
			break
	_check("one that sees you calls the floor: the other Hire drops its walk and chases too", upstairs.size() >= 2 and answered, "crew %d, h2 state %d, hunting %d" % [upstairs.size(), h2.hstate, h2.hunt_peer])
	caller.debug_frozen = true
	h2.debug_frozen = true
	caller.respawn_at(plate + Vector3(14.0, 0.0, 0.0))
	h2.respawn_at(plate + Vector3(14.0, 0.0, 3.0))
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
	_park_mate_clear()
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
	_park_mate_clear()
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
	_park_mate_clear()
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
	# Two rounds drop it; the floor sends another after a while, out of sight. Shot across the Break
	# Room: open floor on any layout (5 m on from the crates can be through a wall).
	var spawn_at: Vector3 = _level.test_points["spawn"]
	_place(spawn_at, PI)
	_park_mate(spawn_at + Vector3(1.5, 0.0, -0.4))
	await _wait(0.3)
	h.debug_reset(spawn_at + Vector3(0.0, 0.0, 3.5), 0.0)
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
	var stun_left: float = h.get("_t")
	_check("Snubby rounds don't kill a Hire: each one stuns it for 12 seconds", not h.is_dead() and h.hits >= 2 and h.hstate == HollowHire.HState.STUNNED and stun_left > HollowHire.SHOT_STUN - 1.0, "hits %d, state %d, %.1f s of stun left" % [h.hits, h.hstate, stun_left])
	_host.server_drop_item(false)
	h.blast()  # only a bomb puts one down
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
	# Pacing: dread builds on its target (the heartbeat, then the hush), then it lands and the
	# director waits out a fresh cooldown before the next.
	ScareDirector.debug_build(_host)
	await _wait(0.3)
	var building: bool = ScareDirector.is_building()
	await _wait(ScareDirector.BUILD_TIME + 0.4)
	var landed: bool = not ScareDirector.is_building()
	var cooldown: float = ScareDirector.get("_next_t")
	_check("scares are paced: dread builds on its target, lands, then a fresh cooldown", building and landed and cooldown >= ScareDirector.COOLDOWN_MIN - 6.0,
		"building %s, landed %s, next in %.1f s" % [building, landed, cooldown])
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
	_level.set("_stutter_t", 999.0)  # its own stutter landing mid-check would restart the flicker
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
	_park_mate(under + Vector3(1.2, 0.0, -1.2))  # beside you: from the Break Room the chain drags you out
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
	if only == "roof":
		_place(lot.spawn_position, 0.0)
		lot.server_arrive()
	_check("the roof is its own level for names, scares and the sky", _stack.floor_name(_host.global_position.y) == HordeArena.FLOOR_NAME and _stack.level_index_at(_host.global_position) == 2 and _stack.scare_pool(_host.global_position) == HordeArena.SCARE_POOL and not _stack.is_safe_spot(_host.global_position), _stack.floor_name(_host.global_position.y))
	await _escape_by_helicopter(lot, _stack.test_points, "l_")


## The whole way out: fence, gap (wave two, the spiders), the last roof (every roof's wave), the
## helipad (the last wave, the bats, and its checkpoint), jetpack into the flyby.
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
	var round2 := lot.rounds_spawned >= 2
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
	var round3 := lot.rounds_spawned >= lot.wave_count() and not lot.waves_spawn(Horde.KIND_WEAVER) and not lot.waves_spawn(Horde.KIND_FLITTER)
	var cp_ok := GameState.checkpoint_index == lot.helipad_checkpoint_index()
	_check("the gap brings wave two, the helipad the helipad checkpoint, and no spider or bat ever comes in a wave (they are jump scares now)", two_done and round2 and climbed and round3 and cp_ok,
		"tasks %s, waves %d, weavers %d, flitters %d, checkpoint %d (want %d)" % [str(GameState.tasks), lot.rounds_spawned, lot.horde.alive_of(Horde.KIND_WEAVER), lot.horde.alive_of(Horde.KIND_FLITTER), GameState.checkpoint_index, lot.helipad_checkpoint_index()])
	# Standing below a passing aircraft must never count as boarding.
	var airborne: bool = lot.heli_position().y - tp[prefix + "helipad"].y > 3.5  # it bobs between 3.85 and 4.55 m; a jump reaches 1.6
	var initial := lot.heli_position()
	await _wait(3.0)  # slowest at the ends of a pass: 2 s there can be under 2 m
	_check("helicopter flies past immediately; waiting on the pad cannot win", airborne and initial.distance_to(lot.heli_position()) > 2.0 and not GameState.escaped and GameState.task_done(HordeArena.TASK_PAD), "moved %.1f m" % initial.distance_to(lot.heli_position()))
	var supply := 0
	for p in Net.get_players():
		if p.has_item("jetpack"):
			supply += 1
	for pickup in get_tree().get_nodes_in_group("pickups"):
		if pickup.get("item_id") == "jetpack" and pickup.global_position.distance_to(tp[prefix + "helipad"]) < 10.0:
			supply += 1
	_check("helipad provides fresh jetpacks for the team", supply >= 1, "%d packs" % supply)
	lot.server_on_respawn()
	await _wait(0.7)
	_check("respawn restarts flybys even with the helipad task already complete", lot.heli_fraction == 1.0 and lot.heli_elapsed > 0.0, "clock %.2f" % lot.heli_elapsed)
	# Real controls, fuel and chain physics: launch from the pad into the moving cabin.
	for p in Net.get_players():
		p.server_drop_all(false)
		p.server_give_item(ItemRegistry.get_data("jetpack").create_logic())
	_place(tp[prefix + "helipad"] + Vector3(0.0, 0.0, 6.5), 0.0)
	for wait_tick in 160:
		if lot.heli_elapsed >= HordeArena.FLYBY_SECONDS * 0.25 - 1.5:
			break
		await _wait(0.05)
	var highest := _host.global_position.y
	for tick in 70:
		var phase := (lot.heli_elapsed + 0.25) / HordeArena.FLYBY_SECONDS * TAU
		var aim := lot.origin + lot.tower_top + Vector3(-cos(phase) * HordeArena.FLYBY_WIDTH, HordeArena.FLYBY_HEIGHT + 0.7, sin(phase) * 1.5)
		for p in Net.get_players():
			var direction := Vector2(aim.x - p.global_position.x, aim.z - p.global_position.z).limit_length(1.0)
			if p.global_position.y < aim.y - 0.1:
				direction.y = clampf((lot.origin.z + lot.tower_top.z + 6.5 - p.global_position.z) * 2.0, -1.0, 1.0)
			# Ease off like a pilot would: no thrust once the climb alone carries you to the deck.
			# Thrusting until level with it overshot onto the cabin's roof.
			var rise := maxf(p.velocity.y, 0.0)
			var apex := p.global_position.y + rise * rise / (2.0 * Player.GRAVITY)
			var flags := Player.FLAG_RUN | (Player.FLAG_USE if apex < aim.y + 0.25 else 0)
			p._apply_input(direction, 0.0, 0.0, flags)
		await _wait(0.05)
		highest = maxf(highest, _host.global_position.y)
		if GameState.escaped:
			break
	_check("jetpack flight with the chain reaches the moving cabin and escapes", GameState.escaped and GameState.escape_line.begins_with("Airlifted"), "rose %.2f m; host %s, heli %s" % [highest - tp[prefix + "helipad"].y, _host.global_position, lot.heli_position()])
	for p in Net.get_players():
		p._apply_input(Vector2.ZERO, 0.0, 0.0, 0)
	await _wait(0.3)


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
	var o2 := Vector2(arena.origin.x, arena.origin.z)
	for i in range(1, arena.roofs.size() - 1):
		var r: HordeArena.Roof = arena.roofs[i]
		var prev: HordeArena.Roof = arena.roofs[i - 1]
		var d := r.dir
		var d3 := Vector3(d.x, 0.0, d.y)
		var yaw := atan2(-d.x, -d.y)
		var edge := o2.dot(d) + prev.edge_along(d)  # the edge you leave from, as a coordinate along d
		var near := edge + r.gap  # this roof's near edge
		# 4 m of run-up, the partner a metre behind: both still on the raised part (5.6 m or more deep).
		# (Behind a leaning slab, not on it: it runs back from the wall r.ramp m.)
		var start := arena.origin + Vector3(r.cross.x, prev.top + 0.1, r.cross.y) - d3 * maxf(4.0, r.ramp + 1.2)
		_host.teleport_to(start, yaw)
		if _mate != null:
			_mate.teleport_to(start - d3 * 1.0, yaw)
		_bot(Vector2.ZERO, yaw, 0)
		await _wait(0.4)
		if r.link == HordeArena.Link.FACADE:
			failed += await _climb_facade(i)
			continue
		# Where to take off: the edge for a jump or a leap, then each chimney stack's far edge.
		# Girders and a snapped plank are walked, with a hop at each gap; the rest are sprinted.
		var takeoffs: Array[float] = []
		if r.link == HordeArena.Link.JUMP or r.link == HordeArena.Link.LEAP or r.link == HordeArena.Link.STONES or r.link == HordeArena.Link.GIRDERS:
			takeoffs.append(edge)
		for s in r.stones:
			takeoffs.append(o2.dot(d) + Vector2(s.x, s.z).dot(d) + HordeArena.STONE_DEPTH * 0.5)
		for g in r.girders.size():
			takeoffs.append(o2.dot(d) + Vector2(r.girders[g].x, r.girders[g].z).dot(d) + r.girder_len[g] * 0.5)
		if r.link == HordeArena.Link.PLANK and r.plank_break != Vector2.ZERO:
			takeoffs.append(edge + r.plank_break.x)
		var run := r.link == HordeArena.Link.JUMP or r.link == HordeArena.Link.LEAP or r.link == HordeArena.Link.STONES or r.link == HordeArena.Link.DROP
		var flags := Player.FLAG_RUN if run else 0
		# Jump in the last half metre at a sprint (0.35 m a poll), the last 0.3 m at a walk: the long
		# jumps are sized to a take-off from the very edge.
		var early := 0.5 if run else 0.3
		var jumped := 0
		var mate_jumped := 0
		var landed := false
		var mate_p := _mate as Player
		var mate_landed := mate_p == null
		var trail := ""
		for k in 240:
			await _wait(0.05)
			var along := Vector2(_host.global_position.x, _host.global_position.z).dot(d)
			if k % 10 == 0:
				trail += "[%.1f %.1f %s %d] " % [along - near, _host.global_position.y - arena.origin.y, "F" if _host.is_on_floor() else "a", _host.state]
			var tap := false
			if jumped < takeoffs.size() and along > takeoffs[jumped] - early and _host.is_on_floor() and _host.state == Player.State.NORMAL:
				tap = true
				jumped += 1
			elif r.link == HordeArena.Link.CLIMB and k % 6 == 0 and along < near + 0.3 and (r.ramp <= 0.0 or along > edge - 0.9):
				tap = true  # Space into the unit, then the roof
			if not landed and arena.roof_at(_host.global_position) == i and _host.is_on_floor() and along > near + 2.4:
				landed = true  # clear of the edge: the teammate is coming over behind
			_bot(Vector2.ZERO if landed else d, yaw, 0 if landed else flags, tap and not landed)  # world-space, like _send_input
			# A teammate (co-op) crosses the same way, jumping at their own edges.
			if mate_p != null:
				var m_along := Vector2(mate_p.global_position.x, mate_p.global_position.z).dot(d)
				var mtap := false
				if mate_jumped < takeoffs.size() and m_along > takeoffs[mate_jumped] - early and mate_p.is_on_floor() and mate_p.state == Player.State.NORMAL:
					mtap = true
					mate_jumped += 1
				elif r.link == HordeArena.Link.CLIMB and k % 6 == 3 and m_along < near + 0.3 and (r.ramp <= 0.0 or m_along > edge - 0.9):
					mtap = true
				if not mate_landed and arena.roof_at(mate_p.global_position) == i and mate_p.is_on_floor() and m_along > near + 0.6:
					mate_landed = true
				_drive_mate(Vector2.ZERO if mate_landed else d, 0 if mate_landed else flags, mtap and not mate_landed)
			if landed and mate_landed:
				break
		_bot(Vector2.ZERO, yaw, 0)
		_drive_mate(Vector2.ZERO, 0, false)
		await _wait(0.6)
		if not landed or arena.roof_at(_host.global_position) != i or not mate_landed:
			var h_along := Vector2(_host.global_position.x, _host.global_position.z).dot(d)
			failed += "roof %d (%s, heading %s) not reached: host at %s on roof %d (%.1f m past the near edge, roof y %.1f, top %.1f), mate landed %s; " % [i, HordeArena.LINK_NAMES[r.link], d, _host.global_position, arena.roof_at(_host.global_position), h_along - near, r.y, r.top, mate_landed]
			failed += "prev %d y %.1f top %.1f tier %s unit %s steps %d gap %.1f trail %s; " % [i - 1, prev.y, prev.top, prev.tier, prev.tier_unit, r.climb_steps, r.gap, trail]
	_check("every link of the route can be crossed by running, jumping, walking and climbing, whichever way it turns, with the partner on the chain (no layoffs)", failed == "" and GameState.wipes == wipes0, failed + "wipes %d -> %d" % [wipes0, GameState.wipes])
	# The raised parts: from where you land, up onto the part you leave from (one mantle, or a
	# unit and then a mantle when it's taller), the partner hauled up behind.
	var tier_fail := ""
	var tiers := 0
	for i in range(1, arena.roofs.size() - 1):
		var r: HordeArena.Roof = arena.roofs[i]
		if r.tier.size.x <= 0.0:
			continue
		tiers += 1
		var od := Vector3(r.out_dir.x, 0.0, r.out_dir.y)
		var has_unit := r.tier_unit != Vector3.ZERO
		var aim: Vector3 = r.tier_unit if has_unit else r.exit
		var inner := minf(r.tier.position.dot(r.out_dir), r.tier.end.dot(r.out_dir))
		var tside := arena._side(r.out_dir)
		var s2 := r.out_dir * (inner - (3.5 if has_unit else 2.5)) + tside * Vector2(aim.x, aim.z).dot(tside)
		var tyaw := atan2(-r.out_dir.x, -r.out_dir.y)
		var at := arena.origin + Vector3(s2.x, r.y + 0.1, s2.y)
		_host.teleport_to(at, tyaw)
		if _mate != null:
			_mate.teleport_to(at - od * 1.5, tyaw)
		await _wait(0.3)
		var up := false
		var ttrail := ""
		for k in 120:
			await _wait(0.05)
			if k % 8 == 0:
				ttrail += "[%.1f %.1f %s %d] " % [(Vector2(_host.global_position.x, _host.global_position.z) - Vector2(arena.origin.x, arena.origin.z)).dot(r.out_dir), _host.global_position.y - arena.origin.y, "F" if _host.is_on_floor() else "a", _host.state]
			_bot(r.out_dir, tyaw, 0, k % 6 == 0)
			if _mate is Player:
				_drive_mate(r.out_dir, 0, k % 6 == 3)
			if _host.global_position.y > arena.origin.y + r.top - 0.3:  # up (a buffered jump off the top is still up)
				up = true
				break
		_bot(Vector2.ZERO, tyaw, 0)
		_drive_mate(Vector2.ZERO, 0, false)
		await _wait(0.3)
		if not up:
			tier_fail += "roof %d tier %.1f m%s (roof y %.1f, unit %s, inner %.1f, heap %s): host at %s state %d knocked %s; trail %s; " % [i, r.top - r.y, " (unit)" if has_unit else "", r.y, r.tier_unit, inner, r.barrier, _host.global_position, _host.state, _host.is_knocked(), ttrail]
	_check("the roofs stand at their own heights: most have a raised part to climb before the next crossing (%d of them), and each can be climbed with the partner on the chain" % tiers, tier_fail == "" and tiers >= 3, tier_fail)
	# The heaps of fallen slabs across the walk: up over the top and down the other side.
	var heap_fail := ""
	var heaps := 0
	for i in range(1, arena.roofs.size() - 1):
		var r: HordeArena.Roof = arena.roofs[i]
		if r.barrier.size.x <= 0.0:
			continue
		heaps += 1
		var od2 := r.out_dir
		var bside := arena._side(od2)
		var b0 := minf(r.barrier.position.dot(od2), r.barrier.end.dot(od2))
		var b1 := maxf(r.barrier.position.dot(od2), r.barrier.end.dot(od2))
		# Across the heap where the walk over the roof crosses it (landing, run-up, way out): the
		# dressing keeps off that walk, not off any other line over the heap.
		var e2 := Vector2(r.enter.x, r.enter.z)
		var x2 := Vector2(r.exit.x, r.exit.z)
		var rn2 := x2 - od2 * HordeArena.RUN_UP
		var mid_b := r.barrier.get_center().dot(od2)
		var pick := e2
		for seg: Array in [[e2, rn2], [rn2, x2]]:
			var pa: Vector2 = seg[0]
			var pb: Vector2 = seg[1]
			var da := pa.dot(od2)
			var db := pb.dot(od2)
			if absf(db - da) > 0.01 and (mid_b - da) * (mid_b - db) <= 0.0:
				pick = pa.lerp(pb, (mid_b - da) / (db - da))
				break
		var s3 := od2 * (b0 - 1.6) + bside * pick.dot(bside)
		var byaw := atan2(-od2.x, -od2.y)
		var bat := arena.origin + Vector3(s3.x, r.y + 0.1, s3.y)
		_host.teleport_to(bat, byaw)
		if _mate != null:
			_mate.teleport_to(bat - Vector3(od2.x, 0.0, od2.y) * 1.2, byaw)
		await _wait(0.3)
		var over := false
		for k in 120:
			await _wait(0.05)
			var al_now := (Vector2(_host.global_position.x, _host.global_position.z) - Vector2(arena.origin.x, arena.origin.z)).dot(od2)
			_bot(od2, byaw, 0, k % 6 == 0 and al_now < b0 + 0.2)  # Space at the heap's face, not on top of it (that leaps onto what's beyond)
			if _mate is Player:
				_drive_mate(od2, 0, k % 6 == 3)
			var al := (Vector2(_host.global_position.x, _host.global_position.z) - Vector2(arena.origin.x, arena.origin.z)).dot(od2)
			if _host.is_on_floor() and al > b1 + 0.6:  # past it (an air grab off its top may land you on the raised part beyond: that's past it too)
				over = true
				break
		_bot(Vector2.ZERO, byaw, 0)
		_drive_mate(Vector2.ZERO, 0, false)
		await _wait(0.3)
		if not over:
			var al_h := (Vector2(_host.global_position.x, _host.global_position.z) - Vector2(arena.origin.x, arena.origin.z)).dot(od2)
			heap_fail += "roof %d heap %.1f m high (along %.1f..%.1f, roof y %.1f): host along %.1f y %.1f state %d knocked %s floor %s, mate %s; " % [i, r.barrier_h, b0, b1, arena.origin.y + r.y, al_h, _host.global_position.y, _host.state, _host.is_knocked(), _host.is_on_floor(), _mate.global_position if _mate != null else Vector3.ZERO]
	_check("heaps of fallen slabs lie across most roofs (%d of them), and each can be climbed over with the partner on the chain" % heaps, heap_fail == "" and heaps >= 3, heap_fail)
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


## The collapse up to roof i, the way a player climbs it: a run and a jump over the alley onto the
## first slab, then along each slab to its end and Space to grab the next, and from the top one a
## mantle onto the roof. The teammate (co-op) follows; a Ballast is hauled. "" when it made it.
func _climb_facade(i: int) -> String:
	var arena := _arena
	var r: HordeArena.Roof = arena.roofs[i]
	var prev: HordeArena.Roof = arena.roofs[i - 1]
	var d := r.dir
	var side := arena._side(d)
	var edge := prev.edge_along(d)
	var stage := -1  # -1: still on the roof below; s: standing on slab s
	var trail := ""
	var done := false
	for k in 500:
		await _wait(0.05)
		var lp := _host.global_position - arena.origin
		var l2 := Vector2(lp.x, lp.z)
		if _host.is_on_floor():
			for s in r.ledges.size():
				var c := Vector2(r.ledges[s].x, r.ledges[s].z)
				if absf(lp.y - r.ledges[s].y) < 0.35 and absf((l2 - c).dot(side)) < r.ledge_w[s] * 0.5 + 0.15 and absf((l2 - c).dot(d)) < r.ledge_out[s] * 0.5 + 0.15:
					stage = maxi(stage, s)
		if k % 10 == 0:
			trail += "[%d %.1f %.1f %s] " % [stage, (l2.dot(side)), lp.y, "F" if _host.is_on_floor() else "a"]
		if arena.roof_at(_host.global_position) == i and _host.is_on_floor() and lp.y > r.y - 0.3:
			done = true
			break
		var move := Vector2.ZERO
		var flags := 0
		var tap := false
		if stage < 0:
			# Across the roof below at a run, toward the first slab; jump at the edge.
			var to := Vector2(r.ledges[0].x, r.ledges[0].z) - l2
			move = to.normalized() if to.length() > 0.2 else d
			flags = Player.FLAG_RUN
			tap = _host.is_on_floor() and l2.dot(d) > edge - 0.5
		elif stage == r.ledges.size() - 1:
			move = d  # into the wall: the roof is a mantle up
			tap = k % 6 == 0
		else:
			# Along this slab to its end toward the next, kept in from the slab's outer edge; Space
			# while standing at the end.
			var c := Vector2(r.ledges[stage].x, r.ledges[stage].z)
			var nx := Vector2(r.ledges[stage + 1].x, r.ledges[stage + 1].z)
			var s_dir := signf((nx - c).dot(side))
			var end_c := c.dot(side) + s_dir * r.ledge_w[stage] * 0.5
			var off_d := (l2 - c).dot(d)
			var to_end := s_dir * (end_c - l2.dot(side))  # m left to the end
			move = (side * s_dir - d * clampf(off_d, -0.5, 0.5)).normalized() * (0.3 if to_end < 0.9 else 1.0)  # ease up to the end
			tap = _host.is_on_floor() and to_end < 0.3
		_bot(move, atan2(-move.x, -move.y) if move.length() > 0.1 else atan2(-d.x, -d.y), flags, tap)
		if _mate is Player:
			var mt := Vector2(_host.global_position.x - _mate.global_position.x, _host.global_position.z - _mate.global_position.z)
			_drive_mate(mt.normalized() if mt.length() > 1.4 else Vector2.ZERO, 0, k % 6 == 3)
	# Up: keep walking in from the edge, hauling up whoever is still hanging down the wall.
	for k in 30:
		await _wait(0.05)
		_bot(d, atan2(-d.x, -d.y), 0)
	_bot(Vector2.ZERO, atan2(-d.x, -d.y), 0)
	_drive_mate(Vector2.ZERO, 0, false)
	await _wait(0.8)
	if done and arena.roof_at(_host.global_position) == i:
		return ""
	return "roof %d (the collapse, %d slabs, %.1f m up, alley %.1f): host at %s on roof %d, reached slab %d; trail %s; " % [i, r.ledges.size(), r.y - prev.top, r.gap, _host.global_position, arena.roof_at(_host.global_position), stage, trail]


## Over one of the nest roofs (a hand's breadth past the edge still counts: a mite on the lip).
func _on_a_nest(arena: HordeArena, p: Vector3) -> bool:
	for k in arena.nests:
		if arena.roofs[k].rect.grow(0.8).has_point(Vector2(p.x - arena.origin.x, p.z - arena.origin.z)):
			return true
	return false


## A nest roof: landing on it floods it with mites out of its burst vents; they never leave that
## roof; and standing in them pulls you down.
func _test_nest() -> void:
	var arena := _arena
	_horde.debug_frozen = true
	for l in arena.launchers:
		l.debug_frozen = true
	await _wait(1.6)  # a layoff from the test before lands first
	var k: int = arena.nests[0]
	var r: HordeArena.Roof = arena.roofs[k]
	var spot := arena.origin + arena.landing_spot(k) + Vector3(0.0, 0.1, 0.0)
	# Re-arm it: earlier tests woke every nest and cleared the map. Back to "nobody has been here".
	for i in _horde.count:
		if _horde.tiny[i] == 1:
			_horde.state[i] = Horde.AState.GONE
	var rounds0 := arena.rounds_spawned
	arena.rounds_spawned = k + 1
	arena._rounds_done = k + 1
	r.reached = false
	_place(spot, 0.0)
	for i in 30:
		await _wait(0.1)
		if arena.rounds_spawned >= k + 2:
			break
	await _wait(0.3)
	var mites := 0
	for i in _horde.count:
		if _horde.tiny[i] == 1 and _horde.state[i] != Horde.AState.DEAD and _horde.state[i] != Horde.AState.GONE and arena.roof_under(_horde.agent_position(i)) == k:
			mites += 1
	_check("a nest roof floods with mites as you land on it (%d of them; nests on roofs %s)" % [mites, arena.nests], mites >= 40 and arena.rounds_spawned >= k + 2, "rounds %d" % arena.rounds_spawned)
	# Loose for a few seconds: they come for you, and stay on their roof.
	var wipes0 := GameState.wipes
	_horde.debug_frozen = false
	var pulled := false
	for i in 120:
		await _wait(0.1)
		_bot(Vector2.ZERO, 0.0, 0)
		if GameState.wipes > wipes0:
			pulled = true
			break
	_horde.debug_frozen = true
	var off := 0
	for i in _horde.count:
		if _horde.tiny[i] == 1 and _horde.state[i] != Horde.AState.DEAD and _horde.state[i] != Horde.AState.GONE and not _on_a_nest(arena, _horde.agent_position(i)):
			off += 1
	_check("the mites keep to their roof", off == 0, "%d off it" % off)
	_check("stand in a nest and they pull you down", pulled, "mauls %d" % _horde.mauls)
	await _wait(1.6)
	_horde.clear_near(arena.origin + r.center(), 60.0)
	arena.rounds_spawned = maxi(rounds0, arena.rounds_spawned)  # as far as the run had got before the re-arm


## The district: ROOF_COUNT roofs laid out from the seed with jumpable links, the field knowing
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
	var turns := 0
	var long_jumps := 0
	var facades := 0
	var broken := 0
	var heights: Array[float] = []
	for i in range(1, arena.roofs.size()):
		var r: HordeArena.Roof = arena.roofs[i]
		var prev: HordeArena.Roof = arena.roofs[i - 1]
		var dy := r.y - prev.top  # from where you leave: the top of the raised part, if it has one
		var side := arena._side(r.dir)
		var t := r.cross.dot(side)
		var lo_p := minf(prev.rect.position.dot(side), prev.rect.end.dot(side))
		var hi_p := maxf(prev.rect.position.dot(side), prev.rect.end.dot(side))
		var lo_r := minf(r.rect.position.dot(side), r.rect.end.dot(side))
		var hi_r := maxf(r.rect.position.dot(side), r.rect.end.dot(side))
		var inside := t > lo_p + 2.0 and t < hi_p - 2.0 and t > lo_r + 2.0 and t < hi_r - 2.0
		var ok := inside and r.y >= 0.0 and r.y <= HordeArena.ROOF_TOP_MAX + HordeArena.TOWER_RISE and r.dir.y <= 0.0
		if r.dir != HordeArena.NORTH:
			turns += 1
		heights.append(r.y)
		if i < arena.roofs.size() - 1:
			for v in r.vents:
				if arena._lane_distance(r, v) < 1.2:
					ok = false
					why += "roof %d has a vent on the walk across it; " % i
		# Clear of every roof but its neighbours.
		for j in range(0, i - 1):
			if arena.roofs[j].rect.grow(3.9).intersects(r.rect):
				ok = false
				why += "roof %d sits on roof %d; " % [i, j]
		match r.link:
			HordeArena.Link.JUMP:
				# Off the lot an easy one; after that within JUMP_SLACK of a sprint jump's full reach.
				var full := HordeArena.sprint_reach(dy)
				ok = ok and dy <= 0.01 and dy >= -2.7 and r.gap <= full - HordeArena.JUMP_SLACK.x + 0.01 and (i == 1 or r.gap >= full - HordeArena.JUMP_SLACK.y - 0.01)
				if i > 1:
					long_jumps += 1
			HordeArena.Link.LEAP:
				ok = ok and r.gap >= 2.7 and r.gap <= 3.7 and dy >= 1.3 and dy <= 2.0
			HordeArena.Link.PLANK, HordeArena.Link.PIPE:
				ok = ok and r.gap >= 6.4 and r.gap <= 11.1 and absf(dy) < 0.01
				if r.plank_break != Vector2.ZERO:
					broken += 1
					var b := r.plank_break.y - r.plank_break.x
					ok = ok and b >= HordeArena.PLANK_BREAK.x - 0.01 and b <= HordeArena.PLANK_BREAK.y + 0.01 and r.plank_break.x > 2.0 and r.plank_break.y < r.gap - 2.0
			HordeArena.Link.DROP:
				ok = ok and r.gap >= 2.9 and r.gap <= 4.1 and dy <= -3.3
			HordeArena.Link.CLIMB:
				ok = ok and r.gap == 0.0 and dy >= 2.5 and dy <= (HordeArena.TOWER_RISE + 0.01 if i == arena.roofs.size() - 1 else HordeArena.CLIMB_STEP * float(r.climb_steps) + 2.05)
			HordeArena.Link.STONES:
				ok = ok and r.stones.size() >= 3 and r.gap > 15.0 and dy <= 0.01
			HordeArena.Link.FACADE:
				# Slab to slab up a wall: each a standing grab above the last, never over the one
				# below, the top one a mantle under the roof.
				facades += 1
				ok = ok and r.gap >= HordeArena.FACADE_GAP.x - 0.01 and r.gap <= HordeArena.FACADE_GAP.y + 0.01 and dy >= HordeArena.FAR_UP.x - 0.01 and r.ledges.size() >= 2
				var below := prev.top
				for s in r.ledges.size():
					var rise := r.ledges[s].y - below
					ok = ok and rise >= HordeArena.LEDGE_RISE.x - 0.01 and rise <= HordeArena.LEDGE_RISE.y + 0.01
					if s > 0:
						var apart := absf((Vector2(r.ledges[s].x, r.ledges[s].z) - Vector2(r.ledges[s - 1].x, r.ledges[s - 1].z)).dot(side))
						ok = ok and apart >= (r.ledge_w[s] + r.ledge_w[s - 1]) * 0.5 + HordeArena.LEDGE_SIDE_GAP.x - 0.01
					below = r.ledges[s].y
				var lip := r.y - below
				ok = ok and lip >= 1.19 and lip <= 1.96
			HordeArena.Link.GIRDERS:
				# Each gap a walking jump, each gap plus its beam past a sprint jump's reach.
				ok = ok and r.girders.size() >= 4 and dy <= 0.01
				for g in r.girder_len.size():
					ok = ok and r.girder_len[g] >= HordeArena.GIRDER_LEN.x - 0.01
		if not ok:
			links_ok = false
			why += "roof %d link %d heading %s gap %.1f dy %.1f inside %s; " % [i, r.link, r.dir, r.gap, dy, inside]
	heights.sort()
	var spread := heights[heights.size() - 2] - heights[0]  # the route's roofs, not the tower
	print("[smoke] links: %s; %d long jumps, %d snapped planks, %d collapses; heights %s" % [", ".join(PackedStringArray(arena.roofs.slice(1).map(func(r: HordeArena.Roof) -> String: return HordeArena.LINK_NAMES[r.link]))), long_jumps, broken, facades, heights])
	_check("%d roofs and the tower scattered at their own heights (not a line: %d turns, %.1f m between lowest and highest), every link within reach, the crossing inside both roofs and clear of vents, no roof on another" % [HordeArena.ROOF_COUNT, turns, spread], links_ok and arena.roofs.size() == HordeArena.ROOF_COUNT + 2 and turns >= 1 and spread > 20.0, why)
	_check("no green route signs: nothing but the red light points the way", arena.find_children("*", "Label3D", true, false).filter(func(l: Node) -> bool: return (l as Label3D).modulate.g > 0.9 and (l as Label3D).modulate.r < 0.6).is_empty(), "")
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
	# A Weaver on the roof behind you swings the gap on a thread. (None come in waves now; the
	# crowd tech still supports them, so the test brings one.)
	var wk := 2
	while wk < arena.roofs.size() - 2 and (arena.roofs[wk].link == HordeArena.Link.CLIMB or arena.roofs[wk].link == HordeArena.Link.STONES or arena.roofs[wk].link == HordeArena.Link.GIRDERS or arena.roofs[wk].link == HordeArena.Link.FACADE):
		wk += 1  # a link with open street to swing across
	var r2: HordeArena.Roof = arena.roofs[wk]
	var r_from: HordeArena.Roof = arena.roofs[wk - 1]
	var d2 := Vector3(r2.dir.x, 0.0, r2.dir.y)
	var stand := arena.origin + r2.enter + d2 * 1.0
	_host.teleport_to(stand, 0.0)
	if _mate != null:
		_mate.teleport_to(stand + d2 * 1.5, 0.0)
	_horde.clear_near(arena.origin, 500.0)  # the rest of the swarm climbs and leaps too now: keep it out of this
	for k: int in [Horde.KIND_WEAVER, Horde.KIND_ROACH]:
		await _agent_crosses_and_climbs(k, wk, r_from, d2)
	_horde.debug_frozen = true
	# The route's Jumper crosses from its roof to you on the next (a thread, or up the wall).
	# A roof whose next crossing has open air to swing over (a jump, a leap, a plank or a pipe): the
	# route's Jumper is brought there. (Where it waits, roof 7, the next can be a 16 m wall.)
	var jk: int = HordeArena.JUMPER_ROOFS[0]
	for k in range(2, arena.roofs.size() - 2):
		var lk: int = arena.roofs[k + 1].link
		if lk == HordeArena.Link.JUMP or lk == HordeArena.Link.LEAP or lk == HordeArena.Link.PLANK or lk == HordeArena.Link.PIPE:
			jk = k
			break
	var jumper: Launcher = arena.launchers[HordeArena.LOT_JUMPERS]
	var r3: HordeArena.Roof = arena.roofs[jk]
	var r4: HordeArena.Roof = arena.roofs[jk + 1]
	var d4 := Vector3(r4.dir.x, 0.0, r4.dir.y)
	var there := arena.origin + r4.enter
	var deep := absf(r4.rect.size.dot(r4.dir))  # how far the roof runs the way you came in
	# Out of lunge range: it has to cross first. Up a climb (a wall up to 6.8 m) it has to SEE you to
	# come up the face, so you stand at the lip.
	var room4 := deep - 3.0
	if r4.tier.size.x > 0.0:
		# Not inside its raised part: in front of it.
		room4 = minf(r4.tier.position.dot(r4.dir), r4.tier.end.dot(r4.dir)) - Vector2(r4.enter.x, r4.enter.z).dot(r4.dir) - 0.8
	# (Just past where you land: further in there may be the raised part or a heap of slabs.)
	var stand4 := there - d4 * 1.0 if r4.link == HordeArena.Link.CLIMB else there + d4 * clampf(minf(room4, 0.6), 0.3, 4.0)
	_host.teleport_to(stand4, 0.0)
	if _mate != null:
		_mate.teleport_to(stand4 + d4 * (1.0 if r4.link == HordeArena.Link.CLIMB else -1.0), 0.0)  # on the roof, not in its raised part
	_bot(Vector2.ZERO, 0.0, 0)
	await _wait(0.3)
	# At the edge: from further back the lip hides a roof far below or far above, and it only
	# goes after someone it can see.
	var back4 := 0.0
	if r4.link == HordeArena.Link.CLIMB:
		# Behind the slab heap or the leaning slab's foot, not inside them (exit is 1.6 m from the wall).
		back4 = (r4.ramp + 1.0 if r4.ramp > 0.0 else HordeArena.CLIMB_STEP_DEPTH * float(r4.climb_steps) + 0.4) - 1.6
	jumper.debug_reset(arena.origin + r3.exit - d4 * back4)
	jumper.debug_frozen = false
	var crossed := false
	var how := ""
	for i in 170:  # a crossing of stumps is several swings
		await _wait(0.1)
		if jumper.lstate == Launcher.LState.SWING:
			how = "swing"
		elif jumper.lstate == Launcher.LState.LUNGE and how == "":
			how = "jump"
		elif jumper.lstate == Launcher.LState.CLIMB and how == "":
			how = "climb"
		if arena.roof_at(jumper.global_position) == jk + 1:
			crossed = true
			if how == "":
				how = "walk"  # over a plank or a duct
			break
	jumper.debug_frozen = true
	_check("the Jumper on the roof behind crosses to yours (link: %s)" % HordeArena.LINK_NAMES[r4.link], crossed and how != "", "crossed %s by %s, state %d, at roof %d" % [crossed, how, jumper.lstate, arena.roof_at(jumper.global_position)])
	jumper.debug_reset(arena.launcher_homes[HordeArena.LOT_JUMPERS])
	jumper.release(false)
	await _wait(0.5)


## One of a kind (a Weaver on its thread, a roach with a leap) at the edge of the roof behind you
## crosses the gap to yours, then from the foot of the tower climbs its face to the helipad.
func _agent_crosses_and_climbs(k: int, wk: int, r_from: HordeArena.Roof, d2: Vector3) -> void:
	var arena := _arena
	var r2: HordeArena.Roof = arena.roofs[wk]
	var label := "Weaver" if k == Horde.KIND_WEAVER else "roach"
	_horde.debug_frozen = true
	var stand := arena.origin + r2.enter + d2 * 1.0
	_host.teleport_to(stand, 0.0)
	if _mate != null:
		_mate.teleport_to(stand + d2 * 1.5, 0.0)
	var from := arena.origin + r_from.exit - d2 * 1.0
	var weights: Array[float] = [0.0, 1.0, 0.0]
	if k == Horde.KIND_ROACH:
		weights = [1.0, 0.0, 0.0]
	_horde.spawn_group(1, Rect2(from.x - 0.5, from.z - 0.5, 1.0, 1.0), 4242 + k, weights)
	var agent := _horde.count - 1
	_horde.place(agent, from)
	await _wait(0.6)
	_horde.debug_frozen = false
	var swung := false
	var arrived := false
	for i in 60:
		await _wait(0.1)
		if _horde.state[agent] == Horde.AState.SWING:
			swung = true
		if swung and _horde.state[agent] == Horde.AState.WALK and arena.roof_at(_horde.agent_position(agent)) == wk:
			arrived = true
			break
	_check("a %s at the edge of the roof behind you %s the gap and lands on yours" % [label, "swings" if k == Horde.KIND_WEAVER else "leaps"], swung and arrived,
		"swung %s, arrived %s, state %d, at %s from %s; roof %d heading %s link %d" % [swung, arrived, _horde.state[agent], _horde.agent_position(agent), from, wk, r2.dir, r2.link])
	_horde.debug_frozen = true
	var tower: HordeArena.Roof = arena.roofs[arena.roofs.size() - 1]
	var last: HordeArena.Roof = arena.roofs[arena.roofs.size() - 2]
	var pad: Vector3 = arena.test_points["helipad"]
	_host.teleport_to(pad + Vector3(0.0, 0.0, 3.0), 0.0)
	if _mate != null:
		_mate.teleport_to(pad + Vector3(1.5, 0.0, 1.0), 0.0)
	# At the foot of the tower's face. Whether the flow field leads up the face from a given spot
	# depends on the layout (the fire-escape landings are floors too), so it tries a few along the
	# foot: on the last roof, under the tower, and passes when it climbs from one of them.
	var spots: Array[float] = [tower.rect.get_center().x + 4.0]
	var lo_x := maxf(tower.rect.position.x, last.rect.position.x) + 1.2
	var hi_x := minf(tower.rect.end.x, last.rect.end.x) - 1.2
	var fx := lo_x
	while fx <= hi_x and spots.size() < 5:
		var clear := absf(fx - arena._escape_x()) > 1.6  # the dumpster at the foot
		for s in arena.escape_steps:
			if absf(fx - s.x) < arena._escape_step_w(tower) * 0.5 + 0.6:
				clear = false
		if clear:
			spots.append(fx)
			fx += 3.0
		else:
			fx += 0.5
	# Up the face to the pad, or (the leap reaches 12-13 m) up the fire escape landing by landing:
	# either counts once it's well up the tower.
	var climbed := false
	var up := false
	var risen := 0.0
	for foot_x in spots:
		_horde.debug_frozen = true
		_horde.place(agent, arena.origin + Vector3(foot_x, last.y, tower.rect.end.y + 1.5))
		await _wait(0.4)
		_horde.debug_frozen = false
		climbed = false
		for i in 60:
			await _wait(0.1)
			risen = maxf(risen, _horde.py[agent] - (arena.origin.y + last.y))
			if _horde.state[agent] == Horde.AState.CLIMB:
				climbed = true
			if climbed and _horde.state[agent] != Horde.AState.CLIMB and _horde.py[agent] > pad.y - 0.5:
				up = true
				break
			if not climbed and i >= 45:
				break  # not going anywhere from here
		if up:
			break
	var ok := climbed and up
	ok = ok or risen > HordeArena.TOWER_RISE * 0.55
	_check("a %s below the helipad gets up the tower after you (its face or the fire escape)" % label, ok, "climbed %s, up %s, rose %.1f m, state %d, y %.1f (pad %.1f)" % [climbed, up, risen, _horde.state[agent], _horde.py[agent], pad.y])
	_horde.debug_frozen = true
	_horde.clear_near(_horde.agent_position(agent), 3.0)


# --- The Loading Lot (--arena): the Level 3 tech ------------------------------------------------------

var _arena: HordeArena
var _horde: Horde


func _run_arena(arena: HordeArena) -> void:
	Player.debug_infinite_stamina = true  # the route is about parkour, not breath
	_arena = arena
	_horde = arena.horde
	_host.bot_controlled = true
	await _wait(0.6)
	var bodies := Net.get_chain_bodies()
	_mate = bodies[1] if bodies.size() > 1 else null
	_check("arena built: field, a handful of the swarm (the user: less of them), the Jumpers, the route, loot, the nests", _horde.count >= 5 and _horde.count <= 20 and arena.nests.size() == HordeArena.NEST_COUNT and _horde.count < arena.horde_count and arena.launchers.size() == HordeArena.LOT_JUMPERS + HordeArena.JUMPER_ROOFS.size() and arena.field.cell_count() > 9000 and arena.roofs.size() == HordeArena.ROOF_COUNT + 2 and get_tree().get_nodes_in_group("pickups").size() >= 10,
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
	await _test_stare()
	await _test_horde_perf()
	await _test_district()
	await _test_route()
	await _test_nest()
	await _test_lot_clear()
	_finish()


## Clearing the lot: the three tasks done, then everyone back on the pad clocks out.
func _test_lot_clear() -> void:
	await _test_roof_scares()
	await _test_roof_dread()
	await _escape_by_helicopter(_arena, _arena.test_points, "")


func _test_roof_scares() -> void:
	var lot := _arena if _arena != null else _stack.lot
	lot.horde.debug_frozen = true
	for l in lot.launchers:
		l.debug_frozen = true
	_place(lot.test_points["spawn"], 0.0)
	var before := ScareDirector.scares_played
	for kind: String in ["roof_scrape", "roof_shadow", "roof_swarm"]:
		ScareDirector.trigger_for(kind, _host)
		await _wait(0.1)
	var shown := lot.find_children("RoofScare*", "MeshInstance3D", true, false).size()
	await _wait(2.0)
	_check("roof scares play and their temporary silhouettes clean up", ScareDirector.scares_played >= before + 3 and shown >= 6 and lot.find_children("RoofScare*", "MeshInstance3D", true, false).is_empty(), "scares %d, silhouettes %d" % [ScareDirector.scares_played - before, shown])


## The roof's horror pacing (RoofDread): darker night, no scare while a bug is close, the hush
## (wind and swarm silent, heartbeat, a lamp out) before every scare, the scripted ones waiting
## for quiet too, the Tall Tenant glimpsed and gone, landing lamps dying as you come near.
func _test_roof_dread() -> void:
	var lot: HordeArena = _arena if _arena != null else _stack.lot
	var lvl: Node = _arena if _arena != null else _stack
	var dread := lot.dread
	var horde := lot.horde
	horde.debug_frozen = true
	for i in lot.launchers.size():
		var l: Launcher = lot.launchers[i]
		l.debug_frozen = true
		if l.is_hunting():
			l.debug_reset(lot.launcher_homes[i])  # one an earlier test froze mid-lunge would keep it from ever going quiet
	var env := LevelKit.make_environment(2, 2)
	var beacon_mat := LevelKit.mat("beacon") as StandardMaterial3D
	_check("the roof's night is dark and fogged; the tower's red light ignores the fog", env.ambient_light_energy <= 0.08 and env.fog_density >= 0.03 and beacon_mat.disable_fog and lot.beacon != null and lot.beacon.omni_range >= 40.0, "ambient %.3f, fog %.3f" % [env.ambient_light_energy, env.fog_density])
	_check("the ScareDirector's timer leaves the roof to its own pacing", bool(lvl.call("paces_own_scares", _host.global_position)), "")
	dread._cool = 999.0  # nothing builds while the test sets up
	dread._build_t = -1.0  # and nothing left building from before
	var r2d: HordeArena.Roof = lot.roofs[2]
	var spot := lot.origin + r2d.enter + Vector3(r2d.dir.x, 0.0, r2d.dir.y) * 1.5 + Vector3(0.0, 0.1, 0.0)  # where you land: never up on its raised part
	_place(spot, 0.0)
	await _wait(0.5)
	dread._glimpse_t = 999.0
	dread._pending.clear()
	horde.clear_near(spot, 90.0)
	horde.place(0, spot + Vector3(4.0, 0.0, 0.0))
	horde.closest_d2 = 16.0  # the next active pick says the same; don't race it
	dread._quiet = 0.0
	dread._cool = 0.0
	dread._need = 1.5
	var b0 := dread.builds
	await _wait(3.0)
	_check("no scare builds while a bug is close: it has to go quiet first", dread.builds == b0 and dread._quiet == 0.0, "builds %d, nearest %.1f m" % [dread.builds - b0, sqrt(horde.closest_d2)])
	horde.clear_near(spot, 90.0)
	var heard := dread.hushes_heard
	var played := ScareDirector.scares_played
	for k in 50:
		await _wait(0.1)
		if dread.builds > b0:
			break
	await _wait(0.3)
	_check("once it's quiet the build starts: the wind and the swarm drop away, the heartbeat", dread.builds == b0 + 1 and dread.hushes_heard > heard and dread.hushed() and horde.muted and dread.is_building(), "builds %d, heard %d" % [dread.builds - b0, dread.hushes_heard - heard])
	await _wait(RoofDread.HUSH_SECONDS + 0.4)
	_check("after the silence the scare lands (or only a glimpse)", not dread.is_building() and dread.fired.size() >= 1 and ScareDirector.scares_played >= played + 1, "ended in '%s'" % (dread.fired.back() if not dread.fired.is_empty() else "?"))
	# A scripted one (the spider roofs) waits its turn and still gets the hush first.
	dread._cool = 999.0
	var n := dread.fired.size()
	dread.queue("roof_drop", _host, 0.0)
	for k in 30:
		await _wait(0.1)
		if dread.is_building():
			break
	var building := dread.is_building()
	await _wait(RoofDread.HUSH_SECONDS + 0.4)
	_check("a scripted spider drop is built like the rest: hush, silence, then the spider", building and dread.fired.size() == n + 1 and dread.fired.back() == "roof_drop", "")
	# The Tall Tenant: past the edge of a lamp, and gone when you come close.
	var gs := dread.glimpse_spot(_host)
	var flat := Vector2(gs.x - _host.global_position.x, gs.z - _host.global_position.z).length() if gs != Vector3.INF else -1.0
	_check("the Tall Tenant gets a spot on a roof, out past the light, at a distance", gs != Vector3.INF and lot.roof_under(gs) >= 0 and flat >= 15.0 and flat <= 34.0, "%.1f m" % flat)
	if gs != Vector3.INF:
		var s := dread.spawn_glimpse(gs)
		await _wait(0.3)
		var stood := is_instance_valid(s) and not s.is_leaving()
		var under := lot.roofs[lot.roof_under(gs)]
		_place(gs.lerp(lot.origin + under.center(), 0.3) + Vector3(0.0, 0.1, 0.0), 0.0)
		await _wait(0.8)
		_check("it stands there while nobody comes near, and steps back into the dark when you do", stood and not is_instance_valid(s), "")
	# A landing lamp that dies as the Line comes near (the route test may have killed it already).
	var dying: OmniLight3D = null
	for lamp in lot.lamps:
		if bool(lamp.get_meta("can_die", false)):
			dying = lamp
			if int(lamp.get_meta("die_at", 0)) == 0:
				break
	if dying != null:
		var lp := dying.global_position
		_place(Vector3(lp.x, lp.y - 4.9, lp.z), 0.0)
		await _wait(0.25 + float(RoofDread.LAMP_GUTTER_MSEC) * 0.001 + 0.5)
	_check("landing lamps gutter and die as you come near", dying != null and bool(dying.get_meta("dead", false)) and dying.light_energy < float(dying.get_meta("base_energy")) * 0.2 and dread.lamps_died >= 1, "%d died" % dread.lamps_died)
	_check("the roof skitters: vents ahead and under your feet, heard before they're seen", dread.skitters >= 1, "%d" % dread.skitters)
	horde.muted = false


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
	if _horde.count < 30:
		# The lot only has a handful now (the user: "less of them"): these checks borrow by index.
		_horde.spawn_group(30 - _horde.count, Rect2(spawn.x - 40.0, spawn.z - 75.0, 80.0, 20.0), 777)
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
	# The Flitters: they fly, they dive at you, and they never hang on the chain. (No wave brings
	# them any more; the crowd tech still supports them, so the test brings one.)
	_arena.debug_spawn_all_rounds()
	_horde.spawn_group(1, Rect2(spawn.x - 0.5, spawn.z + 1.0, 1.0, 1.0), 4343, [0.0, 0.0, 1.0] as Array[float])
	var bat := -1
	for i in _horde.count:
		if _horde.kind[i] == Horde.KIND_FLITTER and _horde.state[i] == Horde.AState.WALK:
			bat = i
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


## The Jumper doesn't move while you look straight at it; look away and it comes, faster than you
## walk.
func _test_stare() -> void:
	var spawn: Vector3 = _arena.test_points["spawn"]
	_horde.debug_frozen = true
	await _wait(1.6)  # a layoff from the test before lands first
	var l := _arena.launchers[0]
	_host.teleport_to(spawn, 0.0)
	if _mate != null:
		_mate.teleport_to(spawn + Vector3(1.0, 0.0, 1.5), 0.0)
	l.debug_reset(spawn + Vector3(0.0, 0.0, -16.0))
	await _wait(0.3)
	var look := l.chest_point() - _host.eye_position()
	var at_it := atan2(-look.x, -look.z)
	var down := atan2(look.y, Vector2(look.x, look.z).length())
	l.debug_frozen = false
	var d0 := l.global_position.distance_to(_host.global_position)
	var held := true
	for i in 15:
		_host._apply_input(Vector2.ZERO, at_it, down, 0)
		await _wait(0.1)
		held = held and l.stared
	var d1 := l.global_position.distance_to(_host.global_position)
	_check("looked at, the Jumper doesn't take a step (it stares back)", held and absf(d1 - d0) < 0.3, "stared %s, %.1f -> %.1f m" % [held, d0, d1])
	for i in 15:
		_host._apply_input(Vector2.ZERO, at_it + PI, 0.0, 0)  # turn your back on it
		await _wait(0.1)
	var d2 := l.global_position.distance_to(_host.global_position)
	l.debug_frozen = true
	_check("look away and it comes, faster than you walk", not l.stared and d1 - d2 > 4.0, "%.1f -> %.1f m in 1.5 s" % [d1, d2])
	l.debug_reset(_arena.launcher_homes[0])
	_bot(Vector2.ZERO, 0.0, 0)


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
	# The waves are a few hundred now; the budget is still checked at a thousand (the crowd tech's
	# headroom for later levels).
	_horde.spawn_group(maxi(0, 1000 - _horde.count), Rect2(_arena.origin.x - 44.0, _arena.origin.z - 46.0, 88.0, 40.0), 5151, [1.0, 0.0, 0.0] as Array[float])
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
	_check("client: the host's world config arrived and the Lot was rebuilt (joined with no --arena)", bool(Net.world_config.get("arena", false)) and arena.horde.count >= 100 and bool(main.get("_rejoined")), "config %s, rejoined %s" % [Net.world_config, main.get("_rejoined")])
	if only == "lot_clear":
		var moving := false
		var previous := arena.heli_position()
		for i in 180:
			await _wait(0.25)
			moving = moving or (arena.heli_fraction == 1.0 and arena.heli_position().distance_to(previous) > 0.1)
			previous = arena.heli_position()
			if GameState.escaped:
				break
		_check("client: moving helicopter clock and escape replicate", moving and GameState.escaped and arena.heli_elapsed > 0.0, "moving %s, escaped %s, clock %.2f" % [moving, GameState.escaped, arena.heli_elapsed])
		_finish()
		return
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


## The partner just past a Hire's RESCUE_RADIUS behind the host, still on the chain: "nobody
## helping" holds whatever the room size (the 6 m rooms used to put a wall between them).
func _park_mate_clear() -> void:
	if _mate == null:
		return
	_mate.teleport_to(_host.global_position + Vector3(0.0, 0.0, -(HollowHire.RESCUE_RADIUS + 0.9)), 0.0)


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
