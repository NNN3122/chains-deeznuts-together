class_name Effects
extends Node3D
## One per world, at World/Effects on every peer. The server calls these RPCs (call_local) so
## every screen shows the same gunshot, blast, falling tile or dust, and hears the same sound.

const DUST_COLOR: Color = Color(0.75, 0.7, 0.55, 0.6)


static func find(n: Node) -> Effects:
	if n == null or not n.is_inside_tree():
		return null
	return n.get_tree().get_first_node_in_group("effects") as Effects


func _ready() -> void:
	add_to_group("effects")


@rpc("authority", "call_local", "unreliable")
func fx_sound(id: String, pos: Vector3, volume_db: float, pitch: float) -> void:
	Sfx.play_at(self, id, pos, volume_db, pitch, 45.0)


@rpc("authority", "call_local", "reliable")
func fx_shot(from: Vector3, to: Vector3) -> void:
	Sfx.play_at(self, "shot", from, 2.0, randf_range(0.95, 1.05), 80.0)
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.8, 0.45)
	flash.light_energy = 6.0
	flash.omni_range = 7.0
	add_child(flash)
	flash.global_position = from
	var tracer := MeshInstance3D.new()
	var box := BoxMesh.new()
	var length := from.distance_to(to)
	box.size = Vector3(0.025, 0.025, length)
	tracer.mesh = box
	tracer.material_override = _unshaded(Color(3.0, 2.4, 1.2, 1.0))
	add_child(tracer)
	if length > 0.01:
		tracer.global_transform = Transform3D(Basis.looking_at((to - from).normalized(), _up_for(to - from)), (from + to) * 0.5)
	var tw := create_tween()
	tw.tween_property(flash, "light_energy", 0.0, 0.08)
	tw.parallel().tween_property(tracer, "scale", Vector3(0.1, 0.1, 1.0), 0.09)
	tw.tween_callback(flash.queue_free)
	tw.tween_callback(tracer.queue_free)
	_local_shake(from, 0.25, 8.0)


@rpc("authority", "call_local", "reliable")
func fx_explosion(pos: Vector3) -> void:
	Sfx.play_at(self, "boom", pos, 6.0, randf_range(0.9, 1.05), 90.0)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.2)
	light.light_energy = 14.0
	light.omni_range = 16.0
	add_child(light)
	light.global_position = pos + Vector3.UP * 0.5
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	ball.mesh = sm
	var mat := _unshaded(Color(4.0, 1.8, 0.4, 1.0))
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ball.material_override = mat
	add_child(ball)
	ball.global_position = pos + Vector3.UP * 0.4
	ball.scale = Vector3.ONE * 0.2
	var tw := create_tween()
	tw.tween_property(ball, "scale", Vector3.ONE * 3.2, 0.22).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(light, "light_energy", 0.0, 0.7)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tw.tween_callback(ball.queue_free)
	tw.tween_callback(light.queue_free)
	for i in 7:
		var smoke := MeshInstance3D.new()
		var s2 := SphereMesh.new()
		s2.radius = 0.6
		s2.height = 1.2
		smoke.mesh = s2
		var sm_mat := StandardMaterial3D.new()
		sm_mat.albedo_color = Color(0.12, 0.11, 0.1, 0.75)
		sm_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm_mat.roughness = 1.0
		smoke.material_override = sm_mat
		add_child(smoke)
		var off := Vector3(randf_range(-1.0, 1.0), randf_range(0.2, 1.0), randf_range(-1.0, 1.0))
		smoke.global_position = pos + off * 0.6
		var st := create_tween()
		st.tween_property(smoke, "global_position", pos + off * 2.2 + Vector3.UP * 1.5, 2.2)
		st.parallel().tween_property(smoke, "scale", Vector3.ONE * 2.5, 2.2)
		st.parallel().tween_property(sm_mat, "albedo_color:a", 0.0, 2.2)
		st.tween_callback(smoke.queue_free)
	fx_dust_local(pos + Vector3.UP * 3.0, 40)
	_local_shake(pos, 1.0, 18.0)
	for p in Net.get_players():
		var away := p.global_position - pos
		if away.length() < 6.5:
			away.y = 0.0
			p.model.pop_hat((away.normalized() if away.length() > 0.05 else Vector3.ZERO) * 4.0 + Vector3.UP * 6.5)


@rpc("authority", "call_local", "reliable")
func fx_tile_drop(pos: Vector3) -> void:
	Sfx.play_at(self, "tile", pos, 2.0, randf_range(0.9, 1.1), 35.0)
	var tile := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.6, 0.03, 0.6)
	tile.mesh = bm
	tile.material_override = LevelKit.mat("ceiling")
	add_child(tile)
	tile.global_position = pos
	var floor_y := pos.y - 3.15
	var tw := create_tween()
	tw.tween_property(tile, "global_position:y", floor_y + 0.02, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(tile, "rotation", Vector3(randf_range(-0.4, 0.4), randf_range(-1.0, 1.0), randf_range(-0.4, 0.4)), 0.45)
	tw.tween_property(tile, "rotation", Vector3(0.0, tile.rotation.y, 0.0), 0.05)
	tw.tween_interval(10.0)
	tw.tween_callback(tile.queue_free)
	fx_dust_local(pos, 30)
	_local_shake(pos, 0.3, 6.0)


@rpc("authority", "call_local", "unreliable")
func fx_dust(pos: Vector3) -> void:
	fx_dust_local(pos, 18)


func fx_dust_local(pos: Vector3, amount: int) -> void:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = 2.2
	p.one_shot = true
	p.explosiveness = 0.85
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.6, 0.05, 0.6)
	pm.direction = Vector3(0.0, -1.0, 0.0)
	pm.spread = 25.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 1.0
	pm.gravity = Vector3(0.0, -1.6, 0.0)
	pm.damping_min = 0.5
	pm.damping_max = 1.0
	pm.scale_min = 0.5
	pm.scale_max = 1.5
	pm.color = DUST_COLOR
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.05)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.vertex_color_use_as_albedo = true
	qm.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	q.material = qm
	p.draw_pass_1 = q
	add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(p.lifetime + 0.5).timeout.connect(p.queue_free)


## Shakes the local player's camera, scaled by how close they are.
func _local_shake(at: Vector3, strength: float, radius: float) -> void:
	var me := Net.get_local_player()
	if me == null:
		return
	var d := me.global_position.distance_to(at)
	if d < radius:
		me.add_shake(strength * (1.0 - d / radius))


func _unshaded(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	return m


func _up_for(d: Vector3) -> Vector3:
	return Vector3.UP if absf(d.normalized().y) < 0.95 else Vector3.RIGHT
