extends Station
class_name MarketStation

# =====================================================================
#  A market counter for money questions:
#    shopping  {"type":"market","mode":"shopping","budget":15,
#               "items":[{"name":"Apples","icon":"🍎","price":4,"qty":1}, ...]}
#    change    {"type":"market","mode":"change","paid":10,"items":[...]}
#  Top: the coin purse (budget) or the coins the customer paid. Middle:
#  a price card per item. Bottom: a receipt slip where the typed answer
#  appears. Right = coins hop into the purse, wrong = the slip shakes.
# =====================================================================

const COIN := Color("#f2c94c")
const COIN_DARK := Color("#b88a1e")

var _box : VBoxContainer
var _coins : CoinRow
var _purse_label : Label
var _cards : HBoxContainer
var _slip : PanelContainer
var _slip_label : Label
var _slip_prefix : String = ""


func _init() -> void:
	super._init()
	_box = VBoxContainer.new()
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_theme_constant_override("separation", 10)
	add_child(_box)
	resized.connect(func():
		_box.position = Vector2(12, 8)
		_box.size = size - Vector2(24, 16)
	)


func setup(q: Dictionary, answer_type: String) -> void:
	super.setup(q, answer_type)
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	var v = q.get("visual", {})
	if typeof(v) != TYPE_DICTIONARY:
		return
	var change : bool = str(v.get("mode", "shopping")) == "change"

	# Purse / paid coins
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 12)
	_box.add_child(top)
	var amount := int(v.get("paid", 0)) if change else int(v.get("budget", 0))
	_purse_label = ClassTheme.label(("🪙 Paid: %d coins" if change else "👛 You have %d coins") % amount, 21, ClassTheme.GOLD_LIGHT)
	top.add_child(_purse_label)
	_coins = CoinRow.new()
	_coins.count = amount
	_coins.custom_minimum_size = Vector2(160, 36)
	top.add_child(_coins)

	# Price cards
	_cards = HBoxContainer.new()
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards.add_theme_constant_override("separation", 16)
	_box.add_child(_cards)
	for item in v.get("items", []):
		_cards.add_child(_card(item))

	# Receipt slip
	_slip = PanelContainer.new()
	_slip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_slip.add_theme_stylebox_override("panel", ClassTheme.flat(Color("#fffaf0"), ClassTheme.SAND_DARK, 4, 2, 8))
	_box.add_child(_slip)
	_slip_prefix = "Change: " if change else "Answer: "
	_slip_label = ClassTheme.label(_slip_prefix + "?", 22, ClassTheme.INK_DARK)
	_slip.add_child(_slip_label)


func _card(item: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", ClassTheme.flat(ClassTheme.PARCHMENT, ClassTheme.GOLD, 10, 3, 12))
	card.custom_minimum_size = Vector2(118, 0)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 2)
	card.add_child(col)
	var qty := int(item.get("qty", 1))
	var icon := ClassTheme.label(str(item.get("icon", "🧺")) + ("  x%d" % qty if qty > 1 else ""), 36)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(icon)
	var name_label := ClassTheme.label(str(item.get("name", "")), 19, ClassTheme.INK)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(name_label)
	var price := ClassTheme.label("%d coins%s" % [int(item.get("price", 0)), " each" if qty > 1 else ""], 18, ClassTheme.CRIMSON)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(price)
	return card


func preview(value: String) -> void:
	if _slip_label:
		_slip_label.text = _slip_prefix + (value if value != "" else "?") + (" coins" if value != "" else "")


func action_label() -> String:
	return "PAY!"


func cast_color() -> Color:
	return COIN


func success() -> void:
	if _coins:
		_coins.hop()
	ClassTheme.pop(_slip, 1.15)
	await get_tree().create_timer(0.7).timeout


func fail() -> void:
	ClassTheme.shake(_slip)
	await get_tree().create_timer(0.45).timeout


## A row of drawn coins (at most 10 shown, then "+n").
class CoinRow extends Control:
	var count : int = 0
	var _hop : float = 0.0:
		set(v):
			_hop = v
			queue_redraw()

	func hop() -> void:
		var tw := create_tween()
		tw.tween_property(self, "_hop", 1.0, 0.18)
		tw.tween_property(self, "_hop", 0.0, 0.25)

	func _draw() -> void:
		var shown := mini(count, 10)
		var r := minf(size.y * 0.32, 9.0)
		for i in range(shown):
			var c := Vector2(r + i * r * 1.3, size.y / 2.0 - sin(_hop * PI) * 6.0 * (1.0 if i % 2 == 0 else 0.6))
			draw_circle(c + Vector2(0, 2), r, MarketStation.COIN_DARK)
			draw_circle(c, r, MarketStation.COIN)
			draw_arc(c, r * 0.6, 0.0, TAU, 16, MarketStation.COIN_DARK, 1.2)
		if count > shown:
			draw_string(get_theme_default_font(), Vector2(r + shown * r * 1.3, size.y / 2.0 + 6), "+%d" % (count - shown),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ClassTheme.GOLD_LIGHT)
