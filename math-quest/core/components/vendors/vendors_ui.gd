extends Control
class_name VendorShop

signal item_purchased(product_id: String, stamina: int, price: int)
signal shop_closed

@export_file("*.json") var data_path: String = "res://data/vendors_data.json"
@export var vendor_name: String = "Traveling Vendor"
@export var player_money: int = 300
@export var seconds_per_character: float = 0.03
@export var panel_height: float = 400.0
## Empty space on the left and right edges of the screen.
@export var side_margin: int = 60
## Size (in pixels) of each square item slot.
@export var slot_size: float = 130.0
## Dim overlay shown behind the shop (alpha controls how dark it is).
@export var shop_dim_color: Color = Color(0, 0, 0, 0.5)
## Width of the item detail panel on the right.
@export var detail_width: float = 320.0

const CREAM := Color("f8ead2")
const CREAM_BTN := Color("f2e0b6")
const GOLD := Color("b07d1a")
const INK := Color("1e1408")
const RED := Color("8b2020")
const RED_BORDER := Color("fbf0dc")
const LEAF := Color("4a6b2a")

# Inventory-style palette
const WOOD := Color("8a5a30")
const WOOD_DARK := Color("5e3a1a")
const SLOT := Color("f7e8c8")
const SLOT_BORDER := Color("e2c993")
const SLOT_SELECTED := Color("f6b92b")
const SLOT_SELECTED_BORDER := Color("c98410")
const YELLOW_BTN := Color("f8b52a")
const YELLOW_BTN_BORDER := Color("fff1c2")
const BTN_TEXT := Color("7a3b00")
const SOFT_TEXT := Color("7a6a48")

const STOCK_SIZE := 9
const UNIQUE_VENDORS := 7
const GRID_COLUMNS := 4

static var _unused_pool: Array = [] 
static var _vendors_stocked: int = 0

var _dialogue: String = ""
var _products: Dictionary = {}
var _stock: Array = []        

var _built := false
var _in_shop := false
var _typing_tween: Tween
var _slots: Dictionary = {}
var _selected_id: String = ""

# Main UI nodes
var _root_margin: MarginContainer
var _title_label: Label
var _money_label: Label
var _dialogue_label: Label
var _button_row: MarginContainer
var _shop_btn: Button
var _shop_view: HBoxContainer
var _shop_scroll: ScrollContainer
var _product_grid: GridContainer
var _spacer: Control
var _panel: PanelContainer
var _panel_margin: MarginContainer
var _shop_bg: ColorRect
var _dialogue_panel_style: StyleBoxFlat
var _shop_panel_style: StyleBoxFlat

# Detail panel nodes
var _detail_panel: PanelContainer
var _detail_icon: Label
var _detail_name: Label
var _detail_stamina: Label
var _detail_desc: Label
var _detail_price: Label
var _detail_buy_btn: Button

var _challenge_overlay: Control
var _challenge_title: Label
var _challenge_question: Label
var _challenge_equation: Label
var _numpad: NumberPad                # same on-screen pad as the class
var _numpad_holder: VBoxContainer
var _feedback_label: Label

var _current_product_id: String = ""
var _current_answer: int = 0


func _ready() -> void:
	hide()
	#start_shop()
	player_money = GameManager.kp_amount

# ------------------------------------------------------------------ PUBLIC

func start_shop() -> void:
	player_money = GameManager.kp_amount
	
	if not _load_data():
		return
	_ensure_stock()
	if not _built:
		_build_ui()
		_built = true

	_title_label.text = vendor_name
	_populate_products()
	_update_money()
	_set_shop_mode(false)
	_challenge_overlay.hide()
	_button_row.hide()
	show()
	_play_dialogue()


func set_money(amount: int) -> void:
	player_money = amount
	if _built:
		_update_money()


# ------------------------------------------------------------------ DATA

