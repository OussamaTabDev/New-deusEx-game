class_name InventoryComponent extends Node

## Core inventory system component for Deus Ex-style grid-based inventory
## Attach to Player node

signal item_added(item: InventoryItem, x: int, y: int)
signal item_removed(item: InventoryItem)
signal item_moved(item: InventoryItem, from_x: int, from_y: int, to_x: int, to_y: int)
signal item_equipped(item: InventoryItem, slot: String)
signal item_unequipped(item: InventoryItem, slot: String)
signal item_rotated(item: InventoryItem, old_w: int, old_h: int) # Added for UI/Stat updates
signal item_dropped(item: InventoryItem, source: String)
signal stack_changed(item: InventoryItem, new_count: int)
signal stack_split(original: InventoryItem, new_stack: InventoryItem)

signal inventory_full()
signal hotbar_item_used(slot: int, item: InventoryItem)

@export var player : Player 
@export var grid_columns: int = 8
@export var grid_rows: int = 10
@export var max_weight: float = 100.0
@export var hotbar_slots: int = 8
@export var enable_weight_limit: bool = false
@export var drop_marker : Marker3D
@export var weapon_manager : WeaponManager
# Grid storage: key = "x,y", value = {item: InventoryItem, is_origin: bool}
var grid: Dictionary = {}
var equipment_slots: Dictionary = {}
var hotbar: Array[InventoryItem] = []
var current_weight: float = 0.0

# Item database (Placeholder for external data loading)
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
    # Load item definitions from resources/files here
    pass

## Check if item can be placed at position
func can_place_item(item: InventoryItem, x: int, y: int, ignore_item: InventoryItem = null) -> bool:
    # 1. Bounds check
    if x < 0 or y < 0:
        return false
    if x + item.width > grid_columns or y + item.height > grid_rows:
        return false
    
    # 2. Weight check
    # Note: We subtract the item's weight if it's the one being ignored (i.e., it's currently in the inventory)
    var weight_to_check = current_weight + item.weight
    if ignore_item and ignore_item == item:
        weight_to_check -= item.weight
    
    if enable_weight_limit and weight_to_check > max_weight:
        return false
    
    # 3. Collision check
    for ix in range(item.width):
        for iy in range(item.height):
            var key = _grid_key(x + ix, y + iy)
            if grid.has(key):
                var cell = grid[key]
                # Allow collision only if the colliding item is the one we are explicitly ignoring
                if cell.item != ignore_item: 
                    return false
    
    return true

## Place item at position
func place_item(item: InventoryItem, x: int, y: int) -> bool:
    if not can_place_item(item, x, y):
        return false
    
    for ix in range(item.width):
        for iy in range(item.height):
            var key = _grid_key(x + ix, y + iy)
            grid[key] = {
                "item": item,
                "is_origin": (ix == 0 and iy == 0)
            }
    
    item.grid_x = x
    item.grid_y = y
    
    # Only update weight if item was previously unplaced (-1, -1)
    if item.grid_x == -1 and item.grid_y == -1: 
        current_weight += item.weight
    
    item_added.emit(item, x, y)
    return true

## Remove item from grid
func remove_item(item: InventoryItem) -> bool:
    var original_x = item.grid_x
    var original_y = item.grid_y
    
    if original_x == -1 or original_y == -1:
        return false
    
    for ix in range(item.width):
        for iy in range(item.height):
            var key = _grid_key(original_x + ix, original_y + iy)
            if grid.has(key) and grid[key].item == item:
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
    
    # Check if placement is valid, ignoring the item's current position/weight
    if not can_place_item(item, to_x, to_y, item):
        return false
        
    # Temporary removal (removes grid cells but keeps weight the same via ignore in can_place_item)
    var success = true
    for ix in range(item.width):
        for iy in range(item.height):
            var key = _grid_key(from_x + ix, from_y + iy)
            if grid.has(key): grid.erase(key)
            
    # Re-place at new position
    for ix in range(item.width):
        for iy in range(item.height):
            var key = _grid_key(to_x + ix, to_y + iy)
            grid[key] = {
                "item": item,
                "is_origin": (ix == 0 and iy == 0)
            }

    item.grid_x = to_x
    item.grid_y = to_y
    item_moved.emit(item, from_x, from_y, to_x, to_y)
    return true


