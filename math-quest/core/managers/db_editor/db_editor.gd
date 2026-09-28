extends Control

var sql_editor : CodeEdit
var output_table : Tree
var output_log : RichTextLabel
var schema_tree : Tree
var right_sidebar_content : VBoxContainer

var expanded_panel : PanelContainer
var expanded_tree : Tree
var expanded_title : Label
var current_expanded_table : String = ""
var delete_confirm_dialog : ConfirmationDialog
var select_all_btn : CheckButton

var is_dark_mode : bool = false
var app_theme : Theme
var bg_style : StyleBoxFlat
var panel_style : StyleBoxFlat
var theme_btn : Button

var _is_silent : bool = false

var sql_keywords : Array = [
	"SELECT", "FROM", "WHERE", "INSERT INTO", "VALUES", 
	"UPDATE", "SET", "DELETE FROM", "CREATE TABLE", "DROP TABLE", "TRUNCATE TABLE",
	"ALTER TABLE", "ADD COLUMN", "DEFAULT", "RENAME TO", "RENAME COLUMN", "DROP COLUMN",
	"ALTER COLUMN", "SET DEFAULT",
	"LIMIT", "ORDER BY", "ASC", "DESC", "SHOW TABLES", "primary_key", "auto_increment", "not_null",
	"bool", "int", "float", "String", "text", "Vector2", "Vector2i", 
	"Vector3", "Vector3i", "Vector4", "Vector4i", "Color", "Rect2", "Rect2i", 
	"Transform2D", "Transform3D", "Plane", "Quaternion", "AABB", "Basis", 
	"Projection", "Dictionary", "Array", "PackedByteArray", 
	"PackedInt32Array", "PackedInt64Array", "PackedFloat32Array", 
	"PackedFloat64Array", "PackedStringArray", "PackedVector2Array", 
	"PackedVector3Array", "PackedColorArray"
]

func _ready() -> void:
	visible = true if get_tree().current_scene.scene_file_path == scene_file_path else false
		
		
	_init_theme()
	_build_ui()
	_apply_theme()
	_refresh_ui()
	_print_to_log("System", "Database Console Initialized. Ready for queries.")

func _init_theme() -> void:
	app_theme = Theme.new()
	theme = app_theme
	
	bg_style = StyleBoxFlat.new()
	panel_style = StyleBoxFlat.new()
	panel_style.set_border_width_all(1)

