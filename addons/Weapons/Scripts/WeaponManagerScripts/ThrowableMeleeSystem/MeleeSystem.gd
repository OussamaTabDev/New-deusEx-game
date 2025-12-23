# MeleeSystem.gd - Handles all melee combat mechanics
extends Node
class_name MeleeSystem

var weapon_manager: WeaponManager
var player: CharacterBody3D
var camera: Camera3D
var stamina_system: Node  # Your stamina component
var animation_player: AnimationPlayer
var hit_particles: PackedScene

# Current melee weapon
var current_melee: MeleeWeaponResource = null
var current_melee_model: Node3D = null

# Combat state
var is_attacking: bool = false
var is_blocking: bool = false
var is_charging: bool = false
var charge_time: float = 0.0
var attack_cooldown: float = 0.0
var block_start_time: float = 0.0

# Combo tracking
var combo_count: int = 0
var combo_timer: float = 0.0
var can_combo: bool = false

# Hit detection
var hit_enemies: Array = []  # Track hit enemies this attack

# Fists fallback (unarmed)
var fist_damage: float = 15.0
var fist_range: float = 1.5
var fist_speed: float = 1.2

func _ready():
	hit_particles = preload("res://materials/Effects/Blood/blood_particales_1.tscn")  # Adjust path


func _process(delta: float):
	# Update combo timer
	if combo_timer > 0:
		combo_timer -= delta
		if combo_timer <= 0:
			reset_combo()
	
	# Update attack cooldown
	if attack_cooldown > 0:
		attack_cooldown -= delta
	
	# Charge attack
	if is_charging:
		charge_time += delta
		if current_melee and charge_time >= current_melee.max_charge_time:
			release_charged_attack()

func set_current_melee(melee: MeleeWeaponResource, model: Node3D):
	"""Set the active melee weapon"""
	current_melee = melee
	current_melee_model = model
	reset_combo()

func clear_melee():
	"""Clear current melee weapon"""
	current_melee = null
	current_melee_model = null
	is_attacking = false
	is_blocking = false
	is_charging = false
	reset_combo()

func light_attack():
	"""Perform light attack"""
	if not can_attack():
		return
	
	var damage = fist_damage
	var range_val = fist_range
	var speed = fist_speed
	var stamina_cost = 5.0
	var anim = "punch"
	
	if current_melee:
		damage = current_melee.light_damage
		range_val = current_melee.attack_range
		speed = current_melee.light_speed
		stamina_cost = current_melee.light_stamina_cost
		anim = current_melee.light_attack_anim
		
		# Apply combo multiplier
		if combo_count > 0:
			damage = current_melee.get_combo_damage(damage)
	
	# Check stamina
	if not consume_stamina(stamina_cost):
		print("Not enough stamina!")
		return
	
	# Start attack
	is_attacking = true
	hit_enemies.clear()
	
	# Play animation
	play_attack_animation(anim, speed)
	
	# Play sound
	if current_melee and current_melee.swing_sound:
		play_sound(current_melee.swing_sound)
	
	# Schedule hit detection at animation peak
	var hit_delay = 0.2 / speed
	await weapon_manager.get_tree().create_timer(hit_delay).timeout
	
	perform_hit_detection(damage, range_val, current_melee.knockback_force if current_melee else 3.0)
	
	# Wait for attack to finish
	var attack_duration = (current_melee.light_attack_duration if current_melee else 0.4) / speed
	await weapon_manager.get_tree().create_timer(attack_duration - hit_delay).timeout
	
	is_attacking = false
	
	# Update combo
	if current_melee:
		increment_combo()
		can_combo = true
		await weapon_manager.get_tree().create_timer(0.2).timeout
		can_combo = false

