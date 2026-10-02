extends Control

@onready var play_btn: Button = %play
@onready var continue_btn: Button = %continue
@onready var quit_btn: Button = %quit
@onready var setting: Button = %setting

@onready var popup_bg: PanelContainer = %popup_bg
@onready var popup: PanelContainer = %popup

@onready var title: TextureRect = %title
@onready var btns: VBoxContainer = %btns
@onready var save_slots: Panel = %save_slots

@onready var slot_1: Button = %slot1
@onready var slot_2: Button = %slot2
@onready var slot_3: Button = %slot3
@onready var slot_container: HBoxContainer = %slot_container
@onready var transition_fx: TransitionFX = %TransitionFx

const HOVER_SCALE_MULTIPLIER = 1.05 
const TWEEN_DURATION = 0.15

func _ready() -> void:
	var res = db.query("SELECT * FROM progress LIMIT 3")
	for slot_num in range(1, 4):
		var btn = slot_container.get_node_or_null("slot%s" % slot_num)
		if btn:
			var data_idx = slot_num - 1
			if res.code >= 200 and res.code <= 299 and data_idx < res.data.size():
				btn.text = "Chapter %s" % res.data[data_idx].current_chapter
				btn.disabled = false
			else:
				btn.text = "Empty Slot"
				btn.disabled = true

	popup_bg.hide()
	save_slots.hide() 
	
	# Verify whether an active save slot exists and set the continue button state
	_update_continue_button_state()
	
	_setup_child_hover_scale(play_btn)
	_setup_child_hover_scale(continue_btn)
	_setup_child_hover_scale(setting)
	_setup_child_hover_scale(quit_btn)

	_apply_disabled_dark_mode(play_btn)
	_apply_disabled_dark_mode(continue_btn)
	_apply_disabled_dark_mode(setting)
	_apply_disabled_dark_mode(quit_btn)

func handle_progress():
	
	var next_scene_path : String = ""
	
	var res = db.query("SELECT id FROM checklist WHERE chapter = (SELECT current_chapter FROM progress WHERE is_active = true) LIMIT 1")
	if int(res.data[0].id) <= 2:
		next_scene_path = "res://scenes/main_scene/mian_scene.tscn"
	else:
		next_scene_path = "res://scenes/main_scene/world.tscn"
	GameManager.next_scene = next_scene_path
	GameManager.custom_loading_screen = "Loading..."
	GameManager.extend_loading = false
	
	get_tree().change_scene_to_file("res://core/components/loading/loading_screen.tscn")

func _setup_child_hover_scale(button: Button) -> void:
	if button.get_child_count() == 0:
		return
		
	var child_node = button.get_child(0)
	var base_scale = child_node.scale 
	
	#button.get_child(0).pivot_offset.x = button.get_child(0).size.x / 2
	#button.get_child(0).pivot_offset.y = button.get_child(0).size.y / 2
	
	button.mouse_entered.connect(func():
		if button.disabled:
			return
			
		var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(child_node, "scale", base_scale * HOVER_SCALE_MULTIPLIER, TWEEN_DURATION)
	)
	
	button.mouse_exited.connect(func():
		var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(child_node, "scale", base_scale, TWEEN_DURATION)
	)

func _apply_disabled_dark_mode(button: Button) -> void:
	if button.disabled:
		button.modulate = Color(0.4, 0.4, 0.4, 1.0)
	else:
		button.modulate = Color(1.0, 1.0, 1.0, 1.0)

func set_button_disabled(button: Button, is_disabled: bool) -> void:
	button.disabled = is_disabled
	_apply_disabled_dark_mode(button)

# Checks database for any active progress slot and updates continue button interactability
func _update_continue_button_state() -> void:
	var check_active = db.query("SELECT id FROM progress WHERE is_active = true LIMIT 1")
	var has_active_slot = check_active.code >= 200 and check_active.code <= 299 and check_active.data.size() > 0
	set_button_disabled(continue_btn, not has_active_slot)

func _on_play_pressed() -> void:
	title.hide()
	btns.hide()
	
	save_slots.visible = true
	save_slots.scale = Vector2.ZERO
	save_slots.pivot_offset = save_slots.size / 2.0
	
	var tween = create_tween()
	tween.tween_property(save_slots, "scale", Vector2(1.1, 1.1), 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(save_slots, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_continue_pressed() -> void:
	transition_fx.transition = true

func _on_quit_pressed() -> void:
	popup_bg.visible = true
	popup_bg.modulate.a = 0.0
	
	popup.visible = true
	popup.scale = Vector2.ZERO
	popup.pivot_offset = popup.size / 2.0
	
	var tween = create_tween()
	
	tween.parallel().tween_property(popup_bg, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(popup, "scale", Vector2(1.1, 1.1), 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(popup, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_cancel_quit_pressed() -> void:
	var tween = create_tween()
	
	tween.parallel().tween_property(popup, "scale", Vector2.ZERO, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(popup_bg, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	tween.tween_callback(func():
		popup_bg.hide()
		popup.hide()
	)

func _on_quit_confirm_pressed() -> void:
	get_tree().quit()

func _on_close_slots_pressed() -> void:
	var tween = create_tween()
	tween.tween_property(save_slots, "scale", Vector2.ZERO, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	tween.tween_callback(func():
		save_slots.hide()
		title.show()
		btns.show()
	)

func _set_active_slot(slot_id: int) -> void:
	db.query("UPDATE progress SET is_active = false WHERE id != %d" % slot_id)
	db.query("UPDATE progress SET is_active = true WHERE id = %d" % slot_id)
	_update_continue_button_state()
	
	transition_fx.transition = true

func _on_slot_1_pressed() -> void:
	_set_active_slot(1)

func _on_slot_2_pressed() -> void:
	_set_active_slot(2)

func _on_slot_3_pressed() -> void:
	_set_active_slot(3)


func _on_transition_fx_transition_in_complete() -> void:
	handle_progress()
