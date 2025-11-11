class_name WallRunState
extends State

@export var WALL_RUN_SPEED: float = 10.0
@export var GRAVITY_REDUCTION: float = 0.7
@export var wall_run_duration: float = 3.0

var wall_run_timer: float = 0.0
var collision
func enter() -> void:
	player.can_wall_run_bool = false
	wall_run_timer = wall_run_duration



func physics_update(delta: float) -> void:
	wall_run_timer -= delta

	# Exit if wall run time is up
	if wall_run_timer <= 0.0:
		state_machine.get_state("FallingState")
		return

	# Apply reduced gravity (only if not on floor)
	# if not player.is_on_floor():
	# 	player.velocity.y -= player.gravity * delta * GRAVITY_REDUCTION
		

	# Get the latest wall collision
	collision = player.get_slide_collision(0)
	if not collision :
		return state_machine.get_state("FallingState")
	var wall_normal = collision.get_normal()

	# Ensure we don't run into the wall: movement must be PARALLEL to wall
	# Use upward direction as primary run direction (standard for wall running)
	var desired_direction = Vector3.UP + Vector3.FORWARD

	# Project desired_direction onto the wall plane (remove normal component)
	var wall_run_direction = desired_direction - wall_normal * desired_direction.dot(wall_normal)
	if wall_run_direction.length() < 0.1:
		# If wall is ceiling/floor, can't wall-run — fall
		state_machine.get_state("FallingState")
		return

	wall_run_direction = wall_run_direction.normalized()

	# Set velocity along the wall
	player.velocity = wall_run_direction * WALL_RUN_SPEED
	print()
	# Perform movement
	player.move_and_slide()


func check_transitions() -> State:
	# Exit early if player releases forward or times out
	if wall_run_timer <= 0.0 or collision == null:
		return state_machine.get_state("FallingState")

	# Jump during wall run
	if Input.is_action_just_pressed("jump") and wall_run_timer > 0.0 and wall_run_timer < wall_run_duration - 0.5:
		if player.can_climb():
			return state_machine.get_state("CLimbState")
		else:
			return state_machine.get_state("JumpingState")

	return null
