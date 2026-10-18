extends AnswerInput
class_name NumberPad

# =====================================================================
#  On-screen 0-9 pad (never opens the phone keyboard). On PC the number
#  keys, Backspace and Enter work too.
# =====================================================================

const MAX_DIGITS := 5

var _value : String = ""
var _display : Dictionary
var _keys : Array = []


func setup(q: Dictionary) -> void:
	super.setup(q)
	add_theme_constant_override("separation", 8)
	_display = make_display()
	add_child(_display["panel"])
	_refresh()

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	add_child(grid)
	for label in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "C", "0", "DEL"]:
		var key : Button
		if label == "C" or label == "DEL":
			key = make_key(label, ClassTheme.SAND, ClassTheme.INK)
		else:
			key = make_key(label)
		key.pressed.connect(_on_key.bind(label))
		grid.add_child(key)
		_keys.append(key)


func get_value() -> String:
	return _value


## Empties the display for another try (used by the merchant challenge).
func clear() -> void:
	_value = ""
	_refresh()
	value_changed.emit(_value)


func _on_key(label: String) -> void:
	if locked:
		return
	match label:
		"C":
			_value = ""
		"DEL":
			_value = _value.substr(0, _value.length() - 1)
		_:
			if _value.length() >= MAX_DIGITS:
				return
			_value = label if _value == "0" else _value + label
	_refresh()
	ClassTheme.pop(_display["value"], 1.15)
	value_changed.emit(_value)


func _refresh() -> void:
	var lbl : Label = _display["value"]
	lbl.text = _value if _value != "" else "?"
	lbl.modulate.a = 1.0 if _value != "" else 0.5


func _unhandled_input(event: InputEvent) -> void:
	if locked or not is_visible_in_tree():
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key : int = event.keycode
	if key >= KEY_0 and key <= KEY_9:
		_on_key(str(key - KEY_0))
	elif key >= KEY_KP_0 and key <= KEY_KP_9:
		_on_key(str(key - KEY_KP_0))
	elif key == KEY_BACKSPACE:
		_on_key("DEL")
	elif key == KEY_ENTER or key == KEY_KP_ENTER:
		submitted.emit()
	else:
		return
	get_viewport().set_input_as_handled()


func lock(correct: bool, expected: String) -> void:
	super.lock(correct, expected)
	for k in _keys:
		k.disabled = true
	style_display_result(_display, correct, expected)
