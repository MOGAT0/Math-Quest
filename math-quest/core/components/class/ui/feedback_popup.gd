extends PanelContainer
class_name FeedbackPopup

# =====================================================================
#  The message that pops up over the stage after every answer:
#     correct  ->  a cheer ("Correct! The magic worked!")
#     wrong    ->  "Not quite!", the correct answer, and why
#  Next continues to the following question (same as the panel button).
#  build() also makes `layer`: a full-screen dim backdrop with the card
#  centred on it. Add `layer` to the screen, not the card itself.
# =====================================================================

signal next_pressed

var font_scale : float = 1.0
var layer : Control
var _dim : ColorRect

var _title : Label
var _answer_box : PanelContainer
var _answer : Label
var _why : Label
var _next : Button


func _fs(base: int) -> int:
	return roundi(base * font_scale)


func build() -> void:
	layer = Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.hide()
	_dim = ColorRect.new()
	_dim.color = Color(0.08, 0.05, 0.1, 0.65)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	center.add_child(self)

	mouse_filter = Control.MOUSE_FILTER_STOP
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 12)
	add_child(col)

	_title = ClassTheme.label("", _fs(34))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_title)

	_answer_box = PanelContainer.new()
	_answer_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_answer_box.add_theme_stylebox_override("panel", ClassTheme.flat(ClassTheme.INK_DARK, ClassTheme.GOLD, 12, 3, 10))
	col.add_child(_answer_box)
	_answer = ClassTheme.label("", _fs(26), ClassTheme.GOLD_LIGHT)
	_answer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_answer_box.add_child(_answer)

	_why = ClassTheme.label("", _fs(17), ClassTheme.INK)
	_why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_why)

	_next = Button.new()
	_next.text = "NEXT ->"
	_next.custom_minimum_size = Vector2(200, 54)
	_next.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_next.pressed.connect(func(): next_pressed.emit())
	col.add_child(_next)
	layer.resized.connect(_fit)


func show_correct(message: String) -> void:
	_style(true)
	_title.text = message
	_answer_box.hide()
	_why.hide()
	_pop_in()


func show_wrong(title: String, answer: String, why: String) -> void:
	_style(false)
	_title.text = title
	_answer.text = "The answer is %s" % answer
	_answer_box.show()
	_why.text = why
	_why.visible = why != ""
	_pop_in()


func close() -> void:
	layer.hide()


## Card width follows the screen; the CenterContainer keeps it centred.
func _fit() -> void:
	var w := clampf(layer.size.x * 0.6, 280.0, 600.0)
	_title.custom_minimum_size.x = w - 48.0
	_why.custom_minimum_size.x = w - 48.0
	custom_minimum_size = Vector2(w, 0)


func _style(correct: bool) -> void:
	var border := ClassTheme.GREEN if correct else ClassTheme.RED
	var bg := ClassTheme.GREEN_LIGHT if correct else ClassTheme.RED_LIGHT
	add_theme_stylebox_override("panel", ClassTheme.flat(bg.lerp(ClassTheme.PARCHMENT, 0.4), border, 18, 4, 22))
	_title.add_theme_color_override("font_color", border)
	ClassTheme.style_button(_next, border, border.darkened(0.3), ClassTheme.PARCHMENT, _fs(22))


func _pop_in() -> void:
	_fit()
	layer.show()
	_dim.modulate.a = 0.0
	modulate.a = 0.0
	scale = Vector2(0.7, 0.7)
	# Wait one frame so the card has its final size before scaling from its centre
	await get_tree().process_frame
	pivot_offset = size / 2.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_dim, "modulate:a", 1.0, 0.2)
	tw.tween_property(self, "modulate:a", 1.0, 0.18)
	tw.tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
