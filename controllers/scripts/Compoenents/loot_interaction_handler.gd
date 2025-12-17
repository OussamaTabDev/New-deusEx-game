class_name LootInteractionHandler
extends Node

## Handles looting items, pickups, and container interactions

var main_component: UnifiedInteractionComponent

# ============================================================================
# INITIALIZATION
# ============================================================================
func initialize(component: UnifiedInteractionComponent) -> void:
	main_component = component

# ============================================================================
# TARGET HANDLING
# ============================================================================
func handle_loot_target(target: Node, component: UnifiedInteractionComponent) -> void:
	var pickup = target as PickupableItem
	component.item_detected.emit(pickup)
	
	if pickup.has_method("set_highlighted"):
		pickup.set_highlighted(true)
	
	_apply_scanner(pickup, component)
	
	var item_name = _get_item_display_name(pickup)
	component._update_ui("Pick up", "", item_name)

func handle_dual_target(target: Node, component: UnifiedInteractionComponent) -> void:
	var pickup = _find_pickupable(target, component)
	if pickup:
		if pickup.has_method("set_highlighted"):
			pickup.set_highlighted(true)
		_apply_scanner(pickup, component)
		var item_name = _get_item_display_name(pickup)
		component._update_ui("Pick up", "Hold to Grab", item_name)
	else:
		component._update_ui("Pick up", "Hold to Grab", target.name)

func handle_container_target(target: Node, component: UnifiedInteractionComponent) -> void:
	var container = target as ContainerComponent
	component.container_detected.emit(container)
	component._update_ui("Open", "", container.container_name)

func clear_loot_target(target: Node) -> void:
	if not main_component:
		return
	
	var pickup = _find_pickupable(target, main_component)
	if pickup:
		if pickup.has_method("set_highlighted"):
			pickup.set_highlighted(false)
		_remove_scanner(pickup, main_component)

# ============================================================================
# LOOT ACTIONS
# ============================================================================
func pickup_item(pickup: PickupableItem, component: UnifiedInteractionComponent) -> void:
	if not pickup or not component.inventory_handler:
		component.interaction_failed.emit("No inventory handler")
		return
	
	var base_item = pickup.item_data
	if not base_item:
		component.interaction_failed.emit("Invalid item data")
		return
	
	var total_count = pickup.stack_count
	var max_stack = base_item.max_stack
	var items_to_add: Array[InventoryItem] = []
	
	# Check for duplicate weapons
	if base_item.display_name in component.inventory_handler.inventory_component.get_all_display_name_items() and base_item.type == "weapon":
		print("Already have weapon: %s" % base_item.display_name)
		var _pickup = _find_pickupable(pickup, component, false)
		base_item = _pickup.item_data
		total_count = _pickup.stack_count
		max_stack = base_item.max_stack
		if not base_item:
			component.interaction_failed.emit("Invalid item data")
			return
	
	# Split into stacks
	while total_count > 0:
		var chunk = base_item.duplicate()
		chunk.stack_count = min(total_count, max_stack)
		items_to_add.append(chunk)
		total_count -= max_stack
	
	# Add all items
	var all_succeeded = true
	for item in items_to_add:
		if not component.inventory_handler.pickup_item(item):
			all_succeeded = false
			break
	
	if all_succeeded:
		pickup.on_picked_up(component)
		component._clear_target()
	else:
		component.interaction_failed.emit("Inventory full")

func open_container(container: ContainerComponent, component: UnifiedInteractionComponent) -> void:
	if not component.inventory_handler:
		component.interaction_failed.emit("No inventory handler")
		return
	component.inventory_handler.interact_with_container(container)

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================
func _find_pickupable(node: Node, component: UnifiedInteractionComponent, check_self = true) -> PickupableItem:
	return component._find_pickupable(node, check_self)

func _get_item_display_name(pickup: PickupableItem) -> String:
	if not pickup.item_data:
		return "Unknown"
	
	var item_name = pickup.item_data.display_name
	var count = pickup.stack_count
	if pickup.item_data.stackable and count > 1:
		return "%s (x%d)" % [item_name, count]
	return item_name

func _apply_scanner(pickup: PickupableItem, component: UnifiedInteractionComponent) -> void:
	if component.cyber_scanner and component.is_scan_enabled:
		component.cyber_scanner._on_scanning(true)
		pickup.apply_to_scanner(component.cyber_scanner)
		pickup.set_scanning_layer(true)

func _remove_scanner(pickup: PickupableItem, component: UnifiedInteractionComponent) -> void:
	if component.cyber_scanner and component.is_scan_enabled:
		pickup.set_scanning_layer(false)
		component.cyber_scanner._on_scanning(false)