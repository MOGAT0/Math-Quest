extends Control
class_name Chapter8

signal isChapter_Done(chapter : String)

@onready var title_label: Label = %title_label
@onready var name_label: Label = %name_label
@onready var text_label: RichTextLabel = %dialogue
@onready var entity_1: TextureRect = %entity1
@onready var entity_2: TextureRect = %entity2
@onready var entity_3: TextureRect = %entity3
@onready var screen_bg: TextureRect = %bg

@export var nex_pos : Marker2D
@export var _optional : Control

const bg1 = preload("res://assets/ui/bg/innerview_school.jpg")

var darken : Color = Color("212121ff")
var normal : Color = Color("ffffffff")
var current_chapter_id: String = "portal_key_awarded"
var current_dialogues: Array = []
var dialogue_index: int = 0

var index_visibility_overrides: Dictionary = {
	0: {"entity_1": true, "entity_2": false, "entity_3": true, "active": "entity_3"},
	1: {"entity_1": true, "entity_2": true, "entity_3": false, "active": "entity_2"},
	2: {"entity_1": true, "entity_2": true, "entity_3": false, "active": "entity_1"},
}

var tween: Tween

enum signalType {
	Start, End
}

func _ready() -> void:
	var is_done = db.query("SELECT is_done FROM checklist WHERE chapter = %s" % current_chapter_id)
	if is_done.data[0].is_done:
		advance_to_next_chapter()
		isChapter_Done.emit(current_chapter_id)
#
	hide()
	GameManager.allow_cursor_click = false
	load_chapter(current_chapter_id)
	
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
	
func trigger_signal(value : signalType) -> void:
	match value:
		signalType.Start:
			var is_done = db.query("SELECT is_done FROM checklist WHERE chapter = %s" % current_chapter_id)
			if !is_done.data[0].is_done:
				show()
		signalType.End:
			#if nex_pos:
				#GameManager.arith_goto = nex_pos.global_position
				#GameManager.target_location = nex_pos
			if _optional:
				_optional._trigger(StarterHandBook.SignalType.Open)
			await get_tree().process_frame
			#queue_free()
			hide()
			


func update_entity_visibility(current_idx: int) -> void:
	if index_visibility_overrides.has(current_idx):
		var overrides = index_visibility_overrides[current_idx]
		
		if overrides.has("entity_1"): entity_1.visible = overrides["entity_1"]
		if overrides.has("entity_2"): entity_2.visible = overrides["entity_2"]
		if overrides.has("entity_3"): entity_3.visible = overrides["entity_3"]
		
		entity_1.modulate = darken
		entity_2.modulate = darken
		entity_3.modulate = darken
		
		if overrides.has("active"):
			match overrides["active"]:
				"entity_1": entity_1.modulate = normal
				"entity_2": entity_2.modulate = normal
				"entity_3": entity_3.modulate = normal
		else:
			# {to-do} Handle edge cases if a narrator speaks and all entities should be darkened or hidden
			pass


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
			update_entity_visibility(dialogue_index)
			
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
			
			update_entity_visibility(dialogue_index)
			
		dialogue_index += 1


func advance_to_next_chapter() -> void:
	isChapter_Done.emit(current_chapter_id)
	var next_id = StoryLineManager.get_next_node(current_chapter_id)
	GameManager.current_chapter_id = next_id
	GameManager.allow_cursor_click = true
	trigger_signal(signalType.End)
	

func _on_next_pressed() -> void:
	if tween and tween.is_running():
		tween.kill()
		text_label.visible_characters = -1
	else:
		show_next_dialogue()


func _on_previous_pressed() -> void:
	show_previous_dialogue()
