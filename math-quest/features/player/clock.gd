extends Control

@onready var claw: Control = %claw
@onready var time: Label = %time

func _ready() -> void:
	GameManager.hour_changed.connect(_on_hour_changed)
	GameManager.time_state_changed.connect(_on_state_changed)
	visible = GameManager.game_time_enabled
	
func _on_state_changed(_is_enabled : bool) -> void:
	visible = _is_enabled
	
func _on_hour_changed(_new_hour: float) -> void:
	claw.rotation_degrees = 90.0 + (GameManager.current_time / 24.0) * 180.0
	time.text = GameManager.get_formatted_time()
