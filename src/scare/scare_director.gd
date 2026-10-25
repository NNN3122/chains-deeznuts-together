extends Node
## Autoload "ScareDirector". The server decides WHEN and WHERE (scripted triggers plus a
## procedural director that picks on whoever wandered off); every peer plays the scare locally.
## Every level: face (its monster's face lunges into yours), lunge (its monster rushes you out
## of the dark), ceiling_drop (it drops head first in front of you), crawler (it comes at you on
## all fours), peek (a face at the edge of your view, staring), hands (arms up out of the floor at
## your face), behind (a breath at your ear: it's there when you turn round), figure (its silhouette).
## Office: lights_out, tile, whisper, phone,
## slam, dennis.
## Pizzeria scares (played by Pizzeria.play_scare): jukebox_skip, balloon, vent_patter,
## pepperoni_eyes, bell, static_face, counter_bell, order_window, curtain, costume_rack,
## birthday_song. Each level offers its own pool (level.scare_pool) for where the target stands.
## Roof scares (HordeArena.play_scare): roof_hush, roof_glimpse, roof_drop, roof_swarm,
## roof_shadow, roof_scrape. The roof paces its own (RoofDread, level.paces_own_scares).

## Pacing (the office and the pizzeria; the roof has RoofDread). A scare every 16-34 s numbed
## people, so now the director waits for quiet, lets dread build on whoever wandered, and only
## then hits: the heartbeat climbs, the sound drops out, then the scare (or, sometimes, nothing).
const FIRST_DELAY: float = 35.0  # s into a run before the first build may start
const COOLDOWN_MIN: float = 30.0  # s after a scare before the next can start building
const COOLDOWN_MAX: float = 50.0
const QUIET_MIN: float = 8.0  # s with nothing hunting anyone (and nobody caught) before a build
const QUIET_MAX: float = 15.0
const BUILD_TIME: float = 4.5  # s from the first heartbeat to the scare
const HUSH_TIME: float = 1.2  # s at the end of the build where the world goes nearly silent
const HUSH_DB: float = -16.0  # how far the target's sound drops in the hush
const FAKE_CHANCE: float = 0.25  # a build that ends in a breath, footsteps or only the silence
const REPEAT_PENALTY: float = 0.25  # weight multiplier for the last two kinds played, so runs vary
const POOL: Array = [
	["face", 3], ["lunge", 2], ["ceiling_drop", 2], ["crawler", 2], ["peek", 2], ["hands", 2], ["behind", 2], ["lights_out", 2], ["tile", 2], ["whisper", 1], ["slam", 2], ["figure", 2], ["phone", 1], ["dennis", 1],
	["breath", 2], ["footsteps", 2], ["stalker", 1],
]

var scares_played: int = 0
var blackout_center: Vector3 = Vector3.ZERO
var blackout_radius: float = 0.0
var flicker_center: Vector3 = Vector3.ZERO
var flicker_radius: float = 0.0
var _blackout_until: int = 0
var _flicker_until: int = 0
var _layer: CanvasLayer
var _overlay: ColorRect
var _next_t: float = FIRST_DELAY
var _quiet_t: float = 0.0  # server: how long nothing has hunted anyone
var _quiet_need: float = QUIET_MIN
var _build_t: float = -1.0  # server: >= 0 while dread builds on _build_target
var _build_target: Player
var _dread_left: float = 0.0  # local: seconds of the build still to run on this screen
var _beat_t: float = 0.0
var _duck_base: float = 0.0
var _ducked: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _recent: Array[String] = []  # the last kinds played, so the next pick leans elsewhere


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


## The power came back on a floor (a fixed breaker panel): a lights-out there ends now.
func end_blackout_on_floor(floor_y: float) -> void:
	if blackout_active() and absf(blackout_center.y - floor_y) < 3.0:
		_blackout_until = 0


## Local: every light within radius of center goes dark for a while.
func blackout(center: Vector3, radius: float, msec: int) -> void:
	blackout_center = center
	blackout_radius = radius
	_blackout_until = Time.get_ticks_msec() + msec


func flicker_active() -> bool:
	return Time.get_ticks_msec() < _flicker_until


