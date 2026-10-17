extends Control
class_name Scholl

# =====================================================================
#  AcadeMath class screen  -  interactive / gamified version
#
#  LECTURES   lesson["lecture_steps"] is an array of steps (see below).
#             Lessons without it fall back to the plain typed lesson["lecture"].
#       {"type":"say",     "text":"..."}                       typed + spoken line
#       {"type":"confirm", "text":"Ready?", "yes":"..", "no":".."}  popup, waits for YES ("no" is optional: omit it for a single button)
#       {"type":"count",   "from":1, "to":10, "step":1, "interval":1.2, "repeat":true}  number cards + Count Again button
#       {"type":"show",    "text":"..", "visual":{..}}         live demo, auto-advances
#       {"type":"tap",     "text":"..", "visual":{..}}         live demo, waits for NEXT
#       {"type":"check",   "text":"..", "visual":{..}, "answer":"..", "options":[..]}
#                                                              unscored mini question
#       {"type":"cheer",   "text":".."}                        confetti + line
#
#  VISUAL TYPES (question["visual"] or step["visual"])
#       existing : grid, groups, sequence, balance
#       drawn    : shapes {"shapes":[{"sides":3},{"points":[[x,y],..]}]}
#                  fraction {"bars":[{"parts":4,"filled":3}]}
#                  clock {"clocks":[{"hour":12,"minute":20}]}
#       PUZZLES (solved inside the question, no answer buttons; set "answer" to any
#       string such as "solved"; solved with 0 mistakes = correct):
#                  shape_match  {"shapes":[{"sides":3,"label":"triangle"}, ...]}
#                  block_stack  {"heights":[3,1,4,2], "order":"asc"|"desc"}
#                  connect_dots {"dots":[[0.2,0.8],[0.5,0.2],[0.8,0.8]],
#                                "labels":["2","4","6"], "close":true}
#       Any visual may carry "instruction": "..." to override the default
#       instruction banner shown above it.
# =====================================================================

signal class_end(currentGrade: String, currentLesson : String)

var save_path = "user://analysis_data.json"

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

# The final exam is exclusive: it only runs for progress that is exactly
# grade "g4" + lesson "final", and it is never listed on the relearn page.
const FINAL_EXAM_GRADE := "g4"
const FINAL_EXAM_LESSON := "final"

var lecture_container : VBoxContainer
var lecture_title_label : Label
var lecture_continue_button : Button
var lecture_replay_button : Button

var lecture_scroll : ScrollContainer
var lecture_stage_panel : PanelContainer
var lecture_stage_vbox : VBoxContainer

# --- Interactive lecture runner (lecture_steps in curriculum.json) ---
const COUNT_CARD_SCALE := 1.45
var _lecture_token : int = 0
var _skip_flag : bool = false
var _steps : Array = []
var _last_line : String = ""
var _confirm_overlay : Control = null
var _continue_pulse : Tween = null

# --- Gamification ---
const PUZZLE_TYPES := ["shape_match", "block_stack", "connect_dots"]
const SHAPE_COLORS := [Color("#e8c97a"), Color("#d98a6c"), Color("#8fb58a"), Color("#8fa6c9"), Color("#b79ac9"), Color("#d9b26c")]
const BLOCK_COLORS := [Color("#d98a6c"), Color("#e8c97a"), Color("#8fb58a"), Color("#8fa6c9"), Color("#b79ac9"), Color("#d9b26c")]
var stars_label : Label
var streak_label : Label
var _streak : int = 0
var _wrong_count : int = 0
var _puzzle_active : bool = false

# --- Spell casting: question queue + magic circle ---
# Every question the player sees comes from _queue, so extra entries
# (mend / golden / challenge rounds) only need to be inserted here.
var _queue : Array = []            # {"q": question Dictionary, "kind": "normal"}
var _circle : MagicCircle = null
var _circle_busy : bool = false    # NEXT stays locked while the circle animates
const SFX_DIR := "res://assets/audio/sfx/"
const SFX_NAMES := ["chime", "fire", "shatter"]
var _sfx_player : AudioStreamPlayer = null
var _sfx : Dictionary = {}

var root_bg : ColorRect

const TYPEWRITER_CHAR_DELAY := 0.045
var _tw_timer : Timer = null
var _tw_target : RichTextLabel = null
var _tts_voice_id : String = ""

var _session_id : String = ""
var _question_start_ms : int = 0
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
	_prepare_sfx()



	_lesson_available = _lesson_exists(current_grade, current_lesson)

	hide()
	start_class()

func _load_active_curriculum():
	var curriculum = db.query("SELECT current_grade, current_lesson FROM progress WHERE is_active = true LIMIT 1")
	var data = curriculum.data[0]
	current_grade = data.current_grade
	current_lesson = data.current_lesson

func start_class() -> void:
	_load_active_curriculum()
	_lesson_available = _lesson_exists(current_grade, current_lesson)
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

	top_bar.add_theme_constant_override("separation", 16)

	stars_label = Label.new()
	stars_label.add_theme_font_size_override("font_size", _fs(20))
	stars_label.add_theme_color_override("font_color", COLOR_AMBER_500)
	top_bar.add_child(stars_label)

	streak_label = Label.new()
	streak_label.add_theme_font_size_override("font_size", _fs(18))
	streak_label.add_theme_color_override("font_color", COLOR_RED_500)
	top_bar.add_child(streak_label)
	_update_hud()

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


	var stage_center = CenterContainer.new()
	stage_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_area.add_child(stage_center)

	# Parchment panel that holds the live lecture demo (number cards, visuals, popups)
	lecture_stage_panel = PanelContainer.new()
	var stage_style = StyleBoxFlat.new()
	stage_style.bg_color = COLOR_WHITE
	stage_style.set_border_width_all(3)
	stage_style.border_color = COLOR_AMBER_500
	stage_style.set_corner_radius_all(18)
	stage_style.content_margin_left = 24
	stage_style.content_margin_right = 24
	stage_style.content_margin_top = 18
	stage_style.content_margin_bottom = 18
	lecture_stage_panel.add_theme_stylebox_override("panel", stage_style)
	lecture_stage_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	lecture_stage_panel.hide()
	stage_center.add_child(lecture_stage_panel)

	lecture_stage_vbox = VBoxContainer.new()
	lecture_stage_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	lecture_stage_vbox.add_theme_constant_override("separation", 14)
	lecture_stage_panel.add_child(lecture_stage_vbox)

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
	lecture_bottom_panel.gui_input.connect(_on_lecture_display_input)
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

	lecture_scroll = ScrollContainer.new()
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
	_start_lecture()

## Starts (or restarts) the lecture. Uses lecture_steps when the lesson has them,
## otherwise falls back to the old typed paragraph.
func _start_lecture() -> void:
	_stop_lecture_steps()
	_stage_clear()
	var steps = current_lesson_data.get("lecture_steps", [])
	if typeof(steps) == TYPE_ARRAY and not steps.is_empty():
		_steps = steps
		lecture_scroll.custom_minimum_size = Vector2(0, 120)
		lecture_display.add_theme_font_size_override("normal_font_size", _fs(24))
		lecture_replay_button.text = "Watch Again"
		lecture_display.text = ""
		_run_lecture_steps(_lecture_token)
	else:
		_steps = []
		lecture_scroll.custom_minimum_size = Vector2(0, 300)
		lecture_display.add_theme_font_size_override("normal_font_size", _fs(14))
		lecture_replay_button.text = "Read Again"
		_typewrite_and_speak(lecture_display, str(current_lesson_data.get("lecture", "")))

