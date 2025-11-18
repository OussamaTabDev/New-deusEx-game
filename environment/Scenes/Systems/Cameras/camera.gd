extends StaticBody3D
class_name SecurityCamera

# ============================================================================
# SECURITY CAMERA SYSTEM - ENHANCED
# Professional stealth camera with smooth transitions and multiple states
# ============================================================================

## Node references
@export_group("Node References")
@export var anchor_rotation: Marker3D
@export var area_3d: Area3D
@export var vision_raycast: RayCast3D

## Camera Physical Settings
@export_group("Camera Settings")
@export_range(0.5, 10.0, 0.1) var fov_radius: float = 2.0 ## Vision cone width
@export_range(1.0, 20.0, 0.5) var vision_distance: float = 3.0 ## How far camera sees
@export_range(15.0, 90.0, 5.0) var max_rotation_x: float = 45.0 ## Vertical limit (degrees)
@export_range(30.0, 180.0, 5.0) var max_rotation_y: float = 90.0 ## Horizontal limit (degrees)

## Patrol Settings
@export_group("Patrol Settings")
@export_range(10.0, 100.0, 5.0) var patrol_speed: float = 30.0 ## Degrees per second
@export_range(0.0, 5.0, 0.1) var patrol_wait_time: float = 2.0 ## Pause at each point
@export var patrol_points: Array[Vector2] = [
	Vector2(-45, 0),
	Vector2(45, 0),
	Vector2(0, 30),
	Vector2(0, -30)
] ## Patrol rotations (x, y in degrees)

## Static Mode Settings
@export_group("Static Mode")
@export var static_mode_enabled: bool = false ## Enable static/fixed position mode
@export var static_mode_can_detect: bool = true ## Can detect players while static
@export var static_rotation: Vector2 = Vector2(0, 0) ## Fixed rotation (Y, X in degrees)

## Camera Power Settings
@export_group("Power Settings")
@export var is_powered_on: bool = true ## Camera power state
@export var can_be_disabled: bool = true ## Allow external disable/hacking

## Chase Settings
@export_group("Chase Settings")
@export_range(30.0, 150.0, 5.0) var chase_speed: float = 60.0 ## Tracking speed
@export_range(1.0, 30.0, 0.5) var speed_multiplier: float = 15.0 ## Adaptive speed factor

## Search Settings
@export_group("Search Settings")
@export_range(20.0, 100.0, 5.0) var search_speed: float = 45.0 ## Search rotation speed
@export_range(2.0, 10.0, 0.5) var search_duration: float = 5.0 ## How long to search
@export_range(0.1, 1.0, 0.1) var search_randomness: float = 0.5 ## Search pattern chaos

## Vision Settings
@export_group("Vision Settings")
@export_range(0.05, 0.5, 0.05) var vision_check_interval: float = 0.1 ## Detection frequency
@export_range(5.0, 15.0, 0.5) var lost_sight_wait_time: float = 10.0 ## Wait at obstacles
@export var detection_color: Color = Color(1.0, 0.0, 0.0) ## Chase mode color
@export var idle_color: Color = Color(0.0, 1.0, 0.0) ## Patrol/Static mode color
@export var search_color: Color = Color(1.0, 1.0, 0.0) ## Search/Wait mode color
@export var disabled_color: Color = Color(0.3, 0.3, 0.3) ## Powered off color

## Target Centering Settings
@export_group("Target Centering")
@export var enable_centering_offset: bool = true ## Compensate for vision cone edge detection
@export_range(-5.0, 5.0, 0.1) var vertical_offset: float = 0.0 ## Manual Y offset adjustment
@export_range(-2.0, 2.0, 0.1) var horizontal_offset: float = 0.0 ## Manual horizontal offset
@export var auto_calculate_offset: bool = true ## Auto-calculate offset based on FOV
@export_range(0.0, 1.0, 0.05) var centering_strength: float = 0.15 ## How strong the centering force is
@export_range(0.0, 5.0, 0.1) var oscillation_dampening: float = 1.0 ## Prevent up/down oscillation

