extends Area2D

@onready var arith_sleeping: Sprite2D = %arith_sleeping

func _ready() -> void:
	arith_sleeping.hide()

func _on_body_entered(body: Node2D) -> void:
	if body is Arith:
		arith_sleeping.show()
		body.hide()


func _on_body_exited(body: Node2D) -> void:
	if body is Arith:
		#arith_sleeping.hide()
		pass


func _on_matthew_sleep_woke_up() -> void:
	arith_sleeping.hide()
