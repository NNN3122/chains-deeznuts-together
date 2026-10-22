class_name ManorMachine
extends Node3D
## One of the four old pump engines scattered over the Ashgrave estate, or (is_main) the main
## generator in the courtyard. An engine is repaired by typing (the user: "make it harder than just
## holding ctrl"): crouch at it (Ctrl, within REACH) and the HUD's TypingPanel gives you a page of
## its maintenance book to type out; every right key is 1/TYPE_CHARS of the engine (about one page
## each, alone), every wrong one clangs (NOISE_MISS) and costs TYPE_MISS. Everyone at it types their
## own page, so more hands are faster. A crack of the wrench (it is "repairable") jumps it
## WRENCH_BOOST at the cost of a bang everything hears. Work is noise: something on the grounds
## hears a machine being worked on ("noise_source"), and Manor sends the Groundskeeper to it. Left
## half-done, a machine the Groundskeeper walks past gets kicked (server_kick): it clangs and runs
## back down until someone works on it again. At 100% it coughs into life and runs for good. The
## main generator is a switch, not a repair: dead until all four engines run (armed), then holding
## Ctrl at it for START_SECONDS throws it, the estate's lamps come on and the south gate opens.
## Host-authoritative: progress, done, working, regressing and armed are replicated; each typist's
## page and place in it go to that typist alone (_rpc_typing), and their keys come back one by one.

const REACH: float = 2.1  # m from its middle
const TYPE_CHARS: float = 210.0  # right keys to repair an engine from nothing: about one page
const TYPE_MISS: float = 0.02  # of the engine a wrong key knocks off
const TYPE_LINGER: float = 1.2  # s after a right key it still counts as being worked on
const MISS_NOISE_TIME: float = 1.0  # s a wrong key's clang carries
const NOISE_MISS: float = 85.0
## The pace (the user: "type really fast, at least 80 wpm, or else it makes sound and the monster can
## come get you"): five keys a word, so a right key at least every KEY_GAP s, smoothed over the keys
## (PACE_SMOOTH). Slower and the engine grinds (GRIND_TIME after each slow key, NOISE_GRIND) and the
## Groundskeeper comes for the typist. A gap over KEY_GAP_PAUSE is stopping, not slow typing; the
## pace counts again WPM_WARMUP keys after one.
const WPM_MIN: float = 80.0
const KEY_GAP: float = 60.0 / (WPM_MIN * 5.0)  # s: 0.15
const PACE_SMOOTH: float = 0.3
const KEY_GAP_PAUSE: float = 1.2
const WPM_WARMUP: int = 4
const GRIND_TIME: float = 1.5
const GRIND_SOUND_EVERY: float = 0.9  # s between grinds while it goes on
const NOISE_GRIND: float = 95.0
const WRENCH_BOOST: float = 0.03  # of the machine per crack of the wrench
## The engines' maintenance book, a page at a time (punctuation types itself; case doesn't matter).
const TYPE_TEXTS: Array[String] = [
	"Prime the pump with three strokes of the handle and listen. If the engine answers, open the valve slowly. If something else answers from under the floor, close it and do not open it again tonight.",
	"Clean the spark plug with the rag kept in the tin. The rag is not to be used for anything else, no matter what is on it, and no matter who is asking you for it.",
	"Turn the flywheel by hand until it catches. It will catch on the fourth turn. If it catches on the third, you are not alone in here, and you should leave by the window.",
	"Check the oil, then check it again. The level should not change between the two looks. If it has risen, something has been drinking from the reservoir and it will want more.",
	"Tighten every bolt on the housing by a quarter turn and count them as you go. There are twelve. If you count thirteen, stop counting and do not look at the last one.",
	"Bleed the line until the water runs clear. It runs red for a while in the autumn. The master says that is rust. The master has not been seen since the last autumn.",
	"Open the fuel cock and wait for the smell of paraffin. If you smell lilies instead, the old mistress is standing behind you, and she does not like the noise of the engine.",
	"Hold the choke down and pull the cord in one long breath. Do not stop halfway. Whatever is holding the other end of the cord will let go if you are steady and quick.",
	"Replace the belt if it has stretched. Spare belts hang in the cellar beside the hooks. Do not use what hangs on the hooks. They are not belts and they never were.",
	"When the engine runs at last, walk away and do not thank it. It does not run for you. It runs because it is afraid of the man with the lantern, the same as you are.",
]
const START_SECONDS: float = 4.0  # main: braced at its switch this long
const REGRESS_SECONDS: float = 100.0  # a kicked machine runs all the way down in this long
const NOISE_WORK: float = 48.0  # what something on the grounds hears while it's being worked on
const NOISE_RUNNING: float = 12.0
const WORK_LINGER: float = 0.8  # s a wrench crack counts as working
const ENGINE_SIZE: Vector3 = Vector3(1.8, 1.4, 1.1)  # m, ManorMeshes "manor_engine"
const MAIN_SIZE: Vector3 = Vector3(3.2, 2.4, 1.8)  # "manor_generator"

