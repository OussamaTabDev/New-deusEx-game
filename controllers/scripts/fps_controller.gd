class_name Player extends CharacterBody3D

# Movement parameters
@export var WALK_SPEED: float = 5.0
@export var SPRINT_SPEED: float = 8.0
@export var JUMP_VELOCITY: float = 4.5
@export var CAMERA_CONTROLLER: CameraController
@export var state_machine: StateMachine
@export var anim_player: AnimationPlayer
@export var head_Cast : ShapeCast3D
@export var chest_Cast: ShapeCast3D
@export var mid_chest_Cast: ShapeCast3D
@export var upperchestCastNode: Node3D
@export var upperchest_Cast: ShapeCast3D
@export var upperchest_Cast_Crouch: ShapeCast3D
@export var h_cast : RayCast3D
@export var h_cast_up : RayCast3D
@export var r_cast : RayCast3D
@export var step_handler : StepHandlerComponent
@export var audio_component: PlayerAudioComponent

@export_group("Audio")
## AudioStream that gets played when the player jumps.
@export var jump_sound : AudioStream
## AudioStream that gets played when the player slides (sprint + crouch).
@export var slide_sound : AudioStream
@export_subgroup ("Footstep Audio")
@export var walk_volume_db : float = -38.0
@export var sprint_volume_db : float = -30.0
@export var crouch_volume_db : float = -60.0
## the time between footstep sounds when walking
@export var walk_footstep_interval : float = 0.6
## the time between footstep sounds when sprinting
@export var sprint_footstep_interval : float = 0.3
## the speed at which the player must be moving before the footsteps change from walk to sprint.
@export var footstep_interval_change_velocity : float = 5.2

@export_subgroup ("Landing Audio")
## Threshold for triggering landing sound
@export var landing_threshold = -2.0  
## Defines Maximum velocity (in negative) for the hardest landing sound
@export var max_landing_velocity = -8
## Defines Minimum velocity (in negative) for the softest landing sound
@export var min_landing_velocity = -2
## Max volume in dB for the landing sound
@export var max_volume_db = 0
## Min volume in dB for the landing sound
@export var min_volume_db = -40
## Highest pitch for lightest landing sound
@export var max_pitch = 0.8
## Lowest pitch for hardest landing sound
@export var min_pitch = 0.7
#Setup Dynamic Pitch & Volume for Landing Audio, used to store velocity based results
var LandingPitch: float = 1.0
var LandingVolume: float = 0.8
# Adding carryable position for item control.
@onready var footstep_player = $FootstepPlayer
@onready var footstep_surface_detector : FootstepSurfaceDetector = $FootstepPlayer


# Current speed (modified by states)
var SPEED: float = 5.0
var previous_velocity : Vector3


var dash_direction: Vector3 = Vector3.ZERO

var can_wall_run_bool: bool = true

# Gravity
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# hitmarker points
var hit_point2: Vector3
var current_distance: float

var _input_dir = Vector2.ZERO

var in_water: bool = false
var current_water_body:Area3D
func _ready():
	# The state machine will handle initialization
	pass

func _physics_process(delta):
	# _input_dir = 
	previous_velocity = velocity
	if is_ledge_detect() and state_machine.current_state.name != "ClimbState":
		ledge_detect()
	_input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	# move_and_slide()
	


func _process(delta):
	# State machine handles all updates
	pass

# Optional: Add helper functions that states can use
func get_movement_input() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_forward", "move_backward")

