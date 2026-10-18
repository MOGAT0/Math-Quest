extends Station
class_name ClockStation

# =====================================================================
#  The Grand Clock Tower.
#   reading mode  ("hour hand is just past 12 ... minute hand points to
#                 the 4"): the tower shows that time, the player types it
#   setting mode  (elapsed time): the hands start at the time in the
#                 question; drag them (or type) to the answer.
#  Dragging emits time_set(hour, minute) so the time boxes follow.
# =====================================================================

signal time_set(hour: int, minute: int)

const STONE := Color("#6d6478")
const STONE_DARK := Color("#4d4657")
const ROOF := Color("#5c1414")
const FACE := Color("#f3e9c6")

var reading_mode : bool = false
var _hour : float = 12.0:
	set(v):
		_hour = v
		queue_redraw()
var _minute : float = 0.0:
	set(v):
		_minute = v
		queue_redraw()
var _drag : String = ""           # "", "hour", "minute"
var _glow : float = 0.0:
	set(v):
		_glow = v
		queue_redraw()
var _red : float = 0.0:
	set(v):
		_red = v
		queue_redraw()
var _hand_tween : Tween = null


func setup(q: Dictionary, answer_type: String) -> void:
	super.setup(q, answer_type)
	_glow = 0.0
	_red = 0.0
	_drag = ""
	var shown := _time_to_read(q)
	reading_mode = not shown.is_empty()
	if reading_mode:
		_hour = shown[0]
		_minute = shown[1]
	else:
		var start := _first_time_in_text(str(q.get("text", "")))
		_hour = start[0]
		_minute = start[1]
	mouse_filter = Control.MOUSE_FILTER_IGNORE if reading_mode else Control.MOUSE_FILTER_STOP
	queue_redraw()


## The time the tower should display for "read the clock" questions.
func _time_to_read(q: Dictionary) -> Array:
	var v = q.get("visual", {})
	if typeof(v) == TYPE_DICTIONARY:
		if str(v.get("type", "")) == "clock" and not v.get("clocks", []).is_empty():
			var c = v["clocks"][0]
			return [int(c.get("hour", 12)), int(c.get("minute", 0))]
		if str(v.get("type", "")) == "sequence":
			var h := -1
			var m := -1
			for token in v.get("sequence", []):
				var t := str(token)
				var hm := RegEx.create_from_string("hour:\\s*(\\d+)").search(t)
				if hm:
					h = hm.get_string(1).to_int()
				var mm := RegEx.create_from_string("minute:\\s*(\\d+)\\s*x\\s*5").search(t)
				if mm:
					m = mm.get_string(1).to_int() * 5
			if h >= 0 and m >= 0:
				return [h, m % 60]
	return []


func _first_time_in_text(text: String) -> Array:
	var m := RegEx.create_from_string("(\\d{1,2}):(\\d{2})").search(text)
	if m:
		return [m.get_string(1).to_int(), m.get_string(2).to_int()]
	return [12, 0]


func preview(value: String) -> void:
	if reading_mode or _drag != "":
		return
	var parts := value.split(":")
	if parts.size() != 2 or parts[0] == "" or parts[1] == "":
		return
	_move_hands(parts[0].to_int(), parts[1].to_int())


func _move_hands(h: int, m: int) -> void:
	if _hand_tween and _hand_tween.is_valid():
		_hand_tween.kill()
	_hand_tween = create_tween().set_parallel(true)
	_hand_tween.tween_property(self, "_hour", float(h % 12 if h % 12 != 0 else 12), 0.3)
	_hand_tween.tween_property(self, "_minute", float(m % 60), 0.3)


func action_label() -> String:
	return "RING!"


func cast_color() -> Color:
	return FACE


func success() -> void:
	var tw := create_tween()
	tw.tween_property(self, "_glow", 1.0, 0.25)
	ClassTheme.burst(self, _face_center(), ClassTheme.GOLD_LIGHT, 30, 360.0, -20.0, 5.0)
	await get_tree().create_timer(0.8).timeout


func fail() -> void:
	var tw := create_tween()
	tw.tween_property(self, "_red", 1.0, 0.15)
	tw.tween_property(self, "_red", 0.0, 0.5)
	ClassTheme.shake(self)
	await tw.finished


# ---------------------------------------------------------------- input --

func _gui_input(event: InputEvent) -> void:
	if reading_mode:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_drag = _nearest_hand(event.position)
			if _drag != "":
				_drag_to(event.position)
		else:
			_drag = ""
		accept_event()
	elif event is InputEventMouseMotion and _drag != "":
		_drag_to(event.position)
		accept_event()


