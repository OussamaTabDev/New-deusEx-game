# CameraController.gd
class_name CameraController
extends Node3D

@export var player: CharacterBody3D
@export var CAMERA_CONTROLLER: Camera3D
@export var MOUSE_SENSITIVITY: float = 0.5
@export var CONTROLLER_SENSITIVITY: float = 1.0
@export var TILT_LOWER_LIMIT := deg_to_rad(-90.0)
@export var TILT_UPPER_LIMIT := deg_to_rad(90.0)

# Head bob variables
@export var BOB_FREQ: float = 2.4
@export var BOB_AMP: float = 0.08
var t_bob: float = 0.0

# FOV variables
@export var BASE_FOV: float = 75.0
@export var FOV_CHANGE: float = 1.5

# Leaning variables
@export var LEAN_AMOUNT: float = 0.3
@export var LEAN_SPEED: float = 8.0
@export var LEAN_ROLL_ANGLE: float = deg_to_rad(5.0)
@export var lean_shape_cast_left: ShapeCast3D
@export var lean_shape_cast_right: ShapeCast3D
@export var resurrected_states_on_leaning := ["SprintingState", "SlidingState", "JumpingState", "FallingState", "ClimbState", "DashState"]
@export var resurrected_states_on_using := ["ClimbState"]

# Camera shake variables
@export var SHAKE_INTENSITY_IDLE: float = 0.05
@export var SHAKE_FREQUENCY_IDLE: float = 6.0
@export var SHAKE_FADE_SPEED: float = 5.0
@export var SHAKE_RANDOMNESS: float = 0.3

# Fall kick variables
@export_category("Fall State Parameters")
@export var enable_fall_kick: bool = true
@export var fall_time: float = 0.3
@export var fall_kick_velocity: float

var _fall_timer: float = 0.0
var _fall_value: float = 0.0

# Damage kick variables
@export_category("Damage Kick Parameters")
@export var enable_damage_kick: bool = true
@export var damage_kick_intensity: float = 3.0
@export var damage_kick_duration: float = 0.4
@export var damage_kick_shake_strength: float = 0.5
@export var damage_kick_roll_amount: float = deg_to_rad(15.0)  # Roll angle for side hits

var _damage_kick_timer: float = 0.0
var _damage_kick_direction: Vector3 = Vector3.ZERO
var _damage_kick_strength: float = 0.0

# Climb-specific damage tilt (downward dip on side hits during climb)
var _climb_damage_tilt: float = 0.0
var _climb_damage_tilt_timer: float = 0.0
const CLIMB_DAMAGE_TILT_AMOUNT := deg_to_rad(4.0)
const CLIMB_DAMAGE_TILT_DURATION := 0.3

# Climb animation variables
@export_category("Climb Animation Parameters")
@export var climb_sway_amount: float = 0.15
@export var climb_bob_speed: float = 1.5
@export var climb_fov_reduction: float = 5.0

var _is_climbing: bool = false
var _is_crouching: bool = false
var _climb_animation_time: float = 0.0

# Zoom variables
@export_category("Zoom Parameters")
@export var enable_zoom: bool = true
@export var zoom_fov: float = 40.0
@export var zoom_speed: float = 10.0
@export var zoom_sensitivity_multiplier: float = 0.3

var _is_zooming: bool = false
var _target_fov: float = 75.0

# Camera shake state
var shake_strength: float = 0.0
var shake_time: float = 0.0

# Current lean/roll state
var current_roll: float = 0.0
var current_lean: float = 0.0

# Mouse input accumulators
var _rotation_input: float = 0.0
var _tilt_input: float = 0.0

# Camera rotation state
var _mouse_rotation: Vector3 = Vector3.ZERO


func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var sensitivity_modifier = zoom_sensitivity_multiplier if _is_zooming else 1.0
		_rotation_input = -event.relative.x * MOUSE_SENSITIVITY * sensitivity_modifier
		_tilt_input = -event.relative.y * MOUSE_SENSITIVITY * sensitivity_modifier


func _input(event):
	if event.is_action_pressed("exit"):
		get_tree().quit()
	
	# Zoom input
	if enable_zoom:
		if event.is_action_pressed("zoom"):
			_is_zooming = true
		elif event.is_action_released("zoom"):
			_is_zooming = false


func _process(delta: float):
	# Test damage kick (bind "test" to a key in InputMap)
	if Input.is_action_just_pressed("test"):
		add_damage_kick(Vector3(20, 2, 5), 0.5)
	
	_update_camera(delta)


