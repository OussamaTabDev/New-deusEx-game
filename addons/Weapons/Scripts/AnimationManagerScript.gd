## ============================================
## MODERN PROCEDURAL ANIMATION MANAGER (ENHANCED VISIBILITY + LANDING)
## ============================================
extends Node3D
class_name AnimationManager

# === YOUR ORIGINAL REFERENCES ===
var cW
var cWModel: Node3D

@export var cameraHolder: Node3D
@export var player: CharacterBody3D
@export var animPlayer: AnimationPlayer
@export var weaponManager: Node3D
@export var combat_health: CombatHealthComponent

# === NEW: State Machine (for state logic) ===
@export var state_machine: StateMachine

# === SMOOTH SETTINGS ===
@export var use_smooth_effects: bool = true
@export var injury_intensity: float = 1.0

# === INJURY EFFECTS ===
var injury_shake: Vector3 = Vector3.ZERO
var injury_sway_offset: Vector2 = Vector2.ZERO
var _shake_velocity: Vector3 = Vector3.ZERO

# === SPRING SYSTEM (now more visible) ===
var weapon_pos_offset: Vector3 = Vector3.ZERO
var weapon_rot_offset: Vector3 = Vector3.ZERO
var pos_velocity: Vector3 = Vector3.ZERO
var rot_velocity: Vector3 = Vector3.ZERO

@export_group("Spring Settings")
@export var spring_stiffness: float = 20.0   # Slightly softer → more overshoot
@export var spring_damping: float = 6.0      # Less damping → more bounce
@export var weight_scale: float = 0.15       # Increased base weight

# === NOISE ===
var noise = FastNoiseLite.new()
var noise_time: float = 0.0

func _ready():
	noise.seed = randi()
	noise.frequency = 0.5

func getCurrentWeapon(currWeap, currWeaponModel):
	cW = currWeap
	cWModel = currWeaponModel

func _process(delta: float):
	if not cW or not cWModel:
		return

	_apply_spring_physics(delta)

	if use_smooth_effects:
		_update_smooth_injury_effects(delta)

	_handle_state_logic(delta)

	# Apply FINAL transform
	cWModel.position = cW.position[0] + weapon_pos_offset + injury_shake
	cWModel.rotation = cW.position[1] + weapon_rot_offset

## ============================================
## SPRING PHYSICS
## ============================================
func _apply_spring_physics(delta: float):
	var pos_force = -spring_stiffness * weapon_pos_offset - spring_damping * pos_velocity
	pos_velocity += pos_force * delta
	weapon_pos_offset += pos_velocity * delta

	var rot_force = -spring_stiffness * weapon_rot_offset - spring_damping * rot_velocity
	rot_velocity += rot_force * delta
	weapon_rot_offset += rot_velocity * delta

## ============================================
## PUBLIC API: CALL FROM PLAYER WHEN LANDING
## ============================================
func on_landing(velocity: Vector3):
	if not cWModel:
		return

	# Vertical impact scales with fall speed
	var fall_speed = -velocity.y  # Negative = downward
	if fall_speed < 5.0:
		return  # Ignore small hops

	# Normalize for consistent feel (cap at 20 m/s)
	var impact_power = min(fall_speed / 20.0, 1.0)
	var intensity = 0.8 + impact_power * 0.7  # Range: 0.8 → 1.5

	# Direction: weapon slams DOWN and BACK (negative Y, slightly negative Z)
	var pos_impulse = Vector3(
		0,
		-0.12 * intensity,   # Strong downward hit
		-0.04 * intensity    # Slight backward push
	)

	# Rotation: pitch weapon upward (positive X rotation)
	var rot_impulse = Vector3(
		0.4 * intensity,     # Upward snap
		0,
		0.1 * intensity      # Slight wobble
	)

	apply_impulse(pos_impulse, rot_impulse)

## ============================================
## IMPULSE API
## ============================================
func apply_impulse(pos_impulse: Vector3, rot_impulse: Vector3):
	pos_velocity += pos_impulse
	rot_velocity += rot_impulse

