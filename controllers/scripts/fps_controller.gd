class_name Player extends CharacterBody3D

# Movement parameters
@export var WALK_SPEED: float = 5.0
@export var SPRINT_SPEED: float = 8.0
@export var JUMP_VELOCITY: float = 4.5
@export var CAMERA_CONTROLLER: Camera3D
@export var state_machine: StateMachine

# Current speed (modified by states)
var SPEED: float = 5.0

# Gravity
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# State machine reference

func _ready():
	# The state machine will handle initialization
	pass

func _physics_process(delta):
	# State machine handles all physics updates
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