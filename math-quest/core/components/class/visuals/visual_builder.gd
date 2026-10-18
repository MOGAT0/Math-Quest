extends RefCounted
class_name VisualBuilder

# =====================================================================
#  Builds the "visual" blocks from curriculum.json for the lecture slate:
#     grid      {"items":[{"icon":"⭐","count":3}]}     tap charms to count
#     groups    equal bundles  {"groups":{"icon":"🍎","count":3,"itemsPerGroup":4}}
#               or one size per bundle (numbers, or objects with their own
#               icon / label):
#                 {"groups":{"icon":"🪙","bundles":[3, 10, 5]}}
#                 {"groups":{"icon":"🪙","bundles":[3, {"count":4,"icon":"💎","label":"Arith's bag"}]}}
#               "show_counts": true writes each bundle's size under it
#     sequence  {"sequence":["(5 + 3)","x","4","= ?"]}
#     balance   {"leftItems":{..},"rightItems":{..}}   (the scale station)
#     shapes    {"shapes":[{"sides":3},...]}            tap sides to count
#     fraction  {"bars":[{"parts":4,"filled":3}]}
#     clock     {"clocks":[{"hour":12,"minute":20}]}
#  speak(text) is called when the player counts something out loud.
# =====================================================================

var speak : Callable
var number_word : Callable
var icon_scale : float = 1.0
## Optional: called with the running count when charms are tapped (grid).
var on_count : Callable


func _init(speak_fn: Callable = Callable(), number_word_fn: Callable = Callable()) -> void:
	speak = speak_fn
	number_word = number_word_fn


func _say_count(n: int) -> void:
	if speak.is_valid():
		speak.call(number_word.call(n) if number_word.is_valid() else str(n))


## True once a tappable picture has been fully counted: every countable
## charm / bundle toggled on and every tappable shape's sides counted.
## Pictures with nothing to tap count as done straight away.
static func is_done(root: Node) -> bool:
	for b in root.find_children("*", "Button", true, false):
		if b.toggle_mode and not b.disabled and not b.button_pressed:
			return false
	for p in root.find_children("*", "PolyView", true, false):
		if p.interactive and not p.is_complete():
			return false
	return true


func build(v: Dictionary, available: Vector2) -> Control:
	match str(v.get("type", "")):
		"grid":
			return _grid(v.get("items", []))
		"groups":
			return _groups(v.get("groups", {}))
		"sequence":
			return _sequence(v.get("sequence", []))
		"balance":
			return _station(ScaleStation.new(), v, available)
		"clock":
			return _station(ClockStation.new(), v, available)
		"shapes":
			return _shapes(v.get("shapes", []), bool(v.get("interactive", false)))
		"fraction":
			return _fractions(v.get("bars", []))
	return null


func _flow(sep: int = 10) -> HFlowContainer:
	var f := HFlowContainer.new()
	f.alignment = FlowContainer.ALIGNMENT_CENTER
	f.add_theme_constant_override("h_separation", sep)
	f.add_theme_constant_override("v_separation", sep)
	return f


func _chip(text: String, font_size: int = 24, min_size: float = 50.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_size, min_size) * icon_scale
	ClassTheme.style_button(b, ClassTheme.PARCHMENT, ClassTheme.SAND_DARK, ClassTheme.INK, roundi(font_size * icon_scale))
	return b


func _grid(items: Array) -> Control:
	var flow := _flow()
	var counted := {"n": 0}
	for item in items:
		var icon := str(item.get("icon", "?"))
		var countable : bool = icon.strip_edges() != "" and bool(item.get("countable", true))
		for i in range(int(item.get("count", 0))):
			var chip := _chip(icon)
			if not countable:
				chip.disabled = true
				chip.modulate.a = 0.5
			else:
				chip.toggle_mode = true
				chip.toggled.connect(func(on: bool):
					counted["n"] += 1 if on else -1
					if on_count.is_valid():
						on_count.call(counted["n"])
					ClassTheme.style_button(chip, ClassTheme.GREEN_LIGHT if on else ClassTheme.PARCHMENT, ClassTheme.GREEN if on else ClassTheme.SAND_DARK, ClassTheme.INK, roundi(24 * icon_scale))
					ClassTheme.pop(chip)
					if on:
						_say_count(counted["n"])
				)
			flow.add_child(chip)
	return flow


## Bundles of a "groups" visual as [{"count", "icon", "label"}], from
## either "bundles" (one size each) or "count" x "itemsPerGroup".
static func read_bundles(g: Dictionary) -> Array:
	var icon := str(g.get("icon", "?"))
	var out : Array = []
	var list = g.get("bundles", null)
	if typeof(list) == TYPE_ARRAY:
		for b in list:
			if typeof(b) == TYPE_DICTIONARY:
				out.append({"count": int(b.get("count", 0)), "icon": str(b.get("icon", icon)), "label": str(b.get("label", ""))})
			else:
				out.append({"count": int(b), "icon": icon, "label": ""})
	else:
		for i in range(int(g.get("count", 0))):
			out.append({"count": int(g.get("itemsPerGroup", 0)), "icon": icon, "label": ""})
	return out


## True when every bundle holds the same amount (a multiplication picture).
static func bundles_equal(bundles: Array) -> bool:
	for b in bundles:
		if b["count"] != bundles[0]["count"]:
			return false
	return true


