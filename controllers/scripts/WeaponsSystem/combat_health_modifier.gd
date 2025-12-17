## Smooth Combat Health Component - Production Ready
## No debug prints, smooth transitions, optimized performance
class_name CombatHealthComponent
extends Node

signal weapon_handling_changed(modifiers: Dictionary)
signal combat_effectiveness_updated(effectiveness: float)
signal player_incapacitated(can_shoot: bool, can_reload: bool, can_aim: bool)
signal arm_status_changed(can_use_weapons: bool)

@export var player_health: PlayerHealthComponent
@export var weapon_manager: WeaponManager
@export var camera_holder: CameraController

## Smooth transition settings
@export_group("Smoothness Settings")
@export_range(1.0, 20.0) var modifier_lerp_speed: float = 8.0
@export_range(0.5, 10.0) var shake_recovery_speed: float = 3.0
@export_range(0.01, 1.0) var pain_fade_speed: float = 0.3
@export var use_smooth_transitions: bool = true

## Combat modifiers (smoothly interpolated)
var combat_modifiers := {
	"aim_sway_multiplier": 1.0,
	"reload_speed_multiplier": 1.0,
	"weapon_sway_multiplier": 1.0,
	"recoil_multiplier": 1.0,
	"spread_multiplier": 1.0,
	"weapon_stability": 1.0
}

## Target values (what we're lerping towards)
var _target_modifiers := {
	"aim_sway_multiplier": 1.0,
	"reload_speed_multiplier": 1.0,
	"weapon_sway_multiplier": 1.0,
	"recoil_multiplier": 1.0,
	"spread_multiplier": 1.0,
	"weapon_stability": 1.0
}

## Effects
var shake_trauma: float = 0.0
var pain_intensity: float = 0.0
var _target_pain: float = 0.0

## Timers
var recent_damage_timer: float = 0.0
var adrenaline_boost_timer: float = 0.0

## State tracking
var _previous_can_use_weapons: bool = true
var _arm_drop_pending: bool = false
var _smooth_drop_timer: float = 0.0
const SMOOTH_DROP_DELAY: float = 0.15  # Small delay for smooth drop

func _ready():
	if not player_health:
		push_error("PlayerHealthComponent not assigned!")
		return
	
	_connect_health_signals()
	_initialize_modifiers()

func _connect_health_signals():
	player_health.limb_damaged.connect(_on_limb_damaged)
	player_health.limb_destroyed.connect(_on_limb_destroyed)
	player_health.state_changed.connect(_on_state_changed)
	player_health.health_changed.connect(_on_health_changed)
	
	if player_health is PlayerHealthComponent:
		player_health.screen_effect_triggered.connect(_on_screen_effect)
		player_health.movement_impaired.connect(_on_movement_impaired)
		player_health.aim_impaired.connect(_on_aim_impaired)

func _initialize_modifiers():
	_recalculate_target_modifiers()
	# Set current to target instantly on init
	for key in combat_modifiers:
		combat_modifiers[key] = _target_modifiers[key]

func _process(delta: float):
	_smooth_update_modifiers(delta)
	_smooth_update_effects(delta)
	_update_timers(delta)
	_check_arm_drop(delta)

## ============================================
## SMOOTH UPDATES
## ============================================

func _smooth_update_modifiers(delta: float):
	"""Smoothly interpolate modifiers to target values"""
	var changed = false
	var lerp_speed = modifier_lerp_speed * delta
	
	for key in combat_modifiers:
		var current = combat_modifiers[key]
		var target = _target_modifiers[key]
		
		if abs(current - target) > 0.001:
			combat_modifiers[key] = lerp(current, target, lerp_speed)
			changed = true
	
	if changed:
		weapon_handling_changed.emit(combat_modifiers)
		var effectiveness = _calculate_combat_effectiveness()
		combat_effectiveness_updated.emit(effectiveness)

func _smooth_update_effects(delta: float):
	"""Smoothly update pain and shake effects"""
	# Smooth pain intensity
	pain_intensity = lerp(pain_intensity, _target_pain, pain_fade_speed * delta)
	
	# Smooth shake decay
	if shake_trauma > 0:
		shake_trauma = max(0, shake_trauma - shake_recovery_speed * delta)

func _update_timers(delta: float):
	"""Update effect timers"""
	if recent_damage_timer > 0:
		recent_damage_timer = max(0, recent_damage_timer - delta)
		if recent_damage_timer == 0:
			_recalculate_target_modifiers()
	
	if adrenaline_boost_timer > 0:
		adrenaline_boost_timer = max(0, adrenaline_boost_timer - delta)
		if adrenaline_boost_timer == 0:
			_recalculate_target_modifiers()

func _check_arm_drop(delta: float):
	"""Smooth weapon drop with small delay for polish"""
	if _arm_drop_pending:
		_smooth_drop_timer += delta
		if _smooth_drop_timer >= SMOOTH_DROP_DELAY:
			_execute_arm_drop()
			_arm_drop_pending = false
			_smooth_drop_timer = 0.0

