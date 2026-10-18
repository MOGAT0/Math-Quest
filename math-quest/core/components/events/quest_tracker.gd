extends PanelContainer
class_name QuestTracker

# =====================================================================
#  Small task panel that stays on screen while Matthew is gathering items
#  for a visitor: "Abby's marbles  2 / 5", then "Bring them back to
#  Abby!". Sits on the left, just under the clock.
# =====================================================================

const SCREEN_POS := Vector2(16, 104)   # just under the clock

var task_key : String = ""
var _title : Label
var _count : Label
var _bar : ProgressBar


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = SCREEN_POS
	add_theme_stylebox_override("panel", ClassTheme.flat(Color(0.14, 0.1, 0.06, 0.88), Color("#1fb5a8"), 10, 2, 10))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	add_child(col)
	_title = ClassTheme.label("", 15, ClassTheme.GOLD_LIGHT)
	col.add_child(_title)
	_count = ClassTheme.label("", 20, ClassTheme.PARCHMENT)
	col.add_child(_count)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(190, 8)
	_bar.add_theme_stylebox_override("background", ClassTheme.flat(Color(0, 0, 0, 0.4), Color.TRANSPARENT, 4))
	_bar.add_theme_stylebox_override("fill", ClassTheme.flat(Color("#1fb5a8"), Color.TRANSPARENT, 4))
	col.add_child(_bar)
	hide()


func show_task(key: String, title: String, found: int, total: int) -> void:
	task_key = key
	_title.text = title
	set_progress(found, total)
	show()
	ClassTheme.pop(self, 1.06)


func set_progress(found: int, total: int) -> void:
	_count.text = "%d / %d" % [found, total]
	_bar.max_value = maxi(total, 1)
	_bar.value = found
	_count.add_theme_color_override("font_color", ClassTheme.PARCHMENT)
	if found > 0:
		ClassTheme.pop(_count, 1.2)


## All items found: keep the full count ("4 / 4"), tinted to show it's
## done. (The toast and the arrow send the player back to the visitor.)
func show_return(_who: String) -> void:
	_count.text = "%d / %d" % [int(_bar.max_value), int(_bar.max_value)]
	_count.add_theme_color_override("font_color", Color("#7fe0d4"))
	_bar.value = _bar.max_value
	ClassTheme.pop(self, 1.06)


func hide_task(key: String = "") -> void:
	if key == "" or key == task_key:
		task_key = ""
		hide()