## Transition Settings
@export_group("Smooth Transitions")
@export_range(0.1, 2.0, 0.1) var transition_smoothing: float = 0.3 ## Rotation smoothing factor
@export var use_smooth_transitions: bool = true ## Enable smooth state transitions

# ============================================================================
# STATE MACHINE
# ============================================================================

enum CameraState {
	DISABLED,            ## Camera is off/hacked/broken
	IDLE,                ## Powered on but inactive (boot up state)
	STATIC,              ## Fixed position, can detect
	PATROL,              ## Normal patrol between points
	CHASE,               ## Actively tracking player
	WAITING_AT_OBSTACLE, ## Player hidden, waiting
	SEARCH               ## Lost player, searching randomly
}

var current_state: CameraState = CameraState.IDLE
var previous_state: CameraState = CameraState.IDLE

# ============================================================================
# INTERNAL VARIABLES
# ============================================================================

# Smooth rotation
var target_rotation: Vector2 = Vector2.ZERO
var smooth_rotation: Vector2 = Vector2.ZERO

# Patrol state
var current_patrol_index: int = 0
var patrol_wait_timer: float = 0.0
var is_waiting_at_patrol: bool = false

# Detection state
var detected_player: Node3D = null
var last_known_position_head: Vector3 = Vector3.ZERO
var last_known_position_feet: Vector3 = Vector3.ZERO
var player_velocity: Vector3 = Vector3.ZERO
var previous_player_position: Vector3 = Vector3.ZERO
var detection_start_time: float = 0.0

# Obstacle waiting state
var obstacle_wait_timer: float = 0.0
var obstacle_last_position: Vector3 = Vector3.ZERO

# Search state
var search_timer: float = 0.0
var search_noise: FastNoiseLite = null
var search_time_offset: float = 0.0

# Vision check timer
var vision_timer: float = 0.0

# Current rotation
var current_rotation: Vector2 = Vector2.ZERO

# Idle timer for boot up
var idle_timer: float = 0.0
@export var idle_boot_time: float = 1.0 ## Time to stay in idle before activating

# Centering stabilization
var last_centered_position: Vector3 = Vector3.ZERO

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	_validate_setup()
	_initialize_search_noise()
	_apply_fov_settings()
	_set_initial_state()
	_update_raycast_color(_get_state_color())

func _validate_setup() -> void:
	assert(anchor_rotation != null, "SecurityCamera: anchor_rotation not assigned!")
	assert(area_3d != null, "SecurityCamera: area_3d not assigned!")
	assert(vision_raycast != null, "SecurityCamera: vision_raycast not assigned!")
	
	if patrol_points.is_empty() and not static_mode_enabled:
		push_warning("SecurityCamera: No patrol points defined, using default pattern")
		patrol_points = [Vector2(-45, 0), Vector2(45, 0)]

func _initialize_search_noise() -> void:
	search_noise = FastNoiseLite.new()
	search_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	search_noise.frequency = 0.5
	search_time_offset = randf() * 1000.0

func _apply_fov_settings() -> void:
	if area_3d:
		area_3d.scale = Vector3(fov_radius, fov_radius, vision_distance)

func _set_initial_state() -> void:
	if not is_powered_on:
		current_state = CameraState.DISABLED
		_disable_detection()
	elif static_mode_enabled:
		current_rotation = static_rotation
		smooth_rotation = static_rotation
		target_rotation = static_rotation
		_apply_rotation(current_rotation)
		current_state = CameraState.STATIC
	else:
		current_state = CameraState.IDLE
		if patrol_points.size() > 0:
			current_rotation = patrol_points[0]
			smooth_rotation = current_rotation
			target_rotation = current_rotation
			_apply_rotation(current_rotation)

# ============================================================================
# MAIN LOOP
# ============================================================================