## Local: every light within radius of center gutters for a while (the warning before dark).
func flicker(center: Vector3, radius: float, msec: int) -> void:
	flicker_center = center
	flicker_radius = radius
	_flicker_until = Time.get_ticks_msec() + msec


## How long the lights_out scare keeps a spot dark: 12-20 s, the same on every peer for a spot.
static func lights_out_msec(pos: Vector3) -> int:
	var h := sin(pos.x * 3.17 + pos.z * 1.71) * 43758.5453
	return 12000 + int((h - floorf(h)) * 8000.0)


## Server: called at the start of every run.
func reset_director() -> void:
	_next_t = FIRST_DELAY
	_quiet_t = 0.0
	_build_t = -1.0
	_build_target = null
	_unduck()


# --- Server: deciding ------------------------------------------------------------------------

func _process(delta: float) -> void:
	_tick_local_dread(delta)
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	if get_tree().get_first_node_in_group("level") == null or GameState.escaped:
		return
	_next_t -= delta
	var busy := false
	for c in get_tree().get_nodes_in_group("monster"):
		if c.call("is_hunting") or int(c.get("grab_peer")) != 0:
			busy = true  # never pile a fake scare on top of a real one
	# A build in progress: it lands, or a real threat cancels it.
	if _build_t >= 0.0:
		if busy or _build_target == null or not is_instance_valid(_build_target):
			_cancel_build()
			return
		_build_t += delta
		if _build_t >= BUILD_TIME:
			_land_build()
		return
	if busy:
		_quiet_t = 0.0
		return
	_quiet_t += delta
	if _next_t > 0.0 or _quiet_t < _quiet_need:
		return
	var players := Net.get_players()
	if players.is_empty():
		return
	var target := _pick_target(players)
	var level := get_tree().get_first_node_in_group("level")
	if level != null and level.has_method("paces_own_scares") and level.call("paces_own_scares", target.global_position):
		_next_t = 5.0  # the roof waits for quiet and builds its own (RoofDread)
		return
	_build_t = 0.0
	_build_target = target
	_rpc_dread.rpc(target.peer_id, BUILD_TIME)


func _land_build() -> void:
	var target := _build_target
	_build_t = -1.0
	_build_target = null
	_next_t = _rng.randf_range(COOLDOWN_MIN, COOLDOWN_MAX)
	_quiet_t = 0.0
	_quiet_need = _rng.randf_range(QUIET_MIN, QUIET_MAX)
	if _rng.randf() < FAKE_CHANCE:
		var fake: String = ["breath", "footsteps", ""][_rng.randi() % 3]
		if fake != "":
			trigger_for(fake, target)
		return  # or only the silence, and then the room again
	trigger_for(_pick_kind(target.global_position), target)


func _cancel_build() -> void:
	var peer := _build_target.peer_id if _build_target != null and is_instance_valid(_build_target) else 0
	_build_t = -1.0
	_build_target = null
	_quiet_t = 0.0
	_rpc_dread.rpc(peer, 0.0)


## Every peer: the target hears the build (seconds 0 ends one early: something real came).
@rpc("authority", "call_local", "reliable")
func _rpc_dread(target_peer: int, seconds: float) -> void:
	var me := Net.get_local_player()
	if me == null or me.peer_id != target_peer:
		return
	_dread_left = seconds
	_beat_t = 0.0
	if seconds <= 0.0:
		_unduck()


## Local: a heartbeat that climbs from slow to racing, then the world drops to near silence for
## the last HUSH_TIME so the scare lands out of nothing.
func _tick_local_dread(delta: float) -> void:
	if _dread_left <= 0.0:
		return
	_dread_left -= delta
	var u := clampf(1.0 - _dread_left / BUILD_TIME, 0.0, 1.0)
	if _dread_left > HUSH_TIME:
		_beat_t -= delta
		if _beat_t <= 0.0:
			_beat_t = lerpf(0.95, 0.38, u)
			Sfx.play(self, "heartbeat", lerpf(-12.0, 0.0, u), 1.0)
	elif not _ducked:
		_ducked = true
		_duck_base = AudioServer.get_bus_volume_db(0)
		AudioServer.set_bus_volume_db(0, _duck_base + HUSH_DB)
	if _dread_left <= 0.0:
		_unduck()


func _unduck() -> void:
	_dread_left = 0.0
	if _ducked:
		_ducked = false
		AudioServer.set_bus_volume_db(0, _duck_base)


