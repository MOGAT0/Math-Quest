extends Station
class_name ScaleStation

# =====================================================================
#  Enchanted balance for comparing. The pans hold the two amounts from
#  the question ("balance" visual, or the first two numbers in the
#  text); the beam tips toward the heavier side.  The chosen answer is
#  hung on a sign above the beam.  Engraved brass tags under the beam
#  ends name the LEFT and RIGHT side, and glow when the chosen answer
#  names that side.
# =====================================================================

const BRASS := Color("#c9962b")
const BRASS_DARK := Color("#8a6420")
const GEM := Color("#7fd0e0")
const MAX_GEMS := 12

var _left : int = 0
var _right : int = 0
var _choice : String = ""
var _tilt : float = 0.0:          # radians, + = right side down
	set(v):
		_tilt = v
		queue_redraw()
var _glow : float = 0.0:
	set(v):
		_glow = v
		queue_redraw()
var _time : float = 0.0
var _tag_glow : Array = [0.0, 0.0]   # left, right


func setup(q: Dictionary, answer_type: String) -> void:
	super.setup(q, answer_type)
	_choice = ""
	_glow = 0.0
	_tag_glow = [0.0, 0.0]
	_left = 0
	_right = 0
	var v = q.get("visual", {})
	if typeof(v) == TYPE_DICTIONARY and str(v.get("type", "")) == "balance":
		_left = int(v.get("leftItems", {}).get("count", 0))
		_right = int(v.get("rightItems", {}).get("count", 0))
	else:
		var nums := numbers_in_text()
		if nums.size() >= 2:
			_left = nums[0]
			_right = nums[1]
	_tilt = 0.0
	var target := clampf(float(_right - _left) * 0.04, -0.22, 0.22)
	create_tween().tween_property(self, "_tilt", target, 0.9) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func preview(value: String) -> void:
	_choice = value
	var v := value.to_lower()
	var both := v.contains("both") or v.contains("equal")
	var targets := [
		1.0 if v.contains("left") or both else 0.0,
		1.0 if v.contains("right") or both else 0.0,
	]
	var tw := create_tween().set_parallel(true)
	for i in range(2):
		tw.tween_method(_set_tag_glow.bind(i), _tag_glow[i], targets[i], 0.25)
	queue_redraw()


func _set_tag_glow(v: float, index: int) -> void:
	_tag_glow[index] = v
	queue_redraw()


func action_label() -> String:
	return "WEIGH!"


func cast_color() -> Color:
	return GEM


func success() -> void:
	var tw := create_tween()
	tw.tween_property(self, "_glow", 1.0, 0.3)
	var pans := _pan_points()
	ClassTheme.burst(self, pans[0], ClassTheme.GOLD_LIGHT, 18, 260.0, -30.0, 5.0)
	ClassTheme.burst(self, pans[1], ClassTheme.GOLD_LIGHT, 18, 260.0, -30.0, 5.0)
	await get_tree().create_timer(0.8).timeout


func fail() -> void:
	var base := _tilt
	var tw := create_tween()
	for i in range(4):
		tw.tween_property(self, "_tilt", base + (0.18 if i % 2 == 0 else -0.18), 0.1)
	tw.tween_property(self, "_tilt", base, 0.2)
	ClassTheme.burst(self, Vector2(size.x / 2.0, size.y * 0.9), Color(0.5, 0.45, 0.4), 16, 160.0, 200.0, 5.0)
	await tw.finished


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _pivot() -> Vector2:
	return Vector2(size.x * 0.5, size.y * 0.3)


func _beam_half() -> float:
	return minf(size.x * 0.4, size.y * 0.55)


func _pan_points() -> Array:
	var p := _pivot()
	var d := Vector2(cos(_tilt), sin(_tilt)) * _beam_half()
	return [p - d, p + d]


