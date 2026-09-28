extends Control

@onready var title_label: Label = %title_label
@onready var name_label: Label = %name_label
@onready var text_label: RichTextLabel = %dialogue
@onready var entity_1: TextureRect = %entity1
@onready var entity_2: TextureRect = %entity2

var darken : Color = Color("212121ff")
var normal : Color = Color("ffffffff")
var show_entities : bool = false
var current_chapter_id: String = "prologue_classroom"
var current_dialogues: Array = []
var dialogue_index: int = 0

func _ready() -> void:
	load_chapter(current_chapter_id)
	entity_1.visible = show_entities
	entity_2.visible = show_entities
	
	GameManager.current_chapter_id = current_chapter_id

func load_chapter(chapter_id: String) -> void:
	if chapter_id == "":
		# {to-do} Implement game completion screen or logic
		return

	current_chapter_id = chapter_id
	dialogue_index = 0
	
	# Fetch data from the singleton
	var chapter_title = StoryLineManager.get_title(current_chapter_id)
	current_dialogues = StoryLineManager.get_dialogues(current_chapter_id)
	
	if title_label:
		title_label.text = chapter_title
		
	show_next_dialogue()

func show_next_dialogue() -> void:
	if dialogue_index < current_dialogues.size():
		var line_data = current_dialogues[dialogue_index]
		
		if name_label and text_label:
			name_label.text = line_data.get("name", "").capitalize()
			text_label.text = line_data.get("log", "")
			
		dialogue_index += 1
	else:
		advance_to_next_chapter()

func show_previous_dialogue() -> void:
	# Check if we are past the first dialogue line
	if dialogue_index > 1:
		# Step back by 2 because dialogue_index is already pointing to the next line
		dialogue_index -= 2
		var line_data = current_dialogues[dialogue_index]
		
		if name_label and text_label:
			name_label.text = line_data.get("name", "").capitalize()
			text_label.text = line_data.get("log", "")
			
		# Increment by 1 so the next time "Next" is clicked, it proceeds correctly
		dialogue_index += 1

func advance_to_next_chapter() -> void:
	var next_id = StoryLineManager.get_next_node(current_chapter_id)
	#load_chapter(next_id)
	GameManager.current_chapter_id = next_id

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.is_action_pressed("ui_accept"):
			show_next_dialogue()
		if event.keycode == KEY_BACKSPACE:
			show_previous_dialogue()
func _on_next_pressed() -> void:
	show_next_dialogue()
func _on_previous_pressed() -> void:
	show_previous_dialogue()
