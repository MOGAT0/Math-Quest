extends Control
class_name TargetIndicator

# ---------------------------------------------------------------- Exports --

@export_group("Targets")
@export var main_target: CanvasItem
## Values can be Node, NodePath (relative to this node) or Array of those.
@export var side_targets: Dictionary = {}
@export var target_gap: float = 24.0
## Main targets inside / at the academy (node names); hidden on days
## the school is closed (major events).
@export var school_target_names: PackedStringArray = [
	"academy_gate", "class_room_entrance", "inner_academy", "principal_office"]

@export_group("Icons")
@export var main_icon: Texture2D
@export var side_icon: Texture2D

@export_group("Style")
@export var main_color: Color = Color.GOLD
@export var side_color: Color = Color.DODGER_BLUE
@export var background_color: Color = Color(0.05, 0.05, 0.08, 0.75)
@export var indicator_size: float = 56.0
@export var border_width: float = 4.0
@export var icon_padding: float = 10.0

@export_group("Arrow")
@export var arrow_length: float = 14.0
@export var arrow_width: float = 18.0
@export var arrow_gap: float = 4.0

@export_group("Behaviour")
## Extra space kept between the indicator (arrow included) and the screen edge.
@export var edge_margin: float = 12.0
## If true, an indicator hides while its target is comfortably on screen.
@export var hide_when_on_screen: bool = false

@export_group("Pathfinding")
## Off-screen indicators follow the walkable path (navigation mesh) from
## this node to the target instead of pointing straight at it. Leave empty
## to use the nearest Node2D above this indicator (the player).
@export var path_origin: Node2D
@export var use_pathfinding: bool = true
## Navigation layers the path may use (match the player's NavigationAgent2D).
@export_flags_2d_navigation var navigation_layers: int = 1
## Seconds between path recalculations.
@export var path_refresh: float = 0.2

@export_group("Spacing & focus")
## Indicators never overlap: they keep at least this many meters apart
## (1 meter = meter_px world pixels, scaled by the camera zoom).
@export var min_spacing_meters: float = 2.0
@export var meter_px: float = 16.0
## Side-quest keys containing this text are items to pick up and use
## item_color instead of side_color.
@export var item_key_tag: String = "_item_"
@export var item_color: Color = Color("#1fb5a8")

@export_group("Smoothing")
## How quickly indicators glide to a new place / turn to a new direction.
## Higher = snappier, 0 = no smoothing.
@export var move_smoothing: float = 10.0
@export var turn_smoothing: float = 12.0
## When an indicator gets within this many meters of its spot next to an
## on-screen target (1 meter = meter_px world pixels, camera zoom
## included) it snaps onto it and stays locked: it follows the target
## exactly, with no smoothing, so it doesn't sway while the player
## (camera) moves. It lets go when the target leaves the screen.
@export var lock_distance_meters: float = 1.0

# ---------------------------------------------------------------- Runtime --

var _main_marker: Control = null
var _side_markers: Dictionary = {} # marker id (String) -> Control
var _path_cache: Dictionary = {}   # target instance id -> {"time": float, "path": PackedVector2Array}
var _clock: float = 0.0
var _delta: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_clock += delta
	_delta = delta
	_sync_main_marker()
	_sync_side_markers()
	_apply_smoothing()


# ------------------------------------------------------------- Public API --

func set_main_target(target: CanvasItem) -> void:
	main_target = target


func clear_main_target() -> void:
	main_target = null


## Adds a side-quest target. Calling this again with the same key adds
## another target to that key instead of replacing the old one.
func add_side_target(key: Variant, target: Variant) -> void:
	if not side_targets.has(key):
		side_targets[key] = [target]
		return
	var existing: Variant = side_targets[key]
	if existing is Array:
		if not existing.has(target):
			existing.append(target)
	elif existing != target:
		side_targets[key] = [existing, target]


## Removes one target from a key, or the whole key when target is null.
func remove_side_target(key: Variant, target: Variant = null) -> void:
	if not side_targets.has(key):
		return
	if target == null:
		side_targets.erase(key)
		return
	var existing: Variant = side_targets[key]
	if existing is Array:
		existing.erase(target)
		if existing.is_empty():
			side_targets.erase(key)
	elif existing == target:
		side_targets.erase(key)


func clear_side_targets() -> void:
	side_targets.clear()


# ------------------------------------------------------- Marker lifecycle --

## On major events that close the academy the main arrow
## pointing to it is hidden until the next school day.
func _is_closed_school_target(target: CanvasItem) -> bool:
	return school_target_names.has(String(target.name)) and not CalendarManager.is_school_day()


