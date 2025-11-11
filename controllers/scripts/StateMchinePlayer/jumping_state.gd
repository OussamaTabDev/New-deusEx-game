class_name JumpingState
extends State

var jump_pressed := true  # Tracks if jump key is still held
var _jump_buffer := Buffer.new(0.15, 0.15, true)

var was_in_air_time: float = 0.0
func enter() -> void:
	was_in_air_time = 0.0
	player.velocity.y = player.JUMP_VELOCITY
	jump_pressed = true

func physics_update(delta: float) -> void:
	was_in_air_time += delta
	# Check if jump input was released
	if jump_pressed and not Input.is_action_pressed("jump"):
		jump_pressed = false
		# Early jump release → reduce jump height
		if player.velocity.y > 0:  # Only cut if still going up
			player.velocity.y *= 0.5  # Or set to a max "short hop" cap

	_jump_buffer.update(
			Input.is_action_just_pressed("jump"),
			player.can_climb(),
			delta,
	)

	# Check for jump
	if _jump_buffer.should_run_action():
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

	if can_wall_run():
			return state_machine.get_state("WallRunState")

	# Check for dash
	if Input.is_action_just_pressed("dash"):
		return state_machine.get_state("DashState")
		
	return null

func can_wall_run() -> bool:
	return Input.is_action_pressed("move_forward") and player.can_wall_run()\
	 and state_machine.previous_state.name != "WallRunState" and state_machine.previous_state.name == "SprintingState"\
	 and was_in_air_time > 0.1