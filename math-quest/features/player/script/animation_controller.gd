@icon("res://animation_controller_node_icon_.png")
extends Node
class_name AnimationController

@export var player: CharacterBody2D
@export var animation_player: AnimationPlayer

enum PlayerDir {
	UP,
	DOWN,
	LEFT,
	RIGHT
}

var current_dir: PlayerDir = PlayerDir.DOWN

func _process(_delta: float) -> void:
	if player.velocity == Vector2.ZERO:
		animation_player.play("idle")
		return

	# NEW: Compares absolute velocity to approximate the primary movement axis.
	# Using >= ensures Left/Right takes priority when X and Y magnitudes are equal (e.g., perfect diagonals).
	if abs(player.velocity.x) >= abs(player.velocity.y):
		current_dir = PlayerDir.LEFT if player.velocity.x < 0 else PlayerDir.RIGHT
	else:
		current_dir = PlayerDir.UP if player.velocity.y < 0 else PlayerDir.DOWN
		
	# {to-do} If analog stick drift causes the character to snap to left/right when you intend to move purely up/down, add a deadzone threshold check to the raw input before it becomes velocity
	
	walk_direction(current_dir)
	
func walk_direction(_dir:PlayerDir):
	match _dir:
		PlayerDir.UP:
			animation_player.play("walk_up")
		PlayerDir.DOWN:
			animation_player.play("walk_down")
		PlayerDir.LEFT:
			animation_player.play("walk_left")
		PlayerDir.RIGHT:
			animation_player.play("walk_right")
