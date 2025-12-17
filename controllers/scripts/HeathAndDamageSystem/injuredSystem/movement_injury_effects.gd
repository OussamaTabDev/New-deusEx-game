class_name MovementInjuryEffects
extends Node

## Modular movement injury system with "Juicy" transitions and State Machine enforcement.
## Uses Perlin noise to create uneven limping gaits and smooth interpolation for speed changes.

# ============================================================
# SIGNALS
# ============================================================
signal movement_state_changed(state: MovementState)
signal stamina_changed(current: float, max: float)
signal stamina_depleted()
signal stamina_recovered()
signal fall_risk_increased()

# ============================================================
# ENUMS
# ============================================================
enum MovementState {
    NORMAL,
    LIMPING,
    SEVERE_LIMP,
    CRAWLING,
    IMMOBILIZED
}

# ============================================================
# EXPORTS - REFERENCES
# ============================================================
@export_category("Core References")
@export var player: CharacterBody3D # Generalized to CharacterBody3D, cast as needed
@export var movement_stats_provider: Node # Generic reference
@export var health_component: Node # Generic reference
@export var state_machine: Node # Generic reference
@export var audio_component: Node # Generic reference

# ============================================================
# EXPORTS - FEEL & POLISH (THE JUICE)
# ============================================================
@export_category("Game Feel")
@export var speed_change_smoothing: float = 2.0 # How fast speed penalties apply (lower = heavier feel)
@export var gait_noise_speed: float = 2.5 # How fast the limp unevenness oscillates
@export var gait_unevenness: float = 0.15 # How much speed fluctuates while limping

# ============================================================
# EXPORTS - SPEED MODIFIERS
# ============================================================
@export_category("Speed Modifiers")
@export_group("Leg Damage")
@export var slight_limp_threshold: float = 0.6  # HP % when limp starts
@export var slight_limp_speed: float = 0.85
@export var severe_limp_threshold: float = 0.4
@export var severe_limp_speed: float = 0.6
@export var crawl_threshold: float = 0.15
@export var walk_threshold: float = 0.3 # Below this, cannot stand

@export var crawl_speed: float = 0.3

@export_group("Torso Damage")
@export var torso_endurance_threshold: float = 0.5
@export var torso_speed_penalty: float = 0.9
@export var heavy_breathing_speed: float = 0.85

@export_group("Overall Health")
@export var critical_health_threshold: float = 0.25
@export var critical_speed_multiplier: float = 0.7

# ============================================================
# EXPORTS - STAMINA SYSTEM
# ============================================================
@export_category("Stamina System")
@export var enable_injury_stamina: bool = true
@export var base_stamina: float = 100.0
@export var stamina_regen_rate: float = 20.0
@export var injured_stamina_regen: float = 8.0  # Slower regen when hurt

@export_group("Stamina Costs")
@export var sprint_stamina_cost: float = 15.0
@export var jump_stamina_cost: float = 20.0
@export var dash_stamina_cost: float = 30.0
@export var swim_stamina_cost: float = 10.0
@export var climb_stamina_cost: float = 12.0
@export var injured_stamina_multiplier: float = 1.5  # Costs more when hurt

# ============================================================
# EXPORTS - MOVEMENT RESTRICTIONS
# ============================================================
@export_category("Movement Restrictions")
@export_group("Sprint")
@export var sprint_disabled_threshold: float = 0.3  # Leg HP to disable sprint
@export var sprint_torso_threshold: float = 0.2  # Torso HP to disable sprint

@export_group("Jump")
@export var jump_height_reduction: float = 0.5  # At low leg health
@export var jump_disabled_threshold: float = 0.2

@export_group("Climb & Parkour")
@export var climb_disabled_arm_threshold: float = 0.3
@export var climb_disabled_leg_threshold: float = 0.2

@export_group("Dash")
@export var dash_disabled_threshold: float = 0.4

# ============================================================
# EXPORTS - ANIMATION & AUDIO
# ============================================================
@export_category("Feedback")
@export var enable_pain_stumbles: bool = true
@export var stumble_chance_per_second: float = 0.1
@export var stumble_slow_duration: float = 0.8
@export var enable_injury_falls: bool = true
@export var fall_risk_threshold: float = 0.2  # Leg HP

# ============================================================
# INTERNAL STATE
# ============================================================
var current_movement_state: MovementState = MovementState.NORMAL

