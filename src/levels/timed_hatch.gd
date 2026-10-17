class_name TimedHatch
extends Node3D
## A steel hatch over B2's shelf-shaft hole, and its release switch two rooms back along the
## route. Hold Ctrl at the switch and the hatch slides open for OPEN_SECONDS with a buzzer
## counting down, then slams shut (loud: the floor hears it) unless somebody is in the hole.
## So the Line sprints from the switch to the shelf and gets everyone up before it closes, and a
## straggler is yanked along. It can be released again from the switch.
## Server decides "open" and the clock (replicated); every peer slides the plate and hears it.

const OPEN_SECONDS: float = 25.0
const PULL_TIME: float = 0.6  # s of holding Ctrl at the switch
const HOLD_RADIUS: float = 1.5
const WAKE_SECONDS: float = 8.0  # the slam wakes the floor's Hires

var level: YellowRooms
var floor_index: int = 0
var hole: float = 2.6  # m square
var ceiling_y: float = 3.2  # underside of the ceiling, world y
var switch_pos: Vector3 = Vector3.ZERO  # world, on a wall face at floor level
var switch_normal: Vector3 = Vector3.FORWARD
var open: bool = false  # replicated
var seconds_left: float = 0.0  # replicated
var _hold_t: float = 0.0
var _plate: Node3D
var _shape: CollisionShape3D
var _switch_lever: MeshInstance3D
var _shown_open: bool = false
var _told_msec: int = -100000
var _warned: int = 0
var _buzz_t: float = 0.0


static func create(node_name: String, hole_center: Vector3, ceil_y: float, hole_size: float, sw_pos: Vector3, sw_normal: Vector3) -> TimedHatch:
	var h := TimedHatch.new()
	h.name = node_name
	h.position = Vector3(hole_center.x, ceil_y, hole_center.z)
	h.ceiling_y = ceil_y
	h.hole = hole_size
	h.switch_pos = sw_pos
	h.switch_normal = sw_normal.normalized()
	return h


func _enter_tree() -> void:
	if has_node("Sync"):
		return
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	for prop in ["open", "seconds_left"]:
		var path := NodePath(".:" + prop)
		cfg.add_property(path)
		cfg.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	sync.replication_config = cfg
	add_child(sync)


func _ready() -> void:
	add_to_group("hatches")
	# The plate: a steel slab filling the hole, sitting in the plenum just above the ceiling line.
	_plate = Node3D.new()
	add_child(_plate)
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(hole + 0.3, 0.12, hole + 0.3)
	m.mesh = bm
	m.position = Vector3(0.0, 0.07, 0.0)
	m.material_override = LevelKit.mat("steel_dark")
	_plate.add_child(m)
	for s: float in [-1.0, 1.0]:
		var stripe := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(hole + 0.3, 0.012, 0.14)
		stripe.mesh = sm
		stripe.position = Vector3(0.0, 0.005, s * (hole * 0.5 - 0.1))
		stripe.material_override = LevelKit.mat("hazard")
		_plate.add_child(stripe)
	var body := StaticBody3D.new()
	body.collision_layer = ChainBody.LAYER_WORLD
	body.collision_mask = 0
	_shape = CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(hole + 0.3, 0.12, hole + 0.3)
	_shape.shape = bs
	_shape.position = Vector3(0.0, 0.07, 0.0)
	body.add_child(_shape)
	_plate.add_child(body)
	# The switch: a lever box on a wall two rooms back.
	var sw := Node3D.new()
	sw.name = "Switch"
	sw.top_level = true  # the switch lives on a wall two rooms away: its transform is world space
	sw.position = switch_pos
	sw.rotation.y = atan2(switch_normal.x, switch_normal.z)
	add_child(sw)
	var box := MeshInstance3D.new()
	var xm := BoxMesh.new()
	xm.size = Vector3(0.34, 0.44, 0.12)
	box.mesh = xm
	box.position = Vector3(0.0, 1.3, 0.06)
	box.material_override = LevelKit.mat("steel_dark")
	sw.add_child(box)
	_switch_lever = MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(0.06, 0.3, 0.06)
	_switch_lever.mesh = lm
	_switch_lever.position = Vector3(0.0, 1.42, 0.16)
	_switch_lever.rotation.x = -0.5
	_switch_lever.material_override = LevelKit.mat("hazard")
	sw.add_child(_switch_lever)
	var face := Label3D.new()
	face.text = "SHELF SHAFT\nHATCH RELEASE\n%d s" % int(OPEN_SECONDS)
	face.font_size = 24
	face.pixel_size = 0.0032
	face.modulate = Color(1.0, 1.0, 1.0)
	face.outline_size = 0
	face.shaded = true
	face.double_sided = false
	face.position = Vector3(0.0, 1.16, 0.122)
	sw.add_child(face)


