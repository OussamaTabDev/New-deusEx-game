class_name JumpingState
extends State

var jump_pressed := true  # Tracks if jump key is still held

func enter() -> void:
	player.velocity.y = player.JUMP_VELOCITY
	jump_pressed = true

func physics_update(delta: float) -> void:
	# Check if jump input was released
	if jump_pressed and not Input.is_action_pressed("jump"):
		jump_pressed = false
		# Early jump release → reduce jump height
		if player.velocity.y > 0:  # Only cut if still going up
			player.velocity.y *= 0.5  # Or set to a max "short hop" cap

	# Check for jump
	if Input.is_action_just_pressed("jump"):
		if player.can_climb():
			return state_machine.get_state("CLimbState")
			

	# Apply gravity
	player.velocity.y -= player.gravity * delta
	
	# Air control
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		player.velocity.x = lerp(player.velocity.x, direction.x * player.SPEED, 0.3)
		player.velocity.z = lerp(player.velocity.z, direction.z * player.SPEED, 0.3)
	
	player.move_and_slide()

func check_transitions() -> State:
	if player.velocity.y <= 0:
		return state_machine.get_state("FallingState")
	return null