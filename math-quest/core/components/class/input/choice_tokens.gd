extends AnswerInput
class_name ChoiceTokens

# =====================================================================
#  Word / symbol answers ("greater than", ">", "square") shown as rune
#  tokens. Uses the question's "options" as distractors; also the
#  fallback for any answer type without its own input.
# =====================================================================

var _value : String = ""
var _tokens : Array = []


func setup(q: Dictionary) -> void:
	super.setup(q)
	add_theme_constant_override("separation", 10)
	var hint := ClassTheme.label(str(q.get("choice_hint", "Choose the rune that completes the spell:")), _fs(16), ClassTheme.BROWN)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	add_child(grid)
	for opt in options_for(q):
		var b := Button.new()
		b.text = opt
		b.custom_minimum_size = Vector2(0, 60)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(_on_pick.bind(b))
		grid.add_child(b)
		_tokens.append(b)
	_restyle()


## The answer plus its distractors, de-duplicated and shuffled.
static func options_for(q: Dictionary) -> Array:
	var answer := str(q.get("answer", ""))
	var key := answer.to_lower().strip_edges()
	var opts : Array = [answer]
	for o in q.get("options", []):
		var text := str(o)
		if text.to_lower().strip_edges() == key or opts.has(text):
			continue
		opts.append(text)
	opts.shuffle()
	return opts


func get_value() -> String:
	return _value


func _on_pick(btn: Button) -> void:
	if locked:
		return
	_value = btn.text
	_restyle()
	ClassTheme.pop(btn, 1.08)
	value_changed.emit(_value)


func _restyle(correct_text: String = "", show_result: bool = false) -> void:
	for b in _tokens:
		var bg := ClassTheme.PARCHMENT
		var border := ClassTheme.SAND_DARK
		var fg := ClassTheme.INK
		if show_result and b.text.to_lower().strip_edges() == correct_text:
			bg = ClassTheme.GREEN_LIGHT
			border = ClassTheme.GREEN
			fg = ClassTheme.GREEN
		elif show_result and b.text == _value:
			bg = ClassTheme.RED_LIGHT
			border = ClassTheme.RED
			fg = ClassTheme.RED
		elif b.text == _value:
			bg = ClassTheme.ARCANE_LIGHT
			border = ClassTheme.ARCANE
			fg = ClassTheme.INK_DARK
		ClassTheme.style_button(b, bg, border, fg, _fs(20))


func lock(correct: bool, expected: String) -> void:
	super.lock(correct, expected)
	_restyle(expected.to_lower().strip_edges(), true)
	for b in _tokens:
		b.disabled = true
		# Keep the result colours visible on disabled tokens
		b.add_theme_stylebox_override("disabled", b.get_theme_stylebox("normal"))
		b.add_theme_color_override("font_disabled_color", b.get_theme_color("font_color"))
