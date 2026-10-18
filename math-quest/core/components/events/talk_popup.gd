extends Control
class_name TalkPopup

# =====================================================================
#  A visitor talking to Matthew: name, a line of dialogue and up to two
#  answer buttons ("I'll help!" / "Later").  chosen(index) is emitted
#  with the button pressed (0 = first), then the popup closes itself.
# =====================================================================

signal chosen(index: int)


func open(speaker: String, line: String, buttons: Array) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.08, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ClassTheme.flat(ClassTheme.PARCHMENT, ClassTheme.GOLD, 18, 4, 24))
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	panel.add_child(col)

	var title := ClassTheme.label(speaker, 26, ClassTheme.CRIMSON)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var text := ClassTheme.label("\"%s\"" % line, 19, ClassTheme.INK_DARK)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(460, 0)
	col.add_child(text)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	col.add_child(row)
	for i in range(buttons.size()):
		var b := Button.new()
		b.text = str(buttons[i])
		b.custom_minimum_size = Vector2(170, 54)
		if i == 0:
			ClassTheme.style_button(b, ClassTheme.CRIMSON, ClassTheme.CRIMSON_DARK, ClassTheme.PARCHMENT, 20)
		else:
			ClassTheme.style_button(b, ClassTheme.PARCHMENT_DARK, ClassTheme.GOLD, ClassTheme.INK, 20)
		b.pressed.connect(func():
			chosen.emit(i)
			queue_free()
		)
		row.add_child(b)
