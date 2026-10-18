extends Node
class_name LectureRunner

# =====================================================================
#  Plays a lesson's "lecture_steps" on the class stage. The teacher
#  stands at the left, Matthew watches from the right, pictures appear
#  on a parchment slate and the panel holds the step's controls.
#
#   {"type":"say",     "text":"..."}
#   {"type":"confirm", "text":"Ready?", "yes":"..", "no":".."}   ("no" optional)
#   {"type":"count",   "from":1, "to":10, "step":1, "interval":1.2, "repeat":true}
#   {"type":"show",    "text":"..", "visual":{..}}     slate picture, auto-advances
#   {"type":"tap",     "text":"..", "visual":{..}}     slate picture, waits for Next
#   {"type":"check",   "text":"..", "visual":{..}, "answer":"..", "options":[..]}
#                      "Your turn!": answered with the real answer input, unscored
#   {"type":"cheer",   "text":".."}
#   {"type":"demo",    "text":"..", "value":"12", "station":"potion",
#                      "question":{..}}    Matthew works the magic at a station
#
#  Tapping the teacher's text skips ahead.
# =====================================================================

signal finished

const COUNT_CARD_SCALE := 1.4

var cls                                # the Scholl class screen
var teacher_name : String = "Mr. Archimedes"

var _token : int = 0
var _skip : bool = false


func _alive(token: int) -> bool:
	return token == _token and is_inside_tree()


func run(steps: Array) -> void:
	_token += 1
	var token := _token
	if not cls.card.tapped.is_connected(skip):
		cls.card.tapped.connect(skip)
	cls.stage.enter_lecture()
	cls.stage.teacher.face(StageActor.FACE_RIGHT)
	for step in steps:
		if not _alive(token):
			return
		_skip = false
		if typeof(step) == TYPE_DICTIONARY:
			await _run_step(step, token)
	if _alive(token):
		_clear_panel()
		finished.emit()


func stop() -> void:
	_token += 1
	_skip = false
	_clear_panel()
	if cls and cls.stage:
		cls.stage.teacher.set_talking(false)
		cls.stage.clear_slate()
	if DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		DisplayServer.tts_stop()


func skip() -> void:
	_skip = true


func _run_step(step: Dictionary, token: int) -> void:
	match str(step.get("type", "say")):
		"say":
			await _say(str(step.get("text", "")), token)
		"confirm":
			await _confirm(step, token)
		"count":
			await _count(step, token)
		"show":
			await _show(step, token, false)
		"tap":
			await _show(step, token, true)
		"check":
			await _check(step, token)
		"cheer":
			await _cheer(step, token)
		"demo":
			await _demo(step, token)


# --------------------------------------------------------------- helpers --

func _wait(seconds: float, token: int) -> void:
	var t := 0.0
	while t < seconds and _alive(token) and not _skip:
		await get_tree().process_frame
		t += get_process_delta_time()


## Teacher says a line: typed on the card, spoken, with a talking bob.
func _say(text: String, token: int) -> void:
	if text.is_empty() or not _alive(token):
		return
	var teacher : StageActor = cls.stage.teacher
	teacher.set_talking(true)
	cls.card.show_question(text, teacher_name)
	while _alive(token) and not _skip and cls.card.is_typing():
		await get_tree().process_frame
	cls.card.finish_typing()
	if DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		var waited := 0.0
		while _alive(token) and not _skip and DisplayServer.tts_is_speaking() and waited < 8.0:
			await get_tree().process_frame
			waited += get_process_delta_time()
	else:
		await _wait(0.4 + 0.05 * text.split(" ").size(), token)
	if _alive(token):
		teacher.set_talking(false)
		_skip = false
		await _wait(0.3, token)


func _clear_panel() -> void:
	if cls == null:
		return
	for c in cls._input_holder.get_children():
		cls._input_holder.remove_child(c)
		c.queue_free()


## Shows buttons in the panel and waits for one; returns its index.
func _ask(labels: Array, token: int, styles: Array = []) -> int:
	_clear_panel()
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	cls._input_holder.add_child(row)
	var picked := {"i": -1}
	for i in range(labels.size()):
		var b := Button.new()
		b.text = str(labels[i])
		b.custom_minimum_size = Vector2(150, 58)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var style : String = styles[i] if i < styles.size() else "primary"
		if style == "primary":
			ClassTheme.style_button(b, ClassTheme.GREEN, ClassTheme.GREEN.darkened(0.3), ClassTheme.PARCHMENT, cls._fs(20))
		else:
			ClassTheme.style_button(b, ClassTheme.PARCHMENT, ClassTheme.GOLD, ClassTheme.INK, cls._fs(20))
		b.pressed.connect(func(): picked["i"] = i)
		row.add_child(b)
	ClassTheme.pop(row, 1.06)
	while picked["i"] == -1 and _alive(token):
		await get_tree().process_frame
	_clear_panel()
	return picked["i"]


