extends Control
class_name FinalPart

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

@export_group("TTS")
@export var tts_enabled: bool = true
@export var auto_advance: bool = true
@export var auto_advance_delay: float = 0.6 
@export var tts_volume: int = 80      
@export var tts_pitch: float = 1.0
@export var tts_rate: float = 1.0
@export var tts_language: String = "en"

var tts_voice_id: String = ""
var tts_utterance_id: int = 0 

const bg1 = preload("res://assets/ui/bg/innerview_school.jpg")

var darken : Color = Color("212121ff")
var normal : Color = Color("ffffffff")
var current_chapter_id: String = "victory_epilogue"
var current_dialogues: Array = []
var dialogue_index: int = 0

var tween: Tween

var index_visibility_overrides: Dictionary = {
	0: {"entity_1": false, "entity_2": false, "entity_3": false, "active": "entity_3"},
	1: {"entity_1": false, "entity_2": false, "entity_3": false, "active": "entity_2"},
	2: {"entity_1": false, "entity_2": false, "entity_3": false, "active": "entity_1"},
}

enum signalType {
	Start, End
}

@export var default_bg_color : Color

func _ready() -> void:
	_setup_tts()
	RenderingServer.set_default_clear_color(default_bg_color)
	var is_done = db.query("SELECT is_done FROM checklist WHERE chapter = %s" % current_chapter_id)
	if is_done.data[0].is_done:
		advance_to_next_chapter()
		isChapter_Done.emit(current_chapter_id)
#
	hide()
	GameManager.allow_cursor_click = false
	load_chapter(current_chapter_id)
	
	GameManager.current_chapter_id = current_chapter_id
	
	show()
	
	
	MusicPlayer.play_playlist([
		preload("res://assets/audio/ending_Beyond_the_Valley_s_Edge.mp3"),
		preload("res://assets/audio/ending_Beneath_the_Winding_Road.mp3"),
	])

func _setup_tts() -> void:
	var voices := DisplayServer.tts_get_voices_for_language(tts_language)
	if voices.is_empty():
		voices = DisplayServer.tts_get_voices()
	if not voices.is_empty():
		tts_voice_id = voices[0]
	else:
		push_warning("No TTS voices available, using timed auto-advance instead.")
	
	DisplayServer.tts_set_utterance_callback(
		DisplayServer.TTS_UTTERANCE_ENDED, _on_tts_ended
	)


func speak_line(dialogue_text: String) -> void:
	if not tts_enabled:
		return
	
	tts_utterance_id += 1
	var my_id := tts_utterance_id
	
	# Strip BBCode so tags aren't read aloud
	var clean_text := text_label.get_parsed_text()
	
	DisplayServer.tts_stop()
	
	if tts_voice_id != "":
		DisplayServer.tts_speak(
			clean_text, tts_voice_id, tts_volume, tts_pitch, tts_rate, my_id, true
		)
	elif auto_advance:
		# Fallback when the platform has no TTS: wait roughly reading time
		var fallback_time := maxf(1.5, clean_text.length() * 0.06)
		await get_tree().create_timer(fallback_time).timeout
		_on_tts_ended(my_id)


func _on_tts_ended(utterance_id: int) -> void:
	# Ignore stale callbacks from lines the player already skipped
	if utterance_id != tts_utterance_id or not auto_advance:
		return
	
	await get_tree().create_timer(auto_advance_delay).timeout
	
	# Player may have skipped during the delay
	if utterance_id != tts_utterance_id:
		return
	
	show_next_dialogue()


func stop_tts() -> void:
	tts_utterance_id += 1   # invalidates any pending callbacks
	DisplayServer.tts_stop()


func _exit_tree() -> void:
	stop_tts()
	DisplayServer.tts_set_utterance_callback(
		DisplayServer.TTS_UTTERANCE_ENDED, Callable()
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
			get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
			


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


func start_typewriter(dialogue_text: String) -> void:
	text_label.text = dialogue_text
	text_label.visible_characters = -1  # show all characters
	
	speak_line(dialogue_text) 
	
	if tween and tween.is_valid():
		tween.kill()
	
	text_label.modulate.a = 0.0
	
	tween = create_tween()
	var fade_duration: float = 1.5
	
	tween.tween_property(text_label, "modulate:a", 1.0, fade_duration)

func advance_to_next_chapter() -> void:
	isChapter_Done.emit(current_chapter_id)
	var next_id = StoryLineManager.get_next_node(current_chapter_id)
	GameManager.current_chapter_id = next_id
	GameManager.allow_cursor_click = true
	trigger_signal(signalType.End)
	

func _on_next_pressed() -> void:
	if tween and tween.is_running():
		tween.kill()
		MusicPlayer.one_shot = false
		text_label.visible_characters = -1
	else:
		stop_tts()
		show_next_dialogue()


func _on_previous_pressed() -> void:
	stop_tts()
	show_previous_dialogue()
