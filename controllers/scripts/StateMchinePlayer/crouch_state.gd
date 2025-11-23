# ClimbState.gd
class_name ClimbState
extends State

@export var time_to_climb: float = 1.0
@export var time_to_move: float = 0.5
@export var move_speed: float = .5

var climb_hight: float 
var previous: String = ""
@export var head_Cast : ShapeCast3D
@export var chest_Cast: ShapeCast3D
@export var upperchest_Cast_Idle: ShapeCast3D
@export var upperchest_Cast_Crouch: ShapeCast3D

@export var crouchState: State
@export var standState: State
var will_crouch: bool = false
var current_distance: float
@export var collision : CollisionShape3D 

var h_speed_twin: float = 0.0
var v_speed_twin: float = 0.0

# Manual animation variables
var is_climbing: bool = false
var climb_timer: float = 0.0
var climb_phase: int = 0  # 0 = vertical, 1 = horizontal
var start_pos: Vector3
var mid_pos: Vector3
var end_pos: Vector3


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

	await get_tree().create_timer(0.1).timeout
	print("Entering Climb state")
	start_climb()


func exit() -> void:
	is_climbing = false
	print("Exiting Climb state")


func update(delta: float) -> void:
	if is_climbing:
		animate_climb(delta)


func physics_update(delta: float) -> void:
	player.move_and_slide()


func check_transitions() -> State:
	if Input.is_action_just_pressed("move_backward"):
		if is_climbing:
			is_climbing = false
			return state_machine.get_state("FallingState")
	return null


func _can_stand_up() -> bool:
	return will_crouch


func start_climb():
	var climb_height = climb_hight
	var climb_forward = -player.global_transform.basis.z * (move_speed + player.current_distance)
	
	start_pos = player.global_position
	mid_pos = start_pos + Vector3(0, climb_height * 0.6, 0) + climb_forward * 0.2
	end_pos = start_pos + Vector3(0, climb_height, 0) + climb_forward
	
	is_climbing = true
	climb_timer = 0.0
	climb_phase = 0


func animate_climb(delta: float):
	climb_timer += delta
	
	if climb_phase == 0:  # Vertical phase
		var progress = min(climb_timer / v_speed_twin, 1.0)
		# Ease out sine
		var eased_progress = sin(progress * PI / 2.0)
		
		player.global_position = start_pos.lerp(mid_pos, eased_progress)
		
		if progress >= 1.0:
			climb_phase = 1
			climb_timer = 0.0
			
			if will_crouch:
				player.anim_player.play("Crouching", -1, 10.0)
	
	elif climb_phase == 1:  # Horizontal phase
		var progress = min(climb_timer / h_speed_twin, 1.0)
		# Ease in sine
		var eased_progress = 1.0 - cos(progress * PI / 2.0)
		
		player.global_position = mid_pos.lerp(end_pos, eased_progress)
		
		if progress >= 1.0:
			finish_climb()


func finish_climb():
	is_climbing = false
	print("Climb animation done!")
	
	if previous == "CrouchWalkingState" or _can_stand_up():
		state_machine.transition_to(crouchState)
	else:
		state_machine.transition_to(standState)
