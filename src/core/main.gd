extends Node
## Root flow: title -> world -> end screen. The world (level, spawners, effects, Ballast, chain) is
## built identically on every peer BEFORE any network traffic, so node paths match everywhere.
##
## Command line (everything after "--", or bare):
##   --solo | --host | --join=IP   start straight away        --name=Bob   player name
##   --remote / --no-remote        force Remote Controls for this session
##   --port=N                      host or join on another port
##   --fake-build=X                pretend to be another build (tests the version check)
##   --smoke [--smoke-players=N] / --smoke-client             run tests/smoke_test.gd
##   --smoke-only=NAME             run just _test_NAME (e.g. crouch, p_lift) after the setup checks
##   --shots=DIR                                              save screenshots (tests/screenshots.gd)
##   --arena [--horde=N]           the Loading Lot: the Level 3 horde test block instead of the building
##   --seed=N                      build the building from this seed (the title picks a random one;
##                                 command-line runs default to the fixed test seed)
##   --bench=SECONDS               print the frame rate after that long, then quit
##   --bots=N                      host N extra players nobody controls (load tests: a six-body Line)
##
## The host's world config (seed, lot or building, crowd size) travels in the join handshake: a
## joiner who built something else is sent the host's config, rebuilds, and joins again.

var title: TitleMenu
var settings_panel: SettingsPanel
var pause_menu: PauseMenu
var end_screen: EndScreen
var hud: Hud
var screen_fx: ScreenFx
var world: Node3D
var backdrop: MenuBackdrop
var in_game: bool = false
var bots: int = 0
var _settings_from_pause: bool = false
var _join_ip: String = ""
var _join_port: int = Net.DEFAULT_PORT
var _join_name: String = ""
var _rejoined: bool = false  # this join already rebuilt the world once for the host's config
var _bench_t: float = -1.0
var _bench_frames: int = 0
var _bench_sample_t: float = 1.0
var _bench_samples: Array[int] = []


func _ready() -> void:
	Settings.load_settings()
	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	if args.has("--remote"):
		Settings.remote_mode = true
	elif args.has("--no-remote"):
		Settings.remote_mode = false
	Settings.apply()
	get_window().min_size = Vector2i(960, 540)
	screen_fx = ScreenFx.new()
	add_child(screen_fx)
	hud = Hud.new()
	hud.screen_fx = screen_fx
	hud.visible = false
	add_child(hud)
	var ui := CanvasLayer.new()
	ui.layer = 20
	add_child(ui)
	title = TitleMenu.new()
	ui.add_child(title)
	title.solo_requested.connect(func(n: String) -> void: _start("solo", n, "", 0, true))
	title.host_requested.connect(func(n: String, port: int) -> void: _start("host", n, "", port, true))
	title.join_requested.connect(func(n: String, ip: String, port: int) -> void: _start("join", n, ip, port, true))
	title.settings_requested.connect(func() -> void: _open_settings(false))
	pause_menu = PauseMenu.new()
	pause_menu.visible = false
	ui.add_child(pause_menu)
	pause_menu.resume_requested.connect(_resume)
	pause_menu.settings_requested.connect(func() -> void: _open_settings(true))
	pause_menu.leave_requested.connect(func() -> void: _leave_to_title(""))
	pause_menu.regroup_requested.connect(func() -> void:
		GameState.request_regroup(Net.local_name)
		_resume())
	end_screen = EndScreen.new()
	end_screen.visible = false
	ui.add_child(end_screen)
	end_screen.menu_requested.connect(func() -> void: _leave_to_title(""))
	settings_panel = SettingsPanel.new()
	settings_panel.visible = false
	ui.add_child(settings_panel)
	settings_panel.closed.connect(_on_settings_closed)
	Net.disconnected_from_game.connect(_leave_to_title)
	Net.connection_failed.connect(_leave_to_title)
	Net.world_mismatch.connect(_on_world_mismatch)
	GameState.escaped_changed.connect(_on_escaped)
	_show_title("")
	if Settings.remote_autodetected:
		title.show_status("TeamViewer detected: Remote Controls are ON (smooth keys over TeamViewer; arrows walk/turn, R auto-walk). Change it in Settings.")
	if DisplayServer.get_name() != "headless":
		await get_tree().process_frame
		Sfx.warmup()
	_handle_cmdline(args)


