extends Area2D

@export var chapter_node : Chapter5

@onready var trigger_collider: CollisionShape2D = %trigger_collider

var arith_entered : bool = false
var player_entered : bool = false

func _process(_delta: float) -> void:
	if arith_entered:
		if trigger_collider.shape is CircleShape2D:
			trigger_collider.shape.radius = 30
		if player_entered and chapter_node:
			chapter_node.trigger_signal(Chapter5.signalType.Start)
			trigger_collider.disabled = true #forgot to add this
		
	elif !player_entered and !arith_entered:
		if trigger_collider.shape is CircleShape2D:
			trigger_collider.shape.radius = 10


func _on_body_entered(body: Node2D) -> void:
	if body is Arith:
		arith_entered = true
	elif body is Player:
		player_entered = true


func _on_body_exited(body: Node2D) -> void:
	if body is Arith:
		arith_entered = false
	elif body is Player:
		player_entered = false
