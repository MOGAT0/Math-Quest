extends PolyView
class_name ShapeSlot

# Moved out of the old class.gd (vector drawn, no image assets).

signal dropped(slot, data)
var key : String = ""
var filled : bool = false

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return not filled and typeof(data) == TYPE_DICTIONARY and str(data.get("kind", "")) == "shape"

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	dropped.emit(self, data)
