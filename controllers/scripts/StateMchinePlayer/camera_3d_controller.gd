# CameraController.gd
class_name CameraController
extends Node3D

## Modular camera controller with organized feature modules
## Each feature is self-contained and can be easily enabled/disabled

# ============================================================
# CORE REFERENCES
# ============================================================
@export_category("Core Setup")
@export_group("Node References")
@export var player: CharacterBody3D
@export var audio_component: PlayerAudioComponent
@export var camera_base: Node3D
@export var camera_offset: Node3D
@export var CAMERA_CONTROLLER: Camera3D
### self[camera_base[camera_offset[CAMERA_CONTROLLER]]] as childs of each others

# ============================================================
# FEATURE TOGGLES
# ============================================================
@export_category("Feature Toggles")
@export var enable_mouse_look: bool = true
@export var enable_controller_look: bool = true
@export var enable_head_bob: bool = true
@export var enable_leaning: bool = true
@export var enable_zoom: bool = true
@export var enable_fov_effects: bool = true
@export var enable_idle_shake: bool = true
@export var enable_fall_kick: bool = true
@export var enable_damage_kick: bool = true
@export var enable_screen_shake: bool = true
@export var enable_step_smoothing: bool = true
@export var enable_ladder_mode: bool = true
@export var static_camera_mode: bool = false
@export var climb_effects_enabled: bool = true  

# ============================================================
# INPUT SETTINGS
# ============================================================
@export_category("Input Settings")
@export_group("Sensitivity")
@export var MOUSE_SENSITIVITY: float = 0.5
@export var CONTROLLER_SENSITIVITY: float = 1.0
@export var zoom_sensitivity_multiplier: float = 0.4

# ============================================================
# CAMERA ROTATION LIMITS
# ============================================================
@export_category("Camera Rotation Limits")
@export_group("Tilt")
@export var TILT_LOWER_LIMIT := deg_to_rad(-90.0)
@export var TILT_UPPER_LIMIT := deg_to_rad(90.0)

@export_group("Locked Rotation Limits")
@export var LOCKED_YAW_LIMIT := deg_to_rad(60.0)      # Left/right max
@export var LOCKED_PITCH_LIMIT := deg_to_rad(30.0)    # Up/down max
@export var lock_vertical: bool = false

# ============================================================
# CAMERA MOVEMENT EFFECTS
# ============================================================
@export_category("Camera Movement Effects")

@export_group("Head Bob")
@export var BOB_FREQ: float = 2.4
@export var BOB_AMP: float = 0.08

@export_group("Field of View")
@export var BASE_FOV: float = 75.0
@export var FOV_CHANGE: float = 1.5

@export_group("Zoom")
@export var zoom_fov: float = 40.0
@export var zoom_toggle: bool = false  # true = toggle, false = hold

@export_group("Leaning")
@export var LEAN_AMOUNT: float = 0.3
@export var LEAN_SPEED: float = 8.0
@export var LEAN_ROLL_ANGLE: float = deg_to_rad(5.0)
@export var lean_camera_rot_limit := 45.0 # degrees
@export var lean_shape_cast_left: ShapeCast3D
@export var lean_shape_cast_right: ShapeCast3D

@export_group("Leaning Restrictions")
@export var resurrected_states_on_leaning := [
    "SprintingState", "SlidingState", "JumpingState",
    "FallingState", "ClimbLadderState", "DashState",
    "SwimmingState","SprintSwimmingState"
]
@export var resurrected_states_on_using := ["ClimbLadderState"]

@export_group("Auto Strafe Tilt")
@export var auto_strafe_intensity: float = 0.7
@export var dash_roll_intensity: float = deg_to_rad(8.0)

@export_group("Step Smoothing")
@export var step_smoothing_speed: float = 8.0

@export_group("Ladder Mode")
@export var ladder_locked_yaw_limit: float = 60.0  # Degrees left/right
@export var ladder_locked_pitch_limit: float = 30.0  # Degrees up/down
@export var ladder_transition_speed: float = 5.0  # How fast camera locks/unlocks
@export var ladder_climbing_states: Array[String] = ["ClimbLadderState"]

# ============================================================
# CAMERA SHAKE
# ============================================================
@export_category("Camera Shake")

@export_group("Idle Shake")
@export var SHAKE_INTENSITY_IDLE: float = 0.05
@export var SHAKE_FREQUENCY_IDLE: float = 6.0
@export var SHAKE_FADE_SPEED: float = 5.0
@export var SHAKE_RANDOMNESS: float = 0.3

