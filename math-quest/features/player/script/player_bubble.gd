extends Node2D
class_name PlayerBubble

# =====================================================================
#  A speech bubble over the player's head ("Should I go to the shop?").
#  say() pops it in, types the line, holds it, then fades it out.
#  The text is drawn LABEL_RES times bigger and scaled down, so it stays
#  crisp under the 4x world camera (same trick as the EventNPC prompt).
# =====================================================================

const LABEL_RES := 4.0
## Absolute layer above the player and the props (not y-sorted)
const Z_LAYER := 3
## Sizes in world pixels
const FONT_SIZE := 6
const MAX_WIDTH := 100.0
const TAIL := 4.0
const GAP := 1.0
## Letters typed per second
const TYPE_SPEED := 45.0

var _sprite : Sprite2D = null
var _box : Node2D            # origin = tip of the tail, scaled 1/LABEL_RES
var _panel : PanelContainer
var _label : Label
var _tween : Tween = null


func _init() -> void:
	z_as_relative = false
	z_index = Z_LAYER
	hide()

	_box = Node2D.new()
	add_child(_box)

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", ClassTheme.flat(ClassTheme.PARCHMENT, ClassTheme.INK, 16, 3, 12))
	_box.add_child(_panel)

	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Lay out the whole line first, so typing doesn't change the size
	_label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_label.add_theme_font_size_override("font_size", int(FONT_SIZE * LABEL_RES))
	_label.add_theme_color_override("font_color", ClassTheme.INK_DARK)
	_panel.add_child(_label)

	# Tail: an ink triangle with a parchment one on top. The parchment one
	# reaches into the panel to cover its bottom border there.
	var w := 3.0 * LABEL_RES
	var h := TAIL * LABEL_RES
	var outline := Polygon2D.new()
	outline.color = ClassTheme.INK
	outline.polygon = PackedVector2Array([Vector2(-w - 3, -h - 3), Vector2(w + 3, -h - 3), Vector2(0, 0)])
	_box.add_child(outline)
	var fill := Polygon2D.new()
	fill.color = ClassTheme.PARCHMENT
	fill.polygon = PackedVector2Array([Vector2(-w, -h - 4), Vector2(w, -h - 4), Vector2(0, -5)])
	_box.add_child(fill)


## The sprite whose head the bubble sits on.
func setup(sprite: Sprite2D) -> void:
	_sprite = sprite


## Shows a line over the head. seconds = how long it stays after typing
## (0 = by length). A new line replaces the one on screen.
func say(text: String, seconds: float = 0.0) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

	_label.text = text
	var font_size := int(FONT_SIZE * LABEL_RES)
	var one_line := _label.get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var width := minf(one_line + 4.0, MAX_WIDTH * LABEL_RES)
	_label.custom_minimum_size = Vector2(width, 0)
	# A wrapping label measures its height at its current width (and caches
	# it): give it the width first, re-measure, then shrink to fit
	_label.size = Vector2(width, 0)
	_label.update_minimum_size()
	_label.reset_size()
	_label.visible_characters = 0
	_panel.update_minimum_size()
	_panel.reset_size()
	var box_size := _panel.get_combined_minimum_size()
	_panel.size = box_size
	_panel.position = Vector2(-box_size.x / 2.0, -TAIL * LABEL_RES - box_size.y)

	position = Vector2(0, _head_y() - GAP)
	modulate.a = 1.0
	show()

	var hold := seconds if seconds > 0.0 else 2.5 + 0.05 * text.length()
	_box.scale = Vector2.ONE / LABEL_RES * 0.6
	_tween = create_tween()
	_tween.tween_property(_box, "scale", Vector2.ONE / LABEL_RES, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_label, "visible_characters", text.length(), text.length() / TYPE_SPEED)
	_tween.tween_interval(hold)
	_tween.tween_property(self, "modulate:a", 0.0, 0.3)
	_tween.tween_callback(hide)


func hide_now() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	hide()


func is_talking() -> bool:
	return visible


## Top of the sprite's frame, in the player's space.
func _head_y() -> float:
	if _sprite == null or _sprite.texture == null:
		return -24.0
	return _sprite.position.y + _sprite.get_rect().position.y * _sprite.scale.y
