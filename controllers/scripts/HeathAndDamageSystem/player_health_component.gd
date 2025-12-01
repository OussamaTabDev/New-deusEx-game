class_name PlayerHealthComponent
extends HealthComponent

## Player-specific effects
signal screen_effect_triggered(effect_type: String, intensity: float)
signal movement_impaired(speed_multiplier: float)
signal aim_impaired(accuracy_multiplier: float)

@export var player: Player
@export var use_precise_hitboxes: bool = false  # Toggle in editor!

## Effect modifiers (applied to player stats)
var speed_modifier: float = 1.0
var accuracy_modifier: float = 1.0
var reload_speed_modifier: float = 1.0
var melee_damage_modifier: float = 1.0

## Screen effects
var screen_blur_amount: float = 0.0
var screen_desaturation: float = 0.0
var heartbeat_intensity: float = 0.0

# Mapping between limb types and expected hitbox node names
const LIMB_TO_AREA := {
	LimbData.BodyPart.HEAD: "HeadHitbox",
	LimbData.BodyPart.TORSO: "TorsoHitbox",
	LimbData.BodyPart.LEFT_ARM: "LeftArmHitbox",
	LimbData.BodyPart.RIGHT_ARM: "RightArmHitbox",
	LimbData.BodyPart.LEFT_LEG: "LeftLegHitbox",
	LimbData.BodyPart.RIGHT_LEG: "RightLegHitbox"
}

var _area_to_limb: Dictionary = {}


func _ready():
	super._ready()
	
	if not player:
		player = get_parent() as Player
	
	# Build reverse lookup
	for limb in LIMB_TO_AREA:
		var area_name = LIMB_TO_AREA[limb]
		_area_to_limb[area_name] = limb
	
	# Connect hitbox areas if using precise mode
	if use_precise_hitboxes:
		for area_name in _area_to_limb:
			var area = get_node_or_null(area_name)
			if area:
				if area is Area3D:
					area.connect("area_entered", Callable(self, "_on_limb_area_entered").bind(area_name))
				else:
					push_warning("Node '%s' exists but is not an Area3D!" % area_name)
			# else: optional — don't warn if missing during early dev
	else:
		# In fallback mode, ensure no hitboxes are accidentally connected
		pass
	
	# Connect to limb/state signals
	limb_critical.connect(_on_limb_critical)
	limb_destroyed.connect(_on_limb_destroyed)
	state_changed.connect(_on_state_changed)


func _process(delta: float):
	_update_screen_effects(delta)


## Override limb effects for player
func _apply_limb_effects(limb: LimbData.Limb) -> void:
	_recalculate_all_effects()


func _recalculate_all_effects() -> void:
	# Reset modifiers
	speed_modifier = 1.0
	accuracy_modifier = 1.0
	reload_speed_modifier = 1.0
	melee_damage_modifier = 1.0
	screen_blur_amount = 0.0
	screen_desaturation = 0.0
	heartbeat_intensity = 0.0
	
	# Fetch limb data
	var head = get_limb(LimbData.BodyPart.HEAD)
	var torso = get_limb(LimbData.BodyPart.TORSO)
	var left_arm = get_limb(LimbData.BodyPart.LEFT_ARM)
	var right_arm = get_limb(LimbData.BodyPart.RIGHT_ARM)
	var left_leg = get_limb(LimbData.BodyPart.LEFT_LEG)
	var right_leg = get_limb(LimbData.BodyPart.RIGHT_LEG)
	
	# HEAD EFFECTS - Vision and consciousness
	if head.get_health_percent() < 0.5:
		screen_blur_amount = (1.0 - head.get_health_percent() * 2.0) * 0.5
	if head.get_health_percent() < 0.25:
		screen_desaturation = (1.0 - head.get_health_percent() * 4.0) * 0.6
	
	# TORSO EFFECTS - Stamina and vitality
	if torso.get_health_percent() < 0.5:
		heartbeat_intensity = 1.0 - torso.get_health_percent() * 2.0
	if torso.get_health_percent() < 0.3:
		speed_modifier *= 0.85
	if torso.get_health_percent() < 0.15:
		screen_desaturation = max(screen_desaturation, 0.8)
		heartbeat_intensity = 1.0
	
	# ARM EFFECTS - Combat effectiveness
	if right_arm.get_health_percent() < 0.4:
		reload_speed_modifier *= 0.7
		accuracy_modifier *= 0.75
	if left_arm.get_health_percent() < 0.4:
		accuracy_modifier *= 0.8
	if right_arm.get_health_percent() < 0.2:
		melee_damage_modifier *= 0.6
	
	# LEG EFFECTS - Mobility
	if left_leg.get_health_percent() < 0.4 or right_leg.get_health_percent() < 0.4:
		speed_modifier *= 0.7
	if left_leg.get_health_percent() < 0.25 or right_leg.get_health_percent() < 0.25:
		speed_modifier *= 0.5  # Severe limp
	if left_leg.is_destroyed() or right_leg.is_destroyed():
		speed_modifier *= 0.3  # Crawling speed
	
	# Apply to player and emit
	_apply_modifiers_to_player()
	screen_effect_triggered.emit("blur", screen_blur_amount)
	screen_effect_triggered.emit("desaturation", screen_desaturation)
	screen_effect_triggered.emit("heartbeat", heartbeat_intensity)
	movement_impaired.emit(speed_modifier)
	aim_impaired.emit(accuracy_modifier)


