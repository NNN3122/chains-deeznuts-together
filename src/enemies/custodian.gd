class_name Custodian
extends Node3D
## The original Custodian, restored on B3 alongside one Hollow Hire.
## Blind. Hunts by sound (anything in the "noise_source" group). Seen only as a bruise-colored
## stain moving across the ceiling, dimming lights and shedding dust, until it reaches someone:
## then a tile drops, an arm comes down, and it starts LIFTING them.
## It only lifts, so the Line is the counter: teammates standing near the victim hold them down
## (bracing holds twice as hard). A flashlight held on it, two pistol hits or a blast make it let go.
## If the victim is lifted into the ceiling, the whole group is laid off to the last checkpoint.
## Server simulates; position, state and grab are replicated; everything visual runs on every peer.

enum CState { WANDER, INVESTIGATE, HUNT, GRAB, RETREAT }

const PLENUM_HEIGHT: float = 3.9
const CEILING_HEIGHT: float = 3.2
const WANDER_SPEED: float = 1.6
const INVESTIGATE_SPEED: float = 3.0
const HUNT_SPEED: float = 4.8  # walking is 4.2: walking away barely works; running is loud
const RETREAT_SPEED: float = 6.0
const HEAR_RADIUS: float = 30.0
const INVESTIGATE_THRESHOLD: float = 18.0
const HUNT_THRESHOLD: float = 38.0
const TRACK_THRESHOLD: float = 11.0
const LOSE_TRACK_TIME: float = 4.0
const GRAB_RADIUS: float = 1.25
const LIFT_SPEED: float = 1.0  # m/s with nobody holding on
const HOLD_RESIST: float = 3.0  # e.g. one braced teammate (2) + one standing (1)
const RESIST_RADIUS: float = 7.0
const KILL_LIFT: float = 1.9
const GIVE_UP_TIME: float = 3.0  # seconds held at a standstill before it lets go
const BURN_TO_RELEASE: float = 0.9
const BURN_TO_RETREAT: float = 1.6
const HITS_TO_RETREAT: int = 2
const RETREAT_TIME: float = 9.0
const BEAM_ANGLE: float = 0.42  # radians (~24 degrees): the beam's whole cone, not just its center
const BEAM_RANGE: float = 16.0
const BURN_DECAY: float = 0.25  # per second the burn fades while the beam is off it
const DWELL_SECONDS: float = 7.0  # standing in one spot this long on its floor: it comes to look

var floor_index: int = 0
var floor_y: float = 0.0
var bounds: Rect2 = Rect2(0.0, 0.0, 36.0, 36.0)  # x/z area it can roam
var dormant_until_heard: bool = false  # the first floor's Custodian waits for a real noise
var debug_frozen: bool = false  # tests: hold it still and deaf

# Replicated.
var synced_position: Vector3 = Vector3.ZERO
var cstate: int = CState.WANDER
var hunt_peer: int = 0
var grab_peer: int = 0
var grab_lift: float = 0.0
var burn_fraction: float = 0.0  # replicated: 0..1 of the light it has taken (HUD feedback)

# Server.
var _dwell: Dictionary = {}  # peer -> [position, seconds]
var _hiss_t: float = 0.0
var _target: Vector3 = Vector3.ZERO
var _hunt_node: Node3D = null
var _hunt_pos: Vector3 = Vector3.ZERO
var _lose_t: float = 0.0
var _linger: float = 0.0
var _retreat_t: float = 0.0
var _burn: float = 0.0
var _hits: int = 0
var _hold_t: float = 0.0
var _grabbed: Player = null
var _grab_xz: Vector2 = Vector2.ZERO
var _grab_base_y: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Visual (every peer).
var _stain: Decal
var _dust: GPUParticles3D
var _creak: AudioStreamPlayer3D
var _hitbox: Area3D
var _hole: MeshInstance3D
var _eyes: Node3D
var _arm: Array[MeshInstance3D] = []
var _claws: Node3D
var _hole_glow: OmniLight3D
var _shown_grab_peer: int = 0
var _thump_t: float = 0.0
var _caption_t: float = 0.0
var _last_pos: Vector3 = Vector3.ZERO
var _visual_speed: float = 0.0


