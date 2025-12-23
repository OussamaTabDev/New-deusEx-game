# GrenadeProjectile.gd - Spawned grenade with physics and explosion
extends RigidBody3D
class_name GrenadeProjectile

var throwable_data: ThrowableResource
var cooked_time: float = 0.0
var fuse_timer: float = 0.0
var has_exploded: bool = false

# Audio
var beep_audio: AudioStreamPlayer3D
var beep_interval: float = 1.0
var beep_timer: float = 0.0

# Visual
var model: MeshInstance3D
var trail: GPUParticles3D

func _ready():
	# Setup collision
	contact_monitor = true
	max_contacts_reported = 10
	body_entered.connect(_on_body_entered)
	
	# Setup audio
	beep_audio = AudioStreamPlayer3D.new()
	add_child(beep_audio)

func initialize(data: ThrowableResource, velocity: Vector3, cook_time: float):
	"""Initialize grenade with data"""
	throwable_data = data
	cooked_time = cook_time
	fuse_timer = max(0.0, data.fuse_time - cook_time)
	
	linear_velocity = velocity
	mass = data.projectile_mass
	
	# Setup beeping
	if data.beep_sound:
		beep_audio.stream = data.beep_sound
	
	# Add trail effect
	if data.trail_effect:
		trail = data.trail_effect.instantiate()
		add_child(trail)
		trail.emitting = true
	
	print("Grenade fuse: %.1fs" % fuse_timer)

func _process(delta: float):
	if has_exploded:
		return
	
	# Update fuse
	fuse_timer -= delta
	
	# Beeping gets faster
	var fuse_percent = 1.0 - (fuse_timer / throwable_data.fuse_time)
	beep_interval = lerp(1.0, 0.05, fuse_percent)
	
	beep_timer += delta
	if beep_timer >= beep_interval and throwable_data.beep_sound:
		beep_audio.play()
		beep_timer = 0.0
	
	# Check explosion
	if fuse_timer <= 0:
		explode()

func _on_body_entered(body: Node):
	"""Handle collision"""
	if has_exploded:
		return
	
	# Play bounce sound
	if throwable_data.bounce_sound and linear_velocity.length() > 2.0:
		play_sound(throwable_data.bounce_sound, 0.8)
	
	# Impact explosion for molotovs
	if throwable_data.throwable_type == ThrowableResource.ThrowableType.MOLOTOV:
		explode()

func explode():
	"""Trigger explosion"""
	if has_exploded:
		return
	
	has_exploded = true
	
	print("BOOM!")
	
	# Spawn explosion effect
	if throwable_data.explosion_effect:
		var effect = throwable_data.explosion_effect.instantiate()
		get_tree().root.add_child(effect)
		effect.global_position = global_position
	
	# Play explosion sound
	if throwable_data.explosion_sound:
		play_sound(throwable_data.explosion_sound, 1.0)
	
	# Deal damage
	apply_explosion_damage()
	
	# Apply physics force
	if throwable_data.applies_force:
		apply_explosion_force()
	
	# Special effects
	apply_special_effects()
	
	# Destroy grenade
	queue_free()

func apply_explosion_damage():
	"""Apply damage to nearby entities"""
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = throwable_data.explosion_radius
	query.shape = sphere
	query.transform.origin = global_position
	query.collision_mask = 4 + 2  # Enemies + Players
	
	var results = space_state.intersect_shape(query)
	
	for result in results:
		var target = result.collider
		var distance = global_position.distance_to(target.global_position)
		
		# Calculate damage with falloff
		var damage = throwable_data.explosion_damage
		if throwable_data.damage_falloff:
			var falloff = 1.0 - (distance / throwable_data.explosion_radius)
			falloff = clamp(falloff, 0.1, 1.0)
			damage *= falloff
		
		# Apply damage
		if target.has_method("take_damage"):
			target.take_damage(damage, self)
			print("Explosion hit %s for %.1f damage" % [target.name, damage])

func apply_explosion_force():
	"""Apply physics force to nearby objects"""
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = throwable_data.explosion_radius
	query.shape = sphere
	query.transform.origin = global_position
	query.collision_mask = 7  # All physics layers
	
	var results = space_state.intersect_shape(query)
	
	for result in results:
		var target = result.collider
		if target is RigidBody3D:
			var distance = global_position.distance_to(target.global_position)
			var direction = (target.global_position - global_position).normalized()
			
			# Calculate force with falloff
			var force = throwable_data.explosion_force
			if throwable_data.force_falloff:
				var falloff = 1.0 - (distance / throwable_data.explosion_radius)
				force *= falloff
			
			target.apply_central_impulse(direction * force)

func apply_special_effects():
	"""Apply special effects (fire, flash, smoke)"""
	
	# Fire effect (molotov)
	if throwable_data.applies_fire:
		spawn_fire_area()
	
	# Flash effect (flashbang)
	if throwable_data.applies_flash:
		apply_flash_effect()
	
	# Smoke effect
	if throwable_data.applies_smoke:
		spawn_smoke_area()

func spawn_fire_area():
	"""Create fire damage area"""
	# Create area for fire damage over time
	var fire_area = Area3D.new()
	get_tree().root.add_child(fire_area)
	fire_area.global_position = global_position
	
	var collision = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = throwable_data.explosion_radius * 0.8
	collision.shape = sphere
	fire_area.add_child(collision)
	
	fire_area.collision_mask = 4 + 2  # Enemies + Players
	
	# Fire particles
	var fire_particles = GPUParticles3D.new()
	fire_area.add_child(fire_particles)
	fire_particles.emitting = true
	fire_particles.amount = 50
	fire_particles.lifetime = 2.0
	
	# Damage over time
	var timer = 0.0
	var duration = throwable_data.fire_duration
	
	while timer < duration:
		await get_tree().create_timer(0.5).timeout
		timer += 0.5
		
		if not is_instance_valid(fire_area):
			break
		
		# Apply fire damage to overlapping bodies
		for body in fire_area.get_overlapping_bodies():
			if body.has_method("take_damage"):
				body.take_damage(throwable_data.fire_damage_per_second * 0.5, self)
	
	fire_area.queue_free()

func apply_flash_effect():
	"""Apply flashbang effect to nearby players"""
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = throwable_data.flash_radius
	query.shape = sphere
	query.transform.origin = global_position
	query.collision_mask = 2  # Player layer
	
	var results = space_state.intersect_shape(query)
	
	for result in results:
		var target = result.collider
		if target.has_method("apply_flash"):
			target.apply_flash(throwable_data.flash_duration)
			print("Flashed %s!" % target.name)

func spawn_smoke_area():
	"""Create smoke area"""
	var smoke_area = Area3D.new()
	get_tree().root.add_child(smoke_area)
	smoke_area.global_position = global_position
	
	var collision = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = throwable_data.smoke_radius
	collision.shape = sphere
	smoke_area.add_child(collision)
	
	# Smoke particles
	var smoke_particles = GPUParticles3D.new()
	smoke_area.add_child(smoke_particles)
	smoke_particles.emitting = true
	smoke_particles.amount = 100
	smoke_particles.lifetime = 3.0
	
	# Remove after duration
	await get_tree().create_timer(throwable_data.smoke_duration).timeout
	smoke_area.queue_free()

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
