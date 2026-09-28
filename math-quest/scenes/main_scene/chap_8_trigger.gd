extends Area2D

@export var node_chapter: Chapter8
@onready var chp_8_collider: CollisionShape2D = %chp8_collider

func _ready() -> void:
	chp_8_collider.disabled = true
	
	var data = db.query("SELECT is_done FROM checklist WHERE chapter = grade3_complete").data[0]
	if data.is_done:
		chp_8_collider.disabled = false

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		node_chapter.trigger_signal(Chapter8.signalType.Start)
		chp_8_collider.disabled = true


func _on_portal_portal_opened() -> void:
	chp_8_collider.disabled = true


func _on_class_class_end(currentGrade: String, currentLesson: String) -> void:
	if currentGrade == "g3" and currentLesson == "g3-l10":
		chp_8_collider.disabled = false
