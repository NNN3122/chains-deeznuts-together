class_name Strider
extends Node3D
## Level 4's hunter: the Strider (StriderBody) runs the cars down through Kettle Hollow. It doesn't
## path-find: it gallops along the rally route behind them (the Town owns where it is, `s`, metres
## along the route, and moves it on the server), so a car that takes a wrong turn falls behind the
## route while it doesn't. When it passes a car (or comes within reach of one), it lunges: the car is
## caught. Every peer places and animates it from the replicated `s` and the lunge, with its footfalls
## shaking the street and a roar now and then you hear long before you see the eyes.
## In group "monster" with the fields the rest of the game reads (hunt_peer, grab_peer, is_hunting).

const STRIDE: float = 9.0  # m of street a gallop cycle covers
const CATCH_REACH: float = 7.0  # m: a car this close to it is caught
const LUNGE_TIME: float = 0.7  # s from the spring to the hands on the roof
const ROAR_MIN: float = 7.0
const ROAR_MAX: float = 13.0

var town: Node  # Town: route_point(s), route_tangent(s)
var s: float = -60.0  # replicated: metres along the route
var active: bool = false  # replicated: running
var lunge: float = -1.0  # replicated: 0..1 through a lunge, -1 none
var lunge_to: Vector3 = Vector3.ZERO  # replicated
var hunt_peer: int = 0  # replicated: the driver it is after (chase music, HUD)
var grab_peer: int = 0  # never holds anyone itself: the car's catch is a layoff
var body: StriderBody
var _twitch_t: float = 0.0
var _phase: float = 0.0
var _last_s: float = 0.0
var _step_side: int = 0
var _roar_t: float = 4.0
var _lunge_from: Vector3 = Vector3.ZERO
var _lunging_shown: bool = false


func _enter_tree() -> void:
	add_to_group("monster")
	add_to_group("strider")
	if has_node("Sync"):
		return
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	for prop in ["s", "active", "lunge", "lunge_to", "hunt_peer"]:
		var path := NodePath(".:" + prop)
		cfg.add_property(path)
		cfg.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	sync.replication_config = cfg
	add_child(sync)


func _ready() -> void:
	body = StriderBody.new()
	body.name = "Body"
	add_child(body)
	body.build()
	_last_s = s


func is_hunting() -> bool:
	return active


func is_chasing() -> bool:
	return active


func is_dead() -> bool:
	return false


func head_point() -> Vector3:
	return body.head.global_position if body != null and body.head != null else global_position + Vector3.UP * 7.0


func _process(delta: float) -> void:
	if town == null:
		return
	visible = active or lunge >= 0.0
	if not visible:
		_last_s = s
		return
	var at: Vector3 = town.call("route_point", s)
	var fwd: Vector3 = town.call("route_tangent", s)
	if lunge >= 0.0:
		if not _lunging_shown:
			_lunging_shown = true
			_lunge_from = at
			Sfx.play_at(self, "scream", head_point(), 8.0, 0.55, 140.0)
		var u := smoothstep(0.0, 1.0, lunge)
		at = _lunge_from.lerp(lunge_to, u) + Vector3.UP * sin(u * PI) * 3.0
		var to := lunge_to - _lunge_from
		to.y = 0.0
		if to.length() > 0.5:
			fwd = to.normalized()
	else:
		_lunging_shown = false
	global_position = at
	if fwd.length() > 0.1:
		global_basis = Basis.looking_at(fwd, Vector3.UP)
	var moved := absf(s - _last_s)
	_last_s = s
	if moved > 20.0:
		moved = 0.0  # a reset, not a stride
	_animate(delta, moved)
	_sounds(delta)


func _animate(delta: float, moved: float) -> void:
	var before := _phase
	_phase += moved / STRIDE * TAU
	if lunge >= 0.0:
		_phase += delta * 6.0
	var p := _phase
	# A gallop: the arms reach together and the legs drive together, half a beat apart.
	for k in 2:
		var shoulder := body.arms[k]
		var off := 0.25 * float(k)
		shoulder.rotation.x = 0.65 * sin(p + off) - 0.15
		(shoulder.get_child(1) as Node3D).rotation.x = -0.25 - 0.55 * maxf(0.0, -cos(p + off))
		var hip := body.legs[k]
		hip.rotation.x = 0.7 * sin(p + PI + off) + 0.35
		(hip.get_child(1) as Node3D).rotation.x = 0.35 + 0.6 * maxf(0.0, cos(p + PI + off))
	body.position.y = absf(sin(p)) * 0.5
	body.rotation.x = 0.06 * sin(p * 2.0) - (0.25 if lunge >= 0.0 else 0.0)
	# Its head finds whoever's camera is on it.
	var cam := get_viewport().get_camera_3d()
	if cam != null and body.head != null:
		var local: Vector3 = (body.head.get_parent() as Node3D).to_local(cam.global_position) - body.head.position
		var yaw := clampf(atan2(-local.x, -local.z), -0.9, 0.9)
		var pitch := clampf(atan2(local.y, Vector2(local.x, local.z).length()), -0.6, 0.5)
		body.head.rotation = body.head.rotation.lerp(Vector3(pitch, yaw, body.head.rotation.z), clampf(delta * 6.0, 0.0, 1.0))
		# Now and then the head snaps to a wrong angle and holds it: nothing alive moves like that.
		_twitch_t -= delta
		if _twitch_t <= 0.0:
			_twitch_t = randf_range(0.25, 1.6)
			body.head.rotation.z = 0.0 if randf() < 0.4 else randf_range(-0.7, 0.7)
	# Footfalls: every half stride a hand or a foot comes down.
	if floorf(p / PI) != floorf(before / PI):
		_step_side = 1 - _step_side
		Sfx.play_at(self, "thump", global_position, 6.0, randf_range(0.42, 0.55), 120.0)
		var me := Net.get_local_player()
		if me != null:
			var d := me.global_position.distance_to(global_position)
			if d < 40.0:
				me.add_shake(0.25 * (1.0 - d / 40.0))


func _sounds(delta: float) -> void:
	_roar_t -= delta
	if _roar_t <= 0.0 and active:
		_roar_t = randf_range(ROAR_MIN, ROAR_MAX)
		Sfx.play_at(self, "roar", head_point(), 10.0, randf_range(0.5, 0.62), 180.0)
		Sfx.caption(self, "a ROAR behind you", global_position)


## It sprints at the cars: a roar every peer hears (the server's word).
func server_roar() -> void:
	_rpc_roar.rpc()


@rpc("authority", "call_local", "reliable")
func _rpc_roar() -> void:
	_roar_t = randf_range(ROAR_MIN, ROAR_MAX)
	Sfx.play_at(self, "roar", head_point(), 14.0, randf_range(0.4, 0.48), 220.0)
	var me := Net.get_local_player()
	if me != null and me.global_position.distance_to(global_position) < 80.0:
		me.add_shake(0.5)
