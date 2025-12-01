class_name BleedingSystem
extends Node

signal blood_trail_created(position: Vector3)

@export var blood_decal_scene: PackedScene  # Optional: blood decal prefab
@export var bleed_tick_interval: float = 1.0
@export var blood_trail_interval: float = 2.0

var active_bleeds: Dictionary = {}  # BodyPart -> bleed_rate
var bleed_timer: float = 0.0
var trail_timer: float = 0.0
var parent_character: Node3D

func _ready():
	parent_character = get_parent().get_parent()

func _process(delta: float):
	if active_bleeds.is_empty():
		return
	
	bleed_timer += delta
	trail_timer += delta
	
	# Apply bleed damage
	if bleed_timer >= bleed_tick_interval:
		bleed_timer = 0.0
		_apply_bleed_damage()
	
	# Create blood trail
	if trail_timer >= blood_trail_interval:
		trail_timer = 0.0
		_create_blood_trail()

func start_bleeding(limb: LimbData.Limb, rate: float) -> void:
	limb.is_bleeding = true
	limb.bleed_rate = rate
	active_bleeds[limb.part] = limb

func stop_bleeding(limb: LimbData.Limb) -> void:
	limb.is_bleeding = false
	limb.bleed_rate = 0.0
	active_bleeds.erase(limb.part)

func stop_all_bleeding() -> void:
	for limb in active_bleeds.values():
		limb.is_bleeding = false
		limb.bleed_rate = 0.0
	active_bleeds.clear()

func _apply_bleed_damage() -> void:
	var health_component = get_parent() as HealthComponent
	if not health_component:
		return
	
	for limb in active_bleeds.values():
		var damage_info = DamageTypes.DamageInfo.new(
			limb.bleed_rate * bleed_tick_interval,
			DamageTypes.Type.ENVIRONMENTAL
		)
		health_component.apply_damage_to_limb(limb.part, damage_info)

func _create_blood_trail() -> void:
	if not parent_character:
		return
	
	var position = parent_character.global_position
	blood_trail_created.emit(position)
	
	# Optional: spawn blood decal
	if blood_decal_scene:
		var decal = blood_decal_scene.instantiate()
		get_tree().root.add_child(decal)
		decal.global_position = position

func get_total_bleed_rate() -> float:
	var total = 0.0
	for limb in active_bleeds.values():
		total += limb.bleed_rate
	return total
