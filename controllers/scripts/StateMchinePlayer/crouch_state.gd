class_name ClimbState
extends State


@export var time_to_climb: float = 1.0
@export var time_to_move: float = 0.5
@export var move_speed: float = 2.0

var climb_hight: float 
var previous: String = ""
@export var head_Cast : ShapeCast3D
@export var chest_Cast: ShapeCast3D
@export var upperchest_Cast_Idle: ShapeCast3D
@export var upperchest_Cast_Crouch: ShapeCast3D

@export var crouchState: State
@export var standState: State
var will_crouch: bool = false
var tween: Tween  # store tween reference if needed
var current_distance: float
@export var collision : CollisionShape3D 


var h_speed_twin: float = 0.0
var v_speed_twin: float = 0.0

func enter() -> void:
	h_speed_twin =  time_to_move /  player.SPEED
	v_speed_twin =  time_to_climb /  player.SPEED
	
	previous = state_machine.previous_state.name
	current_distance = player.global_transform.origin.distance_to(player.h_cast_up.get_collision_point()) - 1
	# collision.disabled = true
	# print("upperchest_Cast_Idle is collidin/g:", upperchest_Cast_Idle.is_colliding())
	# print("is colliding with:" , upperchest_Cast_Idle.get_collider(0))
	# print("upperchest_Cast_Crouch is colliding:", upperchest_Cast_Crouch.is_colliding())
	# print("is colliding with:" , upperchest_Cast_Crouch.get_collider(0))
	## mark where upperchest_Cast_Crouch is colliding 
	

	if upperchest_Cast_Idle.is_colliding():
		
		print("Playing Crouch Animation")
		will_crouch = true

	else:
		print("Playing Idle Animation")
		will_crouch = false

	climb_hight = player.hit_point2.y  - player.global_transform.origin.y
	
	await get_tree().create_timer(.1).timeout
	# move_speed = player.hit_point2.z - player.global_transform.origin.z + 1.5
	print("Entering Climb state")
	climb()  # start climb immediately when entering


func exit() -> void:
	print("Exiting Climb state")


func update(delta: float) -> void:
	pass


func physics_update(delta: float) -> void:
	# if not  _can_stand_up():
		
	player.move_and_slide()


func check_transitions() -> State:
	# Manual override if player cancels
	# Allow cancelling climb by moving downwards
	if Input.is_action_just_pressed("move_backward"):
		# collision.disabled = false
		if tween and tween.is_running():
			tween.kill()
			return state_machine.get_state("FallingState")
	return null

	

func _can_stand_up() -> bool:
	return will_crouch


func climb():
	var climb_height = climb_hight
	# var climb_forward = -player.global_transform.basis.z * (move_speed + player.current_distance)
	var climb_forward = -player.global_transform.basis.z * ( move_speed + player.current_distance)
	
	# Starting position
	var start_pos = player.global_position
	
	# Midpoint (higher and slightly back)
	var mid_pos = start_pos + Vector3(0, climb_height * 0.6, 0) + climb_forward * 0.2
	
	# End position (on top and forward)
	var end_pos = start_pos + Vector3(0, climb_height, 0) + climb_forward
	
	tween = create_tween()
	
	# Smooth vertical and forward arc — using easing for natural feel
	tween.tween_property(player, "global_position", mid_pos, v_speed_twin)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
	if will_crouch:
		player.anim_player.play("Crouching" , -1 , 10.0)
	
	
	tween.tween_property(player, "global_position", end_pos, h_speed_twin)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	await tween.finished
	print("Climb animation done!")
	
	if previous == "CrouchWalkingState" or _can_stand_up() :
		# collision.disabled = false
		state_machine.transition_to(crouchState)
		return
		
	# collision.disabled = false
	state_machine.transition_to(standState)


