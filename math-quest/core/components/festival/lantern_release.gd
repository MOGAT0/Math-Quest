extends Node2D
class_name LanternRelease

# =====================================================================
#  Festival ending ("ending": "lanterns"): paper wish lanterns lift off
#  around the festival center, sway gently as they rise into the night
#  sky and fade away. Frees itself when they are gone.
# =====================================================================

const COUNT := 14
const SPREAD := 90.0           # how far around the center they start
const RISE := 260.0            # how high they float
const LIFE := 6.5              # seconds from lift-off to gone
const STAGGER := 1.6           # lift-offs spread over this many seconds
const COLORS := ["#ffb347", "#ffd27a", "#ff8f6b", "#ffe9a8"]

var _lanterns : Array = []     # {"start", "delay", "sway", "color", "size", "light"}
## Optional lift-off points as offsets from this node (the festival
## center), e.g. the lit lanterns of the Night of Lanterns parade;
## empty = random spots around the center.
var starts : Array = []
var _time : float = 0.0


func _ready() -> void:
	z_index = 20   # above the festival ground and the people
	var n := starts.size() if not starts.is_empty() else COUNT
	for i in range(n):
		var a := randf() * TAU
		var from := Vector2(cos(a), sin(a) * 0.6) * randf_range(10.0, SPREAD)
		if not starts.is_empty():
			from = starts[i]
		_lanterns.append({
			"start": from,
			"delay": randf() * STAGGER * (0.4 if not starts.is_empty() else 1.0),
			"sway": randf() * TAU,
			"color": Color(COLORS[i % COLORS.size()]),
			"size": randf_range(0.8, 1.2),
		})
		# Each lantern carries a little light, so it glows in the dark
		var light := GlowLight.make(Color(COLORS[i % COLORS.size()]), 18.0, 0.0)
		add_child(light)
		_lanterns.back()["light"] = light


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()
	if _time > LIFE + STAGGER + 0.2:
		queue_free()


func _draw() -> void:
	for l in _lanterns:
		var t : float = (_time - l["delay"]) / LIFE
		if t <= 0.0 or t >= 1.0:
			l["light"].energy = 0.0   # not launched yet / already gone
			continue
		var s : float = l["size"]
		var p : Vector2 = l["start"] + Vector2(sin(_time * 1.3 + l["sway"]) * 6.0 * t, -RISE * ease(t, 0.7))
		var alpha := clampf(t * 6.0, 0.0, 1.0) * clampf((1.0 - t) * 3.0, 0.0, 1.0)
		var col : Color = l["color"]
		var flicker := 0.8 + 0.2 * sin(_time * 9.0 + l["sway"])
		var light : PointLight2D = l["light"]
		light.position = p
		light.energy = 0.9 * alpha * flicker
		# Warm halo, paper body (wider at the top), flame glow at the bottom
		draw_circle(p, 9.0 * s, Color(col.r, col.g, col.b, 0.18 * alpha * flicker))
		var body := PackedVector2Array([
			p + Vector2(-3.6, -5.0) * s, p + Vector2(3.6, -5.0) * s,
			p + Vector2(2.8, 4.0) * s, p + Vector2(-2.8, 4.0) * s])
		draw_colored_polygon(body, Color(col.r, col.g, col.b, 0.9 * alpha))
		draw_line(p + Vector2(-3.6, -5.0) * s, p + Vector2(3.6, -5.0) * s, Color(0.55, 0.3, 0.15, alpha), 1.0)
		draw_circle(p + Vector2(0, 3.0) * s, 1.4 * s, Color(1.0, 0.95, 0.7, alpha * flicker))
