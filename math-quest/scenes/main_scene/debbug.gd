extends MeshInstance2D

@export var follow_target : CharacterBody2D

#func _process(_delta: float) -> void:
	#if follow_target:
		#global_position = follow_target.global_position
