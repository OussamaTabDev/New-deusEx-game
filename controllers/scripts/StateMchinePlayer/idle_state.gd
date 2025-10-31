class_name IdleState
extends State

func enter() -> void:
	player.SPEED = player.WALK_SPEED

func physics_update(delta: float) -> void:
	# Apply gravity
	if not player.is_on_floor():
		player.velocity.y -= player.gravity * delta
	
	# Apply deceleration
	player.velocity.x = move_toward(player.velocity.x, 0, player.SPEED)
	player.velocity.z = move_toward(player.velocity.z, 0, player.SPEED)
	
	player.move_and_slide()

func check_transitions() -> State:
	# Check for falling
	if not player.is_on_floor():
		return state_machine.get_state("FallingState")
	
	# Check for jump
	if Input.is_action_just_pressed("jump"):
		return state_machine.get_state("JumpingState")
	
	# Check for crouch
	if Input.is_action_pressed("crouch"):
		return state_machine.get_state("CrouchingState")
	
	# Check for movement
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if input_dir.length() > 0.1:
		if Input.is_action_pressed("sprint"):
			return state_machine.get_state("SprintingState")
		else:
			return state_machine.get_state("WalkingState")
	
	return null