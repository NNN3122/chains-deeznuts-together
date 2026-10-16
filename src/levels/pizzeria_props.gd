class_name PizzeriaProps
extends RefCounted
## Furniture and set dressing for Pappy Pepperoni's: booths, tables, the counter, arcade
## cabinets, the jukebox, ovens, the band, balloons. Static builders that add to a BoxBatch (one
## draw call per material) or hang lights and labels under a root node. All original designs.

const BALLOONS: Array[String] = ["balloon_red", "balloon_yellow", "balloon_blue"]


## A booth: two facing vinyl benches with a laminate table between, against a wall.
## fwd points from the wall into the room.
static func booth(b: LevelKit.BoxBatch, at: Vector3, fwd: Vector3) -> void:
	var yaw := atan2(-fwd.x, -fwd.z)
	var side := Vector3(fwd.z, 0.0, -fwd.x)
	for s: float in [-1.0, 1.0]:
		var bench := at + side * s * 0.95
		b.add(bench + Vector3(0.0, 0.25, 0.0) + fwd * 0.6, Vector3(0.55, 0.5, 1.5), "booth", true, yaw)
		b.add(bench + Vector3(0.0, 0.75, 0.0) + fwd * 0.6 + side * s * 0.2, Vector3(0.14, 0.6, 1.5), "booth_dark", true, yaw)
	b.add(at + Vector3(0.0, 0.74, 0.0) + fwd * 0.65, Vector3(0.8, 0.05, 1.3), "laminate", true, yaw)
	b.add(at + Vector3(0.0, 0.36, 0.0) + fwd * 0.65, Vector3(0.1, 0.72, 0.1), "steel", true)
	b.add(at + Vector3(0.0, 0.8, 0.0) + fwd * 0.65 + side * 0.25, Vector3(0.14, 0.08, 0.14), "vending", false)  # ketchup
	b.add(at + Vector3(0.0, 0.79, 0.0) + fwd * 0.65 - side * 0.2, Vector3(0.22, 0.04, 0.22), "steel", false)  # tray


## A round pedestal table with chairs around it, maybe a balloon.
static func table(root: Node3D, b: LevelKit.BoxBatch, at: Vector3, rng: RandomNumberGenerator, chairs: int = 4) -> void:
	b.add(at + Vector3(0.0, 0.74, 0.0), Vector3(1.1, 0.05, 1.1), "laminate", true, rng.randf() * 0.5)
	b.add(at + Vector3(0.0, 0.36, 0.0), Vector3(0.08, 0.72, 0.08), "steel", true)
	b.add(at + Vector3(0.0, 0.02, 0.0), Vector3(0.6, 0.04, 0.6), "steel_dark", false)
	for k in chairs:
		if rng.randf() < 0.2:
			continue
		var a := TAU * float(k) / float(chairs) + rng.randf_range(-0.3, 0.3)
		var d := Vector3(cos(a), 0.0, sin(a))
		chair(b, at + d * 0.95, atan2(-d.x, -d.z) + PI)
	if rng.randf() < 0.35:
		b.add(at + Vector3(0.0, 0.76, 0.0), Vector3(0.45, 0.04, 0.45), "pizza_crust", false)
		b.add(at + Vector3(0.0, 0.79, 0.0), Vector3(0.36, 0.02, 0.36), "pizza_sauce", false)
	if rng.randf() < 0.5:
		balloon(root, b, at + Vector3(0.35, 0.78, 0.2), rng, 1.3)


static func chair(b: LevelKit.BoxBatch, at: Vector3, yaw: float) -> void:
	var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
	b.add(at + Vector3(0.0, 0.45, 0.0), Vector3(0.44, 0.05, 0.44), "booth", true, yaw)
	b.add(at - fwd * 0.2 + Vector3(0.0, 0.75, 0.0), Vector3(0.44, 0.55, 0.05), "steel_dark", false, yaw)
	for sx: float in [-0.18, 0.18]:
		for sz: float in [-0.18, 0.18]:
			b.add(at + Vector3(sx, 0.22, sz), Vector3(0.03, 0.44, 0.03), "steel", false)


