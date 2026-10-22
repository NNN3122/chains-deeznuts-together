class_name Groundskeeper
extends HollowHire
## Level 4's hunter: the Groundskeeper of Ashgrave Manor (GroundskeeperBody). It hunts like a Hollow
## Hire (sight, the chase, the four attacks, the catch, the stun, the rescues), walking the Manor's
## grid of the grounds instead of the office's rooms, and it is worse (the user: "too easy to get
## away", "make sure it can hear when you sprint or breathe heavy or just loud noise in general",
## "it can't kill you if you have your flashlight up"):
## - It hears. A player's own noise (Player.noise_level: a sprint, a landing, gasping for breath when
##   winded, the wrench) carries EAR_RANGE; loud enough and it comes running at whoever made it, and
##   while you keep making it it knows where you are, seen or not. Quieter, it comes to look.
## - It runs faster than a Hire and remembers you longer; past its sight it still follows your noise.
## - A light in its face does nothing: there's a sack over its head (no flashlight stun, no flashlight
##   rescue; the wrench, the air horn, a gun and a bomb still work).
## - It knows your hands: a wrong key at an engine, or a page typed slower than ManorMachine.WPM_MIN,
##   brings it straight for the typist (Manor.server_typing_alarm -> hear_typist).
## What makes it the machines' warden lives in Manor: it patrols the unfinished machines, is drawn to
## whichever one is being worked on, and kicks a half-repaired machine it passes so it runs back down.

const KEEPER_CHASE_SPEED: float = 6.4  # m/s: a sprint (7) still gains on it, until you're winded
const KEEPER_SIGHT: float = 22.0  # m
const KEEPER_LOSE_TIME: float = 7.0  # s without sight or sound before it gives up on where you were
const EAR_RANGE: float = 36.0  # m: the furthest it hears anything
const EAR_NOISE: float = 14.0  # loudness where it stands that it hears at all (and keeps chasing by)
const EAR_HUNT: float = 26.0  # from a player this loud it comes running: a sprint within ~19 m, a gasp within ~3
const EAR_ALERT: float = 16.0  # s it hunts after hearing something
const EAR_FLOORS: float = 7.0  # m: it hears through the mansion's floor


func _make_body() -> HireBody:
	return GroundskeeperBody.new()


func _ready() -> void:
	super()
	add_to_group("groundskeeper")
	chase_speed = KEEPER_CHASE_SPEED
	sight_range = KEEPER_SIGHT
	lose_time = KEEPER_LOSE_TIME
	hear_radius = EAR_RANGE


## Straight at you only when nothing on the grid is in the way either: a raycast at chest height
## sails over the headstones and ledgers it would otherwise walk through.
func _has_clear_floor_line(target: Vector3) -> bool:
	if not super._has_clear_floor_line(target):
		return false
	var manor := level as Manor
	return manor == null or manor.clear_walk(global_position, target)


## How loud p is where it stands (0: it can't hear them at all).
func heard(p: Player) -> float:
	if p == null or p.state != Player.State.NORMAL or absf(p.global_position.y - global_position.y) > EAR_FLOORS or level.is_safe_spot(p.global_position):
		return 0.0
	var d := _flat_dist(p.global_position)
	if d > EAR_RANGE:
		return 0.0
	return p.noise_level() * (1.0 - d / EAR_RANGE)


## Seen, or still heard: either keeps it on you.
func _senses(p: Player) -> bool:
	return super(p) or heard(p) >= EAR_NOISE


## The loudest player it can hear: loud enough, it comes running at them; less, it comes to look.
## Anything else loud (an engine being worked, a clang, a decoy) as a Hire hears it, from further.
func _listen() -> void:
	var best: Player = null
	var best_eff := 0.0
	for p in Net.get_players():
		var eff := heard(p)
		if eff > best_eff:
			best_eff = eff
			best = p
	if best != null and best_eff >= EAR_HUNT:
		_alert_t = maxf(_alert_t, EAR_ALERT)
		_start_chase(best, true)
		return
	if best != null and best_eff >= EAR_NOISE:
		if not (hstate == HState.INVESTIGATE and _goal.distance_to(best.global_position) < 3.0):
			alert(best.global_position, EAR_ALERT)
		return
	super()


## The light means nothing to it.
func _tick_burn(_delta: float) -> bool:
	burn_fraction = 0.0
	return false


## Server: a slip at an engine or a page typed too slowly. It knows, wherever it is, and comes for
## the typist.
func hear_typist(p: Player) -> void:
	if p == null or asleep or debug_frozen or hstate == HState.GRAB or hstate == HState.STUNNED or hstate == HState.DEAD or is_attacking():
		return
	_alert_t = maxf(_alert_t, EAR_ALERT)
	if hstate == HState.CHASE:
		if _target == p:
			_last_seen = p.global_position
			_lose_t = 0.0
		return  # after someone else: it keeps on them
	_start_chase(p, true)
