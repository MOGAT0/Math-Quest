extends Control
class_name LoadingScreen

@onready var progress_bar: TextureProgressBar = %TextureProgressBar
@onready var load_percentage: Label = %load_percentage
@onready var loading_txt: RichTextLabel = %loading_txt
@onready var transition_fx: TransitionFX = %TransitionFx

@export var custom_loading_text : String = "Entering World..."

@export var extend_loading_time : bool
@export var extended_time : float

var progress : Array = []
var req_scene_path
var scene_load_status = 0

var _is_transitioning : bool = false 

@export var default_bg_color : Color

func _ready() -> void:
	RenderingServer.set_default_clear_color(default_bg_color)
	extend_loading_time = GameManager.extend_time
	extend_loading_time = GameManager.extend_loading
	loading_txt.text = "[pulse][wave]" + custom_loading_text + "[/wave][/pulse]"
	req_scene_path = GameManager.next_scene
	ResourceLoader.load_threaded_request(req_scene_path)

func _process(_delta: float) -> void:
	if _is_transitioning:
		return

	scene_load_status = ResourceLoader.load_threaded_get_status(req_scene_path, progress)

	match scene_load_status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_update_progress()
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("Failed to load scene: %s" % req_scene_path)
			# maybe show an error UI / retry button instead of hanging forever
		ResourceLoader.THREAD_LOAD_LOADED:
			_update_progress()
			_is_transitioning = true
			transition_fx.transition = true

func _update_progress() -> void:
	if progress.is_empty():
		return
	var percent = floor(progress[0] * 100)
	progress_bar.value = percent
	load_percentage.text = str(percent) + "%"

func _on_transition_fx_transition_in_complete() -> void:
	# NEW CODE: Retrieve the loaded scene and switch to it ONLY after the transition animation finishes
	var new_scene = ResourceLoader.load_threaded_get(req_scene_path)
	get_tree().change_scene_to_packed(new_scene)
	print("transitioned")

#extends Control
#class_name LoadingScreen
#
#@onready var progress_bar: TextureProgressBar = %TextureProgressBar
#@onready var load_percentage: Label = %load_percentage
#@onready var loading_txt: RichTextLabel = %loading_txt
#
#@export var custom_loading_text : String = "Entering World..."
#
#@export var extend_loading_time : bool
#@export var extended_time : float
#
#var progress : Array = []
#var req_scene_path
#var scene_load_status = 0
#
#var _is_transitioning : bool = false 
#
#@export var default_bg_color : Color
#
#func _ready() -> void:
	#RenderingServer.set_default_clear_color(default_bg_color)
	#extend_loading_time = GameManager.extend_time
	#extend_loading_time = GameManager.extend_loading
	#loading_txt.text = "[pulse][wave]" + custom_loading_text + "[/wave][/pulse]"
	#req_scene_path = GameManager.next_scene
	#ResourceLoader.load_threaded_request(req_scene_path)
#
#func _process(_delta: float) -> void:
	#if _is_transitioning:
		#return
#
	#scene_load_status = ResourceLoader.load_threaded_get_status(req_scene_path, progress)
#
	#match scene_load_status:
		#ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			#_update_progress()
		#ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			#push_error("Failed to load scene: %s" % req_scene_path)
			## maybe show an error UI / retry button instead of hanging forever
		#ResourceLoader.THREAD_LOAD_LOADED:
			#_update_progress()
			#_is_transitioning = true
			#var new_scene = ResourceLoader.load_threaded_get(req_scene_path)
			#get_tree().change_scene_to_packed(new_scene)
#
#func _update_progress() -> void:
	#if progress.is_empty():
		#return
	#var percent = floor(progress[0] * 100)
	#progress_bar.value = percent
	#load_percentage.text = str(percent) + "%"
#
#
#func _on_transition_fx_transition_in_complete() -> void:
	#pass # Replace with function body.