func _enter_tree() -> void:
	if has_node("Sync"):
		return
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	for prop in ["synced_position", "cstate", "hunt_peer", "grab_peer", "grab_lift", "burn_fraction"]:
		var path := NodePath(".:" + prop)
		cfg.add_property(path)
		cfg.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	sync.replication_config = cfg
	add_child(sync)


func _ready() -> void:
	add_to_group("custodian")
	add_to_group("monster")
	_rng.seed = 7919 * (floor_index + 1)
	global_position = Vector3(bounds.get_center().x, floor_y + PLENUM_HEIGHT, bounds.get_center().y)
	synced_position = global_position
	_last_pos = global_position
	_pick_wander_target()
	_build_visuals()


func _build_visuals() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(0.09, 0.02, 0.05, 0.95))
	grad.set_color(1, Color(0.2, 0.08, 0.06, 0.0))
	grad.add_point(0.55, Color(0.16, 0.04, 0.07, 0.7))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 128
	tex.height = 128
	_stain = Decal.new()
	_stain.texture_albedo = tex
	_stain.size = Vector3(2.6, 1.2, 2.6)
	_stain.rotation = Vector3(PI, 0.0, 0.0)  # project upward onto the underside of the ceiling
	_stain.upper_fade = 0.2
	_stain.lower_fade = 0.2
	add_child(_stain)
	_dust = GPUParticles3D.new()
	_dust.amount = 30
	_dust.lifetime = 2.0
	_dust.emitting = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.8, 0.02, 0.8)
	pm.direction = Vector3(0.0, -1.0, 0.0)
	pm.spread = 15.0
	pm.initial_velocity_min = 0.1
	pm.initial_velocity_max = 0.5
	pm.gravity = Vector3(0.0, -1.2, 0.0)
	pm.color = Effects.DUST_COLOR
	_dust.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.04, 0.04)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.vertex_color_use_as_albedo = true
	q.material = qm
	_dust.draw_pass_1 = q
	add_child(_dust)
	_creak = Sfx.loop_player("creak", -14.0, 28.0)
	add_child(_creak)
	_hitbox = Area3D.new()
	_hitbox.collision_layer = ChainBody.LAYER_MONSTER
	_hitbox.collision_mask = 0
	_hitbox.monitoring = false
	var hs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.0
	hs.shape = sphere
	_hitbox.add_child(hs)
	add_child(_hitbox)
	_hole = MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.62, 0.02, 0.62)
	_hole.mesh = hm
	_hole.material_override = LevelKit.mat("black_hole")
	_hole.visible = false
	add_child(_hole)
	_eyes = Node3D.new()
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(1.0, 0.15, 0.05)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(1.0, 0.15, 0.05)
	eye_mat.emission_energy_multiplier = 6.0
	for ex: float in [-0.11, 0.11]:
		var e := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radial_segments = 12
		em.rings = 6
		em.radius = 0.035
		em.height = 0.07
		e.mesh = em
		e.position = Vector3(ex, 0.0, 0.0)
		e.material_override = eye_mat
		_eyes.add_child(e)
	_eyes.visible = false
	add_child(_eyes)
	# A wet black limb, sinews standing out, catching the hole's red light at its edges.
	var flesh := CustodianParts.material()
	for i in 4:
		var seg := MeshInstance3D.new()
		seg.mesh = CustodianParts.segment(0.075 - 0.01 * float(i))
		seg.material_override = flesh
		seg.visible = false
		add_child(seg)
		_arm.append(seg)
	_claws = Node3D.new()
	Sculpt.put(_claws, CustodianParts.hand(), flesh, Vector3(0.0, 0.25, 0.0))
	_claws.visible = false
	add_child(_claws)
	_hole_glow = OmniLight3D.new()
	_hole_glow.light_color = Color(1.0, 0.12, 0.05)
	_hole_glow.light_energy = 2.2
	_hole_glow.omni_range = 4.5
	_hole_glow.visible = false
	add_child(_hole_glow)


func stain_point() -> Vector3:
	return Vector3(global_position.x, floor_y + CEILING_HEIGHT - 0.02, global_position.z)


