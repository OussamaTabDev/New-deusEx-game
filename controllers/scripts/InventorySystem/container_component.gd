class_name ContainerComponent extends Node3D

## Represents a lootable container in the world (chest, locker, crate, etc.)

signal opened(player: Player)
signal closed()
signal looted()

@export var container_name: String = "Container"
@export var grid_columns: int = 6
@export var grid_rows: int = 6
@export var is_locked: bool = false
@export var required_key_id: String = ""
@export var loot_table: Array[Dictionary] = []
@export var auto_generate_loot: bool = true

var inventory: InventoryComponent
var is_open: bool = false
var current_player: Player = null

func _ready():
	# Create inventory component
	inventory = InventoryComponent.new()
	inventory.grid_columns = grid_columns
	inventory.grid_rows = grid_rows
	inventory.enable_weight_limit = false
	add_child(inventory)
	
	if auto_generate_loot:
		_generate_loot()

## Try to open container
func try_open(player: Player) -> bool:
	if is_open:
		return false
	
	if is_locked:
		if not _has_key(player):
			push_error("Container is locked!")
			return false
	
	current_player = player
	is_open = true
	opened.emit(player)
	return true

## Close container
func close():
	if not is_open:
		return
	
	is_open = false
	current_player = null
	closed.emit()

## Transfer item from player to container
func transfer_from_player(player_inventory: InventoryComponent, item: InventoryItem, x: int = -1, y: int = -1) -> bool:
	if not is_open:
		return false
	
	if not player_inventory.remove_item(item):
		return false
	
	if x >= 0 and y >= 0:
		if inventory.place_item(item, x, y):
			return true
	else:
		if inventory.add_item(item):
			return true
	
	# Failed to place, return to player
	player_inventory.add_item(item)
	return false

## Transfer item from container to player
func transfer_to_player(player_inventory: InventoryComponent, item: InventoryItem, x: int = -1, y: int = -1) -> bool:
	if not is_open:
		return false
	
	if not inventory.remove_item(item):
		return false
	
	if x >= 0 and y >= 0:
		if player_inventory.place_item(item, x, y):
			return true
	else:
		if player_inventory.add_item(item):
			return true
	
	# Failed to place, return to container
	inventory.add_item(item)
	return false

## Take all items
func loot_all(player_inventory: InventoryComponent):
	var items = inventory.get_all_items().duplicate()
	
	for item in items:
		transfer_to_player(player_inventory, item)
	
	looted.emit()

func _has_key(player: Player) -> bool:
	if required_key_id == "":
		return true
	
	var player_inventory = player.get_node_or_null("InventoryComponent")
	if not player_inventory:
		return false
	
	for item in player_inventory.get_all_items():
		if item.id == required_key_id:
			return true
	
	return false

func _generate_loot():
	if loot_table.is_empty():
		return
	
	for loot_entry in loot_table:
		var item_id = loot_entry.get("item_id", "")
		var chance = loot_entry.get("chance", 1.0)
		var min_count = loot_entry.get("min_count", 1)
		var max_count = loot_entry.get("max_count", 1)
		
		if randf() <= chance:
			var count = randi_range(min_count, max_count)
			
			# Create item from database
			var item = _create_item_from_id(item_id)
			if item:
				item.stack_count = count
				inventory.add_item(item)

func _create_item_from_id(item_id: String) -> InventoryItem:
	# Load from item database
	# For now, return null - implement based on your item database system
	return null

## Save container state
func save_to_dict() -> Dictionary:
	return {
		"container_name": container_name,
		"is_locked": is_locked,
		"inventory": inventory.save_to_dict(),
		"position": global_position,
		"rotation": global_rotation
	}

## Load container state
func load_from_dict(data: Dictionary):
	container_name = data.get("container_name", container_name)
	is_locked = data.get("is_locked", is_locked)
	
	if data.has("inventory"):
		inventory.load_from_dict(data.inventory)
	
	if data.has("position"):
		global_position = data.position
	if data.has("rotation"):
		global_rotation = data.rotation