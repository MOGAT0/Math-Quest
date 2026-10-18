extends Control
class_name BookApp

# =====================================================================
#  The entrance exam, as a treasure map: a dotted path of stops at the
#  top (one per page) and one big parchment card in the middle that
#  flips to the next page. Every chapter starts with a lesson card (tap
#  to count + one short line), then one card per question. Everything
#  fits on one screen; no scrolling.
#
#  Data: res://data/book_data.json (chapters -> lessonContent, exercises).
#  Pictures are counted in the order they are tapped: the 1st tap shows
#  1, the 2nd shows 2..., and the number is read out loud.
#  Each card reads itself out loud when it opens (lesson: title, idea and
#  tip; question: the question and what to do), 🔊 says it again. A right
#  answer flips to the next card by itself.
#  Solving every question shows the certificate; "Return" hides the exam
#  and emits isChapter_Done.
# =====================================================================

signal isChapter_Done

const DATA_PATH := "res://data/book_data.json"

const ITEM_EMOJI := {
	"star": "⭐", "can": "🥫", "box": "📦", "yoyo": "🪀", "balloon": "🎈",
	"backpack": "🎒", "strawberry": "🍓", "pineapple": "🍍", "apple": "🍎",
	"pencil": "✏️", "flower": "🌸"
}
const ROMAN := {1: "I", 2: "II", 3: "III", 4: "IV", 5: "V", 6: "VI", 7: "VII", 8: "VIII"}

# Palette (leather, parchment and gold)
const COL_DESK_BG := "#170e08"
const COL_LEATHER := "#2b120a"
const COL_GOLD := "#c5a059"
const COL_GOLD_LIGHT := "#ecd69e"
const COL_GOLD_DARK := "#9c7328"
const COL_PARCHMENT := "#faf4e5"
const COL_PARCHMENT_DARK := "#eee2c7"
const COL_INK := "#2c1d11"
const COL_INK_SOFT := "#5c3e23"
const COL_TRAIL := "#5c3b1e"
const COL_CORRECT := "#2f7a43"
const COL_WRONG := "#a32228"
const COL_SEAL := "#8d161d"

const MAP_H := 0.12          # map path height (share of the screen)
const CARD_W := 0.78         # card size (share of the screen)
const CARD_H := 0.74
const MAX_TILE := 64.0       # biggest picture tile (px at 648 high)
const MAX_LESSON_TILE := 96.0  # lessons show only a few pictures: bigger
const HINT_AFTER := 2        # wrong answers before the hint shows
const AUTO_NEXT_DELAY := 1.6 # seconds after a right answer before the next card

enum SignalType {
	Open, Close
}

# ------------------------------------------------------------------ TTS --
@export var tts_enabled: bool = true
@export_range(0.1, 10.0, 0.1) var tts_rate: float = 0.9
@export_range(0.0, 2.0, 0.1) var tts_pitch: float = 1.1
@export_range(0, 100, 1) var tts_volume: int = 100
## Kept for the scene's settings; the card sizes itself to the screen.
@export_range(0.5, 3.0, 0.05) var font_scale: float = 1.0
@export_range(0.5, 3.0, 0.05) var icon_scale: float = 1.0

var _tts_voice: String = ""

# ---------------------------------------------------------------- state --
var book_data: Array = []
## Every page in order: a lesson per chapter, then one per question
## ({"kind": "lesson"|"exercise", "ch": int, "ex": int}).
var _pages: Array = []
var current_page: int = 0
var _visited: Array = [0]
var completed_exercises: Array = []
var ex_state: Dictionary = {}       # exercise / practice id -> state
var show_certificate: bool = false

var _map: MapPath
var _card: PanelContainer
var _prev_btn: Button
var _next_btn: Button
var _flipping: bool = false


func _init_tts() -> void:
	var voices := DisplayServer.tts_get_voices_for_language("en")
	if voices.size() > 0:
		_tts_voice = voices[0]


func _speak_number(n: int) -> void:
	_say(str(n))