func heavy_attack():
	"""Perform heavy attack"""
	if not can_attack():
		return
	
	if not current_melee:
		light_attack()  # Fists don't have heavy attack
		return
	
	var damage = current_melee.heavy_damage
	var range_val = current_melee.attack_range * 1.2
	var speed = current_melee.heavy_speed
	var stamina_cost = current_melee.heavy_stamina_cost
	
	# Check stamina
	if not consume_stamina(stamina_cost):
		print("Not enough stamina!")
		return
	
	# Start attack
	is_attacking = true
	hit_enemies.clear()
	
	# Play animation
	play_attack_animation(current_melee.heavy_attack_anim, speed)
	
	# Play sound
	if current_melee.swing_sound:
		play_sound(current_melee.swing_sound)
	
	# Hit detection at peak
	var hit_delay = 0.3 / speed
	await weapon_manager.get_tree().create_timer(hit_delay).timeout
	
	var knockback = current_melee.knockback_force * 1.5
	if combo_count >= current_melee.max_combo_hits:
		knockback *= current_melee.final_combo_knockback_multiplier
	
	perform_hit_detection(damage, range_val, knockback)
	
	# Wait for finish
	var attack_duration = current_melee.heavy_attack_duration / speed
	await weapon_manager.get_tree().create_timer(attack_duration - hit_delay).timeout
	
	is_attacking = false
	reset_combo()  # Heavy attack ends combo

func start_charge():
	"""Begin charging heavy attack"""
	if not current_melee or not current_melee.can_charge:
		return
	
	if is_attacking or is_blocking or is_charging:
		return
	
	is_charging = true
	charge_time = 0.0
	print("Charging attack...")

func release_charged_attack():
	"""Release charged heavy attack"""
	if not is_charging:
		return
	
	is_charging = false
	
	if charge_time < current_melee.min_charge_time:
		print("Not charged enough!")
		return
	
	# Calculate charge multiplier
	var charge_percent = clamp(charge_time / current_melee.max_charge_time, 0.0, 1.0)
	var damage_mult = lerp(1.0, current_melee.charge_damage_multiplier, charge_percent)
	var knockback_mult = lerp(1.0, current_melee.charge_knockback_multiplier, charge_percent)
	
	var damage = current_melee.heavy_damage * damage_mult
	var range_val = current_melee.attack_range * 1.3
	var knockback = current_melee.knockback_force * knockback_mult
	
	# Check stamina
	if not consume_stamina(current_melee.heavy_stamina_cost * 1.5):
		print("Not enough stamina!")
		charge_time = 0.0
		return
	
	is_attacking = true
	hit_enemies.clear()
	
	play_attack_animation(current_melee.heavy_attack_anim, current_melee.heavy_speed * 1.2)
	
	if current_melee.swing_sound:
		play_sound(current_melee.swing_sound, 1.2)
	
	await weapon_manager.get_tree().create_timer(0.3).timeout
	
	perform_hit_detection(damage, range_val, knockback)
	
	await weapon_manager.get_tree().create_timer(0.5).timeout
	
	is_attacking = false
	charge_time = 0.0
	reset_combo()

func start_block():
	"""Begin blocking"""
	if not current_melee or not current_melee.can_block:
		return
	
	if is_attacking:
		return
	
	is_blocking = true
	block_start_time = Time.get_ticks_msec() / 1000.0
	
	if current_melee.block_anim:
		play_attack_animation(current_melee.block_anim, 1.0)
	
	print("Blocking!")

func stop_block():
	"""Stop blocking"""
	is_blocking = false

func perform_hit_detection(damage: float, range_val: float, knockback: float):
	"""Detect and damage enemies in attack cone"""
	var origin = camera.global_position
	var forward = -camera.global_transform.basis.z
	
	var cone_angle = current_melee.attack_cone_angle if current_melee else 90.0
	
	# Get all enemies in range
	var space_state = weapon_manager.get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = range_val
	query.shape = sphere
	query.transform.origin = origin + forward * range_val * 0.5
	query.collision_mask = 4  # Enemy layer
	
	var results = space_state.intersect_shape(query)
	
	for result in results:
		var enemy = result.collider
		
		# Skip if already hit this attack
		if enemy in hit_enemies:
			continue
		
		# Check if in attack cone
		var to_enemy = (enemy.global_position - origin).normalized()
		var angle = rad_to_deg(forward.angle_to(to_enemy))
		
		if angle > cone_angle / 2.0:
			continue
		
		# Check backstab
		var final_damage = damage
		if current_melee and current_melee.can_backstab:
			if is_backstab(enemy, forward):
				final_damage *= current_melee.backstab_damage_multiplier
				print("BACKSTAB!")
		
		# Check execute
		if current_melee and current_melee.can_execute:
			if can_execute_enemy(enemy):
				final_damage = 999999.0  # Instant kill
				print("EXECUTED!")
		
		# Apply damage
		apply_damage_to_enemy(enemy, final_damage, knockback, forward)
		
		hit_enemies.append(enemy)
		
		# Visual feedback
		spawn_hit_effect(enemy.global_position)
		
		# Play hit sound
		if current_melee and current_melee.hit_sound:
			play_sound(current_melee.hit_sound)