func _sync_main_marker() -> void:
	if _is_valid_target(main_target) and not _is_closed_school_target(main_target):
		if not is_instance_valid(_main_marker):
			_main_marker = _create_marker(main_color, main_icon)
			_main_marker.z_index = 1 # keep the main indicator above side ones
			add_child(_main_marker)
		_update_marker(_main_marker, main_target)
	elif is_instance_valid(_main_marker):
		_main_marker.queue_free()
		_main_marker = null


func _sync_side_markers() -> void:
	# 1) Flatten the dictionary into "marker id -> target node". While a
	#    side quest is in progress (GameManager.side_quest_focus) only its
	#    own indicators show; the main quest indicator is not affected.
	var active: Dictionary = {}
	var focus := str(GameManager.side_quest_focus)
	for key in side_targets:
		var k := str(key)
		if focus != "" and k != focus and not k.begins_with(focus + "_"):
			continue
		var index := 0
		for target in _resolve_targets(side_targets[key]):
			active["%s#%d" % [key, index]] = target
			index += 1

	# 2) Remove markers whose target no longer exists.
	for id in _side_markers.keys():
		if not active.has(id):
			var stale: Control = _side_markers[id]
			if is_instance_valid(stale):
				stale.queue_free()
			_side_markers.erase(id)

	# 3) Create missing markers and update all of them.
	for id in active:
		if not _side_markers.has(id):
			var color := item_color if item_key_tag != "" and str(id).contains(item_key_tag) else side_color
			var marker := _create_marker(color, side_icon)
			add_child(marker)
			_side_markers[id] = marker
		_update_marker(_side_markers[id], active[id])

	# 4) Push indicators apart so none overlap.
	_separate_markers()


## Keeps visible indicators at least min_spacing_meters apart. The main
## quest indicator stays put; side indicators move out of its way (and
## out of each other's), staying inside the screen edge margin.
func _separate_markers() -> void:
	var markers: Array = []
	if is_instance_valid(_main_marker) and _main_marker.visible:
		markers.append(_main_marker)
	var main_fixed := not markers.is_empty()
	for m in _side_markers.values():
		if is_instance_valid(m) and m.visible:
			markers.append(m)
	if markers.size() < 2:
		return
	var spacing := _spacing_px()
	var extent := indicator_size * 0.5 + arrow_gap + arrow_length + edge_margin
	var lo := Vector2.ONE * extent
	var hi := (size - Vector2.ONE * extent).max(lo)
	var centers: Array = []
	for m in markers:
		centers.append(_goal_pos(m) + m.size * 0.5)
	for iteration in range(8):
		var moved := false
		for i in range(centers.size()):
			for j in range(i + 1, centers.size()):
				var d: Vector2 = centers[j] - centers[i]
				var dist := d.length()
				if dist >= spacing:
					continue
				moved = true
				var dir := d / dist if dist > 0.01 else Vector2.from_angle(float(j) * 2.4)
				var push := spacing - dist
				if i == 0 and main_fixed:
					centers[j] = (centers[j] + dir * push).clamp(lo, hi)
				else:
					centers[i] = (centers[i] - dir * push * 0.5).clamp(lo, hi)
					centers[j] = (centers[j] + dir * push * 0.5).clamp(lo, hi)
		if not moved:
			break
	for k in range(markers.size()):
		markers[k].set_meta("goal_pos", centers[k] - markers[k].size * 0.5)


## Glide every indicator toward its goal position / arrow angle. New (or
## re-shown) indicators start at their goal so they don't fly in.
func _apply_smoothing() -> void:
	var move_t := 1.0 if move_smoothing <= 0.0 else 1.0 - exp(-move_smoothing * _delta)
	var turn_t := 1.0 if turn_smoothing <= 0.0 else 1.0 - exp(-turn_smoothing * _delta)
	var markers: Array = _side_markers.values()
	if is_instance_valid(_main_marker):
		markers.append(_main_marker)
	for m in markers:
		if not is_instance_valid(m) or not m.has_meta("goal_pos"):
			continue
		var arrow := m.get_node_or_null("Arrow") as Polygon2D
		var goal: Vector2 = m.get_meta("goal_pos")
		var goal_rot: float = m.get_meta("goal_rot", arrow.rotation if arrow else 0.0)
		var fresh: bool = not bool(m.get_meta("placed", false)) or not m.visible
		if fresh:
			m.position = goal
			if arrow:
				arrow.rotation = goal_rot
			m.set_meta("placed", m.visible)
			continue
		# Locked onto an on-screen target: stick to it, no lag or sway
		if bool(m.get_meta("on_screen", false)):
			if bool(m.get_meta("locked", false)) or m.position.distance_to(goal) <= _lock_px():
				m.set_meta("locked", true)
				m.position = goal
				if arrow:
					arrow.rotation = goal_rot
				continue
		else:
			m.set_meta("locked", false)
		m.position = m.position.lerp(goal, move_t)
		if arrow:
			arrow.rotation = lerp_angle(arrow.rotation, goal_rot, turn_t)