## A balloon on a string, tied at the given point.
static func balloon(_root: Node3D, b: LevelKit.BoxBatch, tie: Vector3, rng: RandomNumberGenerator, height: float) -> void:
	var lean := Vector3(rng.randf_range(-0.2, 0.2), 0.0, rng.randf_range(-0.2, 0.2))
	var top := tie + Vector3(0.0, height, 0.0) + lean
	b.add((tie + top) * 0.5, Vector3(0.006, height, 0.006), "white", false)
	b.add(top + Vector3(0.0, 0.18, 0.0), Vector3(0.28, 0.36, 0.28), BALLOONS[rng.randi() % BALLOONS.size()], false)
	b.add(top + Vector3(0.0, -0.02, 0.0), Vector3(0.05, 0.05, 0.05), "dark", false)


## A balloon arch over a doorway.
static func balloon_arch(b: LevelKit.BoxBatch, at: Vector3, along: Vector3, width: float, rng: RandomNumberGenerator) -> void:
	for k in 9:
		var u := float(k) / 8.0
		var x := (u - 0.5) * width
		var y := 0.2 + 1.1 * sin(PI * u)
		b.add(at + along * x + Vector3(0.0, y, 0.0), Vector3(0.3, 0.36, 0.3), BALLOONS[(k + rng.randi() % 2) % 3], false)


## A long serving counter with a sneeze guard, register, pizza boxes. along: the counter's axis.
static func counter(root: Node3D, b: LevelKit.BoxBatch, at: Vector3, along: Vector3, length: float) -> void:
	var yaw := atan2(along.z, along.x)
	var n := Vector3(-along.z, 0.0, along.x)
	b.add(at + Vector3(0.0, 0.55, 0.0), Vector3(length, 1.1, 0.7), "booth_dark", true, -yaw)
	b.add(at + Vector3(0.0, 1.12, 0.0), Vector3(length + 0.1, 0.05, 0.8), "laminate", true, -yaw)
	b.add(at + Vector3(0.0, 1.45, 0.0) + n * 0.25, Vector3(length * 0.6, 0.6, 0.02), "vending_glass", false, -yaw)
	b.add(at + Vector3(0.0, 1.3, 0.0) - along * (length * 0.35), Vector3(0.4, 0.35, 0.4), "plastic", false, -yaw)
	b.add(at + Vector3(0.0, 1.5, 0.0) - along * (length * 0.35) - n * 0.1, Vector3(0.3, 0.12, 0.02), "crt", false, -yaw)
	for k in 4:
		b.add(at + Vector3(0.0, 1.17 + 0.05 * float(k), 0.0) + along * (length * 0.3), Vector3(0.45, 0.05, 0.45), "cardboard", false, -yaw + 0.1 * float(k))
	var sign := Label3D.new()
	sign.text = "PAPPY'S PIES\nSLICE . . . . . . $2\nWHOLE PIE . . . $9\nNIGHT SHIFT SPECIAL: FREE"
	sign.font_size = 30
	sign.pixel_size = 0.0045
	sign.modulate = Color(1.0, 0.9, 0.7)
	sign.outline_size = 6
	sign.position = at + Vector3(0.0, 2.6, 0.0) - n * 2.5
	sign.rotation = Vector3(0.0, -yaw + PI * 0.5, 0.0)
	root.add_child(sign)
	b.add(at + Vector3(0.0, 2.6, 0.0) - n * 2.55, Vector3(2.4, 1.0, 0.05), "dark", false, -yaw)


