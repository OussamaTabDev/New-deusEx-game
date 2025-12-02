class_name MovementInjuryEffects
extends Node

##TODO: need to make this worked with state machine
## Modular movement injury system that modifies player movement based on health
## Handles speed penalties, stamina, animation states, and movement restrictions

# ============================================================
# SIGNALS
# ============================================================
signal movement_state_changed(state: MovementState)
signal stamina_depleted()
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
@export var player: Player
@export var movement_stats_provider: MovementStatsProvider
@export var health_component: PlayerHealthComponent
@export var state_machine: StateMachine
@export var audio_component: PlayerAudioComponent

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
@export var injured_stamina_regen: float = 10.0  # Slower regen when hurt

@export_group("Stamina Costs")
@export var sprint_stamina_cost: float = 15.0
@export var jump_stamina_cost: float = 20.0
@export var dash_stamina_cost: float = 30.0
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

@export_group("Climb")
@export var climb_disabled_arm_threshold: float = 0.3
@export var climb_disabled_leg_threshold: float = 0.2

@export_group("Dash")
@export var dash_disabled_threshold: float = 0.4

# ============================================================
# EXPORTS - ANIMATION EFFECTS
# ============================================================
@export_category("Animation Effects")
@export_group("Limp Animation")
@export var enable_limp_animation: bool = true
@export var limp_animation_speed: float = 0.7
@export var severe_limp_drag_leg: bool = true

@export_group("Pain Reactions")
@export var enable_pain_stumbles: bool = true
@export var stumble_chance_per_second: float = 0.1
@export var stumble_slow_duration: float = 0.8

@export_group("Exhaustion")
@export var enable_exhaustion_pause: bool = true
@export var exhaustion_pause_chance: float = 0.05
@export var exhaustion_pause_duration: float = 1.5

# ============================================================
# EXPORTS - AUDIO FEEDBACK
# ============================================================
@export_category("Audio Feedback")
@export_group("Footsteps")
@export var limp_footstep_pattern: bool = true  # Uneven footstep timing
@export var pain_grunt_chance: float = 0.15
@export var heavy_breathing_volume: float = -10.0  # dB

@export_group("Pain Sounds")
@export var enable_pain_sounds: bool = true
@export var light_pain_sounds: Array[AudioStream] = []
@export var heavy_pain_sounds: Array[AudioStream] = []
@export var exhaustion_sounds: Array[AudioStream] = []

# ============================================================
# EXPORTS - FALL SYSTEM
# ============================================================
@export_category("Fall System")
@export_group("Fall Risk")
@export var enable_injury_falls: bool = true
@export var fall_risk_threshold: float = 0.3  # Leg HP
@export var fall_chance_per_second: float = 0.08
@export var fall_recovery_time: float = 2.0

@export_group("Stumble Falls")
@export var stumble_can_cause_fall: bool = true
@export var stumble_fall_chance: float = 0.3

# ============================================================
# INTERNAL STATE
# ============================================================
var current_movement_state: MovementState = MovementState.NORMAL

# Speed calculations
var _calculated_walk_speed: float = 0.0
var _calculated_sprint_speed: float = 0.0
var _calculated_crouch_speed: float = 0.0
var _speed_multiplier: float = 1.0

# Stamina
var _current_stamina: float = 100.0
var _stamina_depleted: bool = false

# Movement restrictions
var _can_sprint: bool = true
var _can_jump: bool = true
var _can_climb: bool = true
var _can_dash: bool = true

# State timers
var _stumble_timer: float = 0.0
var _exhaustion_pause_timer: float = 0.0
var _fall_recovery_timer: float = 0.0
var _is_fallen: bool = false

# Audio
var _pain_sound_cooldown: float = 0.0
var _breathing_audio_player: AudioStreamPlayer

# Cache
var _leg_avg_health: float = 1.0
var _torso_health: float = 1.0
var _arm_avg_health: float = 1.0
var _total_health_percent: float = 1.0