func _build_ui() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	
	var bg_panel = PanelContainer.new()
	bg_panel.add_theme_stylebox_override("panel", bg_style)
	bg_panel.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg_panel)
	
	var main_hbox = HBoxContainer.new()
	bg_panel.add_child(main_hbox)

	var left_panel = PanelContainer.new()
	left_panel.add_theme_stylebox_override("panel", panel_style)
	left_panel.custom_minimum_size = Vector2(250, 0)
	main_hbox.add_child(left_panel)
	
	schema_tree = Tree.new()
	schema_tree.hide_root = true
	left_panel.add_child(schema_tree)

	var middle_vbox = VBoxContainer.new()
	middle_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	main_hbox.add_child(middle_vbox)
	
	var input_header = HBoxContainer.new()
	middle_vbox.add_child(input_header)
	
	var input_label = Label.new()
	input_label.text = " <  Input "
	input_label.add_theme_font_size_override("font_size", 14)
	input_header.add_child(input_label)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	input_header.add_child(spacer)

	theme_btn = Button.new()
	theme_btn.custom_minimum_size = Vector2(40, 30)
	theme_btn.pressed.connect(_toggle_theme)
	input_header.add_child(theme_btn)
	
	var run_btn = Button.new()
	run_btn.text = "Run >"
	run_btn.custom_minimum_size = Vector2(100, 30)
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.21, 0.527, 0.304, 1.0)
	run_btn.add_theme_stylebox_override("normal", btn_style)
	run_btn.pressed.connect(_on_run_pressed)
	input_header.add_child(run_btn)

	sql_editor = CodeEdit.new()
	sql_editor.size_flags_vertical = SIZE_EXPAND_FILL
	sql_editor.syntax_highlighter = CodeHighlighter.new()
	sql_editor.placeholder_text = "write query here"
	sql_editor.code_completion_enabled = true
	sql_editor.code_completion_prefixes = [""]
	sql_editor.text_changed.connect(_on_editor_text_changed)
	sql_editor.code_completion_requested.connect(_on_code_completion_requested)
	middle_vbox.add_child(sql_editor)
	
	var output_label = Label.new()
	output_label.text = " Output"
	middle_vbox.add_child(output_label)
	
	output_table = Tree.new()
	output_table.size_flags_vertical = SIZE_EXPAND_FILL
	output_table.hide_root = true
	output_table.columns = 1
	output_table.column_titles_visible = true
	middle_vbox.add_child(output_table)
	
	output_log = RichTextLabel.new()
	output_log.custom_minimum_size = Vector2(0, 80)
	output_log.scroll_following = true
	middle_vbox.add_child(output_log)

	var right_panel = PanelContainer.new()
	right_panel.add_theme_stylebox_override("panel", panel_style)
	right_panel.custom_minimum_size = Vector2(400, 0)
	main_hbox.add_child(right_panel)
	
	var right_vbox = VBoxContainer.new()
	right_panel.add_child(right_vbox)
	
	var right_label = Label.new()
	right_label.text = " >  Available Tables"
	right_vbox.add_child(right_label)
	
	var right_scroll = ScrollContainer.new()
	right_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	right_vbox.add_child(right_scroll)
	
	right_sidebar_content = VBoxContainer.new()
	right_sidebar_content.size_flags_horizontal = SIZE_EXPAND_FILL
	right_scroll.add_child(right_sidebar_content)
	
	expanded_panel = PanelContainer.new()
	expanded_panel.add_theme_stylebox_override("panel", bg_style)
	expanded_panel.set_anchors_preset(PRESET_FULL_RECT)
	expanded_panel.hide()
	add_child(expanded_panel) 
	
	var expand_vbox = VBoxContainer.new()
	expand_vbox.set_anchors_preset(PRESET_FULL_RECT)
	expanded_panel.add_child(expand_vbox)
	
	var expand_header = HBoxContainer.new()
	expand_vbox.add_child(expand_header)
	
	expanded_title = Label.new()
	expanded_title.add_theme_font_size_override("font_size", 16)
	expand_header.add_child(expanded_title)
	
	var exp_spacer = Control.new()
	exp_spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	expand_header.add_child(exp_spacer)
	
	# [Newly added code: Creates the Select All CheckButton]
	select_all_btn = CheckButton.new()
	select_all_btn.text = "Select All "
	select_all_btn.toggled.connect(_on_select_all_toggled)
	expand_header.add_child(select_all_btn)
	
	var edit_row_btn = Button.new()
	edit_row_btn.text = " Edit Selected "
	edit_row_btn.custom_minimum_size = Vector2(110, 30)
	edit_row_btn.pressed.connect(_on_edit_row_pressed)
	expand_header.add_child(edit_row_btn)
	
	var del_row_btn = Button.new()
	del_row_btn.text = " Delete Selected "
	del_row_btn.custom_minimum_size = Vector2(120, 30)
	var del_style = StyleBoxFlat.new()
	del_style.bg_color = Color(0.6, 0.2, 0.2) 
	del_row_btn.add_theme_stylebox_override("normal", del_style)
	del_row_btn.pressed.connect(_on_delete_row_pressed)
	expand_header.add_child(del_row_btn)
	
	var close_btn = Button.new()
	close_btn.text = " Close "
	close_btn.custom_minimum_size = Vector2(80, 30)
	close_btn.pressed.connect(_on_close_expanded_pressed)
	expand_header.add_child(close_btn)
	
	expanded_tree = Tree.new()
	expanded_tree.size_flags_vertical = SIZE_EXPAND_FILL
	expanded_tree.hide_root = true
	expanded_tree.column_titles_visible = true
	expanded_tree.item_edited.connect(_on_expanded_tree_item_edited) 
	expand_vbox.add_child(expanded_tree)
	
	# [Newly added code: Builds the confirmation popup for multi-deletion]
	delete_confirm_dialog = ConfirmationDialog.new()
	delete_confirm_dialog.dialog_text = "Are you sure you want to delete the selected row(s)?"
	delete_confirm_dialog.confirmed.connect(_on_delete_confirmed)
	add_child(delete_confirm_dialog)
	#var expand_header = HBoxContainer.new()
	#expand_vbox.add_child(expand_header)
	#
	#expanded_title = Label.new()
	#expanded_title.size_flags_horizontal = SIZE_EXPAND_FILL
	#expanded_title.add_theme_font_size_override("font_size", 16)
	#expand_header.add_child(expanded_title)
	#
	#var close_btn = Button.new()
	#close_btn.text = " Close "
	#close_btn.custom_minimum_size = Vector2(80, 30)
	#close_btn.pressed.connect(_on_close_expanded_pressed)
	#expand_header.add_child(close_btn)
	#
	#expanded_tree = Tree.new()
	#expanded_tree.size_flags_vertical = SIZE_EXPAND_FILL
	#expanded_tree.hide_root = true
	#expanded_tree.column_titles_visible = true
	#expand_vbox.add_child(expanded_tree)

func _toggle_theme() -> void:
	is_dark_mode = !is_dark_mode
	_apply_theme()

func _apply_theme() -> void:
	var text_col : Color
	
	if is_dark_mode:
		theme_btn.text = "[Thm: Night]"
		bg_style.bg_color = Color(0.107, 0.155, 0.301, 1.0)
		panel_style.bg_color = Color(0.117, 0.131, 0.188, 1.0)
		panel_style.border_color = Color(0.2, 0.22, 0.28)
		text_col = Color(0.9, 0.9, 0.9)
	else:
		theme_btn.text = "[Thm: Day]"
		bg_style.bg_color = Color(0.754, 0.754, 0.754, 1.0)
		panel_style.bg_color = Color(0.891, 0.891, 0.891, 1.0)
		panel_style.border_color = Color(0.8, 0.8, 0.85)
		text_col = Color(0.1, 0.1, 0.1)

	app_theme.set_color("font_color", "Label", text_col)
	app_theme.set_color("font_color", "Tree", text_col)
	app_theme.set_color("font_color", "CodeEdit", text_col)
	app_theme.set_color("font_color", "RichTextLabel", text_col)

func _on_editor_text_changed() -> void:
	sql_editor.request_code_completion(true)

func _on_code_completion_requested() -> void:
	var completion_words = sql_keywords.duplicate()
	
	var schemas = DataManager.database.get("schemas", {})
	for table in schemas.keys():
		if not completion_words.has(table):
			completion_words.append(table)
		for col in schemas[table].keys():
			if not completion_words.has(col):
				completion_words.append(col)
				
	for word in completion_words:
		sql_editor.add_code_completion_option(CodeEdit.KIND_PLAIN_TEXT, word, word)
		
	sql_editor.update_code_completion_options(true)

func _on_run_pressed() -> void:
	var cmd = sql_editor.get_selected_text()
	if cmd == "":
		cmd = sql_editor.text
		
	cmd = cmd.strip_edges()
	if cmd == "":
		return
		
	_print_to_log("Command", cmd)
	query(cmd)