## An arcade cabinet facing fwd, with a glowing screen and a light.
static func arcade_cabinet(root: Node3D, b: LevelKit.BoxBatch, at: Vector3, fwd: Vector3, title: String, glow: Color) -> void:
	var yaw := atan2(-fwd.x, -fwd.z)
	b.add(at + Vector3(0.0, 0.9, 0.0), Vector3(0.75, 1.8, 0.8), "arcade", true, yaw)
	b.add(at + Vector3(0.0, 1.3, 0.0) + fwd * 0.41, Vector3(0.55, 0.42, 0.02), "arcade_screen", false, yaw)
	b.add(at + Vector3(0.0, 0.95, 0.0) + fwd * 0.44, Vector3(0.65, 0.08, 0.18), "plastic", false, yaw)
	b.add(at + Vector3(-0.12, 1.0, 0.0) + fwd * 0.46, Vector3(0.04, 0.09, 0.04), "vending", false, yaw)
	b.add(at + Vector3(0.0, 1.95, 0.0) + fwd * 0.2, Vector3(0.8, 0.3, 0.4), "arcade", false, yaw)
	var l := Label3D.new()
	l.text = title
	l.font_size = 26
	l.pixel_size = 0.004
	l.modulate = glow
	l.outline_size = 4
	l.position = at + Vector3(0.0, 1.95, 0.0) + fwd * 0.41
	l.rotation = Vector3(0.0, yaw, 0.0)
	root.add_child(l)
	var light := OmniLight3D.new()
	light.light_color = glow
	light.light_energy = 0.5
	light.omni_range = 2.6
	light.position = at + Vector3(0.0, 1.3, 0.0) + fwd * 0.8
	root.add_child(light)


## The jukebox: the loop's speaker. Returns the AudioStreamPlayer3D to start and stop.
static func jukebox(root: Node3D, b: LevelKit.BoxBatch, at: Vector3, fwd: Vector3) -> AudioStreamPlayer3D:
	var yaw := atan2(-fwd.x, -fwd.z)
	b.add(at + Vector3(0.0, 0.8, 0.0), Vector3(1.0, 1.6, 0.7), "jukebox", true, yaw)
	b.add(at + Vector3(0.0, 1.5, 0.0), Vector3(1.0, 0.4, 0.6), "jukebox", true, yaw)
	b.add(at + Vector3(0.0, 1.2, 0.0) + fwd * 0.36, Vector3(0.8, 0.5, 0.02), "jukebox_glow", false, yaw)
	for s: float in [-0.42, 0.42]:
		b.add(at + Vector3(s, 0.85, 0.0) + fwd * 0.34, Vector3(0.08, 1.4, 0.04), "neon_pink", false, yaw)
	b.add(at + Vector3(0.0, 0.5, 0.0) + fwd * 0.36, Vector3(0.7, 0.45, 0.02), "speaker", false, yaw)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.5, 0.2)
	light.light_energy = 0.8
	light.omni_range = 4.0
	light.position = at + Vector3(0.0, 1.3, 0.0) + fwd * 0.9
	root.add_child(light)
	var p := Sfx.loop_player("jukebox", -6.0, 42.0)
	p.position = at + Vector3(0.0, 1.0, 0.0) + fwd * 0.4
	root.add_child(p)
	return p


## A wall speaker that carries the jukebox into other rooms (quieter).
static func speaker(root: Node3D, b: LevelKit.BoxBatch, at: Vector3) -> AudioStreamPlayer3D:
	b.add(at, Vector3(0.3, 0.4, 0.25), "speaker", false)
	var p := Sfx.loop_player("jukebox", -16.0, 26.0)
	p.position = at
	root.add_child(p)
	return p


## A hanging pendant light; registered with the controller by the caller.
static func pendant(root: Node3D, b: LevelKit.BoxBatch, at: Vector3, ceiling_y: float, color: Color, energy: float) -> Array:
	var drop := ceiling_y - at.y
	b.add(Vector3(at.x, at.y + drop * 0.5, at.z), Vector3(0.015, drop, 0.015), "dark", false)
	b.add(at + Vector3(0.0, 0.1, 0.0), Vector3(0.55, 0.2, 0.55), "vending", false)
	var panel := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.45, 0.03, 0.45)
	panel.mesh = pm
	panel.material_override = LevelKit.mat("glow")
	panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	panel.position = at - Vector3(0.0, 0.01, 0.0)
	root.add_child(panel)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = 7.5
	light.omni_attenuation = 1.4
	light.light_size = 0.3
	light.shadow_blur = 1.5
	light.position = at - Vector3(0.0, 0.25, 0.0)
	root.add_child(light)
	return [light, panel]