## ============================================
## MODIFIER CALCULATION
## ============================================

func _recalculate_target_modifiers():
	"""Calculate target values for smooth interpolation"""
	if not player_health:
		return
	
	var head = player_health.get_limb(LimbData.BodyPart.HEAD)
	var torso = player_health.get_limb(LimbData.BodyPart.TORSO)
	var left_arm = player_health.get_limb(LimbData.BodyPart.LEFT_ARM)
	var right_arm = player_health.get_limb(LimbData.BodyPart.RIGHT_ARM)
	var left_leg = player_health.get_limb(LimbData.BodyPart.LEFT_LEG)
	var right_leg = player_health.get_limb(LimbData.BodyPart.RIGHT_LEG)
	
	# Reset to baseline
	_target_modifiers.aim_sway_multiplier = 1.0
	_target_modifiers.reload_speed_multiplier = 1.0
	_target_modifiers.weapon_sway_multiplier = 1.0
	_target_modifiers.recoil_multiplier = 1.0
	_target_modifiers.spread_multiplier = 1.0
	_target_modifiers.weapon_stability = 1.0
	
	## RIGHT ARM - Primary shooting arm
	if right_arm.get_health_percent() < 0.7:
		var severity = 1.0 - right_arm.get_health_percent()
		_target_modifiers.recoil_multiplier += severity * 0.5
		_target_modifiers.reload_speed_multiplier *= (0.6 + right_arm.get_health_percent() * 0.4)
		_target_modifiers.weapon_stability *= (0.5 + right_arm.get_health_percent() * 0.5)
	
	if right_arm.is_destroyed():
		_target_modifiers.reload_speed_multiplier *= 0.3
		_target_modifiers.recoil_multiplier *= 2.0
	
	## LEFT ARM - Support arm
	if left_arm.get_health_percent() < 0.7:
		var severity = 1.0 - left_arm.get_health_percent()
		_target_modifiers.weapon_sway_multiplier += severity * 0.8
		_target_modifiers.spread_multiplier += severity * 0.3
	
	if left_arm.is_destroyed():
		_target_modifiers.weapon_sway_multiplier *= 2.5
		_target_modifiers.aim_sway_multiplier *= 2.0
	
	## TORSO - Stamina & breathing
	if torso.get_health_percent() < 0.5:
		var severity = 1.0 - torso.get_health_percent() * 2.0
		_target_modifiers.aim_sway_multiplier += severity * 0.5
	
	## HEAD - Vision & focus
	if head.get_health_percent() < 0.6:
		var severity = 1.0 - head.get_health_percent()
		_target_modifiers.aim_sway_multiplier += severity * 0.4
	
	## LEGS - Stability
	var leg_health = min(left_leg.get_health_percent(), right_leg.get_health_percent())
	if leg_health < 0.5:
		var severity = 1.0 - leg_health * 2.0
		_target_modifiers.weapon_sway_multiplier += severity * 0.3
	
	## TEMPORARY EFFECTS
	if adrenaline_boost_timer > 0:
		_target_modifiers.spread_multiplier *= 0.8
		_target_modifiers.recoil_multiplier *= 0.9
	
	if recent_damage_timer > 0:
		var shake = clamp(recent_damage_timer / 2.0, 0.0, 1.0)
		_target_modifiers.weapon_sway_multiplier += shake * 0.5
		_target_modifiers.aim_sway_multiplier += shake * 0.3

func _calculate_combat_effectiveness() -> float:
	"""Returns 0-1 representing overall combat ability"""
	var effectiveness = 1.0
	effectiveness *= combat_modifiers.weapon_stability
	effectiveness *= (2.0 - combat_modifiers.aim_sway_multiplier) * 0.5
	effectiveness *= (2.0 - combat_modifiers.recoil_multiplier) * 0.5
	effectiveness *= combat_modifiers.reload_speed_multiplier
	return clamp(effectiveness, 0.0, 1.0)

## ============================================
## HEALTH SIGNAL HANDLERS
## ============================================

func _on_limb_damaged(limb: LimbData.BodyPart, damage: float, damage_type: DamageTypes.Type):
	# Smooth shake based on damage
	shake_trauma += clamp(damage / 100.0, 0.1, 1.0)
	
	# Smooth pain increase
	_target_pain = clamp(_target_pain + damage / 150.0, 0.0, 1.0)
	
	# Recent damage penalty
	recent_damage_timer = 3.0
	
	# Adrenaline boost
	adrenaline_boost_timer = 5.0
	
	# Interrupt reload if arms damaged
	if (limb == LimbData.BodyPart.LEFT_ARM or limb == LimbData.BodyPart.RIGHT_ARM):
		if weapon_manager and weapon_manager.reloadManager:
			if weapon_manager.cW and weapon_manager.cW.isReloading:
				weapon_manager.reloadManager.forceReloadStop = true
	
	_recalculate_target_modifiers()

