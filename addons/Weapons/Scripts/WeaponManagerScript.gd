# Modified WeaponManager.gd - Hotbar-Based Weapon Switching + Hold F to Unequip

extends Node3D
class_name WeaponManagerv0

var weaponList : Dictionary = {} # All weapon resources
@export var weaponResources : Array[WeaponResource]
## ADD THIS EXPORT AT THE TOP

var cW = null # current weapon
var pW = null : # previous weapon
    get : return pW
    set(value) : 
        if value != null and value != pW:
            pW = value
        # pW = null
var cWModel = null
var currentHotbarSlot : int = -1 # Current active hotbar slot

var canChangeWeapons : bool = true
var canUseWeapon : bool = true
var unequipped_weapon : bool = false 

# state-based offsets
var state_procedural_offset: Vector3 = Vector3.ZERO

@export_group("Keybind variables")
@export var shoot_action : String = "fire"
@export var shoot_alt_action : String = "fire_alt" ## second hand action (fire or throw) or zoom shoot
@export var reload_action : String = "reload"
@export var interact_action : String = "interact"
@export var throw_action : String = "throw" ## throw action for grenades, etc.

@export_group("Drop Settings")
@export var drop_key: String = "drop_weapon"  # Input action for dropping weapon
@export var drop_force: float = 5.0
@export var drop_forward_force: float = 3.0
@export var drop_upward_force: float = 2.0

@export_group("Nodes")
@export var player : CharacterBody3D
@export var state_machine: StateMachine # Assign in Inspector
@export var cameraHolder : CameraController
@export var cameraRecoilHolder : Node3D 
@export var camera : Camera3D 
@export var weaponContainer : Node3D = %WeaponContainer
@export var shootManager : ShootManager = %ShootManager
@export var reloadManager : ReloadManager = %ReloadManager
@export var ammoManager : AmmunitionManager = %AmmunitionManager
@export var animPlayer : AnimationPlayer = %AnimationPlayer
@export var animManager : Node3D = %AnimationManager
@onready var audioManager : PackedScene = preload("../../Misc/Scenes/AudioManagerScene.tscn")
@onready var bulletDecal : PackedScene = preload("../../Weapons/Scenes/BulletDecalScene.tscn")
@export var hud : CanvasLayer 
@export var linkComponent : Node3D = %LinkComponent
@export var combat_health: CombatHealthComponent  
@export var interaction_raycast: RayCast3D  

# Inventory integration
@export_group("Inventory Integration")
@export var inventory_component: InventoryComponent

# --- JUICE VARIABLES ---
var default_fov : float = 75.0 # Set this to your project's default FOV
var initial_container_pos : Vector3
var initial_container_rot : Vector3

# These store the current "kick" amount
var procedural_recoil_pos : Vector3 = Vector3.ZERO
var procedural_recoil_rot : Vector3 = Vector3.ZERO

# Hold-to-unequip variables
var is_holding_f: bool = false
var f_hold_duration: float = 0.0
const F_UNEQUIP_THRESHOLD: float = 0.3  # seconds

var ignore_next_shoot: bool = false

func _ready():
    initialize()
    
    # Link inventory to ammo manager
    if inventory_component and ammoManager:
        ammoManager.inventory_component = inventory_component
    
    # Connect to hotbar usage
    if inventory_component:
        inventory_component.hotbar_item_used.connect(_on_hotbar_used)
    
    # Store defaults for juice calculations
    if camera:
        default_fov = camera.fov
    if weaponContainer:
        initial_container_pos = weaponContainer.position
        initial_container_rot = weaponContainer.rotation
        
    # Hide all weapons initially
    hide_all_weapons()


func initialize():
    # Load all weapon resources into dictionary
    for weapon in weaponResources:
        weaponList[weapon.weaponId] = weapon
    
    # Setup weapon slots but keep invisible
    for weapo in weaponList.keys():
        var weapon = weaponList[weapo]
        
        for weaponSlot in weaponContainer.get_children():
            if weaponSlot.weaponId == weapon.weaponId:
                weapon.weaponSlot = weaponSlot
                var model = weapon.weaponSlot.model
                model.visible = false # Start hidden
                
                forceAttackPointTransformValues(weapon.weaponSlot.attackPoint)
                weapon.bobPos = weapon.position


