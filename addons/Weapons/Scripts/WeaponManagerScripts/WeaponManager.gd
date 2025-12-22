# WeaponManager.gd - Main Orchestrator
# Coordinates all weapon-related subsystems

extends Node3D
class_name WeaponManager

# Core Components
@export_group("Weapon Components")
@export var weapon_database: WeaponDatabase
@export var weapon_switcher: WeaponSwitcher
@export var weapon_inputs: WeaponInputHandler
@export var weapon_visuals: WeaponVisualsManager
@export var weapon_drop_pickup: WeaponDropPickup
@export var weapon_health_checker: WeaponHealthChecker

# External Dependencies
@export_group("External Nodes")
@export var player: CharacterBody3D
@export var camera: Camera3D
@export var cameraHolder: CameraController
@export var cameraRecoilHolder: CameraRecoilHolder
@export var weaponContainer: Node3D = %WeaponContainer
@export var hud: CanvasLayer
@export var interaction_raycast: RayCast3D

# Managers
@export_group("Sub-Managers")
@export var shootManager: ShootManager = %ShootManager
@export var reloadManager: ReloadManager = %ReloadManager
@export var ammoManager: AmmunitionManager = %AmmunitionManager
@export var animPlayer: AnimationPlayer = %AnimationPlayer
@export var animManager: Node3D = %AnimationManager
@export var linkComponent: Node3D = %LinkComponent

# State Machine
@export_group("State System")
@export var state_machine: StateMachine

# Combat & Inventory
@export_group("Systems")
@export var combat_health: CombatHealthComponent
@export var inventory_component: InventoryComponent

# Resources
@onready var audioManager: PackedScene = preload("../../../Misc/Scenes/AudioManagerScene.tscn")
@onready var bulletDecal: PackedScene = preload("../../../Weapons/Scenes/BulletDecalScene.tscn")

# Current state
var cW = null  # Current weapon
var pW = null  # Previous weapon
var cWModel = null
var currentHotbarSlot: int = -1

# Control flags
var canChangeWeapons: bool = true
var canUseWeapon: bool = true
var unequipped_weapon: bool = false
var ignore_next_shoot: bool = false


func _ready():
    _initialize_components()
    _connect_signals()
    weapon_database.initialize()
    weapon_switcher.hide_all_weapons()


func _initialize_components():
    """Setup all weapon components with required references"""
    
    # Weapon Database
    weapon_database.weaponContainer = weaponContainer
    
    # Weapon Switcher
    weapon_switcher.weapon_database = weapon_database
    weapon_switcher.weapon_visuals = weapon_visuals
    weapon_switcher.weapon_health_checker = weapon_health_checker
    weapon_switcher.animManager = animManager
    weapon_switcher.shootManager = shootManager
    weapon_switcher.reloadManager = reloadManager
    weapon_switcher.player = player
    weapon_switcher.hud = hud
    
    # Input Handler
    weapon_inputs.weapon_switcher = weapon_switcher
    weapon_inputs.weapon_drop_pickup = weapon_drop_pickup
    weapon_inputs.weapon_health_checker = weapon_health_checker
    weapon_inputs.shootManager = shootManager
    weapon_inputs.reloadManager = reloadManager
    weapon_inputs.state_machine = state_machine
    weapon_inputs.interaction_raycast = interaction_raycast
    weapon_inputs.inventory_component = inventory_component
    
    # Visuals Manager
    weapon_visuals.camera = camera
    weapon_visuals.weaponContainer = weaponContainer
    weapon_visuals.initialize()
    
    # Drop/Pickup System
    weapon_drop_pickup.weapon_database = weapon_database
    weapon_drop_pickup.weapon_switcher = weapon_switcher
    weapon_drop_pickup.inventory_component = inventory_component
    weapon_drop_pickup.player = player
    
    # Health Checker
    weapon_health_checker.combat_health = combat_health
    weapon_health_checker.hud = hud
    
    # Link inventory to ammo
    if inventory_component and ammoManager:
        ammoManager.inventory_component = inventory_component