## A pizza oven: a big steel box with a glowing mouth.
static func oven(root: Node3D, b: LevelKit.BoxBatch, at: Vector3, fwd: Vector3, lit: bool) -> void:
	var yaw := atan2(-fwd.x, -fwd.z)
	b.add(at + Vector3(0.0, 0.9, 0.0), Vector3(1.6, 1.8, 1.0), "steel", true, yaw)
	b.add(at + Vector3(0.0, 1.05, 0.0) + fwd * 0.51, Vector3(1.1, 0.35, 0.02), "jukebox_glow" if lit else "dark", false, yaw)
	b.add(at + Vector3(0.0, 0.5, 0.0) + fwd * 0.52, Vector3(1.2, 0.6, 0.04), "steel_dark", false, yaw)
	b.add(at + Vector3(0.0, 1.95, 0.0), Vector3(1.4, 0.3, 0.8), "steel_dark", false, yaw)
	if lit:
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.45, 0.1)
		light.light_energy = 1.1
		light.omni_range = 4.5
		light.position = at + Vector3(0.0, 1.0, 0.0) + fwd * 0.9
		root.add_child(light)


## Stainless prep table with stuff on it.
static func prep_table(b: LevelKit.BoxBatch, at: Vector3, size: Vector3, rng: RandomNumberGenerator) -> void:
	b.add(at + Vector3(0.0, 0.88, 0.0), Vector3(size.x, 0.05, size.z), "steel", true)
	b.add(at + Vector3(0.0, 0.3, 0.0), Vector3(size.x - 0.2, 0.04, size.z - 0.2), "steel", true)
	for cx: float in [-1.0, 1.0]:
		for cz: float in [-1.0, 1.0]:
			b.add(at + Vector3(cx * (size.x * 0.5 - 0.05), 0.44, cz * (size.z * 0.5 - 0.05)), Vector3(0.04, 0.88, 0.04), "steel", false)
	for k in rng.randi_range(1, 3):
		var p := at + Vector3(rng.randf_range(-size.x * 0.4, size.x * 0.4), 0.95, rng.randf_range(-size.z * 0.35, size.z * 0.35))
		match rng.randi() % 3:
			0:
				b.add(p, Vector3(0.4, 0.08, 0.4), "dough", false)
			1:
				b.add(p, Vector3(0.3, 0.2, 0.3), "steel", false)
			_:
				b.add(p, Vector3(0.45, 0.03, 0.45), "pizza_crust", false)
				b.add(p + Vector3(0.0, 0.02, 0.0), Vector3(0.36, 0.02, 0.36), "pizza_sauce", false)


## Steel shelving with boxes and cans.
static func shelf(b: LevelKit.BoxBatch, at: Vector3, along_x: bool, rng: RandomNumberGenerator, length: float = 1.8, key: String = "steel") -> void:
	var size := Vector3(length, 2.0, 0.5) if along_x else Vector3(0.5, 2.0, length)
	for h: float in [0.1, 0.7, 1.3, 1.9]:
		b.add(Vector3(at.x, at.y + h, at.z), Vector3(size.x, 0.04, size.z), key)
	for cx: float in [-1.0, 1.0]:
		for cz: float in [-1.0, 1.0]:
			b.add(at + Vector3(cx * (size.x * 0.5 - 0.03), 1.0, cz * (size.z * 0.5 - 0.03)), Vector3(0.04, 2.0, 0.04), key)
	for h: float in [0.12, 0.72, 1.32]:
		var n := rng.randi_range(1, 3)
		for k in n:
			var u := (float(k) + 0.5) / float(n) - 0.5
			var off := Vector3(u * (size.x - 0.5), 0.0, 0.0) if along_x else Vector3(0.0, 0.0, u * (size.z - 0.5))
			var r := rng.randf()
			if r < 0.4:
				var bs := rng.randf_range(0.3, 0.45)
				b.add(at + off + Vector3(0.0, h + bs * 0.5, 0.0), Vector3(bs * 1.2, bs, bs), "cardboard", false, rng.randf_range(-0.2, 0.2))
			elif r < 0.7:
				b.add(at + off + Vector3(0.0, h + 0.15, 0.0), Vector3(0.22, 0.3, 0.22), "steel", false)
			else:
				b.add(at + off + Vector3(0.0, h + 0.2, 0.0), Vector3(0.36, 0.4, 0.3), "flour", false, rng.randf_range(-0.3, 0.3))