func is_hunting() -> bool:
	return cstate == CState.HUNT or cstate == CState.GRAB


# --- Server -----------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		_server_tick(delta)
	else:
		global_position = global_position.lerp(synced_position, clampf(delta * 10.0, 0.0, 1.0))
	_update_visuals(delta)


func _server_tick(delta: float) -> void:
	if debug_frozen and cstate != CState.GRAB:
		return
	if cstate != CState.GRAB and not _anyone_on_floor():
		return  # asleep while nobody is on its floor
	var heard := _loudest()
	var node: Node3D = heard[0]
	var eff: float = heard[1]
	if dormant_until_heard:
		if eff < INVESTIGATE_THRESHOLD:
			return
		dormant_until_heard = false
	_tick_dwell(delta)
	match cstate:
		CState.WANDER:
			_move_toward(_target, WANDER_SPEED, delta)
			if _flat_dist(_target) < 0.5:
				_pick_wander_target()
			_react(node, eff)
		CState.INVESTIGATE:
			_move_toward(_target, INVESTIGATE_SPEED, delta)
			_react(node, eff)
			if _flat_dist(_target) < 0.6:
				_linger -= delta
				if _linger <= 0.0:
					cstate = CState.WANDER
					_pick_wander_target()
			_tick_burn(delta, stain_point(), BURN_TO_RETREAT)
		CState.HUNT:
			_tick_hunt(delta, node, eff)
		CState.GRAB:
			_tick_grab(delta)
		CState.RETREAT:
			_move_toward(_target, RETREAT_SPEED, delta)
			_retreat_t -= delta
			if _retreat_t <= 0.0:
				cstate = CState.WANDER
				_hits = 0
				_burn = 0.0
				_pick_wander_target()
	synced_position = global_position


func _react(node: Node3D, eff: float) -> void:
	if node == null:
		return
	if eff > HUNT_THRESHOLD:
		_start_hunt(node)
	elif eff > INVESTIGATE_THRESHOLD:
		cstate = CState.INVESTIGATE
		_target = _clamp_to_bounds(node.global_position)
		_linger = 3.0


func _start_hunt(node: Node3D) -> void:
	if cstate != CState.HUNT:
		var fx := Effects.find(self)
		if fx != null:
			fx.fx_sound.rpc("cust_hiss", stain_point(), -2.0, randf_range(0.85, 1.0))
	cstate = CState.HUNT
	_hunt_node = node
	_hunt_pos = node.global_position
	_lose_t = 0.0
	hunt_peer = (node as Player).peer_id if node is Player else 0


func _tick_hunt(delta: float, loudest: Node3D, loudest_eff: float) -> void:
	if _hunt_node == null or not is_instance_valid(_hunt_node) or _hunt_node.is_queued_for_deletion():
		_hunt_node = null
	# Something much louder elsewhere steals its attention (that's what decoys are for).
	if loudest != null and loudest != _hunt_node and loudest_eff > HUNT_THRESHOLD + 15.0:
		_start_hunt(loudest)
	if _hunt_node != null and _effective(_hunt_node) > TRACK_THRESHOLD:
		_hunt_pos = _hunt_node.global_position
		_lose_t = 0.0
	else:
		_lose_t += delta
		if _lose_t > LOSE_TRACK_TIME:
			_to_investigate(_hunt_pos)
			return
	_move_toward(_hunt_pos, HUNT_SPEED, delta)
	if _hunt_node is Thrown and _flat_dist(_hunt_node.global_position) < 0.8:
		var fx := Effects.find(self)
		if fx != null:
			fx.fx_sound.rpc("cust_hiss", stain_point(), 0.0, 1.2)
			fx.fx_tile_drop.rpc(stain_point() + Vector3(0.0, 0.02, 0.0))
		_hunt_node.queue_free()
		_to_investigate(_hunt_pos)
		return
	for p in Net.get_players():
		if p.state != Player.State.NORMAL or not _on_floor(p.global_position):
			continue
		if _flat_dist(p.global_position) < GRAB_RADIUS and _ceiling_above(p.global_position):
			_start_grab(p)
			return
	_tick_burn(delta, stain_point(), BURN_TO_RETREAT)