func _connect_signals():
    """Connect all necessary signals"""
    if inventory_component:
        inventory_component.hotbar_item_used.connect(_on_hotbar_used)


func _input(event):
    if not canChangeWeapons:
        return
    
    weapon_inputs.handle_input(event, cW, currentHotbarSlot)


func _process(delta: float):
    # Update component references
    weapon_switcher.cW = cW
    weapon_switcher.pW = pW
    weapon_inputs.cW = cW
    weapon_inputs.unequipped_weapon = unequipped_weapon
    weapon_inputs.canChangeWeapons = canChangeWeapons
    weapon_inputs.canUseWeapon = canUseWeapon
    
    # Process hold-to-unequip
    weapon_inputs.process_hold_unequip(delta)
    
    # Check grappling
    if player.is_graping() and cW != null:
        unequip_current_weapon()
    
    # Check arm health
    if cW != null and not weapon_health_checker.can_equip_weapon():
        print("⚠️ Right arm too damaged - dropping weapon!")
        weapon_drop_pickup.drop_current_weapon(cW, cWModel, currentHotbarSlot)
        _clear_weapon_state()
        return
    
    # Handle weapon inputs
    if cW != null and cWModel != null and canUseWeapon:
        weapon_inputs.process_weapon_inputs(ignore_next_shoot)
        reloadManager.autoReload()
    
    # Update visuals
    weapon_visuals.process_weapon_juice(delta, state_machine)
    
    # Update HUD
    if hud != null:
        displayStats()


func _on_hotbar_used(slot: int, item: InventoryItem):
    """When player uses hotbar item"""
    if item.type == "weapon":
        switch_to_hotbar_slot(slot)
    elif item.type == "consumable":
        use_consumable(item)


func switch_to_hotbar_slot(slot: int):
    """Switch to weapon in specific hotbar slot"""
    if not weapon_health_checker.can_equip_weapon():
        weapon_health_checker.show_arm_damaged_message()
        return
    
    var result = weapon_switcher.switch_to_hotbar_slot(
        slot,
        inventory_component,
        cW,
        currentHotbarSlot
    )
    
    if result.success:
        if result.should_exit:
            exitWeapon(result.weapon_id, result.slot)
        else:
            enterWeapon(result.weapon_id, result.slot)


func exitWeapon(nextWeaponId: int, nextSlot: int):
    """Unequip current weapon"""
    if nextWeaponId == cW.weaponId:
        return
    
    pW = cW
    canChangeWeapons = false
    canUseWeapon = false
    unequipped_weapon = true
    
    await weapon_switcher.play_unequip(cW, cWModel, audioManager)
    
    if cWModel:
        cWModel.visible = false
    
    enterWeapon(nextWeaponId, nextSlot)


func enterWeapon(nextWeaponId: int, slot: int):
    """Equip new weapon"""
    if not weapon_health_checker.can_equip_weapon():
        canChangeWeapons = true
        return
    
    if player.is_graping():
        return
    
    # Load weapon
    cW = weapon_database.weaponList[nextWeaponId]
    currentHotbarSlot = slot
    cWModel = cW.weaponSlot.model
    
    # Make visible
    cWModel.visible = true
    
    # Update managers
    shootManager.getCurrentWeapon(cW)
    reloadManager.getCurrentWeapon(cW)
    animManager.getCurrentWeapon(cW, cWModel)
    
    await weapon_switcher.play_equip(cW, animPlayer, audioManager)
    
    # Enable control
    cW.isShooting = false
    cW.isReloading = false
    unequipped_weapon = false
    canUseWeapon = true
    canChangeWeapons = true
    ignore_next_shoot = false
    
    print("Equipped: %s (Slot %d)" % [cW.weaponName, slot + 1])


