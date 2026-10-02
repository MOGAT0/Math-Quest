extends Control
class_name Scholl

signal class_end(currentGrade: String, currentLesson : String)

@export var current_lesson : String = "g1-l1"
@export var current_grade : String = "g1"

@export_range(0.5, 3.0, 0.05) var font_scale : float = 1.0
@export_range(0.5, 3.0, 0.05) var icon_scale : float = 1.0

const _NUMBER_WORDS := [
	"zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine",
	"ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen",
	"seventeen", "eighteen", "nineteen"
]
const _TENS_WORDS := ["", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety"]



var lesson_database : Dictionary = {}

var main_container : VBoxContainer
var top_bar : HBoxContainer
var progress_bar : ProgressBar
var title_label : Label
var lecture_display : RichTextLabel
var exam_container : VBoxContainer
var action_button : Button
var next_button : Button
var bottom_buttons : HBoxContainer
var options_grid : GridContainer

var lesson_complete_container : VBoxContainer 
var lesson_complete_label : Label
var bottom_panel_margin : MarginContainer

const LESSONS_PER_GRADE := 10

var lecture_container : VBoxContainer
var lecture_title_label : Label
var lecture_continue_button : Button
var lecture_replay_button : Button

var root_bg : ColorRect

const TYPEWRITER_CHAR_DELAY := 0.045
var _tw_timer : Timer = null
var _tw_target : RichTextLabel = null
var _tts_voice_id : String = ""

var current_question_idx : int = 0
var selected_answer : String = ""
var exam_status : String = "idle"
var current_lesson_data : Dictionary
var option_buttons : Array = []

var _lesson_available : bool = false

# --- Relearn feature ---
var relearn_button : Button
var relearn_container : VBoxContainer
var relearn_grades_vbox : VBoxContainer
var relearn_grid_scroll : ScrollContainer


var _is_relearning : bool = false


const COLOR_WHITE = Color("#f7ead0")  
const COLOR_SLATE_200 = Color("#d9c48f")
const COLOR_SLATE_300 = Color("#c2a668")
const COLOR_SLATE_400 = Color("#8a7147")
const COLOR_SLATE_700 = Color("#3b2a1a")
const COLOR_SLATE_800 = Color("#241a10")
const COLOR_BLUE_50 = Color("#f3e2b8")
const COLOR_BLUE_500 = Color("#8a1f1f")
const COLOR_BLUE_600 = Color("#5c1414")
const COLOR_GREEN_50 = Color("#e8f0e2")
const COLOR_GREEN_500 = Color("#2f5233")
const COLOR_RED_50 = Color("#f7e3df")
const COLOR_RED_500 = Color("#8c2f1a")    
const COLOR_AMBER_100 = Color("#f0dfa0")  
const COLOR_AMBER_500 = Color("#a8781a")  

## Scales a base font size by the global font_scale.
func _fs(base: int) -> int:
	return roundi(base * font_scale)

## Scales a base icon/visual size by the global icon_scale.
func _ics(base: float) -> float:
	return base * icon_scale

func _ready() -> void:
	_load_active_curriculum()
	_setup_database()
	_build_ui_nodes()
	_prepare_tts()
	


	_lesson_available = _lesson_exists(current_grade, current_lesson)

	hide()
	#start_class()

func _load_active_curriculum():
	var curriculum = db.query("SELECT current_grade, current_lesson FROM progress WHERE is_active = true LIMIT 1")
	var data = curriculum.data[0]
	current_grade = data.current_grade
	current_lesson = data.current_lesson

func start_class() -> void:
	_load_active_curriculum()
	show()
	GameManager.game_time_enabled = false
	if _lesson_available:
		_start_lesson()
	else:
		current_lesson_data = {}
		_show_curriculum_complete()
	
func _setup_database() -> void:
	var file_path = "res://data/curriculum.json"
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var error = json.parse(json_string)
		
		if error == OK:
			var data = json.get_data()
			if typeof(data) == TYPE_DICTIONARY:
				lesson_database = data
			else:
				push_error("Parsed JSON is not a dictionary.")
		else:
			push_error("JSON Parse Error: ", json.get_error_message())
	else:
		push_error("Curriculum file not found at: ", file_path)

func _build_ui_nodes() -> void:
	main_container = VBoxContainer.new()
	main_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_container.add_theme_constant_override("separation", 20)
	
	root_bg = ColorRect.new()
	root_bg.color = COLOR_WHITE
	root_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root_bg)
	add_child(main_container)

	var top_margin = MarginContainer.new()
	top_margin.add_theme_constant_override("margin_top", 20)
	top_margin.add_theme_constant_override("margin_left", 20)
	top_margin.add_theme_constant_override("margin_right", 20)
	main_container.add_child(top_margin)
	
	top_bar = HBoxContainer.new()
	top_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	top_margin.add_child(top_bar)
	
	progress_bar = ProgressBar.new()
	progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_bar.custom_minimum_size = Vector2(0, 12)
	progress_bar.show_percentage = false
	
	var pb_bg = StyleBoxFlat.new()
	pb_bg.bg_color = COLOR_SLATE_200
	pb_bg.corner_radius_top_left = 10
	pb_bg.corner_radius_bottom_right = 10
	pb_bg.corner_radius_top_right = 10
	pb_bg.corner_radius_bottom_left = 10
	pb_bg.border_width_top = 1
	pb_bg.border_width_bottom = 1
	pb_bg.border_color = COLOR_AMBER_500
	
	var pb_fill = pb_bg.duplicate()
	pb_fill.bg_color = COLOR_AMBER_500
	pb_fill.border_color = COLOR_SLATE_800
	
	progress_bar.add_theme_stylebox_override("background", pb_bg)
	progress_bar.add_theme_stylebox_override("fill", pb_fill)
	top_bar.add_child(progress_bar)

	exam_container = VBoxContainer.new()
	exam_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	exam_container.add_theme_constant_override("separation", 20)
	
	var content_margin = MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", 40)
	content_margin.add_theme_constant_override("margin_right", 40)
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_container.add_child(content_margin)

	var exam_scroll = ScrollContainer.new()
	exam_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exam_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	exam_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_margin.add_child(exam_scroll)

	exam_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exam_scroll.add_child(exam_container)

	title_label = Label.new()
	title_label.text = "Decipher the Incantation"
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", COLOR_SLATE_800)
	exam_container.add_child(title_label)
	
	options_grid = GridContainer.new()
	options_grid.columns = 2
	options_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options_grid.add_theme_constant_override("h_separation", 15)
	options_grid.add_theme_constant_override("v_separation", 15)

	lesson_complete_container = VBoxContainer.new()
	lesson_complete_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	lesson_complete_container.alignment = BoxContainer.ALIGNMENT_CENTER
	lesson_complete_container.add_theme_constant_override("separation", 20)
	lesson_complete_container.hide()
	add_child(lesson_complete_container)
	
	var trophy_bg = PanelContainer.new()
	var trophy_style = StyleBoxFlat.new()
	trophy_style.bg_color = COLOR_AMBER_100
	trophy_style.corner_radius_top_left = 60
	trophy_style.corner_radius_bottom_right = 60
	trophy_style.corner_radius_top_right = 60
	trophy_style.corner_radius_bottom_left = 60
	trophy_style.border_width_left = 3
	trophy_style.border_width_top = 3
	trophy_style.border_width_right = 3
	trophy_style.border_width_bottom = 3
	trophy_style.border_color = COLOR_AMBER_500
	trophy_bg.add_theme_stylebox_override("panel", trophy_style)
	trophy_bg.custom_minimum_size = Vector2(120, 120)
	trophy_bg.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	trophy_bg.mouse_filter = Control.MOUSE_FILTER_PASS
	lesson_complete_container.add_child(trophy_bg)
	
	var trophy_icon = TextureRect.new()
	trophy_icon.texture = load("res://assets/trophy.svg")
	trophy_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	trophy_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	trophy_bg.add_child(trophy_icon)
	
	lesson_complete_label = Label.new()
	lesson_complete_label.text = "Spell Mastered!"
	lesson_complete_label.add_theme_font_size_override("font_size", 32)
	lesson_complete_label.add_theme_color_override("font_color", COLOR_AMBER_500)
	lesson_complete_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lesson_complete_container.add_child(lesson_complete_label)

	relearn_button = Button.new()
	relearn_button.text = "Relearn a Spell"
	relearn_button.custom_minimum_size = Vector2(260, 46)
	relearn_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	relearn_button.add_theme_font_size_override("font_size", 18)
	_style_solid_button(relearn_button, COLOR_AMBER_100, COLOR_AMBER_500, COLOR_SLATE_800)
	relearn_button.pressed.connect(_show_relearn_grid)
	relearn_button.hide()
	lesson_complete_container.add_child(relearn_button)

	var bottom_panel = PanelContainer.new()
	var bp_style = StyleBoxFlat.new()
	bp_style.bg_color = COLOR_WHITE
	bp_style.border_width_top = 2
	bp_style.border_color = COLOR_SLATE_200
	bottom_panel.add_theme_stylebox_override("panel", bp_style)
	bottom_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	main_container.add_child(bottom_panel)
	
	bottom_panel_margin = MarginContainer.new()
	bottom_panel_margin.add_theme_constant_override("margin_top", 15)
	bottom_panel_margin.add_theme_constant_override("margin_bottom", 15)
	bottom_panel_margin.add_theme_constant_override("margin_left", 40)
	bottom_panel_margin.add_theme_constant_override("margin_right", 40)
	bottom_panel.add_child(bottom_panel_margin)

	bottom_buttons = HBoxContainer.new()
	bottom_buttons.alignment = BoxContainer.ALIGNMENT_END
	bottom_buttons.add_theme_constant_override("separation", 15)
	bottom_panel_margin.add_child(bottom_buttons)

	action_button = Button.new()
	action_button.text = "CAST"
	action_button.custom_minimum_size = Vector2(150, 50)
	action_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	action_button.pressed.connect(_on_action_button_pressed)
	bottom_buttons.add_child(action_button)

	next_button = Button.new()
	next_button.text = "NEXT SPELL"
	next_button.custom_minimum_size = Vector2(150, 50)
	next_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	next_button.disabled = true
	next_button.pressed.connect(_on_next_button_pressed)
	bottom_buttons.add_child(next_button)

	_build_lecture_nodes()
	_build_relearn_nodes()

