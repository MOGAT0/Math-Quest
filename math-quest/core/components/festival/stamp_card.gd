extends PanelContainer
class_name StampCard

# =====================================================================
#  The festival stamp card on the HUD, under the clock (moves down when
#  the item-hunt QuestTracker is showing): the festival name, one stamp
#  slot per booth (empty ring -> golden stamp with the booth's icon) and
#  the festival tokens.
# =====================================================================

const SCREEN_POS := Vector2(16, 104)   # same spot as the QuestTracker
const GAP := 8.0
const SLOT := 34.0

var _title : Label
var _tokens : Label
var _row : HBoxContainer
var _slots : Dictionary = {}    # booth id -> Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = SCREEN_POS
	add_theme_stylebox_override("panel", ClassTheme.flat(Color(0.14, 0.1, 0.06, 0.88), ClassTheme.GOLD_LIGHT, 10, 2, 10))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	col.add_child(head)
	_title = ClassTheme.label("", 15, ClassTheme.GOLD_LIGHT)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_tokens = ClassTheme.label("", 15, ClassTheme.PARCHMENT)
	head.add_child(_tokens)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 6)
	col.add_child(_row)
	hide()


## booths: the festival's booth defs (id + icon), stamped: ids done.
func show_card(title: String, booths: Array, stamped: Array, tokens: int) -> void:
	_title.text = title
	# Remove the old slots right away (not just queue_free), or the card
	# would briefly hold both sets and stay stretched
	for c in _row.get_children():
		_row.remove_child(c)
		c.queue_free()
	_slots.clear()
	for b in booths:
		var slot := Label.new()
		slot.custom_minimum_size = Vector2(SLOT, SLOT)
		slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot.add_theme_font_size_override("font_size", 16)
		slot.tooltip_text = str(b.get("name", ""))
		slot.set_meta("icon", str(b.get("icon", "★")))
		_row.add_child(slot)
		_slots[str(b.get("id", ""))] = slot
		_style_slot(slot, stamped.has(str(b.get("id", ""))))
	set_tokens(tokens)
	reset_size()
	show()
	ClassTheme.pop(self, 1.06)


func stamp(booth_id: String) -> void:
	var slot : Label = _slots.get(booth_id)
	if slot:
		_style_slot(slot, true)
		ClassTheme.pop(slot, 1.5)


func set_tokens(tokens: int) -> void:
	_tokens.text = "🪙 %d" % tokens


func _style_slot(slot: Label, done: bool) -> void:
	slot.text = str(slot.get_meta("icon")) if done else ""
	var style := ClassTheme.flat(ClassTheme.GOLD_LIGHT if done else Color(0, 0, 0, 0.25),
		ClassTheme.GOLD if done else Color(1, 1, 1, 0.35), int(SLOT / 2.0), 2)
	slot.add_theme_stylebox_override("normal", style)
	slot.modulate = Color.WHITE if done else Color(1, 1, 1, 0.8)


func _process(_delta: float) -> void:
	# Sit under the item-hunt tracker while it is on screen
	var y := SCREEN_POS.y
	for c in get_parent().get_children() if get_parent() else []:
		if c is QuestTracker and c.visible:
			y = c.position.y + c.size.y + GAP
	position.y = y
