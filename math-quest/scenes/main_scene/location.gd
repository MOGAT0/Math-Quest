#player target location setter
extends Node2D

@export var player : Player
@export var academy_gate : Marker2D
@export var portal_pos : Marker2D
@export var classRoom_entrance : Marker2D

var matthew_in_school : bool = false

func _ready() -> void:
	final_dir()

func _on_matthew_sleep_woke_up() -> void:
	final_dir()
			
func _on_matthew_sleep_is_chapter_done(_chapter: String) -> void:
	final_dir()
	
func final_dir() -> void:
	var check_status = db.query("SELECT is_done FROM checklist WHERE chapter = home_sleep_1")
	var portal_open = db.query("SELECT open_portal FROM progress WHERE is_active = true")
	
	if player:
		if check_status.data[0].is_done:
			if matthew_in_school:
				GameManager.target_location = classRoom_entrance
			else:
				GameManager.target_location = academy_gate if !portal_open.data[0].open_portal else portal_pos


func _on_matthew_in_school_body_entered(body: Node2D) -> void:
	if body is Player:
		matthew_in_school = true
		final_dir()

func _on_matthew_in_school_body_exited(body: Node2D) -> void:
	if body is Player:
		matthew_in_school = false
		final_dir()
