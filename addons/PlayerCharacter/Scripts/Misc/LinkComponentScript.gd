extends Node3D

@export var ammoManager : AmmunitionManager = %AmmunitionManager
@export var weaponManager : WeaponManager = %WeaponManager

func ammoRefillLink(ammoDict : Dictionary):
	for key in ammoDict.keys():
		if key in ammoManager.ammoDict:
			#two cases for the min function here : 
			#1 : 
			var nbAmmoToRefill : int = min(ammoManager.maxNbPerAmmoDict[key] - ammoManager.ammoDict[key], ammoDict[key])
			ammoManager.ammoDict[key] += nbAmmoToRefill
