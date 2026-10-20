class_name PlayerInput
extends Node
## Local input for the player you control. Built to survive remote-desktop tools:
## TeamViewer can send a held key as a stream of separate taps. In Remote Controls mode a key
## stays "held" for a grace period after each release so the stream reads as one hold.
## That grace used to be a flat 650 ms on every release, which made a single tap walk you four
## or five steps. Now it is earned: it starts short, only grows to the learned repeat gap once
## flicker has actually been seen in this session, and while a hold is still unconfirmed the
## movement runs at reduced strength, so a real tap stays a short step.
## Arrow keys walk and turn, R toggles auto-walk. Mouse look over TeamViewer: a captured mouse
## spins wildly (TeamViewer sends absolute cursor positions), so the cursor is hidden and kept
## inside the window instead, and plain mouse movement turns the view. The remote cursor stops
## at the edge of the user's own screen, so holding it against the left or right side of the
## window keeps the turn going.

signal remote_mode_detected

const SHORT_GRACE_MS: int = 140  # before flicker is proven: just enough to bridge packet jitter
const DEFAULT_GRACE_MS: int = 650  # bridges the ~500 ms gap before key repeat starts
const MIN_GRACE_MS: int = 260
const MAX_GRACE_MS: int = 1100
const GRACE_MARGIN_MS: int = 120  # added to the measured repeat delay
# Once a hold is confirmed the remote side is sending repeats every few dozen ms, so a release
# only has to outlast that stream's jitter, not the long first delay (the long grace kept you
# sprinting for 0.65 s after letting go: "it still adds a couple of steps").
const CONFIRMED_GRACE_MS: int = 180
const FLICKER_GAP_MS: int = 70  # release -> press of the same key this fast is a repeat tap
const FLICKER_COUNT: int = 4
const UNCONFIRMED_STRENGTH: float = 0.45  # movement while a tap might still be a tap
const KEY_TURN_SPEED: float = 2.4  # rad/s with arrow keys
const PITCH_KEY_SPEED: float = 1.4  # rad/s with PageUp/PageDown
const TRACKED: Array[String] = [
	"move_forward", "move_back", "move_left", "move_right", "walk_forward_alt", "walk_back_alt",
	"turn_left", "turn_right", "look_up", "look_down", "run", "brace", "use_item",
]

const KEY_TURN_EASE: float = 18.0  # 1/s, how quickly keyboard turning reaches full speed
const REMOTE_LOOK_RATE: float = 55.0  # 1/s, how fast a remote cursor's motion is fed into the view
const REMOTE_LOOK_SCALE: float = 1.4  # cursor pixels turn a bit more than raw mouse counts
const LOOK_JUMP_PX: float = 300.0  # one cursor jump this big is a teleport (refocus, warp), not a flick
const EDGE_ZONE: float = 0.07  # fraction of the window width at each side that keeps turning
const EDGE_TURN_SPEED: float = 2.6  # rad/s with the cursor right against the side of the window
const EDGE_ZONE_Y: float = 0.08  # fraction of the window height at top and bottom that keeps tilting
const EDGE_PITCH_SPEED: float = 1.3  # rad/s with the cursor against the top or bottom of the window
# A hidden cursor left resting in an edge zone used to turn the view forever (the user's "drift").
# The edge only keeps turning for this long after the cursor last moved, then fades out.
const EDGE_HOLD_MS: int = 1800
const EDGE_FADE_MS: int = 500

var auto_run: bool = false
var look_delta: Vector2 = Vector2.ZERO  # mouse motion since the last consume_look()
var flicker_seen: bool = false  # this session delivered a held key as taps at least once
var _look_pending: Vector2 = Vector2.ZERO
var _turn_v: Vector2 = Vector2.ZERO
var _down: Dictionary = {}
var _last_press: Dictionary = {}
var _last_release: Dictionary = {}
var _confirmed: Dictionary = {}  # action -> this hold has shown a repeat press, so it is a real hold
var _first_gap: Dictionary = {}  # action -> release->press gap of the hold's first repeat (ms)
var _flickers: int = 0
var _flicker_window: int = 0
var _jump_count: int = 0
var _drop_count: int = 0
var _use_count: int = 0
var _slot_count: int = 0
var _slot_request: int = 0  # 1..3 the slot last asked for, 0 none; wheel: 4 next, 5 previous; 6 the key slot
var _reload_count: int = 0
var _cursor_moved_at: int = -100000  # msec of the last mouse motion


