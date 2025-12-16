extends Node3D
class_name ShootManager

# Local cache
var cW # Current Weapon Resource
var pointOfCollision : Vector3 = Vector3.ZERO
var rng : RandomNumberGenerator

@export var weaponManager : WeaponManager = %WeaponManager

func _ready():
	# Performance: Initialize RNG once, not every frame
	rng = RandomNumberGenerator.new()

func getCurrentWeapon(currWeap):
	cW = currWeap

func shoot():
	# 1. Validation checks
	if not can_shoot():
		return
		
	# CRITICAL FIX: Create a local reference to the weapon data.
	# If the player switches weapons during the 'await' timer, 
	# 'current_weapon' keeps pointing to the gun they started shooting with.
	var current_weapon = cW 
	
	# 2. Check Ammo (Inventory/Mag)
	if not has_ammo_to_start_shooting(current_weapon):
		handle_out_of_ammo(current_weapon)
		return

	# 3. Start Shooting State
	current_weapon.isShooting = true
	
	# 4. Burst Fire Loop (For burst weapons, this runs multiple times. For semi-auto, once.)
	for i in range(current_weapon.nbProjShots):
		
		# Re-check ammo before every shot in the burst
		if not has_enough_ammo_in_mag(current_weapon):
			print("Click! Out of ammo mid-burst.")
			break
			
		# --- EXECUTE SINGLE SHOT CYCLE ---
		perform_single_shot(current_weapon)
		
		# Wait for fire rate (Rate of Fire)
		await get_tree().create_timer(current_weapon.timeBetweenShots).timeout
		
		# Optional: Stop burst if trigger released (uncomment if desired)
		# if not Input.is_action_pressed("fire"): break
		
	current_weapon.isShooting = false


func perform_single_shot(w_ref):
	# 1. Consume Ammo
	# FIX: We consume ammo ONCE per shot cycle, not inside the pellet loop.
	consume_ammo(w_ref)

	# --- JUICE INJECTION ---
	# Arguments: (KickBack Amount, KickUp Amount)
	# You can tweak these numbers or even add them to your WeaponResource
	# Example: 0.15 meters back, 0.1 radians up
	weaponManager.apply_visual_recoil(0.15, 0.1) 
	# -----------------------



	# 2. Play Visuals & Audio
	weaponManager.weaponSoundManagement(w_ref.shootSound, w_ref.shootSoundSpeed)
	
	if w_ref.shootAnimName != "":
		weaponManager.animManager.playAnimation("ShootAnim%s" % w_ref.weaponName, w_ref.shootAnimSpeed, true)
	else:
		print("%s doesn't have a shoot animation" % w_ref.weaponName)

	if w_ref.showMuzzleFlash: 
		weaponManager.displayMuzzleFlash()


	# 3. Apply Recoil
	weaponManager.cameraRecoilHolder.setRecoilValues(w_ref.baseRotSpeed, w_ref.targetRotSpeed)
	weaponManager.cameraRecoilHolder.addRecoil(w_ref.recoilVal)

	# 4. Calculate Aim Point (Raycast from Camera center)
	pointOfCollision = getCameraPOV(w_ref)

	# 5. Spawn Projectiles / Hitscans (Handle Shotgun Pellets)
	# If nbProjShotsAtSameTime is 1 (Rifle), this runs once.
	# If it is 8 (Shotgun), this runs 8 times.
	for j in range(w_ref.nbProjShotsAtSameTime):
		
		if w_ref.type == w_ref.types.HITSCAN:
			hitscanShot(pointOfCollision, w_ref)
		elif w_ref.type == w_ref.types.PROJECTILE:
			projectileShot(pointOfCollision, w_ref)


# --- AMMO HELPERS ---

func has_ammo_to_start_shooting(w_ref) -> bool:
	# Check if we have ammo in mag
	if has_enough_ammo_in_mag(w_ref):
		return true
		
	# If mag is empty, try auto-reload
	if w_ref.autoReload and weaponManager.reloadManager:
		weaponManager.reloadManager.reload()
	return false

func has_enough_ammo_in_mag(w_ref) -> bool:
	# Logic: Do we have enough ammo for at least 1 projectile?
	# Note: Usually you consume 1 ammo per shot, regardless of pellet count.
	# If your game consumes 1 ammo per pellet, keep 'w_ref.nbProjShotsAtSameTime'.
	# If 1 shell = 8 pellets, change comparison to just '>= 1'.
	
	var required_ammo = 1 # or w_ref.nbProjShotsAtSameTime if 1 pellet = 1 ammo unit
	
	if w_ref.allAmmoInMag:
		return weaponManager.ammoManager.ammoDict.get(w_ref.ammoType, 0) >= required_ammo
	else:
		return w_ref.totalAmmoInMag >= required_ammo

func consume_ammo(w_ref):
	var amount_to_consume = 1 
	# IF you want 1 ammo per pellet, change this to: amount_to_consume = w_ref.nbProjShotsAtSameTime
	
	if w_ref.allAmmoInMag:
		weaponManager.ammoManager.ammoDict[w_ref.ammoType] -= amount_to_consume
	else:
		w_ref.totalAmmoInMag -= amount_to_consume

