# CameraController.gd
class_name CameraController
extends Node3D

@export_category("Camera References")
@export_group("Node References")
@export var player: CharacterBody3D
@export var CAMERA_CONTROLLER: Camera3D

# ============================================================
@export_category("Input Settings")
@export_group("Sensitivity")
@export var MOUSE_SENSITIVITY: float = 0.5
@export var CONTROLLER_SENSITIVITY: float = 1.0

# ============================================================
@export_category("Camera Rotation Limits")
@export_group("Tilt")
@export var TILT_LOWER_LIMIT := deg_to_rad(-90.0)
@export var TILT_UPPER_LIMIT := deg_to_rad(90.0)

# ============================================================
@export_category("Camera Movement Effects")

@export_group("Head Bob")
@export var BOB_FREQ: float = 2.4
@export var BOV_AMP: float = 0.08  # Typo preserved as in your original
var t_bob: float = 0.0

@export_group("Field of View")
@export var BASE_FOV: float = 75.0
@export var FOV_CHANGE: float = 1.5

@export_group("Zoom")
@export var zoom_fov: float = 40.0
@export var zoom_sensitivity_multiplier: float = 0.4
@export var zoom_toggle: bool = false  # true = toggle, false = hold
var is_zoomed: bool = false

@export_group("Leaning")
@export var LEAN_AMOUNT: float = 0.3
@export var LEAN_SPEED: float = 8.0
@export var LEAN_ROLL_ANGLE: float = deg_to_rad(5.0)
@export var lean_shape_cast_left: ShapeCast3D
@export var lean_shape_cast_right: ShapeCast3D

@export_group("Leaning Restrictions")
@export var resurrected_states_on_leaning := [
	"SprintingState", "SlidingState", "JumpingState",
	"FallingState", "ClimbState", "DashState"
]
@export var resurrected_states_on_using := ["ClimbState"]

# ============================================================
@export_category("Camera Shake")

@export_group("Shake Parameters")
@export var SHAKE_INTENSITY_IDLE: float = 0.05
@export var SHAKE_FREQUENCY_IDLE: float = 6.0
@export var SHAKE_FADE_SPEED: float = 5.0
@export var SHAKE_RANDOMNESS: float = 0.3

# ============================================================
@export_category("Camera Kick Effects")

@export_group("Fall Kick")
@export var enable_fall_kick: bool = true
@export var fall_time: float = 0.3
@export var fall_kick_velocity: float

@export_group("Damage Kick")
@export var DAMAGE_KICK_DURATION: float = 0.3
@export var DAMAGE_KICK_BACK: float = 0.15
@export var DAMAGE_KICK_UP: float = 0.1
@export var DAMAGE_KICK_PITCH: float = 8.0
@export var DAMAGE_KICK_ROLL: float = 5.0  # New: roll intensity in degrees

# Internal state
var _fall_timer: float = 0.0
var _fall_value: float = 0.0

var _damage_kick_timer: float = 0.0
var _damage_kick_offset: Vector3 = Vector3.ZERO
var _damage_kick_tilt: float = 0.0
var _damage_roll: float = 0.0  # New: store roll separately

# Camera shake state
var shake_strength: float = 0.0
var shake_time: float = 0.0

# Current lean/roll state
var current_roll: float = 0.0
var current_lean: float = 0.0

# Mouse input accumulators (raw scaled by MOUSE_SENSITIVITY)
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
	# Handle zoom input
	if Input.is_action_pressed("zoom"):
		if zoom_toggle:
			if Input.is_action_just_pressed("zoom"):
				is_zoomed = not is_zoomed
		else:
			is_zoomed = true
	else:
		if not zoom_toggle:
			is_zoomed = false

	if Input.is_action_pressed("test"):
		add_damage_kick(Vector3(20,2,3))
		
	_update_camera(delta)