func _notification(what: int) -> void:
	# Focus lost (alt-tab, a TeamViewer reconnect): releases that happen elsewhere never reach us,
	# so a key would stay down and walk or turn you forever.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_down.clear()
		_confirmed.clear()
		reset_look()


func _input(event: InputEvent) -> void:
	if GameState.ui_blocking:
		return
	if event is InputEventKey:
		var now := Time.get_ticks_msec()
		for a in TRACKED:
			if not event.is_action(a):
				continue
			if event.is_pressed():
				if not bool(_down.get(a, false)):
					var gap := now - int(_last_release.get(a, -100000))
					if gap < FLICKER_GAP_MS:
						_note_flicker(now)
						_confirm_hold(a)
					elif gap < grace_ms():
						# The first repeat after the initial delay: remember the delay, confirm on the next.
						_first_gap[a] = gap
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
			elif event.is_action("use_item"):
				_use_count += 1
			elif event.is_action("reload"):
				_reload_count += 1
			elif event.is_action("slot_1"):
				_request_slot(1)
			elif event.is_action("slot_2"):
				_request_slot(2)
			elif event.is_action("slot_3"):
				_request_slot(3)
			elif event.is_action("slot_4"):
				_request_slot(6)  # the Shackle Key's own slot
			elif event.is_action("auto_run"):
				auto_run = not auto_run
				GameState.post_message_local("Auto-walk %s (R)" % ("ON" if auto_run else "OFF"), 1.5)
	elif event is InputEventMouseMotion:
		var m := event as InputEventMouseMotion
		if m.relative.length_squared() > 0.0:
			_cursor_moved_at = Time.get_ticks_msec()
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			look_delta += m.relative
		elif Settings.remote_mode and m.relative.length() < LOOK_JUMP_PX:
			look_delta += m.relative * REMOTE_LOOK_SCALE
	elif event is InputEventMouseButton:
		var b := event as InputEventMouseButton
		var in_game := Settings.remote_mode or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		if b.pressed and b.button_index == MOUSE_BUTTON_LEFT and not Settings.remote_mode \
				and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED  # click into the game to look around again
		elif b.pressed and b.button_index == MOUSE_BUTTON_LEFT and in_game:
			_use_count += 1
		elif b.pressed and b.button_index == MOUSE_BUTTON_WHEEL_DOWN and in_game:
			_request_slot(4)
		elif b.pressed and b.button_index == MOUSE_BUTTON_WHEEL_UP and in_game:
			_request_slot(5)


func _request_slot(which: int) -> void:
	_slot_count += 1
	_slot_request = which


func _confirm_hold(a: String) -> void:
	if bool(_confirmed.get(a, false)):
		return
	_confirmed[a] = true
	# The gap before the first repeat is the remote side's key-repeat delay: that is the grace
	# we actually need, no more.
	if _first_gap.has(a):
		var learned := clampi(int(_first_gap[a]) + GRACE_MARGIN_MS, MIN_GRACE_MS, MAX_GRACE_MS)
		if learned != Settings.remote_key_gap_ms:
			Settings.remote_key_gap_ms = learned
			Settings.save_settings()
		_first_gap.erase(a)


func _note_flicker(now: int) -> void:
	if now - _flicker_window > 3000:
		_flicker_window = now
		_flickers = 0
	_flickers += 1
	if _flickers >= 2:
		flicker_seen = true
	if _flickers >= FLICKER_COUNT and not Settings.remote_mode:
		Settings.remote_mode = true
		Settings.save_settings()
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CONFINED_HIDDEN
		remote_mode_detected.emit()
		GameState.post_message_local("Remote-desktop input detected: Remote Controls ON (change in Settings)", 5.0)


## How long a released key still counts as held in Remote Controls mode.
func grace_ms() -> int:
	if not flicker_seen:
		return SHORT_GRACE_MS
	return clampi(Settings.remote_key_gap_ms, MIN_GRACE_MS, MAX_GRACE_MS)


