extends Control
class_name CalendarPage

# =====================================================================
#  The season calendar (Stardew-style): a 4 x 7 grid of the season's 28
#  days. Today is highlighted, weekends tinted, and only MAJOR events
#  (data/events.json -> "major") are shown; hidden random events never
#  appear here. Tap a day with an event to read about it; the arrows
#  flip through the seasons of the current year.
# =====================================================================

## Columns run Sunday -> Saturday. CalendarManager counts weekdays from
## Monday (0 = Mon ... 6 = Sun), so _column() converts.
const WEEKDAY_SHORT := ["Sun", "Mon", "Tues", "Wed", "Thur", "Fri", "Sat"]
const CELL := Vector2(78, 60)

var _view_season : int = 0
var _title : Label
var _grid : GridContainer
var _info : Label


func _ready() -> void:
	# Fill the screen (anchors AND offsets, so it doesn't stay at size 0)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.08, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			close()
	)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ClassTheme.flat(ClassTheme.PARCHMENT, ClassTheme.GOLD, 18, 4, 18))
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)

	# Header: < Spring · Year 1 >   [X]
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	col.add_child(head)
	head.add_child(_nav_button("<", -1))
	_title = ClassTheme.label("", 24, ClassTheme.INK_DARK)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	head.add_child(_nav_button(">", 1))
	var journal_btn := Button.new()
	journal_btn.text = "📖 Journal"
	journal_btn.custom_minimum_size = Vector2(110, 40)
	ClassTheme.style_button(journal_btn, ClassTheme.PARCHMENT_DARK, ClassTheme.GOLD, ClassTheme.INK, 16)
	journal_btn.pressed.connect(_open_journal)
	head.add_child(journal_btn)
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(44, 40)
	ClassTheme.style_button(close_btn, ClassTheme.CRIMSON, ClassTheme.CRIMSON_DARK, ClassTheme.PARCHMENT, 18)
	close_btn.pressed.connect(close)
	head.add_child(close_btn)

	# Weekday names
	var names := GridContainer.new()
	names.columns = 7
	names.add_theme_constant_override("h_separation", 4)
	col.add_child(names)
	for i in range(7):
		var weekend_col := i == 0 or i == 6
		var l := ClassTheme.label(WEEKDAY_SHORT[i], 14, ClassTheme.CRIMSON if weekend_col else ClassTheme.BROWN)
		l.custom_minimum_size = Vector2(CELL.x, 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		names.add_child(l)

	_grid = GridContainer.new()
	_grid.columns = 7
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	col.add_child(_grid)

	var info_panel := PanelContainer.new()
	info_panel.add_theme_stylebox_override("panel", ClassTheme.flat(ClassTheme.PARCHMENT_DARK, ClassTheme.SAND_DARK, 10, 2, 10))
	col.add_child(info_panel)
	_info = ClassTheme.label("", 15, ClassTheme.INK)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(CELL.x * 7 + 24, 44)
	info_panel.add_child(_info)

	CalendarManager.day_started.connect(func(_d): _rebuild())
	_view_season = CalendarManager.season
	_rebuild()


func open() -> void:
	_view_season = CalendarManager.season
	_rebuild()
	show()
	ClassTheme.pop(self, 1.03)


func close() -> void:
	hide()


## The festival journal opens on top of the calendar.
func _open_journal() -> void:
	var journal := FestivalJournal.new()
	get_parent().add_child(journal)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _nav_button(text: String, step: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(44, 40)
	ClassTheme.style_button(b, ClassTheme.PARCHMENT_DARK, ClassTheme.GOLD, ClassTheme.INK, 18)
	b.pressed.connect(func():
		_view_season = posmod(_view_season + step, CalendarManager.SEASONS.size())
		_rebuild()
	)
	return b


func _rebuild() -> void:
	var cal := CalendarManager
	_title.text = "%s %s  ·  Year %d" % [cal.season_icon(_view_season), cal.SEASONS[_view_season], cal.year]
	for c in _grid.get_children():
		c.queue_free()
	# Blank boxes before day 1 and after the last day keep the columns lined up
	var lead := _column(cal.weekday_of(_view_season, 1))
	for i in range(lead):
		_grid.add_child(_blank_cell())
	for d in range(1, cal.DAYS_PER_SEASON + 1):
		_grid.add_child(_day_cell(d))
	var used := lead + cal.DAYS_PER_SEASON
	for i in range(posmod(-used, 7)):
		_grid.add_child(_blank_cell())
	_info.text = _today_text()


## CalendarManager weekday (0 = Mon) -> calendar column (0 = Sun).
func _column(weekday: int) -> int:
	return (weekday + 1) % 7


func _blank_cell() -> Control:
	var c := Control.new()
	c.custom_minimum_size = CELL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _day_cell(d: int) -> Control:
	var cal := CalendarManager
	var is_today := _view_season == cal.season and d == cal.day
	var is_past := _view_season < cal.season or (_view_season == cal.season and d < cal.day)
	var weekend := cal.weekday_of(_view_season, d) >= 5
	var events := cal.events_on(_view_season, d)

	var bg := ClassTheme.PARCHMENT
	if weekend:
		bg = ClassTheme.PARCHMENT_DARK
	var border := ClassTheme.SAND_DARK
	var border_w := 2
	if not events.is_empty():
		border = ClassTheme.CRIMSON
		border_w = 3
	if is_today:
		bg = ClassTheme.GOLD_LIGHT
		border = ClassTheme.GOLD
		border_w = 4

	var cell := Button.new()
	cell.custom_minimum_size = CELL
	cell.focus_mode = Control.FOCUS_NONE
	var style := ClassTheme.flat(bg, border, 8, border_w, 4)
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		cell.add_theme_stylebox_override(state, style)
	cell.modulate.a = 0.55 if is_past else 1.0
	cell.pressed.connect(func(): _info.text = _day_text(d))

	var inner := VBoxContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 6
	inner.offset_top = 4
	cell.add_child(inner)
	var num := ClassTheme.label(str(d), 15, ClassTheme.CRIMSON if weekend else ClassTheme.INK_DARK)
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(num)
	if not events.is_empty():
		var icon := ClassTheme.label(str(events[0].get("icon", "★")), 20)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inner.add_child(icon)
		# Festival joined this year: a green tick in the corner
		if FestivalDirector.attended(str(events[0].get("id", "")), cal.year):
			var tick := ClassTheme.label("✓", 16, ClassTheme.GREEN)
			tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tick.position = Vector2(CELL.x - 20, 2)
			cell.add_child(tick)
	elif is_today:
		var tag := ClassTheme.label("today", 11, ClassTheme.GOLD)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(tag)
	return cell


func _today_text() -> String:
	var cal := CalendarManager
	var today := "Today: %s." % cal.date_text(false)
	var fest := FestivalDirector.today_festival()
	if not fest.is_empty() and cal.is_holiday():
		today += " No class today: the %s %s is on in the village!" % [fest.get("icon", ""), fest.get("title", "festival")]
	elif cal.is_holiday():
		today += " No class today, it's a holiday!"
	else:
		today += " Class day at the academy."
	var tonight := FestivalDirector.opening_note()
	if tonight != "":
		today += " " + tonight
	var next := _next_event()
	if not next.is_empty():
		today += "\nComing up: %s %s on %s %d (%s)." % [next["event"].get("icon", ""), next["event"].get("title", ""), cal.SEASONS[next["season"]], next["day"], next["when"]]
	return today


func _day_text(d: int) -> String:
	var cal := CalendarManager
	var events := cal.events_on(_view_season, d)
	var head := "%s %d" % [cal.SEASONS[_view_season], d]
	if events.is_empty():
		return "%s: Class day." % head
	var e : Dictionary = events[0]
	var closed := " (No class)" if bool(e.get("closes_school", false)) else ""
	return "%s: %s %s%s\n%s" % [head, e.get("icon", ""), e.get("title", ""), closed, e.get("description", "")]


## The next major event from today, looking through the rest of the year.
func _next_event() -> Dictionary:
	var cal := CalendarManager
	var today_abs := cal.season * cal.DAYS_PER_SEASON + cal.day
	var best := {}
	var best_gap := 9999
	for e in cal.major_events:
		var at := int(e.get("season", 0)) * cal.DAYS_PER_SEASON + int(e.get("day", 1))
		var gap := at - today_abs
		if gap < 0:
			gap += cal.DAYS_PER_YEAR
		if gap < best_gap:
			best_gap = gap
			best = {"event": e, "season": int(e.get("season", 0)), "day": int(e.get("day", 1))}
	if best.is_empty():
		return {}
	best["when"] = "today" if best_gap == 0 else ("tomorrow" if best_gap == 1 else "in %d days" % best_gap)
	return best
