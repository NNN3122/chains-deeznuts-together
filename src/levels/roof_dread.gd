class_name RoofDread
extends Node
## Carrow Heights' horror pacing (a child of HordeArena). The roof used to throw a scare every
## 14-24 s, which the user stopped noticing; now a scare has to be earned by quiet:
##   - Server: it counts how long nothing has been near the Line (no bug within QUIET_RADIUS, no
##     Jumper hunting, nobody caught). Once it has been quiet long enough and the last scare has
##     cooled off, it builds one on whoever wandered: the HUSH (the wind dies, the swarm goes
##     silent, the target's heartbeat climbs, the nearest lamp gutters out, a beat of nothing),
##     and only then the scare itself, or sometimes nothing but a glimpse of the Tall Tenant
##     (RoofStalker). The scripted ones (the spider roofs, the bats off the tower) queue here too
##     and wait for their own quiet.
##   - Server: between scares, now and then, the Tall Tenant is glimpsed past the edge of a lamp.
##   - Every peer: the wind; the skittering in the vents of the roof ahead (heard well before the
##     wave comes out of them) and under the roof you're on; the landing lamps that gutter and die
##     as the Line comes near; the tower's red beacon breathing.

const QUIET_RADIUS: float = 16.0  # m: a living bug this close to anyone and it isn't quiet
const QUIET_MIN: float = 5.0  # s of quiet a procedural scare needs (rolled each time)
const QUIET_MAX: float = 9.0
const COOL_MIN: float = 16.0  # s after a scare before the next can start building
const COOL_MAX: float = 26.0
const FIRST_COOL: float = 8.0  # s after arriving on the roof
const HUSH_SECONDS: float = 5.6  # the build, start to scare
const SILENCE: float = 1.3  # s of nothing at all at the end of it (the heartbeat stops too)
const FAKE_OUT: float = 1.0  # weight, beside HordeArena.SCARE_POOL: the build, then only a glimpse
const GLIMPSE_MIN: float = 30.0  # s between glimpses
const GLIMPSE_MAX: float = 55.0
const GLIMPSE_QUIET: float = 5.0  # s of quiet a glimpse needs
const PENDING_TTL: float = 45.0  # s a scripted scare waits for its quiet before it's dropped
const LAMP_DIE_RANGE: float = 10.0  # m, flat: a dying lamp goes when someone comes this close
const LAMP_GUTTER_MSEC: int = 1600
const LAMP_EMBER: float = 0.1  # of its energy, a dead lamp
const LAMP_DIE_PERCENT: int = 55  # of the landing lamps past the second roof
const WIND_DB: float = -17.0
const HUSH_DB: float = -46.0
const SKITTER_RANGE: float = 38.0  # m: the vents ahead are heard from this far
const BEACON_ENERGY: float = 5.0

var arena: HordeArena
var builds: int = 0  # server: hushes started (tests)
var fired: Array[String] = []  # server: what each finished build ended in ("" a fake-out)
var hushes_heard: int = 0  # every peer
var glimpses: int = 0  # every peer: Tall Tenants spawned
var lamps_died: int = 0  # every peer
var skitters: int = 0  # every peer

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _quiet: float = 0.0
var _need: float = QUIET_MIN
var _cool: float = FIRST_COOL
var _glimpse_t: float = 20.0
var _check_t: float = 0.0
var _build_t: float = -1.0  # >= 0 while a build runs
var _build_kind: String = ""
var _build_peer: int = 0
var _pending: Array = []  # [[kind, peer, quiet needed, seconds left], ...]
var _wind: AudioStreamPlayer
var _duck_until: int = 0  # msec: the hush holds the wind and the swarm down until then
var _beats_from: int = 0
var _beats_until: int = 0
var _beat_t: float = 0.0
var _skitter_t: float = 6.0


func _ready() -> void:
	_rng.randomize()
	if not Sfx.is_silent():
		_wind = AudioStreamPlayer.new()
		_wind.name = "Wind"
		_wind.stream = Sfx.stream("wind")
		_wind.volume_db = WIND_DB
		add_child(_wind)


## Landing lamps past the second roof may die as you come near; which ones is fixed by the seed so
## every peer agrees.
static func lamp_dies(seed_value: int, roof: int) -> bool:
	if roof < 2:
		return false
	var h := absi((seed_value * 7919 + roof * 104729) % 100)
	return h < LAMP_DIE_PERCENT


# --- Server --------------------------------------------------------------------------------------

