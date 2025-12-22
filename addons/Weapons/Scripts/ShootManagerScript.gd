## Smooth ShootManager - Production Ready
## Clean, smooth shooting with health integration
extends Node3D
class_name ShootManager

var cW
var pointOfCollision: Vector3 = Vector3.ZERO
var rng: RandomNumberGenerator

@export var weaponManager: WeaponManager
@export var combat_health: CombatHealthComponent

## Smooth settings
@export var use_smooth_modifiers: bool = true
@export var modifier_cache_time: float = 0.1

## Cached modifiers (updated smoothly)
var _cached_recoil: float = 1.0
var _cached_spread: float = 1.0
var _cache_timer: float = 0.0

func _ready():
    rng = RandomNumberGenerator.new()

func _process(delta: float):
    _update_cached_modifiers(delta)

func getCurrentWeapon(currWeap):
    cW = currWeap

## ============================================
## SMOOTH MODIFIER CACHING
## ============================================

func _update_cached_modifiers(delta: float):
    """Cache modifiers to avoid frame hitches"""
    if not use_smooth_modifiers or not combat_health:
        return
    
    _cache_timer += delta
    if _cache_timer >= modifier_cache_time:
        _cached_recoil = combat_health.get_recoil_multiplier()
        _cached_spread = combat_health.get_spread_multiplier()
        _cache_timer = 0.0

## ============================================
## SMOOTH SHOOTING
## ============================================

func shoot():
    if not can_shoot():
        return


    var current_weapon = cW
    
    if not has_ammo_to_start_shooting(current_weapon):
        handle_out_of_ammo(current_weapon)
        return
    
    # Interrupt the reload manager if it's currently running
    if cW.isReloading and weaponManager.reloadManager:
        weaponManager.reloadManager.cancel_reload()
        
    current_weapon.isShooting = true
    
    for i in range(current_weapon.nbProjShots):
        if not has_enough_ammo_in_mag(current_weapon):
            break
        
        perform_single_shot(current_weapon)
        print("Shot fired from %s" % current_weapon.weaponName)
        Engine_effects.frameFreeze(0.15, .25)  # Brief hit stop for impact feel
        # Smooth fire rate with modifiers
        var modified_time = current_weapon.timeBetweenShots
        if use_smooth_modifiers and combat_health:
            var stability = combat_health.combat_modifiers.weapon_stability
            modified_time *= (1.0 + (1.0 - stability) * 0.5)
        
        await get_tree().create_timer(modified_time).timeout
    
    current_weapon.isShooting = false

func perform_single_shot(w_ref):
    consume_ammo(w_ref)
    
    # Smooth recoil application
    var recoil_mult = _cached_recoil if use_smooth_modifiers else 1.0
    weaponManager.apply_visual_recoil(0.15 * recoil_mult, 0.1 * recoil_mult)
    
    weaponManager.weaponSoundManagement(w_ref.shootSound, w_ref.shootSoundSpeed)
    
    if w_ref.shootAnimName != "":
        weaponManager.animManager.playAnimation("ShootAnim%s" % w_ref.weaponName, w_ref.shootAnimSpeed, true)
    
    if w_ref.showMuzzleFlash:
        weaponManager.displayMuzzleFlash()
    
    # Smooth recoil
    var modified_recoil = w_ref.recoilVal * recoil_mult
    weaponManager.cameraRecoilHolder.setRecoilValues(w_ref.baseRotSpeed, w_ref.targetRotSpeed)
    weaponManager.cameraRecoilHolder.addRecoil(modified_recoil)
    
    pointOfCollision = getCameraPOV(w_ref)
    
    for j in range(w_ref.nbProjShotsAtSameTime):
        if w_ref.type == w_ref.types.HITSCAN:
            hitscanShot(pointOfCollision, w_ref)
        elif w_ref.type == w_ref.types.PROJECTILE:
            projectileShot(pointOfCollision, w_ref)

## ============================================
## AMMO SYSTEM (No changes needed)
## ============================================

func has_ammo_to_start_shooting(w_ref) -> bool:
    if has_enough_ammo_in_mag(w_ref):
        return true
    if w_ref.autoReload and weaponManager.reloadManager:
        weaponManager.reloadManager.reload()
    return false

func has_enough_ammo_in_mag(w_ref) -> bool:
    var required_ammo = 1
    if w_ref.allAmmoInMag:
        return weaponManager.ammoManager.ammoDict.get(w_ref.ammoType, 0) >= required_ammo
    else:
        return w_ref.totalAmmoInMag >= required_ammo

func consume_ammo(w_ref):
    var amount_to_consume = 1
    if w_ref.allAmmoInMag:
        weaponManager.ammoManager.ammoDict[w_ref.ammoType] -= amount_to_consume
    else:
        w_ref.totalAmmoInMag -= amount_to_consume * w_ref.nbProjShotsAtSameTime
        
