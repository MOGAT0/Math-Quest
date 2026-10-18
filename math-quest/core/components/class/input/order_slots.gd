extends AnswerInput
class_name OrderSlots

# =====================================================================
#  List answers ("2, 4, 5, 8"): tap number tiles to drop them into the
#  slots in order; tap a filled slot to send its tile back.
#  The tile pool is every number in the answer and its distractor
#  options, so "the next two numbers" still needs thinking.
# =====================================================================

var _slots : Array = []      # Button per slot
var _slot_values : Array = []
var _tiles : Array = []      # Button per tile


func setup(q: Dictionary) -> void:
	super.setup(q)
	add_theme_constant_override("separation", 12)
	var answer_parts := _numbers(str(q.get("answer", "")))
	var pool : Array = answer_parts.duplicate()
	for o in q.get("options", []):
		for n in _numbers(str(o)):
			if not pool.has(n):
				pool.append(n)
	pool.shuffle()

	var hint := ClassTheme.label("Tap the numbers in the right order:", _fs(16), ClassTheme.BROWN)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint)

	var slot_row := HBoxContainer.new()
	slot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	slot_row.add_theme_constant_override("separation", 8)
	add_child(slot_row)
	for i in range(answer_parts.size()):
		var s := Button.new()
		s.custom_minimum_size = Vector2(68, 62)
		s.pressed.connect(_on_slot.bind(i))
		slot_row.add_child(s)
		_slots.append(s)
		_slot_values.append("")

	var divider := ColorRect.new()
	divider.color = ClassTheme.SAND_DARK
	divider.custom_minimum_size = Vector2(0, 2)
	add_child(divider)

	var tray := HFlowContainer.new()
	tray.alignment = FlowContainer.ALIGNMENT_CENTER
	tray.add_theme_constant_override("h_separation", 8)
	tray.add_theme_constant_override("v_separation", 8)
	add_child(tray)
	for n in pool:
		var t := Button.new()
		t.text = n
		t.custom_minimum_size = Vector2(64, 56)
		ClassTheme.style_button(t, ClassTheme.GOLD_LIGHT, ClassTheme.GOLD, ClassTheme.INK_DARK, _fs(24))
		t.pressed.connect(_on_tile.bind(t))
		tray.add_child(t)
		_tiles.append(t)
	_refresh()


static func _numbers(text: String) -> Array:
	var out : Array = []
	for p in text.split(","):
		if p.strip_edges() != "":
			out.append(p.strip_edges())
	return out


func get_value() -> String:
	for v in _slot_values:
		if v == "":
			return ""
	return ", ".join(PackedStringArray(_slot_values))


func _on_tile(tile: Button) -> void:
	if locked:
		return
	var free := _slot_values.find("")
	if free == -1:
		ClassTheme.shake(tile)
		return
	_slot_values[free] = tile.text
	tile.set_meta("slot", free)
	tile.hide()
	_refresh()
	ClassTheme.pop(_slots[free], 1.15)
	value_changed.emit(get_value())


func _on_slot(index: int) -> void:
	if locked or _slot_values[index] == "":
		return
	for t in _tiles:
		if not t.visible and t.get_meta("slot", -1) == index:
			t.show()
			t.set_meta("slot", -1)
			ClassTheme.pop(t, 1.15)
			break
	_slot_values[index] = ""
	_refresh()
	value_changed.emit(get_value())


func _refresh(result: Array = []) -> void:
	for i in range(_slots.size()):
		var s : Button = _slots[i]
		var v : String = _slot_values[i]
		s.text = v if v != "" else str(i + 1)
		var bg := ClassTheme.PARCHMENT if v != "" else Color(0, 0, 0, 0.06)
		var border := ClassTheme.GOLD if v != "" else ClassTheme.SAND_DARK
		var fg := ClassTheme.INK if v != "" else ClassTheme.SAND_DARK
		if not result.is_empty():
			var ok : bool = result[i]
			bg = ClassTheme.GREEN_LIGHT if ok else ClassTheme.RED_LIGHT
			border = ClassTheme.GREEN if ok else ClassTheme.RED
			fg = border
		ClassTheme.style_button(s, bg, border, fg, _fs(24))
		s.add_theme_stylebox_override("disabled", s.get_theme_stylebox("normal"))
		s.add_theme_color_override("font_disabled_color", fg)


func lock(correct: bool, expected: String) -> void:
	super.lock(correct, expected)
	var want := _numbers(expected)
	var per_slot : Array = []
	for i in range(_slots.size()):
		per_slot.append(i < want.size() and _slot_values[i] == want[i])
	_refresh(per_slot)
	for s in _slots:
		s.disabled = true
	for t in _tiles:
		t.disabled = true
	if not correct:
		var note := ClassTheme.label("The spell needed: %s" % expected, _fs(18), ClassTheme.RED)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(note)
