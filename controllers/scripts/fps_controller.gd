class_name Player extends CharacterBody3D

# Movement parameters
@export var WALK_SPEED: float = 5.0
@export var SPRINT_SPEED: float = 8.0
@export var JUMP_VELOCITY: float = 4.5
@export var CAMERA_CONTROLLER: CameraController
@export var state_machine: StateMachine
@export var anim_player: AnimationPlayer

@export var head_Cast : ShapeCast3D
@export var chest_Cast: ShapeCast3D
@export var mid_chest_Cast: ShapeCast3D
@export var upperchest_Cast: ShapeCast3D
@export var h_cast : RayCast3D
@export var h_cast_up : RayCast3D
@export var r_cast : RayCast3D

# Current speed (modified by states)
var SPEED: float = 5.0

# Gravity
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# hitmarker points
var hit_point2: Vector3
var current_distance: float
# State machine reference

func _ready():
	# The state machine will handle initialization
	pass

func _physics_process(delta):
	if is_ledge_detect():
		ledge_detect()
	pass

func _process(delta):
	# State machine handles all updates
	pass

# Optional: Add helper functions that states can use
func get_movement_input() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_forward", "move_backward")

func get_move_direction() -> Vector3:
	var input_dir = get_movement_input()
	return (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

func is_moving() -> bool:
	return get_movement_input().length() > 0.1

func is_sprinting() -> bool:
	return Input.is_action_pressed("sprint")

func is_crouching() -> bool:
	return Input.is_action_pressed("crouch")

func wants_to_jump() -> bool:
	return Input.is_action_just_pressed("jump")

func is_leaning() -> bool:
	return Input.is_action_pressed("lean_left") or Input.is_action_pressed("lean_right")

func can_climb():
	var hit_point = h_cast_up.get_collision_point()
	var player_pos = global_transform.origin
	var distance = player_pos.distance_to(hit_point)
	if distance < 2.4:
		current_distance = distance
	print("Hit point:", hit_point, " Player pos:", player_pos, " Distance:", distance)
	return not head_Cast.is_colliding() and not upperchest_Cast.is_colliding() \
	  and hit_point2.y - global_transform.origin.y < 3.0 and hit_point2.y - global_transform.origin.y > 1 \
	  and (chest_Cast.is_colliding() or mid_chest_Cast.is_colliding() or (h_cast_up.is_colliding() and distance < 2.4) )


func ledge_detect():
	var player_pos = global_transform.origin
	var hit_point1 = chest_Cast.get_collision_point(0) # this ShapeCast3D is child of player others is RayCast3D
	var hit_point3 = mid_chest_Cast.get_collision_point(0) # this ShapeCast3D is child of player others is RayCast3D
	var hit_point1_up = h_cast_up.get_collision_point()
	var raycast2_holder = r_cast.get_parent()
	var ledge_marker = r_cast.get_child(0)
	hit_point2 = r_cast.get_collision_point()
	var offset = Vector3(0, 1.5, 0)
	

	if chest_Cast.is_colliding():
		raycast2_holder.global_transform.origin = hit_point1 + offset
		ledge_marker.global_transform.origin = hit_point2

		ledge_marker.visible = true
		r_cast.enabled = true
	elif mid_chest_Cast.is_colliding():
		raycast2_holder.global_transform.origin = hit_point3 + offset
		ledge_marker.global_transform.origin = hit_point2
		ledge_marker.visible = true
		r_cast.enabled = true

	elif h_cast_up.is_colliding():
		raycast2_holder.global_transform.origin = hit_point1_up + offset
		ledge_marker.global_transform.origin = hit_point2

		ledge_marker.visible = true
		r_cast.enabled = true

	else:
		ledge_marker.visible = false
		r_cast.enabled = false

func is_ledge_detect() -> bool:
	return chest_Cast.is_colliding() or mid_chest_Cast.is_colliding() or h_cast_up.is_colliding()