func hide_all_weapons():
    """Hide all weapon models"""
    for weapon_id in weaponList.keys():
        var weapon = weaponList[weapon_id]
        if weapon.weaponSlot and weapon.weaponSlot.model:
            weapon.weaponSlot.model.visible = false


func _input(event):
    if not canChangeWeapons:
        return
    
    # Handle F key press/release for unequip
    if event is InputEventKey and event.keycode == InputActions.get_action_key_number(interact_action):
        if event.pressed and not interaction_raycast.is_colliding():
            is_holding_f = true
            f_hold_duration = 0.0
        elif event.is_released():
            is_holding_f = false
            f_hold_duration = 0.0

    # Hotbar number keys (1-8)
    if event is InputEventKey and event.pressed:
        var slot = -1
        
        match event.keycode:
            KEY_1: slot = 0
            KEY_2: slot = 1
            KEY_3: slot = 2
            KEY_4: slot = 3
            KEY_5: slot = 4
            KEY_6: slot = 5
            KEY_7: slot = 6
            KEY_8: slot = 7
        
        if slot >= 0:
            switch_to_hotbar_slot(slot)
    
    # Mouse wheel scroll through hotbar
    if event is InputEventMouseButton:
        if event.pressed:
            if event.button_index == MOUSE_BUTTON_WHEEL_UP:
                scroll_hotbar(-1)
            elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
                scroll_hotbar(1)
    
    # if  event is InputEventKey:
    #     if event.pressed:
    #         if event.keycode == InputActions.get_action_key_number("wheel_key"):
    #             _equip_previous_weapon()

    if event is InputEventMouseButton:
        if event.pressed:
            if (event.button_index == MOUSE_BUTTON_LEFT and unequipped_weapon):
                ignore_next_shoot = true
                _equip_previous_weapon()

func scroll_hotbar(direction: int):
    """Scroll through hotbar slots"""
    if not inventory_component:
        return
    
    var start_slot = currentHotbarSlot if currentHotbarSlot >= 0 else 0
    var checked = 0
    var next_slot = start_slot
    
    # Find next occupied slot
    while checked < inventory_component.hotbar_slots:
        next_slot = (next_slot + direction) % inventory_component.hotbar_slots
        if next_slot < 0:
            next_slot = inventory_component.hotbar_slots - 1
        
        var item = inventory_component.hotbar[next_slot]
        if item and item.type == "weapon":
            switch_to_hotbar_slot(next_slot)
            return
        
        checked += 1
        if next_slot == start_slot:
            break


## REPLACE switch_to_hotbar_slot() FUNCTION
func switch_to_hotbar_slot(slot: int):
    """Switch to weapon in specific hotbar slot"""
    
    # NEW: Check if able to equip weapons
    if not _can_equip_weapon():
        print("❌ Cannot equip weapon - Right arm too damaged!")
        _show_arm_damaged_message()
        return
    
    if not inventory_component:
        return
    
    if slot < 0 or slot >= inventory_component.hotbar_slots:
        return
    
    # Get item from hotbar
    var item = inventory_component.hotbar[slot]
    # Must be a weapon
    if not item or item.type != "weapon":
        print("No weapon in hotbar slot %d" % (slot + 1))
        return
    
    # Must have weapon_id attribute
    if not item.attributes.has("weapon_id"):
        return
    
    var weapon_id = int(item.attributes.weapon_id)
    # print(weapon_id)
    
    # Check if weapon exists
    if not weaponList.has(weapon_id):
        print("Weapon ID %d not found!" % weapon_id)
        return
    
    # Don't switch to same weapon
    if cW and cW.weaponId == weapon_id:
        return
    
    # Switch to this weapon
    if cW:
        exitWeapon(weapon_id, slot)
    else:
        enterWeapon(weapon_id, slot)


