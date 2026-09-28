extends Node2D
class_name Portal

signal portal_spawned
signal spawn_complete
signal portal_opened

@onready var animation_tree: AnimationTree = %AnimationTree
@onready var portal_collider: CollisionShape2D = %portal_collider
@onready var collision: CollisionPolygon2D = %Collision

func _ready() -> void:
	portal_collider.disabled = true
	collision.disabled = true
	_update_state()
	#var is_done = db.query("SELECT open_portal FROM progress WHERE is_active = true")
	#if is_done.data[0].open_portal:
		#animation_tree["parameters/conditions/crystal_placed"] = true

func _update_state() -> void:

	var is_g3_completed = db.query("SELECT is_done FROM checklist WHERE chapter = grade3_complete")
	if is_g3_completed and is_g3_completed.data.size() > 0:
		if is_g3_completed.data[0].is_done:
			db.query("UPDATE progress SET open_portal = true WHERE is_active = true")
			db.query("UPDATE checklist SET is_done = true WHERE chapter = grade3_complete")
			animation_tree["parameters/conditions/crystal_placed"] = false
			portal_spawned.emit()
			await get_tree().create_timer(2).timeout
			animation_tree["parameters/conditions/portal_spawn"] = true


func _on_portal_detector_body_entered(body: Node2D) -> void:
	if body is Player:
		get_tree().change_scene_to_file("res://scenes/main_scene/final_part.tscn")


func _place_crystal() -> void:
	var is_done = db.query("SELECT open_portal FROM progress WHERE is_active = true")
	if is_done.data[0].open_portal:
		animation_tree["parameters/conditions/crystal_placed"] = true
	portal_collider.disabled = false
	collision.disabled = false

func _on_animation_tree_animation_finished(anim_name: StringName) -> void:
	if anim_name == "spawn_2":
		portal_opened.emit()
	elif anim_name == "spawn":
		spawn_complete.emit()

func _on_chapter_8_is_chapter_done(_chapter: String) -> void:
	_place_crystal()