func _get_sorted_columns(table_schema: Dictionary) -> Array:
	var cols = table_schema.keys()
	var pk_cols = []
	var other_cols = []
	
	for col in cols:
		if table_schema[col].get("primary_key", false):
			pk_cols.append(col)
		else:
			other_cols.append(col)
			
	var sorted_cols = []
	sorted_cols.append_array(pk_cols)
	sorted_cols.append_array(other_cols)
	return sorted_cols

# --- NEW: Standard API Response Generator ---
func _create_response(status: String, code: int, message: String, data: Variant = []) -> Dictionary:
	if not _is_silent:
		var prefix = "Success" if status == "success" else "Error"
		_print_to_log(prefix, str(code) + " - " + message)
		
	return {
		"status": status,
		"code": code,
		"message": message,
		"data": data
	}

# --- MODIFIED: Adjusted for Dictionary responses ---
func _resolve_subqueries(cmd: String) -> String:
	var result_cmd = cmd
	var start_idx = result_cmd.to_upper().find("(SELECT ")
	var max_iters = 10 # Prevent infinite loops
	
	while start_idx != -1 and max_iters > 0:
		max_iters -= 1
		var depth = 0
		var end_idx = -1
		
		for i in range(start_idx, result_cmd.length()):
			if result_cmd[i] == '(': 
				depth += 1
			elif result_cmd[i] == ')':
				depth -= 1
				if depth == 0:
					end_idx = i
					break
					
		if end_idx != -1:
			var sub_cmd = result_cmd.substr(start_idx + 1, end_idx - start_idx - 1)
			_is_silent = true
			var sub_result_dict = query(sub_cmd)
			_is_silent = false
			
			var sub_result = sub_result_dict.get("data", [])
			if sub_result_dict.get("status") == "error":
				sub_result = []
			
			var replacement = _format_subquery_result(sub_result)
			result_cmd = result_cmd.substr(0, start_idx) + replacement + result_cmd.substr(end_idx + 1)
			start_idx = result_cmd.to_upper().find("(SELECT ")
		else:
			break
			
	return result_cmd

func _format_subquery_result(res: Variant) -> String:
	if typeof(res) == TYPE_ARRAY:
		if res.size() == 0: 
			return "null"
		if res.size() == 1 and typeof(res[0]) == TYPE_DICTIONARY:
			var vals = res[0].values()
			if vals.size() > 0:
				var v = vals[0]
				if typeof(v) == TYPE_STRING: 
					return '"' + v + '"'
				return str(v)
				
		var arr_str = "["
		for i in range(res.size()):
			if typeof(res[i]) == TYPE_DICTIONARY and res[i].values().size() > 0:
				var v = res[i].values()[0]
				if typeof(v) == TYPE_STRING: 
					arr_str += '"' + v + '"'
				else: 
					arr_str += str(v)
			if i < res.size() - 1: 
				arr_str += ", "
		arr_str += "]"
		return arr_str
	return str(res)

# --- MODIFIED: Main Query Router ---
func query(cmd: String) -> Dictionary:
	cmd = _resolve_subqueries(cmd)
	
	var upper_cmd = cmd.to_upper().replace("\n", " ")
	var single_line_cmd = cmd.replace("\n", " ")
	var response : Dictionary
	
	if upper_cmd.begins_with("CREATE TABLE"):
		response = _handle_create_table(single_line_cmd)
	elif upper_cmd.begins_with("SELECT * FROM") or upper_cmd.begins_with("SELECT "):
		response = _handle_select(single_line_cmd)
	elif upper_cmd.begins_with("INSERT INTO "):
		response = _handle_insert(single_line_cmd)
	elif upper_cmd.begins_with("UPDATE "):
		response = _handle_update(single_line_cmd)
	elif upper_cmd.begins_with("DELETE FROM "):
		response = _handle_delete(single_line_cmd)
	elif upper_cmd.begins_with("DROP TABLE "):
		response = _handle_drop_table(single_line_cmd)
	elif upper_cmd.begins_with("ALTER TABLE "):
		response = _handle_alter_table(single_line_cmd)
	elif upper_cmd.begins_with("TRUNCATE TABLE "):
		response = _handle_truncate_table(single_line_cmd)
	elif upper_cmd == "SHOW TABLES" or upper_cmd == "SHOW TABLES;":
		response = _handle_show_tables()
	elif upper_cmd == "CLEAR":
		output_log.text = ""
		response = _create_response("success", 200, "Console cleared.")
	else:
		response = _create_response("error", 400, "Command not recognized or unsupported.")
		
	if not _is_silent:
		_refresh_ui()
		
	return response

func _refresh_ui() -> void:
	schema_tree.clear()
	var s_root = schema_tree.create_item()
	var schemas = DataManager.database.get("schemas", {})
	
	for child in right_sidebar_content.get_children():
		child.queue_free()
		
	for table_name in schemas.keys():
		var t_item = schema_tree.create_item(s_root)
		t_item.set_text(0, "[-] " + table_name)
		
		var cols = schemas[table_name]
		var col_keys = _get_sorted_columns(cols) 
		
		for col in col_keys:
			var c_item = schema_tree.create_item(t_item)
			var type_str = cols[col].get("data_type", "unknown")
			c_item.set_text(0, "  |-- " + col + " [" + type_str + "]")
			
		var table_header_hbox = HBoxContainer.new()
		right_sidebar_content.add_child(table_header_hbox)
		
		var t_label = Label.new()
		t_label.text = table_name
		t_label.add_theme_font_size_override("font_size", 12)
		t_label.size_flags_horizontal = SIZE_EXPAND_FILL
		table_header_hbox.add_child(t_label)
		
		var expand_btn = Button.new()
		expand_btn.text = "[+]"
		expand_btn.custom_minimum_size = Vector2(30, 20)
		expand_btn.pressed.connect(_on_expand_pressed.bind(table_name))
		table_header_hbox.add_child(expand_btn)
		
		var preview_tree = Tree.new()
		preview_tree.custom_minimum_size = Vector2(0, 150)
		preview_tree.hide_root = true
		preview_tree.column_titles_visible = true
		preview_tree.columns = col_keys.size()
		
		for i in range(col_keys.size()):
			preview_tree.set_column_title(i, col_keys[i])
			preview_tree.set_column_expand(i, true)
			
		var p_root = preview_tree.create_item()
		var data = DataManager.select_all(table_name)
		for row in data:
			var r_item = preview_tree.create_item(p_root)
			for i in range(col_keys.size()):
				r_item.set_text(i, str(row.get(col_keys[i], "null")))
				
		right_sidebar_content.add_child(preview_tree)


