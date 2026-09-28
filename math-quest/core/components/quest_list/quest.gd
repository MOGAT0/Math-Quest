extends HBoxContainer

signal edit_requested(quest_id: String)

var _quest_id: String = ""

@onready var question: RichTextLabel = %question
@onready var edit: Button = %edit

func _ready():
	edit.pressed.connect(_on_edit_pressed)

func set_quest_data(id: String, question_text: String):
	_quest_id = id
	question.text = question_text

func _on_edit_pressed():
	edit_requested.emit(_quest_id)
