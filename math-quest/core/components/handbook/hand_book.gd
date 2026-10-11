extends Control
class_name StarterHandBook

@onready var close_btn: Button = %close_btn

@export var global_font_size: int = 25

@onready var scroll: ScrollContainer = %ScrollContainer  # your scroll container
@onready var content: Control = %Content   

func _ready() -> void:
	_apply_font_size(self, global_font_size)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.custom_minimum_size.x = 0

func _apply_font_size(node: Node, font_size: int) -> void:
	for child in node.get_children():
		if child is RichTextLabel:
			child.add_theme_font_size_override("normal_font_size", font_size)
			child.add_theme_font_size_override("bold_font_size", font_size)
			child.add_theme_font_size_override("italics_font_size", font_size)
			child.add_theme_font_size_override("bold_italics_font_size", font_size)
			child.add_theme_font_size_override("mono_font_size", font_size)
			child.fit_content = true
			child.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		elif child is Label:
			child.add_theme_font_size_override("font_size", font_size)
			child.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		elif child is Button:
			child.add_theme_font_size_override("font_size", font_size)
		_apply_font_size(child, font_size)


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
	
