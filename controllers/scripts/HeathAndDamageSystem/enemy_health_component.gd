class_name EnemyHealthComponent
extends HealthComponent

## Enemy-specific signals
signal enemy_alerted(damage_source: Node)
signal enemy_staggered()
signal enemy_disabled()

@export var enemy_character: CharacterBody3D
@export var ai_controller: Node  # Your AI controller node

## Enemy behavior modifiers
var is_staggered: bool = false
var is_disabled: bool = false
var alert_radius: float = 20.0

func _ready():
	super._ready()
	
	if not enemy_character:
		enemy_character = get_parent() as CharacterBody3D
	
	# Connect signals
	limb_critical.connect(_on_limb_critical_enemy)
	limb_destroyed.connect(_on_limb_destroyed_enemy)
	state_changed.connect(_on_state_changed_enemy)

## Override for enemy-specific effects
func _apply_limb_effects(limb: LimbData.Limb) -> void:
	_update_enemy_behavior()

func _update_enemy_behavior() -> void:
	if not enemy_character:
		return
	
	var head = get_limb(LimbData.BodyPart.HEAD)
	var torso = get_limb(LimbData.BodyPart.TORSO)
	var left_leg = get_limb(LimbData.BodyPart.LEFT_LEG)
	var right_leg = get_limb(LimbData.BodyPart.RIGHT_LEG)
	
	# Check for disabling conditions
	if head.is_critical():
		_apply_stagger()
	
	# Movement penalties
	var leg_avg = (left_leg.get_health_percent() + right_leg.get_health_percent()) / 2.0
	if leg_avg < 0.3:
		_apply_movement_penalty(0.5)
	elif leg_avg < 0.6:
		_apply_movement_penalty(0.75)
	
	# Check if enemy should be disabled
	if left_leg.is_destroyed() and right_leg.is_destroyed():
		_disable_enemy()

func _apply_stagger() -> void:
	if is_staggered:
		return
	
	is_staggered = true
	enemy_staggered.emit()
	
	# Reset stagger after delay
	await get_tree().create_timer(2.0).timeout
	is_staggered = false

func _disable_enemy() -> void:
	if is_disabled:
		return
	
	is_disabled = true
	enemy_disabled.emit()
	
	# Enemy falls down, can't move
	if enemy_character:
		# Disable AI or movement
		if ai_controller:
			ai_controller.set_process(false)

func _apply_movement_penalty(multiplier: float) -> void:
	# Apply to enemy movement speed
	# This depends on your enemy movement implementation
	pass

## Signal handlers
func _on_limb_critical_enemy(limb: LimbData.BodyPart) -> void:
	print("Enemy %s critically damaged: %s" % [enemy_character.name, LimbData.get_limb_name(limb)])
	
	# Enemy might change behavior when critically damaged
	if ai_controller and ai_controller.has_method("on_critically_wounded"):
		ai_controller.on_critically_wounded(limb)

func _on_limb_destroyed_enemy(limb: LimbData.BodyPart) -> void:
	print("Enemy %s limb destroyed: %s" % [enemy_character.name, LimbData.get_limb_name(limb)])

func _on_state_changed_enemy(new_state: CharacterState) -> void:
	match new_state:
		CharacterState.WOUNDED:
			# Enemy might become more aggressive or try to flee
			if ai_controller and ai_controller.has_method("on_wounded"):
				ai_controller.on_wounded()
		CharacterState.CRITICAL:
			# Enemy might surrender or become desperate
			if ai_controller and ai_controller.has_method("on_critical"):
				ai_controller.on_critical()
		CharacterState.DEAD:
			_handle_enemy_death()

func _handle_enemy_death() -> void:
	print("Enemy %s died" % enemy_character.name)
	
	# Disable physics and AI
	if enemy_character:
		enemy_character.set_physics_process(false)
		if ai_controller:
			ai_controller.set_process(false)
	
	# Play death animation, ragdoll, etc.
	# You can emit a signal to a death handler or animation controller

## Hitbox detection for enemies
func detect_hit_limb(hit_position: Vector3, hit_normal: Vector3) -> LimbData.BodyPart:
	if not enemy_character:
		return LimbData.BodyPart.TORSO
	
	# Get local hit position relative to enemy
	var local_hit = enemy_character.global_transform.inverse() * hit_position
	
	# Simple hitbox (adjust based on your enemy model)
	if local_hit.y > 1.6:  # Head
		return LimbData.BodyPart.HEAD
	elif local_hit.y > 0.9:  # Torso
		return LimbData.BodyPart.TORSO
	elif local_hit.y > 0.4:  # Arms region
		return LimbData.BodyPart.RIGHT_ARM if local_hit.x > 0 else LimbData.BodyPart.LEFT_ARM
	else:  # Legs
		return LimbData.BodyPart.RIGHT_LEG if local_hit.x > 0 else LimbData.BodyPart.LEFT_LEG

## Public API for damaging enemy
func take_damage(damage_amount: float, damage_type: DamageTypes.Type, hit_pos: Vector3 = Vector3.ZERO, source: Node = null) -> void:
	var limb = detect_hit_limb(hit_pos, Vector3.UP)
	
	var damage_info = DamageTypes.DamageInfo.new(damage_amount, damage_type, source)
	damage_info.hit_position = hit_pos
	
	apply_damage_to_limb(limb, damage_info)
	
	# Alert enemy to damage source
	if source and ai_controller and ai_controller.has_method("alert_to_threat"):
		enemy_alerted.emit(source)
		ai_controller.alert_to_threat(source)

## Enemy-specific getters
func is_able_to_move() -> bool:
	return not is_disabled and not is_staggered

func get_aggression_modifier() -> float:
	# Wounded enemies might be more or less aggressive
	var health_percent = get_total_health_percent()
	if health_percent < 0.3:
		return 0.5  # Less aggressive when critical
	elif health_percent < 0.6:
		return 1.2  # More aggressive when wounded
	return 1.0
