# KnifeProjectile.gd - Thrown knife instance

extends RigidBody3D
class_name KnifeProjectile

@export_group("Knife Stats")
@export var damage: float = 50.0
@export var stick_on_hit: bool = true
@export var despawn_time: float = 10.0

@export_group("Effects")
@export var trail_effect: PackedScene
@export var impact_sound: AudioStream
@export var whoosh_sound: AudioStream

# State
var has_hit: bool = false
var stuck_in: Node3D = null
var time_alive: float = 0.0

# Visual
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var audio_player: AudioStreamPlayer3D = $AudioPlayer

# Trail
var trail_instance: Node3D


func _ready():
	contact_monitor = true
	max_contacts_reported = 1
	body_entered.connect(_on_body_entered)
	
	# Spawn trail effect
	if trail_effect:
		trail_instance = trail_effect.instantiate()
		add_child(trail_instance)
	
	# Play whoosh sound
	if whoosh_sound and audio_player:
		audio_player.stream = whoosh_sound
		audio_player.play()
	
	# Align knife to flight direction
	_align_to_velocity()


func _process(delta: float):
	time_alive += delta
	
	# Despawn after time
	if time_alive >= despawn_time:
		queue_free()
	
	# Keep aligned to velocity while flying
	if not has_hit:
		_align_to_velocity()


func _align_to_velocity():
	"""Point knife in direction of travel"""
	if linear_velocity.length() > 0.1:
		look_at(global_position + linear_velocity.normalized(), Vector3.UP)


func _on_body_entered(body: Node):
	"""Handle knife hitting something"""
	if has_hit:
		return
	
	has_hit = true
	
	# Stop trail
	if trail_instance:
		trail_instance.queue_free()
	
	# Play impact sound
	if impact_sound and audio_player:
		audio_player.stream = impact_sound
		audio_player.play()
	
	# Check what we hit
	var is_enemy = body.has_method("take_damage")
	
	if is_enemy:
		# Damage enemy
		body.take_damage(damage, "pierce")
		
		# Stick to enemy
		if stick_on_hit and body is Node3D:
			_stick_to(body)
		else:
			queue_free()
	else:
		# Stick to world geometry
		if stick_on_hit:
			_stick_to(body)
		else:
			queue_free()


func _stick_to(body: Node3D):
	"""Make knife stick into surface"""
	stuck_in = body
	
	# Disable physics
	freeze = true
	collision_shape.disabled = true
	
	# Reparent to hit object
	var old_transform = global_transform
	get_parent().remove_child(self)
	body.add_child(self)
	global_transform = old_transform
	
	# Remove after delay
	await get_tree().create_timer(despawn_time - time_alive).timeout
	queue_free()


func set_stats(stats: Dictionary):
	"""Set knife stats"""
	if stats.has("damage"):
		damage = stats.damage