func _groups(g: Dictionary) -> Control:
	var show_counts := bool(g.get("show_counts", false))
	var flow := _flow(14)
	var counted := {"n": 0}
	for b in read_bundles(g):
		var per : int = b["count"]
		var icon : String = b["icon"]
		var bundle := Button.new()
		bundle.toggle_mode = true
		ClassTheme.style_button(bundle, ClassTheme.PARCHMENT, ClassTheme.SAND_DARK, ClassTheme.INK, 18)
		var grid := GridContainer.new()
		# At most 5 per row: 10 -> 5x2, 20 -> 5x4, so big bundles stay compact
		grid.columns = clampi(per if per <= 5 else int(ceil(per / 2.0)), 1, 5)
		grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.position = Vector2(8, 8)
		for k in range(per):
			var l := ClassTheme.label(icon, roundi(18 * icon_scale))
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			grid.add_child(l)
		bundle.add_child(grid)
		grid.resized.connect(func(): bundle.custom_minimum_size = grid.size + Vector2(16, 16))
		# Each bundle adds its own size to the running total
		bundle.toggled.connect(func(on: bool):
			counted["n"] += per if on else -per
			ClassTheme.style_button(bundle, ClassTheme.GREEN_LIGHT if on else ClassTheme.PARCHMENT, ClassTheme.GREEN if on else ClassTheme.SAND_DARK, ClassTheme.INK, 18)
			ClassTheme.flash(bundle)
			if on_count.is_valid():
				on_count.call(counted["n"])
			if on:
				_say_count(counted["n"])
		)
		var caption := str(b["label"])
		if show_counts:
			caption = ("%s: %d" % [caption, per]) if caption != "" else str(per)
		if caption == "":
			flow.add_child(bundle)
			continue
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_child(bundle)
		var cap := ClassTheme.label(caption, 14, ClassTheme.INK)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(cap)
		flow.add_child(col)
	return flow


func _sequence(seq: Array) -> Control:
	var operators := ["+", "-", "x", "×", "÷", "=", "->", "vs", ":"]
	var flow := _flow()
	for token in seq:
		var text := str(token)
		var is_op := text in operators
		var mystery := text.contains("?") or text == "..."
		var chip := _chip(text, 18 if is_op else 22, 46.0)
		var bg := ClassTheme.SAND if is_op else ClassTheme.GOLD_LIGHT
		ClassTheme.style_button(chip, bg, ClassTheme.GOLD if mystery else ClassTheme.SAND_DARK, ClassTheme.INK, roundi((18 if is_op else 22) * icon_scale))
		chip.pressed.connect(func(): ClassTheme.flash(chip))
		flow.add_child(chip)
		if mystery:
			ClassTheme.pulse(chip)
	return flow


## Balance / clock visuals reuse the stage stations at a smaller size.
func _station(st: Station, v: Dictionary, available: Vector2) -> Control:
	var holder := Control.new()
	var w := clampf(available.x, 200.0, 420.0)
	holder.custom_minimum_size = Vector2(w, clampf(available.y * 0.65, 160.0, 280.0))
	holder.add_child(st)
	st.size = holder.custom_minimum_size
	st.setup({"visual": v}, "choice")
	holder.resized.connect(func(): st.size = holder.size)
	return holder


func _shapes(defs: Array, interactive: bool) -> Control:
	var flow := _flow(20)
	var hint := ClassTheme.label("Tap the glowing side!", 16, ClassTheme.GOLD)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for i in range(defs.size()):
		var d : Dictionary = defs[i]
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		flow.add_child(col)
		var view := PolyView.new()
		view.points = PuzzleStation.shape_points(d)
		view.fill = PuzzleStation.SHAPE_COLORS[i % PuzzleStation.SHAPE_COLORS.size()]
		# Tappable shapes are bigger (small fingers) and get room for the guide arrow
		view.custom_minimum_size = Vector2(150, 150) * icon_scale if interactive else Vector2(90, 90) * icon_scale
		view.interactive = interactive
		view.mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
		if interactive:
			view.side_counted.connect(func(n: int):
				_say_count(n)
				ClassTheme.pop(view)
				if view.is_complete():
					hint.text = "%d sides!" % n
					hint.add_theme_color_override("font_color", ClassTheme.GREEN)
					ClassTheme.pop(hint, 1.3)
			)
		col.add_child(view)
		if d.has("label"):
			var l := ClassTheme.label(str(d["label"]), 15, ClassTheme.INK)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			col.add_child(l)
	if interactive:
		var wrap := VBoxContainer.new()
		wrap.alignment = BoxContainer.ALIGNMENT_CENTER
		wrap.add_theme_constant_override("separation", 34)   # room for the count bubbles
		flow.add_theme_constant_override("h_separation", 60)
		wrap.add_child(flow)
		wrap.add_child(hint)
		return wrap
	return flow


func _fractions(bars: Array) -> Control:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 12)
	for b in bars:
		var bar := FractionBar.new()
		bar.parts = maxi(1, int(b.get("parts", 2)))
		bar.filled = int(b.get("filled", 1))
		bar.custom_minimum_size = Vector2(240, 42) * icon_scale
		bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(bar)
	return col
