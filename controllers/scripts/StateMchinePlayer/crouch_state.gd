# ClimbState.gd
class_name ClimbState
extends State

# -- Settings --
@export_group("Speeds")
@export var vertical_speed: float = 3.5 # Slightly faster for "pro" feel
@export var horizontal_speed: float = 2.5
@export var push_wall_force: float = 1.0 
@export var move_speed: float = .5

# -- References --
@export_group("Raycasts")
@export var upperchest_Cast_Idle: ShapeCast3D
# Assume player has a reference to "camera_controller"

@export_group("Transitions")
@export var crouchState: State
@export var standState: State
@export var fallingState: State

var target_height: float 
var final_pos: Vector3
var will_crouch: bool = false
var climb_phase: int = 0  # 0 = Vertical, 1 = Horizontal

func enter() -> void:
    player.unhold_object()
    
    # JUICE: Trigger a small screen shake for the "Impact" of grabbing the ledge
    if player.CAMERA_CONTROLLER:
        player.CAMERA_CONTROLLER.add_screen_shake(0.2, 0.2) 
        player.CAMERA_CONTROLLER.reset_climb_feedback() # Ensure clean slate
    
    if upperchest_Cast_Idle.is_colliding():
        will_crouch = true
    else:
        will_crouch = false

    # Calculate Ledge Height
    var ledge_y = player.hit_point2.y 
    target_height = ledge_y
    
    # Calculate Landing Spot
    var forward_dir = -player.global_transform.basis.z 
    var horizontal_offset = move_speed + 0.3
    final_pos = Vector3(player.global_position.x, ledge_y, player.global_position.z) + (forward_dir * horizontal_offset)

    climb_phase = 0 
    player.velocity = Vector3.ZERO


func physics_update(delta: float) -> void:
    match climb_phase:
        0: _process_vertical_climb(delta)
        1: _process_horizontal_step(delta)
    
    player.move_and_slide()
    
    # JUICE: Send feedback to camera
    if player.CAMERA_CONTROLLER:
        # True if vertical, False if horizontal
        player.CAMERA_CONTROLLER.process_climb_feedback(delta, player.velocity, climb_phase == 0)


func _process_vertical_climb(delta: float) -> void:
    player.velocity.y = vertical_speed
    
    var forward_dir = -player.global_transform.basis.z
    var wall_push = forward_dir * push_wall_force
    player.velocity.x = wall_push.x
    player.velocity.z = wall_push.z

    if player.global_position.y >= target_height:
        player.global_position.y = target_height 
        player.velocity.y = 0
        climb_phase = 1


func _process_horizontal_step(delta: float) -> void:
    var direction = (final_pos - player.global_position)
    direction.y = 0
    var distance_remaining = direction.length()
    direction = direction.normalized()

    player.velocity = direction * horizontal_speed
    player.velocity.y = 0 

    if distance_remaining < 0.1:
        finish_climb()


func finish_climb() -> void:
    player.velocity = Vector3.ZERO
    
    # JUICE: Reset camera effects and smooth the final "step up"
    if player.CAMERA_CONTROLLER:
        player.CAMERA_CONTROLLER.reset_climb_feedback()
        # This pushes the camera down and smooths it back up, simulating knees bending on landing
        player.CAMERA_CONTROLLER.smooth_step(0.15) 
    
    if will_crouch:
        state_machine.transition_to(crouchState)
    else:
        state_machine.transition_to(standState)


func exit() -> void:
    # Just in case we exit early
    if player.CAMERA_CONTROLLER:
        player.CAMERA_CONTROLLER.reset_climb_feedback()