func _on_hotbar_used(slot: int, item: InventoryItem):
    """When player uses hotbar item (press number key)"""
    if item.type == "weapon":
        switch_to_hotbar_slot(slot)
    elif item.type == "consumable":
        use_consumable(item)


func exitWeapon(nextWeaponId: int, nextSlot: int):
    """Unequip current weapon based on WeaponResource.unequipTime"""
    if nextWeaponId == cW.weaponId :
        return
    
    pW = cW

    canChangeWeapons = false
    canUseWeapon = false
    unequipped_weapon = true

    # 1. Cancel current actions
    if cW.isShooting: cW.isShooting = false
    if cW.isReloading: cW.isReloading = false
    
    # 2. Play Animation
    if cW.unequipAnimName != "":
        animManager.playAnimation("UnequipAnim%s" % cW.weaponName, cW.unequipAnimSpeed, false)
        if cW.unequipSound:
            weaponSoundManagement(cW.unequipSound, cW.unequipSoundSpeed)
    
    # 3. Wait for the EXACT time defined in WeaponResource
    if cW.unequipTime > 0:
        await get_tree().create_timer(cW.unequipTime).timeout

    # 4. Hide current model
    if cWModel:
        cWModel.visible = false
    
    # 5. Enter next weapon
    enterWeapon(nextWeaponId, nextSlot)


func enterWeapon(nextWeaponId: int, slot: int):
    """Equip new weapon based on WeaponResource.equipTime"""
    
    # NEW: Check if physically able to equip weapons
    if not _can_equip_weapon():
        print("❌ Cannot equip weapon - Right arm too damaged!")
        canChangeWeapons = true
        return
    
    if player.is_graping():
        return
    
    # Load the new resource
    cW = weaponList[nextWeaponId]
    currentHotbarSlot = slot
    cWModel = cW.weaponSlot.model
    
    # 1. Make Visible
    cWModel.visible = true
    
    # 2. Update Managers
    shootManager.getCurrentWeapon(cW)
    reloadManager.getCurrentWeapon(cW)
    animManager.getCurrentWeapon(cW, cWModel)
    
    # 3. Play Sound & Animation
    if cW.equipSound:
        weaponSoundManagement(cW.equipSound, cW.equipSoundSpeed)
        
    animPlayer.playback_default_blend_time = cW.animBlendTime
    
    if cW.equipAnimName != "":
        animManager.playAnimation("EquipAnim%s" % cW.weaponName, cW.equipAnimSpeed, false)
    
    # 4. Wait for the EXACT time defined in WeaponResource
    if cW.equipTime > 0:
        await get_tree().create_timer(cW.equipTime).timeout

    # 5. Enable control
    if cW.isShooting: cW.isShooting = false
    if cW.isReloading: cW.isReloading = false
    
    unequipped_weapon = false
    canUseWeapon = true
    canChangeWeapons = true
    ignore_next_shoot = false
    
    print("Equipped: %s (Slot %d)" % [cW.weaponName, slot + 1])

func _equip_previous_weapon():
    """Re-equip the previous weapon if available"""
    print("Re-equipping previous weapon...")
    print(pW)
    if pW:
        var weapon_id = pW.weaponId
        for i in range(inventory_component.hotbar_slots):
            var item = inventory_component.hotbar[i]
            if item and item.type == "weapon" and item.attributes.get("weapon_id") == weapon_id:
                switch_to_hotbar_slot(i)
                return

# NEW: Direct unequip without switching to another weapon
func _unequip_current_weapon():
    """Unequips the current weapon and clears state."""
    if not cW:
        return

    pW = cW
    unequipped_weapon = true
    canChangeWeapons = false
    canUseWeapon = false

    # Cancel actions
    cW.isShooting = false
    cW.isReloading = false

    # Play unequip anim/sound
    if cW.unequipAnimName != "":
        animManager.playAnimation("UnequipAnim%s" % cW.weaponName, cW.unequipAnimSpeed, false)
        if cW.unequipSound:
            weaponSoundManagement(cW.unequipSound, cW.unequipSoundSpeed)

    # Wait for unequip time
    if cW.unequipTime > 0:
        await get_tree().create_timer(cW.unequipTime).timeout

    # Hide model
    if cWModel:
        cWModel.visible = false

    # Clear references
    cW = null
    cWModel = null
    currentHotbarSlot = -1

    # Re-enable controls
    canUseWeapon = true
    canChangeWeapons = true

    print("Weapon unequipped (via F hold)")


