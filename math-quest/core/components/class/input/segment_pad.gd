extends AnswerInput
class_name SegmentPad

# =====================================================================
#  A number pad that fills several boxes joined by a separator:
#      fraction  [ 3 ] / [ 4 ]      (FractionPad, stacked)
#      time      [ 10 ] : [ 55 ]    (TimeInput)
#  Tap a box to choose it; the separator key jumps to the next box.
#  On PC: digits, Backspace, Tab or the separator key, Enter.
# =====================================================================

var separator : String = "/"
var max_digits : Array = [3, 3]
var placeholders : Array = ["?", "?"]
var stacked : bool = false            # numerator over denominator

var _values : Array = []
var _active : int = 0
var _boxes : Array = []               # {"panel": PanelContainer, "label": Label}
var _keys : Array = []
var _display_panel : PanelContainer
var _note : Label


func setup(q: Dictionary) -> void:
	super.setup(q)
	add_theme_constant_override("separation", 8)
	_values = []
	for i in range(max_digits.size()):
		_values.append("")

	_display_panel = PanelContainer.new()
	_display_panel.add_theme_stylebox_override("panel", ClassTheme.flat(ClassTheme.INK_DARK, ClassTheme.GOLD, 12, 3, 6))
	add_child(_display_panel)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	_display_panel.add_child(row)

	var holder : BoxContainer = VBoxContainer.new() if stacked else HBoxContainer.new()
	holder.alignment = BoxContainer.ALIGNMENT_CENTER
	holder.add_theme_constant_override("separation", 2 if stacked else 8)
	row.add_child(holder)
	for i in range(max_digits.size()):
		if i > 0:
			if stacked:
				var bar := ColorRect.new()
				bar.color = ClassTheme.GOLD_LIGHT
				bar.custom_minimum_size = Vector2(70, 4)
				holder.add_child(bar)
			else:
				holder.add_child(ClassTheme.label(separator, _fs(34), ClassTheme.GOLD_LIGHT))
		holder.add_child(_make_box(i))

	_note = ClassTheme.label("", _fs(16), ClassTheme.GOLD_LIGHT)
	row.add_child(_note)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	add_child(grid)
	for label in ["1", "2", "3", "4", "5", "6", "7", "8", "9", separator, "0", "DEL"]:
		var key : Button
		if label == separator:
			key = make_key(label, ClassTheme.ARCANE_LIGHT, ClassTheme.INK_DARK)
		elif label == "DEL":
			key = make_key(label, ClassTheme.SAND, ClassTheme.INK)
		else:
			key = make_key(label)
		key.custom_minimum_size.y = 48 if stacked else 54
		key.pressed.connect(_on_key.bind(label))
		grid.add_child(key)
		_keys.append(key)
	_refresh()


func _make_box(i: int) -> PanelContainer:
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(70, 40 if stacked else 52)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.gui_input.connect(func(e: InputEvent):
		if not locked and e is InputEventMouseButton and e.pressed:
			_active = i
			_refresh()
	)
	var lbl := ClassTheme.label("", _fs(30 if stacked else 34), ClassTheme.GOLD_LIGHT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(lbl)
	_boxes.append({"panel": box, "label": lbl})
	return box


func get_value() -> String:
	for v in _values:
		if v == "":
			return ""
	return separator.join(PackedStringArray(_values))


## Lets a stage prop (e.g. the clock hands) fill the boxes directly.
func set_values(values: Array) -> void:
	if locked:
		return
	for i in range(mini(values.size(), _values.size())):
		_values[i] = str(values[i])
	_refresh()
	value_changed.emit(get_value())


func _on_key(label: String) -> void:
	if locked:
		return
	if label == separator:
		_active = (_active + 1) % _values.size()
	elif label == "DEL":
		if _values[_active] == "" and _active > 0:
			_active -= 1
		_values[_active] = _values[_active].substr(0, _values[_active].length() - 1)
	else:
		var cur : String = _values[_active]
		if cur.length() >= int(max_digits[_active]):
			if _active < _values.size() - 1:
				_active += 1
				cur = _values[_active]
			else:
				return
		cur += label    # keep leading zeros: minutes like "05"
		_values[_active] = cur
		if _should_advance(_active, cur) and _active < _values.size() - 1:
			_active += 1
	_refresh()
	ClassTheme.pop(_boxes[_active]["panel"], 1.1)
	value_changed.emit(get_value())


## Override: move to the next box automatically after this digit?
func _should_advance(index: int, text: String) -> bool:
	return text.length() >= int(max_digits[index])


func _refresh() -> void:
	for i in range(_boxes.size()):
		var lbl : Label = _boxes[i]["label"]
		var val : String = _values[i]
		lbl.text = val if val != "" else str(placeholders[i])
		lbl.modulate.a = 1.0 if val != "" else 0.45
		var active := i == _active and not locked
		var style := ClassTheme.flat(ClassTheme.WOOD_DARK if active else Color(0, 0, 0, 0), ClassTheme.GOLD_LIGHT if active else ClassTheme.BROWN, 8, 2)
		_boxes[i]["panel"].add_theme_stylebox_override("panel", style)


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
	elif key == KEY_TAB or char(event.unicode) == separator or key == KEY_SLASH or key == KEY_KP_DIVIDE:
		_on_key(separator)
	elif key == KEY_ENTER or key == KEY_KP_ENTER:
		submitted.emit()
	else:
		return
	get_viewport().set_input_as_handled()


func lock(correct: bool, expected: String) -> void:
	super.lock(correct, expected)
	for k in _keys:
		k.disabled = true
	_refresh()
	var bg := ClassTheme.GREEN if correct else ClassTheme.RED
	_display_panel.add_theme_stylebox_override("panel", ClassTheme.flat(bg, ClassTheme.GOLD_LIGHT, 12, 3, 6))
	_note.text = "OK!" if correct else "= %s" % expected
	if correct:
		ClassTheme.pop(_display_panel, 1.06)
	else:
		ClassTheme.shake(_display_panel)