# [Newly added code: Loops through all rows and matches their checkbox state to the button]
func _on_select_all_toggled(button_pressed: bool) -> void:
	if current_expanded_table == "": return
	
	var root = expanded_tree.get_root()
	if not root: return
	
	var child = root.get_first_child()
	while child:
		child.set_checked(0, button_pressed)
		child = child.get_next()

func _on_expand_pressed(table_name: String) -> void:
	current_expanded_table = table_name
	expanded_title.text = " Fullscreen View: " + table_name
	if select_all_btn:
		select_all_btn.set_pressed_no_signal(false)
		
	expanded_tree.clear()
	
	var schemas = DataManager.database.get("schemas", {})
	if not schemas.has(table_name):
		return
		
	var col_keys = _get_sorted_columns(schemas[table_name])
	expanded_tree.columns = col_keys.size() + 1
	
	expanded_tree.set_column_title(0, "Del")
	expanded_tree.set_column_expand(0, false)
	expanded_tree.set_column_custom_minimum_width(0, 40)
	
	for i in range(col_keys.size()):
		expanded_tree.set_column_title(i + 1, col_keys[i])
		expanded_tree.set_column_expand(i + 1, true)
		
	var p_root = expanded_tree.create_item()
	var data = DataManager.select_all(table_name)
	var pk_col = col_keys[0] 
	
	for row in data:
		var r_item = expanded_tree.create_item(p_root)
		r_item.set_metadata(0, row.get(pk_col)) 
		
		# Set up the checkbox
		r_item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
		r_item.set_editable(0, true)
		
		# Fill remaining data
		for i in range(col_keys.size()):
			r_item.set_text(i + 1, str(row.get(col_keys[i], "null")))
			r_item.set_editable(i + 1, true)
			
	expanded_panel.show()

#func _on_expand_pressed(table_name: String) -> void:
	#expanded_title.text = " Fullscreen View: " + table_name
	#expanded_tree.clear()
	#
	#var schemas = DataManager.database.get("schemas", {})
	#if not schemas.has(table_name):
		#return
		#
	#var col_keys = _get_sorted_columns(schemas[table_name])
	#expanded_tree.columns = col_keys.size()
	#
	#for i in range(col_keys.size()):
		#expanded_tree.set_column_title(i, col_keys[i])
		#expanded_tree.set_column_expand(i, true)
		#
	#var p_root = expanded_tree.create_item()
	#var data = DataManager.select_all(table_name)
	#
	#for row in data:
		#var r_item = expanded_tree.create_item(p_root)
		#for i in range(col_keys.size()):
			#r_item.set_text(i, str(row.get(col_keys[i], "null")))
			#
	#expanded_panel.show()

func _on_edit_row_pressed() -> void:
	if current_expanded_table == "": return
	var selected = expanded_tree.get_selected()
	if selected:
		expanded_tree.edit_selected(true)

# [Modified code: Scans the tree for checked items. If found, opens the confirmation popup]
func _on_delete_row_pressed() -> void:
	if current_expanded_table == "": return
	
	var has_checked = false
	var root = expanded_tree.get_root()
	if not root: return
	
	var child = root.get_first_child()
	while child:
		if child.is_checked(0):
			has_checked = true
			break
		child = child.get_next()
		
	if not has_checked:
		_print_to_log("System", "No rows selected for deletion.")
		return
		
	delete_confirm_dialog.popup_centered()

# [Newly added code: Fires multiple DELETE queries sequentially for all checked rows]
func _on_delete_confirmed() -> void:
	var root = expanded_tree.get_root()
	if not root: return
	
	var pk_col = expanded_tree.get_column_title(1)
	var schemas = DataManager.database.get("schemas", {})
	var pk_type = schemas[current_expanded_table][pk_col].get("data_type", "int")
	
	var deleted_count = 0
	var child = root.get_first_child()
	
	_is_silent = true
	while child:
		if child.is_checked(0):
			var pk_val = child.get_metadata(0)
			var pk_str = str(pk_val)
			if pk_type in ["string", "text"]:
				pk_str = '"' + pk_str + '"'
				
			var cmd = "DELETE FROM " + current_expanded_table + " WHERE " + pk_col + "=" + pk_str
			var res = query(cmd)
			if res.get("status") == "success":
				deleted_count += 1
		child = child.get_next()
	_is_silent = false
	
	_print_to_log("System", "Auto-deleted " + str(deleted_count) + " row(s) from " + current_expanded_table)
	_on_expand_pressed(current_expanded_table)

