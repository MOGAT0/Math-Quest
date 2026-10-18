extends Station
class_name CountingStation

# =====================================================================
#  Counting table for "grid" visuals ({"items":[{"icon":"🌕","count":18}]})
#  and uneven "groups" bundles ({"bundles":[3, 10, 5]}).  The charms or
#  bundles lie on a parchment table; tapping counts them out loud.  The
#  total is then typed on the number pad.
# =====================================================================

var speak : Callable
var number_word : Callable

var _table : PanelContainer
var _box : VBoxContainer
var _items : Control = null


func _init() -> void:
	super._init()
	mouse_filter = Control.MOUSE_FILTER_PASS
	_table = PanelContainer.new()
	_table.add_theme_stylebox_override("panel", ClassTheme.flat(ClassTheme.PARCHMENT, ClassTheme.GOLD, 16, 3, 12))
	add_child(_table)
	_box = VBoxContainer.new()
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_theme_constant_override("separation", 10)
	_table.add_child(_box)
	resized.connect(func():
		_table.position = Vector2.ZERO
		_table.size = size
	)


func setup(q: Dictionary, answer_type: String) -> void:
	super.setup(q, answer_type)
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	_items = null
	var v = q.get("visual", {})
	if typeof(v) != TYPE_DICTIONARY:
		return

	var hint := ClassTheme.label(_hint_text(v), 15, ClassTheme.BROWN)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(hint)

	var builder := VisualBuilder.new(speak, number_word)
	builder.icon_scale = _chip_scale(v)
	_items = builder.build(v, size)
	if _items:
		_box.add_child(_items)


func _hint_text(v: Dictionary) -> String:
	if str(v.get("type", "")) != "groups":
		return "Tap each charm to count it!"
	var bundles := VisualBuilder.read_bundles(v.get("groups", {}))
	if VisualBuilder.bundles_equal(bundles) and not bundles.is_empty():
		return "Tap each bundle and count by %ds!" % int(bundles[0]["count"])
	return "Tap each bundle to add it up!"


## Smaller charms when there are many, so they all fit on the table.
func _chip_scale(v: Dictionary) -> float:
	var total := 0
	for item in v.get("items", []):
		total += int(item.get("count", 0))
	if str(v.get("type", "")) == "groups":
		for b in VisualBuilder.read_bundles(v.get("groups", {})):
			total += int(b["count"])
	if total > 60:
		return 0.55
	if total > 24:
		return 0.7
	if total > 12:
		return 0.85
	return 1.0


func action_label() -> String:
	return "COUNT!"


func success() -> void:
	ClassTheme.burst(self, size / 2.0, ClassTheme.GOLD_LIGHT, 30, 360.0, 0.0, 6.0)
	ClassTheme.pop(_table, 1.05)
	await get_tree().create_timer(0.7).timeout


func fail() -> void:
	ClassTheme.shake(_table)
	await get_tree().create_timer(0.5).timeout
