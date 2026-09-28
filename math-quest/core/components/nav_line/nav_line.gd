extends Line2D
class_name NavLineComponent

@export_group("Settings")
## The NavigationAgent2D that will calculate the path
@export var nav_agent: NavigationAgent2D
## How often the line recalculates (lower = smoother, higher = better performance)
@export var update_interval: float = 0.05
## If true, the line will hide when the player is close to the target
@export var hide_on_arrival: bool = true
## Distance to target where the line disappears
@export var arrival_threshold: float = 50.0

var _timer: float = 0.0

func _ready() -> void:
	top_level = true 
	z_index = 10 
	
	# Important: This ensures the texture repeats across the line
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	
	await get_tree().physics_frame

func _process(delta: float) -> void:
	if not nav_agent: return

	_timer += delta
	if _timer >= update_interval:
		_timer = 0.0
		_update_line_points()

func _update_line_points() -> void:
	if not nav_agent.get_navigation_map(): return

	var dist_to_target = nav_agent.distance_to_target()
	if hide_on_arrival and dist_to_target < arrival_threshold:
		clear_points()
		return

	var full_path: PackedVector2Array = nav_agent.get_current_navigation_path()
	
	if full_path.size() < 2:
		clear_points()
		return

	# Lock first point to the parent's global position
	var parent_node = nav_agent.get_parent()
	if parent_node is Node2D:
		full_path[0] = parent_node.global_position
	
	points = full_path

func set_destination(target_pos: Vector2) -> void:
	if nav_agent:
		nav_agent.target_position = target_pos
