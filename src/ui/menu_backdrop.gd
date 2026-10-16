class_name MenuBackdrop
extends Node3D
## The live 3D scene behind the title screen: a dim yellow corridor, a dying tube, the Ballast
## smiling on the carpet, Dennis at the far end, and a stain on the ceiling that slowly breathes.

var _cam: Camera3D
var _flicker: OmniLight3D
var _flicker_panel: MeshInstance3D
var _stain: Decal
var _t: float = 0.0


func _ready() -> void:
	var we := WorldEnvironment.new()
	we.environment = LevelKit.make_environment(Settings.quality)
	we.camera_attributes = LevelKit.make_camera_attributes()
	add_child(we)
	var batch := LevelKit.BoxBatch.new()
	batch.add(Vector3(0.0, -0.2, -8.0), Vector3(6.0, 0.4, 20.0), "carpet")
	batch.add(Vector3(0.0, 3.225, -8.0), Vector3(6.0, 0.05, 20.0), "ceiling")
	batch.add(Vector3(-3.0, 1.6, -8.0), Vector3(0.2, 3.2, 20.0), "wall")
	batch.add(Vector3(3.0, 1.6, -8.0), Vector3(0.2, 3.2, 20.0), "wall")
	batch.add(Vector3(-1.9, 1.6, -18.0), Vector3(2.2, 3.2, 0.2), "wall")
	batch.add(Vector3(1.9, 1.6, -18.0), Vector3(2.2, 3.2, 0.2), "wall")
	batch.add(Vector3(0.0, 2.75, -18.0), Vector3(1.6, 0.9, 0.2), "wall")
	batch.add(Vector3(0.0, 1.6, -19.5), Vector3(4.0, 3.2, 0.2), "dark")
	batch.add(Vector3(1.9, 0.5, -6.5), Vector3(0.8, 1.0, 0.8), "cardboard", true, 0.3)
	batch.add(Vector3(1.9, 1.3, -6.6), Vector3(0.6, 0.6, 0.6), "cardboard_dark", true, -0.2)
	batch.add(Vector3(-2.2, 0.36, -10.0), Vector3(0.36, 0.62, 0.03), "sign", false, 0.4)
	batch.build(self, "Backdrop")
	for z: float in [-2.0, -8.0, -14.0]:
		var panel := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(1.2, 0.04, 0.6)
		panel.mesh = pm
		panel.material_override = LevelKit.mat("glow")
		panel.position = Vector3(0.0, 3.18, z)
		add_child(panel)
		var l := OmniLight3D.new()
		l.position = Vector3(0.0, 2.85, z)
		l.omni_range = 8.0
		l.light_energy = 1.2
		l.light_color = Color(1.0, 0.9, 0.62)
		l.shadow_enabled = true
		add_child(l)
		if z == -8.0:
			_flicker = l
			_flicker_panel = panel
	var ballast := Node3D.new()
	add_child(ballast)
	var nut := MeshInstance3D.new()
	var hex := CylinderMesh.new()
	hex.top_radius = 0.42
	hex.bottom_radius = 0.42
	hex.height = 0.38
	hex.radial_segments = 6
	nut.mesh = hex
	nut.material_override = LevelKit.mat("iron")
	nut.position = Vector3(-0.8, 0.19, -4.5)
	nut.rotation = Vector3(0.0, 0.5, 0.0)
	add_child(nut)
	# A length of chain lying on the carpet.
	var link := TorusMesh.new()
	link.inner_radius = 0.026
	link.outer_radius = 0.046
	for i in 40:
		var mi := MeshInstance3D.new()
		mi.mesh = link
		mi.material_override = LevelKit.mat("chain")
		var u := float(i) / 39.0
		var p := Vector3(-0.8 + u * 2.4 + sin(u * 7.0) * 0.3, 0.03, -4.5 + u * 2.6 + cos(u * 5.0) * 0.2)
		mi.position = p
		mi.rotation = Vector3(PI * 0.5 if i % 2 == 1 else 0.0, u * 2.0, 0.0)
		mi.scale = Vector3(1.0, 1.0, 1.65)
		add_child(mi)
	add_child(ScareDirector.build_dennis(Vector3(1.2, 0.0, -16.5), 0.25))
	var grad := Gradient.new()
	grad.set_color(0, Color(0.09, 0.02, 0.05, 0.9))
	grad.set_color(1, Color(0.2, 0.08, 0.06, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	_stain = Decal.new()
	_stain.texture_albedo = tex
	_stain.size = Vector3(2.5, 1.2, 2.5)
	_stain.rotation = Vector3(PI, 0.0, 0.0)
	_stain.position = Vector3(-0.6, 3.18, -11.0)
	add_child(_stain)
	_cam = Camera3D.new()
	_cam.position = Vector3(0.6, 1.55, 1.0)
	_cam.fov = 70.0
	add_child(_cam)
	_cam.current = true
	var hum := AudioStreamPlayer.new()
	hum.stream = Sfx.stream("hum")
	hum.volume_db = -18.0
	add_child(hum)
	Sfx.start_loop(hum)


func _process(delta: float) -> void:
	_t += delta
	_cam.position = Vector3(0.6 + sin(_t * 0.13) * 0.4, 1.55 + sin(_t * 0.31) * 0.05, 1.0 - sin(_t * 0.07) * 1.5)
	_cam.rotation = Vector3(-0.04 + sin(_t * 0.19) * 0.02, -0.12 + sin(_t * 0.11) * 0.08, 0.0)
	var f := sin(_t * 19.0) * sin(_t * 3.1)
	var e := 0.05 if f > 0.75 else 1.0
	_flicker.light_energy = 1.2 * e
	_flicker_panel.set_instance_shader_parameter("glow", e)
	_stain.modulate.a = 0.6 + 0.4 * sin(_t * 0.8)
	_stain.position.z = -11.0 + sin(_t * 0.2) * 1.5