func _load_data() -> bool:
	if not FileAccess.file_exists(data_path):
		push_error("VendorShop: file not found: %s" % data_path)
		return false
	var file := FileAccess.open(data_path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("VendorShop: invalid JSON in %s" % data_path)
		return false
	_dialogue = parsed.get("dialogue", "")
	_products = parsed.get("products", {})
	return true

static func reset_vendor_rotation() -> void:
	_unused_pool.clear()
	_vendors_stocked = 0

func reroll_stock() -> void:
	_stock.clear()
	_ensure_stock()


func _ensure_stock() -> void:
	if not _stock.is_empty() and _stock.all(func(id): return _products.has(id)):
		return
	_stock = _roll_stock()


func _roll_stock() -> Array:
	var all_ids: Array = _products.keys()
	var count: int = mini(STOCK_SIZE, all_ids.size())
	var picks: Array = []

	if _vendors_stocked < UNIQUE_VENDORS:
		while picks.size() < count:
			if _unused_pool.is_empty():
				_unused_pool = all_ids.filter(func(id): return not picks.has(id))
				_unused_pool.shuffle()
			picks.append(_unused_pool.pop_back())
	else:
		var shuffled: Array = all_ids.duplicate()
		shuffled.shuffle()
		picks = shuffled.slice(0, count)

	_vendors_stocked += 1
	return picks


# ------------------------------------------------------------------ STYLE HELPERS

func _box(bg: Color, border: Color = Color.TRANSPARENT, border_w: int = 0, radius: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	return sb


func _style_button(btn: Button, bg: Color, border: Color, font_color: Color,
		font_size: int = 30, radius: int = 22, border_w: int = 4) -> void:
	btn.add_theme_stylebox_override("normal", _box(bg, border, border_w, radius))
	btn.add_theme_stylebox_override("hover", _box(bg.lightened(0.12), border, border_w, radius))
	btn.add_theme_stylebox_override("pressed", _box(bg.darkened(0.12), border, border_w, radius))
	btn.add_theme_stylebox_override("disabled", _box(Color("c9bfa8"), Color("948a75"), border_w, radius))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		btn.add_theme_color_override(c, font_color)
	btn.add_theme_color_override("font_disabled_color", Color("7d745f"))
	btn.add_theme_font_size_override("font_size", font_size)


func _style_label(lbl: Label, label_size: int, color: Color = INK) -> void:
	lbl.add_theme_font_size_override("font_size", label_size)
	lbl.add_theme_color_override("font_color", color)


func _make_margin(l: int, t: int, r: int, b: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", l)
	m.add_theme_constant_override("margin_top", t)
	m.add_theme_constant_override("margin_right", r)
	m.add_theme_constant_override("margin_bottom", b)
	return m


func _set_margin(m: MarginContainer, l: int, t: int, r: int, b: int) -> void:
	m.add_theme_constant_override("margin_left", l)
	m.add_theme_constant_override("margin_top", t)
	m.add_theme_constant_override("margin_right", r)
	m.add_theme_constant_override("margin_bottom", b)


# ------------------------------------------------------------------ UI BUILD

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_shop_bg = ColorRect.new()
	_shop_bg.color = shop_dim_color
	_shop_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shop_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shop_bg.hide()
	add_child(_shop_bg)

	# Everything lives inside this container so the screen edges get a margin.
	_root_margin = _make_margin(side_margin, 0, side_margin, 0)
	_root_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root_margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 0)
	_root_margin.add_child(layout)

	_spacer = Control.new()
	_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(_spacer)

	_button_row = _make_margin(0, 0, 0, 36)
	layout.add_child(_button_row)

	var btn_box := HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_END
	btn_box.add_theme_constant_override("separation", 36)
	_button_row.add_child(btn_box)

	var leave_btn := Button.new()
	leave_btn.text = "Leave"
	leave_btn.custom_minimum_size = Vector2(230, 72)
	_style_button(leave_btn, CREAM_BTN, GOLD, INK)
	leave_btn.pressed.connect(_on_leave_pressed)
	btn_box.add_child(leave_btn)

	_shop_btn = Button.new()
	_shop_btn.text = "Shop"
	_shop_btn.custom_minimum_size = Vector2(230, 72)
	_style_button(_shop_btn, RED, RED_BORDER, CREAM)
	_shop_btn.pressed.connect(_on_shop_pressed)
	btn_box.add_child(_shop_btn)

	# Two looks for the same panel: cream dialogue box / wooden inventory frame
	_dialogue_panel_style = _box(CREAM)
	_dialogue_panel_style.border_width_top = 6
	_dialogue_panel_style.border_color = GOLD
	_dialogue_panel_style.corner_radius_top_left = 24
	_dialogue_panel_style.corner_radius_top_right = 24

	_shop_panel_style = _box(WOOD, WOOD_DARK, 6, 28)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(0, panel_height)
	_panel.add_theme_stylebox_override("panel", _dialogue_panel_style)
	layout.add_child(_panel)

	_panel_margin = _make_margin(50, 26, 50, 20)
	_panel.add_child(_panel_margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	_panel_margin.add_child(content)

	var header := HBoxContainer.new()
	content.add_child(header)

	_title_label = Label.new()
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_label(_title_label, 32)
	header.add_child(_title_label)

	_money_label = Label.new()
	_style_label(_money_label, 26, GOLD.darkened(0.2))
	header.add_child(_money_label)

	_dialogue_label = Label.new()
	_dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue_label.custom_minimum_size = Vector2(100, 0)
	_dialogue_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dialogue_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style_label(_dialogue_label, 24)
	content.add_child(_dialogue_label)

	# Shop view: item grid on the left, detail panel on the right
	_shop_view = HBoxContainer.new()
	_shop_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shop_view.add_theme_constant_override("separation", 20)
	content.add_child(_shop_view)

	_shop_scroll = ScrollContainer.new()
	_shop_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shop_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shop_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_shop_view.add_child(_shop_scroll)

	_product_grid = GridContainer.new()
	_product_grid.columns = GRID_COLUMNS
	_product_grid.add_theme_constant_override("h_separation", 14)
	_product_grid.add_theme_constant_override("v_separation", 14)
	_shop_scroll.add_child(_product_grid)

	_build_detail_panel()
	_shop_view.add_child(_detail_panel)

	_build_challenge_ui()


func _build_detail_panel() -> void:
	_detail_panel = PanelContainer.new()
	_detail_panel.custom_minimum_size = Vector2(detail_width, 0)
	_detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_panel.add_theme_stylebox_override("panel", _box(SLOT, SLOT_BORDER, 3, 22))

	var margin := _make_margin(20, 20, 20, 20)
	_detail_panel.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)

	var icon_frame := PanelContainer.new()
	icon_frame.custom_minimum_size = Vector2(110, 110)
	icon_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_frame.add_theme_stylebox_override("panel", _box(SLOT_SELECTED, SLOT_SELECTED_BORDER, 4, 24))
	col.add_child(icon_frame)

	_detail_icon = Label.new()
	_detail_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_detail_icon.add_theme_font_size_override("font_size", 56)
	icon_frame.add_child(_detail_icon)

	_detail_name = Label.new()
	_detail_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(_detail_name, 32)
	col.add_child(_detail_name)

	_detail_stamina = Label.new()
	_detail_stamina.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(_detail_stamina, 22, LEAF)
	col.add_child(_detail_stamina)

	_detail_desc = Label.new()
	_detail_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_desc.custom_minimum_size = Vector2(100, 0)
	_detail_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style_label(_detail_desc, 20, SOFT_TEXT)
	col.add_child(_detail_desc)

	_detail_price = Label.new()
	_detail_price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(_detail_price, 24, GOLD.darkened(0.25))
	col.add_child(_detail_price)

	_detail_buy_btn = Button.new()
	_detail_buy_btn.text = "Buy"
	_detail_buy_btn.custom_minimum_size = Vector2(0, 70)
	_style_button(_detail_buy_btn, YELLOW_BTN, YELLOW_BTN_BORDER, BTN_TEXT, 32, 24, 4)
	_detail_buy_btn.pressed.connect(func() -> void: _on_buy_pressed(_selected_id))
	col.add_child(_detail_buy_btn)


func _build_challenge_ui() -> void:
	_challenge_overlay = Control.new()
	_challenge_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_challenge_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_challenge_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_challenge_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_challenge_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	panel.add_theme_stylebox_override("panel", _box(CREAM, GOLD, 5, 24))
	center.add_child(panel)

	var margin := _make_margin(32, 28, 32, 28)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)

	_challenge_title = Label.new()
	_challenge_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(_challenge_title, 30)
	box.add_child(_challenge_title)

	# Question on the left, number pad on the right (the pad is too tall to
	# stack under the question on a 648 px high screen)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 28)
	box.add_child(body)

	var left := VBoxContainer.new()
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 14)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left)

	_challenge_question = Label.new()
	_challenge_question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_challenge_question.custom_minimum_size = Vector2(380, 0)
	_style_label(_challenge_question, 22)
	left.add_child(_challenge_question)

	_challenge_equation = Label.new()
	_challenge_equation.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(_challenge_equation, 42, RED)
	left.add_child(_challenge_equation)

	_feedback_label = Label.new()
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback_label.custom_minimum_size = Vector2(0, 30)
	_style_label(_feedback_label, 22)
	left.add_child(_feedback_label)

	_numpad_holder = VBoxContainer.new()
	_numpad_holder.custom_minimum_size = Vector2(260, 0)
	body.add_child(_numpad_holder)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 24)
	box.add_child(btn_row)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(170, 56)
	_style_button(cancel_btn, CREAM_BTN, GOLD, INK, 26, 18, 4)
	cancel_btn.pressed.connect(_close_challenge)
	btn_row.add_child(cancel_btn)

	var submit_btn := Button.new()
	submit_btn.text = "Submit"
	submit_btn.custom_minimum_size = Vector2(170, 56)
	_style_button(submit_btn, RED, RED_BORDER, CREAM, 26, 18, 4)
	submit_btn.pressed.connect(_on_submit_pressed)
	btn_row.add_child(submit_btn)