## Server: the Line has arrived or been put back on a checkpoint.
func server_reset(cool: float) -> void:
	_cool = cool
	_quiet = 0.0
	_need = _rng.randf_range(QUIET_MIN, QUIET_MAX)
	_build_t = -1.0
	_glimpse_t = maxf(_glimpse_t, cool * 0.6)


## Server: a scripted scare (the spider roofs, the bats off the tower) for this player, built as
## soon as it has been quiet for `quiet` seconds and they're standing on a roof.
func queue(kind: String, p: Player, quiet: float) -> void:
	if p == null:
		return
	for e in _pending:
		if String(e[0]) == kind and int(e[1]) == p.peer_id:
			return
	_pending.append([kind, p.peer_id, quiet, PENDING_TTL])


func is_building() -> bool:
	return _build_t >= 0.0


func server_tick(delta: float, players: Array[Player]) -> void:
	if _build_t >= 0.0:
		_build_t -= delta
		if _build_t < 0.0:
			_fire()
		return
	_cool -= delta
	_glimpse_t -= delta
	for i in range(_pending.size() - 1, -1, -1):
		_pending[i][3] = float(_pending[i][3]) - delta
		if float(_pending[i][3]) <= 0.0:
			_pending.remove_at(i)
	_check_t -= delta
	if _check_t > 0.0:
		return
	_check_t = 0.5
	_quiet = _quiet + 0.5 if _is_quiet(players) else 0.0
	for e in _pending:
		var p := _player(int(e[1]), players)
		if p != null and _quiet >= float(e[2]) and _standing(p):
			_pending.erase(e)
			_begin(String(e[0]), p)
			return
	if _cool <= 0.0 and _quiet >= _need:
		var p := _target(players)
		if p != null:
			_begin(_pick(), p)
			return
	if _glimpse_t <= 0.0 and _quiet >= GLIMPSE_QUIET:
		var p := _target(players)
		_glimpse_t = _rng.randf_range(GLIMPSE_MIN, GLIMPSE_MAX) if p != null and _glimpse(p) else 4.0


## Nothing near: no bug within QUIET_RADIUS of the Line, no Jumper hunting, nobody caught.
func _is_quiet(players: Array[Player]) -> bool:
	if arena.horde.closest_d2 < QUIET_RADIUS * QUIET_RADIUS:
		return false
	for l in arena.launchers:
		if l.is_hunting():
			return false
	for p in players:
		if p.state != Player.State.NORMAL:
			return false
	return true


## On a roof, feet down, not caught: scares never land on someone mid-jump.
func _standing(p: Player) -> bool:
	return p.is_on_floor() and p.state == Player.State.NORMAL and arena.roof_at(p.global_position) >= 0


func _player(peer: int, players: Array[Player]) -> Player:
	for p in players:
		if p.peer_id == peer:
			return p
	return null


## Whoever wandered furthest from the rest, if they're standing on a roof.
func _target(players: Array[Player]) -> Player:
	if players.is_empty():
		return null
	var centroid := Vector3.ZERO
	for p in players:
		centroid += p.global_position
	centroid /= float(players.size())
	var best: Player = null
	for p in players:
		if not _standing(p):
			continue
		if best == null or p.global_position.distance_to(centroid) > best.global_position.distance_to(centroid):
			best = p
	return best


func _pick() -> String:
	var pool: Array = HordeArena.SCARE_POOL
	var total := FAKE_OUT
	for e in pool:
		total += float(e[1])
	var r := _rng.randf() * total
	for e in pool:
		r -= float(e[1])
		if r < 0.0:
			return String(e[0])
	return ""


func _begin(kind: String, p: Player) -> void:
	builds += 1
	_build_kind = kind
	_build_peer = p.peer_id
	_build_t = HUSH_SECONDS
	ScareDirector.trigger("roof_hush", p.global_position, p.peer_id)


## The end of the build: the scare, aimed at the target wherever they are now.
func _fire() -> void:
	fired.append(_build_kind)
	_cool = _rng.randf_range(COOL_MIN, COOL_MAX)
	_need = _rng.randf_range(QUIET_MIN, QUIET_MAX)
	_quiet = 0.0
	_glimpse_t = maxf(_glimpse_t, 14.0)
	var p := _player(_build_peer, Net.get_players())
	if p == null:
		return
	if _build_kind == "":
		_glimpse(p)
	else:
		ScareDirector.trigger_for(_build_kind, p)


