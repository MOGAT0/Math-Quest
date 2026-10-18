extends PanelContainer
class_name ClassHud

# =====================================================================
#  Top bar: lesson title, progress, stars and streak.
# =====================================================================

var font_scale : float = 1.0

var _title : Label
var _bar : ProgressBar
var _count : Label
var _stars : Label
var _streak : Label


func _fs(base: int) -> int:
	return roundi(base * font_scale)


func build() -> void:
	add_theme_stylebox_override("panel", ClassTheme.flat(ClassTheme.WOOD_DARK, ClassTheme.GOLD, 0, 0, 0))
	var style := get_theme_stylebox("panel") as StyleBoxFlat
	style.border_width_bottom = 3
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	add_child(row)

	_title = ClassTheme.label("", _fs(18), ClassTheme.GOLD_LIGHT)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.size_flags_stretch_ratio = 1.2
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(_title)

	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(120, 14)
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bar.add_theme_stylebox_override("background", ClassTheme.flat(ClassTheme.INK_DARK, ClassTheme.GOLD, 7, 1))
	_bar.add_theme_stylebox_override("fill", ClassTheme.flat(ClassTheme.GOLD_LIGHT, ClassTheme.GOLD, 7, 1))
	row.add_child(_bar)

	_count = ClassTheme.label("", _fs(18), ClassTheme.PARCHMENT)
	row.add_child(_count)

	_stars = ClassTheme.label("", _fs(20), ClassTheme.GOLD_LIGHT)
	row.add_child(_stars)

	_streak = ClassTheme.label("", _fs(18), Color("#f2a03d"))
	_streak.custom_minimum_size = Vector2(70, 0)
	row.add_child(_streak)


func set_title(text: String) -> void:
	_title.text = text


func set_progress(done: int, total: int) -> void:
	_bar.max_value = maxi(total, 1)
	create_tween().tween_property(_bar, "value", float(done), 0.35).set_trans(Tween.TRANS_SINE)
	_count.text = "%d/%d" % [mini(done + 1, total), total] if total > 0 else ""


func set_stars(n: int) -> void:
	_stars.text = "⭐".repeat(n)


func set_streak(n: int) -> void:
	_streak.text = ("🔥 x%d" % n) if n >= 2 else ""
	if n >= 2:
		ClassTheme.pop(_streak, 1.35)


func shake_stars() -> void:
	ClassTheme.shake(_stars)
