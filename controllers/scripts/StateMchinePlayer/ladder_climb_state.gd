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

# CS:GO-style ladder climbing
@export var climb_speed: float = 3.0
@export var strafe_speed: float = 2.0
@export var look_threshold: float = 0.0  # How much you need to look in a direction to move

func enter() -> void:
	player.unhold_object()
	player.can_wall_run_bool = false
	player.SPEED = player.WALK_SPEED
	player.velocity = Vector3.ZERO
	
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
	
	# Calculate target yaw to face the ladder
	var to_ladder = Vector2(ladder_center.x - player_pos.x, ladder_center.z - player_pos.z)
	if to_ladder.length() > 0.01:
		_target_yaw = atan2(-to_ladder.x, -to_ladder.y)
	else:
		_target_yaw = player.global_transform.basis.get_euler().y
	
	player.is_on_ladder = true
	player.ladder_target_yaw = _target_yaw
	
	# Enable ladder camera mode
	if player.CAMERA_CONTROLLER:
		var ladder_forward = -ladder_direction.cross(Vector3.UP).normalized()
		if ladder_forward.length() < 0.1:
			ladder_forward = Vector3.FORWARD
		#player.CAMERA_CONTROLLER.enter_ladder_mode(ladder_forward)
		#player.CAMERA_CONTROLLER.lock_vertical = true

func exit() -> void:
	player.can_wall_run_bool = true
	player.current_ladder_shape = null
	player.current_ladder_up_direction = Vector3.ZERO
	_is_centering = false
	player.is_on_ladder = false
	
	# Exit ladder camera mode
	#if player.CAMERA_CONTROLLER:
		#player.CAMERA_CONTROLLER.exit_ladder_mode()
		#player.CAMERA_CONTROLLER.lock_vertical = false

func physics_update(delta: float) -> void:
	if not current_ladder_shape or not current_ladder_shape.is_inside_tree():
		state_machine.transition_to(state_machine.get_state("IdleState"))
		return
	player.unhold_object()
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
	
	# CS:GO-style camera-based movement
	var movement = _calculate_csgo_ladder_movement()
	player.velocity = movement
	player.move_and_slide()

func _calculate_csgo_ladder_movement() -> Vector3:
	"""
	Calculate movement based on camera direction like CS:GO
	- Look up + forward = climb up
	- Look down + forward = climb down
	- Look left/right + forward = strafe on ladder
	- Can combine vertical and horizontal movement
	"""
	if not player.CAMERA_CONTROLLER or not player.CAMERA_CONTROLLER.CAMERA_CONTROLLER:
		return Vector3.ZERO
	
	# Get camera forward direction in world space
	var camera = player.CAMERA_CONTROLLER.CAMERA_CONTROLLER
	var camera_forward = -camera.global_transform.basis.z
	var camera_right = camera.global_transform.basis.x
	
	# Get input
	var input_forward = Input.get_axis("move_backward", "move_forward")
	var input_strafe = Input.get_axis("move_left", "move_right")
	
	if input_forward == 0.0 and input_strafe == 0.0:
		return Vector3.ZERO
	
	var final_velocity = Vector3.ZERO
	
	# Vertical movement based on camera pitch and forward input
	if input_forward != 0.0:
		# Extract vertical component from camera direction
		var vertical_component = camera_forward.y
		
		# If looking significantly up or down, apply vertical movement
		if abs(vertical_component) > look_threshold:
			final_velocity.y = vertical_component * input_forward * climb_speed + 1.0
		
		# Horizontal movement on ladder (forward/backward relative to ladder)
		var horizontal_forward = Vector3(camera_forward.x, 0, camera_forward.z).normalized()
		if horizontal_forward.length() > 0.1:
			# Project onto ladder plane
			var ladder_plane_movement = horizontal_forward * input_forward * strafe_speed * 0.5
			final_velocity.x += ladder_plane_movement.x
			final_velocity.z += ladder_plane_movement.z
	
	# Strafe movement (left/right on ladder)
	if input_strafe != 0.0:
		var horizontal_right = Vector3(camera_right.x, 0, camera_right.z).normalized()
		if horizontal_right.length() > 0.1:
			var strafe_movement = horizontal_right * input_strafe * strafe_speed
			final_velocity.x += strafe_movement.x
			final_velocity.z += strafe_movement.z
	
	return final_velocity

func check_transitions() -> State:
	# Check if still on ladder
	
	if current_ladder_shape:
		if not player.on_ladder:
			if player.is_in_water():
				return state_machine.get_state("SwimmingState")
			return state_machine.get_state("FallingState")

	# Jump off ladder
	if Input.is_action_just_pressed("jump"):
		# Jump in camera direction
		if player.is_in_water():
			return state_machine.get_state("SwimmingState")

		if player.CAMERA_CONTROLLER and player.CAMERA_CONTROLLER.CAMERA_CONTROLLER:
			var camera = player.CAMERA_CONTROLLER.CAMERA_CONTROLLER
			var jump_dir = -camera.global_transform.basis.z
			jump_dir.y = 0
			jump_dir = jump_dir.normalized()
			
			# Add horizontal velocity in jump direction
			player.velocity = jump_dir * player.SPEED * 0.5
		
		player.velocity.y = player.JUMP_VELOCITY * 0.7
		return state_machine.get_state("FallingState")
	
	# Dismount at bottom
	if player.is_on_floor() and Input.is_action_pressed("move_backward"):
		if player.is_in_water():
			return state_machine.get_state("SwimmingState")
		return state_machine.get_state("WalkingState")
	
	# Drop down with crouch
	if Input.is_action_just_pressed("crouch"):
		if player.is_in_water():
			return state_machine.get_state("SwimmingState")
		return state_machine.get_state("FallingState")
	
	return null