@export_group("Quake Shake")
@export var MIN_SCREEN_SHAKE: float = 0.05
@export var MAX_SCREEN_SHAKE: float = 0.3

@export_category("Juicy Dash")
@export var dash_fov_transition_speed: float = 0.15 # Fast entry
@export var dash_fov_return_speed: float = 0.3 # Slower exit
@export var dash_tilt_transition_speed: float = 0.1
@export var dash_tilt_return_speed: float = 0.25

# ============================================================
# CAMERA KICK EFFECTS
# ============================================================
@export_category("Camera Kick Effects")

@export_group("Fall Kick")
@export var fall_time: float = 0.3

@export_group("Damage Kick")
@export var DAMAGE_KICK_DURATION: float = 0.3
@export var DAMAGE_KICK_BACK: float = 0.15
@export var DAMAGE_KICK_UP: float = 0.1
@export var DAMAGE_KICK_PITCH: float = 8.0
@export var DAMAGE_KICK_ROLL: float = 5.0

@export_group("Climb Effects")
@export var climb_bob_intensity: float = 0.05
@export var climb_bob_speed: float = 8.0
@export var climb_tilt_amount: float = 2.0 # Degrees to tilt down when pulling up

# ============================================================
# INTERNAL STATE - Don't expose these
# ============================================================
var _mouse_rotation: Vector3 = Vector3.ZERO
var locked_yaw_center: float = 0.0

# Input
var _rotation_input: float = 0.0
var _tilt_input: float = 0.0

# Ladder camera offset rotation
var _ladder_offset_yaw: float = 0.0
var _ladder_offset_pitch: float = 0.0

# Head bob
var t_bob: float = 0.0

# Zoom
var is_zoomed: bool = false

# Leaning
var current_lean: float = 0.0
var current_roll: float = 0.0
var _is_actively_leaning: bool = false
var _lean_yaw_center: float = 0.0

# Fall kick
var _fall_timer: float = 0.0
var _fall_value: float = 0.0

# Damage kick
var _damage_kick_timer: float = 0.0
var _damage_kick_offset: Vector3 = Vector3.ZERO
var _damage_kick_tilt: float = 0.0
var _damage_roll: float = 0.0

# Shake
var shake_strength: float = 0.0
var shake_time: float = 0.0
var _current_screen_shake_amount: float = 0.0
var _screen_shake_tween: Tween

# Step smoothing
var _step_target_height: float = 0.0
var _step_smoothing_active: bool = false
var offset_height: float = 0.0

# Ladder mode
var _is_on_ladder: bool = false
var _ladder_yaw_center: float = 0.0
var _ladder_transition_progress: float = 0.0
var _is_centering_to_ladder: bool = false
var _ladder_center_yaw_target: float = 0.0

# Dash directional roll
var _dash_direction_roll: float = 0.0
var _dash_direction_roll_timer: float = 0.0

# 🆕 New Dash Internal State
var _dash_roll_current: float = 0.0
var _dash_fov_multiplier: float = 1.0
var _dash_tween_tilt: Tween
var _dash_tween_fov: Tween

# Climb Juice
var _climb_offset_y: float = 0.0
var _climb_pitch_mod: float = 0.0
var _climb_roll_mod: float = 0.0

# ============================================================
# INITIALIZATION
# ============================================================
func _ready():
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# ============================================================
# INPUT HANDLING
# ============================================================
func _unhandled_input(event: InputEvent) -> void:
    if enable_mouse_look:
        if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
            _rotation_input = -event.relative.x * MOUSE_SENSITIVITY
            _tilt_input = -event.relative.y * MOUSE_SENSITIVITY

func _input(event):
    if event.is_action_pressed("exit"):
        get_tree().quit()
    if event.is_action_pressed("test"):
        add_screen_shake(1.0, 3.0)

# ============================================================
# MAIN UPDATE LOOP
# ============================================================
func _process(delta: float):
    if enable_zoom:
        _update_zoom()
    _update_camera(delta)

func _update_zoom() -> void:
    if Input.is_action_pressed("zoom"):
        if zoom_toggle:
            if Input.is_action_just_pressed("zoom"):
                is_zoomed = not is_zoomed
        else:
            is_zoomed = true
    else:
        if not zoom_toggle:
            is_zoomed = false