# Noise for organic gait
var _noise: FastNoiseLite = FastNoiseLite.new()
var _noise_time: float = 0.0

# Speed calculations
var _target_speed_multiplier: float = 1.0
var _smoothed_speed_multiplier: float = 1.0 # The actual value used

# Stamina
var _current_stamina: float = 100.0
var _stamina_depleted: bool = false
var _stamina_regen_delay: float = 0.0

# Movement restrictions
var _can_walk :bool = true
var _can_sprint: bool = true
var _can_jump: bool = true
var _can_climb: bool = true
var _can_dash: bool = true
var _can_swim: bool = true

# State timers
var _stumble_timer: float = 0.0
var _exhaustion_pause_timer: float = 0.0
var _fall_recovery_timer: float = 0.0
var _is_fallen: bool = false

# Cache
var _leg_avg_health: float = 1.0
var _torso_health: float = 1.0
var _arm_avg_health: float = 1.0
var _total_health_percent: float = 1.0

# ============================================================
# INITIALIZATION
# ============================================================
func _ready():
    # Setup Noise
    _noise.seed = randi()
    _noise.frequency = 0.5
    
    if not player:
        player = get_parent() as CharacterBody3D
    
    if health_component:
        _connect_health_signals()
    else:
        push_error("MovementInjuryEffects: No health_component assigned!")
    
    _current_stamina = base_stamina
    _update_health_cache()

func _connect_health_signals():
    # Using string referencing for safety if component is generic
    if health_component.has_signal("limb_damaged"):
        health_component.limb_damaged.connect(_on_limb_damaged)
    if health_component.has_signal("limb_critical"):
        health_component.limb_critical.connect(_on_limb_critical)
    if health_component.has_signal("state_changed"):
        health_component.state_changed.connect(_on_health_state_changed)

# ============================================================
# MAIN UPDATE
# ============================================================
func _process(delta: float):
    if not health_component or not player:
        return
    
    _noise_time += delta * gait_noise_speed
    
    _update_health_cache()
    _update_movement_state()
    _update_stamina(delta)
    
    # 1. Determine Restrictions
    _update_movement_restrictions()
    
    # 2. Kick player out of illegal states
    _enforce_state_constraints()

    _check_active_state_validity() 
    # 3. Handle Timers & Random Events
    _update_timers(delta)
    _update_injury_events(delta)
    
    # 4. Calculate & Apply Smooth Speed
    _calculate_target_speed_multiplier()
    _apply_speed_smoothing(delta)
    
    # 5. Notify stats provider
    if movement_stats_provider and movement_stats_provider.has_method("update_stats"):
        movement_stats_provider.update_stats()

## Monitors the current state continuously to kick player out if conditions worsen mid-state
func _check_active_state_validity():
    if not state_machine: return
    
    var current = state_machine.get_current_state_name()
    if current == "": return
    
    # If the state we are currently in is no longer allowed:
    if not can_enter_state(current):
        # Ask for a fallback
        var fallback = get_fallback_state(current)
        if fallback != "":
            # Force the transition immediately
            state_machine.force_transition(fallback)
        else:
            # Fallback to a safe default if no mapping exists
            state_machine.force_transition("IdleState")

func _update_health_cache():
    if health_component.has_method("get_limb_health_percent"):
        var left_leg = health_component.get_limb_health_percent(4) # Assuming indices match your LimbData
        var right_leg = health_component.get_limb_health_percent(5)
        var left_arm = health_component.get_limb_health_percent(2)
        var right_arm = health_component.get_limb_health_percent(3)
        
        _leg_avg_health = (left_leg + right_leg) / 2.0
        _arm_avg_health = (left_arm + right_arm) / 2.0
        _torso_health = health_component.get_limb_health_percent(1) # Torso
        
    if health_component.has_method("get_total_health_percent"):
        _total_health_percent = health_component.get_total_health_percent()

# ============================================================
# MOVEMENT STATE LOGIC
# ============================================================
func _update_movement_state():
    var old_state = current_movement_state
    
    if _is_fallen:
        current_movement_state = MovementState.IMMOBILIZED
    elif _leg_avg_health <= crawl_threshold:
        current_movement_state = MovementState.CRAWLING
    elif _leg_avg_health <= severe_limp_threshold:
        current_movement_state = MovementState.SEVERE_LIMP
    elif _leg_avg_health <= slight_limp_threshold:
        current_movement_state = MovementState.LIMPING
    else:
        current_movement_state = MovementState.NORMAL
    
    if old_state != current_movement_state:
        movement_state_changed.emit(current_movement_state)
        # Optional: Trigger one-shot audio or particles here

