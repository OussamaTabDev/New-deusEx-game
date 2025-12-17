class_name SmallGrabInteractionHandler
extends Node

## JUICY Small Object Handler - Arkane Style (Dishonored/Deathloop)
## Features: Spring-damping motion, movement sway, procedural tilt,
## configurable rotation/scale/offset, full collision disabling while held,
## and smooth grab-in interpolation with tunable speed.

# ============================================================================ 
# SIGNALS 
# ============================================================================ 
signal small_object_grabbed(object: RigidBody3D)
signal small_object_dropped(object: RigidBody3D)
signal small_object_thrown(object: RigidBody3D, velocity: Vector3)

# ============================================================================ 
# REFERENCES 
# ============================================================================ 
@export_group("Small Grab References")
@export var hand_marker: Node3D 

# ============================================================================ 
# JUICY SETTINGS
# ============================================================================ 
@export_group("Small Grab Settings")
@export var max_small_mass: float = 1.0 
@export var max_small_volume: float = 0.125
@export var small_throw_force: float = 15.0 

@export_group("Grab Transform Overrides")
@export var grab_offset: Vector3 = Vector3(0, 0, -0.1)      # Local offset from hand
@export var override_rotation: Vector3 = Vector3.ZERO      # Euler angles (radians)
@export var override_scale: Vector3 = Vector3.ONE          # Scale multiplier

@export_group("Juice & Feel")
@export var spring_strength: float = 40.0   # How "snappy" the grab is
@export var spring_damping: float = 10.0    # Prevents infinite wobbling
@export var sway_amount: float = 1.5        # How much the object lags behind movement
@export var tilt_amount: float = 0.05       # How much the object tilts when strafing
@export var max_sway_distance: float = 0.2
@export var rotation_interp_speed: float = 15.0   # Rotation slerp speed
@export var scale_interp_speed: float = 10.0      # Scale lerp speed
@export var grab_interpolation_speed: float = 20.0  # Grab-in animation speed (higher = faster)

# ============================================================================ 
# STATE 
# ============================================================================ 
var main_component: UnifiedInteractionComponent
var held_small_object: RigidBody3D = null
var is_holding_small: bool = false
var original_parent: Node = null
var original_gravity_scale: float = 1.0
var original_linear_damp: float = 0.0
var original_angular_damp: float = 0.0

# Procedural Animation State
var current_velocity: Vector3 = Vector3.ZERO
var last_hand_pos: Vector3 = Vector3.ZERO
var sway_offset: Vector3 = Vector3.ZERO

# Visibility & Collision State
var original_visibility_layers: Dictionary = {}
var original_collision_layer: int = 1
var original_collision_mask: int = 1
var disabled_shapes: Array = []

# Grab-in animation state
var is_in_grab_transition: bool = false
var grab_transition_progress: float = 0.0

# ============================================================================ 
# INITIALIZATION 
# ============================================================================ 
func initialize(component: UnifiedInteractionComponent) -> void:
	main_component = component
	_validate_hand_marker()
	if hand_marker:
		last_hand_pos = hand_marker.global_position

func _validate_hand_marker() -> void:
	if not hand_marker:
		push_error("SmallGrabInteractionHandler: hand_marker not assigned!")

# ============================================================================ 
# VALIDATION 
# ============================================================================ 
func can_small_grab(rb: RigidBody3D) -> bool:
	if not rb: return false
	if rb.mass <= max_small_mass: return true
	
	var aabb = rb.get_aabb()
	if aabb.size != Vector3.ZERO:
		var volume = aabb.size.x * aabb.size.y * aabb.size.z
		if volume <= max_small_volume: return true
	return false

func should_use_small_grab(rb: RigidBody3D) -> bool:
	return can_small_grab(rb)

func handle_small_grab_target(target: Node, component: UnifiedInteractionComponent) -> void:
	if is_holding_small:
		component._update_ui("Drop", "", target.name)
	else:
		component._update_ui("Grab", "", target.name + " (Small)")