## Attempt to merge source item into target item
func try_merge_stack(source_item: InventoryItem, target_item: InventoryItem) -> bool:
    if source_item == target_item: return false
    if source_item.id != target_item.id: return false
    if not target_item.stackable: return false
    if target_item.stack_count >= target_item.max_stack: return false
    
    var space = target_item.max_stack - target_item.stack_count
    var transfer_amount = min(source_item.stack_count, space)
    
    target_item.stack_count += transfer_amount
    source_item.stack_count -= transfer_amount
    
    stack_changed.emit(target_item, target_item.stack_count)
    
    if source_item.stack_count <= 0:
        remove_item(source_item) # Will emit item_removed
        return true
    else:
        stack_changed.emit(source_item, source_item.stack_count)
        return false

## Quick transfer item to another inventory component
func transfer_item(item: InventoryItem, target_inv: InventoryComponent) -> bool:
    if not target_inv: return false
    
    # 1. Try to merge with existing stacks in target (Crucial for Quick Transfer success)
    if item.stackable:
        var target_items = target_inv.get_all_items()
        for target_item in target_items:
            if target_item.id == item.id and target_item.stack_count < target_item.max_stack:
                # Merge logic handles signals and removal from source if needed
                if target_inv.try_merge_stack(item, target_item):
                    remove_item(item) # Remove from source if merged completely
                    return true
                
                # If only partially merged, check if source item is now empty
                if item.stack_count <= 0:
                    # This case is handled inside try_merge_stack's call to remove_item(source_item)
                    return true 

    # 2. Try to place in empty space
    var pos = target_inv.find_free_space(item)
    if pos.x >= 0:
        if remove_item(item):
            if target_inv.place_item(item, pos.x, pos.y):
                return true
            else:
                # Rollback - Item was successfully removed but placement failed
                place_item(item, item.grid_x, item.grid_y)
    
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
    # 1. Try stacking/merging first
    if item.stackable:
        for existing in get_all_items():
            if existing.id == item.id and existing.stack_count < existing.max_stack:
                var space_available = existing.max_stack - existing.stack_count
                var amount_to_add = min(space_available, item.stack_count)
                
                existing.stack_count += amount_to_add
                item.stack_count -= amount_to_add
                stack_changed.emit(existing, existing.stack_count)
                
                if item.stack_count <= 0:
                    return true
    
    # 2. If stack remains or item is not stackable, find free space
    var pos = find_free_space(item)
    if pos.x >= 0:
        return place_item(item, pos.x, pos.y)
    
    inventory_full.emit()
    return false

## Adds multiple items atomically (all or nothing)
## Returns true only if ALL items were successfully added
func add_items(items: Array[InventoryItem]) -> bool:
    # if not inventory_component:
    #     return false

    var original_items: Array[InventoryItem] = get_all_items()
    var added_items: Array[InventoryItem] = []

    for item in items:
        if add_item(item):
            added_items.append(item)
        else:
            # ❌ Failed to add one → rollback everything
            for added in added_items:
                remove_item(added)
            # Restore original state (in case any items were merged)
            # Note: This simple rollback works if no external merges occurred
            # For robustness, you'd need a full inventory snapshot — but this is fine for most cases
            return false

    # ✅ All succeeded
    for item in added_items:
        if item.stackable and item.stack_count > 1:
            print("✓ Picked up: %s (x%d)" % [item.display_name, item.stack_count])
        else:
            print("✓ Picked up: %s" % item.display_name)

    return true
    
## Split stack
func split_stack(item: InventoryItem, amount: int) -> InventoryItem:
    if not item.stackable or amount <= 0 or amount >= item.stack_count:
        return null
    
    # Note: Using duplicate() requires InventoryItem to be a Resource or class with proper duplication logic
    var new_item = item.duplicate()
    new_item.stack_count = amount
    item.stack_count -= amount
    
    stack_changed.emit(item, item.stack_count)
    stack_split.emit(item, new_item)
    return new_item