# ============================================================
# SPEED CALCULATIONS (THE JUICE)
# ============================================================
func _calculate_target_speed_multiplier():
    var base_mult = 1.0
    
    # 1. Leg Damage Penalties (Base)
    match current_movement_state:
        MovementState.LIMPING:
            base_mult *= slight_limp_speed
        MovementState.SEVERE_LIMP:
            base_mult *= severe_limp_speed
        MovementState.CRAWLING:
            base_mult *= crawl_speed
        MovementState.IMMOBILIZED:
            base_mult = 0.0
            
    # 2. Procedural Gait (Gait Unevenness)
    # If limping, speed isn't constant. It fluctuates to simulate stepping on bad leg.
    if current_movement_state in [MovementState.LIMPING, MovementState.SEVERE_LIMP]:
        if player.velocity.length() > 0.1:
            var noise_val = _noise.get_noise_1d(_noise_time) # -1 to 1
            # Map noise to a dip in speed
            var gait_mod = 1.0 - (abs(noise_val) * gait_unevenness)
            base_mult *= gait_mod

    # 3. Torso/Breath Penalty
    if _torso_health < torso_endurance_threshold:
        var torso_penalty = lerp(1.0, torso_speed_penalty, 1.0 - (_torso_health / torso_endurance_threshold))
        base_mult *= torso_penalty
    
    # 4. Critical Health (Dying)
    if _total_health_percent < critical_health_threshold:
        base_mult *= critical_speed_multiplier
    
    # 5. Stamina Depletion
    if _stamina_depleted:
        base_mult *= heavy_breathing_speed
        
    # 6. Temporary Stumbles
    if _stumble_timer > 0.0:
        base_mult *= 0.5
        
    _target_speed_multiplier = base_mult

func _apply_speed_smoothing(delta: float):
    # Smoothly move current speed towards target speed
    # This prevents jerky snapping when damage is taken or states change
    _smoothed_speed_multiplier = move_toward(
        _smoothed_speed_multiplier, 
        _target_speed_multiplier, 
        delta * speed_change_smoothing
    )
    
    # In case of large discrepancies (e.g. teleporting), clamp it optionally
    # But usually move_toward is sufficient.

# ============================================================
# STAMINA SYSTEM
# ============================================================
func _update_stamina(delta: float):
    if not enable_injury_stamina or not state_machine:
        return
    
    var current_state = state_machine.get_current_state_name() if state_machine.has_method("get_current_state_name") else ""
    var stamina_cost = 0.0
    
    # Define costs based on provided States
    match current_state:
        "SprintingState", "SprintSwimingState":
            stamina_cost = sprint_stamina_cost
        "DashState":
            stamina_cost = dash_stamina_cost
        "JumpingState":
            # Jumping usually instantaneous cost, handled in API
            pass
        "ClimbState", "LadderClimbState", "WallRunState":
            stamina_cost = climb_stamina_cost
    
    # Apply Stamina Drain
    if stamina_cost > 0.0:
        # Cost multiplier when injured
        if _total_health_percent < 0.5:
            stamina_cost *= injured_stamina_multiplier
            
        _current_stamina -= stamina_cost * delta
        _stamina_regen_delay = 1.5 # Pause regen after use
    else:
        # Handle Regen
        if _stamina_regen_delay > 0.0:
            _stamina_regen_delay -= delta
        else:
            var regen_rate = stamina_regen_rate
            if _total_health_percent < 0.6:
                regen_rate = injured_stamina_regen
            
            # Regen is slower when stamina is completely empty (exhaustion)
            if _stamina_depleted:
                regen_rate *= 0.5
                
            _current_stamina += regen_rate * delta
    
    _current_stamina = clamp(_current_stamina, 0.0, base_stamina)
    
    # Check Depletion State Transitions
    var was_depleted = _stamina_depleted
    
    if _current_stamina <= 0.0 and not was_depleted:
        _stamina_depleted = true
        stamina_depleted.emit()
    elif _current_stamina > (base_stamina * 0.2) and was_depleted:
        # Only recover from depleted state once we have 20% stamina back
        _stamina_depleted = false
        stamina_recovered.emit()
        
    stamina_changed.emit(_current_stamina, base_stamina)

