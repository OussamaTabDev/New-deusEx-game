# ============ SPRINT SWIMMING STATE ============
class_name SprintSwimmingState
extends State

# Sprint swimming parameters
@export var sprint_swim_speed: float = 16.0
@export var sprint_acceleration: float = 12.0
@export var sprint_friction: float = 8.0
@export var buoyancy_force: float = 2.0
@export var dive_speed: float = 5.0
@export var surface_speed: float = 6.0
@export var oxygen_drain_multiplier: float = 1.5  # Drains oxygen faster when sprinting

var oxygen: float = 100.0
var is_underwater: bool = false
var water_surface_y: float = 0.0
var oxygen_max: float = 100.0
var oxygen_drain_rate: float = 10.0

func enter() -> void:
	
	player.can_wall_run_bool = false
	player.SPEED = sprint_swim_speed
	
	# Get water surface level based on Area3D bounds
	if player.current_water_body:
		_calculate_water_surface()
	
	# Inherit oxygen from swimming state if possible
	var swimming_state = state_machine.get_state("SwimmingState")
	if swimming_state:
		oxygen = swimming_state.oxygen
		oxygen_max = swimming_state.oxygen_max
		oxygen_drain_rate = swimming_state.oxygen_drain_rate

func exit() -> void:
	# Pass oxygen back to swimming state
	var swimming_state = state_machine.get_state("SwimmingState")
	if swimming_state:
		swimming_state.oxygen = oxygen

func _calculate_water_surface() -> void:
	if not player.current_water_body:
		return
	
	var water_body = player.current_water_body
	var collision_shape: CollisionShape3D = null
	
	for child in water_body.get_children():
		if child is CollisionShape3D:
			collision_shape = child
			break
	
	if not collision_shape or not collision_shape.shape:
		water_surface_y = water_body.global_position.y
		return
	
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
		water_surface_y = shape_global_pos.y

func physics_update(delta: float) -> void:
	var player_half_height = _get_player_half_height()
	is_underwater = (player.global_position.y + player_half_height) < water_surface_y
	
	# Handle oxygen (drains faster when sprinting)
	if is_underwater:
		oxygen -= oxygen_drain_rate * oxygen_drain_multiplier * delta
		if oxygen <= 0:
			oxygen = 0
			player.take_damage(5 * delta)
	else:
		oxygen = min(oxygen + oxygen_drain_rate * 2 * delta, oxygen_max)
	
	# Get input direction
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var camera_basis = player.CAMERA_CONTROLLER.global_transform.basis
	var direction = (camera_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# Horizontal movement (faster)
	if input_dir.length() > 0.1:
		player.velocity.x = move_toward(player.velocity.x, direction.x * sprint_swim_speed, sprint_acceleration * delta)
		player.velocity.z = move_toward(player.velocity.z, direction.z * sprint_swim_speed, sprint_acceleration * delta)
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, sprint_friction * delta)
		player.velocity.z = move_toward(player.velocity.z, 0, sprint_friction * delta)
	
	# Vertical movement
	if Input.is_action_pressed("jump"):
		player.velocity.y = move_toward(player.velocity.y, surface_speed, sprint_acceleration * delta)
	elif Input.is_action_pressed("crouch"):
		player.velocity.y = move_toward(player.velocity.y, -dive_speed, sprint_acceleration * delta)
	else:
		player.velocity.y = move_toward(player.velocity.y, buoyancy_force, sprint_friction * delta)
	
	# Prevent going above water surface too much
	var target_float_position = water_surface_y - player_half_height
	if player.global_position.y > target_float_position and player.velocity.y > 0:
		player.velocity.y = min(player.velocity.y, 0)
	
	player.move_and_slide()

func check_transitions() -> State:
	if not player.is_in_water():
		if player.is_on_floor():
			return state_machine.get_state("IdleState")
		else:
			return state_machine.get_state("FallingState")
	
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	# Stop sprinting if not pressing sprint or no input
	if not Input.is_action_pressed("sprint") or input_dir.length() < 0.1:
		return state_machine.get_state("SwimmingState")
	
	return null

func _get_player_half_height() -> float:
	for child in player.get_children():
		if child is CollisionShape3D:
			var shape = child.shape
			if shape is CapsuleShape3D:
				return (shape.height / 2.0) + shape.radius
			elif shape is BoxShape3D:
				return shape.size.y / 2.0
			elif shape is CylinderShape3D:
				return shape.height / 2.0
	return 0.9

