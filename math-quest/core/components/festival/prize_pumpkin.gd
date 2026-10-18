extends Node2D
class_name PrizePumpkin

# =====================================================================
#  Festival ending ("ending": "pumpkin"): a giant prize pumpkin with a
#  blue rosette ribbon pops up on the stage and wobbles proudly. Stands
#  on its base (origin), so it is y-sorted like the people around it.
#  FestivalDirector keeps it until the festival packs up.
# =====================================================================

const ORANGE := Color("#f28c28")
const ORANGE_DARK := Color("#c4621a")
const STEM := Color("#5a7a2a")
const RIBBON := Color("#3a6fd8")
const RIBBON_DARK := Color("#2a4fa0")
const R := 11.0                 # pumpkin half-width (world pixels)

var _time : float = 0.0


func _ready() -> void:
	scale = Vector2(0.1, 0.1)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	# Shadow
	draw_set_transform(Vector2(0, 0), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, R * 1.1, Color(0, 0, 0, 0.3))
	var wobble := sin(_time * 2.2) * 0.04
	var c := Vector2(0, -R * 0.85)
	draw_set_transform(Vector2.ZERO, wobble)
	# Ribbed body: overlapping ovals, darker ones at the sides
	for k in [-2, 2, -1, 1, 0]:
		var col := ORANGE_DARK if absi(k) == 2 else ORANGE
		var off := Vector2(k * R * 0.32, 0)
		draw_set_transform(c + off.rotated(wobble), wobble, Vector2(0.62, 0.85))
		draw_circle(Vector2.ZERO, R, col)
	draw_set_transform(Vector2.ZERO, wobble)
	# Highlights between the ribs
	for k in [-1, 1]:
		draw_line(c + Vector2(k * R * 0.5, -R * 0.55), c + Vector2(k * R * 0.55, R * 0.55), Color(1, 0.8, 0.5, 0.35), 1.2)
	# Stem and a curly vine
	draw_rect(Rect2(c.x - 1.5, c.y - R * 0.95, 3, 5), STEM)
	draw_arc(c + Vector2(4, -R * 0.85), 2.5, PI, TAU * 0.9, 8, STEM, 1.2)
	# Blue rosette ribbon on the front with two tails
	var ro := c + Vector2(R * 0.45, R * 0.05)
	draw_colored_polygon(PackedVector2Array([ro + Vector2(-2, 2), ro + Vector2(-5, 11), ro + Vector2(-1, 9)]), RIBBON_DARK)
	draw_colored_polygon(PackedVector2Array([ro + Vector2(2, 2), ro + Vector2(5, 11), ro + Vector2(1, 9)]), RIBBON_DARK)
	for k in range(8):
		draw_circle(ro + Vector2.from_angle(TAU * k / 8.0 + _time) * 3.2, 2.0, RIBBON)
	draw_circle(ro, 2.6, Color("#f2cf4a"))
	draw_set_transform(Vector2.ZERO)
