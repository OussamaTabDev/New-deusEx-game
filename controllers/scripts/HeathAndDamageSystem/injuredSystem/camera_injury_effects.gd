class_name CameraInjuryEffects
extends Node

## Modular camera injury system with "Juicy" procedural animation
## Uses Perlin noise and weighted curves for organic, visceral responses.

# ============================================================
# SIGNALS
# ============================================================
signal injury_effect_started(effect_type: String)
signal injury_effect_ended(effect_type: String)
signal concussion_pulse()

# ============================================================
# EXPORTS - REFERENCES
# ============================================================
@export_category("Core References")
@export var camera_controller: Node3D # Generic reference to support different controller types
@export var health_component: Node # Generic reference
@export var camera_3d: Camera3D
@export var post_process_layer: CanvasLayer

# ============================================================
# EXPORTS - ANIMATION FEEL (THE JUICE)
# ============================================================
@export_category("Animation Feel")
@export_range(0.1, 10.0) var noise_speed_scale: float = 1.0
@export_range(0.0, 1.0) var smoothing_factor: float = 0.15 # Lower is snappier, higher is floatier
@export var trauma_decay: float = 0.8 # How fast shake settles

# ============================================================
# EXPORTS - HEAD INJURY EFFECTS
# ============================================================
@export_category("Head Injury Effects")
@export_group("Vision Blur")
@export var enable_vision_blur: bool = true
@export var blur_start_threshold: float = 0.5
@export var max_blur_amount: float = 2.0
@export var blur_pulse_speed: float = 1.5

@export_group("Color Desaturation")
@export var enable_desaturation: bool = true
@export var desat_start_threshold: float = 0.3
@export var max_desaturation: float = 0.8

@export_group("Tunnel Vision")
@export var enable_tunnel_vision: bool = true
@export var tunnel_start_threshold: float = 0.25
@export var tunnel_max_strength: float = 0.6

@export_group("Concussion")
@export var enable_concussion: bool = true
@export var concussion_threshold: float = 0.3
@export var concussion_duration: float = 4.0
@export var concussion_sway_amount: float = 2.0 # Degrees of drunken sway
@export var concussion_noise_speed: float = 0.5

# ============================================================
# EXPORTS - TORSO INJURY EFFECTS
# ============================================================
@export_category("Torso Injury Effects")
@export_group("Breathing")
@export var enable_breathing_effects: bool = true
@export var breathing_fov_change: float = 1.5
@export var breathing_base_freq: float = 0.8
@export var heavy_breathing_threshold: float = 0.6

@export_group("Blood Loss")
@export var enable_blood_vignette: bool = true
@export var blood_vignette_color: Color = Color(0.5, 0.0, 0.0, 0.8)
@export var blood_pulse_speed: float = 2.0
@export var max_blood_vignette: float = 0.7

@export_group("Weakness Sway")
@export var enable_weakness_sway: bool = true
@export var weakness_sway_amount: float = 0.05
@export var weakness_sway_speed: float = 0.8

# ============================================================
# EXPORTS - ARM INJURY EFFECTS
# ============================================================
@export_category("Arm Injury Effects")
@export_group("Weapon Sway")
@export var enable_arm_sway: bool = true
@export var arm_sway_multiplier: float = 2.5
@export var arm_tremor_frequency: float = 12.0 # High freq for muscle spasms

@export_group("Aim Drift")
@export var enable_aim_drift: bool = true
@export var aim_drift_speed: float = 0.5
@export var max_aim_drift: float = 3.0

@export_group("Recoil Amplification")
@export var enable_recoil_amplification: bool = true
@export var recoil_multiplier_damaged: float = 1.8

# ============================================================
# EXPORTS - LEG INJURY EFFECTS
# ============================================================
@export_category("Leg Injury Effects")
@export_group("Limping Camera")
@export var enable_limp_bob: bool = true
@export var limp_bob_intensity: float = 0.2
@export var limp_bob_frequency: float = 1.4
@export var limp_sharpness: float = 4.0 # Higher = sharper dip (more painful look)

