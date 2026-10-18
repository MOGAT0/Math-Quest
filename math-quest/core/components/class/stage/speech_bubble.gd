extends PanelContainer
class_name SpeechBubble

# =====================================================================
#  A short line floating above an actor ("Yes, let's go!").
#  say() pops it in, keeps it over the actor's head, and fades it out.
# =====================================================================

var _label : Label
var _target : Control = null
var _hide_tween : Tween = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", ClassTheme.flat(ClassTheme.PARCHMENT, ClassTheme.INK, 14, 3, 10))
	_label = ClassTheme.label("", 18, ClassTheme.INK_DARK)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label)
	hide()


func say(target: Control, text: String, seconds: float = 2.2) -> void:
	_target = target
	_label.text = text
	_label.custom_minimum_size = Vector2(minf(220.0, 14.0 * text.length() + 20.0), 0)
	reset_size()
	show()
	modulate.a = 1.0
	_follow()
	ClassTheme.pop(self, 1.2)
	if _hide_tween and _hide_tween.is_valid():
		_hide_tween.kill()
	_hide_tween = create_tween()
	_hide_tween.tween_interval(seconds)
	_hide_tween.tween_property(self, "modulate:a", 0.0, 0.3)
	_hide_tween.tween_callback(hide)


func _process(_delta: float) -> void:
	if visible:
		_follow()


func _follow() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var parent_size := (get_parent() as Control).size if get_parent() is Control else Vector2(1e6, 1e6)
	var x := _target.position.x + _target.size.x / 2.0 - size.x / 2.0
	var y := _target.position.y - size.y + _target.size.y * 0.06
	position = Vector2(clampf(x, 4.0, parent_size.x - size.x - 4.0), maxf(4.0, y))
