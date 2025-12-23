# MeleeWeaponResource.gd - Defines melee weapon properties
extends Resource
class_name MeleeWeaponResource

@export_group("Basic Info")
@export var weapon_id: int = 0
@export var weapon_name: String = "Melee Weapon"
@export var description: String = ""
@export var icon: Texture2D

@export_group("Combat Stats")
@export var light_damage: float = 25.0
@export var heavy_damage: float = 50.0
@export var light_speed: float = 1.0  # Animation speed multiplier
@export var heavy_speed: float = 0.7
@export var attack_range: float = 2.0
@export var attack_cone_angle: float = 60.0  # Degrees for hit detection cone
@export var knockback_force: float = 5.0

@export_group("Stamina Costs")
@export var light_stamina_cost: float = 10.0
@export var heavy_stamina_cost: float = 25.0
@export var block_stamina_drain: float = 5.0  # Per second while blocking

@export_group("Combo System")
@export var max_combo_hits: int = 3
@export var combo_timeout: float = 1.5  # Time window for next hit
@export var combo_damage_multiplier: float = 1.2  # Damage increase per combo hit
@export var final_combo_knockback_multiplier: float = 2.0

@export_group("Charge Attack")
@export var can_charge: bool = true
@export var min_charge_time: float = 0.5
@export var max_charge_time: float = 2.0
@export var charge_damage_multiplier: float = 2.0
@export var charge_knockback_multiplier: float = 2.5

@export_group("Blocking")
@export var can_block: bool = true
@export var block_damage_reduction: float = 0.7  # 70% damage blocked
@export var perfect_block_window: float = 0.3  # Timing window for perfect block
@export var perfect_block_reduction: float = 0.95  # 95% damage blocked

@export_group("Special Abilities")
@export var can_backstab: bool = false
@export var backstab_damage_multiplier: float = 3.0
@export var can_execute: bool = false  # Execute low health enemies
@export var execute_health_threshold: float = 0.2  # 20% health
@export var has_special_ability: bool = false
@export var special_ability_name: String = ""
@export var special_cooldown: float = 10.0

@export_group("Visual & Audio")
@export var light_attack_anim: String = "light_attack"
@export var heavy_attack_anim: String = "heavy_attack"
@export var block_anim: String = "block"
@export var equip_anim: String = "equip"
@export var unequip_anim: String = "unequip"

@export var swing_sound: AudioStream
@export var hit_sound: AudioStream
@export var block_sound: AudioStream
@export var perfect_block_sound: AudioStream

@export_group("Weapon Model")
@export var weapon_scene: PackedScene  # 3D model
@export var trail_effect: PackedScene  # Trail during swing

@export_group("Timing")
@export var equip_time: float = 0.5
@export var unequip_time: float = 0.4
@export var light_attack_duration: float = 0.4
@export var heavy_attack_duration: float = 0.8

# Runtime state (not saved)
var current_combo: int = 0
var combo_timer: float = 0.0
var is_attacking: bool = false
var is_blocking: bool = false
var is_charging: bool = false
var charge_time: float = 0.0
var special_cooldown_timer: float = 0.0
var weapon_slot: Node3D = null

func reset_combo():
	current_combo = 0
	combo_timer = 0.0

func increment_combo():
	current_combo = min(current_combo + 1, max_combo_hits)
	combo_timer = combo_timeout

func get_combo_damage(base_damage: float) -> float:
	if current_combo <= 1:
		return base_damage
	return base_damage * pow(combo_damage_multiplier, current_combo - 1)

func is_final_combo_hit() -> bool:
	return current_combo >= max_combo_hits
