extends Control
class_name DevCMD

@onready var cmd: LineEdit = %cmd
@onready var logs: VBoxContainer = %logs

var _regex: RegEx = RegEx.new()

func _ready() -> void:
	hide()
	_regex.compile("\"[^\"]+\"|=|[^\\s=]+")
	
	# Connected the text_submitted signal so pressing Enter triggers the command submission
	cmd.text_submitted.connect(_on_cmd_text_submitted)

func _on_submit_pressed() -> void:
	var input_text: String = cmd.text.strip_edges()
	if input_text.is_empty():
		return
	
	cmd.clear()
	_execute_command(input_text)

# Added handler function that receives the Enter key submission from the LineEdit
func _on_cmd_text_submitted(_new_text: String) -> void:
	_on_submit_pressed()

func _execute_command(input_text: String) -> void:
	var matches: Array[RegExMatch] = _regex.search_all(input_text)
	if matches.is_empty():
		return
		
	var tokens: Array = []
	for m in matches:
		var token: String = m.get_string()
		if token.begins_with("\"") and token.ends_with("\""):
			token = token.substr(1, token.length() - 2)
		tokens.append(token)
		
	var command: String = tokens[0]
	var raw_args: Array = tokens.slice(1)
	var typed_args: Array = []
	
	for i in range(raw_args.size()):
		if raw_args[i] == "=":
			if typed_args.size() > 0:
				typed_args.pop_back()
			continue
		typed_args.append(_convert_type(raw_args[i]))
		
	if has_method(command):
		callv(command, typed_args)
	else:
		_log_to_console("Error: Command not found [" + command + "]")

func _convert_type(val: String) -> Variant:
	var lower_val: String = val.to_lower()
	if lower_val == "true":
		return true
	if lower_val == "false":
		return false
	if val.is_valid_int():
		return val.to_int()
	if val.is_valid_float():
		return val.to_float()
	return val

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == 4194312:
		if event.pressed and not event.echo:
			visible = not visible
			if visible:
				cmd.grab_focus()
			else:
				cmd.clear()
			get_viewport().set_input_as_handled()
			
func _log_to_console(msg: String) -> void:
	var label: Label = Label.new()
	label.text = msg
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	logs.add_child(label)

func follow_player(npc_name: String, value: bool) -> void:
	GameManager._follow_player(npc_name, value)
	_log_to_console("Command executed: follow_player " + npc_name + " " + str(value))

func update_class(current_grade: String, current_lesson: String) -> void:
	GameManager._update_class(current_grade, current_lesson)
	_log_to_console("Command executed: update_class " + current_grade + " " + current_lesson)

## change_date <season> <year> <day>, e.g. "change_date spring 1 13".
## Ends the current day first (festival and random events pack up), then
## starts the new date as if Matthew woke up on it.
func change_date(season_name = "", year = 1, day = 1) -> void:
	var usage := "Usage: change_date <spring|summer|autumn|winter> <year> <day 1-28>"
	var seasons : Array = CalendarManager.SEASONS.map(func(s): return s.to_lower())
	var season := seasons.find(str(season_name).to_lower())
	if season == -1 and str(season_name).to_lower() == "fall":
		season = 2
	if season == -1:
		_log_to_console("Error: unknown season [" + str(season_name) + "]. " + usage)
		return
	if typeof(year) != TYPE_INT or year < 1:
		_log_to_console("Error: year must be 1 or more. " + usage)
		return
	if typeof(day) != TYPE_INT or day < 1 or day > CalendarManager.DAYS_PER_SEASON:
		_log_to_console("Error: day must be 1-%d. %s" % [CalendarManager.DAYS_PER_SEASON, usage])
		return
	CalendarManager.day_ended.emit(CalendarManager.date())
	CalendarManager.set_date(day, season, year)
	_log_to_console("Command executed: change_date -> " + CalendarManager.date_text(false))

## set_time <hour> [minute], 24-hour clock: "set_time 13", "set_time 13 30"
## or "set_time 13:30". Stamina is kept as it was (jumping the clock would
## otherwise drain it for the skipped hours), and it never changes the date
## (use change_date for that).
func set_time(hour = null, minute = 0) -> void:
	var usage := "Usage: set_time <hour 0-23> [minute 0-59], e.g. set_time 13 or set_time 13:30"
	if typeof(hour) == TYPE_STRING and str(hour).contains(":"):
		var parts := str(hour).split(":")
		if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
			minute = parts[1].to_int()
			hour = parts[0].to_int()
	if typeof(hour) != TYPE_INT or hour < 0 or hour > 23:
		_log_to_console("Error: hour must be 0-23. " + usage)
		return
	if typeof(minute) != TYPE_INT or minute < 0 or minute > 59:
		_log_to_console("Error: minute must be 0-59. " + usage)
		return
	var stamina := GameManager.player_stamina
	# (+ a hair, so 13:20 doesn't round down to 13:19 on the clock)
	GameManager.current_time = hour + minute / 60.0 + 0.0001
	GameManager.player_stamina = stamina
	_log_to_console("Command executed: set_time -> %02d:%02d (%s)" % [hour, minute, GameManager.get_formatted_time()])