# ------------------------------------------------------------------ PRODUCTS

func _populate_products() -> void:
	for child in _product_grid.get_children():
		child.queue_free()
	_slots.clear()
	_selected_id = ""

	for product_id: String in _stock:
		var data: Dictionary = _products[product_id]
		var price: int = int(data.get("price", 0))

		var slot := Button.new()
		slot.custom_minimum_size = Vector2(slot_size, slot_size)
		slot.focus_mode = Control.FOCUS_NONE
		slot.pressed.connect(_select_product.bind(product_id))
		_product_grid.add_child(slot)

		# Overlay: icon centered, price badge in the bottom-right corner
		var overlay := _make_margin(8, 8, 10, 6)
		overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(overlay)

		var icon := Label.new()
		icon.text = str(data.get("icon", "?"))
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
		icon.add_theme_font_size_override("font_size", 56)
		overlay.add_child(icon)

		var badge := Label.new()
		badge.text = "%d" % price
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		badge.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		badge.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_style_label(badge, 22, INK)
		overlay.add_child(badge)

		_slots[product_id] = slot
		_apply_slot_style(slot, false)

	if not _stock.is_empty():
		_select_product(_stock[0])
	_refresh_buy_buttons()


func _apply_slot_style(slot: Button, selected: bool) -> void:
	var bg := SLOT_SELECTED if selected else SLOT
	var border := SLOT_SELECTED_BORDER if selected else SLOT_BORDER
	slot.add_theme_stylebox_override("normal", _box(bg, border, 4, 20))
	slot.add_theme_stylebox_override("hover", _box(bg.lightened(0.08), border, 4, 20))
	slot.add_theme_stylebox_override("pressed", _box(bg.darkened(0.08), border, 4, 20))
	slot.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _select_product(product_id: String) -> void:
	if not _products.has(product_id):
		return
	_selected_id = product_id

	for id: String in _slots:
		_apply_slot_style(_slots[id], id == product_id)

	var data: Dictionary = _products[product_id]
	var stamina: int = int(data.get("stamina", 0))
	var price: int = int(data.get("price", 0))

	_detail_icon.text = str(data.get("icon", "?"))
	_detail_name.text = product_id.capitalize()
	_detail_stamina.text = "+%d stamina" % stamina
	_detail_desc.text = str(data.get("description", "Restores %d stamina." % stamina))
	_detail_price.text = "%d KP" % price
	_refresh_detail_button()


