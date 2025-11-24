class_name SwimmingState
extends State

# Swimming parameters
@export var swim_speed: float = 3.0
@export var swim_acceleration: float = 6.0
@export var swim_friction: float = 6.0
@export var buoyancy_force: float = .5
@export var dive_speed: float = 4.0
@export var surface_speed: float = 5.0
@export var oxygen_max: float = 100.0
@export var oxygen_drain_rate: float = 10.0  # Per second

var oxygen: float = 100.0
var is_underwater: bool = false
var water_surface_y: float = 0.0
var entry_velocity: Vector3 = Vector3.ZERO  # Store velocity when entering water

func enter() -> void:
	if state_machine.previous_state.name == "SlidingState":
		player.anim_player.play("Crouching", -1, -10, true)
		pass
	player.can_wall_run_bool = false
	player.SPEED = swim_speed
	oxygen = oxygen_max
	
	# Store the velocity when entering water for momentum-based depth
	entry_velocity = player.velocity
	
	# Get water surface level based on Area3D bounds
	if player.current_water_body:
		_calculate_water_surface()

func exit() -> void:
	# Reset oxygen when leaving water
	oxygen = oxygen_max

func _calculate_water_surface() -> void:
	# Get the water body's collision shape to determine surface level
	if not player.current_water_body:
		return
	
	var water_body = player.current_water_body
	var collision_shape: CollisionShape3D = null
	
	# Find the collision shape in the Area3D
	for child in water_body.get_children():
		if child is CollisionShape3D:
			collision_shape = child
			break
	
	if not collision_shape or not collision_shape.shape:
		# Fallback to global position if no collision shape found
		water_surface_y = water_body.global_position.y
		return
	
	# Calculate the top of the water based on shape type
	var shape = collision_shape.shape
	var shape_global_pos = collision_shape.global_position
	
	if shape is BoxShape3D:
		var box_shape = shape as BoxShape3D
		water_surface_y = shape_global_pos.y + (box_shape.size.y / 2.0)
	elif shape is CylinderShape3D:
		var cylinder_shape = shape as CylinderShape3D
		water_surface_y = shape_global_pos.y + cylinder_shape.height / 2.0
	elif shape is SphereShape3D:
		var sphere_shape = shape as SphereShape3D
		water_surface_y = shape_global_pos.y + sphere_shape.radius
	elif shape is CapsuleShape3D:
		var capsule_shape = shape as CapsuleShape3D
		water_surface_y = shape_global_pos.y + (capsule_shape.height / 2.0) + capsule_shape.radius
	else:
		# Fallback for other shapes
		water_surface_y = shape_global_pos.y

func physics_update(delta: float) -> void:
	# Get player's half height (assuming CharacterBody3D with CollisionShape3D)
	var player_half_height = _get_player_half_height()
	
	# Check if head is underwater (player center + half height = head position)
	is_underwater = (player.global_position.y + player_half_height) < water_surface_y
	
	# Handle oxygen
	if is_underwater:
		oxygen -= oxygen_drain_rate * delta
		if oxygen <= 0:
			oxygen = 0
			# Take damage or trigger drowning state
			#player.take_damage(5 * delta)  # Adjust damage as needed
	else:
		# Regenerate oxygen when head is above water
		oxygen = min(oxygen + oxygen_drain_rate * 2 * delta, oxygen_max)
	
	# Get input direction
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var camera_basis = player.CAMERA_CONTROLLER.global_transform.basis
	var direction = (camera_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# Horizontal movement
	if input_dir.length() > 0.1:
		player.velocity.x = move_toward(player.velocity.x, direction.x * swim_speed, swim_acceleration * delta)
		player.velocity.z = move_toward(player.velocity.z, direction.z * swim_speed, swim_acceleration * delta)
	else:
		# Apply friction
		player.velocity.x = move_toward(player.velocity.x, 0, swim_friction * delta)
		player.velocity.z = move_toward(player.velocity.z, 0, swim_friction * delta)
	
	# Vertical movement (diving and surfacing)
	if Input.is_action_pressed("jump"):
		# Surface / swim up
		player.velocity.y = move_toward(player.velocity.y, surface_speed, swim_acceleration * delta)
	elif Input.is_action_pressed("crouch"):
		# Dive / swim down
		player.velocity.y = move_toward(player.velocity.y, -dive_speed, swim_acceleration * delta)
	else:
		# Natural buoyancy - slowly float up
		player.velocity.y = move_toward(player.velocity.y, buoyancy_force, swim_friction * delta)
	
	# Prevent going above water surface too much
	# Allow player to be half-submerged (float at surface naturally)
	var target_float_position = water_surface_y - player_half_height
	if player.global_position.y > target_float_position and player.velocity.y > 0:
		player.velocity.y = min(player.velocity.y, 0)
	
	player.move_and_slide()

func _get_player_half_height() -> float:
	# Try to get player's collision shape height
	for child in player.get_children():
		if child is CollisionShape3D:
			var shape = child.shape
			if shape is CapsuleShape3D:
				return (shape.height / 2.0) + shape.radius
			elif shape is BoxShape3D:
				return shape.size.y / 2.0
			elif shape is CylinderShape3D:
				return shape.height / 2.0
	
	# Fallback to a reasonable default (adjust based on your player size)
	return 0.85  # Assuming ~1.8m tall character

func check_transitions() -> State:
	# Exit water - transition to appropriate state
	if not player.is_in_water():
		if player.is_on_floor():
			return state_machine.get_state("IdleState")
		else:
			return state_machine.get_state("FallingState")
	
	# Sprint swimming (faster swimming)
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if Input.is_action_pressed("sprint") and input_dir.length() > 0.1:
		return state_machine.get_state("SprintSwimmingState")  # Optional: create this for faster swimming
	
	# Only transition to surface swimming if:
	# - Very close to surface
	# - NOT holding crouch
	# - Vertical velocity is low (not diving or falling through)
	var player_half_height = _get_player_half_height()
	var head_y = player.global_position.y + player_half_height
	var near_surface = (water_surface_y - head_y) < 0.3
	var is_moving_gently = abs(player.velocity.y) < 0.5

	if near_surface and not Input.is_action_pressed("crouch") and is_moving_gently:
		return state_machine.get_state("SurfaceSwimmingState")

	return null