func _on_lecture_continue_pressed() -> void:
	_stop_lecture_steps()
	_stage_clear()
	lecture_container.hide()
	if root_bg:
		root_bg.show()
	main_container.show()
	current_question_idx = 0
	_load_current_question()

func _on_lecture_replay_pressed() -> void:
	_start_lecture()

func _on_lecture_display_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_skip_flag = true
		_skip_typewriter()

func _prepare_tts() -> void:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		return
	var voices = DisplayServer.tts_get_voices_for_language("en")
	if voices.size() > 0:
		if current_grade == "g4" and current_lesson == "final":
			_tts_voice_id = voices[0] if OS.get_name().to_lower() in ["android", "ios"] else voices[1]
		else:
			_tts_voice_id = voices[1] if OS.get_name().to_lower() in ["android", "ios"] else voices[0]

## Optional spell sounds: res://assets/audio/sfx/<name>.ogg|.wav|.mp3.
## Missing files are skipped. Uses its own player so MusicPlayer's
## one_shot_stream (the cutscene dialogue blip) is never replaced.
func _prepare_sfx() -> void:
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = &"SFX"
	add_child(_sfx_player)
	for sfx_name in SFX_NAMES:
		for ext in ["ogg", "wav", "mp3"]:
			var path := "%s%s.%s" % [SFX_DIR, sfx_name, ext]
			if ResourceLoader.exists(path):
				_sfx[sfx_name] = load(path)
				break

func _play_sfx(sfx_name: String) -> void:
	if _sfx_player == null or not _sfx.has(sfx_name):
		return
	_sfx_player.stream = _sfx[sfx_name]
	_sfx_player.play()

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
	
	_streak = 0
	_wrong_count = 0
	_update_hud()
	_build_queue()
	_session_id = str(int(Time.get_unix_time_from_system()))
	_show_lecture()

func _build_queue() -> void:
	_queue.clear()
	for q in current_lesson_data.get("questions", []):
		if typeof(q) == TYPE_DICTIONARY:
			_queue.append({"q": q, "kind": "normal"})

func _current_entry() -> Dictionary:
	if current_question_idx < 0 or current_question_idx >= _queue.size():
		return {}
	return _queue[current_question_idx]

func _current_q() -> Dictionary:
	return _current_entry().get("q", {})

func _load_current_question() -> void:
	exam_status = "idle"
	selected_answer = ""
	_circle_busy = false
	_circle = null

	if current_question_idx >= _queue.size():
		_show_lesson_complete()
		return

	var q = _current_q()
	_puzzle_active = _is_puzzle_question(q)
	_update_action_button()
	progress_bar.value = (float(current_question_idx) / _queue.size()) * 100.0
	
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
	_question_start_ms = Time.get_ticks_msec()

	# Puzzles fill the card, so their circle sits above the puzzle;
	# everywhere else it sits under the visual, right above the answers.
	if _puzzle_active:
		_add_magic_circle(q_vbox)

	if q.has("visual") and typeof(q["visual"]) == TYPE_DICTIONARY:
		var instruction := _instruction_for(q["visual"], q)
		if instruction != "":
			q_vbox.add_child(_make_instruction_banner(instruction))
		_build_visual(q["visual"], q_vbox, str(q.get("answer", "")))

	if not _puzzle_active:
		_add_magic_circle(q_vbox)

	if options_grid.get_parent():
		options_grid.get_parent().remove_child(options_grid)
	exam_container.add_child(options_grid)
	
	options_grid.visible = not _puzzle_active
	var opts : Array = [] if _puzzle_active else _get_options(q)
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
	elif v_type == "shapes" and visual_data.has("shapes"):
		_build_shapes_visual(visual_data["shapes"], parent, bool(visual_data.get("interactive", false)))
	elif v_type == "fraction" and visual_data.has("bars"):
		_build_fraction_visual(visual_data["bars"], parent)
	elif v_type == "clock" and visual_data.has("clocks"):
		_build_clock_visual(visual_data["clocks"], parent)
	elif v_type == "shape_match" and visual_data.has("shapes"):
		_build_shape_match(visual_data, parent)
	elif v_type == "block_stack" and visual_data.has("heights"):
		_build_block_stack(visual_data, parent)
	elif v_type == "connect_dots" and visual_data.has("dots"):
		_build_connect_dots(visual_data, parent)

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
	var tw = ctrl.create_tween()
	tw.bind_node(ctrl)
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
		# Blank items (e.g. the empty boxes) are not countable: they cannot be pressed.
		var countable : bool = icon.strip_edges() != "" and bool(item.get("countable", true))
		for i in range(int(item.get("count", 0))):
			var chip = _make_icon_chip(icon)
			if not countable:
				chip.disabled = true
				chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
				chip.add_theme_stylebox_override("disabled", chip.get_theme_stylebox("normal"))
				chip.modulate = Color(1, 1, 1, 0.55)
				flow.add_child(chip)
				continue
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
	if _circle and is_instance_valid(_circle):
		_circle.charge(opt)
	_play_sfx("chime")
	_refresh_option_styles()
	_update_action_button()

# =====================================================================
#  MAGIC CIRCLE: every question is a spell that fires or shatters
# =====================================================================
func _add_magic_circle(parent: Container) -> void:
	var holder = CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(holder)
	_circle = MagicCircle.new()
	var circle_size := _ics(150.0)
	_circle.custom_minimum_size = Vector2(circle_size, circle_size)
	holder.add_child(_circle)
	_circle.begin(6 + current_question_idx % 4)

## Plays fire/shatter, keeping NEXT locked until the animation is over.
func _play_cast_result(is_correct: bool) -> void:
	_play_sfx("fire" if is_correct else "shatter")
	var circle := _circle
	if circle == null or not is_instance_valid(circle):
		return
	_circle_busy = true
	_update_action_button()
	if is_correct:
		_spawn_spark_burst(circle)
		await circle.fire()
	else:
		await circle.shatter()
	# The player may have left this question while the circle animated.
	if circle != _circle or not is_instance_valid(circle):
		return
	_circle_busy = false
	_update_action_button()

## Small gold particle pop from the circle's centre on a successful cast.
func _spawn_spark_burst(circle: Control) -> void:
	var sparks = CPUParticles2D.new()
	sparks.emitting = false
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.amount = 24
	sparks.lifetime = 0.8
	sparks.spread = 180.0
	sparks.gravity = Vector2(0, 300)
	sparks.initial_velocity_min = 120.0
	sparks.initial_velocity_max = 260.0
	sparks.scale_amount_min = 3.0
	sparks.scale_amount_max = 6.0
	sparks.color = COLOR_AMBER_500
	sparks.position = circle.size / 2.0
	circle.add_child(sparks)
	sparks.emitting = true
	get_tree().create_timer(1.2).timeout.connect(sparks.queue_free)

func _refresh_option_styles() -> void:
	var correct_ans = ""
	if not _current_q().is_empty():
		correct_ans = str(_current_q().get("answer", "")).to_lower().strip_edges()
	
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
			action_button.text = "SOLVE IT!" if _puzzle_active else "CAST SPELL"
			if selected_answer == "":
				action_button.disabled = true
				_apply_action_style(action_button, COLOR_SLATE_200, COLOR_SLATE_300, COLOR_SLATE_400)
			else:
				action_button.disabled = false
				_apply_action_style(action_button, COLOR_BLUE_500, COLOR_BLUE_600, COLOR_WHITE)
		"correct":
			# Answer is locked in: the spell fired, NEXT unlocks once the circle settles
			action_button.text = "SPELL CAST!"
			action_button.disabled = true
			_apply_action_style(action_button, COLOR_SLATE_200, COLOR_SLATE_300, COLOR_SLATE_400)
			next_enabled = not _circle_busy
		"incorrect":
			# Answer is saved and locked: no retry, the player moves on
			action_button.text = "SPELL BROKE"
			action_button.disabled = true
			_apply_action_style(action_button, COLOR_SLATE_200, COLOR_SLATE_300, COLOR_SLATE_400)
			next_enabled = not _circle_busy

	next_button.disabled = not next_enabled
	if next_enabled:
		_apply_action_style(next_button, COLOR_GREEN_500, COLOR_GREEN_500.darkened(0.2), COLOR_WHITE)
	else:
		_apply_action_style(next_button, COLOR_SLATE_200, COLOR_SLATE_300, COLOR_SLATE_400)