func _refresh_detail_button() -> void:
	if _selected_id.is_empty() or not _products.has(_selected_id):
		_detail_buy_btn.disabled = true
		return
	var price: int = int(_products[_selected_id].get("price", 0))
	_detail_buy_btn.disabled = price > player_money
	_detail_buy_btn.tooltip_text = "Not enough KP" if _detail_buy_btn.disabled else ""


func _refresh_buy_buttons() -> void:
	for product_id: String in _slots:
		var price: int = int(_products[product_id].get("price", 0))
		var slot: Button = _slots[product_id]
		# Dim items the player can't afford
		slot.modulate = Color(1, 1, 1, 1) if price <= player_money else Color(1, 1, 1, 0.55)
	_refresh_detail_button()


func _update_money() -> void:
	_money_label.text = "KP: %d" % player_money
	_refresh_buy_buttons()
	_update_KP(player_money)

func _update_KP(new_amount) -> void:
	db.query("UPDATE progress SET kp = %d WHERE is_active = true" % new_amount)
	GameManager._update_KP()
	#player_money = GameManager.kp_amount
# ------------------------------------------------------------------ DIALOGUE

func _play_dialogue() -> void:
	if visible:
		MusicPlayer.one_shot = true
	_dialogue_label.text = _dialogue
	_dialogue_label.visible_ratio = 0.0
	if _typing_tween:
		_typing_tween.kill()
	var duration: float = max(_dialogue.length() * seconds_per_character, 0.01)
	_typing_tween = create_tween()
	_typing_tween.tween_property(_dialogue_label, "visible_ratio", 1.0, duration)
	_typing_tween.finished.connect(_on_dialogue_finished)


