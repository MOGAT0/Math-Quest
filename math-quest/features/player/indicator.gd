extends Sprite2D

@export var target : Node2D

func _ready() -> void:
	await get_tree().process_frame
	if GameManager.next_quest_marker == null:return
	target = GameManager.next_quest_marker

func _process(_delta: float) -> void:
	if !GameManager.next_quest_marker:return
	look_at(GameManager.next_quest_marker.global_position)
