extends Control
class_name BoothGame

# =====================================================================
#  A festival booth game, full screen. The class station of the booth
#  (potion, rune lock, balance, magic circle) on the left, the NumberPad
#  (or rune tokens for the balance) on the right.
#
#  Games ("game" in the booth data):
#    "points"  N rounds; 10 points first try, 5 second try, + up to 5
#              speed bonus. Two misses show the answer and move on.
#    "race"    N rounds against the clock; a wrong rune adds 5 seconds.
#              Score = seconds (lower is better).
#    "duel"    first to 3 against a rival who answers after a few
#              seconds (and sometimes guesses wrong).
#
#  finished(result) when closed: {"completed": false} when the player
#  leaves early, else {"completed": true, "score", "kp", "tokens",
#  "new_best"} (FestivalDirector saves it and gives the rewards).
#  A replay (booth already stamped) is for the best score: no tokens,
#  and half the KP only when the record is beaten.
# =====================================================================

signal finished(result: Dictionary)

const STATION_SIZE := Vector2(460, 300)
## Room above a station that draws above its own rect (the potion jars
## float over the cauldron, into the board area on the class stage).
const STATION_TOP := {"potion": 90.0}
const RACE_PENALTY := 5.0
const DUEL_TARGET := 3

var _booth : Dictionary
var _game : String = "points"
var _rounds : int = 3
var _grade : String = "g1"
var _best = null                 # previous best score (null = none yet)
var _replay : bool = false

var _round : int = 0
var _score : int = 0
var _tries : int = 0
var _elapsed : float = 0.0
var _round_time : float = 0.0
var _penalty : float = 0.0
var _running : bool = false
var _busy : bool = false
var _q : Dictionary = {}
# duel
var _you : int = 0
var _rival : int = 0
var _rival_timer : float = 0.0
var _rival_at : float = 0.0
var _rival_wrong : bool = false

var _col : VBoxContainer
var _intro_box : VBoxContainer
var _body : HBoxContainer
var _station : Station
var _input : AnswerInput
var _input_holder : VBoxContainer
var _question : Label
var _status : Label
var _clock : Label
var _feedback : Label
var _action : Button
var _leave : Button
var _rival_row : HBoxContainer
var _rival_bar : ProgressBar


func open(booth: Dictionary, best = null, replay: bool = false) -> void:
	_booth = booth
	_replay = replay
	_game = str(booth.get("game", "points"))
	_rounds = int(booth.get("rounds", 3))
	_best = best
	_grade = FestivalQuestions.current_grade()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.08, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ClassTheme.flat(ClassTheme.PARCHMENT, Color(str(booth.get("awning", "#a8781a"))), 18, 5, 20))
	center.add_child(panel)
	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", 12)
	panel.add_child(_col)

	# Header: icon + booth name, host, Leave
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	_col.add_child(head)
	var title := ClassTheme.label("%s  %s" % [booth.get("icon", "🎪"), booth.get("name", "Booth")], 26, ClassTheme.CRIMSON)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_leave = Button.new()
	_leave.text = "Leave"
	_leave.custom_minimum_size = Vector2(110, 44)
	ClassTheme.style_button(_leave, ClassTheme.PARCHMENT_DARK, ClassTheme.GOLD, ClassTheme.INK, 18)
	_leave.pressed.connect(func(): _close({"completed": false}))
	head.add_child(_leave)

	_build_intro()
	_build_body()


# ------------------------------------------------------------------ intro --

func _build_intro() -> void:
	_intro_box = VBoxContainer.new()
	_intro_box.add_theme_constant_override("separation", 14)
	_col.add_child(_intro_box)
	var host := ClassTheme.label("%s says:" % str(_booth.get("host_name", "The host")), 16, ClassTheme.BROWN)
	_intro_box.add_child(host)
	var intro := ClassTheme.label("\"%s\"" % str(_booth.get("intro", "")), 20, ClassTheme.INK_DARK)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size = Vector2(560, 0)
	_intro_box.add_child(intro)
	_intro_box.add_child(ClassTheme.label("Your best: %s" % _score_text(_best) if _best != null else "No score yet: set the first record!", 16, ClassTheme.GOLD))
	_intro_box.add_child(_board_label("Scores to beat"))
	for g in _booth.get("ghosts", []):
		_intro_box.add_child(ClassTheme.label("   %s  -  %s" % [g.get("name", "?"), _score_text(g.get("score", 0))], 16, ClassTheme.INK))
	var start := Button.new()
	start.text = "Start!"
	start.custom_minimum_size = Vector2(200, 56)
	start.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ClassTheme.style_button(start, ClassTheme.CRIMSON, ClassTheme.CRIMSON_DARK, ClassTheme.PARCHMENT, 22)
	start.pressed.connect(_start)
	_intro_box.add_child(start)


