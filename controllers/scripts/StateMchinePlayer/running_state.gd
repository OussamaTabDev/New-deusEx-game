class_name SprintingState
extends State

# Set this externally (e.g., from player settings or a config)
@export var is_toggle_sprint: bool = false

# Internal state for toggle mode
var _is_sprinting_toggled: bool = false


func enter() -> void:
	can_shoot = false
	can_reload = false
	weapon_bob_multiplier = 2.0
	weapon_offset = Vector3(0.2, -0.3, -0.1) # Lower
	
	if is_toggle_sprint:
		_is_sprinting_toggled = true


func exit() -> void:
	if is_toggle_sprint:
		_is_sprinting_toggled = false


func physics_update(delta: float) -> void:
	# Smoothly transition speed
	player.SPEED = lerp(player.SPEED, movement_stats_provider.sprint_speed, 3.0 * delta)
	player.unhold_object()
	
	# Apply gravity
	if not player.is_on_floor():
		player.velocity.y -= player.gravity * delta
	
	# Get input and move
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# --- BACKWARD SPEED MODIFIER ---
	var current_speed = player.SPEED
	if input_dir.y > 0: # Moving backward
		current_speed *= 0.5
	# -----------------------------
	
	if direction:
		player.velocity.x = direction.x * current_speed
		player.velocity.z = direction.z * current_speed
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, player.SPEED)
		player.velocity.z = move_toward(player.velocity.z, 0, player.SPEED)
	
	player._push_away_rigid_bodies()
	player.move_and_slide()
	
	if player.is_on_floor():
		player.step_handler.handle_step_climbing()


func check_transitions() -> State:
	# Check for falling
	if not player.is_on_floor():
		return state_machine.get_state("FallingState")
	
	# Check for jump
	if Input.is_action_just_pressed("jump"):
		if player.can_climb():
			return state_machine.get_state("CLimbState")
		return state_machine.get_state("JumpingState")

	if player.is_in_water():
		return state_machine.get_state("SprintSwimmingState")

	# Check for slide (crouch while sprinting)
	if Input.is_action_just_pressed("crouch"):
		return state_machine.get_state("SlidingState")
	
	# Determine if sprint should end
	var should_stop_sprinting: bool = false
	
	if is_toggle_sprint:
		# In toggle mode, only stop sprinting if:
		# - The player pressed sprint again (to toggle off), OR
		# - The player stopped moving
		if Input.is_action_just_pressed("sprint"):
			_is_sprinting_toggled = !_is_sprinting_toggled
		
		if not _is_sprinting_toggled:
			should_stop_sprinting = true
		else:
			# Even in toggle mode, allow stopping via fire (e.g., to draw weapon)
			if Input.is_action_just_pressed("fire"):
				should_stop_sprinting = true
	else:
		# Hold mode: stop if not holding sprint or pressed fire
		if not Input.is_action_pressed("sprint") or Input.is_action_just_pressed("fire"):
			should_stop_sprinting = true

	# Get movement input
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	if should_stop_sprinting:
		if input_dir.length() > 0.1:
			return state_machine.get_state("WalkingState")
		else:
			return state_machine.get_state("IdleState")
	
	# Check if stopped moving (applies to both modes)
	if input_dir.length() < 0.1:
		return state_machine.get_state("IdleState")
	
	return null