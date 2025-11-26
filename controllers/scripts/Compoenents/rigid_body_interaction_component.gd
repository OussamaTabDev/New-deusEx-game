class_name RigidBodyInteractionComponent
extends Node3D

## Component for grabbing, holding, and throwing RigidBody3D objects.
## USES VELOCITY-BASED HOLDING to prevent wall clipping.

signal object_grabbed(object: RigidBody3D)
signal object_dropped(object: RigidBody3D)
signal object_thrown(object: RigidBody3D, velocity: Vector3)

# --- Configuration ---
@export_group("References")
@export var interaction_raycast: RayCast3D ## The RayCast used to detect objects
@export var hold_position: Node3D ## A Node3D child of your Camera acting as the hold point

@export_group("Settings")
@export var max_grab_distance: float = 3.0
@export var max_pickup_mass: float = 50.0
@export var throw_force: float = 50.0
## If the object gets stuck behind a wall and you move this far away, it drops.
@export var break_distance: float = 2.0 
@export var grab_action: String = "interact"
@export var throw_action: String = "throw"

@export_group("Physics Smoothing")
## How "stiff" the hold is. Higher = snaps faster, Lower = loosely follows.
@export var hold_power: float = 20.0 
## How fast it rotates to match view.
@export var rotation_power: float = 20.0 

# --- Internal State ---
var held_object: RigidBody3D = null
var is_holding: bool = false
var original_gravity_scale: float = 1.0
var original_linear_damp: float = 0.0
var original_angular_damp: float = 0.0
var player: CharacterBody3D
var hold_offset_center: Vector3 = Vector3.ZERO # Calculated center of object

func _ready() -> void:
	# Validate references
	if not interaction_raycast:
		push_error("RigidBodyInteractionComponent: InteractionRayCast not assigned!")
	
	# Auto-find player (assuming this component is on the Player or Camera)
	var parent = get_parent()
	while parent:
		if parent is CharacterBody3D:
			player = parent
			break
		parent = parent.get_parent()
		
	if not player:
		push_warning("RigidBodyInteractionComponent: Could not find CharacterBody3D ancestor. 'Prop Surfing' fix will not work.")

	# Create default hold position if missing
	if not hold_position:
		var default_hold = Node3D.new()
		default_hold.name = "DefaultHoldPosition"
		# Attach to camera if possible, otherwise self
		if get_parent().name.to_lower().contains("camera"):
			get_parent().add_child(default_hold)
		else:
			add_child(default_hold)
		default_hold.position = Vector3(0.5, -0.5, -2.0)
		hold_position = default_hold

func _physics_process(delta: float) -> void:
	# Handle Input
	if Input.is_action_just_pressed(grab_action):
		if is_holding:
			drop_object()
		else:
			if player.state_machine.current_state.name != "SprintingState":
				attempt_grab()
	
	if Input.is_action_just_pressed(throw_action) and is_holding:
		throw_object()
	
	# Physics Loop
	if is_holding and held_object:
		_apply_hold_forces(delta)

func attempt_grab() -> void:
	if not interaction_raycast: return
	if not interaction_raycast.is_colliding(): return
	
	var target = interaction_raycast.get_collider()
	if not target is RigidBody3D: return
	
	var rb = target as RigidBody3D
	
	# Checks
	if rb.mass > max_pickup_mass: return
	if global_position.distance_to(rb.global_position) > max_grab_distance: return
	
	grab_object(rb)

func grab_object(rb: RigidBody3D) -> void:
	if is_holding: drop_object()
	
	held_object = rb
	is_holding = true
	
	# 1. Store Original Physics Properties
	original_gravity_scale = held_object.gravity_scale
	original_linear_damp = held_object.linear_damp
	original_angular_damp = held_object.angular_damp
	
	# 2. Modify Physics for Holding
	held_object.gravity_scale = 0.0
	held_object.linear_damp = 1.0 # Adds stability
	held_object.angular_damp = 1.0
	
	# 3. Calculate Center Offset (FIXED FOR BARRELS AND OTHER ASYMMETRICAL OBJECTS)
	var aabb = held_object.get_aabb()
	if aabb.size == Vector3.ZERO:
		hold_offset_center = Vector3.ZERO
	else:
		var center_local = aabb.position + aabb.size / 2.0
		hold_offset_center = -center_local
	
	# 4. Prevent Player Collision (Fixes "Flying/Prop Surfing")
	if player:
		player.add_collision_exception_with(held_object)
		held_object.add_collision_exception_with(player)
	
	object_grabbed.emit(held_object)

func drop_object() -> void:
	if not is_holding or not held_object: return
	
	# Restore Physics
	held_object.gravity_scale = original_gravity_scale
	held_object.linear_damp = original_linear_damp
	held_object.angular_damp = original_angular_damp
	
	# Restore Collisions
	if player:
		player.remove_collision_exception_with(held_object)
		held_object.remove_collision_exception_with(player)
	
	# Apply momentum from player movement so it doesn't stop dead
	if player:
		held_object.linear_velocity += player.velocity
	
	object_dropped.emit(held_object)
	
	held_object = null
	is_holding = false

func throw_object() -> void:
	if not is_holding or not held_object: return
	
	var thrown_obj = held_object
	
	# Calculate direction based on where we are looking (Hold Position Z-axis)
	var dir = -hold_position.global_transform.basis.z
	
	# Drop it first to restore physics/collision
	drop_object()
	
	# Apply impulse (Instant force)
	thrown_obj.apply_central_impulse(dir * throw_force)
	object_thrown.emit(thrown_obj, dir * throw_force)

func _apply_hold_forces(delta: float) -> void:
	if not is_instance_valid(held_object):
		is_holding = false
		held_object = null
		return

	# --- 1. BREAK DISTANCE CHECK ---
	var target_pos = hold_position.global_position
	var current_pos = held_object.global_position
	
	# If object gets stuck behind a wall and player moves away, drop it.
	if target_pos.distance_to(current_pos) > break_distance:
		drop_object()
		return

	# --- 2. POSITION CALCULATION (Velocity Based) ---
	
	# We want the CENTER of the object to be at the target, not the pivot.
	# But we move the pivot. So we apply the rotated offset.
	var center_offset_rotated = held_object.global_transform.basis * hold_offset_center
	
	# The actual point we want the pivot to reach
	var desired_pivot_pos = target_pos + center_offset_rotated
	
	# Calculate velocity vector
	var target_velocity = (desired_pivot_pos - held_object.global_position) * hold_power
	
	# Apply Velocity directly
	held_object.linear_velocity = target_velocity

	# --- 3. ROTATION CALCULATION (Torque Based) ---
	
	var target_basis = hold_position.global_transform.basis
	var current_basis = held_object.global_transform.basis
	
	# Calculate the rotation difference (Quaternion)
	var rot_diff = target_basis * current_basis.inverse()
	var quat_diff = rot_diff.get_rotation_quaternion()
	
	# Convert Quaternion to Axis-Angle (Angular Velocity)
	var axis = quat_diff.get_axis().normalized()
	var angle = quat_diff.get_angle()
	
	# Fix Quaternion flip (shortest path check)
	if angle > PI:
		angle -= 2 * PI
	
	# Apply angular velocity
	held_object.angular_velocity = axis * angle * rotation_power