func _update_camera(delta: float):
    if not player or not CAMERA_CONTROLLER or not camera_offset:
        return
    
    # === STATIC MODE OVERRIDE ===
    if static_camera_mode:
        return

    var is_climbing = _is_climbing()
    var state_name = player.state_machine.get_current_state_name() if player.state_machine else ""
    
    # === ROTATION INPUT ===
    var yaw_input: float = 0.0
    var pitch_input: float = 0.0
    
    # Mouse input
    if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
        var zoom_factor = zoom_sensitivity_multiplier if is_zoomed else 1.0
        yaw_input = _rotation_input * zoom_factor
        pitch_input = _tilt_input * zoom_factor
    
    # Controller input
    if enable_controller_look and _is_controller_connected():
        var look_x = Input.get_axis("look_left", "look_right")
        var look_y = Input.get_axis("look_up", "look_down")
        yaw_input += -look_x * CONTROLLER_SENSITIVITY
        pitch_input += -look_y * CONTROLLER_SENSITIVITY
    
    # === HANDLE LADDER MODE ROTATION ===
    if lock_vertical:
        # Store input in ladder offset instead of main rotation
        _ladder_offset_yaw += yaw_input * delta
        _ladder_offset_pitch += pitch_input * delta
        
        # Clamp the ladder offset rotation
        _ladder_offset_pitch = clamp(_ladder_offset_pitch, -LOCKED_PITCH_LIMIT, LOCKED_PITCH_LIMIT)
        _ladder_offset_yaw = clamp(_ladder_offset_yaw, -LOCKED_YAW_LIMIT, LOCKED_YAW_LIMIT)
    else:
        # Apply input to main rotation
        _mouse_rotation.y += yaw_input * delta
        _mouse_rotation.x += pitch_input * delta
        _mouse_rotation.x = clamp(_mouse_rotation.x, TILT_LOWER_LIMIT, TILT_UPPER_LIMIT)
        
        # NEW: Enforce yaw clamp while actively leaning
        if _is_actively_leaning:
            var max_offset = deg_to_rad(45.0)
            var min_yaw = _lean_yaw_center - max_offset
            var max_yaw = _lean_yaw_center + max_offset
            _mouse_rotation.y = clamp(_mouse_rotation.y, min_yaw, max_yaw)
        
        # Smoothly reset ladder offset to zero when not on ladder
        var reset_speed = 8.0
        _ladder_offset_yaw = lerp(_ladder_offset_yaw, 0.0, delta * reset_speed)
        _ladder_offset_pitch = lerp(_ladder_offset_pitch, 0.0, delta * reset_speed)
        
        if abs(_ladder_offset_yaw) < 0.001:
            _ladder_offset_yaw = 0.0
        if abs(_ladder_offset_pitch) < 0.001:
            _ladder_offset_pitch = 0.0
    
    # === COLLECT ALL OFFSETS ===
    var total_offset = Vector3.ZERO
    var total_pitch_modifier = 0.0
    var total_roll = 0.0

    # We add this to the total roll calculation
    total_roll += _dash_roll_current

    # Head bob
    if enable_head_bob:
        var bob_speed_scale = float(player.is_on_floor() and not is_climbing)
        t_bob += delta * player.velocity.length() * bob_speed_scale
        total_offset += _calculate_headbob(t_bob)

        if audio_component:
            audio_component.process_footstep_sync(t_bob, BOB_FREQ, BOB_AMP, state_name)
    
    # Leaning
    if enable_leaning:
        _update_leaning(delta, state_name)
        total_offset += Vector3(current_lean, 0.0, 0.0)
        total_roll += current_roll
    
    # Fall kick
    if enable_fall_kick and _fall_timer > 0.0:
        _fall_timer -= delta
        var fall_ratio = _fall_timer / fall_time
        var fall_kick_amount = fall_ratio * _fall_value
        total_offset.y += -fall_kick_amount * 0.1
        total_pitch_modifier += -fall_kick_amount
    
    # Damage kick
    if enable_damage_kick and _damage_kick_timer > 0.0:
        _damage_kick_timer -= delta
        var ratio = _damage_kick_timer / DAMAGE_KICK_DURATION
        ratio = ratio * ratio  # ease-out
        total_offset += _damage_kick_offset * ratio
        total_pitch_modifier += _damage_kick_tilt * ratio
        total_roll += _damage_roll * ratio
    
    # Dash directional roll
    # if _dash_direction_roll_timer > 0.0:
    #     _dash_direction_roll_timer -= delta
    #     var roll_ratio = _dash_direction_roll_timer / dash_shake_duration
    #     total_roll += _dash_direction_roll * roll_ratio * roll_ratio
    
    # Screen shake
    if enable_screen_shake and _current_screen_shake_amount > 0.0:
        var h_offset = randf_range(-_current_screen_shake_amount, _current_screen_shake_amount)
        var v_offset = randf_range(-_current_screen_shake_amount, _current_screen_shake_amount)
        total_offset += Vector3(h_offset, v_offset, 0.0)
    
    # Idle shake
    if enable_idle_shake:
        var is_idle = (player.is_on_floor() and player.velocity.length() < 0.1 and state_name == "IdleState")
        var breath_intensity = SHAKE_INTENSITY_IDLE if is_idle else 0.0
        shake_strength = lerp(shake_strength, breath_intensity, delta * (3.0 if is_idle else SHAKE_FADE_SPEED))
        
        # Deterministic breathing — no randomness
        var breath_time = delta / 1000.0  # or use a local accumulator
        var breath_y = sin(breath_time * SHAKE_FREQUENCY_IDLE) * shake_strength * 0.8
        var breath_x = cos(breath_time * SHAKE_FREQUENCY_IDLE * 0.7) * shake_strength * 0.2  # subtle side sway

        # var is_idle = (player.is_on_floor() and player.velocity.length() < 0.1 and state_name == "IdleState")
        if is_idle:
            shake_strength = lerp(shake_strength, SHAKE_INTENSITY_IDLE, delta * 3.0)
        else:
            shake_strength = lerp(shake_strength, 0.0, delta * SHAKE_FADE_SPEED)
        
        var freq = SHAKE_FREQUENCY_IDLE if is_idle else 12.0
        total_offset += Vector3(breath_x, breath_y, 0.0)
        total_offset += _calculate_camera_shake(delta, shake_strength, freq)
    
    # TODO: More Emergent shake types can be added here
    # I = 0.01 ,F = 0.5 nervous shake when idle , S = 0.1 
    # I = 0.001 , F = 5.0 calm shake when moving , S = 0.1
    # we can lerp between them based on player state in state machine

    # Step smoothing
    if enable_step_smoothing and _step_smoothing_active:
        _step_target_height = lerp(_step_target_height, 0.0, step_smoothing_speed * delta)
        if abs(_step_target_height) < 0.01:
            _step_target_height = 0.0
            _step_smoothing_active = false
        total_offset.y += _step_target_height
    
    if climb_effects_enabled:
        total_offset.y += _climb_offset_y
        total_pitch_modifier += _climb_pitch_mod
        total_roll += _climb_roll_mod
        
    # === APPLY TRANSFORMS ===
    var player_rotation = Vector3(0.0, _mouse_rotation.y, 0.0)
    player.global_transform.basis = Basis.from_euler(player_rotation)
    
    camera_offset.rotation.y = _ladder_offset_yaw
    camera_offset.rotation.x = _ladder_offset_pitch
    
    var final_camera_pitch = _mouse_rotation.x + total_pitch_modifier
    final_camera_pitch = clamp(final_camera_pitch, TILT_LOWER_LIMIT, TILT_UPPER_LIMIT)
    
    CAMERA_CONTROLLER.transform.basis = Basis.from_euler(Vector3(final_camera_pitch, 0.0, 0.0))
    CAMERA_CONTROLLER.rotation.z = total_roll
    CAMERA_CONTROLLER.transform.origin = total_offset
    
    # FOV
    if enable_fov_effects:
        _update_fov(delta, state_name)
    
    # Reset input
    _rotation_input = 0.0
    _tilt_input = 0.0

