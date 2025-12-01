class_name DamageTypes
extends Resource

## Damage type enumeration
enum Type {
	Knock,
	BULLET,
	EXPLOSION,
	ELECTRICAL,
	FIRE,
	EMP_NANO_VIRAL,
	MELEE,
	FALL,
	ENVIRONMENTAL
}

## Damage instance data structure
class DamageInfo:
	var amount: float
	var type: Type
	var source: Node
	var hit_position: Vector3
	var hit_normal: Vector3
	var penetration: float = 1.0  # 0-1, affects armor
	
	func _init(amt: float, dmg_type: Type, src: Node = null):
		amount = amt
		type = dmg_type
		source = src
