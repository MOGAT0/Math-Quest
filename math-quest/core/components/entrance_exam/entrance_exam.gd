extends Control
class_name BookApp

signal isChapter_Done
# ---------------------------------------------------------------------------
# CONFIG
# ---------------------------------------------------------------------------
const DATA_PATH := "res://data/book_data.json"
#const SAVE_PATH := "user://entranceExam_data.json"
const PAGE_WIDTH := 900.0

const ITEM_EMOJI := {
	"star": "⭐", "can": "🥫", "box": "📦", "yoyo": "🪀", "balloon": "🎈",
	"backpack": "🎒", "strawberry": "🍓", "pineapple": "🍍", "apple": "🍎",
	"pencil": "✏️", "flower": "🌸"
}

const ROMAN := {1: "I", 2: "II", 3: "III", 4: "IV", 5: "V", 6: "VI", 7: "VII", 8: "VIII"}

# ---------------------------------------------------------------------------
# COLOR PALETTE (lifted from index.css)
# ---------------------------------------------------------------------------
const COL_DESK_BG := "#170e08"
const COL_LEATHER := "#2b120a"
const COL_LEATHER_BORDER := "#1a0b06"
const COL_GOLD := "#c5a059"
const COL_GOLD_LIGHT := "#ecd69e"
const COL_GOLD_DARK := "#9c7328"
const COL_HEADER_BG := "#24130a"
const COL_HEADER_BORDER := "#5c3b1e"
const COL_HEADER_TEXT := "#f7eed8"
const COL_HEADER_SUBTEXT := "#c5ab82"
const COL_TAB_INACTIVE_BG := "#381f12"
const COL_TAB_INACTIVE_BORDER := "#5e381b"
const COL_TAB_INACTIVE_TEXT := "#d4bd94"
const COL_TAB_ACTIVE_BG := "#fcf8ee"
const COL_TAB_ACTIVE_TEXT := "#29170a"
const COL_PARCHMENT := "#faf4e5"
const COL_PARCHMENT_TEXT := "#2c1d11"
const COL_VINTAGE_PLATE := "#fdfbf6"
const COL_VINTAGE_PLATE_BORDER := "#cbb387"
const COL_INK_BOX_BG := "#f5ecda"
const COL_INK_BOX_BORDER := "#9b6c23"
const COL_GOLD_BTN_TOP := "#ecd69e"
const COL_GOLD_BTN_BOT := "#b98e3b"
const COL_GOLD_BTN_BORDER := "#9c7328"
const COL_GOLD_BTN_TEXT := "#2d1b0d"
const COL_PARCH_BTN_TOP := "#fbf7ee"
const COL_PARCH_BTN_BOT := "#eee2c7"
const COL_PARCH_BTN_BORDER := "#bd9e6b"
const COL_PARCH_BTN_TEXT := "#382414"
const COL_SUCCESS_BG := "#ebf7ee"
const COL_SUCCESS_BORDER := "#3d9159"
const COL_SUCCESS_TEXT := "#134e26"
const COL_ERROR_BG := "#fdf0f0"
const COL_ERROR_BORDER := "#b8383e"
const COL_ERROR_TEXT := "#6d1318"
const COL_HINT_BG := "#fff9ea"
const COL_HINT_BORDER := "#d6be85"
const COL_HINT_TEXT := "#523713"
const COL_MC_SELECTED_NEUTRAL := "#9e7526"
const COL_MC_SELECTED_CORRECT := "#156e3b"
const COL_MC_SELECTED_WRONG := "#9c252b"

# ---------------------------------------------------------------------------
# STATE
# ---------------------------------------------------------------------------
var book_data: Array = []
var current_page: int = 0
var show_tagalog: bool = false
var show_certificate: bool = false
var completed_exercises: Array = []
var ex_state: Dictionary = {}   # exercise_id -> Dictionary of per-exercise UI state

var _confirm_dialog: ConfirmationDialog = null

# Persistent top-level nodes so re-rendering the book doesn't blow away and
# recreate the ScrollContainer every time -- that was what reset the scroll
# position to the top on every single button press. We only rebuild the
# CONTENT inside the scroll container; the scroll container itself (and its
# scroll_vertical value) survives across render() calls.
var _scroll: ScrollContainer = null
var _bg: ColorRect = null
var _pending_reset_scroll: bool = false

enum SignalType {
	Open, Close
}

func _trigger(value : SignalType) -> void:
	match value:
		SignalType.Open:
			render()
			show()
		SignalType.Close:
			hide()

# ---------------------------------------------------------------------------
# LIFECYCLE
# ---------------------------------------------------------------------------
func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_load_data()
	#_load_progress()
	#render()
	hide()
	#_trigger(SignalType.Open)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_RIGHT:
			_next_page()
		elif event.keycode == KEY_LEFT:
			_prev_page()


# ---------------------------------------------------------------------------
# DATA LOADING / PERSISTENCE
# ---------------------------------------------------------------------------
func _load_data() -> void:
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	if f == null:
		push_error("BookApp: could not open " + DATA_PATH)
		book_data = []
		return
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	book_data = parsed if parsed is Array else []


#func _load_progress() -> void:
	#if not FileAccess.file_exists(SAVE_PATH):
		#return
	#var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	#if f == null:
		#return
	#var parsed = JSON.parse_string(f.get_as_text())
	#f.close()
	#if parsed is Dictionary and parsed.has("completed"):
		#completed_exercises = parsed["completed"]


#func _save_progress() -> void:
	#var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	#if f == null:
		#return
	#f.store_string(JSON.stringify({"completed": completed_exercises}))
	#f.close()


# ---------------------------------------------------------------------------
# HELPERS
# ---------------------------------------------------------------------------
func _c(hex: String) -> Color:
	return Color(hex)


func _roman(n: int) -> String:
	return ROMAN.get(n, str(n))


func _total_exercises() -> int:
	var total := 0
	for ch in book_data:
		total += (ch.get("exercises", []) as Array).size()
	return total


func _chapter_done(chapter: Dictionary) -> bool:
	for ex in chapter.get("exercises", []):
		if not completed_exercises.has(ex["id"]):
			return false
	return true


func _get_ex_state(id: String) -> Dictionary:
	if not ex_state.has(id):
		ex_state[id] = {
			"counted": [],       # Array[int]
			"selected_option": null,
			"typed_number": "",
			"tens": 0,
			"ones": 0,
			"is_answered": false,
			"is_correct": null,
			"show_hint": false,
		}
	return ex_state[id]


