extends Station
class_name PotionStation

# =====================================================================
#  Cauldron: Matthew brews the answer.
#  Ingredient jars show the numbers from the question, typing makes the
#  brew bubble, a right answer gives a sparkling puff, a wrong one a
#  murky splash and smoke.  All vector drawn.
#  A "visual": {"brew": "cocoa"} makes it a pot of hot cocoa with
#  marshmallow bubbles (Winter Solstice booth).
# =====================================================================

const BREWS := [Color("#4fb3a9"), Color("#d46fa0"), Color("#8d6fd4"), Color("#8fc45a"), Color("#e09a3c")]
const IRON := Color("#2b2630")
const IRON_LIGHT := Color("#4a4352")
const MURK := Color("#5b5340")
const FIRE_A := Color("#f2a03d")
const FIRE_B := Color("#f5d76e")

var _brew : Color = BREWS[0]
var _cocoa : bool = false
var _liquid : Color = BREWS[0]
var _value : String = ""
var _bubbles : Array = []        # {x, y, r, speed}
var _target_bubbles : int = 3
var _time : float = 0.0
var _operands : Array = []
var _operator : String = ""
var _puff : float = 0.0:
	set(v):
		_puff = v
		queue_redraw()
var _smoke : float = 0.0:
	set(v):
		_smoke = v
		queue_redraw()


func setup(q: Dictionary, answer_type: String) -> void:
	super.setup(q, answer_type)
	var v = q.get("visual", {})
	_cocoa = typeof(v) == TYPE_DICTIONARY and str(v.get("brew", "")) == "cocoa"
	_brew = Color("#7b4a2a") if _cocoa else BREWS[randi() % BREWS.size()]
	_liquid = _brew
	_value = ""
	_puff = 0.0
	_smoke = 0.0
	_bubbles.clear()
	_target_bubbles = 3
	_read_recipe()


## "7 + 5" -> two jars labelled 7 and 5 with a + between them.
func _read_recipe() -> void:
	_operands = []
	_operator = ""
	var text := str(question.get("text", ""))
	var re := RegEx.create_from_string("(\\d+)\\s*([+\\-x×÷])\\s*(\\d+)")
	var m := re.search(text)
	if m:
		_operands = [m.get_string(1), m.get_string(3)]
		_operator = m.get_string(2)


func preview(value: String) -> void:
	_value = value
	var n := value.to_int() if value.is_valid_int() else value.length()
	_target_bubbles = clampi(3 + n, 3, 30)


func action_label() -> String:
	return "BREW!"


func cast_color() -> Color:
	return _brew.lightened(0.4)


func success() -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "_puff", 1.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_liquid", _brew.lightened(0.35), 0.3)
	ClassTheme.burst(self, _surface_center(), ClassTheme.GOLD_LIGHT, 36, 420.0, -60.0, 6.0)
	ClassTheme.burst(self, _surface_center(), _brew.lightened(0.3), 24, 300.0, -40.0, 8.0)
	_target_bubbles = 30
	await tw.finished


func fail() -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "_liquid", MURK, 0.35)
	tw.tween_property(self, "_smoke", 1.0, 1.0)
	ClassTheme.burst(self, _surface_center(), MURK, 22, 260.0, 500.0, 7.0)
	_target_bubbles = 2
	ClassTheme.shake(self)
	await tw.finished


# ---------------------------------------------------------------- update --

func _process(delta: float) -> void:
	_time += delta
	var geo := _geometry()
	# Spawn / retire bubbles towards the target count
	while _bubbles.size() < _target_bubbles:
		_bubbles.append(_new_bubble(geo, true))
	for b in _bubbles:
		b["y"] -= b["speed"] * delta
	for i in range(_bubbles.size() - 1, -1, -1):
		if _bubbles[i]["y"] < geo["rim_y"] - geo["pw"] * 0.55:
			if _bubbles.size() > _target_bubbles:
				_bubbles.remove_at(i)
			else:
				_bubbles[i] = _new_bubble(geo, false)
	queue_redraw()


func _new_bubble(geo: Dictionary, anywhere: bool) -> Dictionary:
	var half : float = geo["pw"] * 0.38
	var start_y : float = geo["rim_y"]
	if anywhere:
		start_y -= randf() * geo["pw"] * 0.5
	return {
		"x": geo["cx"] + randf_range(-half, half),
		"y": start_y,
		"r": randf_range(3.0, 7.0) * (geo["pw"] / 220.0),
		"speed": randf_range(30.0, 70.0),
	}


func _geometry() -> Dictionary:
	var pw := minf(size.x * 0.62, size.y * 0.72)
	var ph := pw * 0.62
	var cx := size.x * 0.5
	var bottom := size.y * 0.84
	return {"pw": pw, "ph": ph, "cx": cx, "bottom": bottom, "rim_y": bottom - ph}


func _surface_center() -> Vector2:
	var g := _geometry()
	return Vector2(g["cx"], g["rim_y"])


# ------------------------------------------------------------------ draw --

func _ellipse(center: Vector2, radii: Vector2, segments: int = 32) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(segments):
		var a := TAU * i / segments
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	return pts


