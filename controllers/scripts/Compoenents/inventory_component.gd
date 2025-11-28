class_name InventoryComponent extends Node

## Core inventory system component for Deus Ex-style grid-based inventory
## Attach to Player node

signal item_added(item: InventoryItem, x: int, y: int)
signal item_removed(item: InventoryItem)
signal item_moved(item: InventoryItem, from_x: int, from_y: int, to_x: int, to_y: int)
signal item_equipped(item: InventoryItem, slot: String)
signal item_unequipped(item: InventoryItem, slot: String)
signal stack_split(original: InventoryItem, new_stack: InventoryItem)
signal inventory_full()
signal hotbar_item_used(slot: int, item: InventoryItem)

@export var grid_columns: int = 8
@export var grid_rows: int = 10
@export var max_weight: float = 100.0
@export var hotbar_slots: int = 8
@export var enable_weight_limit: bool = false

# Grid storage: key = "x,y", value = {item: InventoryItem, is_origin: bool}
var grid: Dictionary = {}
var equipment_slots: Dictionary = {}
var hotbar: Array[InventoryItem] = []
var current_weight: float = 0.0

# Item database
var item_database: Dictionary = {}

func _ready():
	_initialize_equipment_slots()
	_initialize_hotbar()
	_load_item_database()

func _initialize_equipment_slots():
	equipment_slots = {
		"head": null,
		"body": null,
		"hands": null,
		"belt_1": null,
		"belt_2": null,
		"primary_weapon": null,
		"secondary_weapon": null,
		"melee": null
	}

func _initialize_hotbar():
	hotbar.resize(hotbar_slots)
	for i in hotbar_slots:
		hotbar[i] = null

func _load_item_database():
	# Load from JSON or Resources
	# For now, creating a sample database
	pass

## Check if item can be placed at position
func can_place_item(item: InventoryItem, x: int, y: int, ignore_item: InventoryItem = null) -> bool:
	if x < 0 or y < 0:
		return false
	if x + item.width > grid_columns or y + item.height > grid_rows:
		return false
	
	# Check weight limit
	if enable_weight_limit and current_weight + item.weight > max_weight:
		return false
	
	# Check if cells are occupied
	for ix in range(item.width):
		for iy in range(item.height):
			var key = _grid_key(x + ix, y + iy)
			if grid.has(key):
				var cell = grid[key]
				# Fix: Ensure we are comparing objects correctly
				if cell.item != item and cell.item != ignore_item:
					return false
	
	return true

## Place item at position
func place_item(item: InventoryItem, x: int, y: int) -> bool:
	if not can_place_item(item, x, y):
		return false
	
	# Mark all cells occupied by this item
	for ix in range(item.width):
		for iy in range(item.height):
			var key = _grid_key(x + ix, y + iy)
			grid[key] = {
				"item": item,
				"is_origin": (ix == 0 and iy == 0)
			}
	
	item.grid_x = x
	item.grid_y = y
	current_weight += item.weight
	item_added.emit(item, x, y)
	return true

## Remove item from grid
func remove_item(item: InventoryItem) -> bool:
	if item.grid_x == -1 or item.grid_y == -1:
		return false
	
	# Clear all cells occupied by this item
	for ix in range(item.width):
		for iy in range(item.height):
			var key = _grid_key(item.grid_x + ix, item.grid_y + iy)
			grid.erase(key)
	
	current_weight -= item.weight
	item.grid_x = -1
	item.grid_y = -1
	item_removed.emit(item)
	return true

## Move item to new position
func move_item(item: InventoryItem, to_x: int, to_y: int) -> bool:
	var from_x = item.grid_x
	var from_y = item.grid_y
	
	if not remove_item(item):
		return false
	
	if place_item(item, to_x, to_y):
		item_moved.emit(item, from_x, from_y, to_x, to_y)
		return true
	else:
		# Restore to original position
		place_item(item, from_x, from_y)
		return false

## Find free space for item
func find_free_space(item: InventoryItem) -> Vector2i:
	for y in range(grid_rows):
		for x in range(grid_columns):
			if can_place_item(item, x, y):
				return Vector2i(x, y)
	return Vector2i(-1, -1)

## Add item to inventory (auto-placement)
func add_item(item: InventoryItem) -> bool:
	# Try to stack with existing items
	if item.stackable:
		for y in range(grid_rows):
			for x in range(grid_columns):
				var key = _grid_key(x, y)
				if grid.has(key) and grid[key].is_origin:
					var existing = grid[key].item
					if existing.id == item.id and existing.stack_count < existing.max_stack:
						var space_available = existing.max_stack - existing.stack_count
						var amount_to_add = min(space_available, item.stack_count)
						existing.stack_count += amount_to_add
						item.stack_count -= amount_to_add
						
						if item.stack_count <= 0:
							return true
	
	# Find free space
	var pos = find_free_space(item)
	if pos.x >= 0:
		return place_item(item, pos.x, pos.y)
	
	inventory_full.emit()
	return false

## Split stack
func split_stack(item: InventoryItem, amount: int) -> InventoryItem:
	if not item.stackable or amount <= 0 or amount >= item.stack_count:
		return null
	
	var new_item = item.duplicate()
	new_item.stack_count = amount
	item.stack_count -= amount
	
	stack_split.emit(item, new_item)
	return new_item

## Equip item to slot
func equip_item(item: InventoryItem, slot: String) -> bool:
	if not equipment_slots.has(slot):
		return false
	
	if item.equip_slot != slot:
		return false
	
	# Unequip current item in slot
	if equipment_slots[slot] != null:
		unequip_item(slot)
	
	# Remove from grid if present
	if item.grid_x >= 0 and item.grid_y >= 0:
		remove_item(item)
	
	equipment_slots[slot] = item
	item_equipped.emit(item, slot)
	return true

