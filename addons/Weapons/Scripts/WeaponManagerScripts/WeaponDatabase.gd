# WeaponDatabase.gd - Manages weapon resources and slots
extends Node
class_name WeaponDatabase

@export var weaponResources: Array[WeaponResource]

var weaponList: Dictionary = {}  # All weapon resources
var weapon_container: Node3D

func initialize():
	load_weapon_resources()
	setup_weapon_slots()

func load_weapon_resources():
	"""Load all weapon resources into dictionary"""
	for weapon in weaponResources:
		weaponList[weapon.weaponId] = weapon

func setup_weapon_slots():
	"""Setup weapon slots but keep invisible"""
	if not weapon_container:
		return
	
	for weapon_id in weaponList.keys():
		var weapon = weaponList[weapon_id]
		
		for weaponSlot in weapon_container.get_children():
			if weaponSlot.weaponId == weapon.weaponId:
				weapon.weaponSlot = weaponSlot
				var model = weapon.weaponSlot.model
				model.visible = false  # Start hidden
				
				force_attack_point_transform_values(weapon.weaponSlot.attackPoint)
				weapon.bobPos = weapon.position

func force_attack_point_transform_values(attackPoint: Marker3D):
	"""Reset attack point rotation to zero"""
	if attackPoint.rotation != Vector3.ZERO:
		attackPoint.rotation = Vector3.ZERO

func get_weapon(weapon_id: int) -> WeaponResource:
	"""Get weapon resource by ID"""
	return weaponList.get(weapon_id)

func has_weapon(weapon_id: int) -> bool:
	"""Check if weapon exists in database"""
	return weaponList.has(weapon_id)

func get_all_weapons() -> Dictionary:
	"""Get all weapons"""
	return weaponList