## Tests: is a build running (server), and start one now on a player.
func is_building() -> bool:
	return _build_t >= 0.0


func debug_build(p: Player) -> void:
	_next_t = 0.0
	_quiet_t = _quiet_need
	_build_t = 0.0
	_build_target = p
	_rpc_dread.rpc(p.peer_id, BUILD_TIME)


func _pick_kind(at: Vector3) -> String:
	var pool := POOL
	var level := get_tree().get_first_node_in_group("level")
	if level != null and level.has_method("scare_pool"):
		pool = level.call("scare_pool", at)
	var weights: Array[float] = []
	var total := 0.0
	for e in pool:
		var w := float(e[1])
		if _recent.has(String(e[0])):
			w *= REPEAT_PENALTY
		weights.append(w)
		total += w
	var r := _rng.randf() * total
	for i in pool.size():
		r -= weights[i]
		if r < 0.0:
			var kind := String(pool[i][0])
			_recent.append(kind)
			while _recent.size() > 2:
				_recent.pop_front()
			return kind
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
				var top: float = float(level.call("ceiling_y", feet)) if level != null and level.has_method("ceiling_y") else feet.y + 3.18
				fx.fx_tile_drop.rpc(Vector3(feet.x + fwd.x * 1.2, top - 0.02, feet.z + fwd.z * 1.2))
			pos = feet
		"figure", "pepperoni_eyes":
			pos = _visible_point(p, fwd, 9.0, 14.0)
		"dennis", "whisper", "balloon":
			pos = feet - fwd * 2.4
			if kind == "balloon":
				p.apply_knockback(fwd * 2.5 + Vector3.UP * 1.5)  # the flinch jerks the Line
		"vent_patter":
			pos = feet + fwd * 1.5
		"roof_drop":
			pos = feet + fwd * 1.3  # in your face
		"face", "ceiling_drop", "crawler", "peek", "hands", "behind":
			pos = feet  # played round the target's own camera
		"breath", "stalker", "roof_swarm":
			pos = feet - fwd * 1.6  # right behind you
		"footsteps":
			pos = feet - fwd * 6.0
		"phone", "slam", "bell":
			pos = feet + Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0)).normalized() * _rng.randf_range(7.0, 12.0)
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
	if targeted:
		_unduck()  # the hush ends the instant it lands
	match kind:
		"face":
			# The big one: whatever haunts this level, its face out of nowhere into yours, a scream,
			# the picture tearing red. Only the one it picked sees it; everyone near hears it.
			if targeted:
				_spawn_face(pos)
			else:
				Sfx.play_at(self, _level_scream(pos), pos + Vector3.UP * 1.6, 2.0, 0.9, 30.0)
				Sfx.caption(self, "someone screams", pos)
		"ceiling_drop", "crawler", "peek", "hands", "behind":
			# Played round the target's own camera; everyone near hears something.
			if targeted:
				match kind:
					"ceiling_drop":
						_spawn_ceiling_drop(pos)
					"crawler":
						_spawn_crawler(pos)
					"peek":
						_spawn_peek(pos)
					"hands":
						_spawn_hands(pos)
					_:
						_spawn_behind(pos)
			elif kind != "peek":
				Sfx.play_at(self, _level_scream(pos), pos + Vector3.UP * 1.6, -2.0, 0.9, 26.0)
		"lunge":
			Sfx.play(self, "stinger", 4.0)
			Sfx.play_at(self, _level_scream(pos), pos + Vector3.UP * 1.5, 4.0, 0.85, 25.0)
			_spawn_lunger(pos)
			_flash(0.6)
			_shake(1.1, pos)
			ScreenFx.jolt(0.45)
		"lights_out":
			# A gutter first, then out for long enough that you need the flashlight to move.
			flicker(pos, 16.0, 1400)
			blackout_center = pos
			blackout_radius = 16.0
			_blackout_until = Time.get_ticks_msec() + 1400 + lights_out_msec(pos)
			Sfx.play_at(self, "slam", pos + Vector3.UP * 3.0, -6.0, 0.6)
			Sfx.caption(self, "the lights go out", pos + Vector3.UP * 3.0)
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
		"breath":
			# The quiet one: a breath at your ear, and nothing there when you turn.
			if targeted:
				Sfx.play_at(self, "whisper", pos + Vector3.UP * 1.6, -2.0, 0.55, 6.0)
				Sfx.caption(self, "breathing, close", pos + Vector3.UP * 1.6)
		"footsteps":
			# Someone walking up behind you, slowing as they get close. Then stopping.
			for k in 6:
				get_tree().create_timer(0.1 + 0.38 * float(k) + 0.06 * float(k * k)).timeout.connect(func() -> void:
					if is_inside_tree():
						var me2 := Net.get_local_player()
						var back := pos if me2 == null else me2.global_position - (me2.global_position - pos).normalized() * (6.0 - float(k) * 0.9)
						Sfx.play_at(self, "step", back, -2.0 + float(k) * 0.6, 0.75, 20.0))
			Sfx.caption(self, "footsteps behind you, closing", pos)
		"stalker":
			# Builds: lights gutter, a figure stands behind you for a breath, then the stinger when
			# you turn. Dread first, bang second.
			var me3 := Net.get_local_player()
			blackout_center = pos
			blackout_radius = 9.0
			_blackout_until = Time.get_ticks_msec() + 1800
			_spawn_figure(pos)
			if me3 != null and me3.global_position.distance_to(pos) < 4.0:
				get_tree().create_timer(1.1).timeout.connect(func() -> void:
					if is_inside_tree():
						Sfx.play(self, "stinger", -2.0)
						_flash(0.35)
						_shake(0.6, pos))
		_:
			# A level's own scare (the pizzeria has its curtain, its jukebox, its bell).
			var level := get_tree().get_first_node_in_group("level")
			if level != null and level.has_method("play_scare"):
				level.call("play_scare", kind, pos, targeted)


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


