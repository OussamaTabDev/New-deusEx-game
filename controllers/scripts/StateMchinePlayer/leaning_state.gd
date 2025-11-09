class_name DashState
extends State

# Leaning system for immersive sims (like Deus Ex, Thief, etc.)
@export var dash_distance: float = 2.0
@export var dash_speed: float = 8.0




func _ready() -> void:
    pass

func enter() -> void:
    pass

func exit() -> void:
    pass

# func physics_update(delta: float) -> void:
# 	# Leaning doesn't change movement, just camera position
# 	# Delegate to previous state's movement logic
    
# 	# Apply gravity
# 	if not player.is_on_floor():
# 		player.velocity.y -= player.gravity * delta
    
# 	# Basic movement (can be customized based on previous state)
# 	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
# 	var direction = (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
    
# 	if direction:
# 		# Slower movement while leaning
# 		var lean_speed_multiplier = 0.7
# 		player.velocity.x = direction.x * player.SPEED * lean_speed_multiplier
# 		player.velocity.z = direction.z * player.SPEED * lean_speed_multiplier
# 	else:
# 		player.velocity.x = move_toward(player.velocity.x, 0, player.SPEED)
# 		player.velocity.z = move_toward(player.velocity.z, 0, player.SPEED)
    
# 	player.move_and_slide()

# func check_transitions() -> State:
# 	# Exit leaning if no lean keys pressed
# 	if not Input.is_action_pressed("lean_left") and not Input.is_action_pressed("lean_right"):
# 		# Return to appropriate state
# 		if not player.is_on_floor():
# 			return state_machine.get_state("FallingState")
        
# 		var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
        
# 		if Input.is_action_pressed("crouch"):
# 			return state_machine.get_state("CrouchWalkingState")
            
        
# 		if input_dir.length() > 0.1:
# 			if Input.is_action_pressed("sprint"):
# 				return state_machine.get_state("SprintingState")
# 			else:
# 				return state_machine.get_state("WalkingState")
# 		else:
# 			return state_machine.get_state("IdleState")
    
# 	# Check for jump (cancel lean)
# 	if Input.is_action_just_pressed("jump") and player.is_on_floor():
# 		return state_machine.get_state("JumpingState")
    
# 	# Check for falling
# 	if not player.is_on_floor():
# 		return state_machine.get_state("FallingState")
    
# 	return null

# func _animate_camera_lean(leaning) -> void:
# 	# Placeholder for any additional camera lean animations if needed
# 	if leaning == LeanDirection.LEFT:
# 		# Implement left lean animation if desired
# 		# player.anim_player.get_animation("LeanLeft")
# 		pass
# 	elif leaning == LeanDirection.RIGHT:
# 		# Implement right lean animation if desired
# 		pass
# 	else:
# 		# Reset to neutral
# 		pass