func _on_dialogue_finished() -> void:
	MusicPlayer.one_shot = false
	_dialogue_label.visible_ratio = 1.0
	_button_row.show()


func _input(event: InputEvent) -> void:
	if not visible or _typing_tween == null or not _typing_tween.is_running():
		return
	var clicked = event is InputEventMouseButton and event.pressed
	if clicked or event.is_action_pressed("ui_accept"):
		_typing_tween.kill()
		_on_dialogue_finished()
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ BUTTON HANDLERS

func _set_shop_mode(enabled: bool) -> void:
	_in_shop = enabled
	_dialogue_label.visible = not enabled
	_shop_view.visible = enabled
	_shop_btn.text = "Back" if enabled else "Shop"
	_shop_bg.visible = enabled
	_spacer.visible = not enabled
	_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL if enabled else Control.SIZE_FILL
	_panel.custom_minimum_size.y = 0.0 if enabled else panel_height
	_panel.add_theme_stylebox_override("panel", _shop_panel_style if enabled else _dialogue_panel_style)

	# Tighter padding inside the wooden frame, top gap above it
	if enabled:
		_set_margin(_panel_margin, 28, 20, 28, 24)
	else:
		_set_margin(_panel_margin, 50, 26, 50, 20)
	_set_margin(_root_margin, side_margin, 24 if enabled else 0, side_margin, 0)

	# Header text needs to read on wood vs. cream
	_style_label(_title_label, 32, CREAM if enabled else INK)
	_style_label(_money_label, 26, Color("ffd36b") if enabled else GOLD.darkened(0.2))

	_button_row.add_theme_constant_override("margin_top", 24 if enabled else 0)
	_button_row.add_theme_constant_override("margin_bottom", 16 if enabled else 36)


func _on_shop_pressed() -> void:
	_set_shop_mode(not _in_shop)


func _on_leave_pressed() -> void:
	_leave_shop()

func _leave_shop() -> void:
	hide()
	shop_closed.emit()
	MusicPlayer.one_shot = false


