extends Node2D

signal cutscene_started
signal cutscene_ended

@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var world_cam: Camera2D = %world_cam
@onready var cenematic_style: Control = %cenematic_style
@onready var cam_target_: Marker2D = %cam_target_
@onready var portal: Node2D = %Portal

func _ready() -> void:
	cenematic_style.hide()
	
func _initialize_cam():
	world_cam.enabled = true
	world_cam.make_current()
	cenematic_style.show()
	if get_tree().current_scene.get_node("Player"):
		world_cam.global_position = get_tree().current_scene.get_node("Player").global_position

func _start_cenematic(timer : float):
	cutscene_started.emit()
	await get_tree().create_timer(timer).timeout
	_initialize_cam()
	portal._update_state()
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(world_cam, "global_position", cam_target_.global_position, 2.0)
	
	await get_tree().create_timer(5).timeout
	world_cam.enabled = false
	cenematic_style.hide()
	cutscene_ended.emit()

func _on_class_class_end(currentGrade: String, currentLesson: String) -> void:
	if currentGrade == "g3" and currentLesson == "g3-l10":
		_start_cenematic(1.0)
		db.query("UPDATE checklist SET is_done = true WHERE chapter = grade3_complete")


func _on_chapter_8_is_chapter_done(chapter: String) -> void:
	_start_cenematic(0)
