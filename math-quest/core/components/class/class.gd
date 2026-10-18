extends Control
class_name Scholl

# =====================================================================
#  AcadeMath class  -  "math magic" stage
#
#  Left : ClassStage   drawn classroom where Matthew works at a station
#                      (cauldron, magic circle, scale, clock tower ...)
#  Right: panel        question card + an answer input that fits the
#                      answer (number pad, fraction pad, clock, tiles,
#                      rune tokens) + one big action button
#
#  Flow:  LECTURE -> ASK -> RESOLVE -> ... -> COMPLETE
#  Data:  res://data/curriculum.json (unchanged format; optional fields
#         "station" and "input" on a lesson/question pick the station or
#         input explicitly, see station_picker.gd / answer_rules.gd)
# =====================================================================

signal class_end(currentGrade: String, currentLesson : String)

@export var current_lesson : String = "g1-l1"
@export var current_grade : String = "g1"

@export_range(0.5, 3.0, 0.05) var font_scale : float = 1.0
@export_range(0.5, 3.0, 0.05) var icon_scale : float = 1.0

const LESSONS_PER_GRADE := 10

# The final exam is exclusive: it only runs for progress that is exactly
# grade "g4" + lesson "final", and it is never listed on the relearn page.
const FINAL_EXAM_GRADE := "g4"
const FINAL_EXAM_LESSON := "final"

