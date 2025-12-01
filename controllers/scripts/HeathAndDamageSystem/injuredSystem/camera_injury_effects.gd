class_name CameraInjuryEffects
extends Node

## Modular camera injury system that responds to health component damage
## Handles all visual and camera effects based on limb damage

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
@export var camera_controller: CameraController
@export var health_component: PlayerHealthComponent
@export var camera_3d: Camera3D
@export var post_process_layer: CanvasLayer  # Optional for full-screen effects

# ============================================================
# EXPORTS - HEAD INJURY EFFECTS
# ============================================================
@export_category("Head Injury Effects")
@export_group("Vision Blur")
@export var enable_vision_blur: bool = true
@export var blur_start_threshold: float = 0.5  # Head HP % when blur starts
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
@export var tunnel_vignette_radius: float = 0.4

@export_group("Concussion")
@export var enable_concussion: bool = true
@export var concussion_threshold: float = 0.3  # Damage required to trigger
@export var concussion_duration: float = 3.0
@export var concussion_shake_intensity: float = 0.15
@export var concussion_tilt_amount: float = 5.0  # degrees
@export var concussion_double_vision: bool = true

# ============================================================
# EXPORTS - TORSO INJURY EFFECTS
# ============================================================
@export_category("Torso Injury Effects")
@export_group("Breathing")
@export var enable_breathing_effects: bool = true
@export var breathing_fov_change: float = 2.0
@export var breathing_frequency: float = 1.0  # breaths per second
@export var heavy_breathing_threshold: float = 0.5

@export_group("Blood Loss")
@export var enable_blood_vignette: bool = true
@export var blood_vignette_color: Color = Color(0.5, 0.0, 0.0, 0.8)
@export var blood_pulse_speed: float = 2.0
@export var max_blood_vignette: float = 0.7

@export_group("Camera Sway")
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
@export var arm_tremor_frequency: float = 8.0

@export_group("Aim Drift")
@export var enable_aim_drift: bool = true
@export var aim_drift_speed: float = 0.5
@export var max_aim_drift: float = 3.0  # degrees

@export_group("Recoil Amplification")
@export var enable_recoil_amplification: bool = true
@export var recoil_multiplier_damaged: float = 1.5

# ============================================================
# EXPORTS - LEG INJURY EFFECTS
# ============================================================
@export_category("Leg Injury Effects")
@export_group("Limping Camera")
@export var enable_limp_bob: bool = true
@export var limp_bob_intensity: float = 0.15
@export var limp_bob_frequency: float = 1.5
@export var limp_vertical_dip: float = 0.1

@export_group("Stumble")
@export var enable_stumble: bool = true
@export var stumble_chance: float = 0.05  # per second when moving
@export var stumble_intensity: float = 0.3
@export var stumble_duration: float = 0.5

@export_group("Crawling Camera")
@export var enable_crawl_mode: bool = true
@export var crawl_camera_height: float = 0.3
@export var crawl_transition_speed: float = 2.0

# ============================================================
# EXPORTS - CRITICAL STATE EFFECTS
# ============================================================
@export_category("Critical State Effects")
@export_group("Near Death")
@export var enable_near_death_effects: bool = true
@export var near_death_fade_speed: float = 0.5
@export var near_death_fade_color: Color = Color.BLACK
@export var near_death_audio_distortion: bool = true

@export_group("Heartbeat")
@export var enable_heartbeat_camera: bool = true
@export var heartbeat_fov_pulse: float = 3.0
@export var heartbeat_position_pulse: float = 0.02

# ============================================================
# INTERNAL STATE
# ============================================================
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

var _concussion_active: bool = false
var _concussion_timer: float = 0.0
var _concussion_tilt_target: float = 0.0

var _breathing_phase: float = 0.0
var _weakness_sway_time: float = 0.0
var _limp_phase: float = 0.0

var _stumble_timer: float = 0.0
var _stumble_offset: Vector3 = Vector3.ZERO

var _aim_drift_accumulated: Vector2 = Vector2.ZERO

var _is_crawling: bool = false
var _crawl_height_offset: float = 0.0

var _heartbeat_pulse: float = 0.0

# Cache health percentages
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
	if not camera_controller:
		camera_controller = get_parent() as CameraController
	
	if not camera_3d and camera_controller:
		camera_3d = camera_controller.CAMERA_CONTROLLER
	
	if health_component:
		_connect_health_signals()
	else:
		push_error("CameraInjuryEffects: No health_component assigned!")