## Equip item to slot
func equip_item(item: InventoryItem, slot: String) -> bool:
    if not equipment_slots.has(slot): return false
    if item.equip_slot != slot: return false
    
    # Unequip existing item if slot is occupied
    if equipment_slots[slot] != null:
        unequip_item(slot)
    
    # Remove from grid if it was in the inventory
    if item.grid_x >= 0 and item.grid_y >= 0:
        remove_item(item)
    
    equipment_slots[slot] = item
    item_equipped.emit(item, slot)
    return true

## Unequip item from slot
func unequip_item(slot: String) -> bool:
    if not equipment_slots.has(slot): return false
    var item = equipment_slots[slot]
    if item == null: return false
    
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
    if slot < 0 or slot >= hotbar_slots: return false
    hotbar[slot] = item
    get_child(0).inventory_ui.refresh_display()
    return true

func set_on_empty_hotbar_slot(item: InventoryItem) -> bool:
    if item  in hotbar: return false
    for i in hotbar_slots:
        if hotbar[i] == null:
            hotbar[i] = item
            get_child(0).inventory_ui.refresh_display()
            return true
    return false

func remove_from_hotbar(item: InventoryItem) -> bool:
    for i in hotbar_slots:
        if hotbar[i] == item:
            hotbar[i] = null
            get_child(0).inventory_ui.refresh_display()
            return true
    return false
## Use hotbar slot
func use_hotbar_slot(slot: int):
    if slot < 0 or slot >= hotbar_slots: return
    var item = hotbar[slot]
    if item == null: return
    
    hotbar_item_used.emit(slot, item)
    match item.type:
        "consumable": _use_consumable(item)
        "weapon": _equip_weapon(item)

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
        # Only process items at their origin cell to avoid duplicates
        if cell.is_origin:
            var item = cell.item
            if not seen.has(item):
                items.append(item)
                seen[item] = true
    return items

func get_all_display_name_items() -> Array[String]:
    var items: Array[String] = []
    var seen = {}
    for key in grid.keys():
        var cell = grid[key]
        # Only process items at their origin cell to avoid duplicates
        if cell.is_origin:
            var item = cell.item
            if not seen.has(item):
                items.append(item.display_name)
                seen[item] = true
    return items

## Rotate item logic (Improved to handle the logic flow better)
func rotate_item(item: InventoryItem) -> bool:
    if item.grid_x < 0 or item.grid_y < 0: return false # Item must be placed
    
    var old_w = item.width
    var old_h = item.height
    
    # Temporarily swap dimensions for the check
    item.width = old_h
    item.height = old_w
    
    var target_x = item.grid_x
    var target_y = item.grid_y
    
    # Check if the rotated item fits in its current location
    # We ignore the item itself because it occupies its current cells (which are about to be cleared/rewritten)
    if can_place_item(item, target_x, target_y, item):
        # 1. Successful: Update grid data
        
        # Clear old cells (uses original dimensions)
        for ix in range(old_w):
            for iy in range(old_h):
                var key = _grid_key(target_x + ix, target_y + iy)
                grid.erase(key)

        # Populate new cells (uses new, swapped dimensions)
        for ix in range(item.width):
            for iy in range(item.height):
                var key = _grid_key(target_x + ix, target_y + iy)
                grid[key] = {
                    "item": item,
                    "is_origin": (ix == 0 and iy == 0)
                }
        
        # Emit signal for UI to react (though UI forces a refresh, this is cleaner)
        item_rotated.emit(item, old_w, old_h)
        return true
    else:
        # 2. Failed: Revert dimensions and return false
        item.width = old_w
        item.height = old_h
        return false



func drop_item(item: InventoryItem, source: String):
    if not item or item.scene_path == "":
        push_warning("Dropped item is null or missing scene_path")
        return
    
    var drop_pos := player.global_position + Vector3(0,0.2,0)
    var world = get_tree().get_current_scene()
    if not player.is_ledge_detect() :
        

        # Random spread radius
        var radius := 0.5  # how far items can land around the drop marker
        var rand_offset := Vector3(
            randf_range(-radius, radius),
            0,
            randf_range(0, radius)
        )

        drop_pos = drop_marker.global_position + rand_offset
    
    
    var pickup = PickupableItem.create_pickup(item, drop_pos, world)
    
    if pickup:
        # Optional: add slight rotation randomness for visual variation
        pickup.rotation.y = randf_range(0.0, TAU)

        # If RigidBody -> throw it a bit
        if pickup is RigidBody3D:
            (pickup as RigidBody3D).apply_impulse(Vector3.ZERO,
                Vector3(randf_range(-2,2), randf_range(3,6), randf_range(-2,2))
            )

        item_dropped.emit(item, source)
    else:
        push_error("Failed to create pickup for item: %s" % item.id)