# ============================================================
# HELPER FUNCTIONS
# ============================================================
func _calculate_headbob(time: float) -> Vector3:
    var pos = Vector3.ZERO
    pos.y = sin(time * BOB_FREQ) * BOB_AMP
    pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
    return pos

func _update_leaning(delta: float, state_name: String) -> void:
    var target_lean: float = 0.0
    var target_roll: float = 0.0
    var was_actively_leaning = _is_actively_leaning
    _is_actively_leaning = false

    # Manual leaning only – auto-strafe doesn't count
    if state_name not in resurrected_states_on_leaning:
        if Input.is_action_pressed("lean_left"):
            if not lean_shape_cast_left or not lean_shape_cast_left.is_colliding():
                target_lean = -LEAN_AMOUNT
                _is_actively_leaning = true
            target_roll = LEAN_ROLL_ANGLE
        elif Input.is_action_pressed("lean_right"):
            if not lean_shape_cast_right or not lean_shape_cast_right.is_colliding():
                target_lean = LEAN_AMOUNT
                _is_actively_leaning = true
            target_roll = -LEAN_ROLL_ANGLE

    # Auto strafe tilt (does not activate leaning restriction)
    var is_manually_leaning = Input.is_action_pressed("lean_left") or Input.is_action_pressed("lean_right")
    if player.is_on_floor() and not is_manually_leaning:
        var move_dir = Input.get_axis("move_left", "move_right")
        if move_dir != 0.0:
            target_roll = -move_dir * LEAN_ROLL_ANGLE * auto_strafe_intensity

    current_lean = lerp(current_lean, target_lean, delta * LEAN_SPEED)
    current_roll = lerp(current_roll, target_roll, delta * LEAN_SPEED)

    # Capture yaw center the moment leaning BEGINS
    if _is_actively_leaning and not was_actively_leaning:
        _lean_yaw_center = _mouse_rotation.y

