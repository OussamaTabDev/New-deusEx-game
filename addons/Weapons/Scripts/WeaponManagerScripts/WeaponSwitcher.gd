# WeaponSwitcher.gd - Handles weapon switching logic

extends Node
class_name WeaponSwitcher

var weapon_database: WeaponDatabase
var weapon_visuals: WeaponVisualsManager
var weapon_health_checker: WeaponHealthChecker
var animManager: Node3D
var shootManager: ShootManager
var reloadManager: ReloadManager
var player: CharacterBody3D
var hud: CanvasLayer

# Current state references (set by WeaponManager each frame)
var cW = null
var pW = null


func hide_all_weapons():
    """Hide all weapon models"""
    for weapon_id in weapon_database.weaponList.keys():
        var weapon = weapon_database.weaponList[weapon_id]
        if weapon.weaponSlot and weapon.weaponSlot.model:
            weapon.weaponSlot.model.visible = false


func switch_to_hotbar_slot(slot: int, inventory: InventoryComponent, current_weapon, current_slot: int) -> Dictionary:
    """
    Determine if we should switch weapons
    Returns: {success: bool, should_exit: bool, weapon_id: int, slot: int}
    """
    
    if not inventory:
        return {success = false}
    
    if slot < 0 or slot >= inventory.hotbar_slots:
        return {success = false}
    
    # Get item from hotbar
    var item = inventory.hotbar[slot]
    
    # Must be a weapon
    if not item or item.type != "weapon":
        print("No weapon in hotbar slot %d" % (slot + 1))
        return {success = false}
    
    # Must have weapon_id
    if not item.attributes.has("weapon_id"):
        return {success = false}
    
    var weapon_id = int(item.attributes.weapon_id)
    
    # Check if weapon exists
    if not weapon_database.has_weapon(weapon_id):
        print("Weapon ID %d not found!" % weapon_id)
        return {success = false}
    
    # Don't switch to same weapon
    if current_weapon and current_weapon.weaponId == weapon_id:
        return {success = false}
    
    # Determine if we need to exit current weapon
    var should_exit = (current_weapon != null)
    
    return {
        success = true,
        should_exit = should_exit,
        weapon_id = weapon_id,
        slot = slot
    }


func play_unequip(weapon: WeaponResource, model: Node3D, audio_manager: PackedScene):
    """Play unequip animation and wait"""
    # Cancel current actions
    if weapon.isShooting:
        weapon.isShooting = false
    if weapon.isReloading:
        weapon.isReloading = false
    
    # Play animation
    if weapon.unequipAnimName != "":
        animManager.playAnimation("UnequipAnim%s" % weapon.weaponName, weapon.unequipAnimSpeed, false)
        if weapon.unequipSound:
            _play_weapon_sound(weapon, audio_manager, weapon.unequipSound, weapon.unequipSoundSpeed)
    
    # Wait for exact unequip time
    if weapon.unequipTime > 0:
        await get_tree().create_timer(weapon.unequipTime).timeout


func play_equip(weapon: WeaponResource, anim_player: AnimationPlayer, audio_manager: PackedScene):
    """Play equip animation and wait"""
    # Play sound
    if weapon.equipSound:
        _play_weapon_sound(weapon, audio_manager, weapon.equipSound, weapon.equipSoundSpeed)
    
    # Set blend time
    anim_player.playback_default_blend_time = weapon.animBlendTime
    
    # Play animation
    if weapon.equipAnimName != "":
        animManager.playAnimation("EquipAnim%s" % weapon.weaponName, weapon.equipAnimSpeed, false)
    
    # Wait for exact equip time
    if weapon.equipTime > 0:
        await get_tree().create_timer(weapon.equipTime).timeout


func equip_previous_weapon(previous_weapon, inventory: InventoryComponent):
    """Re-equip the previous weapon if available"""
    print("Re-equipping previous weapon...")
    
    if not previous_weapon:
        return
    
    var weapon_id = previous_weapon.weaponId
    
    # Find weapon in hotbar
    for i in range(inventory.hotbar_slots):
        var item = inventory.hotbar[i]
        if item and item.type == "weapon" and item.attributes.get("weapon_id") == weapon_id:
            # Trigger switch through main manager
            if weapon_database.weaponList.has(weapon_id):
                print("Found previous weapon in slot %d" % i)
                # Return the slot to switch to
                return i
    
    return -1


func _play_weapon_sound(weapon: WeaponResource, audio_manager: PackedScene, sound: AudioStream, speed: float):
    """Play weapon sound"""
    var audioIns: AudioStreamPlayer3D = audio_manager.instantiate()
    get_tree().get_root().add_child.call_deferred(audioIns)
    await get_tree().process_frame
    
    if audioIns.is_inside_tree():
        audioIns.global_transform = weapon.weaponSlot.attackPoint.global_transform
        audioIns.bus = "Sfx"
        var random_pitch = randf_range(0.95, 1.05)
        audioIns.pitch_scale = speed * random_pitch
        audioIns.stream = sound
        audioIns.play()
