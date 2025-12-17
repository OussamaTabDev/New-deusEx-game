
## ============================================
## SMOOTH ANIMATION MANAGER
## ============================================

extends Node3D
class_name AnimationManager

var cW
var cWModel: Node3D

@export var cameraHolder: Node3D
@export var player: CharacterBody3D
@export var animPlayer: AnimationPlayer
@export var weaponManager: Node3D
@export var combat_health: CombatHealthComponent

## Smooth settings
@export var use_smooth_effects: bool = true
@export var injury_intensity: float = 1.0

# Smooth injury effects
var injury_shake: Vector3 = Vector3.ZERO
var injury_sway_offset: Vector2 = Vector2.ZERO
var _shake_velocity: Vector3 = Vector3.ZERO

func getCurrentWeapon(currWeap, currWeaponModel):
	cW = currWeap
	cWModel = currWeaponModel

func _process(delta: float):
	if cW != null and cWModel != null:
		if use_smooth_effects:
			_update_smooth_injury_effects(delta)
		
		weaponTilt(player._input_dir, delta)
		weaponSway(Vector2(cameraHolder._processed_yaw_input, cameraHolder._processed_pitch_input), delta)
		weaponBob(player.velocity.length(), delta)

## ============================================
## SMOOTH INJURY EFFECTS
## ============================================

func _update_smooth_injury_effects(delta: float):
	if not combat_health:
		return
	
	var modifiers = combat_health.combat_modifiers
	var shake_intensity = (2.0 - modifiers.weapon_stability) * 0.5 * injury_intensity
	
	# Smooth shake with velocity for natural movement
	var target_shake = Vector3(
		sin(Time.get_ticks_msec() * 0.008) * shake_intensity * 0.002,
		cos(Time.get_ticks_msec() * 0.012) * shake_intensity * 0.002,
		sin(Time.get_ticks_msec() * 0.010) * shake_intensity * 0.001
	)
	
	# Spring-like movement
	var shake_diff = target_shake - injury_shake
	_shake_velocity += shake_diff * 10.0 * delta
	_shake_velocity *= (1.0 - 5.0 * delta)  # Damping
	injury_shake += _shake_velocity * delta
	
	cWModel.position += injury_shake
	
	# Smooth pain sway
	var pain = combat_health.get_pain_intensity()
	if pain > 0:
		injury_sway_offset = Vector2(
			sin(Time.get_ticks_msec() * 0.002) * pain * 0.1,
			cos(Time.get_ticks_msec() * 0.003) * pain * 0.05
		)

## ============================================
## WEAPON MOVEMENT (Optimized)
## ============================================

func weaponTilt(playerInput, delta):
	var tilt_modifier = 1.0
	if use_smooth_effects and combat_health:
		tilt_modifier = combat_health.get_sway_multiplier()
	
	var modified_amount = cW.tiltRotAmount * tilt_modifier
	cWModel.rotation.z = lerp(cWModel.rotation.z, playerInput.x * modified_amount, cW.tiltRotSpeed * delta)

func weaponSway(mouseInput, delta):
	var sway_mult = 1.0
	if use_smooth_effects and combat_health:
		sway_mult = combat_health.get_sway_multiplier()
	
	mouseInput.x = clamp(mouseInput.x, cW.minSwayVal.x, cW.maxSwayVal.x)
	mouseInput.y = clamp(mouseInput.y, cW.minSwayVal.y, cW.maxSwayVal.y)
	
	mouseInput += injury_sway_offset
	
	var modified_sway_pos = cW.swayAmountPos * sway_mult
	var modified_sway_rot = cW.swayAmountRot * sway_mult
	
	cWModel.position.x = lerp(cWModel.position.x, 
		cW.position[0].x + (mouseInput.x * modified_sway_pos) * delta, cW.swaySpeedPos)
	cWModel.position.y = lerp(cWModel.position.y, 
		cW.position[0].y - (mouseInput.y * modified_sway_pos) * delta, cW.swaySpeedPos)
	
	cWModel.rotation_degrees.y = lerp(cWModel.rotation_degrees.y, 
		rad_to_deg(cW.position[1].y) - (mouseInput.x * modified_sway_rot) * delta, cW.swaySpeedRot)
	cWModel.rotation_degrees.x = lerp(cWModel.rotation_degrees.x, 
		rad_to_deg(cW.position[1].x) + (mouseInput.y * modified_sway_rot) * delta, cW.swaySpeedRot)

func weaponBob(vel: float, delta):
	var bobFreq: float = cW.bobFreq
	var stability = 1.0
	
	if use_smooth_effects and combat_health:
		stability = combat_health.combat_modifiers.weapon_stability
	
	var bob_irregularity = (1.0 - stability) * injury_intensity
	
	if vel < 4.0:
		bobFreq /= cW.onIdleBobFreqDivider
	
	var time_offset = Time.get_ticks_msec() * bobFreq
	var injury_offset_x = sin(time_offset * 1.3) * bob_irregularity * 0.003
	var injury_offset_y = cos(time_offset * 0.7) * bob_irregularity * 0.005
	
	cWModel.position.y = lerp(cWModel.position.y, 
		cW.bobPos[0].y + sin(time_offset) * cW.bobAmount * vel / 10 + injury_offset_y, 
		cW.bobSpeed * delta)
	cWModel.position.x = lerp(cWModel.position.x, 
		cW.bobPos[0].x + sin(time_offset * 0.5) * cW.bobAmount * vel / 10 + injury_offset_x, 
		cW.bobSpeed * delta)

func playAnimation(animName: String, animSpeed: float, hasToRestartAnim: bool):
	if cW != null and animPlayer != null:
		if hasToRestartAnim and animPlayer.current_animation == animName:
			animPlayer.seek(0, true)
		
		var modified_speed = animSpeed
		if "Reload" in animName and use_smooth_effects and combat_health:
			modified_speed *= combat_health.get_reload_speed_multiplier()
		
		animPlayer.play("%s" % animName, -1, modified_speed)