func _calculate_camera_shake(delta: float, intensity: float, frequency: float) -> Vector3:
    if intensity <= 0.0:
        return Vector3.ZERO
    
    shake_time += delta * frequency
    var rand_x = (randf() - 0.5) * SHAKE_RANDOMNESS
    var rand_y = (randf() - 0.5) * SHAKE_RANDOMNESS
    var offset_x = sin(shake_time * 1.1 + rand_x) * intensity
    var offset_y = cos(shake_time * 1.3 + rand_y) * intensity
    return Vector3(offset_x, offset_y, 0.0)

func _update_fov(delta: float, state_name: String) -> void:
    var speed = max(0.5, player.velocity.length())
    var base_fov = lerp(BASE_FOV, zoom_fov, float(is_zoomed))
    
    # Standard speed-based FOV
    var target_fov = base_fov + FOV_CHANGE * clamp(speed, 0.5, player.SPEED * 2)
    
    # 🆕 2. APPLY DASH MULTIPLIER
    # Instead of checking "if state == Dash", we just multiply by our juice value
    target_fov *= _dash_fov_multiplier
    
    CAMERA_CONTROLLER.fov = lerp(CAMERA_CONTROLLER.fov, target_fov, delta * 8.0)

func _is_climbing() -> bool:
    if not player or not player.state_machine:
        return false
    return player.state_machine.get_current_state_name() in resurrected_states_on_using

func _is_controller_connected() -> bool:
    return (Input.is_action_pressed("look_left") or 
            Input.is_action_pressed("look_right") or 
            Input.is_action_pressed("look_up") or 
            Input.is_action_pressed("look_down"))

# ============================================================
# PUBLIC API - Call these from external scripts
# ============================================================
func add_fall_kick(fall_strength_degrees: float) -> void:
    if enable_fall_kick:
        _fall_value = deg_to_rad(fall_strength_degrees)
        _fall_timer = fall_time

func add_damage_kick(source_position: Vector3) -> void:
    if not enable_damage_kick or not player:
        return
    
    var hit_dir = (player.global_position - source_position).normalized()
    var forward = player.global_transform.basis.z
    var right = player.global_transform.basis.x
    
    var forward_dot = hit_dir.dot(forward)
    var right_dot = hit_dir.dot(right)
    
    _damage_kick_tilt = deg_to_rad(DAMAGE_KICK_PITCH) * forward_dot
    _damage_roll = deg_to_rad(DAMAGE_KICK_ROLL) * right_dot
    
    var local_back = -DAMAGE_KICK_BACK * Vector3(0, 0, 1)
    var world_back = player.global_transform.basis * local_back
    var upward = Vector3(0, DAMAGE_KICK_UP, 0)
    
    _damage_kick_offset = world_back + upward
    _damage_kick_timer = DAMAGE_KICK_DURATION

func add_screen_shake(amount: float, seconds: float) -> void:
    if not enable_screen_shake:
        return
    
    amount = clamp(amount, 0.0, 1.0)
    
    if _screen_shake_tween:
        _screen_shake_tween.kill()
    
    _screen_shake_tween = create_tween()
    _screen_shake_tween.tween_method(
        func(alpha: float):
            var current_shake = amount * (1.0 - alpha)
            _current_screen_shake_amount = remap(current_shake, 0.0, 1.0, MIN_SCREEN_SHAKE, MAX_SCREEN_SHAKE),
        0.0, 1.0, seconds
    ).set_ease(Tween.EASE_OUT)
    _screen_shake_tween.finished.connect(func(): _current_screen_shake_amount = 0.0)

