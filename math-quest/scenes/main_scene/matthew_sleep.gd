extends Area2D

signal is_chapterDone(chapter : String)
signal wokeUp

@onready var matthew_sleeping: Sprite2D = %matthew_sleeping
@onready var indicator: Sprite2D = %indicator
@onready var letter: Letter = %Letter
@onready var transition_fx: TransitionFX = %TransitionFx

var active_player: Node2D = null
var is_sleeping: bool = false
var wake_timer: Timer
var wait_time : float = 5.0

func _ready() -> void:
	matthew_sleeping.hide()

	wake_timer = Timer.new()
	wake_timer.wait_time = wait_time
	wake_timer.one_shot = true
	wake_timer.timeout.connect(wake_up)
	add_child(wake_timer)

func _unhandled_input(event: InputEvent) -> void:
	if active_player and event.is_action_pressed("interact"):
		if !is_sleeping:
			go_to_sleep()

func go_to_sleep() -> void:
	transition_fx.allow_time_extend = true
	transition_fx.extend_time = (wait_time - 1)
	transition_fx.transition = true
	
	indicator.hide()
	is_sleeping = true
	matthew_sleeping.show()
	active_player.hide()

	active_player.set_physics_process(false) 
	wake_timer.start()
	

func wake_up() -> void:
	if not is_sleeping:
		return
	transition_fx.allow_time_extend = false
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
	
func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		indicator.show()
		active_player = body

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		indicator.hide()
		if is_sleeping:
			wake_up()
		active_player = null


func _on_sleep_btn_pressed() -> void:
	go_to_sleep()


func _on_sleep_btn_released() -> void:
	pass
