extends RefCounted
class_name SpawnSpots

# =====================================================================
#  Where things can spawn in the world: random walkable points inside an
#  Area2D (its CollisionPolygon2D / CollisionShape2D children), snapped
#  onto the navigation mesh. Shared by EventDirector (random visitors)
#  and FestivalDirector (festival booths).
# =====================================================================

const TRIES := 25


## A random walkable point inside `area`, or Vector2.INF when the area has
## no usable shape. Snapping to walkable ground can push a point out of
## the polygon, so points that end up outside are retried.
static func random_point(world: Node2D, area: Area2D) -> Vector2:
	var last := Vector2.INF
	for i in range(TRIES):
		var raw := point_in_area(area)
		if raw == Vector2.INF:
			break
		last = on_navmesh(world, raw)
		if inside_area(area, last):
			return last
	return last


## Random point inside one of the area's collision shapes / polygons.
static func point_in_area(area: Area2D) -> Vector2:
	var shapes : Array = []
	for c in area.find_children("*", "CollisionShape2D", true, false):
		if c.shape and not c.disabled:
			shapes.append(c)
	for c in area.find_children("*", "CollisionPolygon2D", true, false):
		if c.polygon.size() >= 3 and not c.disabled:
			shapes.append(c)
	if shapes.is_empty():
		return Vector2.INF
	var node = shapes.pick_random()
	if node is CollisionPolygon2D:
		var poly : PackedVector2Array = node.polygon
		var box := Rect2(poly[0], Vector2.ZERO)
		for v in poly:
			box = box.expand(v)
		for i in range(30):
			var inside := Vector2(randf_range(box.position.x, box.end.x), randf_range(box.position.y, box.end.y))
			if Geometry2D.is_point_in_polygon(inside, poly):
				return node.global_transform * inside
		return node.global_transform * poly[0]
	var shape : Shape2D = node.shape
	var local := Vector2.ZERO
	if shape is RectangleShape2D:
		var half : Vector2 = shape.size / 2.0
		local = Vector2(randf_range(-half.x, half.x), randf_range(-half.y, half.y))
	elif shape is CircleShape2D:
		local = Vector2.from_angle(randf() * TAU) * shape.radius * sqrt(randf())
	elif shape is CapsuleShape2D:
		local = Vector2(randf_range(-shape.radius, shape.radius), randf_range(-shape.height / 2.0, shape.height / 2.0))
	else:
		var r := shape.get_rect()
		local = Vector2(randf_range(r.position.x, r.end.x), randf_range(r.position.y, r.end.y))
	return node.global_transform * local


static func inside_area(area: Area2D, p: Vector2) -> bool:
	for c in area.find_children("*", "CollisionPolygon2D", true, false):
		if c.polygon.size() >= 3 and Geometry2D.is_point_in_polygon(c.global_transform.affine_inverse() * p, c.polygon):
			return true
	for c in area.find_children("*", "CollisionShape2D", true, false):
		if c.shape and c.shape.get_rect().has_point(c.global_transform.affine_inverse() * p):
			return true
	return false


## Closest walkable point (unchanged when the navigation map isn't ready).
static func on_navmesh(world: Node2D, p: Vector2) -> Vector2:
	var map := world.get_world_2d().navigation_map
	if map.is_valid() and NavigationServer2D.map_get_iteration_id(map) > 0:
		return NavigationServer2D.map_get_closest_point(map, p)
	return p


## The world's Area2D with this unique name (e.g. "npc_spawn_area").
static func find_area(world: Node2D, unique_name: String) -> Area2D:
	var area = world.get(unique_name)
	if not (area is Area2D):
		area = world.get_node_or_null("%" + unique_name)
	return area if area is Area2D and is_instance_valid(area) else null