# ============================================================
# INITIALIZATION
# ============================================================
func _ready():
	if not player:
		player = get_parent() as Player
	
	if health_component:
		_connect_health_signals()
	else:
		push_error("MovementInjuryEffects: No health_component assigned!")
	
	_current_stamina = base_stamina
	_setup_audio()

func _connect_health_signals():
	health_component.limb_damaged.connect(_on_limb_damaged)
	health_component.limb_critical.connect(_on_limb_critical)
	health_component.state_changed.connect(_on_health_state_changed)

func _setup_audio():
	_breathing_audio_player = AudioStreamPlayer.new()
	add_child(_breathing_audio_player)
	_breathing_audio_player.bus = "SFX"

# ============================================================
# MAIN UPDATE
# ============================================================
func _process(delta: float):
	if not health_component or not player:
		return
	
	_update_health_cache()
	_update_movement_state()
	_update_stamina(delta)
	_update_speed_calculations()
	_update_movement_restrictions()
	_update_timers(delta)
	_update_injury_events(delta)
	_apply_movement_modifiers()

	
	# Notify stats provider (if exists)
	if player and movement_stats_provider:
		# var provider = player.get_node("MovementStatsProvider") as MovementStatsProvider
		# if provider:
		movement_stats_provider.update_stats()
func _update_health_cache():
	var left_leg = health_component.get_limb_health_percent(LimbData.BodyPart.LEFT_LEG)
	var right_leg = health_component.get_limb_health_percent(LimbData.BodyPart.RIGHT_LEG)
	var left_arm = health_component.get_limb_health_percent(LimbData.BodyPart.LEFT_ARM)
	var right_arm = health_component.get_limb_health_percent(LimbData.BodyPart.RIGHT_ARM)
	
	_leg_avg_health = (left_leg + right_leg) / 2.0
	_arm_avg_health = (left_arm + right_arm) / 2.0
	_torso_health = health_component.get_limb_health_percent(LimbData.BodyPart.TORSO)
	_total_health_percent = health_component.get_total_health_percent()

# ============================================================
# MOVEMENT STATE
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
		_on_movement_state_changed(old_state, current_movement_state)

func _on_movement_state_changed(old_state: MovementState, new_state: MovementState):
	match new_state:
		MovementState.LIMPING:
			print("Player is now limping")
			_play_pain_sound(false)
		
		MovementState.SEVERE_LIMP:
			print("Player has severe limp")
			_play_pain_sound(true)
		
		MovementState.CRAWLING:
			print("Player is now crawling")
			_play_pain_sound(true)
			if state_machine:
				# Force player into crouch/crawl state
				pass
		
		MovementState.IMMOBILIZED:
			print("Player is immobilized")

# ============================================================
# SPEED CALCULATIONS
# ============================================================
func _update_speed_calculations():
	_speed_multiplier = 1.0
	
	# Leg damage penalties
	match current_movement_state:
		MovementState.LIMPING:
			_speed_multiplier *= slight_limp_speed
		MovementState.SEVERE_LIMP:
			_speed_multiplier *= severe_limp_speed
		MovementState.CRAWLING:
			_speed_multiplier *= crawl_speed
		MovementState.IMMOBILIZED:
			_speed_multiplier = 0.0
	
	# Torso damage penalty
	if _torso_health < torso_endurance_threshold:
		var torso_penalty = lerp(1.0, torso_speed_penalty, 1.0 - (_torso_health / torso_endurance_threshold))
		_speed_multiplier *= torso_penalty
	
	# Critical health penalty
	if _total_health_percent < critical_health_threshold:
		_speed_multiplier *= critical_speed_multiplier
	
	# Stamina depletion
	if _stamina_depleted:
		_speed_multiplier *= heavy_breathing_speed
	
	# Calculate final speeds
	_calculated_walk_speed = player.WALK_SPEED * _speed_multiplier
	_calculated_sprint_speed = player.SPRINT_SPEED * _speed_multiplier
	_calculated_crouch_speed = player.CROUCH_SPEED * _speed_multiplier

