# MeleeWeaponResource.gd - Resource definition for melee weapons

extends Resource
class_name MeleeWeaponResource

@export_group("Identification")
@export var melee_id: int = 0
@export var weapon_name: String = "Melee Weapon"
@export var weapon_type: String = "knife"  # knife, bat, sword, axe, fists

@export_group("Stats")
@export var damage: float = 25.0
@export var attack_speed: float = 0.5  # Time between attacks
@export var range: float = 2.0
@export var knockback: float = 5.0
@export var stamina_cost: float = 10.0

@export_group("Attack Types")
@export var has_light_attack: bool = true
@export var has_heavy_attack: bool = true
@export var can_block: bool = false
@export var can_parry: bool = false
@export var max_combo: int = 3

@export_group("Damage Type")
@export var damage_type: String = "slash"  # slash, pierce, blunt

@export_group("Heavy Attack")
@export var heavy_damage_multiplier: float = 2.0
@export var heavy_knockback_multiplier: float = 3.0
@export var heavy_charge_time: float = 1.0
@export var heavy_stamina_cost: float = 25.0

@export_group("Blocking")
@export var block_damage_reduction: float = 0.5
@export var block_stamina_drain: float = 5.0  # Per hit blocked

@export_group("Animations")
@export var light_attack_anims: Array[String] = ["attack_light_1", "attack_light_2", "attack_light_3"]
@export var heavy_attack_anim: String = "attack_heavy"
@export var block_anim: String = "block"
@export var equip_anim: String = "equip"
@export var unequip_anim: String = "unequip"

@export_group("Sounds")
@export var swing_sound: AudioStream
@export var hit_sound: AudioStream
@export var block_sound: AudioStream
@export var equip_sound: AudioStream

@export_group("Visual")
@export var weapon_model: PackedScene
@export var trail_effect: PackedScene
@export var hit_effect: PackedScene

@export_group("Special Properties")
@export var can_backstab: bool = false
@export var backstab_multiplier: float = 3.0
@export var can_execute: bool = false  # Finish downed enemies
@export var execute_health_threshold: float = 0.2  # 20% HP


# Runtime properties (set by system)
var is_equipped: bool = false
var combo_count: int = 0