func _slate_visual(step: Dictionary, interactive: bool = false) -> bool:
	var v = step.get("visual", {})
	if typeof(v) != TYPE_DICTIONARY or v.is_empty():
		return false
	var visual : Dictionary = v.duplicate(true)
	if interactive and str(visual.get("type", "")) == "shapes":
		visual["interactive"] = true      # tap each side to count it
	var builder := VisualBuilder.new(cls._speak, cls._number_to_word)
	builder.icon_scale = cls.icon_scale
	var slate : VBoxContainer = cls.stage.slate()
	var available : Vector2 = cls.stage._slate_rect().size - Vector2(32, 32)
	var ctrl := builder.build(visual, available)
	if ctrl == null:
		return false
	cls.stage.clear_slate()
	slate.add_child(ctrl)
	cls.stage.show_slate()
	return true


# ----------------------------------------------------------------- steps --

func _confirm(step: Dictionary, token: int) -> void:
	var question := str(step.get("text", "Are you ready?"))
	var yes := str(step.get("yes", "I'm ready!"))
	var no := str(step.get("no", ""))
	while _alive(token):
		await _say(question, token)
		var labels : Array = [yes] if no == "" else [yes, no]
		var choice := await _ask(labels, token, ["primary", "secondary"])
		if not _alive(token):
			return
		if choice == 0:
			cls.stage.bubble.say(cls.stage.matthew, yes)
			await cls.stage.matthew.hop()
			return
		cls.stage.bubble.say(cls.stage.matthew, no)
		await _say("Take your time!", token)
		await _wait(3.0, token)


func _count(step: Dictionary, token: int) -> void:
	var from_n := int(step.get("from", 1))
	var to_n := int(step.get("to", 10))
	var stride : int = maxi(1, int(step.get("step", 1)))
	var interval := float(step.get("interval", 0.9))
	var lead_in := float(step.get("lead_in", 0.8))
	var allow_repeat := bool(step.get("repeat", true))
	var values : Array = []
	var n := from_n
	while n <= to_n and values.size() < 60:
		values.append(n)
		n += stride

	cls.stage.clear_slate()
	var flow := HFlowContainer.new()
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	cls.stage.slate().add_child(flow)
	cls.stage.show_slate()
	var cards : Array = []
	for v in values:
		var card := _number_card(int(v))
		flow.add_child(card)
		cards.append(card)

	var teacher : StageActor = cls.stage.teacher
	while _alive(token):
		for c in cards:
			_card_state(c, "idle")
		_skip = false
		await _wait(lead_in, token)
		teacher.set_talking(true)
		for i in range(cards.size()):
			if not _alive(token):
				return
			var card : PanelContainer = cards[i]
			if _skip:
				_card_state(card, "done")
				continue
			_card_state(card, "active")
			card.pivot_offset = card.size / 2.0
			card.z_index = 5
			card.create_tween().tween_property(card, "scale", Vector2.ONE * COUNT_CARD_SCALE, 0.18) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			cls.card.show_question(str(values[i]), teacher_name)
			cls._speak(cls._number_to_word(int(values[i])))
			await _wait(interval, token)
			if not _alive(token):
				return
			_card_state(card, "done")
			card.z_index = 0
			card.create_tween().tween_property(card, "scale", Vector2.ONE, 0.15)
		teacher.set_talking(false)
		_skip = false
		if not allow_repeat:
			return
		var choice := await _ask(["Count Again", "Next ->"], token, ["secondary", "primary"])
		if choice != 0:
			return


func _number_card(value: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(56, 74) * cls.icon_scale
	var lbl := ClassTheme.label(str(value), roundi(30 * cls.icon_scale))
	lbl.name = "Num"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card.add_child(lbl)
	_card_state(card, "idle")
	return card


func _card_state(card: PanelContainer, state: String) -> void:
	var bg := ClassTheme.PARCHMENT
	var border := ClassTheme.SAND_DARK
	var fg := ClassTheme.BROWN
	match state:
		"active":
			bg = ClassTheme.GOLD_LIGHT
			border = ClassTheme.GOLD
			fg = ClassTheme.INK_DARK
		"done":
			bg = ClassTheme.GREEN_LIGHT
			border = ClassTheme.GREEN
			fg = ClassTheme.GREEN
	card.add_theme_stylebox_override("panel", ClassTheme.flat(bg, border, 12, 3))
	(card.get_node("Num") as Label).add_theme_color_override("font_color", fg)


func _show(step: Dictionary, token: int, wait_for_next: bool) -> void:
	if not _slate_visual(step, wait_for_next):
		cls.stage.clear_slate()
	await _say(str(step.get("text", "")), token)
	if not _alive(token):
		return
	if wait_for_next:
		await _next_when_done(token)
	else:
		await _wait(0.9, token)


## "tap" steps: Next stays locked until everything on the slate is counted,
## so the activity can't be skipped.
func _next_when_done(token: int) -> void:
	_clear_panel()
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 58)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cls._input_holder.add_child(btn)
	var pressed := {"v": false}
	btn.pressed.connect(func(): pressed["v"] = true)
	var unlocked := false
	var pulse_tw : Tween = null
	while _alive(token) and not pressed["v"]:
		var done := VisualBuilder.is_done(cls.stage.slate())
		if done != unlocked or btn.text == "":
			unlocked = done
			btn.disabled = not done
			if done:
				btn.text = "Next ->"
				ClassTheme.style_button(btn, ClassTheme.GREEN, ClassTheme.GREEN.darkened(0.3), ClassTheme.PARCHMENT, cls._fs(20))
				ClassTheme.pop(btn, 1.1)
				pulse_tw = ClassTheme.pulse(btn)
			else:
				if pulse_tw and pulse_tw.is_valid():
					pulse_tw.kill()
				btn.text = "Tap them all first!"
				btn.modulate.a = 1.0
				ClassTheme.style_button(btn, ClassTheme.SAND, ClassTheme.SAND_DARK, ClassTheme.BROWN, cls._fs(18))
		await get_tree().process_frame
	_clear_panel()


