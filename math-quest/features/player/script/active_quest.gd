extends Label

func _process(_delta: float) -> void:
	if text == "":
		get_parent().hide()
	else:
		get_parent().show()
	
	var active_quest = QuestManager.get_active_quest()
	if active_quest.has("data"):
		
		if QuestManager.is_quest_active("wizard", "deliver materials") and active_quest.data.current_dialogue == active_quest.data.dialogue.size() -1:
			text = "Place the crystal on the tower"
		elif QuestManager.is_quest_done("wizard","farewell"):
			text = "You can now head to the next area"
		else:
			text = QuestManager.get_active_quest().data.goal

	else:
		if QuestManager.is_quest_done("wizard","farewell"):
			text = "You can now head to the next area"
