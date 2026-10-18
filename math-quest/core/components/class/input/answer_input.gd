extends VBoxContainer
class_name AnswerInput

# =====================================================================
#  Base for every way of entering an answer (number pad, fraction pad,
#  clock hands, order tiles, choice tokens).
#
#  value_changed(value)  the answer being built changed ("" = empty)
#  submitted             the player pressed Enter on a keyboard
#  lock(correct, answer) freeze the input and show the result
# =====================================================================

signal value_changed(value: String)
signal submitted

var question : Dictionary = {}
var locked : bool = false
var font_scale : float = 1.0


func setup(q: Dictionary) -> void:
	question = q


func get_value() -> String:
	return ""


func lock(_correct: bool, _expected: String) -> void:
	locked = true


func _fs(base: int) -> int:
	return roundi(base * font_scale)


## Big chunky key used by the pads.
func make_key(text: String, bg: Color = ClassTheme.PARCHMENT, fg: Color = ClassTheme.INK, min_size: Vector2 = Vector2(64, 54)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ClassTheme.style_button(b, bg, ClassTheme.SAND_DARK, fg, _fs(24))
	return b


## The framed answer display shared by the pads.
func make_display(min_height: float = 64.0) -> Dictionary:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, min_height)
	panel.add_theme_stylebox_override("panel", ClassTheme.flat(ClassTheme.INK_DARK, ClassTheme.GOLD, 12, 3, 6))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	var value := ClassTheme.label("", _fs(34), ClassTheme.GOLD_LIGHT)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(value)
	var note := ClassTheme.label("", _fs(16), ClassTheme.GREEN_LIGHT)
	row.add_child(note)
	return {"panel": panel, "value": value, "note": note}


func style_display_result(display: Dictionary, correct: bool, expected: String) -> void:
	var panel : PanelContainer = display["panel"]
	var bg := ClassTheme.GREEN if correct else ClassTheme.RED
	panel.add_theme_stylebox_override("panel", ClassTheme.flat(bg, ClassTheme.GOLD_LIGHT, 12, 3, 6))
	(display["value"] as Label).add_theme_color_override("font_color", ClassTheme.PARCHMENT)
	var note : Label = display["note"]
	if correct:
		note.text = "OK!"
	else:
		note.text = "= %s" % expected
	note.add_theme_color_override("font_color", ClassTheme.GOLD_LIGHT)
	if correct:
		ClassTheme.pop(panel, 1.08)
	else:
		ClassTheme.shake(panel)
