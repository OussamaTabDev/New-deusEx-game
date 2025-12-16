class_name InventoryHandlerComponenent
extends Node

## Component to manage inventory logic for the player
## Now integrated with PickupInteractionComponent

@export var inventory_component: InventoryComponent
@export var inventory_ui: InventoryUI
@export var camera_controller: Node
@export var state_machine: Node
@export var pickup_interaction: UnifiedInteractionComponent ## NEW

var inventory_open: bool = false

func _ready():
	# Auto-resolve nodes if not assigned
	if not inventory_component:
		inventory_component = get_node_or_null("InventoryComponent")
	
	# TEST ITEMS (remove in production)
	_add_test_items()
	
	if not inventory_ui:
		inventory_ui = get_node_or_null("InventoryUI")
	
	if inventory_ui:
		inventory_ui.inventory_component = inventory_component
		inventory_ui.ui_closed.connect(_on_inventory_closed)
	
	# Connect to pickup system
	if pickup_interaction:
		pickup_interaction.item_detected.connect(_on_item_detected)
		pickup_interaction.item_lost.connect(_on_item_lost)
		pickup_interaction.pickup_failed.connect(_on_pickup_failed)

func _add_test_items() -> void:
	"""Add test items (remove in production)"""
	var item =  ItemDatabase.create_item("weapon_9mm_pistol")
	var item2 =  ItemDatabase.create_items("ammo_light", 75)
	var item3 =  ItemDatabase.create_item("item_medkit", 6)
	
	inventory_component.add_item(item)
	inventory_component.add_items(item2)
	inventory_component.add_item(item3)


	# Give player pistol
	# var weapon_mgr = $'../../../CameraController/CameraBase/CameraOffset/Camera3D/WeaponManager'
	# weapon_mgr.pickup_weapon(1)  # weapon_id: 1 (Pistol)
	# # print(weapon_mgr.get_all_weapons())
	# # Give ammo
	# weapon_mgr.pickup_ammo("LightAmmo", 60)
	
	# # Add pistol to hotbar slot 1
	# var pistol_item = null
	# for item in ItemDatabase.get_items_by_type("weapon"):
	#     print(item.attributes)
	#     if item.attributes.get("weapon_id") == 1:
	#         pistol_item = item
	#         break
	# print(pistol_item)
	# inventory_component.add_item(pistol_item)
	# if pistol_item:
	#     inventory_component.set_hotbar_slot(1, pistol_item)
	#     print("✓ Pistol added to hotbar slot 1")
	#     print("Press '1' to equip!")

func _input(event):
	if inventory_open:
		pass # Block player input while inventory is open

	# Toggle inventory
	if event.is_action_pressed("toggle_inventory"):
		toggle_inventory()
		get_viewport().set_input_as_handled()

	# Quick use hotbar (only when inventory is closed)
	if event is InputEventKey and event.pressed and not inventory_open:
		match event.keycode:
			KEY_1: use_hotbar_slot(0)
			KEY_2: use_hotbar_slot(1)
			KEY_3: use_hotbar_slot(2)
			KEY_4: use_hotbar_slot(3)
			KEY_5: use_hotbar_slot(4)
			KEY_6: use_hotbar_slot(5)
			KEY_7: use_hotbar_slot(6)
			KEY_8: use_hotbar_slot(7)

func toggle_inventory():
	if inventory_open:
		close_inventory()
	else:
		open_inventory()

func open_inventory():
	if not inventory_ui:
		return

	inventory_open = true
	inventory_ui.open_inventory()

	if state_machine:
		state_machine.transition_to(state_machine.get_state("StaticState"))
	
	if camera_controller:
		camera_controller.set_process_input(false)

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close_inventory():
	if not inventory_ui:
		return

	inventory_ui.close_inventory()

	if state_machine:
		state_machine.revert_to_previous_state()

	if camera_controller:
		camera_controller.set_process_input(true)

	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_inventory_closed():
	inventory_open = false
	if camera_controller:
		camera_controller.set_process_input(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func use_hotbar_slot(slot: int):
	if not inventory_component:
		return
	inventory_component.use_hotbar_slot(slot)

## Called by PickupInteractionComponent
func pickup_item(item: InventoryItem) -> bool:
	if not inventory_component:
		return false
	
	if inventory_component.add_item(item):
		# Show count if stackable
		if item.stackable and item.stack_count > 1:
			print("✓ Picked up: %s (x%d)" % [item.display_name, item.stack_count])
		else:
			print("✓ Picked up: %s" % item.display_name)
		#print("Current inventory count: %d / %d" % [inventory_component.get_total_item_count(), inventory_component.max_items])
		##to do: quick add to hotbar if weapon or consumable
		if inventory_ui._can_assign_to_hotbar(item):
			inventory_component.set_on_empty_hotbar_slot(item)
				# print("-> Added to hotbar")
		return true
	else:
		print("✗ Inventory full!")
		return false

func use_item_by_id(item_id: String):
	if not inventory_component:
		return
	for item in inventory_component.get_all_items():
		if item.id == item_id:
			_use_item(item)
			return

func _use_item(item: InventoryItem):
	match item.type:
		"consumable":
			_use_consumable(item)
		"key":
			pass # handled externally

func _use_consumable(item: InventoryItem):
	if item.attributes.has("heal_amount"):
		var heal = item.attributes.heal_amount
		print("Used ", item.display_name, " - Healed ", heal)
		# TODO: Apply to player health

	if item.attributes.has("stamina_amount"):
		var stamina = item.attributes.stamina_amount
		print("Used ", item.display_name, " - Restored ", stamina, " stamina")
		# TODO: Apply to player stamina

	item.stack_count -= 1
	if item.stack_count <= 0:
		inventory_component.remove_item(item)

func equip_weapon_from_inventory(item: InventoryItem):
	if item.type != "weapon":
		return
	var slot = item.equip_slot
	if inventory_component.equip_item(item, slot):
		_spawn_weapon_model(item)
		print("Equipped: ", item.display_name)

func _spawn_weapon_model(item: InventoryItem):
	if item.scene_path != "":
		var weapon_scene = load(item.scene_path)
		if weapon_scene:
			var weapon_instance = weapon_scene.instantiate()
			# Note: Attach to weapon holder via signal

func fire_equipped_weapon():
	var weapon = inventory_component.get_equipped_weapon("primary_weapon")
	if not weapon:
		weapon = inventory_component.get_equipped_weapon("secondary_weapon")
	if not weapon:
		return

	var ammo_items = inventory_component.get_ammo_for_weapon(weapon)
	if ammo_items.is_empty():
		print("No ammo!")
		return

	# TODO: Fire logic
	inventory_component.consume_ammo(weapon, 1)

func interact_with_container(container: ContainerComponent):
	if container.try_open(get_parent()):
		inventory_ui.open_container(container)
		open_inventory()

## Pickup system callbacks
func _on_item_detected(item: PickupableItem):
	# Optional: Show UI feedback
	pass

func _on_item_lost():
	# Optional: Hide UI feedback
	pass

func _on_pickup_failed(reason: String):
	print("Pickup failed: ", reason)
	# Optional: Show error message to player

# Save/Load
func save_inventory() -> Dictionary:
	if inventory_component:
		return inventory_component.save_to_dict()
	return {}

func load_inventory(data: Dictionary):
	if inventory_component:
		inventory_component.load_from_dict(data)
