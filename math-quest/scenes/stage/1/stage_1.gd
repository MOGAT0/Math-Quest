extends Node2D

@onready var wizard_marker: Marker2D = %wizard_marker
@onready var lumberjack_marker: Marker2D = %lumberjack_marker
@onready var bridge_marker: Marker2D = %bridge_marker
@onready var merchant_marker: Marker2D = %merchant_marker
@onready var tower_marker: Marker2D = %tower_marker


func _ready() -> void:
	#QuestManager.reset_all_quests()
	# 1. Connect to the QuestManager signals so the marker updates automatically!
	#QuestManager.quest_updated.connect(_on_quest_changed)
	#QuestManager.quest_completed.connect(_on_quest_changed)
	
	# 2. Run it once on startup to place the marker immediately based on the save file
	GameManager.next_quest_marker = wizard_marker

# This triggers every time dialogue advances, a quest starts, or a quest ends
func _on_quest_changed(_npc_name: String, _quest_name: String) -> void:
	update_quest_marker()

func update_quest_marker() -> void:
	pass
	#var active_quest = QuestManager.get_active_quest()
	#print(active_quest)
	#if active_quest.size() > 0:
		#if QuestManager.is_quest_active("wizard", "deliver materials") and active_quest.data.current_dialogue == active_quest.data.dialogue.size() -1:
			#GameManager.next_quest_marker = tower_marker
		#elif QuestManager.is_quest_done("wizard","farewell"):
			#GameManager.next_quest_marker = bridge_marker
		#else:
			#match active_quest.npc_name:
				#"wizard":
					#GameManager.next_quest_marker = wizard_marker
				#"lumberjack":
					#GameManager.next_quest_marker = lumberjack_marker
				#"merchant":
					#GameManager.next_quest_marker = merchant_marker
				#_:
					#GameManager.next_quest_marker = null
	#else:
		#if QuestManager.is_quest_done("wizard","farewell"):
			#GameManager.next_quest_marker = bridge_marker
		#
	
	
