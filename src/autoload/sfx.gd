extends Node
## ASH&LEAD -- procedural audio.
##
## The game ships no audio files: every gunshot, door, siren, footstep, scream and
## the synthwave score are synthesised into AudioStreamWAV buffers at start-up.
## That keeps the project self-contained and lets the mix react to gameplay
## (suppressed shots, distance filtering, indoor reverb).

const RATE := 22050
const MAX_VOICES := 48
const MAX_MUSIC_VOICES := 2

var banks: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var voice_next := 0
var music_player: AudioStreamPlayer
var ambience_player: AudioStreamPlayer
var music_tracks: Dictionary = {}
var current_music := ""
var rng := RandomNumberGenerator.new()
var listener_pos := Vector2.ZERO
var _built := false
var bus_sfx := "SFX"
var bus_music := "Music"


func _ready() -> void:
	rng.seed = 1337
	_ensure_buses()
	for i in range(MAX_VOICES):
		var p := AudioStreamPlayer.new()
		p.bus = bus_sfx
		p.volume_db = -80.0
		add_child(p)
		voices.append(p)
	music_player = AudioStreamPlayer.new()
	music_player.bus = bus_music
	music_player.volume_db = -12.0
	add_child(music_player)
	ambience_player = AudioStreamPlayer.new()
	ambience_player.bus = bus_sfx
	ambience_player.volume_db = -18.0
	add_child(ambience_player)
	# build in a deferred call so the first frame is not blocked
	call_deferred("build_banks")


func _ensure_buses() -> void:
	var idx := AudioServer.get_bus_index(bus_sfx)
	if idx == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_sfx)
	idx = AudioServer.get_bus_index(bus_music)
	if idx == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_music)
	var sfx_idx := AudioServer.get_bus_index(bus_sfx)
	if sfx_idx != -1 and AudioServer.get_bus_effect_count(sfx_idx) == 0:
		var comp := AudioEffectHardLimiter.new()
		comp.ceiling_db = -1.0
		AudioServer.add_bus_effect(sfx_idx, comp)


# ---------------------------------------------------------------------------
# SYNTHESIS HELPERS
# ---------------------------------------------------------------------------