@export_group("Stumble")
@export var enable_stumble: bool = true
@export var stumble_chance: float = 0.1
@export var stumble_intensity: float = 0.4
@export var stumble_recovery_speed: float = 3.0

@export_group("Crawling Camera")
@export var enable_crawl_mode: bool = true
@export var crawl_camera_height: float = 0.6
@export var crawl_transition_speed: float = 2.0

# ============================================================
# EXPORTS - CRITICAL STATE EFFECTS
# ============================================================
@export_category("Critical State Effects")
@export_group("Near Death")
@export var enable_near_death_effects: bool = true
@export var near_death_fade_speed: float = 0.5
@export var near_death_fade_color: Color = Color.BLACK

@export_group("Heartbeat")
@export var enable_heartbeat_camera: bool = true
@export var heartbeat_fov_pulse: float = 3.0
@export var heartbeat_position_pulse: float = 0.03

# ============================================================
# INTERNAL STATE
# ============================================================
# Noise generator for organic movement
var _noise: FastNoiseLite = FastNoiseLite.new()
var _noise_time: float = 0.0

# Smooth Vectors
var _final_offset: Vector3 = Vector3.ZERO
var _final_rotation: Vector3 = Vector3.ZERO # Euler angles
var _current_offset_velocity: Vector3 = Vector3.ZERO # For smoothing
var _current_rot_velocity: Vector3 = Vector3.ZERO # For smoothing

# Effect Intensities
var _current_effects: Dictionary = {
    "blur": 0.0,
    "desaturation": 0.0,
    "tunnel_vision": 0.0,
    "blood_vignette": 0.0,
    "aim_sway": 0.0,
    "limp_bob": 0.0,
    "crawl_offset": 0.0,
    "near_death_fade": 0.0
}

# Concussion
var _concussion_active: bool = false
var _concussion_timer: float = 0.0
var _concussion_trauma: float = 0.0 # 0 to 1, fades out

# Breathing & Heartbeat
var _breathing_phase: float = 0.0
var _heartbeat_pulse: float = 0.0
var _last_heartbeat_time: float = 0.0

# Stumble
var _stumble_timer: float = 0.0
var _stumble_vector: Vector3 = Vector3.ZERO

# Aim Drift
var _aim_drift_accumulated: Vector2 = Vector2.ZERO

# Crawling
var _is_crawling: bool = false
var _crawl_height_offset: float = 0.0

# Health Cache
var _head_health: float = 1.0
var _torso_health: float = 1.0
var _left_arm_health: float = 1.0
var _right_arm_health: float = 1.0
var _left_leg_health: float = 1.0
var _right_leg_health: float = 1.0
var _arm_avg_health: float = 1.0
var _leg_avg_health: float = 1.0

# ============================================================
# INITIALIZATION
# ============================================================
func _ready():
    # Setup Noise for organic shakes
    _noise.seed = randi()
    _noise.frequency = 0.5
    _noise.fractal_type = FastNoiseLite.FRACTAL_FBM
    _noise.fractal_octaves = 3

    if not camera_controller:
        # Try to find parent if not assigned
        var parent = get_parent()
        if parent: camera_controller = parent
    
    # Try to find camera if not assigned
    if not camera_3d:
        if camera_controller and camera_controller.has_method("get_camera"):
            camera_3d = camera_controller.get_camera()
        elif camera_controller and "camera" in camera_controller:
            camera_3d = camera_controller.camera
    
    if health_component:
        _connect_health_signals()
    else:
        push_warning("CameraInjuryEffects: No health_component assigned!")

func _connect_health_signals():
    if health_component.has_signal("limb_damaged"):
        health_component.limb_damaged.connect(_on_limb_damaged)
    if health_component.has_signal("limb_critical"):
        health_component.limb_critical.connect(_on_limb_critical)
    if health_component.has_signal("state_changed"):
        health_component.state_changed.connect(_on_health_state_changed)
    if health_component.has_signal("health_changed"):
        health_component.health_changed.connect(_on_health_changed)

