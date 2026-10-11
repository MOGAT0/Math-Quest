extends Node2D

@onready var classroom: Scholl = %Class

func _ready() -> void:
	classroom.start_class()


func _on_class_class_end(_currentGrade: String, _currentLesson: String) -> void:
	get_tree().change_scene_to_file("res://scenes/main_scene/final_part.tscn")
