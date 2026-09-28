extends HBoxContainer

@onready var avatar_rect: TextureRect = $avatar
@onready var name_label: Label = $name
var student_id

func set_student_data(student_name: String, avatar_tex: Texture2D) -> void:
	name_label.text = student_name
	if avatar_tex != null:
		avatar_rect.texture = avatar_tex
