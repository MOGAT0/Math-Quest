extends CharacterBody2D
class_name Arith

signal command_trigger(command_name: String, value: bool)
signal player_proximity_changed(is_near: bool) 

var is_following_player: bool = false
var is_player_near: bool = false 

@onready var navigation_agent_2d: NavigationAgent2D = %NavigationAgent2D
@onready var prox_collider: CollisionShape2D = %prox_collider

const SPEED: float = 80.0
var destination: Vector2 = Vector2.ZERO

@export var player_node: Player = null
const FOLLOW_DISTANCE: float = 10.0

@export var lead_min_distance: float = 30.0
@export var lead_max_distance: float = 80.0

func _ready() -> void:
	var is_not_gone = db.query("SELECT id FROM checklist WHERE chapter = (SELECT current_chapter FROM progress WHERE is_active = true)")
	if is_not_gone.status == "success":
		var pos = db.query("SELECT current_location FROM progress WHERE is_active = true")
		if is_not_gone.data[0].id <= 7 and is_not_gone.data[0].id < 3:
			global_position = pos.data[0].current_location
	destination = GameManager.arith_goto
	
	command_trigger.connect(_on_command_trigger)

func follow_player(value: bool) -> void:
	is_following_player = value

func _on_command_trigger(command_name: String, value: bool) -> void:
	if command_name == "follow_player":
		follow_player(value)

func _physics_process(_delta: float) -> void:
	destination = GameManager.arith_goto
	
	if is_following_player:
		prox_collider.disabled = false 
		
		if player_node != null:
			if is_player_near:
				# NEW: Smoothly interpolate velocity to zero over a fraction of a second using delta, creating a braking effect instead of a hard stop.
				velocity = velocity.lerp(Vector2.ZERO, 15.0 * _delta)
			else:
				var distance: float = global_position.distance_to(player_node.global_position)
				var speed_factor: float = clamp((distance - FOLLOW_DISTANCE) / 20.0, 0.0, 1.0)
				velocity = global_position.direction_to(player_node.global_position) * (SPEED * speed_factor)
		else:
			# NEW: Apply the same smooth stop if the player node suddenly becomes null.
			velocity = velocity.lerp(Vector2.ZERO, 15.0 * _delta)
			
		if velocity.length() < 2.0:
			velocity = Vector2.ZERO
			
		move_and_slide()
		return
		
	if destination != Vector2.ZERO:
		prox_collider.disabled = false
		navigation_agent_2d.target_position = destination
		
		if navigation_agent_2d.is_navigation_finished():
			destination = Vector2.ZERO
			GameManager.arith_goto = Vector2.ZERO 
			velocity = Vector2.ZERO
		elif player_node != null:
			var dist_to_player: float = global_position.distance_to(player_node.global_position)
			
			if not is_player_near:
				# NEW: Smoothly interpolate velocity to zero when leading and the player falls behind, matching the braking effect.
				velocity = velocity.lerp(Vector2.ZERO, 15.0 * _delta)
			else:
				var current_position: Vector2 = global_position
				var next_position: Vector2 = navigation_agent_2d.get_next_path_position()
				var speed_factor: float = clamp(1.0 - ((dist_to_player - lead_min_distance) / (lead_max_distance - lead_min_distance)), 0.0, 1.0)
				
				velocity = current_position.direction_to(next_position) * (SPEED * speed_factor)
		else:
			velocity = Vector2.ZERO
	else:
		# Keep hard stops for when Arith doesn't have an active state (not leading, not following)
		velocity = Vector2.ZERO
		prox_collider.disabled = true
		
	if velocity.length() < 2.0:
		velocity = Vector2.ZERO
		
	move_and_slide()

func _on_player_prox_body_entered(body: Node2D) -> void:
	if body is Player:
		is_player_near = true
		player_proximity_changed.emit(true)

func _on_player_prox_body_exited(body: Node2D) -> void:
	if body is Player:
		is_player_near = false
		player_proximity_changed.emit(false)