const _NUMBER_WORDS := [
	"zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine",
	"ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen",
	"seventeen", "eighteen", "nineteen"
]
const _TENS_WORDS := ["", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety"]

const SFX_DIR := "res://assets/audio/sfx/"
const SFX_NAMES := ["chime", "fire", "shatter"]

# --- data / progress ---
var lesson_database : Dictionary = {}
var current_lesson_data : Dictionary = {}
var _lesson_available : bool = false
var _is_relearning : bool = false
var _session_id : String = ""

# --- question flow ---
var _queue : Array = []             # {"q": question, "kind": "normal"}
var current_question_idx : int = 0
var exam_status : String = "idle"   # idle | resolving | correct | incorrect | complete | curriculum_complete
var _input_type : String = "number"
var _station_kind : String = ""
var _question_start_ms : int = 0
var _streak : int = 0
var _wrong_count : int = 0
var _hint_used : bool = false
var _last_wrong : bool = false     # makes the hint bulb pulse on the next question

# --- nodes ---
var _main : VBoxContainer
var _body : BoxContainer
var hud : ClassHud
var stage : ClassStage
var _panel : PanelContainer
var card : QuestionCard
var _input_holder : VBoxContainer
var answer_input : AnswerInput = null
var action_button : Button
var _action_pulse : Tween = null

# --- lecture ---
var _lecture : LectureRunner
var _lecture_row : HBoxContainer
var _begin_button : Button
var _begin_pulse : Tween = null

# --- answer feedback ---
const PRAISE := [
	"Correct! The magic worked!",
	"Well done, young wizard!",
	"Perfect spell!",
	"That's right! Brilliant!",
	"Correct! Great thinking!",
]
const ENCOURAGE := ["Not quite!", "Almost!", "Oops, not this time!"]
var feedback : FeedbackPopup

var _overlay : Control
var _complete_box : VBoxContainer
var _complete_label : Label
var _complete_action : Button
var _relearn_button : Button
var _relearn_box : VBoxContainer
var _relearn_list : VBoxContainer

# --- voice / sound ---
var _tts_voice_id : String = ""
var _sfx_player : AudioStreamPlayer = null
var _sfx : Dictionary = {}


func _fs(base: int) -> int:
	return roundi(base * font_scale)


func _ready() -> void:
	_load_active_curriculum()
	_setup_database()
	_build_ui()
	_prepare_tts()
	_prepare_sfx()
	_lesson_available = _lesson_exists(current_grade, current_lesson)
	hide()
	#start_class()


# =====================================================================
#  ENTRY POINTS (used by world.gd / earth_classroom.gd)
# =====================================================================
func start_class() -> void:
	_load_active_curriculum()
	_is_relearning = false
	_lesson_available = _lesson_exists(current_grade, current_lesson)
	show()
	GameManager.game_time_enabled = false
	if _lesson_available:
		_start_lesson()
	else:
		current_lesson_data = {}
		_show_curriculum_complete()


func _load_active_curriculum() -> void:
	var result = db.query("SELECT current_grade, current_lesson FROM progress WHERE is_active = true LIMIT 1")
	if typeof(result) != TYPE_DICTIONARY or typeof(result.get("data")) != TYPE_ARRAY or result.data.is_empty():
		push_warning("Class: no active progress row, keeping %s / %s" % [current_grade, current_lesson])
		return
	var data = result.data[0]
	current_grade = data.current_grade
	current_lesson = data.current_lesson


func _setup_database() -> void:
	var file_path := "res://data/curriculum.json"
	if not FileAccess.file_exists(file_path):
		push_error("Curriculum file not found at: ", file_path)
		return
	var json := JSON.new()
	var error := json.parse(FileAccess.get_file_as_string(file_path))
	if error != OK:
		push_error("JSON Parse Error: ", json.get_error_message())
		return
	if typeof(json.get_data()) == TYPE_DICTIONARY:
		lesson_database = json.get_data()
	else:
		push_error("Parsed JSON is not a dictionary.")


# =====================================================================
#  UI
# =====================================================================
func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = ClassTheme.WALL
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_main = VBoxContainer.new()
	_main.set_anchors_preset(Control.PRESET_FULL_RECT)
	_main.add_theme_constant_override("separation", 0)
	add_child(_main)

	hud = ClassHud.new()
	hud.font_scale = font_scale
	hud.build()
	_main.add_child(hud)

	_body = BoxContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 0)
	_main.add_child(_body)

	stage = ClassStage.new()
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.size_flags_stretch_ratio = 1.4
	_body.add_child(stage)

	_panel = PanelContainer.new()
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var panel_style := ClassTheme.flat(ClassTheme.PARCHMENT_DARK, ClassTheme.GOLD, 0, 0, 14)
	panel_style.border_width_left = 4
	_panel.add_theme_stylebox_override("panel", panel_style)
	_body.add_child(_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_panel.add_child(col)

	var card_scroll := ScrollContainer.new()
	card_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(card_scroll)
	card = QuestionCard.new()
	card.font_scale = font_scale
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.build()
	card.speak_requested.connect(_speak)
	card.hint_requested.connect(_on_hint_requested)
	card_scroll.add_child(card)

	_input_holder = VBoxContainer.new()
	col.add_child(_input_holder)

	action_button = Button.new()
	action_button.custom_minimum_size = Vector2(0, 62)
	action_button.pressed.connect(_on_action_pressed)
	col.add_child(action_button)

	# During the lecture the action button is swapped for these two
	_lecture_row = HBoxContainer.new()
	_lecture_row.add_theme_constant_override("separation", 10)
	_lecture_row.hide()
	col.add_child(_lecture_row)
	var replay := Button.new()
	replay.text = "Watch Again"
	replay.custom_minimum_size = Vector2(0, 62)
	replay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ClassTheme.style_button(replay, ClassTheme.PARCHMENT, ClassTheme.GOLD, ClassTheme.INK, _fs(20))
	replay.pressed.connect(_on_lecture_replay_pressed)
	_lecture_row.add_child(replay)
	_begin_button = Button.new()
	_begin_button.text = "Begin Trial ->"
	_begin_button.custom_minimum_size = Vector2(0, 62)
	_begin_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_begin_button.size_flags_stretch_ratio = 1.3
	ClassTheme.style_button(_begin_button, ClassTheme.CRIMSON, ClassTheme.CRIMSON_DARK, ClassTheme.PARCHMENT, _fs(22))
	_begin_button.pressed.connect(_on_lecture_begin_pressed)
	_lecture_row.add_child(_begin_button)

	feedback = FeedbackPopup.new()
	feedback.font_scale = font_scale
	feedback.build()
	feedback.next_pressed.connect(_on_action_pressed)
	add_child(feedback.layer)   # full screen, above the stage and panel

	_lecture = LectureRunner.new()
	_lecture.cls = self
	_lecture.finished.connect(_on_lecture_finished)
	add_child(_lecture)

	_build_overlay()
	resized.connect(_apply_orientation)
	_apply_orientation()


## Landscape: stage left / panel right.  Portrait: stage on top.
func _apply_orientation() -> void:
	if _body == null:
		return
	var portrait := size.y > size.x
	_body.vertical = portrait
	stage.size_flags_stretch_ratio = 0.8 if portrait else 1.4


func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.hide()
	add_child(_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.05, 0.1, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", ClassTheme.flat(ClassTheme.PARCHMENT, ClassTheme.GOLD, 20, 4, 26))
	center.add_child(frame)

	# --- lesson complete / curriculum complete ---
	_complete_box = VBoxContainer.new()
	_complete_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_complete_box.add_theme_constant_override("separation", 16)
	frame.add_child(_complete_box)

	var trophy := TextureRect.new()
	trophy.texture = load("res://assets/trophy.svg")
	trophy.custom_minimum_size = Vector2(110, 110)
	trophy.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	trophy.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	trophy.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_complete_box.add_child(trophy)

	_complete_label = ClassTheme.label("", _fs(28), ClassTheme.GOLD)
	_complete_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_complete_label.custom_minimum_size = Vector2(380, 0)
	_complete_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_complete_box.add_child(_complete_label)

	_complete_action = Button.new()
	_complete_action.custom_minimum_size = Vector2(300, 56)
	_complete_action.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ClassTheme.style_button(_complete_action, ClassTheme.CRIMSON, ClassTheme.CRIMSON_DARK, ClassTheme.PARCHMENT, _fs(20))
	_complete_action.pressed.connect(_on_complete_action_pressed)
	_complete_box.add_child(_complete_action)

	_relearn_button = Button.new()
	_relearn_button.text = "Relearn a Spell"
	_relearn_button.custom_minimum_size = Vector2(300, 50)
	_relearn_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ClassTheme.style_button(_relearn_button, ClassTheme.PARCHMENT_DARK, ClassTheme.GOLD, ClassTheme.INK, _fs(18))
	_relearn_button.pressed.connect(_show_relearn_grid)
	_complete_box.add_child(_relearn_button)

	# --- relearn grid ---
	_relearn_box = VBoxContainer.new()
	_relearn_box.add_theme_constant_override("separation", 12)
	_relearn_box.hide()
	frame.add_child(_relearn_box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	_relearn_box.add_child(head)
	var back := Button.new()
	back.text = "<- Back"
	back.custom_minimum_size = Vector2(120, 44)
	ClassTheme.style_button(back, ClassTheme.SAND, ClassTheme.SAND_DARK, ClassTheme.INK, _fs(18))
	back.pressed.connect(_on_relearn_back_pressed)
	head.add_child(back)
	head.add_child(ClassTheme.label("Choose a Spell to Relearn", _fs(22), ClassTheme.INK))

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(680, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_relearn_box.add_child(scroll)
	_relearn_list = VBoxContainer.new()
	_relearn_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_relearn_list.add_theme_constant_override("separation", 14)
	scroll.add_child(_relearn_list)


# =====================================================================
#  LESSON FLOW
# =====================================================================
func _start_lesson() -> void:
	current_lesson_data = {}
	if not lesson_database.has(current_grade):
		return
	for lesson in lesson_database[current_grade]:
		if lesson.has("id") and lesson["id"] == current_lesson:
			current_lesson_data = lesson
			break
	if current_lesson_data.is_empty():
		return

	_lecture.stop()
	feedback.close()
	_overlay.hide()
	_main.show()
	_streak = 0
	_wrong_count = 0
	_station_kind = ""
	_last_wrong = false
	hud.set_title(str(current_lesson_data.get("title", "")))
	hud.set_stars(_stars_now())
	hud.set_streak(0)
	_build_queue()
	_session_id = str(int(Time.get_unix_time_from_system()))
	stage.board(str(current_lesson_data.get("title", "")))
	var final_exam := _is_final_exam(current_grade, current_lesson)
	stage.set_teacher("cruz" if final_exam else "archimedes")
	_lecture.teacher_name = "Ma'am Cruz" if final_exam else "Mr. Archimedes"
	var steps := _lecture_steps()
	if steps.is_empty():
		_begin_questions()
	else:
		_start_lecture(steps)


## lecture_steps, or the old plain "lecture" paragraph as one "say" step.
func _lecture_steps() -> Array:
	var steps = current_lesson_data.get("lecture_steps", [])
	if typeof(steps) == TYPE_ARRAY and not steps.is_empty():
		return steps
	var text := str(current_lesson_data.get("lecture", ""))
	return [] if text.strip_edges() == "" else [{"type": "say", "text": text}]


# =====================================================================
#  LECTURE
# =====================================================================
func _start_lecture(steps: Array) -> void:
	exam_status = "lecture"
	card.set_hint_available(false)
	if answer_input:
		answer_input.queue_free()
		answer_input = null
	action_button.hide()
	# Watch Again / Begin Trial only appear once the lecture has finished
	_lecture_row.hide()
	_stop_begin_pulse()
	hud.set_progress(0, _queue.size())
	_lecture.run(steps)


func _on_lecture_finished() -> void:
	# The lecture is over: reveal the buttons and gently pulse "Begin Trial"
	_lecture_row.show()
	ClassTheme.pop(_lecture_row, 1.06)
	_stop_begin_pulse()
	_begin_pulse = ClassTheme.pulse(_begin_button)


func _stop_begin_pulse() -> void:
	if _begin_pulse and _begin_pulse.is_valid():
		_begin_pulse.kill()
	_begin_button.modulate.a = 1.0


func _on_lecture_replay_pressed() -> void:
	_lecture.stop()
	_stop_begin_pulse()
	_lecture_row.hide()
	_lecture.run(_lecture_steps())


func _on_lecture_begin_pressed() -> void:
	_lecture.stop()
	_stop_begin_pulse()
	_lecture_row.hide()
	action_button.show()
	action_button.disabled = true
	await stage.leave_lecture()
	_begin_questions()


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


func _begin_questions() -> void:
	_lecture_row.hide()
	action_button.show()
	if stage.lecture_mode:
		await stage.leave_lecture()
	current_question_idx = 0
	_load_question()


func _load_question() -> void:
	if current_question_idx >= _queue.size():
		_show_lesson_complete()
		return
	var q := _current_q()
	exam_status = "idle"
	feedback.close()
	hud.set_progress(current_question_idx, _queue.size())

	_input_type = AnswerRules.detect(q)
	_use_station(StationPicker.pick(current_lesson_data, q, _input_type))
	stage.station.setup(q, _input_type)
	var board := stage.station.board_text()
	stage.board(board if board != "" else str(current_lesson_data.get("title", "")))

	card.show_question(str(q.get("text", "")), "Spell %d of %d" % [current_question_idx + 1, _queue.size()])
	_hint_used = false
	card.set_hint_available(true, _last_wrong)
	_mount_input(q)
	_set_action("cast")
	_question_start_ms = Time.get_ticks_msec()


func _use_station(kind: String, force: bool = false) -> void:
	if kind == _station_kind and stage.station and not force:
		return
	_station_kind = kind
	var st : Station
	match kind:
		"circle":
			st = CircleStation.new()
		"scale":
			st = ScaleStation.new()
		"clock":
			st = ClockStation.new()
			st.time_set.connect(_on_clock_dragged)
		"rune_lock":
			st = RuneLockStation.new()
		"puzzle":
			st = PuzzleStation.new()
			st.solved.connect(_on_puzzle_solved)
		"counting":
			st = CountingStation.new()
			st.speak = _speak
			st.number_word = _number_to_word
		"shapes":
			st = ShapeStation.new()
			st.speak = _speak
			st.number_word = _number_to_word
		_:
			st = PotionStation.new()
	stage.set_station(st)


## The lightbulb: one hint per question, shown on the card (not read aloud).
func _on_hint_requested() -> void:
	if exam_status != "idle" or _hint_used:
		return
	_hint_used = true
	var text := AnswerExplainer.hint(_current_q(), _input_type)
	card.spend_hint()
	card.show_hint(text)


## Dragging the clock-tower hands fills the time boxes.
func _on_clock_dragged(hour: int, minute: int) -> void:
	if exam_status == "idle" and answer_input is TimeInput:
		answer_input.set_time(hour, minute)


## Puzzles finish on the stage: record the result and cast right away.
func _on_puzzle_solved(mistakes: int) -> void:
	if exam_status != "idle" or not (answer_input is PuzzleHint):
		return
	answer_input.set_result(mistakes, str(_current_q().get("answer", "solved")))
	_cast()


func _mount_input(q: Dictionary) -> void:
	if answer_input:
		answer_input.queue_free()
		answer_input = null
	var inp := _make_input(q, _input_type)
	_input_holder.add_child(inp)
	inp.setup(q)
	inp.value_changed.connect(_on_input_changed)
	inp.submitted.connect(_on_action_pressed)
	answer_input = inp


## The right input for an answer type (not yet set up / added).
func _make_input(_q: Dictionary, input_type: String) -> AnswerInput:
	var inp : AnswerInput
	match input_type:
		"puzzle":
			inp = PuzzleHint.new()
		"number":
			inp = NumberPad.new()
		"fraction":
			inp = FractionPad.new()
		"time":
			inp = TimeInput.new()
		"list":
			inp = OrderSlots.new()
		_:
			inp = ChoiceTokens.new()
	inp.font_scale = font_scale
	return inp


func _on_input_changed(value: String) -> void:
	if exam_status != "idle":
		return
	if stage.station:
		stage.station.preview(value)
	_set_action("cast")


## The single big button: CAST / BREW / UNLOCK -> (animating) -> NEXT.
func _set_action(state: String) -> void:
	if _action_pulse and _action_pulse.is_valid():
		_action_pulse.kill()
	action_button.modulate.a = 1.0
	match state:
		"cast":
			action_button.text = stage.station.action_label() if stage.station else "CAST!"
			var can_cast := answer_input != null and answer_input.get_value() != ""
			action_button.disabled = not can_cast
			ClassTheme.style_button(action_button, ClassTheme.CRIMSON, ClassTheme.CRIMSON_DARK, ClassTheme.PARCHMENT, _fs(24))
		"busy":
			action_button.text = "..."
			action_button.disabled = true
		"next":
			action_button.text = "NEXT ->"
			action_button.disabled = false
			ClassTheme.style_button(action_button, ClassTheme.GREEN, ClassTheme.GREEN.darkened(0.3), ClassTheme.PARCHMENT, _fs(24))
			_action_pulse = ClassTheme.pulse(action_button)


func _on_action_pressed() -> void:
	match exam_status:
		"idle":
			_cast()
		"correct", "incorrect":
			current_question_idx += 1
			_load_question()


func _cast() -> void:
	if answer_input == null or answer_input.get_value() == "":
		return
	var q := _current_q()
	if q.is_empty():
		return
	card.finish_typing()
	var given := answer_input.get_value()
	var expected := str(q.get("answer", ""))
	var is_correct := AnswerRules.matches(given, expected, _input_type)

	exam_status = "resolving"
	card.set_hint_available(false)
	_last_wrong = not is_correct
	_record_answer(q, AnswerRules.normalize(given, _input_type), is_correct)
	_register_result(is_correct)
	_set_action("busy")
	answer_input.lock(is_correct, expected)
	_play_sfx("fire" if is_correct else "shatter")

	await stage.play_result(is_correct)
	if not is_inside_tree() or exam_status != "resolving":
		return
	if not is_correct:
		stage.board(expected, "The spell needed this answer")
	exam_status = "correct" if is_correct else "incorrect"
	_set_action("next")
	_show_feedback(q, is_correct, expected)


## Pops up a cheer (with confetti) or the right answer and why, and reads
## it out loud.
func _show_feedback(q: Dictionary, is_correct: bool, expected: String) -> void:
	if is_correct:
		var msg : String = PRAISE[randi() % PRAISE.size()]
		ClassTheme.confetti(self)
		feedback.show_correct(msg)
		_speak(msg)
		return
	var title : String = ENCOURAGE[randi() % ENCOURAGE.size()]
	var why := ""
	if _input_type == "puzzle":
		why = "You solved it with %s. Try to place every piece right the first time!" % answer_input.get_value()
		feedback.show_wrong(title, "a perfect solve", why)
		_speak("%s %s" % [title, why])
		return
	why = AnswerExplainer.explain(q, _input_type)
	feedback.show_wrong(title, expected, why)
	_speak("%s The correct answer is %s. %s" % [title, expected, why])


func _record_answer(q: Dictionary, given: String, is_correct: bool) -> void:
	AnalysisReport.record_answer({
		"timestamp": int(Time.get_unix_time_from_system()),
		"datetime": Time.get_datetime_string_from_system(false, true),
		"session": _session_id,
		"grade": current_grade,
		"lesson": current_lesson,
		"lesson_title": str(current_lesson_data.get("title", current_lesson)),
		"question_idx": current_question_idx,
		"question": str(q.get("text", "")),
		"selected_answer": given,
		"correct_answer": str(q.get("answer", "")),
		"is_correct": is_correct,
		"time_ms": Time.get_ticks_msec() - _question_start_ms,
		"relearn": _is_relearning,
		"kind": str(_current_entry().get("kind", "normal")),
		"input": _input_type,
		"hint_used": _hint_used,
	})


# =====================================================================
#  STARS / STREAK
# =====================================================================
func _stars_now() -> int:
	if _wrong_count == 0:
		return 3
	if _wrong_count <= 2:
		return 2
	return 1


func _register_result(is_correct: bool) -> void:
	if is_correct:
		_streak += 1
	else:
		_streak = 0
		_wrong_count += 1
	hud.set_stars(_stars_now())
	hud.set_streak(_streak)
	if not is_correct:
		hud.shake_stars()


# =====================================================================
#  COMPLETE / CURRICULUM COMPLETE / RELEARN
# =====================================================================
func _show_lesson_complete() -> void:
	exam_status = "complete"
	feedback.close()
	if DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		DisplayServer.tts_stop()
	hud.set_progress(_queue.size(), _queue.size())
	if _is_relearning:
		_complete_label.text = "Spell Mastered!\n%s" % "⭐".repeat(_stars_now())
	else:
		_complete_label.text = "Spell Mastered!\n%s\n+%d KP" % ["⭐".repeat(_stars_now()), _get_reward_amount(current_grade, current_lesson)]
	_complete_action.text = "RETURN TO THE HALL"
	_relearn_button.hide()
	_relearn_box.hide()
	_complete_box.show()
	_overlay.show()
	ClassTheme.confetti(self)


func _show_curriculum_complete() -> void:
	exam_status = "curriculum_complete"
	_complete_label.text = "You've mastered every spell so far!"
	_complete_action.text = "Exit"
	_relearn_button.show()
	_relearn_box.hide()
	_complete_box.show()
	_overlay.show()


func _on_complete_action_pressed() -> void:
	if exam_status == "complete":
		if _is_relearning:
			_is_relearning = false
			_show_curriculum_complete()
			return
		_player_reward(_get_reward_amount(current_grade, current_lesson))
		class_end.emit(current_grade, current_lesson)
		_persist_next_progress()
		_close_class()
	elif exam_status == "curriculum_complete":
		class_end.emit(current_grade, current_lesson)
		_close_class()


func _close_class() -> void:
	_overlay.hide()
	hide()
	GameManager.game_time_enabled = true


func _show_relearn_grid() -> void:
	_populate_relearn_grid()
	_complete_box.hide()
	_relearn_box.show()


func _on_relearn_back_pressed() -> void:
	_show_curriculum_complete()


func _populate_relearn_grid() -> void:
	for child in _relearn_list.get_children():
		child.queue_free()
	var grade_keys := lesson_database.keys()
	grade_keys.sort_custom(func(a, b):
		return String(a).trim_prefix("g").to_int() < String(b).trim_prefix("g").to_int()
	)
	for grade in grade_keys:
		var lessons = lesson_database[grade]
		if typeof(lessons) != TYPE_ARRAY:
			continue
		var relearn_lessons : Array = []
		for lesson in lessons:
			if lesson.has("id") and not _is_final_exam(String(grade), str(lesson["id"])):
				relearn_lessons.append(lesson)
		if relearn_lessons.is_empty():
			continue
		_relearn_list.add_child(ClassTheme.label("Grade %s" % String(grade).trim_prefix("g"), _fs(20), ClassTheme.GOLD))
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 12)
		_relearn_list.add_child(grid)
		for lesson in relearn_lessons:
			var lesson_id := str(lesson["id"])
			var btn := Button.new()
			btn.text = str(lesson.get("title", lesson_id))
			btn.custom_minimum_size = Vector2(200, 64)
			btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var is_current : bool = grade == current_grade and lesson_id == current_lesson
			ClassTheme.style_button(btn, ClassTheme.PARCHMENT_DARK if is_current else ClassTheme.PARCHMENT, ClassTheme.SAND_DARK, ClassTheme.INK, _fs(15))
			btn.pressed.connect(_on_relearn_lesson_selected.bind(String(grade), lesson_id))
			grid.add_child(btn)


## Replays a lesson for practice without touching saved progress.
func _on_relearn_lesson_selected(grade: String, lesson_id: String) -> void:
	if _is_final_exam(grade, lesson_id):
		return
	_is_relearning = true
	current_grade = grade
	current_lesson = lesson_id
	_lesson_available = true
	_start_lesson()


# =====================================================================
#  PROGRESS + REWARDS
# =====================================================================
func _persist_next_progress() -> void:
	var grade_num := current_grade.trim_prefix("g").to_int()
	var lesson_num := 1
	var next_grade : String
	var next_lesson : String

	if _is_final_exam(current_grade, current_lesson):
		# Final exam passed: move past the last grade. Nothing exists there,
		# so the class will show the "all classes completed" screen from now on.
		grade_num += 1
		next_grade = "g%d" % grade_num
		next_lesson = "g%d-l1" % grade_num
	else:
		var lesson_parts := current_lesson.split("-l")
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


func _lesson_exists(grade: String, lesson_id: String) -> bool:
	# The final exam only counts as available for exactly g4 + "final".
	if lesson_id == FINAL_EXAM_LESSON and grade != FINAL_EXAM_GRADE:
		return false
	if not lesson_database.has(grade):
		return false
	for lesson in lesson_database[grade]:
		if lesson.has("id") and lesson["id"] == lesson_id:
			return true
	return false


func _is_final_exam(grade: String, lesson_id: String) -> bool:
	return grade == FINAL_EXAM_GRADE and lesson_id == FINAL_EXAM_LESSON


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


func _player_reward(kp_amount: int) -> void:
	var total_kp := GameManager.kp_amount + kp_amount
	db.query("UPDATE progress SET kp = %d WHERE is_active = true" % total_kp)
	GameManager._update_KP()


# =====================================================================
#  VOICE + SOUND
# =====================================================================
func _prepare_tts() -> void:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		return
	var voices := DisplayServer.tts_get_voices_for_language("en")
	if voices.is_empty():
		return
	# Same voice pick as before: the final exam swaps the mobile/desktop voices.
	var mobile := OS.get_name().to_lower() in ["android", "ios"]
	var is_final := _is_final_exam(current_grade, current_lesson)
	var idx := 0 if is_final == mobile else 1
	_tts_voice_id = voices[mini(idx, voices.size() - 1)]


func _speak(text: String) -> void:
	if text.is_empty() or not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		return
	DisplayServer.tts_stop()
	DisplayServer.tts_speak(AnswerExplainer.to_speech(text), _tts_voice_id, 90, 1.0, 1.0, 0, true)


func _number_to_word(n: int) -> String:
	if n < 0:
		return str(n)
	if n < 20:
		return _NUMBER_WORDS[n]
	if n < 100:
		var tens : String = _TENS_WORDS[n / 10]
		var ones := n % 10
		return tens if ones == 0 else "%s %s" % [tens, _NUMBER_WORDS[ones]]
	return str(n)


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
