# GrenadeProjectile.gd - Spawned grenade instance

extends RigidBody3D
class_name GrenadeProjectile

@export_group("Grenade Stats")
@export var damage: float = 100.0
@export var blast_radius: float = 5.0
@export var fuse_time: float = 3.0
@export var explosion_force: float = 20.0

@export_group("Effects")
@export var explosion_scene: PackedScene
@export var beep_sound: AudioStream
@export var explosion_sound: AudioStream

# State
var cook_time: float = 0.0
var time_alive: float = 0.0
var has_exploded: bool = false

# Beeping
var beep_interval: float = 0.5
var last_beep_time: float = 0.0

# Visual
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var audio_player: AudioStreamPlayer3D = $AudioPlayer
@onready var beep_timer: Timer = $BeepTimer


func _ready():
	contact_monitor = true
	max_contacts_reported = 5
	
	# Start beeping
	if beep_timer:
		beep_timer.wait_time = beep_interval
		beep_timer.timeout.connect(_on_beep)
		beep_timer.start()
	
	# Schedule explosion
	var remaining_time = fuse_time - cook_time
	if remaining_time <= 0:
		explode()
	else:
		await get_tree().create_timer(remaining_time).timeout
		explode()


func _process(delta: float):
	time_alive += delta
	
	# Speed up beeping as explosion nears
	var remaining = fuse_time - cook_time - time_alive
	if remaining < 1.0:
		beep_interval = 0.1
	elif remaining < 2.0:
		beep_interval = 0.3


func set_cook_time(time: float):
	"""Set how long grenade was cooked before throw"""
	cook_time = time


func set_stats(stats: Dictionary):
	"""Set grenade stats"""
	if stats.has("damage"):
		damage = stats.damage
	if stats.has("blast_radius"):
		blast_radius = stats.blast_radius
	if stats.has("fuse_time"):
		fuse_time = stats.fuse_time


func explode():
	"""Explode and deal damage"""
	if has_exploded:
		return
	
	has_exploded = true
	
	# Spawn explosion effect
	if explosion_scene:
		var explosion = explosion_scene.instantiate()
		get_tree().get_root().add_child(explosion)
		explosion.global_position = global_position
	
	# Play explosion sound
	if explosion_sound and audio_player:
		audio_player.stream = explosion_sound
		audio_player.play()
	
	# Deal damage in radius
	_deal_explosion_damage()
	
	# Hide mesh
	if mesh_instance:
		mesh_instance.visible = false
	
	# Disable physics
	freeze = true
	
	# Wait for sound to finish then delete
	await get_tree().create_timer(2.0).timeout
	queue_free()


func _deal_explosion_damage():
	"""Damage all entities in blast radius"""
	var space_state = get_world_3d().direct_space_state
	
	# Get all overlapping bodies
	var query = PhysicsShapeQueryParameters3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = blast_radius
	query.shape = sphere
	query.transform = Transform3D(Basis(), global_position)
	query.collision_mask = 1  # Adjust for your layers
	
	var results = space_state.intersect_shape(query)
	
	for result in results:
		var body = result.collider
		
		# Skip self
		if body == self:
			continue
		
		# Calculate damage falloff
		var distance = global_position.distance_to(body.global_position)
		var damage_falloff = 1.0 - (distance / blast_radius)
		damage_falloff = clamp(damage_falloff, 0.0, 1.0)
		
		var final_damage = damage * damage_falloff
		
		# Apply damage
		if body.has_method("take_damage"):
			body.take_damage(final_damage, "explosive")
		
		# Apply explosion force
		if body is RigidBody3D:
			var direction = (body.global_position - global_position).normalized()
			var force = direction * explosion_force * damage_falloff
			body.apply_central_impulse(force)


func _on_beep():
	"""Play beep sound"""
	if beep_sound and audio_player:
		audio_player.stream = beep_sound
		audio_player.play()


func _on_body_entered(body: Node):
	"""Handle collision"""
	# Grenades can bounce
	pass
