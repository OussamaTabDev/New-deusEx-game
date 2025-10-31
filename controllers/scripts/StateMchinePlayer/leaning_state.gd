class_name LeaningState
extends State

# Leaning system for immersive sims (like Deus Ex, Thief, etc.)
@export var lean_distance: float = 0.5
@export var lean_speed: float = 8.0

enum LeanDirection { NONE, LEFT, RIGHT }

var current_lean: LeanDirection = LeanDirection.NONE
var lean_offset: float = 0.0
var previous_state: State

func enter() -> void:
	# Store the state we came from
	pass

func exit() -> void:
	# Reset lean
	lean_offset = 0.0
	current_lean = LeanDirection.NONE

func update(delta: float) -> void:
	# Determine lean direction
	var target_lean = 0.0
	
	if Input.is_action_pressed("lean_left"):
		current_lean = LeanDirection.LEFT
		target_lean = -lean_distance
	elif Input.is_action_pressed("lean_right"):
		current_lean = LeanDirection.RIGHT
		target_lean = lean_distance
	else:
		current_lean = LeanDirection.NONE
		target_lean = 0.0
	
	# Smoothly interpolate lean
	lean_offset = lerp(lean_offset, target_lean, lean_speed * delta)
	
	# Apply lean to camera (lateral movement)
	if player.CAMERA_CONTROLLER:
		var lean_vector = player.transform.basis.x * lean_offset
		player.CAMERA_CONTROLLER.position.x = lean_vector.x
		player.CAMERA_CONTROLLER.position.z = lean_vector.z
		
		# Optional: Add slight camera tilt for more immersion
		player.CAMERA_CONTROLLER.rotation.z = -lean_offset * 0.1

func physics_update(delta: float) -> void:
	# Leaning doesn't change movement, just camera position
	# Delegate to previous state's movement logic
	
	# Apply gravity
	if not player.is_on_floor():
		player.velocity.y -= player.gravity * delta
	
	# Basic movement (can be customized based on previous state)
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		# Slower movement while leaning
		var lean_speed_multiplier = 0.7
		player.velocity.x = direction.x * player.SPEED * lean_speed_multiplier
		player.velocity.z = direction.z * player.SPEED * lean_speed_multiplier
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, player.SPEED)
		player.velocity.z = move_toward(player.velocity.z, 0, player.SPEED)
	
	player.move_and_slide()

func check_transitions() -> State:
	# Exit leaning if no lean keys pressed
	if not Input.is_action_pressed("lean_left") and not Input.is_action_pressed("lean_right"):
		# Return to appropriate state
		if not player.is_on_floor():
			return state_machine.get_state("FallingState")
		
		var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		
		if Input.is_action_pressed("crouch"):
			if input_dir.length() > 0.1:
				return state_machine.get_state("CrouchWalkingState")
			else:
				return state_machine.get_state("CrouchingState")
		
		if input_dir.length() > 0.1:
			if Input.is_action_pressed("sprint"):
				return state_machine.get_state("SprintingState")
			else:
				return state_machine.get_state("WalkingState")
		else:
			return state_machine.get_state("IdleState")
	
	# Check for jump (cancel lean)
	if Input.is_action_just_pressed("jump") and player.is_on_floor():
		return state_machine.get_state("JumpingState")
	
	# Check for falling
	if not player.is_on_floor():
		return state_machine.get_state("FallingState")
	
	return null