func _flat_style(bg: Color, border: Color = Color(0, 0, 0, 0), border_w: int = 0,
		radius: int = 4, margin: int = 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	return sb


func _make_label(text: String, size: int = 14, color: String = COL_PARCHMENT_TEXT,
		bold: bool = false, italic: bool = false, autowrap: bool = false) -> Label:
	# IMPORTANT: autowrap defaults to OFF. A Label with autowrap ON reports a
	# minimum width of ~0px to its parent Container. Inside an HBoxContainer,
	# or as the lone child of a PanelContainer, that makes the parent shrink
	# to near-zero width too, so the label ends up wrapping after every
	# single letter (the vertical "one letter per line" bug). Only pass
	# autowrap=true for genuinely long paragraph text that lives as a direct
	# child of a VBoxContainer, which always stretches children to the full
	# available width regardless of their reported minimum size.
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", _c(color))
	if autowrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l


func _make_btn(text: String, bg: String, border: String, txt_color: String,
		hover_bg: String = "", font_size: int = 13) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", _c(txt_color))
	b.add_theme_color_override("font_hover_color", _c(txt_color))
	b.add_theme_color_override("font_pressed_color", _c(txt_color))
	b.add_theme_color_override("font_disabled_color", _c(txt_color).darkened(0.3))
	var hbg := _c(hover_bg) if hover_bg != "" else _c(bg).lightened(0.08)
	b.add_theme_stylebox_override("normal", _flat_style(_c(bg), _c(border), 2, 4, 10))
	b.add_theme_stylebox_override("hover", _flat_style(hbg, _c(border), 2, 4, 10))
	b.add_theme_stylebox_override("pressed", _flat_style(hbg.darkened(0.05), _c(border), 2, 4, 10))
	b.add_theme_stylebox_override("disabled", _flat_style(_c(bg).darkened(0.15), _c(border).darkened(0.2), 2, 4, 10))
	return b


func _gold_button(text: String, font_size: int = 13) -> Button:
	return _make_btn(text, COL_GOLD_BTN_BOT, COL_GOLD_BTN_BORDER, COL_GOLD_BTN_TEXT, COL_GOLD_BTN_TOP, font_size)


func _parchment_button(text: String, font_size: int = 13) -> Button:
	return _make_btn(text, COL_PARCH_BTN_BOT, COL_PARCH_BTN_BORDER, COL_PARCH_BTN_TEXT, COL_PARCH_BTN_TOP, font_size)


func _spacer(h: float = 8.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _divider(color: String = "#d8c59e") -> ColorRect:
	var r := ColorRect.new()
	r.color = _c(color)
	r.custom_minimum_size = Vector2(0, 1)
	return r


# ---------------------------------------------------------------------------
# MASTER RENDER (rebuilds the book content each time, but keeps the
# ScrollContainer node itself alive so scroll position survives re-renders)
# ---------------------------------------------------------------------------
func render() -> void:
	var reset_scroll := _pending_reset_scroll
	_pending_reset_scroll = false

	if _scroll == null or not is_instance_valid(_scroll):
		# First render (or the persistent nodes were somehow lost): build
		# the whole tree, including the background and scroll container,
		# from scratch.
		for child in get_children():
			child.queue_free()

		_bg = ColorRect.new()
		_bg.color = _c(COL_DESK_BG)
		_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_bg)

		_scroll = ScrollContainer.new()
		_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
		_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		add_child(_scroll)
	else:
		# Subsequent renders: keep _bg and _scroll alive, only tear down
		# their contents (and any extra top-level overlay, e.g. the
		# certificate) so the ScrollContainer's scroll_vertical is preserved.
		for child in _scroll.get_children():
			child.queue_free()
		for child in get_children():
			if child != _bg and child != _scroll:
				child.queue_free()

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.add_child(center)

	var main := VBoxContainer.new()
	main.custom_minimum_size = Vector2(PAGE_WIDTH, 0)
	main.add_theme_constant_override("separation", 0)
	center.add_child(main)

	main.add_child(_build_header())
	main.add_child(_spacer(14))
	main.add_child(_build_chapter_tabs())
	main.add_child(_build_leather_panel())
	main.add_child(_spacer(14))
	main.add_child(_build_footer())
	main.add_child(_spacer(24))

	if show_certificate:
		add_child(_build_certificate_overlay())

	if reset_scroll:
		_scroll.scroll_vertical = 0


# ---------------------------------------------------------------------------
# HEADER (top toolbar)
# ---------------------------------------------------------------------------
func _build_header() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _flat_style(_c(COL_HEADER_BG), _c(COL_HEADER_BORDER), 0, 0, 14))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	# --- Branding block ---
	var brand := HBoxContainer.new()
	brand.add_theme_constant_override("separation", 10)
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var icon_box := PanelContainer.new()
	icon_box.custom_minimum_size = Vector2(38, 38)
	icon_box.add_theme_stylebox_override("panel", _flat_style(_c("#3b2012"), _c("#a17838"), 1, 2, 0))
	var icon_lbl := _make_label("📖", 18, COL_GOLD_LIGHT)
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_box.add_child(icon_lbl)
	brand.add_child(icon_box)

	var title_vbox := VBoxContainer.new()
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	var title_lbl := _make_label("GRADE 1 MATH EXERCISE BOOK", 15, COL_GOLD_LIGHT, true)
	title_row.add_child(title_lbl)
	var anno_lbl := _make_label("ANNO 1898", 10, COL_GOLD)
	var anno_panel := PanelContainer.new()
	anno_panel.add_theme_stylebox_override("panel", _flat_style(Color(0,0,0,0), _c("#8f6a2b"), 1, 2, 4))
	#anno_panel.add_child(anno_lbl)
	#title_row.add_child(anno_panel)
	title_vbox.add_child(title_row)
	var subtitle := _make_label("Counting, Arithmetic Numerals & Place Value", 11, COL_HEADER_SUBTEXT, false, true, true)
	title_vbox.add_child(subtitle)
	brand.add_child(title_vbox)
	row.add_child(brand)

	# --- Controls block ---
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)

	var stars_panel := PanelContainer.new()
	stars_panel.add_theme_stylebox_override("panel", _flat_style(_c("#351d10"), _c("#a68041"), 1, 2, 8))
	var stars_lbl := _make_label("⭐ %d/%d Stars" % [completed_exercises.size(), _total_exercises()], 12, "#fdf6e6", true)
	stars_panel.add_child(stars_lbl)
	controls.add_child(stars_panel)

	row.add_child(controls)
	return panel


func _on_toggle_tagalog() -> void:
	show_tagalog = not show_tagalog
	render()