func _on_buy_pressed(product_id: String) -> void:
	if product_id.is_empty() or not _products.has(product_id):
		return
	var price: int = int(_products[product_id].get("price", 0))
	if price > player_money:
		return
	_current_product_id = product_id
	_start_challenge(product_id, price)


# ------------------------------------------------------------------ CHALLENGE

func _start_challenge(product_id: String, price: int) -> void:
	var item_name := product_id.capitalize()
	var change := player_money - price

	_challenge_title.text = "Pay for the %s" % item_name

	match randi() % 2:
		0:
			_challenge_question.text = "You have %d KP. The %s costs %d. How much would you have left?" \
					% [player_money, item_name, price]
			_challenge_equation.text = "%d - %d = ?" % [player_money, price]
			_current_answer = change
		_:
			_challenge_question.text = "The %s cost you %d and your change is %d. How much money did you have?" \
					% [item_name, price, change]
			_challenge_equation.text = "? - %d = %d" % [price, change]
			_current_answer = player_money

	_feedback_label.text = ""
	_new_numpad()
	_challenge_overlay.show()


## A fresh pad for every challenge. Enter on a PC keyboard submits.
func _new_numpad() -> void:
	if _numpad:
		_numpad.queue_free()
	_numpad = NumberPad.new()
	_numpad_holder.add_child(_numpad)
	_numpad.setup({})
	_numpad.submitted.connect(_on_submit_pressed)


func _close_challenge() -> void:
	_challenge_overlay.hide()
	if _numpad:
		_numpad.locked = true     # stop it catching number keys while hidden


func _on_submit_pressed() -> void:
	var text := _numpad.get_value().strip_edges() if _numpad else ""
	if not text.is_valid_int():
		_show_feedback("Please enter a whole number.", Color("a56a00"))
		return

	if int(text) == _current_answer:
		var data: Dictionary = _products[_current_product_id]
		var price: int = int(data.get("price", 0))
		var stamina: int = int(data.get("stamina", 0))
		player_money -= price
		_close_challenge()
		_update_money()
		_spawn_confetti()
		item_purchased.emit(_current_product_id, stamina, price)
		GameManager.refill_stamina(stamina)
	else:
		_show_feedback("Not quite, try again!", RED)
		_numpad.clear()


func _show_feedback(msg: String, color: Color) -> void:
	_feedback_label.text = msg
	_feedback_label.add_theme_color_override("font_color", color)


# ------------------------------------------------------------------ CONFETTI

func _spawn_confetti() -> void:
	## Two bursts shoot up from the bottom corners, then fall with gravity.
	var screen := get_viewport_rect().size
	var lifetime := 2.8

	for side in 2:
		var x_dir := 1.0 if side == 0 else -1.0
		var p := CPUParticles2D.new()
		p.position = Vector2(screen.x * (0.08 if side == 0 else 0.92), screen.y)
		p.z_index = 100
		p.one_shot = true
		p.explosiveness = 0.95
		p.amount = 80
		p.lifetime = lifetime
		p.direction = Vector2(x_dir * 0.6, -1.0).normalized()
		p.spread = 35.0
		p.initial_velocity_min = 500.0
		p.initial_velocity_max = 1000.0
		p.gravity = Vector2(0, 900)
		p.damping_min = 20.0
		p.damping_max = 60.0
		p.angle_min = 0.0
		p.angle_max = 360.0
		p.angular_velocity_min = -540.0
		p.angular_velocity_max = 540.0
		p.scale_amount_min = 6.0
		p.scale_amount_max = 14.0
		p.color = Color.from_hsv(0.258, 0.75, 1.0, 1.0)
		p.hue_variation_min = -1.0
		p.hue_variation_max = 1.0
		var fade := Gradient.new()
		fade.set_color(0, Color(1, 1, 1, 1))
		fade.set_color(1, Color(1, 1, 1, 0))
		fade.add_point(0.75, Color(1, 1, 1, 1))
		p.color_ramp = fade
		add_child(p)
		p.emitting = true
		get_tree().create_timer(lifetime + 0.5).timeout.connect(p.queue_free)