# [Modified code: Adjusted column indices by +1 to account for the new checkbox column]
func _on_expanded_tree_item_edited() -> void:
	if current_expanded_table == "": return
	var item = expanded_tree.get_edited()
	var col_idx = expanded_tree.get_edited_column()
	
	# Ignore edits if the user just checked/unchecked the box
	if col_idx == 0: return
	
	var col_name = expanded_tree.get_column_title(col_idx)
	var new_val_str = item.get_text(col_idx)
	
	var pk_col = expanded_tree.get_column_title(1)
	var pk_val = item.get_metadata(0)
	
	var schemas = DataManager.database.get("schemas", {})
	var schema = schemas[current_expanded_table]
	var col_type = schema[col_name].get("data_type", "string")
	var pk_type = schema[pk_col].get("data_type", "int")
	
	var pk_str = str(pk_val)
	if pk_type in ["string", "text"]:
		pk_str = '"' + pk_str + '"'
		
	var val_str = new_val_str
	if col_type in ["string", "text"]:
		val_str = '"' + new_val_str.replace('"', '\\"') + '"'
		
	var cmd = "UPDATE " + current_expanded_table + " SET " + col_name + "=" + val_str + " WHERE " + pk_col + "=" + pk_str
	
	_is_silent = true
	var res = query(cmd)
	_is_silent = false
	
	if res.get("status") == "success":
		_print_to_log("System", "Auto-updated " + col_name + " to: " + new_val_str)
		if col_idx == 1:
			item.set_metadata(0, new_val_str)
	else:
		_print_to_log("Error", "Auto-update failed: " + res.get("message", ""))
		_on_expand_pressed(current_expanded_table)


func _on_close_expanded_pressed() -> void:
	expanded_panel.hide()
	_refresh_ui()

func _parse_where_condition(cond_str: String) -> Dictionary:
	var ops = ["!=", ">=", "<=", "=", ">", "<"]
	
	for op in ops:
		var parts = cond_str.split(op, false, 1)
		if parts.size() == 2:
			var field = parts[0].strip_edges()
			var val_str = parts[1].strip_edges()
			var val = null
			
			var expr = Expression.new()
			if expr.parse(val_str) == OK:
				val = expr.execute()
				# Fallback if evaluation fails but parsing succeeds
				if expr.has_execute_failed():
					val = val_str
			else:
				# Fallback for plain strings without quotes
				val = val_str
				
			return {"field": field, "op": op, "val": val}
			
	return {}

func _handle_alter_table(cmd: String) -> Dictionary:
	var stripped = cmd.substr(12).strip_edges().replace(";", "")
	
	var rename_idx = stripped.to_upper().find(" RENAME TO ")
	if rename_idx != -1:
		var old_name = stripped.substr(0, rename_idx).strip_edges()
		var new_name = stripped.substr(rename_idx + 11).strip_edges()
		
		var schemas = DataManager.database.get("schemas", {})
		if not schemas.has(old_name):
			return _create_response("error", 404, "Table '" + old_name + "' does not exist.")
		if schemas.has(new_name):
			return _create_response("error", 400, "Table '" + new_name + "' already exists.")
			
		DataManager.database["schemas"][new_name] = DataManager.database["schemas"][old_name]
		DataManager.database["data"][new_name] = DataManager.database["data"][old_name]
		
		DataManager.database["schemas"].erase(old_name)
		DataManager.database["data"].erase(old_name)
		
		DataManager.save_database()
		return _create_response("success", 200, "Table '" + old_name + "' renamed to '" + new_name + "'.")

	var rename_col_idx = stripped.to_upper().find(" RENAME COLUMN ")
	if rename_col_idx != -1:
		var table_name = stripped.substr(0, rename_col_idx).strip_edges()
		var col_str = stripped.substr(rename_col_idx + 15).strip_edges()
		
		var to_idx = col_str.to_upper().find(" TO ")
		if to_idx == -1:
			return _create_response("error", 400, "Syntax Error: Missing TO keyword in RENAME COLUMN.")
			
		var old_col = col_str.substr(0, to_idx).strip_edges()
		var new_col = col_str.substr(to_idx + 4).strip_edges()
		
		var schemas = DataManager.database.get("schemas", {})
		if not schemas.has(table_name):
			return _create_response("error", 404, "Table '" + table_name + "' does not exist.")
			
		if not schemas[table_name].has(old_col):
			return _create_response("error", 404, "Column '" + old_col + "' does not exist in table '" + table_name + "'.")
			
		if schemas[table_name].has(new_col):
			return _create_response("error", 400, "Column '" + new_col + "' already exists in table '" + table_name + "'.")
			
		schemas[table_name][new_col] = schemas[table_name][old_col]
		schemas[table_name].erase(old_col)
		
		var data = DataManager.database.get("data", {}).get(table_name, [])
		for row in data:
			if row.has(old_col):
				row[new_col] = row[old_col]
				row.erase(old_col)
				
		DataManager.save_database()
		return _create_response("success", 200, "Column '" + old_col + "' renamed to '" + new_col + "' in table '" + table_name + "'.")

	var drop_col_idx = stripped.to_upper().find(" DROP COLUMN ")
	if drop_col_idx != -1:
		var table_name = stripped.substr(0, drop_col_idx).strip_edges()
		var col_name = stripped.substr(drop_col_idx + 13).strip_edges()
		
		var schemas = DataManager.database.get("schemas", {})
		if not schemas.has(table_name):
			return _create_response("error", 404, "Table '" + table_name + "' does not exist.")
			
		if not schemas[table_name].has(col_name):
			return _create_response("error", 404, "Column '" + col_name + "' does not exist in table '" + table_name + "'.")
			
		schemas[table_name].erase(col_name)
		
		var data = DataManager.database.get("data", {}).get(table_name, [])
		for row in data:
			if row.has(col_name):
				row.erase(col_name)
				
		DataManager.save_database()
		return _create_response("success", 200, "Column '" + col_name + "' dropped from table '" + table_name + "'.")

	var add_idx = stripped.to_upper().find(" ADD COLUMN ")
	if add_idx != -1:
		var table_name = stripped.substr(0, add_idx).strip_edges()
		var def_str = stripped.substr(add_idx + 12).strip_edges()
		
		var schemas = DataManager.database.get("schemas", {})
		if not schemas.has(table_name):
			return _create_response("error", 404, "Table '" + table_name + "' does not exist.")
			
		var def_idx = def_str.to_upper().find(" DEFAULT ")
		var col_def = ""
		var default_val_str = ""
		var has_default = false
		var default_val = null
		
		if def_idx != -1:
			col_def = def_str.substr(0, def_idx).strip_edges()
			default_val_str = def_str.substr(def_idx + 9).strip_edges()
			has_default = true
			
			var expr = Expression.new()
			if expr.parse(default_val_str) == OK:
				default_val = expr.execute()
				if expr.has_execute_failed():
					default_val = default_val_str
			else:
				default_val = default_val_str
		else:
			col_def = def_str
			
		var col_parts = col_def.split(" ", false)
		if col_parts.size() < 2:
			return _create_response("error", 400, "Syntax Error: Column definition incomplete.")
			
		var col_name = col_parts[0].strip_edges()
		var col_type = col_parts[1].strip_edges().to_lower()
		
		var col_schema = {"data_type": col_type}
		
		for i in range(2, col_parts.size()):
			var constraint = col_parts[i].strip_edges().to_lower()
			if constraint == "primary_key": col_schema["primary_key"] = true
			elif constraint == "auto_increment": col_schema["auto_increment"] = true
			elif constraint == "not_null": col_schema["not_null"] = true
			
		DataManager.database["schemas"][table_name][col_name] = col_schema
		
		if has_default:
			var data = DataManager.database["data"][table_name]
			for i in range(data.size()):
				data[i][col_name] = default_val
				
		DataManager.save_database()
		return _create_response("success", 200, "Column '" + col_name + "' added to table '" + table_name + "'.")

	var alter_col_idx = stripped.to_upper().find(" ALTER COLUMN ")
	if alter_col_idx != -1:
		var table_name = stripped.substr(0, alter_col_idx).strip_edges()
		var remainder = stripped.substr(alter_col_idx + 14).strip_edges()
		
		var set_def_idx = remainder.to_upper().find(" SET DEFAULT ")
		if set_def_idx == -1:
			return _create_response("error", 400, "Syntax Error: Missing SET DEFAULT keyword.")
			
		var col_name = remainder.substr(0, set_def_idx).strip_edges()
		var default_val_str = remainder.substr(set_def_idx + 13).strip_edges()
		
		var schemas = DataManager.database.get("schemas", {})
		if not schemas.has(table_name):
			return _create_response("error", 404, "Table '" + table_name + "' does not exist.")
			
		if not schemas[table_name].has(col_name):
			return _create_response("error", 404, "Column '" + col_name + "' does not exist in table '" + table_name + "'.")
			
		# Parse the value dynamically to convert Godot strings to proper Variants (like ints, bools, Vector2)
		var default_val = null
		var expr = Expression.new()
		if expr.parse(default_val_str) == OK:
			default_val = expr.execute()
			if expr.has_execute_failed():
				default_val = default_val_str
		else:
			default_val = default_val_str
			
		# Assign the new default value to the schema and save
		schemas[table_name][col_name]["default"] = default_val
		DataManager.save_database()
		
		return _create_response("success", 200, "Default value for column '" + col_name + "' updated to " + str(default_val) + ".")



	return _create_response("error", 400, "Syntax Error: Unsupported ALTER TABLE operation.")

