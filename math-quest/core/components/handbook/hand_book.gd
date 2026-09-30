extends Control
class_name StarterHandBook

@onready var close_btn: Button = %close_btn


enum SignalType {
	Open, Close
}

func _trigger(value : SignalType) -> void:
	var is_done = db.query("SELECT is_done FROM checklist WHERE chapter = academy_interview")
	match value:
		SignalType.Open:
			if !is_done.data[0].is_done:
				show()
				MusicPlayer.tune_down = true
		SignalType.Close:
			hide()
			MusicPlayer.tune_down = false

func _on_close_btn_pressed() -> void:
	_trigger(SignalType.Close)
	
