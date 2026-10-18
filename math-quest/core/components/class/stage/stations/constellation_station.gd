extends Station
class_name ConstellationStation

# =====================================================================
#  A constellation in the night sky: stars numbered by skip counting,
#  joined by faint lines, one of them a "?" star:
#    {"type":"constellation","stars":["2","4","?","8","10"],"shape":7}
#  The typed number shines in the "?" star; right = the lines light up
#  one after another, wrong = the "?" star flickers.
# =====================================================================

const SKY_STAR := Color(1, 1, 1, 0.35)
const LINE_DIM := Color(0.75, 0.8, 1.0, 0.25)
const LINE_LIT := Color("#f5d76e")
const STAR := Color("#fff4c2")

var _stars : Array = []        # labels, "?" = the missing star
var _points : Array = []       # 0..1 positions inside the station
var _sky : Array = []          # faint background stars
var _value : String = ""
var _lit : float = 0.0         # how many lines are lit (animated)
var _flicker : float = 0.0
var _time : float = 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func setup(q: Dictionary, answer_type: String) -> void:
	super.setup(q, answer_type)
	var v = q.get("visual", {})
	_stars = []
	var shape := 0
	if typeof(v) == TYPE_DICTIONARY:
		for s in v.get("stars", []):
			_stars.append(str(s))
		shape = int(v.get("shape", 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = shape
	# A gently zig-zagging path from left to right
	_points = []
	var n := maxi(_stars.size(), 1)
	for i in range(n):
		var x := 0.12 + 0.76 * (i / maxf(n - 1, 1.0))
		var y := 0.5 + (0.22 if i % 2 == 0 else -0.18) * rng.randf_range(0.5, 1.0)
		_points.append(Vector2(x, y))
	_sky = []
	for i in range(40):
		_sky.append(Vector3(rng.randf(), rng.randf(), rng.randf_range(0.6, 1.6)))
	_value = ""
	_lit = 0.0
	_flicker = 0.0


func preview(value: String) -> void:
	_value = value


func action_label() -> String:
	return "SHINE!"


func cast_color() -> Color:
	return LINE_LIT


func success() -> void:
	var tw := create_tween()
	tw.tween_property(self, "_lit", float(_stars.size() - 1), 0.12 * _stars.size())
	await tw.finished
	ClassTheme.burst(self, _pos(_missing_index()), LINE_LIT, 24, 220.0, 0.0, 5.0)
	await get_tree().create_timer(0.35).timeout


func fail() -> void:
	var tw := create_tween()
	for a in [1.0, 0.0, 1.0, 0.0]:
		tw.tween_property(self, "_flicker", a, 0.08)
	await tw.finished


func _missing_index() -> int:
	return maxi(_stars.find("?"), 0)


func _pos(i: int) -> Vector2:
	if i < 0 or i >= _points.size():
		return size / 2.0
	return Vector2(_points[i].x * size.x, _points[i].y * size.y)


func _draw() -> void:
	if size.x < 40.0:
		return
	for s in _sky:
		var tw := 0.5 + 0.5 * sin(_time * s.z * 2.0 + s.x * 10.0)
		draw_circle(Vector2(s.x * size.x, s.y * size.y), s.z, Color(1, 1, 1, 0.15 + 0.3 * tw))
	# Lines (lit up to _lit)
	for i in range(_stars.size() - 1):
		var a := _pos(i)
		var b := _pos(i + 1)
		var on := clampf(_lit - i, 0.0, 1.0)
		draw_line(a, b, LINE_DIM, 2.0)
		if on > 0.0:
			draw_line(a, a.lerp(b, on), LINE_LIT, 3.0)
	# Stars with their numbers
	var f := font()
	var fs := int(clampf(size.y * 0.075, 14, 24))
	for i in range(_stars.size()):
		var p := _pos(i)
		var missing : bool = _stars[i] == "?"
		var label : String = _stars[i]
		if missing:
			label = _value if _value != "" else "?"
		var r := size.y * 0.045
		var glow := 0.6 + 0.4 * sin(_time * 3.0 + i)
		var col := STAR
		if missing and _value == "":
			col = Color(1, 1, 1, 0.35 + 0.35 * glow)
		if missing and _flicker > 0.5:
			col = Color("#ff8a7a")
		draw_circle(p, r * 2.0, Color(col.r, col.g, col.b, 0.12 * glow))
		_star(p, r, col)
		var tw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, p + Vector2(-tw / 2.0, r + fs + 2), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
			ClassTheme.GOLD_LIGHT if missing else ClassTheme.CHALK)


func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in range(10):
		var a := -PI / 2.0 + k * PI / 5.0
		pts.append(c + Vector2.from_angle(a) * (r if k % 2 == 0 else r * 0.45))
	draw_colored_polygon(pts, col)