func has_weapon(weapon_id: int) -> bool:
    """Helper to check if we already hold this unique weapon"""
    if not inventory_component:
        return false
        
    for item in inventory_component.get_all_items():
        if item.type == "weapon" and item.attributes.get("weapon_id") == weapon_id:
            return true
    return false


func attempt_pickup_unique(weapon_id: int) -> bool:
    """
    Call this function after your 'Hold Interact' is complete.
    Returns TRUE if pickup successful.
    Returns FALSE if player already has this unique weapon or can't equip.
    """
    
    # NEW: Check if able to use weapons
    if not _can_equip_weapon():
        print("❌ Cannot pickup weapon - Right arm too damaged!")
        _show_arm_damaged_message()
        return false
    
    # 1. Check if valid weapon exists in our database
    if not weaponList.has(weapon_id):
        print("Error: Weapon ID %d does not exist in WeaponManager database." % weapon_id)
        return false
        
    # 2. Check for Unique Duplicate
    if has_weapon(weapon_id):
        print("Cannot Pickup: You already have the %s!" % weaponList[weapon_id].weaponName)
        return false
    
    # 3. Perform the Pickup
    var success = pickup_weapon(weapon_id)
    
    if success:
        # Optional: Auto-equip if we are holding nothing
        if cW == null:
            for i in range(inventory_component.hotbar_slots):
                var item = inventory_component.hotbar[i]
                if item and item.attributes.get("weapon_id") == weapon_id:
                    switch_to_hotbar_slot(i)
                    break
                    
    return success
  
func _can_equip_weapon() -> bool:
    """Check if player can equip weapons based on arm health"""
    if not combat_health:
        return true  # No health system, allow everything
    
    return combat_health.can_equip_weapon()

func _show_arm_damaged_message():
    """Show message about damaged arm preventing weapon use"""
    if hud and hud.has_method("show_message"):
        hud.show_message("⚠️ Right arm too damaged to use weapons!")
    else:
        print("⚠️ RIGHT ARM TOO DAMAGED - HEAL TO 5%+ TO USE WEAPONS")

func _process(delta : float):
    # Handle F hold to unequip
    if is_holding_f and cW != null:
        f_hold_duration += delta
        if f_hold_duration >= F_UNEQUIP_THRESHOLD and canChangeWeapons:
            is_holding_f = false
            f_hold_duration = 0.0
            _unequip_current_weapon()
    
    if player.is_graping():
        _unequip_current_weapon()
    
    
    # NEW: Continuously check if we can still use weapons
    if cW != null:
        if not _can_equip_weapon():
            print("⚠️ Right arm too damaged - dropping weapon!")
            drop_current_weapon()
            return
    
    if cW != null and cWModel != null and canUseWeapon:
        weaponInputs()
        reloadManager.autoReload()
        
    # PROCESS THE JUICE EVERY FRAME
    process_weapon_juice(delta)

    if hud != null: 
        displayStats()

func get_weapon_restriction_status() -> String:
    """Get current weapon restriction status for HUD"""
    if not combat_health or not combat_health.player_health:
        return ""
    
    var right_arm = combat_health.player_health.get_limb(LimbData.BodyPart.RIGHT_ARM)
    
    if right_arm.is_destroyed():
        return "⚠️ RIGHT ARM DESTROYED - CANNOT USE WEAPONS"
    elif right_arm.get_health_percent() < 0.3:
        return "⚠️ RIGHT ARM CRITICAL (%.0f%%) - HEAL TO 30%+ TO USE WEAPONS" % (right_arm.get_health_percent() * 100)
    elif right_arm.get_health_percent() < 0.5:
        return "⚠️ Right Arm Damaged (%.0f%%) - Reduced effectiveness" % (right_arm.get_health_percent() * 100)
    
    return ""
    
