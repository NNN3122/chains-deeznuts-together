extends Node
## Autoload "Voice": proximity voice chat with no outside service. The microphone is captured on
## a muted bus, cut to 16 kHz mono 8-bit mu-law (16 kB/s while you talk, nothing while you don't),
## sent to the host, and relayed to the other peers. Each remote voice plays from an
## AudioStreamPlayer3D glued to that player's head, so it fades with distance like every other
## sound; a wall between you and the talker muffles and quietens it (a ray from your camera).
## Needs audio/driver/enable_input in project.godot. Silent when headless or in solo.

const RATE: int = 16000  # Hz on the wire
const FRAME_SECONDS: float = 0.05  # one packet per 50 ms while talking
const MAX_DISTANCE: float = 22.0  # m: inaudible beyond this
const UNIT_SIZE: float = 5.0  # keep chained teammates intelligible
const PLAYBACK_BOOST_DB: float = 6.0
const VAD_THRESHOLD: float = 0.012  # RMS below this is silence
const VAD_HOLD: float = 0.45  # s of quiet still sent after speech (word tails)
const TALK_TIMEOUT_MS: int = 350
const WALL_CUTOFF_HZ: float = 1600.0
const WALL_VOLUME_DB: float = -5.0
const BUFFER_SECONDS: float = 0.4

var _mic: AudioStreamPlayer
var _capture: AudioEffectCapture
var _accum: PackedFloat32Array = PackedFloat32Array()
var _resample_pos: float = 0.0
var _hold_t: float = 0.0
var _voices: Dictionary = {}  # peer -> {player, playback, bus_index, low_pass}
var _talking: Dictionary = {}  # peer -> msec of their last packet
var _bus_pool: Array[int] = []
var _available: bool = false
var _reason: String = ""
var _sent_bytes: int = 0
var _received_packets: int = 0


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		_reason = "headless"
		return
	if not bool(ProjectSettings.get_setting("audio/driver/enable_input", false)):
		_reason = "audio input is disabled in project settings"
		return
	_setup_capture()


func _setup_capture() -> void:
	var idx := AudioServer.get_bus_index("VoiceRecord")
	if idx < 0:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, "VoiceRecord")
		AudioServer.set_bus_mute(idx, true)  # you never hear your own microphone
		_capture = AudioEffectCapture.new()
		_capture.buffer_length = 0.5
		AudioServer.add_bus_effect(idx, _capture)
	else:
		_capture = AudioServer.get_bus_effect(idx, 0) as AudioEffectCapture
	_mic = AudioStreamPlayer.new()
	_mic.name = "Mic"
	_mic.stream = AudioStreamMicrophone.new()
	_mic.bus = "VoiceRecord"
	add_child(_mic)
	_mic.play()
	_available = _capture != null
	if not _available:
		_reason = "no capture effect"


func available() -> bool:
	return _available


## One line for the HUD corner.
func status_text() -> String:
	if not multiplayer.has_multiplayer_peer() or Net.is_solo or Net.get_players().size() <= 1:
		return ""
	if not _available:
		return "MIC: unavailable (%s)" % _reason
	if not Settings.voice_enabled:
		return "MIC: off (Settings)"
	if is_peer_talking(multiplayer.get_unique_id()):
		return "MIC: talking"
	return "MIC: on (friends within %d m hear you)" % int(MAX_DISTANCE)


func is_peer_talking(peer: int) -> bool:
	return Time.get_ticks_msec() - int(_talking.get(peer, -100000)) < TALK_TIMEOUT_MS


func _process(delta: float) -> void:
	_position_voices()
	if not _available or not multiplayer.has_multiplayer_peer() or Net.is_solo:
		_drain_capture()
		return
	if not Settings.voice_enabled or Net.get_players().size() <= 1:
		_drain_capture()
		return
	_read_microphone(delta)


func _drain_capture() -> void:
	if _capture != null and _capture.get_frames_available() > 0:
		_capture.clear_buffer()