# ============================================================
# MOVEMENT RESTRICTIONS & STATE ENFORCEMENT
# ============================================================
func _update_movement_restrictions():
    # Helper vars
    var left_leg = 1.0; var right_leg = 1.0
    if health_component.has_method("get_limb_health_percent"):
        left_leg = health_component.get_limb_health_percent(4)
        right_leg = health_component.get_limb_health_percent(5)

    # 1. Walk (Upright)
    _can_walk = true
    if (left_leg <= walk_threshold and right_leg <= walk_threshold) or _is_fallen:
        _can_walk = false
        
    # 2. Swim
    _can_swim = true
    if _torso_health <= crawl_threshold:
        _can_swim = false # Too weak to swim
        
    # 3. Sprint
    _can_sprint = true
    if not _can_walk or _stamina_depleted:
        _can_sprint = false
    elif left_leg < sprint_disabled_threshold or right_leg < sprint_disabled_threshold:
        _can_sprint = false
    elif _torso_health < sprint_torso_threshold:
        _can_sprint = false
        
    # 4. Jump
    _can_jump = true
    if not _can_walk or _current_stamina < jump_stamina_cost:
        _can_jump = false
    elif _leg_avg_health < jump_disabled_threshold:
        _can_jump = false
        
    # 5. Climb / WallRun / Ladder
    _can_climb = true
    if _arm_avg_health < climb_disabled_arm_threshold or _stamina_depleted:
        _can_climb = false
    # Need at least one functional leg to boost up walls usually
    if left_leg < climb_disabled_leg_threshold and right_leg < climb_disabled_leg_threshold:
        _can_climb = false
        
    # 6. Dash
    _can_dash = true
    if not _can_walk or _stamina_depleted or _current_stamina < dash_stamina_cost:
        _can_dash = false
    elif _leg_avg_health < dash_disabled_threshold:
        _can_dash = false

func _enforce_state_constraints():
    if not state_machine or not state_machine.has_method("get_current_state_name"):
        return

    var current_state = state_machine.get_current_state_name()
    
    # LOGIC MAPPING FOR PROVIDED STATE LIST
    
    # A. IMMOBILIZED / FALLEN
    if _is_fallen:
        # Force a generic fallen/prone state if available, or crouch
        if current_state != "FallingState" and current_state != "CrouchWalkingState":
             # We assume CrouchWalkingState can handle being on ground
             _force_state_transition("CrouchWalkingState")
        return

    # B. FORCED CRAWL (Cannot Walk)
    if not _can_walk:
        # Illegal states when you can't stand
        var standing_states = [
            "WalkingState", "SprintingState", "JumpingState", 
            "DashState", "WallRunState", "LadderClimbState"
        ]
        if current_state in standing_states:
            # Demote to Crouch (Crawl)
            _force_state_transition("CrouchWalkingState")
            return

    # C. NO SPRINTING
    if not _can_sprint:
        if current_state == "SprintingState":
            _force_state_transition("WalkingState")
        elif current_state == "SprintSwimingState":
            _force_state_transition("SwimmingState")
        elif current_state == "WallRunState":
            _force_state_transition("FallingState") # Usually need sprint to wall run
            
    # D. NO CLIMBING / PARKOUR
    if not _can_climb:
        if current_state in ["ClimbState", "LadderClimbState", "WallRunState"]:
            _force_state_transition("FallingState")

    # E. NO SWIMMING
    #if not _can_swim:
        #if current_state in ["SwimmingState", "SprintSwimingState", "SurfaceSwimmingState"]:
             ## If you can't swim, you drown or sink (FallingState underwater usually)
             #_force_state_transition("FallingState")

func _force_state_transition(target_state_name: String):
    if state_machine.has_method("get_state"):
        # Some FSMs use get_state to switch
        state_machine.get_state(target_state_name)
        return
# ============================================================
# EVENT LOGIC
# ============================================================
func _update_timers(delta: float):
    if _stumble_timer > 0.0:
        _stumble_timer -= delta
        
    if _fall_recovery_timer > 0.0:
        _fall_recovery_timer -= delta
        if _fall_recovery_timer <= 0.0:
            _is_fallen = false