# ============================================================
# MAIN UPDATE LOOP
# ============================================================
func _process(delta: float):
    if not health_component or not camera_3d:
        return
    
    _noise_time += delta * noise_speed_scale
    _update_health_cache()
    
    # Calculate all target values
    _update_all_effects(delta)
    
    # Apply to Camera with Smoothing
    _apply_effects_to_camera_smooth(delta)

func _update_health_cache():
    # Assumes HealthComponent has get_limb_health_percent(enum)
    # Using generic calls or property access for modularity
    if health_component.has_method("get_limb_health_percent"):
        _head_health = health_component.get_limb_health_percent(0) # HEAD
        _torso_health = health_component.get_limb_health_percent(1) # TORSO
        _left_arm_health = health_component.get_limb_health_percent(2)
        _right_arm_health = health_component.get_limb_health_percent(3)
        _left_leg_health = health_component.get_limb_health_percent(4)
        _right_leg_health = health_component.get_limb_health_percent(5)
    
    _arm_avg_health = (_left_arm_health + _right_arm_health) / 2.0
    _leg_avg_health = (_left_leg_health + _right_leg_health) / 2.0

func _update_all_effects(delta: float):
    # Update Timers
    if _concussion_active:
        _concussion_timer -= delta
        if _concussion_timer <= 0:
            _concussion_active = false
            _concussion_trauma = 0.0
        else:
            # Trauma fades out
            _concussion_trauma = clamp(_concussion_timer / concussion_duration, 0.0, 1.0)
            
    if _stumble_timer > 0:
        _stumble_timer -= delta
    
    # HEAD
    _update_vision_blur(delta)
    _update_desaturation(delta)
    _update_tunnel_vision(delta)
    
    # TORSO
    _update_breathing(delta)
    _update_blood_vignette(delta)
    _update_heartbeat(delta)
    
    # ARMS
    _update_arm_sway(delta)
    _update_aim_drift(delta)
    
    # LEGS
    _update_limp_bob(delta)
    _update_crawl_mode(delta)
    _update_stumble(delta) # Logic update
    
    # CRITICAL
    _update_near_death(delta)

# ============================================================
# EFFECT LOGIC (CALCULATIONS)
# ============================================================

func _update_vision_blur(delta: float):
    if not enable_vision_blur: return
    var target = 0.0
    if _head_health < blur_start_threshold:
        var ratio = 1.0 - (_head_health / blur_start_threshold)
        # Use smoothstep for nicer curve
        target = smoothstep(0.0, 1.0, ratio) * max_blur_amount
        # Add pulsing noise
        if _head_health < 0.2:
            target += (sin(_noise_time * blur_pulse_speed) * 0.5 + 0.5) * 0.5
    
    _current_effects.blur = lerp(_current_effects.blur, target, delta * 3.0)

func _update_desaturation(delta: float):
    if not enable_desaturation: return
    var target = 0.0
    if _head_health < desat_start_threshold or _torso_health < 0.3:
        var h_factor = 1.0 - (_head_health / desat_start_threshold)
        var t_factor = 1.0 - (_torso_health / 0.3)
        target = max(h_factor, t_factor) * max_desaturation
    
    _current_effects.desaturation = lerp(_current_effects.desaturation, target, delta * 2.0)

func _update_tunnel_vision(delta: float):
    if not enable_tunnel_vision: return
    var target = 0.0
    if _head_health < tunnel_start_threshold:
        target = (1.0 - (_head_health / tunnel_start_threshold)) * tunnel_max_strength
        # Add slight noise to tunnel size to make it feel unstable
        target += _noise.get_noise_1d(_noise_time * 10.0) * 0.05
    
    _current_effects.tunnel_vision = lerp(_current_effects.tunnel_vision, target, delta * 2.0)