# ---------------------------------------------------------------------------
# CHAPTER TABS (ribbon bookmarks)
# ---------------------------------------------------------------------------
func _build_chapter_tabs() -> Control:
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 44)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var chapter_index := int(current_page / 2)

	for idx in range(book_data.size()):
		var chapter: Dictionary = book_data[idx]
		var is_current: bool = idx == chapter_index
		var done: bool = _chapter_done(chapter)
		var roman := _roman(int(chapter.get("pageNumber", idx + 1)))

		var btn := Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.text = ("★ " if done else "") + "Tab " + roman
		btn.add_theme_font_size_override("font_size", 12)
		if is_current:
			btn.add_theme_color_override("font_color", _c(COL_TAB_ACTIVE_TEXT))
			btn.add_theme_color_override("font_hover_color", _c(COL_TAB_ACTIVE_TEXT))
			btn.add_theme_stylebox_override("normal", _flat_style(_c(COL_TAB_ACTIVE_BG), _c("#b88e38"), 2, 6, 10))
			btn.add_theme_stylebox_override("hover", _flat_style(_c(COL_TAB_ACTIVE_BG), _c("#b88e38"), 2, 6, 10))
		else:
			btn.add_theme_color_override("font_color", _c(COL_TAB_INACTIVE_TEXT))
			btn.add_theme_color_override("font_hover_color", _c("#f3e7ce"))
			btn.add_theme_stylebox_override("normal", _flat_style(_c(COL_TAB_INACTIVE_BG), _c(COL_TAB_INACTIVE_BORDER), 1, 6, 10))
			btn.add_theme_stylebox_override("hover", _flat_style(_c("#4a2a19"), _c(COL_TAB_INACTIVE_BORDER), 1, 6, 10))
		btn.pressed.connect(_on_go_to_chapter.bind(idx))
		row.add_child(btn)

	scroll.add_child(row)
	return scroll


func _on_go_to_chapter(idx: int) -> void:
	_go_to_page(idx * 2)


# ---------------------------------------------------------------------------
# LEATHER COVER + PAGE (main book area)
# ---------------------------------------------------------------------------
func _build_leather_panel() -> Control:
	var leather := PanelContainer.new()
	leather.add_theme_stylebox_override("panel", _flat_style(_c(COL_LEATHER), _c(COL_LEATHER_BORDER), 4, 14, 16))

	var page_panel := PanelContainer.new()
	page_panel.add_theme_stylebox_override("panel", _flat_style(_c(COL_PARCHMENT), _c(COL_GOLD).darkened(0.1), 1, 4, 0))

	var page_margin := MarginContainer.new()
	page_margin.add_theme_constant_override("margin_left", 30)
	page_margin.add_theme_constant_override("margin_right", 30)
	page_margin.add_theme_constant_override("margin_top", 26)
	page_margin.add_theme_constant_override("margin_bottom", 26)

	var page_vbox := VBoxContainer.new()
	page_vbox.add_theme_constant_override("separation", 0)

	var chapter_index := int(current_page / 2)
	var page_type := "lesson" if current_page % 2 == 0 else "exercise"
	var chapter: Dictionary# = book_data[chapter_index] if chapter_index < book_data.size() else book_data[0]
	
	if book_data.size() > 0:
		if chapter_index < book_data.size():
			chapter = book_data[chapter_index]
		else:
			chapter = book_data[0]
	
	page_vbox.add_child(_build_page_subheader(chapter, page_type, chapter_index))
	page_vbox.add_child(_spacer(18))

	if page_type == "lesson":
		page_vbox.add_child(_build_lesson_page(chapter, chapter_index))
	else:
		page_vbox.add_child(_build_exercise_page(chapter, chapter_index))

	page_vbox.add_child(_spacer(28))
	page_vbox.add_child(_divider())
	page_vbox.add_child(_spacer(12))
	page_vbox.add_child(_build_bottom_nav(page_type))
	page_vbox.add_child(_spacer(8))

	var folio := _make_label(
		"❧ — Page %d of %d : %s — ☙" % [current_page + 1, book_data.size() * 2,
			("Lesson Folio" if page_type == "lesson" else "Exercise Plate")],
		11, "#7a552f", true, true)
	folio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_vbox.add_child(folio)

	page_margin.add_child(page_vbox)
	page_panel.add_child(page_margin)
	leather.add_child(page_panel)
	return leather


func _build_page_subheader(chapter: Dictionary, page_type: String, chapter_index: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var left := HBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)

	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", _flat_style(_c("#ecd8ab"), _c("#b88e38"), 1, 2, 6))
	badge.add_child(_make_label("Chapter %s of %s" % [_roman(int(chapter.get("pageNumber", 1))), _roman(book_data.size())], 11, "#3d2410", true))
	left.add_child(badge)

	var kind_lbl := _make_label("• " + ("Illustrated Lesson" if page_type == "lesson" else "Practice Exercises"), 10, "#7a4e1e")
	left.add_child(kind_lbl)
	row.add_child(left)

	return row


func _on_go_to_page(p: int) -> void:
	_go_to_page(p)


# ---------------------------------------------------------------------------
# LESSON PAGE
# ---------------------------------------------------------------------------
func _build_lesson_page(chapter: Dictionary, chapter_index: int) -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)

	vbox.add_child(_build_lesson_header(chapter))

	# Scholar's Counting Rules
	var rules_panel := PanelContainer.new()
	rules_panel.add_theme_stylebox_override("panel", _flat_style(_c("#f4e8cf").lerp(Color(1,1,1,1), 0.0), _c("#c4ab7e"), 1, 3, 14))
	var rules_vbox := VBoxContainer.new()
	rules_vbox.add_theme_constant_override("separation", 6)
	var rules_title := _make_label("📜 SCHOLAR'S COUNTING RULES", 11, "#66421c", true)
	rules_vbox.add_child(rules_title)
	for rule in [
		"Point to and tally each object one by one with your finger or mouse.",
		"Count in bundles of 5 and 10 for swifter reckoning.",
		"Double-check before declaring your answer."
	]:
		rules_vbox.add_child(_make_label("• " + rule, 12, "#3b2413", false, false, true))
	rules_panel.add_child(rules_vbox)
	vbox.add_child(rules_panel)

	return vbox