## 0 = released, 1 = held. In Remote Controls mode a key just released is still held at reduced
## strength until a repeat press proves it was a real hold.
func strength(action: String) -> float:
	if GameState.ui_blocking:
		return 0.0
	if bool(_down.get(action, false)):
		if Input.is_action_pressed(action):
			return 1.0
		# Released while we weren't listening (a menu was up): count it as released now.
		_down[action] = false
		_last_release[action] = Time.get_ticks_msec()
	if not Settings.remote_mode:
		return 0.0
	var since := Time.get_ticks_msec() - int(_last_press.get(action, -100000))
	var confirmed := bool(_confirmed.get(action, false))
	if since >= (mini(CONFIRMED_GRACE_MS, grace_ms()) if confirmed else grace_ms()):
		_confirmed.erase(action)
		return 0.0
	return 1.0 if confirmed else UNCONFIRMED_STRENGTH


func held(action: String) -> bool:
	return strength(action) > 0.0


func _axis(neg: String, pos: String) -> float:
	return strength(pos) - strength(neg)


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
	var edge := edge_look()
	var yaw := _axis("turn_left", "turn_right") * KEY_TURN_SPEED + edge.x * EDGE_TURN_SPEED
	var want := Vector2(yaw, _axis("look_down", "look_up") * PITCH_KEY_SPEED + edge.y * EDGE_PITCH_SPEED)
	_turn_v = _turn_v.lerp(want, 1.0 - exp(-KEY_TURN_EASE * delta))
	return _turn_v * delta


## How hard the hidden cursor is held against the window's sides: x -1..1 turns left/right, y
## -1..1 tilts down/up (a remote cursor stops at the window's bottom, and you could no longer look
## down). It only lasts EDGE_HOLD_MS after the cursor last moved, so a forgotten cursor stops.
func edge_look() -> Vector2:
	if not Settings.remote_mode or GameState.ui_blocking or Input.mouse_mode != Input.MOUSE_MODE_CONFINED_HIDDEN:
		return Vector2.ZERO
	# Unfocused, the cursor isn't ours: it may be resting anywhere, including an edge.
	if DisplayServer.get_name() == "headless" or not get_window().has_focus():
		return Vector2.ZERO
	var vp := get_viewport()
	var size := vp.get_visible_rect().size
	if size.x <= 1.0 or size.y <= 1.0:
		return Vector2.ZERO
	var still := float(Time.get_ticks_msec() - _cursor_moved_at - EDGE_HOLD_MS)
	var fade := 1.0 - clampf(still / float(EDGE_FADE_MS), 0.0, 1.0)
	if fade <= 0.0:
		return Vector2.ZERO
	var p := vp.get_mouse_position() / size
	return Vector2(edge_strength(p.x), -edge_strength(p.y, EDGE_ZONE_Y)) * fade


## Turn strength for a cursor at x (0 = left or top of the window, 1 = right or bottom).
static func edge_strength(x: float, zone: float = EDGE_ZONE) -> float:
	if x < zone:
		return -smoothstep(0.0, 1.0, (zone - x) / zone)
	if x > 1.0 - zone:
		return smoothstep(0.0, 1.0, (x - (1.0 - zone)) / zone)
	return 0.0


## Mouse look since last frame. In Remote Controls mode the remote cursor arrives in jumpy chunks,
## so it is fed through over a few frames.
func consume_look() -> Vector2:
	_look_pending += look_delta
	look_delta = Vector2.ZERO
	var take := _look_pending
	if Settings.remote_mode:
		# Just enough to blend one cursor chunk into the next frame or two. At 22/s this trailed the
		# mouse by a tenth of a second and the user felt the view arrive late.
		take = _look_pending * (1.0 - exp(-REMOTE_LOOK_RATE * get_process_delta_time()))
	_look_pending -= take
	return take


## Drops any look still on its way in and stops keyboard/edge turning dead.
func reset_look() -> void:
	look_delta = Vector2.ZERO
	_look_pending = Vector2.ZERO
	_turn_v = Vector2.ZERO


func jump_count() -> int:
	return _jump_count


func drop_count() -> int:
	return _drop_count


## Taps of F / left click. Sent as a counter so a tap survives a lost packet.
func use_count() -> int:
	return _use_count


func reload_count() -> int:
	return _reload_count


func slot_count() -> int:
	return _slot_count


func slot_request() -> int:
	return _slot_request


func use_held() -> bool:
	if held("use_item"):
		return true
	if GameState.ui_blocking:
		return false
	# Left mouse fires items when the mouse is captured, or always in Remote Controls mode.
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return Settings.remote_mode or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	return false
