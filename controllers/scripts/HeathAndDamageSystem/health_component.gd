class_name HealthComponent
extends Node

## Signals
signal limb_damaged(limb: LimbData.BodyPart, damage: float, damage_type: DamageTypes.Type)
signal limb_critical(limb: LimbData.BodyPart)
signal limb_destroyed(limb: LimbData.BodyPart)
signal character_died(cause: String)
signal health_changed(total_health: float, max_health: float)
signal state_changed(state: CharacterState)

## Exports
@export var base_limb_health: float = 100.0
@export var enable_bleeding: bool = true
@export var enable_limb_effects: bool = true
@export var critical_threshold: float = 0.25

## Child modules
@onready var armor_module: ArmorModule = $ArmorModule if has_node("ArmorModule") else null
@onready var bleeding_system: BleedingSystem = $BleedingSystem if has_node("BleedingSystem") else null

## Character state
enum CharacterState {
	NORMAL,
	WOUNDED,
	CRITICAL,
	NEAR_DEATH,
	DEAD
}

var current_state: CharacterState = CharacterState.NORMAL

## Limb storage
var limbs: Dictionary = {}
var total_health: float = 0.0
var max_total_health: float = 0.0

func _ready():
	_initialize_limbs()
	_update_total_health()

func _initialize_limbs() -> void:
	for part in LimbData.BodyPart.values():
		var limb_max_health = base_limb_health * LimbData.LIMB_WEIGHTS[part]
		var limb = LimbData.Limb.new(part, limb_max_health)
		limbs[part] = limb
	
	max_total_health = _calculate_total_health()
	total_health = max_total_health

## Main damage application
func apply_damage_to_limb(limb: LimbData.BodyPart, damage_info: DamageTypes.DamageInfo) -> void:
	if current_state == CharacterState.DEAD:
		return
	
	var limb_data = limbs.get(limb) as LimbData.Limb
	if not limb_data:
		return
	
	# Apply armor reduction
	var damage_multiplier = 1.0
	if armor_module:
		damage_multiplier = armor_module.calculate_damage_reduction(damage_info)
	
	var final_damage = damage_info.amount * damage_multiplier
	
	# Apply damage
	limb_data.apply_damage(final_damage)
	limb_damaged.emit(limb, final_damage, damage_info.type)
	
	# Check for bleeding
	if enable_bleeding and _should_cause_bleeding(damage_info, limb_data):
		_start_limb_bleeding(limb_data, damage_info)
	
	# Check limb state
	if limb_data.is_destroyed():
		limb_destroyed.emit(limb)
		_check_death_conditions()
	elif limb_data.is_critical():
		limb_critical.emit(limb)
	
	# Update overall state
	_update_total_health()
	_update_character_state()
	
	# Apply gameplay effects
	if enable_limb_effects:
		_apply_limb_effects(limb_data)

## Healing
func heal_limb(limb: LimbData.BodyPart, amount: float, stop_bleed: bool = false) -> void:
	var limb_data = limbs.get(limb) as LimbData.Limb
	if not limb_data:
		return
	
	limb_data.heal(amount)
	
	if stop_bleed and bleeding_system:
		bleeding_system.stop_bleeding(limb_data)
	
	_update_total_health()
	_update_character_state()

func heal_all(amount: float, stop_all_bleeding: bool = false) -> void:
	for limb in limbs.values():
		limb.heal(amount)
	
	if stop_all_bleeding and bleeding_system:
		bleeding_system.stop_all_bleeding()
	
	_update_total_health()
	_update_character_state()

## Death checks
func _check_death_conditions() -> void:
	var head = limbs[LimbData.BodyPart.HEAD] as LimbData.Limb
	var torso = limbs[LimbData.BodyPart.TORSO] as LimbData.Limb
	
	if head.is_destroyed():
		_trigger_death("Head destroyed")
	elif torso.is_destroyed():
		_trigger_death("Torso destroyed")
	elif _all_limbs_critical():
		_trigger_death("Multiple organ failure")

func _all_limbs_critical() -> bool:
	var critical_count = 0
	for limb in limbs.values():
		if limb.get_health_percent() <= 0.1:
			critical_count += 1
	return critical_count >= 6

func _trigger_death(cause: String) -> void:
	current_state = CharacterState.DEAD
	character_died.emit(cause)
	state_changed.emit(current_state)

## Bleeding logic
func _should_cause_bleeding(damage_info: DamageTypes.DamageInfo, limb: LimbData.Limb) -> bool:
	if limb.part == LimbData.BodyPart.HEAD:
		return false  # Head wounds don't bleed in gameplay terms
	
	match damage_info.type:
		DamageTypes.Type.BULLET, DamageTypes.Type.EXPLOSION, DamageTypes.Type.MELEE:
			return limb.get_health_percent() < 0.4
		_:
			return false

func _start_limb_bleeding(limb: LimbData.Limb, damage_info: DamageTypes.DamageInfo) -> void:
	if not bleeding_system or limb.is_bleeding:
		return
	
	var bleed_rate = damage_info.amount * 0.05  # 5% of damage per second
	bleeding_system.start_bleeding(limb, bleed_rate)

## State updates
func _update_total_health() -> void:
	total_health = _calculate_total_health()
	health_changed.emit(total_health, max_total_health)

func _calculate_total_health() -> float:
	var total = 0.0
	for limb in limbs.values():
		total += limb.current_health
	return total

func _update_character_state() -> void:
	var health_percent = total_health / max_total_health
	var old_state = current_state
	
	if health_percent <= 0.1:
		current_state = CharacterState.NEAR_DEATH
	elif health_percent <= 0.25:
		current_state = CharacterState.CRITICAL
	elif health_percent <= 0.6:
		current_state = CharacterState.WOUNDED
	else:
		current_state = CharacterState.NORMAL
	
	if old_state != current_state:
		state_changed.emit(current_state)

## Gameplay effects (override in player/enemy specific components)
func _apply_limb_effects(limb: LimbData.Limb) -> void:
	# This is called from child classes (PlayerHealthComponent, EnemyHealthComponent)
	pass

## Getters
func get_limb(part: LimbData.BodyPart) -> LimbData.Limb:
	return limbs.get(part)

func get_total_health_percent() -> float:
	return total_health / max_total_health if max_total_health > 0 else 0.0

func is_alive() -> bool:
	return current_state != CharacterState.DEAD

func get_limb_health_percent(part: LimbData.BodyPart) -> float:
	var limb = limbs.get(part)
	return limb.get_health_percent() if limb else 0.0
