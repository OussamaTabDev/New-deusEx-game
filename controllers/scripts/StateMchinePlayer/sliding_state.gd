# SlidingState.gd (updated)
class_name SlidingState
extends State

@export var slide_speed: float = 10.0
@export var is_toggle_crouch: bool = false
@export var slide_friction: float = 3.0
@export var min_slide_speed: float = 3.0
@export var slide_duration: float = 2.0
@export var tilt_amount: float = 0.09
@export var headCast: ShapeCast3D
@export_range(1,10,0.1) var crouch_speed: float = 5.0
@export var min_air_time_before_slide: float = 0.5  # Safety threshold

var slide_direction: Vector3
var slide_timer: float = 0.0


func _ready():
	super._ready()
	headCast.add_exception(player)


func enter() -> void:
	# 🔒 Safety: If somehow entered while airborne too soon, abort
	# if not player.is_on_floor() and player.time_since_last_grounded < min_air_time_before_slide:
	#     # Revert to previous state (e.g., Falling or Sprinting)
	#     state_machine.transition_to(state_machine.previous_state.name)
	#     return

	var horizontal_velocity = Vector3(player.velocity.x, 0, player.velocity.z)
	set_tilt(player.rotation)
	
	if horizontal_velocity.length() > 0:
		slide_direction = horizontal_velocity.normalized()
	else:
		slide_direction = -player.transform.basis.z

	var current_speed = horizontal_velocity.length()
	if state_machine.previous_state.name == "SprintingState":
		slide_speed = max(current_speed, slide_speed)
	
	slide_timer = 0.0
	_animate_crouch(true)


func exit() -> void:
	pass


func update(delta: float) -> void:
	slide_timer += delta


func physics_update(delta: float) -> void:
	# Apply deceleration
	var current_slide_speed = slide_speed - (slide_friction * slide_timer)
	current_slide_speed = max(current_slide_speed, 0)

	player.velocity.x = slide_direction.x * current_slide_speed
	player.velocity.z = slide_direction.z * current_slide_speed

	# Optional steering
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if input_dir.length() > 0:
		var input_direction = (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		slide_direction = slide_direction.lerp(input_direction, 0.1 * delta)
		slide_direction = slide_direction.normalized()

	player.move_and_slide()


func check_transitions() -> State:
	var current_slide_speed = slide_speed - (slide_friction * slide_timer)
	var should_end_slide = false

	if current_slide_speed < min_slide_speed:
		should_end_slide = true
	if slide_timer >= slide_duration:
		should_end_slide = true
	if ((not Input.is_action_pressed("crouch") and not is_toggle_crouch)) and _can_stand_up() and slide_timer >= slide_duration:
		should_end_slide = true
	if Input.is_action_just_pressed("jump"):
		_animate_crouch(false)
		return state_machine.get_state("JumpingState")

	if should_end_slide:
		if Input.is_action_pressed("crouch") or (is_toggle_crouch and not Input.is_action_just_pressed("crouch")):
			return state_machine.get_state("CrouchWalkingState")
		if _can_stand_up() and (is_toggle_crouch and Input.is_action_just_pressed("crouch") or not is_toggle_crouch):
			var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
			_animate_crouch(false)
			return state_machine.get_state("WalkingState") if input_dir.length() > 0.1 else state_machine.get_state("IdleState")
		else:
			return state_machine.get_state("CrouchWalkingState")

	return null


func _can_stand_up() -> bool:
	return not headCast.is_colliding()


func _animate_crouch(is_crouching: bool) -> void:
	if is_crouching:
		player.CAMERA_CONTROLLER.set_crouching(true , crouch_speed / 10)
		player.anim_player.play("Sliding", -1, crouch_speed)
	else:
		player.CAMERA_CONTROLLER.set_crouching(false , crouch_speed / 4)
		player.anim_player.play("Crouching", -1, -crouch_speed, true)


func set_tilt(current_rotation: Vector3) -> void:
	var tilt = Vector3.ZERO
	tilt.z = clamp(tilt_amount * current_rotation.z, -0.1, 0.1)
	if tilt.z == 0.0:
		tilt.z = 0.05
	# Optional: update animation track if needed
