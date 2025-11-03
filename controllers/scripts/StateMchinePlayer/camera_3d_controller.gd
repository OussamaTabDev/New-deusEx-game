class_name CameraController
extends Node3D

@export var player: CharacterBody3D
@export var CAMERA_CONTROLLER: Camera3D
@export var MOUSE_SENSITIVITY: float = 0.5
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
@export var LEAN_ROLL_ANGLE: float = deg_to_rad(5.0)  # Subtle camera tilt
@export var lean_shape_cast_left: ShapeCast3D
@export var lean_shape_cast_right: ShapeCast3D
@export var resurrected_states := ["SprintingState", "SlidingState", "JumpingState", "FallingState"]

var current_roll: float = 0.0
var current_lean: float = 0.0

# Mouse input
var _mouse_input: bool = false
var _rotation_input: float = 0.0
var _tilt_input: float = 0.0
var _mouse_rotation: Vector3
var _player_rotation: Vector3
var _camera_rotation: Vector3

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	_mouse_input = event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	if _mouse_input:
		_rotation_input = -event.relative.x * MOUSE_SENSITIVITY
		_tilt_input = -event.relative.y * MOUSE_SENSITIVITY

func _input(event):
	if event.is_action_pressed("exit"):
		get_tree().quit()

func _process(delta: float):
	_update_camera(delta)

func _update_camera(delta):
	# Mouse look
	_mouse_rotation.x += _tilt_input * delta
	_mouse_rotation.x = clamp(_mouse_rotation.x, TILT_LOWER_LIMIT, TILT_UPPER_LIMIT)
	_mouse_rotation.y += _rotation_input * delta

	_player_rotation = Vector3(0.0, _mouse_rotation.y, 0.0)
	_camera_rotation = Vector3(_mouse_rotation.x, 0.0, 0.0)

	CAMERA_CONTROLLER.transform.basis = Basis.from_euler(_camera_rotation)
	player.global_transform.basis = Basis.from_euler(_player_rotation)
	CAMERA_CONTROLLER.rotation.z = 0.0

	# Head bob
	t_bob += delta * player.velocity.length() * float(player.is_on_floor())
	var bob_offset: Vector3 = _headbob(t_bob)
	
	# Leaning + Strafe tilt
	set_lean(delta, bob_offset)
	
	# FOV
	var velocity_clamped = clamp(player.velocity.length(), 0.5, player.SPEED * 2)
	var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
	CAMERA_CONTROLLER.fov = lerp(CAMERA_CONTROLLER.fov, target_fov, delta * 8.0)

	# Reset input accumulators
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

func set_lean(delta: float, bob_offset: Vector3) -> void:
	var target_lean: float = 0.0
	var target_roll: float = 0.0

	# --- Manual leaning (overrides strafe roll) ---
	if player.state_machine.get_current_state_name() not in resurrected_states:
		if is_leaning_left():
			if not lean_shape_cast_left.is_colliding():
				target_lean = -LEAN_AMOUNT
			target_roll = LEAN_ROLL_ANGLE
		elif is_leaning_right():
			if not lean_shape_cast_right.is_colliding():
				target_lean = LEAN_AMOUNT
			target_roll = -LEAN_ROLL_ANGLE

	# --- Automatic strafe tilt (only if grounded and not manually leaning) ---
	var is_manually_leaning = is_leaning_left() or is_leaning_right()
	if player.is_on_floor() and not is_manually_leaning:
		var move_dir = Input.get_axis("move_left", "move_right")
		if move_dir != 0.0:
			# Tilt opposite to strafe direction (like banking in a turn)
			target_roll = -move_dir * LEAN_ROLL_ANGLE * 0.7

	# Smooth interpolation
	current_lean = lerp(current_lean, target_lean, delta * LEAN_SPEED)
	current_roll = lerp(current_roll, target_roll, delta * LEAN_SPEED)

	# Apply lean offset (X-axis)
	var lean_offset := Vector3(current_lean, 0.0, 0.0)

	# Apply roll to camera Z rotation
	CAMERA_CONTROLLER.rotation.z = current_roll

	# Combine lean and bob into camera local offset
	CAMERA_CONTROLLER.transform.origin = lean_offset + bob_offset