var index: int = 0
var is_main: bool = false
var level: Manor

# Replicated.
var progress: float = 0.0
var done: bool = false
var working: bool = false
var regressing: bool = false
var armed: bool = false  # main: every engine is running, its switch can be thrown

# Every peer: this peer's own page here, as the server last told it (-1: not typing here).
var local_text: int = -1
var local_cursor: int = 0
signal typing_changed(missed: bool)

# Server.
var _wrench_t: float = 0.0
var _type_t: float = 0.0  # s left of "being worked on" after the last right key
var _miss_t: float = 0.0
var _grind_t: float = 0.0  # s left of grinding (someone typing under the pace)
var _grind_sound_t: float = 0.0
var _typists: Dictionary = {}  # peer id -> [page, cursor, pace (see pace_step)]
var _pages: int = 0  # pages handed out here, so each typist gets the next

# Visuals.
var _engine: AudioStreamPlayer3D
var _bulb: OmniLight3D
var _bulb_mat: StandardMaterial3D
var _t: float = 0.0
var _shown_done: bool = false


static func create(node_name: String, idx: int, main: bool, at: Vector3, yaw: float, lvl: Manor) -> ManorMachine:
	var m := ManorMachine.new()
	m.name = node_name
	m.index = idx
	m.is_main = main
	m.level = lvl
	m.position = at
	m.rotation.y = yaw
	return m


func _enter_tree() -> void:
	if has_node("Sync"):
		return
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	for prop in ["progress", "done", "working", "regressing", "armed"]:
		var path := NodePath(".:" + prop)
		cfg.add_property(path)
		cfg.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	sync.replication_config = cfg
	add_child(sync)


func _ready() -> void:
	add_to_group("machine")
	add_to_group("repairable")
	add_to_group("noise_source")
	var key := "manor_generator" if is_main else "manor_engine"
	var size := size_m()
	var mi := MeshInstance3D.new()
	mi.mesh = PropMeshes.mesh(key)
	mi.material_override = PropMeshes.material_for(key)  # rusted iron
	add_child(mi)
	var body := StaticBody3D.new()
	body.collision_layer = ChainBody.LAYER_WORLD
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size.x * 0.9, size.y * 0.8, size.z * 0.9)
	shape.shape = box
	shape.position = Vector3(0.0, size.y * 0.4, 0.0)
	body.add_child(shape)
	add_child(body)
	# The work lamp clamped to it: a faint flicker so you can find it in the fog, brighter while
	# someone works, steady once it runs. The main generator's is a red warning lamp until armed.
	var bulb := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	sm.radial_segments = 10
	sm.rings = 5
	bulb.mesh = sm
	_bulb_mat = StandardMaterial3D.new()
	_bulb_mat.emission_enabled = true
	bulb.material_override = _bulb_mat
	bulb.position = Vector3(-size.x * 0.35, size.y * 0.95, 0.0)
	add_child(bulb)
	_bulb = OmniLight3D.new()
	_bulb.omni_range = 7.0 if not is_main else 9.0
	_bulb.omni_attenuation = 1.4
	_bulb.light_volumetric_fog_energy = 1.5
	_bulb.position = bulb.position + Vector3(0.0, 0.1, 0.0)
	add_child(_bulb)
	_engine = Sfx.loop_player("engine", -40.0, 26.0)
	_engine.position = Vector3(0.0, size.y * 0.5, 0.0)
	add_child(_engine)


func size_m() -> Vector3:
	return MAIN_SIZE if is_main else ENGINE_SIZE


## Where the wrench aims: the top of it, above its collision box (the wrench's line of sight
## would hit the box on the way to a point inside it).
func fix_point() -> Vector3:
	return global_position + Vector3(0.0, size_m().y * 0.86, 0.0)


func needs_fix() -> bool:
	return not done and (not is_main or armed)


