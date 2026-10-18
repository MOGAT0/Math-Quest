extends Station
class_name ShapeStation

# =====================================================================
#  Shape table for "shapes" visuals:
#     {"type":"shapes", "shapes":[{"sides":3,"label":"triangle"}, ...]}
#  The shapes lie on a parchment table; tapping a side counts it out
#  loud with the glowing tap guide (poly_view.gd).  Picking an answer
#  that names a shape ("square") lifts that shape.
#  "interactive": false turns the tapping off; "instruction" sets the
#  hint text.
# =====================================================================

var speak : Callable
var number_word : Callable

var _table : PanelContainer
var _box : VBoxContainer
var _views : Array = []     # PolyView per shape, same order as "shapes"
var _labels : Array = []    # lowercase label per shape


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
	_views.clear()
	_labels.clear()
	var v = q.get("visual", {})
	if typeof(v) != TYPE_DICTIONARY:
		return
	var visual : Dictionary = v.duplicate(true)
	visual["interactive"] = bool(v.get("interactive", true))

	if visual.has("instruction"):
		var hint := ClassTheme.label(str(visual["instruction"]), 15, ClassTheme.BROWN)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_box.add_child(hint)

	var builder := VisualBuilder.new(speak, number_word)
	# Leave room around each shape for the tap arrow and count bubbles
	builder.icon_scale = 0.55 if visual.get("shapes", []).size() > 2 else 0.7
	var ctrl := builder.build(visual, size)
	if ctrl:
		_box.add_child(ctrl)
		_views = ctrl.find_children("*", "PolyView", true, false)
	for d in visual.get("shapes", []):
		_labels.append(str(d.get("label", "")).to_lower())


## Lift the shape the chosen answer names, dim the others a little.
func preview(value: String) -> void:
	var v := value.to_lower()
	var named := -1
	# Either way round: answer "square" / label "square", or answer "Arith" /
	# label "Arith's shield"
	for i in range(_labels.size()):
		if _labels[i] == "" or v.length() < 3:
			continue
		if v.contains(_labels[i]) or _labels[i].contains(v):
			named = i
	for i in range(_views.size()):
		var view : Control = _views[i]
		view.pivot_offset = view.size / 2.0
		var lifted := i == named
		var tw := view.create_tween().set_parallel(true)
		tw.tween_property(view, "scale", Vector2.ONE * (1.08 if lifted else 1.0), 0.2) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(view, "modulate", Color(1.15, 1.12, 0.95) if lifted else (Color(1, 1, 1, 0.7) if named != -1 else Color.WHITE), 0.2)


func action_label() -> String:
	return "CAST!"


func success() -> void:
	ClassTheme.burst(self, size / 2.0, ClassTheme.GOLD_LIGHT, 30, 360.0, 0.0, 6.0)
	ClassTheme.pop(_table, 1.05)
	await get_tree().create_timer(0.7).timeout


func fail() -> void:
	ClassTheme.shake(_table)
	await get_tree().create_timer(0.5).timeout
