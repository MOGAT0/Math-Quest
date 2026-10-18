extends Station
class_name PuzzleStation

# =====================================================================
#  Puzzle table: the hands-on puzzles are solved right on the stage.
#       shape_match  {"shapes":[{"sides":3,"label":"triangle"}, ...]}
#       block_stack  {"heights":[3,1,4,2], "order":"asc"|"desc"}
#       connect_dots {"dots":[[0.2,0.8],[0.5,0.2],[0.8,0.8]],
#                     "labels":["2","4","6"], "close":true}
#  Emits solved(mistakes) once finished; 0 mistakes counts as correct.
# =====================================================================

signal solved(mistakes: int)

const SHAPE_COLORS := [Color("#e8c97a"), Color("#d98a6c"), Color("#8fb58a"), Color("#8fa6c9"), Color("#b79ac9"), Color("#d9b26c")]

var _table : PanelContainer
var _content : VBoxContainer
var _state : Dictionary = {}


func _init() -> void:
	super._init()
	mouse_filter = Control.MOUSE_FILTER_PASS
	_table = PanelContainer.new()
	var style := ClassTheme.flat(Color(0.97, 0.92, 0.82, 0.92), ClassTheme.GOLD, 16, 3, 12)
	_table.add_theme_stylebox_override("panel", style)
	add_child(_table)
	_content = VBoxContainer.new()
	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_theme_constant_override("separation", 12)
	_table.add_child(_content)
	resized.connect(func():
		_table.position = Vector2.ZERO
		_table.size = size
	)


func setup(q: Dictionary, answer_type: String) -> void:
	super.setup(q, answer_type)
	for c in _content.get_children():
		c.queue_free()
	_state = {"placed": 0, "total": 0, "mistakes": 0, "done": false}
	var v = q.get("visual", {})
	if typeof(v) != TYPE_DICTIONARY:
		return
	match str(v.get("type", "")):
		"shape_match":
			_build_shape_match(v)
		"block_stack":
			_build_block_stack(v)
		"connect_dots":
			_build_connect_dots(v)


func action_label() -> String:
	return "SOLVE IT!"


func success() -> void:
	ClassTheme.burst(self, size / 2.0, ClassTheme.GOLD_LIGHT, 34, 380.0, 0.0, 6.0)
	ClassTheme.pop(_table, 1.05)
	await get_tree().create_timer(0.7).timeout


func fail() -> void:
	ClassTheme.shake(_table)
	await get_tree().create_timer(0.5).timeout


func _finish() -> void:
	if _state["done"]:
		return
	_state["done"] = true
	solved.emit(int(_state["mistakes"]))


