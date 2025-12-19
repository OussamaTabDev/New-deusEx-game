## ============================================
## SMOOTH RELOAD MANAGER
## ============================================

extends Node3D
class_name ReloadManager

var reloadTime: float
var startReloadTimer: bool = false
var currentPartIndex: int
var playSoundAndAnim: bool
var forceReloadStop: bool = false

var cW
@export var weaponManager: WeaponManager
@export var combat_health: CombatHealthComponent

## Smooth settings
@export var use_smooth_reload: bool = true
var _cached_reload_mult: float = 1.0

func getCurrentWeapon(currentWeapon):
    cW = currentWeapon

func _process(delta: float):
    if not cW:
        return
    
    # Update cached modifier smoothly
    if use_smooth_reload and combat_health:
        _cached_reload_mult = lerp(_cached_reload_mult, combat_health.get_reload_speed_multiplier(), 5.0 * delta)
    
    if cW.isReloading and startReloadTimer and !forceReloadStop:
        reloadFollow(delta)

    elif forceReloadStop:
        cW.isReloading = false
        startReloadTimer = false
        forceReloadStop = false
        return

func reload():
    if not _can_reload():
        return
    reloadStart()

func reloadStart():
    if cW.hasToReload:
        var available_ammo = weaponManager.ammoManager.get_ammo_count(cW.ammoType) * cW.nbProjShotsAtSameTime
        
        if (!cW.isReloading and available_ammo >= cW.nbProjShotsAtSameTime and 
        cW.totalAmmoInMag < cW.totalAmmoInMagRef and !cW.isShooting):
            cW.isReloading = true
            if (cW.totalAmmoInMagRef % cW.nbPartsNeeded) != 0:
                cW.isReloading = false
            else:
                currentPartIndex = 0
                
                # Smooth reload time
                var base_time = cW.reloadTimePerPart
                reloadTime = base_time / _cached_reload_mult
                
                forceReloadStop = false
                playSoundAndAnim = true
                startReloadTimer = true

func reloadFollow(delta: float):
    if playSoundAndAnim:
        playSoundAndAnim = false
        
        # Smooth sound speed
        var sound_speed = cW.reloadSoundSpeed * _cached_reload_mult
        weaponManager.weaponSoundManagement(cW.reloadSound, sound_speed)
        
        if cW.shootAnimName != "":
            var anim_speed = cW.reloadAnimSpeed * _cached_reload_mult
            weaponManager.animManager.playAnimation("ReloadAnim%s" % cW.weaponName, anim_speed, true)
    
    if reloadTime > 0.0:
        reloadTime -= delta
    else:
        if currentPartIndex < cW.nbPartsNeeded:
            if cW.nbPartsNeeded == 1:
                print("One part reload calculus") #--- IGNORE ---
                onePartReloadCalculus()
            else:
                print("Multi part reload calculus") #--- IGNORE ---
                multiPartReloadCalculus()
            
            currentPartIndex += 1
            
            if currentPartIndex < cW.nbPartsNeeded:
                var base_time = cW.reloadTimePerPart
                reloadTime = base_time / _cached_reload_mult
                playSoundAndAnim = true
            else:
                cW.isReloading = false
        else:
            cW.isReloading = false

    
func onePartReloadCalculus():
    var ammo_needed = cW.totalAmmoInMagRef - cW.totalAmmoInMag
    var available_ammo = weaponManager.ammoManager.get_ammo_count(cW.ammoType) * cW.nbProjShotsAtSameTime
    var nbAmmoToRefill = min(ammo_needed, available_ammo)
    
    if nbAmmoToRefill >= cW.nbProjShotsAtSameTime:
        if weaponManager.ammoManager.consume_ammo(cW.ammoType, nbAmmoToRefill / cW.nbProjShotsAtSameTime):
            cW.totalAmmoInMag += nbAmmoToRefill
        else:
            forceReloadStop = true
    else:
        forceReloadStop = true

func multiPartReloadCalculus():
    var nbAmmoToRefill = cW.totalAmmoInMagRef / cW.nbPartsNeeded 
    var available_ammo = weaponManager.ammoManager.get_ammo_count(cW.ammoType) * cW.nbProjShotsAtSameTime
    
    if available_ammo >= nbAmmoToRefill and cW.totalAmmoInMag <= cW.totalAmmoInMagRef - nbAmmoToRefill:
        if weaponManager.ammoManager.consume_ammo(cW.ammoType, nbAmmoToRefill / cW.nbProjShotsAtSameTime):
            cW.totalAmmoInMag += nbAmmoToRefill
        else:
            forceReloadStop = true
    else:
        forceReloadStop = true

func autoReload():
    var available_ammo = weaponManager.ammoManager.get_ammo_count(cW.ammoType) * cW.nbProjShotsAtSameTime
    if cW.autoReload and !cW.isReloading and available_ammo > 0 and cW.totalAmmoInMag <= 0:
        reload()

func _can_reload() -> bool:
    if not combat_health or not combat_health.player_health:
        return true
    
    var right_arm = combat_health.player_health.get_limb(LimbData.BodyPart.RIGHT_ARM)
    var left_arm = combat_health.player_health.get_limb(LimbData.BodyPart.LEFT_ARM)
    
    return not (right_arm.is_destroyed() and left_arm.is_destroyed())

func cancel_reload():
    if not cW: return
    
    # Stop the logic
    cW.isReloading = false
    startReloadTimer = false
    forceReloadStop = true
    
    # Reset internal counters
    currentPartIndex = 0
    reloadTime = 0.0
    
    # OPTIONAL: Play a "Cancel" or "Pump" animation if your animator supports it
    # weaponManager.animManager.playAnimation("ShootCancel%s" % cW.weaponName, 1.0, true)
    
    print("Reload Canceled by User")