# ============================================================================ 
# GRAB ACTIONS 
# ============================================================================ 
func grab_small_object(rb: RigidBody3D) -> void:
	if not rb or not main_component or not hand_marker: return
	if not can_small_grab(rb): return
	
	if is_holding_small:
		drop_small_object()
	
	held_small_object = rb
	is_holding_small = true
	original_parent = rb.get_parent()
	
	# --- DISABLE COLLISIONS ---
	original_collision_layer = rb.collision_layer
	original_collision_mask = rb.collision_mask
	disabled_shapes.clear()
	_disable_collision_shapes(rb)
	rb.collision_layer = 0
	rb.collision_mask = 0
	
	# --- VISIBILITY ---
	_store_and_set_visibility_layers(rb, 1 << 4) 
	
	# --- PHYSICS PROPS ---
	original_gravity_scale = rb.gravity_scale
	original_linear_damp = rb.linear_damp
	original_angular_damp = rb.angular_damp
	
	rb.gravity_scale = 0.0
	rb.linear_damp = 10.0
	rb.angular_damp = 10.0
	
	# --- REPARENTING ---
	var global_trans = rb.global_transform
	rb.get_parent().remove_child(rb)
	hand_marker.add_child(rb)
	
	# Start smooth grab-in
	is_in_grab_transition = true
	grab_transition_progress = 0.0
	
	# Keep collision exceptions (safe but optional)
	if main_component.player:
		main_component.player.add_collision_exception_with(rb)
		rb.add_collision_exception_with(main_component.player)
	
	small_object_grabbed.emit(rb)

func drop_small_object() -> void:
	if not is_holding_small or not held_small_object: return
	
	var obj = held_small_object
	var global_trans = obj.global_transform
	
	# --- RESTORE COLLISIONS ---
	obj.collision_layer = original_collision_layer
	obj.collision_mask = original_collision_mask
	for shape in disabled_shapes:
		if is_instance_valid(shape):
			shape.disabled = false
	disabled_shapes.clear()
	
	# --- UNPARENT ---
	hand_marker.remove_child(obj)
	if original_parent and is_instance_valid(original_parent):
		original_parent.add_child(obj)
	else:
		main_component.get_tree().root.add_child(obj)
	
	obj.global_transform = global_trans
	obj.gravity_scale = original_gravity_scale
	obj.linear_damp = original_linear_damp
	obj.angular_damp = original_angular_damp
	
	# --- VISIBILITY ---
	_restore_visibility_layers(obj)
	
	# --- COLLISION EXCEPTIONS ---
	if main_component.player:
		main_component.player.remove_collision_exception_with(obj)
		obj.remove_collision_exception_with(main_component.player)
		obj.linear_velocity = main_component.player.velocity * 0.8
	
	small_object_dropped.emit(obj)
	held_small_object = null
	is_holding_small = false
	is_in_grab_transition = false

func throw_small_object() -> void:
	if not is_holding_small or not held_small_object or not main_component: return
	var thrown_obj = held_small_object
	var dir = -hand_marker.global_transform.basis.z
	drop_small_object()
	thrown_obj.apply_central_impulse(dir * small_throw_force)
	small_object_thrown.emit(thrown_obj, dir * small_throw_force)

