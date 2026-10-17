class_name PlayerParts
extends RefCounted
## The sculpted body of a DEEZ Industrial Fasteners new hire, one smooth mesh per bone of
## PlayerModel's rig (each in that pivot's own space, -z forward): hips, thighs, shins, boots,
## belly with the belt, chest in the hi-vis vest, neck, a head with a real face (sockets, brow,
## nose, lips, ears, hair), the hard hat, upper arms, forearms and gloved hands with fingers.
## Colours that differ per player (skin, vest, hair, hat) are baked into their own variants; the
## rest is shared. Sculpt caches every mesh, so this costs once.

const PANTS: Color = Color(0.16, 0.19, 0.26)
const PANTS_DARK: Color = Color(0.1, 0.12, 0.17)
const BOOT: Color = Color(0.2, 0.13, 0.07)
const SOLE: Color = Color(0.05, 0.045, 0.04)
const SHIRT: Color = Color(0.74, 0.76, 0.8)
const GLOVE: Color = Color(0.58, 0.46, 0.29)
const BELT: Color = Color(0.06, 0.05, 0.04)
const METAL: Color = Color(0.7, 0.7, 0.66)
const STRIP: Color = Color(0.86, 0.88, 0.9)
const DARK: Color = Color(0.03, 0.025, 0.02)

const CELL_BODY: float = 0.012
const CELL_FINE: float = 0.0065


static func pelvis() -> ArrayMesh:
	var s := Sculpt.new()
	s.ellipsoid(Vector3(0.0, 0.0, 0.0), Vector3(0.17, 0.11, 0.12), PANTS, 0.04, 0.9, 0.002)
	s.ellipsoid(Vector3(0.0, -0.03, 0.05), Vector3(0.145, 0.1, 0.09), PANTS, 0.04, 0.9)
	for x: float in [-0.1, 0.1]:
		s.capsule(Vector3(x, -0.02, 0.0), Vector3(x, -0.12, 0.0), 0.092, 0.088, PANTS, 0.04, 0.9)
	s.paint_box(Vector3(0.0, -0.05, -0.12), Vector3(0.008, 0.05, 0.03), PANTS_DARK, 0.9)
	return s.mesh("pl_pelvis", CELL_BODY, 1500)


static func thigh() -> ArrayMesh:
	var s := Sculpt.new()
	s.capsule(Vector3.ZERO, Vector3(0.0, -0.43, 0.0), 0.095, 0.068, PANTS, 0.03, 0.9, 0.0025)
	s.ellipsoid(Vector3(0.0, -0.15, -0.03), Vector3(0.075, 0.15, 0.07), PANTS, 0.04, 0.9)
	s.ellipsoid(Vector3(0.0, -0.42, -0.045), Vector3(0.05, 0.05, 0.04), PANTS, 0.03, 0.9)
	return s.noise_scale(28.0).mesh("pl_thigh", CELL_BODY, 1200)


static func shin() -> ArrayMesh:
	var s := Sculpt.new()
	s.capsule(Vector3(0.0, 0.01, 0.0), Vector3(0.0, -0.4, 0.0), 0.068, 0.054, PANTS, 0.03, 0.9, 0.002)
	s.ellipsoid(Vector3(0.0, -0.13, 0.03), Vector3(0.058, 0.11, 0.058), PANTS, 0.04, 0.9)
	s.ellipsoid(Vector3(0.0, -0.36, 0.0), Vector3(0.064, 0.05, 0.068), PANTS, 0.03, 0.9)
	return s.noise_scale(30.0).mesh("pl_shin", CELL_BODY, 1000)


static func boot() -> ArrayMesh:
	var s := Sculpt.new()
	s.capsule(Vector3(0.0, 0.03, 0.0), Vector3(0.0, -0.05, 0.0), 0.06, 0.066, BOOT, 0.02, 0.55)
	s.box(Vector3(0.0, -0.055, -0.06), Vector3(0.06, 0.04, 0.13), 0.035, BOOT, 0.03, 0.55)
	s.ellipsoid(Vector3(0.0, -0.05, -0.17), Vector3(0.058, 0.042, 0.05), BOOT, 0.03, 0.5)
	s.ellipsoid(Vector3(0.0, -0.06, 0.05), Vector3(0.055, 0.04, 0.045), BOOT, 0.03, 0.55)
	s.paint_box(Vector3(0.0, -0.115, -0.05), Vector3(0.1, 0.035, 0.26), SOLE, 0.9)
	s.paint_box(Vector3(0.0, -0.005, -0.09), Vector3(0.018, 0.03, 0.06), DARK, 0.7)
	return s.mesh("pl_boot", 0.009, 1000)


