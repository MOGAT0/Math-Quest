extends AnswerInput
class_name PuzzleHint

# Puzzles are solved on the stage, so the panel only shows a hint and
# the result. The class fills the value when the station reports back.

var _value : String = ""
var _label : Label


func setup(q: Dictionary) -> void:
	super.setup(q)
	_label = ClassTheme.label("Solve the puzzle on the stage!", _fs(20), ClassTheme.ARCANE)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(0, 80)
	add_child(_label)


func get_value() -> String:
	return _value


func set_result(mistakes: int, answer: String) -> void:
	_value = answer if mistakes == 0 else "%d mistakes" % mistakes
	value_changed.emit(_value)


func lock(correct: bool, _expected: String) -> void:
	super.lock(correct, _expected)
	_label.text = "Puzzle solved perfectly!" if correct else "Solved, with %s." % _value
	_label.add_theme_color_override("font_color", ClassTheme.GREEN if correct else ClassTheme.RED)
