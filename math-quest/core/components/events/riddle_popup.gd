extends Control
class_name RiddlePopup

# =====================================================================
#  The visitor's math riddle: name + greeting on the left, the class
#  NumberPad on the right. Wrong answers can try again; "Later" closes
#  it (the visitor stays until Matthew sleeps).
#  finished(solved, mistakes)
# =====================================================================

signal finished(solved: bool, mistakes: int)

var _question : Dictionary = {}
var _mistakes : int = 0
var _pad : NumberPad
var _feedback : Label


func open(def: Dictionary, question: Dictionary) -> void:
	_question = question
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.08, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ClassTheme.flat(ClassTheme.PARCHMENT, ClassTheme.GOLD, 18, 4, 22))
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)

	var title := ClassTheme.label(str(def.get("name", "A visitor")), 26, ClassTheme.CRIMSON)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 24)
	col.add_child(body)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(360, 0)
	left.add_theme_constant_override("separation", 12)
	body.add_child(left)
	var greet := ClassTheme.label("\"%s\"" % str(def.get("intro", "Can you solve this?")), 17, ClassTheme.BROWN)
	greet.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(greet)
	var q := ClassTheme.label(str(question.get("text", "")), 20, ClassTheme.INK_DARK)
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(q)
	var v = question.get("visual", {})
	if typeof(v) == TYPE_DICTIONARY and str(v.get("type", "")) == "sequence":
		var parts := PackedStringArray()
		for token in v.get("sequence", []):
			parts.append(str(token))
		var eq := ClassTheme.label(" ".join(parts), 24, ClassTheme.CRIMSON)
		eq.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		left.add_child(eq)
	if int(def.get("reward", 10)) > 0:
		var reward := ClassTheme.label("Reward: %d KP" % int(def.get("reward", 10)), 15, ClassTheme.GOLD)
		left.add_child(reward)
	_feedback = ClassTheme.label("", 17, ClassTheme.RED)
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_feedback)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(250, 0)
	body.add_child(right)
	_pad = NumberPad.new()
	right.add_child(_pad)
	_pad.setup({})
	_pad.submitted.connect(_submit)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	col.add_child(row)
	var later := Button.new()
	later.text = "Later"
	later.custom_minimum_size = Vector2(160, 54)
	ClassTheme.style_button(later, ClassTheme.PARCHMENT_DARK, ClassTheme.GOLD, ClassTheme.INK, 20)
	later.pressed.connect(func(): _close(false))
	row.add_child(later)
	var answer := Button.new()
	answer.text = "Answer!"
	answer.custom_minimum_size = Vector2(160, 54)
	ClassTheme.style_button(answer, ClassTheme.CRIMSON, ClassTheme.CRIMSON_DARK, ClassTheme.PARCHMENT, 20)
	answer.pressed.connect(_submit)
	row.add_child(answer)


func _submit() -> void:
	var given := _pad.get_value()
	if given == "":
		return
	if AnswerRules.matches(given, str(_question.get("answer", "")), "number"):
		_close(true)
		return
	_mistakes += 1
	var hint := AnswerExplainer.hint(_question, "number")
	_feedback.text = "Not quite, try again!" + ("\nHint: " + hint if _mistakes >= 2 and hint != "" else "")
	ClassTheme.shake(_feedback)
	_pad.clear()


func _close(solved: bool) -> void:
	_pad.locked = true
	finished.emit(solved, _mistakes)
	queue_free()
