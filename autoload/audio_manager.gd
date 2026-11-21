extends Node
## Audio: pooled 2D sound effects, music phases, ambient beds, subtitles.
## Positional effects use a 2D bus and an AudioListener2D placed at the camera.

signal subtitle_requested(text: String, duration: float)

const SFX_POOL := 18
const SFX_DIR := "res://assets/sounds/"
const MUSIC_DIR := "res://assets/music/"

var _streams: Dictionary = {}
var _pool: Array = []
var _pool_index: int = 0
var _music_player: AudioStreamPlayer
var _music_tween: Tween
var _ambient_player: AudioStreamPlayer
var _ambient_tween: Tween
var current_music := ""


func _ready() -> void:
	for i in SFX_POOL:
		var p := AudioStreamPlayer2D.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.bus = "Ambient"
	add_child(_ambient_player)


func _stream(path: String) -> AudioStream:
	if _streams.has(path):
		return _streams[path]
	var s: AudioStream = load(path)
	if s != null:
		_streams[path] = s
	return s


## Play a sound effect. pos == Vector2.INF means "non-positional" (UI, global events).
func play(name: String, pos: Vector2 = Vector2.INF, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not SettingsManager.get_setting("sfx_enabled"):
		return
	var path := SFX_DIR + name + ".wav"
	var stream := _stream(path)
	if stream == null:
		return
	var p: AudioStreamPlayer2D = _next_player()
	p.stream = stream
	p.volume_db = volume_db + linear_to_db(clampf(SettingsManager.get_setting("volume_sfx"), 0.0001, 1.0)) * 0.5
	p.pitch_scale = clampf(pitch, 0.3, 4.0)
	if pos != Vector2.INF:
		p.global_position = pos
	else:
		p.global_position = Vector2.ZERO
	p.play()


func _next_player() -> AudioStreamPlayer2D:
	for i in _pool.size():
		var idx := (_pool_index + i) % _pool.size()
		if not _pool[idx].playing:
			_pool_index = (idx + 1) % _pool.size()
			return _pool[idx]
	var p: AudioStreamPlayer2D = _pool[_pool_index]
	_pool_index = (_pool_index + 1) % _pool.size()
	return p


func play_music(name: String, fade: float = 0.8) -> void:
	if current_music == name and _music_player.playing:
		return
	current_music = name
	var stream := _stream(MUSIC_DIR + name + ".wav")
	if stream == null:
		return
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_player.stream = stream
	_music_player.volume_db = -60.0
	_music_player.play()
	_music_tween = create_tween()
	var target := linear_to_db(clampf(SettingsManager.get_setting("volume_music"), 0.0001, 1.0))
	_music_tween.tween_property(_music_player, "volume_db", target, fade)


func stop_music(fade: float = 0.6) -> void:
	current_music = ""
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	if not _music_player.playing:
		return
	_music_tween = create_tween()
	_music_tween.tween_property(_music_player, "volume_db", -60.0, fade)
	_music_tween.tween_callback(_music_player.stop)


func play_ambient(name: String, fade: float = 1.2) -> void:
	var stream := _stream(SFX_DIR + name + ".wav")
	if stream == null:
		return
	_ambient_player.stream = stream
	_ambient_player.volume_db = -60.0
	_ambient_player.play()
	if _ambient_tween != null and _ambient_tween.is_valid():
		_ambient_tween.kill()
	_ambient_tween = create_tween()
	_ambient_tween.tween_property(_ambient_player, "volume_db",
		linear_to_db(clampf(SettingsManager.get_setting("volume_ambient"), 0.0001, 1.0)), fade)


func stop_ambient(fade: float = 0.8) -> void:
	if _ambient_tween != null and _ambient_tween.is_valid():
		_ambient_tween.kill()
	if not _ambient_player.playing:
		return
	_ambient_tween = create_tween()
	_ambient_tween.tween_property(_ambient_player, "volume_db", -60.0, fade)
	_ambient_tween.tween_callback(_ambient_player.stop)


func subtitle(text: String, duration: float = 2.5) -> void:
	if not SettingsManager.get_setting("subtitles"):
		return
	subtitle_requested.emit(text, duration)


func ui_click() -> void:
	play("ui_click", Vector2.INF, -8.0, 1.0)


func ui_hover() -> void:
	play("ui_hover", Vector2.INF, -14.0, 1.0)
