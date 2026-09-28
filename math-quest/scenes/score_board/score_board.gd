extends Control

const RANKING_ROW = preload("uid://cxw00ae1auque")
@onready var ranking_list: VBoxContainer = %ranking_list

# We save the sorted data here so the export button can access it instantly
var current_ranking_data: Array = []

func _ready() -> void:
	# Optional: Keep it live just like the top 5!
	#DatabaseManager.data_changed.connect(_on_database_changed)
	refresh_scoreboard()

func refresh_scoreboard() -> void:
	#var class_id_str = str(GameManager.active_class_id)
	#var data = DatabaseManager.get_all_where("scores", "class_id", class_id_str)
	#var aggregated_scores = {}
	#
	#for d in data:
		#var s_id = str(int(d.get("student_id", 0)))
		#var points = float(d.get("score", 0.0))
		#if aggregated_scores.has(s_id):
			#aggregated_scores[s_id] += points
		#else:
			#aggregated_scores[s_id] = points
#
	#var combined_student_data: Array = []
	#for s_id in aggregated_scores.keys():
		#var student_info = DatabaseManager.get_hydrated("students", s_id)
		#if not student_info.is_empty():
			#student_info["total_score"] = aggregated_scores[s_id]
			#combined_student_data.append(student_info)
#
	## Sort from highest to lowest score
	#combined_student_data.sort_custom(func(a, b): return a["total_score"] > b["total_score"])
	#
	## Save the full list to our global variable for the Export function
	#current_ranking_data = combined_student_data
	
	display_leaderboard(current_ranking_data)

func display_leaderboard(all_students: Array) -> void:
	# 1. Clear old UI
	for child in ranking_list.get_children():
		child.queue_free()
		
	# 2. Generate all rows (No slicing this time!)
	for i in range(all_students.size()):
		var student = all_students[i]
		var rank = i + 1
		
		var row = RANKING_ROW.instantiate()
		ranking_list.add_child(row)
		row.setup(rank, student)

func _on_database_changed(table_name: String) -> void:
	if table_name == "scores":
		refresh_scoreboard()

# --- BUTTON CONTROLS ---

func _on_home_pressed() -> void:
	# Easily swap back to the main menu
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")

func _on_export_pressed() -> void:
	if current_ranking_data.is_empty():
		print("Nothing to export!")
		return
		
	# We save to the user:// directory so it works on exported games!
	var file_path = "user://Class_" + str(GameManager.active_class_id) + "_Ranking.csv"
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	
	if file == null:
		push_error("Scoreboard: Failed to create Excel export file.")
		return
		
	# 1. Write the Excel Column Headers
	file.store_line("Rank,Student Name,Total Score")
	
	# 2. Write the actual student data row by row
	for i in range(current_ranking_data.size()):
		var rank = str(i + 1)
		var student_name = current_ranking_data[i].get("full_name", "Unknown")
		var score = str(current_ranking_data[i].get("total_score", 0))
		
		# Combine them with commas and write to the file
		var csv_line = rank + "," + student_name + "," + score
		file.store_line(csv_line)
		
	file.close()
	print("Successfully exported ranking to: ", file_path)
	
	# Pro-Tip: Automatically open the folder on the player's computer so they can see the file!
	var absolute_path = ProjectSettings.globalize_path("user://")
	OS.shell_open(absolute_path)
