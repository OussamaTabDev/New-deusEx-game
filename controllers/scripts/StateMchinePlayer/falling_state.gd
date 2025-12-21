class_name FallingState
extends State

@export var air_control_factor: float = 0.3
@export var fall_velocity_threashold: float = -5.0

var _jump_buffer := Buffer.new(0.15, 0.15, true)
var current_fall_velocity: float

func physics_update(delta: float) -> void:
	# Apply gravity
	player.velocity.y -= player.gravity * delta
	# if not player.is_on_floor():
	
	_jump_buffer.update(
			Input.is_action_just_pressed("jump"),
			player.can_climb(),
			delta,
	)
	# Check for jump
	if _jump_buffer.should_run_action():
			return state_machine.get_state("CLimbState")
			
	# Air control
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		# Reduced air control for more realistic movement
		player.velocity.x = lerp(player.velocity.x, direction.x * player.SPEED * air_control_factor, 0.3)
		player.velocity.z = lerp(player.velocity.z, direction.z * player.SPEED * air_control_factor, 0.3)
	
	current_fall_velocity = player.velocity.y
	player.move_and_slide()

func check_transitions() -> State:
	# Check if landed
	if player.is_on_floor():
		var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		if check_fall_speed():
			
			player.footstep_player._play_interaction("landing")
			CAMERA_CONTROLLER.add_fall_kick(2.5)
		# Check for crouch on landing
		if Input.is_action_just_pressed("crouch"):
			return state_machine.get_state("CrouchWalkingState")
		
		# Regular landing
		if input_dir.length() > 0.1:
			if Input.is_action_just_pressed("sprint"):
				return state_machine.get_state("SprintingState")
			else:
				return state_machine.get_state("WalkingState")
		else:
			return state_machine.get_state("IdleState")
	
	# Check for dash
	if Input.is_action_just_pressed("dash"):
		return state_machine.get_state("DashState")
		
	# Check for jump
	if Input.is_action_just_pressed("jump"):
		if player.can_climb():
			return state_machine.get_state("CLimbState")
			
	# Inside FallingState.gd
	if player.is_on_wall() and Input.is_action_pressed("move_forward"):
	# Optional: Check if the player is high enough off the ground
		return state_machine.get_state("WallRunningState")
	return null

func can_wall_run() -> bool:
	return Input.is_action_pressed("move_forward") and player.can_wall_run()\
	and state_machine.previous_state.name != "WallRunState"


func check_fall_speed() -> bool:
	print(current_fall_velocity)
	if current_fall_velocity < fall_velocity_threashold:
		current_fall_velocity = 0.0
		return true
	else:
		current_fall_velocity = 0.0
		return false
