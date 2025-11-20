
# ============ SURFACE SWIMMING STATE ============
class_name SurfaceSwimmingState
extends State

# Surface swimming parameters (faster horizontal movement, restricted vertical)
@export var surface_speed: float = 4.0
@export var surface_acceleration: float = 10.0
@export var surface_friction: float = 7.0
@export var bob_amplitude: float = 0.3  # How much the player bobs up and down
@export var bob_speed: float = 2.0  # How fast the bobbing motion is
@export var surface_tolerance: float = 0.5  # How close to surface to stay in this state

var water_surface_y: float = 0.0
var bob_time: float = 0.0

func enter() -> void:
	player.can_wall_run_bool = false
	player.SPEED = surface_speed
	bob_time = 0.0
	
	if player.current_water_body:
		_calculate_water_surface()

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
	bob_time += delta * bob_speed
	
	# Get input direction (horizontal only)
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var camera_basis = player.CAMERA_CONTROLLER.global_transform.basis
	var direction = (camera_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# Horizontal movement (faster at surface)
	if input_dir.length() > 0.1:
		player.velocity.x = move_toward(player.velocity.x, direction.x * surface_speed, surface_acceleration * delta)
		player.velocity.z = move_toward(player.velocity.z, direction.z * surface_speed, surface_acceleration * delta)
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, surface_friction * delta)
		player.velocity.z = move_toward(player.velocity.z, 0, surface_friction * delta)
	
	# Vertical movement - keep player at surface with bobbing effect
	var target_surface_y = water_surface_y - player_half_height
	var bob_offset = sin(bob_time) * bob_amplitude
	var target_y = target_surface_y + bob_offset
	
	# Smoothly move to target surface position
	player.velocity.y = (target_y - player.global_position.y) * 5.0
	
	player.move_and_slide()

func check_transitions() -> State:
	if not player.is_in_water():
		if player.is_on_floor():
			return state_machine.get_state("IdleState")
		else:
			return state_machine.get_state("FallingState")
	
	var player_half_height = _get_player_half_height()
	var distance_from_surface = abs((player.global_position.y + player_half_height) - water_surface_y)
	
	# If player dives down, switch to regular swimming
	if Input.is_action_pressed("crouch") or distance_from_surface > surface_tolerance:
		return state_machine.get_state("SwimmingState")
	
	# If player wants to sprint
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if Input.is_action_pressed("sprint") and input_dir.length() > 0.1:
		return state_machine.get_state("SprintSwimmingState")
	
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