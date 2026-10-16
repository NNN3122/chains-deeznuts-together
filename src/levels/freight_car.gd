class_name FreightCar
extends AnimatableBody3D
## The freight elevator out of the Yellow Rooms. It waits on B1 with its roll-up door open; once
## everyone on the Line is inside, the door rolls down and the car grinds 5 m up its shaft into
## the pizzeria's Receiving room, where the door rolls up again. The server drives it; height and
## door state are replicated so late joiners see it where it is. Bodies inside ride along.

const WIDTH: float = 2.8  # inside, meters
const HEIGHT: float = 2.9
const WALL: float = 0.1
const CLOSE_TIME: float = 0.9  # s for the door to roll down
const DEPART_DELAY: float = 1.6  # s between the door shutting and the car moving
const SPEED: float = 0.9  # m/s: a tired freight motor
const OPEN_DELAY: float = 0.8  # s after arriving before the door rolls up

enum Phase { WAITING, CLOSING, RIDING, ARRIVED }

var low_y: float = 0.0
var high_y: float = 0.0
var synced_y: float = 0.0  # replicated
var door_closed: bool = false  # replicated
var phase: int = Phase.WAITING  # replicated
var _t: float = 0.0
var _door: Node3D
var _door_shape: CollisionShape3D
var _motor: AudioStreamPlayer3D
var _door_shown: bool = false
var _last_y: float = 0.0
var _shake_t: float = 0.0


static func create(node_name: String, floor_center: Vector3, rise: float) -> FreightCar:
	var car := FreightCar.new()
	car.name = node_name
	car.position = floor_center
	car.low_y = floor_center.y
	car.high_y = floor_center.y + rise
	car.synced_y = floor_center.y
	return car


func _enter_tree() -> void:
	if has_node("Sync"):
		return
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	for prop in ["synced_y", "door_closed", "phase"]:
		var path := NodePath(".:" + prop)
		cfg.add_property(path)
		cfg.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	sync.replication_config = cfg
	add_child(sync)


func _ready() -> void:
	sync_to_physics = true
	collision_layer = ChainBody.LAYER_WORLD
	collision_mask = 0
	var w := WIDTH
	var h := HEIGHT
	# Floor (top flush with the landing), back and side walls, roof. Open toward -z.
	_part(Vector3(0.0, -0.08, 0.0), Vector3(w + WALL * 2.0, 0.2, w + WALL * 2.0), "elevator")
	_part(Vector3(0.0, 0.025, 0.0), Vector3(w, 0.01, w), "metal", false)
	_part(Vector3(0.0, h * 0.5, w * 0.5 + WALL * 0.5), Vector3(w + WALL * 2.0, h, WALL), "elevator")
	_part(Vector3(-w * 0.5 - WALL * 0.5, h * 0.5, 0.0), Vector3(WALL, h, w), "elevator")
	_part(Vector3(w * 0.5 + WALL * 0.5, h * 0.5, 0.0), Vector3(WALL, h, w), "elevator")
	_part(Vector3(0.0, h + 0.05, 0.0), Vector3(w + WALL * 2.0, 0.1, w + WALL * 2.0), "elevator")
	_part(Vector3(0.0, h - 0.15, -w * 0.5), Vector3(w + 0.2, 0.3, 0.12), "hazard", false)
	for s: float in [-1.0, 1.0]:
		# Handrails and a strip of quilted padding, so it reads as a freight car, not a box.
		_part(Vector3(s * (w * 0.5 - 0.04), 0.95, 0.0), Vector3(0.05, 0.05, w - 0.4), "metal", false)
		_part(Vector3(s * (w * 0.5 - 0.01), 1.6, 0.2), Vector3(0.02, 1.4, w - 0.9), "partition", false)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(0.8, 1.0, 0.85)
	lamp.light_energy = 1.6
	lamp.omni_range = 5.0
	lamp.position = Vector3(0.0, h - 0.4, 0.0)
	add_child(lamp)
	_part(Vector3(0.0, h - 0.02, 0.0), Vector3(0.9, 0.04, 0.3), "glow", false)
	var sign := Label3D.new()
	sign.text = "FREIGHT ELEVATOR\nEVERYONE IN TO GO UP"
	sign.font_size = 40
	sign.pixel_size = 0.005
	sign.modulate = Color(1.0, 0.82, 0.15)
	sign.outline_size = 10
	sign.double_sided = false
	sign.position = Vector3(0.0, h - 0.5, -w * 0.5 - 0.14)
	sign.rotation = Vector3(0.0, PI, 0.0)
	add_child(sign)
	# Roll-up door: hangs from the header, scaled down to a thin roll when open.
	_door = Node3D.new()
	_door.position = Vector3(0.0, h, -w * 0.5 - WALL * 0.5)
	add_child(_door)
	var dm := MeshInstance3D.new()
	var dbox := BoxMesh.new()
	dbox.size = Vector3(w, h, 0.06)
	dm.mesh = dbox
	dm.position = Vector3(0.0, -h * 0.5, 0.0)
	dm.material_override = LevelKit.mat("shutter")
	_door.add_child(dm)
	_door.scale = Vector3(1.0, 0.04, 1.0)
	_door_shape = CollisionShape3D.new()
	var ds := BoxShape3D.new()
	ds.size = Vector3(w, h, 0.08)
	_door_shape.shape = ds
	_door_shape.position = Vector3(0.0, h * 0.5, -w * 0.5 - WALL * 0.5)
	_door_shape.disabled = true
	add_child(_door_shape)
	_motor = Sfx.loop_player("lift", -4.0, 25.0)
	_motor.position = Vector3(0.0, -0.3, 0.0)
	add_child(_motor)
	_last_y = position.y


