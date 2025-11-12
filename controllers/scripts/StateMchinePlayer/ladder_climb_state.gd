# ClimbLadderState.gd
class_name LadderClimbState
extends State

# Ladder-specific references
var current_ladder_shape: CollisionShape3D
var ladder_direction: Vector3

var _was_in_floor: bool = true

# Smooth centering
var _is_centering: bool = false
var _center_target: Vector3 = Vector3.ZERO
var _center_speed: float = 8.0  # Tune: higher = faster


func enter() -> void:
	player.can_wall_run_bool = false
	player.SPEED = player.WALK_SPEED  # or a slower climb speed if desired
	CAMERA_CONTROLLER.lock_vertical = true

	player.velocity.y = 0

	if player.current_ladder_shape == null:
		printerr("ClimbLadderState entered without ladder data!")
		return

	current_ladder_shape = player.current_ladder_shape
	ladder_direction = player.current_ladder_up_direction
	ladder_direction = ladder_direction.rotated(Vector3(1, 0, 0), -PI / 2)

	# 🔑 Start smooth centering
	var ladder_center = current_ladder_shape.global_transform.origin
	var player_pos = player.global_transform.origin
	_center_target = Vector3(ladder_center.x, player_pos.y, ladder_center.z)
	_is_centering = true


func exit() -> void:
	player.can_wall_run_bool = true
	CAMERA_CONTROLLER.lock_vertical = false
	player.current_ladder_shape = null
	player.current_ladder_up_direction = Vector3.ZERO
	_is_centering = false


func physics_update(delta: float) -> void:
	if not current_ladder_shape or not current_ladder_shape.is_inside_tree():
		state_machine.get_state("IdleState")
		return

	if not player.is_on_floor():
		_was_in_floor = false

	# 🔑 Smoothly move player toward ladder center (horizontal only)
	if _is_centering:
		var current_pos = player.global_transform.origin
		var target_pos = _center_target

		# Only interpolate X and Z; keep Y separate (climbing handles Y)
		var desired_xz = Vector2(target_pos.x, target_pos.z)
		var current_xz = Vector2(current_pos.x, current_pos.z)

		# Stop centering when very close
		if desired_xz.distance_to(current_xz) < 0.02:
			_is_centering = false
			player.global_transform.origin = Vector3(target_pos.x, current_pos.y, target_pos.z)
		else:
			var new_xz = current_xz.lerp(desired_xz, _center_speed * delta)
			player.global_transform.origin = Vector3(new_xz.x, current_pos.y, new_xz.y)

		# Zero out horizontal velocity to avoid fighting the lerp
		player.velocity.x = 0
		player.velocity.z = 0

	# Handle climbing input
	var up_input = Input.get_axis("move_backward", "move_forward")
	var climb_speed = 2.0
	player.velocity = ladder_direction * up_input * climb_speed

	# Optional: allow slight right/left strafe if needed
	# var right_input = Input.get_axis("move_left", "move_right")
	# var strafe = player.global_transform.basis.x * right_input * 0.8
	# player.velocity += strafe

	player.move_and_slide()


func check_transitions() -> State:
	if current_ladder_shape:
		var dist_to_ladder = player.global_position.distance_to(current_ladder_shape.global_position)
		if dist_to_ladder > 2.0:
			return state_machine.get_state("IdleState")

	if Input.is_action_just_pressed("jump"):
		player.velocity.y = player.JUMP_VELOCITY * 0.7
		return state_machine.get_state("FallingState")

	if player.is_on_floor() and Input.is_action_pressed("move_backward"):
		return state_machine.get_state("WalkingState")

	if Input.is_action_just_pressed("crouch"):
		return state_machine.get_state("FallingState")

	return null
