extends Control
class_name DotCanvas

# Moved out of the old class.gd (vector drawn, no image assets).

signal dot_tapped(index: int)
var dots : PackedVector2Array = PackedVector2Array()
var labels : Array = []
var connected : int = 0
var complete : bool = false
var close_shape : bool = false
var dot_radius : float = 17.0
var line_color : Color = Color("#2f5233")

func label_for(i: int) -> String:
	if i < labels.size():
		return str(labels[i])
	return str(i + 1)

func _draw() -> void:
	var pts : Array = []
	for d in dots:
		pts.append(Vector2(d.x * size.x, d.y * size.y))
	if complete and close_shape and pts.size() >= 3:
		draw_colored_polygon(PackedVector2Array(pts), Color(0.18, 0.32, 0.2, 0.25))
	for i in range(1, mini(connected, pts.size())):
		draw_line(pts[i - 1], pts[i], line_color, 5.0, true)
	if complete and close_shape and pts.size() >= 2:
		draw_line(pts[pts.size() - 1], pts[0], line_color, 5.0, true)
	var font := ThemeDB.fallback_font
	var fs := 18
	for i in range(pts.size()):
		var done_dot := i < connected
		var is_next := i == connected
		var fill_c := Color("#f7ead0")
		if done_dot:
			fill_c = Color("#2f5233")
		elif is_next:
			fill_c = Color("#f0dfa0")
		var ring := Color("#a8781a") if is_next else Color("#3b2a1a")
		draw_circle(pts[i], dot_radius, fill_c)
		draw_arc(pts[i], dot_radius, 0.0, TAU, 32, ring, 3.0, true)
		var text := label_for(i)
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var tcol := Color("#f7ead0") if done_dot else Color("#241a10")
		draw_string(font, pts[i] + Vector2(-tw / 2.0, fs * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tcol)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var best := -1
		var best_d := dot_radius + 14.0
		for i in range(dots.size()):
			var p := Vector2(dots[i].x * size.x, dots[i].y * size.y)
			var d : float = event.position.distance_to(p)
			if d < best_d:
				best_d = d
				best = i
		if best != -1:
			dot_tapped.emit(best)
