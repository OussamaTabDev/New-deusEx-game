# WeaponDropPickup.gd - Handles weapon drop and pickup mechanics

extends Node
class_name WeaponDropPickup

var weapon_database: WeaponDatabase
var weapon_switcher: WeaponSwitcher
var inventory_component: InventoryComponent
var player: CharacterBody3D

# Drop settings
@export var drop_force: float = 5.0
@export var drop_forward_force: float = 3.0
@export var drop_upward_force: float = 2.0


func pickup_weapon(weapon_id: int) -> bool:
    """Add weapon to inventory"""
    if not inventory_component:
        return false
    
    var weapon = weapon_database.get_weapon(weapon_id)
    if not weapon:
        return false
    
    # Check if already have this weapon
    if has_weapon(weapon_id):
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


func has_weapon(weapon_id: int) -> bool:
    """Check if weapon is in inventory"""
    if not inventory_component:
        return false
    
    for item in inventory_component.get_all_items():
        if item.type == "weapon" and item.attributes.get("weapon_id") == weapon_id:
            return true
    
    return false


func attempt_pickup_unique(weapon_id: int, current_weapon) -> bool:
    """
    Attempt to pickup a unique weapon (no duplicates allowed)
    Returns true if successful
    """
    # Check if valid weapon
    if not weapon_database.has_weapon(weapon_id):
        print("Error: Weapon ID %d does not exist in database." % weapon_id)
        return false
    
    # Check for duplicate
    if has_weapon(weapon_id):
        print("Cannot Pickup: You already have the %s!" % weapon_database.get_weapon(weapon_id).weaponName)
        return false
    
    # Perform pickup
    var success = pickup_weapon(weapon_id)
    
    if success:
        # Auto-equip if holding nothing
        if current_weapon == null:
            for i in range(inventory_component.hotbar_slots):
                var item = inventory_component.hotbar[i]
                if item and item.attributes.get("weapon_id") == weapon_id:
                    # Signal to equip this weapon
                    return true
    
    return success


func drop_current_weapon(current_weapon, current_model, current_slot: int):
    """Drop current weapon with CS:GO-style physics"""
    if not current_weapon:
        print("No weapon to drop!")
        return
    
    if not inventory_component:
        return
    
    # Can't drop while using
    if current_weapon.isShooting or current_weapon.isReloading:
        print("Can't drop weapon while using it!")
        return
    
    var weapon_id = current_weapon.weaponId
    
    # Find weapon in inventory
    var weapon_item = null
    for item in inventory_component.get_all_items():
        if item.type == "weapon" and item.attributes.get("weapon_id") == weapon_id:
            weapon_item = item
            break
    
    if not weapon_item:
        print("Weapon not found in inventory!")
        return
    
    # Store ammo in mag
    var ammo_in_mag = current_weapon.totalAmmoInMag
    
    # Remove from hotbar
    if current_slot >= 0:
        inventory_component.hotbar[current_slot] = null
    
    # Remove from inventory
    inventory_component.remove_item(weapon_item)
    inventory_component.get_child(0).inventory_ui.refresh_display()
    
    # Hide model
    if current_model:
        current_model.visible = false
    
    # Spawn in world
    spawn_dropped_weapon(weapon_id, ammo_in_mag)
    
    print("Weapon dropped!")


func spawn_dropped_weapon(weapon_id: int, ammo_in_mag: int):
    """Spawn dropped weapon with physics"""
    if not weapon_database.has_weapon(weapon_id):
        return
    
    var weapon_data = weapon_database.get_weapon(weapon_id)
    
    # Create instance
    var dropped_weapon = create_dropped_weapon_instance(weapon_id)
    
    if not dropped_weapon:
        print("Failed to create dropped weapon instance!")
        return
    
    # Add to world
    get_tree().get_root().add_child(dropped_weapon)
    
    # Position in front of player (CS:GO style)
    var drop_position = player.global_position
    drop_position += player.global_transform.basis.z * -1.0
    drop_position.y += 1.0
    
    dropped_weapon.global_position = drop_position
    
    # Apply throw force
    if dropped_weapon is RigidBody3D:
        var forward = -player.global_transform.basis.z
        var drop_velocity = Vector3.ZERO
        
        # Forward throw
        drop_velocity += forward * drop_forward_force
        
        # Upward arc
        drop_velocity.y = drop_upward_force
        
        # Add player velocity
        if player is CharacterBody3D:
            drop_velocity += player.velocity * 0.3
        
        dropped_weapon.linear_velocity = drop_velocity
        
        # Add spin
        dropped_weapon.angular_velocity = Vector3(
            randf_range(-2, 2),
            randf_range(-3, 3),
            randf_range(-2, 2)
        )


func create_dropped_weapon_instance(weapon_id: int) -> RigidBody3D:
    """Create RigidBody3D instance of dropped weapon"""
    var weapon_item_scene = weapon_database.get_weapon_scene_path(weapon_id)
    
    if weapon_item_scene:
        var weapon_scene = load(weapon_item_scene)
        var instance = weapon_scene.instantiate()
        
        if instance is RigidBody3D:
            return instance
    
    return null