## Save inventory to dictionary
func save_to_dict() -> Dictionary:
    var save_data = {
        "items": [], "equipment": {}, "hotbar": [], "weight": current_weight
    }
    # Save placed items
    for item in get_all_items(): save_data.items.append(item.to_dict())
    
    # Save equipped items
    for slot in equipment_slots.keys():
        if equipment_slots[slot] != null: save_data.equipment[slot] = equipment_slots[slot].to_dict()
        
    # Save hotbar references (assuming hotbar references placed items by ID/position or stores its own instance)
    # For simplicity, we save placed item IDs here if the hotbar item is stackable, otherwise we save the whole item data.
    for i in hotbar.size():
        var item = hotbar[i]
        if item != null: 
            # In a real game, you would save a reference (ID/UUID) instead of the whole object
            save_data.hotbar.append({"slot": i, "item_data": item.to_dict()})
        else:
            save_data.hotbar.append({"slot": i, "item_data": null})
            
    return save_data

## Load inventory from dictionary
func load_from_dict(data: Dictionary):
    clear_inventory()
    var loaded_items = {} # To map item UUIDs if needed, or simply store all loaded items

    if data.has("items"):
        for item_data in data.items:
            var item = InventoryItem.from_dict(item_data)
            # Use place_item to rebuild the grid correctly
            place_item(item, item.grid_x, item.grid_y)
            loaded_items[item.instance_id] = item

    if data.has("equipment"):
        for slot in data.equipment.keys():
            var item = InventoryItem.from_dict(data.equipment[slot])
            equipment_slots[slot] = item

    if data.has("hotbar"):
        for slot_data in data.hotbar:
            if slot_data.item_data != null:
                var item = InventoryItem.from_dict(slot_data.item_data)
                # Note: If the hotbar is meant to reference items *in* the inventory grid, 
                # you'd need a more complex system to find the matching item instance here.
                hotbar[slot_data.slot] = item

    if data.has("weight"):
         current_weight = data.weight # Or recalculate for safety

## Clear entire inventory
func clear_inventory():
    grid.clear()
    for slot in equipment_slots.keys(): equipment_slots[slot] = null
    for i in hotbar.size(): hotbar[i] = null
    current_weight = 0.0

## Auto-organize inventory
func auto_organize():
    var items = get_all_items()
    clear_inventory()
    # Sort largest items first for better packing (W*H)
    items.sort_custom(func(a, b): return a.width * a.height > b.width * b.height)
    for item in items: add_item(item)

## Get equipped weapon
func get_equipped_weapon(slot: String = "primary_weapon") -> InventoryItem:
    if equipment_slots.has(slot): return equipment_slots[slot]
    return null

## Get ammo for weapon
func get_ammo_for_weapon(weapon: InventoryItem) -> Array[InventoryItem]:
    var ammo_items: Array[InventoryItem] = []
    if not weapon or not weapon.attributes.has("ammo_type"): return ammo_items
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
            stack_changed.emit(ammo, ammo.stack_count)
            if ammo.stack_count <= 0: remove_item(ammo)
            return true
        else:
            remaining -= ammo.stack_count
            remove_item(ammo) # Remove the stack entirely
    return false

# Private helper methods
func _grid_key(x: int, y: int) -> String: return "%d,%d" % [x, y]

func _use_consumable(item: InventoryItem):
    # This is a stub for external effect logic
    item.stack_count -= 1
    stack_changed.emit(item, item.stack_count)
    if item.stack_count <= 0: remove_item(item)

func _equip_weapon(item: InventoryItem):
    if item.attributes.get("primary_weapon", false): equip_item(item, "primary_weapon")
    else: equip_item(item, "secondary_weapon")
