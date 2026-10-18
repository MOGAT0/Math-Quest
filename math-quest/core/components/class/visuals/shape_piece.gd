extends PolyView
class_name ShapePiece

# Moved out of the old class.gd (vector drawn, no image assets).

var key : String = ""

func _get_drag_data(_at_position: Vector2) -> Variant:
	var preview = PolyView.new()
	preview.points = points
	preview.fill = fill
	preview.outline = outline
	preview.size = size
	preview.modulate.a = 0.85
	preview.position = -size / 2.0
	var holder = Control.new()
	holder.add_child(preview)
	set_drag_preview(holder)
	modulate.a = 0.35
	return {"kind": "shape", "key": key, "piece": self}

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		modulate.a = 1.0
