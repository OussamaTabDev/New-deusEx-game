# WeaponDropPickup.gd - Handles weapon dropping and pickup
extends Node
class_name WeaponDropPickup

var weapon_manager: WeaponManager
var database: WeaponDatabase
var inventory_component: InventoryComponent
var player: CharacterBody3D

@export var drop_force: float = 5.0
@export var drop_forward_force: float = 3.0
@export var drop_upward_force: float = 2.0

func pickup_weapon(weapon_id: int) -> bool:
	"""Pickup weapon and add to inventory"""
	if not inventory_component:
		return false
	
	var weapon = database.get_weapon(weapon_id)
	if not weapon:
		return false
	
	# Check if already have this weapon
	for item in inventory_component.get_all_items():
		if item.type == "weapon" and item.attributes.get("weapon_id") == weapon_id:
			print("Already have this weapon!")
			return false
	
	# Create inventory item
	var item = InventoryItem.new()
	item.id = "weapon_%d" % weapon_id
	item.display_name = weapon.weaponName
	item.description = "Weapon"
	item.type = "weapon"
	item.width = 2
	item.height = 1
	item.stackable = false
	item.weight = 1.5
	item.attributes = {
		"weapon_id": weapon_id,
		"ammo_type": weapon.ammoType,
		"damage": weapon.damagePerProj
	}
	
	if inventory_component.add_item(item):
		print("Picked up: %s" % weapon.weaponName)
		print("Add to hotbar to use it!")
		return true
	
	return false

func attempt_pickup_unique(weapon_id: int) -> bool:
	"""Attempt to pickup a unique weapon with validation"""
	
	# Check if able to use weapons
	if not weapon_manager.health_checker.can_equip_weapon():
		print("❌ Cannot pickup weapon - Right arm too damaged!")
		weapon_manager.health_checker.show_arm_damaged_message()
		return false
	
	# Check if valid weapon exists
	if not database.has_weapon(weapon_id):
		print("Error: Weapon ID %d does not exist in WeaponManager database." % weapon_id)
		return false
	
	# Check for Unique Duplicate
	if has_weapon(weapon_id):
		print("Cannot Pickup: You already have the %s!" % database.get_weapon(weapon_id).weaponName)
		return false
	
	# Perform the Pickup
	var success = pickup_weapon(weapon_id)
	
	if success:
		# Optional: Auto-equip if we are holding nothing
		if weapon_manager.cW == null:
			for i in range(inventory_component.hotbar_slots):
				var item = inventory_component.hotbar[i]
				if item and item.attributes.get("weapon_id") == weapon_id:
					weapon_manager.switcher.switch_to_hotbar_slot(i)
					break
	
	return success

func has_weapon(weapon_id: int) -> bool:
	"""Helper to check if we already hold this unique weapon"""
	if not inventory_component:
		return false
	
	for item in inventory_component.get_all_items():
		if item.type == "weapon" and item.attributes.get("weapon_id") == weapon_id:
			return true
	return false

