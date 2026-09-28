@tool
extends CanvasLayer
class_name TransitionFX

signal transitionIn_complete
signal transitionOut_complete

@export_group("Extension")
@export var extend_time : float = 0.0
@export var allow_time_extend : bool = false
@export_group("Transition")
@export var on_load_transition : bool = false
@export var transition : bool = false:
	set(value):
		transition = value
		if transition and is_node_ready():
			animation_player.play("transition_in")
			transition = false

@onready var animation_player: AnimationPlayer = %AnimationPlayer

func _ready() -> void:
	if on_load_transition:
		animation_player.play("transition_out")

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "transition_in":
		transitionIn_complete.emit()
		if allow_time_extend:
			await get_tree().create_timer(extend_time).timeout
		animation_player.play("transition_out")
	elif anim_name == "transition_out":
		transitionOut_complete.emit()
		print("out")
