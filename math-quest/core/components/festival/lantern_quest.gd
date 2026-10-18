extends Node2D
class_name LanternQuest

# =====================================================================
#  "Light the lanterns" (festival data "lanterns"): unlit paper lanterns
#  on posts stand around the festival ground. Each one is sealed by a
#  number puzzle: talk to it (E), solve it (FestivalDirector opens the
#  RiddlePopup) and it lights up with a warm glow and a real night light.
#  A counter under the stamp card shows "🏮 Lanterns lit 3 / 8".
#
#  Spots are seeded by the calendar day, so after a reload the lanterns
#  stand in the same places and the ones already lit stay lit.
#
#  "item": "snowman" turns the lanterns into unfinished snowmen (only a
#  big snowball) that are built when their puzzle is solved (Winter
#  Solstice); "label" names them on the counter ("Snowmen built").
#
#  Signals: lantern_asked(index) (open the puzzle), lantern_lit(index,
#  lit_count), all_lit.
# =====================================================================

signal lantern_asked(index: int)
signal lantern_lit(index: int, lit_count: int)
signal all_lit

const MIN_SPACING := 30.0
const SNAP_LIMIT := 12.0
const SPOT_TRIES := 40

var data : Dictionary = {}
var total : int = 8
var lit : Array = []            # indices already lit

var _world : Node2D
var _lanterns : Array = []      # QuestLantern by index
var _meter : LanternMeter = null


func begin(world: Node2D, quest: Dictionary, center: Vector2, avoid: Array, ui: CanvasLayer,
		lit_before: Array = [], day_seed: int = 0) -> void:
	_world = world
	data = quest
	total = int(quest.get("count", 8))
	lit = []
	for i in lit_before:
		lit.append(int(i))
	y_sort_enabled = true

	var rng := RandomNumberGenerator.new()
	rng.seed = day_seed
	var spots : Array = avoid.duplicate()
	var player = world.get("player")
	for i in range(total):
		var lantern := QuestLantern.new()
		lantern.index = i
		lantern.snowman = str(quest.get("item", "lantern")) == "snowman"
		lantern.setup({"name": "Lantern"})
		lantern.player_body = player
		if player is CanvasItem:
			lantern.z_index = player.z_index
			lantern.z_as_relative = player.z_as_relative
		add_child(lantern)
		lantern.global_position = _spot(rng, center, spots)
		spots.append(lantern.global_position)
		lantern.interacted.connect(func(_n): _on_asked(i))
		_lanterns.append(lantern)
		if lit.has(i):
			lantern.light(false)

	_meter = LanternMeter.new()
	ui.add_child(_meter)
	_meter.label = str(quest.get("label", "Lanterns lit"))
	_meter.set_count(lit.size(), total, str(quest.get("icon", "🏮")))


## The ring around the center, away from the stalls and other lanterns.
func _spot(rng: RandomNumberGenerator, center: Vector2, spots: Array) -> Vector2:
	var min_r := float(data.get("min_radius", 120))
	var max_r := float(data.get("max_radius", 210))
	var best := center + Vector2(min_r, 0)
	for t in range(SPOT_TRIES):
		var a := rng.randf() * TAU
		var raw := center + Vector2(cos(a), sin(a) * 0.75) * rng.randf_range(min_r, max_r)
		var p := SpawnSpots.on_navmesh(_world, raw)
		best = p
		if p.distance_to(raw) > SNAP_LIMIT:
			continue
		var clear := true
		for s in spots:
			if p.distance_to(s) < MIN_SPACING:
				clear = false
				break
		if clear:
			break
	return best


func _on_asked(i: int) -> void:
	if not lit.has(i):
		lantern_asked.emit(i)


## The puzzle was solved: light lantern i.
func light(i: int) -> void:
	if lit.has(i) or i < 0 or i >= _lanterns.size():
		return
	lit.append(i)
	_lanterns[i].light(true)
	_meter.set_count(lit.size(), total, str(data.get("icon", "🏮")))
	ClassTheme.pop(_meter, 1.08)
	lantern_lit.emit(i, lit.size())
	if lit.size() >= total:
		all_lit.emit()


func is_done() -> bool:
	return lit.size() >= total


## World positions of the lit paper lanterns (for the parade).
func lit_positions() -> Array:
	var out : Array = []
	for i in lit:
		out.append(_lanterns[i].lantern_point())
	return out


## The parade: the paper lanterns leave their posts.
func release_all() -> void:
	for l in _lanterns:
		l.released = true
		l.light_off()


func _exit_tree() -> void:
	if _meter and is_instance_valid(_meter):
		_meter.queue_free()