## Stacked crates and flour sacks (Receiving).
static func crates(b: LevelKit.BoxBatch, at: Vector3, rng: RandomNumberGenerator) -> void:
	var y := 0.0
	for k in rng.randi_range(1, 3):
		var s := rng.randf_range(0.5, 0.8)
		b.add(at + Vector3(rng.randf_range(-0.15, 0.15), y + s * 0.5, rng.randf_range(-0.15, 0.15)), Vector3(s, s, s), "crate", true, rng.randf_range(-0.3, 0.3))
		y += s
	for k in rng.randi_range(0, 2):
		b.add(at + Vector3(rng.randf_range(0.6, 1.0), 0.18 + 0.3 * float(k), rng.randf_range(-0.4, 0.4)), Vector3(0.7, 0.32, 0.45), "flour", true, rng.randf_range(-0.4, 0.4))


## A roll-up dock door, closed, with painted lettering (Receiving).
static func dock_door(root: Node3D, b: LevelKit.BoxBatch, at: Vector3, normal: Vector3, text: String) -> void:
	var yaw := atan2(normal.x, normal.z)
	b.add(at + Vector3(0.0, 1.6, 0.0) - normal * 0.08, Vector3(3.2, 3.2, 0.08), "shutter", false, yaw)
	b.add(at + Vector3(0.0, 3.35, 0.0) - normal * 0.1, Vector3(3.6, 0.4, 0.4), "steel_dark", false, yaw)
	var l := Label3D.new()
	l.text = text
	l.font_size = 40
	l.pixel_size = 0.006
	l.modulate = Color(0.9, 0.85, 0.7)
	l.outline_size = 0
	l.double_sided = false
	l.position = at + Vector3(0.0, 2.0, 0.0) - normal * 0.03
	l.rotation = Vector3(0.0, yaw, 0.0)
	root.add_child(l)


## A neon sign: text in a glowing color with a dim panel behind.
static func neon(root: Node3D, b: LevelKit.BoxBatch, text: String, at: Vector3, yaw: float, color: Color, size: int = 56) -> void:
	var normal := Vector3(-sin(yaw), 0.0, -cos(yaw))  # the label faces -z of its own frame
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.006
	l.modulate = color
	l.outline_size = 2
	l.outline_modulate = color.darkened(0.6)
	l.double_sided = false
	l.position = at
	l.rotation = Vector3(0.0, yaw, 0.0)
	root.add_child(l)
	b.add(at - normal * 0.04, Vector3(float(size) * 0.055 * 2.2, float(size) * 0.012 * 2.0, 0.03), "dark", false, yaw)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.4
	light.omni_range = 6.0
	light.position = at + normal * 0.6
	root.add_child(light)


## A red EXIT sign over a doorway, with its glow.
static func exit_sign(root: Node3D, b: LevelKit.BoxBatch, at: Vector3, normal: Vector3) -> void:
	b.add(at, Vector3(0.44, 0.17, 0.3) if absf(normal.z) > 0.5 else Vector3(0.3, 0.17, 0.44), "exit_sign", false)
	for side: float in [-1.0, 1.0]:
		var l := Label3D.new()
		l.text = "EXIT"
		l.font_size = 30
		l.pixel_size = 0.0042
		l.modulate = Color(1.0, 0.95, 0.9)
		l.outline_size = 0
		l.double_sided = false
		l.position = at + normal * side * 0.16
		l.rotation = Vector3(0.0, atan2(normal.x * side, normal.z * side), 0.0)
		root.add_child(l)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.15, 0.08)
	glow.light_energy = 0.8
	glow.omni_range = 3.0
	glow.position = at - Vector3(0.0, 0.25, 0.0)
	root.add_child(glow)


