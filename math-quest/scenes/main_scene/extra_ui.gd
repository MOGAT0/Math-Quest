extends Control

@onready var fndnl_book: Button = %fndnl_book

func _ready() -> void:
	fndnl_book.hide()

func _on_chapter_5_is_chapter_done(_chapter: String) -> void:
	await get_tree().process_frame
	fndnl_book.show()