func _on_action_button_pressed() -> void:
	if exam_status == "complete":
		if _is_relearning:
			_is_relearning = false
			_show_curriculum_complete()
			return
		_player_reward(_get_reward_amount(current_grade, current_lesson))
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

	if exam_status == "idle":
		if selected_answer == "": return
		var q = _current_q()
		if q.is_empty(): return
		var correct_ans = str(q["answer"]).to_lower().strip_edges()
		var user_ans = selected_answer.to_lower().strip_edges()
		var is_correct = user_ans == correct_ans

		_record_answer(q, is_correct)
		_register_result(is_correct)

		exam_status = "correct" if is_correct else "incorrect"
		_refresh_option_styles()
		_update_action_button()
		_play_cast_result(is_correct)

func _record_answer(q: Dictionary, is_correct: bool) -> void:
	AnalysisReport.record_answer({
		"timestamp": int(Time.get_unix_time_from_system()),
		"datetime": Time.get_datetime_string_from_system(false, true),
		"session": _session_id,
		"grade": current_grade,
		"lesson": current_lesson,
		"lesson_title": str(current_lesson_data.get("title", current_lesson)),
		"question_idx": current_question_idx,
		"question": str(q.get("text", "")),
		"selected_answer": selected_answer,
		"correct_answer": str(q.get("answer", "")),
		"is_correct": is_correct,
		"time_ms": Time.get_ticks_msec() - _question_start_ms,
		"relearn": _is_relearning,
		"kind": str(_current_entry().get("kind", "normal"))
	})

func _on_next_button_pressed() -> void:
	if exam_status != "correct" and exam_status != "incorrect": return
	if _circle_busy: return
	current_question_idx += 1
	if current_question_idx >= _queue.size():
		_show_lesson_complete()
	else:
		_load_current_question()

func _persist_next_progress() -> void:
	var grade_num = current_grade.trim_prefix("g").to_int()
	var lesson_num = 1

	var next_grade : String
	var next_lesson : String

	if _is_final_exam(current_grade, current_lesson):
		# Final exam passed: move past the last grade. Nothing exists there,
		# so the class will show the "all classes completed" screen from now on.
		grade_num += 1
		next_grade = "g%d" % grade_num
		next_lesson = "g%d-l1" % grade_num
	else:
		var lesson_parts = current_lesson.split("-l")
		if lesson_parts.size() > 1:
			lesson_num = lesson_parts[1].to_int()

		lesson_num += 1
		if lesson_num > LESSONS_PER_GRADE:
			lesson_num = 1
			grade_num += 1

		next_grade = "g%d" % grade_num
		if next_grade == FINAL_EXAM_GRADE:
			# Finished the last regular lesson (g3-l10): the final exam is next.
			next_lesson = FINAL_EXAM_LESSON
		else:
			next_lesson = "g%d-l%d" % [grade_num, lesson_num]

	db.query("UPDATE progress SET current_grade = '%s', current_lesson = '%s' WHERE is_active = true" % [next_grade, next_lesson])

## Checks whether a given grade/lesson id is present in the loaded curriculum.
func _lesson_exists(grade: String, lesson_id: String) -> bool:
	# The final exam only counts as available for exactly g4 + "final".
	# Anything else falls through to the "all classes completed" screen.
	if lesson_id == FINAL_EXAM_LESSON and grade != FINAL_EXAM_GRADE:
		return false
	if not lesson_database.has(grade):
		return false
	for lesson in lesson_database[grade]:
		if lesson.has("id") and lesson["id"] == lesson_id:
			return true
	return false

## True only for the exclusive final exam (grade 4, lesson "final").
func _is_final_exam(grade: String, lesson_id: String) -> bool:
	return grade == FINAL_EXAM_GRADE and lesson_id == FINAL_EXAM_LESSON

func _show_lesson_complete() -> void:
	_cancel_typewriter()
	exam_status = "complete"
	
	if _is_relearning:
		lesson_complete_label.text = "Spell Mastered!\n%s" % "⭐".repeat(_stars_now())
	else:
		lesson_complete_label.text = "Spell Mastered!\n%s\n+%d KP" % ["⭐".repeat(_stars_now()), _get_reward_amount(current_grade, current_lesson)]
		
	
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

		# The final exam is exclusive and is never offered for relearning.
		var relearn_lessons : Array = []
		for lesson in lessons:
			if lesson.has("id") and not _is_final_exam(String(grade), str(lesson["id"])):
				relearn_lessons.append(lesson)
		if relearn_lessons.is_empty():
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

		for lesson in relearn_lessons:
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
	if _is_final_exam(grade, lesson_id):
		return
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

func _get_reward_amount(grade: String, lesson_id: String) -> int:
	var grade_num := grade.trim_prefix("g").to_int()
	var lesson_num := 1
	var parts := lesson_id.split("-l")
	if parts.size() > 1:
		lesson_num = parts[1].to_int()
	if _is_final_exam(grade, lesson_id):
		lesson_num = LESSONS_PER_GRADE

	var reward := 50                  
	reward += (grade_num - 1) * 10  
	reward += (lesson_num - 1) * 2   
	if lesson_num == LESSONS_PER_GRADE:
		reward += 50                
	return reward

func _player_reward(KP_amount):
	var total_kp = GameManager.kp_amount + KP_amount
	db.query("UPDATE progress SET kp = %d WHERE is_active = true" % total_kp)
	GameManager._update_KP()


# =====================================================================
#  GAMIFICATION: stars + streak + small feedback animations
# =====================================================================
func _stars_now() -> int:
	if _wrong_count == 0:
		return 3
	if _wrong_count <= 2:
		return 2
	return 1

func _update_hud() -> void:
	if stars_label == null or streak_label == null:
		return
	stars_label.text = "⭐".repeat(_stars_now())
	streak_label.text = ("🔥 x%d" % _streak) if _streak >= 2 else ""

func _register_result(is_correct: bool) -> void:
	if is_correct:
		_streak += 1
	else:
		_streak = 0
		_wrong_count += 1
	_update_hud()
	if is_correct and _streak >= 2:
		_pop_centered(streak_label)
	elif not is_correct:
		_shake_animation(stars_label)

func _pop_centered(ctrl: Control) -> void:
	if not is_instance_valid(ctrl):
		return
	ctrl.pivot_offset = ctrl.size / 2.0
	_pop_animation(ctrl)

func _shake_animation(ctrl: Control) -> void:
	if not is_instance_valid(ctrl):
		return
	ctrl.pivot_offset = ctrl.size / 2.0
	var tw = ctrl.create_tween()
	tw.tween_property(ctrl, "rotation_degrees", 6.0, 0.06)
	tw.tween_property(ctrl, "rotation_degrees", -6.0, 0.08)
	tw.tween_property(ctrl, "rotation_degrees", 3.0, 0.06)
	tw.tween_property(ctrl, "rotation_degrees", 0.0, 0.06)

