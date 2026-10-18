extends Station
class_name RuneLockStation

# =====================================================================
#  Rune vault door: order of operations (PMDAS), ordering and number
#  sequences.  Every key press turns the rune rings a notch; the right
#  answer lines them up and the door bursts open with light, a wrong
#  one jams the rings with red sparks.
# =====================================================================

const DOOR := Color("#4a3f5c")
const DOOR_DARK := Color("#2f2740")
const RING_COLORS := [Color("#c9962b"), Color("#b79ac9"), Color("#7fd0e0")]
const RUNES_PER_RING := 10

var _value : String = ""
var _ring_angles : Array = [0.0, 0.0, 0.0]
var _open : float = 0.0:
	set(v):
		_open = v
		queue_redraw()
var _jam : float = 0.0:
	set(v):
		_jam = v
		queue_redraw()
var _time : float = 0.0
var _turns : int = 0


func setup(q: Dictionary, answer_type: String) -> void:
	super.setup(q, answer_type)
	_value = ""
	_open = 0.0
	_jam = 0.0
	_turns = 0
	_ring_angles = [randf() * TAU, randf() * TAU, randf() * TAU]


func preview(value: String) -> void:
	_value = value
	_turns += 1
	# Each change clicks the rings round by one rune
	for i in range(_ring_angles.size()):
		var dir := 1.0 if i % 2 == 0 else -1.0
		_ring_angles[i] += dir * TAU / RUNES_PER_RING * (1 + i)
	queue_redraw()


func action_label() -> String:
	return "UNLOCK!"


func cast_color() -> Color:
	return RING_COLORS[1]


func success() -> void:
	var tw := create_tween().set_parallel(true)
	for i in range(_ring_angles.size()):
		tw.tween_method(_set_ring.bind(i), _ring_angles[i], snappedf(_ring_angles[i], TAU), 0.4) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(self, "_open", 1.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ClassTheme.burst(self, _center(), ClassTheme.GOLD_LIGHT, 34, 400.0, -10.0, 6.0)
	await tw.finished


func fail() -> void:
	var tw := create_tween()
	tw.tween_property(self, "_jam", 1.0, 0.12)
	tw.tween_interval(0.35)
	tw.tween_property(self, "_jam", 0.0, 0.4)
	ClassTheme.burst(self, _center(), ClassTheme.RED, 20, 280.0, 300.0, 4.0)
	ClassTheme.shake(self)
	await tw.finished


func _set_ring(angle: float, index: int) -> void:
	_ring_angles[index] = angle
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _center() -> Vector2:
	return Vector2(size.x * 0.5, size.y * 0.48)


func _radius() -> float:
	return minf(size.x * 0.34, size.y * 0.42)


func _draw() -> void:
	if size.x < 40.0:
		return
	var c := _center()
	var r := _radius()
	var f := font()

	# Light pouring out once the door opens
	if _open > 0.0:
		var beam := ClassTheme.GOLD_LIGHT
		beam.a = 0.45 * _open
		draw_circle(c, r * (1.1 + _open * 0.5), beam)

	# Stone arch + door
	draw_rect(Rect2(c.x - r * 1.25, c.y - r * 1.15, r * 2.5, size.y - (c.y - r * 1.15)), DOOR_DARK)
	draw_circle(c, r * 1.08, DOOR_DARK.lightened(0.1))
	draw_circle(c, r, DOOR.lerp(ClassTheme.GOLD_LIGHT, _open * 0.4).lerp(ClassTheme.RED, _jam * 0.4))

	# Rune rings (outer -> inner)
	for i in range(3):
		var rr := r * (0.88 - i * 0.2)
		var col : Color = RING_COLORS[i].lerp(ClassTheme.RED, _jam)
		draw_arc(c, rr, 0.0, TAU, 64, col, 3.0, true)
		var jitter := sin(_time * 60.0) * 0.05 * _jam
		for k in range(RUNES_PER_RING):
			var a : float = _ring_angles[i] + jitter + TAU * k / RUNES_PER_RING
			var p := c + Vector2(cos(a), sin(a)) * (rr - r * 0.08)
			var lit := k == 0
			var rune_col := col if not lit else ClassTheme.CHALK
			_draw_rune(p, a, r * 0.045, rune_col, k + i * 3)

	# Keyhole marker at the top: runes line up here when unlocked
	draw_colored_polygon(PackedVector2Array([c + Vector2(-8, -r - 4), c + Vector2(8, -r - 4), c + Vector2(0, -r + 12)]), ClassTheme.GOLD_LIGHT)

	# Centre plate with the answer being entered
	var plate_r := r * 0.3
	draw_circle(c, plate_r, ClassTheme.INK_DARK)
	draw_arc(c, plate_r, 0.0, TAU, 40, ClassTheme.GOLD, 2.0, true)
	var shown := _value if _value != "" else "?"
	var fs := int(plate_r * 0.75)
	var tw := f.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if tw > plate_r * 1.7:
		fs = maxi(8, int(fs * plate_r * 1.7 / tw))
		tw = f.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(f, c + Vector2(-tw / 2.0, fs * 0.35), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ClassTheme.GOLD_LIGHT)


## A little stroke rune; `shape` picks which one.
func _draw_rune(p: Vector2, angle: float, s: float, col: Color, shape: int) -> void:
	var t := Transform2D(angle + PI / 2.0, p)
	draw_line(t * Vector2(0, -s), t * Vector2(0, s), col, 2.0, true)
	match shape % 4:
		0:
			draw_line(t * Vector2(0, -s * 0.3), t * Vector2(s * 0.7, -s), col, 2.0, true)
		1:
			draw_line(t * Vector2(-s * 0.7, 0), t * Vector2(s * 0.7, 0), col, 2.0, true)
		2:
			draw_line(t * Vector2(0, 0), t * Vector2(-s * 0.7, s * 0.6), col, 2.0, true)
		3:
			draw_line(t * Vector2(-s * 0.6, -s * 0.6), t * Vector2(s * 0.6, s * 0.6), col, 2.0, true)