## Pulls what the microphone recorded since last frame, resamples it to 16 kHz mono, and sends a
## packet per 50 ms while there is speech in it.
func _read_microphone(delta: float) -> void:
	var n := _capture.get_frames_available()
	if n <= 0:
		return
	var frames := _capture.get_buffer(n)
	var ratio := AudioServer.get_mix_rate() / float(RATE)
	var i := _resample_pos
	while i < float(frames.size()):
		var f := frames[int(i)]
		_accum.append((f.x + f.y) * 0.5)
		i += ratio
	_resample_pos = i - float(frames.size())
	var per_packet := int(RATE * FRAME_SECONDS)
	while _accum.size() >= per_packet:
		var chunk := _accum.slice(0, per_packet)
		_accum = _accum.slice(per_packet)
		var rms := 0.0
		for s in chunk:
			rms += s * s
		rms = sqrt(rms / float(per_packet))
		if rms >= VAD_THRESHOLD:
			_hold_t = VAD_HOLD
		elif _hold_t > 0.0:
			_hold_t -= FRAME_SECONDS
		else:
			continue
		var bytes := _encode(chunk)
		_sent_bytes += bytes.size()
		_talking[multiplayer.get_unique_id()] = Time.get_ticks_msec()
		if multiplayer.is_server():
			_relay(multiplayer.get_unique_id(), bytes)
		else:
			_rpc_voice.rpc_id(1, bytes)


## Client -> host: a packet of my voice.
@rpc("any_peer", "call_remote", "unreliable_ordered")
func _rpc_voice(bytes: PackedByteArray) -> void:
	if not multiplayer.is_server():
		return
	_relay(multiplayer.get_remote_sender_id(), bytes)


## Host: everyone else hears it (positional on their end), and the host hears it too.
func _relay(sender: int, bytes: PackedByteArray) -> void:
	_talking[sender] = Time.get_ticks_msec()
	for peer in multiplayer.get_peers():
		if peer != sender:
			_rpc_hear.rpc_id(peer, sender, bytes)
	if sender != multiplayer.get_unique_id():
		_hear(sender, bytes)


@rpc("authority", "call_remote", "unreliable_ordered")
func _rpc_hear(sender: int, bytes: PackedByteArray) -> void:
	_hear(sender, bytes)


func _hear(sender: int, bytes: PackedByteArray) -> void:
	_received_packets += 1
	_talking[sender] = Time.get_ticks_msec()
	if not _available and DisplayServer.get_name() == "headless":
		return
	var v := _voice_for(sender)
	if v.is_empty():
		return
	var playback: AudioStreamGeneratorPlayback = v["playback"]
	if playback == null:
		return
	var samples := _decode(bytes)
	var room := playback.get_frames_available()
	var count := mini(room, samples.size())
	if count <= 0:
		return  # the buffer is full: the link is ahead of us, drop rather than lag
	var out := PackedVector2Array()
	out.resize(count)
	for i in count:
		out[i] = Vector2(samples[i], samples[i])
	playback.push_buffer(out)


## A positional player (on its own muffling bus) for a peer, made on first use.
func _voice_for(peer: int) -> Dictionary:
	if _voices.has(peer):
		return _voices[peer]
	var p := Net.find_player(peer)
	if p == null:
		return {}
	var bus_index := _take_bus(peer)
	var player := AudioStreamPlayer3D.new()
	player.name = "Voice%d" % peer
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = BUFFER_SECONDS
	player.stream = gen
	player.max_distance = MAX_DISTANCE
	player.unit_size = UNIT_SIZE
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.max_db = 24.0  # the default 3 dB ceiling would defeat the volume boost
	player.bus = AudioServer.get_bus_name(bus_index)
	player.volume_db = playback_volume_db(false)
	add_child(player)
	player.global_position = p.global_position + Vector3(0.0, 1.5, 0.0)
	player.play()
	var v := {"player": player, "playback": player.get_stream_playback(), "bus_index": bus_index,
		"low_pass": AudioServer.get_bus_effect(bus_index, 0) as AudioEffectLowPassFilter}
	_voices[peer] = v
	return v


