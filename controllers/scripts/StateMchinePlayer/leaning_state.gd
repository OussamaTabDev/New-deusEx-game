class_name DashState
extends State

# ⚙️ Movement Settings
@export_group("Dash Physics")
@export var dash_duration: float = 0.3
@export var dash_speed_curve: Curve # Create a Curve in Inspector! (High at 0.0, Low at 1.0)
@export var base_dash_speed: float = 25.0
@export var dash_gravity_modifier: float = 0.1 # 10% gravity during dash (floaty feel)
@export var exit_friction: float = 4.0 # How much to slow down when dash ends

# 🎯 Direction Settings
@export_group("Direction")
@export var enable_8_direction: bool = true 
@export var default_direction: String = "forward"

# 🎥 Camera Juice
@export_group("Camera Juice")
@export var fov_multiplier: float = 1.15 # Slight zoom out
@export var tilt_angle: float = 2.0 # Degrees to tilt

var elapsed_time: float = 0.0
var dash_vector: Vector3 = Vector3.ZERO
var initial_gravity: float = 0.0

func enter() -> void:
    elapsed_time = 0.0
    
    # 1. Determine Direction
    if enable_8_direction:
        dash_vector = _get_input_direction()
    else:
        dash_vector = _get_default_direction()
        
    # If no input was pressed, ensure we don't dash in place (default to model forward)
    if dash_vector == Vector3.ZERO:
        dash_vector = -player.transform.basis.z

    # 2. Reset Vertical Velocity for a "snappy" ground dash
    # If on ground, we keep y zero. If in air, we allow a tiny bit or zero it out.
    player.velocity.y = 0 

    # 3. 🎥 Trigger Juice (Shake, FOV, Tilt)
    _trigger_camera_effects(true)

func physics_update(delta: float) -> void:
    elapsed_time += delta
    
    # Calculate progress (0.0 to 1.0)
    var progress = clamp(elapsed_time / dash_duration, 0.0, 1.0)
    
    # 4. Apply Curve-based Speed
    # If no curve is assigned, default to linear 1.0 -> 0.0
    var speed_multiplier = 1.0
    if dash_speed_curve:
        speed_multiplier = dash_speed_curve.sample(progress)
    else:
        speed_multiplier = 1.0 - progress # Fallback linear ease-out
        
    var current_speed = base_dash_speed * speed_multiplier
    
    # Apply horizontal velocity
    player.velocity.x = dash_vector.x * current_speed
    player.velocity.z = dash_vector.z * current_speed
    
    # 5. Gravity Suspension (Floaty feel)
    # Modern games reduce gravity during dash so you don't fall off ledges immediately
    if not player.is_on_floor():
        player.velocity.y -= (player.gravity * dash_gravity_modifier) * delta

    player.move_and_slide()

func exit() -> void:
    # 6. Apply "Braking" friction
    # This prevents the player from sliding on ice when the dash state ends
    player.velocity.x = move_toward(player.velocity.x, 0, exit_friction)
    player.velocity.z = move_toward(player.velocity.z, 0, exit_friction)
    
    # Reset Camera
    _trigger_camera_effects(false)

func check_transitions() -> State:
    if elapsed_time >= dash_duration:
        if state_machine.previous_state and state_machine.previous_state.name == "CrouchWalkingState":
            return state_machine.get_state("CrouchWalkingState")
            
        if not player.is_on_floor():
            return state_machine.get_state("FallingState")
        else:
            return state_machine.get_state("IdleState")
    return null

# --- Helpers ---

func _trigger_camera_effects(active: bool) -> void:
    if not player.has_method("get_camera_controller"):
        return
        
    var cam = player.get_camera_controller()
    if not cam:
        return

    if active:
        # 1. Existing Shake
        if cam.has_method("trigger_dash_shake"):
            cam.trigger_dash_shake(0.05, 0.2)
        
        # 2. FOV Zoom (Optional method check)
        if cam.has_method("set_dash_fov"):
            cam.set_dash_fov(fov_multiplier)

        # 3. TILT (The specific request)
        # We calculate tilt direction based on the dash vector relative to camera right
        if cam.has_method("trigger_dash_tilt"):
            # Determine if we are dashing Left or Right relative to camera
            var cam_basis = cam.global_transform.basis
            var dot = dash_vector.dot(cam_basis.x)
            
            # If dot is positive, we are dashing right (Negative Tilt)
            # If dot is negative, we are dashing left (Positive Tilt)
            var dir_sign = -1.0 if dot > 0 else 1.0
            
            # If dashing forward/back, dot is near 0, so tilt is 0
            if abs(dot) < 0.2: 
                dir_sign = 0.0
                
            cam.trigger_dash_tilt(tilt_angle * dir_sign, dash_duration)
            
    else:
        # Reset effects
        if cam.has_method("reset_dash_fov"):
            cam.reset_dash_fov()
        if cam.has_method("reset_dash_tilt"):
            cam.reset_dash_tilt()

func _get_default_direction() -> Vector3:
    match default_direction:
        "forward": return -player.transform.basis.z
        "backward": return player.transform.basis.z
        "left": return -player.transform.basis.x
        "right": return player.transform.basis.x
        _: return player.transform.basis.z

func _get_input_direction() -> Vector3:
    var input_x = Input.get_axis("move_left", "move_right")
    var input_z = Input.get_axis("move_forward", "move_backward")
    var local_dir = Vector3(input_x, 0, input_z).normalized()
    return player.transform.basis * local_dir