extends Control
class_name LoadingScreen

@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var progress_bar: TextureProgressBar = %TextureProgressBar
@onready var load_percentage: Label = %load_percentage
@onready var loading_txt: RichTextLabel = %loading_txt
@onready var transition_fx: TransitionFX = %TransitionFx
@onready var loading_bar: ProgressBar = %loading_bar

@export var custom_loading_text : String = "Entering World..."
@onready var boot_splash: Control = %BootSplash

@export var load_world_scene : bool = false
@export var to_world_scene : bool = false
var is_bootsplash : bool = false 
@export_file("*.tscn") var bootsplash_next_scene : String = "res://scenes/main_menu/main_menu.tscn"
@export var default_bg_color : Color

const WORLD_PATH := "uid://lkcqsspo5mb6"

var _paths_to_load : Array[String] = []
var _progress : Dictionary = {}
var _is_transitioning : bool = false
var _intro_done : bool = true
var load_percent : String = ""

# Added start time tracking and an array to prevent console log spam
var _start_time_msec : int = 0
var _printed_loading_paths : Array[String] = []

func _ready() -> void:
	# Added tracking for when the loading starts
	_start_time_msec = Time.get_ticks_msec()
	
	MusicPlayer.stop()
	RenderingServer.set_default_clear_color(default_bg_color)

	if not GameManager.boot_done:
		is_bootsplash = true
		GameManager.boot_done = true
	
	boot_splash.visible = is_bootsplash
	if is_bootsplash:
		_setup_bootsplash()

	if to_world_scene:
		if GameManager.loaded_world_scene == null:
			_paths_to_load.append(WORLD_PATH)
	else:
		_paths_to_load.append(GameManager.next_scene)
		if load_world_scene:
			_paths_to_load.append(WORLD_PATH)

	for path in _paths_to_load:
		_progress[path] = []
		ResourceLoader.load_threaded_request(path)

	if is_bootsplash:
		print(is_bootsplash)
		animation_player.play("intro")

func _setup_bootsplash() -> void:
	GameManager.next_scene = bootsplash_next_scene
	load_world_scene = true
	to_world_scene = false

	progress_bar.hide()
	load_percentage.hide()

	_intro_done = false
	if not animation_player.animation_finished.is_connected(_on_animation_player_animation_finished):
		animation_player.animation_finished.connect(_on_animation_player_animation_finished)

	if OS.get_name().to_lower() in ["android", "ios"]:
		DisplayServer.window_set_size(Vector2i(1280, 720))
		get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name.to_lower() == "intro":
		_intro_done = true

func _process(_delta: float) -> void:
	if _is_transitioning:
		return

	loading_txt.text = "[pulse][wave]" + custom_loading_text + load_percent + "[/wave][/pulse]"

	var all_loaded := true
	var total := 0.0

	for path in _paths_to_load:
		var status := ResourceLoader.load_threaded_get_status(path, _progress[path])
		match status:
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				all_loaded = false
				if not _progress[path].is_empty():
					total += _progress[path][0]
				
				# Added log to print what node is currently loading
				if not _printed_loading_paths.has(path):
					print("Currently loading: ", path)
					_printed_loading_paths.append(path)
					
			ResourceLoader.THREAD_LOAD_LOADED:
				total += 1.0
				
				# Added safety log in case loading finished instantly in one frame
				if not _printed_loading_paths.has(path):
					print("Currently loading: ", path)
					_printed_loading_paths.append(path)
					
			_:
				push_error("Failed to load scene: %s" % path)
				return

	var count := _paths_to_load.size()
	_update_progress(1.0 if count == 0 else total / count)

	if all_loaded and _intro_done:
		var elapsed_ms: int = Time.get_ticks_msec() - _start_time_msec
		print("Total load time: ", elapsed_ms, " ms")
		
		_is_transitioning = true
		transition_fx.transition = true

func _update_progress(value: float) -> void:
	var percent := floori(value * 100.0)
	progress_bar.value = percent
	loading_bar.value = percent
	load_percentage.text = str(percent) + "%"
	load_percent = str(percent) + "%"

func _on_transition_fx_transition_in_complete() -> void:
	#MusicPlayer._play_current()
	if to_world_scene:
		var world : PackedScene = GameManager.loaded_world_scene
		if world == null:
			world = ResourceLoader.load_threaded_get(WORLD_PATH)
		GameManager.loaded_world_scene = null
		get_tree().change_scene_to_packed(world)
		return

	if load_world_scene:
		GameManager.loaded_world_scene = ResourceLoader.load_threaded_get(WORLD_PATH)

	var new_scene : PackedScene = ResourceLoader.load_threaded_get(GameManager.next_scene)
	get_tree().change_scene_to_packed(new_scene)

