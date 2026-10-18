extends Node2D
class_name FestivalDecor

# =====================================================================
#  Festival dressing:
#    FestivalDecor        a round stage carpet with a golden star, flat on
#                         the ground (drawn under everything that stands)
#    FestivalDecor.Lantern  the street lamp (assets/img/event_street_lamp)
#                         with a flickering glow; stands on its base, so it
#                         is y-sorted like props
#    FestivalDecor.JackOLantern  a carved pumpkin with a candle inside
#                         (Halloween festivals), glowing after dark
# =====================================================================

const RADIUS := 30.0

var _time : float = 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var r := RADIUS
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))   # flat on the ground
	draw_circle(Vector2.ZERO, r + 3, Color(0.25, 0.12, 0.08, 0.45))
	draw_circle(Vector2.ZERO, r, Color("#8a1f1f"))
	draw_arc(Vector2.ZERO, r - 4, 0, TAU, 48, Color("#e8c97a"), 1.5)
	var star := PackedVector2Array()
	for i in range(10):
		var a := -PI / 2 + i * PI / 5 + _time * 0.3
		star.append(Vector2.from_angle(a) * (r * 0.62 if i % 2 == 0 else r * 0.26))
	draw_colored_polygon(star, Color("#e8c97a"))
	draw_set_transform(Vector2.ZERO)


class Lantern extends Node2D:
	const TEXTURE := preload("res://assets/img/event_street_lamp(200x268).png")
	const SCALE := 0.15
	## Bottom of the post in the image: stands on this node's origin
	const BASE := Vector2(99, 259)
	## The lantern's flame in the image (for the glow)
	const FLAME := Vector2(178, 60)
	var tint : Color = Color("#f5d76e")
	var _time : float = randf() * TAU

	var _light : PointLight2D

	func _ready() -> void:
		var sprite := Sprite2D.new()
		sprite.texture = TEXTURE
		sprite.centered = false
		sprite.offset = -BASE
		sprite.scale = Vector2(SCALE, SCALE)
		add_child(sprite)
		# Real light after dark (the night tint would dim a drawn glow)
		_light = GlowLight.make(tint, 34.0, 0.9)
		_light.position = (FLAME - BASE) * SCALE
		add_child(_light)

	func _process(delta: float) -> void:
		_time += delta
		_light.visible = GlowLight.is_night()
		_light.energy = 0.85 + 0.12 * sin(_time * 3.0)
		queue_redraw()

	## Shadow at the foot of the post and a soft flickering halo around the
	## lantern (drawn under the sprite).
	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, 5.0, Color(0, 0, 0, 0.3))
		draw_set_transform(Vector2.ZERO)
		var glow := 0.55 + 0.2 * sin(_time * 3.0)
		var at := (FLAME - BASE) * SCALE
		draw_circle(at, 8.0, Color(tint.r, tint.g, tint.b, 0.16 * glow))
		draw_circle(at, 4.5, Color(tint.r, tint.g, tint.b, 0.22 * glow))


class JackOLantern extends Node2D:
	var _time : float = randf() * TAU
	var _light : PointLight2D

	func _ready() -> void:
		_light = GlowLight.make(Color("#ff9a3c"), 22.0, 0.8)
		_light.position = Vector2(0, -5)
		add_child(_light)

	func _process(delta: float) -> void:
		_time += delta
		_light.visible = GlowLight.is_night()
		_light.energy = 0.7 + 0.2 * sin(_time * 8.0) + 0.1 * sin(_time * 13.0)
		queue_redraw()

	func _draw() -> void:
		draw_set_transform(Vector2(0, 0), 0.0, Vector2(1.0, 0.4))
		draw_circle(Vector2.ZERO, 7.0, Color(0, 0, 0, 0.3))
		draw_set_transform(Vector2.ZERO)
		var c := Vector2(0, -5)
		for k in [-1, 1, 0]:
			draw_set_transform(c + Vector2(k * 2.6, 0), 0.0, Vector2(0.62, 0.85))
			draw_circle(Vector2.ZERO, 6.0, Color("#c4621a") if k != 0 else Color("#f28c28"))
		draw_set_transform(Vector2.ZERO)
		draw_rect(Rect2(c.x - 0.8, c.y - 7, 1.6, 2.5), Color("#5a7a2a"))
		# Carved face, lit from inside
		var glow := Color(1.0, 0.85, 0.3, 0.8 + 0.2 * sin(_time * 9.0))
		draw_colored_polygon(PackedVector2Array([c + Vector2(-3.4, -1.2), c + Vector2(-1.4, -1.2), c + Vector2(-2.4, -3.0)]), glow)
		draw_colored_polygon(PackedVector2Array([c + Vector2(1.4, -1.2), c + Vector2(3.4, -1.2), c + Vector2(2.4, -3.0)]), glow)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-3.4, 1.0), c + Vector2(3.4, 1.0), c + Vector2(2.2, 2.8),
			c + Vector2(0.8, 2.0), c + Vector2(-0.8, 2.8), c + Vector2(-2.2, 2.0)]), glow)
