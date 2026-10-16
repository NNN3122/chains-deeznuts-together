class_name PlayerInput
extends Node
## Local input for the player you control. Built to survive remote-desktop tools:
## TeamViewer sends a held key as a stream of separate taps, so in Remote Controls mode a key
## counts as held for HOLD_GRACE after its last press. Arrow keys walk and turn, R toggles
## auto-walk. Remote Controls switch on by themselves when key "flicker" is detected.
## Mouse look over TeamViewer: a captured mouse spins wildly (TeamViewer sends absolute cursor
## positions), so the cursor is hidden and kept inside the window instead, and plain mouse
## movement turns the view. The remote cursor stops at the edge of the user's own screen, so
## holding it against the left or right side of the window keeps the turn going.

signal remote_mode_detected

const HOLD_GRACE_MS: int = 650  # bridges the ~500 ms gap before key repeat starts
const FLICKER_GAP_MS: int = 70  # release -> press of the same key this fast is a repeat tap
const FLICKER_COUNT: int = 4
const KEY_TURN_SPEED: float = 2.4  # rad/s with arrow keys
const PITCH_KEY_SPEED: float = 1.4  # rad/s with PageUp/PageDown
const TRACKED: Array[String] = [
	"move_forward", "move_back", "move_left", "move_right", "walk_forward_alt", "walk_back_alt",
	"turn_left", "turn_right", "look_up", "look_down", "run", "brace", "use_item",
]

const KEY_TURN_EASE: float = 9.0  # how quickly keyboard turning reaches full speed
const REMOTE_LOOK_SCALE: float = 1.4  # cursor pixels turn a bit more than raw mouse counts
const LOOK_JUMP_PX: float = 300.0  # one cursor jump this big is a teleport (refocus, warp), not a flick
const EDGE_ZONE: float = 0.07  # fraction of the window width at each side that keeps turning
const EDGE_TURN_SPEED: float = 2.6  # rad/s with the cursor right against the side of the window

var auto_run: bool = false
var look_delta: Vector2 = Vector2.ZERO  # mouse motion since the last consume_look()
var _look_pending: Vector2 = Vector2.ZERO
var _turn_v: Vector2 = Vector2.ZERO
var _down: Dictionary = {}
var _last_press: Dictionary = {}
var _last_release: Dictionary = {}
var _flickers: int = 0
var _flicker_window: int = 0
var _jump_count: int = 0
var _drop_count: int = 0


func _input(event: InputEvent) -> void:
	if GameState.ui_blocking:
		return
	if event is InputEventKey:
		var now := Time.get_ticks_msec()
		for a in TRACKED:
			if not event.is_action(a):
				continue
			if event.is_pressed():
				if not bool(_down.get(a, false)) and now - int(_last_release.get(a, -100000)) < FLICKER_GAP_MS:
					_note_flicker(now)
				_down[a] = true
				_last_press[a] = now
			else:
				_down[a] = false
				_last_release[a] = now
		if event.is_pressed() and not event.is_echo():
			if event.is_action("jump"):
				_jump_count += 1
			elif event.is_action("drop_item"):
				_drop_count += 1
			elif event.is_action("auto_run"):
				auto_run = not auto_run
				GameState.post_message_local("Auto-walk %s (R)" % ("ON" if auto_run else "OFF"), 1.5)
	elif event is InputEventMouseMotion:
		var m := event as InputEventMouseMotion
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			look_delta += m.relative
		elif Settings.remote_mode and m.relative.length() < LOOK_JUMP_PX:
			look_delta += m.relative * REMOTE_LOOK_SCALE
	elif event is InputEventMouseButton:
		var b := event as InputEventMouseButton
		if b.pressed and b.button_index == MOUSE_BUTTON_LEFT and not Settings.remote_mode \
				and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED  # click into the game to look around again


func _note_flicker(now: int) -> void:
	if now - _flicker_window > 3000:
		_flicker_window = now
		_flickers = 0
	_flickers += 1
	if _flickers >= FLICKER_COUNT and not Settings.remote_mode:
		Settings.remote_mode = true
		Settings.save_settings()
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CONFINED_HIDDEN
		remote_mode_detected.emit()
		GameState.post_message_local("Remote-desktop input detected: Remote Controls ON (change in Settings)", 5.0)


func held(action: String) -> bool:
	if GameState.ui_blocking:
		return false
	if bool(_down.get(action, false)):
		return true
	if Settings.remote_mode:
		return Time.get_ticks_msec() - int(_last_press.get(action, -100000)) < HOLD_GRACE_MS
	return false


func _axis(neg: String, pos: String) -> float:
	return (1.0 if held(pos) else 0.0) - (1.0 if held(neg) else 0.0)


## Desired movement in camera space: x = right, y = back (forward is -1), length <= 1.
func move_vector() -> Vector2:
	var v := Vector2(_axis("move_left", "move_right"), _axis("move_forward", "move_back"))
	v.y += _axis("walk_forward_alt", "walk_back_alt")
	if auto_run and v.y >= 0.0 and not held("move_back") and not held("walk_back_alt"):
		v.y = -1.0
	if held("move_back") or held("walk_back_alt"):
		auto_run = false
	return v.limit_length(1.0)


## Keyboard turning (arrow keys, Q/E, PageUp/PageDown) in radians for this frame. Eases in and
## out instead of snapping to full speed, so turning feels like a head, not a turret.
func key_look(delta: float) -> Vector2:
	var yaw := _axis("turn_left", "turn_right") * KEY_TURN_SPEED + edge_turn() * EDGE_TURN_SPEED
	var want := Vector2(yaw, _axis("look_down", "look_up") * PITCH_KEY_SPEED)
	_turn_v = _turn_v.lerp(want, 1.0 - exp(-KEY_TURN_EASE * delta))
	return _turn_v * delta


## -1..1: how hard the hidden cursor is held against the left or right side of the window.
func edge_turn() -> float:
	if not Settings.remote_mode or GameState.ui_blocking or Input.mouse_mode != Input.MOUSE_MODE_CONFINED_HIDDEN:
		return 0.0
	# Unfocused, the cursor isn't ours: it may be resting anywhere, including an edge.
	if DisplayServer.get_name() == "headless" or not get_window().has_focus():
		return 0.0
	var vp := get_viewport()
	var w := vp.get_visible_rect().size.x
	if w <= 1.0:
		return 0.0
	return edge_strength(vp.get_mouse_position().x / w)


## Turn strength for a cursor at x (0 = left side of the window, 1 = right side).
static func edge_strength(x: float) -> float:
	if x < EDGE_ZONE:
		return -smoothstep(0.0, 1.0, (EDGE_ZONE - x) / EDGE_ZONE)
	if x > 1.0 - EDGE_ZONE:
		return smoothstep(0.0, 1.0, (x - (1.0 - EDGE_ZONE)) / EDGE_ZONE)
	return 0.0


## Mouse look since last frame. In Remote Controls mode the remote cursor arrives in jumpy chunks,
## so it is fed through over a few frames.
func consume_look() -> Vector2:
	_look_pending += look_delta
	look_delta = Vector2.ZERO
	var take := _look_pending
	if Settings.remote_mode:
		take = _look_pending * (1.0 - exp(-22.0 * get_process_delta_time()))
	_look_pending -= take
	return take


func jump_count() -> int:
	return _jump_count


func drop_count() -> int:
	return _drop_count


func use_held() -> bool:
	if held("use_item"):
		return true
	if GameState.ui_blocking:
		return false
	# Left mouse fires items when the mouse is captured, or always in Remote Controls mode.
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return Settings.remote_mode or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	return false
