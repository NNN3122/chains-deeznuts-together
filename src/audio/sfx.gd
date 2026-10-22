class_name Sfx
extends RefCounted
## Every sound in the game, synthesized in code (no audio files). Streams are generated once
## and cached. Headless runs never play anything: the dummy audio driver never releases a
## played stream, which leaks at exit, and nobody can hear it anyway.

const RATE: int = 22050
const IDS: Array[String] = [
	"hum", "drone", "step", "clink", "creak", "thump", "stinger", "shot", "boom", "squeak",
	"whisper", "phone", "slam", "heartbeat", "jet", "gulp", "pickup", "lift", "ding", "tile",
	"growl", "scrape", "click", "flashlight",
	"jukebox", "servo", "shutter", "bell", "klaxon", "static", "popper", "airhorn", "birthday", "bang",
	"screech", "wind", "skitter", "scream", "roar",
	"hire_gurgle", "cust_hiss", "cust_shriek", "pappy_laugh", "pappy_scream", "spider_hiss", "spider_shriek",
	"roach_chitter", "chase", "pant",
	"engine", "toll", "gate",
]

## Sounds that get an on-screen caption (Settings.captions), with direction worked out by the HUD.
const CAPTIONS: Dictionary = {
	"growl": "something snarls", "phone": "a phone is ringing", "whisper": "someone whispers",
	"slam": "a door slams", "tile": "a ceiling tile crashes down", "boom": "explosion",
	"shot": "gunshot", "squeak": "squeaky toy", "ding": "elevator chime",
	"servo": "servo whine, rising", "shutter": "a shutter rolls", "bell": "the counter bell rings",
	"klaxon": "overload klaxon", "popper": "party popper", "airhorn": "AIR HORN", "bang": "BANG on the shutter",
	"birthday": "the band sings, slowly", "screech": "a SCREECH: it's about to jump",
	"scream": "a SCREAM", "roar": "a roar, right on you",
	"hire_gurgle": "a wet, choking gurgle", "cust_hiss": "a hiss through teeth, above", "cust_shriek": "a whistling SHRIEK",
	"pappy_laugh": "a broken speaker laughs", "pappy_scream": "a SCREAM, all metal and static", "spider_hiss": "a dry, rattling hiss",
	"spider_shriek": "a chattering SHRIEK", "roach_chitter": "chittering",
	"toll": "a bell tolls, somewhere", "gate": "iron grinding: a gate",
}

static var _cache: Dictionary = {}


## Shows a caption for a sound at a world position (or Vector3.INF for "everywhere").
static func caption(owner: Node, text: String, pos: Vector3) -> void:
	if owner == null or not owner.is_inside_tree() or not Settings.captions:
		return
	var hud := owner.get_tree().get_first_node_in_group("hud")
	if hud != null:
		hud.call("caption", text, pos)


static func is_silent() -> bool:
	return DisplayServer.get_name() == "headless"


static func stream(id: String) -> AudioStreamWAV:
	if _cache.has(id):
		return _cache[id]
	var s := _build(id)
	_cache[id] = s
	return s


static func warmup() -> void:
	for id in IDS:
		stream(id)


