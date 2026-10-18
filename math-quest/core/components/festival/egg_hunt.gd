extends Node2D
class_name EggHunt

# =====================================================================
#  A festival egg hunt (FestivalDirector, "hunt" in the festival data).
#
#  Eggs are hidden min_radius..max_radius around the festival center, on
#  walkable ground and away from the stalls. There are no arrows: an egg
#  only fades in when Matthew is close (reveal), and the HuntMeter on the
#  HUD says how warm he is (distance to the nearest egg still hidden).
#  One golden egg is even harder to spot (golden_reveal); after the
#  normal eggs are found, the meter tracks it.
#
#  "item" picks the look: "egg" (Easter, default), "star" (fallen star
#  fragments, the special one a comet shard) or "apple" (the special one
#  golden); "label" names them on the meter ("Eggs" / "Stars" / "Apples").
#
#  Signals: egg_found(found, total), golden_found(at), hunt_finished.
# =====================================================================

signal egg_found(found: int, total: int)
signal golden_found(at: Vector2)
signal hunt_finished

const MIN_SPACING := 24.0
const SNAP_LIMIT := 12.0        # an egg the navmesh would move further is retried
const SPOT_TRIES := 40
const PASTELS := ["#f2a7c0", "#a7c7f2", "#f7e08a", "#a8e0a0", "#d3b4f0", "#f7c08a"]
const STAR_COLORS := ["#fff4c2", "#cfe3ff", "#ffe08a", "#ffd0e8", "#d8f5ff"]
const APPLE_COLORS := ["#d93a2b", "#e0492f", "#8cc63f", "#c9302c", "#f0b429"]

var data : Dictionary = {}
var center : Vector2 = Vector2.ZERO
var found : int = 0
var total : int = 10
var golden_taken : bool = false

var _world : Node2D
var _player : Node2D
var _eggs : Array = []
var _golden : EasterEgg = null
var _spots : Array = []
var _meter : HuntMeter = null


## avoid: spots already used by the stage and stalls. found_before /
## golden_before: progress from earlier today (only the rest respawns).
func begin(world: Node2D, hunt: Dictionary, at: Vector2, avoid: Array, ui: CanvasLayer,
		found_before: int = 0, golden_before: bool = false) -> void:
	_world = world
	data = hunt
	center = at
	total = int(hunt.get("eggs", 10))
	found = clampi(found_before, 0, total)
	golden_taken = golden_before or not bool(hunt.get("golden", false))
	_player = world.get("player") as Node2D
	_spots = avoid.duplicate()
	y_sort_enabled = true

	var reveal := float(hunt.get("reveal", 50))
	var colors : Array = PASTELS
	match _item():
		"star":
			colors = STAR_COLORS
		"apple":
			colors = APPLE_COLORS
	for i in range(total - found):
		var egg := _spawn_egg(Color(colors[i % colors.size()]), reveal, false)
		egg.collected.connect(_on_egg.bind(egg))
		_eggs.append(egg)
	if not golden_taken:
		_golden = _spawn_egg(Color("#f5c542"), float(hunt.get("golden_reveal", 30)), true)
		_golden.collected.connect(_on_golden.bind(_golden))

	_meter = HuntMeter.new()
	ui.add_child(_meter)
	_meter.set_count(found, total, str(hunt.get("icon", "🥚")), str(hunt.get("label", "Eggs")))


## Put the golden egg back where it was (the riddle was left unsolved).
func respawn_golden(at: Vector2) -> void:
	golden_taken = false
	_golden = _make_egg(Color("#f5c542"), float(data.get("golden_reveal", 30)), true)
	_golden.position = at
	_golden.collected.connect(_on_golden.bind(_golden))


func _item() -> String:
	return str(data.get("item", "egg"))


func is_done() -> bool:
	return found >= total and golden_taken


func _spawn_egg(color: Color, reveal: float, golden: bool) -> EasterEgg:
	var egg := _make_egg(color, reveal, golden)
	egg.global_position = _free_spot()
	return egg


func _make_egg(color: Color, reveal: float, golden: bool) -> EasterEgg:
	var egg := EasterEgg.new()
	egg.glow_color = color
	egg.golden = golden
	egg.item = _item()
	egg.reveal = reveal
	egg.player_body = _player
	if _player:
		egg.z_index = _player.z_index
		egg.z_as_relative = _player.z_as_relative
	add_child(egg)
	return egg


## A walkable spot in the ring around the center, away from the stalls
## and the other eggs.
func _free_spot() -> Vector2:
	var min_r := float(data.get("min_radius", 70))
	var max_r := float(data.get("max_radius", 220))
	var best := center + Vector2(min_r, 0)
	for i in range(SPOT_TRIES):
		var a := randf() * TAU
		var r := lerpf(min_r, max_r, sqrt(randf()))
		var raw := center + Vector2(cos(a), sin(a) * 0.75) * r
		var p := SpawnSpots.on_navmesh(_world, raw)
		best = p
		if p.distance_to(raw) > SNAP_LIMIT:
			continue
		var clear := true
		for s in _spots:
			if p.distance_to(s) < MIN_SPACING:
				clear = false
				break
		if clear:
			break
	_spots.append(best)
	return best


