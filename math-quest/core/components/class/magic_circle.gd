extends Control
class_name MagicCircle

# =====================================================================
#  Magic circle shown on every class question (vector drawn, no assets)
#
#  begin()    rings + runes draw themselves in
#  charge()   an answer is picked: the circle glows and shows the answer
#  fire()     correct answer: the spell bursts outward      (await it)
#  shatter()  wrong answer: the circle cracks and falls apart (await it)
# =====================================================================

signal finished

const COLOR_INK := Color("#3b2a1a")
const COLOR_ARCANE := Color("#8a1f1f")
const COLOR_GOLD := Color("#c9962b")
const COLOR_GLOW := Color("#f0dfa0")
const COLOR_BROKEN := Color("#8c2f1a")

const DRAW_TIME := 1.1
const FIRE_TIME := 0.75
const CRACK_TIME := 0.25
const FALL_TIME := 0.7
const SHARD_COUNT := 10

var rune_count : int = 8
var golden : bool = false

# Animated values (0..1); every change redraws the circle
var _progress : float = 0.0:     # how much of the circle is drawn
	set(v):
		_progress = v
		queue_redraw()
var _glow : float = 0.0:         # charged glow
	set(v):
		_glow = v
		queue_redraw()
var _burst : float = 0.0:        # fire animation
	set(v):
		_burst = v
		queue_redraw()
var _crack : float = 0.0:        # cracks spreading
	set(v):
		_crack = v
		queue_redraw()
var _fall : float = 0.0:         # shards falling
	set(v):
		_fall = v
		queue_redraw()
var _spin : float = 0.0
var _answer_text : String = ""
var _runes : Array = []          # per rune: Array of [Vector2, Vector2] strokes (unit space)
var _shards : Array = []         # per shard: {a0, a1, dir, spin}
var _tween : Tween = null
var _glow_tween : Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _process(delta: float) -> void:
	# Slow idle spin while the circle is alive
	if _progress > 0.0 and _fall == 0.0:
		_spin = wrapf(_spin + delta * (0.25 + _glow * 0.9), 0.0, TAU)
		queue_redraw()


