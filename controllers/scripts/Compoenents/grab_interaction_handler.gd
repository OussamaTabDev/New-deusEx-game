class_name GrabInteractionHandler
extends Node

## Handles physics-based object grabbing, holding, and throwing

# ============================================================================
# SIGNALS
# ============================================================================
signal object_grabbed(object: RigidBody3D)
signal object_dropped(object: RigidBody3D)
signal object_thrown(object: RigidBody3D, velocity: Vector3)

# ============================================================================
# STATE
# ============================================================================
var main_component: UnifiedInteractionComponent
var held_object: RigidBody3D = null
var is_holding_object: bool = false
var original_gravity_scale: float = 1.0
var original_linear_damp: float = 0.0
var original_angular_damp: float = 0.0
var hold_offset_center: Vector3 = Vector3.ZERO

# ============================================================================
# INITIALIZATION
# ============================================================================
func initialize(component: UnifiedInteractionComponent) -> void:
	main_component = component

# ============================================================================
# TARGET HANDLING
# ============================================================================
func handle_grab_target(target: Node, component: UnifiedInteractionComponent) -> void:
	if is_holding_object:
		component._update_ui("Drop", "", target.name)
	else:
		component._update_ui("Grab", "", target.name)

# ============================================================================
# GRAB ACTIONS
# ============================================================================
func grab_object(rb: RigidBody3D) -> void:
	if not rb or not main_component:
		return
	
	# Validation checks
	if rb.mass > main_component.max_pickup_mass:
		main_component.interaction_failed.emit("Too heavy")
		return
	
	if main_component.global_position.distance_to(rb.global_position) > main_component.max_interaction_distance:
		return
	
	# Prevent grabbing while sprinting
	if main_component.player and main_component.player.has_node("state_machine"):
		var state_machine = main_component.player.get_node("state_machine")
		if state_machine.current_state.name == "SprintingState":
			return
	
	# Drop current object if holding one
	if is_holding_object:
		drop_object()
	
	held_object = rb
	is_holding_object = true
	
	# Store and modify physics
	original_gravity_scale = held_object.gravity_scale
	original_linear_damp = held_object.linear_damp
	original_angular_damp = held_object.angular_damp
	
	held_object.gravity_scale = 0.0
	held_object.linear_damp = 1.0
	held_object.angular_damp = 1.0
	
	# Calculate center offset
	var aabb = held_object.get_aabb()
	if aabb.size == Vector3.ZERO:
		hold_offset_center = Vector3.ZERO
	else:
		var center_local = aabb.position + aabb.size / 2.0
		hold_offset_center = -center_local
	
	# Prevent player collision
	if main_component.player:
		main_component.player.add_collision_exception_with(held_object)
		held_object.add_collision_exception_with(main_component.player)
	
	object_grabbed.emit(held_object)

func drop_object() -> void:
	if not is_holding_object or not held_object:
		return
	
	# Restore physics
	held_object.gravity_scale = original_gravity_scale
	held_object.linear_damp = original_linear_damp
	held_object.angular_damp = original_angular_damp
	
	# Restore collisions
	if main_component.player:
		main_component.player.remove_collision_exception_with(held_object)
		held_object.remove_collision_exception_with(main_component.player)
	
	# Apply momentum
	if main_component.player:
		held_object.linear_velocity += main_component.player.velocity
	
	object_dropped.emit(held_object)
	
	held_object = null
	is_holding_object = false

func throw_object() -> void:
	if not is_holding_object or not held_object or not main_component:
		return
	
	var thrown_obj = held_object
	var dir = -main_component.hold_position.global_transform.basis.z
	
	drop_object()
	
	thrown_obj.apply_central_impulse(dir * main_component.throw_force)
	object_thrown.emit(thrown_obj, dir * main_component.throw_force)

# ============================================================================
# PHYSICS UPDATE
# ============================================================================
func update_physics(delta: float) -> void:
	if not is_holding_object or not held_object or not main_component:
		return
	
	if not is_instance_valid(held_object):
		is_holding_object = false
		held_object = null
		return
	
	var target_pos = main_component.hold_position.global_position
	var current_pos = held_object.global_position
	
	# Break distance check
	if target_pos.distance_to(current_pos) > main_component.break_distance:
		drop_object()
		return
	
	# Position calculation
	var center_offset_rotated = held_object.global_transform.basis * hold_offset_center
	var desired_pivot_pos = target_pos + center_offset_rotated
	var target_velocity = (desired_pivot_pos - held_object.global_position) * main_component.hold_power
	held_object.linear_velocity = target_velocity
	
	# Rotation calculation
	var target_basis = main_component.hold_position.global_transform.basis
	var current_basis = held_object.global_transform.basis
	var rot_diff = target_basis * current_basis.inverse()
	var quat_diff = rot_diff.get_rotation_quaternion()
	var axis = quat_diff.get_axis().normalized()
	var angle = quat_diff.get_angle()
	
	if angle > PI:
		angle -= 2 * PI
	
	held_object.angular_velocity = axis * angle * main_component.rotation_power

# ============================================================================
# PUBLIC API
# ============================================================================
func is_holding() -> bool:
	return is_holding_object

func get_held_object() -> RigidBody3D:
	return held_object