func _draw() -> void:
	if size.x < 40.0 or size.y < 40.0:
		return
	var g := _geometry()
	var pw : float = g["pw"]
	var ph : float = g["ph"]
	var cx : float = g["cx"]
	var rim_y : float = g["rim_y"]
	var bottom : float = g["bottom"]

	_draw_fire(cx, bottom, pw)

	# Legs
	for lx in [-0.3, 0.3]:
		draw_rect(Rect2(cx + pw * lx - pw * 0.04, bottom - ph * 0.12, pw * 0.08, ph * 0.22), IRON)

	# Bowl
	var bowl := PackedVector2Array()
	for i in range(25):
		var a := PI * i / 24.0
		bowl.append(Vector2(cx + cos(a) * pw / 2.0, rim_y + sin(a) * ph))
	draw_colored_polygon(bowl, IRON)
	# Highlight on the bowl
	draw_arc(Vector2(cx, rim_y), pw * 0.4, PI * 0.62, PI * 0.88, 12, IRON_LIGHT, pw * 0.03, true)

	# Liquid surface + rim
	var rim_r := Vector2(pw * 0.52, pw * 0.1)
	draw_colored_polygon(_ellipse(Vector2(cx, rim_y), rim_r), IRON_LIGHT)
	var swirl := sin(_time * 1.6) * 0.04
	draw_colored_polygon(_ellipse(Vector2(cx, rim_y + pw * 0.01), Vector2(pw * (0.45 + swirl * 0.2), pw * 0.075)), _liquid)
	var shine := _liquid.lightened(0.35)
	shine.a = 0.6
	draw_arc(Vector2(cx - pw * 0.08, rim_y), pw * 0.12, PI * 1.1, PI * 1.6, 8, shine, 3.0, true)

	# Bubbles rising out of the brew
	for b in _bubbles:
		var col := _liquid.lightened(0.25)
		col.a = clampf(1.0 - (rim_y - b["y"]) / (pw * 0.55), 0.0, 1.0)
		if _cocoa:
			draw_circle(Vector2(b["x"], b["y"]), b["r"], Color(1, 0.97, 0.92, col.a))   # marshmallows
		else:
			draw_arc(Vector2(b["x"], b["y"]), b["r"], 0.0, TAU, 12, col, 2.0, true)

	_draw_recipe(cx, rim_y, pw)

	# Answer plate on the front of the cauldron
	var plate := Rect2(cx - pw * 0.2, rim_y + ph * 0.32, pw * 0.4, ph * 0.38)
	draw_rect(plate, ClassTheme.WOOD_DARK)
	draw_rect(plate, ClassTheme.GOLD, false, 2.0)
	var shown := _value if _value != "" else "?"
	var fs := int(plate.size.y * 0.62)
	var tw := font().get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if tw > plate.size.x * 0.9:
		# Shrink long answers ("neither side") so they stay on the plate
		fs = maxi(8, int(fs * plate.size.x * 0.9 / tw))
		tw = font().get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font(), Vector2(cx - tw / 2.0, plate.position.y + plate.size.y * 0.5 + fs * 0.35), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ClassTheme.GOLD_LIGHT)

	# Success: sparkling rings rising from the brew
	if _puff > 0.0:
		for i in range(3):
			var t := clampf(_puff * 1.3 - i * 0.15, 0.0, 1.0)
			var col := ClassTheme.GOLD_LIGHT.lerp(_brew.lightened(0.4), i / 2.0)
			col.a = 1.0 - t
			draw_arc(Vector2(cx, rim_y - pw * 0.5 * t), pw * (0.2 + t * 0.5), 0.0, TAU, 40, col, 4.0, true)

	# Failure: grey smoke clouds drifting up
	if _smoke > 0.0:
		for i in range(5):
			var t := clampf(_smoke * 1.4 - i * 0.1, 0.0, 1.0)
			var col := Color(0.45, 0.43, 0.4, 0.55 * (1.0 - t))
			var x := cx + (i - 2) * pw * 0.12 + sin(_time * 2.0 + i) * 6.0
			draw_circle(Vector2(x, rim_y - pw * 0.7 * t), pw * (0.07 + t * 0.08), col)


func _draw_fire(cx: float, bottom: float, pw: float) -> void:
	for i in range(5):
		var x := cx + (i - 2) * pw * 0.12
		var h := pw * (0.12 + 0.05 * sin(_time * 9.0 + i * 1.7))
		var w := pw * 0.07
		var flame := PackedVector2Array([Vector2(x - w, bottom + pw * 0.08), Vector2(x, bottom + pw * 0.08 - h), Vector2(x + w, bottom + pw * 0.08)])
		draw_colored_polygon(flame, FIRE_A)
		var inner := PackedVector2Array([Vector2(x - w * 0.5, bottom + pw * 0.08), Vector2(x, bottom + pw * 0.08 - h * 0.55), Vector2(x + w * 0.5, bottom + pw * 0.08)])
		draw_colored_polygon(inner, FIRE_B)


## Two floating ingredient jars (one per number) with the operator between.
func _draw_recipe(cx: float, rim_y: float, pw: float) -> void:
	if _operands.size() < 2:
		return
	var y := rim_y - pw * 0.62 + sin(_time * 2.0) * 4.0
	var jar_w := pw * 0.22
	var jar_h := pw * 0.26
	var fs := int(jar_h * 0.42)
	for i in range(2):
		var x := cx + (-1 if i == 0 else 1) * pw * 0.32
		var body := Rect2(x - jar_w / 2.0, y, jar_w, jar_h)
		var glass := Color(0.85, 0.9, 0.95, 0.35)
		draw_rect(body, glass)
		draw_rect(Rect2(x - jar_w / 2.0, y + jar_h * 0.45, jar_w, jar_h * 0.55), _brew.darkened(0.15 * i))
		draw_rect(body, ClassTheme.CHALK, false, 2.0)
		draw_rect(Rect2(x - jar_w * 0.3, y - jar_h * 0.14, jar_w * 0.6, jar_h * 0.14), ClassTheme.WOOD)
		var txt := str(_operands[i])
		var tw := font().get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font(), Vector2(x - tw / 2.0, y + jar_h * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ClassTheme.CHALK)
	var op_w := font().get_string_size(_operator, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font(), Vector2(cx - op_w / 2.0, y + jar_h * 0.55), _operator, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ClassTheme.GOLD_LIGHT)