func _update_camera(delta: float):
	var yaw_input: float = 0.0
	var pitch_input: float = 0.0
	var is_climbing = climbing()

	if not is_climbing:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			var zoom_factor = zoom_sensitivity_multiplier if is_zoomed else 1.0
			yaw_input = _rotation_input * zoom_factor
			pitch_input = _tilt_input * zoom_factor
		
		if is_controller_connected():
			var look_x = Input.get_axis("look_left", "look_right")
			var look_y = Input.get_axis("look_up", "look_down")
			yaw_input += -look_x * CONTROLLER_SENSITIVITY
			pitch_input += -look_y * CONTROLLER_SENSITIVITY

	_mouse_rotation.y += yaw_input * delta
	_mouse_rotation.x += pitch_input * delta
	_mouse_rotation.x = clamp(_mouse_rotation.x, TILT_LOWER_LIMIT, TILT_UPPER_LIMIT)

	# Head bob (disabled during climb)
	var bob_speed_scale = float(player.is_on_floor() and not is_climbing)
	t_bob += delta * player.velocity.length() * bob_speed_scale
	var bob_offset: Vector3 = _headbob(t_bob)
	
	# Leaning
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

	current_lean = lerp(current_lean, target_lean, delta * LEAN_SPEED)
	current_roll = lerp(current_roll, target_roll, delta * LEAN_SPEED)

	var lean_offset := Vector3(current_lean, 0.0, 0.0)

	# === Fall Kick ===
	var fall_kick_offset = Vector3.ZERO
	var fall_kick_tilt = 0.0
	if enable_fall_kick and _fall_timer > 0.0:
		_fall_timer -= delta
		var fall_ratio = _fall_timer / fall_time
		var fall_kick_amount = fall_ratio * _fall_value
		fall_kick_offset.y = -fall_kick_amount * 0.1
		fall_kick_tilt = -fall_kick_amount

	# === Damage Kick ===
	var damage_kick_offset = Vector3.ZERO
	var damage_kick_tilt = 0.0
	var damage_kick_roll = 0.0  # New: roll component

	if _damage_kick_timer > 0.0:
		_damage_kick_timer -= delta
		var ratio = _damage_kick_timer / DAMAGE_KICK_DURATION
		ratio = ratio * ratio  # smooth ease-out
		damage_kick_offset = _damage_kick_offset * ratio
		damage_kick_tilt = _damage_kick_tilt * ratio
		damage_kick_roll = _damage_roll * ratio

	# Combine all position offsets
	var total_offset = lean_offset + bob_offset + fall_kick_offset + damage_kick_offset

	# Apply rotations
	var player_rotation = Vector3(0.0, _mouse_rotation.y, 0.0)
	var final_camera_pitch = _mouse_rotation.x + fall_kick_tilt + damage_kick_tilt
	final_camera_pitch = clamp(final_camera_pitch, TILT_LOWER_LIMIT, TILT_UPPER_LIMIT)

	# Combine base roll with damage roll
	var total_roll = current_roll + damage_kick_roll

	# Set transforms
	player.global_transform.basis = Basis.from_euler(player_rotation)
	CAMERA_CONTROLLER.transform.basis = Basis.from_euler(Vector3(final_camera_pitch, 0.0, 0.0))
	CAMERA_CONTROLLER.rotation.z = total_roll
	CAMERA_CONTROLLER.transform.origin = total_offset

	# FOV with zoom
	var is_dashing = player.state_machine.get_current_state_name() == "DashState"
	var speed = max(0.5, player.velocity.length())
	var base_fov = lerp(BASE_FOV, zoom_fov, float(is_zoomed))
	var target_fov = base_fov + FOV_CHANGE * clamp(speed, 0.5, player.SPEED * 2)
	if is_dashing:
		target_fov += 5.0
	CAMERA_CONTROLLER.fov = lerp(CAMERA_CONTROLLER.fov, target_fov, delta * 8.0)

	# Camera shake
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

	# Reset input accumulators
	_rotation_input = 0.0
	_tilt_input = 0.0


func _headbob(time: float) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOV_AMP  # Using BOV_AMP as in your code
	pos.x = cos(time * BOB_FREQ / 2) * BOV_AMP
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
	return player and player.state_machine and (player.state_machine.get_current_state_name() in resurrected_states_on_using)


func _camera_shake(delta: float, intensity: float, frequency: float) -> Vector3:
	if intensity <= 0.0:
		return Vector3.ZERO

	shake_time += delta * frequency
	var rand_x = (randf() - 0.5) * SHAKE_RANDOMNESS
	var rand_y = (randf() - 0.5) * SHAKE_RANDOMNESS
	var offset_x = sin(shake_time * 1.1 + rand_x) * intensity
	var offset_y = cos(shake_time * 1.3 + rand_y) * intensity
	return Vector3(offset_x, offset_y, 0.0)


# Call when player takes damage
func add_damage_kick(source_position: Vector3):
	if not player:
		return

	var hit_dir = (player.global_position - source_position).normalized()
	var forward = player.global_transform.basis.z  # camera/player forward
	var right = player.global_transform.basis.x    # camera right

	var forward_dot = hit_dir.dot(forward)
	var right_dot = hit_dir.dot(right)

	# Pitch: positive (up) if hit from front, negative (down) if from behind
	_damage_kick_tilt = deg_to_rad(DAMAGE_KICK_PITCH) * forward_dot

	# Roll: positive (right roll) if hit from left, negative (left roll) if from right
	_damage_roll = deg_to_rad(DAMAGE_KICK_ROLL) * right_dot

	# Recoil position: backward + upward
	var local_back = -DAMAGE_KICK_BACK * Vector3(0, 0, 1)
	var world_back = player.global_transform.basis * local_back
	var upward = Vector3(0, DAMAGE_KICK_UP, 0)

	_damage_kick_offset = world_back + upward
	_damage_kick_timer = DAMAGE_KICK_DURATION


# Call when player lands hard
func add_fall_kick(fall_strength_degrees: float):
	_fall_value = deg_to_rad(fall_strength_degrees)
	_fall_timer = fall_time