func _process(delta: float) -> void:
	# Handle power state changes
	if not is_powered_on and current_state != CameraState.DISABLED:
		_change_state(CameraState.DISABLED)
	elif is_powered_on and current_state == CameraState.DISABLED:
		_change_state(CameraState.IDLE)
	
	# Vision checking (disabled state doesn't check)
	if current_state != CameraState.DISABLED:
		vision_timer += delta
		if vision_timer >= vision_check_interval:
			vision_timer = 0.0
			_check_vision()
	
	# Update current state
	match current_state:
		CameraState.DISABLED:
			_process_disabled(delta)
		CameraState.IDLE:
			_process_idle(delta)
		CameraState.STATIC:
			_process_static(delta)
		CameraState.PATROL:
			_process_patrol(delta)
		CameraState.CHASE:
			_process_chase(delta)
		CameraState.WAITING_AT_OBSTACLE:
			_process_waiting(delta)
		CameraState.SEARCH:
			_process_search(delta)
	
	# Apply smooth rotation transitions
	if use_smooth_transitions:
		_apply_smooth_rotation(delta)
	else:
		smooth_rotation = current_rotation
		_apply_rotation(smooth_rotation)

# ============================================================================
# STATE TRANSITIONS
# ============================================================================

func _change_state(new_state: CameraState) -> void:
	if current_state == new_state:
		return
	
	previous_state = current_state
	current_state = new_state
	
	# State entry logic
	match new_state:
		CameraState.DISABLED:
			_on_enter_disabled()
		CameraState.IDLE:
			_on_enter_idle()
		CameraState.STATIC:
			_on_enter_static()
		CameraState.PATROL:
			_on_enter_patrol()
		CameraState.CHASE:
			_on_enter_chase()
		CameraState.WAITING_AT_OBSTACLE:
			_on_enter_waiting()
		CameraState.SEARCH:
			_on_enter_search()
	
	_update_raycast_color(_get_state_color())

func _get_state_color() -> Color:
	match current_state:
		CameraState.DISABLED:
			return disabled_color
		CameraState.IDLE:
			return idle_color
		CameraState.STATIC:
			return idle_color
		CameraState.PATROL:
			return idle_color
		CameraState.CHASE:
			return detection_color
		CameraState.WAITING_AT_OBSTACLE:
			return search_color
		CameraState.SEARCH:
			return search_color
	return idle_color

# ============================================================================
# VISION & DETECTION
# ============================================================================

func _check_vision() -> void:
	# Static mode without detection does nothing
	if current_state == CameraState.STATIC and not static_mode_can_detect:
		return
	
	# Disabled and idle states don't detect
	if current_state == CameraState.DISABLED or current_state == CameraState.IDLE:
		return
	
	var overlapping_bodies = area_3d.get_overlapping_bodies()
	var player_found: bool = false
	
	for body in overlapping_bodies:
		if body.is_in_group("Player"):
			player_found = true
			_process_player_detection(body)
			break
	
	# Player left Area3D entirely
	if not player_found and (current_state == CameraState.CHASE or current_state == CameraState.WAITING_AT_OBSTACLE):
		_change_state(CameraState.SEARCH)

func _process_player_detection(player: Node3D) -> void:
	var player_target_position: Vector3
	if player.has_node("CameraController"):
		player_target_position = player.get_node("CameraController").global_position
	else:
		player_target_position = player.global_position
	
	var player_body_position = player.global_position
	
	vision_raycast.target_position = vision_raycast.to_local(player_target_position)
	vision_raycast.force_raycast_update()
	
	if vision_raycast.is_colliding():
		var collider = vision_raycast.get_collider()
		
		if collider.is_in_group("Player"):
			_on_player_detected(player, player_target_position, player_body_position)
		else:
			_on_player_obstructed(player, player_target_position)
	else:
		if current_state == CameraState.CHASE:
			_change_state(CameraState.SEARCH)

