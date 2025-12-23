# KnifeProjectile.gd - Thrown knife/axe with sticking behavior
extends RigidBody3D
class_name KnifeProjectile

var throwable_data: ThrowableResource
var has_stuck: bool = false
var stuck_to: Node3D = null
var stuck_offset: Vector3 = Vector3.ZERO
var despawn_timer: float = 10.0

# Visual
var model: Node3D
var trail: GPUParticles3D

func _ready():
	contact_monitor = true
	max_contacts_reported = 5
	body_entered.connect(_on_body_entered)

func initialize(data: ThrowableResource, velocity: Vector3, _cook_time: float):
	"""Initialize knife/axe"""
	throwable_data = data
	linear_velocity = velocity
	mass = data.projectile_mass
	
	# Add trail effect
	if data.trail_effect:
		trail = data.trail_effect.instantiate()
		add_child(trail)
		trail.emitting = true
	
	# Rotate to face flight direction
	look_at(global_position + velocity.normalized(), Vector3.UP)

func _process(delta: float):
	if has_stuck:
		# Follow stuck object
		if is_instance_valid(stuck_to):
			global_position = stuck_to.global_position + stuck_to.global_transform.basis * stuck_offset
		
		# Despawn timer
		despawn_timer -= delta
		if despawn_timer <= 0:
			queue_free()
	else:
		# Rotate to face flight direction while flying
		if linear_velocity.length() > 0.1:
			var forward = linear_velocity.normalized()
			look_at(global_position + forward, Vector3.UP)

func _on_body_entered(body: Node):
	"""Handle collision"""
	if has_stuck:
		return
	
	# Check if can stick
	if not throwable_data.can_stick:
		# Bounce and deal impact damage
		deal_impact_damage(body)
		return
	
	# Stick to surface/enemy
	stick_to(body)

func stick_to(body: Node):
	"""Stick knife to surface or enemy"""
	has_stuck = true
	stuck_to = body
	
	# Stop physics
	freeze = true
	if trail:
		trail.emitting = false
	
	# Calculate local offset
	if body is Node3D:
		stuck_offset = body.global_transform.basis.inverse() * (global_position - body.global_position)
	
	# Deal stuck damage to enemies
	if body.has_method("take_damage"):
		body.take_damage(throwable_data.stuck_damage, self)
		print("Knife stuck in %s for %.1f damage!" % [body.name, throwable_data.stuck_damage])
		
		# Continuous damage over time (bleeding)
		apply_bleed_damage(body)
	else:
		print("Knife stuck in surface")
	
	# Play impact sound
	if throwable_data.bounce_sound:
		play_sound(throwable_data.bounce_sound, 1.2)
	
	# Spawn impact effect
	if throwable_data.impact_effect:
		var effect = throwable_data.impact_effect.instantiate()
		get_tree().root.add_child(effect)
		effect.global_position = global_position

func deal_impact_damage(body: Node):
	"""Deal damage on impact (non-sticking)"""
	if body.has_method("take_damage"):
		body.take_damage(throwable_data.direct_hit_damage, self)
		print("Hit %s for %.1f damage!" % [body.name, throwable_data.direct_hit_damage])
	
	# Spawn effect
	if throwable_data.impact_effect:
		var effect = throwable_data.impact_effect.instantiate()
		get_tree().root.add_child(effect)
		effect.global_position = global_position
	
	# Play sound
	if throwable_data.bounce_sound:
		play_sound(throwable_data.bounce_sound)

func apply_bleed_damage(enemy: Node):
	"""Apply damage over time while stuck"""
	var bleed_duration = 5.0
	var bleed_damage = throwable_data.stuck_damage * 0.2  # 20% of stuck damage per tick
	var tick_interval = 1.0
	var elapsed = 0.0
	
	while elapsed < bleed_duration and is_instance_valid(enemy):
		await get_tree().create_timer(tick_interval).timeout
		elapsed += tick_interval
		
		if is_instance_valid(enemy) and enemy.has_method("take_damage"):
			enemy.take_damage(bleed_damage, self)

func play_sound(sound: AudioStream, pitch: float = 1.0):
	"""Play 3D sound"""
	var audio = AudioStreamPlayer3D.new()
	get_tree().root.add_child(audio)
	audio.global_position = global_position
	audio.stream = sound
	audio.pitch_scale = pitch * randf_range(0.95, 1.05)
	audio.play()
	await audio.finished
	audio.queue_free()