func _build_lesson_header(chapter: Dictionary) -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)

	# Title block
	var title_block := VBoxContainer.new()
	title_block.add_theme_constant_override("separation", 4)

	var chap_badge := PanelContainer.new()
	chap_badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	chap_badge.add_theme_stylebox_override("panel", _flat_style(_c("#ecd69e").lerp(Color(1,1,1,1),0.3), _c("#b88e38"), 1, 2, 6))
	chap_badge.add_child(_make_label("CHAPTER " + _roman(int(chapter.get("pageNumber", 1))), 10, "#3d2410", true))
	title_block.add_child(chap_badge)

	var title_lbl := _make_label(chapter.get("titleEn", ""), 22, "#261509", true, false, true)
	title_block.add_child(title_lbl)

	if show_tagalog and chapter.get("titleTl", "") != "":
		title_block.add_child(_make_label("Salin: " + str(chapter.get("titleTl", "")), 12, "#734f2d", false, true, true))

	title_block.add_child(_make_label(chapter.get("subtitle", ""), 12, "#5c3e23", false, true, true))
	vbox.add_child(title_block)
	vbox.add_child(_divider())

	# Explanation plate
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", _flat_style(_c(COL_VINTAGE_PLATE), _c("#c4ab7e"), 1, 3, 16))
	var plate_vbox := VBoxContainer.new()
	plate_vbox.add_theme_constant_override("separation", 10)

	var concept_row := HBoxContainer.new()
	concept_row.add_theme_constant_override("separation", 8)
	concept_row.add_child(_make_label("✨", 14))
	var concept_lbl := _make_label(chapter.get("lessonContent", {}).get("conceptTitle", ""), 15, "#2a170b", true)
	concept_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	concept_row.add_child(concept_lbl)
	plate_vbox.add_child(concept_row)

	var explanation := _make_label(chapter.get("lessonContent", {}).get("explanation", ""), 13, "#382313", false, false, true)
	plate_vbox.add_child(explanation)

	var tip_panel := PanelContainer.new()
	tip_panel.add_theme_stylebox_override("panel", _flat_style(_c("#f2e6cb"), _c("#9b6c23"), 0, 2, 10))
	tip_panel.add_child(_make_label(chapter.get("lessonContent", {}).get("keyTip", ""), 12, "#3b2311", false, true, true))
	plate_vbox.add_child(tip_panel)

	var visual = chapter.get("lessonContent", {}).get("visualExample", null)
	if visual != null:
		plate_vbox.add_child(_divider("#d8c59e"))
		var ex_label := _make_label("— ILLUSTRATED EXAMPLE PLATE —", 10, "#7a532d", true)
		ex_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plate_vbox.add_child(ex_label)

		# Built as explicit HBoxContainer rows (rather than an HFlowContainer)
		# so the icons reliably lay out in a real horizontal grid. An
		# HFlowContainer has to know its own width before it can decide
		# where to wrap, but nothing upstream here ever hands it one, so it
		# was permanently collapsing to a single vertical column.
		var icons_panel := PanelContainer.new()
		icons_panel.add_theme_stylebox_override("panel", _flat_style(_c("#fbf7ed"), _c("#d2be97"), 1, 3, 10))
		var icons_rows := VBoxContainer.new()
		icons_rows.alignment = BoxContainer.ALIGNMENT_CENTER
		icons_rows.add_theme_constant_override("separation", 6)
		var count: int = int(visual.get("count", 0))
		var per_row := 10
		var idx := 0
		while idx < count:
			var row_box := HBoxContainer.new()
			row_box.alignment = BoxContainer.ALIGNMENT_CENTER
			row_box.add_theme_constant_override("separation", 6)
			var row_end: int = min(idx + per_row, count)
			for i in range(idx, row_end):
				row_box.add_child(_build_static_item_icon(visual.get("itemType", "star"), i + 1))
			icons_rows.add_child(row_box)
			idx = row_end
		icons_panel.add_child(icons_rows)
		var center_icons := CenterContainer.new()
		center_icons.add_child(icons_panel)
		plate_vbox.add_child(center_icons)

		var grouping_lbl := _make_label(visual.get("groupingText", ""), 12, "#3f2612", true, false, true)
		grouping_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plate_vbox.add_child(grouping_lbl)

	plate.add_child(plate_vbox)
	vbox.add_child(plate)

	return vbox


func _build_static_item_icon(item_type: String, count_index: int) -> Control:
	# Non-interactive "already counted" icon used in lesson illustration plates.
	# Built entirely from real Containers (VBoxContainer/PanelContainer) so
	# every child is correctly auto-sized -- plain Control parents in Godot
	# do NOT auto-size their children, so we deliberately avoid that pattern.
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 0)

	var lbl := _make_label(ITEM_EMOJI.get(item_type, "❓"), 20)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(lbl)

	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", _flat_style(_c("#8f191e"), _c("#dfbe76"), 1, 8, 2))
	var badge_lbl := _make_label(str(count_index), 9, "#fef9eb", true)
	badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_child(badge_lbl)
	var badge_center := CenterContainer.new()
	badge_center.add_child(badge)
	stack.add_child(badge_center)
	return stack


# ---------------------------------------------------------------------------
# EXERCISE PAGE
# ---------------------------------------------------------------------------
func _build_exercise_page(chapter: Dictionary, chapter_index: int) -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)

	var banner := VBoxContainer.new()
	banner.add_theme_constant_override("separation", 2)
	banner.add_child(_make_label("CHAPTER %s • PRACTICAL PROBLEMS" % _roman(int(chapter.get("pageNumber", 1))), 10, "#855a2a", true))
	banner.add_child(_make_label("Student Problem Plate", 20, "#241307", true))
	banner.add_child(_make_label("Solve each question below and collect your scholar stars!", 12, "#634427", false, true, true))
	vbox.add_child(banner)
	vbox.add_child(_divider())

	var exercises: Array = chapter.get("exercises", [])
	for i in range(exercises.size()):
		vbox.add_child(_build_exercise_card(exercises[i], i))

	if chapter_index < book_data.size() - 1:
		var center := CenterContainer.new()
		var next_btn := _gold_button("Turn to Next Lesson (Chapter %s)  ➜" % _roman(chapter_index + 2), 12)
		next_btn.pressed.connect(_next_page)
		#center.add_child(next_btn)
		vbox.add_child(center)

	return vbox


