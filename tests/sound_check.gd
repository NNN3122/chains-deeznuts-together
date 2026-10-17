extends SceneTree
## Renders the scare sounds to WAV files and prints their loudness (a check you can listen to):
## -s res://tests/sound_check.gd -- --out=DIR

func _init() -> void:
	var out := OS.get_temp_dir()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	for id: String in ["scream", "roar", "hire_gurgle", "cust_hiss", "cust_shriek", "pappy_laugh", "pappy_scream", "spider_hiss", "spider_shriek", "roach_chitter", "chase", "stinger", "drone"]:
		var t0 := Time.get_ticks_msec()
		var s := Sfx.stream(id)
		var ms := Time.get_ticks_msec() - t0
		var data := s.data
		var peak := 0.0
		var sum := 0.0
		var bad := 0
		var n := data.size() / 2
		for i in n:
			var v := float(data.decode_s16(i * 2)) / 32768.0
			peak = maxf(peak, absf(v))
			sum += v * v
			if is_nan(v):
				bad += 1
		print("%s: %.2f s, peak %.2f, rms %.3f, built in %d ms, bad %d" % [id, float(n) / float(Sfx.RATE), peak, sqrt(sum / maxf(1.0, float(n))), ms, bad])
		s.save_to_wav(out.path_join(id + ".wav"))
	quit()