## ============================================
## STATE + MOVEMENT LOGIC (now more pronounced)
## ============================================
func _handle_state_logic(delta: float):
	if not state_machine or not player:
		return

	var state = state_machine.get_current_state_name()
	var vel = player.velocity
	var vel_len = vel.length()

	_handle_inertia(vel, delta)
	_calculate_bob(vel_len, delta)
	_handle_mouse_sway(delta)

	match state:
		"SprintingState":
			weapon_rot_offset.z = lerp(weapon_rot_offset.z, cW.tiltRotAmount * 1.8, delta * 8.0)
			weapon_pos_offset.y = lerp(weapon_pos_offset.y, -0.12, delta * 8.0)  # More drop
		"CrouchWalkingState", "WalkingState":
			weapon_rot_offset.z = lerp(weapon_rot_offset.z, 0.0, delta * 6.0)
			weapon_pos_offset.y = lerp(weapon_pos_offset.y, 0.03, delta * 6.0)
		"FallingState":
			weapon_pos_offset.y = lerp(weapon_pos_offset.y, 0.06, delta * 4.0)
		_:
			weapon_rot_offset.z = lerp(weapon_rot_offset.z, 0.0, delta * 6.0)

## ============================================
## INERTIA & MICRO-MOVEMENTS (boosted for visibility)
## ============================================
func _handle_inertia(velocity: Vector3, delta: float):
	var local_vel = player.global_transform.basis.inverse() * velocity
	var tilt_target = local_vel.x * 0.035    # ↑ Increased from 0.02
	var shift_target = -local_vel.x * 0.008  # ↑ Increased from 0.005

	rot_velocity.z += (tilt_target - weapon_rot_offset.z) * 10.0 * delta
	pos_velocity.x += (shift_target - weapon_pos_offset.x) * 15.0 * delta

func _calculate_bob(vel_len: float, delta: float):
	if vel_len < 0.8:
		return

	var speed_mult = 1.0
	if state_machine.get_current_state_name() == "SprintingState":
		speed_mult = 1.6

	# ↑ Amplified bob amplitude for visibility
	var bob_x = sin(Time.get_ticks_msec() * 0.008) * 0.0025
	var bob_y = abs(cos(Time.get_ticks_msec() * 0.008)) * 0.0035

	pos_velocity += Vector3(bob_x, bob_y, 0) * vel_len * speed_mult * delta

func _handle_mouse_sway(delta: float):
	if not cameraHolder:
		return

	var mouse_input = Vector2(
		cameraHolder._processed_yaw_input,
		cameraHolder._processed_pitch_input
	)

	# ↑ Increased base sensitivity for clear motion
	var sway_pos_scale = 0.0018  # was 0.001
	var sway_rot_scale = 0.018   # was 0.01

	if cW:
		sway_pos_scale *= cW.swayAmountPos
		sway_rot_scale *= cW.swayAmountRot

	# Add injury sway directly to mouse input
	var effective_mouse = mouse_input + injury_sway_offset * 20.0  # ↑ Scale injury sway

	var sway_force_pos = Vector3(-effective_mouse.x, effective_mouse.y, 0) * sway_pos_scale
	var sway_force_rot = Vector3(
		effective_mouse.y * sway_rot_scale,
		-effective_mouse.x * sway_rot_scale,
		-effective_mouse.x * sway_rot_scale * 2.2
	)

	apply_impulse(sway_force_pos * delta, sway_force_rot * delta)

## ============================================
## INJURY EFFECTS (unchanged but effective)
## ============================================
func _update_smooth_injury_effects(delta: float):
	if not combat_health:
		return

	var modifiers = combat_health.combat_modifiers
	var shake_intensity = (2.0 - modifiers.weapon_stability) * 0.5 * injury_intensity

	var target_shake = Vector3(
		sin(Time.get_ticks_msec() * 0.008) * shake_intensity * 0.003,  # ↑ Slightly more
		cos(Time.get_ticks_msec() * 0.012) * shake_intensity * 0.003,
		sin(Time.get_ticks_msec() * 0.010) * shake_intensity * 0.0015
	)

	var shake_diff = target_shake - injury_shake
	_shake_velocity += shake_diff * 12.0 * delta
	_shake_velocity *= (1.0 - 4.5 * delta)
	injury_shake += _shake_velocity * delta

	var pain = combat_health.get_pain_intensity()
	if pain > 0:
		injury_sway_offset = Vector2(
			sin(Time.get_ticks_msec() * 0.002) * pain * 0.12,
			cos(Time.get_ticks_msec() * 0.003) * pain * 0.07
		)
	else:
		injury_sway_offset = Vector2.ZERO

## ============================================
## ANIMATION PLAYBACK (unchanged)
## ============================================
func playAnimation(animName: String, animSpeed: float, hasToRestartAnim: bool):
	if cW != null and animPlayer != null:
		if hasToRestartAnim and animPlayer.current_animation == animName:
			animPlayer.seek(0, true)

		var modified_speed = animSpeed
		if "Reload" in animName and use_smooth_effects and combat_health:
			modified_speed *= combat_health.get_reload_speed_multiplier()

		animPlayer.play("%s" % animName, -1, modified_speed)