# ============================================================
# STAMINA SYSTEM
# ============================================================
func _update_stamina(delta: float):
	if not enable_injury_stamina:
		return
	
	var state_name = state_machine.get_current_state_name() if state_machine else ""
	
	# Drain stamina
	var stamina_cost = 0.0
	match state_name:
		"SprintingState", "SprintSwimmingState":
			stamina_cost = sprint_stamina_cost
		"DashState":
			stamina_cost = dash_stamina_cost
	
	# Multiply cost if injured
	if _total_health_percent < 0.5:
		stamina_cost *= injured_stamina_multiplier
	
	_current_stamina -= stamina_cost * delta
	
	# Regenerate stamina
	var regen_rate = stamina_regen_rate
	if _total_health_percent < 0.6:
		regen_rate = injured_stamina_regen
	
	if stamina_cost == 0.0:
		_current_stamina += regen_rate * delta
	
	_current_stamina = clamp(_current_stamina, 0.0, base_stamina)
	
	# Check depletion
	var was_depleted = _stamina_depleted
	_stamina_depleted = _current_stamina <= 0.0
	
	if not was_depleted and _stamina_depleted:
		stamina_depleted.emit()
		_play_exhaustion_sound()

# ============================================================
# MOVEMENT RESTRICTIONS
# ============================================================
func _update_movement_restrictions():
	# Sprint restriction
	_can_sprint = true
	if _leg_avg_health < sprint_disabled_threshold:
		_can_sprint = false
	if _torso_health < sprint_torso_threshold:
		_can_sprint = false
	if _stamina_depleted:
		_can_sprint = false
	
	# Jump restriction
	_can_jump = true
	if _leg_avg_health < jump_disabled_threshold:
		_can_jump = false
	if _current_stamina < jump_stamina_cost:
		_can_jump = false
	
	# Climb restriction
	_can_climb = true
	if _arm_avg_health < climb_disabled_arm_threshold:
		_can_climb = false
	if _leg_avg_health < climb_disabled_leg_threshold:
		_can_climb = false
	
	# Dash restriction
	_can_dash = true
	if _leg_avg_health < dash_disabled_threshold:
		_can_dash = false
	if _current_stamina < dash_stamina_cost:
		_can_dash = false

# ============================================================
# TIMERS
# ============================================================
func _update_timers(delta: float):
	if _stumble_timer > 0.0:
		_stumble_timer -= delta
	
	if _exhaustion_pause_timer > 0.0:
		_exhaustion_pause_timer -= delta
		_speed_multiplier *= 0.3  # Very slow during exhaustion pause
	
	if _fall_recovery_timer > 0.0:
		_fall_recovery_timer -= delta
		if _fall_recovery_timer <= 0.0:
			_is_fallen = false
	
	if _pain_sound_cooldown > 0.0:
		_pain_sound_cooldown -= delta

# ============================================================
# INJURY EVENTS
# ============================================================
func _update_injury_events(delta: float):
	if not player.is_on_floor():
		return
	
	var is_moving = player.velocity.length() > 0.5
	
	# Stumble events
	if enable_pain_stumbles and is_moving and _stumble_timer <= 0.0:
		if _leg_avg_health < 0.5:
			var stumble_chance = stumble_chance_per_second * (1.0 - _leg_avg_health)
			if randf() < stumble_chance * delta:
				_trigger_stumble()
	
	# Exhaustion pause
	if enable_exhaustion_pause and _stamina_depleted and _exhaustion_pause_timer <= 0.0:
		if randf() < exhaustion_pause_chance * delta:
			_trigger_exhaustion_pause()
	
	# Fall events
	if enable_injury_falls and not _is_fallen and _fall_recovery_timer <= 0.0:
		if _leg_avg_health < fall_risk_threshold:
			var fall_chance = fall_chance_per_second * (1.0 - _leg_avg_health)
			if randf() < fall_chance * delta:
				_trigger_fall()

