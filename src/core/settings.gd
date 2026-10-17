class_name Settings
extends RefCounted
## Player settings, saved to user://settings.cfg. Static so any script can read them.
## On the very first run, Remote Controls turn on automatically when TeamViewer is running,
## because TeamViewer turns held keys into a stream of taps and breaks captured mouse look.

const PATH: String = "user://settings.cfg"

static var mouse_sensitivity: float = 1.0
static var invert_y: bool = false
static var fov: float = 80.0
static var volume: float = 0.8
static var remote_mode: bool = false
static var fullscreen: bool = false
static var quality: int = 2  # 0 low, 1 medium, 2 high
static var brightness: float = 1.0  # post-process brightness; dark scenes turn to mud over a video stream
static var show_fps: bool = false
static var first_person: bool = false  # the camera you start with; V still flips it in play
static var captions: bool = true  # on-screen captions for important sounds, with direction
static var player_name: String = ""
static var open_router_port: bool = true  # UPnP while hosting, so friends join with an invite code
static var last_join: String = ""  # the last invite code or address typed into JOIN
static var remote_key_gap_ms: int = 650  # learned: the remote side's key-repeat delay (Remote Controls grace)
static var voice_enabled: bool = true  # proximity voice chat: capture and send the microphone
static var voice_volume: float = 1.0
static var remote_autodetected: bool = false
static var loaded: bool = false


static func load_settings() -> void:
	if loaded:
		return
	loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		remote_mode = detect_remote_desktop()
		remote_autodetected = remote_mode
		return
	mouse_sensitivity = float(cfg.get_value("input", "mouse_sensitivity", mouse_sensitivity))
	invert_y = bool(cfg.get_value("input", "invert_y", invert_y))
	remote_mode = bool(cfg.get_value("input", "remote_mode", remote_mode))
	fov = float(cfg.get_value("video", "fov", fov))
	fullscreen = bool(cfg.get_value("video", "fullscreen", fullscreen))
	quality = int(cfg.get_value("video", "quality", quality))
	brightness = float(cfg.get_value("video", "brightness", brightness))
	show_fps = bool(cfg.get_value("video", "show_fps", show_fps))
	first_person = bool(cfg.get_value("video", "first_person", first_person))
	captions = bool(cfg.get_value("audio", "captions", captions))
	volume = float(cfg.get_value("audio", "volume", volume))
	player_name = String(cfg.get_value("player", "name", player_name))
	open_router_port = bool(cfg.get_value("network", "open_router_port", open_router_port))
	last_join = String(cfg.get_value("network", "last_join", last_join))
	remote_key_gap_ms = int(cfg.get_value("input", "remote_key_gap_ms", remote_key_gap_ms))
	voice_enabled = bool(cfg.get_value("audio", "voice_enabled", voice_enabled))
	voice_volume = float(cfg.get_value("audio", "voice_volume", voice_volume))


static func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("input", "invert_y", invert_y)
	cfg.set_value("input", "remote_mode", remote_mode)
	cfg.set_value("video", "fov", fov)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "quality", quality)
	cfg.set_value("video", "brightness", brightness)
	cfg.set_value("video", "show_fps", show_fps)
	cfg.set_value("video", "first_person", first_person)
	cfg.set_value("audio", "captions", captions)
	cfg.set_value("audio", "volume", volume)
	cfg.set_value("player", "name", player_name)
	cfg.set_value("network", "open_router_port", open_router_port)
	cfg.set_value("network", "last_join", last_join)
	cfg.set_value("input", "remote_key_gap_ms", remote_key_gap_ms)
	cfg.set_value("audio", "voice_enabled", voice_enabled)
	cfg.set_value("audio", "voice_volume", voice_volume)
	cfg.save(PATH)


## Applies the settings that live outside the game scene (audio bus, window mode).
static func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)


static func detect_remote_desktop() -> bool:
	if OS.get_name() != "Windows" or DisplayServer.get_name() == "headless":
		return false
	var out: Array = []
	var code := OS.execute("tasklist", ["/FI", "IMAGENAME eq TeamViewer.exe", "/NH"], out, true)
	if code != 0 or out.is_empty():
		return false
	return String(out[0]).to_lower().contains("teamviewer.exe")