## Say something out loud (stops anything still being said). Emoji and
## arrows are left out so the voice doesn't read their names.
func _say(text: String) -> void:
	if not tts_enabled:
		return
	var clean := text.replace("→", ",").replace("+", " plus ").replace("=", " equals ")
	clean = RegEx.create_from_string("[^\\x{0020}-\\x{024F}]").sub(clean, "", true)
	clean = RegEx.create_from_string("\\s+").sub(clean, " ", true).strip_edges()
	if clean != "":
		DisplayServer.tts_speak(clean, _tts_voice, tts_volume, tts_pitch, tts_rate, 0, true)


## What the current card says when it opens.
func _card_speech() -> String:
	# Opened before _ready loaded the book (a chapter can open it from its
	# own _ready): there is no card to read yet
	if book_data.is_empty() or _pages.is_empty():
		return ""
	var page := _page()
	var chapter: Dictionary = book_data[int(page["ch"])]
	if page["kind"] == "lesson":
		var lesson: Dictionary = chapter.get("lessonContent", {})
		return "%s. %s %s" % [_short_title(str(chapter.get("titleEn", ""))), str(lesson.get("explanation", "")),
			str(lesson.get("keyTip", "")).replace("Tip:", "").replace("Quick", "")]
	var ex := _exercise_at(page)
	var q := RegEx.create_from_string("^\\d+\\.\\s*").sub(str(ex.get("questionEn", "")), "")
	return "%s %s" % [q, str(ex.get("instructionEn", ""))]


func _read_card() -> void:
	if visible and not show_certificate:
		_say(_card_speech())


func _trigger(value: SignalType) -> void:
	match value:
		SignalType.Open:
			render()
			show()
			_read_card()
		SignalType.Close:
			hide()


# ------------------------------------------------------------ lifecycle --
func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_init_tts()
	_load_data()
	resized.connect(func():
		if visible and _card and not _flipping:
			render()
	)
	hide()
	#_trigger(SignalType.Open)


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or show_certificate:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_RIGHT:
			_next_page()
		elif event.keycode == KEY_LEFT:
			_prev_page()


func _load_data() -> void:
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	if f == null:
		push_error("BookApp: could not open " + DATA_PATH)
		book_data = []
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	book_data = parsed if parsed is Array else []
	_build_pages()


func _build_pages() -> void:
	_pages = []
	for ch in range(book_data.size()):
		_pages.append({"kind": "lesson", "ch": ch, "ex": -1})
		for ex in range((book_data[ch].get("exercises", []) as Array).size()):
			_pages.append({"kind": "exercise", "ch": ch, "ex": ex})


func _page() -> Dictionary:
	if _pages.is_empty():
		return {"kind": "lesson", "ch": 0, "ex": -1}
	return _pages[clampi(current_page, 0, _pages.size() - 1)]


func _exercise_at(page: Dictionary) -> Dictionary:
	if page["kind"] != "exercise":
		return {}
	return book_data[int(page["ch"])]["exercises"][int(page["ex"])]


func _total_exercises() -> int:
	var total := 0
	for ch in book_data:
		total += (ch.get("exercises", []) as Array).size()
	return total


func _get_ex_state(id: String) -> Dictionary:
	if not ex_state.has(id):
		ex_state[id] = {"counted": [], "selected_option": null, "typed_number": "",
			"tens": 0, "ones": 0, "is_answered": false, "is_correct": null, "misses": 0}
	return ex_state[id]


func _roman(n: int) -> String:
	return ROMAN.get(n, str(n))


## Screen scale: 1.0 at 648 px high.
func _s() -> float:
	return maxf(size.y, 360.0) / 648.0


func _fs(px: float) -> int:
	return maxi(8, roundi(px * _s()))


