extends Area2D

@export var node_chapter: Chapter7
@onready var trigger_collider_7: CollisionShape2D = %trigger_collider7

func _ready() -> void:
	trigger_collider_7.disabled = true


func _on_entrance_exam_is_chapter_done() -> void:
	await get_tree().create_timer(0.2).timeout
	trigger_collider_7.disabled = false
	


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		if node_chapter:
			node_chapter.trigger_signal(Chapter7.signalType.Start)


func _on_chapter_7_is_chapter_done() -> void:
	await get_tree().process_frame
	trigger_collider_7.disabled = true
