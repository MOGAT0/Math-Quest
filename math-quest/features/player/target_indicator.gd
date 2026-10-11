extends Control
class_name TargetIndicator

# ---------------------------------------------------------------- Exports --

@export_group("Targets")
@export var main_target: CanvasItem
## Values can be Node, NodePath (relative to this node) or Array of those.
@export var side_targets: Dictionary = {}
@export var target_gap: float = 24.0

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

# ---------------------------------------------------------------- Runtime --

var _main_marker: Control = null
var _side_markers: Dictionary = {} # marker id (String) -> Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	_sync_main_marker()
	_sync_side_markers()


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

func _sync_main_marker() -> void:
	if _is_valid_target(main_target):
		if not is_instance_valid(_main_marker):
			_main_marker = _create_marker(main_color, main_icon)
			_main_marker.z_index = 1 # keep the main indicator above side ones
			add_child(_main_marker)
		_update_marker(_main_marker, main_target)
	elif is_instance_valid(_main_marker):
		_main_marker.queue_free()
		_main_marker = null


func _sync_side_markers() -> void:
	# 1) Flatten the dictionary into "marker id -> target node".
	var active: Dictionary = {}
	for key in side_targets:
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
			var marker := _create_marker(side_color, side_icon)
			add_child(marker)
			_side_markers[id] = marker
		_update_marker(_side_markers[id], active[id])


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
	if on_screen and hide_when_on_screen:
		marker.visible = false
		return
	marker.visible = true

	var marker_center: Vector2
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
		# Ray from the screen centre through the target, cut at the inset edge.
		var dir := offset.normalized() if offset.length() > 0.001 else Vector2.UP
		var tx := INF if is_zero_approx(dir.x) else half.x / absf(dir.x)
		var ty := INF if is_zero_approx(dir.y) else half.y / absf(dir.y)
		marker_center = center + dir * minf(tx, ty)

	# Screen -> this control's local space, so it also works if the control
	# is not exactly at the origin of the canvas.
	var local_pos := get_global_transform_with_canvas().affine_inverse() * marker_center
	marker.position = local_pos - marker.size * 0.5

	# Arrow points from the indicator toward the real target position.
	var to_target := target_pos - marker_center
	var angle := to_target.angle() if to_target.length() > 1.0 else Vector2.DOWN.angle()
	var arrow := marker.get_node_or_null("Arrow") as Polygon2D
	if arrow:
		arrow.rotation = angle


## Target position in viewport (screen) coordinates, camera included.
func _get_screen_position(target: CanvasItem) -> Vector2:
	var xform := target.get_global_transform_with_canvas()
	var as_control := target as Control
	if as_control:
		return xform * (as_control.size * 0.5)
	return xform.origin


# ---------------------------------------------------------------- Helpers --

func _is_valid_target(node: Object) -> bool:
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