## A security camera on the wall near the ceiling, pointed at a spot. A little red LED blinks.
static func camera_prop(root: Node3D, b: LevelKit.BoxBatch, at: Vector3, look_at: Vector3) -> void:
	var d := look_at - at
	var yaw := atan2(-d.x, -d.z)
	b.add(at + Vector3(0.0, 0.1, 0.0), Vector3(0.1, 0.2, 0.1), "camera", false)
	b.add(at + Vector3(-sin(yaw), 0.0, -cos(yaw)) * 0.15, Vector3(0.14, 0.14, 0.32), "camera", false, yaw)
	b.add(at + Vector3(-sin(yaw), 0.0, -cos(yaw)) * 0.32, Vector3(0.1, 0.1, 0.03), "dark", false, yaw)
	var led := MeshInstance3D.new()
	var lm := SphereMesh.new()
	lm.radius = 0.015
	lm.height = 0.03
	led.mesh = lm
	led.material_override = LevelKit.mat("led_red")
	led.position = at + Vector3(0.05, 0.08, 0.0)
	root.add_child(led)


## The Crust Family Band: three animatronics on the stage back wall, original designs.
## Mama Crust (dough matron, rolling pin), Big Dough (strongman), Tiny Tomato (tomato on legs).
static func band(root: Node3D, b: LevelKit.BoxBatch, at: Vector3, fwd: Vector3) -> Array[OmniLight3D]:
	var yaw := atan2(-fwd.x, -fwd.z)
	var side := Vector3(fwd.z, 0.0, -fwd.x)
	var lights: Array[OmniLight3D] = []
	# Risers.
	b.add(at + Vector3(0.0, 0.2, 0.0), Vector3(7.0, 0.4, 2.2), "stage_wood", true, yaw)
	# Mama Crust, center: a tall dough cone in an apron with a rolling pin.
	var mc := at + Vector3(0.0, 0.4, 0.0)
	b.add(mc + Vector3(0.0, 1.0, 0.0), Vector3(1.3, 2.0, 1.1), "dough", true, yaw)
	b.add(mc + Vector3(0.0, 1.0, 0.0) + fwd * 0.56, Vector3(0.9, 1.3, 0.02), "party_cloth", false, yaw)
	b.add(mc + Vector3(0.0, 2.35, 0.0), Vector3(0.95, 0.75, 0.9), "dough", false, yaw)
	b.add(mc + Vector3(0.0, 2.75, 0.0), Vector3(0.6, 0.25, 0.6), "booth", false, yaw)  # bonnet
	for s: float in [-0.2, 0.2]:
		b.add(mc + Vector3(0.0, 2.45, 0.0) + fwd * 0.46 + side * s, Vector3(0.1, 0.1, 0.02), "dark", false, yaw)
	b.add(mc + Vector3(0.0, 2.2, 0.0) + fwd * 0.46, Vector3(0.35, 0.06, 0.02), "booth_dark", false, yaw)
	b.add(mc + Vector3(0.0, 1.6, 0.0) + side * 0.85 + fwd * 0.3, Vector3(0.12, 0.9, 0.12), "desk", false, yaw + 0.5)  # rolling pin
	# Big Dough, left: a slab with tiny head and huge arms, at a keyboard.
	var bd := at - side * 2.4 + Vector3(0.0, 0.4, 0.0)
	b.add(bd + Vector3(0.0, 0.9, 0.0), Vector3(1.6, 1.8, 0.9), "dough", true, yaw)
	b.add(bd + Vector3(0.0, 2.0, 0.0), Vector3(0.5, 0.4, 0.5), "dough", false, yaw)
	for s: float in [-0.95, 0.95]:
		b.add(bd + Vector3(0.0, 1.1, 0.0) + side * s, Vector3(0.4, 1.4, 0.4), "dough", false, yaw)
	b.add(bd + Vector3(0.0, 0.95, 0.0) + fwd * 0.75, Vector3(1.4, 0.1, 0.4), "dark", true, yaw)  # keyboard
	for k in 7:
		b.add(bd + Vector3(0.0, 1.01, 0.0) + fwd * 0.75 + side * (-0.6 + 0.2 * float(k)), Vector3(0.17, 0.02, 0.36), "white", false, yaw)
	# Tiny Tomato, right: a tomato head on four servo legs with a tambourine.
	var tt := at + side * 2.4 + Vector3(0.0, 0.4, 0.0)
	for k in 4:
		var a := TAU * float(k) / 4.0 + 0.4
		b.add(tt + Vector3(cos(a) * 0.3, 0.3, sin(a) * 0.3), Vector3(0.06, 0.6, 0.06), "steel_dark", false, a)
	b.add(tt + Vector3(0.0, 0.95, 0.0), Vector3(0.75, 0.7, 0.75), "vending", true, yaw)
	b.add(tt + Vector3(0.0, 1.35, 0.0), Vector3(0.3, 0.1, 0.3), "neon_green", false, yaw)
	for s: float in [-0.15, 0.15]:
		b.add(tt + Vector3(0.0, 1.05, 0.0) + fwd * 0.38 + side * s, Vector3(0.09, 0.09, 0.02), "white", false, yaw)
		b.add(tt + Vector3(0.0, 1.05, 0.0) + fwd * 0.39 + side * s, Vector3(0.04, 0.04, 0.02), "dark", false, yaw)
	b.add(tt + Vector3(0.0, 0.85, 0.0) + fwd * 0.4, Vector3(0.3, 0.05, 0.02), "dark", false, yaw)
	b.add(tt + Vector3(0.0, 1.0, 0.0) + side * 0.6, Vector3(0.3, 0.05, 0.3), "brass", false, yaw)
	# Stage lights over the band, off until the curtain scare.
	for s: float in [-2.4, 0.0, 2.4]:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.75, 0.4)
		l.light_energy = 0.0
		l.omni_range = 7.0
		l.position = at + side * s + Vector3(0.0, 3.6, 0.0) + fwd * 1.2
		root.add_child(l)
		lights.append(l)
		b.add(l.position + Vector3(0.0, 0.1, 0.0), Vector3(0.3, 0.3, 0.3), "steel_dark", false)
	return lights


