extends Control

@onready var claw: Control = %claw
@onready var time: Label = %time

## Date tag next to the clock; tapping it opens the season calendar.
const DATE_CHIP_OFFSET := Vector2(214, 6)   # top edge, right of the clock
var _date_chip : CalendarChip

func _ready() -> void:
	GameManager.hour_changed.connect(_on_hour_changed)
	GameManager.time_state_changed.connect(_on_state_changed)
	visible = GameManager.game_time_enabled

	_date_chip = CalendarChip.new()
	_date_chip.position = position + DATE_CHIP_OFFSET
	_date_chip.visible = visible
	get_parent().add_child.call_deferred(_date_chip)

func _on_state_changed(_is_enabled : bool) -> void:
	visible = _is_enabled
	if _date_chip:
		_date_chip.visible = _is_enabled

func _on_hour_changed(_new_hour: float) -> void:
	claw.rotation_degrees = 90.0 + (GameManager.current_time / 24.0) * 180.0
	time.text = GameManager.get_formatted_time()