func handle_out_of_ammo(w_ref):
    pass  # Silent - no spam

func can_shoot() -> bool:
    if cW == null:
        return false
    if cW.isShooting:
        return false
    # MODIFIED: If reloading, check if we have ammo to "cancel" into a shot
    if cW.isReloading:
        return has_enough_ammo_in_mag(cW)
    return true

## ============================================
## SHOOTING LOGIC WITH SMOOTH SPREAD
## ============================================

func getCameraPOV(w_ref) -> Vector3:
    var camera = weaponManager.camera
    var window: Window = get_window()
    var viewport_size: Vector2i
    
    match window.content_scale_mode:
        window.CONTENT_SCALE_MODE_VIEWPORT:
            viewport_size = window.content_scale_size
        window.CONTENT_SCALE_MODE_CANVAS_ITEMS:
            viewport_size = window.content_scale_size
        _:
            viewport_size = window.get_size()
    
    var raycastStart = camera.project_ray_origin(viewport_size/2)
    var raycastDir = camera.project_ray_normal(viewport_size/2)
    var raycastEnd
    
    if w_ref.type == w_ref.types.HITSCAN:
        raycastEnd = raycastStart + raycastDir * w_ref.maxRange
    else:
        raycastEnd = raycastStart + raycastDir * 280
    
    var query = PhysicsRayQueryParameters3D.create(raycastStart, raycastEnd)
    var intersection = get_world_3d().direct_space_state.intersect_ray(query)
    
    if not intersection.is_empty():
        return intersection.position
    else:
        return raycastEnd

func hitscanShot(targetPoint: Vector3, w_ref):
    # Smooth spread application
    var spread_mult = _cached_spread if use_smooth_modifiers else 1.0
    var modified_min = w_ref.minSpread * spread_mult
    var modified_max = w_ref.maxSpread * spread_mult
    
    var spread_vec = Vector3(
        rng.randf_range(modified_min, modified_max),
        rng.randf_range(modified_min, modified_max),
        rng.randf_range(modified_min, modified_max)
    )
    
    var attack_origin = w_ref.weaponSlot.attackPoint.get_global_transform().origin
    var bulletDir = (targetPoint - attack_origin).normalized()
    var spreadTarget = targetPoint + spread_vec + bulletDir * 2
    
    var query = PhysicsRayQueryParameters3D.create(attack_origin, spreadTarget)
    query.collide_with_areas = true
    query.collide_with_bodies = true
    
    var result = get_world_3d().direct_space_state.intersect_ray(query)
    
    if result:
        var collider = result.collider
        var damage = w_ref.damagePerProj
        
        var dist = targetPoint.distance_to(global_position)
        var dropoff_mult = 1.0
        if w_ref.damageDropoff:
            dropoff_mult = w_ref.damageDropoff.sample(dist / w_ref.maxRange)
        
        damage *= dropoff_mult
        
        if collider.is_in_group("Enemies") and collider.has_method("hitscanHit"):
            collider.hitscanHit(damage, bulletDir, result.position)
        elif collider.is_in_group("EnemiesHead") and collider.has_method("hitscanHit"):
            collider.hitscanHit(damage * w_ref.headshotDamageMult, bulletDir, result.position)
        elif collider.is_in_group("HitableObjects") and collider.hit_force_component:
            collider.hit_force_component.hitscan_hit(damage / 6.0, bulletDir, result.position)
            weaponManager.displayBulletHole(result.position, result.normal, collider)
        else:
            weaponManager.displayBulletHole(result.position, result.normal, collider)

func projectileShot(targetPoint: Vector3, w_ref):
    var spread_mult = _cached_spread if use_smooth_modifiers else 1.0
    var modified_min = w_ref.minSpread * spread_mult
    var modified_max = w_ref.maxSpread * spread_mult
    
    var spread_vec = Vector3(
        rng.randf_range(modified_min, modified_max),
        rng.randf_range(modified_min, modified_max),
        rng.randf_range(modified_min, modified_max)
    )
    
    var attack_origin = w_ref.weaponSlot.attackPoint.get_global_transform().origin
    var direction = ((targetPoint - attack_origin).normalized() + spread_vec).normalized()
    
    var projInstance = w_ref.projRef.instantiate()
    
    projInstance.global_transform = w_ref.weaponSlot.attackPoint.global_transform
    projInstance.direction = direction
    projInstance.damage = w_ref.damagePerProj
    projInstance.timeBeforeVanish = w_ref.projTimeBeforeVanish
    projInstance.gravity_scale = w_ref.projGravityVal
    projInstance.isExplosive = w_ref.isProjExplosive
    
    get_tree().current_scene.add_child(projInstance)
    
    if projInstance is RigidBody3D:
        projInstance.set_linear_velocity(direction * w_ref.projMoveSpeed)