func _take_bus(peer: int) -> int:
	if AudioServer.get_bus_index("VoicePlayback") < 0:
		AudioServer.add_bus()
		var mix := AudioServer.bus_count - 1
		AudioServer.set_bus_name(mix, "VoicePlayback")
		AudioServer.add_bus_effect(mix, AudioEffectLimiter.new())
	if not _bus_pool.is_empty():
		return _bus_pool.pop_back()
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, "Voice_%d" % peer)
	AudioServer.set_bus_send(idx, "VoicePlayback")
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = 20000.0
	AudioServer.add_bus_effect(idx, lp)
	return idx


## Every frame: each voice sits on its player's head, and a wall in between muffles it.
func _position_voices() -> void:
	if _voices.is_empty():
		return
	var cam := get_viewport().get_camera_3d()
	var space: PhysicsDirectSpaceState3D = null
	if cam != null and cam.is_inside_tree():
		space = cam.get_world_3d().direct_space_state
	for peer in _voices.keys():
		var v: Dictionary = _voices[peer]
		var player: AudioStreamPlayer3D = v["player"]
		var p := Net.find_player(peer)
		if p == null:
			_drop_voice(peer)
			continue
		var head := p.global_position + Vector3(0.0, 1.5, 0.0)
		player.global_position = head
		var muffled := false
		if cam != null and space != null:
			var q := PhysicsRayQueryParameters3D.create(cam.global_position, head, ChainBody.LAYER_WORLD)
			muffled = not space.intersect_ray(q).is_empty()
		var lp: AudioEffectLowPassFilter = v["low_pass"]
		if lp != null:
			lp.cutoff_hz = WALL_CUTOFF_HZ if muffled else 20000.0
		player.volume_db = playback_volume_db(muffled)
		player.max_distance = MAX_DISTANCE * (0.6 if muffled else 1.0)


func playback_volume_db(muffled: bool) -> float:
	if Settings.voice_volume <= 0.0:
		return -80.0
	return PLAYBACK_BOOST_DB + linear_to_db(clampf(Settings.voice_volume, 0.001, Settings.MAX_VOICE_VOLUME)) + (WALL_VOLUME_DB if muffled else 0.0)


func _drop_voice(peer: int) -> void:
	if not _voices.has(peer):
		return
	var v: Dictionary = _voices[peer]
	(v["player"] as Node).queue_free()
	_bus_pool.append(int(v["bus_index"]))
	_voices.erase(peer)
	_talking.erase(peer)


## Leaving a game drops every voice; a new game starts clean.
func reset() -> void:
	for peer in _voices.keys().duplicate():
		_drop_voice(peer)
	_talking.clear()
	_accum = PackedFloat32Array()
	_hold_t = 0.0


func stats() -> Dictionary:
	return {"sent_bytes": _sent_bytes, "received_packets": _received_packets, "voices": _voices.size()}


# --- G.711 mu-law -----------------------------------------------------------------------------------

const MU_BIAS: int = 0x84
const MU_CLIP: int = 32635


static func _encode(samples: PackedFloat32Array) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(samples.size())
	for i in samples.size():
		var s := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		var sign := 0x80 if s < 0 else 0
		if s < 0:
			s = -s
		if s > MU_CLIP:
			s = MU_CLIP
		s += MU_BIAS
		var exponent := 7
		var mask := 0x4000
		while exponent > 0 and (s & mask) == 0:
			exponent -= 1
			mask >>= 1
		var mantissa := (s >> (exponent + 3)) & 0x0F
		out[i] = (~(sign | (exponent << 4) | mantissa)) & 0xFF
	return out


static func _decode(bytes: PackedByteArray) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(bytes.size())
	for i in bytes.size():
		var u := (~int(bytes[i])) & 0xFF
		var sign := u & 0x80
		var exponent := (u >> 4) & 0x07
		var mantissa := u & 0x0F
		var s := ((mantissa << 3) + MU_BIAS) << exponent
		s -= MU_BIAS
		out[i] = float(-s if sign != 0 else s) / 32768.0
	return out