# ============================================================================ 
# JUICY PHYSICS UPDATE
# ============================================================================ 
func update_physics(delta: float) -> void:
	if not is_holding_small or not held_small_object or not hand_marker: return
	if not is_instance_valid(held_small_object):
		is_holding_small = false
		is_in_grab_transition = false
		return

	# --- SMOOTH GRAB-IN ANIMATION ---
	if is_in_grab_transition:
		grab_transition_progress = min(1.0, grab_transition_progress + grab_interpolation_speed * delta)
		
		# Target transform in hand space
		var target_local_pos = grab_offset
		var target_local_basis = Basis(Quaternion.from_euler(override_rotation))
		var target_local_scale = override_scale
		
		# Interpolate from current to target
		var current_local = held_small_object.transform
		var new_pos = current_local.origin.lerp(target_local_pos, grab_transition_progress)
		var new_basis = current_local.basis.slerp(target_local_basis, grab_transition_progress)
		var new_scale = current_local.basis.get_scale().lerp(target_local_scale, grab_transition_progress)
		
		# Apply interpolated transform
		held_small_object.transform = Transform3D(new_basis.scaled(new_scale), new_pos)
		
		# End transition
		if grab_transition_progress >= 1.0:
			is_in_grab_transition = false
			current_velocity = Vector3.ZERO
			sway_offset = Vector3.ZERO
			last_hand_pos = hand_marker.global_position
		
		# Suppress physics
		held_small_object.linear_velocity = Vector3.ZERO
		held_small_object.angular_velocity = Vector3.ZERO
		return

	# 1. SWAY
	var hand_move_delta = (hand_marker.global_position - last_hand_pos)
	sway_offset -= hand_move_delta * sway_amount
	sway_offset = sway_offset.limit_length(max_sway_distance)
	sway_offset = sway_offset.lerp(Vector3.ZERO, delta * 5.0)
	last_hand_pos = hand_marker.global_position

	# 2. SPRING-DAMPING POSITION
	var target_pos = grab_offset + hand_marker.to_local(hand_marker.global_position + sway_offset)
	var pos_error = target_pos - held_small_object.position
	var spring_force = pos_error * spring_strength
	current_velocity += spring_force * delta
	current_velocity *= (1.0 - spring_damping * delta)
	held_small_object.position += current_velocity * delta

	# 3. ROTATION (override + tilt)
	var base_tilt = Vector3.ZERO
	if spring_strength > 0:
		base_tilt.x = clamp(-current_velocity.y * tilt_amount, -0.2, 0.2)
		base_tilt.z = clamp(current_velocity.x * tilt_amount, -0.2, 0.2)
	var target_euler = override_rotation + base_tilt
	var target_rot = Quaternion.from_euler(target_euler)
	var current_rot = held_small_object.transform.basis.get_rotation_quaternion()
	held_small_object.transform.basis = Basis(current_rot.slerp(target_rot, delta * rotation_interp_speed))

	# 4. SCALE
	held_small_object.scale = held_small_object.scale.lerp(override_scale, delta * scale_interp_speed)

	# 5. ZERO PHYSICS FEEDBACK
	held_small_object.linear_velocity = Vector3.ZERO
	held_small_object.angular_velocity = Vector3.ZERO

# ============================================================================ 
# HELPERS 
# ============================================================================ 
func _store_and_set_visibility_layers(node: Node, new_layer: int) -> void:
	original_visibility_layers.clear()
	_collect_mesh_visibility(node, node)
	for path in original_visibility_layers:
		var mesh_node = node.get_node_or_null(path)
		if mesh_node: mesh_node.layers = new_layer

func _restore_visibility_layers(node: Node) -> void:
	for path in original_visibility_layers:
		var mesh_node = node.get_node_or_null(path)
		if mesh_node: mesh_node.layers = original_visibility_layers[path]

func _collect_mesh_visibility(root: Node, current: Node) -> void:
	if current is MeshInstance3D:
		original_visibility_layers[root.get_path_to(current)] = current.layers
	for child in current.get_children():
		_collect_mesh_visibility(root, child)

func _disable_collision_shapes(node: Node) -> void:
	if node is CollisionShape3D:
		if not node.disabled:
			disabled_shapes.append(node)
			node.disabled = true
	for child in node.get_children():
		_disable_collision_shapes(child)

# ============================================================================ 
# PUBLIC API 
# ============================================================================ 
func is_holding() -> bool:
	return is_holding_small

func get_held_object() -> RigidBody3D:
	return held_small_object

func is_small_object(rb: RigidBody3D) -> bool:
	return can_small_grab(rb)

func get_grab_info(rb: RigidBody3D) -> Dictionary:
	return {
		"mass": rb.mass,
		"volume": get_object_volume(rb),
		"is_small": can_small_grab(rb),
		"reason": "mass <= %.1fkg or volume <= %.3fm³" % [max_small_mass, max_small_volume]
	}

func get_object_volume(rb: RigidBody3D) -> float:
	var aabb = rb.get_aabb()
	return aabb.size.x * aabb.size.y * aabb.size.z