func _build_exercise_card(exercise: Dictionary, index: int) -> Control:
	var id: String = exercise["id"]
	var st := _get_ex_state(id)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _flat_style(_c(COL_VINTAGE_PLATE), _c(COL_VINTAGE_PLATE_BORDER), 1, 3, 18))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)

	# Header row: number badge + question
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)

	var num_badge := PanelContainer.new()
	num_badge.custom_minimum_size = Vector2(30, 30)
	num_badge.add_theme_stylebox_override("panel", _flat_style(_c("#ecd69e"), _c("#b88e38"), 1, 15, 0))
	var num_lbl := _make_label(str(index + 1), 13, "#3d2410", true)
	num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num_badge.add_child(num_lbl)
	header.add_child(num_badge)

	var q_vbox := VBoxContainer.new()
	q_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	q_vbox.add_child(_make_label(exercise.get("questionEn", ""), 15, "#231206", true, false, true))
	if show_tagalog and exercise.get("questionTl", "") != "":
		q_vbox.add_child(_make_label("Salin: " + str(exercise.get("questionTl", "")), 11, "#734f2d", false, true, true))
	header.add_child(q_vbox)
	vbox.add_child(header)

	# Instruction box
	var instr_panel := PanelContainer.new()
	instr_panel.add_theme_stylebox_override("panel", _flat_style(_c(COL_INK_BOX_BG), _c(COL_INK_BOX_BORDER), 0, 2, 10))
	var instr_vbox := VBoxContainer.new()
	instr_vbox.add_child(_make_label(exercise.get("instructionEn", ""), 12, "#3b2514", false, false, true))
	if show_tagalog and exercise.get("instructionTl", "") != "":
		instr_vbox.add_child(_make_label(str(exercise.get("instructionTl", "")), 11, "#734f2d", false, true, true))
	instr_panel.add_child(instr_vbox)
	vbox.add_child(instr_panel)

	# Item grid plate
	var grid_panel := PanelContainer.new()
	grid_panel.add_theme_stylebox_override("panel", _flat_style(_c("#fdfbf6"), _c("#cfbb94"), 1, 3, 12))
	var grid_vbox := VBoxContainer.new()
	grid_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	grid_vbox.add_theme_constant_override("separation", 6)
	var layout: Dictionary = exercise.get("layout", {})
	var rows: Array = layout.get("rows", [exercise.get("count", 0)])
	var item_counter := 0
	var small_icons: bool = rows.size() > 5
	for row_count in rows:
		var row_flow := HBoxContainer.new()
		row_flow.alignment = BoxContainer.ALIGNMENT_CENTER
		row_flow.add_theme_constant_override("separation", 4)
		for _i in range(int(row_count)):
			var this_index := item_counter
			item_counter += 1
			row_flow.add_child(_build_interactive_item_icon(
				exercise.get("itemType", "star"), this_index, st, id, small_icons))
		grid_vbox.add_child(row_flow)
	grid_panel.add_child(grid_vbox)
	vbox.add_child(grid_panel)

	vbox.add_child(_divider())

	# Answer section
	var ex_type: String = exercise.get("type", "number-input")
	if ex_type == "multiple-choice":
		vbox.add_child(_build_mc_answer(exercise, st, id))
	elif ex_type == "number-input":
		vbox.add_child(_build_number_answer(exercise, st, id))
	elif ex_type == "place-value":
		vbox.add_child(_build_place_value_answer(exercise, st, id))

	# Feedback
	if st["is_answered"] and st["is_correct"] == true:
		vbox.add_child(_build_feedback_panel(true, exercise))
	elif st["is_answered"] and st["is_correct"] == false:
		vbox.add_child(_build_feedback_panel(false, exercise, id))

	if st["show_hint"]:
		var hint_panel := PanelContainer.new()
		hint_panel.add_theme_stylebox_override("panel", _flat_style(_c(COL_HINT_BG), _c(COL_HINT_BORDER), 1, 3, 10))
		var hint_row := HBoxContainer.new()
		hint_row.add_theme_constant_override("separation", 8)
		hint_row.add_child(_make_label("", 13))
		var hint_lbl := _make_label("Scholar's Hint: " + str(exercise.get("hint", "")), 12, COL_HINT_TEXT, false, false, true)
		hint_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hint_row.add_child(hint_lbl)
		hint_panel.add_child(hint_row)
		vbox.add_child(hint_panel)

	card.add_child(vbox)
	return card


func _build_interactive_item_icon(item_type: String, index: int, st: Dictionary, ex_id: String, small: bool) -> Control:
	# Built from a VBoxContainer (a real Container) rather than a plain
	# Control with manually-positioned children, so both the icon button and
	# the little counter badge are always sized and laid out correctly.
	var is_counted: bool = st["counted"].has(index)
	var size := 26 if small else 34

	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 1)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(size, size)
	btn.focus_mode = Control.FOCUS_NONE
	btn.text = ITEM_EMOJI.get(item_type, "❓")
	btn.add_theme_font_size_override("font_size", int(size * 0.6))
	var bg := _c("#f4d998") if is_counted else _c("#ffffff")
	var border := _c("#b88e38") if is_counted else _c("#c9b48a")
	btn.add_theme_stylebox_override("normal", _flat_style(bg, border, 2, size, 0))
	btn.add_theme_stylebox_override("hover", _flat_style(bg.lightened(0.05), border, 2, size, 0))
	btn.add_theme_stylebox_override("pressed", _flat_style(bg.darkened(0.05), border, 2, size, 0))
	btn.pressed.connect(_on_toggle_item.bind(ex_id, index))
	stack.add_child(btn)

	if is_counted:
		var badge := PanelContainer.new()
		# Explicit minimum size so the counter badge never collapses down to
		# nothing (that's what made the number invisible before) -- it now
		# also comfortably fits two-digit counts like "10" or "71".
		badge.custom_minimum_size = Vector2(14, 14)
		badge.add_theme_stylebox_override("panel", _flat_style(_c("#8f191e"), _c("#dfbe76"), 1, 8, 1))
		var badge_lbl := _make_label(str(index + 1), 8, "#fef9eb", true)
		badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_child(badge_lbl)
		var badge_center := CenterContainer.new()
		badge_center.add_child(badge)
		stack.add_child(badge_center)

	return stack