func _connect_health_signals():
	health_component.limb_damaged.connect(_on_limb_damaged)
	health_component.limb_critical.connect(_on_limb_critical)
	health_component.state_changed.connect(_on_health_state_changed)
	health_component.health_changed.connect(_on_health_changed)

# ============================================================
# MAIN UPDATE
# ============================================================
func _process(delta: float):
	if not health_component or not camera_3d:
		return
	
	_update_health_cache()
	_update_all_effects(delta)

func _update_health_cache():
	_head_health = health_component.get_limb_health_percent(LimbData.BodyPart.HEAD)
	_torso_health = health_component.get_limb_health_percent(LimbData.BodyPart.TORSO)
	_left_arm_health = health_component.get_limb_health_percent(LimbData.BodyPart.LEFT_ARM)
	_right_arm_health = health_component.get_limb_health_percent(LimbData.BodyPart.RIGHT_ARM)
	_left_leg_health = health_component.get_limb_health_percent(LimbData.BodyPart.LEFT_LEG)
	_right_leg_health = health_component.get_limb_health_percent(LimbData.BodyPart.RIGHT_LEG)
	
	_arm_avg_health = (_left_arm_health + _right_arm_health) / 2.0
	_leg_avg_health = (_left_leg_health + _right_leg_health) / 2.0

func _update_all_effects(delta: float):
	# HEAD EFFECTS
	_update_vision_blur(delta)
	_update_desaturation(delta)
	_update_tunnel_vision(delta)
	_update_concussion(delta)
	
	# TORSO EFFECTS
	_update_breathing(delta)
	_update_blood_vignette(delta)
	_update_weakness_sway(delta)
	_update_heartbeat(delta)
	
	# ARM EFFECTS
	_update_arm_sway(delta)
	_update_aim_drift(delta)
	
	# LEG EFFECTS
	_update_limp_bob(delta)
	_update_stumble(delta)
	_update_crawl_mode(delta)
	
	# CRITICAL EFFECTS
	_update_near_death(delta)
	
	# APPLY ALL EFFECTS TO CAMERA
	_apply_effects_to_camera(delta)

# ============================================================
# HEAD INJURY EFFECTS
# ============================================================
func _update_vision_blur(delta: float):
	if not enable_vision_blur:
		_current_effects.blur = 0.0
		return
	
	var blur_intensity = 0.0
	if _head_health < blur_start_threshold:
		var health_factor = 1.0 - (_head_health / blur_start_threshold)
		blur_intensity = health_factor * max_blur_amount
		
		# Add pulsing when very damaged
		if _head_health < 0.3:
			var pulse = sin(Time.get_ticks_msec() * 0.001 * blur_pulse_speed) * 0.5 + 0.5
			blur_intensity += pulse * 0.5
	
	_current_effects.blur = lerp(_current_effects.blur, blur_intensity, delta * 3.0)

func _update_desaturation(delta: float):
	if not enable_desaturation:
		_current_effects.desaturation = 0.0
		return
	
	var desat_intensity = 0.0
	if _head_health < desat_start_threshold or _torso_health < 0.3:
		var head_factor = clamp(1.0 - (_head_health / desat_start_threshold), 0.0, 1.0)
		var torso_factor = clamp(1.0 - (_torso_health / 0.3), 0.0, 1.0)
		desat_intensity = max(head_factor, torso_factor) * max_desaturation
	
	_current_effects.desaturation = lerp(_current_effects.desaturation, desat_intensity, delta * 2.0)

func _update_tunnel_vision(delta: float):
	if not enable_tunnel_vision:
		_current_effects.tunnel_vision = 0.0
		return
	
	var tunnel_intensity = 0.0
	if _head_health < tunnel_start_threshold:
		var health_factor = 1.0 - (_head_health / tunnel_start_threshold)
		tunnel_intensity = health_factor * tunnel_max_strength
	
	_current_effects.tunnel_vision = lerp(_current_effects.tunnel_vision, tunnel_intensity, delta * 1.5)