func _start() -> void:
	_intro_box.queue_free()
	_body.show()
	_running = true
	_next_round()


# ------------------------------------------------------------------- body --

func _build_body() -> void:
	_body = HBoxContainer.new()
	_body.add_theme_constant_override("separation", 22)
	_body.hide()
	_col.add_child(_body)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	_body.add_child(left)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", ClassTheme.flat(ClassTheme.WALL, ClassTheme.WOOD, 12, 4, 0))
	left.add_child(frame)
	var holder := Control.new()
	holder.custom_minimum_size = STATION_SIZE
	holder.clip_contents = true
	frame.add_child(holder)
	var kind := str(_booth.get("station", "potion"))
	_station = _make_station(kind)
	var margin : float = STATION_TOP.get(kind, 0.0)
	holder.add_child(_station)
	# Sized once it is in the tree, so stations that lay out on "resized"
	# (the counting table) fill the frame
	_station.position = Vector2(0, margin)
	_station.size = STATION_SIZE - Vector2(0, margin)
	_question = ClassTheme.label("", 22, ClassTheme.INK_DARK)
	_question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_question.custom_minimum_size = Vector2(STATION_SIZE.x, 0)
	left.add_child(_question)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(260, 0)
	right.add_theme_constant_override("separation", 10)
	_body.add_child(right)
	var top := HBoxContainer.new()
	right.add_child(top)
	_status = ClassTheme.label("", 17, ClassTheme.BROWN)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_status)
	_clock = ClassTheme.label("", 17, ClassTheme.CRIMSON)
	top.add_child(_clock)

	_rival_row = HBoxContainer.new()
	_rival_row.add_theme_constant_override("separation", 8)
	_rival_row.visible = _game == "duel"
	right.add_child(_rival_row)
	_rival_row.add_child(ClassTheme.label("%s is thinking" % str(_booth.get("rival", "Rival")), 14, ClassTheme.ARCANE))
	_rival_bar = ProgressBar.new()
	_rival_bar.show_percentage = false
	_rival_bar.custom_minimum_size = Vector2(110, 10)
	_rival_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rival_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_rival_bar.add_theme_stylebox_override("background", ClassTheme.flat(Color(0, 0, 0, 0.15), Color.TRANSPARENT, 4))
	_rival_bar.add_theme_stylebox_override("fill", ClassTheme.flat(ClassTheme.ARCANE, Color.TRANSPARENT, 4))
	_rival_row.add_child(_rival_bar)

	_input_holder = VBoxContainer.new()
	right.add_child(_input_holder)
	_feedback = ClassTheme.label("", 16, ClassTheme.RED)
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback.custom_minimum_size = Vector2(260, 44)
	right.add_child(_feedback)
	_action = Button.new()
	_action.text = _station.action_label()
	_action.custom_minimum_size = Vector2(0, 56)
	ClassTheme.style_button(_action, ClassTheme.CRIMSON, ClassTheme.CRIMSON_DARK, ClassTheme.PARCHMENT, 22)
	_action.pressed.connect(_submit)
	right.add_child(_action)


func _make_station(kind: String) -> Station:
	match kind:
		"rune":
			return RuneLockStation.new()
		"scale":
			return ScaleStation.new()
		"circle":
			return CircleStation.new()
		"counting":
			return CountingStation.new()
		"pattern":
			return PatternStation.new()
		"number_line":
			return NumberLineStation.new()
		"constellation":
			return ConstellationStation.new()
		"shooting_stars":
			return ShootingStarStation.new()
		"star_map":
			return StarMapStation.new()
		"market":
			return MarketStation.new()
		"garden":
			return GardenStation.new()
		"sharing":
			return SharingStation.new()
		"shapes":
			return ShapeStation.new()
		"clock":
			return ClockStation.new()
		"tally":
			return TallyStation.new()
	return PotionStation.new()


func _make_input() -> void:
	if _input and is_instance_valid(_input):
		_input.queue_free()
	match str(_q.get("input", "number")):
		"choice":
			_input = ChoiceTokens.new()
		"time":
			_input = TimeInput.new()
		_:
			_input = NumberPad.new()
	_input_holder.add_child(_input)
	_input.setup(_q)
	_input.value_changed.connect(func(v: String): _station.preview(v))
	_input.submitted.connect(_submit)