# =============================================================== render --
func render() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_map = null
	_card = null
	queue_redraw()
	if _pages.is_empty():
		return

	_map = MapPath.new()
	_map.exam = self
	_map.position = Vector2.ZERO
	_map.size = Vector2(size.x, size.y * MAP_H)
	add_child(_map)

	var card_size := Vector2(size.x * CARD_W, size.y * CARD_H)
	var card_pos := Vector2((size.x - card_size.x) / 2.0, size.y * MAP_H + (size.y * (1.0 - MAP_H) - card_size.y) / 2.0)
	_card = PanelContainer.new()
	_card.position = card_pos
	_card.size = card_size
	_card.custom_minimum_size = card_size
	_card.pivot_offset = card_size / 2.0
	_card.add_theme_stylebox_override("panel", _card_style(Color(COL_GOLD)))
	add_child(_card)
	_fill_card()

	# Arrows beside the card
	var arrow_size := Vector2(56, 84) * _s()
	_prev_btn = _arrow_button("‹")
	_prev_btn.position = Vector2((card_pos.x - arrow_size.x) / 2.0, card_pos.y + (card_size.y - arrow_size.y) / 2.0)
	_prev_btn.size = arrow_size
	_prev_btn.disabled = current_page == 0
	_prev_btn.pressed.connect(_prev_page)
	add_child(_prev_btn)
	_next_btn = _arrow_button("›")
	_next_btn.position = Vector2(card_pos.x + card_size.x + (card_pos.x - arrow_size.x) / 2.0, _prev_btn.position.y)
	_next_btn.size = arrow_size
	_next_btn.disabled = current_page >= _pages.size() - 1
	_next_btn.pressed.connect(_next_page)
	add_child(_next_btn)
	if _page_solved() and _page()["kind"] == "exercise" and current_page < _pages.size() - 1:
		ClassTheme.pulse(_next_btn)

	if show_certificate:
		add_child(_build_certificate())


func _card_style(border: Color) -> StyleBoxFlat:
	var sb := ClassTheme.flat(Color(COL_PARCHMENT), border, int(18 * _s()), int(5 * _s()), int(22 * _s()))
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = int(14 * _s())
	sb.shadow_offset = Vector2(0, 6) * _s()
	return sb


func _arrow_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	ClassTheme.style_button(b, Color(COL_LEATHER), Color(COL_GOLD), Color(COL_GOLD_LIGHT), _fs(44))
	return b


## The current page is done (a lesson counts as done once visited).
func _page_solved() -> bool:
	var page := _page()
	if page["kind"] == "lesson":
		return true
	return completed_exercises.has(str(_exercise_at(page).get("id", "")))


func _fill_card() -> void:
	for c in _card.get_children():
		_card.remove_child(c)
		c.queue_free()
	var page := _page()
	var chapter: Dictionary = book_data[int(page["ch"])]
	if page["kind"] == "lesson":
		_card.add_child(_build_lesson_card(chapter, int(page["ch"])))
	else:
		_card.add_child(_build_question_card(chapter, _exercise_at(page)))


# ========================================================= lesson card --
func _build_lesson_card(chapter: Dictionary, ch: int) -> Control:
	var lesson: Dictionary = chapter.get("lessonContent", {})
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(10 * _s()))

	# Title with a small chapter ribbon
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", int(12 * _s()))
	head.add_child(_ribbon("📜 Chapter " + _roman(int(chapter.get("pageNumber", ch + 1)))))
	var title := ClassTheme.label(_short_title(str(chapter.get("titleEn", ""))), _fs(28), Color(COL_INK))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(title)
	head.add_child(_speaker_button())
	col.add_child(head)

	# One short line
	var idea := ClassTheme.label(str(lesson.get("conceptTitle", "")).trim_prefix("Lesson: "), _fs(19), Color(COL_INK_SOFT))
	idea.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(idea)

	# Practice: tap to count, with a big counter
	var visual = lesson.get("visualExample", null)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", int(16 * _s()))
	col.add_child(body)
	var practice_id := "lesson-%d" % ch
	var st := _get_ex_state(practice_id)
	var count := 0
	if visual is Dictionary:
		count = int(visual.get("count", 0))
	if count > 0:
		var area := Vector2(_card.size.x * 0.62, _card.size.y * 0.48)
		body.add_child(_picture_grid(str(visual.get("itemType", "star")), _rows_for(count, 10), st, practice_id, area, MAX_LESSON_TILE))
		var counted: Array = st["counted"]
		var counter := VBoxContainer.new()
		counter.alignment = BoxContainer.ALIGNMENT_CENTER
		counter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var n := ClassTheme.label(str(counted.size()), _fs(72), Color(COL_GOLD_DARK))
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		counter.add_child(n)
		var done := counted.size() >= count
		var under := ClassTheme.label(str(visual.get("groupingText", "")) if done else "Tap to count!", _fs(16),
			Color(COL_CORRECT) if done else Color(COL_INK_SOFT))
		under.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		under.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		counter.add_child(under)
		if counted.size() > 0:
			var again := _small_button("↺ Again")
			again.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			again.pressed.connect(func():
				st["counted"] = []
				_fill_card()
			)
			counter.add_child(again)
		body.add_child(counter)

	# Tip bubble from the little wizard + Let's go
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", int(10 * _s()))
	var tip := str(lesson.get("keyTip", "")).replace("💡 Quick Tip:", "").replace("💡 Tip:", "").replace("💡", "").strip_edges()
	if tip != "":
		var wizard := ClassTheme.label("🧙", _fs(30))
		wizard.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		foot.add_child(wizard)
		var bubble := PanelContainer.new()
		bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bubble.add_theme_stylebox_override("panel", ClassTheme.flat(Color(COL_PARCHMENT_DARK), Color(COL_GOLD), int(14 * _s()), 2, int(10 * _s())))
		var t := ClassTheme.label(tip, _fs(15), Color(COL_INK))
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bubble.add_child(t)
		foot.add_child(bubble)
	else:
		var gap := Control.new()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		foot.add_child(gap)
	var go := _gold_button("Let's go!  ➜", 20)
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	go.pressed.connect(_next_page)
	foot.add_child(go)
	col.add_child(foot)
	return col


