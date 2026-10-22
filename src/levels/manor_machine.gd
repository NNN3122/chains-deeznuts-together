class_name ManorMachine
extends Node3D
## One of the four old pump engines scattered over the Ashgrave estate, or (is_main) the main
## generator in the courtyard. An engine is repaired by whoever crouches at it holding Ctrl
## (braced, within REACH): one player alone takes REPAIR_SECONDS, every extra pair of hands adds
## TEAM_BONUS of a player, and a crack of the wrench (it is "repairable") jumps it WRENCH_BOOST at
## the cost of a bang everything hears. Work is noise: something on the grounds hears a machine
## being worked on ("noise_source"), and Manor sends the Groundskeeper to it. Left half-done, a
## machine the Groundskeeper walks past gets kicked (server_kick): it clangs and runs back down
## until someone works on it again. At 100% it coughs into life and runs for good. The main
## generator is dead until all four engines run (armed); then holding Ctrl at its switch for
## START_SECONDS throws it, the estate's lamps come on and the south gate grinds open.
## Host-authoritative: progress, done, working, regressing and armed are replicated.

const REACH: float = 2.1  # m from its middle
const REPAIR_SECONDS: float = 45.0  # one player, braced the whole time
const TEAM_BONUS: float = 0.7  # each extra player braced at it adds this much of a player
const WRENCH_BOOST: float = 0.03  # of the machine per crack of the wrench
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

# Server.
var _wrench_t: float = 0.0

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
	mi.material_override = PropMeshes.material()
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
	if working:
		return NOISE_WORK
	return NOISE_RUNNING if done and not is_main else 0.0


## Players braced at it right now.
func workers() -> Array[Player]:
	var out: Array[Player] = []
	var reach := REACH + (0.6 if is_main else 0.0)
	for p in Net.get_players():
		if p.state != Player.State.NORMAL or not p.is_bracing():
			continue
		var d := p.global_position - global_position
		if absf(d.y) < 1.5 and Vector2(d.x, d.z).length() < reach:
			out.append(p)
	return out


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		_server_tick(delta)
	_update_visuals(delta)


func _server_tick(delta: float) -> void:
	_wrench_t = maxf(0.0, _wrench_t - delta)
	if done or (is_main and not armed):
		working = false
		return
	var n := workers().size()
	working = n > 0 or _wrench_t > 0.0
	if n > 0:
		regressing = false
		var rate := (1.0 + TEAM_BONUS * float(n - 1)) / (START_SECONDS if is_main else REPAIR_SECONDS)
		progress = minf(1.0, progress + rate * delta)
		if progress >= 1.0:
			_complete()
	elif regressing:
		progress = maxf(0.0, progress - delta / REGRESS_SECONDS)
		if progress <= 0.0:
			regressing = false


func _complete() -> void:
	progress = 1.0
	done = true
	working = false
	regressing = false
	_rpc_done.rpc()
	if level != null:
		level.on_machine_done(self)


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
	return "ENGINE  %d%%   hold Ctrl at it to repair; a crack of the wrench helps, loudly%s" % [int(progress * 100.0), state]
