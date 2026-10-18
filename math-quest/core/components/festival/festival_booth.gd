extends EventNPC
class_name FestivalBooth

# =====================================================================
#  A festival booth: the host NPC (EventNPC: "!" mark, "E" to talk,
#  y-sorted by the feet) standing under the market stall
#  (assets/img/event_stall_2d) with the booth's icon on the awning.
#  A booth that is done gets a "✓" mark.
# =====================================================================

var booth_id : String = ""
var _stall : Node2D


func setup(def: Dictionary) -> void:
	super.setup(def)
	booth_id = str(def.get("id", ""))
	_stall = BoothStall.new()
	_stall.icon = str(def.get("icon", ""))
	add_child(_stall)
	move_child(_stall, 0)   # behind the shadow and the host
	_mark_y = minf(_mark_y, BoothStall.TOP - 16.0)


## Done: the mark becomes a green tick.
func set_done() -> void:
	set_mark("✓")
	if _bang:
		_bang.add_theme_color_override("font_color", Color("#7fe08a"))


class BoothStall extends Node2D:
	const TEXTURE := preload("res://assets/img/event_stall_2d(300x280).png")
	const SCALE := 0.15
	## Middle of the two pole bottoms in the image: sits on the host's feet
	const BASE := Vector2(149, 271)
	## Top of the awning in the image
	const IMAGE_TOP := 7.0
	const TOP := -(BASE.y - IMAGE_TOP) * SCALE   # top of the awning (feet = 0)
	var icon : String = ""

	func _ready() -> void:
		var sprite := Sprite2D.new()
		sprite.texture = TEXTURE
		sprite.centered = false
		sprite.offset = -BASE
		sprite.scale = Vector2(SCALE, SCALE)
		add_child(sprite)
		# The booth's icon on the awning, so booths tell apart at a glance
		var sign := Label.new()
		sign.text = icon
		sign.add_theme_font_size_override("font_size", 9)
		sign.position = Vector2(-7, TOP + 1)
		add_child(sign)
