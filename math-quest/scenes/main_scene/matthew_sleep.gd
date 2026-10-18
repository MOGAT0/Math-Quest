extends Area2D

signal is_chapterDone(chapter : String)
signal wokeUp

@onready var matthew_sleeping: Sprite2D = %matthew_sleeping
#@onready var indicator: Sprite2D = %indicator
@onready var key_label: Label = %key_label
@onready var letter: Letter = %Letter
@onready var transition_fx: TransitionFX = %TransitionFx

var active_player: CharacterBody2D = null
var is_sleeping: bool = false
var wake_timer: Timer
var wait_time : float = 5.0
## Bedtime: after 12:00 noon, and after midnight until WAKE_HOUR (4 AM).
## Daytime, from WAKE_HOUR up to and including 12:00, is blocked. Waking
## up sets the clock to WAKE_HOUR.
const BEDTIME_AFTER := 12.0
const WAKE_HOUR := 4.0
const TOO_EARLY := "It's still daytime... I can only sleep after 12 noon."
const MORNING_SCHOOL := "A fresh new day to learn new things! I should hurry and go to school."
const MORNING_FESTIVAL := "A fresh new day! There is a festival today. Let's go and have fun!"
## Calendar day when Matthew lay down, and whether midnight had already
## passed (then this night's date change has happened: don't do it again)
var _sleep_day : int = 0
var _after_midnight : bool = false

func _ready() -> void:
	key_label.hide()
	var check_status = db.query("SELECT is_done FROM checklist WHERE chapter = home_sleep_1")
	if check_status.data[0].is_done:
		is_chapterDone.emit("home_sleep_1")
		
	matthew_sleeping.hide()

	wake_timer = Timer.new()
	wake_timer.wait_time = wait_time
	wake_timer.one_shot = true
	wake_timer.timeout.connect(wake_up)
	add_child(wake_timer)

func _unhandled_input(event: InputEvent) -> void:
	if active_player and event.is_action_pressed("interact"):
		if !is_sleeping:
			if can_sleep_now():
				go_to_sleep()
			else:
				_too_early_popup()

func go_to_sleep() -> void:
	MusicPlayer.stop()
	MusicPlayer.one_shot_stream = preload("res://assets/audio/dreaming.mp3")
	MusicPlayer.set_one_shot_volume_db(-20)
	MusicPlayer.one_shot = true
	transition_fx.allow_time_extend = true
	transition_fx.extend_time = (wait_time - 1)
	transition_fx.transition = true
	
	#indicator.hide()
	_remember_bedtime()
	is_sleeping = true
	matthew_sleeping.show()
	active_player.hide()

	active_player.set_physics_process(false) 
	wake_timer.start()
	

func wake_up() -> void:
	if not is_sleeping:
		return
	transition_fx.allow_time_extend = false
	if _should_advance_date():
		CalendarManager.next_day()
	wokeUp.emit()
	GameManager.current_time = 4
	is_sleeping = false
	matthew_sleeping.hide()
	active_player.show()
	
	active_player.set_physics_process(true)
	wake_timer.stop()
	
	var check_status = db.query("SELECT is_done FROM checklist WHERE chapter = home_sleep_1")
	if !check_status.data[0].is_done:
		await get_tree().create_timer(0.5).timeout
		letter.open_letter()
	
	await get_tree().process_frame
	is_chapterDone.emit("home_sleep_1")
	GameManager.refill_stamina(100.0)
	MusicPlayer.one_shot = false
	MusicPlayer.one_shot_stream = preload("res://assets/audio/dialogue.mp3")
	MusicPlayer.set_one_shot_volume_db(0)
	MusicPlayer._play_current()
	_morning_line()

## Matthew says what the day is for, after the first morning's letter
## is closed.
func _morning_line() -> void:
	# Kept here: active_player is cleared when he walks out of the area
	var player := active_player as Player
	if player == null:
		return
	while letter.visible:
		await letter.visibility_changed
	await get_tree().create_timer(0.6).timeout
	if is_sleeping or not is_instance_valid(player):
		return
	if CalendarManager.is_school_day():
		player.say(MORNING_SCHOOL)
	else:
		player.say(MORNING_FESTIVAL)

## No sleeping in the daytime (4:00 up to and including 12:00), so the date
## can't be skipped by sleeping again and again. The story's first sleep and the time before
## the clock runs are never blocked.
func can_sleep_now() -> bool:
	if not GameManager.game_time_enabled:
		return true
	var first_sleep = db.query("SELECT is_done FROM checklist WHERE chapter = home_sleep_1")
	if typeof(first_sleep) == TYPE_DICTIONARY and typeof(first_sleep.get("data")) == TYPE_ARRAY 			and not first_sleep.data.is_empty() and not first_sleep.data[0].is_done:
		return true
	var t := GameManager.current_time
	return t > BEDTIME_AFTER or t < WAKE_HOUR


func _too_early_popup() -> void:
	var world := get_tree().current_scene
	if world and world.has_method("show_popup_alert"):
		world.show_popup_alert(2.5, TOO_EARLY)
	else:
		EventDirector._toast_show(TOO_EARLY)


func _remember_bedtime() -> void:
	_sleep_day = CalendarManager.absolute_day()
	_after_midnight = GameManager.game_time_enabled and GameManager.current_time < WAKE_HOUR


## One date change per night: not when midnight had already passed before
## he went to bed, nor when the clock rolled the date while he slept.
func _should_advance_date() -> bool:
	return not _after_midnight and CalendarManager.absolute_day() == _sleep_day


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		#indicator.show()
		if OS.get_name().to_lower() not in ["android", "ios"]:
			key_label.show()
		active_player = body

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		#indicator.hide()
		key_label.hide()
		if is_sleeping:
			wake_up()
		active_player = null
