extends Node
## Autoload "ScareDirector". The server decides WHEN and WHERE (scripted triggers plus a
## procedural director that picks on whoever wandered off); every peer plays the scare locally.
## Scares: lunge, lights_out, tile, figure, whisper, phone, slam, dennis, stain_pass.

const FIRST_DELAY: float = 50.0
const MIN_GAP: float = 38.0
const MAX_GAP: float = 75.0
const POOL: Array = [
	["lights_out", 2], ["tile", 2], ["whisper", 2], ["slam", 2], ["figure", 2], ["phone", 1], ["dennis", 1],
]

var scares_played: int = 0
var blackout_center: Vector3 = Vector3.ZERO
var blackout_radius: float = 0.0
var _blackout_until: int = 0
var _layer: CanvasLayer
var _overlay: ColorRect
var _next_t: float = FIRST_DELAY
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_layer = CanvasLayer.new()
	_layer.layer = 50
	add_child(_layer)
	_overlay = ColorRect.new()
	_overlay.color = Color(0.7, 0.0, 0.0, 0.0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_overlay)


func blackout_active() -> bool:
	return Time.get_ticks_msec() < _blackout_until


## Server: called at the start of every run.
func reset_director() -> void:
	_next_t = FIRST_DELAY


# --- Server: deciding ------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	if get_tree().get_first_node_in_group("level") == null or GameState.escaped:
		return
	_next_t -= delta
	if _next_t > 0.0:
		return
	_next_t = _rng.randf_range(MIN_GAP, MAX_GAP)
	for c in get_tree().get_nodes_in_group("custodian"):
		if c.call("is_hunting"):
			_next_t = 12.0  # never pile a fake scare on top of a real one
			return
	var players := Net.get_players()
	if players.is_empty():
		return
	trigger_for(_pick_kind(), _pick_target(players))


func _pick_kind() -> String:
	var total := 0
	for e in POOL:
		total += int(e[1])
	var r := _rng.randi() % total
	for e in POOL:
		r -= int(e[1])
		if r < 0:
			return String(e[0])
	return "whisper"


## Prefers whoever is farthest from everyone else: the one who wandered.
func _pick_target(players: Array[Player]) -> Player:
	var centroid := Vector3.ZERO
	for p in players:
		centroid += p.global_position
	centroid /= float(players.size())
	var best := players[0]
	for p in players:
		if p.global_position.distance_to(centroid) > best.global_position.distance_to(centroid):
			best = p
	return best


## Server: fire a scare aimed at a player; works out where it should happen.
func trigger_for(kind: String, p: Player) -> void:
	if not multiplayer.is_server() or p == null:
		return
	var fwd := Vector3(-sin(p.body_yaw), 0.0, -cos(p.body_yaw))
	var feet := p.global_position
	var pos := feet
	match kind:
		"lunge":
			pos = feet + fwd * 3.2
		"tile":
			var fx := Effects.find(p)
			if fx != null:
				var level := get_tree().get_first_node_in_group("level")
				var base_y: float = float(level.call("floor_of", feet.y)) * 5.0 if level != null else feet.y
				fx.fx_tile_drop.rpc(Vector3(feet.x + fwd.x * 1.2, base_y + 3.18, feet.z + fwd.z * 1.2))
			pos = feet
		"figure":
			pos = _visible_point(p, fwd, 9.0, 14.0)
		"dennis", "whisper":
			pos = feet - fwd * 2.4
		"phone", "slam":
			pos = feet + Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0)).normalized() * _rng.randf_range(7.0, 12.0)
		"stain_pass":
			pos = feet + fwd * 8.0
			for c in get_tree().get_nodes_in_group("custodian"):
				var cy: float = (c as Node3D).global_position.y
				if absf(cy - feet.y - 3.9) < 2.0:
					c.call("investigate", pos)
	trigger(kind, pos, p.peer_id)


func _visible_point(p: Player, fwd: Vector3, near: float, far: float) -> Vector3:
	var eye := p.eye_position()
	var space := p.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(eye, eye + fwd * far, ChainBody.LAYER_WORLD)
	var hit := space.intersect_ray(q)
	var dist := far
	if not hit.is_empty():
		dist = eye.distance_to(hit["position"]) - 0.8
	dist = clampf(dist, 2.5, far)
	if dist < near * 0.5:
		dist = maxf(2.5, dist)
	return Vector3(eye.x + fwd.x * dist, p.global_position.y, eye.z + fwd.z * dist)


## Server: fire a scare on every peer.
func trigger(kind: String, pos: Vector3, target_peer: int = 0) -> void:
	if not multiplayer.is_server():
		return
	_rpc_scare.rpc(kind, pos, target_peer)


