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
##   --shots=DIR                                              save screenshots (tests/screenshots.gd)

var title: TitleMenu
var settings_panel: SettingsPanel
var pause_menu: PauseMenu
var end_screen: EndScreen
var hud: Hud
var screen_fx: ScreenFx
var world: Node3D
var backdrop: MenuBackdrop
var in_game: bool = false
var _settings_from_pause: bool = false


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
	title.solo_requested.connect(func(n: String) -> void: _start("solo", n, "", 0))
	title.host_requested.connect(func(n: String, port: int) -> void: _start("host", n, "", port))
	title.join_requested.connect(func(n: String, ip: String, port: int) -> void: _start("join", n, ip, port))
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
	LevelKit._mats.clear()
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
	var shots := ""
	var port := Net.DEFAULT_PORT
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
		elif a.begins_with("--shots="):
			shots = a.trim_prefix("--shots=")
			mode = "solo"
		elif a.begins_with("--title-shot="):
			var cam_title: Node = load("res://tests/screenshots.gd").new()
			cam_title.set("out_dir", a.trim_prefix("--title-shot="))
			cam_title.set("title_only", true)
			add_child(cam_title)
			return
	if mode == "":
		return
	if player_name == "":
		player_name = title.player_name()
	_start(mode, player_name, ip, port)
	if world == null:
		return
	if smoke != "":
		var test: Node = load("res://tests/smoke_test.gd").new()
		test.name = "SmokeTest"
		test.set("is_client", smoke == "client")
		test.set("expected_players", smoke_players)
		add_child(test)
	if shots != "":
		var cam_test: Node = load("res://tests/screenshots.gd").new()
		cam_test.name = "Screenshots"
		cam_test.set("out_dir", shots)
		add_child(cam_test)


# --- Flow ------------------------------------------------------------------------------------

func _start(mode: String, player_name: String, ip: String, port: int) -> void:
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
		var level := world.get_node("Level") as LevelStack
		level.server_populate()
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
	var level := LevelStack.new()  # the whole building: the Yellow Rooms with the pizzeria on top
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
	GameState.reset_run(level.spawn_position, level.spawn_facing, YellowRooms.OBJECTIVES[0])


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
