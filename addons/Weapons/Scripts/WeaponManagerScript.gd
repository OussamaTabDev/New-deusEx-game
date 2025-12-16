# Modified WeaponManager.gd - Hotbar-Based Weapon Switching

extends Node3D
class_name WeaponManager

var weaponList : Dictionary = {} # All weapon resources
@export var weaponResources : Array[WeaponResource]

var cW = null # current weapon
var cWModel = null
var currentHotbarSlot : int = -1 # Current active hotbar slot

var canChangeWeapons : bool = true
var canUseWeapon : bool = true

@export_group("Keybind variables")
@export var shoot_action : String = "shoot"
@export var reload_action : String = "reload"

@export_group("Nodes")
@export var playChar : CharacterBody3D 
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

func switch_to_hotbar_slot(slot: int):
    """Switch to weapon in specific hotbar slot"""
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
    print(weapon_id)
    
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

func exitWeapon(nextWeapon : int, nextSlot: int):
    """Unequip current weapon"""
    if not cW:
        enterWeapon(nextWeapon, nextSlot)
        return
    
    canChangeWeapons = false
    canUseWeapon = false
    
    if cW.isShooting: 
        cW.isShooting = false
    if cW.isReloading: 
        cW.isReloading = false
    
    if cW.unequipAnimName != "":
        animManager.playAnimation("UnequipAnim%s" % cW.weaponName, cW.unequipAnimSpeed, false)
    
    await get_tree().create_timer(cW.unequipTime).timeout
    
    # Hide current weapon
    cWModel.visible = false
    
    enterWeapon(nextWeapon, nextSlot)

func enterWeapon(nextWeapon : int, slot: int):
    """Equip new weapon"""
    cW = weaponList[nextWeapon]
    currentHotbarSlot = slot
    cWModel = cW.weaponSlot.model
    
    # Show weapon model
    cWModel.visible = true
    
    shootManager.getCurrentWeapon(cW)
    reloadManager.getCurrentWeapon(cW)
    animManager.getCurrentWeapon(cW, cWModel)
    
    weaponSoundManagement(cW.equipSound, cW.equipSoundSpeed)
    animPlayer.playback_default_blend_time = cW.animBlendTime
    
    if cW.equipAnimName != "":
        animManager.playAnimation("EquipAnim%s" % cW.weaponName, cW.equipAnimSpeed, false)
    
    await get_tree().create_timer(cW.equipTime).timeout
    
    if cW.isShooting: cW.isShooting = false
    if cW.isReloading: cW.isReloading = false
    canUseWeapon = true
    canChangeWeapons = true
    
    print("Equipped: %s (Slot %d)" % [cW.weaponName, slot + 1])

func _process(delta : float):
    if cW != null and cWModel != null and canUseWeapon:
        weaponInputs()
        reloadManager.autoReload()
        
    # PROCESS THE JUICE EVERY FRAME
    process_weapon_juice(delta)

    if hud != null: 
        displayStats()

# --- NEW: PROCEDURAL ANIMATION LOGIC ---
func process_weapon_juice(delta):
    # 1. Weapon Kickback (Lerp back to zero)
    # Adjust '10.0' to change how snappy the return is
    procedural_recoil_pos = procedural_recoil_pos.lerp(Vector3.ZERO, delta * 10.0)
    procedural_recoil_rot = procedural_recoil_rot.lerp(Vector3.ZERO, delta * 10.0)
    
    # Apply to the Weapon Container (so it affects the gun model)
    weaponContainer.position = initial_container_pos + procedural_recoil_pos
    weaponContainer.rotation = initial_container_rot + procedural_recoil_rot
    
    # 2. FOV Recovery (Lerp back to default)
    if camera:
        camera.fov = lerp(camera.fov, default_fov, delta * 5.0)


func apply_visual_recoil(kick_back: float, kick_up: float):
    # Kick the gun backwards (Z axis)
    procedural_recoil_pos.z += kick_back 
    # Rotate the gun up (X axis)
    procedural_recoil_rot.x += kick_up
    # Add a tiny bit of random roll (Z axis twist) for realism
    procedural_recoil_rot.z += randf_range(-0.02, 0.02)
    
    # "Punch" the FOV
    if camera:
        camera.fov += 1.0 # Briefly widen view on shot

    
func weaponInputs():
    # --- FIX START ---
    # Handle Auto vs Semi-Auto input logic here
    if cW.canAutoShoot:
        # Automatic: Fire as long as button is HELD
        if Input.is_action_pressed(shoot_action): 
            shootManager.shoot()
    else:
        # Semi-Auto: Fire only when button is JUST PRESSED
        if Input.is_action_just_pressed(shoot_action): 
            shootManager.shoot()
    # --- FIX END ---
            
    if Input.is_action_just_pressed(reload_action): 
        reloadManager.reload()

func displayStats():
    if not cW:
        hud.displayWeaponName("No Weapon")
        hud.displayTotalAmmoInMag(0, 1)
        hud.displayTotalAmmo(0, 1)
        return
    
    hud.displayWeaponName(cW.weaponName)
    hud.displayTotalAmmoInMag(cW.totalAmmoInMag, cW.nbProjShotsAtSameTime)
    
    var total_ammo = ammoManager.get_ammo_count(cW.ammoType)
    hud.displayTotalAmmo(total_ammo, cW.nbProjShotsAtSameTime)

func use_consumable(item: InventoryItem):
    if item.attributes.has("heal_amount"):
        var heal = item.attributes.heal_amount
        if playChar.has_method("heal"):
            playChar.heal(heal)
        print("Healed %d HP" % heal)
    
    if item.attributes.has("stamina_amount"):
        var stamina = item.attributes.stamina_amount
        if playChar.has_method("restore_stamina"):
            playChar.restore_stamina(stamina)
    
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
    
    # Add to inventory
    if inventory_component.add_item(item):
        print("Picked up: %s" % weapon.weaponName)
        print("Add to hotbar to use it!")
        return true
    
    return false

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
        
        # Sets the Visual Layer to 5
        # Note: If this is 2D, change '.layers' to '.visibility_layer'
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
        
        # JUICE: Randomize the pitch slightly (0.9 to 1.1)
        # This makes automatic fire sound less like a machine gun loop and more real
        var random_pitch = randf_range(0.95, 1.05)
        audioIns.pitch_scale = soundSpeed * random_pitch
        
        audioIns.stream = soundName
        
        audioIns.play()

func forceAttackPointTransformValues(attackPoint : Marker3D):
    if attackPoint.rotation != Vector3.ZERO: 
        attackPoint.rotation = Vector3.ZERO