func switch_point() -> Vector3:
	return switch_pos + switch_normal * 0.5 + Vector3(0.0, 1.2, 0.0)


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		_server_tick(delta)
	if open != _shown_open:
		_shown_open = open
		_shape.disabled = open
		var tw := create_tween()
		tw.tween_property(_plate, "position:x", (hole + 0.4) if open else 0.0, 0.45 if open else 0.12).set_ease(Tween.EASE_IN_OUT)
	_switch_lever.rotation.x = 0.5 if open else -0.5
	if open and seconds_left > 0.0:
		_buzz_t -= delta
		if _buzz_t <= 0.0:
			_buzz_t = 1.0 if seconds_left > 10.0 else 0.5
			Sfx.play_at(self, "click", global_position - Vector3(0.0, 0.5, 0.0), 0.0, 1.6, 30.0)


func _server_tick(delta: float) -> void:
	if open:
		seconds_left = maxf(0.0, seconds_left - delta)
		if seconds_left <= 10.0 and _warned < 1:
			_warned = 1
			GameState.post_message("HATCH: 10 seconds.", 2.0)
		elif seconds_left <= 5.0 and _warned < 2:
			_warned = 2
			GameState.post_message("HATCH: 5 seconds. GET IN THE HOLE.", 2.5)
		if seconds_left <= 0.0:
			if _body_in_hole():
				return  # it won't close on anyone: it waits
			server_close()
		return
	var holding := false
	var near := false
	var sp := switch_point()
	for p in Net.get_players():
		if p.global_position.distance_to(sp) > HOLD_RADIUS or absf(p.global_position.y - switch_pos.y) > 1.5:
			continue
		near = true
		if p.wants_brace():
			holding = true
	if near and not holding and Time.get_ticks_msec() - _told_msec > 4000:
		_told_msec = Time.get_ticks_msec()
		GameState.post_message("HATCH RELEASE: hold Ctrl here. The hatch over the shelf shaft opens for %d seconds. Then run." % int(OPEN_SECONDS), 3.5)
	_hold_t = _hold_t + delta if holding else maxf(0.0, _hold_t - delta * 2.0)
	if _hold_t >= PULL_TIME:
		server_release()


## Anyone in the shaft, or standing at its lip on either floor, counts: it never closes on them.
func _body_in_hole() -> bool:
	var half := hole * 0.5 + 1.0
	for b in Net.get_chain_bodies():
		var p := b.global_position
		if absf(p.x - global_position.x) < half and absf(p.z - global_position.z) < half \
				and p.y > ceiling_y - 2.4 and p.y < ceiling_y + 2.2:
			return true
	return false


## Server: the switch is thrown; the hatch slides open and the clock starts.
func server_release() -> void:
	if open:
		return
	open = true
	_shape.disabled = true
	seconds_left = OPEN_SECONDS
	_warned = 0
	_hold_t = 0.0
	_rpc_released.rpc()
	GameState.post_message("HATCH OPEN: %d SECONDS. Run for the SHELF SHAFT, everyone up, before it slams." % int(OPEN_SECONDS), 4.5)
	if level != null:
		level.on_hatch_released(floor_index)


## Server: time's up and the hole is clear: it slams.
func server_close() -> void:
	if not open:
		return
	open = false
	_shape.disabled = false
	seconds_left = 0.0
	_rpc_slam.rpc()
	if level != null:
		level.wake_floor(floor_index, global_position - Vector3(0.0, 1.5, 0.0), WAKE_SECONDS)
	GameState.post_message("The hatch slammed shut. Back to the release switch.", 3.0)


## Tests: open now / set the clock.
func debug_open() -> void:
	server_release()


func debug_set_clock(seconds: float) -> void:
	seconds_left = seconds


@rpc("authority", "call_local", "reliable")
func _rpc_released() -> void:
	Sfx.play_at(self, "servo", global_position, 0.0, 0.7, 40.0)
	Sfx.play_at(self, "ding", switch_point(), -2.0, 0.8, 30.0)
	Sfx.caption(self, "a hatch grinding open", global_position)


@rpc("authority", "call_local", "reliable")
func _rpc_slam() -> void:
	Sfx.play_at(self, "bang", global_position, 4.0, 0.7, 60.0)
	Sfx.caption(self, "the hatch slams", global_position)
	var me := Net.get_local_player()
	if me != null and me.global_position.distance_to(global_position) < 18.0:
		me.add_shake(0.45)
