
extends Node

## Singleton for managing item definitions and creating items

signal items_loaded()

const ITEMS_PATH = "res://data/items/"

var items: Dictionary = {}

func _ready():
	load_items()

## Load all item definitions from JSON files
func load_items():
	items.clear()
	
	# Load from JSON files
	var dir = DirAccess.open(ITEMS_PATH)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if file_name.ends_with(".json"):
				_load_item_file(ITEMS_PATH + file_name)
			file_name = dir.get_next()
		
		dir.list_dir_end()
	
	# Also load from resources
	_load_item_resources()
	
	items_loaded.emit()
	print("Loaded %d items" % items.size())

func _load_item_file(path: String):
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Failed to open item file: " + path)
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	
	if error != OK:
		push_error("Failed to parse JSON in: " + path)
		return
	
	var data = json.data
	
	# Handle both single item and array of items
	if data is Array:
		for item_data in data:
			_register_item(item_data)
	elif data is Dictionary:
		_register_item(data)

func _load_item_resources():
	# Load .tres item resources if any exist
	var dir = DirAccess.open(ITEMS_PATH)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if file_name.ends_with(".tres"):
				var item = load(ITEMS_PATH + file_name) as InventoryItem
				if item:
					items[item.id] = item
			file_name = dir.get_next()
		
		dir.list_dir_end()

func _register_item(data: Dictionary):
	var item = InventoryItem.new()
	
	item.id = data.get("id", "")
	item.display_name = data.get("display_name", "")
	item.description = data.get("description", "")
	
	if data.has("icon_path"):
		item.icon = load(data.icon_path)
	
	item.scene_path = data.get("scene_path", "")
	item.width = data.get("width", 1)
	item.height = data.get("height", 1)
	item.can_rotate = data.get("can_rotate", true)
	item.stackable = data.get("stackable", false)
	item.max_stack = data.get("max_stack", 1)
	item.stack_count = data.get("stack_count", 1)
	item.weight = data.get("weight", 1.0)
	item.type = data.get("type", "misc")
	item.equip_slot = data.get("equip_slot", "")
	item.attributes = data.get("attributes", {})
	
	items[item.id] = item

## Create a new item instance from database
func create_item(item_id: String, count: int = 1) -> InventoryItem:
	# Returns ONE item (clamped to max_stack)
	# Use create_items() below for multiple!
	if not items.has(item_id):
		push_error("Item not found in database: " + item_id)
		return null
	
	var template = items[item_id]
	var item = template.duplicate()
	item.stack_count = min(count, item.max_stack)
	item.stack_count = max(1, item.stack_count)  # at least 1
	return item

# NEW: create multiple items if needed
func create_items(item_id: String, total_count: int) -> Array[InventoryItem]:
	var items_list: Array[InventoryItem] = []
	var remaining = total_count
	while remaining > 0:
		var chunk_count = min(remaining, get_item_template(item_id).max_stack)
		items_list.append(create_item(item_id, chunk_count))
		remaining -= chunk_count
	return items_list

## Get item template (don't modify!)
func get_item_template(item_id: String) -> InventoryItem:
	return items.get(item_id)

## Check if item exists
func has_item(item_id: String) -> bool:
	return items.has(item_id)

## Get all item IDs
func get_all_item_ids() -> Array:
	return items.keys()

## Get items by type
func get_items_by_type(type: String) -> Array[InventoryItem]:
	var result: Array[InventoryItem] = []
	
	for item in items.values():
		if item.type == type:
			result.append(item)
	
	return result

# ## Create example items JSON (for setup)
# static func create_example_items_json() -> String:
# 	var examples = [
# 		{
# 			"id": "pistol_9mm",
# 			"display_name": "9mm Pistol",
# 			"description": "A reliable sidearm.",
# 			"icon_path": "res://icons/pistol.png",
# 			"width": 2,
# 			"height": 1,
# 			"stackable": false,
# 			"weight": 1.5,
# 			"type": "weapon",
# 			"equip_slot": "secondary_weapon",
# 			"attributes": {
# 				"ammo_type": "9mm",
# 				"damage": 15,
# 				"mag_size": 12,
# 				"fire_rate": 0.2
# 			}
# 		},
# 		{
# 			"id": "ammo_9mm",
# 			"display_name": "9mm Rounds",
# 			"description": "Standard 9mm ammunition.",
# 			"icon_path": "res://icons/9mm.png",
# 			"width": 1,
# 			"height": 1,
# 			"stackable": true,
# 			"max_stack": 50,
# 			"weight": 0.02,
# 			"type": "ammo",
# 			"attributes": {
# 				"ammo_type": "9mm"
# 			}
# 		},
# 		{
# 			"id": "medkit",
# 			"display_name": "Medical Kit",
# 			"description": "Restores 50 health.",
# 			"icon_path": "res://icons/medkit.png",
# 			"width": 1,
# 			"height": 1,
# 			"stackable": true,
# 			"max_stack": 5,
# 			"weight": 0.5,
# 			"type": "consumable",
# 			"attributes": {
# 				"heal_amount": 50
# 			}
# 		},
# 		{
# 			"id": "energy_bar",
# 			"display_name": "Energy Bar",
# 			"description": "Restores 25 stamina.",
# 			"icon_path": "res://icons/energy_bar.png",
# 			"width": 1,
# 			"height": 1,
# 			"stackable": true,
# 			"max_stack": 10,
# 			"weight": 0.1,
# 			"type": "consumable",
# 			"attributes": {
# 				"stamina_amount": 25
# 			}
# 		},
# 		{
# 			"id": "keycard_red",
# 			"display_name": "Red Keycard",
# 			"description": "Opens red doors.",
# 			"icon_path": "res://icons/keycard_red.png",
# 			"width": 1,
# 			"height": 1,
# 			"stackable": false,
# 			"weight": 0.1,
# 			"type": "key"
# 		},
# 		{
# 			"id": "armor_vest",
# 			"display_name": "Ballistic Vest",
# 			"description": "Reduces damage by 30%.",
# 			"icon_path": "res://icons/vest.png",
# 			"width": 2,
# 			"height": 2,
# 			"stackable": false,
# 			"weight": 3.0,
# 			"type": "armor",
# 			"equip_slot": "body",
# 			"attributes": {
# 				"armor_value": 30
# 			}
# 		}
# 	]
	
# 	return JSON.stringify(examples, "\t")
