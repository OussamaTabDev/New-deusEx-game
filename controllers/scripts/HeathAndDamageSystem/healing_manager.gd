## Healing manager component
class_name HealingManager
extends Node

signal healing_started(item: HealingItem, limb: LimbData.BodyPart)
signal healing_progress(progress: float)
signal healing_complete(item: HealingItem)
signal healing_interrupted()

var current_usage: HealingItem.HealingItemUsage = null
var is_healing: bool = false

func _process(delta: float):
	if not is_healing or not current_usage:
		return
	
	current_usage.process(delta)
	healing_progress.emit(current_usage.get_progress())
	
	if current_usage.is_complete:
		_complete_healing()

func use_item(item: HealingItem, health_component: HealthComponent, limb: LimbData.BodyPart = LimbData.BodyPart.TORSO) -> bool:
	if is_healing:
		return false  # Already healing
	
	current_usage = HealingItem.HealingItemUsage.new(item, health_component, limb)
	is_healing = true
	healing_started.emit(item, limb)
	return true

func interrupt_healing() -> void:
	if not is_healing:
		return
	
	current_usage = null
	is_healing = false
	healing_interrupted.emit()

func _complete_healing() -> void:
	var item = current_usage.item
	current_usage = null
	is_healing = false
	healing_complete.emit(item)

func can_use_item() -> bool:
	return not is_healing
