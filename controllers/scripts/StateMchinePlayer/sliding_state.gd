class_name SlidingState
extends State

@export var slide_speed: float = 10.0  # Initial slide speed (faster than sprint)
@export var is_toggle_crouch: bool = false # Whether crouch is toggle or hold
@export var slide_friction: float = 3.0  # How quickly the slide decelerates
@export var min_slide_speed: float = 3.0  # Minimum speed before transitioning out
@export var slide_duration: float = 2.0  # Maximum slide duration
@export var headCast: ShapeCast3D
@export_range(1,10,0.1) var crouch_speed: float = 5.0

var slide_direction: Vector3
var slide_timer: float = 0.0


func _ready():
    super._ready()
    headCast.add_exception(player)
    #await player.ready

func enter() -> void:
    # Capture the direction player was moving when slide started
    var horizontal_velocity = Vector3(player.velocity.x, 0, player.velocity.z)
    
    if horizontal_velocity.length() > 0:
        slide_direction = horizontal_velocity.normalized()
    else:
        # Fallback to forward direction if somehow no velocity
        slide_direction = -player.transform.basis.z
    
    # Set initial slide speed based on current velocity
    var current_speed = horizontal_velocity.length()
    if state_machine.previous_state.name == "SprintingState":
        slide_speed = max(current_speed, slide_speed)
    # else: MVP
    #     slide_speed =  slide_speed * 0.3  # Reduced speed if not from sprint
    #     slide_duration = slide_duration *  0.3  # Shorter slide duration if not from sprint
    
    # Reset slide timer
    slide_timer = 0.0
    _animate_crouch(true)
    
    

func exit() -> void:
    pass


func update(delta: float) -> void:
    # Animate the crouch (faster than normal crouch)
    slide_timer += delta
    pass

func physics_update(delta: float) -> void:
    # Apply gravity
    if not player.is_on_floor():
        player.velocity.y -= player.gravity * delta
    
    # Calculate slide velocity with deceleration
    var current_slide_speed = slide_speed - (slide_friction * slide_timer)
    current_slide_speed = max(current_slide_speed, 0)
    
    # Apply slide movement
    player.velocity.x = slide_direction.x * current_slide_speed
    player.velocity.z = slide_direction.z * current_slide_speed
    
    # Optional: Very minimal air control during slide
    var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
    if input_dir.length() > 0:
        var input_direction = (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
        # Allow slight steering during slide (10% influence)
        slide_direction = slide_direction.lerp(input_direction, 0.1 * delta)
        slide_direction = slide_direction.normalized()
    
    player.move_and_slide()

func check_transitions() -> State:
    # Check for falling (went off edge while sliding)
    if not player.is_on_floor():
        return state_machine.get_state("FallingState")
    
    # Check if slide should end
    var current_slide_speed = slide_speed - (slide_friction * slide_timer)
    var should_end_slide = false
    
    # End slide if:
    # 1. Speed dropped below minimum
    if current_slide_speed < min_slide_speed:
        should_end_slide = true
    
    # 2. Maximum slide duration reached
    if slide_timer >= slide_duration:
        should_end_slide = true
    
    # 3. Player released crouch and can stand up
    if ((not Input.is_action_pressed("crouch") and not is_toggle_crouch )) and _can_stand_up() and slide_timer >= slide_duration:
        should_end_slide = true
    
    # 4. Player pressed jump to cancel slide
    if Input.is_action_just_pressed("jump"):
        _animate_crouch(false)
        return state_machine.get_state("JumpingState")
    
    if should_end_slide:
        # Check if still holding crouch
        if Input.is_action_pressed("crouch") or (is_toggle_crouch and not Input.is_action_just_pressed("crouch")):
            return state_machine.get_state("CrouchWalkingState")
        
        # Check if can stand up
        if _can_stand_up() and (is_toggle_crouch and Input.is_action_just_pressed("crouch") or not is_toggle_crouch):
            var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
            _animate_crouch(false)
            if input_dir.length() > 0.1:
                return state_machine.get_state("WalkingState")
            else:
                return state_machine.get_state("IdleState")
        else:
            # Can't stand, stay crouched
            return state_machine.get_state("CrouchWalkingState")
    
    return null

func _can_stand_up() -> bool:
    return headCast.is_colliding() == false

func _animate_crouch(is_crouching: bool) -> void:
    if is_crouching:
        player.anim_player.play("Sliding" , -1 , crouch_speed)
    else:
        player.anim_player.play("Crouching" , -1 , -crouch_speed , true)
