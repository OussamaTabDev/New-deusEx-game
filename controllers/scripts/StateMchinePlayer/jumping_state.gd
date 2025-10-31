class_name JumpingState
extends State

func enter() -> void:
	player.velocity.y = player.JUMP_VELOCITY

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
	# Check if started falling (velocity.y <= 0)
	if player.velocity.y <= 0:
		return state_machine.get_state("FallingState")
	
	return null