func _on_player_detected(player: Node3D, target_position: Vector3, body_position: Vector3) -> void:
	detected_player = player
	last_known_position_head = target_position
	
	if previous_player_position != Vector3.ZERO:
		player_velocity = (body_position - previous_player_position) / vision_check_interval
	previous_player_position = body_position
	
	if current_state != CameraState.CHASE:
		_change_state(CameraState.CHASE)
	
	detection_start_time = Time.get_ticks_msec() / 1000.0

func _on_player_obstructed(player: Node3D, position: Vector3) -> void:
	if current_state == CameraState.CHASE:
		obstacle_last_position = last_known_position_head
		_change_state(CameraState.WAITING_AT_OBSTACLE)

# ============================================================================
# STATE: DISABLED
# ============================================================================

func _on_enter_disabled() -> void:
	_disable_detection()
	detected_player = null

func _process_disabled(_delta: float) -> void:
	# Camera is off, do nothing
	pass

func _disable_detection() -> void:
	if area_3d:
		area_3d.monitoring = false

func _enable_detection() -> void:
	if area_3d:
		area_3d.monitoring = true

# ============================================================================
# STATE: IDLE
# ============================================================================

func _on_enter_idle() -> void:
	_enable_detection()
	idle_timer = 0.0
	detected_player = null

func _process_idle(delta: float) -> void:
	idle_timer += delta
	
	if idle_timer >= idle_boot_time:
		# Boot up complete, transition to appropriate state
		if static_mode_enabled:
			_change_state(CameraState.STATIC)
		else:
			_change_state(CameraState.PATROL)

# ============================================================================
# STATE: STATIC
# ============================================================================

func _on_enter_static() -> void:
	_enable_detection()
	current_rotation = static_rotation
	target_rotation = static_rotation

func _process_static(_delta: float) -> void:
	# Stay at fixed position
	target_rotation = static_rotation

# ============================================================================
# STATE: PATROL
# ============================================================================

func _on_enter_patrol() -> void:
	_enable_detection()
	detected_player = null
	player_velocity = Vector3.ZERO
	previous_player_position = Vector3.ZERO

func _process_patrol(delta: float) -> void:
	if is_waiting_at_patrol:
		patrol_wait_timer += delta
		if patrol_wait_timer >= patrol_wait_time:
			is_waiting_at_patrol = false
			patrol_wait_timer = 0.0
			_next_patrol_point()
		return
	
	var patrol_target = patrol_points[current_patrol_index]
	var rotation_delta = _calculate_rotation_delta(current_rotation, patrol_target)
	
	if rotation_delta.length() < 1.0:
		is_waiting_at_patrol = true
		current_rotation = patrol_target
	else:
		current_rotation = _rotate_towards(current_rotation, patrol_target, patrol_speed * delta)
	
	target_rotation = current_rotation

func _next_patrol_point() -> void:
	current_patrol_index = (current_patrol_index + 1) % patrol_points.size()

# ============================================================================
# STATE: CHASE
# ============================================================================

func _on_enter_chase() -> void:
	# Reset centering stabilization when entering chase
	last_centered_position = Vector3.ZERO

func _process_chase(delta: float) -> void:
	if detected_player == null:
		_change_state(CameraState.SEARCH)
		return

	# Keep current vertical rotation (Y-axis unchanged)
	var current_vertical = current_rotation.y

	# Compute direction to player (use body or head position as before)
	var direction_to_player = last_known_position_head - anchor_rotation.global_position

	# Get full rotation to player
	var full_target = _direction_to_rotation(direction_to_player)

	# BUT: only take the horizontal (X) component; keep vertical (Y) as-is
	var chase_target = Vector2(full_target.x, current_vertical)

	if _is_beyond_rotation_limits(chase_target):
		_change_state(CameraState.SEARCH)
		return

	var player_speed = player_velocity.length()
	var adaptive_speed = max(patrol_speed, player_speed * speed_multiplier)

	current_rotation = _rotate_towards(current_rotation, chase_target, adaptive_speed * delta)
	target_rotation = current_rotation

# ============================================================================
# STATE: WAITING AT OBSTACLE
# ============================================================================

