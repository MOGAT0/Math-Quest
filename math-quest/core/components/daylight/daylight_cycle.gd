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
@export var day_color : Color = Color("ccccccff")
@export var noon_color : Color = Color("ffffffff")
@export var dusk_color : Color = Color("292958")
@export var midnight_color : Color = Color("1a1a4dff")
 
var is_sleep_task_done : bool = false

func _ready() -> void:
	_update_loc_finder()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		if not editor_time_enabled:
			return
			
		var game_hours_per_second = 24.0 / (10.0 * 60.0)
		self.current_time += game_hours_per_second * delta
	else:
		self.current_time = GameManager.current_time
		if is_sleep_task_done:
			if GameManager.current_time > 21 or GameManager.current_time <= 4:
				GameManager.target_location = %arith_house
			
func _update_color() -> void:
	if current_time < 6.0:
		color = midnight_color.lerp(day_color, current_time / 6.0)
	elif current_time < 12.0:
		color = day_color.lerp(noon_color, (current_time - 6.0) / 6.0)
	elif current_time < 18.0:
		color = noon_color.lerp(dusk_color, (current_time - 12.0) / 6.0)
	else:
		color = dusk_color.lerp(midnight_color, (current_time - 18.0) / 6.0)


func _on_ariths_house_entrance_body_entered(body: Node2D) -> void:
	if body is Player:
		pass
	
func _update_loc_finder():
	var is_done = db.query("SELECT is_done FROM checklist WHERE chapter = home_sleep_1")
	var portal_spawned = db.query("SELECT open_portal FROM progress WHERE is_active = true")
	
	if !portal_spawned.data[0].open_portal:
		is_sleep_task_done = is_done.data[0].is_done
	else:
		is_sleep_task_done = false
		


func _on_class_class_end(_currentGrade: String, _currentLesson: String) -> void:
	_update_loc_finder()