func _update_injury_events(delta: float):
    if not player.is_on_floor():
        return
        
    var velocity_len = player.velocity.length()
    if velocity_len < 0.1: return
    
    # Random Stumbles (Procedural Noise Threshold)
    if enable_pain_stumbles and _stumble_timer <= 0.0:
        if _leg_avg_health < 0.5:
            # Use noise to determine stumble spikes instead of pure random
            # This makes stumbles cluster together organically
            var noise_val = _noise.get_noise_1d(_noise_time * 2.0)
            var stumble_threshold = 0.6 + (_leg_avg_health * 0.3) # Harder to stumble if healthy
            
            if noise_val > stumble_threshold:
                _trigger_stumble()

    # Falls
    if enable_injury_falls and not _is_fallen and _fall_recovery_timer <= 0.0:
        if _leg_avg_health < fall_risk_threshold:
             # Pure random for falls is usually better as it's a rare event
             if randf() < (0.01 * delta): # Very low chance per frame
                 _trigger_fall()

func _trigger_stumble():
    _stumble_timer = stumble_slow_duration
    # We rely on _calculate_target_speed_multiplier to apply the slow
    
    # Optional: Emit signal for Camera Shake or Audio
    # camera_injury.add_screen_shake(...) 
    
    # High risk of falling if stumbling while running
    if _leg_avg_health < 0.3 and _can_sprint == false:
         if randf() < 0.2:
             _trigger_fall()

func _trigger_fall():
    _is_fallen = true
    _fall_recovery_timer = 2.0
    fall_risk_increased.emit()
    _force_state_transition("CrouchWalkingState") # Or a Ragdoll state if you have one

# ============================================================
# SIGNAL HANDLERS
# ============================================================
func _on_limb_damaged(limb: int, damage: float, type: int):
    # Juice: Stamina damage on hit
    if damage > 20.0:
        _current_stamina = max(0, _current_stamina - (damage * 0.5))
        _stamina_regen_delay = 2.0

func _on_limb_critical(limb: int):
    # Force immediate stumble on break
    if limb == 4 or limb == 5: # Legs
        _trigger_stumble()

func _on_health_state_changed(new_state: int):
    pass

# ============================================================
# PUBLIC API (For MovementStatsProvider)
# ============================================================
func get_speed_multiplier() -> float:
    return _smoothed_speed_multiplier

func get_stamina_percent() -> float:
    return _current_stamina / base_stamina

func is_movement_impaired() -> bool:
    return current_movement_state != MovementState.NORMAL

func consume_instant_stamina(amount: float) -> bool:
    if _current_stamina >= amount:
        _current_stamina -= amount
        _stamina_regen_delay = 1.0
        stamina_changed.emit(_current_stamina, base_stamina)
        return true
    return false

## Checks if a specific state is physically possible given current injuries
func can_enter_state(state_name: String) -> bool:
    var state_lower = state_name.to_lower()
    
    # 1. IMMOBILIZED / FALLEN
    if _is_fallen:
        # Only allow recovery states or lying down states
        return state_lower in ["fallingstate", "crouchwalkingstate", "immobilizedstate"]

    # 2. LEG DAMAGE (Must Crawl)
    if not _can_walk:
        # Block all standing states
        var standing_states = [
            "idlestate","walkingstate", "sprintingstate", "jumpingstate", 
            "dashstate", "wallrunstate", "ladderclimbstate"
        ]
        if state_lower in standing_states:
            return false

    # 3. SPRINT BLOCK
    if not _can_sprint:
        if state_lower in ["sprintingstate", "sprintswimingstate", "wallrunstate"]:
            return false

    # 4. CLIMB BLOCK
    if not _can_climb:
        if state_lower in ["climbstate", "ladderclimbstate", "wallrunstate"]:
            return false

    # 5. SWIM BLOCK (Optional)
    if not _can_swim:
        if state_lower in ["swimmingstate", "sprintswimingstate"]:
            return false

    return true

## Returns a valid alternative state if the requested one is blocked
## e.g. If trying to Sprint but leg broken -> Return "WalkingState"
func get_fallback_state(blocked_state_name: String) -> String:
    var state_lower = blocked_state_name.to_lower()
    
    if _is_fallen:
        return "CrouchWalkingState" # Or "ProneState"
        
    if not _can_walk:
        # If trying to stand/walk/run but legs broken -> Crawl
        return "CrouchWalkingState"
        
    if not _can_sprint:
        # If trying to sprint -> Walk
        if state_lower == "sprintingstate":
            return "WalkingState"
        if state_lower == "sprintswimingstate":
            return "SwimmingState"
            
    return "" # No specific fallback, just block the input