extends Area2D


@export var transition_timer: float = 1.0
enum TransitionType {
	ENTER,
	EXIT
}
@export var current_transition : TransitionType = TransitionType.ENTER

@export var next_scene : String = ""
@onready var animation_player: AnimationPlayer = %AnimationPlayer

func _ready() -> void:
	animation_player.play("_enter")

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		animation_player.play("_exit")
		await get_tree().create_timer(0.6).timeout
		get_tree().change_scene_to_file(next_scene)


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		pass
