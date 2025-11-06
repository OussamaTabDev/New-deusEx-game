class_name CrouchWalkingState
extends State

@export_range(3,10,0.1) var crouch_speed: float = 6.0
@export var walk_crouch_speed: float = 2.5
@export var is_toggle_crouch: bool = false
@export var headCast: ShapeCast3D
func _ready():
	super._ready()
	headCast.add_exception(player)
	#await player.ready
	
	

func enter() -> void:
	player.SPEED = walk_crouch_speed
	if state_machine.previous_state.name == "SlidingState" or state_machine.previous_state.name == "ClimbState":
		pass
	else:
		_animate_crouch(true)

func exit() -> void:
	_animate_crouch(false)
	

func update(delta: float) -> void:
	pass

func physics_update(delta: float) -> void:
	# print("crouch walking physics update")
	# # Smoothly transition speed
	player.SPEED = lerp(player.SPEED, walk_crouch_speed, 2.5 * delta)
	
	# # Apply gravity
	if not player.is_on_floor():
		player.velocity.y -= player.gravity * delta
	
	if player.can_climb() and (Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("sprint")):
		return state_machine.get_state("CLimbState")
		

	# # Get input and move
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		player.velocity.x = direction.x * player.SPEED
		player.velocity.z = direction.z * player.SPEED
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, player.SPEED)
		player.velocity.z = move_toward(player.velocity.z, 0, player.SPEED)
	
	player.move_and_slide()

func check_transitions() -> State:
	# Check for falling
	if not player.is_on_floor():
		return state_machine.get_state("FallingState")
	
	# Check for jump
	if Input.is_action_just_pressed("jump"):
		if player.can_climb():
			return state_machine.get_state("CLimbState")
		if is_toggle_crouch and _can_stand_up() :
			return state_machine.get_state("IdleState")
			
		# return state_machine.get_state("JumpingState")

	# Check if crouch released and can stand up
	if ((not Input.is_action_pressed("crouch") and not is_toggle_crouch) or (is_toggle_crouch and Input.is_action_just_pressed("crouch"))):
		if _can_stand_up():
			var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
			if input_dir.length() > 0.1:
				if Input.is_action_pressed("sprint"):
					return state_machine.get_state("SprintingState")
				else:
					return state_machine.get_state("WalkingState")
			else:
				if not state_machine.previous_state.name == "ClimbState":
					return state_machine.get_state("IdleState")
				
	
	return null

func _animate_crouch(is_crouching: bool) -> void:
	if is_crouching:
		player.anim_player.play("Crouching" , -1 , crouch_speed)
	else:
		player.anim_player.play("Crouching" , -1 , -crouch_speed * 0.80 , true)

func _can_stand_up() -> bool:
	return headCast.is_colliding() == false