func _to_investigate(pos: Vector3) -> void:
	cstate = CState.INVESTIGATE
	_target = _clamp_to_bounds(pos)
	_linger = 3.0
	hunt_peer = 0
	_hunt_node = null


func _start_grab(p: Player) -> void:
	cstate = CState.GRAB
	_grabbed = p
	grab_peer = p.peer_id
	hunt_peer = p.peer_id
	grab_lift = 0.0
	_hold_t = 0.0
	_burn = 0.0
	_grab_xz = Vector2(p.global_position.x, p.global_position.z)
	_grab_base_y = p.global_position.y
	global_position = Vector3(_grab_xz.x, global_position.y, _grab_xz.y)
	p.grab_start(self)
	var fx := Effects.find(self)
	if fx != null:
		fx.fx_tile_drop.rpc(stain_point() + Vector3(0.25, 0.0, 0.2))
		fx.fx_sound.rpc("cust_hiss", stain_point(), 4.0, 0.8)
	GameState.post_tip("grab_custodian", "IT HAS %s. EVERYONE NEAR THEM: HOLD CTRL AND HOLD ON. Or shine a light on it." % p.display_name.to_upper(), 4.0)


func _tick_grab(delta: float) -> void:
	if _grabbed == null or not is_instance_valid(_grabbed) or not _grabbed.is_grabbed():
		release(false)
		return
	var resist := 0.0
	for b in Net.get_chain_bodies():
		if b != _grabbed and b.global_position.distance_to(_grabbed.global_position) < RESIST_RADIUS:
			resist += b.resist_value()
	var factor := maxf(0.0, 1.0 - resist / HOLD_RESIST)
	grab_lift += LIFT_SPEED * factor * delta
	if factor <= 0.0:
		_hold_t += delta
	_grabbed.global_position = Vector3(_grab_xz.x, _grab_base_y + grab_lift, _grab_xz.y)
	_grabbed.synced_position = _grabbed.global_position
	if grab_lift >= KILL_LIFT:
		var victim := _grabbed.display_name
		release(true)
		var level := get_tree().get_first_node_in_group("level")
		if level != null and level.has_method("request_layoff"):
			level.call("request_layoff", "%s was taken into the ceiling." % victim)
		return
	if _hold_t >= GIVE_UP_TIME:
		release(false)
		return
	_tick_burn(delta, stain_point(), BURN_TO_RELEASE)  # lets go by itself when the light wins


## Server. Lets go of whoever it holds and backs off. killed: the victim was taken.
func release(killed: bool) -> void:
	var victim := _grabbed
	_grabbed = null
	grab_peer = 0
	grab_lift = 0.0
	_hold_t = 0.0
	if victim != null and is_instance_valid(victim) and victim.is_grabbed():
		victim.grab_end()
		if not killed:
			victim.apply_knockback(Vector3(0.0, -2.0, 0.0))
	_start_retreat()


func _start_retreat() -> void:
	cstate = CState.RETREAT
	hunt_peer = 0
	_hunt_node = null
	_retreat_t = RETREAT_TIME
	_burn = 0.0
	var away := Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0)).normalized()
	var me := Net.get_players()
	if not me.is_empty():
		var d := global_position - me[0].global_position
		d.y = 0.0
		if d.length() > 0.1:
			away = d.normalized()
	_target = _clamp_to_bounds(global_position + away * 14.0)
	var fx := Effects.find(self)
	if fx != null:
		fx.fx_sound.rpc("cust_hiss", stain_point(), -4.0, 1.4)


## Pistol hit (server).
func take_hit() -> void:
	if cstate == CState.RETREAT:
		return
	_hits += 1
	var fx := Effects.find(self)
	if fx != null:
		fx.fx_sound.rpc("cust_hiss", stain_point(), 2.0, 1.3)
		fx.fx_dust.rpc(stain_point())
	if _hits >= HITS_TO_RETREAT:
		if cstate == CState.GRAB:
			release(false)
		else:
			_start_retreat()


## A bomb went off nearby (server).
func blast() -> void:
	if cstate == CState.GRAB:
		release(false)
	elif cstate != CState.RETREAT:
		_start_retreat()


