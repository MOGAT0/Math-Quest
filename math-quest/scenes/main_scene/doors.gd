extends Node2D

@onready var class_room_entrance: Marker2D = %class_room_entrance

@onready var door_1: TileMapLayer = %door1
@onready var door_2: TileMapLayer = %door2
@onready var door_3: TileMapLayer = %door3

var door1_pos : Vector2 = Vector2(-2632.0,-267.0)
var door2_pos : Vector2 = Vector2(-2554.0,-266.0)
var door3_pos : Vector2 = Vector2(-2473.0,-266.0)

func _ready() -> void:
	_update_door()

func _update_door():
	var current_grade = db.query("SELECT current_grade FROM progress WHERE is_active = true")
	
	match current_grade.data[0].current_grade:
		"g1":
			door_1.enabled = true
			door_2.enabled = false
			door_3.enabled = false
			class_room_entrance.global_position = door1_pos
		"g2":
			door_1.enabled = false
			door_2.enabled = true
			door_3.enabled = false
			class_room_entrance.global_position = door2_pos
		"g3":
			door_1.enabled = false
			door_2.enabled = false
			door_3.enabled = true
			class_room_entrance.global_position = door3_pos


func _on_class_class_end(_currentGrade: String, _currentLesson: String) -> void:
	_update_door()
