extends Control
class_name Station

# =====================================================================
#  Base for everything Matthew can work at on the class stage
#  (cauldron, magic circle, scale, clock tower, rune lock, puzzles).
#
#  setup(q, input_type)  a new question arrives
#  preview(value)        the player is typing/choosing: react live, but
#                        never give away whether the answer is right
#  success() / fail()    awaitable result animations
#  demo(value)           lecture: Matthew shows the magic with a value
# =====================================================================

var question : Dictionary = {}
var input_type : String = "number"


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func setup(q: Dictionary, answer_type: String) -> void:
	question = q
	input_type = answer_type
	queue_redraw()


func preview(_value: String) -> void:
	pass


func success() -> void:
	await get_tree().create_timer(0.4).timeout


func fail() -> void:
	await get_tree().create_timer(0.4).timeout


func demo(value: String) -> void:
	preview(value)
	await success()


## Label for the big action button while this station is active.
func action_label() -> String:
	return "CAST!"


## Colour of Matthew's casting aura at this station.
func cast_color() -> Color:
	return ClassTheme.GOLD_LIGHT


## Where Matthew should stand, in the station's own coordinates.
func stand_point() -> Vector2:
	return Vector2(-size.x * 0.08, size.y)


## What goes on the chalkboard for this question ("" = lesson title).
## The old "sequence" visuals ("(5 + 3)", "x", "4", "= ?") read nicely
## as a chalk equation.
func board_text() -> String:
	var v = question.get("visual", {})
	if typeof(v) == TYPE_DICTIONARY and str(v.get("type", "")) == "sequence":
		var parts := PackedStringArray()
		for token in v.get("sequence", []):
			parts.append(str(token))
		return " ".join(parts)
	return ""


## Numbers in the question text, e.g. "Brew 7 + 5 drops" -> [7, 5].
func numbers_in_text() -> Array:
	var out : Array = []
	var re := RegEx.create_from_string("\\d+")
	for m in re.search_all(str(question.get("text", ""))):
		out.append(m.get_string().to_int())
	return out


func font() -> Font:
	return get_theme_default_font()