func _hint(text: String) -> Label:
	var l := ClassTheme.label(text, 15, ClassTheme.INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _flow(sep: int = 14) -> HFlowContainer:
	var f := HFlowContainer.new()
	f.alignment = FlowContainer.ALIGNMENT_CENTER
	f.add_theme_constant_override("h_separation", sep)
	f.add_theme_constant_override("v_separation", sep)
	return f


# ------------------------------------------------------------ shapes --

static func regular_polygon(sides: int, rotation_offset: float = 0.0) -> PackedVector2Array:
	var n := maxi(3, sides)
	var start := -PI / 2.0 + rotation_offset
	if n % 2 == 0:
		start += PI / n          # even polygons sit flat
	var raw : Array = []
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for i in range(n):
		var a := start + TAU * i / n
		var p := Vector2(cos(a), sin(a))
		raw.append(p)
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	var span := maxf(hi.x - lo.x, hi.y - lo.y)
	var off := (Vector2.ONE - (hi - lo) / span) / 2.0
	var pts := PackedVector2Array()
	for p in raw:
		pts.append((p - lo) / span + off)
	return pts


## Points (0..1 box) for {"sides":n} or {"points":[[x,y],..]}.
static func shape_points(d: Dictionary) -> PackedVector2Array:
	if d.has("points"):
		var pts := PackedVector2Array()
		for p in d["points"]:
			pts.append(Vector2(float(p[0]), float(p[1])))
		return pts
	return regular_polygon(int(d.get("sides", 3)), float(d.get("rotation", 0.0)))


func _build_shape_match(data: Dictionary) -> void:
	var defs : Array = data.get("shapes", [])
	if defs.is_empty():
		return
	var piece := 84.0
	_state["total"] = defs.size()
	_content.add_child(_hint("Drag each shape onto its matching outline."))
	var board := _flow(18)
	_content.add_child(board)
	var tray := _flow(18)
	for i in range(defs.size()):
		var d : Dictionary = defs[i]
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		board.add_child(col)
		var slot := ShapeSlot.new()
		slot.key = str(d.get("id", d.get("name", d.get("sides", i))))
		slot.points = shape_points(d)
		slot.fill = Color(0, 0, 0, 0.06)
		slot.outline = ClassTheme.BROWN
		slot.dashed = true
		slot.custom_minimum_size = Vector2(piece, piece)
		slot.dropped.connect(_on_shape_dropped)
		col.add_child(slot)
		if d.has("label"):
			var l := ClassTheme.label(str(d["label"]), 14, ClassTheme.INK)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			col.add_child(l)
	_content.add_child(_hint("Pieces"))
	_content.add_child(tray)
	var order : Array = range(defs.size())
	order.shuffle()
	for i in order:
		var d2 : Dictionary = defs[i]
		var p := ShapePiece.new()
		p.key = str(d2.get("id", d2.get("name", d2.get("sides", i))))
		p.points = shape_points(d2)
		p.fill = SHAPE_COLORS[i % SHAPE_COLORS.size()]
		p.custom_minimum_size = Vector2(piece, piece)
		tray.add_child(p)


func _on_shape_dropped(slot, data) -> void:
	if _state["done"] or typeof(data) != TYPE_DICTIONARY:
		return
	var piece = data.get("piece")
	if str(data.get("key", "")) == str(slot.key):
		slot.filled = true
		slot.dashed = false
		slot.fill = piece.fill
		slot.outline = ClassTheme.INK_DARK
		slot.queue_redraw()
		ClassTheme.pop(slot)
		if is_instance_valid(piece):
			piece.call_deferred("hide")
		_state["placed"] += 1
		if _state["placed"] >= _state["total"]:
			_finish()
	else:
		_state["mistakes"] += 1
		ClassTheme.flash(slot, Color(1.4, 0.7, 0.7))
		if is_instance_valid(piece):
			ClassTheme.shake(piece)


# -------------------------------------------------------------- blocks --

func _build_block_stack(data: Dictionary) -> void:
	var heights : Array = data.get("heights", [])
	if heights.size() < 2:
		return
	var descending := str(data.get("order", "asc")) == "desc"
	var show_values := bool(data.get("show_values", true))
	var target : Array = []
	var max_h := 1
	for h in heights:
		target.append(int(h))
		max_h = maxi(max_h, int(h))
	target.sort()
	if descending:
		target.reverse()
	var unit := clampf(size.y * 0.35 / max_h, 12.0, 26.0)
	var block_w := 48.0
	_state["total"] = heights.size()
	_content.add_child(_hint("Tallest on the left, shortest on the right." if descending else "Shortest on the left, tallest on the right."))

	var bays := HBoxContainer.new()
	bays.alignment = BoxContainer.ALIGNMENT_CENTER
	bays.add_theme_constant_override("separation", 8)
	_content.add_child(bays)
	for h in target:
		var bay := BlockBay.new()
		bay.expected = int(h)
		bay.unit_px = unit
		bay.show_value = show_values
		bay.custom_minimum_size = Vector2(block_w + 8.0, unit * max_h + 8.0)
		bay.dropped.connect(_on_block_dropped)
		bays.add_child(bay)

	var tray := HBoxContainer.new()
	tray.alignment = BoxContainer.ALIGNMENT_CENTER
	tray.add_theme_constant_override("separation", 10)
	_content.add_child(tray)
	var shuffled : Array = heights.duplicate()
	shuffled.shuffle()
	for h in shuffled:
		var blk := BlockPiece.new()
		blk.units = int(h)
		blk.unit_px = unit
		blk.show_value = show_values
		blk.color = SHAPE_COLORS[(int(h) - 1) % SHAPE_COLORS.size()]
		blk.custom_minimum_size = Vector2(block_w, unit * int(h))
		blk.size_flags_vertical = Control.SIZE_SHRINK_END
		tray.add_child(blk)


func _on_block_dropped(bay, data) -> void:
	if _state["done"] or typeof(data) != TYPE_DICTIONARY:
		return
	var piece = data.get("piece")
	if int(data.get("units", 0)) == bay.expected:
		bay.filled_units = bay.expected
		bay.filled_color = piece.color
		bay.queue_redraw()
		ClassTheme.pop(bay)
		if is_instance_valid(piece):
			piece.call_deferred("hide")
		_state["placed"] += 1
		if _state["placed"] >= _state["total"]:
			_finish()
	else:
		_state["mistakes"] += 1
		ClassTheme.flash(bay, Color(1.4, 0.7, 0.7))
		if is_instance_valid(piece):
			ClassTheme.shake(piece)


# ---------------------------------------------------------------- dots --

func _build_connect_dots(data: Dictionary) -> void:
	var raw : Array = data.get("dots", [])
	if raw.size() < 2:
		return
	_content.add_child(_hint("Tap the dots in order, from the first to the last."))
	var canvas := DotCanvas.new()
	for p in raw:
		canvas.dots.append(Vector2(float(p[0]), float(p[1])))
	var lbls = data.get("labels", [])
	if typeof(lbls) == TYPE_ARRAY:
		canvas.labels = lbls
	canvas.close_shape = bool(data.get("close", false))
	canvas.custom_minimum_size = Vector2(minf(size.x * 0.8, 320.0), minf(size.y * 0.6, 240.0))
	canvas.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	canvas.dot_tapped.connect(_on_dot_tapped.bind(canvas))
	_content.add_child(canvas)


func _on_dot_tapped(index: int, canvas) -> void:
	if _state["done"]:
		return
	if index == canvas.connected:
		canvas.connected += 1
		canvas.queue_redraw()
		if canvas.connected >= canvas.dots.size():
			canvas.complete = true
			canvas.queue_redraw()
			_finish()
	elif index > canvas.connected:
		_state["mistakes"] += 1
		ClassTheme.flash(canvas, Color(1.4, 0.7, 0.7))