func _flash_red(ctrl: CanvasItem) -> void:
	if not is_instance_valid(ctrl):
		return
	ctrl.modulate = Color(1.4, 0.7, 0.7)
	var tw = ctrl.create_tween()
	tw.tween_property(ctrl, "modulate", Color(1, 1, 1), 0.35)

# =====================================================================
#  INSTRUCTION BANNER (shown above every question visual)
# =====================================================================
func _make_instruction_banner(text: String) -> Control:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_AMBER_100
	style.set_border_width_all(2)
	style.border_color = COLOR_AMBER_500
	style.set_corner_radius_all(12)
	style.content_margin_left = 14
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)

	var icon = Label.new()
	icon.text = "💡"
	icon.add_theme_font_size_override("font_size", _fs(20))
	row.add_child(icon)

	var lbl = Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", _fs(16))
	lbl.add_theme_color_override("font_color", COLOR_SLATE_800)
	row.add_child(lbl)

	var speaker = Button.new()
	speaker.text = "🔊"
	speaker.focus_mode = Control.FOCUS_NONE
	speaker.custom_minimum_size = Vector2(44, 44)
	_style_solid_button(speaker, COLOR_WHITE, COLOR_SLATE_300, COLOR_SLATE_800)
	speaker.pressed.connect(func(): _speak(text))
	row.add_child(speaker)
	return panel

## "Instruction" text for a question visual: the JSON value wins, otherwise a
## sensible default per visual type.
func _instruction_for(visual: Dictionary, q: Dictionary) -> String:
	if visual.has("instruction"):
		return str(visual["instruction"])
	match str(visual.get("type", "")):
		"grid":
			return "Tap each charm once to count it."
		"groups":
			var per := 0
			var gd = visual.get("groups", {})
			if typeof(gd) == TYPE_DICTIONARY:
				per = int(gd.get("itemsPerGroup", 0))
			if per > 0:
				return "Tap each bundle and count by %d." % per
			return "Tap each bundle to count."
		"sequence":
			if _looks_like_reorder(visual.get("sequence", []), str(q.get("answer", ""))):
				return "Tap two runes to swap them into order, then press CAST."
			return "Look at the puzzle, then pick an answer and press CAST."
		"balance":
			return "Tap each pan to see what it holds."
		"shapes":
			return "Look at the shapes, then pick your answer."
		"fraction":
			return "Look at the shaded pieces, then pick your answer."
		"clock":
			return "Read the clock hands, then pick your answer."
		"shape_match":
			return "Drag each shape onto its matching outline."
		"block_stack":
			if str(visual.get("order", "asc")) == "desc":
				return "Drag the blocks in: tallest on the left, shortest on the right."
			return "Drag the blocks in: shortest on the left, tallest on the right."
		"connect_dots":
			return "Tap the dots in order, from the first to the last."
	return ""

func _looks_like_reorder(sequence, answer_str: String) -> bool:
	if answer_str.find(",") == -1 or typeof(sequence) != TYPE_ARRAY:
		return false
	for token in sequence:
		if not str(token).strip_edges().is_valid_int():
			return false
	return true

# =====================================================================
#  PUZZLE BRIDGE: puzzles report their result like the CAST button does
# =====================================================================
func _is_puzzle_question(q: Dictionary) -> bool:
	var v = q.get("visual", null)
	return typeof(v) == TYPE_DICTIONARY and PUZZLE_TYPES.has(str(v.get("type", "")))

func _submit_puzzle_result(is_correct: bool, answer_text: String) -> void:
	if exam_status != "idle":
		return
	var q = _current_q()
	if q.is_empty():
		return
	selected_answer = answer_text
	_record_answer(q, is_correct)
	_register_result(is_correct)
	exam_status = "correct" if is_correct else "incorrect"
	_refresh_option_styles()
	_update_action_button()
	_play_cast_result(is_correct)

func _finish_puzzle(state: Dictionary) -> void:
	if state["done"]:
		return
	state["done"] = true
	var mistakes := int(state["mistakes"])
	var ok := mistakes == 0
	var ans := str(_current_q().get("answer", "solved"))
	if ok:
		_spawn_confetti()
	_submit_puzzle_result(ok, ans if ok else "%d mistakes" % mistakes)

# =====================================================================
#  INTERACTIVE LECTURE RUNNER
# =====================================================================
func _alive(token: int) -> bool:
	return token == _lecture_token and is_inside_tree()

func _wait(seconds: float, token: int) -> void:
	var t := 0.0
	while t < seconds:
		if not _alive(token) or _skip_flag:
			return
		await get_tree().process_frame
		t += get_process_delta_time()

func _stage_clear() -> void:
	if lecture_stage_vbox == null:
		return
	for c in lecture_stage_vbox.get_children():
		lecture_stage_vbox.remove_child(c)
		c.queue_free()
	lecture_stage_panel.hide()

func _stage_reveal() -> void:
	var w := clampf(get_viewport_rect().size.x - 160.0, 260.0, 720.0)
	lecture_stage_vbox.custom_minimum_size = Vector2(w, 0)
	lecture_stage_panel.show()

func _stop_lecture_steps() -> void:
	_lecture_token += 1
	_skip_flag = false
	if _confirm_overlay and is_instance_valid(_confirm_overlay):
		_confirm_overlay.queue_free()
	_confirm_overlay = null
	if _continue_pulse and _continue_pulse.is_valid():
		_continue_pulse.kill()
	_continue_pulse = null
	if lecture_continue_button:
		lecture_continue_button.modulate.a = 1.0
	_cancel_typewriter()

func _run_lecture_steps(token: int) -> void:
	var steps : Array = _steps.duplicate()
	for step in steps:
		if not _alive(token):
			return
		_skip_flag = false
		if typeof(step) != TYPE_DICTIONARY:
			continue
		await _run_step(step, token)
	if not _alive(token):
		return
	_finish_lecture_steps()

func _run_step(step: Dictionary, token: int) -> void:
	match str(step.get("type", "say")):
		"say":
			await _say_text(str(step.get("text", "")), token)
		"confirm":
			await _step_confirm(step, token)
		"count":
			await _step_count(step, token)
		"show":
			await _step_show(step, token, false)
		"tap":
			await _step_show(step, token, true)
		"check":
			await _step_check(step, token)
		"cheer":
			await _step_cheer(step, token)

func _finish_lecture_steps() -> void:
	# Gently pulse "Begin Trial" so the player knows the lecture is over.
	if _continue_pulse and _continue_pulse.is_valid():
		_continue_pulse.kill()
	_continue_pulse = lecture_continue_button.create_tween()
	_continue_pulse.set_loops()
	_continue_pulse.tween_property(lecture_continue_button, "modulate:a", 0.6, 0.6).set_trans(Tween.TRANS_SINE)
	_continue_pulse.tween_property(lecture_continue_button, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)

## Types + speaks a line, waits for the voice to finish. Tapping skips ahead.
func _say_text(text: String, token: int) -> void:
	if text.is_empty():
		return
	_last_line = text
	var done := {"v": false}
	_typewrite_and_speak(lecture_display, text, func(): done["v"] = true)
	while not done["v"] and lecture_display.visible_characters != -1:
		if _skip_flag or not _alive(token):
			break
		await get_tree().process_frame
	if not _alive(token):
		return
	lecture_display.visible_characters = -1
	if DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		var waited := 0.0
		while DisplayServer.tts_is_speaking() and waited < 6.0 and not _skip_flag:
			await get_tree().process_frame
			if not _alive(token):
				return
			waited += get_process_delta_time()
	else:
		await _wait(0.4 + 0.05 * text.split(" ").size(), token)
	await _wait(0.35, token)