func _build_lecture_nodes() -> void:
	lecture_container = VBoxContainer.new()
	lecture_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	lecture_container.add_theme_constant_override("separation", 0)
	lecture_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lecture_container.hide()
	add_child(lecture_container)

	# --- Transparent stage area (the game scene shows through here) ---
	var stage_area = VBoxContainer.new()
	stage_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_area.add_theme_constant_override("separation", 0)
	stage_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lecture_container.add_child(stage_area)

	var stage_spacer = Control.new()
	stage_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_area.add_child(stage_spacer)

	# --- Buttons float above the divider, right aligned ---
	var buttons_margin = MarginContainer.new()
	buttons_margin.add_theme_constant_override("margin_right", 40)
	buttons_margin.add_theme_constant_override("margin_bottom", 22)
	buttons_margin.add_theme_constant_override("margin_left", 40)
	buttons_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_area.add_child(buttons_margin)

	var lbp_hbox = HBoxContainer.new()
	lbp_hbox.alignment = BoxContainer.ALIGNMENT_END
	lbp_hbox.add_theme_constant_override("separation", 22)
	lbp_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buttons_margin.add_child(lbp_hbox)

	lecture_replay_button = Button.new()
	lecture_replay_button.text = "Read Again"
	lecture_replay_button.custom_minimum_size = Vector2(190, 62)
	lecture_replay_button.add_theme_font_size_override("font_size", 24)
	lecture_replay_button.pressed.connect(_on_lecture_replay_pressed)
	_style_lecture_button(lecture_replay_button, COLOR_BLUE_50, COLOR_AMBER_500, COLOR_SLATE_800)
	lbp_hbox.add_child(lecture_replay_button)

	lecture_continue_button = Button.new()
	lecture_continue_button.text = "Begin Trial ->"
	lecture_continue_button.custom_minimum_size = Vector2(230, 62)
	lecture_continue_button.add_theme_font_size_override("font_size", 24)
	lecture_continue_button.pressed.connect(_on_lecture_continue_pressed)
	_style_lecture_button(lecture_continue_button, COLOR_BLUE_500, COLOR_WHITE, COLOR_WHITE)
	lbp_hbox.add_child(lecture_continue_button)

	# --- Bottom parchment panel with the teacher's script ---
	var lecture_bottom_panel = PanelContainer.new()
	var lbp_style = StyleBoxFlat.new()
	lbp_style.bg_color = COLOR_WHITE
	lbp_style.border_width_top = 4
	lbp_style.border_color = COLOR_AMBER_500
	lecture_bottom_panel.add_theme_stylebox_override("panel", lbp_style)
	lecture_bottom_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	lecture_container.add_child(lecture_bottom_panel)

	var lbp_margin = MarginContainer.new()
	lbp_margin.add_theme_constant_override("margin_top", 18)
	lbp_margin.add_theme_constant_override("margin_bottom", 18)
	lbp_margin.add_theme_constant_override("margin_left", 32)
	lbp_margin.add_theme_constant_override("margin_right", 32)
	lecture_bottom_panel.add_child(lbp_margin)

	var lecture_vbox = VBoxContainer.new()
	lecture_vbox.add_theme_constant_override("separation", 8)
	lbp_margin.add_child(lecture_vbox)

	lecture_title_label = Label.new()
	lecture_title_label.add_theme_font_size_override("font_size", _fs(20))
	lecture_title_label.add_theme_color_override("font_color", COLOR_SLATE_800)
	lecture_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lecture_vbox.add_child(lecture_title_label)

	var lecture_scroll = ScrollContainer.new()
	lecture_scroll.custom_minimum_size = Vector2(0, 300)
	lecture_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lecture_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lecture_vbox.add_child(lecture_scroll)
	lecture_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER

	lecture_display = RichTextLabel.new()
	lecture_display.scroll_following = true
	lecture_display.bbcode_enabled = false
	lecture_display.fit_content = true
	lecture_display.scroll_active = false
	lecture_display.selection_enabled = false
	lecture_display.add_theme_font_size_override("normal_font_size", _fs(14))
	lecture_display.add_theme_color_override("default_color", COLOR_SLATE_800)
	lecture_display.add_theme_constant_override("line_separation", 2)
	lecture_display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lecture_display.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lecture_display.gui_input.connect(_on_lecture_display_input)
	lecture_scroll.add_child(lecture_display)