## "Your turn!": the real answer input, unscored.
func _check(step: Dictionary, token: int) -> void:
	if not _slate_visual(step):
		cls.stage.clear_slate()
	var q := {"text": str(step.get("text", "")), "answer": str(step.get("answer", "")), "options": step.get("options", [])}
	if step.has("input"):
		q["input"] = step["input"]
	var input_type := AnswerRules.detect(q)
	await _say(q["text"], token)
	if not _alive(token):
		return
	cls.card.show_hint("Your turn! Try it - this one is just practice.")

	_clear_panel()
	var inp : AnswerInput = cls._make_input(q, input_type)
	cls._input_holder.add_child(inp)
	inp.setup(q)
	var try_btn := Button.new()
	try_btn.text = "TRY IT!"
	try_btn.custom_minimum_size = Vector2(0, 56)
	try_btn.disabled = true
	ClassTheme.style_button(try_btn, ClassTheme.ARCANE, ClassTheme.ARCANE.darkened(0.3), ClassTheme.PARCHMENT, cls._fs(22))
	cls._input_holder.add_child(try_btn)
	var state := {"go": false}
	inp.value_changed.connect(func(v: String): try_btn.disabled = v == "")
	inp.submitted.connect(func(): state["go"] = inp.get_value() != "")
	try_btn.pressed.connect(func(): state["go"] = true)
	while not state["go"] and _alive(token):
		await get_tree().process_frame
	if not _alive(token):
		return
	try_btn.disabled = true
	var right := AnswerRules.matches(inp.get_value(), q["answer"], input_type)
	inp.lock(right, q["answer"])
	cls.card.show_hint("")
	if right:
		cls.stage.matthew.hop()
		cls.stage.bubble.say(cls.stage.matthew, "I got it!")
		await _say("Correct! Well done!", token)
	else:
		cls.stage.matthew.slump()
		var why := AnswerExplainer.explain(q, input_type)
		await _say(("Not quite. The answer is %s. %s" % [q["answer"], why]).strip_edges(), token)
	await _wait(0.6, token)
	_clear_panel()


func _cheer(step: Dictionary, token: int) -> void:
	ClassTheme.confetti(cls)
	cls.stage.matthew.hop(3)
	cls.stage.teacher.hop(2)
	await _say(str(step.get("text", "Great job!")), token)
	await _wait(0.6, token)


## Matthew walks to a station and works the magic with the given value.
func _demo(step: Dictionary, token: int) -> void:
	var value := str(step.get("value", ""))
	var q : Dictionary = step.get("question", {}).duplicate() if typeof(step.get("question")) == TYPE_DICTIONARY else {}
	if q.is_empty():
		q = {"text": str(step.get("text", "")), "answer": value}
		if step.has("visual"):
			q["visual"] = step["visual"]
	var input_type := AnswerRules.detect(q)
	var kind := str(step.get("station", StationPicker.pick({}, q, input_type)))
	var stage : ClassStage = cls.stage

	cls._use_station(kind, true)
	stage.station.setup(q, input_type)
	stage.show_station_for_demo()
	await stage.matthew.walk_to(stage.size.x * 0.33, 420.0)
	if not _alive(token):
		return
	await _say(str(step.get("text", "")), token)
	# "Type" the value one character at a time so the station reacts
	var shown := ""
	for ch in value:
		if not _alive(token):
			return
		shown += ch
		stage.station.preview(shown)
		await _wait(0.35, token)
	if not _alive(token):
		return
	await stage.play_result(true)
	await _wait(0.5, token)
	if not _alive(token):
		return
	stage._station_holder.hide()
	await stage.matthew.walk_to(stage.matthew_spot(), 420.0)
	stage.matthew.face(StageActor.FACE_LEFT)
