extends Node

var storyData_path : String = "res://data/story_data.json"

var story_data: Dictionary = {}

func _ready() -> void:
	load_story_data()


func load_story_data() -> void:
	var file = FileAccess.open(storyData_path, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		var json = JSON.new()
		var error = json.parse(json_string)
		if error == OK:
			story_data = json.data
		file.close()


func get_story_node(node_id: String) -> Dictionary:
	if story_data.has(node_id):
		return story_data[node_id]
	return {}

func get_title(node_id: String) -> String:
	var node = get_story_node(node_id)
	return node.get("title", "")

func get_location(node_id: String) -> String:
	var node = get_story_node(node_id)
	return node.get("location", "")

func get_dialogues(node_id: String) -> Array:
	var node = get_story_node(node_id)
	return node.get("dialogues", [])

func get_next_node(node_id: String) -> String:
	var node = get_story_node(node_id)
	var next_node = node.get("next")
	if next_node == null:
		return ""
	return next_node
