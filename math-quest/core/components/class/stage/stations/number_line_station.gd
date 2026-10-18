extends Station
class_name NumberLineStation

# =====================================================================
#  A bunny on a number line:
#    {"type":"number_line","start":3,"step":5,"hops":4,"max":25}
#  The bunny sits on `start`; the typed answer plants a flag on the line.
#  Right = the bunny hops step by step (one arc per hop) onto the flag,
#  wrong = the flag wobbles. Hops are not drawn before the answer, so the
#  line doesn't give it away.
#  "rider": "penguin" swaps the bunny for a penguin skating on ice; a
#  negative "step" jumps backwards (to the left).
# =====================================================================

const LINE := Color("#eef2e6")
const BUNNY := Color("#f4efe6")
const FLAG := Color("#e2574c")

var _start : int = 0
var _step : int = 1
var _hops : int = 1
var _max : int = 10
var _penguin : bool = false
var _value : String = ""
var _bunny_t : float = 0.0      # hops done so far, 0.._hops (fractional while jumping)
var _wobble : float = 0.0
var _time : float = 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func setup(q: Dictionary, answer_type: String) -> void:
	super.setup(q, answer_type)
	var v = q.get("visual", {})
	if typeof(v) == TYPE_DICTIONARY:
		_start = int(v.get("start", 0))
		_step = int(v.get("step", 1))
		_hops = int(v.get("hops", 1))
		_max = int(v.get("max", _start + _step * _hops + _step))
		_max = maxi(_max, _start)
		_penguin = str(v.get("rider", "")) == "penguin"
	_value = ""
	_bunny_t = 0.0
	_wobble = 0.0


func preview(value: String) -> void:
	_value = value


func action_label() -> String:
	return "HOP!"


func cast_color() -> Color:
	return Color("#f2cf4a")


func success() -> void:
	var tw := create_tween()
	for i in range(_hops):
		tw.tween_property(self, "_bunny_t", float(i + 1), 0.32).set_trans(Tween.TRANS_SINE)
	await tw.finished
	ClassTheme.burst(self, _point(_start + _step * _hops) + Vector2(0, -20), Color("#f2cf4a"), 24, 240.0, 0.0, 5.0)
	await get_tree().create_timer(0.4).timeout


func fail() -> void:
	var tw := create_tween()
	for a in [1.0, -1.0, 0.6, -0.4, 0.0]:
		tw.tween_property(self, "_wobble", a, 0.07)
	await tw.finished


func _line_y() -> float:
	return size.y * 0.66


## Screen x for a number on the line (0.._max across the station).
func _point(n: float) -> Vector2:
	var left := size.x * 0.06
	var right := size.x * 0.94
	return Vector2(left + (right - left) * n / maxf(_max, 1.0), _line_y())


func _draw() -> void:
	if size.x < 40.0:
		return
	var f := font()
	var y := _line_y()
	draw_rect(Rect2(0, y + 26, size.x, size.y), Color("#bfe3f2") if _penguin else Color("#4f7a3a"))
	if _penguin:
		for k in range(6):
			var sx := size.x * (0.1 + 0.17 * k)
			draw_line(Vector2(sx, y + 40), Vector2(sx + 30, y + 46), Color(1, 1, 1, 0.6), 1.5)
	draw_line(_point(0) - Vector2(8, 0), _point(_max) + Vector2(8, 0), LINE, 3.0)
	# Ticks: every number on short lines, labels so they never crowd
	var label_every := 50
	for s in [1, 2, 5, 10, 20, 50]:
		if _max / s <= 12:
			label_every = s
			break
	for n in range(0, _max + 1):
		var p := _point(n)
		var big := n % label_every == 0
		draw_line(p + Vector2(0, -6 if big else -3), p + Vector2(0, 6 if big else 3), LINE, 2.0)
		if big:
			var t := str(n)
			var tw := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			draw_string(f, p + Vector2(-tw / 2.0, 24), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, LINE)
	# Hop arcs already made
	var done := int(floor(_bunny_t))
	for i in range(done):
		_arc(_start + _step * i, _start + _step * (i + 1), Color(0.95, 0.81, 0.29, 0.85))
	# The flag at the typed answer
	if _value.is_valid_int():
		var n := clampi(_value.to_int(), 0, _max)
		var base := _point(n)
		draw_set_transform(base, _wobble * 0.3)
		draw_line(Vector2.ZERO, Vector2(0, -34), Color("#5a3b22"), 2.0)
		draw_colored_polygon(PackedVector2Array([Vector2(0, -34), Vector2(16, -28), Vector2(0, -22)]), FLAG)
		draw_set_transform(Vector2.ZERO)
	# The bunny (mid-jump follows a parabola)
	var frac := _bunny_t - done
	var from := _point(_start + _step * done)
	var to := _point(_start + _step * mini(done + 1, _hops))
	var pos := from.lerp(to, frac) + Vector2(0, -sin(frac * PI) * 40.0)
	if _penguin:
		_draw_penguin(pos + Vector2(0, -4 + sin(_time * 3.0) * (1.0 if frac == 0.0 else 0.0)))
	else:
		_bunny(pos + Vector2(0, -4 + sin(_time * 3.0) * (1.0 if frac == 0.0 else 0.0)))
	# Start label
	var st := "start %d" % _start
	draw_string(f, _point(_start) + Vector2(-20, -62), st, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ClassTheme.GOLD_LIGHT)