@rpc("authority", "call_local", "reliable")
func _rpc_scare(kind: String, pos: Vector3, target_peer: int) -> void:
	play_local(kind, pos, target_peer)


# --- Every peer: playing -----------------------------------------------------------------------

func play_local(kind: String, pos: Vector3, target_peer: int = 0) -> void:
	scares_played += 1
	var me := Net.get_local_player()
	var targeted := me != null and me.peer_id == target_peer
	match kind:
		"lunge":
			Sfx.play(self, "stinger", 2.0)
			_spawn_lunger(pos)
			_flash(0.6)
			_shake(0.9, pos)
			GameState.post_message_local("UNSCHEDULED EVENT", 1.5)
		"lights_out":
			blackout_center = pos
			blackout_radius = 16.0
			_blackout_until = Time.get_ticks_msec() + 2600
			Sfx.play_at(self, "slam", pos + Vector3.UP * 3.0, -6.0, 0.6)
			if me != null:
				var behind := me.global_position + Vector3(randf_range(-1.0, 1.0), 1.6, randf_range(-1.0, 1.0)).normalized() * 1.5
				Sfx.play_at(self, "whisper", behind, 4.0, randf_range(0.85, 1.0), 12.0)
		"tile":
			pass  # Effects.fx_tile_drop already played it everywhere
		"figure":
			_spawn_figure(pos)
			Sfx.play_at(self, "thump", pos, -4.0, 0.6)
		"whisper":
			if targeted:
				Sfx.play_at(self, "whisper", pos + Vector3.UP * 1.6, 6.0, randf_range(0.85, 1.0), 10.0)
		"phone":
			Sfx.play_at(self, "phone", pos + Vector3.UP, 0.0, 1.0, 40.0)
		"slam":
			Sfx.play_at(self, "slam", pos + Vector3.UP, 4.0, randf_range(0.8, 1.0), 45.0)
			_shake(0.25, pos)
		"dennis":
			var look := me.global_position if me != null else pos + Vector3.FORWARD
			var d := build_dennis(pos, atan2(pos.x - look.x, pos.z - look.z))  # printed side faces you
			_add_temp(d, 14.0)
			if targeted:
				Sfx.play_at(self, "squeak", pos + Vector3.UP * 1.5, -8.0, 0.5, 8.0)
		"stain_pass":
			Sfx.play_at(self, "thump", pos + Vector3.UP * 3.5, -2.0, 0.7, 30.0)
			Sfx.play_at(self, "creak", pos + Vector3.UP * 3.5, 0.0, 1.2, 30.0)
			GameState.post_message_local("...something is moving in the ceiling.", 3.0)


func _flash(alpha: float) -> void:
	_overlay.color = Color(0.7, 0.0, 0.0, alpha)
	var tw := _overlay.create_tween()
	tw.tween_property(_overlay, "color:a", 0.0, 0.5)


func _shake(amount: float, at: Vector3) -> void:
	var me := Net.get_local_player()
	if me != null and me.global_position.distance_to(at) < 14.0:
		me.add_shake(amount)


func _add_temp(n: Node3D, seconds: float) -> void:
	var root := get_tree().current_scene
	if root == null:
		n.free()
		return
	root.add_child(n)
	get_tree().create_timer(seconds).timeout.connect(n.queue_free)


func _spawn_lunger(at: Vector3) -> void:
	var m := Node3D.new()
	m.name = "ScareMonster"
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.04, 0.0, 0.02)
	dark.roughness = 0.3
	var body := MeshInstance3D.new()
	var bm := CapsuleMesh.new()
	bm.radius = 0.45
	bm.height = 2.6
	body.mesh = bm
	body.position = Vector3(0.0, 1.3, 0.0)
	body.material_override = dark
	m.add_child(body)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.95, 0.85)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.85, 0.6)
	glow.emission_energy_multiplier = 5.0
	for sx: float in [-0.17, 0.17]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.08
		em.height = 0.16
		eye.mesh = em
		eye.position = Vector3(sx, 2.2, -0.38)
		eye.material_override = glow
		m.add_child(eye)
	var mouth := MeshInstance3D.new()
	var mm := BoxMesh.new()
	mm.size = Vector3(0.5, 0.5, 0.05)
	mouth.mesh = mm
	mouth.position = Vector3(0.0, 1.75, -0.42)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.5, 0.0, 0.0)
	red.emission_enabled = true
	red.emission = Color(0.9, 0.0, 0.0)
	red.emission_energy_multiplier = 2.0
	mouth.material_override = red
	m.add_child(mouth)
	for sx: float in [-1.0, 1.0]:
		var arm := MeshInstance3D.new()
		var am := CapsuleMesh.new()
		am.radius = 0.08
		am.height = 1.6
		arm.mesh = am
		arm.material_override = dark
		arm.position = Vector3(sx * 0.6, 1.9, -0.4)
		arm.rotation = Vector3(-1.2, 0.0, sx * 0.4)
		m.add_child(arm)
	_add_temp(m, 1.0)
	m.global_position = at
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		var target := Vector3(cam.global_position.x, at.y, cam.global_position.z)
		if target.distance_to(at) > 0.05:
			m.look_at(target, Vector3.UP)
	m.scale = Vector3(0.3, 0.3, 0.3)
	var tw := m.create_tween()
	tw.tween_property(m, "scale", Vector3(1.2, 1.2, 1.2), 0.07)
	tw.tween_property(m, "scale", Vector3.ONE, 0.1)
	if cam != null:
		var close := at.lerp(Vector3(cam.global_position.x, at.y, cam.global_position.z), 0.5)
		tw.parallel().tween_property(m, "global_position", close, 0.25)