func _build_relearn_nodes() -> void:
	relearn_container = VBoxContainer.new()
	relearn_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	relearn_container.add_theme_constant_override("separation", 16)
	relearn_container.hide()
	add_child(relearn_container)

	var header_margin = MarginContainer.new()
	header_margin.add_theme_constant_override("margin_top", 20)
	header_margin.add_theme_constant_override("margin_left", 20)
	header_margin.add_theme_constant_override("margin_right", 20)
	relearn_container.add_child(header_margin)

	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 20)
	header_margin.add_child(header_hbox)

	var back_btn = Button.new()
	back_btn.text = "<- Back"
	back_btn.custom_minimum_size = Vector2(120, 44)
	_style_solid_button(back_btn, COLOR_SLATE_200, COLOR_SLATE_300, COLOR_SLATE_800)
	back_btn.pressed.connect(_on_relearn_back_pressed)
	header_hbox.add_child(back_btn)

	var header_label = Label.new()
	header_label.text = "Choose a Spell to Relearn"
	header_label.add_theme_font_size_override("font_size", 22)
	header_label.add_theme_color_override("font_color", COLOR_SLATE_800)
	header_hbox.add_child(header_label)

	var body_margin = MarginContainer.new()
	body_margin.add_theme_constant_override("margin_left", 40)
	body_margin.add_theme_constant_override("margin_right", 40)
	body_margin.add_theme_constant_override("margin_bottom", 20)
	body_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	relearn_container.add_child(body_margin)

	relearn_grid_scroll = ScrollContainer.new()
	relearn_grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	relearn_grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_margin.add_child(relearn_grid_scroll)

	relearn_grades_vbox = VBoxContainer.new()
	relearn_grades_vbox.add_theme_constant_override("separation", 18)
	relearn_grades_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	relearn_grid_scroll.add_child(relearn_grades_vbox)

func _style_lecture_button(btn: Button, bg: Color, border: Color, font_color: Color) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	btn.add_theme_stylebox_override("normal", style)

	var hover_style = style.duplicate()
	hover_style.bg_color = bg.lightened(0.08)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("focus", style)

	var pressed_style = style.duplicate()
	pressed_style.bg_color = bg.darkened(0.12)
	btn.add_theme_stylebox_override("pressed", pressed_style)

	btn.add_theme_color_override("font_color", font_color)
	btn.add_theme_color_override("font_hover_color", font_color)
	btn.add_theme_color_override("font_pressed_color", font_color)
	btn.add_theme_color_override("font_focus_color", font_color)

func _style_solid_button(btn: Button, bg: Color, border: Color, font_color: Color) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 4
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("focus", style)
	var pressed_style = style.duplicate()
	pressed_style.border_width_bottom = 0
	pressed_style.content_margin_top = 4
	btn.add_theme_stylebox_override("pressed", pressed_style)
	btn.add_theme_color_override("font_color", font_color)

func _show_lecture() -> void:
	lesson_complete_container.hide()
	main_container.hide()
	if root_bg:
		root_bg.hide()
	lecture_container.show()

	lecture_title_label.text = str(current_lesson_data.get("title", ""))
	var lecture_text = str(current_lesson_data.get("lecture", ""))
	_typewrite_and_speak(lecture_display, lecture_text)

func _on_lecture_continue_pressed() -> void:
	_cancel_typewriter()
	lecture_container.hide()
	if root_bg:
		root_bg.show()
	main_container.show()
	current_question_idx = 0
	_load_current_question()

func _on_lecture_replay_pressed() -> void:
	var lecture_text = str(current_lesson_data.get("lecture", ""))
	_typewrite_and_speak(lecture_display, lecture_text)

func _on_lecture_display_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_skip_typewriter()

func _get_male_english_voice() -> String:
	var all_voices = DisplayServer.tts_get_voices()

	for voice in all_voices:
		if voice["language"].begins_with("en") and "male" in voice["name"].to_lower():
			return voice["id"]
			
	return ""

func _prepare_tts() -> void:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		return
		
	# Added: Call the helper function to search for a male voice ID
	var male_voice_id = _get_male_english_voice()
	
	# Added: Check if a male voice was successfully found
	if male_voice_id != "":
		# Added: Assign the specific male voice to your variable
		_tts_voice_id = male_voice_id
	else:
		# Added: Fallback to the original logic if no male voice exists on the phone
		var voices = DisplayServer.tts_get_voices_for_language("en")
		if voices.size() > 0:
			_tts_voice_id = voices[0]

#func _prepare_tts() -> void:
	#if not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		#return
	#var voices = DisplayServer.tts_get_voices_for_language("en")
	#if voices.size() > 0:
		#_tts_voice_id = voices[0]

func _number_to_word(n: int) -> String:
	if n < 0:
		return str(n)
	if n < 20:
		return _NUMBER_WORDS[n]
	if n < 100:
		var tens: String = _TENS_WORDS[n / 10]
		var ones := n % 10
		return tens if ones == 0 else "%s %s" % [tens, _NUMBER_WORDS[ones]]
	return str(n)
	
func _speak(text: String) -> void:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		return
	DisplayServer.tts_stop()
	DisplayServer.tts_speak(text, _tts_voice_id, 90, 1.0, 1.0, 0, true)

func _cancel_typewriter() -> void:
	if _tw_timer and is_instance_valid(_tw_timer):
		_tw_timer.stop()
		_tw_timer.queue_free()
	_tw_timer = null
	_tw_target = null
	if DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		DisplayServer.tts_stop()

func _skip_typewriter() -> void:
	if _tw_target and is_instance_valid(_tw_target):
		_tw_target.visible_characters = -1
	_cancel_typewriter()

