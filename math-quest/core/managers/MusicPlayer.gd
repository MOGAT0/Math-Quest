extends Node

var playlist: Array[AudioStream] = []

const FADE_UP_TIME := 1.0
var _volume_tween: Tween

var tune_down: bool = false:
	set(value):
		tune_down = value
		_apply_volume()

var one_shot_stream: AudioStream
var one_shot: bool = false:
	set(value):
		one_shot = value
		_apply_one_shot()

const TUNED_DOWN_VOLUME := 0.1
const NORMAL_VOLUME := 0.5

var current_index: int = 0
var _player: AudioStreamPlayer
var _one_shot_player: AudioStreamPlayer


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_player.finished.connect(_on_track_finished)
	_player.bus = &"Music"

	_one_shot_player = AudioStreamPlayer.new()
	add_child(_one_shot_player)
	_one_shot_player.finished.connect(_on_one_shot_finished)
	_one_shot_player.bus = &"SFX"
	_set_music_volume(NORMAL_VOLUME)
	_apply_volume()

	#play_playlist([
		#preload("uid://gxi3ibqe3cki"),
		#preload("uid://dbuw7fumbxllh"),
		#preload("uid://cecfi3ldn4pn8"),
	#])
	
	one_shot_stream = preload("res://assets/audio/dialogue.mp3")


func play_playlist(new_playlist: Array[AudioStream]) -> void:
	playlist = new_playlist
	current_index = 0
	_play_current()


func stop() -> void:
	_player.stop()


## Convenience: set the stream and start it in one call.
func play_one_shot(stream: AudioStream) -> void:
	one_shot_stream = stream
	one_shot = true


func _play_current() -> void:
	if playlist.is_empty():
		return
	_player.stream = playlist[current_index]
	_player.play()
	print("playing")


func _on_track_finished() -> void:
	if playlist.is_empty():
		return
	current_index = (current_index + 1) % playlist.size()
	_play_current()


func _apply_one_shot() -> void:
	if _one_shot_player == null:
		return
	if one_shot:
		if one_shot_stream == null:
			one_shot = false
			return
		tune_down = true 
		_one_shot_player.stream = one_shot_stream
		_one_shot_player.play()
	else:
		_one_shot_player.stop()
		tune_down = false


func _on_one_shot_finished() -> void:
	# Sound ended on its own, so reset the flag.
	one_shot = false


func _apply_volume() -> void:
	if _player == null:
		return

	# Cancel any fade that's still running
	if _volume_tween and _volume_tween.is_valid():
		_volume_tween.kill()

	if tune_down:
		# Instant drop
		_player.volume_db = linear_to_db(TUNED_DOWN_VOLUME)
	else:
		# Gradual return to normal volume
		var from_linear := db_to_linear(_player.volume_db)
		_volume_tween = create_tween()
		_volume_tween.tween_method(_set_music_volume, from_linear, NORMAL_VOLUME, FADE_UP_TIME)


func _set_music_volume(linear: float) -> void:
	_player.volume_db = linear_to_db(linear)
