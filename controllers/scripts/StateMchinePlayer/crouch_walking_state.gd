class_name CrouchWalkingState
extends State

@export var crouch_speed: float = 2.5
@export var crouch_height: float = 0.5

# var original_collision_height: float
# var target_collision_height: float
# var crouch_animation_speed: float = 5.0

# func _ready():
# 	super._ready()
# 	await player.ready
	
# 	# Store original collision shape height
# 	var collision_shape = player.get_node("CollisionShape3D")
# 	if collision_shape and collision_shape.shape is CapsuleShape3D:
# 		original_collision_height = collision_shape.shape.height

# func enter() -> void:
# 	player.SPEED = crouch_speed
# 	_animate_crouch(true)

# func exit() -> void:
# 	_animate_crouch(false)

# func update(delta: float) -> void:
# 	# Animate the crouch
# 	var collision_shape = player.get_node("CollisionShape3D")
# 	if collision_shape and collision_shape.shape is CapsuleShape3D:
# 		collision_shape.shape.height = lerp(
# 			collision_shape.shape.height,
# 			target_collision_height,
# 			crouch_animation_speed * delta
# 		)
		
# 		# Adjust camera position to match crouch
# 		if player.CAMERA_CONTROLLER:
# 			var target_y = (target_collision_height - original_collision_height) * 0.5
# 			player.CAMERA_CONTROLLER.position.y = lerp(
# 				player.CAMERA_CONTROLLER.position.y,
# 				target_y,
# 				crouch_animation_speed * delta
# 			)

# func physics_update(delta: float) -> void:
# 	# Smoothly transition speed
# 	player.SPEED = lerp(player.SPEED, crouch_speed, 2.5 * delta)
	
# 	# Apply gravity
# 	if not player.is_on_floor():
# 		player.velocity.y -= player.gravity * delta
	
# 	# Get input and move
# 	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
# 	var direction = (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
# 	if direction:
# 		player.velocity.x = direction.x * player.SPEED
# 		player.velocity.z = direction.z * player.SPEED
# 	else:
# 		player.velocity.x = move_toward(player.velocity.x, 0, player.SPEED)
# 		player.velocity.z = move_toward(player.velocity.z, 0, player.SPEED)
	
# 	player.move_and_slide()

# func check_transitions() -> State:
# 	# Check for falling
# 	if not player.is_on_floor():
# 		return state_machine.get_state("FallingState")
	
# 	# Check if crouch released and can stand up
# 	if not Input.is_action_pressed("crouch"):
# 		if _can_stand_up():
# 			var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
# 			if input_dir.length() > 0.1:
# 				if Input.is_action_pressed("sprint"):
# 					return state_machine.get_state("SprintingState")
# 				else:
# 					return state_machine.get_state("WalkingState")
# 			else:
# 				return state_machine.get_state("IdleState")
	
# 	# Check if stopped moving
# 	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
# 	if input_dir.length() < 0.1:
# 		return state_machine.get_state("CrouchingState")
	
# 	return null

# func _animate_crouch(is_crouching: bool) -> void:
# 	if is_crouching:
# 		target_collision_height = original_collision_height * crouch_height
# 	else:
# 		target_collision_height = original_collision_height

# func _can_stand_up() -> bool:
# 	# Raycast upward to check if player can stand
# 	var space_state = player.get_world_3d().direct_space_state
# 	var query = PhysicsRayQueryParameters3D.create(
# 		player.global_position,
# 		player.global_position + Vector3(0, original_collision_height, 0)
# 	)
# 	query.exclude = [player]
	
# 	var result = space_state.intersect_ray(query)
# 	return result.is_empty()
