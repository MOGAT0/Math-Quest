extends Node2D
class_name World

@onready var game_ui: CanvasLayer = %Game_UI
@onready var indicator: Sprite2D = %indicator
@export var player : Player
@export var arith : CharacterBody2D
@export var great_wizzard : CharacterBody2D
@onready var classRoom: Scholl = %Class
@onready var transition_fx: TransitionFX = %TransitionFx

@onready var locations: Dictionary[String, Marker2D] = {
	"arith_house": %arith_house,
	"arith_house_exit": %arith_house_exit,
	"academy_gate": %academy_gate,
	"academy_gate2": %academy_gate2,
	"inner_academy": %inner_academy,
	"inner_academy2": %inner_academy2,
	"principal_office": %principal_office,
	"wizard_castle": %wizard_castle,
	"inside_ariths_home": %inside_ariths_home,
	"arith_bed": %arith_bed,
	"school_exit": %school_exit,
	"class_room": %class_room,
	"class_room_entrance": %class_room_entrance,
	"waiting_loc":%waiting_loc, 
	"gw_pos":%gw_pos, 
	"arith_pos":%arith_pos, 
	"matthew_pos":%matthew_pos
}


var player_in_zone: Player = null
var current_destination_key: String = ""

#office loc
var _has_entered : bool = false

const STARTING_CHAPTER : String = "chapter_1"

@export var default_bg_color : Color

func _ready() -> void:
	RenderingServer.set_default_clear_color(default_bg_color)
	indicator.hide()
	#_ensure_save_tables()
	_load_progress()
	
	var done_sleep_once = db.query("SELECT is_done FROM checklist WHERE chapter = home_sleep_1 LIMIT 1")
	var is_done = done_sleep_once.data[0].is_done
	
	if is_done:
		GameManager.game_time_enabled = true
	

#region save/load

func _ensure_save_tables() -> void:
	pass
	#db.query("CREATE TABLE progress (id int primary_key auto_increment, current_location vector2, current_chapter text, is_active bool)")
	#db.query("CREATE TABLE checklist (id int primary_key auto_increment, chapter text not_null, is_done bool)")

func _sql_str(value: String) -> String:
	return "\"" + value.replace("\"", "\\\"") + "\""

func _first_row(query_result: Dictionary) -> Variant:
	if query_result.get("status") == "success" and not query_result.get("data", []).is_empty():
		return query_result.data[0]
	return null

func _load_progress() -> void:
	var enable_daynight = db.query("SELECT is_done FROM checklist WHERE chapter = home_sleep_1")
	var res = _first_row(enable_daynight)
	if res:
		GameManager.game_time_enabled = res.is_done
	
	
	
	var progress_query = db.query("SELECT current_location, arith_pos, current_chapter FROM progress WHERE is_active = true LIMIT 1")
	var save_row = _first_row(progress_query)

	if save_row == null:
		push_warning("World: no active save found, starting a new game.")
		_create_new_save()
		return

	var current_chap : String = save_row.current_chapter

	if player and save_row.current_location != null:
		player.global_position = save_row.current_location

	if arith:
		if save_row.arith_pos != null:
			arith.global_position = save_row.arith_pos
		else:
			_position_arith_for_chapter(current_chap)

	_has_entered = _is_chapter_done("chapter_7")

func _create_new_save() -> void:
	var start_pos : Vector2 = player.global_position if player else Vector2.ZERO
	db.query("INSERT INTO progress (current_location, current_chapter, is_active) VALUES (Vector2%s, %s, true)" % [start_pos, _sql_str(STARTING_CHAPTER)])

func _position_arith_for_chapter(current_chap: String) -> void:
	var chapter_query = db.query("SELECT id FROM checklist WHERE chapter = %s LIMIT 1" % _sql_str(current_chap))
	var row = _first_row(chapter_query)

	if row != null and row.id <= 7:
		if locations.has("inner_academy"):
			arith.global_position = locations["inner_academy"].global_position
			GameManager.arith_goto = locations["inner_academy"].global_position
			GameManager.target_location = locations["inner_academy"]
	elif locations.has("arith_house"):
		arith.global_position = locations["arith_house"].global_position
		GameManager.arith_goto = locations["arith_house"].global_position
		GameManager.target_location = locations["arith_house"]

func _is_chapter_done(chapter: String) -> bool:
	var result = db.query("SELECT is_done FROM checklist WHERE chapter = %s LIMIT 1" % _sql_str(chapter))
	var row = _first_row(result)
	return row.is_done if row != null else false

func update_checklist(chapter : String) -> void:
	if not player:
		push_error("World: cannot save, player reference is null.")
		return

	if _is_chapter_done(chapter):
		return

	var player_pos = player.global_position
	_save_progress(player_pos, chapter)
	_mark_chapter_done(chapter)
	_save_arith_position()

func _save_arith_position() -> void:
	if not arith:
		return

	var checklist_id = _get_current_checklist_id()
	if checklist_id == null or checklist_id > 7:
		return

	db.query("UPDATE progress SET arith_pos = Vector2%s WHERE is_active = true" % [arith.global_position])