# ---------- confirm popup ----------
func _step_confirm(step: Dictionary, token: int) -> void:
	var question := str(step.get("text", "Are you ready?"))
	var yes_text := str(step.get("yes", "I'm ready!"))
	var no_text := str(step.get("no", ""))
	while _alive(token):
		_speak(question)
		var result := {"v": 0}
		_confirm_overlay = _build_confirm_popup(question, yes_text, no_text, result)
		add_child(_confirm_overlay)
		_confirm_overlay.modulate.a = 0.0
		_confirm_overlay.create_tween().tween_property(_confirm_overlay, "modulate:a", 1.0, 0.18)
		while result["v"] == 0 and _alive(token):
			await get_tree().process_frame
		if _confirm_overlay and is_instance_valid(_confirm_overlay):
			_confirm_overlay.queue_free()
		_confirm_overlay = null
		if not _alive(token):
			return
		if result["v"] == 1:
			return
		# "Wait a moment": give the player a breather, then ask again.
		_typewrite_and_speak(lecture_display, "Take your time!")
		await _wait(3.5, token)
		if not _alive(token):
			return
		lecture_display.text = _last_line
		lecture_display.visible_characters = -1

func _build_confirm_popup(question: String, yes_text: String, no_text: String, result: Dictionary) -> Control:
	var overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_WHITE
	style.set_border_width_all(4)
	style.border_color = COLOR_AMBER_500
	style.set_corner_radius_all(20)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 22)
	panel.add_child(vbox)

	var lbl = Label.new()
	lbl.text = question
	lbl.custom_minimum_size = Vector2(320, 0)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", _fs(26))
	lbl.add_theme_color_override("font_color", COLOR_SLATE_800)
	vbox.add_child(lbl)

	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	vbox.add_child(row)

	var yes = Button.new()
	yes.text = yes_text
	yes.custom_minimum_size = Vector2(_ics(180), 60)
	yes.add_theme_font_size_override("font_size", _fs(20))
	_style_lecture_button(yes, COLOR_GREEN_500, COLOR_GREEN_500.darkened(0.25), COLOR_WHITE)
	yes.pressed.connect(func(): result["v"] = 1)
	row.add_child(yes)

	# The "no" button only exists when the step provides a "no" text.
	if no_text != "":
		var no = Button.new()
		no.text = no_text
		no.custom_minimum_size = Vector2(_ics(180), 60)
		no.add_theme_font_size_override("font_size", _fs(20))
		_style_lecture_button(no, COLOR_BLUE_50, COLOR_AMBER_500, COLOR_SLATE_800)
		no.pressed.connect(func(): result["v"] = 2)
		row.add_child(no)

	return overlay

# ---------- counting with number cards ----------
func _step_count(step: Dictionary, token: int) -> void:
	_stage_clear()
	var from_n := int(step.get("from", 1))
	var to_n := int(step.get("to", 10))
	var stride : int = maxi(1, int(step.get("step", 1)))
	var interval := float(step.get("interval", 0.9))
	var lead_in := float(step.get("lead_in", 0.8))
	var allow_repeat := bool(step.get("repeat", true))

	var values : Array = []
	var n := from_n
	while n <= to_n:
		values.append(n)
		n += stride

	var flow = _make_flow(12, 12)
	lecture_stage_vbox.add_child(flow)
	_stage_reveal()

	var cards : Array = []
	for v in values:
		var card = _make_number_card(int(v))
		flow.add_child(card)
		cards.append(card)
	await get_tree().process_frame

	var buttons_row : HBoxContainer = null
	while _alive(token):
		# Fresh run: every card back to idle, buttons hidden while counting.
		for c in cards:
			_set_card_state(c, "idle")
			c.scale = Vector2.ONE
		if buttons_row:
			buttons_row.queue_free()
			buttons_row = null
		_skip_flag = false
		await _wait(lead_in, token)

		for i in range(cards.size()):
			if not _alive(token):
				return
			var card : PanelContainer = cards[i]
			if _skip_flag:
				_set_card_state(card, "done")
				continue
			_set_card_state(card, "active")
			card.z_index = 5
			var up = card.create_tween()
			up.tween_property(card, "scale", Vector2(COUNT_CARD_SCALE, COUNT_CARD_SCALE), 0.18) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_speak(_number_to_word(int(values[i])))
			await _wait(interval, token)
			if not _alive(token):
				return
			_set_card_state(card, "done")
			card.z_index = 0
			var down = card.create_tween()
			down.tween_property(card, "scale", Vector2.ONE, 0.15)
		_skip_flag = false
		await _wait(0.5, token)
		if not allow_repeat or not _alive(token):
			return

		# Let the player count again, or move on.
		var choice := {"v": 0}
		buttons_row = HBoxContainer.new()
		buttons_row.alignment = BoxContainer.ALIGNMENT_CENTER
		buttons_row.add_theme_constant_override("separation", 14)
		lecture_stage_vbox.add_child(buttons_row)

		var again = Button.new()
		again.text = "Count Again"
		again.custom_minimum_size = Vector2(_ics(190), 54)
		again.add_theme_font_size_override("font_size", _fs(20))
		_style_lecture_button(again, COLOR_BLUE_50, COLOR_AMBER_500, COLOR_SLATE_800)
		again.pressed.connect(func(): choice["v"] = 1)
		buttons_row.add_child(again)

		var next = Button.new()
		next.text = "Next ->"
		next.custom_minimum_size = Vector2(_ics(160), 54)
		next.add_theme_font_size_override("font_size", _fs(20))
		_style_lecture_button(next, COLOR_BLUE_500, COLOR_BLUE_600, COLOR_WHITE)
		next.pressed.connect(func(): choice["v"] = 2)
		buttons_row.add_child(next)

		while choice["v"] == 0 and _alive(token):
			await get_tree().process_frame
		if choice["v"] != 1:
			return

