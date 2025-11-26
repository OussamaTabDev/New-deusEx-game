class_name InventoryItem extends Resource

## Represents a single item in the inventory system

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var icon: Texture2D
@export var scene_path: String = ""

@export_group("Grid Properties")
@export var width: int = 1
@export var height: int = 1
@export var can_rotate: bool = true

@export_group("Stack Properties")
@export var stackable: bool = false
@export var max_stack: int = 1
@export var stack_count: int = 1

@export_group("Physical Properties")
@export var weight: float = 1.0

@export_group("Item Type")
@export_enum("weapon", "ammo", "consumable", "key", "tool", "armor", "misc") var type: String = "misc"
@export_enum("none", "head", "body", "hands", "belt_1", "belt_2", "primary_weapon", "secondary_weapon", "melee") var equip_slot: String = "none"

@export_group("Attributes")
@export var attributes: Dictionary = {}

# Internal grid position (not exported)
var grid_x: int = -1
var grid_y: int = -1

func _init(
	p_id: String = "",
	p_name: String = "",
	p_width: int = 1,
	p_height: int = 1
):
	id = p_id
	display_name = p_name
	width = p_width
	height = p_height

## Create a copy of this item
func _duplicate() -> InventoryItem:
	var item = InventoryItem.new()
	item.id = id
	item.display_name = display_name
	item.description = description
	item.icon = icon
	item.scene_path = scene_path
	item.width = width
	item.height = height
	item.can_rotate = can_rotate
	item.stackable = stackable
	item.max_stack = max_stack
	item.stack_count = stack_count
	item.weight = weight
	item.type = type
	item.equip_slot = equip_slot
	item.attributes = attributes.duplicate(true)
	return item

## Serialize to dictionary
func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"description": description,
		"icon_path": icon.resource_path if icon else "",
		"scene_path": scene_path,
		"width": width,
		"height": height,
		"can_rotate": can_rotate,
		"stackable": stackable,
		"max_stack": max_stack,
		"stack_count": stack_count,
		"weight": weight,
		"type": type,
		"equip_slot": equip_slot,
		"attributes": attributes,
		"grid_x": grid_x,
		"grid_y": grid_y
	}

## Deserialize from dictionary
static func from_dict(data: Dictionary) -> InventoryItem:
	var item = InventoryItem.new()
	item.id = data.get("id", "")
	item.display_name = data.get("display_name", "")
	item.description = data.get("description", "")
	
	if data.has("icon_path") and data.icon_path != "":
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
	item.grid_x = data.get("grid_x", -1)
	item.grid_y = data.get("grid_y", -1)
	
	return item

## Get total weight including stack
func get_total_weight() -> float:
	return weight * stack_count

## Check if can merge with another item
func can_merge_with(other: InventoryItem) -> bool:
	return stackable and other.stackable and id == other.id and stack_count < max_stack

## Merge another stack into this one
func merge_with(other: InventoryItem) -> int:
	if not can_merge_with(other):
		return 0
	
	var space_available = max_stack - stack_count
	var amount_to_merge = min(space_available, other.stack_count)
	
	stack_count += amount_to_merge
	other.stack_count -= amount_to_merge
	
	return amount_to_merge