## Server: the Tall Tenant, past the edge of a lamp's light, in front of p but off to the side
## (the edge of vision). False if there's nowhere to put it.
func _glimpse(p: Player) -> bool:
	var spot := glimpse_spot(p)
	if spot == Vector3.INF:
		return false
	ScareDirector.trigger("roof_glimpse", spot, p.peer_id)
	return true


func glimpse_spot(p: Player) -> Vector3:
	var me := p.global_position
	var fwd := Vector3(-sin(p.body_yaw), 0.0, -cos(p.body_yaw))
	var best := Vector3.INF
	var best_score := -1.0e9
	var candidates: Array[Vector3] = []
	for lamp in arena.lamps:
		var lp := lamp.global_position
		var flat := Vector3(lp.x - me.x, 0.0, lp.z - me.z)
		var d := flat.length()
		if d < 6.0 or d > 32.0:
			continue
		for turn: float in [-0.7, 0.0, 0.7]:
			candidates.append(Vector3(lp.x, 0.0, lp.z) + (flat / d).rotated(Vector3.UP, turn) * lamp.omni_range * 0.85)
	for k in 10:
		var a := _rng.randf_range(-1.3, 1.3)
		candidates.append(me + fwd.rotated(Vector3.UP, a) * _rng.randf_range(16.0, 28.0))
	for c in candidates:
		var k := arena.roof_under(c)
		if k < 0:
			continue
		var spot := Vector3(c.x, arena.origin.y + arena.roofs[k].y, c.z)
		var to := Vector3(spot.x - me.x, 0.0, spot.z - me.z)
		var dist := to.length()
		if dist < 15.0 or dist > 34.0 or absf(spot.y - me.y) > 9.0:
			continue
		var clear := true
		for q in Net.get_players():
			if Vector2(q.global_position.x - spot.x, q.global_position.z - spot.z).length() < 13.0:
				clear = false
		if not clear:
			continue
		var facing := fwd.dot(to / dist)
		var score := -absf(facing - 0.6) - absf(dist - 22.0) / 30.0
		if score > best_score:
			best_score = score
			best = spot
	return best


# --- Every peer ----------------------------------------------------------------------------------

## The hush (HordeArena.play_scare "roof_hush"): the wind and the swarm drop away for everyone
## near, the nearest lamp gutters out at the start of the silence, and the target hears their own
## heart climbing until the silence.
func hush(pos: Vector3, targeted: bool) -> void:
	var now := Time.get_ticks_msec()
	var silence_at := now + int((HUSH_SECONDS - SILENCE) * 1000.0)
	_kill_lamp_near(pos, silence_at - LAMP_GUTTER_MSEC + 400)
	var me := Net.get_local_player()
	if me == null or me.global_position.distance_to(pos) > 40.0:
		return
	hushes_heard += 1
	_duck_until = now + int(HUSH_SECONDS * 1000.0) + 2500
	Sfx.caption(self, "the wind drops. Everything goes quiet", Vector3.INF)
	if targeted:
		_beats_from = now
		_beats_until = silence_at
		_beat_t = 0.0


## The Tall Tenant at pos, facing whoever is watching here.
func spawn_glimpse(pos: Vector3) -> RoofStalker:
	var s := RoofStalker.new()
	s.name = "RoofStalker"
	arena.add_child(s, true)
	s.global_position = pos
	var me := Net.get_local_player()
	if me != null:
		s.face(me.global_position)
	glimpses += 1
	return s


func hushed() -> bool:
	return Time.get_ticks_msec() < _duck_until


func _process(delta: float) -> void:
	if arena == null:
		return
	var now := Time.get_ticks_msec()
	var me := Net.get_local_player()
	var up := me != null and me.global_position.y > arena.origin.y - 1.0 and arena.root.visible
	var quiet := now < _duck_until
	arena.horde.muted = quiet
	if _wind != null:
		if up:
			Sfx.start_loop(_wind)
		elif _wind.playing:
			_wind.stop()
		# The wind cuts out fast and creeps back.
		_wind.volume_db = move_toward(_wind.volume_db, HUSH_DB if quiet else WIND_DB, (32.0 if quiet else 5.0) * delta)
	if now < _beats_until:
		_beat_t -= delta
		if _beat_t <= 0.0:
			var u := clampf(float(now - _beats_from) / float(maxi(1, _beats_until - _beats_from)), 0.0, 1.0)
			_beat_t = lerpf(1.05, 0.42, u)
			Sfx.play(self, "heartbeat", lerpf(-14.0, 0.0, u))
	if up and not quiet:
		_skitter_t -= delta
		if _skitter_t <= 0.0:
			_skitter_t = _rng.randf_range(6.0, 11.0)
			_skitter(me)
	_tick_lamps(now)