func _build_mc_answer(exercise: Dictionary, st: Dictionary, id: String) -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	var label_row := HBoxContainer.new()
	var lbl := _make_label("SELECT MATCHING NUMBER:" + (" (piliin ang tamang sagot)" if show_tagalog else ""), 11, "#4e321b", true)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_row.add_child(lbl)
	if st["is_answered"] and st["is_correct"] == false:
		var retry := _make_btn("↺ Try another choice", "#faf4e5", "#faf4e5", "#9c252b", "#faf4e5", 11)
		retry.pressed.connect(_on_reset_answer.bind(id))
		label_row.add_child(retry)
	vbox.add_child(label_row)

	var options_row := HBoxContainer.new()
	options_row.add_theme_constant_override("separation", 10)
	var letters := ["A", "B", "C", "D"]
	var options: Array = exercise.get("options", [])
	for i in range(options.size()):
		var option: int = int(options[i])
		var is_selected: bool = st["selected_option"] == option
		var btn := Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 60)
		btn.text = "%s\n%d" % [letters[i] if i < letters.size() else str(i + 1), option]
		btn.add_theme_font_size_override("font_size", 20)

		var bg: Color; var border: Color; var txt: Color
		if is_selected:
			if st["is_correct"] == true:
				bg = _c(COL_MC_SELECTED_CORRECT); border = bg.darkened(0.2); txt = Color.WHITE
			elif st["is_correct"] == false:
				bg = _c(COL_MC_SELECTED_WRONG); border = bg.darkened(0.2); txt = Color.WHITE
			else:
				bg = _c(COL_MC_SELECTED_NEUTRAL); border = bg.darkened(0.2); txt = Color.WHITE
		else:
			bg = _c(COL_PARCH_BTN_BOT); border = _c(COL_PARCH_BTN_BORDER); txt = _c(COL_PARCH_BTN_TEXT)

		btn.add_theme_color_override("font_color", txt)
		btn.add_theme_color_override("font_hover_color", txt)
		btn.add_theme_stylebox_override("normal", _flat_style(bg, border, 2, 4, 8))
		btn.add_theme_stylebox_override("hover", _flat_style(bg.lightened(0.06), border, 2, 4, 8))
		btn.disabled = st["is_correct"] == true
		btn.pressed.connect(_on_mc_choose.bind(id, option))
		options_row.add_child(btn)
	vbox.add_child(options_row)

	return vbox


func _build_number_answer(exercise: Dictionary, st: Dictionary, id: String) -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)

	var lbl := _make_label("Write the Number:", 13, "#382313", true)
	top_row.add_child(lbl)

	var line_edit := LineEdit.new()
	line_edit.text = str(st["typed_number"])
	line_edit.placeholder_text = "0"
	line_edit.custom_minimum_size = Vector2(90, 36)
	line_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	line_edit.add_theme_font_size_override("font_size", 20)
	line_edit.editable = st["is_correct"] != true
	line_edit.add_theme_stylebox_override("normal", _flat_style(_c("#fefcf8"), _c("#bda376"), 2, 3, 6))
	line_edit.text_changed.connect(_on_number_typed.bind(id))
	line_edit.text_submitted.connect(func(_t): _on_check_answer(id, exercise))
	line_edit.add_theme_color_override("font_color", Color("000000ff"))
	top_row.add_child(line_edit)

	top_row.add_child(_spacer(4))

	var verify_btn := _gold_button("Verify Answer", 12)
	# Only ever disabled once answered correctly -- it must NOT depend on
	# typed_number, because typing updates state without a full re-render
	# (to keep the LineEdit's focus/caret), so a disabled-state that reads
	# typed_number would never get re-evaluated and the button would stay
	# permanently disabled. Pressing while empty is already handled safely
	# by _check_answer(), which just no-ops on empty/invalid input.
	verify_btn.disabled = st["is_correct"] == true
	verify_btn.pressed.connect(_on_check_answer.bind(id, exercise))
	top_row.add_child(verify_btn)

	if st["is_answered"]:
		var reset_btn := _parchment_button("↺", 14)
		reset_btn.pressed.connect(_on_reset_answer.bind(id))
		top_row.add_child(reset_btn)

	vbox.add_child(top_row)

	return vbox


func _build_place_value_answer(exercise: Dictionary, st: Dictionary, id: String) -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)

	var top_row := HBoxContainer.new()
	var lbl := _make_label("PLACE VALUE BUILDER: TENS & ONES", 11, "#4a2e18", true)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(lbl)
	var total_lbl := _make_label("Total: %d" % (int(st["tens"]) * 10 + int(st["ones"])), 12, "#6d461f", true)
	top_row.add_child(total_lbl)
	vbox.add_child(top_row)

	var counters_row := HBoxContainer.new()
	counters_row.add_theme_constant_override("separation", 10)
	counters_row.add_child(_build_place_value_counter("Tens (Sampuan)", int(st["tens"]), 10, id, "tens", st))
	counters_row.add_child(_build_place_value_counter("Ones (Isahan)", int(st["ones"]), 1, id, "ones", st))
	vbox.add_child(counters_row)

	var bottom_row := HBoxContainer.new()
	var eq_lbl := _make_label("Equation: %d + %d = %d" % [int(st["tens"]) * 10, int(st["ones"]), int(st["tens"]) * 10 + int(st["ones"])], 11, "#5a391e")
	eq_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.add_child(eq_lbl)
	var verify_btn := _gold_button("Verify", 12)
	verify_btn.disabled = st["is_correct"] == true
	verify_btn.pressed.connect(_on_check_answer.bind(id, exercise))
	bottom_row.add_child(verify_btn)
	if st["is_answered"]:
		var reset_btn := _parchment_button("↺", 12)
		reset_btn.pressed.connect(_on_reset_answer.bind(id))
		bottom_row.add_child(reset_btn)
	vbox.add_child(bottom_row)

	return vbox


func _build_place_value_counter(title: String, value: int, unit: int, ex_id: String, field: String, st: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _flat_style(_c("#fdfaf2"), _c("#cbb387"), 1, 3, 10))

	var row := HBoxContainer.new()
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(_make_label(title, 11, "#734d26", true))
	left.add_child(_make_label("%d = %d" % [value, value * unit], 12, "#3d2511"))
	row.add_child(left)

	var stepper := HBoxContainer.new()
	stepper.add_theme_constant_override("separation", 6)
	var minus_btn := _make_btn("-", "#f5ecda", "#bfa576", "#38200f", "#ffffff", 14)
	minus_btn.custom_minimum_size = Vector2(28, 28)
	minus_btn.disabled = value <= 0 or st["is_correct"] == true
	minus_btn.pressed.connect(_on_place_value_step.bind(ex_id, field, -1))
	stepper.add_child(minus_btn)
	stepper.add_child(_make_label(str(value), 18, "#281508", true))
	var plus_btn := _make_btn("+", "#f5ecda", "#bfa576", "#38200f", "#ffffff", 14)
	plus_btn.custom_minimum_size = Vector2(28, 28)
	plus_btn.disabled = value >= 9 or st["is_correct"] == true
	plus_btn.pressed.connect(_on_place_value_step.bind(ex_id, field, 1))
	stepper.add_child(plus_btn)
	row.add_child(stepper)

	panel.add_child(row)
	return panel