func _draw() -> void:
	if size.x < 40.0:
		return
	var p := _pivot()
	var half := _beam_half()
	var floor_y := size.y * 0.97
	# Stand
	draw_rect(Rect2(p.x - half * 0.35, floor_y - 12, half * 0.7, 12), BRASS_DARK)
	draw_rect(Rect2(p.x - 5, p.y, 10, floor_y - p.y), BRASS)
	# Beam
	var ends := _pan_points()
	var beam_col := BRASS.lerp(ClassTheme.GOLD_LIGHT, _glow)
	draw_line(ends[0], ends[1], beam_col, 8.0, true)
	draw_circle(p, 10.0, BRASS_DARK)
	draw_circle(p, 5.0, ClassTheme.GOLD_LIGHT)
	# Pans hang straight down from the beam ends
	var hang := size.y * 0.32
	var pan_w := half * 0.62
	for i in range(2):
		var top : Vector2 = ends[i]
		var pan_c := top + Vector2(0, hang)
		draw_line(top, pan_c + Vector2(-pan_w / 2.0, 0), BRASS_DARK, 2.0, true)
		draw_line(top, pan_c + Vector2(pan_w / 2.0, 0), BRASS_DARK, 2.0, true)
		_draw_side_tag(top + Vector2(0, hang * 0.16), pan_w, "LEFT" if i == 0 else "RIGHT", maxf(_tag_glow[i], _glow))
		var bowl := PackedVector2Array()
		for k in range(13):
			var a := PI * k / 12.0
			bowl.append(pan_c + Vector2(cos(a) * pan_w / 2.0, sin(a) * pan_w * 0.22))
		draw_colored_polygon(bowl, BRASS)
		_draw_load(pan_c, pan_w, _left if i == 0 else _right)

	# Answer sign hanging above the pivot
	if _choice != "":
		var fs := 22
		var tw := font().get_string_size(_choice, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var r := Rect2(p.x - tw / 2.0 - 12, p.y - 70, tw + 24, 38)
		draw_line(Vector2(p.x, r.end.y), p, ClassTheme.WOOD, 2.0)
		draw_rect(r, ClassTheme.PARCHMENT)
		draw_rect(r, ClassTheme.GOLD.lerp(ClassTheme.GREEN, _glow), false, 3.0)
		draw_string(font(), Vector2(r.position.x + 12, r.position.y + 27), _choice, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ClassTheme.INK)


## Small engraved brass plaque naming a side; brightens with `glow`.
func _draw_side_tag(center: Vector2, pan_w: float, text: String, glow: float) -> void:
	var fs := maxi(11, int(_beam_half() * 0.085))
	var tw := font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var w := maxf(pan_w * 0.5, tw + 22.0)
	var h := fs + 9.0
	var r := Rect2(center - Vector2(w, h) / 2.0, Vector2(w, h))
	if glow > 0.0:
		var halo := ClassTheme.GOLD_LIGHT
		halo.a = 0.3 * glow
		draw_circle(center, w * 0.62, halo)
	draw_rect(r, BRASS.lerp(ClassTheme.GOLD_LIGHT, glow * 0.8))
	draw_rect(r, BRASS_DARK, false, 2.0)
	for x in [r.position.x + 5.0, r.end.x - 5.0]:
		draw_circle(Vector2(x, center.y), 1.8, BRASS_DARK)
	# Engraved: a light edge one pixel down-right, the dark cut on top
	var base := Vector2(center.x - tw / 2.0, center.y + fs * 0.36)
	var shine := ClassTheme.GOLD_LIGHT
	shine.a = 0.35 * (1.0 - glow)
	draw_string(font(), base + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, shine)
	draw_string(font(), base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, BRASS_DARK.lerp(ClassTheme.INK_DARK, glow))


## Gems piled in the pan (or a number tag when there are too many).
func _draw_load(pan_c: Vector2, pan_w: float, count: int) -> void:
	var gem_r := pan_w * 0.07
	if count <= MAX_GEMS:
		for i in range(count):
			var row := i / 4
			var col := i % 4
			var x := pan_c.x + (col - 1.5) * gem_r * 2.3
			var y := pan_c.y - gem_r - row * gem_r * 1.9 + sin(_time * 2.0 + i) * 1.2
			draw_circle(Vector2(x, y), gem_r, GEM)
			draw_circle(Vector2(x - gem_r * 0.3, y - gem_r * 0.3), gem_r * 0.35, Color(1, 1, 1, 0.7))
	var label := str(count)
	var fs := int(pan_w * 0.26)
	var tw := font().get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font(), Vector2(pan_c.x - tw / 2.0, pan_c.y + pan_w * 0.22 + fs + 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ClassTheme.GOLD_LIGHT)