## Server: a crack of the wrench. Loud (the wrench makes its own noise), quick.
func wrench_fix(_by: Node) -> void:
	if not multiplayer.is_server() or not needs_fix():
		return
	_wrench_t = WORK_LINGER
	regressing = false
	progress = minf(1.0, progress + (0.25 if is_main else WRENCH_BOOST))
	if progress >= 1.0:
		_complete()


## Server: the Groundskeeper put its boot into it. True if it did anything.
func server_kick() -> bool:
	if not multiplayer.is_server() or done or is_main or progress <= 0.0 or working or regressing:
		return false
	regressing = true
	progress = maxf(0.0, progress - 0.05)
	_rpc_kicked.rpc()
	return true


## Server: Manor arms the main generator once every engine runs.
func server_arm() -> void:
	if multiplayer.is_server() and is_main and not armed:
		armed = true
		_rpc_armed.rpc()


func noise_level() -> float:
	if _grind_t > 0.0:
		return NOISE_GRIND
	if _miss_t > 0.0:
		return NOISE_MISS
	if working:
		return NOISE_WORK
	return NOISE_RUNNING if done and not is_main else 0.0


## Within reach of it (and on its floor).
func in_reach(p: Player) -> bool:
	var d := p.global_position - global_position
	return absf(d.y) < 1.5 and Vector2(d.x, d.z).length() < REACH + (0.6 if is_main else 0.0)


## Players braced at it right now (the main generator's switch).
func workers() -> Array[Player]:
	var out: Array[Player] = []
	for p in Net.get_players():
		if p.state == Player.State.NORMAL and p.is_bracing() and in_reach(p):
			out.append(p)
	return out


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		_server_tick(delta)
	_update_visuals(delta)


func _server_tick(delta: float) -> void:
	_wrench_t = maxf(0.0, _wrench_t - delta)
	_type_t = maxf(0.0, _type_t - delta)
	_miss_t = maxf(0.0, _miss_t - delta)
	_grind_t = maxf(0.0, _grind_t - delta)
	if _grind_t > 0.0:
		_grind_sound_t -= delta
		if _grind_sound_t <= 0.0:
			_grind_sound_t = GRIND_SOUND_EVERY
			_rpc_grind.rpc()
	# A typist who was taken, knocked down or walked off stops typing here.
	for peer: int in _typists.keys():
		var p := Net.find_player(peer)
		if p == null or p.state != Player.State.NORMAL or not in_reach(p):
			_typists.erase(peer)
			if p != null:
				_rpc_typing.rpc_id(peer, -1, 0, false)
	if done or (is_main and not armed):
		working = false
		return
	if is_main:
		var n := workers().size()
		working = n > 0 or _wrench_t > 0.0
		if n > 0:
			progress = minf(1.0, progress + float(n) / START_SECONDS * delta)
			if progress >= 1.0:
				_complete()
		return
	working = _type_t > 0.0 or _wrench_t > 0.0
	if regressing and _type_t <= 0.0:
		progress = maxf(0.0, progress - delta / REGRESS_SECONDS)
		if progress <= 0.0:
			regressing = false


func _complete() -> void:
	progress = 1.0
	done = true
	working = false
	regressing = false
	for peer: int in _typists.keys():
		_rpc_typing.rpc_id(peer, -1, 0, false)
	_typists.clear()
	_rpc_done.rpc()
	if level != null:
		level.on_machine_done(self)


# --- Typing (engines) ------------------------------------------------------------------------------

## Server: someone at it opened their page (TypingPanel). They get the next page of the book.
func server_begin_typing(peer: int) -> void:
	var p := Net.find_player(peer)
	if is_main or not needs_fix() or p == null or p.state != Player.State.NORMAL or not in_reach(p):
		_rpc_typing.rpc_id(peer, -1, 0, false)
		return
	if not _typists.has(peer):
		_typists[peer] = [_next_page(), 0, new_pace()]
	_send_page(peer, false)


func server_end_typing(peer: int) -> void:
	_typists.erase(peer)


