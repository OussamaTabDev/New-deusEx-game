# WeaponDatabase.gd - Manages weapon resource loading and storage

extends Node
class_name WeaponDatabase

@export var weaponResources: Array[WeaponResource]
var weaponList: Dictionary = {}  # All weapon resources
var weaponContainer: Node3D


func initialize():
    """Load all weapon resources into dictionary"""
    for weapon in weaponResources:
        weaponList[weapon.weaponId] = weapon
    
    # Setup weapon slots
    for weapo in weaponList.keys():
        var weapon = weaponList[weapo]
        
        for weaponSlot in weaponContainer.get_children():
            if weaponSlot.weaponId == weapon.weaponId:
                weapon.weaponSlot = weaponSlot
                var model = weapon.weaponSlot.model
                model.visible = false  # Start hidden
                
                _force_attack_point_transform(weapon.weaponSlot.attackPoint)
                weapon.bobPos = weapon.position


func get_weapon(weapon_id: int) -> WeaponResource:
    """Get weapon resource by ID"""
    return weaponList.get(weapon_id)


func has_weapon(weapon_id: int) -> bool:
    """Check if weapon exists in database"""
    return weaponList.has(weapon_id)


func get_weapon_scene_path(weapon_id: int) -> String:
    """Get scene path from inventory item"""
    for item in ItemDatabase.items.values():
        if item.type == "weapon" and item.attributes.get("weapon_id") == weapon_id:
            return item.scene_path
    return ""


func _force_attack_point_transform(attackPoint: Marker3D):
    """Force attack point rotation to zero"""
    if attackPoint.rotation != Vector3.ZERO:
        attackPoint.rotation = Vector3.ZERO
