class_name ArmorModule
extends Node

enum ArmorType {
	NONE,
	KEVLAR_SOFT,
	CERAMIC_PLATE,
	NANO_SKIN
}

@export var armor_type: ArmorType = ArmorType.NONE
@export var armor_condition: float = 100.0  # Degrades over time
@export var max_armor_condition: float = 100.0

## Armor damage reduction per type and damage type
const ARMOR_RESISTANCES = {
	ArmorType.KEVLAR_SOFT: {
		DamageTypes.Type.BULLET: 0.6,
		DamageTypes.Type.MELEE: 0.4,
		DamageTypes.Type.FIRE: 0.2,
		DamageTypes.Type.EXPLOSION: 0.3,
		DamageTypes.Type.ELECTRICAL: 0.5,
		DamageTypes.Type.EMP_NANO_VIRAL: 0.5
	},
	ArmorType.CERAMIC_PLATE: {
		DamageTypes.Type.BULLET: 0.8,
		DamageTypes.Type.MELEE: 0.6,
		DamageTypes.Type.FIRE: 0.5,
		DamageTypes.Type.EXPLOSION: 0.3,
		DamageTypes.Type.ELECTRICAL: 0.5,
		DamageTypes.Type.EMP_NANO_VIRAL: 0.5
	},
	ArmorType.NANO_SKIN: {
		DamageTypes.Type.BULLET: 0.5,
		DamageTypes.Type.MELEE: 0.5,
		DamageTypes.Type.FIRE: 0.5,
		DamageTypes.Type.EXPLOSION: 0.5,
		DamageTypes.Type.ELECTRICAL: 0.3,
		DamageTypes.Type.EMP_NANO_VIRAL: 0.2
	}
}

func calculate_damage_reduction(damage_info: DamageTypes.DamageInfo) -> float:
	if armor_type == ArmorType.NONE or armor_condition <= 0:
		return 1.0  # No reduction
	
	var condition_factor = armor_condition / max_armor_condition
	var base_reduction = ARMOR_RESISTANCES.get(armor_type, {}).get(damage_info.type, 0.5)
	
	# Armor effectiveness scales with condition
	var effective_reduction = base_reduction * condition_factor
	
	# Degrade armor
	degrade_armor(damage_info.amount * 0.1)
	
	return 1.0 - effective_reduction

func degrade_armor(amount: float) -> void:
	armor_condition = max(0, armor_condition - amount)

func repair_armor(amount: float) -> void:
	armor_condition = min(max_armor_condition, armor_condition + amount)

func get_armor_percent() -> float:
	return armor_condition / max_armor_condition if max_armor_condition > 0 else 0.0