func _build_feedback_panel(correct: bool, exercise: Dictionary, ex_id: String = "") -> Control:
	var panel := PanelContainer.new()
	if correct:
		panel.add_theme_stylebox_override("panel", _flat_style(_c(COL_SUCCESS_BG), _c(COL_SUCCESS_BORDER), 2, 3, 10))
	else:
		panel.add_theme_stylebox_override("panel", _flat_style(_c(COL_ERROR_BG), _c(COL_ERROR_BORDER), 2, 3, 10))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var icon_lbl := _make_label("✔" if correct else "✘", 16, "#ffffff", true)
	var icon_bg := PanelContainer.new()
	var icon_bg_color: Color = _c("#207c42") if correct else _c("#a32228")
	icon_bg.add_theme_stylebox_override("panel", _flat_style(icon_bg_color, Color(0, 0, 0, 0), 0, 14, 6))
	icon_bg.add_child(icon_lbl)
	row.add_child(icon_bg)

	var text_vbox := VBoxContainer.new()
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if correct:
		text_vbox.add_child(_make_label("Splendid! Problem Solved Correctly! ✦", 13, "#0f4420", true))
		var detail := "Count verified = %s" % str(exercise.get("correctAnswer", ""))
		if exercise.get("type", "") == "place-value":
			var pv = exercise.get("placeValue", {})
			var tens = pv.get("tens", int(exercise.get("correctAnswer", 0)) / 10)
			var ones = pv.get("ones", int(exercise.get("correctAnswer", 0)) % 10)
			detail = "%s = %s Tens and %s Ones" % [str(exercise.get("correctAnswer","")), str(tens), str(ones)]
		text_vbox.add_child(_make_label(detail, 11, "#1b5d30", false, false, true))
	else:
		text_vbox.add_child(_make_label("Not quite yet! Check the count once more.", 13, "#5c0d12", true))
		var detail2 := "Count each row carefully or tap each picture to put a mark on it!"
		if exercise.get("type", "") == "place-value":
			detail2 = "Count how many full rows of 10 there are, and how many extra single items!"
		text_vbox.add_child(_make_label(detail2, 11, "#7e1c22", false, false, true))
	row.add_child(text_vbox)

	if not correct and ex_id != "":
		var hint_btn := _make_btn(" Hint", "#fdf0f0", "#fdf0f0", "#8d181e", "#fdf0f0", 11)
		hint_btn.pressed.connect(_on_toggle_hint.bind(ex_id))
		row.add_child(hint_btn)

	panel.add_child(row)
	return panel


# ---------------------------------------------------------------------------
# BOTTOM PAGE NAVIGATION
# ---------------------------------------------------------------------------
func _build_bottom_nav(page_type: String) -> Control:
	var row := HBoxContainer.new()

	var back_btn := _parchment_button("‹ Turn Back", 12)
	back_btn.disabled = current_page == 0
	back_btn.pressed.connect(_prev_page)
	row.add_child(back_btn)

	var dots_center := CenterContainer.new()
	dots_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var dots_row := HBoxContainer.new()
	dots_row.add_theme_constant_override("separation", 6)
	var total_pages := book_data.size() * 2
	for i in range(total_pages):
		var dot := Button.new()
		dot.focus_mode = Control.FOCUS_NONE
		dot.custom_minimum_size = Vector2(12, 12)
		var is_cur := i == current_page
		var bg := _c("#9c7128") if is_cur else _c("#e5d5b7")
		var border := _c("#6e4a10") if is_cur else _c("#bca57a")
		dot.add_theme_stylebox_override("normal", _flat_style(bg, border, 1, 6, 0))
		dot.add_theme_stylebox_override("hover", _flat_style(bg.lightened(0.1), border, 1, 6, 0))
		dot.pressed.connect(_on_go_to_page.bind(i))
		dots_row.add_child(dot)
	dots_center.add_child(dots_row)
	row.add_child(dots_center)

	var next_btn := _gold_button("Turn Next ›", 12)
	next_btn.disabled = current_page == total_pages - 1
	next_btn.pressed.connect(_next_page)
	row.add_child(next_btn)

	return row


# ---------------------------------------------------------------------------
# FOOTER
# ---------------------------------------------------------------------------
func _build_footer() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var left := HBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)

	var total := _total_exercises()
	var percent := 0
	if total > 0:
		percent = int(round(float(completed_exercises.size()) / float(total) * 100.0))

	left.add_child(_make_label("Volume Mastery: %d%%" % percent, 12, COL_GOLD_LIGHT, true))

	# Plain Control (not a Container) so the fill ColorRect can be given an
	# explicit pixel width instead of being auto-stretched by a layout parent.
	var bar_container := Control.new()
	bar_container.custom_minimum_size = Vector2(130, 10)

	var bar_track := Panel.new()
	bar_track.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar_track.add_theme_stylebox_override("panel", _flat_style(_c("#2a160b"), _c("#6b4728"), 1, 2, 0))
	bar_container.add_child(bar_track)

	var fill_w: float = max(0.0, (130.0 - 4.0) * float(percent) / 100.0)
	var bar_fill := ColorRect.new()
	bar_fill.color = _c("#dcc07a")
	bar_fill.position = Vector2(2, 2)
	bar_fill.size = Vector2(fill_w, 6)
	bar_container.add_child(bar_fill)

	left.add_child(bar_container)
	#row.add_child(left)

	var right := HBoxContainer.new()
	right.add_theme_constant_override("separation", 14)

	if completed_exercises.size() == total and total > 0:
		var diploma_btn := _gold_button("🏆 View Diploma", 11)
		diploma_btn.pressed.connect(_on_show_certificate)
		right.add_child(diploma_btn)

	var wipe_btn := _make_btn("Wipe Book Slate Clean", "#170e08", "#170e08", "#aa8a60", "#170e08", 11)
	wipe_btn.pressed.connect(_on_wipe_requested)
	#right.add_child(wipe_btn)

	row.add_child(right)
	return row


func _on_show_certificate() -> void:
	show_certificate = true
	_pending_reset_scroll = true
	render()


func _on_wipe_requested() -> void:
	if _confirm_dialog == null or not is_instance_valid(_confirm_dialog):
		_confirm_dialog = ConfirmationDialog.new()
		get_tree().root.add_child(_confirm_dialog)
	_confirm_dialog.dialog_text = "Wipe the book clean and reset all completed stars and exercise answers?"
	_confirm_dialog.title = "Confirm Reset"
	if not _confirm_dialog.confirmed.is_connected(_on_wipe_confirmed):
		_confirm_dialog.confirmed.connect(_on_wipe_confirmed)
	_confirm_dialog.popup_centered()


func _on_wipe_confirmed() -> void:
	completed_exercises = []
	ex_state = {}
	show_certificate = false
	#_save_progress()
	_pending_reset_scroll = true
	render()


