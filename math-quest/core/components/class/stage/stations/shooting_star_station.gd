extends Station
class_name ShootingStarStation

# =====================================================================
#  Shooting stars in equal groups:
#    {"type":"shooting_stars","groups":3,"per":4}
#  One group after another streaks in from the top right and comes to
#  rest as a little cluster with a faint ring, so the stars can be
#  counted (in all, or by groups). Right = every star sparkles.
#  "creature": "bat" swaps the stars for flapping bats that swoop in from
#  the top left (the Night of Lanterns bat counting).
# =====================================================================

const STAR := Color("#fff4c2")
const RING := Color(0.75, 0.8, 1.0, 0.3)
const STREAK_TIME := 0.45

var _groups : int = 1
var _bats : bool = false
var _per : int = 1
var _sky : Array = []
var _arrive : Array = []        # per group, 0..1 (1 = resting in place)
var _sparkle : float = 0.0
var _value : String = ""
var _time : float = 0.0
var _streak : Tween


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func setup(q: Dictionary, answer_type: String) -> void:
	super.setup(q, answer_type)
	var v = q.get("visual", {})
	if typeof(v) == TYPE_DICTIONARY:
		_groups = clampi(int(v.get("groups", 1)), 1, 10)
		_per = clampi(int(v.get("per", 1)), 1, 12)
		_bats = str(v.get("creature", "")) == "bat"
	var rng := RandomNumberGenerator.new()
	rng.seed = _groups * 31 + _per
	_sky = []
	for i in range(36):
		_sky.append(Vector3(rng.randf(), rng.randf(), rng.randf_range(0.6, 1.5)))
	_sparkle = 0.0
	_value = ""
	_arrive = []
	for i in range(_groups):
		_arrive.append(0.0)
	# The groups streak in one after another (a new round stops the old one)
	if _streak and _streak.is_valid():
		_streak.kill()
	_streak = create_tween()
	var tw := _streak
	for i in range(_groups):
		tw.tween_method(_set_arrive.bind(i), 0.0, 1.0, STREAK_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


func _set_arrive(v: float, i: int) -> void:
	if i < _arrive.size():
		_arrive[i] = v


func preview(value: String) -> void:
	_value = value


func action_label() -> String:
	return "COUNT!"


func cast_color() -> Color:
	return STAR


func success() -> void:
	var tw := create_tween()
	tw.tween_property(self, "_sparkle", 1.0, 0.25)
	tw.tween_property(self, "_sparkle", 0.0, 0.45)
	await tw.finished


func fail() -> void:
	await get_tree().create_timer(0.4).timeout


## Where group i rests: a grid of clusters across the sky.
func _group_center(i: int) -> Vector2:
	var cols := mini(_groups, 5)
	var rows := int(ceil(_groups / float(cols)))
	var col := i % cols
	var row := i / cols
	var cell := Vector2(size.x * 0.9 / cols, size.y * 0.8 / rows)
	return Vector2(size.x * 0.05 + cell.x * (col + 0.5), size.y * 0.12 + cell.y * (row + 0.5))


func _cluster_radius() -> float:
	var cols := mini(_groups, 5)
	var rows := int(ceil(_groups / float(cols)))
	return minf(size.x * 0.9 / cols, size.y * 0.8 / rows) * 0.36


## Star j of a group: a small ring (or the middle for a single star).
func _offset(j: int) -> Vector2:
	if _per == 1:
		return Vector2.ZERO
	var r := _cluster_radius() * (0.55 if _per <= 6 else 0.7)
	var a := -PI / 2.0 + TAU * j / _per
	if _per > 6 and j % 2 == 1:
		r *= 0.55
	return Vector2.from_angle(a) * r


func _draw() -> void:
	if size.x < 40.0:
		return
	for s in _sky:
		var tw := 0.5 + 0.5 * sin(_time * s.z * 2.0 + s.y * 9.0)
		draw_circle(Vector2(s.x * size.x, s.y * size.y), s.z, Color(1, 1, 1, 0.12 + 0.25 * tw))
	var start := Vector2(-size.x * 0.1, -size.y * 0.15) if _bats else Vector2(size.x * 1.1, -size.y * 0.15)
	var sr := clampf(_cluster_radius() * 0.16, 3.0, 9.0)
	for i in range(_groups):
		var t : float = _arrive[i] if i < _arrive.size() else 1.0
		if t <= 0.0:
			continue
		var home := _group_center(i)
		var c := start.lerp(home, t)
		if t >= 1.0:
			draw_arc(home, _cluster_radius(), 0.0, TAU, 40, RING, 1.5)
		for j in range(_per):
			var p := c + _offset(j)
			if _bats:
				# Wings span ~4.4 r: keep them inside the group's ring
				_bat(p, clampf(_cluster_radius() / (2.4 if _per <= 4 else 4.0), 4.0, sr * 1.6), t < 1.0)
				continue
			if t < 1.0:
				# Streak: a fading tail behind the star
				var tail := (start - home).normalized() * size.x * 0.12 * (1.0 - t * 0.6)
				draw_line(p, p + tail, Color(1, 1, 1, 0.35), sr * 0.8)
			var glow := 0.6 + 0.4 * sin(_time * 4.0 + i + j) + _sparkle
			draw_circle(p, sr * 2.2, Color(STAR.r, STAR.g, STAR.b, 0.10 * glow))
			_star(p, sr * (1.0 + _sparkle * 0.5), STAR)


func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in range(8):
		var a := -PI / 2.0 + k * PI / 4.0
		pts.append(c + Vector2.from_angle(a) * (r if k % 2 == 0 else r * 0.4))
	draw_colored_polygon(pts, col)


## A little bat: dark body, two flapping wings, glinting eyes.
func _bat(c: Vector2, r: float, flying: bool) -> void:
	var flap := sin(_time * (16.0 if flying else 6.0) + c.x) * 0.5 + 0.5
	var body := Color("#2a2238")
	for side in [-1.0, 1.0]:
		var tip := c + Vector2(side * r * 2.2, -r * (0.2 + flap * 0.9))
		draw_colored_polygon(PackedVector2Array([c + Vector2(side * r * 0.3, -r * 0.2), tip,
			c + Vector2(side * r * 1.5, r * 0.3), c + Vector2(side * r * 0.9, r * 0.05),
			c + Vector2(side * r * 0.5, r * 0.4)]), body)
	draw_circle(c, r * 0.6, body)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.45, -r * 0.4), c + Vector2(-r * 0.25, -r * 0.9), c + Vector2(-r * 0.05, -r * 0.45)]), body)
	draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.45, -r * 0.4), c + Vector2(r * 0.25, -r * 0.9), c + Vector2(r * 0.05, -r * 0.45)]), body)
	draw_circle(c + Vector2(-r * 0.22, -r * 0.1), r * 0.12, Color("#ffd27a"))
	draw_circle(c + Vector2(r * 0.22, -r * 0.1), r * 0.12, Color("#ffd27a"))
