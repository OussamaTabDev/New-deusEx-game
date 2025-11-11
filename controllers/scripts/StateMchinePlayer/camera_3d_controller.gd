# CameraController.gd
class_name CameraController
extends Node3D

@export var player: CharacterBody3D
@export var CAMERA_CONTROLLER: Camera3D
@export var MOUSE_SENSITIVITY: float = 0.5
@export var CONTROLLER_SENSITIVITY: float = 1.0
@export var TILT_LOWER_LIMIT := deg_to_rad(-90.0)
@export var TILT_UPPER_LIMIT := deg_to_rad(90.0)

# Eye height (player's camera height)
@export var EYE_HEIGHT: float = 1.6

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

# Damage kick (impulse-based, always resets)
@export_category("Damage Kick Parameters")
@export var enable_damage_kick: bool = true
@export var damage_kick_intensity: float = 0.15
@export var damage_kick_tilt: float = 6.0
@export var damage_kick_roll: float = deg_to_rad(8.0)

var _damage_kick_x: float = 0.0
var _damage_kick_y: float = 0.0
var _damage_kick_z: float = 0.0
var _damage_tilt_impulse: float = 0.0
var _damage_roll_impulse: float = 0.0

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
		_rotation_input = -event.relative.x * MOUSE_SENSITIVITY
		_tilt_input = -event.relative.y * MOUSE_SENSITIVITY


func _input(event):
	if event.is_action_pressed("exit"):
		get_tree().quit()


func _process(delta: float):
	if Input.is_action_just_pressed("test"):
		add_damage_kick(Vector3(20,2,5))
	_update_camera(delta)


func _update_camera(delta: float):
	# Decay damage impulses every frame (exponential decay)
	if enable_damage_kick:
		var decay = pow(0.01, delta)  # ~99% decay per second; adjust 0.01 to tune duration
		_damage_kick_x *= decay
		_damage_kick_y *= decay
		_damage_kick_z *= decay
		_damage_tilt_impulse *= decay
		_damage_roll_impulse *= decay

	var yaw_input: float = 0.0
	var pitch_input: float = 0.0
	if not climbing():
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			yaw_input = _rotation_input
			pitch_input = _tilt_input
		
		if is_controller_connected():
			var look_x = Input.get_axis("look_left", "look_right")
			var look_y = Input.get_axis("look_up", "look_down")
			yaw_input = -look_x * CONTROLLER_SENSITIVITY
			pitch_input = -look_y * CONTROLLER_SENSITIVITY

	_mouse_rotation.y += yaw_input * delta
	_mouse_rotation.x += pitch_input * delta
	_mouse_rotation.x = clamp(_mouse_rotation.x, TILT_LOWER_LIMIT, TILT_UPPER_LIMIT)

	# Head bob
	t_bob += delta * player.velocity.length() * float(player.is_on_floor())
	var bob_offset: Vector3 = _headbob(t_bob)
	
	# Leaning logic
	var target_lean: float = 0.0
	var target_roll: float = 0.0

	if player.state_machine.get_current_state_name() not in resurrected_states_on_leaning:
		if is_leaning_left():
			if not lean_shape_cast_left.is_colliding():
				target_lean = -LEAN_AMOUNT
			target_roll = LEAN_ROLL_ANGLE
		elif is_leaning_right():
			if not lean_shape_cast_right.is_colliding():
				target_lean = LEAN_AMOUNT
			target_roll = -LEAN_ROLL_ANGLE

	var is_manually_leaning = is_leaning_left() or is_leaning_right()
	if player.is_on_floor() and not is_manually_leaning:
		var move_dir = Input.get_axis("move_left", "move_right")
		if move_dir != 0.0:
			target_roll = -move_dir * LEAN_ROLL_ANGLE * 0.7

	if player.state_machine.get_current_state_name() == "DashState":
		var dash_roll_intensity = deg_to_rad(8.0)
		target_roll = -sign(player.velocity.x) * dash_roll_intensity

	current_lean = lerp(current_lean, target_lean, delta * LEAN_SPEED)
	current_roll = lerp(current_roll, target_roll, delta * LEAN_SPEED)

	# Fall kick
	var fall_kick_offset = Vector3.ZERO
	var fall_kick_tilt = 0.0
	if enable_fall_kick and _fall_timer > 0.0:
		_fall_timer -= delta
		var fall_ratio = _fall_timer / fall_time
		var fall_kick_amount = fall_ratio * _fall_value
		fall_kick_offset.y = -fall_kick_amount * 0.1
		fall_kick_tilt = -fall_kick_amount

	# === Final Camera Placement ===
	var base_position = player.global_transform.origin + Vector3.UP * EYE_HEIGHT
	var total_local_offset = Vector3(current_lean, 0.0, 0.0) + bob_offset + fall_kick_offset + Vector3(_damage_kick_x, _damage_kick_y, _damage_kick_z)
	var world_offset = player.global_transform.basis * total_local_offset
	var final_position = base_position + world_offset

	# Rotation
	var player_rotation = Vector3(0.0, _mouse_rotation.y, 0.0)
	var final_camera_pitch = _mouse_rotation.x + fall_kick_tilt + _damage_tilt_impulse
	final_camera_pitch = clamp(final_camera_pitch, TILT_LOWER_LIMIT, TILT_UPPER_LIMIT)
	var camera_rotation = Vector3(final_camera_pitch, 0.0, 0.0)

	# Apply to player and camera
	player.global_transform.basis = Basis.from_euler(player_rotation)
	CAMERA_CONTROLLER.global_transform.origin = final_position
	CAMERA_CONTROLLER.transform.basis = Basis.from_euler(camera_rotation)
	CAMERA_CONTROLLER.rotation.z = current_roll + _damage_roll_impulse

	# FOV
	var is_dashing = player.state_machine.get_current_state_name() == "DashState"
	var speed = max(0.5, player.velocity.length())
	var target_fov = BASE_FOV + FOV_CHANGE * clamp(speed, 0.5, player.SPEED * 2)
	if is_dashing:
		target_fov += 5.0
	CAMERA_CONTROLLER.fov = lerp(CAMERA_CONTROLLER.fov, target_fov, delta * 8.0)

	# Camera shake (applied in camera-local space)
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

	# Add shake in local camera space (X/Y screen space)
	CAMERA_CONTROLLER.transform.origin += shake_offset

	# Reset mouse accumulators
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


