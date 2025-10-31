class_name FallingState
extends State

func physics_update(delta: float) -> void:
	# Apply gravity
	player.velocity.y -= player.gravity * delta
	
	# Air control
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		# Reduced air control for more realistic movement
		player.velocity.x = lerp(player.velocity.x, direction.x * player.SPEED, 0.3)
		player.velocity.z = lerp(player.velocity.z, direction.z * player.SPEED, 0.3)
	
	player.move_and_slide()

func check_transitions() -> State:
	# Check if landed
	if player.is_on_floor():
		var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		
		# Check for crouch on landing
		if Input.is_action_pressed("crouch"):
			if input_dir.length() > 0.1:
				return state_machine.get_state("CrouchWalkingState")
			else:
				return state_machine.get_state("CrouchingState")
		
		# Regular landing
		if input_dir.length() > 0.1:
			if Input.is_action_pressed("sprint"):
				return state_machine.get_state("SprintingState")
			else:
				return state_machine.get_state("WalkingState")
		else:
			return state_machine.get_state("IdleState")
	
	return null