# --- NEW: PROCEDURAL ANIMATION LOGIC ---
func process_weapon_juice(delta):
    var target_offset = Vector3.ZERO
    if state_machine.current_state:
        target_offset = state_machine.current_state.weapon_offset
    
    state_procedural_offset = state_procedural_offset.lerp(target_offset, delta * 10.0)

    # 1. Weapon Kickback (Lerp back to zero)
    procedural_recoil_pos = procedural_recoil_pos.lerp(Vector3.ZERO, delta * 10.0)
    procedural_recoil_rot = procedural_recoil_rot.lerp(Vector3.ZERO, delta * 10.0)
    
    # Apply to the Weapon Container
    weaponContainer.position = initial_container_pos + procedural_recoil_pos
    weaponContainer.rotation = initial_container_rot + procedural_recoil_rot
    
    # 2. FOV Recovery
    if camera:
        camera.fov = lerp(camera.fov, default_fov, delta * 5.0)

func apply_visual_recoil(kick_back: float, kick_up: float):
    procedural_recoil_pos.z += kick_back 
    procedural_recoil_rot.x += kick_up
    procedural_recoil_rot.z += randf_range(-0.02, 0.02)
    
    if camera:
        camera.fov += 1.0


## REPLACE weaponInputs() FUNCTION
func weaponInputs():
    # NEW: Check if able to use weapons before any input
    if not _can_equip_weapon() and cW != null:
        # Force drop if we somehow have a weapon equipped
        drop_current_weapon()
        return
    
    if Input.is_action_just_pressed(drop_key):
        drop_current_weapon()

    var current_state = state_machine.current_state
    # 1. Check State Permissions
    if not current_state.can_shoot:
        #shootManager.cancel_fire() # If you have a continuous fire mode
        return
        
    if cW:   
        # Auto vs Semi-Auto input logic
        if cW.canAutoShoot:
            if Input.is_action_pressed(shoot_action) and !ignore_next_shoot:
                shootManager.shoot()
        else:
            if Input.is_action_just_pressed(shoot_action) and !ignore_next_shoot:
                shootManager.shoot()
                
        if Input.is_action_just_pressed(reload_action): 
            reloadManager.reload()


func displayStats():
    if not cW:
        hud.displayWeaponName("No Weapon")
        hud.displayTotalAmmoInMag(0, 1)
        hud.displayTotalAmmo(0, 1)
        
        # NEW: Show why weapon can't be equipped
        var restriction = get_weapon_restriction_status()
        if restriction != "" and hud.has_method("show_restriction"):
            hud.show_restriction(restriction)
        return
    
    hud.displayWeaponName(cW.weaponName)
    hud.displayTotalAmmoInMag(cW.totalAmmoInMag, cW.nbProjShotsAtSameTime)
    
    var total_ammo = ammoManager.get_ammo_count(cW.ammoType)
    hud.displayTotalAmmo(total_ammo, cW.nbProjShotsAtSameTime)
    
    # NEW: Show arm damage warning
    var restriction = get_weapon_restriction_status()
    if restriction != "" and hud.has_method("show_restriction"):
        hud.show_restriction(restriction)


func use_consumable(item: InventoryItem):
    if item.attributes.has("heal_amount"):
        var heal = item.attributes.heal_amount
        if player.has_method("heal"):
            player.heal(heal)
        print("Healed %d HP" % heal)
    
    if item.attributes.has("stamina_amount"):
        var stamina = item.attributes.stamina_amount
        if player.has_method("restore_stamina"):
            player.restore_stamina(stamina)
    
    item.stack_count -= 1
    if item.stack_count <= 0:
        inventory_component.remove_item(item)


# Pickup weapon - adds to inventory
func pickup_weapon(weapon_id: int) -> bool:
    if not inventory_component:
        return false
    
    var weapon = weaponList.get(weapon_id)
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