#extends Control
#class_name LoadingScreen
#
#@onready var animation_player: AnimationPlayer = %AnimationPlayer
#@onready var progress_bar: TextureProgressBar = %TextureProgressBar
#@onready var load_percentage: Label = %load_percentage
#@onready var loading_txt: RichTextLabel = %loading_txt
#@onready var transition_fx: TransitionFX = %TransitionFx
#@onready var loading_bar: ProgressBar = %loading_bar
#
#@export var custom_loading_text : String = "Entering World..."
#@onready var boot_splash: Control = %BootSplash
#
#@export var load_world_scene : bool = false
#@export var to_world_scene : bool = false
#var is_bootsplash : bool = false 
#@export_file("*.tscn") var bootsplash_next_scene : String = "res://scenes/main_menu/main_menu.tscn"
#@export var default_bg_color : Color
#
#const WORLD_PATH := "uid://lkcqsspo5mb6"
#
#var _paths_to_load : Array[String] = []
#var _progress : Dictionary = {}
#var _is_transitioning : bool = false
#var _intro_done : bool = true
#var load_percent : String = ""
#
#func _ready() -> void:
	#MusicPlayer.stop()
	#RenderingServer.set_default_clear_color(default_bg_color)
#
	#if not GameManager.boot_done:
		#is_bootsplash = true
		#GameManager.boot_done = true
	#
	#boot_splash.visible = is_bootsplash
	#if is_bootsplash:
		#
		#_setup_bootsplash()
#
	#if to_world_scene:
		#if GameManager.loaded_world_scene == null:
			#_paths_to_load.append(WORLD_PATH)
	#else:
		#_paths_to_load.append(GameManager.next_scene)
		#if load_world_scene:
			#_paths_to_load.append(WORLD_PATH)
#
	#for path in _paths_to_load:
		#_progress[path] = []
		#ResourceLoader.load_threaded_request(path)
#
	#if is_bootsplash:
		#print(is_bootsplash)
		#animation_player.play("intro")
#
#func _setup_bootsplash() -> void:
	#GameManager.next_scene = bootsplash_next_scene
	#load_world_scene = true
	#to_world_scene = false
#
	#progress_bar.hide()
	#load_percentage.hide()
#
	#_intro_done = false
	#if not animation_player.animation_finished.is_connected(_on_animation_player_animation_finished):
		#animation_player.animation_finished.connect(_on_animation_player_animation_finished)
#
	#if OS.get_name().to_lower() in ["android", "ios"]:
		#DisplayServer.window_set_size(Vector2i(1252, 648))
		#get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		#get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
#
#func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	#if anim_name.to_lower() == "intro":
		#_intro_done = true
#
#func _process(_delta: float) -> void:
	#if _is_transitioning:
		#return
#
	#loading_txt.text = "[pulse][wave]" + custom_loading_text + load_percent + "[/wave][/pulse]"
#
	#var all_loaded := true
	#var total := 0.0
#
	#for path in _paths_to_load:
		#var status := ResourceLoader.load_threaded_get_status(path, _progress[path])
		#match status:
			#ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				#all_loaded = false
				#if not _progress[path].is_empty():
					#total += _progress[path][0]
			#ResourceLoader.THREAD_LOAD_LOADED:
				#total += 1.0
			#_:
				#push_error("Failed to load scene: %s" % path)
				#return
#
	#var count := _paths_to_load.size()
	#_update_progress(1.0 if count == 0 else total / count)
#
	#if all_loaded and _intro_done:
		#_is_transitioning = true
		#transition_fx.transition = true
#
#func _update_progress(value: float) -> void:
	#var percent := floori(value * 100.0)
	#progress_bar.value = percent
	#loading_bar.value = percent
	#load_percentage.text = str(percent) + "%"
	#load_percent = str(percent) + "%"
#
#func _on_transition_fx_transition_in_complete() -> void:
	##MusicPlayer._play_current()
	#if to_world_scene:
		#var world : PackedScene = GameManager.loaded_world_scene
		#if world == null:
			#world = ResourceLoader.load_threaded_get(WORLD_PATH)
		#GameManager.loaded_world_scene = null
		#get_tree().change_scene_to_packed(world)
		#return
#
	#if load_world_scene:
		#GameManager.loaded_world_scene = ResourceLoader.load_threaded_get(WORLD_PATH)
#
	#var new_scene : PackedScene = ResourceLoader.load_threaded_get(GameManager.next_scene)
	#get_tree().change_scene_to_packed(new_scene)
