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
const NORMAL_VOLUME := 0.4

var current_index: int = 0
var _player: AudioStreamPlayer
var _one_shot_player: AudioStreamPlayer

#region major event theme songs
const ACADEMY_MAGIC_FEST = preload("uid://4cit4hagysr0")
const EASTER_HOLIDAY = preload("uid://crbnyipblldk4")
const HARVEST_FAIR = preload("uid://xddwgxjq6rfw")
const NIGHT_OF_LANTERNS = preload("uid://b7g7wdaf6jg27")
const STAR_FESTIVAL = preload("uid://c7l3kg7j7i7go")
const WINTER_SOLSTICE = preload("uid://ceujf5jltsas8")
#endregion major event theme songs

## Major event id (data/events.json) -> its theme song
const THEME_SONGS : Dictionary = {
	"academy_magic_fest": ACADEMY_MAGIC_FEST,
	"easter_holiday": EASTER_HOLIDAY,
	"harvest_fair": HARVEST_FAIR,
	"night_of_lanterns": NIGHT_OF_LANTERNS,
	"star_festival": STAR_FESTIVAL,
	"winter_solstice": WINTER_SOLSTICE,
}
## Wake-up time (same as matthew_sleep.WAKE_HOUR): an event day's theme
## starts here, whether Matthew slept or stayed up all night.
const WAKE_HOUR := 4.0

## Theme song playing (or waiting to play) instead of the playlist
var _theme: AudioStream = null
## Calendar day the theme last played, so it plays once per event day
var _theme_day: int = -1
var _last_time: float = 0.0
var _last_day: int = -1


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
	GameManager.hour_changed.connect(_on_hour_changed)


func play_playlist(new_playlist: Array[AudioStream]) -> void:
	playlist = new_playlist
	current_index = 0
	_theme = null   # a new playlist (main menu, ending) wins over a theme
	_play_current()


## Plays a major event's theme song once, then the normal playlist goes
## on where it was. False if the event has no theme song.
func play_event_theme(event_id: String) -> bool:
	var song : AudioStream = THEME_SONGS.get(event_id)
	if song == null:
		return false
	_theme = song
	_player.stream = song
	_player.play()
	return true


## At wake time on a major event day, start that event's theme. The time
## is reached by the clock running past 4:00 (stayed up) or by being set
## to 4:00 on a new day (woke up). Loading a save later in the day or
## jumping the date in the daytime doesn't count.
func _on_hour_changed(t: float) -> void:
	var today : int = CalendarManager.absolute_day()
	if _last_day == -1:
		_last_day = today
		_last_time = t
		return
	var reached : bool = t >= WAKE_HOUR and t < WAKE_HOUR + 1.0 \
		and (_last_time < WAKE_HOUR or today != _last_day)
	_last_day = today
	_last_time = t
	if not reached or _theme_day == today:
		return
	for e in CalendarManager.events_on(CalendarManager.season, CalendarManager.day):
		if play_event_theme(str(e.get("id", ""))):
			_theme_day = today
			return


func stop() -> void:
	_player.stop()


func play_one_shot(stream: AudioStream, volume_db: float = 0.0) -> void:
	_one_shot_player.volume_db = volume_db
	one_shot_stream = stream
	one_shot = true
	
func set_one_shot_volume_db(db: float) -> void:
	if _one_shot_player == null:
		return
	_one_shot_player.volume_db = db

#func set_one_shot_volume_linear(linear: float) -> void:
	#set_one_shot_volume_db(linear_to_db(linear))

func _play_current() -> void:
	# A theme song goes first (e.g. waking up resumes the music right
	# after the theme started at 4:00: don't cut it or start it over)
	if _theme:
		if _player.stream != _theme or not _player.playing:
			_player.stream = _theme
			_player.play()
		return
	if playlist.is_empty():
		return
	_player.stream = playlist[current_index]
	_player.play()


func _on_track_finished() -> void:
	if _theme:
		# Theme done: back to the playlist where it was
		_theme = null
		_play_current()
		return
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
	one_shot = false


func _apply_volume() -> void:
	if _player == null:
		return
		
	if _volume_tween and _volume_tween.is_valid():
		_volume_tween.kill()

	if tune_down:
		_player.volume_db = linear_to_db(TUNED_DOWN_VOLUME)
	else:
		var from_linear := db_to_linear(_player.volume_db)
		_volume_tween = create_tween()
		_volume_tween.tween_method(_set_music_volume, from_linear, NORMAL_VOLUME, FADE_UP_TIME)


func _set_music_volume(linear: float) -> void:
	_player.volume_db = linear_to_db(linear)
