extends Area2D
class_name EventPickup

# =====================================================================
#  A glowing, bobbing pickup for "collect" events (star fragments, mana
#  crystals...). Walking over it collects it. Vector drawn, no assets.
# =====================================================================

signal collected

var glow_color : Color = Color("#f5d76e")
## The player body (set by EventDirector). Any CharacterBody2D if unset.
var player_body : Node2D = null
var _time : float = 0.0
var _taken : bool = false


func _ready() -> void:
	_time = randf() * TAU
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 9.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var y := sin(_time * 3.0) * 2.0 - 6.0
	var c := Vector2(0, y)
	var halo := glow_color
	halo.a = 0.25 + 0.15 * sin(_time * 5.0)
	draw_circle(c, 7.0, halo)
	# Four-pointed sparkle
	var r := 5.0
	var star := PackedVector2Array([
		c + Vector2(0, -r), c + Vector2(1.4, -1.4), c + Vector2(r, 0), c + Vector2(1.4, 1.4),
		c + Vector2(0, r), c + Vector2(-1.4, 1.4), c + Vector2(-r, 0), c + Vector2(-1.4, -1.4)])
	draw_colored_polygon(star, glow_color)
	draw_circle(c, 1.5, Color.WHITE)
	# Little shadow so it reads as lying on the ground
	draw_circle(Vector2(0, 1), 3.0, Color(0, 0, 0, 0.25))


func _is_player(body: Node2D) -> bool:
	return body == player_body if player_body else body is CharacterBody2D


func _on_body_entered(body: Node2D) -> void:
	if _taken or not _is_player(body):
		return
	_taken = true
	collected.emit()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector2(1.8, 1.8), 0.25)
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.chain().tween_callback(queue_free)