## Unequip item from slot
func unequip_item(slot: String) -> bool:
	if not equipment_slots.has(slot):
		return false
	
	var item = equipment_slots[slot]
	if item == null:
		return false
	
	# Try to place back in inventory
	var pos = find_free_space(item)
	if pos.x >= 0:
		equipment_slots[slot] = null
		place_item(item, pos.x, pos.y)
		item_unequipped.emit(item, slot)
		return true
	
	inventory_full.emit()
	return false

## Set hotbar slot
func set_hotbar_slot(slot: int, item: InventoryItem) -> bool:
	if slot < 0 or slot >= hotbar_slots:
		return false
	
	hotbar[slot] = item
	return true

## Use hotbar slot
func use_hotbar_slot(slot: int):
	if slot < 0 or slot >= hotbar_slots:
		return
	
	var item = hotbar[slot]
	if item == null:
		return
	
	hotbar_item_used.emit(slot, item)
	
	# Handle item usage based on type
	match item.type:
		"consumable":
			_use_consumable(item)
		"weapon":
			_equip_weapon(item)
		_:
			pass

## Get item at grid position
func get_item_at(x: int, y: int) -> InventoryItem:
	var key = _grid_key(x, y)
	if grid.has(key):
		return grid[key].item
	return null

## Get all items in inventory
func get_all_items() -> Array[InventoryItem]:
	var items: Array[InventoryItem] = []
	var seen = {}
	
	for key in grid.keys():
		var cell = grid[key]
		if cell.is_origin:
			var item = cell.item
			if not seen.has(item):
				items.append(item)
				seen[item] = true
	
	return items

## Rotate item
func rotate_item(item: InventoryItem) -> bool:
	if item.grid_x < 0 or item.grid_y < 0:
		return false
	
	var old_w = item.width
	var old_h = item.height
	
	# Swap dimensions
	item.width = old_h
	item.height = old_w
	
	# Check if still fits
	if can_place_item(item, item.grid_x, item.grid_y, item):
		# Remove and replace
		var x = item.grid_x
		var y = item.grid_y
		remove_item(item)
		return place_item(item, x, y)
	else:
		# Revert rotation
		item.width = old_w
		item.height = old_h
		return false

## Save inventory to dictionary
func save_to_dict() -> Dictionary:
	var save_data = {
		"items": [],
		"equipment": {},
		"hotbar": [],
		"weight": current_weight
	}
	
	# Save grid items
	for item in get_all_items():
		save_data.items.append(item.to_dict())
	
	# Save equipment
	for slot in equipment_slots.keys():
		if equipment_slots[slot] != null:
			save_data.equipment[slot] = equipment_slots[slot].to_dict()
	
	# Save hotbar
	for i in hotbar.size():
		if hotbar[i] != null:
			save_data.hotbar.append({"slot": i, "item_id": hotbar[i].id})
	
	return save_data

## Load inventory from dictionary
func load_from_dict(data: Dictionary):
	clear_inventory()
	
	# Load items
	if data.has("items"):
		for item_data in data.items:
			var item = InventoryItem.from_dict(item_data)
			place_item(item, item.grid_x, item.grid_y)
	
	# Load equipment
	if data.has("equipment"):
		for slot in data.equipment.keys():
			var item = InventoryItem.from_dict(data.equipment[slot])
			equipment_slots[slot] = item

## Clear entire inventory
func clear_inventory():
	grid.clear()
	for slot in equipment_slots.keys():
		equipment_slots[slot] = null
	for i in hotbar.size():
		hotbar[i] = null
	current_weight = 0.0

## Auto-organize inventory
func auto_organize():
	var items = get_all_items()
	clear_inventory()
	
	# Sort by size (larger first)
	items.sort_custom(func(a, b): return a.width * a.height > b.width * b.height)
	
	for item in items:
		add_item(item)

## Get equipped weapon
func get_equipped_weapon(slot: String = "primary_weapon") -> InventoryItem:
	if equipment_slots.has(slot):
		return equipment_slots[slot]
	return null

## Get ammo for weapon
func get_ammo_for_weapon(weapon: InventoryItem) -> Array[InventoryItem]:
	var ammo_items: Array[InventoryItem] = []
	
	if not weapon or not weapon.attributes.has("ammo_type"):
		return ammo_items
	
	var ammo_type = weapon.attributes.ammo_type
	
	for item in get_all_items():
		if item.type == "ammo" and item.attributes.get("ammo_type") == ammo_type:
			ammo_items.append(item)
	
	return ammo_items

## Consume ammo
func consume_ammo(weapon: InventoryItem, amount: int = 1) -> bool:
	var ammo_items = get_ammo_for_weapon(weapon)
	
	var remaining = amount
	for ammo in ammo_items:
		if ammo.stack_count >= remaining:
			ammo.stack_count -= remaining
			if ammo.stack_count <= 0:
				remove_item(ammo)
			return true
		else:
			remaining -= ammo.stack_count
			remove_item(ammo)
	
	return false

# Private helper methods

func _grid_key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]

func _use_consumable(item: InventoryItem):
	# Implement consumable logic
	item.stack_count -= 1
	if item.stack_count <= 0:
		remove_item(item)

func _equip_weapon(item: InventoryItem):
	if item.attributes.get("primary_weapon", false):
		equip_item(item, "primary_weapon")
	else:
		equip_item(item, "secondary_weapon")
