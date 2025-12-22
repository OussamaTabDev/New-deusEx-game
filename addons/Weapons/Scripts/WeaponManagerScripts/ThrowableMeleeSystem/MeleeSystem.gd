# MeleeSystem.gd - Handles melee combat (knife, bat, fists, etc.)

extends Node
class_name MeleeSystem

var weapon_manager: WeaponManager
var player: CharacterBody3D
var camera: Camera3D
var animation_manager: Node3D
var combat_health: CombatHealthComponent

# Current melee weapon
var current_melee: InventoryItem = null
var current_melee_resource: MeleeWeaponResource = null
var is_attacking: bool = false
var can_attack: bool = true
var combo_count: int = 0
var last_attack_time: float = 0.0

# Melee settings
@export_group("Melee Settings")
@export var melee_range: float = 2.0
@export var melee_angle: float = 60.0  # Cone angle for hit detection
@export var combo_window: float = 0.5  # Time to continue combo
@export var heavy_attack_charge_time: float = 1.0
@export var block_damage_reduction: float = 0.5

# Attack tracking
var is_charging_heavy: bool = false
var heavy_charge_start: float = 0.0
var is_blocking: bool = false

# Hit detection
@export var hit_layers: int = 1  # Physics layers to hit
var melee_raycast: RayCast3D

# Visual feedback
@export var show_hit_indicator: bool = true
var hit_particles: PackedScene


func _ready():
	_setup_melee_raycast()
	_load_hit_particles()


func _process(delta: float):
	if is_charging_heavy:
		_update_heavy_charge(delta)
	
	# Reset combo if too much time passed
	if combo_count > 0:
		var time_since_attack = Time.get_ticks_msec() / 1000.0 - last_attack_time
		if time_since_attack > combo_window:
			combo_count = 0


func _setup_melee_raycast():
	"""Create raycast for melee hit detection"""
	melee_raycast = RayCast3D.new()
	add_child(melee_raycast)
	melee_raycast.enabled = false
	melee_raycast.target_position = Vector3(0, 0, -melee_range)
	melee_raycast.collision_mask = hit_layers


func _load_hit_particles():
	"""Load particle effects for hits"""
	# Load your hit effect scene
	# hit_particles = preload("res://Effects/MeleeHit.tscn")
	pass


func equip_melee(item: InventoryItem):
	"""Equip a melee weapon"""
	if not is_item_melee(item):
		print("Item is not a melee weapon!")
		return
	
	current_melee = item
	
	# Load melee resource if it exists
	var melee_id = item.attributes.get("melee_id")
	if melee_id:
		current_melee_resource = _load_melee_resource(melee_id)
	
	combo_count = 0
	can_attack = true
	
	print("Equipped melee: %s" % item.display_name)


func unequip_melee():
	"""Unequip melee weapon"""
	current_melee = null
	current_melee_resource = null
	combo_count = 0
	is_blocking = false


func is_item_melee(item: InventoryItem) -> bool:
	"""Check if item is a melee weapon"""
	if not item:
		return false
	
	return item.type == "melee" or item.attributes.get("is_melee", false)


func attempt_light_attack():
	"""Perform light/quick attack"""
	if not can_attack or is_attacking or is_blocking:
		return
	
	if not current_melee:
		# Use fists
		_perform_fist_attack()
	else:
		_perform_melee_attack("light")


func attempt_heavy_attack():
	"""Start charging heavy attack"""
	if not can_attack or is_attacking or is_blocking:
		return
	
	is_charging_heavy = true
	heavy_charge_start = Time.get_ticks_msec() / 1000.0
	
	_play_melee_animation("heavy_charge")
	print("Charging heavy attack...")


func release_heavy_attack():
	"""Release heavy attack"""
	if not is_charging_heavy:
		return
	
	var charge_time = (Time.get_ticks_msec() / 1000.0) - heavy_charge_start
	is_charging_heavy = false
	
	# Fully charged?
	var is_fully_charged = charge_time >= heavy_attack_charge_time
	
	_perform_melee_attack("heavy", is_fully_charged)


func start_block():
	"""Start blocking"""
	if not current_melee or is_attacking:
		return
	
	# Only certain weapons can block
	if not _can_block():
		return
	
	is_blocking = true
	_play_melee_animation("block_start")
	print("Blocking...")


func stop_block():
	"""Stop blocking"""
	if not is_blocking:
		return
	
	is_blocking = false
	_play_melee_animation("block_end")


func _can_block() -> bool:
	"""Check if current melee weapon can block"""
	if not current_melee:
		return false
	
	return current_melee.attributes.get("can_block", false)


func _perform_fist_attack():
	"""Attack with bare fists"""
	is_attacking = true
	can_attack = false
	
	combo_count += 1
	var anim_name = "punch_%d" % ((combo_count - 1) % 3 + 1)  # punch_1, punch_2, punch_3
	
	_play_melee_animation(anim_name)
	_play_melee_sound("punch")
	
	# Detect hits after short delay (animation timing)
	await get_tree().create_timer(0.1).timeout
	
	var hit_data = {
		"damage": 10.0,
		"knockback": 2.0,
		"type": "blunt"
	}
	
	#_detect_and_apply_hits(hit_data)
	
	# Attack cooldown
	await get_tree().create_timer(0.3).timeout
	
	is_attacking = false
	can_attack = true
	last_attack_time = Time.get_ticks_msec() / 1000.0