func _evaluate_where(row: Dictionary, cond: Dictionary) -> bool:
	if cond.is_empty(): 
		return true
		
	var field = cond.get("field", "")
	var op = cond.get("op", "=")
	var val = cond.get("val")
	
	if not row.has(field): 
		return false
		
	var row_val = row[field]
	
	if typeof(row_val) != typeof(val):
		if (typeof(row_val) == TYPE_INT or typeof(row_val) == TYPE_FLOAT) and (typeof(val) == TYPE_INT or typeof(val) == TYPE_FLOAT):
			row_val = float(row_val)
			val = float(val)
		else:
			row_val = str(row_val)
			val = str(val)

	if op == "=": return row_val == val
	elif op == "!=": return row_val != val
	elif op == ">": return row_val > val
	elif op == "<": return row_val < val
	elif op == ">=": return row_val >= val
	elif op == "<=": return row_val <= val
	
	return false

func _handle_truncate_table(cmd: String) -> Dictionary:
	var table_name = cmd.substr(15).strip_edges().replace(";", "")
	
	if DataManager.database.get("schemas", {}).has(table_name):
		DataManager.database["data"][table_name] = []
		DataManager.save_database()
		return _create_response("success", 200, "Table '" + table_name + "' truncated (all rows deleted).")
	else:
		return _create_response("error", 404, "Table '" + table_name + "' does not exist.")


