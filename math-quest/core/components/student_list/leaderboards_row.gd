extends HBoxContainer
class_name LeaderboardsRow

@onready var avatar: TextureRect = %avatar
@onready var student_name: Label = %name

func setup(rank: int, student_data: Dictionary) -> void:
	# 1. Format the text to show Rank, Name, and Score
	var s_name = student_data.get("full_name", "Unknown")
	var s_score = student_data.get("total_score", 0)
	student_name.text = str(s_name)
	
	# 2. Load the avatar texture safely
	var avatar_path = student_data.get("avatar_path", "")
	if avatar_path != "" and ResourceLoader.exists(avatar_path):
		avatar.texture = load(avatar_path)
	else:
		push_warning("LeaderboardsRow: Could not load avatar for " + s_name)
