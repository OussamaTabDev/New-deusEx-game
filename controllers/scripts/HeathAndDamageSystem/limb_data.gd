class_name LimbData
extends Resource

## Body part enumeration
enum BodyPart {
	HEAD,
	TORSO,
	LEFT_ARM,
	RIGHT_ARM,
	LEFT_LEG,
	RIGHT_LEG
}

## Individual limb state
class Limb:
	var part: BodyPart
	var max_health: float
	var current_health: float
	var is_bleeding: bool = false
	var bleed_rate: float = 0.0
	var is_fractured: bool = false
	var is_augmented: bool = false
	var aug_malfunction: bool = false
	var trauma_level: int = 0  # 0-5, increases with repeated hits
	
	func _init(body_part: BodyPart, max_hp: float):
		part = body_part
		max_health = max_hp
		current_health = max_hp
	
	func get_health_percent() -> float:
		return current_health / max_health if max_health > 0 else 0.0
	
	func is_critical() -> bool:
		return get_health_percent() <= 0.25
	
	func is_destroyed() -> bool:
		return current_health <= 0
	
	func apply_damage(amount: float) -> void:
		current_health = max(0, current_health - amount)
		trauma_level = min(5, trauma_level + 1)
	
	func heal(amount: float) -> void:
		current_health = min(max_health, current_health + amount)
		if current_health > max_health * 0.4:
			is_bleeding = false
			bleed_rate = 0.0

## Limb weight configuration (from PRD)
const LIMB_WEIGHTS = {
	BodyPart.HEAD: 0.20,
	BodyPart.TORSO: 0.30,
	BodyPart.RIGHT_ARM: 0.125,
	BodyPart.LEFT_ARM: 0.125,
	BodyPart.RIGHT_LEG: 0.125,
	BodyPart.LEFT_LEG: 0.125
}

## Get limb name as string
static func get_limb_name(part: BodyPart) -> String:
	match part:
		BodyPart.HEAD: return "Head"
		BodyPart.TORSO: return "Torso"
		BodyPart.LEFT_ARM: return "Left Arm"
		BodyPart.RIGHT_ARM: return "Right Arm"
		BodyPart.LEFT_LEG: return "Left Leg"
		BodyPart.RIGHT_LEG: return "Right Leg"
		_: return "Unknown"
