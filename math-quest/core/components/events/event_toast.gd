extends PanelContainer
class_name EventToast

# Short message that slides in at the top of the screen and fades away
# ("✨ Shooting stars fell near the road!", "Star fragments 2 / 5").

var _label : Label
var _tween : Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", ClassTheme.flat(ClassTheme.INK_DARK, ClassTheme.GOLD, 12, 3, 12))
	_label = ClassTheme.label("", 18, ClassTheme.GOLD_LIGHT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label)
	hide()


func show_text(text: String, seconds: float = 3.0) -> void:
	_label.text = text
	reset_size()
	var view := get_viewport_rect().size
	var rest := Vector2((view.x - size.x) / 2.0, 70.0)
	position = rest + Vector2(0, -30)
	modulate.a = 0.0
	show()
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position", rest, 0.3)
	_tween.parallel().tween_property(self, "modulate:a", 1.0, 0.2)
	_tween.tween_interval(seconds)
	_tween.tween_property(self, "modulate:a", 0.0, 0.4)
	_tween.tween_callback(hide)