## Pappy's spare suit on a costume rack: limp, headless until it isn't. Returns the head node.
static func spare_suit(root: Node3D, b: LevelKit.BoxBatch, at: Vector3, fwd: Vector3) -> Node3D:
	var yaw := atan2(-fwd.x, -fwd.z)
	var side := Vector3(fwd.z, 0.0, -fwd.x)
	b.add(at + Vector3(0.0, 1.95, 0.0), Vector3(2.0, 0.05, 0.05), "steel", false, yaw + PI * 0.5)
	for s: float in [-0.95, 0.95]:
		b.add(at + side * s + Vector3(0.0, 1.0, 0.0), Vector3(0.05, 2.0, 0.05), "steel", true)
	for k in 3:
		var p := at + side * (-0.6 + 0.6 * float(k))
		b.add(p + Vector3(0.0, 1.35, 0.0), Vector3(0.5, 1.2, 0.3), ["chef_white", "party_cloth", "chef_white"][k], true, yaw)
	var head := Node3D.new()
	head.position = at + side * 0.6 + Vector3(0.0, 2.3, 0.0)
	root.add_child(head)
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.3
	sm.height = 0.66
	m.mesh = sm
	m.material_override = LevelKit.mat("chef_skin")
	head.add_child(m)
	var hat := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.3
	hm.bottom_radius = 0.22
	hm.height = 0.45
	hat.mesh = hm
	hat.position = Vector3(0.0, 0.45, 0.0)
	hat.material_override = LevelKit.mat("chef_white")
	head.add_child(hat)
	for s: float in [-0.12, 0.12]:
		var e := MeshInstance3D.new()
		var em := CylinderMesh.new()
		em.top_radius = 0.06
		em.bottom_radius = 0.06
		em.height = 0.02
		e.mesh = em
		e.position = Vector3(s, 0.08, -0.28)
		e.rotation = Vector3(PI * 0.5, 0.0, 0.0)
		e.material_override = LevelKit.mat("pepperoni")
		head.add_child(e)
	var mo := MeshInstance3D.new()
	var mm := BoxMesh.new()
	mm.size = Vector3(0.4, 0.07, 0.06)
	mo.mesh = mm
	mo.position = Vector3(0.0, -0.08, -0.27)
	mo.material_override = LevelKit.mat("mustache")
	head.add_child(mo)
	head.rotation.y = yaw + 2.6  # facing the wall, for now
	return head