func drop_current_weapon():
    """Drop current weapon with CS:GO-style physics"""
    
    if not cW:
        print("No weapon to drop!")
        return
    
    if not inventory_component:
        return
    
    # Can't drop while shooting or reloading
    if cW.isShooting or cW.isReloading:
        print("Can't drop weapon while using it!")
        return
    if cW == pW:
        pW = null

    var weapon_id = cW.weaponId
    
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
    var ammo_in_mag = cW.totalAmmoInMag
    
    # Remove from hotbar first
    if currentHotbarSlot >= 0:
        inventory_component.hotbar[currentHotbarSlot] = null
    
    # Remove from inventory
    inventory_component.remove_item(weapon_item)
    inventory_component.get_child(0).inventory_ui.refresh_display()
    # Hide weapon model
    if cWModel:
        cWModel.visible = false
    
    # Spawn weapon in world
    spawn_dropped_weapon(weapon_id, ammo_in_mag)
    
    # Switch to another weapon if available
    cW = null
    cWModel = null
    currentHotbarSlot = -1
    
    # Find next weapon in hotbar
    for i in range(inventory_component.hotbar_slots):
        var item = inventory_component.hotbar[i]
        if item and item.type == "weapon":
            switch_to_hotbar_slot(i)
            break
    
    print("Weapon dropped!")

# Pickup ammo - adds to inventory
func pickup_ammo(ammo_type: String, amount: int) -> bool:
    if not ammoManager:
        return false
    
    return ammoManager.add_ammo(ammo_type, amount)


func displayMuzzleFlash():
    if cW.muzzleFlashRef != null:
        var muzzleFlashInstance = cW.muzzleFlashRef.instantiate()
        add_child(muzzleFlashInstance)
        muzzleFlashInstance.global_position = cW.weaponSlot.muzzleFlashSpawner.global_position
        muzzleFlashInstance.layers = 5 
        muzzleFlashInstance.emitting = true


func displayBulletHole(colliderPoint : Vector3, colliderNormal : Vector3 , collider : Object):
    var bulletDecalInstance = bulletDecal.instantiate()
    if collider is Node3D:
        bulletDecalInstance.scale /= collider.scale
        collider.add_child(bulletDecalInstance)
    else:
        get_tree().get_root().add_child(bulletDecalInstance)
    bulletDecalInstance.global_position = colliderPoint
    bulletDecalInstance.look_at(colliderPoint - colliderNormal, Vector3.UP)
    bulletDecalInstance.rotate_object_local(Vector3(1.0, 0.0, 0.0), 90)


# --- MODIFIED SOUND MANAGER ---
func weaponSoundManagement(soundName : AudioStream, soundSpeed : float):
    var audioIns : AudioStreamPlayer3D = audioManager.instantiate()
    get_tree().get_root().add_child.call_deferred(audioIns)
    await get_tree().process_frame
    
    if audioIns.is_inside_tree():
        audioIns.global_transform = cW.weaponSlot.attackPoint.global_transform
        audioIns.bus = "Sfx"
        var random_pitch = randf_range(0.95, 1.05)
        audioIns.pitch_scale = soundSpeed * random_pitch
        audioIns.stream = soundName
        audioIns.play()


func forceAttackPointTransformValues(attackPoint : Marker3D):
    if attackPoint.rotation != Vector3.ZERO: 
        attackPoint.rotation = Vector3.ZERO



func spawn_dropped_weapon(weapon_id: int, ammo_in_mag: int):
    """Spawn weapon in world with CS:GO physics"""
    
    if not weaponList.has(weapon_id):
        return
    
    var weapon_data = weaponList[weapon_id]
    
    # Create dropped weapon instance
    var dropped_weapon = create_dropped_weapon_instance(weapon_id)
    
    if not dropped_weapon:
        print("Failed to create dropped weapon instance!")
        return
    
    # Add to world
    get_tree().get_root().add_child(dropped_weapon)
    
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
        
        # Add player's velocity (feels more realistic)
        if player is CharacterBody3D:
            drop_velocity += player.velocity * 0.3
        
        dropped_weapon.linear_velocity = drop_velocity
        
        # Add slight spin (CS:GO weapons spin when dropped)
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