func _goal_pos(m: Control) -> Vector2:
	return m.get_meta("goal_pos", m.position)


## min_spacing_meters in screen pixels (camera zoom included), never less
## than one indicator plus a small gap.
## lock_distance_meters in screen pixels (camera zoom included).
func _lock_px() -> float:
	var zoom := absf(get_viewport().get_canvas_transform().get_scale().x) if get_viewport() else 1.0
	return lock_distance_meters * meter_px * maxf(zoom, 0.01)


func _spacing_px() -> float:
	var zoom := 1.0
	var origin := _get_path_origin()
	if origin:
		zoom = absf(origin.get_canvas_transform().get_scale().x)
	return maxf(min_spacing_meters * meter_px * zoom, indicator_size + 8.0)


# --------------------------------------------------------- Marker builder --

## Builds one indicator entirely from code:
## Control (root)
##  |- Panel      (circle with coloured border)
##  |- TextureRect (icon)
##  '- Polygon2D  (arrow, rotated to point at the target)
func _create_marker(border_color: Color, icon: Texture2D) -> Control:
	var marker := Control.new()
	marker.name = "Marker"
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.size = Vector2.ONE * indicator_size

	# Circle
	var circle := Panel.new()
	circle.name = "Circle"
	circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	circle.position = Vector2.ZERO
	circle.size = marker.size
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(int(border_width))
	style.set_corner_radius_all(int(indicator_size * 0.5))
	style.anti_aliasing = true
	circle.add_theme_stylebox_override("panel", style)
	marker.add_child(circle)

	# Icon in the middle
	var icon_rect := TextureRect.new()
	icon_rect.name = "Icon"
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.texture = icon
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.position = Vector2.ONE * icon_padding
	icon_rect.size = marker.size - Vector2.ONE * icon_padding * 2.0
	marker.add_child(icon_rect)

	# Arrow (points along +X locally, then gets rotated)
	var arrow := Polygon2D.new()
	arrow.name = "Arrow"
	arrow.color = border_color
	arrow.antialiased = true
	arrow.position = marker.size * 0.5
	var r := indicator_size * 0.5 + arrow_gap
	arrow.polygon = PackedVector2Array([
		Vector2(r + arrow_length, 0.0),
		Vector2(r, -arrow_width * 0.5),
		Vector2(r, arrow_width * 0.5),
	])
	marker.add_child(arrow)

	return marker


# ------------------------------------------------------- Marker placement --

func _update_marker(marker: Control, target: CanvasItem) -> void:
	var view_rect := get_viewport_rect()
	var center := view_rect.get_center()

	# Space the whole indicator (circle + arrow + margin) needs at the edge.
	var indicator_extent := indicator_size * 0.5 + arrow_gap + arrow_length
	var margin := indicator_extent + edge_margin
	var half := (view_rect.size * 0.5 - Vector2.ONE * margin).max(Vector2.ONE)

	var target_pos := _get_screen_position(target)
	var offset := target_pos - center

	var on_screen := absf(offset.x) <= half.x and absf(offset.y) <= half.y
	marker.set_meta("on_screen", on_screen)
	if on_screen and hide_when_on_screen:
		marker.visible = false
		return
	marker.visible = true

	var marker_center: Vector2
	var path_heading := Vector2.ZERO   # set when the arrow should follow the path
	if on_screen:
		# Hover next to the target, arrow tip stopping `target_gap` short of it.
		var hover_dist := indicator_extent + target_gap
		var dir_away := Vector2.UP
		# Not enough room above? Go below instead.
		if target_pos.y - hover_dist < center.y - half.y:
			dir_away = Vector2.DOWN
		marker_center = target_pos + dir_away * hover_dist
		# Safety clamp so the indicator never leaves the screen.
		marker_center = marker_center.clamp(center - half, center + half)
	else:
		# Follow the walkable path: sit where it leaves the screen and point
		# along it. Without a path, fall back to the straight line.
		var exit := _path_exit(target, Rect2(center - half, half * 2.0))
		if not exit.is_empty():
			marker_center = exit["point"]
			path_heading = exit["dir"]
		else:
			# Ray from the screen centre through the target, cut at the inset edge.
			var dir := offset.normalized() if offset.length() > 0.001 else Vector2.UP
			var tx := INF if is_zero_approx(dir.x) else half.x / absf(dir.x)
			var ty := INF if is_zero_approx(dir.y) else half.y / absf(dir.y)
			marker_center = center + dir * minf(tx, ty)

	# Screen -> this control's local space, so it also works if the control
	# is not exactly at the origin of the canvas.
	var local_pos := get_global_transform_with_canvas().affine_inverse() * marker_center
	marker.set_meta("goal_pos", local_pos - marker.size * 0.5)

	# Arrow follows the path heading, or points straight at the target.
	var to_target := path_heading if path_heading != Vector2.ZERO else target_pos - marker_center
	var angle := to_target.angle() if to_target.length() > 0.001 else Vector2.DOWN.angle()
	var arrow := marker.get_node_or_null("Arrow") as Polygon2D
	if arrow:
		marker.set_meta("goal_rot", angle)