func handle_out_of_ammo(w_ref):
	print("Out of ammo!")
	# Optional: Play dry fire sound here

func can_shoot() -> bool:
	if cW == null: return false
	
	# CRITICAL FIX: Always return false if the gun is currently cycling a shot.
	# It doesn't matter if it's auto or semi; the mechanical parts need to cycle 
	# (wait for the timer) before firing again.
	if cW.isShooting: 
		return false
		
	if cW.isReloading: return false
	return true



# --- SHOOTING LOGIC ---

func getCameraPOV(w_ref) -> Vector3:  
	var camera = weaponManager.camera 
	var window : Window = get_window()
	var viewport_size : Vector2i
	
	match window.content_scale_mode:
		window.CONTENT_SCALE_MODE_VIEWPORT: viewport_size = window.content_scale_size
		window.CONTENT_SCALE_MODE_CANVAS_ITEMS: viewport_size = window.content_scale_size
		_: viewport_size = window.get_size()
			
	var raycastStart = camera.project_ray_origin(viewport_size/2)
	var raycastDir = camera.project_ray_normal(viewport_size/2)
	var raycastEnd
	
	if w_ref.type == w_ref.types.HITSCAN: 
		raycastEnd = raycastStart + raycastDir * w_ref.maxRange 
	else: 
		raycastEnd = raycastStart + raycastDir * 280 # Arbitrary large distance for projectiles
	
	var query = PhysicsRayQueryParameters3D.create(raycastStart, raycastEnd)
	var intersection = get_world_3d().direct_space_state.intersect_ray(query)
	
	if not intersection.is_empty():
		return intersection.position
	else:
		return raycastEnd 

func hitscanShot(targetPoint : Vector3, w_ref):
	# Calculate Spread
	var spread_vec = Vector3(
		rng.randf_range(w_ref.minSpread, w_ref.maxSpread), 
		rng.randf_range(w_ref.minSpread, w_ref.maxSpread), 
		rng.randf_range(w_ref.minSpread, w_ref.maxSpread)
	)
	
	var attack_origin = w_ref.weaponSlot.attackPoint.get_global_transform().origin
	var bulletDir = (targetPoint - attack_origin).normalized()
	
	# Apply spread to the target point logic (Simplified for consistency with your code)
	var spreadTarget = targetPoint + spread_vec + bulletDir * 2
	
	var query = PhysicsRayQueryParameters3D.create(attack_origin, spreadTarget)
	query.collide_with_areas = true
	query.collide_with_bodies = true 
	
	var result = get_world_3d().direct_space_state.intersect_ray(query)
	
	if result: 
		var collider = result.collider
		var damage = w_ref.damagePerProj
		
		# Damage Dropoff Calculation
		var dist = targetPoint.distance_to(global_position)
		var dropoff_mult = 1.0
		if w_ref.damageDropoff: # Safety check
			dropoff_mult = w_ref.damageDropoff.sample(dist / w_ref.maxRange)
			
		damage *= dropoff_mult

		if collider.is_in_group("Enemies") and collider.has_method("hitscanHit"):
			collider.hitscanHit(damage, bulletDir, result.position)
		
		elif collider.is_in_group("EnemiesHead") and collider.has_method("hitscanHit"):
			collider.hitscanHit(damage * w_ref.headshotDamageMult, bulletDir, result.position)
		
		elif collider.is_in_group("HitableObjects") and collider.has_method("hitscanHit"): 
			collider.hitscanHit(damage / 6.0, bulletDir, result.position)
			weaponManager.displayBulletHole(result.position, result.normal, collider)
			
		else:
			weaponManager.displayBulletHole(result.position, result.normal, collider)

func projectileShot(targetPoint : Vector3, w_ref):
	# Calculate Spread
	var spread_vec = Vector3(
		rng.randf_range(w_ref.minSpread, w_ref.maxSpread), 
		rng.randf_range(w_ref.minSpread, w_ref.maxSpread), 
		rng.randf_range(w_ref.minSpread, w_ref.maxSpread)
	)
	
	var attack_origin = w_ref.weaponSlot.attackPoint.get_global_transform().origin
	
	# Calculate Direction with spread added
	var direction = ((targetPoint - attack_origin).normalized() + spread_vec).normalized()
	
	var projInstance = w_ref.projRef.instantiate()
	
	projInstance.global_transform = w_ref.weaponSlot.attackPoint.global_transform
	projInstance.direction = direction
	projInstance.damage = w_ref.damagePerProj
	projInstance.timeBeforeVanish = w_ref.projTimeBeforeVanish
	projInstance.gravity_scale = w_ref.projGravityVal
	projInstance.isExplosive = w_ref.isProjExplosive
	
	# FIX: Add to current scene, not root (prevents memory leaks on scene change)
	get_tree().current_scene.add_child(projInstance)
	
	if projInstance is RigidBody3D:
		projInstance.set_linear_velocity(direction * w_ref.projMoveSpeed)