func _exit_tree() -> void:
	# Static caches hold resources for the whole session; drop them so exit is leak-free.
	Sfx._cache.clear()
	Sfx._one_shots.clear()
	LevelKit._mats.clear()
	HordeMesh._meshes.clear()
	HordeMesh._materials.clear()
	ItemRegistry._by_id.clear()
	UiTheme._theme = null
	UiTheme._title = null
	UiTheme._body = null


func _handle_cmdline(args: PackedStringArray) -> void:
	var player_name := ""
	var mode := ""
	var ip := ""
	var smoke := ""
	var smoke_players := 1
	var smoke_only := ""
	var shots := ""
	var port := Net.DEFAULT_PORT
	var cfg := Net.default_world_config()
	for a in args:
		if a.begins_with("--port="):
			port = clampi(a.trim_prefix("--port=").to_int(), 1, 65535)
		elif a == "--host":
			mode = "host"
		elif a == "--solo":
			mode = "solo"
		elif a == "--join":
			mode = "join"
			ip = "127.0.0.1"
		elif a.begins_with("--join="):
			mode = "join"
			ip = a.trim_prefix("--join=")
		elif a.begins_with("--name="):
			player_name = a.trim_prefix("--name=")
		elif a.begins_with("--fake-build="):
			Net.set_build_id_override(a.trim_prefix("--fake-build="))
		elif a == "--smoke":
			smoke = "host"
		elif a == "--smoke-client":
			smoke = "client"
		elif a.begins_with("--smoke-players="):
			smoke_players = maxi(1, a.trim_prefix("--smoke-players=").to_int())
		elif a.begins_with("--smoke-only="):
			smoke_only = a.trim_prefix("--smoke-only=")
		elif a.begins_with("--shots="):
			shots = a.trim_prefix("--shots=")
			if mode == "":
				mode = "solo"
		elif a == "--arena":
			cfg["arena"] = true
		elif a.begins_with("--horde="):
			cfg["horde"] = clampi(a.trim_prefix("--horde=").to_int(), 0, Horde.MAX_AGENTS)
		elif a.begins_with("--seed="):
			cfg["seed"] = a.trim_prefix("--seed=").to_int()
		elif a.begins_with("--bench="):
			_bench_t = maxf(1.0, a.trim_prefix("--bench=").to_float())
		elif a.begins_with("--bots="):
			bots = clampi(a.trim_prefix("--bots=").to_int(), 0, Net.MAX_PLAYERS - 1)
		elif a.begins_with("--title-shot="):
			title.set_arena(bool(cfg["arena"]))
			var cam_title: Node = load("res://tests/screenshots.gd").new()
			cam_title.set("out_dir", a.trim_prefix("--title-shot="))
			cam_title.set("title_only", true)
			add_child(cam_title)
			return
	title.set_arena(bool(cfg["arena"]))
	if mode == "":
		return
	if player_name == "":
		player_name = title.player_name()
	Net.world_config = cfg
	_start(mode, player_name, ip, port, false)
	if world == null:
		return
	if bots > 0 and multiplayer.is_server():
		# Extra bodies on the Line with nobody behind them: they stand where they spawn.
		for k in bots:
			Net.call("_spawn_player_for", 1000 + k, "Bot %d" % (k + 1))
	if smoke != "":
		var test: Node = load("res://tests/smoke_test.gd").new()
		test.name = "SmokeTest"
		test.set("is_client", smoke == "client")
		test.set("expected_players", smoke_players)
		test.set("only", smoke_only)
		add_child(test)
	if shots != "":
		var cam_test: Node = load("res://tests/screenshots.gd").new()
		cam_test.name = "Screenshots"
		cam_test.set("out_dir", shots)
		add_child(cam_test)


# --- Flow ------------------------------------------------------------------------------------

