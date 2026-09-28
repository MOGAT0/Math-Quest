extends VBoxContainer

# If you have a UI component for individual leaderboard rows, preload it here:
# const LEADERBOARD_ROW = preload("res://path/to/leaderboard_row.tscn")

const LEADERBOARD_ROW = preload("uid://g4l8u86qq4ra")
@onready var leaderboard_cont: PanelContainer = %leaderboard_cont


func _ready() -> void:
	# 1. Wire up the live refresh signal
	DatabaseManager.data_changed.connect(_on_database_changed)
	
	# 2. Fetch and display initial scores
	get_scores()

func get_scores() -> void:
	var class_id_str = str(GameManager.active_class_id)
	var data = DatabaseManager.get_all_where("scores", "class_id", class_id_str)
	
	# Dictionary to act as our accumulator: { "student_id": total_score }
	var aggregated_scores = {}
	
	# --- PHASE 1: SUM THE SCORES --
	print(data)
	for d in data:
		var s_id = str(int(d.get("student_id", 0)))
		var score = float(d.get("score", 0.0))
		
		if aggregated_scores.has(s_id):
			aggregated_scores[s_id] += score
		else:
			aggregated_scores[s_id] = score

	# --- PHASE 2: HYDRATE & COMBINE ---
	var combined_student_data: Array = []
	
	for s_id in aggregated_scores.keys():
		var student_info = DatabaseManager.get_hydrated("students", s_id)
		
		# Ensure the student actually exists before combining
		if not student_info.is_empty():
			student_info["total_score"] = aggregated_scores[s_id]
			combined_student_data.append(student_info)

	# --- PHASE 3: SORT DESCENDING ---
	# This sorts the array so the highest total_score is at index 0
	combined_student_data.sort_custom(func(a, b): return a["total_score"] > b["total_score"])

	# --- PHASE 4: GET TOP 5 ---
	# Array.slice gracefully handles cases where there are less than 5 students
	var top_5 = combined_student_data.slice(0, 5)
	
	display_leaderboard(top_5)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if Input.is_action_just_pressed("live_leaderboards"):
			leaderboard_cont.visible = !leaderboard_cont.visible

func display_leaderboard(top_students: Array) -> void:
	# 1. Clear out old UI nodes so they don't duplicate on refresh
	for child in get_children():
		child.queue_free()
		
	# 2. Generate the new UI
	for i in range(top_students.size()):
		var student = top_students[i]
		var rank = i + 1
		
		# For debugging in the console to verify the data is perfect:

		# --- UI INSTANTIATION ---
		# Replace this section with your actual UI spawning logic
		var row = LEADERBOARD_ROW.instantiate()
		add_child(row)
		row.setup(rank, student) 

# --- LIVE REFRESH TRIGGER ---
func _on_database_changed(table_name: String) -> void:
	# Only rebuild the leaderboard if the scores table was the one updated
	if table_name == "scores":
		print("Leaderboard: New score detected! Refreshing live view...")
		get_scores()