func _trigger_stumble():
	_stumble_timer = stumble_slow_duration
	_speed_multiplier *= 0.5
	
	_play_pain_sound(false)
	
	# Chance to fall from stumble
	if stumble_can_cause_fall and _leg_avg_health < 0.3:
		if randf() < stumble_fall_chance:
			_trigger_fall()

func _trigger_exhaustion_pause():
	_exhaustion_pause_timer = exhaustion_pause_duration
	_play_exhaustion_sound()

func _trigger_fall():
	_is_fallen = true
	_fall_recovery_timer = fall_recovery_time
	fall_risk_increased.emit()
	_play_pain_sound(true)
	
	# Add camera shake
	if player.CAMERA_CONTROLLER:
		player.CAMERA_CONTROLLER.add_screen_shake(0.5, 0.5)

# ============================================================
# APPLY MODIFIERS
# ============================================================
func _apply_movement_modifiers():
	if not player:
		return
	
	# Apply speed modifiers by providing apis instead hard code ## TODO AI 
	# player.SPEED = _calculated_walk_speed
	
	# Modify jump velocity if injured
	if _leg_avg_health < 0.6:
		var jump_reduction = lerp(1.0, jump_height_reduction, 1.0 - (_leg_avg_health / 0.6))
		# You'd need to modify player's jump calculation
		# player.JUMP_VELOCITY *= jump_reduction

# ============================================================
# AUDIO
# ============================================================
func _play_pain_sound(heavy: bool):
	if not enable_pain_sounds or _pain_sound_cooldown > 0.0:
		return
	
	var sounds = heavy_pain_sounds if heavy else light_pain_sounds
	if sounds.is_empty():
		return
	
	var sound = sounds[randi() % sounds.size()]
	if audio_component:
		# Use your audio component to play
		pass
	
	_pain_sound_cooldown = 2.0

func _play_exhaustion_sound():
	if exhaustion_sounds.is_empty():
		return
	
	var sound = exhaustion_sounds[randi() % exhaustion_sounds.size()]
	_breathing_audio_player.stream = sound
	_breathing_audio_player.volume_db = heavy_breathing_volume
	_breathing_audio_player.play()

# ============================================================
# SIGNAL HANDLERS
# ============================================================
func _on_limb_damaged(limb: LimbData.BodyPart, damage: float, damage_type: DamageTypes.Type):
	# Play pain grunt on significant damage
	if damage > 15.0 and randf() < pain_grunt_chance:
		_play_pain_sound(damage > 30.0)

func _on_limb_critical(limb: LimbData.BodyPart):
	_play_pain_sound(true)

func _on_health_state_changed(new_state: HealthComponent.CharacterState):
	pass

# ============================================================
# PUBLIC API
# ============================================================
func can_sprint() -> bool:
	return _can_sprint

func can_jump() -> bool:
	return _can_jump

func can_climb() -> bool:
	return _can_climb

func can_dash() -> bool:
	return _can_dash

func consume_jump_stamina() -> bool:
	if _current_stamina >= jump_stamina_cost:
		_current_stamina -= jump_stamina_cost
		return true
	return false

func consume_dash_stamina() -> bool:
	if _current_stamina >= dash_stamina_cost:
		_current_stamina -= dash_stamina_cost
		return true
	return false

func get_speed_multiplier() -> float:
	return _speed_multiplier

func get_stamina_percent() -> float:
	return _current_stamina / base_stamina

func get_movement_state() -> MovementState:
	return current_movement_state

func is_movement_impaired() -> bool:
	return current_movement_state != MovementState.NORMAL

func is_immobilized() -> bool:
	return _is_fallen or current_movement_state == MovementState.IMMOBILIZED

func force_recovery_from_fall():
	"""Call this to manually recover from fall (e.g., player pressed button)"""
	_is_fallen = false
	_fall_recovery_timer = 0.0
