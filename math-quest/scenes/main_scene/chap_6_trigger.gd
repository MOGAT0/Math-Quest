extends Area2D

@export var chapter_node : Chapter6

@onready var trigger_collider: CollisionShape2D = %trigger_collider6


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		chapter_node.trigger_signal(Chapter6.signalType.Start)
		
		await get_tree().process_frame
		trigger_collider.disabled = true


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		pass