func smooth_step(height_change: float) -> void:
    if enable_step_smoothing:
        _step_target_height -= height_change
        _step_smoothing_active = true

func enter_ladder_mode(ladder_forward_direction: Vector3 = Vector3.ZERO) -> void:
    if not enable_ladder_mode:
        return
    if ladder_forward_direction != Vector3.ZERO:
        var ladder_angle = atan2(ladder_forward_direction.x, ladder_forward_direction.z)
        _ladder_yaw_center = ladder_angle
    else:
        _ladder_yaw_center = _mouse_rotation.y
    _is_on_ladder = true
    _ladder_transition_progress = 0.0

func exit_ladder_mode() -> void:
    _is_on_ladder = false

func process_climb_feedback(delta: float, velocity: Vector3, is_vertical_phase: bool) -> void:
    # 1. Vertical Phase (Pulling Up)
    if is_vertical_phase:
        # Create a "struggle" sine wave
        var bob = sin(Time.get_ticks_msec() * 0.01) * climb_bob_intensity
        
        # Lag the camera down slightly as we go up (implies weight)
        var upward_force = velocity.y * 0.02
        _climb_offset_y = lerp(_climb_offset_y, -upward_force + bob, delta * 5.0)
        
        # Tilt head down slightly to look at hands/ledge
        _climb_pitch_mod = lerp(_climb_pitch_mod, deg_to_rad(-climb_tilt_amount), delta * 4.0)
        _climb_roll_mod = lerp(_climb_roll_mod, 0.0, delta * 5.0)
        
    # 2. Horizontal Phase (Mantling)
    else:
        # Reset vertical offset
        _climb_offset_y = lerp(_climb_offset_y, 0.0, delta * 8.0)
        
        # Pitch head up slightly as we crest the edge
        _climb_pitch_mod = lerp(_climb_pitch_mod, deg_to_rad(climb_tilt_amount * 0.5), delta * 4.0)
        
        # Slight roll to simulate stepping one leg up
        _climb_roll_mod = lerp(_climb_roll_mod, deg_to_rad(1.5), delta * 4.0)

func reset_climb_feedback() -> void:
    # Snap back or smooth back
    _climb_offset_y = 0.0
    _climb_pitch_mod = 0.0
    _climb_roll_mod = 0.0

# ============================================================
# 🆕 NEW PUBLIC API (Called by DashState)
# ============================================================

## 1. TILT (Dutch Angle)
## Called when dash starts to tilt camera left/right
func trigger_dash_tilt(angle_degrees: float, _duration: float) -> void:
    if _dash_tween_tilt: _dash_tween_tilt.kill()
    _dash_tween_tilt = create_tween()
    
    # Tween to the angle quickly using Cubic Ease Out for a "Snap" feel
    _dash_tween_tilt.tween_property(
        self, 
        "_dash_roll_current", 
        deg_to_rad(angle_degrees), 
        dash_tilt_transition_speed
    ).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

## Called when dash ends to smooth back to 0
func reset_dash_tilt() -> void:
    if _dash_tween_tilt: _dash_tween_tilt.kill()
    _dash_tween_tilt = create_tween()
    
    # Return to 0 slowly for a smooth settlement
    _dash_tween_tilt.tween_property(
        self, 
        "_dash_roll_current", 
        0.0, 
        dash_tilt_return_speed
    ).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

## 2. FOV (Warp Speed)
## Called to punch the FOV out
func set_dash_fov(multiplier: float) -> void:
    if _dash_tween_fov: _dash_tween_fov.kill()
    _dash_tween_fov = create_tween()
    
    _dash_tween_fov.tween_property(
        self,
        "_dash_fov_multiplier",
        multiplier,
        dash_fov_transition_speed
    ).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)

## Called to return FOV to normal
func reset_dash_fov() -> void:
    if _dash_tween_fov: _dash_tween_fov.kill()
    _dash_tween_fov = create_tween()
    
    _dash_tween_fov.tween_property(
        self,
        "_dash_fov_multiplier",
        1.0,
        dash_fov_return_speed
    ).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

## 3. SHAKE (Impact)
func trigger_dash_shake(intensity: float = 0.4, duration: float = 0.2) -> void:
    # High frequency shake for dash feels more energetic
    SHAKE_FREQUENCY_IDLE = 20.0 
    add_screen_shake(intensity, duration)
    # Reset frequency after a moment (handled in update loop logic mostly, 
    # but strictly we should reset it here via timer or just use a separate shake var. 
    # For now, standard shake is fine)