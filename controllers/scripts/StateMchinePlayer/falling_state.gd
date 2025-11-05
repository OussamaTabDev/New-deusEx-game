class_name FallingState
extends State

@export var air_control_factor: float = 0.3
func physics_update(delta: float) -> void:
	# Apply gravity
	player.velocity.y -= player.gravity * delta
	
	# Air control
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		# Reduced air control for more realistic movement
		player.velocity.x = lerp(player.velocity.x, direction.x * player.SPEED * air_control_factor, 0.3)
		player.velocity.z = lerp(player.velocity.z, direction.z * player.SPEED * air_control_factor, 0.3)
	
	player.move_and_slide()

func check_transitions() -> State:
	# Check if landed
	if player.is_on_floor():
		var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		
		# Check for crouch on landing
		if Input.is_action_just_pressed("crouch"):
			return state_machine.get_state("CrouchWalkingState")
		
		# Regular landing
		if input_dir.length() > 0.1:
			if Input.is_action_pressed("sprint"):
				return state_machine.get_state("SprintingState")
			else:
				return state_machine.get_state("WalkingState")
		else:
			return state_machine.get_state("IdleState")
	
	# Check for jump
	if Input.is_action_just_pressed("jump"):
		if player.can_climb():
			return state_machine.get_state("CLimbState")
			

	return null