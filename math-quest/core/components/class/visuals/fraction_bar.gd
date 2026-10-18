extends Control
class_name FractionBar

# Moved out of the old class.gd (vector drawn, no image assets).

var parts : int = 2
var filled : int = 1

func _draw() -> void:
	var gap := 3.0
	var cw := (size.x - gap * (parts - 1)) / parts
	for i in range(parts):
		var r := Rect2(Vector2(i * (cw + gap), 0.0), Vector2(cw, size.y))
		var col := Color("#c9962b") if i < filled else Color("#f7ead0")
		draw_rect(r, col, true)
		draw_rect(r, Color("#3b2a1a"), false, 2.0)