# =====================================================================
#  A lantern on a post (EventNPC: "!" mark, E to interact, y-sorted by
#  the foot of the post). Unlit = dark paper; lit = warm flicker + light.
# =====================================================================
class QuestLantern extends EventNPC:
	const POST_H := 30.0
	var index : int = 0
	var snowman : bool = false     # a snowman to build instead of a lantern
	var is_lit : bool = false
	var released : bool = false
	var _glow : PointLight2D
	var _t : float = randf() * TAU
	var _pop : float = 0.0

	func setup(def: Dictionary) -> void:
		super.setup(def)
		_sprite.visible = false          # drawn instead of a sprite
		_mark_y = -POST_H - 22.0
		set_mark("?")
		_glow = GlowLight.make(Color("#ffb347"), 30.0, 0.0)
		_glow.position = Vector2(6, -POST_H + 8)
		add_child(_glow)

	func light(animate: bool) -> void:
		is_lit = true
		set_mark("")
		if animate:
			_pop = 1.0
			create_tween().tween_property(self, "_pop", 0.0, 0.5)

	func light_off() -> void:
		_glow.energy = 0.0

	func _draw_snowman() -> void:
		var white := Color("#f4f8fb")
		var shade := Color("#c9dbe6")
		draw_circle(Vector2(0, -7), 8.0, white)
		draw_arc(Vector2(0, -7), 8.0, 0.2, PI - 0.2, 12, shade, 1.2)
		if not is_lit:
			return
		var s := 1.0 + _pop * 0.4
		draw_circle(Vector2(0, -18) * s, 6.0 * s, white)
		draw_circle(Vector2(0, -27) * s, 4.5 * s, white)
		draw_circle(Vector2(-1.6, -28) * s, 0.8, Color("#1a1a1a"))
		draw_circle(Vector2(1.6, -28) * s, 0.8, Color("#1a1a1a"))
		draw_colored_polygon(PackedVector2Array([Vector2(0, -27) * s, Vector2(5, -26) * s, Vector2(0, -25.6) * s]), Color("#f29a3c"))
		draw_rect(Rect2(Vector2(-4.5, -24) * s, Vector2(9, 2.2) * s), Color("#d64545"))
		draw_rect(Rect2(Vector2(2.0, -24) * s, Vector2(2.2, 6) * s), Color("#d64545"))
		draw_rect(Rect2(Vector2(-4.5, -32.5) * s, Vector2(9, 1.5) * s), Color("#23233a"))
		draw_rect(Rect2(Vector2(-3, -37.5) * s, Vector2(6, 5.2) * s), Color("#23233a"))
		for k in range(2):
			draw_circle(Vector2(0, -20 + k * 3.2) * s, 0.8, Color("#1a1a1a"))

	func lantern_point() -> Vector2:
		return global_position + Vector2(6, -POST_H + 8)

	func _process(delta: float) -> void:
		super._process(delta)
		_t += delta
		if is_lit and not released and not snowman:
			_glow.energy = (0.9 + 0.15 * sin(_t * 7.0)) * (1.0 + _pop)
		queue_redraw()

	func _draw() -> void:
		if snowman:
			_draw_snowman()
			return
		var wood := Color("#5a3b22")
		draw_rect(Rect2(-1, -POST_H, 2, POST_H), wood)
		draw_rect(Rect2(-1, -POST_H, 8, 1.5), wood)
		if released:
			return
		var c := Vector2(6, -POST_H + 8 + sin(_t * 1.5) * 0.5)
		var paper := Color("#ff9a3c") if is_lit else Color("#6b5a52")
		var flick := 0.85 + 0.15 * sin(_t * 9.0) if is_lit else 1.0
		if is_lit:
			draw_circle(c, 7.0 * (1.0 + _pop * 0.6), Color(1.0, 0.7, 0.3, 0.25 * flick))
		draw_line(Vector2(6, -POST_H + 1.5), c + Vector2(0, -5), Color(0.2, 0.15, 0.1), 0.8)
		var body := PackedVector2Array([c + Vector2(-3.5, -4.5), c + Vector2(3.5, -4.5), c + Vector2(4.2, 0),
			c + Vector2(3.5, 4.5), c + Vector2(-3.5, 4.5), c + Vector2(-4.2, 0)])
		draw_colored_polygon(body, Color(paper.r * flick, paper.g * flick, paper.b * flick))
		draw_line(c + Vector2(-4, -4.8), c + Vector2(4, -4.8), Color("#3e2816"), 1.2)
		draw_line(c + Vector2(-4, 4.8), c + Vector2(4, 4.8), Color("#3e2816"), 1.2)
		if is_lit:
			draw_circle(c + Vector2(0, 1), 1.4, Color(1.0, 0.95, 0.7, flick))


# =====================================================================
#  HUD: "🏮 Lanterns lit 3 / 8". Sits under the stamp card.
# =====================================================================
class LanternMeter extends PanelContainer:
	const GAP := 8.0
	var label : String = "Lanterns lit"
	var _count : Label
	var _bar : ProgressBar

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		position = Vector2(16, 200)
		add_theme_stylebox_override("panel", ClassTheme.flat(Color(0.14, 0.1, 0.06, 0.88), Color("#ff9a3c"), 10, 2, 10))
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 4)
		add_child(col)
		_count = ClassTheme.label("", 17, ClassTheme.PARCHMENT)
		col.add_child(_count)
		_bar = ProgressBar.new()
		_bar.show_percentage = false
		_bar.custom_minimum_size = Vector2(200, 8)
		_bar.add_theme_stylebox_override("background", ClassTheme.flat(Color(0, 0, 0, 0.4), Color.TRANSPARENT, 4))
		_bar.add_theme_stylebox_override("fill", ClassTheme.flat(Color("#ff9a3c"), Color.TRANSPARENT, 4))
		col.add_child(_bar)

	func set_count(n: int, total: int, icon: String) -> void:
		_count.text = "%s %s  %d / %d" % [icon, label, n, total]
		_bar.max_value = maxi(total, 1)
		_bar.value = n

	func _process(_delta: float) -> void:
		var y := 200.0
		for c in get_parent().get_children() if get_parent() else []:
			if c is StampCard and c.visible:
				y = c.position.y + c.size.y + GAP
		position = Vector2(16, y)