## Which level a spot is in: 0 the offices, 1 the pizzeria, 2 the roof.
func _level_index(pos: Vector3) -> int:
	var level := get_tree().get_first_node_in_group("level")
	if level != null and level.has_method("level_index_at"):
		return int(level.call("level_index_at", pos))
	return 0


## The scream of whatever haunts the level at pos: the Hire's, Pappy's voice chip, the Jumper's mouthparts.
func _level_scream(pos: Vector3) -> String:
	return ["scream", "pappy_scream", "spider_shriek", "scream"][clampi(_level_index(pos), 0, 3)]


## The body of whatever haunts that level, built (a HireBody, a PappyBody or a JumperBody).
func _level_body(idx: int) -> Node3D:
	match idx:
		1:
			var p := PappyBody.new()
			p.build()
			p.arm_l.rotation.x = 1.6  # reaching for you
			p.arm_r.rotation.x = 1.6
			return p
		2:
			var j := JumperBody.new()
			j.build(1.0)
			for i in j.legs.size():
				if i < 2:
					j.legs[i].rotation.z = (1.0 if i % 2 == 1 else -1.0) * 1.3  # the front pair up
			return j
		3:
			var g := GroundskeeperBody.new()
			g.build()
			g.arm_l.rotation = Vector3(1.9, 0.0, -0.3)  # both long hands out at you
			g.arm_r.rotation = Vector3(1.9, 0.0, 0.3)
			g.hips.rotation.x = -0.35
			return g
	var h := HireBody.new()
	h.build()
	h.arm_l.rotation = Vector3(1.9, 0.0, -0.3)  # both arms out at you
	h.arm_r.rotation = Vector3(1.9, 0.0, 0.3)
	h.hips.rotation.x = -0.35
	return h