func _typewrite_and_speak(rt: RichTextLabel, text: String, on_done: Callable = Callable()) -> void:
	_cancel_typewriter()

	rt.text = text
	rt.visible_characters = 0
	if text.is_empty():
		return

	_tw_target = rt
	_speak(text)

	var total_chars = text.length()
	var timer = Timer.new()
	timer.wait_time = TYPEWRITER_CHAR_DELAY
	timer.one_shot = false
	add_child(timer)
	_tw_timer = timer

	timer.timeout.connect(func():
		rt.visible_characters += 1
		if rt.visible_characters >= total_chars:
			rt.visible_characters = -1
			timer.stop()
			timer.queue_free()
			if _tw_timer == timer:
				_tw_timer = null
				_tw_target = null
			if on_done.is_valid():
				on_done.call()
	)
	timer.start()

func _start_lesson() -> void:
	
	current_lesson_data = {}
	if not lesson_database.has(current_grade): return
	var grade_lessons = lesson_database[current_grade]
	for lesson in grade_lessons:
		if lesson.has("id") and lesson["id"] == current_lesson:
			current_lesson_data = lesson
			break
			
	if current_lesson_data.is_empty(): return

	# The action button may still be sitting inside lesson_complete_container
	# from a previous lesson's trophy screen - put it back in the normal
	# lesson footer before presenting anything.
	if action_button.get_parent() != bottom_buttons:
		if action_button.get_parent():
			action_button.get_parent().remove_child(action_button)
		bottom_buttons.add_child(action_button)
		bottom_buttons.move_child(action_button, 0)   # keep CAST on the left of NEXT
	action_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	action_button.custom_minimum_size = Vector2(150, 50)

	main_container.hide()
	lesson_complete_container.hide()
	current_question_idx = 0
	_show_lecture()

func _load_current_question() -> void:
	exam_status = "idle"
	selected_answer = ""
	_update_action_button()
	
	var questions = current_lesson_data.get("questions", [])
	if current_question_idx >= questions.size():
		_show_lesson_complete()
		return
		
	var q = questions[current_question_idx]
	progress_bar.value = (float(current_question_idx) / questions.size()) * 100.0
	
	for child in exam_container.get_children():
		if child != title_label and child != options_grid: 
			child.queue_free()
	
	for child in options_grid.get_children():
		child.queue_free()
	option_buttons.clear()
		
	var q_card = PanelContainer.new()
	var qc_style = StyleBoxFlat.new()
	qc_style.bg_color = COLOR_BLUE_50
	qc_style.corner_radius_top_left = 14
	qc_style.corner_radius_bottom_right = 14
	qc_style.corner_radius_top_right = 14
	qc_style.corner_radius_bottom_left = 14
	qc_style.border_width_left = 2
	qc_style.border_width_top = 2
	qc_style.border_width_right = 2
	qc_style.border_width_bottom = 2
	qc_style.content_margin_left = 24
	qc_style.content_margin_right = 24
	qc_style.content_margin_top = 24
	qc_style.content_margin_bottom = 24
	qc_style.border_color = COLOR_AMBER_500
	q_card.add_theme_stylebox_override("panel", qc_style)
	q_card.mouse_filter = Control.MOUSE_FILTER_PASS
	exam_container.add_child(q_card)
	
	var q_margin = MarginContainer.new()
	q_margin.add_theme_constant_override("margin_all", 24)
	q_card.add_child(q_margin)
	
	var q_vbox = VBoxContainer.new()
	q_vbox.add_theme_constant_override("separation", 20)
	q_margin.add_child(q_vbox)
	
	var q_label = RichTextLabel.new()
	q_label.bbcode_enabled = false
	q_label.fit_content = true
	q_label.scroll_active = false
	q_label.selection_enabled = false
	q_label.add_theme_font_size_override("normal_font_size", _fs(16))
	q_label.add_theme_color_override("default_color", COLOR_SLATE_800)
	q_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	q_label.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			_skip_typewriter()
	)
	q_vbox.add_child(q_label)
	_typewrite_and_speak(q_label, str(q["text"]))
	
	if q.has("visual"):
		_build_visual(q["visual"], q_vbox, str(q.get("answer", "")))

	if options_grid.get_parent():
		options_grid.get_parent().remove_child(options_grid)
	exam_container.add_child(options_grid)
	
	var opts = _get_options(q)
	for i in range(opts.size()):
		var btn = Button.new()
		btn.text = opts[i]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 60)
		btn.add_theme_font_size_override("font_size", _fs(18))
		btn.add_theme_color_override("font_color", COLOR_SLATE_800)
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		btn.pressed.connect(_on_option_selected.bind(opts[i]))
		options_grid.add_child(btn)
		option_buttons.append(btn)
		
	_refresh_option_styles()


func _build_visual(visual_data: Dictionary, parent: Container, answer_str: String = "") -> void:
	if not visual_data.has("type"): return
	var v_type = visual_data["type"]

	if v_type == "grid" and visual_data.has("items"):
		_build_grid_visual(visual_data["items"], parent)
	elif v_type == "groups" and visual_data.has("groups"):
		_build_groups_visual(visual_data["groups"], parent)
	elif v_type == "sequence" and visual_data.has("sequence"):
		_build_sequence_visual(visual_data["sequence"], parent, answer_str)
	elif v_type == "balance" and visual_data.has("leftItems") and visual_data.has("rightItems"):
		_build_balance_visual(visual_data["leftItems"], visual_data["rightItems"], parent)