## from_title: a fresh random building (or the Lot the title has selected); a joiner starts with
## the default building and is handed the host's config if it differs.
func _start(mode: String, player_name: String, ip: String, port: int, from_title: bool) -> void:
	if from_title:
		Net.world_config = Net.random_world_config(title.arena_selected()) if mode != "join" else Net.default_world_config()
	_rejoined = false
	_join_ip = ip
	_join_port = port
	_join_name = player_name
	_build_world()
	var err := OK
	match mode:
		"solo":
			err = Net.start_solo(player_name)
		"host":
			err = Net.host(port, player_name)
		"join":
			err = Net.join(ip, port, player_name)
	if err != OK:
		_teardown_world()
		title.show_status("Couldn't start (%s, error %d). If hosting, is another copy already hosting?" % [mode, err])
		return
	_enter_game(mode.to_upper(), player_name)
	if multiplayer.is_server():
		var level := world.get_node("Level")
		level.call("server_populate")
		ScareDirector.reset_director()
		if mode == "host":
			GameState.post_message("You're hosting. Press Esc to copy the invite code for your friends.", 6.0)
	else:
		GameState.post_message_local("Connecting to %s ..." % ip, 5.0)


func _enter_game(role: String, player_name: String) -> void:
	in_game = true
	if backdrop != null:
		backdrop.queue_free()
		backdrop = null
	title.visible = false
	end_screen.visible = false
	pause_menu.visible = false
	hud.visible = true
	hud.reset()
	_set_ui_blocking(false)
	get_window().title = "CHAINS DEEZNUTS TOGETHER - %s - %s" % [role, player_name]


func _show_title(reason: String) -> void:
	in_game = false
	title.visible = true
	title.show_status(reason)
	hud.visible = false
	pause_menu.visible = false
	end_screen.visible = false
	screen_fx.fade = 0.0
	if backdrop == null:
		backdrop = MenuBackdrop.new()
		backdrop.name = "Backdrop"
		add_child(backdrop)
	GameState.ui_blocking = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_window().title = "CHAINS DEEZNUTS TOGETHER"


func _leave_to_title(reason: String) -> void:
	Net.leave()
	_teardown_world()
	_show_title(reason)


## The host builds another world than ours (its own seed, or the Loading Lot): hang up, build
## theirs, and join again. Once; a second mismatch means something is really wrong.
func _on_world_mismatch(config: Dictionary) -> void:
	if _rejoined or not in_game:
		_leave_to_title("Couldn't build the host's world. Try joining again.")
		return
	_rejoined = true
	Net.leave()
	_teardown_world()
	Net.world_config = config
	_build_world()
	GameState.post_message_local("Building the host's %s ..." % ("Loading Lot" if bool(config.get("arena", false)) else "building"), 4.0)
	var err := Net.join(_join_ip, _join_port, _join_name)
	if err != OK:
		_leave_to_title("Couldn't reconnect to the host (error %d)." % err)


func _set_ui_blocking(blocking: bool) -> void:
	GameState.ui_blocking = blocking
	if blocking:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif Settings.remote_mode:
		# Captured mouse look spins over TeamViewer; PlayerInput looks with the hidden cursor instead.
		Input.mouse_mode = Input.MOUSE_MODE_CONFINED_HIDDEN
		if DisplayServer.get_name() != "headless":
			Input.warp_mouse(get_viewport().get_visible_rect().size * 0.5)  # not against an edge (that turns)
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## --bench=N: the frame rate sampled once a second for N seconds, with the Line parked where the
## crowd will reach it, then printed and the game quits. The worst second is the number to watch.
func _process(delta: float) -> void:
	if _bench_t <= 0.0 or not in_game:
		return
	if _bench_frames == 0:
		var me := Net.get_local_player()
		var level := get_tree().get_first_node_in_group("level")
		if me != null and level != null and level is HordeArena:
			me.bot_controlled = true
			(level as HordeArena).debug_spawn_all_rounds()
			for b in Net.get_chain_bodies():
				b.teleport_to((level as HordeArena).test_points["north"] + Vector3(1.2 * float(b.join_index % 6), 0.0, 1.0), 0.0)
	_bench_frames += 1
	_bench_t -= delta
	_bench_sample_t -= delta
	if _bench_sample_t <= 0.0:
		_bench_sample_t = 1.0
		_bench_samples.append(Engine.get_frames_per_second())
	if _bench_t <= 0.0:
		var horde := get_tree().get_first_node_in_group("horde")
		var worst := 100000
		var sum := 0
		for s in _bench_samples:
			worst = mini(worst, s)
			sum += s
		print("[bench] fps per second: %s" % [_bench_samples])
		print("[bench] worst %d FPS, mean %d FPS, %s" % [worst, sum / maxi(1, _bench_samples.size()), String(horde.call("stats_text")) if horde != null else "no horde"])
		print("[bench] quality %d, window %s, %d bodies on the Line" % [Settings.quality, get_window().size, Net.get_chain_bodies().size()])
		get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if not in_game:
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if settings_panel.visible or end_screen.visible:
			return
		if pause_menu.visible:
			_resume()
		else:
			pause_menu.visible = true
			_set_ui_blocking(true)
	elif event.is_action_pressed("help") and not GameState.ui_blocking:
		hud.toggle_help()