## "Activity 1: Counting Small Objects" -> "Counting Small Objects".
func _short_title(t: String) -> String:
	var i := t.find(":")
	return t.substr(i + 1).strip_edges() if i >= 0 else t


## `count` pictures split into rows of at most `per_row`.
func _rows_for(count: int, per_row: int) -> Array:
	var rows : Array = []
	var left := count
	while left > 0:
		rows.append(mini(left, per_row))
		left -= per_row
	return rows


# ======================================================= question card --
func _build_question_card(chapter: Dictionary, exercise: Dictionary) -> Control:
	var id := str(exercise.get("id", ""))
	var st := _get_ex_state(id)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(10 * _s()))

	# The question (numbering like "1. " dropped)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", int(12 * _s()))
	var page := _page()
	var exercises: Array = chapter.get("exercises", [])
	head.add_child(_ribbon("%s · %d/%d" % [_roman(int(chapter.get("pageNumber", 1))), int(page["ex"]) + 1, exercises.size()]))
	var q := RegEx.create_from_string("^\\d+\\.\\s*").sub(str(exercise.get("questionEn", "")), "")
	var title := ClassTheme.label(q, _fs(26), Color(COL_INK))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(title)
	if completed_exercises.has(id):
		head.add_child(ClassTheme.label("⭐", _fs(34)))
	head.add_child(_speaker_button())
	col.add_child(head)

	# Pictures | answer
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", int(16 * _s()))
	col.add_child(body)
	var ex_type := str(exercise.get("type", "number-input"))
	var answer_w := (240.0 if ex_type == "number-input" else 170.0) * _s()
	var layout: Dictionary = exercise.get("layout", {})
	var rows: Array = layout.get("rows", [exercise.get("count", 0)])
	var area := Vector2(_card.size.x - answer_w - 90.0 * _s(), _card.size.y - 150.0 * _s())
	var pics := _picture_grid(str(exercise.get("itemType", "star")), rows, st, id, area)
	pics.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(pics)

	var answer := VBoxContainer.new()
	answer.custom_minimum_size = Vector2(answer_w, 0)
	answer.alignment = BoxContainer.ALIGNMENT_CENTER
	answer.add_theme_constant_override("separation", int(10 * _s()))
	body.add_child(answer)
	match ex_type:
		"multiple-choice":
			_build_choices(answer, exercise, st, id)
		"place-value":
			_build_place_value(answer, exercise, st, id)
		_:
			_build_number_pad(answer, exercise, st, id)

	# Hint after a few misses
	if int(st["misses"]) >= HINT_AFTER and not completed_exercises.has(id) and str(exercise.get("hint", "")) != "":
		var hint := PanelContainer.new()
		hint.add_theme_stylebox_override("panel", ClassTheme.flat(Color("#fff3c4"), Color(COL_GOLD), int(12 * _s()), 2, int(8 * _s())))
		var hl := ClassTheme.label("💡 " + str(exercise.get("hint", "")), _fs(15), Color(COL_INK))
		hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.add_child(hl)
		col.add_child(hint)
	return col