func begin(runes: int = 8, is_golden: bool = false) -> void:
	rune_count = maxi(3, runes)
	golden = is_golden
	_progress = 0.0
	_glow = 0.0
	_burst = 0.0
	_crack = 0.0
	_fall = 0.0
	_answer_text = ""
	modulate = Color.WHITE
	_build_runes()
	_build_shards()
	_kill_tweens()
	_tween = create_tween()
	_tween.tween_property(self, "_progress", 1.0, DRAW_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Glow while an answer is selected; shows the chosen answer in the middle.
func charge(answer_text: String = "") -> void:
	_answer_text = answer_text if answer_text.length() <= 8 else ""
	if _glow_tween and _glow_tween.is_valid():
		_glow_tween.kill()
	_glow_tween = create_tween()
	_glow_tween.tween_property(self, "_glow", 1.0, 0.25)
	pivot_offset = size / 2.0
	scale = Vector2(1.08, 1.08)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func fire() -> Signal:
	_kill_tweens()
	_progress = 1.0
	_glow = 1.0
	_tween = create_tween()
	_tween.tween_property(self, "_burst", 1.0, FIRE_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.finished.connect(func(): finished.emit())
	return finished


func shatter() -> Signal:
	_kill_tweens()
	_progress = 1.0
	_glow = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "_crack", 1.0, CRACK_TIME)
	_tween.tween_interval(0.15)
	_tween.tween_property(self, "_fall", 1.0, FALL_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.finished.connect(func(): finished.emit())
	return finished


func _kill_tweens() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	if _glow_tween and _glow_tween.is_valid():
		_glow_tween.kill()


# ---------------------------------------------------------------- setup --

## Every rune is 2-3 short strokes. Seeded per index so a circle with the
## same rune count always looks the same.
func _build_runes() -> void:
	_runes.clear()
	var rng := RandomNumberGenerator.new()
	for i in range(rune_count):
		rng.seed = 7919 * (i + 1) + rune_count
		var strokes : Array = []
		var top := Vector2(0, -1)
		var bottom := Vector2(0, 1)
		strokes.append([top, bottom])
		for s in range(rng.randi_range(1, 2)):
			var y1 := rng.randf_range(-1.0, 0.6)
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			strokes.append([Vector2(0, y1), Vector2(side * 0.7, y1 + rng.randf_range(-0.6, 0.6))])
		_runes.append(strokes)


func _build_shards() -> void:
	_shards.clear()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var step := TAU / SHARD_COUNT
	for i in range(SHARD_COUNT):
		var mid := step * (i + 0.5)
		_shards.append({
			"a0": step * i, "a1": step * (i + 1),
			"dir": Vector2(cos(mid), sin(mid)) * rng.randf_range(0.2, 0.6) + Vector2(0, 1.0),
			"spin": rng.randf_range(-2.5, 2.5)
		})


# ----------------------------------------------------------------- draw --

func _ink() -> Color:
	if _crack > 0.0:
		return COLOR_INK.lerp(COLOR_BROKEN, _crack)
	var base := COLOR_GOLD if golden else COLOR_ARCANE
	return base.lerp(COLOR_GOLD, _glow * 0.5)


func _draw() -> void:
	if _progress <= 0.0:
		return
	var c := size / 2.0
	var r := minf(size.x, size.y) / 2.0 - 6.0
	if r <= 4.0:
		return

	if _fall > 0.0:
		_draw_shards(c, r)
		return

	var ink := _ink()
	var fade := 1.0 - _burst

	# Soft glow disc behind the circle while charged / firing
	if _glow > 0.0:
		var glow_col := COLOR_GLOW
		glow_col.a = 0.35 * _glow * fade
		draw_circle(c, r * (1.0 + _burst * 0.6), glow_col)

	ink.a = fade
	var sweep := TAU * _progress
	# Outer and inner rings draw in as a sweep
	draw_arc(c, r, -PI / 2.0, -PI / 2.0 + sweep, 72, ink, 4.0, true)
	draw_arc(c, r * 0.82, PI / 2.0, PI / 2.0 + sweep, 64, ink, 2.0, true)

	# Star polygon connecting points on the inner ring
	var points := rune_count
	var skip := 2 if points >= 5 else 1
	var shown := int(floor(points * clampf((_progress - 0.3) / 0.7, 0.0, 1.0)))
	for i in range(shown):
		var a0 := _spin + TAU * i / points - PI / 2.0
		var a1 := _spin + TAU * ((i + skip) % points) / points - PI / 2.0
		draw_line(c + Vector2(cos(a0), sin(a0)) * r * 0.78, c + Vector2(cos(a1), sin(a1)) * r * 0.78, ink, 2.0, true)

	# Runes between the two rings
	var rune_r := r * 0.91
	var rune_size := r * 0.075
	var runes_shown := int(floor(rune_count * clampf((_progress - 0.5) / 0.5, 0.0, 1.0)))
	for i in range(runes_shown):
		var a := -_spin * 0.6 + TAU * i / rune_count - PI / 2.0
		var pos := c + Vector2(cos(a), sin(a)) * rune_r
		var rot := Transform2D(a + PI / 2.0, pos)
		for stroke in _runes[i]:
			draw_line(rot * (stroke[0] * rune_size), rot * (stroke[1] * rune_size), ink, 2.0, true)

	# Spell burst: rays fly out from the centre
	if _burst > 0.0:
		var ray_col := COLOR_GOLD
		ray_col.a = fade
		for i in range(12):
			var a := TAU * i / 12.0 + _spin
			var dir := Vector2(cos(a), sin(a))
			draw_line(c + dir * r * (0.2 + _burst * 0.8), c + dir * r * (0.45 + _burst * 1.1), ray_col, 3.0, true)
		draw_arc(c, r * (1.0 + _burst * 0.5), 0.0, TAU, 72, ray_col, 3.0 * fade + 0.5, true)

	# Cracks spread from the centre before the circle falls apart
	if _crack > 0.0:
		var crack_col := COLOR_BROKEN
		for s in _shards:
			var a : float = s["a0"]
			var end := c + Vector2(cos(a), sin(a)) * r * _crack
			var mid := c.lerp(end, 0.5) + Vector2(cos(a + 1.2), sin(a + 1.2)) * r * 0.06 * _crack
			draw_line(c, mid, crack_col, 2.0, true)
			draw_line(mid, end, crack_col, 2.0, true)

	# Chosen answer in the middle of the circle
	if _answer_text != "" and _crack == 0.0:
		var font := ThemeDB.fallback_font
		var fs := int(r * 0.42)
		var tw := font.get_string_size(_answer_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var tcol := COLOR_INK
		tcol.a = fade
		draw_string(font, c + Vector2(-tw / 2.0, fs * 0.35), _answer_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tcol)


func _draw_shards(c: Vector2, r: float) -> void:
	var col := COLOR_BROKEN
	col.a = 1.0 - _fall
	var drop := _fall * _fall
	for s in _shards:
		var mid_a : float = (s["a0"] + s["a1"]) / 2.0
		var anchor := c + Vector2(cos(mid_a), sin(mid_a)) * r * 0.9
		var offset : Vector2 = s["dir"] * r * 1.6 * drop
		draw_set_transform(anchor + offset, s["spin"] * _fall, Vector2.ONE)
		var a0 : float = s["a0"]
		var a1 : float = s["a1"]
		var local_c := c - anchor
		draw_arc(local_c, r, a0, a1, 8, col, 4.0, true)
		draw_arc(local_c, r * 0.82, a0, a1, 8, col, 2.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