func _spawn_figure(at: Vector3) -> void:
	var m := Node3D.new()
	m.name = "Figure"
	var black := StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color = Color(0.0, 0.0, 0.0)
	var body := MeshInstance3D.new()
	var bm := CapsuleMesh.new()
	bm.radius = 0.22
	bm.height = 2.3
	body.mesh = bm
	body.position = Vector3(0.0, 1.15, 0.0)
	body.material_override = black
	m.add_child(body)
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.17
	hm.height = 0.38
	head.mesh = hm
	head.position = Vector3(0.0, 2.45, 0.0)
	head.material_override = black
	m.add_child(head)
	for sx: float in [-0.3, 0.3]:
		var arm := MeshInstance3D.new()
		var am := CapsuleMesh.new()
		am.radius = 0.05
		am.height = 1.7
		arm.mesh = am
		arm.position = Vector3(sx, 1.35, 0.0)
		arm.material_override = black
		m.add_child(arm)
	_add_temp(m, 1.3)
	m.global_position = at


## Dennis from Accounts: a cardboard Employee-of-the-Month standee. Monsters never touch Dennis.
func build_dennis(pos: Vector3, yaw: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Dennis"
	root.position = pos
	root.rotation = Vector3(0.0, yaw, 0.0)
	var card := StandardMaterial3D.new()
	card.albedo_color = Color(0.62, 0.48, 0.3)
	card.roughness = 0.95
	var board := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.62, 1.78, 0.03)
	board.mesh = bm
	board.position = Vector3(0.0, 0.89, 0.0)
	board.material_override = card
	root.add_child(board)
	var printed := func(size: Vector3, at: Vector3, c: Color) -> void:
		var mi := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = size
		mi.mesh = b
		mi.position = at
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.9
		mi.material_override = m
		root.add_child(mi)
	printed.call(Vector3(0.5, 0.75, 0.01), Vector3(0.0, 1.0, -0.02), Color(0.22, 0.27, 0.4))  # suit
	printed.call(Vector3(0.08, 0.5, 0.012), Vector3(0.0, 1.08, -0.025), Color(0.75, 0.1, 0.1))  # tie
	printed.call(Vector3(0.3, 0.36, 0.01), Vector3(0.0, 1.55, -0.02), Color(0.93, 0.78, 0.62))  # face
	printed.call(Vector3(0.32, 0.08, 0.012), Vector3(0.0, 1.74, -0.025), Color(0.3, 0.2, 0.1))  # hair
	printed.call(Vector3(0.05, 0.03, 0.012), Vector3(-0.07, 1.6, -0.026), Color(0.05, 0.05, 0.05))
	printed.call(Vector3(0.05, 0.03, 0.012), Vector3(0.07, 1.6, -0.026), Color(0.05, 0.05, 0.05))
	printed.call(Vector3(0.16, 0.025, 0.012), Vector3(0.0, 1.47, -0.026), Color(0.6, 0.15, 0.15))  # big smile
	printed.call(Vector3(0.4, 0.45, 0.01), Vector3(0.0, 0.4, -0.02), Color(0.2, 0.2, 0.22))  # trousers
	var label := Label3D.new()
	label.text = "DENNIS\nEMPLOYEE OF THE MONTH"
	label.font_size = 26
	label.pixel_size = 0.004
	label.modulate = Color(1.0, 0.85, 0.2)
	label.outline_size = 6
	label.double_sided = false
	label.position = Vector3(0.0, 0.75, -0.03)
	label.rotation = Vector3(0.0, PI, 0.0)
	root.add_child(label)
	return root
