@tool
extends CanvasModulate
class_name DayNightCycle

@export_group("Setting")
@export var editor_time_enabled : bool = false

@export var current_time : float = 8.0:
	set(value):
		current_time = wrapf(value, 0.0, 24.0)
		_update_color()

@export_group("Light")
@export var day_color : Color = Color(0.8, 0.8, 0.8, 1.0)
@export var noon_color : Color = Color(1.0, 1.0, 1.0, 1.0)
@export var dusk_color : Color = Color(0.7, 0.4, 0.3, 1.0)
@export var midnight_color : Color = Color(0.1, 0.1, 0.3, 1.0)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		if not editor_time_enabled:
			return
			
		var game_hours_per_second = 24.0 / (10.0 * 60.0)
		self.current_time += game_hours_per_second * delta
	else:
		self.current_time = GameManager.current_time

func _update_color() -> void:
	if current_time < 6.0:
		color = midnight_color.lerp(day_color, current_time / 6.0)
	elif current_time < 12.0:
		color = day_color.lerp(noon_color, (current_time - 6.0) / 6.0)
	elif current_time < 18.0:
		color = noon_color.lerp(dusk_color, (current_time - 12.0) / 6.0)
	else:
		color = dusk_color.lerp(midnight_color, (current_time - 18.0) / 6.0)