func _make_number_card(value: int) -> PanelContainer:
	var card = PanelContainer.new()
	var w := _ics(64.0)
	var h := _ics(84.0)
	card.custom_minimum_size = Vector2(w, h)
	card.pivot_offset = Vector2(w, h) / 2.0
	card.resized.connect(func(): card.pivot_offset = card.size / 2.0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var lbl = Label.new()
	lbl.name = "Num"
	lbl.text = str(value)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", roundi(_ics(34.0)))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(lbl)

	_set_card_state(card, "idle")
	return card

func _set_card_state(card: PanelContainer, state: String) -> void:
	var style = StyleBoxFlat.new()
	style.set_corner_radius_all(12)
	style.set_border_width_all(3)
	style.content_margin_left = 8
	style.content_margin_right = 8
	var font_col : Color
	match state:
		"active":
			style.bg_color = COLOR_AMBER_100
			style.border_color = COLOR_AMBER_500
			font_col = COLOR_AMBER_500
		"done":
			style.bg_color = COLOR_GREEN_50
			style.border_color = COLOR_GREEN_500
			font_col = COLOR_GREEN_500
		_:
			style.bg_color = COLOR_WHITE
			style.border_color = COLOR_SLATE_300
			font_col = COLOR_SLATE_400
	card.add_theme_stylebox_override("panel", style)
	var lbl : Label = card.get_node("Num")
	lbl.add_theme_color_override("font_color", font_col)

# ---------- show / tap : live demo of a visual ----------
func _step_show(step: Dictionary, token: int, wait_for_next: bool) -> void:
	_stage_clear()
	var text := str(step.get("text", ""))
	var visual = step.get("visual", {})
	if typeof(visual) == TYPE_DICTIONARY and not visual.is_empty():
		var v : Dictionary = visual.duplicate(true)
		if wait_for_next and str(v.get("type", "")) == "shapes":
			v["interactive"] = true   # tap each side to count it
		_build_visual(v, lecture_stage_vbox)
		_stage_reveal()
	await _say_text(text, token)
	if not _alive(token):
		return
	if wait_for_next:
		await _wait_for_next(token)
	else:
		await _wait(0.9, token)

func _wait_for_next(token: int) -> void:
	var btn = Button.new()
	btn.text = "Next ->"
	btn.custom_minimum_size = Vector2(_ics(160), 54)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_size_override("font_size", _fs(20))
	_style_lecture_button(btn, COLOR_BLUE_500, COLOR_BLUE_600, COLOR_WHITE)
	lecture_stage_vbox.add_child(btn)
	_stage_reveal()
	var done := {"v": false}
	btn.pressed.connect(func(): done["v"] = true)
	_pulse_animation(btn)
	while not done["v"] and _alive(token):
		await get_tree().process_frame

# ---------- check : unscored mini question ----------
func _step_check(step: Dictionary, token: int) -> void:
	_stage_clear()
	var text := str(step.get("text", ""))
	var visual = step.get("visual", {})
	if typeof(visual) == TYPE_DICTIONARY and not visual.is_empty():
		_build_visual(visual, lecture_stage_vbox)

	var answer := str(step.get("answer", ""))
	var choices : Array = [answer]
	for o in step.get("options", []):
		var s := str(o)
		if not choices.has(s):
			choices.append(s)
	choices.shuffle()

	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	lecture_stage_vbox.add_child(grid)

	var result := {"v": 0, "answer": answer}
	var buttons : Array = []
	for c in choices:
		var b = Button.new()
		b.text = str(c)
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(_ics(150), 56)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", _fs(20))
		_style_solid_button(b, COLOR_WHITE, COLOR_SLATE_300, COLOR_SLATE_800)
		b.pivot_offset = Vector2(_ics(150), 56) / 2.0
		b.pressed.connect(_on_check_choice.bind(b, str(c) == answer, result, buttons))
		grid.add_child(b)
		buttons.append(b)
	_stage_reveal()

	await _say_text(text, token)
	while result["v"] == 0 and _alive(token):
		await get_tree().process_frame
	if not _alive(token):
		return
	if result["v"] == 1:
		await _say_text("Correct! Well done!", token)
	else:
		await _say_text("Not quite. The answer is %s." % answer, token)
	await _wait(0.6, token)

func _on_check_choice(btn: Button, is_right: bool, result: Dictionary, buttons: Array) -> void:
	if result["v"] != 0:
		return
	result["v"] = 1 if is_right else 2
	if is_right:
		_style_solid_button(btn, COLOR_GREEN_50, COLOR_GREEN_500, COLOR_GREEN_500)
		_pop_animation(btn)
	else:
		_style_solid_button(btn, COLOR_RED_50, COLOR_RED_500, COLOR_RED_500)
		_shake_animation(btn)
		for other in buttons:
			if other.text == str(result["answer"]):
				_style_solid_button(other, COLOR_GREEN_50, COLOR_GREEN_500, COLOR_GREEN_500)

# ---------- cheer ----------
func _step_cheer(step: Dictionary, token: int) -> void:
	_spawn_confetti()
	await _say_text(str(step.get("text", "Great job!")), token)
	await _wait(0.6, token)

# =====================================================================
#  VECTOR VISUALS: shapes, fractions, clocks
# =====================================================================
func _regular_polygon(sides: int, rotation_offset: float = 0.0) -> PackedVector2Array:
	var n := maxi(3, sides)
	var start := -PI / 2.0 + rotation_offset
	if n % 2 == 0:
		start += PI / n          # even polygons sit flat
	var raw : Array = []
	var min_x := INF
	var min_y := INF
	var max_x := -INF
	var max_y := -INF
	for i in range(n):
		var a := start + TAU * i / n
		var p := Vector2(cos(a), sin(a))
		raw.append(p)
		min_x = minf(min_x, p.x)
		min_y = minf(min_y, p.y)
		max_x = maxf(max_x, p.x)
		max_y = maxf(max_y, p.y)
	var span := maxf(max_x - min_x, max_y - min_y)
	var off_x := (1.0 - (max_x - min_x) / span) / 2.0
	var off_y := (1.0 - (max_y - min_y) / span) / 2.0
	var pts := PackedVector2Array()
	for p in raw:
		pts.append(Vector2((p.x - min_x) / span + off_x, (p.y - min_y) / span + off_y))
	return pts

## Points (0..1 box) for a shape definition: {"sides":n} or {"points":[[x,y],..]}.
func _shape_points(d: Dictionary) -> PackedVector2Array:
	if d.has("points"):
		var pts := PackedVector2Array()
		for p in d["points"]:
			pts.append(Vector2(float(p[0]), float(p[1])))
		return pts
	return _regular_polygon(int(d.get("sides", 3)), float(d.get("rotation", 0.0)))

func _shape_key(d: Dictionary, fallback: int) -> String:
	return str(d.get("id", d.get("name", d.get("sides", fallback))))

func _shape_label(d: Dictionary) -> String:
	if d.has("label"):
		return str(d["label"])
	if d.has("sides"):
		return "%d sides" % int(d["sides"])
	return ""

func _build_shapes_visual(defs: Array, parent: Container, interactive: bool) -> void:
	var flow = _make_flow(22, 16)
	parent.add_child(flow)
	for i in range(defs.size()):
		var d : Dictionary = defs[i]
		var col = VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 6)
		flow.add_child(col)

		var view = PolyView.new()
		view.points = _shape_points(d)
		view.fill = SHAPE_COLORS[i % SHAPE_COLORS.size()]
		view.custom_minimum_size = Vector2(_ics(96.0), _ics(96.0))
		view.interactive = interactive
		view.mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
		if interactive:
			view.side_counted.connect(func(n: int):
				_speak(_number_to_word(n))
				_pop_centered(view)
			)
		col.add_child(view)

		if d.has("label"):
			var lbl = Label.new()
			lbl.text = str(d["label"])
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.add_theme_font_size_override("font_size", _fs(15))
			lbl.add_theme_color_override("font_color", COLOR_SLATE_700)
			col.add_child(lbl)

func _build_fraction_visual(bars: Array, parent: Container) -> void:
	var col = VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)
	parent.add_child(col)
	for b in bars:
		var bar = FractionBar.new()
		bar.parts = maxi(1, int(b.get("parts", 2)))
		bar.filled = int(b.get("filled", 1))
		bar.custom_minimum_size = Vector2(_ics(260.0), _ics(46.0))
		bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(bar)

func _build_clock_visual(clocks: Array, parent: Container) -> void:
	var flow = _make_flow(18, 12)
	parent.add_child(flow)
	for c in clocks:
		var clk = ClockView.new()
		clk.hour = int(c.get("hour", 12))
		clk.minute = int(c.get("minute", 0))
		clk.custom_minimum_size = Vector2(_ics(150.0), _ics(150.0))
		clk.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flow.add_child(clk)

