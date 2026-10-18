extends Control
class_name BlockBay

# Moved out of the old class.gd (vector drawn, no image assets).

signal dropped(bay, data)
var expected : int = 1
var filled_units : int = 0
var filled_color : Color = Color("#e8c97a")
var unit_px : float = 26.0
var show_value : bool = true

func _draw() -> void:
	var edge := Color("#8a7147")
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(0, 0, 0, 0.05), true)
	if filled_units == 0:
		draw_dashed_line(r.position, Vector2(r.end.x, r.position.y), edge, 2.0, 6.0)
		draw_dashed_line(Vector2(r.end.x, r.position.y), r.end, edge, 2.0, 6.0)
		draw_dashed_line(r.end, Vector2(r.position.x, r.end.y), edge, 2.0, 6.0)
		draw_dashed_line(Vector2(r.position.x, r.end.y), r.position, edge, 2.0, 6.0)
	else:
		var h := filled_units * unit_px
		var br := Rect2(Vector2(4.0, size.y - 4.0 - h), Vector2(size.x - 8.0, h))
		draw_rect(br, filled_color, true)
		draw_rect(br, Color("#3b2a1a"), false, 3.0)
		if show_value:
			var font := ThemeDB.fallback_font
			var fs := 20
			var label := str(filled_units)
			var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(font, Vector2((size.x - tw) / 2.0, br.position.y + h / 2.0 + fs * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#241a10"))

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return filled_units == 0 and typeof(data) == TYPE_DICTIONARY and str(data.get("kind", "")) == "block"

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	dropped.emit(self, data)
