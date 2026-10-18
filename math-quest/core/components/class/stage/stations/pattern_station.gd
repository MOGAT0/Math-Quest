extends Station
class_name PatternStation

# =====================================================================
#  A row of painted eggs that make a pattern, the last one a "?" egg:
#    colours  {"type":"pattern","kind":"color","pattern":["Red","Blue","Red","Blue","?"]}
#    numbers  {"type":"pattern","kind":"number","pattern":["2","4","6","8","?"]}
#  The typed / chosen answer paints the "?" egg; right = the eggs hop in a
#  wave, wrong = the "?" egg wobbles.
# =====================================================================

const COLORS := {
	"red": Color("#e2574c"), "blue": Color("#4a8fe0"), "yellow": Color("#f2cf4a"),
	"green": Color("#5cb85c"), "pink": Color("#f28fb5"), "purple": Color("#9b6ad6"),
	"orange": Color("#f29a3c"),
}
const PASTEL := Color("#f6e7c8")
const OUTLINE := Color("#5a3b22")

var _items : Array = []          # strings, "?" = the missing egg
var _kind : String = "color"
var _value : String = ""
var _hops : Array = []           # per egg, 0..1 hop height
var _wobble : float = 0.0:
	set(v):
		_wobble = v
		queue_redraw()


func setup(q: Dictionary, answer_type: String) -> void:
	super.setup(q, answer_type)
	var v = q.get("visual", {})
	_items = []
	_kind = "color"
	if typeof(v) == TYPE_DICTIONARY:
		for item in v.get("pattern", []):
			_items.append(str(item))
		_kind = str(v.get("kind", "color"))
	_value = ""
	_hops = []
	for i in range(_items.size()):
		_hops.append(0.0)
	_wobble = 0.0


func preview(value: String) -> void:
	_value = value
	queue_redraw()


func action_label() -> String:
	return "PAINT!"


func cast_color() -> Color:
	return Color("#f28fb5")


## The eggs hop one after another, like a wave.
func success() -> void:
	var tw := create_tween().set_parallel(true)
	for i in range(_hops.size()):
		tw.tween_method(_set_hop.bind(i), 0.0, 1.0, 0.18).set_delay(i * 0.07)
		tw.tween_method(_set_hop.bind(i), 1.0, 0.0, 0.18).set_delay(i * 0.07 + 0.18)
	ClassTheme.burst(self, _egg_center(_items.size() - 1), Color("#f28fb5"), 24, 260.0, 0.0, 5.0)
	await get_tree().create_timer(0.9).timeout


func fail() -> void:
	var tw := create_tween()
	for a in [1.0, -1.0, 0.6, -0.4, 0.0]:
		tw.tween_property(self, "_wobble", a, 0.07)
	await tw.finished


func _set_hop(v: float, index: int) -> void:
	if index < _hops.size():
		_hops[index] = v
		queue_redraw()


func _egg_size() -> Vector2:
	var n := maxi(_items.size(), 1)
	var w := minf(size.x * 0.8 / n, size.y * 0.32)
	return Vector2(w * 0.78, w)


func _egg_center(i: int) -> Vector2:
	var n := maxi(_items.size(), 1)
	var step := size.x * 0.86 / n
	return Vector2(size.x * 0.07 + step * (i + 0.5), size.y * 0.56)


func _draw() -> void:
	if size.x < 40.0 or _items.is_empty():
		return
	# Grass strip the eggs sit on
	draw_rect(Rect2(0, size.y * 0.56 + _egg_size().y * 0.42, size.x, size.y), Color("#4f7a3a"))
	var es := _egg_size()
	var fs := int(es.y * 0.34)
	for i in range(_items.size()):
		var item : String = _items[i]
		var missing := item == "?"
		var shown := _value if missing else item
		var c := _egg_center(i) + Vector2(0, -_hops[i] * es.y * 0.35)
		var rot := _wobble * 0.25 if missing else 0.0
		# Shadow
		draw_set_transform(_egg_center(i) + Vector2(0, es.y * 0.48), 0.0, Vector2(1.0, 0.3))
		draw_circle(Vector2.ZERO, es.x * 0.45, Color(0, 0, 0, 0.25))
		draw_set_transform(c, rot)
		var fill := PASTEL
		if _kind == "color":
			fill = COLORS.get(shown.to_lower(), PASTEL if missing else Color.GRAY)
		var poly := _egg_polygon(es)
		if missing and shown == "":
			draw_colored_polygon(poly, Color(1, 1, 1, 0.15))
			_dashed(poly, ClassTheme.GOLD_LIGHT)
		else:
			draw_colored_polygon(poly, fill)
			# Painted zig-zag band
			var band := PackedVector2Array()
			for k in range(9):
				var x := -es.x * 0.48 + es.x * 0.96 * k / 8.0
				band.append(Vector2(x, es.y * (0.02 if k % 2 == 0 else 0.1)))
			draw_polyline(band, Color(1, 1, 1, 0.75), maxf(1.5, es.x * 0.05))
			draw_polyline(poly + PackedVector2Array([poly[0]]), OUTLINE, 2.0)
		var text := shown if (_kind == "number" or (missing and shown == "")) else ""
		if missing and shown == "":
			text = "?"
		if text != "":
			var f := font()
			var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(f, Vector2(-tw / 2.0, fs * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
				ClassTheme.GOLD_LIGHT if missing and _value == "" else ClassTheme.INK_DARK)
		draw_set_transform(Vector2.ZERO)


## Egg outline: rounder at the bottom, narrower at the top.
func _egg_polygon(es: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in range(28):
		var a := TAU * k / 28.0
		var x := cos(a) * es.x / 2.0
		var y := sin(a) * es.y / 2.0
		if y < 0.0:
			x *= 1.0 + y / es.y * 0.45    # taper the top
		pts.append(Vector2(x, y))
	return pts


func _dashed(poly: PackedVector2Array, color: Color) -> void:
	for k in range(0, poly.size(), 2):
		draw_line(poly[k], poly[(k + 1) % poly.size()], color, 2.0)
