class_name WalkingState
extends State

func enter() -> void:
	player.SPEED = player.WALK_SPEED

func physics_update(delta: float) -> void:
	# Smoothly transition speed
	player.SPEED = lerp(player.SPEED, player.WALK_SPEED, 2.5 * delta)
	
	# Apply gravity
	if not player.is_on_floor():
		player.velocity.y -= player.gravity * delta
	
	# Get input and move
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		player.velocity.x = direction.x * player.SPEED
		player.velocity.z = direction.z * player.SPEED
	else:
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
		return state_machine.get_state("CrouchWalkingState")
	
	# Check for sprint
	if Input.is_action_pressed("sprint"):
		return state_machine.get_state("SprintingState")
	
	# Check if stopped moving
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if input_dir.length() < 0.1:
		return state_machine.get_state("IdleState")
	
	return null