## Tests: back to a calm wander at a given spot.
func debug_reset(at: Vector3) -> void:
	if cstate == CState.GRAB:
		release(false)
	cstate = CState.WANDER
	hunt_peer = 0
	_hunt_node = null
	_hits = 0
	_burn = 0.0
	dormant_until_heard = false
	global_position = Vector3(at.x, floor_y + PLENUM_HEIGHT, at.z)
	synced_position = global_position
	_pick_wander_target()


## Scripted scares can send it somewhere (server).
func investigate(pos: Vector3) -> void:
	dormant_until_heard = false
	if cstate == CState.WANDER or cstate == CState.INVESTIGATE:
		_to_investigate(pos)


## Returns true if the burn reached the threshold this tick (and acted on it).
## The beam counts on the stain, on the arm and on the hole: whichever part of it you light.
func _tick_burn(delta: float, target: Vector3, threshold: float) -> bool:
	var targets: Array[Vector3] = [target]
	if cstate == CState.GRAB and _grabbed != null and is_instance_valid(_grabbed):
		var hand := _grabbed.global_position + Vector3(0.0, 2.05, 0.0)
		targets.append(hand)
		targets.append(target.lerp(hand, 0.5))
	var lit := false
	for t in targets:
		if _beam_on(t):
			lit = true
			break
	if lit:
		_burn += delta
		_hiss_t -= delta
		if _hiss_t <= 0.0:
			_hiss_t = 0.35
			var fx := Effects.find(self)
			if fx != null:
				fx.fx_sound.rpc("scrape", stain_point(), -6.0, randf_range(1.6, 2.0))
	else:
		_burn = maxf(0.0, _burn - delta * BURN_DECAY)
	burn_fraction = clampf(_burn / threshold, 0.0, 1.0)
	if _burn < threshold:
		return false
	burn_fraction = 0.0
	if cstate == CState.GRAB:
		release(false)
	else:
		_start_retreat()
	return true


