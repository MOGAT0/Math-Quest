extends Control
class_name TraderPopup

# =====================================================================
#  The Traveling Trader (at every major event): swaps the special event
#  tokens bought at the festival prize booths for KP. Lists every special
#  token of the year (the ones not owned yet are greyed out), how many
#  the player has and what each is worth. FestivalDirector does the
#  trade (trade_special_tokens) and the saving.
# =====================================================================

signal closed

var _list : VBoxContainer
var _feedback : Label
var _total_label : Label


func open(trader: Dictionary) -> void:
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
	panel.add_theme_stylebox_override("panel", ClassTheme.flat(ClassTheme.PARCHMENT, Color(str(trader.get("awning", "#2f5a7a"))), 18, 5, 22))
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	col.add_child(head)
	var title := ClassTheme.label("%s  %s" % [trader.get("icon", "🧳"), trader.get("name", "Traveling Trader")], 26, ClassTheme.CRIMSON)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_total_label = ClassTheme.label("", 18, ClassTheme.GOLD)
	head.add_child(_total_label)

	var intro := ClassTheme.label("\"%s\"" % str(trader.get("intro", "")), 17, ClassTheme.BROWN)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size = Vector2(560, 0)
	col.add_child(intro)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(560, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)

	_feedback = ClassTheme.label("", 16, ClassTheme.GREEN)
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_feedback)
	var done := Button.new()
	done.text = "Done"
	done.custom_minimum_size = Vector2(180, 52)
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ClassTheme.style_button(done, ClassTheme.CRIMSON, ClassTheme.CRIMSON_DARK, ClassTheme.PARCHMENT, 20)
	done.pressed.connect(close)
	col.add_child(done)
	_refresh()


func _refresh() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var owned := FestivalDirector.special_tokens()
	var worth := 0
	for t in FestivalDirector.special_token_defs():
		var id := str(t.get("id", ""))
		var count := int(owned.get(id, 0))
		var value := int(t.get("kp_value", 50))
		worth += count * value
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", ClassTheme.flat(ClassTheme.PARCHMENT_DARK, ClassTheme.SAND_DARK, 10, 2, 8))
		row.modulate = Color.WHITE if count > 0 else Color(1, 1, 1, 0.5)
		_list.add_child(row)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		row.add_child(h)
		h.add_child(ClassTheme.label(str(t.get("icon", "🎟️")), 28))
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(text)
		text.add_child(ClassTheme.label(str(t.get("name", "")), 18, ClassTheme.INK_DARK))
		text.add_child(ClassTheme.label("You have %d  ·  %d KP each" % [count, value], 14, ClassTheme.BROWN))
		# "Trade 1" always; "Trade all" only when there is more than one
		var amounts := [1] if count <= 1 else [1, count]
		for n in amounts:
			var b := Button.new()
			b.text = "Trade 1" if n == 1 else "Trade all"
			b.custom_minimum_size = Vector2(110, 44)
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			b.disabled = count < 1
			ClassTheme.style_button(b, ClassTheme.GREEN if not b.disabled else ClassTheme.SAND, ClassTheme.GREEN,
				ClassTheme.PARCHMENT if not b.disabled else ClassTheme.BROWN, 16)
			b.pressed.connect(_trade.bind(id, n))
			h.add_child(b)
	_total_label.text = "Worth: %d KP" % worth


func _trade(id: String, count: int) -> void:
	var kp := FestivalDirector.trade_special_tokens(id, count)
	if kp > 0:
		_feedback.add_theme_color_override("font_color", ClassTheme.GREEN)
		_feedback.text = "Traded! +%d KP" % kp
		ClassTheme.pop(_feedback, 1.2)
	else:
		_feedback.add_theme_color_override("font_color", ClassTheme.RED)
		_feedback.text = "You don't have that token yet."
		ClassTheme.shake(_feedback)
	_refresh()


func close() -> void:
	closed.emit()
	queue_free()