func _arc(a: float, b: float, color: Color) -> void:
	var pa := _point(a)
	var pb := _point(b)
	var pts := PackedVector2Array()
	for k in range(13):
		var t := k / 12.0
		pts.append(pa.lerp(pb, t) + Vector2(0, -sin(t * PI) * 40.0))
	draw_polyline(pts, color, 2.5)
	var mid := pa.lerp(pb, 0.5) + Vector2(0, -46)
	var t := ("+%d" if _step >= 0 else "%d") % _step
	draw_string(font(), mid + Vector2(-10, 0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)


func _bunny(p: Vector2) -> void:
	# Ears, head, body, tail
	draw_set_transform(p + Vector2(-3, -24), -0.15)
	draw_rect(Rect2(-2, -10, 4, 12), BUNNY)
	draw_rect(Rect2(-1, -8, 2, 8), Color("#f2a7c0"))
	draw_set_transform(p + Vector2(4, -24), 0.15)
	draw_rect(Rect2(-2, -10, 4, 12), BUNNY)
	draw_rect(Rect2(-1, -8, 2, 8), Color("#f2a7c0"))
	draw_set_transform(Vector2.ZERO)
	draw_circle(p + Vector2(0, -8), 9.0, BUNNY)
	draw_circle(p + Vector2(1, -19), 7.0, BUNNY)
	draw_circle(p + Vector2(-8, -6), 3.0, Color.WHITE)
	draw_circle(p + Vector2(3, -20), 1.3, ClassTheme.INK_DARK)
	draw_circle(p + Vector2(7, -18), 1.0, Color("#f2a7c0"))


func _draw_penguin(p: Vector2) -> void:
	var dir := -1.0 if _step < 0 else 1.0
	draw_set_transform(p + Vector2(0, -12), 0.0, Vector2(0.8, 1.0))
	draw_circle(Vector2.ZERO, 11.0, Color("#23233a"))
	draw_set_transform(p + Vector2(dir * 1.5, -10), 0.0, Vector2(0.6, 0.85))
	draw_circle(Vector2.ZERO, 8.0, Color("#f4f4f4"))
	draw_set_transform(Vector2.ZERO)
	draw_circle(p + Vector2(0, -23), 7.0, Color("#23233a"))
	draw_circle(p + Vector2(dir * 2.5, -24), 1.6, Color.WHITE)
	draw_circle(p + Vector2(dir * 2.9, -24), 0.8, Color.BLACK)
	draw_colored_polygon(PackedVector2Array([p + Vector2(dir * 5, -23), p + Vector2(dir * 10, -21.5), p + Vector2(dir * 5, -20.5)]), Color("#f2a33c"))
	draw_rect(Rect2(p.x - 6, p.y - 2, 5, 2.5), Color("#f2a33c"))
	draw_rect(Rect2(p.x + 1, p.y - 2, 5, 2.5), Color("#f2a33c"))
	# Red winter scarf
	draw_rect(Rect2(p.x - 6, p.y - 18, 12, 3), Color("#d64545"))