## Server: one key from a typist. Right: the engine comes along and their place moves on (a new page
## at the end of one); under the pace it grinds and the Groundskeeper comes for them. Wrong: a clang
## everything on the grounds hears, the engine slips back, and the Groundskeeper comes for them.
func server_type(peer: int, code: int) -> void:
	if done or not _typists.has(peer):
		return
	var st: Array = _typists[peer]
	var text: String = TYPE_TEXTS[int(st[0])]
	var cur := skip_untyped(text, int(st[1]))
	if cur < text.length() and same_key(text.unicode_at(cur), code):
		cur = skip_untyped(text, cur + 1)
		st[1] = cur
		if cur >= text.length():
			st[0] = _next_page()
			st[1] = 0
		regressing = false
		_type_t = TYPE_LINGER
		progress = minf(1.0, progress + 1.0 / TYPE_CHARS)
		if pace_step(st[2], Time.get_ticks_msec()):
			if _grind_t <= 0.0:
				_grind_sound_t = 0.0
			_grind_t = GRIND_TIME
			if level != null:
				level.server_typing_alarm(peer)
		if progress >= 1.0:
			_complete()
			return
		_send_page(peer, false)
	else:
		progress = maxf(0.0, progress - TYPE_MISS)
		_miss_t = MISS_NOISE_TIME
		_rpc_miss.rpc()
		_send_page(peer, true)
		if level != null:
			level.server_typing_alarm(peer)


## A typist's pace, kept the same way on the host (the grind) and in their TypingPanel (the readout):
## [msec of the last right key, smoothed seconds between keys, keys since a pause].
static func new_pace() -> Array:
	return [0, KEY_GAP, 0]


## A right key at msec `now`. True when they're typing slower than WPM_MIN.
static func pace_step(pace: Array, now: int) -> bool:
	var gap := float(now - int(pace[0])) / 1000.0
	if int(pace[0]) <= 0 or gap > KEY_GAP_PAUSE:
		pace[1] = KEY_GAP
		pace[2] = 0
	else:
		pace[1] = lerpf(float(pace[1]), gap, PACE_SMOOTH)
		pace[2] = int(pace[2]) + 1
	pace[0] = now
	return int(pace[2]) >= WPM_WARMUP and float(pace[1]) > KEY_GAP


## Words a minute at that pace (five keys a word).
static func pace_wpm(pace: Array) -> float:
	return 12.0 / maxf(float(pace[1]), 0.01)


## Grinding (someone at it typing under the pace).
func is_grinding() -> bool:
	return _grind_t > 0.0


func _next_page() -> int:
	_pages += 1
	return (index * 3 + _pages - 1) % TYPE_TEXTS.size()


func _send_page(peer: int, missed: bool) -> void:
	var st: Array = _typists[peer]
	_rpc_typing.rpc_id(peer, int(st[0]), skip_untyped(TYPE_TEXTS[int(st[0])], int(st[1])), missed)


## Past anything you don't type (punctuation): the index of the next letter, digit or space.
static func skip_untyped(text: String, i: int) -> int:
	while i < text.length() and not typed_char(text.unicode_at(i)):
		i += 1
	return i


static func typed_char(c: int) -> bool:
	return c == 32 or (c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122)


static func same_key(want: int, got: int) -> bool:
	return String.chr(want).to_lower() == String.chr(got).to_lower()


## Tests: type the next n right keys as peer (opening a page first if they had none).
func debug_type(peer: int, n: int) -> void:
	if not _typists.has(peer):
		server_begin_typing(peer)
	for k in n:
		if not _typists.has(peer):
			return
		var st: Array = _typists[peer]
		var text: String = TYPE_TEXTS[int(st[0])]
		server_type(peer, text.unicode_at(skip_untyped(text, int(st[1]))))


func _sender() -> int:
	var s := multiplayer.get_remote_sender_id()
	return s if s != 0 else multiplayer.get_unique_id()


@rpc("any_peer", "call_local", "reliable")
func rpc_begin_typing() -> void:
	if multiplayer.is_server():
		server_begin_typing(_sender())


@rpc("any_peer", "call_local", "reliable")
func rpc_end_typing() -> void:
	if multiplayer.is_server():
		server_end_typing(_sender())


@rpc("any_peer", "call_local", "reliable")
func rpc_key(code: int) -> void:
	if multiplayer.is_server():
		server_type(_sender(), code)


## To one typist: their page and place (-1: they're done typing here).
@rpc("authority", "call_local", "reliable")
func _rpc_typing(page: int, cursor: int, missed: bool) -> void:
	local_text = page
	local_cursor = cursor
	typing_changed.emit(missed)


@rpc("authority", "call_local", "reliable")
func _rpc_miss() -> void:
	Sfx.play_at(self, "clink", fix_point(), 6.0, randf_range(0.45, 0.6), 45.0)
	Sfx.play_at(self, "bang", fix_point(), -2.0, randf_range(0.9, 1.1), 40.0)
	Sfx.caption(self, "metal clangs: a slip at an engine", fix_point())
	_bulb.light_energy = 2.5  # a spark


