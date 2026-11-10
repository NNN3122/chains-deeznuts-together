class_name RallyPanel
extends Control
## Kettle Hollow's screen (Level 4) for whoever is in a rally car. The navigator gets the map:
## heading-up round their own car, every street, the route ahead in yellow, the streets that end in
## wreckage in red, the other cars, the finish, and the Strider coming up behind. The driver gets no
## map at all, only the navigator's calls, big at the top of the screen (and a chime), so the turns
## have to be talked through. Both see the countdown, how far back the Strider is, and the speed.
## The driver has a rear-view mirror (a second camera looking back off the car's tail, flipped like a
## mirror) so the Strider is something you see coming, not only a number; the navigator has the gun's
## rounds. A Flyer on the glass covers the driver's screen.
## Added to the Hud's layer by the Town; it hides itself when the local player isn't in a car.

const VIEW: float = 125.0  # m from the car to the map's edge
const CALL_SECONDS: float = 2.4

var town: Town
var _map: Control
var _call: Label
var _info: Label
var _count: Label
var _hint: Label
var _call_t: float = 0.0
var _mirror_vp: SubViewport
var _mirror_cam: Camera3D
var _mirror: TextureRect
var _mirror_frame: Panel
var _ammo: Label
var _glass: Control
var _sat_vp: SubViewport  # the navigator's satellite picture: the town (and the hills) seen from straight above
var _sat_cam: Camera3D
var _sat_frame: int = 0
var _note: Label
var _t: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map = Control.new()
	_map.clip_contents = true
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map.draw.connect(_draw_map)
	add_child(_map)
	_call = _label(96, UiTheme.YELLOW)
	_count = _label(140, UiTheme.PAPER)
	_info = _label(22, UiTheme.PAPER)
	_hint = _label(18, UiTheme.YELLOW_DIM)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ammo = _label(26, UiTheme.PAPER)
	_ammo.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	# The mirror: a small camera of its own on the same world, drawn flipped like a real mirror.
	_mirror_vp = SubViewport.new()
	_mirror_vp.size = Vector2i(480, 150)
	_mirror_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_mirror_vp)
	_mirror_cam = Camera3D.new()
	_mirror_cam.fov = 48.0
	_mirror_cam.far = 260.0
	_mirror_vp.add_child(_mirror_cam)
	_mirror_frame = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.02, 0.02, 1.0)
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(4)
	sb.border_color = Color(0.06, 0.06, 0.06)
	_mirror_frame.add_theme_stylebox_override("panel", sb)
	_mirror_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_mirror_frame)
	_mirror = TextureRect.new()
	_mirror.texture = _mirror_vp.get_texture()
	_mirror.flip_h = true
	_mirror.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_mirror.stretch_mode = TextureRect.STRETCH_SCALE
	_mirror.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mirror_frame.add_child(_mirror)
	_glass = Control.new()
	_glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glass.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glass.draw.connect(_draw_glass)
	add_child(_glass)
	move_child(_glass, 0)
	_note = _label(30, UiTheme.YELLOW)
	_sat_vp = SubViewport.new()
	_sat_vp.size = Vector2i(640, 640)
	_sat_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_sat_vp)
	_sat_cam = Camera3D.new()
	_sat_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_sat_cam.size = VIEW * 2.0
	_sat_cam.near = 1.0
	_sat_cam.far = 400.0
	var env := Environment.new()  # a satellite sees it by day: flat bright light, no fog, no night
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.06, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.98, 0.94)
	env.ambient_light_energy = 2.2
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.85
	env.adjustment_contrast = 1.15
	_sat_cam.environment = env
	_sat_vp.add_child(_sat_cam)