# ----------------------------------------------------------------- rounds --

func _next_round() -> void:
	if _game != "duel" and _round >= _rounds:
		_finish()
		return
	_round += 1
	_tries = 0
	_round_time = 0.0
	_busy = false
	_q = FestivalQuestions.make(str(_booth.get("station", "potion")), _grade, _round, _booth)
	_station.setup(_q, str(_q.get("input", "number")))
	_question.text = str(_q.get("text", ""))
	_feedback.text = ""
	_make_input()
	if _game == "duel":
		_rival_timer = 0.0
		_rival_at = _rival_speed()
		_rival_wrong = randf() < 0.25
	_refresh_status()


## Seconds the rival needs: quicker on higher grades.
func _rival_speed() -> float:
	var level := maxi(1, _grade.trim_prefix("g").to_int())
	return randf_range(6.0, 10.0) - minf(level - 1, 3) * 0.6


func _process(delta: float) -> void:
	if not _running:
		return
	if not _busy:
		_elapsed += delta
		_round_time += delta
		if _game == "duel":
			_rival_timer += delta
			_rival_bar.value = 100.0 * minf(_rival_timer / maxf(_rival_at, 0.1), 1.0)
			if _rival_timer >= _rival_at:
				_rival_answers()
	_refresh_clock()


func _submit() -> void:
	if _busy or not _running or _input == null:
		return
	var given := _input.get_value()
	if given == "":
		return
	_busy = true
	var expected := str(_q.get("answer", ""))
	_station.preview(given)
	if _is_right(given, expected):
		_input.lock(true, expected)
		_feedback.add_theme_color_override("font_color", ClassTheme.GREEN)
		_feedback.text = "✨ Correct!"
		match _game:
			"points":
				_score += (10 if _tries == 0 else 5) + maxi(0, 5 - int(_round_time / 4.0))
			"duel":
				_you += 1
		_refresh_status()
		await _station.success()
		await get_tree().create_timer(0.4).timeout
		if _game == "duel" and _you >= DUEL_TARGET:
			_finish()
		else:
			_next_round()
		return

	_tries += 1
	_feedback.add_theme_color_override("font_color", ClassTheme.RED)
	ClassTheme.shake(_feedback)
	await _station.fail()
	match _game:
		"race":
			_penalty += RACE_PENALTY
			_feedback.text = "Wrong rune! +%d seconds. Try again!" % int(RACE_PENALTY)
		"points":
			if _tries >= 2:
				_input.lock(false, expected)
				_feedback.text = "The answer was %s." % expected
				await get_tree().create_timer(1.3).timeout
				_next_round()
				return
			_feedback.text = "Not quite, one more try!"
		"duel":
			_feedback.text = "Oops! Quick, try again!"
	_make_input()
	_busy = false


func _rival_answers() -> void:
	var rival := str(_booth.get("rival", "Rival"))
	if _rival_wrong:
		_rival_wrong = false
		_rival_at = _rival_timer + randf_range(3.5, 6.0)
		_feedback.add_theme_color_override("font_color", ClassTheme.ARCANE)
		_feedback.text = "%s guessed wrong! Your chance!" % rival
		return
	_busy = true
	_rival += 1
	_input.lock(false, str(_q.get("answer", "")))
	_feedback.add_theme_color_override("font_color", ClassTheme.ARCANE)
	_feedback.text = "%s got it first! (%s)" % [rival, str(_q.get("answer", ""))]
	_refresh_status()
	await get_tree().create_timer(1.4).timeout
	if _rival >= DUEL_TARGET:
		_finish()
	else:
		_next_round()


func _is_right(given: String, expected: String) -> bool:
	match str(_q.get("input", "number")):
		"choice":
			return given.to_lower().strip_edges() == expected.to_lower().strip_edges()
		"time":
			return AnswerRules.matches(given, expected, "time")
	return AnswerRules.matches(given, expected, "number")


func _refresh_status() -> void:
	match _game:
		"duel":
			_status.text = "You %d  :  %d %s" % [_you, _rival, str(_booth.get("rival", "Rival"))]
		"race":
			_status.text = "Lock %d / %d" % [_round, _rounds]
		_:
			_status.text = "Round %d / %d   ·   %d pts" % [_round, _rounds, _score]
	_refresh_clock()


func _refresh_clock() -> void:
	if _game == "race":
		_clock.text = "⏱ %.1f s" % (_elapsed + _penalty)
	elif _game == "points":
		_clock.text = "⏱ %d s" % int(_round_time)
	else:
		_clock.text = ""