func _on_enter_waiting() -> void:
	obstacle_wait_timer = 0.0
	var direction = obstacle_last_position - anchor_rotation.global_position
	current_rotation = _direction_to_rotation(direction)
	target_rotation = current_rotation

func _process_waiting(delta: float) -> void:
	obstacle_wait_timer += delta
	
	if obstacle_wait_timer >= lost_sight_wait_time:
		_change_state(CameraState.SEARCH)

# ============================================================================
# STATE: SEARCH
# ============================================================================

func _on_enter_search() -> void:
	search_timer = 0.0
	detected_player = null

func _process_search(delta: float) -> void:
	search_timer += delta
	
	if search_timer >= search_duration:
		if static_mode_enabled:
			_change_state(CameraState.STATIC)
		else:
			_change_state(CameraState.PATROL)
		return
	
	var noise_time = (search_timer + search_time_offset) * 0.5
	var noise_x = search_noise.get_noise_1d(noise_time * 100.0)
	var noise_y = search_noise.get_noise_1d(noise_time * 100.0 + 500.0)
	
	# Use centered position for search as well
	var centered_last_pos = _calculate_centered_target_position(last_known_position_head)
	var direction_to_last = centered_last_pos - anchor_rotation.global_position
	var base_rotation = _direction_to_rotation(direction_to_last)
	
	var search_offset = Vector2(
		noise_x * max_rotation_y * search_randomness,
		noise_y * max_rotation_x * search_randomness
	)
	
	var search_target = base_rotation + search_offset
	search_target = _clamp_rotation(search_target)
	
	current_rotation = _rotate_towards(current_rotation, search_target, search_speed * delta)
	target_rotation = current_rotation

# ============================================================================
# ROTATION UTILITIES
# ============================================================================

func _apply_rotation(rotation: Vector2) -> void:
	anchor_rotation.rotation_degrees = Vector3(rotation.y, rotation.x, 0)

func _apply_smooth_rotation(delta: float) -> void:
	var smooth_factor = clamp(transition_smoothing * 10.0 * delta, 0.0, 1.0)
	smooth_rotation = smooth_rotation.lerp(target_rotation, smooth_factor)
	_apply_rotation(smooth_rotation)

func _calculate_rotation_delta(from: Vector2, to: Vector2) -> Vector2:
	var delta = to - from
	delta.x = fposmod(delta.x + 180.0, 360.0) - 180.0
	delta.y = fposmod(delta.y + 180.0, 360.0) - 180.0
	return delta

func _rotate_towards(from: Vector2, to: Vector2, max_delta: float) -> Vector2:
	var delta = _calculate_rotation_delta(from, to)
	var distance = delta.length()
	
	if distance <= max_delta:
		return to
	
	var ratio = max_delta / distance
	return from + delta * ratio

func _direction_to_rotation(direction: Vector3) -> Vector2:
	var flat_dir = Vector2(direction.x, direction.z).normalized()
	var y_rotation = rad_to_deg(atan2(flat_dir.x, flat_dir.y))
	
	var horizontal_distance = flat_dir.length()
	var x_rotation = rad_to_deg(atan2(-direction.y, horizontal_distance))
	
	return Vector2(y_rotation, x_rotation)

func _clamp_rotation(rotation: Vector2) -> Vector2:
	return Vector2(
		clamp(rotation.x, -max_rotation_y, max_rotation_y),
		clamp(rotation.y, -max_rotation_x, max_rotation_x)
	)

func _is_beyond_rotation_limits(rotation: Vector2) -> bool:
	return abs(rotation.x) > max_rotation_y or abs(rotation.y) > max_rotation_x

# ============================================================================
# TARGET CENTERING UTILITIES
# ============================================================================