## Heard before seen: the vents of the roof ahead (whose wave comes out as you land), or, with
## nothing ahead in earshot and nothing near, something under the roof you're standing on.
func _skitter(me: Player) -> void:
	var at := Vector3.INF
	var text := "skittering in the vents ahead"
	var k := arena.furthest_roof + 1
	if k <= HordeArena.ROOF_COUNT:
		for v in arena.roofs[k].vents:
			var w := arena.origin + v + Vector3(0.0, 0.3, 0.0)
			var d := w.distance_to(me.global_position)
			if d < SKITTER_RANGE and (at == Vector3.INF or d < at.distance_to(me.global_position)):
				at = w
	if at == Vector3.INF:
		if arena.horde.closest_d2 < 14.0 * 14.0:
			return  # they're already here: no need to hear them coming
		var a := _rng.randf() * TAU
		at = me.global_position + Vector3(cos(a), 0.0, sin(a)) * _rng.randf_range(3.0, 7.0) + Vector3.DOWN * 1.4
		text = "something skittering under the roof"
	skitters += 1
	var dist := at.distance_to(me.global_position)
	Sfx.play_at(self, "skitter", at, lerpf(-2.0, -14.0, clampf(dist / SKITTER_RANGE, 0.0, 1.0)), _rng.randf_range(0.85, 1.2), SKITTER_RANGE + 8.0)
	Sfx.caption(self, text, at)


func _kill_lamp_near(pos: Vector3, at_msec: int) -> void:
	var best: OmniLight3D = null
	var bd := 18.0
	for lamp in arena.lamps:
		if int(lamp.get_meta("die_at", 0)) != 0:
			continue
		var d := lamp.global_position.distance_to(pos)
		if d < bd:
			bd = d
			best = lamp
	if best != null:
		best.set_meta("die_at", at_msec)


## Every lamp's energy each frame: lit, guttering, or a dead ember; the flicker scares on top.
func _tick_lamps(now: int) -> void:
	var players := Net.get_players()
	for lamp in arena.lamps:
		var energy := float(lamp.get_meta("base_energy"))
		var die_at := int(lamp.get_meta("die_at", 0))
		if die_at == 0 and bool(lamp.get_meta("can_die", false)):
			var lp := lamp.global_position
			for p in players:
				if Vector2(p.global_position.x - lp.x, p.global_position.z - lp.z).length() < LAMP_DIE_RANGE:
					die_at = now + 250
					lamp.set_meta("die_at", die_at)
					break
		if die_at != 0 and now >= die_at:
			if now >= die_at + LAMP_GUTTER_MSEC:
				energy *= LAMP_EMBER
				if not bool(lamp.get_meta("dead", false)):
					lamp.set_meta("dead", true)
					lamps_died += 1
					var head := lamp.get_meta("head", null) as MeshInstance3D
					if head != null:
						head.material_override = LevelKit.mat("dark")
					Sfx.play_at(self, "click", lamp.global_position, -4.0, 0.35, 26.0)
			else:
				# An irregular gutter: two beating rates, mostly dark by the end.
				var t := float(now - die_at) / float(LAMP_GUTTER_MSEC)
				var on := sin(float(now) * 0.047) + sin(float(now) * 0.013) > -0.4 + 1.6 * t
				energy *= 0.95 if on else 0.08
		if ScareDirector.flicker_active() and lamp.global_position.distance_to(ScareDirector.flicker_center) < ScareDirector.flicker_radius:
			energy *= 0.2 if sin(now * 0.027) > 0.0 else 0.8
		lamp.light_energy = energy
	# The fires in the wreckage: two uneven flickers each, never in step.
	var t := float(now) * 0.001
	for i in arena.fires.size():
		var f := arena.fires[i]
		var k := float(i) * 1.7
		f.light_energy = float(f.get_meta("base_energy")) * (0.72 + 0.18 * sin(t * 11.0 + k) + 0.1 * sin(t * 23.0 + k * 2.3))
	if arena.beacon != null:
		# The way out breathes, slowly: the only steady thing up here.
		arena.beacon.light_energy = BEACON_ENERGY * (0.72 + 0.28 * sin(float(now) * 0.0021))
