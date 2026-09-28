extends PanelContainer
class_name ScoreboardRow

@onready var rank_no: Label = %rank_no
@onready var avatar: TextureRect = %avatar
@onready var std_name: Label = %std_name
@onready var score: Label = %score

func setup(rank: int, student_data: Dictionary) -> void:
	rank_no.text = str(rank)
	std_name.text = student_data.get("full_name", "Unknown")
	score.text = str(student_data.get("total_score", 0))
	
	# Load the avatar safely
	var avatar_path = student_data.get("avatar_path", "")
	if avatar_path != "" and ResourceLoader.exists(avatar_path):
		avatar.texture = load(avatar_path)
	else:
		push_warning("ScoreboardRow: Could not load avatar for " + std_name.text)