func _apply_modifiers_to_player() -> void:
	if not player:
		return
	player.SPEED = player.WALK_SPEED * speed_modifier
	# Extend camera/weapon modifiers here as needed


func _update_screen_effects(delta: float) -> void:
	# Optional: smooth interpolation over time
	pass


## === HITBOX HANDLING ===

func _on_limb_area_entered(area_name: String, other: Node) -> void:
	# Only accept damage sources (customize this logic as needed)
	if not (other is Node3D and other.has_method("get_damage_info")):
		return
	
	var damage_info = other.get_damage_info()
	var hit_pos = other.global_position  # or use contact point if available
	
	var limb = _area_to_limb.get(area_name, LimbData.BodyPart.TORSO)
	apply_damage_to_limb(limb, damage_info)


## Fallback limb detection (used in non-precise mode)
func detect_hit_limb(hit_position: Vector3, hit_normal: Vector3) -> LimbData.BodyPart:
	if not player:
		return LimbData.BodyPart.TORSO

	var local_hit = player.global_transform.inverse() * hit_position

	if local_hit.y > 1.5:
		return LimbData.BodyPart.HEAD
	elif local_hit.y > 0.8:
		return LimbData.BodyPart.TORSO
	elif local_hit.y > 0.3:
		if abs(local_hit.x) > 0.2:
			return LimbData.BodyPart.RIGHT_ARM if local_hit.x > 0 else LimbData.BodyPart.LEFT_ARM
		else:
			return LimbData.BodyPart.TORSO
	else:
		return LimbData.BodyPart.RIGHT_LEG if local_hit.x > 0 else LimbData.BodyPart.LEFT_LEG


## Public API: called by bullets, explosions, etc.
func take_damage(damage_amount: float, damage_type: DamageTypes.Type, hit_pos: Vector3 = Vector3.ZERO, source: Node = null) -> void:
	var limb: LimbData.BodyPart
	
	if use_precise_hitboxes:
		# In precise mode, this function is mainly for non-hitbox damage (e.g. explosions)
		# So we still use position-based fallback
		limb = detect_hit_limb(hit_pos, Vector3.UP)
	else:
		limb = detect_hit_limb(hit_pos, Vector3.UP)
	
	var damage_info = DamageTypes.DamageInfo.new(damage_amount, damage_type, source)
	damage_info.hit_position = hit_pos
	
	apply_damage_to_limb(limb, damage_info)


## === SIGNAL HANDLERS ===

func _on_limb_critical(limb: LimbData.BodyPart) -> void:
	print("WARNING: %s is critically damaged!" % LimbData.get_limb_name(limb))


func _on_limb_destroyed(limb: LimbData.BodyPart) -> void:
	print("CRITICAL: %s has been destroyed!" % LimbData.get_limb_name(limb))


func _on_state_changed(new_state: CharacterState) -> void:
	match new_state:
		CharacterState.WOUNDED:
			print("Player is wounded")
		CharacterState.CRITICAL:
			print("Player is in critical condition!")
		CharacterState.NEAR_DEATH:
			print("Player is near death!")
		CharacterState.DEAD:
			_handle_player_death()


func _handle_player_death() -> void:
	if player:
		player.set_physics_process(false)
		player.set_process_input(false)
		print("PLAYER DIED")


## === GETTERS FOR OTHER SYSTEMS ===

func get_speed_modifier() -> float:
	return speed_modifier

func get_accuracy_modifier() -> float:
	return accuracy_modifier

func get_reload_speed_modifier() -> float:
	return reload_speed_modifier

func can_sprint() -> bool:
	var left_leg = get_limb(LimbData.BodyPart.LEFT_LEG)
	var right_leg = get_limb(LimbData.BodyPart.RIGHT_LEG)
	return left_leg.get_health_percent() > 0.25 and right_leg.get_health_percent() > 0.25

func is_limping() -> bool:
	var left_leg = get_limb(LimbData.BodyPart.LEFT_LEG)
	var right_leg = get_limb(LimbData.BodyPart.RIGHT_LEG)
	return left_leg.get_health_percent() < 0.4 or right_leg.get_health_percent() < 0.4