## Non-positional one-shot (UI, your own scares).
static func play(owner: Node, id: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if is_silent() or owner == null or not owner.is_inside_tree():
		return
	var p := AudioStreamPlayer.new()
	p.stream = one_shot(id)
	p.volume_db = volume_db
	p.pitch_scale = pitch
	owner.get_tree().root.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


## Positional one-shot. Lives under the root so it survives its owner being freed.
static func play_at(owner: Node, id: String, pos: Vector3, volume_db: float = 0.0, pitch: float = 1.0, max_distance: float = 40.0) -> void:
	if is_silent() or owner == null or not owner.is_inside_tree():
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = one_shot(id)
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.max_distance = max_distance
	p.unit_size = 5.0
	owner.get_tree().root.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()
	if CAPTIONS.has(id):
		caption(owner, CAPTIONS[id], pos)


## A one-shot must end, or its player (freed on "finished") lives under the root forever and
## the sound never stops. Looping banks (jukebox, static) get a non-looping copy here.
static var _one_shots: Dictionary = {}

static func one_shot(id: String) -> AudioStreamWAV:
	var s := stream(id)
	if s.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		return s
	if not _one_shots.has(id):
		var copy := s.duplicate() as AudioStreamWAV
		copy.loop_mode = AudioStreamWAV.LOOP_DISABLED
		_one_shots[id] = copy
	return _one_shots[id]


## A monster's idle noise, played only for a local player on its floor and within reach: how you
## know where it is before you see it. Ambient, so each peer rolls its own and nothing is synced.
static func idle_call(owner: Node3D, id: String, pos: Vector3, volume_db: float, pitch: float, reach: float, text: String, max_dy: float = 3.0) -> void:
	if is_silent() or owner == null or not owner.is_inside_tree():
		return
	# Looked up by path, not the Net autoload's name, so Sfx still compiles in the bare sound check.
	var net := owner.get_node_or_null("/root/Net")
	var me: Node3D = net.call("get_local_player") if net != null else null
	if me == null or absf(me.global_position.y - pos.y) > max_dy or me.global_position.distance_to(pos) > reach:
		return
	play_at(owner, id, pos, volume_db, pitch, reach)
	caption(owner, text, pos)


## A looping positional player for the caller to parent and start with start_loop().
static func loop_player(id: String, volume_db: float, max_distance: float = 30.0) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream(id)
	p.volume_db = volume_db
	p.max_distance = max_distance
	p.unit_size = 4.0
	return p


static func start_loop(p: Node) -> void:
	if is_silent() or p == null:
		return
	if p is AudioStreamPlayer3D and not (p as AudioStreamPlayer3D).playing:
		(p as AudioStreamPlayer3D).play()
	elif p is AudioStreamPlayer and not (p as AudioStreamPlayer).playing:
		(p as AudioStreamPlayer).play()


# --- Synthesis ------------------------------------------------------------------------------

static func _build(id: String) -> AudioStreamWAV:
	match id:
		"hum": return _pack(_hum(), true)
		"drone": return _pack(_drone(), true)
		"step": return _pack(_step())
		"clink": return _pack(_clink())
		"creak": return _pack(_creak(), true)
		"thump": return _pack(_thump(0.6, 55.0))
		"stinger": return _pack(_stinger())
		"shot": return _pack(_shot())
		"boom": return _pack(_boom())
		"squeak": return _pack(_squeak())
		"whisper": return _pack(_whisper())
		"phone": return _pack(_phone())
		"slam": return _pack(_slam())
		"heartbeat": return _pack(_heartbeat())
		"jet": return _pack(_jet(), true)
		"gulp": return _pack(_gulp())
		"pickup": return _pack(_chime([880.0, 1320.0], 0.35))
		"lift": return _pack(_lift(), true)
		"ding": return _pack(_chime([1046.0, 1568.0], 1.3))
		"tile": return _pack(_tile())
		"growl": return _pack(_growl())
		"scrape": return _pack(_scrape(), true)
		"click": return _pack(_click())
		"flashlight": return _pack(_click(0.5))
		"jukebox": return _pack(_jukebox(), true)
		"servo": return _pack(_servo())
		"shutter": return _pack(_shutter())
		"bell": return _pack(_chime([2093.0, 2637.0, 3136.0], 1.1))
		"klaxon": return _pack(_klaxon())
		"static": return _pack(_static(), true)
		"popper": return _pack(_popper())
		"airhorn": return _pack(_airhorn())
		"birthday": return _pack(_birthday())
		"bang": return _pack(_bang())
		"screech": return _pack(_screech())
		"wind": return _pack(_wind(), true)
		"skitter": return _pack(_skitter())
		"scream": return _pack(_scream())
		"roar": return _pack(_roar())
		"hire_gurgle": return _pack(_hire_gurgle())
		"cust_hiss": return _pack(_cust_hiss())
		"cust_shriek": return _pack(_cust_shriek())
		"pappy_laugh": return _pack(_pappy_laugh())
		"pappy_scream": return _pack(_pappy_scream())
		"spider_hiss": return _pack(_spider_hiss())
		"spider_shriek": return _pack(_spider_shriek())
		"roach_chitter": return _pack(_roach_chitter())
		"chase": return _pack(_chase(), true)
		"pant": return _pack(_pant(), true)
		"engine": return _pack(_engine(), true)
		"toll": return _pack(_toll())
		"gate": return _pack(_gate())
	push_warning("Sfx: unknown sound '%s'" % id)
	return _pack(PackedFloat32Array([0.0]))


static func _pack(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = samples.size()
	return s


static func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b


static func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


static func _lp_coef(cutoff: float) -> float:
	return 1.0 - exp(-TAU * cutoff / float(RATE))


## Blends the tail into the head so a noise-based loop has no click at the seam.
static func _seamless(b: PackedFloat32Array, fade_seconds: float) -> PackedFloat32Array:
	var n := b.size()
	var f := int(fade_seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n - f)
	for i in n - f:
		out[i] = b[i]
	for i in f:
		var t := float(i) / float(f)
		out[i] = b[i] * t + b[n - f + i] * (1.0 - t)
	return out


static func _hum() -> PackedFloat32Array:
	var b := _buf(2.0)
	var r := _rng(60)
	for i in b.size():
		var t := float(i) / RATE
		var buzz := signf(sin(TAU * 120.0 * t)) * 0.035
		b[i] = 0.22 * sin(TAU * 60.0 * t) + 0.14 * sin(TAU * 120.0 * t) + 0.07 * sin(TAU * 180.0 * t) + buzz + r.randf_range(-0.015, 0.015)
	return b


static func _drone() -> PackedFloat32Array:
	var b := _buf(6.0)
	var r := _rng(41)
	var lp := 0.0
	var lp2 := 0.0
	var a := _lp_coef(180.0)
	for i in b.size():
		var t := float(i) / RATE
		lp += a * (r.randf_range(-1.0, 1.0) - lp)
		lp2 += a * (lp - lp2)
		var swell := 0.6 + 0.4 * sin(TAU * t / 6.0)
		# Two notes a semitone apart, beating slowly against each other: wrong, never resolving.
		var unease := 0.035 * (sin(TAU * 82.4 * t) + sin(TAU * 87.3 * t)) * (0.5 + 0.5 * sin(TAU * t / 6.0 + 1.0))
		# Once a loop, the building groans: a deep bend down with a rough edge.
		var g := clampf((t - 2.8) / 1.8, 0.0, 1.0)
		var groan := sin(TAU * (140.0 * t - 12.0 * g * g * 1.8)) * sin(PI * g) * (0.8 + 0.2 * sin(TAU * 31.0 * t)) * 0.05
		b[i] = lp2 * 2.2 * swell + 0.08 * sin(TAU * 41.0 * t) + 0.04 * sin(TAU * 61.5 * t) + unease + groan
	return _seamless(b, 0.5)


static func _step() -> PackedFloat32Array:
	var b := _buf(0.16)
	var r := _rng(7)
	var lp := 0.0
	var a := _lp_coef(900.0)
	for i in b.size():
		var t := float(i) / RATE
		lp += a * (r.randf_range(-1.0, 1.0) - lp)
		b[i] = (lp * 1.6 + 0.5 * sin(TAU * 85.0 * t)) * exp(-t * 38.0)
	return b


static func _clink() -> PackedFloat32Array:
	var b := _buf(0.4)
	var freqs := [1730.0, 2410.0, 3960.0, 5230.0]
	var decays := [11.0, 15.0, 22.0, 30.0]
	var amps := [0.35, 0.25, 0.18, 0.1]
	for i in b.size():
		var t := float(i) / RATE
		var s := 0.0
		for k in 4:
			s += float(amps[k]) * sin(TAU * float(freqs[k]) * t) * exp(-t * float(decays[k]))
		b[i] = s
	return b


static func _creak() -> PackedFloat32Array:
	var b := _buf(4.0)
	var r := _rng(13)
	var lp := 0.0
	var a := _lp_coef(400.0)
	var phase := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var f := 52.0 + 9.0 * sin(TAU * 0.5 * t) + 4.0 * sin(TAU * 1.75 * t)
		phase += f / RATE
		var saw := 2.0 * (phase - floorf(phase)) - 1.0
		lp += a * (saw * 0.6 + r.randf_range(-0.4, 0.4) - lp)
		var trem := 0.5 + 0.5 * absf(sin(TAU * 0.75 * t))
		b[i] = lp * 0.9 * trem
	return _seamless(b, 0.4)


static func _thump(seconds: float, freq: float) -> PackedFloat32Array:
	var b := _buf(seconds)
	var r := _rng(3)
	var lp := 0.0
	var a := _lp_coef(320.0)
	for i in b.size():
		var t := float(i) / RATE
		lp += a * (r.randf_range(-1.0, 1.0) - lp)
		b[i] = (0.8 * sin(TAU * freq * t * (1.0 - t * 0.4)) + lp * 1.3) * exp(-t * 7.0)
	return b


## The jump-scare hit: a slam of low strings a semitone apart, a shriek of high ones on top that
## won't settle, a burst of noise and a sub thump under it all. Instant attack, a long ugly tail.
static func _stinger() -> PackedFloat32Array:
	var dur := 1.4
	var b := _buf(dur)
	var r := _rng(1337)
	var lows: Array[float] = [55.0, 58.3, 82.4, 87.3, 110.0]
	var highs: Array[float] = [1760.0, 1864.7, 2349.3, 2489.0]
	var ph := PackedFloat32Array()
	ph.resize(lows.size())
	var lp := 0.0
	var a := _lp_coef(1800.0)
	for i in b.size():
		var t := float(i) / RATE
		var low := 0.0
		for k in lows.size():
			ph[k] += lows[k] * (1.0 + 0.004 * sin(TAU * (3.0 + float(k)) * t)) / RATE
			low += 2.0 * (ph[k] - floorf(ph[k])) - 1.0
		lp += a * (low * 0.35 - lp)
		var high := 0.0
		for k in highs.size():
			var vib := 1.0 + 0.012 * sin(TAU * (9.0 + 2.3 * float(k)) * t)
			high += sin(TAU * highs[k] * vib * t)
		var env_low := exp(-t * 1.8)
		var env_high := minf(1.0, t * 60.0) * exp(-t * 2.4)
		var burst := r.randf_range(-1.0, 1.0) * exp(-t * 14.0)
		var sub := sin(TAU * (48.0 - 20.0 * t) * t) * exp(-t * 6.0)
		b[i] = tanh((lp * env_low + high * 0.16 * env_high + burst * 0.9 + sub * 0.9) * 1.6)
	return _normalize(b, 0.95)


static func _shot() -> PackedFloat32Array:
	var b := _buf(0.5)
	var r := _rng(9)
	var lp := 0.0
	var a := _lp_coef(2500.0)
	for i in b.size():
		var t := float(i) / RATE
		var n := r.randf_range(-1.0, 1.0)
		lp += a * (n - lp)
		b[i] = (lp * 1.5 * exp(-t * 22.0)) + 0.7 * sin(TAU * 70.0 * t) * exp(-t * 14.0)
	return b


static func _boom() -> PackedFloat32Array:
	var b := _buf(2.0)
	var r := _rng(11)
	var lp := 0.0
	var a := _lp_coef(380.0)
	for i in b.size():
		var t := float(i) / RATE
		lp += a * (r.randf_range(-1.0, 1.0) - lp)
		b[i] = (lp * 2.6 * exp(-t * 2.6)) + 0.8 * sin(TAU * 42.0 * t) * exp(-t * 3.5)
	return b


static func _squeak() -> PackedFloat32Array:
	var b := _buf(0.28)
	var phase := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var u := t / 0.28
		var f := 1150.0 + 700.0 * sin(PI * u) + 60.0 * sin(TAU * 35.0 * t)
		phase += f / RATE
		b[i] = 0.5 * sin(TAU * phase) * sin(PI * u)
	return b


static func _whisper() -> PackedFloat32Array:
	var b := _buf(1.8)
	var r := _rng(21)
	var lp := 0.0
	var lp2 := 0.0
	var a := _lp_coef(5000.0)
	var a2 := _lp_coef(1400.0)
	for i in b.size():
		var t := float(i) / RATE
		var n := r.randf_range(-1.0, 1.0)
		lp += a * (n - lp)
		lp2 += a2 * (lp - lp2)
		var band := lp - lp2
		var syll := pow(absf(sin(TAU * 3.3 * t + sin(TAU * 0.9 * t))), 2.0)
		var env := sin(PI * t / 1.8)
		b[i] = band * 2.4 * syll * env
	return b


static func _phone() -> PackedFloat32Array:
	var b := _buf(3.0)
	for i in b.size():
		var t := float(i) / RATE
		var on := 1.0 if fmod(t, 1.5) < 0.9 and fmod(t, 0.1) < 0.05 else 0.0
		b[i] = on * 0.3 * (sin(TAU * 440.0 * t) + sin(TAU * 480.0 * t))
	return b


static func _slam() -> PackedFloat32Array:
	var b := _thump(0.7, 70.0)
	var r := _rng(5)
	for i in mini(b.size(), int(0.08 * RATE)):
		var t := float(i) / RATE
		b[i] += r.randf_range(-1.0, 1.0) * 0.6 * exp(-t * 60.0)
	return b


static func _heartbeat() -> PackedFloat32Array:
	var b := _buf(0.9)
	for i in b.size():
		var t := float(i) / RATE
		var beat1 := sin(TAU * 55.0 * t) * exp(-t * 18.0)
		var t2 := maxf(0.0, t - 0.24)
		var beat2 := 0.7 * sin(TAU * 50.0 * t2) * exp(-t2 * 18.0) if t >= 0.24 else 0.0
		b[i] = 0.9 * (beat1 + beat2)
	return b


static func _jet() -> PackedFloat32Array:
	var b := _buf(1.5)
	var r := _rng(17)
	var lp := 0.0
	var hp := 0.0
	var a := _lp_coef(1400.0)
	var ah := _lp_coef(120.0)
	for i in b.size():
		var t := float(i) / RATE
		lp += a * (r.randf_range(-1.0, 1.0) - lp)
		hp += ah * (lp - hp)
		b[i] = (lp - hp) * 1.8 * (0.85 + 0.15 * sin(TAU * 11.0 * t))
	return _seamless(b, 0.25)


static func _gulp() -> PackedFloat32Array:
	var b := _buf(0.7)
	for i in b.size():
		var t := float(i) / RATE
		var k := fmod(t, 0.22) / 0.22
		var f := 260.0 - 140.0 * k
		b[i] = 0.5 * sin(TAU * f * t) * sin(PI * k) * exp(-t * 2.0)
	return b


static func _chime(freqs: Array, seconds: float) -> PackedFloat32Array:
	var b := _buf(seconds)
	for i in b.size():
		var t := float(i) / RATE
		var s := 0.0
		for k in freqs.size():
			var start := 0.06 * float(k)
			if t >= start:
				s += 0.3 * sin(TAU * float(freqs[k]) * (t - start)) * exp(-(t - start) * 4.5)
		b[i] = s
	return b


static func _lift() -> PackedFloat32Array:
	var b := _buf(2.0)
	var r := _rng(29)
	var lp := 0.0
	var a := _lp_coef(600.0)
	for i in b.size():
		var t := float(i) / RATE
		lp += a * (r.randf_range(-1.0, 1.0) - lp)
		b[i] = 0.25 * sin(TAU * 50.0 * t) + 0.12 * sin(TAU * 100.0 * t) + lp * 0.5
	return _seamless(b, 0.2)


static func _tile() -> PackedFloat32Array:
	var b := _buf(0.6)
	var r := _rng(31)
	var lp := 0.0
	var a := _lp_coef(1800.0)
	for i in b.size():
		var t := float(i) / RATE
		lp += a * (r.randf_range(-1.0, 1.0) - lp)
		var rattle := 1.0 + 0.6 * sin(TAU * 31.0 * t)
		b[i] = lp * 1.4 * exp(-t * 9.0) * rattle + 0.4 * sin(TAU * 120.0 * t) * exp(-t * 20.0)
	return b


static func _growl() -> PackedFloat32Array:
	var b := _buf(1.6)
	var r := _rng(37)
	var lp := 0.0
	var a := _lp_coef(700.0)
	var phase := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var f := 78.0 + 25.0 * sin(TAU * 2.0 * t) + r.randf_range(-6.0, 6.0)
		phase += f / RATE
		var saw := 2.0 * (phase - floorf(phase)) - 1.0
		lp += a * (saw + r.randf_range(-0.5, 0.5) - lp)
		var env := sin(PI * minf(t / 1.6, 1.0)) * (0.7 + 0.3 * sin(TAU * 9.0 * t))
		b[i] = lp * 1.4 * env
	return b


static func _scrape() -> PackedFloat32Array:
	var b := _buf(1.0)
	var r := _rng(43)
	var lp := 0.0
	var hp := 0.0
	var a := _lp_coef(1100.0)
	var ah := _lp_coef(250.0)
	for i in b.size():
		var t := float(i) / RATE
		lp += a * (r.randf_range(-1.0, 1.0) - lp)
		hp += ah * (lp - hp)
		b[i] = (lp - hp) * 1.6 * (0.7 + 0.3 * sin(TAU * 17.0 * t))
	return _seamless(b, 0.15)


static func _click(pitch: float = 1.0) -> PackedFloat32Array:
	var b := _buf(0.08)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = 0.5 * sin(TAU * 2200.0 * pitch * t) * exp(-t * 90.0)
	return b


# --- Level 2 --------------------------------------------------------------------------------------

## A plinky party tune played at half speed through a blown speaker, looping forever.
static func _jukebox() -> PackedFloat32Array:
	var notes := [262.0, 330.0, 392.0, 330.0, 440.0, 392.0, 330.0, 294.0, 262.0, 262.0, 392.0, 330.0, 294.0, 294.0, 330.0, 262.0]
	var step := 0.5  # seconds per note: half speed
	var b := _buf(step * float(notes.size()))
	var r := _rng(77)
	var lp := 0.0
	var a := _lp_coef(1800.0)
	for i in b.size():
		var t := float(i) / RATE
		var k := int(t / step) % notes.size()
		var u := fmod(t, step) / step
		var f: float = notes[k] * (1.0 + 0.004 * sin(TAU * 5.5 * t))  # warped record wobble
		var tone := 0.35 * sin(TAU * f * t) + 0.18 * sin(TAU * f * 2.0 * t) + 0.08 * signf(sin(TAU * f * 0.5 * t))
		var env := minf(1.0, u * 25.0) * exp(-u * 2.2)
		var bass := 0.2 * sin(TAU * f * 0.25 * t) * (0.5 + 0.5 * sin(TAU * 2.0 * t / step))
		lp += a * (tone * env + bass + r.randf_range(-0.03, 0.03) - lp)
		b[i] = lp * 0.9
	return b


## A servo winding up: the Step is coming.
static func _servo() -> PackedFloat32Array:
	var b := _buf(1.6)
	var phase := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var u := t / 1.6
		var f := 200.0 + 600.0 * u * u
		phase += f / RATE
		var saw := 2.0 * (phase - floorf(phase)) - 1.0
		var env := sin(PI * minf(u * 1.1, 1.0))
		b[i] = (0.25 * saw + 0.2 * sin(TAU * phase) + 0.1 * sin(TAU * phase * 3.01)) * env
	return b


## Corrugated steel rolling on its drum.
static func _shutter() -> PackedFloat32Array:
	var b := _buf(0.9)
	var r := _rng(83)
	var lp := 0.0
	var a := _lp_coef(900.0)
	for i in b.size():
		var t := float(i) / RATE
		lp += a * (r.randf_range(-1.0, 1.0) - lp)
		var rattle := 0.6 + 0.4 * sin(TAU * 27.0 * t)
		var env := sin(PI * minf(t / 0.9, 1.0))
		b[i] = (lp * 1.5 * rattle + 0.2 * sin(TAU * 90.0 * t)) * env + 0.4 * sin(TAU * 60.0 * t) * exp(-maxf(0.0, t - 0.8) * 30.0) * step_f(t, 0.8)
	return b


static func step_f(t: float, at: float) -> float:
	return 1.0 if t >= at else 0.0


static func _klaxon() -> PackedFloat32Array:
	var b := _buf(1.2)
	for i in b.size():
		var t := float(i) / RATE
		var on := 1.0 if fmod(t, 0.4) < 0.25 else 0.0
		var f := 520.0 + 40.0 * sin(TAU * 8.0 * t)
		b[i] = on * 0.4 * (signf(sin(TAU * f * t)) * 0.5 + sin(TAU * f * 1.5 * t) * 0.5)
	return b


static func _static() -> PackedFloat32Array:
	var b := _buf(1.0)
	var r := _rng(91)
	var hp := 0.0
	var ah := _lp_coef(300.0)
	for i in b.size():
		var n := r.randf_range(-1.0, 1.0)
		hp += ah * (n - hp)
		var t := float(i) / RATE
		b[i] = (n - hp) * 0.5 * (0.7 + 0.3 * sin(TAU * 50.0 * t))
	return _seamless(b, 0.1)


static func _popper() -> PackedFloat32Array:
	var b := _buf(0.7)
	var r := _rng(97)
	var lp := 0.0
	var a := _lp_coef(3500.0)
	for i in b.size():
		var t := float(i) / RATE
		lp += a * (r.randf_range(-1.0, 1.0) - lp)
		var pop := lp * 1.8 * exp(-t * 30.0)
		var streamer := 0.12 * sin(TAU * (1500.0 - 900.0 * t) * t) * exp(-t * 4.0) * step_f(t, 0.05)
		b[i] = pop + streamer
	return b


static func _airhorn() -> PackedFloat32Array:
	var b := _buf(1.4)
	for i in b.size():
		var t := float(i) / RATE
		var env := minf(1.0, t * 40.0) * (1.0 if t < 1.1 else exp(-(t - 1.1) * 25.0))
		var s := 0.0
		for f: float in [392.0, 494.0, 587.0]:
			var ph := TAU * f * t
			s += 0.14 * (sin(ph) + 0.5 * sin(ph * 2.0) + 0.3 * sin(ph * 3.0) + 0.15 * signf(sin(ph)))
		b[i] = s * env
	return b


## The birthday song, sung slow and wrong by a dying animatronic band.
static func _birthday() -> PackedFloat32Array:
	var notes := [262.0, 262.0, 294.0, 262.0, 349.0, 330.0, 262.0, 262.0, 294.0, 262.0, 392.0, 349.0]
	var lens := [0.5, 0.25, 0.75, 0.75, 0.75, 1.5, 0.5, 0.25, 0.75, 0.75, 0.75, 1.5]
	var total := 0.0
	for l in lens:
		total += float(l)
	var b := _buf(total + 0.3)
	var r := _rng(101)
	var lp := 0.0
	var a := _lp_coef(1200.0)
	for i in b.size():
		var t := float(i) / RATE
		var acc := 0.0
		var k := 0
		while k < notes.size() - 1 and t >= acc + float(lens[k]):
			acc += float(lens[k])
			k += 1
		var u := (t - acc) / float(lens[k])
		var slow := 1.0 - 0.06 * (t / total)  # the pitch sags as the batteries die
		var f: float = notes[k] * 0.5 * slow * (1.0 + 0.01 * sin(TAU * 4.0 * t))
		var voice := 0.3 * sin(TAU * f * t) + 0.2 * sin(TAU * f * 2.0 * t) + 0.1 * sin(TAU * f * 3.0 * t)
		var env := minf(1.0, u * 12.0) * (1.0 if u < 0.85 else exp(-(u - 0.85) * 20.0))
		lp += a * (voice * env + r.randf_range(-0.04, 0.04) - lp)
		b[i] = lp
	return b


## The Launcher's tell: a wet throat tearing upward into a shriek, 0.7 s, then it jumps.
static func _screech() -> PackedFloat32Array:
	var b := _buf(0.75)
	var r := _rng(107)
	var phase := 0.0
	var lp := 0.0
	var a := _lp_coef(3200.0)
	for i in b.size():
		var t := float(i) / RATE
		var u := t / 0.75
		var f := 420.0 + 2200.0 * u * u + 60.0 * sin(TAU * 31.0 * t)
		phase += f / RATE
		var saw := 2.0 * (phase - floorf(phase)) - 1.0
		var grit := r.randf_range(-1.0, 1.0) * (0.5 - 0.3 * u)
		var env := minf(1.0, t * 30.0) * (1.0 if u < 0.85 else exp(-(u - 0.85) * 40.0))
		lp += a * ((saw * 0.6 + grit * 0.5 + 0.2 * sin(TAU * f * 0.5 * t)) - lp)
		b[i] = lp * env * 1.1
	return b


## A fist the size of a ham on corrugated steel.
static func _bang() -> PackedFloat32Array:
	var b := _thump(0.8, 48.0)
	var r := _rng(103)
	for i in b.size():
		var t := float(i) / RATE
		var ring := 0.3 * sin(TAU * 310.0 * t) * exp(-t * 6.0) + 0.15 * sin(TAU * 470.0 * t) * exp(-t * 9.0)
		b[i] = b[i] * 1.2 + ring + r.randf_range(-0.6, 0.6) * exp(-t * 40.0)
	return b


# --- Screams ---------------------------------------------------------------------------------------

## One resonant band-pass (RBJ, constant peak gain) for vowel formants. state: x1, x2, y1, y2.
static func _bandpass(x: float, f: float, q: float, state: PackedFloat32Array, k: int) -> float:
	var w0 := TAU * clampf(f, 40.0, float(RATE) * 0.45) / float(RATE)
	var alpha := sin(w0) / (2.0 * q)
	var a0 := 1.0 + alpha
	var y := (alpha * x - alpha * state[k + 1] + 2.0 * cos(w0) * state[k + 2] - (1.0 - alpha) * state[k + 3]) / a0
	state[k + 1] = state[k]
	state[k] = x
	state[k + 3] = state[k + 2]
	state[k + 2] = y
	return y


static func _normalize(b: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var m := 0.0001
	for v in b:
		m = maxf(m, absf(v))
	for i in b.size():
		b[i] = b[i] / m * peak
	return b


## The Hire's scream: not one voice but a throatful. Six ragged voices that never agree on a pitch
## (each wanders on its own), every one tearing into a sub-octave rasp (period doubling: the sound of
## a throat giving way), more breath than tone, through a dark open throat and a harsh high band,
## with a ring-modulated edge no person makes and a low roar under its first half, then a small dead
## room's echo. No vibrato, no vowel slide, no crack: those made the old one sound like a cartoon.
static func _scream() -> PackedFloat32Array:
	var dur := 1.9
	var tail := 0.6
	var b := _buf(dur + tail)
	var r := _rng(613)
	var ratios: Array[float] = [1.0, 1.013, 0.987, 1.026, 0.974, 0.5]
	var amps: Array[float] = [0.5, 0.42, 0.42, 0.3, 0.3, 0.55]
	var ph: Array[float] = [0.0, 0.17, 0.41, 0.63, 0.82, 0.29]
	var drift: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	var st := PackedFloat32Array()
	st.resize(24)
	var breath := 0.0
	var roar_ph := 0.0
	var rasp_ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var u := minf(t / dur, 1.0)
		var on := 1.0 if t < dur else 0.0
		# Jumps up hard, strains a little higher, then sags as it runs out of air.
		var f0 := 300.0 + 190.0 * smoothstep(0.0, 0.05, u) + 45.0 * smoothstep(0.05, 0.5, u) - 170.0 * smoothstep(0.55, 1.0, u)
		var src := 0.0
		for v in ratios.size():
			drift[v] += (r.randf_range(-1.0, 1.0) - drift[v]) * 0.0025
			var f := f0 * ratios[v] * (1.0 + 0.05 * drift[v])
			ph[v] = fposmod(ph[v] + f / RATE, 2.0)  # two cycles, so the sub-octave rasp can alternate
			var saw := 2.0 * fposmod(ph[v], 1.0) - 1.0
			var tear := 1.0 + 0.55 * signf(1.0 - ph[v])  # every other cycle louder: period doubling
			src += saw * tear * amps[v]
		breath += 0.45 * (r.randf_range(-1.0, 1.0) - breath)
		src = src * 0.55 + breath * 1.3
		# Roughness: the throat flutters at a ragged 60-90 Hz.
		rasp_ph = fposmod(rasp_ph + r.randf_range(60.0, 90.0) / RATE, 1.0)
		src *= 0.7 + 0.3 * sin(TAU * rasp_ph)
		var out := _bandpass(src, 640.0, 3.0, st, 0) * 1.0
		out += _bandpass(src, 1150.0, 4.0, st, 4) * 0.55
		out += _bandpass(src, 3200.0, 5.0, st, 8) * 0.95
		out += _bandpass(src, 4500.0, 6.0, st, 12) * 0.5
		out += out * sin(TAU * 1270.0 * t) * 0.3  # the metallic edge
		# A low roar under the first half gives it a body behind the throat.
		roar_ph = fposmod(roar_ph + (82.0 + r.randf_range(-4.0, 4.0)) / RATE, 1.0)
		var roar := _bandpass(2.0 * roar_ph - 1.0 + breath * 0.6, 260.0, 1.2, st, 16) * (1.0 - smoothstep(0.2, 0.6, u)) * 1.4
		var env := minf(1.0, t * 80.0) * (1.0 - smoothstep(0.78, 1.0, u)) * on
		b[i] = tanh((out + roar) * 3.2 * env)
	var roomed := _room(b, 0.32)
	for i in roomed.size():
		roomed[i] = tanh(roomed[i] * 1.8)  # squeeze the echo's peaks so the scream itself stays loud
	return _normalize(roomed, 0.95)


## A small dead room round a sound: four feedback combs (Schroeder), mixed in at wet. One flat
## buffer for all four lines: writing into a PackedFloat32Array held in an Array copies it each time.
static func _room(b: PackedFloat32Array, wet: float) -> PackedFloat32Array:
	var delays: Array[int] = [int(0.0297 * RATE), int(0.0371 * RATE), int(0.0411 * RATE), int(0.0437 * RATE)]
	var starts: Array[int] = []
	var total := 0
	for d in delays:
		starts.append(total)
		total += d
	var lines := PackedFloat32Array()
	lines.resize(total)
	var idx: Array[int] = [0, 0, 0, 0]
	var out := PackedFloat32Array()
	out.resize(b.size())
	for i in b.size():
		var x := b[i]
		var verb := 0.0
		for k in 4:
			var at: int = starts[k] + idx[k]
			var y := lines[at]
			lines[at] = x + y * 0.72
			idx[k] = (idx[k] + 1) % delays[k]
			verb += y
		out[i] = x * (1.0 - wet) + verb * 0.5 * wet
	return out


## A roar right on you: two deep rasping voices, a rattle in the throat, heavy distortion.
static func _roar() -> PackedFloat32Array:
	var dur := 1.3
	var b := _buf(dur)
	var r := _rng(617)
	var ph := PackedFloat32Array([0.0, 0.5])
	var st := PackedFloat32Array()
	st.resize(8)
	var n := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var u := t / dur
		var f0 := 95.0 + 40.0 * smoothstep(0.0, 0.2, u) - 30.0 * u + r.randf_range(-6.0, 6.0)
		ph[0] += f0 / RATE
		ph[1] += f0 * 1.51 / RATE
		var src := (2.0 * (ph[0] - floorf(ph[0])) - 1.0) * 0.7 + (2.0 * (ph[1] - floorf(ph[1])) - 1.0) * 0.4
		n += 0.5 * (r.randf_range(-1.0, 1.0) - n)
		src += n * 0.9 * (0.6 + 0.4 * sin(TAU * 27.0 * t))  # the rattle
		var out := _bandpass(src, 420.0, 3.0, st, 0) + _bandpass(src, 1050.0, 4.0, st, 4) * 0.6
		var env := minf(1.0, t * 25.0) * (1.0 if u < 0.7 else maxf(0.0, 1.0 - (u - 0.7) / 0.3))
		b[i] = tanh(out * 3.5) * env
	return _normalize(b, 0.95)


# --- Monster voices --------------------------------------------------------------------------------
# Every monster has its own throat. The Hire chokes and shrieks like the person it used to be
# ("scream", "roar" for the bite), the Custodian hisses and whistles through its teeth, Pappy's
# voice chip laughs and wails in broken electronics, the Jumper and the swarm stridulate and click.

## Plays one tick of a decaying click into a running value (for click trains).
static func _decay(v: float, per_second: float) -> float:
	return v * exp(-per_second / float(RATE))


## The Hire's wet, choking gurgle: vocal fry through an "uh" throat, with bubbles in it. Its
## noticing, its stun, its sweep: a person drowning in their own shirt collar.
static func _hire_gurgle() -> PackedFloat32Array:
	var dur := 1.6
	var b := _buf(dur)
	var r := _rng(701)
	var st := PackedFloat32Array()
	st.resize(16)
	var next_pulse := 0.0
	var exc := 0.0
	var bubble_t := 0.0
	var bubble_f := 400.0
	var lp := 0.0
	var k_lp := _lp_coef(3500.0)
	for i in b.size():
		var t := float(i) / RATE
		var u := t / dur
		# Vocal fry: irregular glottal clicks, quickening as the throat strains.
		if t >= next_pulse:
			exc = 1.0
			next_pulse = t + 1.0 / r.randf_range(35.0 + 30.0 * u, 60.0 + 45.0 * u)
		exc = _decay(exc, 1400.0)
		var src := exc + r.randf_range(-0.12, 0.12)
		var voice := _bandpass(src, 520.0 + 90.0 * sin(TAU * 1.3 * t), 4.0, st, 0) * 1.3
		voice += _bandpass(src, 1050.0, 6.0, st, 4) * 0.7
		voice += _bandpass(src, 2500.0, 9.0, st, 8) * 0.3
		# Bubbles: short bursts of narrow noise at random pitches.
		if bubble_t <= 0.0 and r.randf() < 0.0007:
			bubble_t = r.randf_range(0.012, 0.045)
			bubble_f = r.randf_range(250.0, 900.0)
		var bub := 0.0
		if bubble_t > 0.0:
			bubble_t -= 1.0 / RATE
			bub = _bandpass(r.randf_range(-1.0, 1.0), bubble_f, 12.0, st, 12) * 4.0
		lp += k_lp * (voice + bub - lp)
		var env := smoothstep(0.0, 0.12, u) * (1.0 - smoothstep(0.75, 1.0, u)) * (0.7 + 0.3 * sin(TAU * 2.2 * t))
		b[i] = tanh(lp * 2.2) * env
	return _normalize(b, 0.9)


## The Custodian's hiss: breath forced through teeth, rattling, with the wet clicks of a jaw. It
## comes out of the ceiling tiles before the arm does.
static func _cust_hiss() -> PackedFloat32Array:
	var dur := 1.5
	var b := _buf(dur)
	var r := _rng(709)
	var st := PackedFloat32Array()
	st.resize(12)
	var rattle := 0.0
	var click := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var u := t / dur
		var n := r.randf_range(-1.0, 1.0)
		var hiss := _bandpass(n, 4200.0 - 1400.0 * u, 2.5, st, 0) + _bandpass(n, 7000.0, 3.0, st, 4) * 0.5
		rattle += r.randf_range(16.0, 27.0) / RATE
		var shake := 0.45 + 0.55 * absf(sin(PI * rattle))
		if r.randf() < 0.0009:
			click = 1.0
		click = _decay(click, 260.0)
		var clk := _bandpass(click * r.randf_range(-1.0, 1.0), 1800.0, 5.0, st, 8) * 3.0
		var env := smoothstep(0.0, 0.25, u) * (1.0 - smoothstep(0.7, 1.0, u))
		b[i] = tanh((hiss * shake * 1.8 + clk) * 1.5) * env
	return _normalize(b, 0.85)


## The Custodian's shriek when it takes you: a whistle through clenched teeth with a sick fast
## vibrato, a second whistle beating against it, breath tearing underneath.
static func _cust_shriek() -> PackedFloat32Array:
	var dur := 1.5
	var b := _buf(dur)
	var r := _rng(719)
	var st := PackedFloat32Array()
	st.resize(8)
	var p0 := 0.0
	var p1 := 0.0
	var p2 := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var u := t / dur
		var f := 1700.0 + 900.0 * smoothstep(0.0, 0.08, u) - 1100.0 * smoothstep(0.55, 1.0, u)
		f += 160.0 * sin(TAU * 31.0 * t)
		p0 = fposmod(p0 + f / RATE, 1.0)
		p1 = fposmod(p1 + f * 1.07 / RATE, 1.0)
		p2 = fposmod(p2 + f * 0.5 / RATE, 1.0)
		var tone := sin(TAU * p0) + 0.7 * sin(TAU * p1) + 0.4 * (2.0 * p2 - 1.0)
		var n := r.randf_range(-1.0, 1.0)
		var breath := _bandpass(n, f * 1.5, 3.0, st, 0) * 1.6 + _bandpass(n, 900.0, 2.0, st, 4) * 0.8 * (1.0 - u)
		var env := minf(1.0, t * 60.0) * (1.0 - smoothstep(0.7, 1.0, u))
		b[i] = tanh((tone * 0.6 + breath) * 2.4) * env
	return _normalize(b, 0.93)


## Pappy's laugh: his speaker's "ha, ha, ha", each one slower and lower, like a toy whose
## batteries are dying; crushed to a few bits, held at a low sample rate, buzzing with mains hum.
static func _pappy_laugh() -> PackedFloat32Array:
	var dur := 2.4
	var b := _buf(dur)
	var r := _rng(727)
	var st := PackedFloat32Array()
	st.resize(12)
	var starts: Array[float] = [0.0, 0.27, 0.56, 0.9, 1.3, 1.78]
	var ph := 0.0
	var held := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var u := t / dur
		var gate := 0.0
		var s := 0.0
		for k in starts.size():
			var span := 0.18 + 0.05 * float(k)
			if t >= starts[k] and t < starts[k] + span:
				s = (t - starts[k]) / span
				gate = smoothstep(0.0, 0.08, s) * (1.0 - smoothstep(0.55, 1.0, s))
		var f0 := lerpf(240.0, 92.0, u) * (1.0 - 0.15 * s) * (1.0 + 0.03 * sin(TAU * 5.0 * t))
		ph = fposmod(ph + f0 / RATE, 1.0)
		var src := (1.0 if ph < 0.28 else -0.4) * gate
		src += r.randf_range(-1.0, 1.0) * gate * (1.0 - smoothstep(0.0, 0.3, s)) * 0.8  # the "h"
		var voice := _bandpass(src, 760.0, 5.0, st, 0) + _bandpass(src, 1220.0, 6.0, st, 4) * 0.8
		voice += _bandpass(src, 2600.0, 8.0, st, 8) * 0.4
		voice += 0.04 * (sin(TAU * 60.0 * t) + 0.5 * sin(TAU * 180.0 * t))  # the mains buzz
		if i % 3 == 0:
			held = roundf(tanh(voice * 2.5) * 7.0) / 7.0  # 3-bit-ish, 7 kHz: a cheap chip
		b[i] = held * (1.0 - smoothstep(0.92, 1.0, u))
	return _normalize(b, 0.85)


## Pappy's scream: the voice chip pushed past its limits. A rising wail ring-modulated into metal,
## the speaker clipping and dropping out, a servo shrieking underneath.
static func _pappy_scream() -> PackedFloat32Array:
	var dur := 1.6
	var b := _buf(dur)
	var r := _rng(733)
	var st := PackedFloat32Array()
	st.resize(12)
	var ph := 0.0
	var ring := 0.0
	var servo := 0.0
	var held := 0.0
	var drop := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var u := t / dur
		var f0 := 280.0 + 470.0 * smoothstep(0.0, 0.15, u) + 70.0 * sin(TAU * 9.0 * t) - 260.0 * smoothstep(0.7, 1.0, u)
		ph = fposmod(ph + f0 / RATE, 1.0)
		ring = fposmod(ring + 173.0 / RATE, 1.0)
		var saw := 2.0 * ph - 1.0
		var src := saw * 0.6 + saw * sin(TAU * ring) * 0.8
		var voice := _bandpass(src, 900.0, 4.0, st, 0) + _bandpass(src, 1400.0, 5.0, st, 4) * 0.8
		voice += _bandpass(src, 2800.0, 7.0, st, 8) * 0.5
		servo = fposmod(servo + lerpf(900.0, 2600.0, u) / RATE, 1.0)
		voice += sin(TAU * servo) * 0.22
		if drop <= 0.0 and r.randf() < 0.0004:
			drop = r.randf_range(0.01, 0.03)  # the speaker cutting out
		var gate := 1.0
		if drop > 0.0:
			drop -= 1.0 / RATE
			gate = 0.0
		if i % 2 == 0:
			held = roundf(tanh(voice * 3.0) * 11.0) / 11.0
		b[i] = held * gate * minf(1.0, t * 50.0) * (1.0 - smoothstep(0.8, 1.0, u))
	return _normalize(b, 0.95)


## The Jumper's hiss: stridulation, a dry comb of clicks quickening into a buzz, a hiss of air
## through its spiracles and a low thrum in the body under it.
static func _spider_hiss() -> PackedFloat32Array:
	var dur := 1.3
	var b := _buf(dur)
	var r := _rng(739)
	var st := PackedFloat32Array()
	st.resize(12)
	var next_click := 0.0
	var click := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var u := t / dur
		if t >= next_click:
			click = 1.0
			next_click = t + 1.0 / r.randf_range(40.0 + 80.0 * u, 60.0 + 110.0 * u)
		click = _decay(click, 900.0)
		var n := r.randf_range(-1.0, 1.0)
		var comb := _bandpass(n * click, 3500.0, 4.0, st, 0) * 2.5 + _bandpass(n * click, 6500.0, 5.0, st, 4) * 1.5
		var air := _bandpass(n, 5200.0, 1.5, st, 8) * 0.35 * smoothstep(0.0, 0.6, u)
		var thrum := sin(TAU * 68.0 * t) * 0.35 * click
		var env := smoothstep(0.0, 0.1, u) * (1.0 - smoothstep(0.75, 1.0, u))
		b[i] = tanh((comb + air + thrum) * 1.8) * env
	return _normalize(b, 0.85)


## The Jumper's shriek when it pins you: a thud, then a chattering scream of mouthparts that climbs
## out of hearing, two thin whistles bending against each other.
static func _spider_shriek() -> PackedFloat32Array:
	var dur := 1.4
	var b := _buf(dur)
	var r := _rng(743)
	var st := PackedFloat32Array()
	st.resize(8)
	var w0 := 0.0
	var w1 := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var u := t / dur
		var chatter := 0.5 + 0.5 * signf(sin(TAU * (26.0 + 14.0 * u) * t))
		var n := r.randf_range(-1.0, 1.0)
		var mouth := _bandpass(n, lerpf(2500.0, 5800.0, u), 3.0, st, 0) * chatter * 1.8
		var fm := 260.0 * sin(TAU * 40.0 * t)
		w0 = fposmod(w0 + (3100.0 + 900.0 * u + fm) / RATE, 1.0)
		w1 = fposmod(w1 + (3350.0 + 700.0 * u - fm) / RATE, 1.0)
		var whistle := (sin(TAU * w0) + sin(TAU * w1)) * 0.35
		var thud := sin(TAU * 58.0 * t) * exp(-t * 18.0) * 1.6
		var env := minf(1.0, t * 80.0) * (1.0 - smoothstep(0.65, 1.0, u))
		b[i] = tanh((mouth + whistle) * 2.0 * env + thud)
	return _normalize(b, 0.93)


## The swarm's chitter: a burst of dry clicks in uneven clusters.
static func _roach_chitter() -> PackedFloat32Array:
	var dur := 0.55
	var b := _buf(dur)
	var r := _rng(751)
	var st := PackedFloat32Array()
	st.resize(8)
	var next_click := 0.0
	var click := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var u := t / dur
		if t >= next_click:
			click = r.randf_range(0.5, 1.0)
			next_click = t + (r.randf_range(0.006, 0.014) if r.randf() < 0.8 else r.randf_range(0.03, 0.06))
		click = _decay(click, 1100.0)
		var n := r.randf_range(-1.0, 1.0) * click
		var out := _bandpass(n, 2800.0, 4.0, st, 0) * 2.0 + _bandpass(n, 5200.0, 5.0, st, 4) * 1.4
		b[i] = tanh(out * 1.6) * (1.0 - smoothstep(0.6, 1.0, u))
	return _normalize(b, 0.8)


## The chase: what you hear while something is hunting you. A sub pulse beating like a pounding
## heart, two low saws grinding a semitone apart, a high cluster trembling, a tick counting
## you down. Loops seamlessly (every period divides 4 s; it is rendered twice and the second,
## warmed-up pass is kept so the filter has no seam). Each monster plays it at its own pitch.
static func _chase() -> PackedFloat32Array:
	var loop := 4.0
	var full := _buf(loop * 2.0)
	var lp := 0.0
	var k_lp := _lp_coef(420.0)
	var r := _rng(757)
	var st := PackedFloat32Array()
	st.resize(4)
	for i in full.size():
		var t := float(i) / RATE
		var tl := fposmod(t, loop)
		var beat := fposmod(tl, 0.5)
		var pulse := exp(-beat * 9.0) + 0.6 * exp(-maxf(0.0, beat - 0.14) * 11.0) * (1.0 if beat >= 0.14 else 0.0)
		var sub := sin(TAU * 41.0 * tl) * pulse
		var saws := (2.0 * fposmod(55.0 * tl, 1.0) - 1.0) + (2.0 * fposmod(58.25 * tl, 1.0) - 1.0)
		lp += k_lp * (saws - lp)
		var trem := 0.5 + 0.5 * sin(TAU * 8.0 * tl)
		var cluster := (sin(TAU * 880.0 * tl) + sin(TAU * 932.25 * tl) + 0.7 * sin(TAU * 1244.5 * tl)) * trem
		var tick_t := fposmod(tl, 0.25)
		var tick := _bandpass(r.randf_range(-1.0, 1.0) * exp(-tick_t * 300.0), 2200.0, 6.0, st, 0)
		full[i] = tanh(sub * 0.9 + lp * 0.35 * (0.6 + 0.4 * pulse) + cluster * 0.06 + tick * 0.8)
	var b := _buf(loop)
	for i in b.size():
		b[i] = full[b.size() + i]
	return _normalize(b, 0.8)


## Out of breath: ragged in-out panting through the mouth, a voice catching on the out-breath,
## 1.6 breaths a second. Loops (seamless); its volume follows the stamina left.
static func _pant() -> PackedFloat32Array:
	var dur := 2.5
	var b := _buf(dur + 0.3)
	var r := _rng(761)
	var st := PackedFloat32Array()
	st.resize(12)
	var period := dur / 4.0
	var ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var c := fposmod(t, period) / period
		var n := r.randf_range(-1.0, 1.0)
		# In through the teeth: short, high, quieter. Out through the mouth: longer, lower, louder.
		var inhale := smoothstep(0.0, 0.08, c) * (1.0 - smoothstep(0.28, 0.36, c))
		var exhale := smoothstep(0.42, 0.5, c) * (1.0 - smoothstep(0.78, 0.97, c))
		var jitter := 0.85 + 0.3 * r.randf()
		var air := _bandpass(n, 2100.0, 2.0, st, 0) * inhale * 0.55
		air += (_bandpass(n, 950.0, 1.6, st, 4) + _bandpass(n, 1600.0, 3.0, st, 8) * 0.5) * exhale
		ph = fposmod(ph + (118.0 + 10.0 * c) / RATE, 1.0)
		var voice := (2.0 * ph - 1.0) * exhale * 0.08 * smoothstep(0.45, 0.6, c)
		b[i] = tanh((air * jitter + voice) * 1.8)
	return _normalize(_seamless(b, 0.3), 0.8)


# --- Level 3 --------------------------------------------------------------------------------------

## Night wind over the roofs: low rushing noise that swells and drops in slow gusts, with a thin
## whistle riding the strongest of them. Loops (seamless).
static func _wind() -> PackedFloat32Array:
	var b := _buf(9.0)
	var r := _rng(211)
	var lp := 0.0
	var lp2 := 0.0
	var bp := 0.0
	var bp2 := 0.0
	var a := _lp_coef(320.0)
	var aw := _lp_coef(1100.0)
	var aw2 := _lp_coef(700.0)
	for i in b.size():
		var t := float(i) / RATE
		var n := r.randf_range(-1.0, 1.0)
		lp += a * (n - lp)
		lp2 += a * (lp - lp2)
		bp += aw * (n - bp)
		bp2 += aw2 * (bp - bp2)
		var gust := 0.55 + 0.3 * sin(TAU * t / 9.0) + 0.15 * sin(TAU * t / 3.0 + 1.3)
		var whistle := (bp - bp2) * maxf(0.0, gust - 0.7) * 2.2
		b[i] = lp2 * 3.2 * gust + whistle
	return _seamless(b, 0.8)


## Something with a lot of legs moving fast inside sheet metal: a scatter of tiny hard ticks that
## bunches up and thins out over a second and a half, over the duct ringing faintly.
static func _skitter() -> PackedFloat32Array:
	var b := _buf(1.5)
	var r := _rng(223)
	for k in 70:
		var at := r.randf() * 1.35
		at *= 0.6 + 0.4 * sin(at * 7.0) * sin(at * 7.0)  # bunched, not even
		var start := int(at * RATE)
		var f := r.randf_range(2600.0, 5200.0)
		var amp := r.randf_range(0.15, 0.45) * sin(PI * minf(at / 1.35, 1.0))
		for j in int(0.012 * RATE):
			var idx := start + j
			if idx >= b.size():
				break
			var t := float(j) / RATE
			b[idx] += amp * (sin(TAU * f * t) * 0.6 + r.randf_range(-0.5, 0.5)) * exp(-t * 520.0)
	for i in b.size():
		var t := float(i) / RATE
		b[i] += 0.04 * sin(TAU * 610.0 * t) * sin(PI * t / 1.5) * (0.5 + 0.5 * sin(TAU * 23.0 * t))
	return b


# --- Level 4: the manor grounds -----------------------------------------------------------------

## A tired old pump engine ticking over: a two-stroke putt nine times a second, a knock every
## fourth, the exhaust a rasp of noise under it. Loops (18 putts in the 2 s, so it joins clean).
static func _engine() -> PackedFloat32Array:
	var b := _buf(2.0)
	var r := _rng(71)
	var lp := 0.0
	var a := _lp_coef(900.0)
	var rate := 9.0
	for i in b.size():
		var t := float(i) / RATE
		var ph := fmod(t * rate, 1.0)
		var pulse := exp(-ph * 9.0)
		lp += a * (r.randf_range(-1.0, 1.0) - lp)
		var knock := 0.0
		if fmod(t * rate, 4.0) < 1.0:
			knock = 0.25 * exp(-ph * 14.0) * sin(TAU * 140.0 * t)
		b[i] = pulse * (0.45 * sin(TAU * 55.0 * t) + lp * 0.8) + 0.08 * sin(TAU * 27.5 * t) + knock
	return _seamless(b, 0.2)


## A funeral bell, deep and slow to die: a bell's out-of-tune partials (hum, prime, minor third,
## fifth, octave and the rest), each fading at its own rate, a metallic strike on top.
static func _toll() -> PackedFloat32Array:
	var b := _buf(6.0)
	var partials := [[0.5, 0.5, 0.6], [1.0, 0.45, 0.9], [1.19, 0.3, 1.2], [1.5, 0.22, 1.5], [2.0, 0.2, 1.9], [2.51, 0.14, 2.6], [2.66, 0.12, 2.9], [3.01, 0.08, 3.5]]
	var f0 := 98.0
	for i in b.size():
		var t := float(i) / RATE
		var v := 0.0
		for pt in partials:
			v += float(pt[1]) * sin(TAU * f0 * float(pt[0]) * t + 0.3 * float(pt[0])) * exp(-t * float(pt[2]) * 0.45)
		var strike := exp(-t * 40.0) * 0.3 * sin(TAU * 1800.0 * t)
		b[i] = (v + strike) * 0.55
	return b


## An iron gate grinding open on hinges nobody has oiled in decades: a scraping rumble with a
## squeal riding on it, wavering.
static func _gate() -> PackedFloat32Array:
	var b := _buf(3.2)
	var r := _rng(73)
	var lp := 0.0
	var a := _lp_coef(400.0)
	var ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += a * (r.randf_range(-1.0, 1.0) - lp)
		var f := 180.0 + 60.0 * sin(t * 2.3) + 25.0 * sin(t * 13.0)
		ph += TAU * f / RATE
		var squeal := sin(ph) * (0.5 + 0.5 * sin(t * 7.0)) * 0.25
		var env := minf(1.0, t * 4.0) * minf(1.0, (3.2 - t) * 3.0)
		b[i] = (lp * 1.2 + squeal + 0.15 * sin(TAU * 45.0 * t)) * env
	return b