func _build_choices(box: VBoxContainer, exercise: Dictionary, st: Dictionary, id: String) -> void:
	var solved := completed_exercises.has(id)
	for o in exercise.get("options", []):
		var option := int(o)
		var b := Button.new()
		b.text = str(option)
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 78.0 * _s())
		var bg := Color(COL_PARCHMENT_DARK)
		var fg := Color(COL_INK)
		if solved and option == int(exercise.get("correctAnswer", -1)):
			bg = Color(COL_CORRECT)
			fg = Color.WHITE
		elif st["selected_option"] != null and int(st["selected_option"]) == option and st["is_correct"] == false:
			bg = Color(COL_WRONG)
			fg = Color.WHITE
		ClassTheme.style_button(b, bg, Color(COL_GOLD_DARK), fg, _fs(34))
		b.disabled = solved
		b.add_theme_stylebox_override("disabled", b.get_theme_stylebox("normal"))
		b.add_theme_color_override("font_disabled_color", fg)
		b.pressed.connect(func():
			st["selected_option"] = option
			_answer(id, exercise, b)
		)
		box.add_child(b)


func _build_number_pad(box: VBoxContainer, exercise: Dictionary, st: Dictionary, id: String) -> void:
	var pad := NumberPad.new()
	box.add_child(pad)
	pad.setup({})
	var answer := str(int(exercise.get("correctAnswer", 0)))
	if completed_exercises.has(id):
		for c in answer:
			pad._on_key(c)
		pad.lock(true, answer)
		return
	var check := _gold_button("Check  ✔", 20)
	check.pressed.connect(func():
		st["typed_number"] = pad.get_value()
		_answer(id, exercise, pad)
	)
	pad.submitted.connect(func():
		st["typed_number"] = pad.get_value()
		_answer(id, exercise, pad)
	)
	box.add_child(check)


func _build_place_value(box: VBoxContainer, exercise: Dictionary, st: Dictionary, id: String) -> void:
	for field in ["tens", "ones"]:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(ClassTheme.label(str(field).capitalize(), _fs(16), Color(COL_INK_SOFT)))
		var minus := _small_button("−")
		minus.pressed.connect(func():
			st[field] = clampi(int(st[field]) - 1, 0, 9)
			_fill_card()
		)
		row.add_child(minus)
		row.add_child(ClassTheme.label(str(st[field]), _fs(30), Color(COL_INK)))
		var plus := _small_button("+")
		plus.pressed.connect(func():
			st[field] = clampi(int(st[field]) + 1, 0, 9)
			_fill_card()
		)
		row.add_child(plus)
		box.add_child(row)
	var check := _gold_button("Check  ✔", 20)
	check.pressed.connect(func(): _answer(id, exercise, check))
	box.add_child(check)


## Check an answer: right = green glow, star, confetti; wrong = shake and
## a red flash (the hint shows after a few misses).
func _answer(id: String, exercise: Dictionary, source: Control) -> void:
	var st := _get_ex_state(id)
	var correct = _check_answer(id, exercise)
	if correct == null:
		ClassTheme.shake(source)
		return
	if correct:
		_card.add_theme_stylebox_override("panel", _card_style(Color(COL_CORRECT)))
		_fill_card()
		ClassTheme.pop(_card, 1.03)
		ClassTheme.confetti(_card)
		if _map:
			_map.queue_redraw()
		_say("Great job!")
		if show_certificate:
			get_tree().create_timer(1.2).timeout.connect(render)
		else:
			if _next_btn:
				ClassTheme.pulse(_next_btn)
			# Flip on by itself (unless the player already moved on)
			var here := current_page
			get_tree().create_timer(AUTO_NEXT_DELAY).timeout.connect(func():
				if visible and current_page == here and not show_certificate:
					_next_page()
			)
	else:
		st["misses"] = int(st["misses"]) + 1
		_card.add_theme_stylebox_override("panel", _card_style(Color(COL_WRONG)))
		_fill_card()
		ClassTheme.shake(_card)
		var card := _card
		get_tree().create_timer(0.6).timeout.connect(func():
			if is_instance_valid(card):
				card.add_theme_stylebox_override("panel", _card_style(Color(COL_GOLD)))
		)


