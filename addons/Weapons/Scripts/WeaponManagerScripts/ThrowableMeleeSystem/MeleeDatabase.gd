# MeleeDatabase.gd - Manages melee weapon resources
extends Node
class_name MeleeDatabase

@export var melee_resources: Array[MeleeWeaponResource]

var melee_list: Dictionary = {}  # melee_id -> MeleeWeaponResource

func _ready():
	initialize()

func initialize():
	"""Load all melee resources"""
	for melee in melee_resources:
		melee_list[melee.weapon_id] = melee
	
	print("Loaded %d melee weapons" % melee_list.size())

func get_melee(melee_id: int) -> MeleeWeaponResource:
	"""Get melee resource by ID"""
	return melee_list.get(melee_id)

func has_melee(melee_id: int) -> bool:
	"""Check if melee exists"""
	return melee_list.has(melee_id)

func get_all_melee() -> Dictionary:
	"""Get all melee weapons"""
	return melee_list