func _update_camera(delta: float):
	var yaw_input: float = 0.0
	var pitch_input: float = 0.0
	if not climbing():
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			yaw_input = _rotation_input
			pitch_input = _tilt_input
		
		if is_controller_connected():
			var look_x = Input.get_axis("look_left", "look_right")
			var look_y = Input.get_axis("look_up", "look_down")
			var sensitivity_modifier = zoom_sensitivity_multiplier if _is_zooming else 1.0
			yaw_input = -look_x * CONTROLLER_SENSITIVITY * sensitivity_modifier
			pitch_input = -look_y * CONTROLLER_SENSITIVITY * sensitivity_modifier

	_mouse_rotation.y += yaw_input * delta
	_mouse_rotation.x += pitch_input * delta
	_mouse_rotation.x = clamp(_mouse_rotation.x, TILT_LOWER_LIMIT, TILT_UPPER_LIMIT)

	# Head bob
	t_bob += delta * player.velocity.length() * float(player.is_on_floor())
	var bob_offset: Vector3 = _headbob(t_bob)
	
	# === Leaning & Roll Logic (DISABLED during climb) ===
	var target_lean: float = 0.0
	var target_roll: float = 0.0

	if not _is_climbing:
		if player.state_machine.get_current_state_name() not in resurrected_states_on_leaning:
			if is_leaning_left():
				if not lean_shape_cast_left.is_colliding():
					target_lean = -LEAN_AMOUNT
				target_roll = LEAN_ROLL_ANGLE
			elif is_leaning_right():
				if not lean_shape_cast_right.is_colliding():
					target_lean = LEAN_AMOUNT
				target_roll = -LEAN_ROLL_ANGLE

		# Auto strafe tilt
		var is_manually_leaning = is_leaning_left() or is_leaning_right()
		if player.is_on_floor() and not is_manually_leaning:
			var move_dir = Input.get_axis("move_left", "move_right")
			if move_dir != 0.0:
				target_roll = -move_dir * LEAN_ROLL_ANGLE * 0.7

		# Dash roll
		if player.state_machine.get_current_state_name() == "DashState":
			var dash_roll_intensity = deg_to_rad(8.0)
			target_roll = -sign(player.velocity.x) * dash_roll_intensity

	# Smooth lean/roll (will go to 0 during climb)
	current_lean = lerp(current_lean, target_lean, delta * LEAN_SPEED)
	current_roll = lerp(current_roll, target_roll, delta * LEAN_SPEED)

	var lean_offset := Vector3(current_lean, 0.0, 0.0)

	# === Fall Kick Integration ===
	var fall_kick_offset = Vector3.ZERO
	var fall_kick_tilt = 0.0

	if enable_fall_kick and _fall_timer > 0.0:
		_fall_timer -= delta
		var fall_ratio = _fall_timer / fall_time
		var fall_kick_amount = fall_ratio * _fall_value

		fall_kick_offset.y = -fall_kick_amount * 0.1
		fall_kick_tilt = -fall_kick_amount

	# === Damage Kick Integration ===
	var damage_kick_offset = Vector3.ZERO
	var damage_kick_rotation = 0.0
	var damage_kick_roll_amount_local = 0.0

	if enable_damage_kick and _damage_kick_timer > 0.0:
		_damage_kick_timer -= delta
		var damage_ratio = _damage_kick_timer / damage_kick_duration
		var intensity = damage_ratio * _damage_kick_strength
		
		damage_kick_offset = _damage_kick_direction * intensity * 0.2
		damage_kick_rotation = sin(damage_ratio * PI) * intensity * 0.5
		
		# Only apply roll if NOT climbing
		if not _is_climbing:
			damage_kick_roll_amount_local = sin(damage_ratio * PI) * intensity * damage_kick_roll_amount

		# During climb: side hit → trigger downward tilt (only if not active)
		if _is_climbing and abs(_damage_kick_direction.x) > 0.5:
			if _climb_damage_tilt_timer <= 0.0:
				_climb_damage_tilt = CLIMB_DAMAGE_TILT_AMOUNT
				_climb_damage_tilt_timer = CLIMB_DAMAGE_TILT_DURATION

	# === Climb-Specific Damage Tilt ===
	var climb_damage_tilt = 0.0
	if _climb_damage_tilt_timer > 0.0:
		_climb_damage_tilt_timer -= delta
		var tilt_ratio = _climb_damage_tilt_timer / CLIMB_DAMAGE_TILT_DURATION
		climb_damage_tilt = _climb_damage_tilt * tilt_ratio

	# === Climb Animation ===
	var climb_offset = Vector3.ZERO
	var climb_roll_offset = 0.0
	
	if _is_climbing:
		_climb_animation_time += delta * climb_bob_speed
		
		climb_offset.x = sin(_climb_animation_time * 0.8) * climb_sway_amount
		climb_offset.y = abs(sin(_climb_animation_time * 1.2)) * climb_sway_amount * 0.5
		climb_roll_offset = sin(_climb_animation_time * 0.6) * deg_to_rad(3.0)
		
		if _is_crouching:
			climb_offset.y -= 0.3

	# Combine all position offsets
	var total_offset = lean_offset + bob_offset + fall_kick_offset + damage_kick_offset + climb_offset

	# Apply rotations
	var player_rotation = Vector3(0.0, _mouse_rotation.y, 0.0)
	
	var final_camera_pitch = (
		_mouse_rotation.x + 
		fall_kick_tilt + 
		damage_kick_rotation - 
		climb_damage_tilt  # Downward dip during climb side hits
	)
	final_camera_pitch = clamp(final_camera_pitch, TILT_LOWER_LIMIT, TILT_UPPER_LIMIT)
	var camera_rotation = Vector3(final_camera_pitch, 0.0, 0.0)

	# Set transforms
	player.global_transform.basis = Basis.from_euler(player_rotation)
	CAMERA_CONTROLLER.transform.basis = Basis.from_euler(camera_rotation)

	# Roll: climb uses its own roll; damage/lean roll suppressed during climb
	var total_roll = current_roll + climb_roll_offset
	CAMERA_CONTROLLER.rotation.z = total_roll

	# Set camera position
	CAMERA_CONTROLLER.transform.origin = total_offset

	# === FOV (with Zoom and Climb) ===
	var is_dashing = player.state_machine.get_current_state_name() == "DashState"
	var speed = max(0.5, player.velocity.length())
	_target_fov = BASE_FOV + FOV_CHANGE * clamp(speed, 0.5, player.SPEED * 2)
	
	if is_dashing:
		_target_fov += 5.0
	
	if _is_climbing:
		_target_fov -= climb_fov_reduction
	
	if _is_zooming:
		_target_fov = zoom_fov
	
	CAMERA_CONTROLLER.fov = lerp(CAMERA_CONTROLLER.fov, _target_fov, delta * zoom_speed)

	# === Camera Shake ===
	var is_idle = (
		player.is_on_floor() and 
		player.velocity.length() < 0.1 and 
		player.state_machine.get_current_state_name() == "IdleState"
	)

	var shake_offset = Vector3.ZERO
	if is_idle:
		shake_strength = lerp(shake_strength, SHAKE_INTENSITY_IDLE, delta * 3.0)
		shake_offset = _camera_shake(delta, shake_strength, SHAKE_FREQUENCY_IDLE)
	else:
		shake_strength = lerp(shake_strength, 0.0, delta * SHAKE_FADE_SPEED)
		shake_offset = _camera_shake(delta, shake_strength, 12.0)

	CAMERA_CONTROLLER.transform.origin += shake_offset

	# Reset accumulators
	_rotation_input = 0.0
	_tilt_input = 0.0


