extends Button
class_name CalendarChip

# =====================================================================
#  Calendar button for the HUD: just the calendar icon (minimal look).
#  Tap it to open the season calendar; the date is in the tooltip.
#  A small gold dot appears on days with a major event.
# =====================================================================

const ICON := "res://assets/img/calendar_icon.png"
const ICON_SIZE := 52.0   # matches the settings gear
const EVENT_DOT := Color("#f5d76e")

var _page : CalendarPage = null
var _has_event : bool = false


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	flat = true
	icon = load(ICON)
	expand_icon = true
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	custom_minimum_size = Vector2.ONE * ICON_SIZE
	size = custom_minimum_size
	pivot_offset = size / 2.0
	for state in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	# A little brighter on hover, a little press-in on tap
	mouse_entered.connect(func(): modulate = Color(1.15, 1.15, 1.15))
	mouse_exited.connect(func(): modulate = Color.WHITE)
	button_down.connect(func(): scale = Vector2(0.92, 0.92))
	button_up.connect(func(): scale = Vector2.ONE)
	pressed.connect(open_calendar)
	CalendarManager.day_started.connect(func(_d): refresh())
	refresh()


func refresh() -> void:
	var cal := CalendarManager
	var today := cal.events_on(cal.season, cal.day)
	_has_event = not today.is_empty()
	tooltip_text = cal.date_text(false)
	if _has_event:
		tooltip_text += "
%s %s" % [today[0].get("icon", ""), today[0].get("title", "")]
	queue_redraw()


func _draw() -> void:
	if _has_event:
		var c := Vector2(size.x - 6.0, 6.0)
		draw_circle(c, 6.0, Color(0.14, 0.1, 0.06))
		draw_circle(c, 4.5, EVENT_DOT)


## The calendar page lives on the same CanvasLayer as the HUD.
func open_calendar() -> void:
	if _page == null or not is_instance_valid(_page):
		_page = CalendarPage.new()
		var layer := get_parent()
		while layer and not (layer is CanvasLayer):
			layer = layer.get_parent()
		(layer if layer else get_parent()).add_child(_page)
	_page.open()
