class_name LadderClimbState
extends State

# Ladder-specific references
var current_ladder_shape: CollisionShape3D
var ladder_direction: Vector3

var _was_in_floor: bool = true

# Smooth centering
var _is_centering: bool = false
var _center_target: Vector3 = Vector3.ZERO
var _center_speed: float = 8.0

# Smooth rotation
var _target_yaw: float = 0.0
var _yaw_speed: float = 3.0


func enter() -> void:
	player.can_wall_run_bool = false
	player.SPEED = player.WALK_SPEED
	player.velocity.y = 0

	if player.current_ladder_shape == null:
		printerr("ClimbLadderState entered without ladder data!")
		state_machine.transition_to(state_machine.get_state("IdleState"))
		return

	current_ladder_shape = player.current_ladder_shape
	ladder_direction = player.current_ladder_up_direction

	# Initialize centering
	var ladder_center = current_ladder_shape.global_transform.origin
	var player_pos = player.global_transform.origin
	_center_target = Vector3(ladder_center.x, player_pos.y, ladder_center.z)
	_is_centering = true

	# Initialize target yaw
	var to_ladder = Vector2(ladder_center.x - player_pos.x, ladder_center.z - player_pos.z)
	if to_ladder.length() > 0.01:
		_target_yaw = atan2(-to_ladder.x, -to_ladder.y)
	else:
		_target_yaw = player.global_transform.basis.get_euler().y

	player.is_on_ladder = true
	player.ladder_target_yaw = _target_yaw
	
	# 🎯 Calculate ladder forward direction for camera
	# var ladder_forward = Vector3(-sin(_target_yaw), 0.0, -cos(_target_yaw)).normalized()
	# var ladder_forward = Vector3(-sin(_target_yaw), 0.0, -cos(_target_yaw)).normalized()
	# CAMERA_CONTROLLER.enter_ladder_mode(ladder_forward)
	CAMERA_CONTROLLER.lock_vertical = true


func exit() -> void:
	player.can_wall_run_bool = true
	player.current_ladder_shape = null
	player.current_ladder_up_direction = Vector3.ZERO
	_is_centering = false
	player.is_on_ladder = false
	# When player exits ladder
	# CAMERA_CONTROLLER.exit_ladder_mode()
	CAMERA_CONTROLLER.lock_vertical = false
	# CAMERA_CONTROLLER.lock_vertical = false


func physics_update(delta: float) -> void:
	if not current_ladder_shape or not current_ladder_shape.is_inside_tree():
		state_machine.transition_to(state_machine.get_state("IdleState"))
		return

	if not player.is_on_floor():
		_was_in_floor = false

	# Smooth centering (XZ only)
	if _is_centering:
		var current_pos = player.global_transform.origin
		var target_pos = _center_target

		var desired_xz = Vector2(target_pos.x, target_pos.z)
		var current_xz = Vector2(current_pos.x, current_pos.z)

		if desired_xz.distance_to(current_xz) < 0.02:
			_is_centering = false
			player.global_transform.origin = Vector3(target_pos.x, current_pos.y, target_pos.z)
		else:
			var new_xz = current_xz.lerp(desired_xz, _center_speed * delta)
			player.global_transform.origin = Vector3(new_xz.x, current_pos.y, new_xz.y)

		player.velocity.x = 0
		player.velocity.z = 0

	# Update target yaw toward ladder center
	var ladder_center = current_ladder_shape.global_transform.origin
	var player_pos = player.global_transform.origin
	var to_ladder = Vector2(ladder_center.x - player_pos.x, ladder_center.z - player_pos.z)
	if to_ladder.length() > 0.01:
		_target_yaw = atan2(-to_ladder.x, -to_ladder.y)

	# Smooth yaw interpolation
	var current_yaw = player.global_transform.basis.get_euler().y
	var new_yaw = lerp_angle(current_yaw, _target_yaw, _yaw_speed * delta)
	player.ladder_target_yaw = new_yaw

	# Handle climbing input
	var up_input = Input.get_axis("move_backward", "move_forward")
	var climb_speed = 2.0
	player.velocity = Vector3.UP * up_input * climb_speed

	player.move_and_slide()


func check_transitions() -> State:
	if current_ladder_shape:
		var dist_to_ladder = player.global_position.distance_to(current_ladder_shape.global_position)
		if dist_to_ladder > 2.0:
			return state_machine.get_state("IdleState")

	if Input.is_action_just_pressed("jump"):
		player.velocity.y = player.JUMP_VELOCITY * 0.7
		return state_machine.get_state("FallingState")

	if player.is_on_floor() and Input.is_action_pressed("move_backward"):
		return state_machine.get_state("WalkingState")

	if Input.is_action_just_pressed("crouch"):
		return state_machine.get_state("FallingState")

	return null
