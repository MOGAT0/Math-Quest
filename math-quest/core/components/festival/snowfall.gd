extends Node2D
class_name Snowfall

# =====================================================================
#  Festival ending ("ending": "snow_gift"): gentle snow falling over the
#  festival square, drawn around this node (the festival center). Flakes
#  drift down with a little sway and start again at the top. Stays until
#  the festival packs up.
# =====================================================================

const COUNT := 120
const AREA := Vector2(560, 360)

var _flakes : Array = []       # Vector4: x, y, size, speed
var _time : float = 0.0


func _ready() -> void:
	z_index = 30   # over the square and the people
	for i in range(COUNT):
		_flakes.append(Vector4(randf_range(-AREA.x, AREA.x) / 2.0, randf_range(-AREA.y, AREA.y) / 2.0,
			randf_range(0.8, 2.0), randf_range(14.0, 30.0)))


func _process(delta: float) -> void:
	_time += delta
	for i in range(_flakes.size()):
		var f : Vector4 = _flakes[i]
		f.y += f.w * delta
		if f.y > AREA.y / 2.0:
			f.y = -AREA.y / 2.0
			f.x = randf_range(-AREA.x, AREA.x) / 2.0
		_flakes[i] = f
	queue_redraw()


func _draw() -> void:
	for f in _flakes:
		var x : float = f.x + sin(_time * 1.2 + f.y * 0.05) * 4.0
		draw_circle(Vector2(x, f.y), f.z, Color(1, 1, 1, 0.85))
