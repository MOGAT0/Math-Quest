extends RefCounted
class_name ClassTheme

# =====================================================================
#  Shared colors + style helpers for the class screen.
#  Parchment UI on the right, arcane classroom stage on the left.
# =====================================================================

const PARCHMENT := Color("#f7ead0")
const PARCHMENT_DARK := Color("#f0dfa0")
const SAND := Color("#d9c48f")
const SAND_DARK := Color("#c2a668")
const BROWN := Color("#8a7147")
const INK := Color("#3b2a1a")
const INK_DARK := Color("#241a10")
const CRIMSON := Color("#8a1f1f")
const CRIMSON_DARK := Color("#5c1414")
const GOLD := Color("#a8781a")
const GOLD_LIGHT := Color("#e8c97a")
const GREEN := Color("#2f5233")
const GREEN_LIGHT := Color("#e8f0e2")
const RED := Color("#8c2f1a")
const RED_LIGHT := Color("#f7e3df")
const ARCANE := Color("#6b4fa0")
const ARCANE_LIGHT := Color("#b79ac9")

# Stage (classroom) palette
const WALL := Color("#3a2b44")
const WALL_LIGHT := Color("#4a3858")
const WOOD := Color("#5a3b22")
const WOOD_DARK := Color("#3e2816")
const FLOOR := Color("#6b4a2c")
const BOARD := Color("#23382c")
const BOARD_FRAME := Color("#8a5a2b")
const CHALK := Color("#eef2e6")


static func flat(bg: Color, border: Color = Color.TRANSPARENT, radius: int = 12, border_w: int = 0, pad: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	return s


## Chunky button with a darker bottom edge that "presses" down.
static func style_button(btn: Button, bg: Color, border: Color, font_color: Color, font_size: int = 22) -> void:
	var normal := flat(bg, border, 12, 2)
	normal.border_width_bottom = 5
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	var hover := normal.duplicate()
	hover.bg_color = bg.lightened(0.08)
	var pressed := normal.duplicate()
	pressed.border_width_bottom = 2
	pressed.content_margin_top = 9
	pressed.bg_color = bg.darkened(0.08)
	var disabled := normal.duplicate()
	disabled.bg_color = SAND
	disabled.border_color = SAND_DARK
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("hover_pressed", pressed)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("disabled", disabled)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		btn.add_theme_color_override(key, font_color)
	btn.add_theme_color_override("font_disabled_color", BROWN)
	btn.add_theme_font_size_override("font_size", font_size)
	btn.focus_mode = Control.FOCUS_NONE


static func label(text: String, font_size: int, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


# ------------------------------------------------------------ animation --

static func pop(ctrl: Control, amount: float = 1.25) -> void:
	if not is_instance_valid(ctrl):
		return
	ctrl.pivot_offset = ctrl.size / 2.0
	ctrl.scale = Vector2(amount, amount)
	ctrl.create_tween().tween_property(ctrl, "scale", Vector2.ONE, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func shake(ctrl: Control) -> void:
	if not is_instance_valid(ctrl):
		return
	ctrl.pivot_offset = ctrl.size / 2.0
	var tw := ctrl.create_tween()
	tw.tween_property(ctrl, "rotation_degrees", 6.0, 0.06)
	tw.tween_property(ctrl, "rotation_degrees", -6.0, 0.08)
	tw.tween_property(ctrl, "rotation_degrees", 3.0, 0.06)
	tw.tween_property(ctrl, "rotation_degrees", 0.0, 0.06)


static func flash(ctrl: CanvasItem, tint: Color = Color(1.35, 1.3, 1.1)) -> void:
	if not is_instance_valid(ctrl):
		return
	ctrl.modulate = tint
	ctrl.create_tween().tween_property(ctrl, "modulate", Color.WHITE, 0.35)


static func pulse(ctrl: CanvasItem) -> Tween:
	var tw := ctrl.create_tween()
	tw.bind_node(ctrl)
	tw.set_loops()
	tw.tween_property(ctrl, "modulate:a", 0.55, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(ctrl, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	return tw


## One-shot particle burst at a position inside `parent`.
static func burst(parent: Node, at: Vector2, color: Color, amount: int = 24, speed: float = 260.0, gravity: float = 300.0, size_px: float = 5.0) -> void:
	var p := CPUParticles2D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 0.9
	p.spread = 180.0
	p.gravity = Vector2(0, gravity)
	p.initial_velocity_min = speed * 0.45
	p.initial_velocity_max = speed
	p.scale_amount_min = size_px * 0.6
	p.scale_amount_max = size_px
	p.color = color
	p.position = at
	parent.add_child(p)
	p.emitting = true
	p.get_tree().create_timer(1.3).timeout.connect(p.queue_free)


static func confetti(parent: Control) -> void:
	var center := parent.size / 2.0
	for c in [GOLD, CRIMSON, GREEN, Color("#8a5a2b"), ARCANE]:
		var e := CPUParticles2D.new()
		e.emitting = false
		e.one_shot = true
		e.explosiveness = 0.9
		e.amount = 25
		e.lifetime = 3.0
		e.direction = Vector2(0, -1)
		e.spread = 90.0
		e.initial_velocity_min = 400.0
		e.initial_velocity_max = 800.0
		e.angular_velocity_min = -360.0
		e.angular_velocity_max = 360.0
		e.scale_amount_min = 10.0
		e.scale_amount_max = 18.0
		e.color = c
		e.position = center
		parent.add_child(e)
		e.emitting = true
		parent.get_tree().create_timer(3.5).timeout.connect(e.queue_free)