func _pop_animation(ctrl: Control) -> void:
	ctrl.scale = Vector2(1.28, 1.28)
	var tw = create_tween()
	tw.tween_property(ctrl, "scale", Vector2(1.0, 1.0), 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _flash_animation(ctrl: CanvasItem) -> void:
	ctrl.modulate = Color(1.35, 1.3, 1.1)
	var tw = create_tween()
	tw.tween_property(ctrl, "modulate", Color(1, 1, 1), 0.3).set_trans(Tween.TRANS_SINE)

func _pulse_animation(ctrl: CanvasItem) -> void:
	var tw = create_tween()
	tw.set_loops()
	tw.tween_property(ctrl, "modulate:a", 0.5, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(ctrl, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)

func _make_flow(h_sep: int = 12, v_sep: int = 12) -> HFlowContainer:
	var flow = HFlowContainer.new()
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.add_theme_constant_override("h_separation", h_sep)
	flow.add_theme_constant_override("v_separation", v_sep)
	return flow

func _make_hint_label(text: String) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", COLOR_SLATE_700)
	return lbl

func _make_icon_chip(display_text: String, iocn_size: float = 52.0, font_size: int = 24) -> Button:
	var chip_size := _ics(iocn_size)
	var btn = Button.new()
	btn.text = display_text
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(chip_size, chip_size)
	btn.pivot_offset = Vector2(chip_size, chip_size) / 2.0
	btn.add_theme_font_size_override("font_size", roundi(_ics(font_size)))

	var normal = StyleBoxFlat.new()
	normal.bg_color = COLOR_WHITE
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.border_color = COLOR_SLATE_300
	normal.corner_radius_top_left = 10
	normal.corner_radius_top_right = 10
	normal.corner_radius_bottom_left = 10
	normal.corner_radius_bottom_right = 10
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", normal)
	btn.add_theme_stylebox_override("focus", normal)

	var pressed_style = normal.duplicate()
	pressed_style.bg_color = COLOR_BLUE_50
	pressed_style.border_color = COLOR_BLUE_500
	btn.add_theme_stylebox_override("pressed", pressed_style)
	btn.add_theme_stylebox_override("hover_pressed", pressed_style)

	return btn

func _build_grid_visual(items: Array, parent: Container) -> void:
	var total := 0
	for item in items:
		total += int(item.get("count", 0))

	var tally = _make_hint_label("Tap each charm as you count it! (0 / %d)" % total)
	#parent.add_child(tally)

	var flow = _make_flow()
	parent.add_child(flow)

	var counted := {"n": 0}
	for item in items:
		var icon = str(item.get("icon", "❔"))
		for i in range(int(item.get("count", 0))):
			var chip = _make_icon_chip(icon)
			chip.toggle_mode = true
			chip.toggled.connect(func(is_on: bool):
				counted["n"] += 1 if is_on else -1
				tally.text = "Tap each charm as you count it! (%d / %d)" % [counted["n"], total]
				_pop_animation(chip)
				# Say the running count when a charm is counted
				if is_on:
					_speak(_number_to_word(counted["n"]))
			)
			flow.add_child(chip)

func _build_groups_visual(group_data: Dictionary, parent: Container) -> void:
	var icon = str(group_data.get("icon", "❔"))
	var count = int(group_data.get("count", 0))
	var per_group = int(group_data.get("itemsPerGroup", 0))
	var total = count * per_group

	var tally = _make_hint_label("Tap a bundle to count by %d! (0 / %d)" % [per_group, total])
	#parent.add_child(tally)

	var flow = _make_flow(15, 15)
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(flow)

	# Lay each bundle out as a neat grid (e.g. 10 -> 5 x 2, 6 -> 3 x 2)
	var columns: int = per_group if per_group <= 5 else int(ceil(per_group / 2.0))
	columns = max(columns, 1)

	var selected := {"n": 0}
	for g in range(count):
		# PanelContainer sizes itself to its contents (a Button does NOT),
		# so the bundle now reserves real space instead of overlapping the options.
		var bundle = PanelContainer.new()
		bundle.mouse_filter = Control.MOUSE_FILTER_PASS
		bundle.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

		var normal = StyleBoxFlat.new()
		normal.bg_color = COLOR_WHITE
		normal.set_border_width_all(2)
		normal.border_color = COLOR_SLATE_300
		normal.set_corner_radius_all(14)

		var pressed_style = normal.duplicate()
		pressed_style.bg_color = COLOR_GREEN_50
		pressed_style.border_color = COLOR_GREEN_500

		# Bottom layer: the tappable button, stretched over the whole bundle
		var group_btn = Button.new()
		group_btn.text = ""
		group_btn.toggle_mode = true
		group_btn.focus_mode = Control.FOCUS_NONE
		group_btn.add_theme_stylebox_override("normal", normal)
		group_btn.add_theme_stylebox_override("hover", normal)
		group_btn.add_theme_stylebox_override("focus", normal)
		group_btn.add_theme_stylebox_override("pressed", pressed_style)
		group_btn.add_theme_stylebox_override("hover_pressed", pressed_style)
		bundle.add_child(group_btn)

		# Top layer: the icons (ignores the mouse so clicks reach the button)
		var margin = MarginContainer.new()
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_theme_constant_override("margin_left", 10)
		margin.add_theme_constant_override("margin_right", 10)
		margin.add_theme_constant_override("margin_top", 10)
		margin.add_theme_constant_override("margin_bottom", 10)
		bundle.add_child(margin)

		var grid = GridContainer.new()
		grid.columns = columns
		grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.add_theme_constant_override("h_separation", 4)
		grid.add_theme_constant_override("v_separation", 4)
		margin.add_child(grid)

		for i in range(per_group):
			var lbl = Label.new()
			lbl.text = icon
			lbl.custom_minimum_size = Vector2(_ics(30), _ics(30))
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lbl.add_theme_font_size_override("font_size", roundi(_ics(20)))
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			grid.add_child(lbl)

		group_btn.toggled.connect(func(is_on: bool):
			selected["n"] += 1 if is_on else -1
			var counted_total = selected["n"] * per_group
			tally.text = "Tap a bundle to count by %d! (%d / %d)" % [per_group, counted_total, total]
			_flash_animation(bundle)
		)
		flow.add_child(bundle)

func _build_sequence_visual(sequence: Array, parent: Container, answer_str: String) -> void:
	var is_reorder := answer_str.find(",") != -1
	if is_reorder:
		for token in sequence:
			if not str(token).strip_edges().is_valid_int():
				is_reorder = false
				break

	if is_reorder:
		_build_reorder_sequence(sequence, parent, answer_str)
	else:
		_build_static_sequence(sequence, parent)

func _build_reorder_sequence(sequence: Array, parent: Container, answer_str: String) -> void:
	var target_order : Array = []
	for part in answer_str.split(","):
		target_order.append(part.strip_edges())

	var hint = _make_hint_label("Tap two runes to swap them into place!")
	parent.add_child(hint)

	var flow = _make_flow()
	parent.add_child(flow)

	var chips : Array = []
	var first_pick := {"btn": null}

	var refresh_colors: Callable = func():
		var solved := true
		for i in range(chips.size()):
			var chip : Button = chips[i]
			var is_correct = i < target_order.size() and chip.text.strip_edges() == target_order[i]
			if not is_correct:
				solved = false

			var style = StyleBoxFlat.new()
			style.border_width_left = 2
			style.border_width_top = 2
			style.border_width_right = 2
			style.border_width_bottom = 2
			style.corner_radius_top_left = 10
			style.corner_radius_top_right = 10
			style.corner_radius_bottom_left = 10
			style.corner_radius_bottom_right = 10

			if is_correct:
				style.bg_color = COLOR_GREEN_50
				style.border_color = COLOR_GREEN_500
				chip.add_theme_color_override("font_color", COLOR_GREEN_500)
			else:
				style.bg_color = COLOR_BLUE_50
				style.border_color = COLOR_SLATE_300
				chip.add_theme_color_override("font_color", COLOR_SLATE_800)

			if first_pick["btn"] == chip:
				style.border_color = COLOR_BLUE_500
				style.border_width_left = 4
				style.border_width_top = 4
				style.border_width_right = 4
				style.border_width_bottom = 4

			chip.add_theme_stylebox_override("normal", style)
			chip.add_theme_stylebox_override("hover", style)
			chip.add_theme_stylebox_override("pressed", style)
			chip.add_theme_stylebox_override("focus", style)

		if solved:
			hint.text = "The spell sequence is correct!"
			hint.add_theme_color_override("font_color", COLOR_GREEN_500)
		else:
			hint.text = "Tap two runes to swap them into place!"
			hint.add_theme_color_override("font_color", COLOR_SLATE_700)

	for token in sequence:
		var chip = _make_icon_chip(str(token), 60.0, 22)
		chips.append(chip)
		chip.pressed.connect(func():
			_pop_animation(chip)
			if first_pick["btn"] == null:
				first_pick["btn"] = chip
			elif first_pick["btn"] == chip:
				first_pick["btn"] = null
			else:
				var other : Button = first_pick["btn"]
				var tmp = other.text
				other.text = chip.text
				chip.text = tmp
				first_pick["btn"] = null
			refresh_colors.call()
		)
		flow.add_child(chip)

	refresh_colors.call()

func _build_static_sequence(sequence: Array, parent: Container) -> void:
	var operators = ["+", "-", "x", "×", "÷", "=", "->", "vs", ":"]

	var flow = _make_flow()
	parent.add_child(flow)

	for seq_item in sequence:
		var text = str(seq_item)
		var is_operator = text in operators or text.begins_with("(")
		var is_mystery = text.find("?") != -1 or text == "..."

		var chip = Button.new()
		chip.text = text
		chip.focus_mode = Control.FOCUS_NONE
		chip.custom_minimum_size = Vector2(0, 56)
		chip.add_theme_font_size_override("font_size", 18 if is_operator else 22)

		var style = StyleBoxFlat.new()
		style.content_margin_left = 18
		style.content_margin_right = 18
		style.content_margin_top = 10
		style.content_margin_bottom = 10
		style.corner_radius_top_left = 10
		style.corner_radius_top_right = 10
		style.corner_radius_bottom_left = 10
		style.corner_radius_bottom_right = 10

		if is_mystery:
			style.bg_color = COLOR_AMBER_100
			style.border_width_left = 2
			style.border_width_top = 2
			style.border_width_right = 2
			style.border_width_bottom = 2
			style.border_color = COLOR_AMBER_500
			chip.add_theme_color_override("font_color", COLOR_AMBER_500)
		elif is_operator:
			style.bg_color = COLOR_SLATE_200
			chip.add_theme_color_override("font_color", COLOR_SLATE_700)
		else:
			style.bg_color = COLOR_AMBER_100
			chip.add_theme_color_override("font_color", COLOR_AMBER_500)

		chip.add_theme_stylebox_override("normal", style)
		chip.add_theme_stylebox_override("hover", style)
		chip.add_theme_stylebox_override("focus", style)
		var pressed_style = style.duplicate()
		pressed_style.bg_color = COLOR_BLUE_50
		chip.add_theme_stylebox_override("pressed", pressed_style)

		chip.pressed.connect(func(): _flash_animation(chip))
		flow.add_child(chip)

		if is_mystery:
			_pulse_animation(chip)

const BALANCE_STAGE_WIDTH := 340.0
const BALANCE_STAGE_HEIGHT := 210.0
const BALANCE_BEAM_WIDTH := 220.0
const BALANCE_PAN_WIDTH := 110.0
const BALANCE_BEAM_Y := 70.0
const BALANCE_PAN_Y := 96.0

func _build_balance_visual(left_items: Dictionary, right_items: Dictionary, parent: Container) -> void:
	var left_icon = str(left_items.get("icon", "❔"))
	var left_count = int(left_items.get("count", 0))
	var right_icon = str(right_items.get("icon", "❔"))
	var right_count = int(right_items.get("count", 0))

	# Pans grow with icon_scale; the stage grows with them so nothing is clipped.
	var pan_w := _ics(BALANCE_PAN_WIDTH)
	var stage_w := BALANCE_STAGE_WIDTH + (pan_w - BALANCE_PAN_WIDTH)
	var stage_h := BALANCE_STAGE_HEIGHT + (icon_scale - 1.0) * 80.0

	var beam_x = (stage_w - BALANCE_BEAM_WIDTH) / 2.0
	var beam_left_x = beam_x
	var beam_right_x = beam_x + BALANCE_BEAM_WIDTH
	var center_x = stage_w / 2.0

	var stage = Control.new()
	stage.custom_minimum_size = Vector2(stage_w, stage_h)
	stage.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(stage)

	var base = ColorRect.new()
	base.color = COLOR_AMBER_500
	base.size = Vector2(50, 6)
	base.position = Vector2(center_x - 25, BALANCE_BEAM_Y + 44)
	stage.add_child(base)

	var stand = ColorRect.new()
	stand.color = COLOR_AMBER_500
	stand.size = Vector2(6, 44)
	stand.position = Vector2(center_x - 3, BALANCE_BEAM_Y + 3)
	stage.add_child(stand)

	var beam = ColorRect.new()
	beam.color = COLOR_AMBER_500
	beam.size = Vector2(BALANCE_BEAM_WIDTH, 6)
	beam.position = Vector2(beam_left_x, BALANCE_BEAM_Y)
	beam.pivot_offset = Vector2(BALANCE_BEAM_WIDTH / 2.0, 3)
	stage.add_child(beam)

	var left_string = ColorRect.new()
	left_string.color = COLOR_SLATE_300
	left_string.size = Vector2(2, BALANCE_PAN_Y - BALANCE_BEAM_Y - 6)
	left_string.position = Vector2(beam_left_x - 1, BALANCE_BEAM_Y + 6)
	stage.add_child(left_string)

	var right_string = ColorRect.new()
	right_string.color = COLOR_SLATE_300
	right_string.size = Vector2(2, BALANCE_PAN_Y - BALANCE_BEAM_Y - 6)
	right_string.position = Vector2(beam_right_x - 1, BALANCE_BEAM_Y + 6)
	stage.add_child(right_string)

	var tilt = clamp(float(right_count - left_count) * 1.5, -12.0, 12.0)
	var beam_tween = create_tween()
	beam_tween.tween_property(beam, "rotation_degrees", tilt, 0.7) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	var tally = _make_hint_label("Tap each pan to weigh it!")

	var left_pan = _make_balance_pan(left_icon, left_count, tally, "Left", pan_w)
	left_pan.position = Vector2(beam_left_x - pan_w / 2.0, BALANCE_PAN_Y)
	stage.add_child(left_pan)

	var right_pan = _make_balance_pan(right_icon, right_count, tally, "Right", pan_w)
	right_pan.position = Vector2(beam_right_x - pan_w / 2.0, BALANCE_PAN_Y)
	stage.add_child(right_pan)

	#parent.add_child(tally)

func _make_balance_pan(icon: String, count: int, tally_label: Label, side_name: String, pan_w: float = BALANCE_PAN_WIDTH) -> Control:
	var pan = Button.new()
	pan.text = ""
	pan.focus_mode = Control.FOCUS_NONE
	pan.custom_minimum_size = Vector2(pan_w, 0)

	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_WHITE
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = COLOR_SLATE_300
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	pan.add_theme_stylebox_override("normal", style)
	pan.add_theme_stylebox_override("hover", style)

	var pressed_style = style.duplicate()
	pressed_style.bg_color = COLOR_BLUE_50
	pressed_style.border_color = COLOR_BLUE_500
	pan.add_theme_stylebox_override("pressed", pressed_style)
	pan.add_theme_stylebox_override("hover_pressed", pressed_style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_all", 12)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pan.add_child(margin)

	var flow = _make_flow(6, 6)
	flow.custom_minimum_size = Vector2(pan_w - 24, 0)
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(flow)

	for i in range(count):
		var lbl = Label.new()
		lbl.text = icon
		lbl.add_theme_font_size_override("font_size", roundi(_ics(22)))
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flow.add_child(lbl)

	pan.pressed.connect(func():
		_flash_animation(pan)
		tally_label.text = "%s pan holds %d %s" % [side_name, count, icon]
	)
	return pan

## Builds the answer choices for a question. Uses the "options" array from
## curriculum.json (the distractors) plus the correct answer, shuffled. Falls
## back to randomly generated distractors if a question has no usable options.
func _get_options(q: Dictionary) -> Array:
	var answer := str(q["answer"])
	var authored = q.get("options", [])
	if typeof(authored) != TYPE_ARRAY or authored.is_empty():
		return _generate_options(answer)

	var opts : Array = [answer]
	var answer_key := answer.to_lower().strip_edges()
	for o in authored:
		var text := str(o)
		# Skip duplicates and accidental copies of the answer.
		if text.to_lower().strip_edges() == answer_key or opts.has(text):
			continue
		opts.append(text)

	opts.shuffle()
	return opts

## Fallback only: random numeric distractors when the JSON has no options.
func _generate_options(answer: String) -> Array:
	var options = [answer]
	var ans_lower = answer.to_lower().strip_edges()
	
	if ans_lower.is_valid_float() or ans_lower.is_valid_int():
		var num = ans_lower.to_float()
		while options.size() < 4:
			var offset = (randi() % int(max(5, num * 0.3))) + 1
			if randf() > 0.5: offset = -offset
			var fake = str(num + offset)
			if not options.has(fake) and (num + offset) >= 0:
				options.append(fake)
	else:
		while options.size() < 4:
			options.append("Option " + str(options.size() + 1))
			
	options.shuffle()
	return options

func _on_option_selected(opt: String) -> void:
	if exam_status != "idle": return
	selected_answer = opt
	_refresh_option_styles()
	_update_action_button()

func _refresh_option_styles() -> void:
	var questions = current_lesson_data.get("questions", [])
	var correct_ans = ""
	if current_question_idx < questions.size():
		correct_ans = str(questions[current_question_idx]["answer"]).to_lower().strip_edges()
	
	for btn in option_buttons:
		var btn_text = btn.text.to_lower().strip_edges()
		var style = StyleBoxFlat.new()
		style.bg_color = COLOR_WHITE
		
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 4 
		
		style.corner_radius_top_left = 10
		style.corner_radius_bottom_right = 10
		style.corner_radius_top_right = 10
		style.corner_radius_bottom_left = 10
		
		style.border_color = COLOR_SLATE_200
		btn.add_theme_color_override("font_color", COLOR_SLATE_800)
		btn.add_theme_color_override("font_hover_color", COLOR_BLUE_500)
		
		if exam_status == "idle":
			if btn.text == selected_answer:
				style.bg_color = COLOR_BLUE_50
				style.border_color = COLOR_BLUE_500
				btn.add_theme_color_override("font_color", COLOR_BLUE_600)
		else:
			if btn_text == correct_ans:
				style.bg_color = COLOR_GREEN_50
				style.border_color = COLOR_GREEN_500
				btn.add_theme_color_override("font_color", COLOR_GREEN_500)
			elif btn.text == selected_answer and exam_status == "incorrect":
				style.bg_color = COLOR_RED_50
				style.border_color = COLOR_RED_500
				btn.add_theme_color_override("font_color", COLOR_RED_500)
				
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)

func _apply_action_style(btn: Button, bg: Color, border: Color, font_color: Color) -> void:
	var style = StyleBoxFlat.new()
	style.set_corner_radius_all(10)
	style.border_width_bottom = 4
	style.bg_color = bg
	style.border_color = border
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("disabled", style)
	btn.add_theme_stylebox_override("hover", style)

	var pressed_style = style.duplicate()
	pressed_style.border_width_bottom = 0
	pressed_style.content_margin_top = 4
	btn.add_theme_stylebox_override("pressed", pressed_style)

	btn.add_theme_color_override("font_color", font_color)
	btn.add_theme_color_override("font_disabled_color", font_color)

func _update_action_button() -> void:
	var next_enabled := false

	match exam_status:
		"complete":
			action_button.text = "RETURN TO THE HALL"
			action_button.disabled = false
			_apply_action_style(action_button, COLOR_BLUE_500, COLOR_BLUE_600, COLOR_WHITE)
		"curriculum_complete":
			action_button.text = "Exit"
			action_button.disabled = false
			_apply_action_style(action_button, COLOR_BLUE_500, COLOR_BLUE_600, COLOR_WHITE)
		"idle":
			action_button.text = "CAST"
			if selected_answer == "":
				action_button.disabled = true
				_apply_action_style(action_button, COLOR_SLATE_200, COLOR_SLATE_300, COLOR_SLATE_400)
			else:
				action_button.disabled = false
				_apply_action_style(action_button, COLOR_BLUE_500, COLOR_BLUE_600, COLOR_WHITE)
		"correct":
			# Answer is locked in: CAST is done, NEXT becomes available
			action_button.text = "CAST"
			action_button.disabled = true
			_apply_action_style(action_button, COLOR_SLATE_200, COLOR_SLATE_300, COLOR_SLATE_400)
			next_enabled = true
		"incorrect":
			action_button.text = "ONCE MORE"
			action_button.disabled = false
			_apply_action_style(action_button, COLOR_RED_500, COLOR_RED_500.darkened(0.2), COLOR_WHITE)

	next_button.disabled = not next_enabled
	if next_enabled:
		_apply_action_style(next_button, COLOR_GREEN_500, COLOR_GREEN_500.darkened(0.2), COLOR_WHITE)
	else:
		_apply_action_style(next_button, COLOR_SLATE_200, COLOR_SLATE_300, COLOR_SLATE_400)

func _on_action_button_pressed() -> void:
	if exam_status == "complete":
		# A relearned lesson doesn't advance saved progress; just hop back
		# to the curriculum-complete screen instead of closing the module.
		if _is_relearning:
			_is_relearning = false
			_show_curriculum_complete()
			return
		class_end.emit(current_grade, current_lesson)
		_persist_next_progress()
		hide()
		GameManager.game_time_enabled = true
		return

	if exam_status == "curriculum_complete":
		class_end.emit(current_grade, current_lesson)
		hide()
		GameManager.game_time_enabled = true
		return

	var questions = current_lesson_data.get("questions", [])

	if exam_status == "idle":
		if selected_answer == "": return
		var correct_ans = str(questions[current_question_idx]["answer"]).to_lower().strip_edges()
		var user_ans = selected_answer.to_lower().strip_edges()

		exam_status = "correct" if user_ans == correct_ans else "incorrect"
		_refresh_option_styles()
		_update_action_button()

	elif exam_status == "incorrect":
		exam_status = "idle"
		selected_answer = ""
		_refresh_option_styles()
		_update_action_button()

func _on_next_button_pressed() -> void:
	if exam_status != "correct": return
	var questions = current_lesson_data.get("questions", [])
	current_question_idx += 1
	if current_question_idx >= questions.size():
		_show_lesson_complete()
	else:
		_load_current_question()

func _persist_next_progress() -> void:
	var grade_num = current_grade.trim_prefix("g").to_int()
	var lesson_num = 1

	var lesson_parts = current_lesson.split("-l")
	if lesson_parts.size() > 1:
		lesson_num = lesson_parts[1].to_int()

	lesson_num += 1
	if lesson_num > LESSONS_PER_GRADE:
		lesson_num = 1
		grade_num += 1

	var next_grade = "g%d" % grade_num
	var next_lesson = "g%d-l%d" % [grade_num, lesson_num]

	db.query("UPDATE progress SET current_grade = '%s', current_lesson = '%s' WHERE is_active = true" % [next_grade, next_lesson])

## Checks whether a given grade/lesson id is present in the loaded curriculum.
func _lesson_exists(grade: String, lesson_id: String) -> bool:
	if not lesson_database.has(grade):
		return false
	for lesson in lesson_database[grade]:
		if lesson.has("id") and lesson["id"] == lesson_id:
			return true
	return false

func _show_lesson_complete() -> void:
	_cancel_typewriter()
	exam_status = "complete"
	main_container.hide()
	relearn_button.hide()

	if action_button.get_parent():
		action_button.get_parent().remove_child(action_button)
	
	lesson_complete_container.add_child(action_button)
	action_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	action_button.custom_minimum_size = Vector2(300, 50)
	
	_update_action_button()
	lesson_complete_container.show()
	
	_spawn_confetti()

func _show_curriculum_complete() -> void:
	_cancel_typewriter()
	exam_status = "curriculum_complete"
	main_container.hide()
	relearn_container.hide()

	if action_button.get_parent() != lesson_complete_container:
		if action_button.get_parent():
			action_button.get_parent().remove_child(action_button)
		lesson_complete_container.add_child(action_button)

	action_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	action_button.custom_minimum_size = Vector2(300, 50)

	lesson_complete_label.text = "You've mastered every spell so far!"
	relearn_button.show()

	_update_action_button()
	lesson_complete_container.show()

## Shows the full-screen grid of every grade/lesson in the curriculum so the
## player can pick one to replay for practice.
func _show_relearn_grid() -> void:
	_populate_relearn_grid()
	lesson_complete_container.hide()
	relearn_container.show()

func _on_relearn_back_pressed() -> void:
	relearn_container.hide()
	_show_curriculum_complete()

## Rebuilds the grade sections + lesson button grid inside relearn_container
## from the current lesson_database. Called each time the grid is opened so
## it always reflects the latest curriculum data.
func _populate_relearn_grid() -> void:
	for child in relearn_grades_vbox.get_children():
		child.queue_free()

	var grade_keys = lesson_database.keys()
	grade_keys.sort_custom(func(a, b):
		return String(a).trim_prefix("g").to_int() < String(b).trim_prefix("g").to_int()
	)

	for grade in grade_keys:
		var lessons = lesson_database[grade]
		if typeof(lessons) != TYPE_ARRAY or lessons.is_empty():
			continue

		var grade_label = Label.new()
		grade_label.text = "Grade %s" % String(grade).trim_prefix("g")
		grade_label.add_theme_font_size_override("font_size", 20)
		grade_label.add_theme_color_override("font_color", COLOR_AMBER_500)
		relearn_grades_vbox.add_child(grade_label)

		var grid = GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 14)
		grid.add_theme_constant_override("v_separation", 14)
		relearn_grades_vbox.add_child(grid)

		for lesson in lessons:
			if not lesson.has("id"):
				continue
			var lesson_id = str(lesson["id"])
			var lesson_title = str(lesson.get("title", lesson_id))

			var btn = Button.new()
			btn.text = lesson_title
			btn.custom_minimum_size = Vector2(200, 64)
			btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			btn.add_theme_font_size_override("font_size", 15)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			var is_current = (grade == current_grade and lesson_id == current_lesson)
			_style_solid_button(btn, COLOR_AMBER_100 if is_current else COLOR_BLUE_50, COLOR_SLATE_300, COLOR_SLATE_800)

			btn.pressed.connect(_on_relearn_lesson_selected.bind(grade, lesson_id))
			grid.add_child(btn)

## Enters a lesson chosen from the relearn grid without touching saved
## progress (see _is_relearning usage in _on_action_button_pressed()).
func _on_relearn_lesson_selected(grade: String, lesson_id: String) -> void:
	_is_relearning = true
	current_grade = grade
	current_lesson = lesson_id
	_lesson_available = true
	relearn_container.hide()
	_start_lesson()

func _spawn_confetti() -> void:
	var colors = [COLOR_AMBER_500, COLOR_BLUE_500, COLOR_GREEN_500, Color("#8a5a2b"), Color("#7b4fa0")]
	var center_pos = get_viewport_rect().size / 2.0
	
	for c in colors:
		var emitter = CPUParticles2D.new()
		emitter.emitting = false
		emitter.one_shot = true
		emitter.explosiveness = 0.9
		emitter.amount = 25
		emitter.lifetime = 3.0
		
		emitter.direction = Vector2(0, -1)
		emitter.spread = 90.0
		emitter.initial_velocity_min = 400.0
		emitter.initial_velocity_max = 800.0

		emitter.angular_velocity_min = -360.0
		emitter.angular_velocity_max = 360.0

		emitter.scale_amount_min = 10.0
		emitter.scale_amount_max = 18.0
		
		emitter.color = c
		emitter.position = center_pos
		
		add_child(emitter)
		emitter.emitting = true

		get_tree().create_timer(3.5).timeout.connect(emitter.queue_free)
