# Modified AmmunitionManager.gd - Syncs with Inventory (No Duplication)

extends Node3D
class_name AmmunitionManager

# NEW: Reference to inventory component
var inventory_component: InventoryComponent = null

# These dictionaries now just track ammo TYPE info, not actual amounts
var maxNbPerAmmoDict : Dictionary = {
	"LightAmmo" : 360,
	"MediumAmmo" : 360,
	"HeavyAmmo" : 50,
	"ShellAmmo" : 640,
	"RocketAmmo" : 15,
	"GrenadeAmmo" : 60
}

# NEW: Get actual ammo count directly from inventory
func get_ammo_count(ammo_type: String) -> int:
	if not inventory_component:
		return 0
	
	var total = 0
	for item in inventory_component.get_all_items():
		if item.type == "ammo" and item.attributes.get("ammo_type") == ammo_type:
			total += item.stack_count
	
	return total 

# NEW: Consume ammo from inventory
func consume_ammo(ammo_type: String, amount: int) -> bool:
	if not inventory_component:
		return false
	
	var remaining = amount
	
	# Find all ammo items of this type
	var ammo_items = inventory_component.get_all_items().filter(
		func(item): return item.type == "ammo" and item.attributes.get("ammo_type") == ammo_type
	)
	
	# Check if we have enough total
	var total_available = 0
	for item in ammo_items:
		total_available += item.stack_count
	
	if total_available < amount:
		return false
	
	# Consume from stacks
	for item in ammo_items:
		if remaining <= 0:
			break
		
		var consume_from_this = min(item.stack_count, remaining)
		item.stack_count -= consume_from_this
		remaining -= consume_from_this
		
		# Remove empty stacks
		if item.stack_count <= 0:
			inventory_component.remove_item(item)
	
	return true

# NEW: Add ammo to inventory
func add_ammo(ammo_type: String, amount: int) -> bool:
	if not inventory_component:
		return false
	
	# Try to find existing stacks first
	var ammo_items = inventory_component.get_all_items().filter(
		func(item): return item.type == "ammo" and item.attributes.get("ammo_type") == ammo_type
	)
	
	var remaining = amount
	
	# Fill existing stacks
	for item in ammo_items:
		if remaining <= 0:
			break
		
		var space_in_stack = item.max_stack - item.stack_count
		if space_in_stack > 0:
			var add_amount = min(space_in_stack, remaining)
			item.stack_count += add_amount
			remaining -= add_amount
	
	# Create new stacks for remaining
	while remaining > 0:
		var item = _create_ammo_item(ammo_type, min(remaining, 50)) # 50 = default max stack
		if inventory_component.add_item(item):
			remaining -= item.stack_count
		else:
			# Inventory full
			return false
	
	return true

# NEW: Check if ammo is available in inventory
func has_ammo(ammo_type: String, amount: int) -> bool:
	return get_ammo_count(ammo_type) >= amount

# NEW: Get max ammo for type
func get_max_ammo(ammo_type: String) -> int:
	return maxNbPerAmmoDict.get(ammo_type, 999)

# Helper to create ammo item
func _create_ammo_item(ammo_type: String, amount: int) -> InventoryItem:
	var item = InventoryItem.new()
	
	# Map ammo type to item ID
	var ammo_id_map = {
		"LightAmmo": "ammo_light",
		"MediumAmmo": "ammo_medium",
		"HeavyAmmo": "ammo_heavy",
		"ShellAmmo": "ammo_shell",
		"RocketAmmo": "ammo_rocket",
		"GrenadeAmmo": "ammo_grenade"
	}
	
	var ammo_name_map = {
		"LightAmmo": "Light Ammo",
		"MediumAmmo": "Medium Ammo",
		"HeavyAmmo": "Heavy Ammo",
		"ShellAmmo": "Shotgun Shells",
		"RocketAmmo": "Rockets",
		"GrenadeAmmo": "Grenades"
	}
	
	item.id = ammo_id_map.get(ammo_type, "ammo_unknown")
	item.display_name = ammo_name_map.get(ammo_type, "Unknown Ammo")
	item.type = "ammo"
	item.width = 1
	item.height = 1
	item.stackable = true
	item.max_stack = 50
	item.stack_count = amount
	item.weight = 0.02
	item.attributes = {"ammo_type": ammo_type}
	
	return item

# OLD COMPATIBILITY: These now redirect to inventory
func get_ammo_dict() -> Dictionary:
	# Return current ammo counts from inventory
	var dict = {}
	for ammo_type in maxNbPerAmmoDict.keys():
		dict[ammo_type] = get_ammo_count(ammo_type)
	return dict

# Property to maintain compatibility with old code
var ammoDict: Dictionary:
	get:
		return get_ammo_dict()