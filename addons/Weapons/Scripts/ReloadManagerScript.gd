# Modified ReloadManager.gd - Direct Inventory Ammo Consumption

extends Node3D
class_name ReloadManager

var reloadTime : float
var startReloadTimer : bool = false
var currentPartIndex : int
var playSoundAndAnim : bool
var forceReloadStop : bool = false

var cW # current weapon
@export var weaponManager : WeaponManager = %WeaponManager

func getCurrentWeapon(currentWeapon):
	cW = currentWeapon
	
func _process(delta : float):
	if not cW:
		return		
	
	if cW.isReloading and startReloadTimer and !forceReloadStop:
		reloadFollow(delta)
	elif forceReloadStop:
		cW.isReloading = false
		startReloadTimer = false
		return

		
func reload():
	reloadStart()
	
func reloadStart():
	if cW.hasToReload:
		# Check ammo directly from inventory
		var available_ammo = weaponManager.ammoManager.get_ammo_count(cW.ammoType)
		
		if (!cW.isReloading and \
		available_ammo > cW.nbProjShotsAtSameTime and \
		cW.totalAmmoInMag != cW.totalAmmoInMagRef and \
		!cW.isShooting): 
			cW.isReloading = true
			
			if (cW.totalAmmoInMagRef % cW.nbPartsNeeded) != 0:
				push_error("The number of parts set is not correct, cannot insert %d of ammunition" % (cW.nbPartsNeeded / cW.totalAmmoInMagRef))
				cW.isReloading = false
			else:
				currentPartIndex = 0
				reloadTime = cW.reloadTimePerPart
				forceReloadStop = false
				playSoundAndAnim = true
				startReloadTimer = true
		else:
			if available_ammo <= 0:
				print("No ammo in inventory for ", cW.ammoType)
	else:
		print("No need to reload")
		
func reloadFollow(delta : float):
	if playSoundAndAnim:
		playSoundAndAnim = false
		weaponManager.weaponSoundManagement(cW.reloadSound, cW.reloadSoundSpeed)
		
		if cW.shootAnimName != "":
			weaponManager.animManager.playAnimation("ReloadAnim%s" % cW.weaponName, cW.reloadAnimSpeed, true)
		else:
			print("%s doesn't have a reload animation" % cW.weaponName)
			
	if reloadTime > 0.0: 
		reloadTime -= delta
	else:
		if currentPartIndex < cW.nbPartsNeeded:
			if cW.nbPartsNeeded == 1:
				onePartReloadCalculus()
			else:
				multiPartReloadCalculus()
				
			currentPartIndex += 1
			
			if currentPartIndex < cW.nbPartsNeeded:
				reloadTime = cW.reloadTimePerPart
				playSoundAndAnim = true
			else:
				print("Reload complete")
				cW.isReloading = false
		else:
			print("Reload complete")
			cW.isReloading = false
			
func onePartReloadCalculus():
	# Calculate how much ammo we need
	var ammo_needed = cW.totalAmmoInMagRef - cW.totalAmmoInMag
	var available_ammo = weaponManager.ammoManager.get_ammo_count(cW.ammoType)
	
	# Take the minimum of what we need and what's available
	var nbAmmoToRefill = min(ammo_needed, available_ammo)
	
	if nbAmmoToRefill >= cW.nbProjShotsAtSameTime:
		# Consume ammo directly from inventory
		if weaponManager.ammoManager.consume_ammo(cW.ammoType, nbAmmoToRefill):
			# Add to magazine
			cW.totalAmmoInMag += nbAmmoToRefill
			print("Reloaded %d rounds from inventory" % nbAmmoToRefill)
		else:
			print("Failed to consume ammo from inventory")
			forceReloadStop = true
	else:
		print("Not enough ammo to reload")
		forceReloadStop = true
		
func multiPartReloadCalculus():
	var nbAmmoToRefill = cW.totalAmmoInMagRef / cW.nbPartsNeeded
	var available_ammo = weaponManager.ammoManager.get_ammo_count(cW.ammoType)
	
	if available_ammo >= nbAmmoToRefill and \
	cW.totalAmmoInMag <= cW.totalAmmoInMagRef - nbAmmoToRefill:
		# Consume ammo directly from inventory
		if weaponManager.ammoManager.consume_ammo(cW.ammoType, nbAmmoToRefill):
			# Add to magazine
			cW.totalAmmoInMag += nbAmmoToRefill
			print("Reloaded %d rounds (part %d/%d)" % [nbAmmoToRefill, currentPartIndex + 1, cW.nbPartsNeeded])
		else:
			print("Failed to consume ammo from inventory")
			forceReloadStop = true
	else:
		print("Not enough ammunition in inventory, or magazine complete")
		forceReloadStop = true
		
func autoReload():
	# Check if we have any ammo in inventory
	var available_ammo = weaponManager.ammoManager.get_ammo_count(cW.ammoType)
	
	if cW.autoReload and !cW.isReloading and \
	available_ammo > 0 and \
	cW.totalAmmoInMag <= 0: 
		reload()