# ------------------------------------------------------------ Pathfinding --

## Where the walkable path to `target` leaves `rect` (screen space), as
## {"point", "dir"}, or {} when there is no usable path.
func _path_exit(target: CanvasItem, rect: Rect2) -> Dictionary:
	var origin := _get_path_origin()
	if not use_pathfinding or origin == null:
		return {}
	var path := _world_path(origin, target)
	if path.size() < 2:
		return {}
	var to_screen := origin.get_canvas_transform()
	var a: Vector2 = to_screen * path[0]
	for i in range(1, path.size()):
		var b: Vector2 = to_screen * path[i]
		if not rect.has_point(b):
			var seg := b - a
			if seg.length() < 0.001:
				return {}
			var start := a.clamp(rect.position, rect.end)
			return {"point": _leave_point(start, b, rect), "dir": seg.normalized()}
		a = b
	return {}


## Point where the segment start -> end crosses out of rect.
func _leave_point(start: Vector2, end: Vector2, rect: Rect2) -> Vector2:
	var d := end - start
	var t := 1.0
	if d.x > 0.0:
		t = minf(t, (rect.end.x - start.x) / d.x)
	elif d.x < 0.0:
		t = minf(t, (rect.position.x - start.x) / d.x)
	if d.y > 0.0:
		t = minf(t, (rect.end.y - start.y) / d.y)
	elif d.y < 0.0:
		t = minf(t, (rect.position.y - start.y) / d.y)
	return (start + d * clampf(t, 0.0, 1.0)).clamp(rect.position, rect.end)


## Path in world space from the origin to the target, refreshed every
## `path_refresh` seconds. Ends exactly on the target even if the target
## sits just off the navigation mesh (e.g. in a doorway).
func _world_path(origin: Node2D, target: CanvasItem) -> PackedVector2Array:
	var key := target.get_instance_id()
	var cached: Dictionary = _path_cache.get(key, {})
	if not cached.is_empty() and _clock - float(cached["time"]) < path_refresh:
		return cached["path"]
	var path := PackedVector2Array()
	var map := origin.get_world_2d().navigation_map
	if map.is_valid() and NavigationServer2D.map_get_iteration_id(map) > 0:
		var goal := _get_world_position(target)
		path = NavigationServer2D.map_get_path(map, origin.global_position, goal, true, navigation_layers)
		if path.size() >= 1:
			path[0] = origin.global_position
			if path[path.size() - 1].distance_to(goal) > 1.0:
				path.append(goal)
	_path_cache[key] = {"time": _clock, "path": path}
	return path


func _get_path_origin() -> Node2D:
	if is_instance_valid(path_origin):
		return path_origin
	var node := get_parent()
	while node:
		if node is Node2D:
			return node as Node2D
		node = node.get_parent()
	return null


func _get_world_position(target: CanvasItem) -> Vector2:
	if target is Node2D:
		return (target as Node2D).global_position
	var as_control := target as Control
	if as_control:
		return as_control.get_global_rect().get_center()
	return Vector2.ZERO


## Target position in viewport (screen) coordinates, camera included.
func _get_screen_position(target: CanvasItem) -> Vector2:
	var xform := target.get_global_transform_with_canvas()
	var as_control := target as Control
	if as_control:
		return xform * (as_control.size * 0.5)
	return xform.origin


# ---------------------------------------------------------------- Helpers --

## Untyped on purpose: a target can be a node that was already freed (e.g.
## a marker of a world that was unloaded); a typed Object argument would
## error before is_instance_valid() could say "no".
func _is_valid_target(node) -> bool:
	return is_instance_valid(node) and node is CanvasItem and (node as CanvasItem).is_inside_tree()


func _resolve_targets(value: Variant) -> Array[CanvasItem]:
	var result: Array[CanvasItem] = []
	if value is Array:
		for entry in value:
			var node := _resolve_node(entry)
			if node:
				result.append(node)
	else:
		var node := _resolve_node(value)
		if node:
			result.append(node)
	return result


func _resolve_node(value: Variant) -> CanvasItem:
	var node: Node = null
	match typeof(value):
		TYPE_OBJECT:
			if is_instance_valid(value):
				node = value as Node
		TYPE_NODE_PATH, TYPE_STRING, TYPE_STRING_NAME:
			if not str(value).is_empty():
				node = get_node_or_null(NodePath(str(value)))
	if node and node is CanvasItem and node.is_inside_tree():
		return node as CanvasItem
	return null