func unequip_current_weapon():
    """Unequip current weapon without switching"""
    if not cW:
        return
    
    pW = cW
    unequipped_weapon = true
    canChangeWeapons = false
    canUseWeapon = false
    
    await weapon_switcher.play_unequip(cW, cWModel, audioManager)
    
    if cWModel:
        cWModel.visible = false
    
    _clear_weapon_state()
    
    canUseWeapon = true
    canChangeWeapons = true
    print("Weapon unequipped (via F hold)")


func _clear_weapon_state():
    """Clear current weapon references"""
    cW = null
    cWModel = null
    currentHotbarSlot = -1


func equip_previous_weapon():
    """Re-equip the previous weapon"""
    weapon_switcher.equip_previous_weapon(pW, inventory_component)


func displayStats():
    """Update HUD with weapon stats"""
    if not cW:
        hud.displayWeaponName("No Weapon")
        hud.displayTotalAmmoInMag(0, 1)
        hud.displayTotalAmmo(0, 1)
        weapon_health_checker.show_restriction_if_needed()
        return
    
    hud.displayWeaponName(cW.weaponName)
    hud.displayTotalAmmoInMag(cW.totalAmmoInMag, cW.nbProjShotsAtSameTime)
    
    var total_ammo = ammoManager.get_ammo_count(cW.ammoType)
    hud.displayTotalAmmo(total_ammo, cW.nbProjShotsAtSameTime)
    
    weapon_health_checker.show_restriction_if_needed()


func use_consumable(item: InventoryItem):
    """Use consumable item from hotbar"""
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


# Proxy methods for external access
func pickup_weapon(weapon_id: int) -> bool:
    return weapon_drop_pickup.pickup_weapon(weapon_id)

func pickup_ammo(ammo_type: String, amount: int) -> bool:
    return ammoManager.add_ammo(ammo_type, amount)

func attempt_pickup_unique(weapon_id: int) -> bool:
    if not weapon_health_checker.can_equip_weapon():
        weapon_health_checker.show_arm_damaged_message()
        return false
    
    return weapon_drop_pickup.attempt_pickup_unique(weapon_id, cW)

func has_weapon(weapon_id: int) -> bool:
    return weapon_drop_pickup.has_weapon(weapon_id)

func displayMuzzleFlash():
    if cW.muzzleFlashRef != null:
        var muzzleFlashInstance = cW.muzzleFlashRef.instantiate()
        add_child(muzzleFlashInstance)
        muzzleFlashInstance.global_position = cW.weaponSlot.muzzleFlashSpawner.global_position
        muzzleFlashInstance.layers = 5
        muzzleFlashInstance.emitting = true

func displayBulletHole(colliderPoint: Vector3, colliderNormal: Vector3, collider: Object):
    var bulletDecalInstance = bulletDecal.instantiate()
    if collider is Node3D:
        bulletDecalInstance.scale /= collider.scale
        collider.add_child(bulletDecalInstance)
    else:
        get_tree().get_root().add_child(bulletDecalInstance)
    bulletDecalInstance.global_position = colliderPoint
    bulletDecalInstance.look_at(colliderPoint - colliderNormal, Vector3.UP)
    bulletDecalInstance.rotate_object_local(Vector3(1.0, 0.0, 0.0), 90)

func weaponSoundManagement(soundName: AudioStream, soundSpeed: float):
    var audioIns: AudioStreamPlayer3D = audioManager.instantiate()
    get_tree().get_root().add_child.call_deferred(audioIns)
    await get_tree().process_frame
    
    if audioIns.is_inside_tree():
        audioIns.global_transform = cW.weaponSlot.attackPoint.global_transform
        audioIns.bus = "Sfx"
        var random_pitch = randf_range(0.95, 1.05)
        audioIns.pitch_scale = soundSpeed * random_pitch
        audioIns.stream = soundName
        audioIns.play()

func apply_visual_recoil(kick_back: float, kick_up: float):
    weapon_visuals.apply_visual_recoil(kick_back, kick_up)