func apply_damage_to_enemy(enemy: Node, damage: float, knockback: float, direction: Vector3):
	"""Apply damage and knockback to enemy"""
	if enemy.has_method("take_damage"):
		enemy.take_damage(damage, player)
	
	if enemy.has_method("apply_knockback"):
		enemy.apply_knockback(direction * knockback)
	elif enemy is RigidBody3D:
		enemy.apply_central_impulse(direction * knockback)

func is_backstab(enemy: Node, attack_direction: Vector3) -> bool:
	"""Check if attack is from behind"""
	if not enemy is Node3D:
		return false
	
	var enemy_forward = -enemy.global_transform.basis.z
	var angle = rad_to_deg(enemy_forward.angle_to(attack_direction))
	
	return angle < 60.0  # Within 60 degrees of enemy's back

func can_execute_enemy(enemy: Node) -> bool:
	"""Check if enemy can be executed"""
	if not enemy.has_method("get_health_percent"):
		return false
	
	return enemy.get_health_percent() <= current_melee.execute_health_threshold

func handle_block_damage(incoming_damage: float) -> float:
	"""Calculate blocked damage"""
	if not is_blocking or not current_melee:
		return incoming_damage
	
	var current_time = Time.get_ticks_msec() / 1000.0
	var block_time = current_time - block_start_time
	
	# Perfect block timing
	if block_time <= current_melee.perfect_block_window:
		print("PERFECT BLOCK!")
		if current_melee.perfect_block_sound:
			play_sound(current_melee.perfect_block_sound)
		return incoming_damage * (1.0 - current_melee.perfect_block_reduction)
	
	# Normal block
	if current_melee.block_sound:
		play_sound(current_melee.block_sound)
	
	# Drain stamina
	var stamina_drain = incoming_damage * 0.5
	consume_stamina(stamina_drain)
	
	return incoming_damage * (1.0 - current_melee.block_damage_reduction)

func can_attack() -> bool:
	"""Check if can perform attack"""
	if is_attacking or is_blocking:
		return false
	
	if attack_cooldown > 0:
		return false
	
	if weapon_manager.state_machine and weapon_manager.state_machine.current_state:
		if not weapon_manager.state_machine.current_state.can_shoot:
			return false
	
	return true

func reset_combo():
	"""Reset combo counter"""
	combo_count = 0
	combo_timer = 0.0

func increment_combo():
	"""Increment combo counter"""
	combo_count += 1
	if current_melee:
		combo_timer = current_melee.combo_timeout
	else:
		combo_timer = 1.0
	
	print("Combo: %d" % combo_count)

func consume_stamina(amount: float) -> bool:
	"""Try to consume stamina"""
	if not stamina_system or not stamina_system.has_method("consume"):
		return true
	
	return stamina_system.consume(amount)

func play_attack_animation(anim_name: String, speed: float):
	"""Play attack animation"""
	if animation_player and animation_player.has_animation(anim_name):
		animation_player.play(anim_name, -1, speed)

func play_sound(sound: AudioStream, pitch: float = 1.0):
	"""Play 3D sound at player position"""
	var audio = AudioStreamPlayer3D.new()
	weapon_manager.add_child(audio)
	audio.stream = sound
	audio.pitch_scale = pitch * randf_range(0.95, 1.05)
	audio.play()
	await audio.finished
	audio.queue_free()

func spawn_hit_effect(position: Vector3):
	"""Spawn hit particles"""
	if not hit_particles:
		return
	
	var effect = hit_particles.instantiate()
	weapon_manager.get_tree().root.add_child(effect)
	effect.global_position = position
	effect.emitting = true
