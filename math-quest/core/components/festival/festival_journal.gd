extends Control
class_name FestivalJournal

# =====================================================================
#  The festival journal (opened from the calendar page): every major
#  event of the year with its status (badge earned / attended / missed /
#  coming up), the best booth scores and the prizes collected.
# =====================================================================

var _body : VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.08, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			close()
	)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ClassTheme.flat(ClassTheme.PARCHMENT, ClassTheme.GOLD, 18, 4, 20))
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	col.add_child(head)
	var title := ClassTheme.label("📖  Festival Journal", 26, ClassTheme.CRIMSON)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(44, 40)
	ClassTheme.style_button(close_btn, ClassTheme.CRIMSON, ClassTheme.CRIMSON_DARK, ClassTheme.PARCHMENT, 18)
	close_btn.pressed.connect(close)
	head.add_child(close_btn)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(640, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 8)
	scroll.add_child(_body)
	_rebuild()


func _rebuild() -> void:
	for c in _body.get_children():
		c.queue_free()
	var cal := CalendarManager

	_body.add_child(_section("Festivals  ·  Year %d     🪙 %d tokens" % [cal.year, FestivalDirector.tokens()]))
	var events : Array = cal.major_events.duplicate()
	events.sort_custom(func(a, b): return int(a.get("season", 0)) * 100 + int(a.get("day", 0)) < int(b.get("season", 0)) * 100 + int(b.get("day", 0)))
	for e in events:
		_body.add_child(_festival_row(e))

	_body.add_child(_section("Best scores"))
	var any_best := false
	for e in events:
		var fest = e.get("festival", {})
		if typeof(fest) != TYPE_DICTIONARY:
			continue
		for b in fest.get("booths", []):
			var best = FestivalDirector.best_score(str(b.get("id", "")))
			if best == null:
				continue
			any_best = true
			var unit := "s" if str(b.get("game", "")) == "race" else "pts"
			_body.add_child(ClassTheme.label("   %s %s  -  %d %s" % [b.get("icon", ""), b.get("name", ""), int(best), unit], 16, ClassTheme.INK))
	if not any_best:
		_body.add_child(ClassTheme.label("   Play a festival booth to set your first record!", 15, ClassTheme.BROWN))

	_body.add_child(_section("Special tokens (trade them to the Traveling Trader)"))
	var special := FestivalDirector.special_tokens()
	for t in FestivalDirector.special_token_defs():
		var n := int(special.get(str(t.get("id", "")), 0))
		var l := ClassTheme.label("   %s %s  x%d" % [t.get("icon", ""), t.get("name", ""), n], 16, ClassTheme.INK_DARK if n > 0 else ClassTheme.BROWN)
		l.modulate = Color.WHITE if n > 0 else Color(1, 1, 1, 0.55)
		_body.add_child(l)

	_body.add_child(_section("Prizes collected"))
	var owned := FestivalDirector.collectibles()
	if owned.is_empty():
		_body.add_child(ClassTheme.label("   Nothing yet.", 15, ClassTheme.BROWN))
	for e in events:
		var fest = e.get("festival", {})
		if typeof(fest) != TYPE_DICTIONARY:
			continue
		var keepsakes : Array = fest.get("prizes", []).duplicate()
		if typeof(fest.get("gift")) == TYPE_DICTIONARY:
			keepsakes.append(fest["gift"])
		for p in keepsakes:
			if owned.has(str(p.get("id", ""))):
				_body.add_child(ClassTheme.label("   %s %s" % [p.get("icon", ""), p.get("name", "")], 17, ClassTheme.INK_DARK))


func _festival_row(e: Dictionary) -> Control:
	var cal := CalendarManager
	var id := str(e.get("id", ""))
	var status := FestivalDirector.status_of(id, int(e.get("season", 0)), int(e.get("day", 1)))
	var row := PanelContainer.new()
	var earned := status == "badge"
	row.add_theme_stylebox_override("panel", ClassTheme.flat(ClassTheme.GOLD_LIGHT if earned else ClassTheme.PARCHMENT_DARK,
		ClassTheme.GOLD if earned else ClassTheme.SAND_DARK, 10, 2, 8))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	row.add_child(h)
	var icon := ClassTheme.label(str(e.get("icon", "★")), 26)
	icon.modulate = Color.WHITE if status in ["badge", "attended", "today"] else Color(1, 1, 1, 0.45)
	h.add_child(icon)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(text)
	text.add_child(ClassTheme.label(str(e.get("title", "")), 18, ClassTheme.INK_DARK))
	text.add_child(ClassTheme.label("%s %d" % [cal.SEASONS[int(e.get("season", 0))], int(e.get("day", 1))], 13, ClassTheme.BROWN))
	var labels := {
		"badge": ["🏅 Badge earned!", ClassTheme.GOLD],
		"attended": ["✓ Attended", ClassTheme.GREEN],
		"missed": ["Missed", ClassTheme.RED],
		"today": ["Today!", ClassTheme.CRIMSON],
		"upcoming": ["Coming up", ClassTheme.BROWN],
		"past": ["Passed", ClassTheme.BROWN],
	}
	var l : Array = labels.get(status, labels["upcoming"])
	var tag := ClassTheme.label(l[0], 16, l[1])
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(tag)
	return row


func _section(text: String) -> Label:
	var l := ClassTheme.label(text, 17, ClassTheme.CRIMSON)
	return l


func close() -> void:
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
