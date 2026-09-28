extends Control
class_name Letter

@onready var letter_content: RichTextLabel = %letter_content

func _ready() -> void:
	hide()

func open_letter():
	letter_state(true)

func letter_state(is_open : bool):
	var tween = create_tween()
	if is_open:
		visible = true
		scale = Vector2.ZERO
		tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "scale", Vector2.ONE, 0.3)
	else:
		tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_property(self, "scale", Vector2.ZERO, 0.3)
		tween.tween_callback(func(): visible = false)

func _on_close_btn_pressed() -> void:
	letter_state(false)
