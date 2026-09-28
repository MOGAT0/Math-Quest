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
