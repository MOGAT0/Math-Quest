extends Node

var next_quest_marker : Marker2D = null
var allow_cursor_click : bool = true
var current_chapter_id : String = ""
var arith_goto : Vector2 = Vector2.ZERO

var target_location : Marker2D
var sideQuest_locations : Dictionary[String, Marker2D]

var next_scene : String = ""
var custom_loading_screen : String = "Loading..."
var extend_loading : bool = false
var extend_time : float = 3.0

#region day and night cycle
signal hour_changed(new_hour: float)
signal time_state_changed(is_enabled: bool)

var game_time_enabled : bool = false:
	set(value):
		if game_time_enabled != value:
			game_time_enabled = value
			time_state_changed.emit(game_time_enabled)
			
var minute_per_day : float = 24.0
var speed_scale : float = 1.0

var current_time : float = 8.0

func _process(delta: float) -> void:
	if not game_time_enabled:
		return

	if minute_per_day > 0.0:
		var game_hours_per_second = 24.0 / (minute_per_day * 60.0)
		current_time += (game_hours_per_second * speed_scale) * delta
		current_time = wrapf(current_time, 0.0, 24.0) 
		
		hour_changed.emit(current_time)

func get_formatted_time() -> String:
	var total_hours: int = int(current_time)
	var minutes: int = int((current_time - total_hours) * 60)

	var suffix: String = "AM" if total_hours < 12 else "PM"
	var display_hours: int = total_hours % 12
	if display_hours == 0:
		display_hours = 12

	return "%02d:%02d %s" % [display_hours, minutes, suffix]

#signal hour_changed(new_hour: int)
#
#var game_time_enabled : bool = false
#var minute_per_day : float = 24.0
#var speed_scale : float = 1.0
#
#var current_time : float = 8.0
#
#var _last_hour : int = 8 
#
#func _process(delta: float) -> void:
	#if not game_time_enabled:
		#return
#
	#if minute_per_day > 0.0:
		#var game_hours_per_second = 24.0 / (minute_per_day * 60.0)
		#current_time += (game_hours_per_second * speed_scale) * delta
		#current_time = wrapf(current_time, 0.0, 24.0)
#
		#var current_hour: int = int(current_time)
		#if current_hour != _last_hour:
			#hour_changed.emit(current_hour)
			#_last_hour = current_hour
			
#endregion day and night cycle


#region cmd functions

func _follow_player(npc_name: String, value: bool) -> Dictionary:
	var current_scene: Node = get_tree().current_scene
	var npc: Node = current_scene.find_child(npc_name, true, false)
	
	if npc != null:
		if npc.has_signal("command_trigger"):
			npc.emit_signal("command_trigger", "follow_player", value)
			
		if npc.has_method("follow_player"):
			npc.follow_player(value)
			
		return {"npc_name": npc_name, "value": value, "status": "success"}

	return {"npc_name": npc_name, "value": value, "status": "failed"}

func _update_class(currentGrade : String, currentLesson : String):
	db.query("UPDATE progress SET current_grade = '%s' WHERE is_active = true" % currentGrade)
	db.query("UPDATE progress SET current_lesson = '%s' WHERE is_active = true" % currentLesson)

#endregion
