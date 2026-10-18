extends Station
class_name GardenStation

# =====================================================================
#  A vegetable patch planted in rows and columns (arrays):
#    {"type":"garden","rows":4,"cols":5,"crop":"carrot"}
#  Each row is a strip of soil with its number on the left, so rows can
#  be counted and the crops counted by rows (skip counting) or multiplied.
#  Crops: "carrot", "cabbage", "corn". Right = the rows bounce one by one.
# =====================================================================

const SOIL := Color("#6b4a2c")
const SOIL_DARK := Color("#4e3420")
const GRASS := Color("#4f7a3a")

var _rows : int = 1
var _cols : int = 1
var _crop : String = "carrot"
var _bounce : Array = []
var _time : float = 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func setup(q: Dictionary, answer_type: String) -> void:
	super.setup(q, answer_type)
	var v = q.get("visual", {})
	if typeof(v) == TYPE_DICTIONARY:
		_rows = clampi(int(v.get("rows", 1)), 1, 8)
		_cols = clampi(int(v.get("cols", 1)), 1, 10)
		_crop = str(v.get("crop", "carrot"))
	_bounce = []
	for i in range(_rows):
		_bounce.append(0.0)


func action_label() -> String:
	return "HARVEST!"


func cast_color() -> Color:
	return Color("#f29a3c")


func success() -> void:
	var tw := create_tween().set_parallel(true)
	for i in range(_rows):
		tw.tween_method(_set_bounce.bind(i), 0.0, 1.0, 0.15).set_delay(i * 0.1)
		tw.tween_method(_set_bounce.bind(i), 1.0, 0.0, 0.18).set_delay(i * 0.1 + 0.15)
	await get_tree().create_timer(0.35 + _rows * 0.1).timeout


func fail() -> void:
	await get_tree().create_timer(0.4).timeout


func _set_bounce(v: float, i: int) -> void:
	if i < _bounce.size():
		_bounce[i] = v


func _draw() -> void:
	if size.x < 40.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), GRASS)
	var f := font()
	var left := 40.0
	var area := Rect2(left, 14, size.x - left - 14, size.y - 28)
	var row_h := area.size.y / _rows
	var cell_w := area.size.x / _cols
	var s := minf(row_h * 0.62, cell_w * 0.7)
	for r in range(_rows):
		var y := area.position.y + row_h * r
		draw_rect(Rect2(area.position.x - 6, y + row_h * 0.18, area.size.x + 12, row_h * 0.64), SOIL)
		draw_rect(Rect2(area.position.x - 6, y + row_h * 0.74, area.size.x + 12, row_h * 0.08), SOIL_DARK)
		var label := str(r + 1)
		draw_string(f, Vector2(10, y + row_h * 0.62), label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(clampf(row_h * 0.38, 12, 20)), ClassTheme.GOLD_LIGHT)
		var lift : float = (_bounce[r] if r < _bounce.size() else 0.0) * row_h * 0.25
		for c in range(_cols):
			var base := Vector2(area.position.x + cell_w * (c + 0.5), y + row_h * 0.62 - lift + sin(_time * 2.0 + c + r) * 0.6)
			_draw_crop(base, s)


func _draw_crop(base: Vector2, s: float) -> void:
	match _crop:
		"cabbage":
			draw_circle(base + Vector2(0, -s * 0.3), s * 0.42, Color("#7fbf5a"))
			draw_circle(base + Vector2(0, -s * 0.32), s * 0.26, Color("#b3e08a"))
			draw_arc(base + Vector2(0, -s * 0.3), s * 0.42, PI * 1.1, PI * 1.9, 8, Color("#4f8a3a"), 1.5)
		"corn":
			draw_rect(Rect2(base.x - s * 0.04, base.y - s * 0.9, s * 0.08, s * 0.9), Color("#5c9a3a"))
			draw_colored_polygon(PackedVector2Array([base + Vector2(-s * 0.16, -s * 0.85), base + Vector2(s * 0.16, -s * 0.85),
				base + Vector2(s * 0.1, -s * 0.3), base + Vector2(-s * 0.1, -s * 0.3)]), Color("#f2cf4a"))
			draw_line(base + Vector2(0, -s * 0.5), base + Vector2(s * 0.3, -s * 0.75), Color("#7fbf5a"), 2.0)
			draw_line(base + Vector2(0, -s * 0.45), base + Vector2(-s * 0.3, -s * 0.7), Color("#7fbf5a"), 2.0)
		_:
			# Carrot: green leaves over an orange root poking out of the soil
			for k in [-1, 0, 1]:
				draw_line(base + Vector2(0, -s * 0.35), base + Vector2(k * s * 0.18, -s * 0.85), Color("#5cb85c"), 2.0)
			draw_colored_polygon(PackedVector2Array([base + Vector2(-s * 0.16, -s * 0.38), base + Vector2(s * 0.16, -s * 0.38),
				base + Vector2(0, s * 0.12)]), Color("#f29a3c"))
			draw_line(base + Vector2(-s * 0.08, -s * 0.22), base + Vector2(s * 0.04, -s * 0.22), Color("#c46f1e"), 1.0)