## Local: the face of this level's monster, out of nowhere, up into the camera, a scream, held a
## moment shaking, gone. Lit by its own sick light so the dark can't hide it.
func _spawn_face(pos: Vector3) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var idx := _level_index(pos)
	var face := Node3D.new()
	face.name = "ScareFace"
	var m: Mesh
	var mat: Material
	var center := Vector3.ZERO
	match idx:
		1:
			m = PappyBody.face()
			mat = Sculpt.material(0.25, 0.3, 0.0, 0.1, 0.55)
			center = Vector3(0.0, 0.3, -0.3)
		2:
			m = JumperBody.face()
			mat = Sculpt.material(0.45, 0.5, 0.0, 0.0, 0.35)
			center = Vector3(0.0, -0.12, -0.2)
		3:
			m = GroundskeeperBody.gk_head()
			mat = Sculpt.material(0.12, 0.3, 0.0, 0.0, 0.7)
			center = Vector3(0.0, 0.22, -0.1)
		_:
			m = HireBody.skull(true)
			mat = Sculpt.material(0.3, 0.5, 0.75, 0.15, 0.5)
			center = Vector3(0.0, 0.22, -0.1)
	Sculpt.put(face, m, mat, -center)
	if idx == 0:
		HireBody.add_eyes(face, -center)
	if idx == 0 or idx == 3:
		var jaw := Node3D.new()  # its jaw hanging open, far too wide
		jaw.position = HireBody.JAW_HINGE - center
		jaw.rotation.x = -1.0
		face.add_child(jaw)
		Sculpt.put(jaw, GroundskeeperBody.gk_jaw() if idx == 3 else HireBody.jaw_mesh(), mat)
	if idx == 1:
		for x: float in [-0.14, 0.14]:  # his eyes, burning
			var e := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radial_segments = 12  # a glowing eye: a few hundred triangles, not four thousand
			sm.rings = 6
			sm.radius = 0.022
			sm.height = 0.044
			e.mesh = sm
			e.material_override = LevelKit.mat("pepperoni")
			e.position = Vector3(x, 0.4, -0.29) - center
			face.add_child(e)
	var light := OmniLight3D.new()
	light.light_color = Color(0.85, 1.0, 0.75) if idx != 1 else Color(1.0, 0.35, 0.2)
	light.light_energy = 2.5
	light.omni_range = 2.5
	light.position = Vector3(0.25, 0.35, 0.6)  # between it and you, a little above
	face.add_child(light)
	cam.add_child(face)
	face.rotation = Vector3(0.0, PI, 0.0)  # its -z face toward the camera
	face.position = Vector3(0.35, -0.15, -4.0)
	face.scale = Vector3.ONE * 0.7
	Sfx.play(self, "stinger", 6.0)
	Sfx.play(self, ["scream", "pappy_scream", "spider_shriek"][clampi(idx, 0, 2)], 3.0, 1.0)
	var tw := face.create_tween()
	tw.tween_property(face, "position", Vector3(0.0, -0.02, -0.34 if idx != 1 else -0.62), 0.16).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(face, "scale", Vector3.ONE, 0.16)
	tw.tween_callback(func() -> void:
		_flash(0.55)
		ScreenFx.jolt(0.5)
		var me := Net.get_local_player()
		if me != null:
			me.add_shake(1.0))
	for k in 6:
		tw.tween_property(face, "rotation", Vector3(randf_range(-0.12, 0.12), PI + randf_range(-0.15, 0.15), randf_range(-0.25, 0.25)), 0.06)
	tw.tween_callback(face.queue_free)


## The big hit of a jump scare on this screen: the sting, a red flash, the picture tearing, a shake.
func _hit(strength: float = 1.0) -> void:
	var me := Net.get_local_player()
	Sfx.play(self, "stinger", 4.0 * strength)
	Sfx.play(self, _level_scream(me.global_position) if me != null else "scream", 1.0 * strength, randf_range(0.88, 1.0))
	_flash(0.55 * strength)
	ScreenFx.jolt(0.45 * strength)
	if me != null:
		me.add_shake(strength)


## A light of its own for a scare body, so the dark can't hide it.
func _scare_light(parent: Node3D, at: Vector3, idx: int) -> void:
	var light := OmniLight3D.new()
	light.light_color = Color(0.85, 1.0, 0.75) if idx != 1 else Color(1.0, 0.35, 0.2)
	light.light_energy = 2.2
	light.omni_range = 3.5
	light.position = at
	parent.add_child(light)


