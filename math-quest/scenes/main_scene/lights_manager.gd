extends Node2D

func _ready() -> void:
	GameManager.hour_changed.connect(_on_hour_changed)
	for c in get_children():
		if c is Node2D:
			c.hide()
	
func _on_hour_changed(time : int) -> void:
	for c in get_children():
		if c is Node2D:
			if time >= 18 or time <= 2:
				c.show()
			else:
				c.hide()
