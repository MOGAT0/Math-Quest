extends CharacterBody2D
class_name Wizard

@export var chapter_node : Chapter4

func _on_player_detector_body_entered(body: Node2D) -> void:
	if chapter_node and body is Player:
		chapter_node.trigger_signal(Chapter4.signalType.Start)
		
		await get_tree().create_timer(0.5).timeout
		%detector_collider.disabled = true
	


func _on_chapter_5_is_chapter_done(_chapter: String) -> void:
	hide()
