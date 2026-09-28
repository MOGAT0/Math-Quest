#player target location setter
extends Node2D

@export var player : Player


func _on_matthew_sleep_woke_up() -> void:
	var id = db.query("SELECT id FROM checklist WHERE is_done = true ORDER BY id DESC LIMIT 1")
	
	if player:
		if id.data[0].id >= 11:
			GameManager.target_location = %academy_gate
			