func add_fall_kick(fall_strength_degrees: float):
	_fall_value = deg_to_rad(fall_strength_degrees)
	_fall_timer = fall_time


func add_damage_kick(damage_source: Vector3) -> void:
	if not enable_damage_kick or player == null:
		return

	var to_source = damage_source - player.global_transform.origin
	to_source.y = 0.0
	if to_source.length() < 0.01:
		to_source = -player.global_transform.basis.z  # default direction: front
	to_source = to_source.normalized()

	var local_dir = player.global_transform.basis.inverse() * to_source

	var abs_x = abs(local_dir.x)
	var abs_z = abs(local_dir.z)
	var kick = damage_kick_intensity
	var tilt_rad = deg_to_rad(damage_kick_tilt)

	if abs_z >= abs_x:
		if local_dir.z < 0:  # front
			_damage_kick_x = 0.0
			_damage_kick_y = kick * 0.5
			_damage_kick_z = -kick
			_damage_tilt_impulse = tilt_rad
			_damage_roll_impulse = 0.0
		else:  # back
			_damage_kick_x = 0.0
			_damage_kick_y = kick * 0.3
			_damage_kick_z = kick * 0.7
			_damage_tilt_impulse = tilt_rad * 0.6
			_damage_roll_impulse = 0.0
	else:
		if local_dir.x > 0:  # right side
			_damage_kick_x = -kick * 0.8
			_damage_kick_y = kick * 0.4
			_damage_kick_z = -kick * 0.3
			_damage_tilt_impulse = tilt_rad * 0.8
			_damage_roll_impulse = -damage_kick_roll
		else:  # left side
			_damage_kick_x = kick * 0.8
			_damage_kick_y = kick * 0.4
			_damage_kick_z = -kick * 0.3
			_damage_tilt_impulse = tilt_rad * 0.8
			_damage_roll_impulse = damage_kick_roll