# ---------------------------------------------------------------------------
# CERTIFICATE MODAL
# ---------------------------------------------------------------------------
func _build_certificate_overlay() -> Control:
	var overlay := ColorRect.new()
	overlay.color = Color(0.07, 0.04, 0.02, 0.85)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(480, 0)
	card.add_theme_stylebox_override("panel", _flat_style(_c("#fcf7ec"), _c("#b88e38"), 4, 4, 30))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var seal := PanelContainer.new()
	seal.custom_minimum_size = Vector2(56, 56)
	seal.add_theme_stylebox_override("panel", _flat_style(_c("#8d161d"), _c("#5a0c10"), 2, 28, 0))
	var seal_lbl := _make_label("🏅", 22)
	seal_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seal_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	seal.add_child(seal_lbl)
	var seal_center := CenterContainer.new()
	seal_center.add_child(seal)
	vbox.add_child(seal_center)

	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", _flat_style(_c("#f4e6c9"), _c("#cfba8f"), 1, 3, 8))
	var badge_lbl := _make_label("PASSED", 10, "#7a4e1e", true)
	badge.add_child(badge_lbl)
	var badge_center := CenterContainer.new()
	badge_center.add_child(badge)
	vbox.add_child(badge_center)

	var title_lbl := _make_label("Entrance Exam", 20, "#241306", true)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_lbl)

	var body_lbl := _make_label(
		"Be it known that this student has successfully passed the entrance examination and is hereby declared eligible to enroll at Acade Math!",
		12, "#472d17", false, false, true)
	body_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(body_lbl)

	var achieve_panel := PanelContainer.new()
	achieve_panel.add_theme_stylebox_override("panel", _flat_style(_c("#f7eed8"), _c("#cbb387"), 1, 3, 12))
	var achieve_vbox := VBoxContainer.new()
	achieve_vbox.add_theme_constant_override("separation", 4)
	for line in [
		"✔ Counted collections and item groupings",
		"✔ Mastered numerical selection and quantity recognition",
		"✔ Concluded all arithmetic lessons and exercise plates"
	]:
		achieve_vbox.add_child(_make_label(line, 11, "#14572b", true, false, true))
	achieve_panel.add_child(achieve_vbox)
	vbox.add_child(achieve_panel)

	var close_btn := _gold_button("Return", 12)
	close_btn.pressed.connect(_on_close_certificate)
	var close_center := CenterContainer.new()
	close_center.add_child(close_btn)
	vbox.add_child(close_center)

	card.add_child(vbox)
	center.add_child(card)
	overlay.add_child(center)
	return overlay


func _on_close_certificate() -> void:
	show_certificate = false
	_pending_reset_scroll = true
	#render()
	hide()
	isChapter_Done.emit()


# ---------------------------------------------------------------------------
# NAVIGATION LOGIC
# ---------------------------------------------------------------------------
func _go_to_page(target: int) -> void:
	var total_pages := book_data.size() * 2
	if target < 0 or target >= total_pages or target == current_page:
		return
	current_page = target
	_pending_reset_scroll = true
	render()


func _next_page() -> void:
	_go_to_page(current_page + 1)


func _prev_page() -> void:
	_go_to_page(current_page - 1)


# ---------------------------------------------------------------------------
# EXERCISE INTERACTION LOGIC
# ---------------------------------------------------------------------------
func _on_toggle_item(ex_id: String, index: int) -> void:
	var st := _get_ex_state(ex_id)
	if st["counted"].has(index):
		st["counted"].erase(index)
	else:
		st["counted"].append(index)
	render()


func _on_reset_count(ex_id: String) -> void:
	var st := _get_ex_state(ex_id)
	st["counted"] = []
	render()


func _on_auto_count(ex_id: String, count: int) -> void:
	var st := _get_ex_state(ex_id)
	var all := []
	for i in range(count):
		all.append(i)
	st["counted"] = all
	render()


func _on_number_typed(new_text: String, ex_id: String) -> void:
	# Update state without a full re-render so the LineEdit keeps focus/caret.
	var st := _get_ex_state(ex_id)
	st["typed_number"] = new_text
	st["is_correct"] = null
	st["is_answered"] = false


func _on_mc_choose(ex_id: String, option: int) -> void:
	var st := _get_ex_state(ex_id)
	st["selected_option"] = option
	_check_answer(ex_id, _find_exercise(ex_id))


func _on_place_value_step(ex_id: String, field: String, delta: int) -> void:
	var st := _get_ex_state(ex_id)
	st[field] = clampi(int(st[field]) + delta, 0, 9)
	st["is_correct"] = null
	st["is_answered"] = false
	render()


func _on_check_answer(ex_id: String, exercise: Dictionary) -> void:
	_check_answer(ex_id, exercise)


func _find_exercise(ex_id: String) -> Dictionary:
	for chapter in book_data:
		for ex in chapter.get("exercises", []):
			if ex["id"] == ex_id:
				return ex
	return {}


func _check_answer(ex_id: String, exercise: Dictionary) -> void:
	if exercise.is_empty():
		return
	var st := _get_ex_state(ex_id)
	var correct := false
	var ex_type: String = exercise.get("type", "")

	if ex_type == "multiple-choice":
		if st["selected_option"] == null:
			render()
			return
		correct = int(st["selected_option"]) == int(exercise.get("correctAnswer", -999999))
	elif ex_type == "number-input":
		var raw := str(st["typed_number"]).strip_edges()
		if raw == "" or not raw.is_valid_int():
			render()
			return
		correct = int(raw) == int(exercise.get("correctAnswer", -999999))
	elif ex_type == "place-value":
		var pv: Dictionary = exercise.get("placeValue", {})
		var target_tens: int = pv.get("tens", int(exercise.get("correctAnswer", 0)) / 10)
		var target_ones: int = pv.get("ones", int(exercise.get("correctAnswer", 0)) % 10)
		correct = int(st["tens"]) == target_tens and int(st["ones"]) == target_ones

	st["is_answered"] = true
	st["is_correct"] = correct

	if correct:
		if not completed_exercises.has(ex_id):
			completed_exercises.append(ex_id)
			#_save_progress()
			if completed_exercises.size() == _total_exercises():
				show_certificate = true
				_pending_reset_scroll = true

	render()


func _on_reset_answer(ex_id: String) -> void:
	var st := _get_ex_state(ex_id)
	st["is_answered"] = false
	st["is_correct"] = null
	st["selected_option"] = null
	st["typed_number"] = ""
	st["tens"] = 0
	st["ones"] = 0
	render()


func _on_toggle_hint(ex_id: String) -> void:
	var st := _get_ex_state(ex_id)
	st["show_hint"] = not st["show_hint"]
	render()
