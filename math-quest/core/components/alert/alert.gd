extends Control
class_name AlertPanel
# Added: Export variables for the trigger and the wait duration
@export var display_duration: float = 2.0
@export var alert: bool = false:
	set(value):
		alert = value
		if alert and is_node_ready():
			_play_popup_animation()

@onready var popup: PanelContainer = %popup

# Added: Tween reference to prevent animation glitches if triggered multiple times quickly
var _alert_tween: Tween

func _ready() -> void:
	# Added: Hide the popup by default on start
	popup.modulate.a = 0.0
	popup.hide()
	hide()

# Added: The animation logic
func _play_popup_animation() -> void:
	if _alert_tween and _alert_tween.is_valid():
		_alert_tween.kill()
	
	popup.show()
	show()
	popup.modulate.a = 1.0 
	
	_alert_tween = create_tween()
	_alert_tween.tween_interval(display_duration)
	_alert_tween.tween_property(popup, "modulate:a", 0.0, 0.5) 
	_alert_tween.tween_callback(func():
		popup.hide()
		alert = false
	)