## true / false, or null when there is nothing to check yet.
func _check_answer(ex_id: String, exercise: Dictionary):
	if exercise.is_empty():
		return null
	var st := _get_ex_state(ex_id)
	var correct := false
	match str(exercise.get("type", "")):
		"multiple-choice":
			if st["selected_option"] == null:
				return null
			correct = int(st["selected_option"]) == int(exercise.get("correctAnswer", -999999))
		"number-input":
			var raw := str(st["typed_number"]).strip_edges()
			if raw == "" or not raw.is_valid_int():
				return null
			correct = int(raw) == int(exercise.get("correctAnswer", -999999))
		"place-value":
			var pv: Dictionary = exercise.get("placeValue", {})
			correct = int(st["tens"]) == int(pv.get("tens", int(exercise.get("correctAnswer", 0)) / 10)) \
				and int(st["ones"]) == int(pv.get("ones", int(exercise.get("correctAnswer", 0)) % 10))
	st["is_answered"] = true
	st["is_correct"] = correct
	if correct and not completed_exercises.has(ex_id):
		completed_exercises.append(ex_id)
		if completed_exercises.size() == _total_exercises():
			show_certificate = true
	return correct


# ============================================================ pictures --
## The pictures to count, as rows of tappable tiles sized to fit `area`.
## Each tile's corner badge shows the ORDER it was tapped in.
func _picture_grid(item_type: String, rows: Array, st: Dictionary, id: String, area: Vector2, max_tile: float = MAX_TILE) -> Control:
	var widest := 1
	for r in rows:
		widest = maxi(widest, int(r))
	var tile := minf(area.x / widest, area.y / maxf(rows.size(), 1)) * 0.86
	tile = clampf(tile, 16.0 * _s(), max_tile * _s())
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", int(tile * 0.1))
	var index := 0
	for r in rows:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", int(tile * 0.1))
		for _i in range(int(r)):
			row.add_child(_picture_tile(item_type, index, st, tile))
			index += 1
		box.add_child(row)
	return box


func _picture_tile(item_type: String, index: int, st: Dictionary, tile: float) -> Control:
	var counted: Array = st["counted"]
	var order := counted.find(index) + 1
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(tile, tile)
	b.text = ITEM_EMOJI.get(item_type, "❓")
	b.add_theme_font_size_override("font_size", int(tile * 0.58))
	var bg := Color("#f4d998") if order > 0 else Color("#fffdf6")
	var border := Color(COL_GOLD_DARK) if order > 0 else Color("#d8c59e")
	var r := int(tile / 2.0)
	b.add_theme_stylebox_override("normal", ClassTheme.flat(bg, border, r, 2, 0))
	b.add_theme_stylebox_override("hover", ClassTheme.flat(bg.lightened(0.05), border, r, 2, 0))
	b.add_theme_stylebox_override("pressed", ClassTheme.flat(bg.darkened(0.05), border, r, 2, 0))
	b.pressed.connect(func():
		if counted.has(index):
			counted.erase(index)
			DisplayServer.tts_stop()
		else:
			counted.append(index)
			_speak_number(counted.size())
		_fill_card()
	)
	if order > 0:
		var badge := Label.new()
		badge.text = str(order)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var bs := maxf(tile * 0.42, 14.0)
		badge.size = Vector2(bs, bs)
		badge.position = Vector2(tile - bs * 0.75, -bs * 0.25)
		badge.add_theme_font_size_override("font_size", int(bs * 0.62))
		badge.add_theme_color_override("font_color", Color("#fef9eb"))
		badge.add_theme_stylebox_override("normal", ClassTheme.flat(Color(COL_SEAL), Color(COL_GOLD_LIGHT), int(bs / 2.0), 1, 0))
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(badge)
	return b