func _headbob(time: float) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	return pos


func is_leaning() -> bool:
	return is_leaning_left() or is_leaning_right()


func is_leaning_left() -> bool:
	return Input.is_action_pressed("lean_left")


func is_leaning_right() -> bool:
	return Input.is_action_pressed("lean_right")


func trigger_dash_shake(strength: float = 0.3, duration: float = 0.15) -> void:
	shake_strength = strength
	shake_time = 0.0


func is_controller_connected() -> bool:
	return (
		Input.is_action_pressed("look_left") or 
		Input.is_action_pressed("look_right") or 
		Input.is_action_pressed("look_up") or 
		Input.is_action_pressed("look_down")
	)


func climbing() -> bool:
	return player.state_machine.get_current_state_name() in resurrected_states_on_using


func _camera_shake(delta: float, intensity: float, frequency: float) -> Vector3:
	if intensity <= 0.0:
		return Vector3.ZERO

	shake_time += delta * frequency
	var rand_x = (randf() - 0.5) * SHAKE_RANDOMNESS
	var rand_y = (randf() - 0.5) * SHAKE_RANDOMNESS
	var offset_x = sin(shake_time * 1.1 + rand_x) * intensity
	var offset_y = cos(shake_time * 1.3 + rand_y) * intensity
	return Vector3(offset_x, offset_y, 0.0)


# === PUBLIC API ===

func add_fall_kick(fall_strength_degrees: float):
	_fall_value = deg_to_rad(fall_strength_degrees)
	_fall_timer = fall_time


func add_damage_kick(direction: Vector3, strength: float = 0.5):
	if not enable_damage_kick:
		return
	
	var local_dir = player.global_transform.basis * direction.normalized()
	_damage_kick_direction = local_dir
	_damage_kick_strength = damage_kick_intensity * clamp(strength, 0.0, 2.0)
	_damage_kick_timer = damage_kick_duration
	
	# Add camera shake
	shake_strength = damage_kick_shake_strength * strength

	# Note: Climb-specific tilt is handled in _update_camera to avoid timing issues


func set_climb_active(active: bool):
	_is_climbing = active
	if active:
		_climb_animation_time = 0.0
		# Snap to clean state: no residual roll or lean
		current_roll = 0.0
		current_lean = 0.0


func set_crouching(crouching: bool):
	_is_crouching = crouching