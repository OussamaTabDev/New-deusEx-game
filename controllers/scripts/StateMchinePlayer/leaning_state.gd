# DashState.gd
class_name DashState
extends State

var dash_duration: float = 0.2  # seconds
var elapsed_time: float = 0.0
var dash_force: float = 10.0

func enter() -> void:
	# Determine dash direction: backward relative to player's orientation
	var backward = player.transform.basis.z  # assumes Z is forward
	player.velocity.x = backward.x * dash_force
	player.velocity.z = backward.z * dash_force

	elapsed_time = 0.0

	# 🎮 Trigger juicy camera shake on dash
	if player.has_method("get_camera_controller"):
		var cam = player.get_camera_controller()
		if cam:
			cam.trigger_dash_shake(0.4, 0.2)


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
