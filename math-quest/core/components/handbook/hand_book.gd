extends Control
class_name StarterHandBook

@onready var close_btn: Button = %close_btn
@onready var _scroll_container_10: ScrollContainer = %_ScrollContainer_10

func _ready() -> void:
	close_btn.disabled = true

enum SignalType {
	Open, Close
}

func _process(_delta: float) -> void:
	if _scroll_container_10.scroll_vertical > 1900:
		close_btn.disabled = false

func _trigger(value : SignalType) -> void:
	var is_done = db.query("SELECT is_done FROM checklist WHERE chapter = academy_interview")
	match value:
		SignalType.Open:
			if !is_done.data[0].is_done:
				show()
		SignalType.Close:
			hide()

func _on_close_btn_pressed() -> void:
	_trigger(SignalType.Close)