func _part(at: Vector3, size: Vector3, key: String, collide: bool = true) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = at
	mi.material_override = LevelKit.mat(key)
	if key == "glow":
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	if collide:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		cs.position = at
		add_child(cs)


func is_busy() -> bool:
	return phase == Phase.CLOSING or phase == Phase.RIDING


func has_arrived() -> bool:
	return phase == Phase.ARRIVED


## Server: everyone is inside. Shut the door and go.
func server_start_ride() -> void:
	if not multiplayer.is_server() or phase != Phase.WAITING:
		return
	phase = Phase.CLOSING
	door_closed = true
	_t = 0.0
	_rpc_ride_fx.rpc(0)


## Server: back to the bottom with the door open (a layoff before anyone reached the pizzeria).
func server_reset() -> void:
	if not multiplayer.is_server():
		return
	phase = Phase.WAITING
	door_closed = false
	_t = 0.0
	position.y = low_y
	synced_y = low_y


## Server: park it at the top, door open (tests, and late fixes).
func server_park_top() -> void:
	if not multiplayer.is_server():
		return
	phase = Phase.ARRIVED
	door_closed = false
	position.y = high_y
	synced_y = high_y


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		_t += delta
		match phase:
			Phase.CLOSING:
				if _t >= CLOSE_TIME + DEPART_DELAY:
					phase = Phase.RIDING
					_t = 0.0
					_rpc_ride_fx.rpc(1)
			Phase.RIDING:
				position.y = move_toward(position.y, high_y, SPEED * delta)
				if position.y >= high_y - 0.001:
					position.y = high_y
					phase = Phase.ARRIVED
					_t = 0.0
					_rpc_ride_fx.rpc(2)
			Phase.ARRIVED:
				if door_closed and _t >= OPEN_DELAY:
					door_closed = false
		synced_y = position.y
	else:
		position.y = synced_y
	_door_shape.disabled = not door_closed
	if door_closed != _door_shown:
		_door_shown = door_closed
		var tw := create_tween()
		tw.tween_property(_door, "scale:y", 1.0 if door_closed else 0.04, CLOSE_TIME).set_trans(Tween.TRANS_BOUNCE if door_closed else Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		Sfx.play_at(self, "shutter", global_position + Vector3(0.0, HEIGHT, -WIDTH * 0.5), -2.0, 0.8 if door_closed else 1.0)
	var moving := absf(position.y - _last_y) > 0.0005
	_last_y = position.y
	if moving:
		Sfx.start_loop(_motor)
		_shake_t -= delta
		if _shake_t <= 0.0:
			_shake_t = 0.35
			var me := Net.get_local_player()
			if me != null and me.global_position.distance_to(global_position) < 4.0:
				me.add_shake(0.12)
	elif _motor.playing:
		_motor.stop()


## 0 door shut, 1 departing, 2 arrived (every peer).
@rpc("authority", "call_local", "reliable")
func _rpc_ride_fx(stage: int) -> void:
	var at := global_position + Vector3(0.0, HEIGHT * 0.7, 0.0)
	match stage:
		0:
			Sfx.play_at(self, "ding", at, 0.0, 1.0)
		1:
			Sfx.play_at(self, "slam", at, -2.0, 0.6)
			var me := Net.get_local_player()
			if me != null and me.global_position.distance_to(global_position) < 4.0:
				me.add_shake(0.6)
		2:
			Sfx.play_at(self, "ding", at, 2.0, 0.85)
			Sfx.play_at(self, "thump", at, -2.0, 0.7)