func _update_breathing(delta: float):
    if not enable_breathing_effects: return
    
    # Calculate Breathing Speed & Depth based on health
    var breath_speed = breathing_base_freq
    var breath_depth = 1.0
    
    if _torso_health < heavy_breathing_threshold:
        var stress = 1.0 - (_torso_health / heavy_breathing_threshold)
        breath_speed += stress * 1.5
        breath_depth += stress * 1.0 # Breaths get deeper
    
    _breathing_phase += delta * breath_speed * TAU
    
    # JUICE: Use a shaped sine wave for "heaving" chest feel
    # sin(x)^2 creates a sharper "inhale/exhale" pause
    # Adding a second offset sine wave adds organic irregularity
    var raw_breath = sin(_breathing_phase)
    var organic_breath = (raw_breath + sin(_breathing_phase * 2.1) * 0.2) * 0.5
    
    # Store for application
    _current_effects.breath_val = organic_breath * breath_depth

func _update_blood_vignette(delta: float):
    if not enable_blood_vignette: return
    var target = 0.0
    
    # Check bleeding if system exists
    var is_bleeding = false
    if health_component.has_method("is_bleeding"):
        is_bleeding = health_component.is_bleeding()
    
    if is_bleeding or _torso_health < 0.4:
        target = (1.0 - _torso_health) * max_blood_vignette
        # Pulse based on heartbeat
        var pulse = sin(_noise_time * blood_pulse_speed) * 0.5 + 0.5
        target *= (0.8 + pulse * 0.2)
        
    _current_effects.blood_vignette = lerp(_current_effects.blood_vignette, target, delta * 2.0)

func _update_heartbeat(delta: float):
    if not enable_heartbeat_camera: return
    var hp_pct = health_component.get_total_health_percent() if health_component.has_method("get_total_health_percent") else 1.0
    
    if hp_pct < 0.3:
        # Faster beat as health gets lower
        var beat_speed = remap(hp_pct, 0.3, 0.0, 1.0, 3.0)
        _heartbeat_pulse += delta * beat_speed * TAU
    else:
        _heartbeat_pulse = 0.0

func _update_arm_sway(delta: float):
    if not enable_arm_sway: return
    var target = 0.0
    if _arm_avg_health < 0.6:
        target = (1.0 - (_arm_avg_health / 0.6)) * arm_sway_multiplier
        
    _current_effects.aim_sway = lerp(_current_effects.aim_sway, target, delta * 4.0)

func _update_aim_drift(delta: float):
    if not enable_aim_drift: return
    
    if _arm_avg_health < 0.5:
        # Use Perlin Noise for smoother, wandering drift instead of random lerps
        var drift_intensity = 1.0 - (_arm_avg_health / 0.5)
        var time_scale = _noise_time * aim_drift_speed
        
        # 2D Noise lookup
        var nx = _noise.get_noise_2d(time_scale, 0.0)
        var ny = _noise.get_noise_2d(0.0, time_scale)
        
        var target_drift = Vector2(nx, ny) * max_aim_drift * drift_intensity
        _aim_drift_accumulated = _aim_drift_accumulated.lerp(target_drift, delta * 1.0)
    else:
        _aim_drift_accumulated = _aim_drift_accumulated.lerp(Vector2.ZERO, delta * 2.0)

func _update_limp_bob(delta: float):
    if not enable_limp_bob:
        _current_effects.limp_bob = 0.0
        return
        
    # Check player movement
    var player = camera_controller.get_parent() # Assuming controller is on player
    if not player or not (player is CharacterBody3D or player is RigidBody3D):
        return
        
    var velocity_len = player.velocity.length()
    var is_moving = velocity_len > 0.5 and player.is_on_floor()
    var is_limping = _leg_avg_health < 0.6
    
    if is_limping and is_moving:
        var limp_severity = 1.0 - _leg_avg_health
        var freq = limp_bob_frequency * (velocity_len / 4.0) # Scale with speed
        
        # JUICE: Use a power function to make the dip sharp and recovery slow
        # abs(sin) gives bounces. pow() sharpens the curve.
        var wave = abs(sin(_noise_time * freq * 3.0)) 
        wave = pow(wave, limp_sharpness) # Sharp impact
        
        # Invert so it's a dip
        var bob = -wave * limp_bob_intensity * limp_severity
        
        _current_effects.limp_bob = bob
    else:
        _current_effects.limp_bob = lerp(_current_effects.limp_bob, 0.0, delta * 5.0)

