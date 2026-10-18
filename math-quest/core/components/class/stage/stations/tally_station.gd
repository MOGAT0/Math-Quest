extends Station
class_name TallyStation

# =====================================================================
#  A snowball fight scoreboard in tally marks:
#    {"type":"tally","teams":[{"name":"Red","count":13},{"name":"Blue","count":9}]}
#  Each team has a snow fort with its banner and its hits written as
#  tally marks (four sticks and a slash for every 5). Right = snowballs
#  fly between the forts and the marks glow.
# =====================================================================

const SNOW := Color("#eef6fb")
const SNOW_SHADE := Color("#c9dbe6")
const CHALK := Color("#f4f1e8")
const TEAM_COLORS := {"red": Color("#d64545"), "blue": Color("#3a6fd8"), "green": Color("#3f8a52"), "yellow": Color("#d9a92b")}

var _teams : Array = []        # [{"name", "count"}]
var _glow : float = 0.0:
	set(v):
		_glow = v
		queue_redraw()
var _throw : float = 0.0:
	set(v):
		_throw = v
		queue_redraw()
var _shake : float = 0.0:
	set(v):
		_shake = v
		queue_redraw()


func setup(q: Dictionary, answer_type: String) -> void:
	super.setup(q, answer_type)
	_teams = []
	var v = q.get("visual", {})
	if typeof(v) == TYPE_DICTIONARY:
		for t in v.get("teams", []):
			_teams.append({"name": str(t.get("name", "")), "count": clampi(int(t.get("count", 0)), 0, 40)})
	_glow = 0.0
	_throw = 0.0
	_shake = 0.0
	queue_redraw()


func action_label() -> String:
	return "SCORE!"


func cast_color() -> Color:
	return SNOW


func success() -> void:
	_throw = 0.0
	var tw := create_tween()
	tw.tween_property(self, "_throw", 1.0, 0.6)
	tw.parallel().tween_property(self, "_glow", 1.0, 0.3)
	tw.tween_property(self, "_glow", 0.0, 0.3)
	tw.tween_property(self, "_throw", 0.0, 0.01)
	await tw.finished


func fail() -> void:
	var tw := create_tween()
	for a in [1.0, -1.0, 0.6, -0.4, 0.0]:
		tw.tween_property(self, "_shake", a, 0.07)
	await tw.finished


func _fort_rect(i: int) -> Rect2:
	var n := maxi(_teams.size(), 1)
	var w := size.x * 0.9 / n
	return Rect2(size.x * 0.05 + w * i + 8, size.y * 0.2, w - 16, size.y * 0.72)


func _draw() -> void:
	if size.x < 40.0:
		return
	var f := font()
	draw_rect(Rect2(0, size.y * 0.82, size.x, size.y * 0.18), SNOW_SHADE)
	for i in range(_teams.size()):
		var t : Dictionary = _teams[i]
		var r := _fort_rect(i)
		r.position.x += _shake * 6.0
		var col : Color = TEAM_COLORS.get(str(t["name"]).to_lower(), Color("#8a6fd4"))
		# Snow fort with a crenellated top
		draw_rect(Rect2(r.position + Vector2(0, 18), r.size - Vector2(0, 18)), SNOW)
		for k in range(5):
			var bw := r.size.x / 5.0
			if k % 2 == 0:
				draw_rect(Rect2(r.position.x + bw * k, r.position.y + 6, bw, 14), SNOW)
		draw_rect(Rect2(r.position + Vector2(0, 18), r.size - Vector2(0, 18)), SNOW_SHADE, false, 2.0)
		# Team banner
		draw_rect(Rect2(r.position.x + r.size.x * 0.5 - 1, r.position.y - 26, 2, 34), Color("#5a3b22"))
		draw_colored_polygon(PackedVector2Array([Vector2(r.position.x + r.size.x * 0.5 + 1, r.position.y - 26),
			Vector2(r.position.x + r.size.x * 0.5 + 26, r.position.y - 19), Vector2(r.position.x + r.size.x * 0.5 + 1, r.position.y - 12)]), col)
		var title := "%s team" % str(t["name"])
		var tw := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_string(f, Vector2(r.get_center().x - tw / 2.0, r.position.y + 42), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)
		_draw_tally(int(t["count"]), Rect2(r.position + Vector2(10, 56), r.size - Vector2(20, 70)), col)
	# Snowballs flying between the forts on a right answer
	if _throw > 0.0 and _teams.size() >= 2:
		for k in range(4):
			var a := _fort_rect(0).get_center()
			var b := _fort_rect(1).get_center()
			var t := fmod(_throw + k * 0.22, 1.0)
			var from := a if k % 2 == 0 else b
			var to := b if k % 2 == 0 else a
			var p := from.lerp(to, t) + Vector2(0, -sin(t * PI) * 60.0)
			draw_circle(p, 6.0, Color.WHITE)
			draw_arc(p, 6.0, 0.0, TAU, 12, SNOW_SHADE, 1.0)


## Tally marks: bundles of five (four sticks + a slash), wrapping in rows.
func _draw_tally(count: int, area: Rect2, team: Color) -> void:
	var stick_h := 26.0
	var gap := 6.0
	var bundle_w := 4 * gap + 14.0
	var per_row := maxi(int(area.size.x / bundle_w), 1)
	var col := CHALK.lerp(team, 0.15)
	col = col.lerp(Color("#fff3a0"), _glow * 0.7)
	var ink := Color("#2a2f44")
	for b in range(int(ceil(count / 5.0))):
		var row := b / per_row
		var x0 := area.position.x + (b % per_row) * bundle_w
		var y0 := area.position.y + row * (stick_h + 12.0)
		var sticks := mini(5, count - b * 5)
		for s in range(mini(sticks, 4)):
			var x := x0 + s * gap + 2
			draw_line(Vector2(x, y0), Vector2(x, y0 + stick_h), ink, 3.0)
			draw_line(Vector2(x, y0), Vector2(x, y0 + stick_h), col, 1.2)
		if sticks == 5:
			draw_line(Vector2(x0 - 3, y0 + stick_h - 4), Vector2(x0 + 3 * gap + 7, y0 + 4), ink, 3.0)
			draw_line(Vector2(x0 - 3, y0 + stick_h - 4), Vector2(x0 + 3 * gap + 7, y0 + 4), col, 1.2)