func _update_concussion(delta: float):
	if not _concussion_active:
		return
	
	_concussion_timer -= delta
	
	if _concussion_timer <= 0.0:
		_concussion_active = false
		_concussion_tilt_target = 0.0
		return
	
	# Random tilt during concussion
	if randf() < delta * 2.0:  # Change tilt randomly
		_concussion_tilt_target = randf_range(-concussion_tilt_amount, concussion_tilt_amount)
	
	# Add shake
	if camera_controller and camera_controller.enable_screen_shake:
		var shake_amount = (_concussion_timer / concussion_duration) * concussion_shake_intensity
		if randf() < delta * 5.0:
			camera_controller.add_screen_shake(shake_amount, 0.2)

# ============================================================
# TORSO INJURY EFFECTS
# ============================================================
func _update_breathing(delta: float):
	if not enable_breathing_effects:
		return
	
	var breathing_speed = breathing_frequency
	if _torso_health < heavy_breathing_threshold:
		breathing_speed *= 1.5 + (1.0 - _torso_health / heavy_breathing_threshold)
	
	_breathing_phase += delta * breathing_speed * TAU

func _update_blood_vignette(delta: float):
	if not enable_blood_vignette:
		_current_effects.blood_vignette = 0.0
		return
	
	var vignette_intensity = 0.0
	
	# Check if bleeding
	var is_bleeding = false
	if health_component.bleeding_system:
		is_bleeding = health_component.bleeding_system.get_total_bleed_rate() > 0.0
	
	if is_bleeding or _torso_health < 0.4:
		var health_factor = 1.0 - _torso_health
		vignette_intensity = health_factor * max_blood_vignette
		
		# Pulse effect
		var pulse = sin(Time.get_ticks_msec() * 0.001 * blood_pulse_speed) * 0.5 + 0.5
		vignette_intensity *= (0.7 + pulse * 0.3)
	
	_current_effects.blood_vignette = lerp(_current_effects.blood_vignette, vignette_intensity, delta * 2.0)

func _update_weakness_sway(delta: float):
	if not enable_weakness_sway:
		return
	
	if _torso_health < 0.5:
		_weakness_sway_time += delta * weakness_sway_speed

func _update_heartbeat(delta: float):
	if not enable_heartbeat_camera:
		return
	
	var health_percent = health_component.get_total_health_percent()
	if health_percent < 0.3:
		var beat_speed = remap(health_percent, 0.3, 0.0, 1.0, 2.5)
		_heartbeat_pulse += delta * beat_speed * TAU

# ============================================================
# ARM INJURY EFFECTS
# ============================================================
func _update_arm_sway(delta: float):
	if not enable_arm_sway:
		_current_effects.aim_sway = 0.0
		return
	
	var sway_intensity = 0.0
	if _arm_avg_health < 0.6:
		var damage_factor = 1.0 - (_arm_avg_health / 0.6)
		sway_intensity = damage_factor * arm_sway_multiplier
		
		# Add tremor
		var tremor = sin(Time.get_ticks_msec() * 0.001 * arm_tremor_frequency)
		sway_intensity *= (0.8 + tremor * 0.2)
	
	_current_effects.aim_sway = lerp(_current_effects.aim_sway, sway_intensity, delta * 4.0)

func _update_aim_drift(delta: float):
	if not enable_aim_drift:
		return
	
	if _arm_avg_health < 0.5:
		var drift_intensity = 1.0 - (_arm_avg_health / 0.5)
		var drift_speed = aim_drift_speed * drift_intensity
		
		# Random drift direction
		var drift_x = randf_range(-drift_speed, drift_speed) * delta
		var drift_y = randf_range(-drift_speed, drift_speed) * delta
		
		_aim_drift_accumulated.x += drift_x
		_aim_drift_accumulated.y += drift_y
		
		# Clamp drift
		_aim_drift_accumulated.x = clamp(_aim_drift_accumulated.x, -max_aim_drift, max_aim_drift)
		_aim_drift_accumulated.y = clamp(_aim_drift_accumulated.y, -max_aim_drift, max_aim_drift)
		
		# Slowly return to center
		_aim_drift_accumulated = _aim_drift_accumulated.lerp(Vector2.ZERO, delta * 0.5)