static func belly() -> ArrayMesh:
	var s := Sculpt.new()
	s.ellipsoid(Vector3(0.0, 0.12, 0.0), Vector3(0.165, 0.17, 0.125), SHIRT, 0.05, 0.85, 0.002)
	s.ellipsoid(Vector3(0.0, 0.0, 0.0), Vector3(0.172, 0.06, 0.127), SHIRT, 0.04, 0.85)
	s.paint_box(Vector3(0.0, 0.0, 0.0), Vector3(0.22, 0.026, 0.18), BELT, 0.5)
	s.box(Vector3(0.0, 0.0, -0.13), Vector3(0.03, 0.022, 0.008), 0.004, METAL, 0.0, 0.25)
	s.box(Vector3(0.165, -0.005, 0.07), Vector3(0.042, 0.058, 0.035), 0.012, BOOT, 0.006, 0.6)  # tool pouch
	return s.noise_scale(26.0).mesh("pl_belly", CELL_BODY, 1500)


static func chest(vest: Color) -> ArrayMesh:
	var s := Sculpt.new()
	s.ellipsoid(Vector3(0.0, 0.1, 0.0), Vector3(0.21, 0.2, 0.135), vest, 0.05, 0.75, 0.0025)
	s.capsule(Vector3(-0.18, 0.22, 0.0), Vector3(0.18, 0.22, 0.0), 0.085, 0.085, vest, 0.05, 0.75)
	for x: float in [-0.22, 0.22]:
		s.ellipsoid(Vector3(x, 0.24, 0.0), Vector3(0.07, 0.07, 0.075), SHIRT, 0.04, 0.85)
	s.capsule(Vector3(-0.07, 0.3, -0.01), Vector3(0.07, 0.3, -0.01), 0.032, 0.032, SHIRT, 0.03, 0.85)
	s.paint_ellipsoid(Vector3(0.0, 0.32, 0.0), Vector3(0.11, 0.055, 0.1), SHIRT, 0.85)
	s.paint_box(Vector3(0.0, 0.08, -0.15), Vector3(0.01, 0.22, 0.04), DARK, 0.5)  # zip
	for y: float in [-0.04, 0.12]:
		s.paint_box(Vector3(0.0, y, 0.0), Vector3(0.26, 0.017, 0.2), STRIP, 0.12)
	s.box(Vector3(-0.1, 0.16, -0.13), Vector3(0.045, 0.05, 0.012), 0.006, vest.darkened(0.15), 0.004, 0.8)
	return s.noise_scale(24.0).mesh("pl_chest", CELL_BODY, 2500)


static func neck(skin: Color) -> ArrayMesh:
	var s := Sculpt.new()
	s.capsule(Vector3(0.0, -0.04, 0.0), Vector3(0.0, 0.13, 0.0), 0.062, 0.055, skin, 0.02, 0.55)
	s.ellipsoid(Vector3(0.0, 0.03, -0.048), Vector3(0.014, 0.018, 0.012), skin, 0.015, 0.55)
	return s.mesh("pl_neck", 0.009, 400)


## The head: eyes not included (PlayerModel puts real eyeballs in the sockets).
static func head(skin: Color, hair: Color) -> ArrayMesh:
	var s := Sculpt.new()
	var lips := Color(skin.r * 0.82, skin.g * 0.6, skin.b * 0.58)
	var socket := skin.darkened(0.35)
	s.ellipsoid(Vector3(0.0, 0.07, 0.01), Vector3(0.098, 0.112, 0.11), skin, 0.03, 0.55)
	s.ellipsoid(Vector3(0.0, 0.005, -0.035), Vector3(0.08, 0.075, 0.08), skin, 0.04, 0.55)
	s.ellipsoid(Vector3(0.0, -0.055, -0.07), Vector3(0.035, 0.03, 0.03), skin, 0.03, 0.55)
	for x: float in [-0.05, 0.05]:
		s.ellipsoid(Vector3(x, 0.03, -0.075), Vector3(0.03, 0.022, 0.025), skin, 0.02, 0.5)
		s.ellipsoid(Vector3(x * 2.0, 0.04, 0.01), Vector3(0.014, 0.03, 0.022), skin, 0.01, 0.55)  # ears
	s.capsule(Vector3(-0.055, 0.072, -0.092), Vector3(0.055, 0.072, -0.092), 0.016, 0.016, skin, 0.02, 0.5)  # brow
	s.capsule(Vector3(0.0, 0.065, -0.105), Vector3(0.0, 0.015, -0.128), 0.011, 0.018, skin, 0.012, 0.45)  # nose
	s.ellipsoid(Vector3(0.0, 0.01, -0.122), Vector3(0.022, 0.012, 0.014), skin, 0.01, 0.45)
	for x: float in [-0.04, 0.04]:
		s.carve_ellipsoid(Vector3(x, 0.045, -0.1), Vector3(0.024, 0.016, 0.02), socket, 0.012)
	s.capsule(Vector3(-0.024, -0.028, -0.106), Vector3(0.024, -0.028, -0.106), 0.009, 0.009, lips, 0.006, 0.4)
	s.carve_capsule(Vector3(-0.022, -0.028, -0.117), Vector3(0.022, -0.028, -0.117), 0.003, 0.003, DARK, 0.002)
	s.ellipsoid(Vector3(0.0, 0.105, 0.03), Vector3(0.106, 0.085, 0.104), hair, 0.015, 0.85, 0.004)
	for x: float in [-1.0, 1.0]:
		s.paint_capsule(Vector3(x * 0.062, 0.079, -0.096), Vector3(x * 0.02, 0.083, -0.106), 0.007, 0.006, hair, 0.85)
	return s.noise_scale(60.0).mesh("pl_head", CELL_FINE, 4000)


