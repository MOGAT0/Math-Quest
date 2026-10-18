extends Control
class_name PolyView

# Moved out of the old class.gd (vector drawn, no image assets).

signal side_counted(count: int)
var points : PackedVector2Array = PackedVector2Array()
var fill : Color = Color(1, 1, 1, 1)
var outline : Color = Color("#3b2a1a")
var counted_color : Color = Color("#2f5233")
var text_color : Color = Color("#3b2a1a")
var line_w : float = 3.0
var dashed : bool = false
var interactive : bool = false
var counted : Array = []
var counted_n : int = 0
var _order : Array = []       # count number shown beside each tapped side
var _t : float = 0.0

## Interactive shapes guide the tap: the next side to count glows gold and
## pulses, with a ripple and an arrow pointing at it from outside.
const GUIDE := Color("#c9962b")
const GUIDE_LIGHT := Color("#f0dfa0")

func _process(delta: float) -> void:
	if interactive and not is_complete():
		_t += delta
		queue_redraw()

func is_complete() -> bool:
	return points.size() >= 3 and counted_n >= points.size()

func _font() -> Font:
	return get_theme_default_font()

## Points in pixels. Scaled evenly and centred, so a shape stays true
## even when its column (e.g. a long label) makes the control wider.
func _px() -> PackedVector2Array:
	var s := minf(size.x, size.y)
	var off := (size - Vector2(s, s)) / 2.0
	var out := PackedVector2Array()
	for p in points:
		out.append(off + p * s)
	return out

func _draw() -> void:
	var pts := _px()
	if pts.size() < 3:
		return
	if fill.a > 0.0:
		var f := fill
		if interactive and is_complete():
			f = fill.lerp(Color("#8fb58a"), 0.6)
		draw_colored_polygon(pts, f)
	for i in range(pts.size()):
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		var is_counted : bool = i < counted.size() and counted[i]
		var col := counted_color if is_counted else outline
		var w := line_w + (3.0 if is_counted else 0.0)
		if dashed and not is_counted:
			draw_dashed_line(a, b, col, w, 8.0)
		else:
			draw_line(a, b, col, w, true)
	if interactive:
		_draw_guide(pts)
	if counted_n > 0:
		var font := _font()
		var fs := int(size.y * 0.34)
		var label := str(counted_n)
		var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2((size.x - tw) / 2.0, size.y / 2.0 + fs * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)

func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pts := _px()
		if pts.size() < 3:
			return
		var best := -1
		var best_d := 28.0
		for i in range(pts.size()):
			var a := pts[i]
			var b := pts[(i + 1) % pts.size()]
			var d : float = event.position.distance_to(Geometry2D.get_closest_point_to_segment(event.position, a, b))
			if d < best_d:
				best_d = d
				best = i
		if best == -1:
			return
		while counted.size() < pts.size():
			counted.append(false)
		if counted[best]:
			return
		counted[best] = true
		counted_n += 1
		while _order.size() < pts.size():
			_order.append(0)
		_order[best] = counted_n
		queue_redraw()
		side_counted.emit(counted_n)


func _outward(a: Vector2, b: Vector2, pts: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for p in pts:
		c += p
	c /= pts.size()
	var m := (a + b) / 2.0
	var n := (m - c).normalized()
	return n if n != Vector2.ZERO else Vector2.UP


func _draw_guide(pts: PackedVector2Array) -> void:
	var font := _font()
	# Count numbers next to the sides already tapped
	for i in range(pts.size()):
		if i < _order.size() and _order[i] > 0:
			var a := pts[i]
			var b := pts[(i + 1) % pts.size()]
			var p := (a + b) / 2.0 + _outward(a, b, pts) * 16.0
			var label := str(_order[i])
			var fs := 16
			draw_circle(p, 11.0, counted_color)
			var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(font, p + Vector2(-tw / 2.0, fs * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	if is_complete():
		return
	# The next side to tap: first one not counted yet
	var next := -1
	for i in range(pts.size()):
		if not (i < counted.size() and counted[i]):
			next = i
			break
	if next == -1:
		return
	var a := pts[next]
	var b := pts[(next + 1) % pts.size()]
	var m := (a + b) / 2.0
	var n := _outward(a, b, pts)
	var pulse := 0.5 + 0.5 * sin(_t * 6.0)
	var glow := GUIDE_LIGHT
	glow.a = 0.35 + 0.4 * pulse
	draw_line(a, b, glow, line_w + 10.0, true)
	draw_line(a, b, GUIDE, line_w + 2.0, true)
	# Ripple ring on the middle of the side
	var ripple := fmod(_t, 1.0)
	var ring := GUIDE
	ring.a = 1.0 - ripple
	draw_arc(m, 8.0 + ripple * 14.0, 0.0, TAU, 24, ring, 2.5, true)
	# Arrow outside the shape pointing at the side, bobbing gently
	var tip := m + n * (12.0 + 4.0 * pulse)
	var base := tip + n * 18.0
	var side := Vector2(-n.y, n.x) * 9.0
	draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]), GUIDE)
	draw_line(base, base + n * 10.0, GUIDE, 4.0, true)

