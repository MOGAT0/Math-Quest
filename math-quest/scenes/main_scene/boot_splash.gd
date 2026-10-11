#intro
extends Control

func _ready() -> void:
	if OS.get_name().to_lower() in ["android", "ios"]:
		DisplayServer.window_set_size(Vector2i(1252, 648))
		get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name.to_lower() == "intro":
		#GameManager.next_scene = "res://scenes/main_menu/main_menu.tscn"
		#get_tree().change_scene_to_file("res://core/components/loading/loading_screen.tscn")
		GameManager.go_to_loading("res://scenes/main_menu/main_menu.tscn", true)
