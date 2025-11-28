# A component to manage inventory logic for the player

class_name InventoryHandlerComponenent
extends Node

@export var inventory_component: InventoryComponent
@export var inventory_ui: InventoryUI
@export var camera_controller: Node  # Reference to the camera controller
@export var state_machine: Node      # Reference to the player state machine

var inventory_open: bool = false

func _ready():
	# Auto-resolve nodes if not assigned
	if not inventory_component:
		inventory_component = get_node_or_null("InventoryComponent")
		
	var item =  ItemDatabase.create_item("item_1764169325431")
	var item2 =  ItemDatabase.create_item("ammo_1764360991992" , 75)
	var item3 =  ItemDatabase.create_item("medkit_1764361004645" , 6)
	var item4 =  ItemDatabase.create_item("medkit_1764361004645")
	var item5 =  ItemDatabase.create_item("medkit_1764361004645")
	var item6 =  ItemDatabase.create_item("medkit_1764361004645")
	var item7 =  ItemDatabase.create_item("medkit_1764361004645")
	var item8 =  ItemDatabase.create_item("medkit_1764361004645")
	inventory_component.add_item(item)
	inventory_component.add_item(item2)
	inventory_component.add_item(item3)
	inventory_component.add_item(item4)
	inventory_component.add_item(item5)
	inventory_component.add_item(item6)
	inventory_component.add_item(item7)
	inventory_component.add_item(item8)
	
	if not inventory_ui:
		inventory_ui = get_node_or_null("InventoryUI")
	
	if inventory_ui:
		inventory_ui.inventory_component = inventory_component
		inventory_ui.ui_closed.connect(_on_inventory_closed)

func _input(event):
	if inventory_open:
		# Optional: block player input while inventory is open
		pass

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
		state_machine.transition_to(state_machine.get_state("StaticState"))  # or dedicated InventoryState
	# Pause the game
	if camera_controller:
		camera_controller.set_process_input(false)

	#get_tree().paused = true
	#inventory_ui.pause_mode = Node.PROCESS_MODE_WHEN_PAUSED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close_inventory():
	if not inventory_ui:
		return

	#inventory_open = false
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

# Public API: called by player or world
func pickup_item(item: InventoryItem) -> bool:
	if not inventory_component:
		return false
	if inventory_component.add_item(item):
		print("Picked up: ", item.display_name)
		return true
	else:
		print("Inventory full!")
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
			pass  # handled externally

func _use_consumable(item: InventoryItem):
	if item.attributes.has("heal_amount"):
		var heal = item.attributes.heal_amount
		print("Used ", item.display_name, " - Healed ", heal)
		# TODO: Apply to player health (via signal or reference)

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
			# Note: Attach to weapon holder via signal or by exposing it externally
			# Example: emit_signal("spawn_weapon", weapon_instance)

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

	# TODO: Fire logic (emit signal or call player method)
	# Example: emit_signal("fire_weapon", weapon)

	# Consume ammo
	inventory_component.consume_ammo(weapon, 1)

func interact_with_container(container: ContainerComponent):
	if container.try_open(get_parent()):  # assumes Player is parent
		inventory_ui.open_container(container)
		open_inventory()

# Save/Load
func save_inventory() -> Dictionary:
	if inventory_component:
		return inventory_component.save_to_dict()
	return {}

func load_inventory(data: Dictionary):
	if inventory_component:
		inventory_component.load_from_dict(data)