func _beam_on(target: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	for p in Net.get_players():
		if p.held_item == null or p.held_item.data.id != "flashlight" or not p.held_item.is_active:
			continue
		var eye := p.eye_position()
		var to := target - eye
		var d := to.length()
		if d > BEAM_RANGE or d < 0.1:
			continue
		if p.aim_direction().angle_to(to / d) > BEAM_ANGLE:
			continue
		# Only walls block the beam: a teammate (or the victim) standing in it does not.
		var q := PhysicsRayQueryParameters3D.create(eye, target - (to / d) * 0.2, ChainBody.LAYER_WORLD)
		q.exclude = [p.get_rid()]
		if space.intersect_ray(q).is_empty():
			return true
	return false


## Standing still in one place for too long on its floor (crouched or not) draws it over: the
## chain creaks, the floor settles, and it comes to look. Sneaking is for moving, not camping.
func _tick_dwell(delta: float) -> void:
	for p in Net.get_players():
		if not _on_floor(p.global_position) or p.state != Player.State.NORMAL:
			_dwell.erase(p.peer_id)
			continue
		var level := get_tree().get_first_node_in_group("level")
		if level != null and level.has_method("is_safe_spot") and bool(level.call("is_safe_spot", p.global_position)):
			_dwell.erase(p.peer_id)
			continue
		var entry: Array = _dwell.get(p.peer_id, [p.global_position, 0.0])
		if (entry[0] as Vector3).distance_to(p.global_position) > 1.5:
			entry = [p.global_position, 0.0]
		entry[1] = float(entry[1]) + delta
		_dwell[p.peer_id] = entry
		if float(entry[1]) >= DWELL_SECONDS and (cstate == CState.WANDER or cstate == CState.INVESTIGATE):
			_dwell[p.peer_id] = [p.global_position, 0.0]
			_to_investigate(p.global_position)
			var fx := Effects.find(self)
			if fx != null:
				fx.fx_sound.rpc("creak", stain_point(), 2.0, 0.7)
			GameState.post_tip("custodian_still", "...something in the ceiling is coming to look at whoever stopped moving.", 3.0)


func _loudest() -> Array:
	var best: Node3D = null
	var best_eff := 0.0
	for n in get_tree().get_nodes_in_group("noise_source"):
		var n3 := n as Node3D
		if n3 == null or not n3.is_inside_tree():
			continue
		var eff := _effective(n3)
		if eff > best_eff:
			best_eff = eff
			best = n3
	return [best, best_eff]


func _effective(n: Node3D) -> float:
	if not _on_floor(n.global_position) or not n.has_method("noise_level"):
		return 0.0
	var level := get_tree().get_first_node_in_group("level")
	if level != null and level.has_method("is_safe_spot") and level.call("is_safe_spot", n.global_position):
		return 0.0
	var lvl: float = n.call("noise_level")
	if lvl <= 0.0:
		return 0.0
	return lvl * clampf(1.0 - _flat_dist(n.global_position) / HEAR_RADIUS, 0.0, 1.0)


func _anyone_on_floor() -> bool:
	for p in Net.get_players():
		if _on_floor(p.global_position):
			return true
	return false


func _on_floor(p: Vector3) -> bool:
	return p.y > floor_y - 0.6 and p.y < floor_y + 4.2


func _ceiling_above(p: Vector3) -> bool:
	var level := get_tree().get_first_node_in_group("level")
	if level != null and level.has_method("is_safe_spot") and level.call("is_safe_spot", p):
		return false
	if level == null or not level.has_method("has_ceiling_at"):
		return true
	return bool(level.call("has_ceiling_at", p))


func _flat_dist(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()


func _move_toward(target: Vector3, speed: float, delta: float) -> void:
	var cur := Vector2(global_position.x, global_position.z)
	var tgt := Vector2(target.x, target.z)
	cur = cur.move_toward(tgt, speed * delta)
	global_position = Vector3(cur.x, floor_y + PLENUM_HEIGHT, cur.y)


func _pick_wander_target() -> void:
	_target = Vector3(_rng.randf_range(bounds.position.x, bounds.end.x), 0.0, _rng.randf_range(bounds.position.y, bounds.end.y))


func _clamp_to_bounds(p: Vector3) -> Vector3:
	return Vector3(clampf(p.x, bounds.position.x, bounds.end.x), 0.0, clampf(p.z, bounds.position.y, bounds.end.y))


# --- Visuals (every peer) ------------------------------------------------------------------

func _update_visuals(delta: float) -> void:
	var moved := global_position.distance_to(_last_pos) / maxf(delta, 0.0001)
	_last_pos = global_position
	_visual_speed = lerpf(_visual_speed, moved, clampf(delta * 6.0, 0.0, 1.0))
	var sp := stain_point()
	_stain.global_position = sp
	_hitbox.global_position = sp - Vector3(0.0, 0.3, 0.0)
	var hunting := cstate == CState.HUNT or cstate == CState.GRAB
	var target_alpha := 0.55
	var target_size := 2.4
	if hunting:
		target_alpha = 1.0
		target_size = 3.4
	elif cstate == CState.RETREAT:
		target_alpha = 0.3
	_stain.modulate.a = lerpf(_stain.modulate.a, target_alpha, clampf(delta * 3.0, 0.0, 1.0))
	var sz := lerpf(_stain.size.x, target_size + sin(Time.get_ticks_msec() * 0.004) * 0.2, clampf(delta * 3.0, 0.0, 1.0))
	_stain.size = Vector3(sz, 1.2, sz)
	_dust.global_position = sp - Vector3(0.0, 0.05, 0.0)
	_dust.emitting = _visual_speed > 2.5 and _near_local_player(18.0)
	_creak.global_position = sp
	var listener := Net.get_local_player()
	if listener != null and _on_floor(listener.global_position):
		Sfx.start_loop(_creak)
	elif _creak.playing:
		_creak.stop()
	_creak.volume_db = lerpf(_creak.volume_db, -1.0 if hunting else (-7.0 if cstate == CState.INVESTIGATE else -15.0), clampf(delta * 2.0, 0.0, 1.0))
	_creak.pitch_scale = 1.3 if hunting else 1.0
	if hunting and _visual_speed > 2.0:
		_thump_t -= delta
		if _thump_t <= 0.0:
			_thump_t = 0.42
			Sfx.play_at(self, "thump", sp + Vector3.UP * 0.3, -12.0, randf_range(1.3, 1.6), 25.0)
	# Captions for the sounds that only exist as loops (crawling, creaking).
	_caption_t -= delta
	if _caption_t <= 0.0 and cstate != CState.GRAB and _near_local_player(hunting_caption_range(hunting)):
		_caption_t = 4.0 if hunting else 7.0
		if hunting:
			Sfx.caption(self, "something crawls fast through the ceiling", sp + Vector3.UP * 0.5)
		elif cstate == CState.INVESTIGATE or _visual_speed > 1.0:
			Sfx.caption(self, "the ceiling creaks", sp + Vector3.UP * 0.5)
	_update_grab_visuals()


func hunting_caption_range(hunting: bool) -> float:
	return 16.0 if hunting else 9.0


func _near_local_player(radius: float) -> bool:
	var me := Net.get_local_player()
	return me != null and me.global_position.distance_to(global_position) < radius + 4.0


func _update_grab_visuals() -> void:
	var victim: Player = Net.find_player(grab_peer) if grab_peer != 0 else null
	var show := victim != null
	if grab_peer != _shown_grab_peer:
		_shown_grab_peer = grab_peer
		if show:
			Sfx.play_at(self, "cust_shriek", stain_point(), 8.0, 1.0, 40.0)  # out of the ceiling, right over you
		if show and victim.is_local:
			Sfx.play(self, "stinger", 0.0)
	_hole.visible = show
	_eyes.visible = show
	_claws.visible = show
	_hole_glow.visible = show
	for seg in _arm:
		seg.visible = show
	if not show:
		return
	var top := stain_point()
	_hole.global_position = top - Vector3(0.0, 0.01, 0.0)
	_hole_glow.global_position = top - Vector3(0.0, 0.5, 0.0)  # lights the ceiling round the hole
	_hole_glow.light_energy = 0.9 + 0.4 * sin(Time.get_ticks_msec() * 0.012)
	_eyes.global_position = top + Vector3(0.0, 0.18, 0.0)
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		var look := Vector3(cam.global_position.x, _eyes.global_position.y, cam.global_position.z)
		if look.distance_to(_eyes.global_position) > 0.05:
			_eyes.look_at(look, Vector3.UP)
	var hand := victim.global_position + Vector3(0.0, 2.05, 0.0)  # claws close round the hard hat
	var t := Time.get_ticks_msec() * 0.001
	for i in _arm.size():
		var u0 := float(i) / float(_arm.size())
		var u1 := float(i + 1) / float(_arm.size())
		var p0 := top.lerp(hand, u0) + Vector3(sin(t * 3.0 + u0 * 4.0) * 0.12 * sin(PI * u0), 0.0, cos(t * 2.6 + u0 * 3.0) * 0.1 * sin(PI * u0))
		var p1 := top.lerp(hand, u1) + Vector3(sin(t * 3.0 + u1 * 4.0) * 0.12 * sin(PI * u1), 0.0, cos(t * 2.6 + u1 * 3.0) * 0.1 * sin(PI * u1))
		var seg := _arm[i]
		var d := p1 - p0
		var l := d.length()
		if l < 0.01:
			continue
		var up := Vector3.FORWARD if absf(d.normalized().dot(Vector3.UP)) > 0.95 else Vector3.UP
		var basis := Basis.looking_at(d / l, up)
		# A capsule's long axis is Y: rotate so Y follows the segment, then stretch to fit.
		seg.global_transform = Transform3D(basis * Basis.from_euler(Vector3(PI * 0.5, 0.0, 0.0)) * Basis.from_scale(Vector3(1.0, l / 0.7 + 0.15, 1.0)), (p0 + p1) * 0.5)
	_claws.global_position = hand


## A wrench on the arm (server): holding someone, it lets go and goes back up; otherwise it
## counts like a shot toward driving it off. True when it freed someone.
func wrench_hit(_by: Node3D) -> bool:
	if cstate == CState.GRAB:
		release(false)
		return true
	take_hit()
	return false