func _on_limb_destroyed(limb: LimbData.BodyPart):
	# Major effects
	shake_trauma += 0.5
	_target_pain = 1.0
	
	# CRITICAL: Right arm destroyed = schedule smooth weapon drop
	if limb == LimbData.BodyPart.RIGHT_ARM:
		_schedule_weapon_drop()
	
	_check_combat_capability()
	_recalculate_target_modifiers()

func _on_state_changed(new_state: HealthComponent.CharacterState):
	match new_state:
		HealthComponent.CharacterState.CRITICAL:
			_target_pain = 0.8
			shake_trauma += 0.3
		HealthComponent.CharacterState.NEAR_DEATH:
			_target_pain = 1.0
			shake_trauma += 0.5
		HealthComponent.CharacterState.DEAD:
			_disable_combat()
	
	_recalculate_target_modifiers()

func _on_health_changed(total_health: float, max_health: float):
	var health_percent = total_health / max_health
	_target_pain = 1.0 - health_percent
	
	# Check if right arm healed enough
	_check_right_arm_healed()
	
	_recalculate_target_modifiers()

func _on_screen_effect(effect_type: String, intensity: float):
	match effect_type:
		"blur":
			_target_modifiers.aim_sway_multiplier += intensity * 0.2

func _on_movement_impaired(speed_multiplier: float):
	_recalculate_target_modifiers()

func _on_aim_impaired(accuracy_multiplier: float):
	_target_modifiers.spread_multiplier *= (2.0 - accuracy_multiplier)
	_recalculate_target_modifiers()

## ============================================
## SMOOTH ARM DROP SYSTEM
## ============================================

func _schedule_weapon_drop():
	"""Schedule weapon drop with smooth delay"""
	_arm_drop_pending = true
	_smooth_drop_timer = 0.0

func _execute_arm_drop():
	"""Execute the actual weapon drop"""
	if not weapon_manager:
		return
	
	# Drop current weapon smoothly
	if weapon_manager.cW:
		weapon_manager.drop_current_weapon()
	
	# Disable weapon usage
	weapon_manager.canUseWeapon = false
	weapon_manager.canChangeWeapons = false

func _check_right_arm_healed():
	"""Check if right arm healed enough to re-enable weapons"""
	if not player_health:
		return
	
	var right_arm = player_health.get_limb(LimbData.BodyPart.RIGHT_ARM)
	var can_use = right_arm.get_health_percent() >= 0.3 and not right_arm.is_destroyed()
	
	# Detect state change
	if can_use != _previous_can_use_weapons:
		_previous_can_use_weapons = can_use
		arm_status_changed.emit(can_use)
		
		if can_use and weapon_manager:
			weapon_manager.canUseWeapon = true
			weapon_manager.canChangeWeapons = true

## ============================================
## COMBAT CAPABILITY
## ============================================

func _check_combat_capability():
	"""Check if player can perform combat actions"""
	var can_shoot = true
	var can_reload = true
	var can_aim = true
	
	var right_arm = player_health.get_limb(LimbData.BodyPart.RIGHT_ARM)
	var left_arm = player_health.get_limb(LimbData.BodyPart.LEFT_ARM)
	
	if right_arm.is_destroyed() and left_arm.is_destroyed():
		can_shoot = false
		can_reload = false
		can_aim = false
	elif right_arm.is_destroyed():
		can_reload = false
		can_aim = false
	
	if player_health.current_state == HealthComponent.CharacterState.NEAR_DEATH:
		can_aim = false
	
	player_incapacitated.emit(can_shoot, can_reload, can_aim)
	
	if weapon_manager and weapon_manager.cW:
		if not can_shoot:
			weapon_manager.canUseWeapon = false
		if not can_reload and weapon_manager.cW.isReloading:
			weapon_manager.reloadManager.forceReloadStop = true

func _disable_combat():
	"""Called on death"""
	if weapon_manager:
		weapon_manager.canUseWeapon = false
		weapon_manager.canChangeWeapons = false

## ============================================
## PUBLIC API
## ============================================

func get_reload_speed_multiplier() -> float:
	return combat_modifiers.reload_speed_multiplier

func get_recoil_multiplier() -> float:
	return combat_modifiers.recoil_multiplier

func get_spread_multiplier() -> float:
	return combat_modifiers.spread_multiplier

func get_sway_multiplier() -> float:
	return combat_modifiers.weapon_sway_multiplier

func can_use_weapon() -> bool:
	if not player_health:
		return true
	
	var right_arm = player_health.get_limb(LimbData.BodyPart.RIGHT_ARM)
	
	if right_arm.is_destroyed():
		return false
	
	if right_arm.get_health_percent() < 0.3:
		return false
	
	return true

func can_equip_weapon() -> bool:
	"""Check if player can equip/pickup weapons"""
	if not player_health:
		return true
	
	var right_arm = player_health.get_limb(LimbData.BodyPart.RIGHT_ARM)
	
	if right_arm.is_destroyed() or right_arm.get_health_percent() < 0.05:
		return false
	
	return true

func get_combat_effectiveness() -> float:
	return _calculate_combat_effectiveness()

func get_shake_intensity() -> float:
	return shake_trauma

func get_pain_intensity() -> float:
	return pain_intensity