func _handle_select(cmd: String) -> Dictionary:
	var from_idx = cmd.to_upper().find(" FROM ")
	if from_idx == -1:
		return _create_response("error", 400, "Syntax Error: Missing FROM keyword.")
		
	var cols_str = cmd.substr(7, from_idx - 7).strip_edges()
	var remainder = cmd.substr(from_idx + 6).strip_edges().replace(";", "")
	
	# --- LIMIT LOGIC ---
	var limit_val = -1
	var limit_idx = remainder.to_upper().find(" LIMIT ")
	if limit_idx != -1:
		var l_str = remainder.substr(limit_idx + 7).strip_edges()
		if l_str.is_valid_int():
			limit_val = l_str.to_int()
		remainder = remainder.substr(0, limit_idx).strip_edges()
		
	# --- ORDER BY LOGIC ---
	# [Newly added code: Extracts the column to sort by and the ASC/DESC direction]
	var order_by_field = ""
	var order_desc = false
	var order_idx = remainder.to_upper().find(" ORDER BY ")
	if order_idx != -1:
		var o_str = remainder.substr(order_idx + 10).strip_edges()
		var o_parts = o_str.split(" ", false)
		if o_parts.size() > 0:
			order_by_field = o_parts[0].strip_edges()
			if o_parts.size() > 1 and o_parts[1].to_upper() == "DESC":
				order_desc = true
		remainder = remainder.substr(0, order_idx).strip_edges()
	
	# --- WHERE LOGIC ---
	var table_name = remainder
	var has_where = false
	var condition = {}
	
	var where_idx = remainder.to_upper().find(" WHERE ")
	if where_idx != -1:
		table_name = remainder.substr(0, where_idx).strip_edges()
		has_where = true
		var cond_str = remainder.substr(where_idx + 7).strip_edges()
		condition = _parse_where_condition(cond_str)
	
	var schemas = DataManager.database.get("schemas", {})
	if not schemas.has(table_name):
		return _create_response("error", 404, "Table '" + table_name + "' does not exist.")
		
	var data = DataManager.select_all(table_name)
	var filtered_data = []
	
	if has_where and not condition.is_empty():
		for row in data:
			if _evaluate_where(row, condition):
				filtered_data.append(row)
	else:
		filtered_data = data
		
	# --- APPLY ORDER BY ---
	# [Newly added code: Sorts the filtered array dynamically based on the parsed field and direction]
	if order_by_field != "":
		filtered_data.sort_custom(func(a, b):
			var val_a = a.get(order_by_field)
			var val_b = b.get(order_by_field)
			
			# Fallbacks for null values
			if val_a == null: return not order_desc
			if val_b == null: return order_desc
			
			if order_desc:
				return val_a > val_b
			else:
				return val_a < val_b
		)
		
	# --- APPLY LIMIT ---
	if limit_val > 0 and filtered_data.size() > limit_val:
		filtered_data = filtered_data.slice(0, limit_val)
	
	var result_array = []
	var final_cols = []
	if cols_str == "*":
		final_cols = _get_sorted_columns(schemas[table_name])
	else:
		var raw_cols = cols_str.split(",")
		for c in raw_cols:
			var c_clean = c.strip_edges()
			if schemas[table_name].has(c_clean):
				final_cols.append(c_clean)
				
	for row in filtered_data:
		var filtered_row = {}
		for col in final_cols:
			filtered_row[col] = row.get(col, null)
		result_array.append(filtered_row)

	if not _is_silent:
		output_table.clear()
		var root = output_table.create_item()
		
		output_table.columns = final_cols.size()
		for i in range(final_cols.size()):
			output_table.set_column_title(i, final_cols[i])
			output_table.set_column_expand(i, true)
			
		for row in filtered_data:
			var row_item = output_table.create_item(root)
			for i in range(final_cols.size()):
				row_item.set_text(i, str(row.get(final_cols[i], "null")))
				
	if filtered_data.is_empty():
		return _create_response("success", 200, "Query returned 0 rows.", result_array)
	else:
		return _create_response("success", 200, "Retrieved " + str(filtered_data.size()) + " rows successfully.", result_array)

func _handle_create_table(cmd: String) -> Dictionary:
	var stripped = cmd.substr(12).strip_edges() 
	var first_paren = stripped.find("(")
	var last_paren = stripped.rfind(")")
	
	if first_paren == -1 or last_paren == -1:
		return _create_response("error", 400, "Syntax Error: Missing parentheses for columns.")
		
	var table_name = stripped.substr(0, first_paren).strip_edges()
	var columns_str = stripped.substr(first_paren + 1, last_paren - first_paren - 1)
	
	var table_dict = {}
	var columns = columns_str.split(",")
	
	for col in columns:
		var col_parts = col.strip_edges().split(" ", false)
		if col_parts.size() < 2:
			return _create_response("error", 400, "Syntax Error: Column definition incomplete for '" + col + "'")
			
		var col_name = col_parts[0].strip_edges()
		var col_type = col_parts[1].strip_edges().to_lower()
		
		var col_schema = {"data_type": col_type}
		
		for i in range(2, col_parts.size()):
			var constraint = col_parts[i].strip_edges().to_lower()
			if constraint == "primary_key":
				col_schema["primary_key"] = true
			elif constraint == "auto_increment":
				col_schema["auto_increment"] = true
			elif constraint == "not_null":
				col_schema["not_null"] = true
				
		table_dict[col_name] = col_schema
		
	DataManager.create_table(table_name, table_dict)
	return _create_response("success", 201, "Table '" + table_name + "' created.")