# ============================================================= widgets --
func _ribbon(text: String) -> Control:
	var p := PanelContainer.new()
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_theme_stylebox_override("panel", ClassTheme.flat(Color(COL_LEATHER), Color(COL_GOLD), int(8 * _s()), 2, int(8 * _s())))
	p.add_child(ClassTheme.label(text, _fs(15), Color(COL_GOLD_LIGHT)))
	return p


func _gold_button(text: String, px: int) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 54.0 * _s())
	ClassTheme.style_button(b, Color("#d9b56a"), Color(COL_GOLD_DARK), Color(COL_INK), _fs(px))
	return b


## 🔊: read the card again.
func _speaker_button() -> Button:
	var b := _small_button("🔊")
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.tooltip_text = "Listen again"
	b.pressed.connect(func(): _say(_card_speech()))
	return b


func _small_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(44, 40) * _s()
	ClassTheme.style_button(b, Color(COL_PARCHMENT_DARK), Color(COL_GOLD_DARK), Color(COL_INK), _fs(16))
	return b


# ========================================================== navigation --
## Flip the card: it narrows to a sliver, the page changes, it opens again.
func _go_to_page(target: int) -> void:
	if _flipping or target < 0 or target >= _pages.size() or target == current_page or _card == null:
		return
	DisplayServer.tts_stop()
	_flipping = true
	var tw := create_tween()
	tw.tween_property(_card, "scale:x", 0.02, 0.12).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		current_page = target
		if not _visited.has(target):
			_visited.append(target)
		render()
		_card.scale.x = 0.02
		var open := create_tween()
		open.tween_property(_card, "scale:x", 1.0, 0.16).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		open.finished.connect(func(): _flipping = false)
		_read_card()
	)


func _next_page() -> void:
	_go_to_page(current_page + 1)


func _prev_page() -> void:
	_go_to_page(current_page - 1)


## Map stops: visited pages can be jumped to.
func can_jump_to(page_index: int) -> bool:
	return _visited.has(page_index)


func is_solved(page_index: int) -> bool:
	var page: Dictionary = _pages[page_index]
	if page["kind"] == "lesson":
		return _visited.has(page_index)
	return completed_exercises.has(str(_exercise_at(page).get("id", "")))


# ======================================================== certificate --
func _build_certificate() -> Control:
	var dim := ColorRect.new()
	dim.color = Color(0.07, 0.04, 0.02, 0.8)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(460, 0) * _s()
	card.add_theme_stylebox_override("panel", _card_style(Color(COL_GOLD)))
	center.add_child(card)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", int(12 * _s()))
	card.add_child(col)
	var seal := ClassTheme.label("🏅", _fs(64))
	seal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(seal)
	var passed := ClassTheme.label("PASSED!", _fs(36), Color(COL_CORRECT))
	passed.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(passed)
	var line := ClassTheme.label("You can join Acade Math!", _fs(20), Color(COL_INK))
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(line)
	var stars := ClassTheme.label("⭐".repeat(mini(_total_exercises(), 12)), _fs(22))
	stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(stars)
	var ret := _gold_button("Return", 22)
	ret.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ret.custom_minimum_size.x = 200 * _s()
	ret.pressed.connect(_on_close_certificate)
	col.add_child(ret)
	return dim


func _on_close_certificate() -> void:
	show_certificate = false
	hide()
	isChapter_Done.emit()


