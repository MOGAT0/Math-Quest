extends Control
class_name ClockView

# Moved out of the old class.gd (vector drawn, no image assets).

var hour : int = 12
var minute : int = 0

func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) / 2.0 - 4.0
	draw_circle(c, r, Color("#f7ead0"))
	draw_arc(c, r, 0.0, TAU, 64, Color("#3b2a1a"), 4.0, true)
	var font := ThemeDB.fallback_font
	var fs := int(r * 0.26)
	for n in range(1, 13):
		var a := TAU * n / 12.0
		var p := c + Vector2(sin(a), -cos(a)) * (r * 0.78)
		var label := str(n)
		var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, p + Vector2(-tw / 2.0, fs * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#3b2a1a"))
	var ma := TAU * minute / 60.0
	var ha := TAU * ((hour % 12) + minute / 60.0) / 12.0
	draw_line(c, c + Vector2(sin(ha), -cos(ha)) * r * 0.5, Color("#241a10"), 6.0, true)
	draw_line(c, c + Vector2(sin(ma), -cos(ma)) * r * 0.75, Color("#8a1f1f"), 4.0, true)
	draw_circle(c, 6.0, Color("#241a10"))
