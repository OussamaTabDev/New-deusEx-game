# DashState.gd
class_name DashState
extends State

var dash_duration: float = 0.2  # seconds
var elapsed_time: float = 0.0
var dash_force: float = 10.0

# 🎯 Direction settings
@export var enable_8_direction: bool = false  # Toggle for 8-directional dash
@export var default_direction: String = "backward"  # "forward", "backward", "left", "right"

func enter() -> void:
	var dash_direction: Vector3
	
	if enable_8_direction:
		# Get input direction for 8-way dash
		dash_direction = _get_input_direction()
	else:
		# Use default direction
		dash_direction = _get_default_direction()
	
	# Apply dash force
	player.velocity.x = dash_direction.x * dash_force
	player.velocity.z = dash_direction.z * dash_force

	elapsed_time = 0.0

	# 🎮 Trigger juicy camera shake on dash
	if player.has_method("get_camera_controller"):
		var cam = player.get_camera_controller()
		if cam:
			cam.trigger_dash_shake(0.04, 0.2)


func _get_default_direction() -> Vector3:
	"""Returns the default dash direction based on player orientation"""
	match default_direction:
		"forward":
			return -player.transform.basis.z  # Forward
		"backward":
			return player.transform.basis.z   # Backward
		"left":
			return -player.transform.basis.x  # Left
		"right":
			return player.transform.basis.x   # Right
		_:
			return player.transform.basis.z   # Default to backward


func _get_input_direction() -> Vector3:
	"""Returns dash direction based on WASD/input (8 directions)"""
	# Get input axes
	var input_x = Input.get_axis("move_left", "move_right")
	var input_z = Input.get_axis("move_forward", "move_backward")
	
	# If no input, use default direction
	if input_x == 0 and input_z == 0:
		return _get_default_direction()
	
	# Create direction vector in local space
	var local_direction = Vector3(input_x, 0, input_z).normalized()
	
	# Transform to world space based on player's orientation
	var world_direction = player.transform.basis * local_direction
	
	return world_direction


func physics_update(delta: float) -> void:
	# Apply gravity during dash (optional: some games disable gravity during dash)
	if not player.is_on_floor():
		player.velocity.y -= player.gravity * delta

	player.move_and_slide()

	# Track time to end dash
	elapsed_time += delta


func check_transitions() -> State:
	# End dash after duration
	if elapsed_time >= dash_duration:
		if state_machine.previous_state.name == "CrouchWalkingState":
			return state_machine.get_state("CrouchWalkingState")

		if not player.is_on_floor():
			return state_machine.get_state("FallingState")
		else:
			return state_machine.get_state("IdleState")  # or Walking, etc.
	return null