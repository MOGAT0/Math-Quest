#chapter 2
extends Control
class_name Chapter2

signal isChapter_Done

@onready var title_label: Label = %title_label
@onready var name_label: Label = %name_label
@onready var text_label: RichTextLabel = %dialogue
@onready var entity_1: TextureRect = %entity1
@onready var entity_3: TextureRect = %entity3
@onready var screen_bg: TextureRect = %bg
@onready var transition_fx: TransitionFX = %TransitionFx

const bg1 = preload("res://assets/ui/bg/alley_bg.png")
const bg2 = preload("res://assets/ui/bg/portal_bg.png")

var darken : Color = Color("212121ff")
var normal : Color = Color("ffffffff")
var show_entities : bool = false
var current_chapter_id: String = "alley_portal"
var current_dialogues: Array = []
var dialogue_index: int = 0

var tween: Tween

func talking(c_name : String) -> void:
	var regex = RegEx.new()
	regex.compile("[^a-zA-Z0-9 ]") 
	
	var new_name = regex.sub(c_name, "", true).replace(" ","_")
	
	match new_name:
		"narrator":
			show_entities = false
			entity_1.modulate = normal
		"matthew":
			show_entities = true
			entity_1.modulate = normal


	if dialogue_index == 1:
		entity_1.visible = false
	else:
		entity_1.visible = show_entities
		
func dialog_idx_checker(idx : int) -> void:
	entity_3.visible = true if idx == 2 else false
	screen_bg.texture = bg1 if idx < 3 else bg2
	
	
	print(idx)


func _ready() -> void:
	load_chapter(current_chapter_id)
	entity_1.visible = show_entities
	
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


func start_typewriter(dialogue_text: String) -> void:
	text_label.text = dialogue_text
	text_label.visible_characters = 0
	
	if tween and tween.is_valid():
		tween.kill()
		
	tween = create_tween()
	var type_speed: float = 0.01
	var duration: float = dialogue_text.length() * type_speed
	
	tween.tween_property(text_label, "visible_characters", dialogue_text.length(), duration)

func show_next_dialogue() -> void:
	if dialogue_index < current_dialogues.size():
		var line_data = current_dialogues[dialogue_index]
		if name_label and text_label:
			var get_charName : String = line_data.get("name", "")
			name_label.text = get_charName.capitalize()
			start_typewriter(line_data.get("log", ""))
			talking(get_charName)
			
		dialogue_index += 1
		dialog_idx_checker(dialogue_index)
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
			talking(get_charName)
		dialogue_index += 1
		dialog_idx_checker(dialogue_index)

func advance_to_next_chapter() -> void:
	var next_id = StoryLineManager.get_next_node(current_chapter_id)
	#load_chapter(next_id)
	db.query("UPDATE checklist SET is_done = true WHERE chapter = alley_portal")
	GameManager.current_chapter_id = next_id
	isChapter_Done.emit()
	GameManager.extend_loading = false
	GameManager.next_scene = "res://scenes/main_scene/world.tscn"
	#get_tree().change_scene_to_file("res://core/components/loading/loading_screen.tscn")
	transition_fx.transition = true

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.is_action_pressed("ui_accept"):
			show_next_dialogue()
		if event.keycode == KEY_BACKSPACE:
			show_previous_dialogue()
func _on_next_pressed() -> void:
	if tween and tween.is_running():
		tween.kill()
		text_label.visible_characters = -1
	else:
		show_next_dialogue()
func _on_previous_pressed() -> void:
	show_previous_dialogue()


func _on_transition_fx_transition_in_complete() -> void:
	get_tree().change_scene_to_file("res://core/components/loading/loading_screen.tscn")
