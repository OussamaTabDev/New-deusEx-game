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
# State machine reference

func _ready():
	# The state machine will handle initialization
	pass

func _physics_process(delta):
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
	print("marker point y: ", hit_point2.y , " player y: " , global_transform.origin.y )
	return not head_Cast.is_colliding() and not upperchest_Cast.is_colliding()  and hit_point2.y - global_transform.origin.y < 3.0 and hit_point2.y - global_transform.origin.y > 1 and chest_Cast.is_colliding()


func ledge_detect():
	var hit_point1 = h_cast.get_collision_point()
	var hit_point1_up = h_cast_up.get_collision_point()
	var raycast2_holder = r_cast.get_parent()
	var ledge_marker = r_cast.get_child(0)
	hit_point2 = r_cast.get_collision_point()
	var offset = Vector3(0, 3, 0)
	if h_cast.is_colliding():
		raycast2_holder.global_transform.origin = hit_point1 + offset
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