#extends CharacterBody2D
#class_name Arith
#
#signal command_trigger(command_name: String, value: bool)
#var is_following_player: bool = false
#
#@onready var navigation_agent_2d: NavigationAgent2D = %NavigationAgent2D
#@onready var prox_collider: CollisionShape2D = %prox_collider
#
#const SPEED: float = 75.0
#var destination: Vector2 = Vector2.ZERO
#var player_in_range : bool = false
#
#@export var player_node: Player = null
#const FOLLOW_DISTANCE: float = 10.0
#
#func _ready() -> void:
	#var is_not_gone = db.query("SELECT id FROM checklist WHERE chapter = (SELECT current_chapter FROM progress WHERE is_active = true)")
	#if is_not_gone.status == "success":
		#var pos = db.query("SELECT current_location FROM progress WHERE is_active = true")
		#if is_not_gone.data[0].id <= 7 and is_not_gone.data[0].id < 3:
			#global_position = pos.data[0].current_location
	#destination = GameManager.arith_goto
	#
	#command_trigger.connect(_on_command_trigger)
#
#func follow_player(value: bool) -> void:
	#is_following_player = value
#
#func _on_command_trigger(command_name: String, value: bool) -> void:
	#if command_name == "follow_player":
		#follow_player(value)
#
#func _physics_process(_delta: float) -> void:
	#destination = GameManager.arith_goto
	#
	#if is_following_player:
		#if player_node != null:
			#var distance: float = global_position.distance_to(player_node.global_position)
			#if distance > FOLLOW_DISTANCE:
				#velocity = global_position.direction_to(player_node.global_position) * SPEED
			#else:
				#velocity = Vector2.ZERO
		#else:
			#velocity = Vector2.ZERO
			#
		#move_and_slide()
		#return
		#
	#if destination != Vector2.ZERO:
		#prox_collider.disabled = false
		#navigation_agent_2d.target_position = destination
		#
		#if navigation_agent_2d.is_navigation_finished():
			#destination = Vector2.ZERO
			#GameManager.arith_goto = Vector2.ZERO 
			#velocity = Vector2.ZERO
		#elif player_in_range:
			#var current_position: Vector2 = global_position
			#var next_position: Vector2 = navigation_agent_2d.get_next_path_position()
			#velocity = current_position.direction_to(next_position) * SPEED
		#else:
			#velocity = Vector2.ZERO
	#else:
		#velocity = Vector2.ZERO
		#prox_collider.disabled = true
		#
	#move_and_slide()
#
#func _on_player_prox_body_entered(body: Node2D) -> void:
	#if body is Player:
		#player_in_range = true
#
#func _on_player_prox_body_exited(body: Node2D) -> void:
	#if body is Player:
		#player_in_range = false


#extends CharacterBody2D
#class_name Arith
#
#signal command_trigger(command_name: String, value: bool)
#var is_following_player: bool = false
#
#@onready var navigation_agent_2d: NavigationAgent2D = %NavigationAgent2D
#@onready var prox_collider: CollisionShape2D = %prox_collider
#const SPEED: float = 80.0 
#var go_to: Vector2 = Vector2.ZERO
#var player_in_range : bool = false
#
#func _ready() -> void:
	#go_to = GameManager.arith_goto
	#command_trigger.connect(_on_command_trigger)
#
#func follow_player(value: bool) -> void:
	#is_following_player = value
	#
	#if is_following_player:
		## {to-do} acquire player node reference and initialize pathfinding
		#pass
	#else:
		## {to-do} clear player target and halt movement
		#pass
#
#func _on_command_trigger(command_name: String, value: bool) -> void:
	#if command_name == "follow_player":
		#follow_player(value)
#
#func _physics_process(_delta: float) -> void:
	#go_to = GameManager.arith_goto
	#if is_following_player:
		## {to-do} implement velocity and move_and_slide logic towards the player
		#pass
	#if go_to != Vector2.ZERO:
		#prox_collider.disabled = false
		#navigation_agent_2d.target_position = go_to
		#
		#if navigation_agent_2d.is_navigation_finished():
			#go_to = Vector2.ZERO
			#GameManager.arith_goto = Vector2.ZERO 
			#velocity = Vector2.ZERO
		#elif player_in_range:
			#var current_position: Vector2 = global_position
			#var next_position: Vector2 = navigation_agent_2d.get_next_path_position()
			#velocity = current_position.direction_to(next_position) * SPEED
		#else:
			#velocity = Vector2.ZERO
	#else:
		#velocity = Vector2.ZERO
		#prox_collider.disabled = true
		#
	#move_and_slide()
#
#func _on_player_prox_body_entered(body: Node2D) -> void:
	#if body is Player:
		#player_in_range = true
#
#func _on_player_prox_body_exited(body: Node2D) -> void:
	#if body is Player:
		#player_in_range = false