func _calculate_centered_target_position(target_position: Vector3) -> Vector3:
	"""
	Calculates an offset target position to center the player in the camera's view.
	This compensates for Area3D edge detection causing off-center tracking.
	Includes oscillation dampening to prevent up/down loops.
	"""
	if not enable_centering_offset:
		last_centered_position = target_position
		return target_position
	
	var centered_pos = target_position
	var direction_to_target = target_position - anchor_rotation.global_position
	var distance = direction_to_target.length()
	
	if distance < 0.1:  # Avoid division by zero
		last_centered_position = target_position
		return target_position
	
	# Apply manual offsets first
	centered_pos.y += vertical_offset
	
	# Auto-calculate offset based on FOV and distance
	if auto_calculate_offset:
		# Get local direction to understand target position relative to camera
		var local_direction = anchor_rotation.to_local(target_position)
		
		# Calculate vertical angle (pitch) - positive = looking down, negative = looking up
		var horizontal_dist = Vector2(local_direction.x, local_direction.z).length()
		var vertical_angle = rad_to_deg(atan2(-local_direction.y, horizontal_dist))
		
		# Calculate how far off-center horizontally
		var cone_radius_at_distance = fov_radius * (distance / vision_distance)
		var lateral_offset_factor = 0.0
		if cone_radius_at_distance > 0.1:
			lateral_offset_factor = clamp(horizontal_dist / cone_radius_at_distance, 0.0, 1.0)
		
		# Determine relative position more accurately
		# local_direction.y: negative = above camera, positive = below camera
		var target_is_above = local_direction.y < -0.3  # Target significantly above
		var target_is_below = local_direction.y > 0.3   # Target significantly below
		var target_is_level = abs(local_direction.y) <= 0.3  # Roughly same height
		
		# Only apply correction when target is off-center
		if lateral_offset_factor > 0.5 or not target_is_level:
			var edge_factor = clamp((lateral_offset_factor - 0.5) / 0.5, 0.0, 1.0)
			
			# Reduce correction at extreme angles to prevent oscillation
			var angle_reduction = 1.0
			if abs(vertical_angle) > 35.0:
				angle_reduction = clamp(1.0 - (abs(vertical_angle) - 35.0) / 25.0, 0.2, 1.0)
			
			var adjusted_strength = centering_strength * edge_factor * angle_reduction
			
			# CRITICAL FIX: When target is ABOVE camera (negative Y in local space)
			# Camera needs to look DOWN less / UP more to see center of body
			# So we SUBTRACT from Y to aim lower on the target
			if target_is_above:
				# Target above: aim at body center, not head
				# Subtracting Y makes us look at a lower point on the player
				var correction = distance * adjusted_strength * 0.4
				centered_pos.y -= correction  # Look lower on player when they're above
			
			# When target is BELOW camera (positive Y in local space)
			# Camera needs to look UP less / DOWN more to see center
			# So we ADD to Y to aim higher on the target
			elif target_is_below:
				# Target below: aim at body center, not feet
				# Adding Y makes us look at a higher point on the player
				var correction = distance * adjusted_strength * 0.4
				centered_pos.y += correction  # Look higher on player when they're below
			
			# Target at same level - minimal adjustment
			elif lateral_offset_factor > 0.6:
				var minor_correction = cone_radius_at_distance * adjusted_strength * 0.15
				# Adjust toward center of cone
				if local_direction.y < 0:
					centered_pos.y -= minor_correction
				else:
					centered_pos.y += minor_correction
	
	# Apply horizontal offset in world space
	if abs(horizontal_offset) > 0.01:
		var right_vector = anchor_rotation.global_transform.basis.x
		centered_pos += right_vector * horizontal_offset
	
	# Apply oscillation dampening using velocity smoothing
	if oscillation_dampening > 0.01 and last_centered_position != Vector3.ZERO:
		var position_delta = centered_pos - last_centered_position
		
		# Dampen rapid changes in Y direction (main source of oscillation)
		var dampen_factor = clamp(1.0 / (1.0 + oscillation_dampening), 0.1, 0.8)
		
		# Heavy dampening on Y axis
		var smoothed_y_change = lerp(0.0, position_delta.y, dampen_factor)
		centered_pos.y = last_centered_position.y + smoothed_y_change
		
		# Light dampening on horizontal movement
		centered_pos.x = lerp(last_centered_position.x, centered_pos.x, 0.7)
		centered_pos.z = lerp(last_centered_position.z, centered_pos.z, 0.7)
	
	last_centered_position = centered_pos
	return centered_pos

