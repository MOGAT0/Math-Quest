extends Node

var save_path : String = "user://data.json"

var database : Dictionary = {
	"schemas": {},
	"data": {}
}


const DEFAULT_SCHEMAS : Dictionary = {
	"checklist": {
		"id": {"data_type": "int", "not_null": true, "primary_key": true, "auto_increment": true},
		"chapter": {"data_type": "text", "not_null": true},
		"is_done": {"data_type": "bool"}
	},
	"progress": {
		"id": {"data_type": "int", "not_null": true, "primary_key": true, "auto_increment": true},
		"current_chapter": {"data_type": "text", "not_null": true},
		"current_grade": {"data_type": "text", "default": "g1"},
		"current_lesson": {"data_type": "text", "default": "g1-l1"},
		"current_location": {"data_type": "vector2", "default":Vector2(0,0)},
		"arith_pos": {"data_type": "vector2", "default":Vector2(0,0)},
		"is_active": {"data_type": "bool", "default": false},
		"open_portal": {"data_type": "bool", "default": false},
		"c1":{"data_type": "bool", "default": false},
		"c2":{"data_type": "bool", "default": false},
		"c3":{"data_type": "bool", "default": false},
		"kp":{"data_type": "int", "default": 0},
	},
	"streak": {
		"id": {"data_type": "int", "not_null": true, "primary_key": true, "auto_increment": true},
		"date": {"data_type": "text"},
		"days": {"data_type": "int"}
	}
}

const DEFAULT_CHAPTERS : Array = [
	"prologue_classroom", "alley_portal", "magical_forest", "wizard_castle_intro",
	"arith_study_book", "academy_interview", "school_admission", "market_food_1",
	"grade1_lesson1_class", "grade1_lesson1_test", "home_sleep_1", "market_food_2",
	"grade1_lesson2_class", "grade1_lesson2_test", "home_sleep_2", "market_food_3",
	"grade1_lesson3_class", "grade1_lesson3_test", "home_sleep_3", "market_food_4",
	"grade1_lesson4_class", "grade1_lesson4_test", "home_sleep_4", "market_food_5",
	"grade1_lesson5_class", "grade1_lesson5_test", "home_sleep_5", "market_food_6",
	"grade1_lesson6_class", "grade1_lesson6_test", "home_sleep_6", "market_food_7",
	"grade1_lesson7_class", "grade1_lesson7_test", "home_sleep_7", "market_food_8",
	"grade1_lesson8_class", "grade1_lesson8_test", "home_sleep_8", "market_food_9",
	"grade1_lesson9_class", "grade1_lesson9_test", "home_sleep_9", "market_food_10",
	"grade1_lesson10_class", "grade1_lesson10_test", "grade1_complete", "home_sleep_10",
	"market_food_11", "grade2_lesson1_class", "grade2_lesson1_test", "home_sleep_11",
	"market_food_12", "grade2_lesson2_class", "grade2_lesson2_test", "home_sleep_12",
	"market_food_13", "grade2_lesson3_class", "grade2_lesson3_test", "home_sleep_13",
	"market_food_14", "grade2_lesson4_class", "grade2_lesson4_test", "home_sleep_14",
	"market_food_15", "grade2_lesson5_class", "grade2_lesson5_test", "home_sleep_15",
	"market_food_16", "grade2_lesson6_class", "grade2_lesson6_test", "home_sleep_16",
	"market_food_17", "grade2_lesson7_class", "grade2_lesson7_test", "home_sleep_17",
	"market_food_18", "grade2_lesson8_class", "grade2_lesson8_test", "home_sleep_18",
	"market_food_19", "grade2_lesson9_class", "grade2_lesson9_test", "home_sleep_19",
	"market_food_20", "grade2_lesson10_class", "grade2_lesson10_test", "grade2_complete",
	"home_sleep_20", "market_food_21", "grade3_lesson1_class", "grade3_lesson1_test",
	"home_sleep_21", "market_food_22", "grade3_lesson2_class", "grade3_lesson2_test",
	"home_sleep_22", "market_food_23", "grade3_lesson3_class", "grade3_lesson3_test",
	"home_sleep_23", "market_food_24", "grade3_lesson4_class", "grade3_lesson4_test",
	"home_sleep_24", "market_food_25", "grade3_lesson5_class", "grade3_lesson5_test",
	"home_sleep_25", "market_food_26", "grade3_lesson6_class", "grade3_lesson6_test",
	"home_sleep_26", "market_food_27", "grade3_lesson7_class", "grade3_lesson7_test",
	"home_sleep_27", "market_food_28", "grade3_lesson8_class", "grade3_lesson8_test",
	"home_sleep_28", "market_food_29", "grade3_lesson9_class", "grade3_lesson9_test",
	"home_sleep_29", "market_food_30", "grade3_lesson10_class", "grade3_lesson10_test",
	"grade3_complete", "library_ms_richie", "interactive_review", "wizard_final_trial",
	"portal_key_awarded", "return_earth_exam", "victory_epilogue",
]

func _ready() -> void:
	load_database()
	ensure_base_tables()

