extends Control
#
#var all_avatars: Array[Texture2D] = [] 
#var teacher_avatars: Array[Texture2D] = [] 
#var current_t_idx = 0
#var current_s_idx = 0
#var current_class_id = "" 
#var current_quest_id = ""
#
#const list_component = preload("uid://byrmutg2oph3h")
#const quest_log_component = preload("uid://bjxsw4iq3hdwy")
#
#@onready var class_creation: VBoxContainer = %class_creation
#@onready var student_creation: VBoxContainer = %student_creation
#@onready var activity_creation: VBoxContainer = %activity_creation
#@onready var student_lists: VBoxContainer = %student_lists
#@onready var t_avatar_preview: Sprite2D = %T_avatar_preview 
#@onready var s_avatar_preview: TextureRect = %S_avatar_preview
#@onready var teacher_name_inp: LineEdit = %teacher_name_inp
#@onready var class_name_inp: LineEdit = %class_name_inp
#@onready var student_name_inp: LineEdit = %student_name_inp 
#
#@onready var question_inp: LineEdit = %question_inp
##what is checked is the correct answer
#@onready var option_a: CheckBox = %option_a
#@onready var option_b: CheckBox = %option_b
#@onready var option_c: CheckBox = %option_c
#@onready var option_d: CheckBox = %option_d
#
#@onready var opt_a_inp: LineEdit = %opt_a_inp
#@onready var opt_b_inp: LineEdit = %opt_b_inp
#@onready var opt_c_inp: LineEdit = %opt_c_inp
#@onready var opt_d_inp: LineEdit = %opt_d_inp
#
#
##display the quests here using the quest_log_component
#@onready var quest_log: VBoxContainer = %QuestLog
#
#
#func _ready() -> void:
	#for i in range(1, 49):
		#var path = "res://assets/models/avatar/%d.png" % i
		#var tex = load(path)
		#if tex:
			#all_avatars.append(tex)
		#else:
			#printerr("Failed to load student avatar at ", path)
#
	#for i in range(1, 3):
		#var path = "res://assets/models/teacher/%d.png" % i
		#var tex = load(path)
		#if tex:
			#teacher_avatars.append(tex)
		#else:
			#printerr("Failed to load teacher avatar at ", path)
			#
	#class_creation.show()
	#student_creation.hide()
	#activity_creation.hide()
	#update_previews()
#
#
#func _on_return_to_home_pressed() -> void:
	#get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
	#
#func _on_next_to_student_creation_pressed() -> void:
	#if class_name_inp.text.is_empty(): 
		#return
		#
	#create_class() 
	#class_creation.hide()
	#activity_creation.hide()
	#student_creation.show()
	#display_students()
#
#func _on_return_to_teacher_creation_pressed() -> void:
	#student_creation.hide()
	#activity_creation.hide()
	#class_creation.show()
#
#func _on_next_t_avatar_pressed():
	#current_t_idx = (current_t_idx + 1) % teacher_avatars.size()
	#update_previews()
#
#func _on_prev_t_avatar_pressed():
	#current_t_idx = (current_t_idx - 1 + teacher_avatars.size()) % teacher_avatars.size()
	#update_previews()
#
#func _on_next_s_avatar_pressed():
	#current_s_idx = (current_s_idx + 1) % all_avatars.size()
	#update_previews()
#
#func _on_prev_s_avatar_pressed():
	#current_s_idx = (current_s_idx - 1 + all_avatars.size()) % all_avatars.size()
	#update_previews()
#
#func update_previews():
	#if not teacher_avatars.is_empty():
		#t_avatar_preview.texture = teacher_avatars[current_t_idx]
		#
	#if not all_avatars.is_empty():
		#s_avatar_preview.texture = all_avatars[current_s_idx]
#
#
#func create_class():
	#var c_name = class_name_inp.text.strip_edges()
	#var t_name = teacher_name_inp.text.strip_edges()
	#
	#var all_classes = DatabaseManager.get_table_data("classes")
	#for id in all_classes:
		#if all_classes[id].class_name == c_name:
			#print("UI: Class already exists, loading its ID.")
			#current_class_id = id
			#return
#
	#var new_class_data = {
		#"class_name": c_name,
		#"teacher": t_name,
		#"teacher_avatar_id": str(current_t_idx + 1), 
	#}
	#
	#current_class_id = DatabaseManager.insert("classes", new_class_data)
	#print("UI: New Class Created ID: ", current_class_id)
#
#func _on_add_student_pressed():
	#create_students()
#
#func create_students():
	#var s_name = student_name_inp.text.strip_edges() 
	#
	#if s_name.is_empty(): 
		#print("UI: Name cannot be empty!")
		#return
	#
	#var all_students = DatabaseManager.get_all("students")
	#for student in all_students:
		#if student.full_name.to_lower() == s_name.to_lower() and str(student.get("class_id", "")) == current_class_id:
			#print("UI: Student already exists in this class! Try again.")
			#return 