# =====================================================================
#  PUZZLE 1: shape_match  (drag each shape onto its matching outline)
# =====================================================================
func _build_shape_match(data: Dictionary, parent: Container) -> void:
	var defs : Array = data.get("shapes", [])
	if defs.is_empty():
		return
	var piece_size := _ics(92.0)
	var state := {"placed": 0, "total": defs.size(), "mistakes": 0, "done": false}

	var board = _make_flow(18, 18)
	parent.add_child(board)

	var divider = _make_hint_label("Pieces")
	parent.add_child(divider)

	var tray = _make_flow(18, 18)
	parent.add_child(tray)

	for i in range(defs.size()):
		var d : Dictionary = defs[i]
		var key := _shape_key(d, i)

		var col = VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 6)
		board.add_child(col)

		var slot = ShapeSlot.new()
		slot.key = key
		slot.points = _shape_points(d)
		slot.fill = Color(0, 0, 0, 0.06)
		slot.outline = COLOR_SLATE_400
		slot.dashed = true
		slot.custom_minimum_size = Vector2(piece_size, piece_size)
		slot.dropped.connect(_on_shape_dropped.bind(state))
		col.add_child(slot)

		var text = _shape_label(d)
		if text != "":
			var lbl = Label.new()
			lbl.text = text
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.add_theme_font_size_override("font_size", _fs(15))
			lbl.add_theme_color_override("font_color", COLOR_SLATE_700)
			col.add_child(lbl)

	var order : Array = range(defs.size())
	order.shuffle()
	for i in order:
		var d2 : Dictionary = defs[i]
		var piece = ShapePiece.new()
		piece.key = _shape_key(d2, i)
		piece.points = _shape_points(d2)
		piece.fill = SHAPE_COLORS[i % SHAPE_COLORS.size()]
		piece.custom_minimum_size = Vector2(piece_size, piece_size)
		tray.add_child(piece)

func _on_shape_dropped(slot, data, state: Dictionary) -> void:
	if state["done"] or typeof(data) != TYPE_DICTIONARY:
		return
	var piece = data.get("piece")
	if str(data.get("key", "")) == str(slot.key):
		slot.filled = true
		slot.dashed = false
		slot.fill = piece.fill
		slot.outline = COLOR_SLATE_800
		slot.queue_redraw()
		_pop_centered(slot)
		if is_instance_valid(piece):
			piece.call_deferred("hide")
		state["placed"] += 1
		if state["placed"] >= state["total"]:
			_finish_puzzle(state)
	else:
		state["mistakes"] += 1
		_flash_red(slot)
		if is_instance_valid(piece):
			_shake_animation(piece)

# =====================================================================
#  PUZZLE 2: block_stack  (arrange blocks by height)
# =====================================================================
func _build_block_stack(data: Dictionary, parent: Container) -> void:
	var heights : Array = data.get("heights", [])
	if heights.size() < 2:
		return
	var descending := str(data.get("order", "asc")) == "desc"
	var show_values := bool(data.get("show_values", true))

	var target : Array = []
	var max_h := 1
	for h in heights:
		target.append(int(h))
		max_h = maxi(max_h, int(h))
	target.sort()
	if descending:
		target.reverse()

	var unit := _ics(26.0)
	var block_w := _ics(52.0)
	var state := {"placed": 0, "total": heights.size(), "mistakes": 0, "done": false}

	var hint = _make_hint_label("Biggest on the left, smallest on the right." if descending else "Smallest on the left, biggest on the right.")
	parent.add_child(hint)

	var bays_row = HBoxContainer.new()
	bays_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bays_row.add_theme_constant_override("separation", 8)
	parent.add_child(bays_row)
	for i in range(target.size()):
		var bay = BlockBay.new()
		bay.expected = int(target[i])
		bay.unit_px = unit
		bay.show_value = show_values
		bay.custom_minimum_size = Vector2(block_w + 8.0, unit * max_h + 8.0)
		bay.dropped.connect(_on_block_dropped.bind(state))
		bays_row.add_child(bay)

	var tray = HBoxContainer.new()
	tray.alignment = BoxContainer.ALIGNMENT_CENTER
	tray.add_theme_constant_override("separation", 10)
	parent.add_child(tray)

	var shuffled : Array = heights.duplicate()
	shuffled.shuffle()
	for h in shuffled:
		var units := int(h)
		var blk = BlockPiece.new()
		blk.units = units
		blk.unit_px = unit
		blk.show_value = show_values
		blk.color = BLOCK_COLORS[(units - 1) % BLOCK_COLORS.size()]
		blk.custom_minimum_size = Vector2(block_w, unit * units)
		blk.size_flags_vertical = Control.SIZE_SHRINK_END
		tray.add_child(blk)

func _on_block_dropped(bay, data, state: Dictionary) -> void:
	if state["done"] or typeof(data) != TYPE_DICTIONARY:
		return
	var piece = data.get("piece")
	var units := int(data.get("units", 0))
	if units == bay.expected:
		bay.filled_units = units
		bay.filled_color = piece.color
		bay.queue_redraw()
		_pop_centered(bay)
		if is_instance_valid(piece):
			piece.call_deferred("hide")
		state["placed"] += 1
		if state["placed"] >= state["total"]:
			_finish_puzzle(state)
	else:
		state["mistakes"] += 1
		_flash_red(bay)
		if is_instance_valid(piece):
			_shake_animation(piece)

# =====================================================================
#  PUZZLE 3: connect_dots  (tap the dots in order)
# =====================================================================
func _build_connect_dots(data: Dictionary, parent: Container) -> void:
	var raw : Array = data.get("dots", [])
	if raw.size() < 2:
		return
	var canvas = DotCanvas.new()
	for p in raw:
		canvas.dots.append(Vector2(float(p[0]), float(p[1])))
	var lbls = data.get("labels", [])
	if typeof(lbls) == TYPE_ARRAY:
		canvas.labels = lbls
	canvas.close_shape = bool(data.get("close", false))
	canvas.custom_minimum_size = Vector2(_ics(300.0), _ics(240.0))
	canvas.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var state := {"mistakes": 0, "done": false}
	canvas.dot_tapped.connect(_on_dot_tapped.bind(canvas, state))
	parent.add_child(canvas)

func _on_dot_tapped(index: int, canvas, state: Dictionary) -> void:
	if state["done"]:
		return
	if index == canvas.connected:
		canvas.connected += 1
		_speak(canvas.label_for(index))
		canvas.queue_redraw()
		if canvas.connected >= canvas.dots.size():
			canvas.complete = true
			canvas.queue_redraw()
			_finish_puzzle(state)
	elif index > canvas.connected:
		state["mistakes"] += 1
		_flash_red(canvas)