# ========================================================= background --
## A treasure-map desk: dark leather, faint dotted trails, a compass rose
## and a few X marks.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(COL_DESK_BG))
	draw_rect(Rect2(Vector2.ZERO, size).grow(-6), Color(COL_LEATHER).lerp(Color(COL_DESK_BG), 0.3))
	var trail := Color(COL_TRAIL)
	trail.a = 0.55
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for t in range(3):
		var p := Vector2(rng.randf() * size.x * 0.3, size.y * (0.3 + 0.25 * t))
		for k in range(14):
			var q := p + Vector2(size.x / 12.0, rng.randf_range(-40, 40) * _s())
			_dotted(p, q, trail)
			p = q
	# Compass rose (bottom right) and X marks
	var c := Vector2(size.x * 0.93, size.y * 0.86)
	var r := 38.0 * _s()
	var gold := Color(COL_GOLD)
	gold.a = 0.35
	for k in range(8):
		var ray := r if k % 2 == 0 else r * 0.55
		draw_line(c, c + Vector2.from_angle(k * PI / 4.0) * ray, gold, 2.0)
	draw_arc(c, r * 0.4, 0, TAU, 24, gold, 2.0)
	for x in [Vector2(0.07, 0.8), Vector2(0.95, 0.35)]:
		var at := Vector2(size.x * x.x, size.y * x.y)
		var d := 9.0 * _s()
		draw_line(at - Vector2(d, d), at + Vector2(d, d), Color(COL_SEAL, 0.6), 3.0)
		draw_line(at - Vector2(d, -d), at + Vector2(d, -d), Color(COL_SEAL, 0.6), 3.0)


func _dotted(a: Vector2, b: Vector2, color: Color) -> void:
	var n := maxi(int(a.distance_to(b) / (10.0 * _s())), 1)
	for i in range(n):
		if i % 2 == 0:
			draw_line(a.lerp(b, float(i) / n), a.lerp(b, float(i + 1) / n), color, 2.0)


# =====================================================================
#  The map path at the top: one stop per page joined by a dotted trail.
#  Lessons are bigger medallions with the chapter's roman numeral,
#  questions are round markers; solved = gold star, current = glowing.
#  Tap a visited stop to go there.
# =====================================================================
class MapPath extends Control:
	var exam : BookApp
	var _time : float = 0.0

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _stop_pos(i: int) -> Vector2:
		var n := maxi(exam._pages.size(), 1)
		var x0 := size.x * 0.06
		var x1 := size.x * 0.94
		var x := x0 + (x1 - x0) * (i / maxf(n - 1, 1.0))
		return Vector2(x, size.y * 0.55 + sin(i * 0.9) * size.y * 0.12)

	func _draw() -> void:
		var s := exam._s()
		var n := exam._pages.size()
		for i in range(n - 1):
			var a := _stop_pos(i)
			var b := _stop_pos(i + 1)
			var col := Color(BookApp.COL_GOLD) if exam.is_solved(i + 1) else Color(BookApp.COL_TRAIL)
			for k in range(8):
				if k % 2 == 0:
					draw_line(a.lerp(b, k / 8.0), a.lerp(b, (k + 1) / 8.0), col, 3.0 * s)
		var font := get_theme_default_font()
		for i in range(n):
			var p := _stop_pos(i)
			var lesson : bool = exam._pages[i]["kind"] == "lesson"
			var current := i == exam.current_page
			var solved := exam.is_solved(i)
			var r := (15.0 if lesson else 10.0) * s * (1.25 if current else 1.0)
			if current:
				draw_circle(p, r * 1.7, Color(1.0, 0.85, 0.4, 0.25 + 0.15 * sin(_time * 4.0)))
			var fill := Color(BookApp.COL_PARCHMENT)
			if solved:
				fill = Color(BookApp.COL_GOLD_LIGHT)
			elif not exam.can_jump_to(i):
				fill = Color(BookApp.COL_PARCHMENT_DARK)
				fill.a = 0.35
			draw_circle(p, r, fill)
			draw_arc(p, r, 0, TAU, 24, Color(BookApp.COL_GOLD_DARK), 2.0 * s)
			var text := ""
			if lesson:
				text = BookApp.ROMAN.get(int(exam.book_data[int(exam._pages[i]["ch"])].get("pageNumber", 1)), "?")
			elif solved:
				text = "★"
			if text != "":
				var fs := int((14.0 if lesson else 13.0) * s)
				var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				draw_string(font, p + Vector2(-w / 2.0, fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
					Color(BookApp.COL_GOLD_DARK) if solved and not lesson else Color(BookApp.COL_INK))

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var best := -1
			var best_d := 30.0 * exam._s()
			for i in range(exam._pages.size()):
				var d := _stop_pos(i).distance_to(event.position)
				if d < best_d:
					best_d = d
					best = i
			if best >= 0 and exam.can_jump_to(best):
				exam._go_to_page(best)
				accept_event()
