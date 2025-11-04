class_name ClimbState
extends State

@export var move_speed: float = 5.0
@export var time_to_climb: float = 1.0
@export var time_to_move: float = 0.5

var climb_hight: float 
@export var head_Cast : ShapeCast3D
@export var chest_Cast: ShapeCast3D
@export var upperchest_Cast: ShapeCast3D

@export var crouchState: State
@export var standState: State

var tween: Tween  # store tween reference if needed

func enter() -> void:
	climb_hight = player.hit_point2.y
	print("Entering Climb state")
	climb()  # start climb immediately when entering


func exit() -> void:
	print("Exiting Climb state")


func update(delta: float) -> void:
	pass


func physics_update(delta: float) -> void:
	player.move_and_slide()


func check_transitions() -> State:
	# Manual override if player cancels
	# Allow cancelling climb by moving downwards
	if Input.is_action_just_pressed("move_backward"):
		if tween and tween.is_running():
			tween.kill()
			return state_machine.get_state("FallingState")
	return null


func _can_stand_up() -> bool:
	return head_Cast.is_colliding()


func climb():
	var vertical_target = player.global_position + Vector3(0, climb_hight, 0)
	var forward_target = player.global_position  + (-player.global_transform.basis.z * move_speed) + Vector3(0, climb_hight, 0)

	# Step 1 — climb up
	tween = create_tween()
	tween.tween_property(
		player,
		"global_position",
		vertical_target,
		time_to_climb
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	

	# Step 2 — after climbing, move forward
	tween.tween_property(
		player,
		"global_position",
		forward_target,
		time_to_move
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	

	# Wait for tween to finish, then return to idle/crouch
	await tween.finished
	print("Climb animation done!")

	if state_machine.previous_state.name == "WalkingCrouchState" or not _can_stand_up():
		state_machine.transition_to(crouchState)
	else:
		state_machine.transition_to(standState)