# ---------------------------------------------------------------- results --

func _final_score() -> int:
	match _game:
		"race":
			return maxi(1, int(round(_elapsed + _penalty)))
		"duel":
			return _you * 10 + (10 if _you >= DUEL_TARGET else 0)
	return _score


func lower_is_better() -> bool:
	return _game == "race"


## 0..1: how well the game went (sets the KP and tokens).
func _fraction(score: int) -> float:
	match _game:
		"race":
			return clampf(float(_booth.get("par", 40)) / maxf(score, 1.0), 0.0, 1.0)
		"duel":
			return 1.0 if _you >= DUEL_TARGET else 0.25 + 0.15 * _you
	return clampf(score / (15.0 * _rounds), 0.0, 1.0)


func _finish() -> void:
	_running = false
	_busy = true
	var score := _final_score()
	var f := _fraction(score)
	var kp_range : Array = _booth.get("kp", [5, 15])
	var tok_range : Array = _booth.get("tokens", [1, 3])
	var kp := int(round(lerpf(float(kp_range[0]), float(kp_range[1]), f)))
	var tokens := int(tok_range[0])
	if f >= 0.85:
		tokens = int(tok_range[1])
	elif f >= 0.5:
		tokens = int(round((float(tok_range[0]) + float(tok_range[1])) / 2.0))
	var new_best := _best == null or (score < float(_best) if lower_is_better() else score > float(_best))
	if _replay:
		tokens = 0
		kp = kp / 2 if new_best else 0
	var result := {"completed": true, "score": score, "kp": kp, "tokens": tokens, "new_best": new_best,
		"won": _game != "duel" or _you >= DUEL_TARGET}
	_show_results(result)


func _show_results(result: Dictionary) -> void:
	_body.queue_free()
	_leave.hide()   # only "Collect!" from here, so the rewards can't be skipped
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(560, 0)
	_col.add_child(box)

	var head := "Booth complete!"
	if _game == "duel":
		head = "You won the duel!" if result["won"] else "%s won this time... well played!" % str(_booth.get("rival", "Rival"))
	var title := ClassTheme.label(head, 26, ClassTheme.GREEN if result["won"] else ClassTheme.ARCANE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var score := ClassTheme.label("Your score: %s" % _score_text(result["score"]), 22, ClassTheme.INK_DARK)
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(score)
	if result["new_best"]:
		var best := ClassTheme.label("🏆 New best!", 22, ClassTheme.GOLD)
		best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(best)
		ClassTheme.pulse(best)

	# Leaderboard: the classmates' scores with the player's placed in
	box.add_child(_board_label("Leaderboard"))
	var rows : Array = []
	for g in _booth.get("ghosts", []):
		rows.append({"name": str(g.get("name", "?")), "score": float(g.get("score", 0)), "you": false})
	rows.append({"name": "You", "score": float(result["score"]), "you": true})
	var low := lower_is_better()
	rows.sort_custom(func(a, b): return a["score"] < b["score"] if low else a["score"] > b["score"])
	for i in range(rows.size()):
		var r : Dictionary = rows[i]
		var line := ClassTheme.label("%d.  %s  -  %s" % [i + 1, r["name"], _score_text(r["score"])], 18 if r["you"] else 16,
			ClassTheme.CRIMSON if r["you"] else ClassTheme.INK)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(line)

	var reward_text := "+%d KP    +%d 🪙 tokens    Stamp ✓" % [result["kp"], result["tokens"]]
	if _replay:
		reward_text = "Practice round: +%d KP for the new record!" % result["kp"] if result["new_best"] else "Practice round: beat your best for a KP bonus!"
	var reward := ClassTheme.label(reward_text, 20, ClassTheme.GREEN)
	reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(reward)
	var collect := Button.new()
	collect.text = "Collect!"
	collect.custom_minimum_size = Vector2(200, 56)
	collect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ClassTheme.style_button(collect, ClassTheme.CRIMSON, ClassTheme.CRIMSON_DARK, ClassTheme.PARCHMENT, 22)
	collect.pressed.connect(func(): _close(result))
	box.add_child(collect)
	ClassTheme.confetti(self)


func _board_label(text: String) -> Label:
	var l := ClassTheme.label(text, 15, ClassTheme.BROWN)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## "42 pts" or "37 s" (the race counts seconds).
func _score_text(score) -> String:
	if lower_is_better():
		return "%d s" % int(score)
	return "%d pts" % int(score)


func _close(result: Dictionary) -> void:
	_running = false
	finished.emit(result)
	queue_free()