# ============================================================================
# VISUAL FEEDBACK
# ============================================================================

func _update_raycast_color(color: Color) -> void:
	if vision_raycast:
		vision_raycast.debug_shape_custom_color = color

# ============================================================================
# PUBLIC API
# ============================================================================

## Power control
func power_on() -> void:
	is_powered_on = true

func power_off() -> void:
	is_powered_on = false

func toggle_power() -> void:
	is_powered_on = not is_powered_on

## Static mode control
func enable_static_mode(rotation: Vector2 = static_rotation) -> void:
	static_mode_enabled = true
	static_rotation = rotation
	if current_state != CameraState.DISABLED:
		_change_state(CameraState.STATIC)

func disable_static_mode() -> void:
	static_mode_enabled = false
	if current_state == CameraState.STATIC:
		_change_state(CameraState.PATROL)

func set_static_rotation_manual(rotation: Vector2) -> void:
	static_rotation = rotation
	if current_state == CameraState.STATIC:
		current_rotation = rotation
		target_rotation = rotation

## Offset control for fine-tuning
func set_vertical_offset(offset: float) -> void:
	vertical_offset = offset

func set_horizontal_offset(offset: float) -> void:
	horizontal_offset = offset

func set_centering_offsets(vertical: float, horizontal: float) -> void:
	vertical_offset = vertical
	horizontal_offset = horizontal

func toggle_auto_centering(enabled: bool) -> void:
	auto_calculate_offset = enabled

func toggle_centering_offset(enabled: bool) -> void:
	enable_centering_offset = enabled

func set_centering_strength(strength: float) -> void:
	centering_strength = clamp(strength, 0.0, 1.0)

func set_oscillation_dampening(dampen: float) -> void:
	oscillation_dampening = clamp(dampen, 0.0, 5.0)

## Detection queries
func is_player_detected() -> bool:
	return current_state == CameraState.CHASE

func get_detected_player() -> Node3D:
	return detected_player

func get_player_position() -> Vector3:
	return last_known_position_head

func get_camera_state() -> CameraState:
	return current_state

func get_state_name() -> String:
	return CameraState.keys()[current_state]

func get_detection_info() -> Dictionary:
	return {
		"is_detected": is_player_detected(),
		"player_node": detected_player,
		"player_position": last_known_position_head,
		"state": get_state_name(),
		"detection_time": detection_start_time,
		"player_velocity": player_velocity,
		"camera_rotation": current_rotation,
		"is_powered": is_powered_on,
		"static_mode": static_mode_enabled
	}

## Patrol control
func add_patrol_point(rotation: Vector2) -> void:
	patrol_points.append(rotation)

func clear_patrol_points() -> void:
	patrol_points.clear()
	current_patrol_index = 0

func set_patrol_points(points: Array[Vector2]) -> void:
	patrol_points = points
	current_patrol_index = 0
	if current_state == CameraState.PATROL:
		_set_initial_state()

## Switches from patrol (or any active state) to static mode,
## freezing the camera at its current orientation.
func freeze_as_static() -> void:
	if current_state == CameraState.DISABLED:
		return  # Can't freeze a disabled camera
	
	# Capture the current effective rotation
	# Use `smooth_rotation` if smooth transitions are on, else `current_rotation`
	var current_rot = smooth_rotation if use_smooth_transitions else current_rotation
	
	# Enable static mode and set the rotation
	static_mode_enabled = true
	static_rotation = current_rot
	
	# Force immediate update of static target
	if current_state != CameraState.STATIC:
		_change_state(CameraState.STATIC)
	else:
		# If already static, just update the target
		target_rotation = static_rotation
		if not use_smooth_transitions:
			smooth_rotation = static_rotation
			_apply_rotation(smooth_rotation)
