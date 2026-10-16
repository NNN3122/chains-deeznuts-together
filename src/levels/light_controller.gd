class_name LightController
extends Node
## Drives every fluorescent panel on this peer: flicker, dying tubes, dimming near the Custodian,
## blackout scares, and which few lights near your camera get real shadows. Purely local visuals.

const UPDATE_INTERVAL: float = 0.05
const SHADOW_LIGHTS: int = 4
const SHADOW_REFRESH: float = 0.3
const CUSTODIAN_DIM_RADIUS: float = 7.0
const FLOOR_HEIGHT: float = 5.0

class Tube:
	var light: OmniLight3D
	var panel: MeshInstance3D
	var base_energy: float = 1.0
	var kind: int = 0  # 0 steady, 1 flickering, 2 dying (mostly off), 3 dead
	var floor_index: int = 0
	var phase: float = 0.0
	var hum: AudioStreamPlayer3D

var tubes: Array[Tube] = []
var blackout: bool = false  # the pizzeria's power bank is empty: every tube off
var _t: float = 0.0
var _acc: float = 0.0
var _shadow_t: float = 0.0
var _shadowed: Array[Tube] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func register(light: OmniLight3D, panel: MeshInstance3D, floor_index: int, kind: int, hum: AudioStreamPlayer3D) -> void:
	var t := Tube.new()
	t.light = light
	t.panel = panel
	t.base_energy = light.light_energy
	t.kind = kind
	t.floor_index = floor_index
	t.phase = _rng.randf() * 100.0
	t.hum = hum
	tubes.append(t)


func _process(delta: float) -> void:
	_t += delta
	_acc += delta
	_shadow_t -= delta
	if _acc < UPDATE_INTERVAL:
		return
	_acc = 0.0
	var cam := get_viewport().get_camera_3d()
	var cam_pos := cam.global_position if cam != null else Vector3.ZERO
	var cam_floor := int(floor(cam_pos.y / FLOOR_HEIGHT + 0.1))
	var custodians := get_tree().get_nodes_in_group("custodian")
	for tube in tubes:
		var near_floor := absi(tube.floor_index - cam_floor) <= 1
		tube.light.visible = near_floor and tube.kind != 3
		if tube.hum != null:
			var hum_on := near_floor and tube.kind != 3 and tube.light.global_position.distance_to(cam_pos) < 14.0
			if hum_on:
				Sfx.start_loop(tube.hum)
			elif tube.hum.playing:
				tube.hum.stop()
		if not near_floor:
			continue
		var e := _pattern(tube)
		for c in custodians:
			var cn := c as Node3D
			var d := Vector2(cn.global_position.x - tube.light.global_position.x, cn.global_position.z - tube.light.global_position.z).length()
			if d < CUSTODIAN_DIM_RADIUS and absf(cn.global_position.y - tube.light.global_position.y) < 3.0:
				var k := d / CUSTODIAN_DIM_RADIUS
				var hunting: bool = c.call("is_hunting")
				e *= lerpf(0.15 if hunting else 0.45, 1.0, k)
				if hunting and _rng.randf() < 0.25:
					e *= 0.2
		if ScareDirector.blackout_active() and tube.light.global_position.distance_to(ScareDirector.blackout_center) < ScareDirector.blackout_radius:
			e = 0.0
		if blackout:
			e = 0.0
		tube.light.light_energy = tube.base_energy * e
		tube.panel.set_instance_shader_parameter("glow", e)
		if tube.hum != null:
			tube.hum.volume_db = -30.0 + 12.0 * e
	if _shadow_t <= 0.0:
		_shadow_t = SHADOW_REFRESH
		_pick_shadow_lights(cam_pos)


func _pattern(tube: Tube) -> float:
	match tube.kind:
		1:
			var f := sin(_t * 23.0 + tube.phase) * sin(_t * 7.3 + tube.phase * 2.0)
			return 0.15 if f > 0.82 else 1.0
		2:
			var g := fmod(_t + tube.phase, 6.0)
			if g < 0.08 or (g > 0.2 and g < 0.26) or (g > 3.1 and g < 3.2):
				return 0.9
			return 0.04
		3:
			return 0.0
	return 1.0


func _pick_shadow_lights(cam_pos: Vector3) -> void:
	var candidates: Array[Tube] = []
	for tube in tubes:
		if tube.light.visible and tube.kind != 3 and tube.light.global_position.distance_to(cam_pos) < 12.0:
			candidates.append(tube)
	candidates.sort_custom(func(a: Tube, b: Tube) -> bool:
		return a.light.global_position.distance_squared_to(cam_pos) < b.light.global_position.distance_squared_to(cam_pos))
	var keep: Array[Tube] = []
	for i in mini(SHADOW_LIGHTS if Settings.quality >= 1 else 1, candidates.size()):
		keep.append(candidates[i])
	for tube in _shadowed:
		if not keep.has(tube):
			tube.light.shadow_enabled = false
	for tube in keep:
		tube.light.shadow_enabled = true
	_shadowed = keep