#
	#var new_student_data = {
		#"full_name": s_name,
		#"avatar_id": str(current_s_idx + 1),
		#"class_id": current_class_id 
	#}
	#DatabaseManager.insert("students", new_student_data)
#
	#student_name_inp.clear()
	#display_students()
#
#func display_students():
	#for child in student_lists.get_children():
		#child.queue_free()
		#
	#var students = DatabaseManager.get_all("students")
	#
	#for student in students:
		#if str(student.get("class_id", "")) == current_class_id:
			#var new_student_item = list_component.instantiate()
			#student_lists.add_child(new_student_item)
			#
			#var tex_index = int(student.get("avatar_id", "1")) - 1 
			#var student_tex = null
			#
			#if tex_index >= 0 and tex_index < all_avatars.size():
				#student_tex = all_avatars[tex_index]
				#
			#new_student_item.set_student_data(student.full_name, student_tex)
#
#func _on_next_to_activities_pressed() -> void:
	#student_creation.hide()
	#activity_creation.show()
	#class_creation.hide()
	#display_quests()
#
#func _on_next_to_game_pressed() -> void:
	#if current_class_id == "":
		#print("UI: Please create a class first!")
		#return
#
	#GameManager.active_class_id = current_class_id
#
	#get_tree().change_scene_to_file("res://scenes/stage/1/stage_1.tscn")
#
#func _on_return_to_student_creation_pressed() -> void:
	#student_creation.show()
	#activity_creation.hide()
	#class_creation.hide()
#
#
#func _on_save_quest_pressed() -> void:
	#if question_inp.text.is_empty():
		#print("UI: Question cannot be empty!")
		#return
		#
	## Determine which checkbox is ticked
	#var correct_ans = ""
	#if option_a.button_pressed: correct_ans = "a"
	#elif option_b.button_pressed: correct_ans = "b"
	#elif option_c.button_pressed: correct_ans = "c"
	#elif option_d.button_pressed: correct_ans = "d"
	#
	#if correct_ans == "":
		#print("UI: Please select a correct answer!")
		#return
#
	## Build the data structure you requested
	#var quest_data = {
		#"class_id": current_class_id,
		#"question": question_inp.text,
		#"options": {
			#"a": opt_a_inp.text,
			#"b": opt_b_inp.text,
			#"c": opt_c_inp.text,
			#"d": opt_d_inp.text
		#},
		#"correct_answer": correct_ans,
		#"answered": false
	#}
	#
	#if current_quest_id == "":
		## CREATE NEW
		#DatabaseManager.insert("quests", quest_data)
	#else:
		## UPDATE EXISTING
		#DatabaseManager.update("quests", current_quest_id, quest_data)
		#current_quest_id = "" # Reset back to "Create Mode"
#
	#clear_quest_inputs()
	#display_quests()
	#
#func clear_quest_inputs():
	#question_inp.clear()
	#opt_a_inp.clear()
	#opt_b_inp.clear()
	#opt_c_inp.clear()
	#opt_d_inp.clear()
	#
	#option_a.button_pressed = false
	#option_b.button_pressed = false
	#option_c.button_pressed = false
	#option_d.button_pressed = false
#
#func display_quests():
	#for child in quest_log.get_children():
		#child.queue_free()
		#
	#var quests = DatabaseManager.get_all("quests")
	#
	#for quest in quests:
		## Only show quests for the active class
		#if str(quest.get("class_id", "")) == current_class_id:
			#var new_quest_item = quest_log_component.instantiate()
			#quest_log.add_child(new_quest_item)
			#
			## Pass data to the component
			#new_quest_item.set_quest_data(str(quest.id), quest.question)
			#
			## Listen for the edit button
			#new_quest_item.edit_requested.connect(load_quest_for_editing)
#
#func load_quest_for_editing(quest_id: String):
	#current_quest_id = quest_id # Set the state to "Edit Mode"
	#
	#var quest = DatabaseManager.get_by_id("quests", quest_id)
	#if quest.is_empty(): return
	#
	## Populate the UI with the existing data
	#question_inp.text = quest.get("question", "")
	#
	#var options = quest.get("options", {})
	#opt_a_inp.text = options.get("a", "")
	#opt_b_inp.text = options.get("b", "")
	#opt_c_inp.text = options.get("c", "")
	#opt_d_inp.text = options.get("d", "")
	#
	## Set the correct checkbox
	#var ans = quest.get("correct_answer", "")
	#option_a.button_pressed = (ans == "a")
	#option_b.button_pressed = (ans == "b")
	#option_c.button_pressed = (ans == "c")
	#option_d.button_pressed = (ans == "d")
