extends PanelContainer
class_name StudentSelectionList

# Emit this signal when the checkbox is clicked
signal student_selected(id: String)

var student_id: String

@onready var stdnt_profile: TextureRect = %stdnt_profile
@onready var stdn_name: Label = %stdn_name
@onready var check_box: CheckBox = %CheckBox

func _ready() -> void:
	# Connect the checkbox toggle to our custom function
	check_box.toggled.connect(_on_checkbox_toggled)

# Custom setup function called from Questionair
func setup(data: Dictionary) -> void:
	student_id = str(data.get("id", ""))
	stdn_name.text = data.get("full_name", "Unknown Student")
	
	# Load the avatar texture using the hydrated path
	var avatar_path = data.get("avatar_path", "")
	if avatar_path != "" and ResourceLoader.exists(avatar_path):
		stdnt_profile.texture = load(avatar_path)
	else:
		push_warning("Could not load avatar for: " + stdn_name.text)

func _on_checkbox_toggled(toggled_on: bool) -> void:
	if toggled_on:
		student_selected.emit(student_id)