func _perform_melee_attack(attack_type: String, fully_charged: bool = false):
	"""Perform melee weapon attack"""
	is_attacking = true
	can_attack = false
	
	var damage_multiplier = 1.0
	var knockback_multiplier = 1.0
	var attack_speed = 1.0
	
	match attack_type:
		"light":
			combo_count += 1
			var combo_index = (combo_count - 1) % 3 + 1
			_play_melee_animation("attack_light_%d" % combo_index)
			attack_speed = 1.2
		
		"heavy":
			combo_count = 0  # Heavy resets combo
			_play_melee_animation("attack_heavy")
			damage_multiplier = 2.0
			knockback_multiplier = 3.0
			attack_speed = 0.8
			
			if fully_charged:
				damage_multiplier = 3.0
				knockback_multiplier = 5.0
				_play_melee_sound("heavy_charged")
			else:
				_play_melee_sound("heavy")
	
	_play_melee_sound("swing")
	
	# Wait for hit timing (based on animation)
	var hit_delay = 0.15 / attack_speed
	await get_tree().create_timer(hit_delay).timeout
	
	# Gather hit data
	var base_damage = current_melee.attributes.get("damage", 25.0)
	var base_knockback = current_melee.attributes.get("knockback", 5.0)
	
	var hit_data = {
		"damage": base_damage * damage_multiplier,
		"knockback": base_knockback * knockback_multiplier,
		"type": current_melee.attributes.get("damage_type", "slash"),
		"attack_type": attack_type,
		"combo": combo_count if attack_type == "light" else 0
	}
	
	#_detect_and_apply_hits(hit_data)
	
	# Attack recovery time
	var recovery_time = current_melee.attributes.get("attack_speed", 0.5)
	await get_tree().create_timer(recovery_time / attack_speed).timeout
	
	is_attacking = false
	can_attack = true
	last_attack_time = Time.get_ticks_msec() / 1000.0


#func _detect_and_apply_hits(hit_data: Dictionary):
	#"""Detect what we hit and apply damage"""
	#var hit_something = false
	#var hits: Array = []
	#
	## Cone-based detection
	#var forward = -camera.global_transform.basis.z
	#var start_pos = camera.global_position
	#
	## Check multiple raycasts in a cone
	#var num_rays = 5
	#var angle_step = melee_angle / num_rays
	#
	#for i in range(num_rays):
		#var angle = -melee_angle / 2 + i * angle_step
		#var ray_dir = forward.rotated(camera.global_transform.basis.y, deg_to_rad(angle))
		#
		## Perform raycast
		#var space_state = get_world_3d().direct_space_state
		#var query = PhysicsRayQueryParameters3D.create(
			#start_pos,
			#start_pos + ray_dir * melee_range
		#)
		#query.collision_mask = hit_layers
		#query.exclude = [player]  # Don't hit self
		#
		#var result = space_state.intersect_ray(query)
		#
		#if result:
			#var hit_object = result.collider
			#
			## Avoid duplicate hits
			#if hit_object in hits:
				#continue
			#
			#hits.append(hit_object)
			#hit_something = true
			#
			## Apply damage
			#if hit_object.has_method("take_damage"):
				#var actual_damage = hit_data.damage
				#
				## Check if target is blocking
				#if hit_object.has_method("is_blocking") and hit_object.is_blocking():
					#actual_damage *= (1.0 - block_damage_reduction)
					#_play_melee_sound("block_impact")
				#
				#hit_object.take_damage(actual_damage, hit_data.type)
			#
			## Apply knockback
			#if hit_object.has_method("apply_knockback"):
				#var knockback_dir = (hit_object.global_position - start_pos).normalized()
				#hit_object.apply_knockback(knockback_dir * hit_data.knockback)
			#
			## Spawn hit effect
			#_spawn_hit_effect(result.position, result.normal)
			#
			#_play_melee_sound("hit_" + hit_data.type)
	#
	#if not hit_something:
		#_play_melee_sound("whoosh")
#

func _spawn_hit_effect(position: Vector3, normal: Vector3):
	"""Spawn visual hit effect"""
	if not hit_particles:
		return
	
	var effect = hit_particles.instantiate()
	get_tree().get_root().add_child(effect)
	effect.global_position = position
	effect.look_at(position + normal, Vector3.UP)
	
	if effect.has_method("emit"):
		effect.emit()


func _update_heavy_charge(delta: float):
	"""Update heavy attack charge"""
	var charge_time = (Time.get_ticks_msec() / 1000.0) - heavy_charge_start
	
	# Visual feedback for charge level
	if charge_time >= heavy_attack_charge_time:
		# Play "fully charged" effect
		pass


func _play_melee_animation(anim_name: String):
	"""Play melee animation"""
	if animation_manager and animation_manager.has_method("playAnimation"):
		animation_manager.playAnimation(anim_name, 1.0, false)


func _play_melee_sound(sound_name: String):
	"""Play melee sound effect"""
	# Implement with your audio system
	pass


func _load_melee_resource(melee_id: int) -> MeleeWeaponResource:
	"""Load melee weapon resource"""
	# Implement loading from database
	return null


func take_damage_while_blocking(damage: float) -> float:
	"""Process incoming damage while blocking"""
	if not is_blocking:
		return damage
	
	var blocked_damage = damage * block_damage_reduction
	_play_melee_sound("block_impact")
	
	# Stamina cost for blocking?
	if player.has_method("consume_stamina"):
		player.consume_stamina(damage * 0.5)
	
	return blocked_damage


func get_attack_state() -> Dictionary:
	"""Get current attack state for external systems"""
	return {
		"is_attacking": is_attacking,
		"is_blocking": is_blocking,
		"is_charging": is_charging_heavy,
		"combo_count": combo_count,
		"can_attack": can_attack
	}
