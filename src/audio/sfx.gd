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
]

## Sounds that get an on-screen caption (Settings.captions), with direction worked out by the HUD.
const CAPTIONS: Dictionary = {
	"growl": "something snarls", "phone": "a phone is ringing", "whisper": "someone whispers",
	"slam": "a door slams", "tile": "a ceiling tile crashes down", "boom": "explosion",
	"shot": "gunshot", "squeak": "squeaky toy", "ding": "elevator chime",
	"servo": "servo whine, rising", "shutter": "a shutter rolls", "bell": "the counter bell rings",
	"klaxon": "overload klaxon", "popper": "party popper", "airhorn": "AIR HORN", "bang": "BANG on the shutter",
	"birthday": "the band sings, slowly",
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
		b[i] = lp2 * 2.2 * swell + 0.08 * sin(TAU * 41.0 * t) + 0.04 * sin(TAU * 61.5 * t)
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


static func _stinger() -> PackedFloat32Array:
	var b := _buf(0.9)
	var r := _rng(1337)
	var phase := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var env := 1.0 if t < 0.08 else exp(-(t - 0.08) * 5.0)
		var freq := 190.0 - 120.0 * (t / 0.9)
		phase += freq / RATE
		var saw := 2.0 * (phase - floorf(phase)) - 1.0
		var screech := sin(TAU * (1800.0 + 600.0 * sin(TAU * 13.0 * t)) * t) * 0.25
		b[i] = (saw * 0.55 + r.randf_range(-0.7, 0.7) + screech) * env
	return b


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


## A fist the size of a ham on corrugated steel.
static func _bang() -> PackedFloat32Array:
	var b := _thump(0.8, 48.0)
	var r := _rng(103)
	for i in b.size():
		var t := float(i) / RATE
		var ring := 0.3 * sin(TAU * 310.0 * t) * exp(-t * 6.0) + 0.15 * sin(TAU * 470.0 * t) * exp(-t * 9.0)
		b[i] = b[i] * 1.2 + ring + r.randf_range(-0.6, 0.6) * exp(-t * 40.0)
	return b
