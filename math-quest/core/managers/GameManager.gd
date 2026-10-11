extends Node

var next_quest_marker: Marker2D = null
var allow_cursor_click: bool = true
var current_chapter_id: String = ""
var arith_goto: Vector2 = Vector2.ZERO

var target_location: Marker2D
var sideQuest_locations: Dictionary[String, Marker2D]

var next_scene: String = ""
var loaded_world_scene : PackedScene
var custom_loading_screen: String = "Loading..."
var extend_loading: bool = false
var extend_time: float = 3.0

var boot_done : bool = false

func go_to_loading(next: String = "", load_world := false, to_world := false, text := "Entering World...") -> void:
	boot_done = true
	if next != "":
		next_scene = next
	var loading : LoadingScreen = preload("uid://dw6vygkcma2c8").instantiate()
	loading.load_world_scene = load_world
	loading.to_world_scene = to_world
	loading.custom_loading_text = text
	var old := get_tree().current_scene
	get_tree().root.add_child(loading)
	get_tree().current_scene = loading
	if old:
		old.queue_free()


#region day and night cycle
signal hour_changed(new_hour: float)
signal time_state_changed(is_enabled: bool)

var game_time_enabled: bool = false:
	set(value):
		if game_time_enabled != value:
			game_time_enabled = value
			time_state_changed.emit(game_time_enabled)
			
var minute_per_day: float = 24.0
var speed_scale: float = 1.0

# Added: Explicitly typed kp_amount to int for Godot 4 strict typing
var kp_amount: int = 0
var max_stamina: float = 100.0 
var player_stamina: float = 100.0

var current_time: float = 8.0:
	set(new_time):
		if current_time == new_time:
			return
			
		# Added: Explicit type hinting for internal variables
		var time_diff: float = new_time - current_time
		
		if time_diff < 0.0:
			time_diff += 24.0
			
		stamina_control(5.0 * time_diff)
		
		current_time = new_time
		hour_changed.emit(current_time)

# Added: Explicit -> void return types for functions that do not return a value
func stamina_control(custom_value: float) -> void:
	player_stamina -= custom_value
	player_stamina = clampf(player_stamina, 0.0, max_stamina)

func refill_stamina(value: float) -> void:
	player_stamina += value
	player_stamina = clampf(player_stamina, 0.0, max_stamina)

func _ready() -> void:
	await get_tree().process_frame
	_update_KP()
	
func _update_KP() -> void:
	var data = db.query("SELECT kp FROM progress WHERE is_active = true")
	# {to-do} Add error handling/null checks in case the db query fails or returns empty
	kp_amount = data.data[0].kp

func _process(delta: float) -> void:
	if not game_time_enabled:
		return

	if minute_per_day > 0.0:
		var game_hours_per_second: float = 24.0 / (minute_per_day * 60.0)
		var hour_increment: float = (game_hours_per_second * speed_scale) * delta
		
		self.current_time = wrapf(current_time + hour_increment, 0.0, 24.0)

func get_formatted_time() -> String:
	var total_hours: int = int(current_time)
	var minutes: int = int((current_time - total_hours) * 60)

	var suffix: String = "AM" if total_hours < 12 else "PM"
	var display_hours: int = total_hours % 12
	if display_hours == 0:
		display_hours = 12

	return "%02d:%02d %s" % [display_hours, minutes, suffix]
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

func _update_class(currentGrade: String, currentLesson: String) -> void:
	db.query("UPDATE progress SET current_grade = '%s' WHERE is_active = true" % currentGrade)
	db.query("UPDATE progress SET current_lesson = '%s' WHERE is_active = true" % currentLesson)
#endregion

#extends Node
#
#var next_quest_marker : Marker2D = null
#var allow_cursor_click : bool = true
#var current_chapter_id : String = ""
#var arith_goto : Vector2 = Vector2.ZERO
#
#var target_location : Marker2D
#var sideQuest_locations : Dictionary[String, Marker2D]
#
#var next_scene : String = ""
#var custom_loading_screen : String = "Loading..."
#var extend_loading : bool = false
#var extend_time : float = 3.0
#
##region day and night cycle
#signal hour_changed(new_hour: float)
#signal time_state_changed(is_enabled: bool)
#
#var game_time_enabled : bool = false:
	#set(value):
		#if game_time_enabled != value:
			#game_time_enabled = value
			#time_state_changed.emit(game_time_enabled)
			#
#var minute_per_day : float = 24.0
#var speed_scale : float = 1.0
#
#var current_time : float = 8.0
#
#var kp_amount := 0
#var player_stamina : float = 100.0
#
#func stamina_control(custom_value):
	##{to-do}
	##stamina should drop 5 per hour but you should gradualy deduct it not instant when it hit an hour
	##also we can call this function to apply a custom value deduction to the stamina
	#pass
#
#func refill_stamina(value):
	#player_stamina += value
	#pass
#
#func _ready() -> void:
	#await get_tree().process_frame
	#_update_KP()
	#
	#
#func _update_KP():
	#var data = db.query("SELECT kp FROM progress WHERE is_active = true")
	#kp_amount = data.data[0].kp
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
		#hour_changed.emit(current_time)
#
#func get_formatted_time() -> String:
	#var total_hours: int = int(current_time)
	#var minutes: int = int((current_time - total_hours) * 60)
#
	#var suffix: String = "AM" if total_hours < 12 else "PM"
	#var display_hours: int = total_hours % 12
	#if display_hours == 0:
		#display_hours = 12
#
	#return "%02d:%02d %s" % [display_hours, minutes, suffix]
#
			#
##endregion day and night cycle
#
#
##region cmd functions
#
#func _follow_player(npc_name: String, value: bool) -> Dictionary:
	#var current_scene: Node = get_tree().current_scene
	#var npc: Node = current_scene.find_child(npc_name, true, false)
	#
	#if npc != null:
		#if npc.has_signal("command_trigger"):
			#npc.emit_signal("command_trigger", "follow_player", value)
			#
		#if npc.has_method("follow_player"):
			#npc.follow_player(value)
			#
		#return {"npc_name": npc_name, "value": value, "status": "success"}
#
	#return {"npc_name": npc_name, "value": value, "status": "failed"}
#
#func _update_class(currentGrade : String, currentLesson : String):
	#db.query("UPDATE progress SET current_grade = '%s' WHERE is_active = true" % currentGrade)
	#db.query("UPDATE progress SET current_lesson = '%s' WHERE is_active = true" % currentLesson)
#
##endregion