## Local: this level's monster drops head-first out of the ceiling right in front of your face,
## hanging upside down, twitching, and is yanked back up into the dark.
func _spawn_ceiling_drop(pos: Vector3) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var idx := _level_index(pos)
	var m := _level_body(idx)
	m.name = "ScareDrop"
	if m is HireBody:
		(m as HireBody).jaw.rotation.x = -0.9
		(m as HireBody).arm_l.rotation.x = PI - 0.3  # hanging down past its head, toward you
		(m as HireBody).arm_r.rotation.x = PI - 0.3
	var fwd := -cam.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var face_at := cam.global_position + fwd * 0.9
	var head_h := 1.9 if idx == 0 else (2.35 if idx == 1 else 1.1)
	_add_temp(m, 1.6)
	m.global_position = face_at + Vector3.UP * (head_h + 3.0)
	m.look_at(m.global_position - fwd * 2.0, Vector3.UP)  # its -z front at you
	m.rotate_object_local(Vector3.FORWARD, PI)  # upside down
	_scare_light(m, Vector3(0.0, head_h - 0.3, -0.6), idx)  # body space: by the head, before the flip
	var tw := m.create_tween()
	tw.tween_property(m, "global_position", face_at + Vector3.UP * (head_h - 0.05), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_hit)
	for k in 5:
		tw.tween_property(m, "global_position", face_at + Vector3.UP * (head_h + randf_range(-0.08, 0.08)) + Vector3(randf_range(-0.06, 0.06), 0.0, 0.0), 0.12)
	tw.tween_property(m, "global_position", face_at + Vector3.UP * (head_h + 4.0), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## Local: this level's monster on all fours, coming at you along the floor far too fast, skittering;
## it reaches you, screams, and is gone.
func _spawn_crawler(pos: Vector3) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var idx := _level_index(pos)
	var m := _level_body(idx)
	m.name = "ScareCrawler"
	if m is HireBody:
		var h := m as HireBody
		h.hips.rotation.x = -1.35  # flat out, face first
		h.hips.position.y = 0.72
		h.head.rotation.x = 1.25  # head up, looking at you
		h.jaw.rotation.x = -0.8
		for limb: Node3D in [h.arm_l, h.arm_r, h.thigh_l, h.thigh_r]:
			limb.rotation.x = 1.35  # down to the floor
	elif m is PappyBody:
		m.rotation.x = -1.2
	var fwd := -cam.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var feet := Vector3(cam.global_position.x, pos.y, cam.global_position.z)
	var start := feet + fwd * 8.0 + fwd.cross(Vector3.UP) * randf_range(-1.0, 1.0)
	var end := feet + fwd * 1.9
	_add_temp(m, 1.3)
	m.global_position = start
	var r := m.rotation
	m.look_at(feet, Vector3.UP)
	m.rotation.x += r.x
	_scare_light(m, Vector3(0.0, 1.0, -1.0), idx)
	Sfx.play_at(self, "skitter", start, 4.0, 1.4, 30.0)
	var tw := m.create_tween()
	var legs: Array[Node3D] = []
	if m is HireBody:
		var h := m as HireBody
		legs = [h.arm_l, h.thigh_r, h.arm_r, h.thigh_l]
	for k in 7:
		var u := float(k + 1) / 7.0
		var at := start.lerp(end, u) + fwd.cross(Vector3.UP) * randf_range(-0.25, 0.25)
		tw.tween_property(m, "global_position", at, 0.085)
		for i in legs.size():
			tw.parallel().tween_property(legs[i], "rotation:x", 1.35 + (0.45 if (k + i) % 2 == 0 else -0.45), 0.085)
	# The last of it: it springs up off the floor at your face.
	var pounce := Vector3(cam.global_position.x, pos.y, cam.global_position.z) + fwd * 0.75 + Vector3.UP * maxf(0.0, cam.global_position.y - pos.y - 0.95)
	tw.tween_property(m, "global_position", pounce, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(m, "rotation:x", m.rotation.x + 0.6, 0.1)
	tw.tween_callback(_hit)
	tw.tween_interval(0.25)
	tw.tween_callback(m.queue_free)


## Local: a face slides in at the edge of your view, close, and stares. No sound but a breath. Then
## it snaps away.
func _spawn_peek(pos: Vector3) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var idx := _level_index(pos)
	var side := -1.0 if randf() < 0.5 else 1.0
	var face := _face_node(idx)
	face.name = "ScarePeek"
	cam.add_child(face)
	face.rotation = Vector3(0.0, PI, side * 0.35)  # its face toward you, tilted
	# The edge of the frame at that depth, whatever the field of view and the window's shape.
	var vp := get_viewport().get_visible_rect().size
	var edge := 0.9 * tan(deg_to_rad(cam.fov) * 0.5) * (vp.x / maxf(vp.y, 1.0))
	face.position = Vector3(side * (edge + 0.35), 0.05, -0.9)  # just outside the frame
	Sfx.play(self, "whisper", -4.0, 0.5)
	var tw := face.create_tween()
	tw.tween_property(face, "position", Vector3(side * (edge - 0.16), 0.05, -0.9), 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.1)
	tw.tween_callback(func() -> void: Sfx.play(self, "click", 0.0, 0.6))
	tw.tween_property(face, "position", Vector3(side * (edge + 0.6), 0.05, -0.9), 0.1)
	tw.tween_callback(face.queue_free)


## Local: arms burst up out of the floor into your view, long fingers clawing at your face.
func _spawn_hands(pos: Vector3) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var idx := _level_index(pos)
	var root := Node3D.new()
	root.name = "ScareHands"
	cam.add_child(root)
	var mat := Sculpt.material(0.3, 0.5, 0.75, 0.15, 0.5)
	var xs: Array[float] = [-0.42, -0.15, 0.14, 0.4]
	for i in xs.size():
		var arm := Node3D.new()
		root.add_child(arm)
		var mesh: Mesh = HireBody.arm(1.0 if i % 2 == 0 else -1.0)
		if idx == 1:
			mesh = PappyBody.arm(1.0 if i % 2 == 0 else -1.0)
			mat = Sculpt.material(0.15, 0.2, 0.0, 0.0, 0.5)
		elif idx == 2:
			mesh = JumperBody.lower_leg(1.0)
			mat = Sculpt.material(0.45, 0.5, 0.0, 0.0, 0.35)
		elif idx == 3:
			mesh = GroundskeeperBody.gk_arm(1.0 if i % 2 == 0 else -1.0)
			mat = Sculpt.material(0.08, 0.04, 1.0, 0.02, 1.0)
		var mi := Sculpt.put(arm, mesh, mat)
		mi.rotation = Vector3(PI, 0.0, -xs[i] * 0.8) if idx != 2 else Vector3(0.0, 0.0, PI * 0.5 + xs[i] * 0.6)
		arm.position = Vector3(xs[i], -2.0, -0.55 - 0.08 * float(i % 2))
		var tw := arm.create_tween()
		tw.tween_interval(0.05 * float(i))
		tw.tween_property(arm, "position:y", -1.0 + 0.12 * float(i % 2), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		for k in 4:
			tw.tween_property(arm, "rotation:z", randf_range(-0.25, 0.25), 0.1)
		tw.tween_property(arm, "position:y", -2.4, 0.2)
	_scare_light(root, Vector3(0.0, -0.4, -0.3), idx)
	_hit(0.8)
	get_tree().create_timer(1.1).timeout.connect(root.queue_free)


## Local: it is standing right behind you. A breath at your ear. Turn round and it screams in
## your face; don't, and after a few seconds it's simply gone.
func _spawn_behind(pos: Vector3) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var idx := _level_index(pos)
	var m := _level_body(idx)
	m.name = "ScareBehind"
	if m is HireBody:
		# Stooped over you, its face at the height of yours, mouth open, hands up.
		var h := m as HireBody
		h.hips.position.y = 0.72
		h.hips.rotation.x = -0.5
		h.head.rotation.x = 0.55
		h.jaw.rotation.x = -0.9
	var fwd := -cam.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var feet := Vector3(cam.global_position.x, pos.y, cam.global_position.z)
	var lurker := Lurker.new()
	lurker.body = m
	lurker.director = self
	get_tree().current_scene.add_child(lurker)
	lurker.global_position = feet - fwd * 1.4
	lurker.add_child(m)
	lurker.look_at(feet, Vector3.UP)
	_scare_light(m, Vector3(0.0, 1.5, -0.8), idx)
	Sfx.play_at(self, "whisper", lurker.global_position + Vector3.UP * 1.7, 2.0, 0.5, 6.0)
	Sfx.caption(self, "breathing, right behind you", lurker.global_position + Vector3.UP * 1.6)


## The thing standing behind you (_spawn_behind): it waits for you to look at it.
class Lurker extends Node3D:
	const WAIT: float = 5.0  # s before it gives up and is just gone
	const SEEN_ANGLE: float = 0.55  # rad off the centre of your view
	var body: Node3D
	var director: Node
	var _t: float = 0.0
	var _done: bool = false

	func _process(delta: float) -> void:
		_t += delta
		if _done:
			return
		if _t > WAIT:
			queue_free()
			return
		var cam := get_viewport().get_camera_3d()
		if cam == null:
			return
		var to := global_position + Vector3.UP * 1.5 - cam.global_position
		if (-cam.global_transform.basis.z).angle_to(to) < SEEN_ANGLE:
			_done = true
			director.call("_hit", 1.0)
			var tw := create_tween()
			var close := global_position.lerp(Vector3(cam.global_position.x, global_position.y, cam.global_position.z), 0.55)
			tw.tween_property(self, "global_position", close, 0.12)
			tw.tween_interval(0.35)
			tw.tween_callback(queue_free)


## A head on its own for a camera-attached scare, facing -z, centred on its face.
func _face_node(idx: int) -> Node3D:
	var face := Node3D.new()
	var mat: Material
	match idx:
		1:
			mat = Sculpt.material(0.25, 0.3, 0.0, 0.1, 0.55)
			Sculpt.put(face, PappyBody.face(), mat, -Vector3(0.0, 0.3, -0.3))
		2:
			mat = Sculpt.material(0.45, 0.5, 0.0, 0.0, 0.35)
			Sculpt.put(face, JumperBody.face(), mat, -Vector3(0.0, -0.12, -0.2))
		3:
			mat = Sculpt.material(0.12, 0.3, 0.0, 0.0, 0.7)
			var gc := Vector3(0.0, 0.22, -0.1)
			Sculpt.put(face, GroundskeeperBody.gk_head(), mat, -gc)
			var gjaw := Node3D.new()
			gjaw.position = HireBody.JAW_HINGE - gc
			gjaw.rotation.x = -0.35
			face.add_child(gjaw)
			Sculpt.put(gjaw, GroundskeeperBody.gk_jaw(), mat)
		_:
			mat = Sculpt.material(0.3, 0.5, 0.75, 0.15, 0.5)
			var center := Vector3(0.0, 0.22, -0.1)
			Sculpt.put(face, HireBody.skull(true), mat, -center)
			HireBody.add_eyes(face, -center)
			var jaw := Node3D.new()
			jaw.position = HireBody.JAW_HINGE - center
			jaw.rotation.x = -0.35
			face.add_child(jaw)
			Sculpt.put(jaw, HireBody.jaw_mesh(), mat)
	_scare_light(face, Vector3(0.2, 0.2, -0.5), idx)
	return face


## Local: this level's monster rushes you from the dark ahead, arms out, and is gone.
func _spawn_lunger(at: Vector3) -> void:
	var m := _level_body(_level_index(at))
	m.name = "ScareMonster"
	var light := OmniLight3D.new()
	light.light_color = Color(0.9, 0.2, 0.1)
	light.light_energy = 3.0
	light.omni_range = 4.0
	light.position = Vector3(0.0, 1.6, -1.2)
	m.add_child(light)
	_add_temp(m, 0.9)
	m.global_position = at
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		var target := Vector3(cam.global_position.x, at.y, cam.global_position.z)
		if target.distance_to(at) > 0.05:
			m.look_at(target, Vector3.UP)
	if cam != null:
		var close := at.lerp(Vector3(cam.global_position.x, at.y, cam.global_position.z), 0.7)
		m.create_tween().tween_property(m, "global_position", close, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## Local: this level's monster as a black silhouette, standing there for a breath.
func _spawn_figure(at: Vector3) -> void:
	var m := _level_body(_level_index(at))
	m.name = "Figure"
	var black := StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color = Color(0.0, 0.0, 0.0)
	for n in m.find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).material_override = black
	_add_temp(m, 1.3)
	m.global_position = at
	var me := Net.get_local_player()
	if me != null:
		var target := Vector3(me.global_position.x, at.y, me.global_position.z)
		if target.distance_to(at) > 0.05:
			m.look_at(target, Vector3.UP)  # its -z front at you


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
	label.shaded = true
	label.outline_size = 6
	label.double_sided = false
	label.position = Vector3(0.0, 0.75, -0.03)
	label.rotation = Vector3(0.0, PI, 0.0)
	root.add_child(label)
	return root
