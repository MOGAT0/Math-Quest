#chapter 3

extends Control
class_name Chapter3

signal isChapter_Done(chapter:String)

@onready var title_label: Label = %title_label
@onready var name_label: Label = %name_label
@onready var text_label: RichTextLabel = %dialogue
@onready var entity_1: TextureRect = %entity1
@onready var entity_2: TextureRect = %entity2
@onready var entity_3: TextureRect = %entity3
@onready var screen_bg: TextureRect = %bg
@onready var bg_fx: Panel = %bg_fx

#@onready var wizard_castle: Marker2D = %wizard_castle
@export var next_pos : Marker2D

# [NEW] Pre-compile RegEx once at the top level for better performance
@onready var name_cleaner_regex: RegEx = RegEx.new()

const bg1 = preload("res://assets/ui/bg/forest_bg.jpg")

var darken : Color = Color("212121ff")
var normal : Color = Color("ffffffff")
var show_entities : bool = false
var current_chapter_id: String = "magical_forest"
var current_dialogues: Array = []
var dialogue_index: int = 0

# Only include the entities you want to explicitly override.
var index_visibility_overrides: Dictionary = {
	1: {"entity_1": false, "entity_2": false, "entity_3": true},
	2: {"entity_1": false, "entity_2": false, "entity_3": true},
}

var tween: Tween

func _ready() -> void:
	show()
	var is_done = db.query("SELECT is_done FROM checklist WHERE chapter = %s" % current_chapter_id)
	if is_done.data[0].is_done:
		advance_to_next_chapter()
		isChapter_Done.emit(current_chapter_id)
	
	name_cleaner_regex.compile("[^a-zA-Z0-9 ]")
	
	
	GameManager.allow_cursor_click = false
	load_chapter(current_chapter_id)
	entity_1.visible = show_entities
	
	GameManager.current_chapter_id = current_chapter_id

func start_typewriter(dialogue_text: String) -> void:
	MusicPlayer.one_shot = true
	text_label.text = dialogue_text
	text_label.visible_characters = 0
	
	if tween and tween.is_valid():
		tween.kill()
		
	tween = create_tween()
	var type_speed: float = 0.01
	var duration: float = dialogue_text.length() * type_speed
	
	tween.tween_property(text_label, "visible_characters", dialogue_text.length(), duration)
	tween.finished.connect(func():
		MusicPlayer.one_shot = false
	)
	
func update_entity_visibility(c_name: String, current_idx: int) -> void:
	var new_name = name_cleaner_regex.sub(c_name, "", true).replace(" ", "_")
	match new_name:
		"narrator":
			show_entities = false
			entity_1.modulate = normal
			bg_fx.show()
		"matthew":
			show_entities = true
			entity_1.modulate = normal
			entity_2.modulate = darken
			bg_fx.hide()
		"arith":
			show_entities = true
			entity_1.modulate = darken
			entity_2.modulate = normal
			bg_fx.hide()

	entity_1.visible = show_entities
	entity_2.visible = show_entities
	entity_3.visible = false
	
	if index_visibility_overrides.has(current_idx):
		var overrides = index_visibility_overrides[current_idx]
		if overrides.has("entity_1"): entity_1.visible = overrides["entity_1"]
		if overrides.has("entity_2"): entity_2.visible = overrides["entity_2"]
		if overrides.has("entity_3"): entity_3.visible = overrides["entity_3"]

func load_chapter(chapter_id: String) -> void:
	if chapter_id == "":
		# {to-do} Implement game completion screen or logic
		return

	current_chapter_id = chapter_id
	dialogue_index = 0
	
	var chapter_title = StoryLineManager.get_title(current_chapter_id)
	current_dialogues = StoryLineManager.get_dialogues(current_chapter_id)
	
	if title_label:
		title_label.text = chapter_title
		
	show_next_dialogue()

func show_next_dialogue() -> void:
	if dialogue_index < current_dialogues.size():
		var line_data = current_dialogues[dialogue_index]
		if name_label and text_label:
			var get_charName : String = line_data.get("name", "")
			name_label.text = get_charName.capitalize()
			start_typewriter(line_data.get("log", ""))
			update_entity_visibility(get_charName, dialogue_index)
			
		dialogue_index += 1
	else:
		advance_to_next_chapter()

func show_previous_dialogue() -> void:
	if dialogue_index > 1:
		dialogue_index -= 2
		
		var line_data = current_dialogues[dialogue_index]
		
		if name_label and text_label:
			var get_charName : String = line_data.get("name", "")
			name_label.text = get_charName.capitalize()
			start_typewriter(line_data.get("log", ""))
			update_entity_visibility(get_charName, dialogue_index)
			
		dialogue_index += 1

func advance_to_next_chapter() -> void:
	var next_id = StoryLineManager.get_next_node(current_chapter_id)
	GameManager.current_chapter_id = next_id
	GameManager.allow_cursor_click = true
	if next_pos:
		GameManager.arith_goto = next_pos.global_position
		GameManager.target_location = next_pos
		print(GameManager.arith_goto)
		hide()
		isChapter_Done.emit(current_chapter_id)

func _on_next_pressed() -> void:
	if tween and tween.is_running():
		tween.kill()
		text_label.visible_characters = -1
	else:
		show_next_dialogue()

func _on_previous_pressed() -> void:
	show_previous_dialogue()