func _resume() -> void:
	pause_menu.visible = false
	_set_ui_blocking(false)


func _open_settings(from_pause: bool) -> void:
	_settings_from_pause = from_pause
	pause_menu.visible = false
	settings_panel.open()


func _on_settings_closed() -> void:
	if in_game and _settings_from_pause:
		pause_menu.visible = true
	elif not in_game:
		title.show_status("")


func _on_escaped(escaped: bool) -> void:
	if not escaped:
		return
	await get_tree().create_timer(2.0).timeout
	if not in_game:
		return
	pause_menu.visible = false
	end_screen.show_results()
	_set_ui_blocking(true)


# --- World ------------------------------------------------------------------------------------

func _build_world() -> void:
	_teardown_world()
	world = Node3D.new()
	world.name = "World"
	add_child(world)
	var cfg := Net.world_config
	var level: Node3D
	if bool(cfg.get("arena", false)):
		var arena := HordeArena.new()  # the Level 3 test block: a lot, a fence, a thousand infected
		arena.horde_count = int(cfg.get("horde", HordeArena.HORDE_COUNT))
		arena.seed_value = int(cfg.get("seed", YellowRooms.DEFAULT_SEED))
		level = arena
	else:
		var stack := LevelStack.new()  # the whole building: the Yellow Rooms with the pizzeria on top
		stack.seed_value = int(cfg.get("seed", YellowRooms.DEFAULT_SEED))
		level = stack
	level.name = "Level"
	world.add_child(level)
	_add_spawned_root("Players", "PlayerSpawner", Net.spawn_player_node)
	_add_spawned_root("Pickups", "PickupSpawner", Net.spawn_pickup_node)
	_add_spawned_root("Thrown", "ThrownSpawner", Net.spawn_thrown_node)
	var fx := Effects.new()
	fx.name = "Effects"
	world.add_child(fx)
	var ballast := Ballast.new()
	ballast.name = "Ballast"
	world.add_child(ballast)
	var chain := ChainSystem.new()
	chain.name = "Chain"
	world.add_child(chain)  # last, so it runs after every body has moved this tick
	Net.bind_world(world)
	GameState.reset_run(level.get("spawn_position"), level.get("spawn_facing"), String(level.call("first_objective")))


func _add_spawned_root(root_name: String, spawner_name: String, fn: Callable) -> void:
	var root := Node3D.new()
	root.name = root_name
	world.add_child(root)
	var spawner := MultiplayerSpawner.new()
	spawner.name = spawner_name
	spawner.spawn_path = NodePath("../" + root_name)
	spawner.spawn_function = fn
	world.add_child(spawner)


func _teardown_world() -> void:
	if world != null and is_instance_valid(world):
		# Detach and rename at once so a rebuilt world can reuse the exact path "World".
		world.name = "WorldOld"
		remove_child(world)
		world.queue_free()
	world = null
	Net.unbind_world()
