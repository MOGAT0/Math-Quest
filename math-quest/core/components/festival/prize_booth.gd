extends Control
class_name PrizeBooth

# =====================================================================
#  The festival prize booth: spend festival tokens on prizes listed in
#  the festival data ("prizes"). Each prize has an effect:
#    {"stamina": n}       refill stamina
#    {"kp": n}            add KP
#    {"collectible": true}  kept in the journal, one per player
#    {"special_token": true}  this festival's special token (stackable),
#                         traded for KP at the Traveling Trader
#  The popup only asks; FestivalDirector.buy_prize() checks the tokens,
#  applies the effect and saves.
# =====================================================================

signal closed

var _prizes : Array = []
var _tokens_label : Label
var _list : VBoxContainer
var _feedback : Label


func open(booth: Dictionary, prizes: Array) -> void:
	_prizes = prizes
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
	panel.add_theme_stylebox_override("panel", ClassTheme.flat(ClassTheme.PARCHMENT, Color(str(booth.get("awning", "#c8962a"))), 18, 5, 22))
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	col.add_child(head)
	var title := ClassTheme.label("%s  %s" % [booth.get("icon", "🎁"), booth.get("name", "Prize Booth")], 26, ClassTheme.CRIMSON)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_tokens_label = ClassTheme.label("", 22, ClassTheme.GOLD)
	head.add_child(_tokens_label)

	var intro := ClassTheme.label("%s: \"%s\"" % [booth.get("host_name", "Host"), booth.get("intro", "")], 17, ClassTheme.BROWN)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size = Vector2(520, 0)
	col.add_child(intro)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	col.add_child(_list)
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
	var tokens := FestivalDirector.tokens()
	_tokens_label.text = "🪙 %d" % tokens
	for c in _list.get_children():
		c.queue_free()
	for p in _prizes:
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", ClassTheme.flat(ClassTheme.PARCHMENT_DARK, ClassTheme.SAND_DARK, 10, 2, 10))
		_list.add_child(row)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		row.add_child(h)
		h.add_child(ClassTheme.label(str(p.get("icon", "🎁")), 28))
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(text)
		text.add_child(ClassTheme.label(str(p.get("name", "")), 19, ClassTheme.INK_DARK))
		var about := str(p.get("description", ""))
		if bool(p.get("effect", {}).get("special_token", false)):
			about += "  (You have %d)" % int(FestivalDirector.special_tokens().get(str(p.get("id", "")), 0))
		var desc := ClassTheme.label(about, 14, ClassTheme.BROWN)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(300, 0)
		text.add_child(desc)
		var buy := Button.new()
		buy.custom_minimum_size = Vector2(120, 48)
		buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var cost := int(p.get("cost", 1))
		var owned := FestivalDirector.has_collectible(str(p.get("id", ""))) and bool(p.get("effect", {}).get("collectible", false))
		if owned:
			buy.text = "Owned"
			buy.disabled = true
		else:
			buy.text = "🪙 %d" % cost
			buy.disabled = tokens < cost
		ClassTheme.style_button(buy, ClassTheme.GREEN if not buy.disabled else ClassTheme.SAND, ClassTheme.GREEN, ClassTheme.PARCHMENT if not buy.disabled else ClassTheme.BROWN, 18)
		buy.pressed.connect(_buy.bind(p))
		h.add_child(buy)


func _buy(prize: Dictionary) -> void:
	if FestivalDirector.buy_prize(prize):
		_feedback.add_theme_color_override("font_color", ClassTheme.GREEN)
		_feedback.text = "You got the %s!" % str(prize.get("name", "prize"))
		ClassTheme.pop(_feedback, 1.2)
	else:
		_feedback.add_theme_color_override("font_color", ClassTheme.RED)
		_feedback.text = "Not enough tokens yet. Play the booths to earn more!"
		ClassTheme.shake(_feedback)
	_refresh()


func close() -> void:
	closed.emit()
	queue_free()