func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	l.add_theme_constant_override("outline_size", 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


## A call reached this car: the driver sees it big (the navigator sees what they called, smaller).
func show_call(kind: int, grade: int = 0) -> void:
	_call.text = Town.CALL_WORDS[kind] if kind >= 0 and kind < Town.CALL_WORDS.size() else ""
	var note := Town.PACE_WORDS[grade] if grade > 1 and grade < Town.PACE_WORDS.size() else ""
	match kind:
		Town.Call.LEFT:
			_call.text = "<<<  HAIRPIN LEFT" if grade == 1 else ("<<<  LEFT " + note).strip_edges()
		Town.Call.RIGHT:
			_call.text = "HAIRPIN RIGHT  >>>" if grade == 1 else ("RIGHT " + note).strip_edges() + "  >>>"
	_call.add_theme_color_override("font_color", UiTheme.DANGER if grade == 1 or grade == 2 else UiTheme.YELLOW)
	_call_t = CALL_SECONDS


func _process(delta: float) -> void:
	_t += delta
	var car := town.local_car() if town != null else null
	visible = car != null and town.active
	_mirror_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_sat_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if not visible:
		return
	var seat := town.local_seat()
	var navigator := seat >= 1
	var size := get_viewport_rect().size
	# The map: the right side of the screen for the navigator, nothing for the driver.
	var side := minf(size.y * 0.66, size.x * 0.42)
	_map.visible = navigator
	_map.position = Vector2(size.x - side - 24.0, size.y * 0.5 - side * 0.5)
	_map.size = Vector2(side, side)
	_map.queue_redraw()
	if navigator:
		# The satellite picture, heading-up round the car, refreshed every other frame.
		_sat_frame += 1
		if _sat_frame % 2 == 0:
			_sat_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		var fwd := -car.global_basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		var look_at := car.global_position + fwd * (VIEW * 2.0 * 0.12)
		_sat_cam.global_transform = Transform3D(Basis.looking_at(Vector3.DOWN, fwd), look_at + Vector3.UP * 200.0)
		# The next bend's note, for the navigator to read out.
		var nt := town.next_turn(car.progress, 220.0)
		_note.visible = not nt.is_empty()
		if _note.visible:
			var g := int(nt[2])
			var dir := "LEFT" if int(nt[1]) == Town.Call.LEFT else "RIGHT"
			var word := ("HAIRPIN " + dir) if g == 1 else (dir + (" " + Town.PACE_WORDS[g] if g > 1 else ""))
			_note.text = "NEXT:  %s   %d m" % [word, int(float(nt[0]) - car.progress)]
			_note.add_theme_color_override("font_color", UiTheme.DANGER if g == 1 or g == 2 else UiTheme.YELLOW)
		_note.position = Vector2(_map.position.x, _map.position.y - 44.0)
		_note.size = Vector2(_map.size.x, 40.0)
	else:
		_note.visible = false
	_call_t = maxf(0.0, _call_t - delta)
	_call.visible = _call_t > 0.0
	_call.modulate.a = clampf(_call_t / 0.6, 0.0, 1.0)
	_call.add_theme_font_size_override("font_size", 96 if not navigator else 44)
	_call.position = Vector2(0.0, size.y * 0.16)
	_call.size = Vector2(size.x, 120.0)
	_count.visible = town.countdown > 0.0
	_count.text = str(int(ceilf(town.countdown)))
	_count.position = Vector2(0.0, size.y * 0.3)
	_count.size = Vector2(size.x, 160.0)
	var behind := car.progress - town.strider.s
	var kmh := int(absf(car.speed) * 3.6)
	if town.strider.active:
		_info.text = "IT'S %d m BEHIND    %d km/h" % [maxi(0, int(behind)), kmh]
		var hot := behind < 40.0 and fmod(_t, 0.4) < 0.22
		_info.add_theme_color_override("font_color", UiTheme.DANGER if hot else UiTheme.PAPER)
	else:
		_info.text = "%d km/h" % kmh
		_info.add_theme_color_override("font_color", UiTheme.PAPER)
	_info.position = Vector2(0.0, 18.0)
	_info.size = Vector2(size.x, 30.0)
	if navigator:
		_hint.text = "YOU HAVE THE MAP AND THE GUN. Call the turns: talk, or A = LEFT, D = RIGHT, W = STRAIGHT ON, S = BRAKE. F or SPACE: SHOOT what's in the road, or the Strider when it's close."
	else:
		_hint.text = "YOU'RE DRIVING BLIND: listen to your navigator. W/S go and brake, A/D steer, Ctrl handbrake. The mirror shows what's behind."
	# The mirror (the driver's; the navigator has the map where it would be).
	var show_mirror := not navigator
	_mirror_frame.visible = show_mirror
	if show_mirror:
		_mirror_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		var mw := clampf(size.x * 0.34, 300.0, 620.0)
		var mh := mw * 0.3
		var want := Vector2i(int(mw * 0.8), int(mh * 0.8))  # a little soft, like a mirror at night
		if _mirror_vp.size != want:
			_mirror_vp.size = want
		_mirror_frame.position = Vector2((size.x - mw) * 0.5, 52.0)
		_mirror_frame.size = Vector2(mw, mh)
		_mirror.position = Vector2(6.0, 6.0)
		_mirror.size = Vector2(mw - 12.0, mh - 12.0)
		var back := car.global_basis.z
		back.y = 0.0
		back = back.normalized()
		var eye := car.global_position + Vector3.UP * 1.55 + back * (RallyCar.LENGTH * 0.5 + 0.2)
		_mirror_cam.global_transform = Transform3D(Basis.looking_at(back + Vector3.DOWN * 0.06, Vector3.UP), eye)
	_call.position.y = size.y * 0.16 + (60.0 if show_mirror else 0.0)
	# The navigator's rounds.
	_ammo.visible = navigator
	if navigator:
		var n := town.threats.ammo[car.index] if car.index < town.threats.ammo.size() else 0
		_ammo.text = ("ROUNDS  " + "|".repeat(n)) if n > 0 else "RELOADING..."
		_ammo.add_theme_color_override("font_color", UiTheme.PAPER if n > 2 else UiTheme.DANGER)
		_ammo.position = Vector2(size.x - minf(size.y * 0.66, size.x * 0.42) - 24.0, size.y * 0.5 + minf(size.y * 0.66, size.x * 0.42) * 0.5 + 8.0)
		_ammo.size = Vector2(400.0, 34.0)
	_glass.queue_redraw()
	_hint.position = Vector2(size.x * 0.1, size.y - 70.0)
	_hint.size = Vector2(size.x * 0.8, 50.0)


func _draw_map() -> void:
	var car := town.local_car()
	if car == null:
		return
	var side := _map.size.x
	var centre := Vector2(side * 0.5, side * 0.62)
	var k := side / (VIEW * 2.0)
	var at := car.global_position - town.origin
	var yaw := car.global_rotation.y
	var cs := cos(yaw)
	var sn := sin(yaw)
	var to_map := func(p: Vector3) -> Vector2:
		var rx := p.x - at.x
		var rz := p.z - at.z
		return centre + Vector2(rx * cs - rz * sn, rx * sn + rz * cs) * k
	_map.draw_rect(Rect2(Vector2.ZERO, _map.size), Color(0.02, 0.025, 0.03, 1.0))
	_map.draw_texture_rect(_sat_vp.get_texture(), Rect2(Vector2.ZERO, _map.size), false)
	_map.draw_rect(Rect2(Vector2.ZERO, _map.size), Color(0.0, 0.02, 0.0, 0.18))  # the screen's tint
	# The streets themselves are in the picture: only the right way is drawn on it, done in grey,
	# ahead in yellow, with an outline so it reads over roofs and roads alike.
	var pts := town.route_pts
	for n in range(1, pts.size() - 1):
		var a2: Vector2 = to_map.call(pts[n - 1])
		var b2: Vector2 = to_map.call(pts[n])
		var ahead := town.route_s[n] > car.progress
		_map.draw_line(a2, b2, Color(0.0, 0.0, 0.0, 0.7), maxf(Town.ROAD * k * 0.3, 3.0) + 3.0)
		_map.draw_line(a2, b2, Color(1.0, 0.82, 0.15) if ahead else Color(0.45, 0.42, 0.3), maxf(Town.ROAD * k * 0.3, 3.0))
	var finish: Vector2 = to_map.call(town.route_local(town.finish_s))
	_map.draw_circle(finish, 9.0, Color(0.2, 0.9, 0.35))
	# The other cars, then this one (pointing up), then the Strider.
	for c in town.cars:
		if c == car or not c.in_use:
			continue
		_map.draw_circle(to_map.call(c.global_position - town.origin), 6.0, RallyCar.LIVERIES[c.index % RallyCar.LIVERIES.size()])
	var th := town.threats
	for i in th.kinds.size():
		if th.alive[i] == 0:
			continue
		var tp: Vector2 = to_map.call(th.pos[i] - town.origin)
		if th.kinds[i] == RoadThreats.Kind.SHAMBLER:
			_map.draw_circle(tp, 3.5, Color(0.55, 0.65, 0.4))
		else:
			_map.draw_colored_polygon(PackedVector2Array([tp + Vector2(0.0, -5.0), tp + Vector2(5.0, 4.0), tp + Vector2(-5.0, 4.0)]), Color(0.95, 0.5, 0.6))
	_map.draw_colored_polygon(PackedVector2Array([centre + Vector2(0.0, -12.0), centre + Vector2(8.0, 9.0), centre + Vector2(-8.0, 9.0)]), Color(1.0, 1.0, 1.0))
	if town.strider.active:
		var sp: Vector2 = to_map.call(town.strider.global_position - town.origin)
		var pulse := 9.0 + 3.0 * sin(_t * 9.0)
		_map.draw_circle(sp, pulse, Color(0.9, 0.08, 0.05))
	_map.draw_rect(Rect2(Vector2.ZERO, _map.size), Color(0.9, 0.75, 0.2, 0.7), false, 2.0)


## A Flyer spread over this car's glass: the driver sees its belly and its mouth, and little round it.
func _draw_glass() -> void:
	var car := town.local_car() if town != null else null
	if car == null or town.threats.latched_on(car.index) < 0 or town.local_seat() != 0:
		return
	var sz := _glass.size
	# The thing itself is drawn in 3D against the camera (RoadThreats); here, the glass round it:
	# smeared red at the edges and blood running down.
	for k in 10:
		var w := sz.x * (0.04 + 0.025 * float(k % 4))
		var y := sz.y * (0.05 + 0.09 * float(k))
		_glass.draw_rect(Rect2(Vector2(0.0, y), Vector2(w, sz.y * 0.07)), Color(0.25, 0.0, 0.01, 0.35))
		_glass.draw_rect(Rect2(Vector2(sz.x - w, y), Vector2(w, sz.y * 0.07)), Color(0.25, 0.0, 0.01, 0.35))
	for k in 9:
		var x := sz.x * (0.08 + 0.105 * float(k)) + sin(float(k) * 7.0) * 20.0
		var len := sz.y * (0.25 + 0.2 * absf(sin(float(k) * 3.1)))
		var drip := minf(1.0, fmod(_t * 0.35 + float(k) * 0.13, 1.0) * 1.6)
		_glass.draw_line(Vector2(x, 0.0), Vector2(x + 4.0, len * drip), Color(0.3, 0.0, 0.02, 0.85), 4.0 + float(k % 3) * 2.0)
	var warn := "IT'S ON THE GLASS: NAVIGATOR, SHOOT IT"
	_glass.draw_string(ThemeDB.fallback_font, Vector2(0.0, sz.y * 0.86), warn, HORIZONTAL_ALIGNMENT_CENTER, sz.x, 30, UiTheme.DANGER)
