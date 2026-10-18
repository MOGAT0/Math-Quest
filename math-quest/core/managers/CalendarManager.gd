extends Node

# =====================================================================
#  In-game calendar (autoload "CalendarManager").
#
#  4 seasons x 28 days, 7-day weeks: Spring 1, Year 1 is a Monday.
#  The academy is open every day, weekends included, except on major
#  events that close it ("closes_school" in data/events.json). A day passes when the clock
#  runs past midnight (GameManager.midnight_passed), or when Matthew goes
#  to bed before midnight (matthew_sleep.gd -> next_day()); never twice
#  for the same night.
#
#  Saved in the "calendar" table of DataManager (user://data.json).
#
#  day_started(date) / day_ended(date) give a date Dictionary:
#    {"day", "season", "season_name", "year", "weekday", "weekday_name",
#     "absolute"}   (absolute = days since Spring 1, Year 1, starting at 1)
# =====================================================================

signal day_started(date: Dictionary)
signal day_ended(date: Dictionary)

const SEASONS := ["Spring", "Summer", "Autumn", "Winter"]
const SEASON_ICONS := ["🌸", "☀️", "🍂", "❄️"]
const EVENTS_PATH := "res://data/events.json"
const WEEKDAYS := ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
const DAYS_PER_SEASON := 28
const DAYS_PER_YEAR := DAYS_PER_SEASON * 4

var day : int = 1          # 1..28
var season : int = 0       # 0..3
var year : int = 1
## Absolute day on which the next hidden random event may roll (used by the
## event system later). Kept here so it is saved with the date.
var next_random_day : int = 0
## Ids of one-shot events already seen.
var seen_events : Array = []
## Major (calendar-visible) events from data/events.json.
var major_events : Array = []


func _ready() -> void:
	_load_events()
	load_calendar()
	DataManager.data_cleared.connect(load_calendar)
	GameManager.midnight_passed.connect(next_day)


# --------------------------------------------------------------- queries --

func absolute_day() -> int:
	return (year - 1) * DAYS_PER_YEAR + season * DAYS_PER_SEASON + day


## 0 = Monday ... 6 = Sunday
func weekday() -> int:
	return (absolute_day() - 1) % 7


func is_weekend() -> bool:
	return weekday() >= 5


## The academy is open every day (weekends too) unless a major event
## closes it.
func is_school_day() -> bool:
	return not is_holiday()


## A major event that closes the academy today.
func is_holiday() -> bool:
	for e in events_on(season, day):
		if bool(e.get("closes_school", false)):
			return true
	return false


## Major events of a season, sorted by day.
func events_in_season(s: int) -> Array:
	var out : Array = []
	for e in major_events:
		if int(e.get("season", -1)) == s:
			out.append(e)
	out.sort_custom(func(a, b): return int(a.get("day", 0)) < int(b.get("day", 0)))
	return out


func events_on(s: int, d: int) -> Array:
	var out : Array = []
	for e in major_events:
		if int(e.get("season", -1)) == s and int(e.get("day", 0)) == d:
			out.append(e)
	return out


## Weekday (0 = Monday) of any day in the current year's season `s`.
func weekday_of(s: int, d: int) -> int:
	return ((year - 1) * DAYS_PER_YEAR + s * DAYS_PER_SEASON + d - 1) % 7


func season_icon(s: int = -1) -> String:
	return SEASON_ICONS[season if s < 0 else s]


func season_name() -> String:
	return SEASONS[season]


func weekday_name(short: bool = false) -> String:
	var full : String = WEEKDAYS[weekday()]
	return full.substr(0, 3) if short else full


func date() -> Dictionary:
	return {
		"day": day,
		"season": season,
		"season_name": season_name(),
		"year": year,
		"weekday": weekday(),
		"weekday_name": weekday_name(),
		"absolute": absolute_day(),
	}


## "Spring 13, Sat" (short) or "Saturday, Spring 13, Year 1".
func date_text(short: bool = true) -> String:
	if short:
		return "%s %d, %s" % [season_name(), day, weekday_name(true)]
	return "%s, %s %d, Year %d" % [weekday_name(), season_name(), day, year]


# --------------------------------------------------------------- changes --

## Ends today and starts tomorrow (Matthew went to sleep).
func next_day() -> void:
	day_ended.emit(date())
	day += 1
	if day > DAYS_PER_SEASON:
		day = 1
		season += 1
		if season >= SEASONS.size():
			season = 0
			year += 1
	save_calendar()
	day_started.emit(date())


## Jump to a date (dev tools / tests). Starts that day.
func set_date(new_day: int, new_season: int, new_year: int = 1) -> void:
	day = clampi(new_day, 1, DAYS_PER_SEASON)
	season = clampi(new_season, 0, SEASONS.size() - 1)
	year = maxi(1, new_year)
	save_calendar()
	day_started.emit(date())


func mark_event_seen(event_id: String) -> void:
	if not seen_events.has(event_id):
		seen_events.append(event_id)
		save_calendar()


# ---------------------------------------------------------------- events --

func _load_events() -> void:
	major_events = []
	if not FileAccess.file_exists(EVENTS_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(EVENTS_PATH))
	if typeof(parsed) == TYPE_DICTIONARY and typeof(parsed.get("major")) == TYPE_ARRAY:
		major_events = parsed["major"]


# ---------------------------------------------------------------- saving --

func load_calendar() -> void:
	var rows : Array = DataManager.select_all("calendar")
	if rows.is_empty():
		day = 1
		season = 0
		year = 1
		next_random_day = 0
		seen_events = []
		return
	var row : Dictionary = rows[0]
	day = clampi(int(row.get("day", 1)), 1, DAYS_PER_SEASON)
	season = clampi(int(row.get("season", 0)), 0, SEASONS.size() - 1)
	year = maxi(1, int(row.get("year", 1)))
	next_random_day = int(row.get("next_random_day", 0))
	var parsed = JSON.parse_string(str(row.get("seen_events", "[]")))
	seen_events = parsed if typeof(parsed) == TYPE_ARRAY else []


func save_calendar() -> void:
	var values := {
		"day": day,
		"season": season,
		"year": year,
		"next_random_day": next_random_day,
		"seen_events": JSON.stringify(seen_events),
	}
	if not DataManager.update_by_id("calendar", "id", 1, values):
		var row := values.duplicate()
		DataManager.insert("calendar", row)
