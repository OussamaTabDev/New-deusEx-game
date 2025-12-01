class_name HealingItem
extends Resource

enum ItemType {
	MEDKIT,
	TRAUMA_KIT,
	NANO_REGEN_SERUM,
	AUG_REPAIR_PATCH,
	BANDAGE
}

@export var item_type: ItemType
@export var display_name: String
@export var heal_amount: float
@export var use_time: float = 2.0
@export var stops_bleeding: bool = false
@export var can_target_limb: bool = true

func get_description() -> String:
	match item_type:
		ItemType.MEDKIT:
			return "Standard medkit. Heals 30% of limb health slowly."
		ItemType.TRAUMA_KIT:
			return "Advanced trauma kit. Prioritizes torso/head and stops bleeding."
		ItemType.NANO_REGEN_SERUM:
			return "Experimental nano-tech. Regenerates all body parts gradually."
		ItemType.AUG_REPAIR_PATCH:
			return "Repairs damaged augmentations instantly. Risk of overcharge!"
		ItemType.BANDAGE:
			return "Quick bandage. Stops bleeding but doesn't heal much."
		_:
			return "Unknown item"

## Healing logic
class HealingItemUsage:
	var item: HealingItem
	var target_health_component: HealthComponent
	var target_limb: LimbData.BodyPart
	var use_timer: float = 0.0
	var is_complete: bool = false
	
	func _init(healing_item: HealingItem, health_comp: HealthComponent, limb: LimbData.BodyPart = LimbData.BodyPart.TORSO):
		item = healing_item
		target_health_component = health_comp
		target_limb = limb
	
	func process(delta: float) -> void:
		if is_complete:
			return
		
		use_timer += delta
		
		if use_timer >= item.use_time:
			_apply_healing()
			is_complete = true
	
	func _apply_healing() -> void:
		match item.item_type:
			HealingItem.ItemType.MEDKIT:
				target_health_component.heal_limb(target_limb, item.heal_amount, false)
			
			HealingItem.ItemType.TRAUMA_KIT:
				# Prioritize critical limbs
				var head = target_health_component.get_limb(LimbData.BodyPart.HEAD)
				var torso = target_health_component.get_limb(LimbData.BodyPart.TORSO)
				
				if head.is_critical():
					target_health_component.heal_limb(LimbData.BodyPart.HEAD, item.heal_amount, true)
				elif torso.is_critical():
					target_health_component.heal_limb(LimbData.BodyPart.TORSO, item.heal_amount, true)
				else:
					target_health_component.heal_limb(target_limb, item.heal_amount, true)
			
			HealingItem.ItemType.NANO_REGEN_SERUM:
				target_health_component.heal_all(item.heal_amount, false)
			
			HealingItem.ItemType.BANDAGE:
				target_health_component.heal_limb(target_limb, item.heal_amount * 0.5, true)
			
			HealingItem.ItemType.AUG_REPAIR_PATCH:
				target_health_component.heal_limb(target_limb, item.heal_amount, false)
				# You can add augmentation-specific repair logic here
	
	func get_progress() -> float:
		return use_timer / item.use_time if item.use_time > 0 else 1.0