func _handle_insert(cmd: String) -> Dictionary:
	var val_idx = cmd.to_upper().find(" VALUES ")
	if val_idx == -1:
		return _create_response("error", 400, "Syntax Error: Missing VALUES keyword.")
		
	var table_part = cmd.substr(12, val_idx - 12).strip_edges()
	var val_part = cmd.substr(val_idx + 8).strip_edges()
	
	var t_paren = table_part.find("(")
	var table_name = table_part.substr(0, t_paren).strip_edges()
	var cols_str = table_part.substr(t_paren + 1, table_part.length() - t_paren - 2)
	var cols = cols_str.split(",")
	
	for i in range(cols.size()):
		cols[i] = cols[i].strip_edges()
	
	var rows_str = []
	var current_row = ""
	var in_string = false
	var depth = 0
	
	for i in range(val_part.length()):
		var c = val_part[i]
		if c == '"':
			in_string = !in_string
		
		if not in_string:
			if c == '(':
				depth += 1
				if depth == 1:
					current_row = ""
					continue
			elif c == ')':
				depth -= 1
				if depth == 0:
					rows_str.append(current_row)
					continue
		
		if depth > 0:
			current_row += c
			
	if rows_str.is_empty():
		return _create_response("error", 400, "Syntax Error: Failed to extract VALUES.")
		
	var inserted_ids = []
	var expr = Expression.new()
	
	for r_str in rows_str:
		var safe_r_str = r_str.replace("VECTOR2", "Vector2").replace("VECTOR3", "Vector3")
		
		if expr.parse("[" + safe_r_str + "]") != OK:
			continue
			
		var vals = expr.execute()
		var row_data = {}
		
		for i in range(cols.size()):
			if i < vals.size():
				row_data[cols[i]] = vals[i]
			
		var new_id = DataManager.insert(table_name, row_data)
		if new_id != -1:
			inserted_ids.append(new_id)
			
	if inserted_ids.size() == 1:
		return _create_response("success", 201, "Inserted row ID " + str(inserted_ids[0]), inserted_ids)
	elif inserted_ids.size() > 1:
		return _create_response("success", 201, "Inserted " + str(inserted_ids.size()) + " rows.", inserted_ids)
	else:
		return _create_response("error", 500, "Insert failed. Check schema and data types.")

func _handle_update(cmd: String) -> Dictionary:
	var where_parts = cmd.split(" WHERE ", false, 1)
	if where_parts.size() < 2:
		return _create_response("error", 400, "Syntax Error: Missing WHERE clause.")
		
	var set_parts = where_parts[0].substr(7).split(" SET ", false, 1)
	var table_name = set_parts[0].strip_edges()
	var assignments_str = set_parts[1].strip_edges()
	
	var cond_dict = _parse_where_condition(where_parts[1])
	if cond_dict.is_empty():
		return _create_response("error", 400, "Syntax Error: Invalid WHERE condition.")
	
	var pairs = []
	var current_pair = ""
	var in_string = false
	var depth = 0
	
	for i in range(assignments_str.length()):
		var c = assignments_str[i]
		if c == '"':
			in_string = !in_string
			
		if not in_string:
			if c == '(': 
				depth += 1
			elif c == ')': 
				depth -= 1
			elif c == ',' and depth == 0:
				pairs.append(current_pair)
				current_pair = ""
				continue
				
		current_pair += c
		
	if current_pair != "":
		pairs.append(current_pair)
		
	var new_data = {}
	var expr = Expression.new()
	
	for pair in pairs:
		var kv = pair.split("=", false, 1)
		if kv.size() == 2:
			var key = kv[0].strip_edges()
			var val_str = kv[1].strip_edges()
			
			if expr.parse(val_str) == OK:
				var result = expr.execute()
				if expr.has_execute_failed():
					return _create_response("error", 500, "Execution Error: Failed to process value for '" + key + "'.")
				new_data[key] = result
			else:
				return _create_response("error", 400, "Syntax Error: Failed to parse value '" + val_str + "'.")
				
	if not DataManager.database["data"].has(table_name):
		return _create_response("error", 404, "Table '" + table_name + "' does not exist.")
		
	var data = DataManager.database["data"][table_name]
	var affected_rows = 0
	
	for i in range(data.size()):
		if _evaluate_where(data[i], cond_dict):
			for k in new_data.keys():
				data[i][k] = new_data[k]
			affected_rows += 1
			
	if affected_rows > 0:
		DataManager.save_database()
		return _create_response("success", 200, "Updated " + str(affected_rows) + " matching row(s).")
	else:
		return _create_response("success", 200, "Update executed, but no matching rows found.")

func _handle_delete(cmd: String) -> Dictionary:
	var parts = cmd.substr(12).split(" WHERE ", false, 1)
	if parts.size() < 2:
		return _create_response("error", 400, "Syntax Error: Missing WHERE clause.")
		
	var table_name = parts[0].strip_edges()
	var cond_dict = _parse_where_condition(parts[1])
	
	if cond_dict.is_empty():
		return _create_response("error", 400, "Syntax Error: Invalid WHERE condition.")
		
	if not DataManager.database["data"].has(table_name):
		return _create_response("error", 404, "Table '" + table_name + "' does not exist.")
		
	var data = DataManager.database["data"][table_name]
	var items_to_remove = []
	
	for i in range(data.size()):
		if _evaluate_where(data[i], cond_dict):
			items_to_remove.append(data[i])
			
	if items_to_remove.is_empty():
		return _create_response("success", 200, "Delete executed, but no matching rows found.")
		
	for item in items_to_remove:
		data.erase(item)
		
	DataManager.save_database()
	return _create_response("success", 200, "Deleted " + str(items_to_remove.size()) + " row(s).")

func _handle_drop_table(cmd: String) -> Dictionary:
	var table_name = cmd.substr(11).strip_edges().replace(";", "")
	if DataManager.database.get("schemas", {}).has(table_name):
		DataManager.database["schemas"].erase(table_name)
		DataManager.database["data"].erase(table_name)
		DataManager.save_database()
		return _create_response("success", 200, "Table '" + table_name + "' dropped.")
	else:
		return _create_response("error", 404, "Table '" + table_name + "' does not exist.")

func _handle_show_tables() -> Dictionary:
	var schemas = DataManager.database.get("schemas", {})
	if schemas.is_empty():
		return _create_response("success", 200, "No tables found in the database.", [])
	else:
		return _create_response("success", 200, "Tables retrieved successfully.", schemas.keys())

func _print_to_log(prefix: String, msg: String) -> void:
	if _is_silent: return
	output_log.text += "[" + prefix + "] " + msg + "\n"