static func hard_hat(color: Color) -> ArrayMesh:
	var s := Sculpt.new()
	# A tall dome, a narrow rim all round, a short peak at the front, a raised ridge front to back.
	s.ellipsoid(Vector3(0.0, 0.0, 0.0), Vector3(0.128, 0.105, 0.142), color, 0.0, 0.35)
	s.ellipsoid(Vector3(0.0, 0.012, 0.0), Vector3(0.142, 0.008, 0.158), color, 0.012, 0.35)
	s.ellipsoid(Vector3(0.0, 0.014, -0.085), Vector3(0.11, 0.007, 0.12), color, 0.012, 0.35)
	s.capsule(Vector3(0.0, 0.088, -0.09), Vector3(0.0, 0.092, 0.09), 0.011, 0.011, color, 0.025, 0.35)
	s.carve_box(Vector3(0.0, -0.06, 0.0), Vector3(0.3, 0.06, 0.3), color.darkened(0.5))
	return s.mesh("pl_hat", CELL_FINE + 0.0005, 1200)


static func upper_arm() -> ArrayMesh:
	var s := Sculpt.new()
	s.ellipsoid(Vector3(0.0, -0.02, 0.0), Vector3(0.072, 0.075, 0.07), SHIRT, 0.03, 0.85)
	s.capsule(Vector3(0.0, -0.04, 0.0), Vector3(0.0, -0.3, 0.0), 0.06, 0.048, SHIRT, 0.03, 0.85, 0.002)
	s.ellipsoid(Vector3(0.0, -0.15, -0.02), Vector3(0.05, 0.08, 0.05), SHIRT, 0.04, 0.85)
	return s.noise_scale(30.0).mesh("pl_upper_arm", 0.011, 1000)


static func forearm(skin: Color) -> ArrayMesh:
	var s := Sculpt.new()
	s.capsule(Vector3(0.0, 0.0, 0.0), Vector3(0.0, -0.27, 0.0), 0.05, 0.036, skin, 0.03, 0.55)
	s.ellipsoid(Vector3(0.0, -0.08, -0.01), Vector3(0.048, 0.08, 0.045), skin, 0.04, 0.55)
	s.ellipsoid(Vector3(0.0, -0.02, 0.0), Vector3(0.061, 0.036, 0.061), SHIRT, 0.012, 0.85, 0.003)
	return s.noise_scale(40.0).mesh("pl_forearm", 0.009, 1000)


## A work glove: palm, four fingers curled a little forward, the thumb on the inside. side: +1
## right hand, -1 left.
static func hand(side: float) -> ArrayMesh:
	var s := Sculpt.new()
	s.ellipsoid(Vector3(0.0, 0.0, 0.0), Vector3(0.042, 0.026, 0.031), GLOVE, 0.02, 0.8)
	s.box(Vector3(0.0, -0.05, 0.0), Vector3(0.04, 0.048, 0.018), 0.016, GLOVE, 0.02, 0.8, 0.0015)
	for k in 4:
		var x := -0.027 + 0.018 * float(k)
		var l := 0.055 - absf(x) * 0.5
		s.capsule(Vector3(x, -0.09, 0.0), Vector3(x, -0.09 - l, -0.02), 0.0115, 0.0095, GLOVE, 0.008, 0.8)
	s.capsule(Vector3(-side * 0.035, -0.03, -0.012), Vector3(-side * 0.052, -0.085, -0.032), 0.013, 0.01, GLOVE, 0.012, 0.8)
	return s.noise_scale(70.0).mesh("pl_hand_%d" % int(side), 0.0055, 1200)