func _update_stumble(delta: float):
    if not enable_stumble: return
    
    # Recovery from stumble
    if _stumble_timer <= 0:
        # Spring back to zero
        _stumble_vector = _stumble_vector.lerp(Vector3.ZERO, delta * stumble_recovery_speed)
        return

    # Random stumble check is in logic update, this handles the visual vector
    # We leave _stumble_vector as set by trigger, letting it decay above

    # Chance to trigger new stumble if moving fast on bad legs
    var player = camera_controller.get_parent()
    if player and player.is_on_floor() and player.velocity.length() > 3.0 and _leg_avg_health < 0.4:
        if randf() < stumble_chance * delta:
            _trigger_stumble()

func _update_crawl_mode(delta: float):
    if not enable_crawl_mode: return
    
    var should_crawl = (_left_leg_health <= 0.0 and _right_leg_health <= 0.0)
    
    if should_crawl != _is_crawling:
        _is_crawling = should_crawl
        if _is_crawling:
            injury_effect_started.emit("crawl_mode")
        else:
            injury_effect_ended.emit("crawl_mode")
            
    var target = -crawl_camera_height if _is_crawling else 0.0
    _current_effects.crawl_offset = lerp(_current_effects.crawl_offset, target, delta * crawl_transition_speed)

func _update_near_death(delta: float):
    if not enable_near_death_effects: return
    var hp = health_component.get_total_health_percent() if health_component.has_method("get_total_health_percent") else 1.0
    var target = 0.0
    
    if hp < 0.15:
        target = (1.0 - (hp / 0.15)) * 0.95
        
    _current_effects.near_death_fade = lerp(_current_effects.near_death_fade, target, delta * near_death_fade_speed)

# ============================================================
# COMPOSITION & APPLICATION
# ============================================================
func _apply_effects_to_camera_smooth(delta: float):
    # We compose all offsets into a single target Vector3 and Rotation Vector3
    # Then smooth damp them for that "Cinematic/Juicy" feel.
    
    var target_pos = Vector3.ZERO
    var target_rot = Vector3.ZERO # Euler
    
    # 1. BREATHING (Vertical + slight roll)
    if enable_breathing_effects:
        var b_val = _current_effects.get("breath_val", 0.0)
        target_pos.y += b_val * 0.05
        target_rot.z += b_val * 0.2 * deg_to_rad(1.0) # Slight roll with breath
        
        # FOV Breathing
        camera_3d.fov = lerp(camera_3d.fov, 75.0 + (b_val * breathing_fov_change), delta * 2.0)
    
    # 2. WEAKNESS SWAY (Noise based)
    if enable_weakness_sway and _torso_health < 0.5:
        var sway_mag = (1.0 - _torso_health / 0.5) * weakness_sway_amount
        # 3D Noise movement
        var nx = _noise.get_noise_2d(_noise_time * weakness_sway_speed, 10.0)
        var ny = _noise.get_noise_2d(_noise_time * weakness_sway_speed, 20.0)
        target_pos.x += nx * sway_mag
        target_pos.y += ny * sway_mag
        
        # Rotational drag
        target_rot.z += nx * sway_mag * 0.5 # Roll into sway
    
    # 3. CONCUSSION (Drunken Tilt + Noise)
    if _concussion_active:
        # Slow heavy sway
        var c_sway = sin(_noise_time * concussion_noise_speed) * concussion_sway_amount * _concussion_trauma
        target_rot.z += deg_to_rad(c_sway)
        
        # Vision blur double vision effect handled in shader usually, but we can offset pos
        target_pos.x += cos(_noise_time) * 0.05 * _concussion_trauma
        
    # 4. ARM TREMOR (High freq noise)
    if _current_effects.aim_sway > 0.0:
        var tremor_speed = arm_tremor_frequency
        var tx = _noise.get_noise_1d(_noise_time * tremor_speed)
        var ty = _noise.get_noise_1d((_noise_time * tremor_speed) + 100.0)
        
        var shake = _current_effects.aim_sway * 0.005 # Small positional jitter
        target_pos += Vector3(tx, ty, 0) * shake
        
        target_rot.x += deg_to_rad(ty * _current_effects.aim_sway)
        target_rot.y += deg_to_rad(tx * _current_effects.aim_sway)
        
    # 5. AIM DRIFT
    target_rot.x += deg_to_rad(_aim_drift_accumulated.y)
    target_rot.y += deg_to_rad(_aim_drift_accumulated.x)
    
    # 6. LIMP BOB (Vertical Dip)
    target_pos.y += _current_effects.limp_bob
    
    # 7. STUMBLE (Large impact)
    target_pos += _stumble_vector
    # Add tilt to stumble
    target_rot.z += -_stumble_vector.x * 0.5 # Bank into stumble
    target_rot.x += -_stumble_vector.z * 0.5 # Pitch into stumble
    
    # 8. CRAWL
    target_pos.y += _current_effects.crawl_offset
    
    # 9. HEARTBEAT (FOV Pulse + Positional Jerk)
    if _heartbeat_pulse > 0.0:
        # Sharp heartbeat curve: 1.0 - abs(sin) is smooth, we want sharp beat
        # Use a sawtooth-like modification of sine
        var beat = sin(_heartbeat_pulse)
        beat = pow(max(0.0, beat), 10.0) # Sharp spikes only
        
        target_pos.z += beat * heartbeat_position_pulse # Jerk forward/back
        camera_3d.fov += beat * heartbeat_fov_pulse
    
    # --- FINAL SMOOTHING APPLICATION ---
    # We use SmoothDamp (approximated here via lerp with variable delta)
    # for "Juicy" fluid motion.
    
    # Position
    _final_offset = _final_offset.lerp(target_pos, delta * (1.0 / smoothing_factor))
    
    # Rotation
    _final_rotation = _final_rotation.lerp(target_rot, delta * (1.0 / smoothing_factor))
    
    # Apply to Camera
    # Note: We assume the camera has a base position of (0,0,0) locally.
    # If not, you should store base_pos in _ready.
    camera_3d.position = _final_offset
    camera_3d.rotation = _final_rotation

