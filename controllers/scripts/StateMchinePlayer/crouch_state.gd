# ClimbState.gd
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
var tween: Tween
var current_distance: float
@export var collision : CollisionShape3D 

var h_speed_twin: float = 0.0
var v_speed_twin: float = 0.0


func enter() -> void:
	h_speed_twin = time_to_move / player.SPEED
	v_speed_twin = time_to_climb / player.SPEED
	
	previous = state_machine.previous_state.name
	current_distance = player.global_transform.origin.distance_to(player.h_cast_up.get_collision_point()) - 1
	
	if upperchest_Cast_Idle.is_colliding():
		print("Playing Crouch Animation")
		will_crouch = true
	else:
		print("Playing Idle Animation")
		will_crouch = false

	climb_hight = player.hit_point2.y - player.global_transform.origin.y
	
	## Notify camera: climbing started
	#if player.CAMERA_CONTROLLER:
		#player.CAMERA_CONTROLLER.set_climb_active(true)

	await get_tree().create_timer(0.1).timeout
	print("Entering Climb state")
	climb()


func exit() -> void:
	# Notify camera: climbing ended
	#if player.CAMERA_CONTROLLER:
		#player.CAMERA_CONTROLLER.set_climb_active(false)
	print("Exiting Climb state")


func update(delta: float) -> void:
	pass


func physics_update(delta: float) -> void:
	player.move_and_slide()


func check_transitions() -> State:
	if Input.is_action_just_pressed("move_backward"):
		if tween and tween.is_running():
			tween.kill()
			return state_machine.get_state("FallingState")
	return null


func _can_stand_up() -> bool:
	return will_crouch


func climb():
	var climb_height = climb_hight
	var climb_forward = -player.global_transform.basis.z * (move_speed + player.current_distance)
	var start_pos = player.global_position
	var mid_pos = start_pos + Vector3(0, climb_height * 0.6, 0) + climb_forward * 0.2
	var end_pos = start_pos + Vector3(0, climb_height, 0) + climb_forward
	
	tween = create_tween()
	tween.tween_property(player, "global_position", mid_pos, v_speed_twin)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
	if will_crouch:
		#player.CAMERA_CONTROLLER.set_crouching(true)
		player.anim_player.play("Crouching", -1, 10.0)
	
	tween.tween_property(player, "global_position", end_pos, h_speed_twin)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	await tween.finished
	print("Climb animation done!")
	
	if previous == "CrouchWalkingState" or _can_stand_up():
		state_machine.transition_to(crouchState)
	else:
		state_machine.transition_to(standState)