func _on_egg(egg: EasterEgg) -> void:
	_eggs.erase(egg)
	found += 1
	_meter.set_count(found, total, str(data.get("icon", "🥚")), str(data.get("label", "Eggs")))
	ClassTheme.pop(_meter, 1.08)
	egg_found.emit(found, total)
	if found >= total:
		hunt_finished.emit()


func _on_golden(egg: EasterEgg) -> void:
	golden_taken = true
	_golden = null
	golden_found.emit(egg.global_position)


func _process(_delta: float) -> void:
	if _meter == null or _player == null:
		return
	# Warmth from the nearest egg still hidden (the golden one once the
	# others are all found)
	var targets : Array = _eggs.duplicate()
	if targets.is_empty() and _golden and is_instance_valid(_golden):
		targets.append(_golden)
	var nearest := INF
	for e in targets:
		if is_instance_valid(e):
			nearest = minf(nearest, e.global_position.distance_to(_player.global_position))
	var golden_left := _golden != null and is_instance_valid(_golden)
	_meter.set_warmth(nearest, _eggs.is_empty(), golden_left)


func _exit_tree() -> void:
	if _meter and is_instance_valid(_meter):
		_meter.queue_free()


# =====================================================================
#  A painted egg lying in the grass (EventPickup: walk over it to pick it
#  up). It fades in only when the player is within `reveal` pixels.
# =====================================================================
class EasterEgg extends EventPickup:
	var golden : bool = false
	var reveal : float = 50.0
	var item : String = "egg"      # "egg", "star" or "apple"
	var _light : PointLight2D = null

	func _ready() -> void:
		super._ready()
		# Stars shine through the night tint (a hidden star stays dark)
		if item == "star":
			_light = GlowLight.make(Color("#bfe6ff") if golden else glow_color, 22.0 if golden else 16.0, 0.0)
			_light.position = Vector2(0, -4)
			add_child(_light)

	func _process(delta: float) -> void:
		super._process(delta)
		if player_body and is_instance_valid(player_body):
			var d := global_position.distance_to(player_body.global_position)
			modulate.a = clampf(1.0 - (d - reveal * 0.5) / (reveal * 0.5), 0.0, 1.0)
		if _light:
			_light.energy = modulate.a * (1.0 + 0.25 * sin(_time * 5.0))

	func _draw() -> void:
		if item == "star":
			_draw_star()
			return
		if item == "apple":
			_draw_apple()
			return
		draw_set_transform(Vector2(0, 1), 0.0, Vector2(1.0, 0.4))
		draw_circle(Vector2.ZERO, 4.0, Color(0, 0, 0, 0.25))
		draw_set_transform(Vector2(0, -4.5))
		var pts := PackedVector2Array()
		for k in range(20):
			var a := TAU * k / 20.0
			var x := cos(a) * 3.6
			var y := sin(a) * 4.8
			if y < 0.0:
				x *= 1.0 + y / 4.8 * 0.3
			pts.append(Vector2(x, y))
		if golden:
			var halo := Color(1.0, 0.9, 0.4, 0.25 + 0.2 * sin(_time * 4.0))
			draw_circle(Vector2.ZERO, 7.0, halo)
		draw_colored_polygon(pts, glow_color)
		# Painted band and dots
		draw_line(Vector2(-3.4, 0.5), Vector2(3.4, 0.5), Color(1, 1, 1, 0.85), 1.2)
		draw_circle(Vector2(-1.3, -2.2), 0.7, Color(1, 1, 1, 0.85))
		draw_circle(Vector2(1.4, 2.6), 0.7, Color(1, 1, 1, 0.85))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.25, 0.17, 0.1, 0.8), 0.8)
		if golden:
			draw_circle(Vector2(-1.2, -2.8), 0.9, Color(1, 1, 1, 0.5 + 0.5 * sin(_time * 6.0)))
		draw_set_transform(Vector2.ZERO)


	## A ripe apple lying in the grass (a stem and a leaf); the golden
	## apple shimmers.
	func _draw_apple() -> void:
		draw_set_transform(Vector2(0, 1), 0.0, Vector2(1.0, 0.4))
		draw_circle(Vector2.ZERO, 4.0, Color(0, 0, 0, 0.25))
		draw_set_transform(Vector2.ZERO)
		var c := Vector2(0, -4.0)
		var col := Color("#f5c542") if golden else glow_color
		if golden:
			draw_circle(c, 7.0, Color(1.0, 0.9, 0.4, 0.25 + 0.2 * sin(_time * 4.0)))
		draw_circle(c + Vector2(-1.3, 0), 3.4, col)
		draw_circle(c + Vector2(1.3, 0), 3.4, col)
		draw_circle(c + Vector2(0, 1.0), 3.2, col.darkened(0.08))
		draw_circle(c + Vector2(-1.5, -1.2), 0.9, Color(1, 1, 1, 0.55))
		draw_line(c + Vector2(0, -3.0), c + Vector2(0.6, -5.2), Color("#5a3b22"), 1.0)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0.6, -4.6), c + Vector2(3.4, -5.6), c + Vector2(1.6, -3.6)]), Color("#5cb85c"))
		if golden:
			draw_circle(c + Vector2(1.6, -1.6), 0.8, Color(1, 1, 1, 0.5 + 0.5 * sin(_time * 6.0)))

	## A fallen star fragment twinkling in the grass; the special one is a
	## comet shard with a glowing tail.
	func _draw_star() -> void:
		draw_set_transform(Vector2(0, 1), 0.0, Vector2(1.0, 0.4))
		draw_circle(Vector2.ZERO, 3.5, Color(0, 0, 0, 0.25))
		draw_set_transform(Vector2.ZERO)
		var c := Vector2(0, -4.0 + sin(_time * 3.0) * 0.8)
		var tw := 0.6 + 0.4 * sin(_time * 5.0)
		if golden:
			var tail := PackedVector2Array([c + Vector2(-1.5, -1.5), c + Vector2(1.5, 1.5), c + Vector2(-9, 5)])
			draw_colored_polygon(tail, Color(0.6, 0.85, 1.0, 0.45 * tw))
			draw_circle(c, 7.0, Color(0.55, 0.8, 1.0, 0.25 * tw))
		else:
			draw_circle(c, 5.5, Color(glow_color.r, glow_color.g, glow_color.b, 0.22 * tw))
		var r := 3.6 if golden else 3.0
		var col := Color("#bfe6ff") if golden else glow_color
		var pts := PackedVector2Array()
		for k in range(8):
			var a := -PI / 2.0 + k * PI / 4.0 + (_time * 0.8 if golden else 0.0)
			pts.append(c + Vector2.from_angle(a) * (r if k % 2 == 0 else r * 0.38))
		draw_colored_polygon(pts, col)
		draw_circle(c, 0.9, Color(1, 1, 1, 0.9))


