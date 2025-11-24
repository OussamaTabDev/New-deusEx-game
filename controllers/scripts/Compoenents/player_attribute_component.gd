class_name PlayerAttributeComponent
extends Node

## Manages player attributes like health, stamina, sanity, visibility
## Usage: Add as child node to Player, then add CogitoAttribute nodes as children

signal attribute_changed(attribute_name: String, old_value: float, new_value: float)
signal player_died()

@export var is_logging: bool = false

var player_attributes: Dictionary = {}
var stamina_attribute: CogitoAttribute = null
var health_attribute: CogitoAttribute = null
var visibility_attribute: CogitoAttribute = null
var sanity_attribute: CogitoAttribute = null

func _ready():
	# Wait one frame to ensure all child nodes are ready
	await get_tree().process_frame
	_setup_attributes()

func _setup_attributes():
	# Find all CogitoAttribute children
	for attribute in find_children("", "CogitoAttribute", false):
		player_attributes[attribute.attribute_name] = attribute
		_log("Cogito Attribute found: " + attribute.attribute_name)
	
	# Cache commonly used attributes
	health_attribute = player_attributes.get("health")
	stamina_attribute = player_attributes.get("stamina")
	visibility_attribute = player_attributes.get("visibility")
	sanity_attribute = player_attributes.get("sanity")
	
	# Connect health to death signal
	if health_attribute:
		health_attribute.death.connect(_on_death)
	
	# Connect visibility to sanity
	if sanity_attribute and visibility_attribute:
		visibility_attribute.attribute_changed.connect(sanity_attribute.on_visibility_changed)
		visibility_attribute.check_current_visibility()

func increase_attribute(attribute_name: String, value: float, value_type = 0) -> bool:
	var attribute = player_attributes.get(attribute_name)
	if not attribute:
		_log("Increase attribute: Attribute '" + attribute_name + "' not found")
		return false
	
	# value_type: 0 = CURRENT, 1 = MAX
	if value_type == 0:  # CURRENT
		if attribute.value_current >= attribute.value_max:
			return false
		attribute.add(value)
		attribute_changed.emit(attribute_name, attribute.value_current - value, attribute.value_current)
		return true
	elif value_type == 1:  # MAX
		attribute.value_max += value
		attribute.add(value)
		attribute_changed.emit(attribute_name, attribute.value_current - value, attribute.value_current)
		return true
	return false

func decrease_attribute(attribute_name: String, value: float) -> void:
	var attribute = player_attributes.get(attribute_name)
	if not attribute:
		_log("Decrease attribute: " + attribute_name + " - Attribute not found")
		return
	
	var old_value = attribute.value_current
	attribute.subtract(value)
	attribute_changed.emit(attribute_name, old_value, attribute.value_current)

func get_attribute_value(attribute_name: String) -> float:
	var attribute = player_attributes.get(attribute_name)
	if attribute:
		return attribute.value_current
	return 0.0

func get_attribute_max(attribute_name: String) -> float:
	var attribute = player_attributes.get(attribute_name)
	if attribute:
		return attribute.value_max
	return 0.0

func has_attribute(attribute_name: String) -> bool:
	return player_attributes.has(attribute_name)

func has_stamina(amount: float) -> bool:
	if not stamina_attribute:
		return true  # No stamina system, allow action
	return stamina_attribute.value_current >= amount

func _on_death():
	player_died.emit()

func _log(message: String):
	if is_logging:
		print("[PlayerAttributeComponent] ", message)