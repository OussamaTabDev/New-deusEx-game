class_name ClimbState
extends State


@export var time_to_climb: float = 1.0
@export var time_to_move: float = 0.5
@export var move_speed: float = 2.0

var climb_hight: float 
@export var head_Cast : ShapeCast3D
@export var chest_Cast: ShapeCast3D
@export var upperchest_Cast: ShapeCast3D

@export var crouchState: State
@export var standState: State

var tween: Tween  # store tween reference if needed

func enter() -> void:
	climb_hight = player.hit_point2.y + 0.5 - player.global_transform.origin.y
	# move_speed = player.hit_point2.z - player.global_transform.origin.z + 1.5
	print("Entering Climb state")
	climb()  # start climb immediately when entering


func exit() -> void:
	print("Exiting Climb state")


func update(delta: float) -> void:
	pass


func physics_update(delta: float) -> void:
	if not  _can_stand_up():
		player.anim_player.play("Crouching")
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
	return not head_Cast.is_colliding()


func climb():
	var climb_height = climb_hight
	var climb_forward = -player.global_transform.basis.z * (move_speed + player.current_distance)
	
	# Starting position
	var start_pos = player.global_position
	
	# Midpoint (higher and slightly back)
	var mid_pos = start_pos + Vector3(0, climb_height * 0.6, 0) + climb_forward * 0.2
	
	# End position (on top and forward)
	var end_pos = start_pos + Vector3(0, climb_height, 0) + climb_forward
	
	tween = create_tween()
	
	# Smooth vertical and forward arc — using easing for natural feel
	tween.tween_property(player, "global_position", mid_pos, time_to_climb * 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(player, "global_position", end_pos, time_to_climb * 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	await tween.finished
	
	print("Climb animation done!")
	
	if state_machine.previous_state.name == "WalkingCrouchState" or not  _can_stand_up():
		state_machine.transition_to(crouchState)
	
	state_machine.transition_to(standState)