func _nearest_hand(at: Vector2) -> String:
	var c := _face_center()
	var r := _face_radius()
	if at.distance_to(c) > r * 1.15:
		return ""
	var d_min := at.distance_to(_hand_tip(_minute_angle(), r * 0.75))
	var d_hour := at.distance_to(_hand_tip(_hour_angle(), r * 0.5))
	return "minute" if d_min <= d_hour else "hour"


func _drag_to(at: Vector2) -> void:
	var v := at - _face_center()
	var a := fposmod(atan2(v.x, -v.y), TAU)     # 0 at 12 o'clock, clockwise
	if _drag == "minute":
		var new_min := int(round(a / TAU * 12.0)) * 5 % 60
		var old_min := int(_minute)
		# Crossing 12 moves the hour along, like a real clock
		if old_min >= 45 and new_min <= 10:
			_hour = float(int(_hour) % 12 + 1)
		elif old_min <= 10 and new_min >= 45:
			_hour = float((int(_hour) + 10) % 12 + 1)
		_minute = float(new_min)
	else:
		var h := int(round(a / TAU * 12.0)) % 12
		_hour = float(12 if h == 0 else h)
	queue_redraw()
	time_set.emit(int(_hour), int(_minute))


# ----------------------------------------------------------------- draw --

func _face_center() -> Vector2:
	return Vector2(size.x * 0.5, size.y * 0.5)


func _face_radius() -> float:
	return minf(size.x * 0.28, size.y * 0.25)


func _minute_angle() -> float:
	return TAU * _minute / 60.0


func _hour_angle() -> float:
	return TAU * (fmod(_hour, 12.0) + _minute / 60.0) / 12.0


func _hand_tip(angle: float, length: float) -> Vector2:
	return _face_center() + Vector2(sin(angle), -cos(angle)) * length


func _draw() -> void:
	if size.x < 40.0:
		return
	var c := _face_center()
	var r := _face_radius()
	# Tower body + roof
	var body := Rect2(c.x - r * 1.35, c.y - r * 1.25, r * 2.7, size.y - (c.y - r * 1.25))
	draw_rect(body, STONE)
	for row in range(int(body.size.y / 22.0)):
		var y := body.position.y + row * 22.0
		draw_line(Vector2(body.position.x, y), Vector2(body.end.x, y), STONE_DARK, 1.0)
	var roof := PackedVector2Array([Vector2(body.position.x - 10, body.position.y), Vector2(c.x, maxf(0.0, body.position.y - r * 0.75)), Vector2(body.end.x + 10, body.position.y)])
	draw_colored_polygon(roof, ROOF)
	# Door
	draw_rect(Rect2(c.x - r * 0.3, size.y - r * 0.7, r * 0.6, r * 0.7), ClassTheme.WOOD_DARK)

	# Face
	if _glow > 0.0:
		var halo := ClassTheme.GOLD_LIGHT
		halo.a = 0.4 * _glow
		draw_circle(c, r * (1.15 + _glow * 0.2), halo)
	draw_circle(c, r + 6, ClassTheme.BOARD_FRAME)
	draw_circle(c, r, FACE.lerp(ClassTheme.RED_LIGHT, _red))
	var f := font()
	var fs := int(r * 0.24)
	for n in range(1, 13):
		var a := TAU * n / 12.0
		var p := c + Vector2(sin(a), -cos(a)) * (r * 0.8)
		var label := str(n)
		var tw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, p + Vector2(-tw / 2.0, fs * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ClassTheme.INK)
	for t in range(60):
		if t % 5 != 0:
			var a := TAU * t / 60.0
			draw_line(c + Vector2(sin(a), -cos(a)) * r * 0.93, c + Vector2(sin(a), -cos(a)) * r * 0.97, ClassTheme.BROWN, 1.0)

	var hour_col := ClassTheme.INK_DARK
	var min_col := ClassTheme.CRIMSON
	if _drag == "hour":
		hour_col = ClassTheme.ARCANE
	elif _drag == "minute":
		min_col = ClassTheme.ARCANE
	draw_line(c, _hand_tip(_hour_angle(), r * 0.5), hour_col, 7.0, true)
	draw_line(c, _hand_tip(_minute_angle(), r * 0.75), min_col, 4.0, true)
	draw_circle(c, 7.0, ClassTheme.INK_DARK)

	if not reading_mode:
		var hint := "drag the hands"
		var hw := f.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string(f, Vector2(c.x - hw / 2.0, c.y + r + 26), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ClassTheme.GOLD_LIGHT)