@rpc("authority", "call_local", "reliable")
func _rpc_grind() -> void:
	Sfx.play_at(self, "scrape", fix_point(), 4.0, randf_range(0.35, 0.45), 45.0)
	Sfx.play_at(self, "clink", fix_point(), 0.0, randf_range(0.3, 0.4), 40.0)
	Sfx.caption(self, "an engine grinds: too slow at it", fix_point())
	_bulb.light_energy = 1.8


## Tests: finish it now, as if someone had worked it to the end.
func debug_complete() -> void:
	if not done:
		if is_main and not armed:
			armed = true
		_complete()


@rpc("authority", "call_local", "reliable")
func _rpc_done() -> void:
	Sfx.play_at(self, "slam", fix_point(), 2.0, 0.55, 45.0)
	Sfx.play_at(self, "lift", fix_point(), 0.0, 0.6, 30.0)
	Sfx.caption(self, "the main generator roars into life" if is_main else "an engine coughs into life", fix_point())


@rpc("authority", "call_local", "reliable")
func _rpc_kicked() -> void:
	Sfx.play_at(self, "bang", fix_point(), 0.0, 0.7, 40.0)
	Sfx.play_at(self, "clink", fix_point(), 2.0, 0.6, 25.0)
	Sfx.caption(self, "metal clangs: something kicked an engine", fix_point())
	_t = 0.0
	_bulb.light_energy = 3.0  # a spark


@rpc("authority", "call_local", "reliable")
func _rpc_armed() -> void:
	Sfx.play_at(self, "click", fix_point(), 4.0, 0.5, 30.0)


func _update_visuals(delta: float) -> void:
	_t += delta
	var col := Color(1.0, 0.68, 0.35)
	var e := 0.0
	if is_main:
		if done:
			e = 1.8
		elif armed:
			col = Color(1.0, 0.75, 0.2)
			e = 1.2 if fmod(_t, 0.9) < 0.55 else 0.3  # blinking: ready
		else:
			col = Color(1.0, 0.1, 0.05)
			e = 0.5 + 0.2 * sin(_t * 2.0)
	elif done:
		e = 1.5
	elif working:
		e = 0.8 + 0.4 * absf(sin(_t * 17.0)) * (1.0 if sin(_t * 3.1) > -0.6 else 0.1)
	elif progress > 0.0:
		e = 0.35 if sin(_t * 23.0) * sin(_t * 5.0) < 0.8 else 0.05
		if regressing:
			col = Color(1.0, 0.3, 0.12)
	else:
		e = 0.22 if sin(_t * 19.0) * sin(_t * 3.3) < 0.85 else 0.0
	_bulb.light_color = col
	_bulb.light_energy = lerpf(_bulb.light_energy, e, clampf(delta * 10.0, 0.0, 1.0))
	_bulb_mat.albedo_color = col
	_bulb_mat.emission = col
	_bulb_mat.emission_energy_multiplier = 0.4 + _bulb.light_energy * 3.0
	# The engine: sputtering while worked on (faster as it comes along), steady once it runs.
	var want_db := -40.0
	var pitch := 1.0
	if done:
		want_db = -9.0 if is_main else -13.0
		pitch = 0.75 if is_main else 1.0
	elif working:
		want_db = -14.0 + 4.0 * sin(_t * 5.0)
		pitch = 0.55 + 0.4 * progress + 0.08 * sin(_t * 9.0)
	_engine.volume_db = lerpf(_engine.volume_db, want_db, clampf(delta * 4.0, 0.0, 1.0))
	_engine.pitch_scale = maxf(0.3, pitch)
	if _engine.volume_db > -38.0:
		Sfx.start_loop(_engine)
	elif _engine.playing:
		_engine.stop()
	if done and not _shown_done:
		_shown_done = true


## The HUD's line for a player standing at it.
func hud_line() -> String:
	if is_main:
		if done:
			return "MAIN GENERATOR: RUNNING. THE GATE IS OPEN."
		if not armed:
			return "MAIN GENERATOR: dead. Get all four engines running first (%d of 4)." % (level.engines_running() if level != null else 0)
		return "MAIN GENERATOR: hold Ctrl at it to throw the switch  %d%%" % int(progress * 100.0)
	if done:
		return "ENGINE RUNNING"
	var state := ""
	if regressing:
		state = "  (KICKED: it's running down)"
	return "ENGINE  %d%%   crouch at it (Ctrl) to repair: type the page out fast (%d words a minute) and right, or it hears you; a crack of the wrench helps, loudly%s" % [int(progress * 100.0), int(WPM_MIN), state]