## A lockable walk-in freezer interior: frost, racks of boxes, the compressor hum.
static func freezer(root: Node3D, b: LevelKit.BoxBatch, center: Vector3, rng: RandomNumberGenerator) -> void:
	for s: float in [-2.1, 2.1]:
		shelf(b, center + Vector3(s, 0.0, 0.0), false, rng, 3.5, "freezer")
	b.add(center + Vector3(0.0, 1.6, 2.7), Vector3(1.0, 0.8, 0.3), "frost", false)
	for k in 6:
		b.add(center + Vector3(rng.randf_range(-1.2, 1.2), 0.005, rng.randf_range(-2.0, 2.0)), Vector3(rng.randf_range(0.3, 0.9), 0.01, rng.randf_range(0.3, 0.9)), "frost", false, rng.randf() * PI)
	var hum := Sfx.loop_player("hum", -14.0, 10.0)
	hum.pitch_scale = 0.55
	hum.position = center + Vector3(0.0, 2.5, 2.6)
	root.add_child(hum)
	Sfx.start_loop(hum)
	var light := OmniLight3D.new()
	light.light_color = Color(0.7, 0.85, 1.0)
	light.light_energy = 1.0
	light.omni_range = 6.0
	light.position = center + Vector3(0.0, 2.9, 0.0)
	root.add_child(light)


## A giant pizza slice sculpture (Party Room Big Slice).
static func big_slice(b: LevelKit.BoxBatch, at: Vector3, yaw: float) -> void:
	b.add(at + Vector3(0.0, 1.3, 0.0), Vector3(2.4, 2.6, 0.3), "pizza_crust", true, yaw)
	b.add(at + Vector3(0.0, 1.2, 0.0), Vector3(1.9, 2.0, 0.34), "pizza_sauce", false, yaw)
	for k in 5:
		var a := float(k) * 1.3
		b.add(at + Vector3(cos(a) * 0.6, 1.2 + sin(a * 1.7) * 0.6, 0.0), Vector3(0.4, 0.4, 0.4), "vending", false, yaw)
	b.add(at + Vector3(0.0, 0.1, 0.0), Vector3(1.2, 0.2, 1.2), "steel_dark", true)


## A pinata hanging from the ceiling.
static func pinata(b: LevelKit.BoxBatch, at: Vector3, ceiling_y: float) -> void:
	b.add(Vector3(at.x, (at.y + ceiling_y) * 0.5, at.z), Vector3(0.012, ceiling_y - at.y, 0.012), "white", false)
	b.add(at, Vector3(0.7, 0.5, 0.4), "party_cloth", false, 0.4)
	b.add(at + Vector3(0.4, 0.1, 0.0), Vector3(0.3, 0.3, 0.3), "balloon_yellow", false, 0.4)
	for k in 4:
		b.add(at + Vector3(-0.25 + 0.17 * float(k), -0.32, 0.0), Vector3(0.1, 0.25, 0.1), "balloon_blue", false)


## The pass window: a hatch in a wall with its own little roll-up shutter.
static func pass_window(b: LevelKit.BoxBatch, at: Vector3, normal: Vector3) -> void:
	var yaw := atan2(normal.x, normal.z)
	b.add(at + Vector3(0.0, 1.55, 0.0) - normal * 0.06, Vector3(1.6, 1.0, 0.06), "shutter", false, yaw)
	b.add(at + Vector3(0.0, 2.15, 0.0) - normal * 0.1, Vector3(1.8, 0.2, 0.25), "steel_dark", false, yaw)
	b.add(at + Vector3(0.0, 1.02, 0.0) + normal * 0.2, Vector3(1.8, 0.06, 0.5), "steel", true, yaw)
	b.add(at + Vector3(0.0, 0.5, 0.0) + normal * 0.1, Vector3(1.7, 1.0, 0.3), "booth_dark", true, yaw)