# =====================================================================
#  HUD: "🥚 3 / 10" and how warm Matthew is. Sits under the stamp card.
# =====================================================================
class HuntMeter extends PanelContainer:
	const SCREEN_X := 16.0
	const GAP := 8.0
	var _count : Label
	var _word : Label
	var _bar : ProgressBar
	var _fill : StyleBoxFlat

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		position = Vector2(SCREEN_X, 200)
		add_theme_stylebox_override("panel", ClassTheme.flat(Color(0.14, 0.1, 0.06, 0.88), Color("#f2a7c0"), 10, 2, 10))
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 4)
		add_child(col)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		col.add_child(row)
		_count = ClassTheme.label("", 17, ClassTheme.PARCHMENT)
		_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(_count)
		_word = ClassTheme.label("", 15, ClassTheme.GOLD_LIGHT)
		row.add_child(_word)
		_bar = ProgressBar.new()
		_bar.show_percentage = false
		_bar.custom_minimum_size = Vector2(200, 8)
		_bar.add_theme_stylebox_override("background", ClassTheme.flat(Color(0, 0, 0, 0.4), Color.TRANSPARENT, 4))
		_fill = ClassTheme.flat(Color("#6fa8dc"), Color.TRANSPARENT, 4)
		_bar.add_theme_stylebox_override("fill", _fill)
		col.add_child(_bar)

	func set_count(found: int, total: int, icon: String, label: String = "Eggs") -> void:
		_count.text = "%s %s  %d / %d" % [icon, label, found, total]

	## distance: to the nearest hidden egg (INF = none left to look for).
	func set_warmth(distance: float, all_found: bool, golden_left: bool) -> void:
		if distance == INF:
			_word.text = "All found!"
			_bar.value = 100.0
			_fill.bg_color = Color("#7fe08a")
			return
		var warmth := clampf(1.0 - (distance - 30.0) / 150.0, 0.0, 1.0)
		_bar.value = warmth * 100.0
		_fill.bg_color = Color("#6fa8dc").lerp(Color("#f25c3c"), warmth)
		var label := "Cold..."
		if warmth > 0.75:
			label = "Hot!"
		elif warmth > 0.4:
			label = "Warm"
		_word.text = ("✨ " if all_found and golden_left else "") + label
		_word.modulate.a = 0.7 + 0.3 * sin(Time.get_ticks_msec() / 90.0) if warmth > 0.75 else 1.0

	func _process(_delta: float) -> void:
		# Stack under the stamp card (which itself moves under the quest tracker)
		var y := 200.0
		for c in get_parent().get_children() if get_parent() else []:
			if c is StampCard and c.visible:
				y = c.position.y + c.size.y + GAP
		position = Vector2(SCREEN_X, y)
