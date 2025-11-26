class_name CrouchWalkingState
extends State

@export_range(3, 10, 0.1) var crouch_speed: float = 6.0
@export var walk_crouch_speed: float = 2.5
@export var is_toggle_crouch: bool = false
@export var headCast: ShapeCast3D
@export var proneCast: ShapeCast3D

var no_need_to_back: bool = false
var is_in_prone_pose: bool = false  # Tracks whether we're visually "prone"

var was_crouching_array: Array = ["SlidingState", "ClimbState", "DashState"]

func _ready():
	super._ready()
	headCast.add_exception(player)
	proneCast.add_exception(player)  # Good practice

func enter() -> void:
	player.SPEED = walk_crouch_speed
	if state_machine.previous_state.name in was_crouching_array:
		pass
	else:
		_animate_crouch(true)
	# Check for prone immediately on entry
	_update_prone_pose()

func exit() -> void:
	if no_need_to_back:
		_animate_crouch(false)

func update(delta: float) -> void:
	pass

func physics_update(delta: float) -> void:
	# Interpolate speed to crouch walk speed
	player.SPEED = lerp(player.SPEED, walk_crouch_speed, 2.5 * delta)

	# Apply gravity if airborne
	if not player.is_on_floor():
		player.velocity.y -= player.gravity * delta

	# Climbing check
	if player.can_climb() and (Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("sprint")):
		state_machine.get_state("CLimbState")
		return

	# Input and movement
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		player.velocity.x = direction.x * player.SPEED
		player.velocity.z = direction.z * player.SPEED
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, player.SPEED)
		player.velocity.z = move_toward(player.velocity.z, 0, player.SPEED)

	player._push_away_rigid_bodies()
	player.move_and_slide()

	if player.is_on_floor():
		player.step_handler.handle_step_climbing()

	# Update prone pose every physics frame
	_update_prone_pose()

func check_transitions() -> State:
	no_need_to_back = true

	# Falling
	if not player.is_on_floor():
		return state_machine.get_state("FallingState")

	# Jump / climb
	if Input.is_action_just_pressed("jump"):
		if player.can_climb():
			return state_machine.get_state("CLimbState")
		if is_toggle_crouch and _can_stand_up():
			return state_machine.get_state("IdleState")

	# Dash
	if Input.is_action_just_pressed("dash"):
		no_need_to_back = false
		return state_machine.get_state("DashState")

	# Stand up logic (only if not in prone pose)
	if ((not Input.is_action_pressed("crouch") and not is_toggle_crouch) or 
		(is_toggle_crouch and Input.is_action_just_pressed("crouch"))):
		if _can_stand_up():
			var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
			if input_dir.length() > 0.1:
				if Input.is_action_pressed("sprint"):
					return state_machine.get_state("SprintingState")
				else:
					return state_machine.get_state("WalkingState")
			else:
				if state_machine.previous_state.name != "ClimbState":
					return state_machine.get_state("IdleState")

	return null

func _animate_crouch(is_crouching: bool) -> void:
	if is_crouching:
		player.anim_player.play("Crouching", -1, crouch_speed)
	else:
		player.anim_player.play("Crouching", -1, -crouch_speed * 0.8, true)

func _animate_proning(is_proning: bool) -> void:
	if is_proning:
		player.anim_player.play("Pronning", -1, crouch_speed * 2)
	else:
		player.anim_player.play("Pronning", -1, -crouch_speed * 2, true)

func _update_prone_pose() -> void:
	var should_prone = proneCast.is_colliding()

	if should_prone and not is_in_prone_pose:
		# Enter prone pose: play forward once
		_animate_proning(true)
		is_in_prone_pose = true
	elif not should_prone and is_in_prone_pose:
		# Exit prone pose: play backward once
		_animate_proning(false)
		is_in_prone_pose = false

func _can_stand_up() -> bool:
	# Cannot stand up while in prone pose
	if is_in_prone_pose:
		return false
	return headCast.is_colliding() == false