func _save_progress(player_pos: Vector2, chapter: String) -> void:
	var existing = _first_row(db.query("SELECT id FROM progress WHERE is_active = true LIMIT 1"))

	if existing != null:
		db.query("UPDATE progress SET current_location = Vector2%s WHERE is_active = true" % [player_pos])
		db.query("UPDATE progress SET current_chapter = %s WHERE is_active = true" % _sql_str(chapter))
	else:
		db.query("INSERT INTO progress (current_location, current_chapter, is_active) VALUES (Vector2%s, %s, true)" % [player_pos, _sql_str(chapter)])

func _mark_chapter_done(chapter: String) -> void:
	var existing = _first_row(db.query("SELECT id FROM checklist WHERE chapter = %s LIMIT 1" % _sql_str(chapter)))

	if existing != null:
		db.query("UPDATE checklist SET is_done = true WHERE chapter = %s" % _sql_str(chapter))
	#else:
		#db.query("INSERT INTO checklist (chapter, is_done) VALUES (%s, true)" % _sql_str(chapter))

#endregion


func _process(_delta: float) -> void:
	var has_visible_child: bool = false

	for i in game_ui.get_children():
		if i.name.to_lower() != "extra_ui":
			if i is CanvasItem and i.visible:
				has_visible_child = true
				break
			
	if has_visible_child:
		GameManager.allow_cursor_click = false
	else:
		GameManager.allow_cursor_click = true
	
	if player_in_zone and current_destination_key != "":
		if locations.has(current_destination_key):
			teleport(player_in_zone, locations[current_destination_key].global_position)
		else:
			push_error("teleport failed: missing key in locations")

func _get_current_checklist_id() -> Variant:
	var result = db.query("SELECT id FROM checklist WHERE chapter = (SELECT current_chapter FROM progress WHERE is_active = true LIMIT 1) ORDER BY id DESC LIMIT 1")
	var row = _first_row(result)
	return row.id if row != null else null

#region in and out of the academy

func _on_academy_entrance_body_entered(body: Node2D) -> void:
	var done_status = _is_chapter_done("school_admission")
	
	if GameManager.current_time > 21 or GameManager.current_time <= 4:
		#{to-do} add a pop up alert
		return
	
	if body is Arith:
		if locations.has("inner_academy"):
			teleport(body, locations["inner_academy"].global_position)
			if !_has_entered:
				await get_tree().process_frame
				GameManager.arith_goto = locations["principal_office"].global_position
				GameManager.target_location = locations["principal_office"]
			
	if body is Player:
		indicator.show()
		player_in_zone = body
		current_destination_key = "inner_academy" if !done_status else "school_exit"

func _on_academy_entrance_body_exited(body: Node2D) -> void:
	if body is Player:
		indicator.hide()
		player_in_zone = null
		current_destination_key = ""

func _on_class_room_exit_body_entered(body: Node2D) -> void:
	if body is Player:
		teleport(body, locations["academy_gate2"].global_position)

func _on_in_acd_entrace_body_entered(body: Node2D) -> void:
	if body is Arith:
		if locations.has("academy_gate2"):
			#if _has_entered:
			GameManager.arith_goto = locations["arith_house"].global_position
			GameManager.target_location = locations["arith_house"]
			await get_tree().process_frame
			teleport(body, locations["academy_gate2"].global_position)

			
	if body is Player:
		indicator.show()
		player_in_zone = body
		current_destination_key = "academy_gate"

		if _is_chapter_done("school_admission"):
			GameManager.current_time = 23
			GameManager.game_time_enabled = true

func _on_in_acd_entrace_body_exited(body: Node2D) -> void:
	if body is Player:
		indicator.hide()
		player_in_zone = null
		current_destination_key = ""
		
func teleport(character: CharacterBody2D, location: Vector2) -> void:
	character.set_deferred("global_position", location)
	if character is Player and transition_fx:
		await get_tree().process_frame
		transition_fx.transition = true
	

func _on_arith_home_exit_body_entered(body: Node2D) -> void:
	if body is Player:
		teleport(body, locations["arith_house_exit"].global_position)

func _on_g_1_entrance_body_entered(body: Node2D) -> void:
	if body is Player:
		teleport(body, locations["class_room"].global_position)
		body.hide()
		await get_tree().create_timer(1).timeout
		classRoom.start_class()

func _on_class_class_end(_currentGrade: String, _currentLesson: String) -> void:
	teleport(player,locations["academy_gate2"].global_position)
	player.show()
	GameManager.current_time = 22

func _on_portal_portal_spawned() -> void:
	print("portal spawned")
	await get_tree().process_frame
	teleport(arith,locations["waiting_loc"].global_position)
	teleport(great_wizzard, locations["gw_pos"].global_position)
	GameManager.arith_goto = locations.arith_pos.global_position
	arith.show()
	great_wizzard.show()


#endregion


#region monitor finished chapters

func _on_chap_3_is_chapter_done(chapter: String) -> void:
	update_checklist(chapter)

func _on_chapter_4_is_chapter_done(chapter: String) -> void:
	update_checklist(chapter)

func _on_chapter_5_is_chapter_done(chapter: String) -> void:
	update_checklist(chapter)

func _on_chapter_6_is_chapter_done(chapter: String) -> void:
	update_checklist(chapter)

func _on_chapter_7_is_chapter_done(chapter: String) -> void:
	_has_entered = true
	update_checklist(chapter)
	


func _on_matthew_sleep_is_chapter_done(chapter: String) -> void:
	update_checklist(chapter)


#endregion monitor finished chapters
