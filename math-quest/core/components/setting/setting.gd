extends Control

@onready var panel_cont: Control = %panel_cont
@onready var setting_btn: Button = %setting_btn
@onready var pause_cont: Control = %pause_cont
@onready var credit_cont: Control = %credit_cont
@onready var music_slider: HSlider = %music_slider

@export var use_external_button : bool = false
@export var external_button : Button

var Master = AudioServer.get_bus_index("Master")
var SFX = AudioServer.get_bus_index("SFX")
var Music = AudioServer.get_bus_index("Music")

var pop_tween: Tween

func _ready() -> void:
	show()
	panel_cont.scale = Vector2.ZERO
	panel_cont.pivot_offset = panel_cont.size / 2 
	panel_cont.hide()

	pause_cont.scale = Vector2.ZERO
	pause_cont.pivot_offset = pause_cont.size / 2
	pause_cont.hide()
	
	# --- Added code: Setup credit container initialization ---
	credit_cont.scale = Vector2.ZERO
	credit_cont.pivot_offset = credit_cont.size / 2
	credit_cont.hide()
	# ---------------------------------------------------------

	# --- Added code: Setup external button logic ---
	if use_external_button:
		setting_btn.hide()
		if external_button:
			external_button.pressed.connect(_on_setting_btn_pressed)
	# -----------------------------------------------

	AudioServer.set_bus_volume_db(SFX, linear_to_db(1.0))
	AudioServer.set_bus_volume_db(Master, linear_to_db(1.0))
	AudioServer.set_bus_volume_db(Music, linear_to_db(MusicPlayer.NORMAL_VOLUME))
	music_slider.max_value = MusicPlayer.NORMAL_VOLUME
	music_slider.value = MusicPlayer.NORMAL_VOLUME
	


func _on_setting_btn_pressed() -> void:
	var current_scn = get_tree().current_scene.name.to_lower()
	
	# This hides the original button. If using the external button, 
	# it remains visible since this only targets setting_btn.
	setting_btn.hide()
	
	if pop_tween and pop_tween.is_valid():
		pop_tween.kill()
		
	pop_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if current_scn != "mainmenu":
		pause_cont.show()
		pop_tween.tween_property(pause_cont, "scale", Vector2.ONE, 0.3)
	else:
		panel_cont.show()
		pop_tween.tween_property(panel_cont, "scale", Vector2.ONE, 0.3)


func _on_close_btn_pressed() -> void:
	# --- Added code: Prevent showing default button if external is used ---
	if not use_external_button:
		setting_btn.show()
	# ----------------------------------------------------------------------
	
	if pop_tween and pop_tween.is_valid():
		pop_tween.kill()
		
	pop_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

	if pause_cont.visible:
		pop_tween.tween_property(pause_cont, "scale", Vector2.ZERO, 0.3)
		pop_tween.tween_callback(pause_cont.hide)
	elif panel_cont.visible:
		pop_tween.tween_property(panel_cont, "scale", Vector2.ZERO, 0.3)
		pop_tween.tween_callback(panel_cont.hide)


func _on_continue_pressed() -> void:
	_on_close_btn_pressed()


func _on_setting_pressed() -> void:
	if pop_tween and pop_tween.is_valid():
		pop_tween.kill()
		
	pause_cont.hide()
	pause_cont.scale = Vector2.ZERO
	
	panel_cont.show()
	pop_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop_tween.tween_property(panel_cont, "scale", Vector2.ONE, 0.3)


func _on_exit_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")


func _on_master_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(Master, linear_to_db(value))


func _on_music_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(Music, linear_to_db(value))


func _on_sfx_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(SFX, linear_to_db(value))


func _on_clear_data_pressed() -> void:
	var confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.dialog_text = "Are you sure you want to clear all save data? This cannot be undone."
	confirm_dialog.title = "Confirm Clear Data"
	
	add_child(confirm_dialog)
	
	confirm_dialog.confirmed.connect(_on_clear_data_confirmed)
	
	confirm_dialog.canceled.connect(confirm_dialog.queue_free)
	confirm_dialog.confirmed.connect(confirm_dialog.queue_free)
	
	confirm_dialog.popup_centered()

func _on_clear_data_confirmed() -> void:
	DataManager.clear_data()
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")

func _on_credits_pressed() -> void:
	# --- Added code: Animate opening the credits and hiding settings ---
	if pop_tween and pop_tween.is_valid():
		pop_tween.kill()
		
	panel_cont.hide()
	panel_cont.scale = Vector2.ZERO
	
	credit_cont.show()
	pop_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop_tween.tween_property(credit_cont, "scale", Vector2.ONE, 0.3)
	# -------------------------------------------------------------------


func _on_close_credit_pressed() -> void:
	# --- Added code: Animate closing the credits and showing settings ---
	if pop_tween and pop_tween.is_valid():
		pop_tween.kill()
		
	pop_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	
	pop_tween.tween_property(credit_cont, "scale", Vector2.ZERO, 0.3)
	pop_tween.tween_callback(credit_cont.hide)
	
	# Transition back to the settings panel
	pop_tween.tween_callback(panel_cont.show)
	pop_tween.tween_property(panel_cont, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# --------------------------------------------------------------------


func _on_export_analysis_pressed() -> void:
	if AnalysisReport.get_attempts().is_empty():
		_show_message("No analysis data yet. Finish a few lessons first!")
		return

	if not AnalysisReport.report_exported.is_connected(_on_report_exported):
		AnalysisReport.report_exported.connect(_on_report_exported)
	if not AnalysisReport.share_requested.is_connected(_on_share_requested):
		AnalysisReport.share_requested.connect(_on_share_requested)

	AnalysisReport.pick_folder_and_export()


func _on_report_exported(summary_path: String) -> void:
	if AnalysisReport._fell_back_to_private:
		return   # share_requested handles this case
	_show_message("Report saved to:\n%s" % summary_path.get_base_dir())


func _on_share_requested(paths: PackedStringArray) -> void:
	_show_message("Report Saved to %s" % paths)


func _show_message(text: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Export Analysis"
	dialog.dialog_text = text
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()