# ============================================================
# EVENT TRIGGERS
# ============================================================
func _trigger_stumble():
    _stumble_timer = stumble_recovery_speed
    
    # Random direction stumble
    var angle = randf() * TAU
    var strength = stumble_intensity
    
    _stumble_vector = Vector3(cos(angle), -0.2, sin(angle)) * strength
    
    # Screen shake
    if camera_controller and camera_controller.has_method("add_screen_shake"):
        camera_controller.add_screen_shake(0.5, 0.4)

func _trigger_concussion():
    if _concussion_active: return
    _concussion_active = true
    _concussion_timer = concussion_duration
    _concussion_trauma = 1.0
    injury_effect_started.emit("concussion")
    concussion_pulse.emit()

func _on_limb_damaged(limb_idx: int, damage: float, type: int):
    # Trigger concussion on head damage
    if limb_idx == 0 and damage >= concussion_threshold * 100.0 and enable_concussion: # Assuming dmg is raw
        _trigger_concussion()
        
    # Add punch/kick to camera on any damage
    # Just displace the target momentarily
    var kick_dir = Vector3(randf()-0.5, randf()-0.5, randf()-0.5).normalized()
    _final_offset += kick_dir * 0.1 # Instant displacement that smooths back

func _on_limb_critical(limb_idx: int):
    # Juice: Sudden high-intensity shake
    if camera_controller and camera_controller.has_method("add_screen_shake"):
        camera_controller.add_screen_shake(0.8, 0.5)

func _on_health_state_changed(new_state: int):
    # Optional: trigger audio cues here
    pass

func _on_health_changed(current: float, max_h: float):
    pass

# ============================================================
# HELPER / PUBLIC
# ============================================================
func reset_effects():
    _concussion_active = false
    _stumble_timer = 0
    _final_offset = Vector3.ZERO
    _final_rotation = Vector3.ZERO
    _current_effects.clear()
    for k in ["blur", "desaturation", "tunnel_vision", "blood_vignette", 
              "aim_sway", "limp_bob", "crawl_offset", "near_death_fade"]:
        _current_effects[k] = 0.0