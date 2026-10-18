extends Station
class_name StarMapStation

# =====================================================================
#  Looking through a telescope at two constellations:
#    {"type":"star_map","maps":[{"name":"Big Dipper","count":7},
#                               {"name":"Orion","count":10}]}
#  Each constellation is a cluster of joined stars with its name, so the
#  player can count, add them up or compare them. Right = both shine.
# =====================================================================

const STAR := Color("#fff4c2")
const LINE := Color(0.75, 0.8, 1.0, 0.4)
const LENS_RIM := Color("#8a5a2b")
const TINTS := [Color("#9fd3ff"), Color("#ffd27a")]

var _maps : Array = []         # [{"name","count","points":[Vector2 0..1 inside its half]}]
var _sky : Array = []
var _shine : float = 0.0
var _value : String = ""
var _time : float = 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func setup(q: Dictionary, answer_type: String) -> void:
	super.setup(q, answer_type)
	_maps = []
	var v = q.get("visual", {})
	var shape_seed := 1
	if typeof(v) == TYPE_DICTIONARY:
		for m in v.get("maps", []):
			var count := clampi(int(m.get("count", 1)), 1, 20)
			shape_seed = shape_seed * 7 + count
			_maps.append({"name": str(m.get("name", "")), "count": count, "points": _shape(count, shape_seed)})
	var rng := RandomNumberGenerator.new()
	rng.seed = shape_seed
	_sky = []
	for i in range(30):
		_sky.append(Vector3(rng.randf(), rng.randf(), rng.randf_range(0.5, 1.3)))
	_shine = 0.0
	_value = ""


## A wandering chain of `count` stars inside a unit box (spaced apart).
func _shape(count: int, shape_seed: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = shape_seed
	var pts : Array = []
	var p := Vector2(rng.randf_range(0.15, 0.3), rng.randf_range(0.3, 0.7))
	for i in range(count):
		pts.append(p)
		for tries in range(20):
			var step := Vector2.from_angle(rng.randf_range(-1.2, 1.2) + (0.0 if i % 4 < 2 else PI * 0.5)) * rng.randf_range(0.12, 0.2)
			var next := (p + step).clamp(Vector2(0.08, 0.1), Vector2(0.92, 0.9))
			var ok := true
			for o in pts:
				if next.distance_to(o) < 0.11:
					ok = false
					break
			if ok:
				p = next
				break
	return pts


func preview(value: String) -> void:
	_value = value


func action_label() -> String:
	return "LOOK!"


func cast_color() -> Color:
	return STAR


func success() -> void:
	var tw := create_tween()
	tw.tween_property(self, "_shine", 1.0, 0.3)
	tw.tween_property(self, "_shine", 0.0, 0.5)
	await tw.finished


func fail() -> void:
	await get_tree().create_timer(0.4).timeout


func _lens() -> Dictionary:
	var r := minf(size.x * 0.48, size.y * 0.47)
	return {"c": size / 2.0, "r": r}


func _draw() -> void:
	if size.x < 40.0:
		return
	var lens := _lens()
	var c : Vector2 = lens["c"]
	var r : float = lens["r"]
	# Telescope lens: dark round sky with a wooden rim
	draw_circle(c, r + 8, LENS_RIM)
	draw_circle(c, r, Color("#0f1430"))
	for s in _sky:
		var p := c + (Vector2(s.x, s.y) - Vector2(0.5, 0.5)) * 2.0 * r * 0.95
		if p.distance_to(c) < r - 4:
			var tw := 0.5 + 0.5 * sin(_time * s.z * 2.0 + s.x * 8.0)
			draw_circle(p, s.z, Color(1, 1, 1, 0.12 + 0.25 * tw))
	# The constellations, side by side inside the lens
	var f := font()
	var fs := int(clampf(r * 0.1, 12, 18))
	var n := maxi(_maps.size(), 1)
	for i in range(_maps.size()):
		var m : Dictionary = _maps[i]
		var box := Rect2(c.x - r * 0.82 + (r * 1.64 / n) * i, c.y - r * 0.55, r * 1.64 / n, r * 1.0)
		var tint : Color = TINTS[i % TINTS.size()]
		var pts : Array = []
		for p in m["points"]:
			pts.append(box.position + Vector2(p.x * box.size.x, p.y * box.size.y))
		for k in range(pts.size() - 1):
			draw_line(pts[k], pts[k + 1], Color(tint.r, tint.g, tint.b, 0.35 + 0.5 * _shine), 1.5)
		var sr := clampf(r * 0.035, 3.0, 7.0)
		for k in range(pts.size()):
			var glow := 0.6 + 0.4 * sin(_time * 3.0 + k) + _shine
			draw_circle(pts[k], sr * 2.0, Color(tint.r, tint.g, tint.b, 0.12 * glow))
			_star(pts[k], sr * (1.0 + _shine * 0.4), STAR)
		var title := str(m["name"])
		var tw := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, Vector2(box.get_center().x - tw / 2.0, box.end.y + fs + 6), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tint)


func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in range(10):
		var a := -PI / 2.0 + k * PI / 5.0
		pts.append(c + Vector2.from_angle(a) * (r if k % 2 == 0 else r * 0.45))
	draw_colored_polygon(pts, col)