# ============================================================
# LEG INJURY EFFECTS
# ============================================================
func _update_limp_bob(delta: float):
	if not enable_limp_bob:
		_current_effects.limp_bob = 0.0
		return
	
	var player = camera_controller.player if camera_controller else null
	if not player:
		return
	
	var is_limping = health_component.is_limping()
	if is_limping and player.is_on_floor() and player.velocity.length() > 0.5:
		var limp_factor = 1.0 - _leg_avg_health
		_limp_phase += delta * limp_bob_frequency * player.velocity.length() * 0.1
		
		var bob_value = sin(_limp_phase) * limp_bob_intensity * limp_factor
		_current_effects.limp_bob = bob_value
	else:
		_current_effects.limp_bob = lerp(_current_effects.limp_bob, 0.0, delta * 5.0)

func _update_stumble(delta: float):
	if not enable_stumble:
		return
	
	var player = camera_controller.player if camera_controller else null
	if not player:
		return
	
	if _stumble_timer > 0.0:
		_stumble_timer -= delta
		var ratio = _stumble_timer / stumble_duration
		_stumble_offset = _stumble_offset.lerp(Vector3.ZERO, delta * 8.0)
	elif _leg_avg_health < 0.4 and player.velocity.length() > 1.0:
		# Chance to stumble
		if randf() < stumble_chance * delta:
			_trigger_stumble()

func _trigger_stumble():
	_stumble_timer = stumble_duration
	var random_dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	_stumble_offset = random_dir * stumble_intensity
	
	if camera_controller:
		camera_controller.add_screen_shake(0.3, 0.3)

func _update_crawl_mode(delta: float):
	if not enable_crawl_mode:
		return
	
	# Check if both legs are destroyed or critically damaged
	var should_crawl = (_left_leg_health <= 0.1 and _right_leg_health <= 0.1) or \
					   (_left_leg_health <= 0.0 or _right_leg_health <= 0.0)
	
	if should_crawl != _is_crawling:
		_is_crawling = should_crawl
		if _is_crawling:
			injury_effect_started.emit("crawl_mode")
		else:
			injury_effect_ended.emit("crawl_mode")
	
	var target_height = -crawl_camera_height if _is_crawling else 0.0
	_crawl_height_offset = lerp(_crawl_height_offset, target_height, delta * crawl_transition_speed)
	_current_effects.crawl_offset = _crawl_height_offset

# ============================================================
# CRITICAL STATE EFFECTS
# ============================================================
func _update_near_death(delta: float):
	if not enable_near_death_effects:
		_current_effects.near_death_fade = 0.0
		return
	
	var health_percent = health_component.get_total_health_percent()
	var fade_intensity = 0.0
	
	if health_percent < 0.15:
		fade_intensity = 1.0 - (health_percent / 0.15)
		fade_intensity = clamp(fade_intensity, 0.0, 0.8)  # Don't go completely black
	
	_current_effects.near_death_fade = lerp(_current_effects.near_death_fade, fade_intensity, delta * near_death_fade_speed)

# ============================================================
# APPLY EFFECTS TO CAMERA
# ============================================================
func _apply_effects_to_camera(delta: float):
	if not camera_3d or not camera_controller:
		return
	
	var additional_offset = Vector3.ZERO
	var additional_rotation = Vector3.ZERO
	
	# Breathing effect
	if enable_breathing_effects and _torso_health < heavy_breathing_threshold:
		var breath_intensity = 1.0 - (_torso_health / heavy_breathing_threshold)
		var breath = sin(_breathing_phase) * breathing_fov_change * breath_intensity
		camera_3d.fov += breath * delta * 10.0
		
		additional_offset.y += sin(_breathing_phase) * 0.02 * breath_intensity
	
	# Weakness sway
	if enable_weakness_sway and _torso_health < 0.5:
		var sway_amount = (1.0 - _torso_health / 0.5) * weakness_sway_amount
		additional_offset.x += sin(_weakness_sway_time * 1.1) * sway_amount
		additional_offset.y += cos(_weakness_sway_time * 0.9) * sway_amount * 0.5
	
	# Concussion tilt
	if _concussion_active:
		additional_rotation.z += deg_to_rad(_concussion_tilt_target) * (_concussion_timer / concussion_duration)
	
	# Arm sway (affects aiming)
	if enable_arm_sway:
		var sway = sin(Time.get_ticks_msec() * 0.001 * arm_tremor_frequency) * _current_effects.aim_sway
		additional_rotation.x += deg_to_rad(sway * 0.5)
		additional_rotation.z += deg_to_rad(sway * 0.3)
	
	# Aim drift
	if enable_aim_drift:
		additional_rotation.x += deg_to_rad(_aim_drift_accumulated.y)
		additional_rotation.y += deg_to_rad(_aim_drift_accumulated.x)
	
	# Limp bob
	additional_offset.y += _current_effects.limp_bob
	if abs(_current_effects.limp_bob) > 0.01:
		var dip = sin(_limp_phase * 0.5) * limp_vertical_dip
		additional_offset.y += dip
	
	# Stumble
	additional_offset += _stumble_offset
	
	# Crawl mode
	additional_offset.y += _current_effects.crawl_offset
	
	# Heartbeat pulse
	if enable_heartbeat_camera and health_component.get_total_health_percent() < 0.3:
		var pulse_value = abs(sin(_heartbeat_pulse))
		camera_3d.fov += pulse_value * heartbeat_fov_pulse
		additional_offset.y += sin(_heartbeat_pulse) * heartbeat_position_pulse
	
	# Apply to camera (additive to camera controller's existing offsets)
	camera_3d.position += additional_offset
	camera_3d.rotation += additional_rotation

