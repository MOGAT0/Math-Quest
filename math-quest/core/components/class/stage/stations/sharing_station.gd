extends Station
class_name SharingStation

# =====================================================================
#  Sharing candies equally (division):
#    {"type":"sharing","total":12,"friends":["Tim","Abby","Romeo"]}
#  A pile of wrapped candies at the top, one treat bag per friend along
#  the bottom. Right = the candies are dealt one by one into the bags
#  (round-robin), so every bag ends up with the same number; leftovers
#  stay in the pile.
#  "item": "cookie" shares cookies onto plates instead (Winter Solstice).
# =====================================================================

const WRAPS := [Color("#e2574c"), Color("#f2cf4a"), Color("#5cb85c"), Color("#4a8fe0"), Color("#b05ad6"), Color("#f29a3c")]
const BAG := Color("#c98b4a")
const BAG_DARK := Color("#8a5a2b")
const MAX_SHOWN := 60

var _total : int = 0
var _cookies : bool = false
var _friends : Array = []
var _dealt : float = 0.0        # candies dealt so far (animated)
var _shake : float = 0.0
var _time : float = 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func setup(q: Dictionary, answer_type: String) -> void:
	super.setup(q, answer_type)
	var v = q.get("visual", {})
	_friends = []
	if typeof(v) == TYPE_DICTIONARY:
		_total = clampi(int(v.get("total", 0)), 0, MAX_SHOWN)
		_cookies = str(v.get("item", "")) == "cookie"
		for f in v.get("friends", []):
			_friends.append(str(f))
	if _friends.is_empty():
		_friends = ["A", "B"]
	_dealt = 0.0
	_shake = 0.0


func action_label() -> String:
	return "SHARE!"


func cast_color() -> Color:
	return WRAPS[0]


## Deal: every bag gets one candy per pass until a full pass can't be made.
func success() -> void:
	var n := _friends.size()
	var to_deal := (_total / n) * n
	var tw := create_tween()
	tw.tween_property(self, "_dealt", float(to_deal), clampf(to_deal * 0.06, 0.4, 1.6))
	await tw.finished
	await get_tree().create_timer(0.3).timeout


func fail() -> void:
	var tw := create_tween()
	for a in [1.0, -1.0, 0.6, -0.4, 0.0]:
		tw.tween_property(self, "_shake", a, 0.07)
	await tw.finished


func _bag_rect(i: int) -> Rect2:
	var n := _friends.size()
	var w := minf(size.x * 0.8 / n, 90.0)
	var gap := (size.x - w * n) / (n + 1)
	return Rect2(gap + i * (w + gap), size.y * 0.6, w, size.y * 0.3)


## Pile positions: a loose heap in the top half.
func _pile_pos(k: int) -> Vector2:
	var cols := mini(maxi(_total, 1), 10)
	var r := float(k / cols)
	var c := float(k % cols) + (0.5 if int(r) % 2 == 1 else 0.0)
	return Vector2(size.x * 0.5 + (c - (cols - 1) / 2.0) * 34.0, size.y * 0.13 + r * 26.0 + (k % 3) * 3.0)


## Where candy k sits once dealt: in bag (k % n), stacked.
func _bag_pos(k: int) -> Vector2:
	var n := _friends.size()
	var bag := _bag_rect(k % n)
	var slot := k / n
	var per_row := maxi(int((bag.size.x - 12.0) / 24.0), 1)
	return bag.position + Vector2(16 + (slot % per_row) * 24.0, bag.size.y - 14 - (slot / per_row) * 18.0)


func _draw() -> void:
	if size.x < 40.0:
		return
	var f := font()
	var off := Vector2(_shake * 6.0, 0)
	# Bags
	for i in range(_friends.size()):
		var b := _bag_rect(i)
		b.position += off
		if _cookies:
			# A plate: a wide white ellipse at the bottom of the slot
			draw_set_transform(Vector2(b.get_center().x, b.end.y - 14), 0.0, Vector2(1.0, 0.32))
			draw_circle(Vector2.ZERO, b.size.x * 0.55, Color("#d9e4ec"))
			draw_circle(Vector2.ZERO, b.size.x * 0.42, Color("#f7fbff"))
			draw_set_transform(Vector2.ZERO)
		else:
			draw_rect(b, BAG)
			draw_rect(Rect2(b.position, Vector2(b.size.x, 6)), BAG_DARK)
			draw_rect(b, BAG_DARK, false, 2.0)
		var who : String = _friends[i]
		var tw := f.get_string_size(who, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string(f, Vector2(b.get_center().x - tw / 2.0, b.end.y + 16), who, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ClassTheme.GOLD_LIGHT)
	# Candies: the first `dealt` ones fly from the pile into the bags
	var dealt := int(floor(_dealt))
	var frac := _dealt - dealt
	for k in range(_total):
		var p : Vector2
		if k < dealt:
			p = _bag_pos(k)
		elif k == dealt and frac > 0.0:
			p = _pile_pos(k).lerp(_bag_pos(k), frac) + Vector2(0, -sin(frac * PI) * 30.0)
		else:
			p = _pile_pos(k) + off
		if _cookies:
			_cookie(p, k)
		else:
			_candy(p, WRAPS[k % WRAPS.size()])


func _candy(c: Vector2, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(-15, -6), c + Vector2(-7, 0), c + Vector2(-15, 6)]), col.darkened(0.15))
	draw_colored_polygon(PackedVector2Array([c + Vector2(15, -6), c + Vector2(7, 0), c + Vector2(15, 6)]), col.darkened(0.15))
	draw_circle(c, 8.5, col)
	draw_arc(c, 8.5, 0.0, TAU, 20, col.darkened(0.3), 1.2)
	draw_circle(c + Vector2(-3, -3), 2.2, Color(1, 1, 1, 0.6))


func _cookie(c: Vector2, k: int) -> void:
	draw_circle(c, 10.0, Color("#b9773a"))
	draw_circle(c, 8.5, Color("#d9a05b"))
	for j in range(4):
		var a := TAU * j / 4.0 + k
		draw_circle(c + Vector2.from_angle(a) * 4.5, 1.6, Color("#4a2c18"))
