extends PanelContainer
class_name QuestionCard

# =====================================================================
#  Parchment card with the question, typed out letter by letter.
#  Tap the text to finish typing; the speaker button reads it again and
#  the lightbulb asks for a hint (one per question).
# =====================================================================

signal speak_requested(text: String)
signal tapped
signal hint_requested

const CHAR_TIME := 0.018

var font_scale : float = 1.0

var _tag : Label
var _text : RichTextLabel
var _hint : Label
var _speaker : Button
var _hint_btn : Button
var _hint_pulse : Tween = null
var _type_tween : Tween = null
var _full_text : String = ""


func _fs(base: int) -> int:
	return roundi(base * font_scale)


func build() -> void:
	add_theme_stylebox_override("panel", ClassTheme.flat(ClassTheme.PARCHMENT, ClassTheme.GOLD, 14, 3, 14))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	add_child(col)

	var head := HBoxContainer.new()
	col.add_child(head)
	_tag = ClassTheme.label("", _fs(14), ClassTheme.CRIMSON)
	_tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_tag)
	_speaker = Button.new()
	_speaker.text = "🔊"
	_speaker.custom_minimum_size = Vector2(44, 40)
	ClassTheme.style_button(_speaker, ClassTheme.PARCHMENT_DARK, ClassTheme.SAND_DARK, ClassTheme.INK, _fs(18))
	_speaker.pressed.connect(func(): speak_requested.emit(_full_text))
	head.add_child(_speaker)

	_hint_btn = Button.new()
	_hint_btn.text = "💡"
	_hint_btn.tooltip_text = "Need a hint?"
	_hint_btn.custom_minimum_size = Vector2(44, 40)
	ClassTheme.style_button(_hint_btn, ClassTheme.GOLD_LIGHT, ClassTheme.GOLD, ClassTheme.INK, _fs(18))
	_hint_btn.pressed.connect(func(): hint_requested.emit())
	_hint_btn.hide()
	head.add_child(_hint_btn)

	_text = RichTextLabel.new()
	_text.bbcode_enabled = false
	_text.fit_content = true
	_text.scroll_active = false
	_text.selection_enabled = false
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_size_override("normal_font_size", _fs(20))
	_text.add_theme_color_override("default_color", ClassTheme.INK_DARK)
	_text.gui_input.connect(_on_text_input)
	col.add_child(_text)

	_hint = ClassTheme.label("", _fs(15), ClassTheme.ARCANE)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.hide()
	col.add_child(_hint)


func show_question(text: String, tag: String = "") -> void:
	_full_text = text
	_tag.text = tag
	_hint.hide()
	_text.text = text
	_text.visible_characters = 0
	if _type_tween and _type_tween.is_valid():
		_type_tween.kill()
	_type_tween = create_tween()
	_type_tween.tween_property(_text, "visible_characters", text.length(), text.length() * CHAR_TIME)
	_type_tween.tween_callback(func(): _text.visible_characters = -1)
	speak_requested.emit(text)


## Shows / hides the lightbulb; `nudge` makes it pulse gently.
func set_hint_available(on: bool, nudge: bool = false) -> void:
	if _hint_pulse and _hint_pulse.is_valid():
		_hint_pulse.kill()
	_hint_btn.modulate.a = 1.0
	_hint_btn.visible = on
	_hint_btn.disabled = false
	if on and nudge:
		_hint_pulse = ClassTheme.pulse(_hint_btn)


## The hint was used: keep the bulb visible but spent.
func spend_hint() -> void:
	if _hint_pulse and _hint_pulse.is_valid():
		_hint_pulse.kill()
	_hint_btn.modulate.a = 0.45
	_hint_btn.disabled = true


func show_hint(text: String) -> void:
	_hint.text = "💡 " + text
	_hint.visible = text != ""
	if _hint.visible:
		ClassTheme.pop(_hint, 1.05)


func is_typing() -> bool:
	return _type_tween != null and _type_tween.is_valid() and _type_tween.is_running()


func finish_typing() -> void:
	if _type_tween and _type_tween.is_valid():
		_type_tween.kill()
	_text.visible_characters = -1


func _on_text_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		finish_typing()
		tapped.emit()
