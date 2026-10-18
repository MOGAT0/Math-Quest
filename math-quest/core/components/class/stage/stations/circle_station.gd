extends Station
class_name CircleStation

# =====================================================================
#  Magic circle on the floor: multiplication, division and groups.
#  "4 x 3" floats 4 groups of 3 rune-orbs around the circle; the typed
#  answer glows in the middle; right = the circle fires, wrong = it
#  shatters (see magic_circle.gd).
# =====================================================================

const ORB := Color("#b79ac9")
const ORB_CORE := Color("#f3e9ff")
const MAX_ORBS := 60

var _circle : MagicCircle
var _bundles : Array = []    # orb count per group
var _time : float = 0.0
var _orb_glow : float = 0.0:
	set(v):
		_orb_glow = v
		queue_redraw()


func _init() -> void:
	super._init()
	_circle = MagicCircle.new()
	add_child(_circle)
	resized.connect(_place_circle)


func setup(q: Dictionary, answer_type: String) -> void:
	super.setup(q, answer_type)
	_read_groups()
	_orb_glow = 0.0
	_place_circle()
	_circle.begin(maxi(4, mini(_bundles.size(), 12)) if not _bundles.is_empty() else 8)


## Groups from the visual ("groups"), or "a x b" / "a ÷ b" in the text.
func _read_groups() -> void:
	_bundles = []
	var v = question.get("visual", {})
	if typeof(v) == TYPE_DICTIONARY and str(v.get("type", "")) == "groups":
		for b in VisualBuilder.read_bundles(v.get("groups", {})):
			_bundles.append(int(b["count"]))
	else:
		var re := RegEx.create_from_string("(\\d+)\\s*([x×*÷/])\\s*(\\d+)")
		var m := re.search(str(question.get("text", "")))
		if m:
			var a := m.get_string(1).to_int()
			var b := m.get_string(3).to_int()
			if m.get_string(2) in ["÷", "/"]:
				# a shared into b groups
				if b > 0 and a % b == 0:
					for i in range(b):
						_bundles.append(a / b)
			else:
				for i in range(a):
					_bundles.append(b)
	var total := 0
	for n in _bundles:
		total += n
	if total > MAX_ORBS or _bundles.size() > 12:
		_bundles = []


func _place_circle() -> void:
	if _circle == null:
		return
	var d := minf(size.x * 0.62, size.y * 0.78)
	_circle.size = Vector2(d, d)
	_circle.position = Vector2(size.x * 0.5 - d / 2.0, size.y * 0.5 - d / 2.0)


func preview(value: String) -> void:
	_circle.charge(value)


func action_label() -> String:
	return "CAST!"


func cast_color() -> Color:
	return ORB


func success() -> void:
	var tw := create_tween()
	tw.tween_property(self, "_orb_glow", 1.0, 0.25)
	ClassTheme.burst(self, size / 2.0, ORB_CORE, 30, 380.0, -40.0, 6.0)
	await _circle.fire()


func fail() -> void:
	await _circle.shatter()


func _process(delta: float) -> void:
	_time += delta
	if not _bundles.is_empty():
		queue_redraw()


func _draw() -> void:
	if _bundles.is_empty():
		return
	var c := size / 2.0
	var groups := _bundles.size()
	var ring := minf(size.x * 0.62, size.y * 0.78) * 0.62
	var orb_r := clampf(ring * 0.07, 4.0, 10.0)
	for g in range(groups):
		var per : int = _bundles[g]
		var a := TAU * g / groups - PI / 2.0 + _time * 0.15
		var center := c + Vector2(cos(a), sin(a)) * ring
		# Each group is a small cluster of orbs (its own size)
		for i in range(per):
			var ia := TAU * i / per + _time * 0.8
			var spread := 0.0 if per == 1 else orb_r * (1.4 + per * 0.12)
			var p := center + Vector2(cos(ia), sin(ia)) * spread
			var glow := ORB
			glow.a = 0.35 + 0.35 * _orb_glow
			draw_circle(p, orb_r * (1.5 + _orb_glow * 0.5), glow)
			draw_circle(p, orb_r * 0.6, ORB_CORE)