func drop_current_weapon():
	"""Drop current weapon with CS:GO-style physics"""
	
	if not weapon_manager.cW:
		print("No weapon to drop!")
		return
	
	if not inventory_component:
		return
	
	# Can't drop while shooting or reloading
	if weapon_manager.cW.isShooting or weapon_manager.cW.isReloading:
		print("Can't drop weapon while using it!")
		return
	
	if weapon_manager.cW == weapon_manager.pW:
		weapon_manager.pW = null
	
	var weapon_id = weapon_manager.cW.weaponId
	
	# Find weapon item in inventory
	var weapon_item = null
	for item in inventory_component.get_all_items():
		if item.type == "weapon" and item.attributes.get("weapon_id") == weapon_id:
			weapon_item = item
			break
	
	if not weapon_item:
		print("Weapon not found in inventory!")
		return
	
	# Store current ammo in magazine
	var ammo_in_mag = weapon_manager.cW.totalAmmoInMag
	print("hotbar slots :" , inventory_component.hotbar[weapon_manager.switcher.currentHotbarSlot])
	print("weapon slot :" , weapon_manager.switcher.currentHotbarSlot)
	print("weapon to drop :" , weapon_item == inventory_component.hotbar[weapon_manager.switcher.currentHotbarSlot])
	# Remove from hotbar first
	if weapon_manager.switcher.currentHotbarSlot >= 0:
		if weapon_item == inventory_component.hotbar[weapon_manager.switcher.currentHotbarSlot]:
			print("Removing weapon from hotbar slot %d" % weapon_manager.switcher.currentHotbarSlot)
			inventory_component.hotbar[weapon_manager.switcher.currentHotbarSlot] = null
		else:
			for i in range(inventory_component.hotbar.size()):
				if weapon_item == inventory_component.hotbar[i]:
					print("Removing weapon from hotbar at slot: ", i)
					inventory_component.hotbar[i] = null
					break

	# Remove from inventory
	inventory_component.remove_item(weapon_item)
	inventory_component.get_child(0).inventory_ui.refresh_display()
	
	# Hide weapon model
	if weapon_manager.cWModel:
		weapon_manager.cWModel.visible = false
	
	# Spawn weapon in world
	spawn_dropped_weapon(weapon_id, ammo_in_mag)
	
	# Switch to another weapon if available
	weapon_manager.cW = null
	weapon_manager.cWModel = null
	weapon_manager.switcher.currentHotbarSlot = -1
	
	# Find next weapon in hotbar
	for i in range(inventory_component.hotbar_slots):
		var item = inventory_component.hotbar[i]
		if item and item.type == "weapon":
			weapon_manager.switcher.switch_to_hotbar_slot(i)
			break
	
	print("Weapon dropped!")

func spawn_dropped_weapon(weapon_id: int, ammo_in_mag: int):
	"""Spawn weapon in world with CS:GO physics"""
	
	if not database.has_weapon(weapon_id):
		return
	
	var weapon_data = database.get_weapon(weapon_id)
	
	# Create dropped weapon instance
	var dropped_weapon = create_dropped_weapon_instance(weapon_id)
	
	if not dropped_weapon:
		print("Failed to create dropped weapon instance!")
		return
	
	# Add to world
	weapon_manager.get_tree().get_root().add_child(dropped_weapon)
	
	# Position in front of player (CS:GO style)
	var drop_position = player.global_position
	drop_position += player.global_transform.basis.z * -1.0  # Forward
	drop_position.y += 1.0  # Slightly above ground
	
	dropped_weapon.global_position = drop_position
	
	# Apply CS:GO-style throw force
	if dropped_weapon is RigidBody3D:
		var forward = -player.global_transform.basis.z
		var drop_velocity = Vector3.ZERO
		
		# Forward throw
		drop_velocity += forward * drop_forward_force
		
		# Upward arc
		drop_velocity.y = drop_upward_force
		
		# Add player's velocity
		if player is CharacterBody3D:
			drop_velocity += player.velocity * 0.3
		
		dropped_weapon.linear_velocity = drop_velocity
		
		# Add slight spin
		dropped_weapon.angular_velocity = Vector3(
			randf_range(-2, 2),
			randf_range(-3, 3),
			randf_range(-2, 2)
		)

func create_dropped_weapon_instance(weapon_id: int) -> RigidBody3D:
	"""Create a RigidBody3D instance of the dropped weapon"""
	
	# Check if weapon has a scene path in inventory item
	var weapon_item_scene = get_weapon_scene_path(weapon_id)
	
	if weapon_item_scene:
		# Use the scene from inventory item
		var weapon_scene = load(weapon_item_scene)
		var instance = weapon_scene.instantiate()
		
		if instance is RigidBody3D:
			return instance
	
	return null

func get_weapon_scene_path(weapon_id: int) -> String:
	"""Get scene path from inventory item"""
	for item in ItemDatabase.items.values():
		if item.type == "weapon" and item.attributes.get("weapon_id") == weapon_id:
			return item.scene_path
	return ""
