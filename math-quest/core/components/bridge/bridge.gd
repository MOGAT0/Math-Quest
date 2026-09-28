extends Node2D

@export var fixed : bool = false

@onready var fixed_bridge: TileMapLayer = %fixed_bridge
@onready var broken_bridge: Sprite2D = %broken_bridge
@onready var magic_circle: Sprite2D = %MagicCircle
@onready var collision_shape_2d: CollisionShape2D = %CollisionShape2D

#func _process(_delta: float) -> void:
	#match QuestManager.is_quest_done("lumberjack","bridge fixed"):
		#true:
			#fixed_bridge.visible = true
			#broken_bridge.visible = false
			#magic_circle.visible = true
		#false:
			#magic_circle.visible = false
			#fixed_bridge.visible = false
			#broken_bridge.visible = true
			#
	#if QuestManager.is_quest_done("wizard","farewell"):
		#collision_shape_2d.disabled = true
		#magic_circle.visible = false
	#else:
		#collision_shape_2d.disabled = false
