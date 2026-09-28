extends Control
class_name Reward

signal reward_trigger(reward_item: String)

@onready var desc: RichTextLabel = %desc
@onready var emerald_icon: PanelContainer = %emerald_icon
@onready var ruby_icon: PanelContainer = %ruby_icon
@onready var diamond_icon: PanelContainer = %diamond_icon

func _ready() -> void:
	hide()
	reward_trigger.connect(_on_reward_triggered)

func _on_reward_triggered(reward_item: String) -> void:
	show()
	pivot_offset = size / 2
	scale = Vector2.ZERO
	var pop_tween = create_tween()
	pop_tween.tween_property(self, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	match reward_item:
		"emerald":
			desc.text = "Emerald\n\n1 of 3 crystals requred to open the portal gate"
			emerald_icon.show()
			ruby_icon.hide()
			diamond_icon.hide()
		"ruby":
			desc.text = "Ruby\n\n2 of 3 crystals requred to open the portal gate"
			ruby_icon.show()
			emerald_icon.hide()
			diamond_icon.hide()
		"diamond":
			desc.text = "Diamond\n\n3 of 3 crystals requred to open the portal gate"
			diamond_icon.show()
			emerald_icon.hide()
			ruby_icon.hide()

func _on_exit_pressed() -> void:
	var close_tween = create_tween()
	close_tween.tween_property(self, "scale", Vector2.ZERO, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	close_tween.tween_callback(hide)




#func _unhandled_input(event: InputEvent) -> void:
	#if event is InputEventKey:
		#match event.keycode:
			#49:
				#reward_trigger.emit("emerald")
			#50:
				#reward_trigger.emit("ruby")
			#51:
				#reward_trigger.emit("diamond")
