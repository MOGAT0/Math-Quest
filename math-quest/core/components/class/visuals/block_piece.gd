extends Control
class_name BlockPiece

# Moved out of the old class.gd (vector drawn, no image assets).

var units : int = 1
var unit_px : float = 26.0
var show_value : bool = true
var color : Color = Color("#d98a6c")

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, color, true)
	draw_rect(r, Color("#3b2a1a"), false, 3.0)
	if show_value:
		var font := ThemeDB.fallback_font
		var fs := 20
		var label := str(units)
		var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2((size.x - tw) / 2.0, size.y / 2.0 + fs * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#241a10"))

func _get_drag_data(_at_position: Vector2) -> Variant:
	var preview = BlockPiece.new()
	preview.units = units
	preview.unit_px = unit_px
	preview.show_value = show_value
	preview.color = color
	preview.size = size
	preview.modulate.a = 0.85
	preview.position = -size / 2.0
	var holder = Control.new()
	holder.add_child(preview)
	set_drag_preview(holder)
	modulate.a = 0.35
	return {"kind": "block", "units": units, "piece": self}

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		modulate.a = 1.0