func ensure_base_tables() -> void:
	var needs_save : bool = false

	for table_name in DEFAULT_SCHEMAS.keys():
		if not database["schemas"].has(table_name):
			database["schemas"][table_name] = DEFAULT_SCHEMAS[table_name].duplicate(true)
			database["data"][table_name] = []
			_seed_default_table(table_name)
			needs_save = true

	if needs_save:
		save_database()

func _seed_default_table(table_name: String) -> void:
	match table_name:
		"checklist":
			var rows : Array = []
			for i in range(DEFAULT_CHAPTERS.size()):
				rows.append({
					"id": i + 1,
					"chapter": DEFAULT_CHAPTERS[i],
					"is_done": false
				})
			database["data"]["checklist"] = rows

		"progress":
			database["data"]["progress"] = [{
				"id": 1,
				"current_chapter": "prologue_classroom",
				"current_grade": "g1",
				"current_lesson": "g1-l1",
				"current_location": Vector2.ZERO,
				"arith_pos": Vector2.ZERO,
				"is_active": true,
				"open_portal": false,
				"c1": false,
				"c2": false,
				"c3": false,
				"kp": 0     
			}]

		"streak":
			database["data"]["streak"] = []

		_:
			pass

func create_table(table_name: String, schema: Dictionary) -> void:
	if not database["schemas"].has(table_name):
		database["schemas"][table_name] = schema
		database["data"][table_name] = []
		save_database()

func insert(table_name: String, row_data: Dictionary) -> int:
	if not database["schemas"].has(table_name):
		return -1
		
	var schema = database["schemas"][table_name]
	var new_row = row_data.duplicate()
	var inserted_id = -1
	
	for field in schema:
		if schema[field].get("auto_increment", false):
			var next_id = _get_next_id(table_name, field)
			new_row[field] = next_id
			inserted_id = next_id
			
	if not _validate_data(table_name, new_row):
		push_error("DataManager: Validation failed for table '" + table_name + "'")
		return -1
	
	database["data"][table_name].append(new_row)
	save_database()
	return inserted_id

func select_all(table_name: String) -> Array:
	if database["data"].has(table_name):
		return database["data"][table_name]
	return []

func update_by_id(table_name: String, id_field: String, id_value: int, new_data: Dictionary) -> bool:
	if not database["data"].has(table_name):
		return false
		
	for i in range(database["data"][table_name].size()):
		var row = database["data"][table_name][i]
		if row.get(id_field) == id_value:
			for key in new_data:
				database["data"][table_name][i][key] = new_data[key]

			if not _validate_data(table_name, database["data"][table_name][i]):
				push_error("DataManager: Update validation failed.")
				return false
				
			save_database()
			return true
	return false

func delete_by_id(table_name: String, id_field: String, id_value: int) -> bool:
	if not database["data"].has(table_name):
		return false
		
	for i in range(database["data"][table_name].size()):
		var row = database["data"][table_name][i]
		if row.get(id_field) == id_value:
			database["data"][table_name].remove_at(i)
			save_database()
			return true
	return false

func _get_next_id(table_name: String, field: String) -> int:
	var highest_id = 0
	for row in database["data"][table_name]:
		if row.has(field) and row[field] > highest_id:
			highest_id = row[field]
	return highest_id + 1

func _validate_data(table_name: String, row_data: Dictionary) -> bool:
	var schema = database["schemas"][table_name]
	for field in schema:
		var rules = schema[field]

		if rules.get("not_null", false):
			if not row_data.has(field) or row_data[field] == null:
				return false

		if row_data.has(field) and row_data[field] != null:
			var expected = rules.get("data_type", "")
			var actual_type = typeof(row_data[field])
			
			if expected == "int" and actual_type != TYPE_INT and actual_type != TYPE_FLOAT:
				return false
			elif expected == "text" and actual_type != TYPE_STRING:
				return false
			elif expected == "vector2" and actual_type != TYPE_VECTOR2:
				return false
	return true

func save_database() -> void:
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		var serialized_db = _serialize_value(database)
		file.store_string(JSON.stringify(serialized_db, "\t"))
		file.close()

func load_database() -> void:
	if FileAccess.file_exists(save_path):
		var file = FileAccess.open(save_path, FileAccess.READ)
		var json = JSON.new()
		var error = json.parse(file.get_as_text())
		if error == OK:
			database = _deserialize_value(json.data)
		file.close()

func _serialize_value(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY:
		var dict_res = {}
		for key in value:
			dict_res[key] = _serialize_value(value[key])
		return dict_res
	elif typeof(value) == TYPE_ARRAY:
		var arr_res = []
		for item in value:
			arr_res.append(_serialize_value(item))
		return arr_res
	elif typeof(value) == TYPE_VECTOR2:
		return {"__type__": "Vector2", "x": value.x, "y": value.y}
	return value

func _deserialize_value(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY:
		if value.has("__type__") and value["__type__"] == "Vector2":
			return Vector2(value["x"], value["y"])
			
		var dict_res = {}
		for key in value:
			dict_res[key] = _deserialize_value(value[key])
		return dict_res
	elif typeof(value) == TYPE_ARRAY:
		var arr_res = []
		for item in value:
			arr_res.append(_deserialize_value(item))
		return arr_res
	return value

func clear_data() -> void:
	database["schemas"].clear()
	database["data"].clear()
	ensure_base_tables()
