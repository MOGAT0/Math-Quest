extends Control
class_name EntranceExam

signal isChapter_Done

@onready var page_1: ScrollContainer = %page1
@onready var page_2: ScrollContainer = %page2
@onready var page_3: ScrollContainer = %page3
@onready var page_4: ScrollContainer = %page4

@onready var tab_btn_container: HBoxContainer = %tab_btn_container

enum SignalType {
	Open, Close
}

var tabs: Array[Dictionary] = []

func _ready() -> void:
	_trigger(SignalType.Open)
	#var is_done = db.query("SELECT is_done FROM checklist WHERE chapter = school_admission")
	#if is_done.data[0].is_done:
		#_trigger(SignalType.Close)
		#isChapter_Done.emit()
	
	tabs = [
		{"button": tab_btn_container.get_node("page1"), "page": page_1},
		{"button": tab_btn_container.get_node("page2"), "page": page_2},
		{"button": tab_btn_container.get_node("page3"), "page": page_3},
		{"button": tab_btn_container.get_node("page4"), "page": page_4}
	]
	
	for tab in tabs:
		tab.button.toggled.connect(_on_tab_toggled.bind(tab.page))
		tab.page.visible = tab.button.button_pressed

func _on_tab_toggled(toggled_on: bool, active_page: ScrollContainer) -> void:
	if toggled_on:
		for tab in tabs:
			tab.page.visible = (tab.page == active_page)

func _trigger(value : SignalType) -> void:
	match value:
		SignalType.Open:
			var is_done = db.query("SELECT is_done FROM checklist WHERE chapter = school_admission")
			if !is_done.data[0].is_done:
				show()
		SignalType.Close:
			hide()

func _on_next_2_page_2_pressed() -> void:
	var btn = tab_btn_container.get_node("page2") as Button
	btn.toggled.emit(true)
	btn.button_pressed = true


func _on_next_2_page_3_pressed() -> void:
	var btn = tab_btn_container.get_node("page3") as Button
	btn.toggled.emit(true)
	btn.button_pressed = true


func _on_next_2_page_4_pressed() -> void:
	var btn = tab_btn_container.get_node("page4") as Button
	btn.toggled.emit(true)
	btn.button_pressed = true


func _on_next_2_page_1_pressed() -> void:
	var btn = tab_btn_container.get_node("page1") as Button
	btn.toggled.emit(true)
	btn.button_pressed = true


func _on_close_pressed() -> void:
	isChapter_Done.emit()
	_trigger(SignalType.Close)