func _wav(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in range(samples.size()):
		var v := clampf(samples[i], -1.0, 1.0)
		var iv := int(v * 32000.0)
		bytes.encode_s16(i * 2, iv)
	s.data = bytes
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = samples.size()
	return s


func _buf(seconds: float) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(int(RATE * seconds))
	a.fill(0.0)
	return a


func _noise(seconds: float) -> PackedFloat32Array:
	var a := _buf(seconds)
	for i in range(a.size()):
		a[i] = rng.randf_range(-1.0, 1.0)
	return a


func _env(a: PackedFloat32Array, attack: float, decay: float, curve: float = 3.0) -> PackedFloat32Array:
	var n := a.size()
	var atk: int = maxi(1, int(attack * RATE))
	var dec: int = maxi(1, int(decay * RATE))
	for i in range(n):
		var e := 1.0
		if i < atk:
			e = float(i) / float(atk)
		elif i > atk:
			e = pow(max(0.0, 1.0 - float(i - atk) / float(dec)), curve)
		a[i] *= e
	return a


func _lowpass(a: PackedFloat32Array, cutoff: float) -> PackedFloat32Array:
	# one-pole low-pass
	var dt := 1.0 / float(RATE)
	var rc := 1.0 / (TAU * cutoff)
	var alpha := dt / (rc + dt)
	var y := 0.0
	var out := PackedFloat32Array()
	out.resize(a.size())
	for i in range(a.size()):
		y = y + alpha * (a[i] - y)
		out[i] = y
	return out


func _highpass(a: PackedFloat32Array, cutoff: float) -> PackedFloat32Array:
	var dt := 1.0 / float(RATE)
	var rc := 1.0 / (TAU * cutoff)
	var alpha := rc / (rc + dt)
	var prev_in := 0.0
	var prev_out := 0.0
	var out := PackedFloat32Array()
	out.resize(a.size())
	for i in range(a.size()):
		var x := a[i]
		prev_out = alpha * (prev_out + x - prev_in)
		prev_in = x
		out[i] = prev_out
	return out


func _mix(a: PackedFloat32Array, b: PackedFloat32Array, gain_b: float = 1.0) -> PackedFloat32Array:
	var n: int = maxi(a.size(), b.size())
	var out := PackedFloat32Array()
	out.resize(n)
	for i in range(n):
		var va := a[i] if i < a.size() else 0.0
		var vb := b[i] if i < b.size() else 0.0
		out[i] = va + vb * gain_b
	return out


func _gain(a: PackedFloat32Array, g: float) -> PackedFloat32Array:
	for i in range(a.size()):
		a[i] *= g
	return a


func _tone(freq: float, seconds: float, kind: String = "sine", sweep: float = 0.0) -> PackedFloat32Array:
	var a := _buf(seconds)
	var phase := 0.0
	for i in range(a.size()):
		var t := float(i) / float(RATE)
		var f := freq + sweep * t
		phase += TAU * f / float(RATE)
		var v := 0.0
		match kind:
			"sine":
				v = sin(phase)
			"square":
				v = 1.0 if sin(phase) > 0.0 else -1.0
			"saw":
				v = fmod(phase / PI, 2.0) - 1.0
			"triangle":
				v = abs(fmod(phase / PI, 2.0) - 1.0) * 2.0 - 1.0
		a[i] = v
	return a


func _gunshot(base_freq: float, noise_gain: float, body_seconds: float, punch: float) -> PackedFloat32Array:
	var n := _noise(body_seconds)
	n = _lowpass(n, base_freq * 2.2)
	n = _env(n, 0.001, body_seconds * 0.85, 2.2)
	var crack := _noise(0.06)
	crack = _highpass(crack, 2600.0)
	crack = _env(crack, 0.0005, 0.05, 3.0)
	var thump := _tone(84.0, body_seconds, "sine", -40.0)
	thump = _env(thump, 0.002, body_seconds * 0.6, 2.6)
	var out := _mix(n, crack, 0.55 * noise_gain)
	out = _mix(out, thump, punch)
	out = _gain(out, 0.9)
	return out


func _suppressed_shot() -> PackedFloat32Array:
	var n := _noise(0.19)
	n = _lowpass(n, 900.0)
	n = _env(n, 0.002, 0.17, 2.4)
	var click := _noise(0.02)
	click = _highpass(click, 3200.0)
	click = _env(click, 0.0002, 0.015, 3.0)
	var out := _mix(n, click, 0.7)
	var mech := _tone(1800.0, 0.03, "square", -2200.0)
	mech = _env(mech, 0.001, 0.02, 2.0)
	return _mix(out, mech, 0.12)


func _step_sound(heavy: bool) -> PackedFloat32Array:
	var n := _noise(0.09 if not heavy else 0.14)
	n = _lowpass(n, 420.0 if heavy else 700.0)
	n = _env(n, 0.002, 0.08 if not heavy else 0.12, 2.6)
	var thump := _tone(70.0, 0.08, "sine", -60.0)
	thump = _env(thump, 0.003, 0.07, 2.0)
	return _mix(n, thump, 0.35)


func _splash_sound() -> PackedFloat32Array:
	var n := _noise(0.22)
	n = _highpass(n, 900.0)
	n = _lowpass(n, 5200.0)
	n = _env(n, 0.004, 0.2, 2.0)
	return _gain(n, 0.6)


func _reload_sound() -> PackedFloat32Array:
	var out := _buf(0.1)
	var click := _noise(0.02)
	click = _highpass(click, 2400.0)
	click = _env(click, 0.0005, 0.018, 2.5)
	var click2 := _noise(0.03)
	click2 = _highpass(click2, 1500.0)
	click2 = _env(click2, 0.001, 0.028, 2.2)
	out = _mix(out, click, 1.0)
	out = _mix(out, click2, 0.8)
	var slide := _tone(420.0, 0.07, "square", 600.0)
	slide = _env(slide, 0.002, 0.06, 2.0)
	return _mix(out, slide, 0.12)


func _door_sound(locked: bool) -> PackedFloat32Array:
	if locked:
		var out := _buf(0.25)
		for i in range(3):
			var knock := _noise(0.04)
			knock = _lowpass(knock, 600.0)
			knock = _env(knock, 0.001, 0.035, 2.0)
			out = _mix(out, knock, 0.9)
		return out
	var creak := _tone(120.0, 0.5, "saw", 90.0)
	creak = _lowpass(creak, 800.0)
	creak = _env(creak, 0.02, 0.45, 1.6)
	var n := _noise(0.4)
	n = _lowpass(n, 1200.0)
	n = _env(n, 0.03, 0.35, 2.0)
	return _mix(creak, n, 0.35)


func _explosion_sound() -> PackedFloat32Array:
	var n := _noise(1.3)
	n = _lowpass(n, 900.0)
	n = _env(n, 0.002, 1.1, 1.8)
	var boom := _tone(46.0, 1.0, "sine", -20.0)
	boom = _env(boom, 0.005, 0.9, 2.0)
	var debris := _noise(0.5)
	debris = _highpass(debris, 1800.0)
	debris = _env(debris, 0.05, 0.45, 2.4)
	var out := _mix(n, boom, 1.4)
	return _mix(out, debris, 0.5)


func _siren_sound(seconds: float, loop: bool) -> PackedFloat32Array:
	var a := _buf(seconds)
	for i in range(a.size()):
		var t := float(i) / float(RATE)
		var f := 700.0 + sin(t * TAU * 0.45) * 260.0
		var v := sin(TAU * f * t) * 0.5 + sin(TAU * f * 2.0 * t) * 0.12
		a[i] = v * 0.5
	if loop:
		# wrap-safe crossfade at the boundary
		for i in range(200):
			var k := float(i) / 200.0
			a[i] *= k
			a[a.size() - 1 - i] *= k
	return a


func _scream_sound(pitch: float) -> PackedFloat32Array:
	var dur := 0.75
	var a := _buf(dur)
	var phase := 0.0
	for i in range(a.size()):
		var t := float(i) / float(RATE)
		var f := (180.0 + 260.0 * sin(t * 3.0)) * pitch
		phase += TAU * f / float(RATE)
		var v := sin(phase) * 0.5 + sin(phase * 2.0) * 0.2 + sin(phase * 3.0) * 0.1
		a[i] = v * (1.0 - t / dur) * 0.7
	a = _lowpass(a, 2400.0)
	return a


func _alarm_sound() -> PackedFloat32Array:
	var dur := 1.6
	var a := _buf(dur)
	for i in range(a.size()):
		var t := float(i) / float(RATE)
		var f := 880.0 if fmod(t, 0.8) < 0.4 else 660.0
		a[i] = sin(TAU * f * t) * 0.4 + sin(TAU * f * 1.5 * t) * 0.12
	a = _env(a, 0.05, dur * 0.9, 1.2)
	return a


func _ui_sound(kind: String) -> PackedFloat32Array:
	match kind:
		"hover":
			var a := _tone(1240.0, 0.05, "sine", -300.0)
			return _env(a, 0.001, 0.04, 2.0)
		"click":
			var b := _tone(760.0, 0.09, "triangle", 180.0)
			var n := _noise(0.03)
			n = _env(n, 0.001, 0.025, 2.0)
			return _mix(_env(b, 0.002, 0.08, 2.0), n, 0.4)
		"back":
			var c := _tone(520.0, 0.12, "triangle", -300.0)
			return _env(c, 0.002, 0.1, 2.2)
		"buy":
			var d := _tone(420.0, 0.24, "square", 600.0)
			d = _lowpass(d, 2400.0)
			var e := _tone(880.0, 0.2, "sine", 0.0)
			return _mix(_env(d, 0.003, 0.2, 2.0), _env(e, 0.003, 0.16, 2.0), 0.25)
		"kill":
			var f := _tone(220.0, 0.3, "saw", -120.0)
			f = _lowpass(f, 1200.0)
			var g := _tone(660.0, 0.22, "sine", -300.0)
			return _mix(_env(f, 0.004, 0.26, 2.0), _env(g, 0.004, 0.2, 2.0), 0.3)
		"objective":
			var h := _tone(330.0, 0.4, "triangle", 0.0)
			var h2 := _tone(495.0, 0.4, "triangle", 0.0)
			return _mix(_env(h, 0.01, 0.35, 1.5), _env(h2, 0.02, 0.3, 1.6), 0.5)
		"alarm":
			return _alarm_sound()
		"deny":
			var i2 := _tone(160.0, 0.2, "square", -40.0)
			return _env(i2, 0.002, 0.16, 2.0)
	return _tone(440.0, 0.05)


func _punch_sound() -> PackedFloat32Array:
	var n := _noise(0.12)
	n = _lowpass(n, 500.0)
	n = _env(n, 0.002, 0.1, 2.4)
	var body := _tone(90.0, 0.14, "sine", -40.0)
	body = _env(body, 0.002, 0.12, 2.0)
	return _mix(n, body, 0.6)


func _knife_sound() -> PackedFloat32Array:
	var swish := _noise(0.18)
	swish = _highpass(swish, 2200.0)
	swish = _lowpass(swish, 7000.0)
	swish = _env(swish, 0.02, 0.14, 2.0)
	return _gain(swish, 0.7)


func _heartbeat_sound() -> PackedFloat32Array:
	var a := _tone(52.0, 0.5, "sine", -18.0)
	a = _env(a, 0.01, 0.45, 1.5)
	var b := _tone(48.0, 0.3, "sine", -14.0)
	b = _env(b, 0.01, 0.26, 1.6)
	var out := _mix(a, b, 0.6)
	return out


func _drill_sound() -> PackedFloat32Array:
	var dur := 0.4
	var a := _buf(dur)
	for i in range(a.size()):
		var t := float(i) / float(RATE)
		a[i] = sin(TAU * 140.0 * t) * 0.4 + sin(TAU * 283.0 * t) * 0.3
	var n := _noise(dur)
	n = _lowpass(n, 3200.0)
	a = _mix(a, n, 0.35)
	return _env(a, 0.01, dur * 0.9, 1.0)


func _pickup_sound() -> PackedFloat32Array:
	var a := _tone(520.0, 0.12, "triangle", 420.0)
	var b := _tone(1040.0, 0.1, "sine", 300.0)
	return _mix(_env(a, 0.002, 0.1, 2.0), _env(b, 0.004, 0.08, 2.0), 0.3)


func _taser_sound() -> PackedFloat32Array:
	var dur := 0.5
	var a := _buf(dur)
	for i in range(a.size()):
		var t := float(i) / float(RATE)
		var gate := 1.0 if sin(t * TAU * 24.0) > 0.2 else 0.15
		a[i] = (rng.randf_range(-1, 1) * 0.5 + sin(TAU * 120.0 * t) * 0.3) * gate
	a = _highpass(a, 800.0)
	return _env(a, 0.002, 0.45, 1.6)


func _flash_sound() -> PackedFloat32Array:
	var n := _noise(0.9)
	n = _highpass(n, 2000.0)
	n = _env(n, 0.001, 0.8, 2.0)
	var ring := _tone(3200.0, 1.6, "sine", -200.0)
	ring = _env(ring, 0.005, 1.5, 1.2)
	return _mix(n, ring, 0.05)


func _fire_sound() -> PackedFloat32Array:
	var dur := 1.2
	var n := _noise(dur)
	n = _lowpass(n, 1400.0)
	n = _env(n, 0.1, 1.0, 1.5)
	var crackle := _noise(dur)
	crackle = _highpass(crackle, 3000.0)
	for i in range(crackle.size()):
		if rng.randf() < 0.02:
			crackle[i] *= 3.0
	return _mix(n, crackle, 0.25)


# ---------------------------------------------------------------------------
# BANKS
# ---------------------------------------------------------------------------

func build_banks() -> void:
	if _built:
		return
	_built = true
	banks["shot_pistol"] = _wav(_gunshot(1200.0, 0.8, 0.24, 0.7))
	banks["shot_heavy_pistol"] = _wav(_gunshot(900.0, 1.0, 0.34, 0.95))
	banks["shot_smg"] = _wav(_gunshot(1500.0, 0.85, 0.2, 0.6))
	banks["shot_rifle"] = _wav(_gunshot(900.0, 1.1, 0.32, 0.9))
	banks["shot_heavy_rifle"] = _wav(_gunshot(700.0, 1.2, 0.42, 1.1))
	banks["shot_lmg"] = _wav(_gunshot(650.0, 1.2, 0.36, 1.0))
	banks["shot_shotgun"] = _wav(_gunshot(520.0, 1.3, 0.5, 1.2))
	banks["shot_sniper"] = _wav(_gunshot(620.0, 1.2, 0.6, 1.15))
	banks["shot_suppressed"] = _wav(_suppressed_shot())
	banks["shot_taser"] = _wav(_taser_sound())
	banks["shot_flash"] = _wav(_flash_sound())
	banks["explosion"] = _wav(_explosion_sound())
	banks["step_soft"] = _wav(_step_sound(false))
	banks["step_heavy"] = _wav(_step_sound(true))
	banks["splash"] = _wav(_splash_sound())
	banks["reload"] = _wav(_reload_sound())
	banks["door_open"] = _wav(_door_sound(false))
	banks["door_locked"] = _wav(_door_sound(true))
	banks["siren"] = _wav(_siren_sound(3.2, true), true)
	banks["alarm"] = _wav(_alarm_sound())
	banks["scream_1"] = _wav(_scream_sound(1.0))
	banks["scream_2"] = _wav(_scream_sound(1.25))
	banks["scream_3"] = _wav(_scream_sound(0.82))
	banks["heartbeat"] = _wav(_heartbeat_sound())
	banks["drill"] = _wav(_drill_sound(), true)
	banks["punch"] = _wav(_punch_sound())
	banks["knife"] = _wav(_knife_sound())
	banks["pickup"] = _wav(_pickup_sound())
	banks["fire"] = _wav(_fire_sound(), true)
	banks["ui_hover"] = _wav(_ui_sound("hover"))
	banks["ui_click"] = _wav(_ui_sound("click"))
	banks["ui_back"] = _wav(_ui_sound("back"))
	banks["ui_buy"] = _wav(_ui_sound("buy"))
	banks["ui_kill"] = _wav(_ui_sound("kill"))
	banks["ui_objective"] = _wav(_ui_sound("objective"))
	banks["ui_deny"] = _wav(_ui_sound("deny"))
	banks["flesh"] = _wav(_punch_sound())
	_build_music()
	_build_ambience()


func _build_music() -> void:
	# Three minimal dark-synth loops; the mode picks one.
	music_tracks["menu"] = _synth_loop(8.0, [55.0, 82.4, 110.0, 98.0], 0.55)
	music_tracks["heist"] = _synth_loop(8.0, [48.9, 73.4, 98.0, 87.3], 0.75)
	music_tracks["arcade"] = _synth_loop(4.0, [65.4, 98.0, 130.8, 98.0], 0.9)
	music_tracks["tension"] = _synth_loop(6.0, [43.6, 43.6, 65.4, 51.9], 0.35)
	for k in music_tracks:
		music_tracks[k] = _wav(music_tracks[k], true)


func _synth_loop(seconds: float, roots: Array, drive: float) -> PackedFloat32Array:
	var a := _buf(seconds)
	var bars := roots.size()
	var bar_len := seconds / float(bars)
	for i in range(a.size()):
		var t := float(i) / float(RATE)
		var bar := int(t / bar_len) % bars
		var local := t - float(int(t / bar_len)) * bar_len
		var root: float = roots[bar]
		# bass pulse on the eighth notes
		var eighth := bar_len / 4.0
		var pulse := 1.0 if fmod(local, eighth) < eighth * 0.42 else 0.0
		var bass := sin(TAU * root * t) * 0.35 * pulse
		bass += sin(TAU * root * 0.5 * t) * 0.2 * pulse
		# pad chord (root, minor third, fifth) swelling
		var swell := 0.5 + 0.5 * sin(TAU * local / bar_len)
		var pad := (sin(TAU * root * 2.0 * t) + sin(TAU * root * 2.378 * t) + sin(TAU * root * 2.996 * t)) * 0.045 * swell
		# tick / percussion
		var tick := 0.0
		if fmod(local, eighth) < 0.012:
			tick = (rng.randf_range(-1, 1)) * 0.12 * (1.0 - fmod(local, eighth) / 0.012)
		# sub drone for heist tension
		var drone := sin(TAU * 27.5 * t) * 0.06
		a[i] = (bass + pad + tick) * drive + drone
	a = _lowpass(a, 3400.0)
	# gentle master curve
	for i in range(a.size()):
		a[i] = tanh(a[i] * 1.4) * 0.8
	return a


func _build_ambience() -> void:
	var dur := 6.0
	var a := _buf(dur)
	for i in range(a.size()):
		var t := float(i) / float(RATE)
		var v := sin(TAU * 38.0 * t) * 0.12
		v += sin(TAU * 57.0 * t + sin(t * 0.7)) * 0.06
		a[i] = v
	a = _lowpass(a, 400.0)
	# rain hiss
	var n := _noise(dur)
	n = _highpass(n, 1200.0)
	n = _lowpass(n, 6000.0)
	a = _mix(a, n, 0.18)
	# crossfade loop edges
	for i in range(400):
		var k := float(i) / 400.0
		a[i] *= k
		a[a.size() - 1 - i] *= k
	ambience_player.stream = _wav(a, true)


# ---------------------------------------------------------------------------
# PLAYBACK
# ---------------------------------------------------------------------------

func play(sound: String, volume_db: float = 0.0, pitch: float = 1.0, pos: Vector2 = Vector2(-1, -1)) -> void:
	if not banks.has(sound):
		return
	var stream: AudioStream = banks[sound]
	var p := voices[voice_next]
	voice_next = (voice_next + 1) % voices.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = clampf(pitch, 0.4, 2.4)
	# virtual distance attenuation so distant fights sound distant
	if pos != Vector2(-1, -1):
		var d := listener_pos.distance_to(pos)
		p.volume_db -= clampf(d / 260.0, 0.0, 22.0)
		if d > 2600.0:
			return
	p.play()


func play_at(sound: String, pos: Vector2, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	play(sound, volume_db, pitch, pos)


func play_ui(sound: String) -> void:
	play(sound, -8.0, 1.0)


func play_music(track: String, fade: float = 1.2) -> void:
	if current_music == track or not music_tracks.has(track):
		return
	current_music = track
	var tween := create_tween()
	if music_player.playing:
		tween.tween_property(music_player, "volume_db", -40.0, fade * 0.5)
		tween.tween_callback(func() -> void:
			music_player.stream = music_tracks[track]
			music_player.play())
		tween.tween_property(music_player, "volume_db", -12.0, fade * 0.5)
	else:
		music_player.stream = music_tracks[track]
		music_player.volume_db = -40.0
		music_player.play()
		tween.tween_property(music_player, "volume_db", -12.0, fade)


func stop_music(fade: float = 0.8) -> void:
	current_music = ""
	var tween := create_tween()
	tween.tween_property(music_player, "volume_db", -50.0, fade)
	tween.tween_callback(music_player.stop)


func start_ambience() -> void:
	if ambience_player.stream != null and not ambience_player.playing:
		ambience_player.play()


func stop_ambience() -> void:
	ambience_player.stop()


func gunshot(weapon_id: String, pos: Vector2, suppressed: bool = false) -> void:
	var w: Dictionary = Db.WEAPONS.get(weapon_id, {})
	var kind := str(w.get("kind", "pistol"))
	var sound := "shot_pistol"
	match kind:
		"smg":
			sound = "shot_smg"
		"rifle":
			sound = "shot_heavy_rifle" if float(w.get("dmg", 30)) > 45.0 else "shot_rifle"
		"shotgun":
			sound = "shot_shotgun"
		"sniper":
			sound = "shot_sniper"
		"lmg":
			sound = "shot_lmg"
		"special":
			sound = "shot_heavy_pistol"
		"melee":
			sound = "knife" if weapon_id == "knife" else "punch"
		"throw":
			sound = "knife"
	if suppressed:
		sound = "shot_suppressed" if kind != "melee" and kind != "throw" else sound
	var vol := 0.0
	if kind == "pistol" or kind == "smg":
		vol = -4.0
	elif kind == "melee" or kind == "throw":
		vol = -10.0
	play_at(sound, pos, vol, randf_range(0.94, 1.06))


func step(pos: Vector2, heavy: bool, wet: bool) -> void:
	if wet:
		play_at("splash", pos, -16.0, randf_range(0.9, 1.1))
	else:
		play_at("step_heavy" if heavy else "step_soft", pos, -19.0, randf_range(0.85, 1.15))


func scream(pos: Vector2, variant: int = -1) -> void:
	var v := variant
	if v < 0:
		v = randi_range(1, 3)
	play_at("scream_%d" % v, pos, -6.0, randf_range(0.9, 1.1))


func ui(kind: String) -> void:
	match kind:
		"hover":
			play_ui("ui_hover")
		"click":
			play_ui("ui_click")
		"back":
			play_ui("ui_back")
		"buy":
			play_ui("ui_buy")
		"kill":
			play_ui("ui_kill")
		"objective":
			play_ui("ui_objective")
		"deny":
			play_ui("ui_deny")
		_:
			play_ui("ui_click")