func get_move_direction() -> Vector3:
	var input_dir = get_movement_input()
	return (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

func is_moving() -> bool:
	return get_movement_input().length() > 0.1

func is_sprinting() -> bool:
	return Input.is_action_pressed("sprint")

func is_crouching() -> bool:
	return Input.is_action_pressed("crouch")

func wants_to_jump() -> bool:
	return Input.is_action_just_pressed("jump")

func is_leaning() -> bool:
	return Input.is_action_pressed("lean_left") or Input.is_action_pressed("lean_right")

func can_climb():
	var hit_point = h_cast_up.get_collision_point()
	var player_pos = global_transform.origin
	var distance = player_pos.distance_to(hit_point)
	# if distance < 2.4:
	# 	current_distance = distance
	# print("Hit point:", hit_point, " Player pos:", player_pos, " Distance:", distance)
	if state_machine.current_state.name == "SurfaceSwimmingState":
		return not head_Cast.is_colliding()  \
		and hit_point2.y - global_transform.origin.y < 3.0 and hit_point2.y - global_transform.origin.y > 0.3 \
		and (chest_Cast.is_colliding() or mid_chest_Cast.is_colliding() or (h_cast_up.is_colliding() and distance < 2.4 ) )
	
	return not head_Cast.is_colliding()  \
	  and hit_point2.y - global_transform.origin.y < 3.0 and hit_point2.y - global_transform.origin.y > 1 \
	  and (chest_Cast.is_colliding() or mid_chest_Cast.is_colliding() or (h_cast_up.is_colliding() and distance < 2.4 ) )


func ledge_detect():
	var player_pos = global_transform.origin
	var hit_point1 = chest_Cast.get_collision_point(0) # this ShapeCast3D is child of player others is RayCast3D
	var hit_point3 = mid_chest_Cast.get_collision_point(0) # this ShapeCast3D is child of player others is RayCast3D
	var hit_point1_up = h_cast_up.get_collision_point()
	var raycast2_holder = r_cast.get_parent()
	var ledge_marker = r_cast.get_child(0)
	hit_point2 = r_cast.get_collision_point()
	var offset = Vector3(0, .5, 0)
	

	if chest_Cast.is_colliding():
		raycast2_holder.global_transform.origin = hit_point1 + offset
		ledge_marker.global_transform.origin = hit_point2
		upperchestCastNode.global_transform.origin.y = hit_point2.y + 0.2
		ledge_marker.visible = true
		r_cast.enabled = true
	elif mid_chest_Cast.is_colliding():
		raycast2_holder.global_transform.origin = hit_point3 + offset
		ledge_marker.global_transform.origin = hit_point2
		upperchestCastNode.global_transform.origin.y = hit_point2.y + 0.2
		ledge_marker.visible = true
		r_cast.enabled = true

	elif h_cast_up.is_colliding():
		raycast2_holder.global_transform.origin = hit_point1_up + offset
		ledge_marker.global_transform.origin = hit_point2
		upperchestCastNode.global_transform.origin.y = hit_point2.y + 0.2

		ledge_marker.visible = true
		r_cast.enabled = true

	else:
		ledge_marker.visible = false
		r_cast.enabled = false

func is_ledge_detect() -> bool:
	return chest_Cast.is_colliding() or mid_chest_Cast.is_colliding() or h_cast_up.is_colliding()

func can_wall_run() -> bool:
	return not is_on_floor() and is_on_wall() and can_wall_run_bool


func get_input_direction() -> Vector3:
	var dir = Vector3.ZERO
	var forward = -global_transform.basis.z
	var right = global_transform.basis.x
	

	if Input.is_action_pressed("move_forward"):
		dir += forward
	if Input.is_action_pressed("move_backward"):
		dir -= forward
	if Input.is_action_pressed("move_right"):
		dir += right
	if Input.is_action_pressed("move_left"):
		dir -= right

	return dir.normalized()


var current_ladder_shape: CollisionShape3D = null
var current_ladder_up_direction: Vector3 = Vector3.ZERO
var on_ladder: bool = false  # You may already have this
# Add these to your Player class (e.g., Player.gd)
var is_on_ladder: bool = false
var ladder_target_yaw: float = 0.0
# Optional: ladder-related method (called by Area3D)
func set_current_ladder(shape: CollisionShape3D, direction: Vector3) -> void:
	current_ladder_shape = shape
	current_ladder_up_direction = direction
	on_ladder = true
	print(current_ladder_shape , current_ladder_up_direction , on_ladder )

func _get_input_direction() -> Vector2:
	return _input_dir

func is_in_water():
	return in_water

func get_camera_controller():
	return CAMERA_CONTROLLER


func _push_away_rigid_bodies():
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_collider() is RigidBody3D:
			var push_dir = -c.get_normal()
			# How much velocity the object needs to increase to match player velocity in the push direction
			var velocity_diff_in_push_dir = self.velocity.dot(push_dir) - c.get_collider().linear_velocity.dot(push_dir)
			# Only count velocity towards push dir, away from character
			velocity_diff_in_push_dir = max(0., velocity_diff_in_push_dir)
			# Objects with more mass than us should be harder to push. But doesn't really make sense to push faster than we are going
			const MY_APPROX_MASS_KG = 80.0
			var mass_ratio = min(1., MY_APPROX_MASS_KG / c.get_collider().mass)
			# Optional add: Don't push object at all if it's 4x heavier or more
			if mass_ratio < 0.25:
				continue
			# Don't push object from above/below
			push_dir.y = 0
			# 5.0 is a magic number, adjust to your needs
			var push_force = mass_ratio * 1.0
			c.get_collider().apply_impulse(push_dir * velocity_diff_in_push_dir * push_force, c.get_position() - c.get_collider().global_position)
