# ThrowableResource.gd - Defines throwable item properties
extends Resource
class_name ThrowableResource

enum ThrowableType {
	GRENADE,
	KNIFE,
	MOLOTOV,
	FLASHBANG,
	SMOKE,
	AXE,
	ROCK
}

@export_group("Basic Info")
@export var throwable_id: int = 0
@export var throwable_name: String = "Throwable"
@export var description: String = ""
@export var icon: Texture2D
@export var throwable_type: ThrowableType = ThrowableType.GRENADE

@export_group("Throwing Physics")
@export var throw_force: float = 15.0
@export var throw_arc: float = 0.3  # Higher = more arc
@export var max_throw_distance: float = 30.0
@export var projectile_mass: float = 0.5
@export var air_resistance: float = 0.1

@export_group("Cooking Mechanic")
@export var can_cook: bool = true
@export var fuse_time: float = 3.0  # Total fuse time
@export var auto_throw_at_max: bool = true  # Auto-throw when fully cooked
@export var min_cook_time: float = 0.0  # Minimum time to hold

@export_group("Damage & Effects")
@export var explosion_damage: float = 100.0
@export var explosion_radius: float = 8.0
@export var damage_falloff: bool = true  # Damage decreases with distance
@export var direct_hit_damage: float = 150.0  # If it hits before exploding

# Knife/Axe specific
@export var stuck_damage: float = 50.0  # Damage when stuck in enemy
@export var can_stick: bool = false  # Can stick to surfaces/enemies

# Special effects
@export var applies_fire: bool = false  # Molotov
@export var fire_duration: float = 5.0
@export var fire_damage_per_second: float = 20.0

@export var applies_flash: bool = false  # Flashbang
@export var flash_duration: float = 3.0
@export var flash_radius: float = 10.0

@export var applies_smoke: bool = false  # Smoke grenade
@export var smoke_duration: float = 8.0
@export var smoke_radius: float = 6.0

@export_group("Physics Force")
@export var applies_force: bool = true
@export var explosion_force: float = 1000.0
@export var force_falloff: bool = true

@export_group("Trajectory Preview")
@export var show_trajectory: bool = true
@export var trajectory_point_count: int = 30
@export var trajectory_point_spacing: float = 0.1

@export_group("Visual & Audio")
@export var projectile_scene: PackedScene  # The spawned projectile
@export var explosion_effect: PackedScene
@export var trail_effect: PackedScene
@export var impact_effect: PackedScene

@export var throw_sound: AudioStream
@export var explosion_sound: AudioStream
@export var beep_sound: AudioStream  # While cooking
@export var bounce_sound: AudioStream

@export_group("Timing")
@export var equip_time: float = 0.3
@export var unequip_time: float = 0.3
@export var throw_animation_time: float = 0.5

@export_group("Inventory")
@export var max_stack: int = 5
@export var weight: float = 0.5

# Runtime state
var is_cooking: bool = false
var cook_timer: float = 0.0
var weapon_slot: Node3D = null

func get_remaining_fuse() -> float:
	return max(0.0, fuse_time - cook_timer)

func is_fully_cooked() -> bool:
	return cook_timer >= fuse_time

func get_cook_percentage() -> float:
	return clamp(cook_timer / fuse_time, 0.0, 1.0)
