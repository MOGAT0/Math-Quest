extends CharacterBody2D 
class_name Player

@export var SPEED : float = 80.0
const T_avatar_default : String = "res://assets/models/teacher/"
var current_avatar: String
@onready var fps_disp: Label = %fps

@onready var step_anim: AnimationPlayer = %step_anim

@onready var target_indicator: TargetIndicator = %target_indicator
@export var target : Marker2D
@export var side_quest_targets : Dictionary[String, Marker2D]

@onready var navigation_agent_2d: NavigationAgent2D = %NavigationAgent2D
@onready var sprite_2d: Sprite2D = %character

@onready var emerald: PanelContainer = %emerald
@onready var ruby: PanelContainer = %ruby
@onready var diamond: PanelContainer = %diamond

@onready var reward: Reward = %reward
@onready var hud: Control = %hud
@onready var crystals_cont: VBoxContainer = %crystals
@onready var currency: HBoxContainer = %currency
@onready var kp: Label = %kp

@onready var stamina_bar: ProgressBar = %stamina_bar
@onready var interact_btn: Button = %interact_btn

var is_navigating: bool = false
var joystick_direction: Vector2 = Vector2.ZERO

const AFTER_CLASS_LINE := "Class is finally over! I can't wait to go home and sleep... Should I go to the shop first? Hmmm..."

var _bubble: PlayerBubble

func _ready() -> void:
	interact_btn.hide()
	_onload_show_crystal()
	call_deferred("setup_navigation")
	#currency.hide()
	_bubble = PlayerBubble.new()
	add_child(_bubble)
	_bubble.setup(sprite_2d)

## Speech bubble over Matthew's head. seconds = how long it stays after
## the line is typed (0 = by length).
func say(text: String, seconds: float = 0.0) -> void:
	_bubble.say(text, seconds)

func show_target_indicator(value : bool) -> void:
	target_indicator.visible = value

func setup_navigation() -> void:
	navigation_agent_2d.path_desired_distance = 8.0 
	navigation_agent_2d.target_desired_distance = 8.0

func _physics_process(_delta: float) -> void:
	kp.text = str(GameManager.kp_amount)
	stamina_bar.value = GameManager.player_stamina
	
	fps_disp.text = str(Engine.get_frames_per_second())
	
	var keyboard_dir = Input.get_vector("a", "d", "w", "s")
	var input_dir = (keyboard_dir + joystick_direction).limit_length(1.0)
	
	if velocity.length() > 0.01:
		step_anim.play("step")
	else:
		step_anim.play("RESET")
	
	if !GameManager.allow_cursor_click: return
	
	if input_dir != Vector2.ZERO:
		is_navigating = false
		velocity = input_dir * SPEED
	elif is_navigating:
		path_finding()
	else:
		velocity = Vector2.ZERO

	move_and_slide()
	set_target_indicator()
	

func set_target_indicator() -> void:
	target_indicator.main_target = GameManager.target_location
	target_indicator.side_targets = GameManager.sideQuest_locations
	
func _unhandled_input(event: InputEvent) -> void:
	if !GameManager.allow_cursor_click: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		#set_movement_target(get_global_mouse_position())
		pass

func set_movement_target(target_loc: Vector2) -> void:
	navigation_agent_2d.target_position = target_loc
	is_navigating = true

func path_finding() -> void:
	if navigation_agent_2d.is_navigation_finished():
		is_navigating = false
		velocity = Vector2.ZERO
		return

	var next_path_pos = navigation_agent_2d.get_next_path_position()
	var new_velocity = global_position.direction_to(next_path_pos) * SPEED
	
	velocity = new_velocity

func _on_virtual_joystick_plus_analogic_changed(value: Vector2, _distance: float, _angle: float, _angle_clockwise: float, _angle_not_clockwise: float) -> void:
	joystick_direction = value


func _on_class_class_end(currentGrade: String, currentLesson: String) -> void:
	if currentGrade == "g1" and currentLesson == "g1-l10":
		emerald.show()
		db.query("UPDATE progress SET c1 = true WHERE is_active = true")
		reward.reward_trigger.emit("emerald")
	if currentGrade == "g2" and currentLesson == "g2-l10":
		ruby.show()
		db.query("UPDATE progress SET c2 = true WHERE is_active = true")
		reward.reward_trigger.emit("ruby")
	if currentGrade == "g3" and currentLesson == "g3-l10":
		diamond.show()
		db.query("UPDATE progress SET c3 = true WHERE is_active = true")
		reward.reward_trigger.emit("diamond")
		return   # the grade-3 cinematic plays now, no bubble

	# After the teleport to the academy gate and any crystal reward
	await get_tree().create_timer(1.2).timeout
	say(AFTER_CLASS_LINE)

func _onload_show_crystal():
	var req = db.query("SELECT c1,c2,c3 FROM progress WHERE is_active = true")
	var data = req.data[0]

	emerald.visible = data.c1
	ruby.visible = data.c2
	diamond.visible = data.c3
	
	crystals_cont.visible = !db.query("SELECT open_portal FROM progress WHERE is_active = true").data[0].open_portal


func _on_portal_portal_opened() -> void:
	crystals_cont.hide()


func _on_cutscene_player_cutscene_started() -> void:
	hud.hide()
	_bubble.hide_now()


func _on_cutscene_player_cutscene_ended() -> void:
	hud.show()



func _on_interact_btn_button_down() -> void:
	var event = InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	Input.parse_input_event(event)
	print("pressed")


func _on_interact_btn_button_up() -> void:
	var event = InputEventAction.new()
	event.action = "interact"
	event.pressed = false
	Input.parse_input_event(event)
	print("released")


func _on_indicator_visibility_area_entered(area: Area2D) -> void:
	if area.name == "matthew_sleep":
		_mobile_btn_state()
	elif area.owner is Merchant:
		_mobile_btn_state()
	elif area is EventNPC:
		_mobile_btn_state()


func _on_indicator_visibility_area_exited(area: Area2D) -> void:
	if area.name == "matthew_sleep":
		interact_btn.hide()
	elif area.owner is Merchant:
		interact_btn.hide()
	elif area is EventNPC:
		interact_btn.hide()

func _mobile_btn_state() -> void:
	#interact_btn.show() #for debug
	#return #for debug
	if OS.get_name().to_lower() in ["android", "ios"]:
		interact_btn.show()
	else:
		interact_btn.hide()