# ============================================================
# SIGNAL HANDLERS
# ============================================================
func _on_limb_damaged(limb: LimbData.BodyPart, damage: float, damage_type: DamageTypes.Type):
	# Trigger concussion on head damage
	if limb == LimbData.BodyPart.HEAD and damage >= concussion_threshold and enable_concussion:
		_trigger_concussion()
	
	# Camera kick from damage
	if camera_controller and health_component.player:
		var damage_source = health_component.player.global_position + Vector3.UP * 2.0
		camera_controller.add_damage_kick(damage_source)

func _on_limb_critical(limb: LimbData.BodyPart):
	# Dramatic effect when limb becomes critical
	if camera_controller:
		camera_controller.add_screen_shake(0.6, 0.5)

func _on_health_state_changed(new_state: HealthComponent.CharacterState):
	match new_state:
		HealthComponent.CharacterState.WOUNDED:
			# Mild warning effect
			if camera_controller:
				camera_controller.add_screen_shake(0.3, 0.3)
		
		HealthComponent.CharacterState.CRITICAL:
			# Heavy warning
			if camera_controller:
				camera_controller.add_screen_shake(0.8, 1.0)
		
		HealthComponent.CharacterState.NEAR_DEATH:
			# Extreme effect
			if camera_controller:
				camera_controller.add_screen_shake(1.0, 2.0)

func _on_health_changed(total_health: float, max_health: float):
	# Optional: could trigger effects based on health changes
	pass

func _trigger_concussion():
	if _concussion_active:
		return
	
	_concussion_active = true
	_concussion_timer = concussion_duration
	_concussion_tilt_target = randf_range(-concussion_tilt_amount, concussion_tilt_amount)
	
	concussion_pulse.emit()
	injury_effect_started.emit("concussion")

# ============================================================
# PUBLIC API
# ============================================================
func get_recoil_multiplier() -> float:
	"""Returns recoil multiplier based on arm damage for weapon systems"""
	if not enable_recoil_amplification:
		return 1.0
	
	if _arm_avg_health < 0.5:
		var damage_factor = 1.0 - (_arm_avg_health / 0.5)
		return 1.0 + (recoil_multiplier_damaged - 1.0) * damage_factor
	
	return 1.0

func get_aim_stability() -> float:
	"""Returns 0-1 value of aim stability (1 = stable, 0 = very unstable)"""
	return _arm_avg_health

func is_crawling() -> bool:
	"""Check if player is in crawl mode due to leg damage"""
	return _is_crawling

func get_movement_handicap() -> float:
	"""Returns movement speed multiplier based on leg damage"""
	return _leg_avg_health

func get_vision_clarity() -> float:
	"""Returns 0-1 value of vision clarity (1 = clear, 0 = very blurred)"""
	return 1.0 - (_current_effects.blur / max_blur_amount)

func reset_all_effects():
	"""Reset all injury effects (for respawn, etc.)"""
	_current_effects = {
		"blur": 0.0,
		"desaturation": 0.0,
		"tunnel_vision": 0.0,
		"blood_vignette": 0.0,
		"aim_sway": 0.0,
		"limp_bob": 0.0,
		"crawl_offset": 0.0,
		"near_death_fade": 0.0
	}
	
	_concussion_active = false
	_concussion_timer = 0.0
	_stumble_timer = 0.0
	_aim_drift_accumulated = Vector2.ZERO
	_is_crawling = false