# =====================================================================
#  INNER CLASSES (all drawing is vector based, no image assets)
# =====================================================================
class PolyView extends Control:
	signal side_counted(count: int)
	var points : PackedVector2Array = PackedVector2Array()
	var fill : Color = Color(1, 1, 1, 1)
	var outline : Color = Color("#3b2a1a")
	var counted_color : Color = Color("#2f5233")
	var text_color : Color = Color("#3b2a1a")
	var line_w : float = 3.0
	var dashed : bool = false
	var interactive : bool = false
	var counted : Array = []
	var counted_n : int = 0

	func _px() -> PackedVector2Array:
		var out := PackedVector2Array()
		for p in points:
			out.append(Vector2(p.x * size.x, p.y * size.y))
		return out

	func _draw() -> void:
		var pts := _px()
		if pts.size() < 3:
			return
		if fill.a > 0.0:
			draw_colored_polygon(pts, fill)
		for i in range(pts.size()):
			var a := pts[i]
			var b := pts[(i + 1) % pts.size()]
			var is_counted : bool = i < counted.size() and counted[i]
			var col := counted_color if is_counted else outline
			var w := line_w + (3.0 if is_counted else 0.0)
			if dashed and not is_counted:
				draw_dashed_line(a, b, col, w, 8.0)
			else:
				draw_line(a, b, col, w, true)
		if counted_n > 0:
			var font := ThemeDB.fallback_font
			var fs := int(size.y * 0.34)
			var label := str(counted_n)
			var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(font, Vector2((size.x - tw) / 2.0, size.y / 2.0 + fs * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)

	func _gui_input(event: InputEvent) -> void:
		if not interactive:
			return
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var pts := _px()
			if pts.size() < 3:
				return
			var best := -1
			var best_d := 28.0
			for i in range(pts.size()):
				var a := pts[i]
				var b := pts[(i + 1) % pts.size()]
				var d : float = event.position.distance_to(Geometry2D.get_closest_point_to_segment(event.position, a, b))
				if d < best_d:
					best_d = d
					best = i
			if best == -1:
				return
			while counted.size() < pts.size():
				counted.append(false)
			if counted[best]:
				return
			counted[best] = true
			counted_n += 1
			queue_redraw()
			side_counted.emit(counted_n)

class ShapePiece extends PolyView:
	var key : String = ""

	func _get_drag_data(_at_position: Vector2) -> Variant:
		var preview = PolyView.new()
		preview.points = points
		preview.fill = fill
		preview.outline = outline
		preview.size = size
		preview.modulate.a = 0.85
		preview.position = -size / 2.0
		var holder = Control.new()
		holder.add_child(preview)
		set_drag_preview(holder)
		modulate.a = 0.35
		return {"kind": "shape", "key": key, "piece": self}

	func _notification(what: int) -> void:
		if what == NOTIFICATION_DRAG_END:
			modulate.a = 1.0

class ShapeSlot extends PolyView:
	signal dropped(slot, data)
	var key : String = ""
	var filled : bool = false

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		return not filled and typeof(data) == TYPE_DICTIONARY and str(data.get("kind", "")) == "shape"

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		dropped.emit(self, data)

class BlockPiece extends Control:
	var units : int = 1
	var unit_px : float = 26.0
	var show_value : bool = true
	var color : Color = Color("#d98a6c")

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, color, true)
		draw_rect(r, Color("#3b2a1a"), false, 3.0)
		if show_value:
			var font := ThemeDB.fallback_font
			var fs := 20
			var label := str(units)
			var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(font, Vector2((size.x - tw) / 2.0, size.y / 2.0 + fs * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#241a10"))

	func _get_drag_data(_at_position: Vector2) -> Variant:
		var preview = BlockPiece.new()
		preview.units = units
		preview.unit_px = unit_px
		preview.show_value = show_value
		preview.color = color
		preview.size = size
		preview.modulate.a = 0.85
		preview.position = -size / 2.0
		var holder = Control.new()
		holder.add_child(preview)
		set_drag_preview(holder)
		modulate.a = 0.35
		return {"kind": "block", "units": units, "piece": self}

	func _notification(what: int) -> void:
		if what == NOTIFICATION_DRAG_END:
			modulate.a = 1.0

class BlockBay extends Control:
	signal dropped(bay, data)
	var expected : int = 1
	var filled_units : int = 0
	var filled_color : Color = Color("#e8c97a")
	var unit_px : float = 26.0
	var show_value : bool = true

	func _draw() -> void:
		var edge := Color("#8a7147")
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0, 0, 0, 0.05), true)
		if filled_units == 0:
			draw_dashed_line(r.position, Vector2(r.end.x, r.position.y), edge, 2.0, 6.0)
			draw_dashed_line(Vector2(r.end.x, r.position.y), r.end, edge, 2.0, 6.0)
			draw_dashed_line(r.end, Vector2(r.position.x, r.end.y), edge, 2.0, 6.0)
			draw_dashed_line(Vector2(r.position.x, r.end.y), r.position, edge, 2.0, 6.0)
		else:
			var h := filled_units * unit_px
			var br := Rect2(Vector2(4.0, size.y - 4.0 - h), Vector2(size.x - 8.0, h))
			draw_rect(br, filled_color, true)
			draw_rect(br, Color("#3b2a1a"), false, 3.0)
			if show_value:
				var font := ThemeDB.fallback_font
				var fs := 20
				var label := str(filled_units)
				var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				draw_string(font, Vector2((size.x - tw) / 2.0, br.position.y + h / 2.0 + fs * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#241a10"))

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		return filled_units == 0 and typeof(data) == TYPE_DICTIONARY and str(data.get("kind", "")) == "block"

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		dropped.emit(self, data)

class DotCanvas extends Control:
	signal dot_tapped(index: int)
	var dots : PackedVector2Array = PackedVector2Array()
	var labels : Array = []
	var connected : int = 0
	var complete : bool = false
	var close_shape : bool = false
	var dot_radius : float = 17.0
	var line_color : Color = Color("#2f5233")

	func label_for(i: int) -> String:
		if i < labels.size():
			return str(labels[i])
		return str(i + 1)

	func _draw() -> void:
		var pts : Array = []
		for d in dots:
			pts.append(Vector2(d.x * size.x, d.y * size.y))
		if complete and close_shape and pts.size() >= 3:
			draw_colored_polygon(PackedVector2Array(pts), Color(0.18, 0.32, 0.2, 0.25))
		for i in range(1, mini(connected, pts.size())):
			draw_line(pts[i - 1], pts[i], line_color, 5.0, true)
		if complete and close_shape and pts.size() >= 2:
			draw_line(pts[pts.size() - 1], pts[0], line_color, 5.0, true)
		var font := ThemeDB.fallback_font
		var fs := 18
		for i in range(pts.size()):
			var done_dot := i < connected
			var is_next := i == connected
			var fill_c := Color("#f7ead0")
			if done_dot:
				fill_c = Color("#2f5233")
			elif is_next:
				fill_c = Color("#f0dfa0")
			var ring := Color("#a8781a") if is_next else Color("#3b2a1a")
			draw_circle(pts[i], dot_radius, fill_c)
			draw_arc(pts[i], dot_radius, 0.0, TAU, 32, ring, 3.0, true)
			var text := label_for(i)
			var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var tcol := Color("#f7ead0") if done_dot else Color("#241a10")
			draw_string(font, pts[i] + Vector2(-tw / 2.0, fs * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tcol)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var best := -1
			var best_d := dot_radius + 14.0
			for i in range(dots.size()):
				var p := Vector2(dots[i].x * size.x, dots[i].y * size.y)
				var d : float = event.position.distance_to(p)
				if d < best_d:
					best_d = d
					best = i
			if best != -1:
				dot_tapped.emit(best)

class FractionBar extends Control:
	var parts : int = 2
	var filled : int = 1

	func _draw() -> void:
		var gap := 3.0
		var cw := (size.x - gap * (parts - 1)) / parts
		for i in range(parts):
			var r := Rect2(Vector2(i * (cw + gap), 0.0), Vector2(cw, size.y))
			var col := Color("#c9962b") if i < filled else Color("#f7ead0")
			draw_rect(r, col, true)
			draw_rect(r, Color("#3b2a1a"), false, 2.0)

class ClockView extends Control:
	var hour : int = 12
	var minute : int = 0

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) / 2.0 - 4.0
		draw_circle(c, r, Color("#f7ead0"))
		draw_arc(c, r, 0.0, TAU, 64, Color("#3b2a1a"), 4.0, true)
		var font := ThemeDB.fallback_font
		var fs := int(r * 0.26)
		for n in range(1, 13):
			var a := TAU * n / 12.0
			var p := c + Vector2(sin(a), -cos(a)) * (r * 0.78)
			var label := str(n)
			var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(font, p + Vector2(-tw / 2.0, fs * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#3b2a1a"))
		var ma := TAU * minute / 60.0
		var ha := TAU * ((hour % 12) + minute / 60.0) / 12.0
		draw_line(c, c + Vector2(sin(ha), -cos(ha)) * r * 0.5, Color("#241a10"), 6.0, true)
		draw_line(c, c + Vector2(sin(ma), -cos(ma)) * r * 0.75, Color("#8a1f1f"), 4.0, true)
		draw_circle(c, 6.0, Color("#241a10"))
