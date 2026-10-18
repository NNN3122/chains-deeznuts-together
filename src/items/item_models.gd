class_name ItemModels
extends RefCounted
## Little 3D models for every item, built from primitives. Used in hands, on backs and on
## pickups. The front of a hand-held model points along -Z.


static func build(id: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Model_" + id
	match id:
		"flashlight":
			_cyl(root, 0.035, 0.035, 0.22, Vector3(0.0, 0.0, 0.0), _m(Color(0.08, 0.08, 0.09), 0.4), true)
			_cyl(root, 0.05, 0.04, 0.07, Vector3(0.0, 0.0, -0.13), _m(Color(0.1, 0.1, 0.11), 0.3), true)
			_cyl(root, 0.045, 0.045, 0.01, Vector3(0.0, 0.0, -0.17), _glow(Color(1.0, 0.95, 0.7), 2.0), true)
		"pistol":
			_box(root, Vector3(0.05, 0.13, 0.07), Vector3(0.0, -0.07, 0.03), _m(Color(0.2, 0.13, 0.08), 0.6))
			_box(root, Vector3(0.055, 0.07, 0.2), Vector3(0.0, 0.0, -0.05), _m(Color(0.12, 0.12, 0.13), 0.3, 0.8))
			_cyl(root, 0.015, 0.015, 0.12, Vector3(0.0, 0.015, -0.17), _m(Color(0.1, 0.1, 0.1), 0.3, 0.9), true)
		"drink":
			_cyl(root, 0.04, 0.04, 0.14, Vector3.ZERO, _glow(Color(0.4, 1.0, 0.2), 0.6), false)
			_cyl(root, 0.041, 0.041, 0.035, Vector3(0.0, 0.0, 0.0), _m(Color(0.1, 0.05, 0.25), 0.4), false)
			_cyl(root, 0.035, 0.04, 0.012, Vector3(0.0, 0.075, 0.0), _m(Color(0.8, 0.8, 0.82), 0.2, 0.9), false)
		"decoy":
			var yellow := _m(Color(1.0, 0.85, 0.1), 0.25)
			_sphere(root, 0.08, Vector3(0.0, 0.0, 0.0), yellow)
			_sphere(root, 0.055, Vector3(0.0, 0.09, -0.05), yellow)
			_box(root, Vector3(0.05, 0.02, 0.05), Vector3(0.0, 0.085, -0.11), _m(Color(1.0, 0.45, 0.05), 0.4))
			_sphere(root, 0.012, Vector3(0.025, 0.11, -0.09), _m(Color(0.0, 0.0, 0.0), 0.2))
			_sphere(root, 0.012, Vector3(-0.025, 0.11, -0.09), _m(Color(0.0, 0.0, 0.0), 0.2))
		"bomb":
			_sphere(root, 0.1, Vector3.ZERO, _m(Color(0.07, 0.07, 0.08), 0.35, 0.3))
			_cyl(root, 0.03, 0.03, 0.04, Vector3(0.0, 0.11, 0.0), _m(Color(0.5, 0.5, 0.5), 0.3, 0.8), false)
			_cyl(root, 0.006, 0.006, 0.07, Vector3(0.0, 0.16, 0.0), _m(Color(0.6, 0.5, 0.3), 0.8), false)
			_sphere(root, 0.015, Vector3(0.0, 0.2, 0.0), _glow(Color(1.0, 0.3, 0.05), 3.0))
		"popper":
			_cyl(root, 0.012, 0.05, 0.18, Vector3(0.0, 0.0, -0.02), _m(Color(1.0, 0.4, 0.7), 0.4), true)
			_cyl(root, 0.05, 0.05, 0.01, Vector3(0.0, 0.0, -0.115), _m(Color(0.95, 0.9, 0.3), 0.5), true)
			_cyl(root, 0.004, 0.004, 0.06, Vector3(0.0, 0.0, 0.1), _m(Color(0.9, 0.9, 0.9), 0.8), true)
		"airhorn":
			_cyl(root, 0.035, 0.035, 0.14, Vector3(0.0, -0.02, 0.04), _m(Color(0.85, 0.12, 0.1), 0.35), false)
			_cyl(root, 0.03, 0.06, 0.11, Vector3(0.0, 0.0, -0.08), _m(Color(0.1, 0.1, 0.1), 0.5), true)
			_cyl(root, 0.012, 0.012, 0.05, Vector3(0.0, 0.0, -0.015), _m(Color(0.8, 0.8, 0.82), 0.3, 0.8), true)
		"ammo":
			_box(root, Vector3(0.14, 0.09, 0.1), Vector3.ZERO, _m(Color(0.45, 0.32, 0.12), 0.7))
			_box(root, Vector3(0.142, 0.03, 0.102), Vector3(0.0, 0.03, 0.0), _m(Color(0.85, 0.7, 0.3), 0.4, 0.6))
			for k in 3:
				_cyl(root, 0.012, 0.012, 0.05, Vector3(-0.04 + 0.04 * float(k), 0.06, 0.0), _m(Color(0.8, 0.65, 0.2), 0.3, 0.9), false)
		"jetpack":
			var steel := _m(Color(0.7, 0.7, 0.72), 0.25, 0.9)
			_cyl(root, 0.09, 0.09, 0.5, Vector3(-0.11, 0.0, 0.0), steel, false)
			_cyl(root, 0.09, 0.09, 0.5, Vector3(0.11, 0.0, 0.0), steel, false)
			_box(root, Vector3(0.36, 0.42, 0.06), Vector3(0.0, 0.0, -0.08), _m(Color(0.6, 0.12, 0.08), 0.5))
			_cyl(root, 0.05, 0.07, 0.1, Vector3(-0.11, -0.3, 0.0), _m(Color(0.15, 0.15, 0.15), 0.4, 0.8), false)
			_cyl(root, 0.05, 0.07, 0.1, Vector3(0.11, -0.3, 0.0), _m(Color(0.15, 0.15, 0.15), 0.4, 0.8), false)
		"wrench":
			# A long steel pipe wrench: a worn grip, the shaft, an open jaw at the striking end (-Z).
			var steel := _m(Color(0.55, 0.56, 0.6), 0.35, 0.9)
			var dark := _m(Color(0.18, 0.18, 0.2), 0.5, 0.7)
			_cyl(root, 0.022, 0.022, 0.16, Vector3(0.0, 0.0, 0.1), _m(Color(0.35, 0.08, 0.06), 0.8), true)
			_box(root, Vector3(0.03, 0.035, 0.34), Vector3(0.0, 0.0, -0.1), steel)
			_box(root, Vector3(0.05, 0.1, 0.06), Vector3(0.0, 0.03, -0.29), dark)
			_box(root, Vector3(0.045, 0.025, 0.09), Vector3(0.0, 0.07, -0.34), steel)
			_box(root, Vector3(0.045, 0.025, 0.07), Vector3(0.0, -0.005, -0.33), steel)
			_cyl(root, 0.02, 0.02, 0.05, Vector3(0.0, 0.03, -0.25), dark, false)
		_:
			_box(root, Vector3(0.2, 0.2, 0.2), Vector3.ZERO, _m(Color(0.8, 0.2, 0.8), 0.5))
	return root


static func _m(c: Color, rough: float, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


static func _glow(c: Color, energy: float) -> StandardMaterial3D:
	var m := _m(c, 0.3)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


static func _box(root: Node3D, size: Vector3, at: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = at
	mi.material_override = m
	root.add_child(mi)


static func _sphere(root: Node3D, r: float, at: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	mi.mesh = s
	mi.position = at
	mi.material_override = m
	root.add_child(mi)


## Cylinder along Y, or along Z when along_z is true.
static func _cyl(root: Node3D, top: float, bottom: float, h: float, at: Vector3, m: Material, along_z: bool) -> void:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	mi.mesh = c
	mi.position = at
	if along_z:
		mi.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	mi.material_override = m
	root.add_child(mi)
