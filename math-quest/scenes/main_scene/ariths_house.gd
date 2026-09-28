extends Area2D

@onready var ariths_entrance_collider: CollisionShape2D = %ariths_entrance_collider


@export var next_loc : Marker2D
@export var arithsbed : Marker2D
@onready var transition_fx: TransitionFX = %TransitionFx

func _ready() -> void:
	ariths_entrance_collider.disabled = true

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		teleport(body,next_loc.global_position)
	if body is Arith:
		teleport(body,next_loc.global_position)
		await get_tree().process_frame
		GameManager.arith_goto = arithsbed.global_position
		GameManager.target_location = arithsbed

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		pass

func teleport(character: CharacterBody2D, location: Vector2) -> void:
	character.set_deferred("global_position", location)
	if character is Player and transition_fx:
		await get_tree().process_frame
		transition_fx.transition = true

func _on_chapter_7_is_chapter_done(_chapter: String) -> void:
	await get_tree().process_frame
	ariths_entrance_collider.disabled = false
	
