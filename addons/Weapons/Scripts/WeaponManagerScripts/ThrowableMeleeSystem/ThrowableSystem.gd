# ThrowableSystem.gd - Handles throwable items with trajectory preview
extends Node
class_name ThrowableSystem

@onready var weapon_manager: WeaponManager = $".."
var player: CharacterBody3D
var camera: Camera3D
var inventory_component: InventoryComponent

# Current throwable
var current_throwable: ThrowableResource = null
var current_throwable_model: Node3D = null

# Cooking state
var is_cooking: bool = false
var cook_timer: float = 0.0
var can_throw: bool = true

# Trajectory preview
var trajectory_line: MeshInstance3D
var trajectory_points: Array[Vector3] = []
var show_preview: bool = false

# Audio
var beep_audio: AudioStreamPlayer3D
var beep_interval: float = 1.0
var beep_timer: float = 0.0

func _ready():
	setup_trajectory_preview()
	setup_beep_audio()

func _process(delta: float):
	if is_cooking:
		update_cooking(delta)
		if show_preview:
			update_trajectory_preview()

func setup_trajectory_preview():
	"""Create visual trajectory line"""
	trajectory_line = MeshInstance3D.new()
	var immediate_mesh = ImmediateMesh.new()
	trajectory_line.mesh = immediate_mesh
	
	# Material for trajectory line
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1, 1, 0, 0.5)  # Yellow with transparency
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trajectory_line.material_override = material
	
	weapon_manager.add_child(trajectory_line)
	trajectory_line.visible = false

func setup_beep_audio():
	"""Setup cooking beep audio"""
	beep_audio = AudioStreamPlayer3D.new()
	weapon_manager.add_child(beep_audio)

func set_current_throwable(throwable: ThrowableResource, model: Node3D):
	"""Set active throwable"""
	current_throwable = throwable
	current_throwable_model = model
	reset_cooking()

func clear_throwable():
	"""Clear current throwable"""
	current_throwable = null
	current_throwable_model = null
	is_cooking = false
	hide_trajectory()

func start_cooking():
	"""Begin cooking grenade/throwable"""
	if not current_throwable or not can_throw:
		return
	
	if not current_throwable.can_cook:
		# Instant throw for non-cookable items
		throw_projectile()
		return
	
	is_cooking = true
	cook_timer = 0.0
	show_preview = true
	beep_timer = 0.0
	
	print("Cooking %s..." % current_throwable.throwable_name)
	
	# Start beeping
	if current_throwable.beep_sound:
		beep_audio.stream = current_throwable.beep_sound

func update_cooking(delta: float):
	"""Update cooking timer"""
	cook_timer += delta
	
	# Update beep speed (faster as it gets closer to explosion)
	if current_throwable.beep_sound:
		var cook_percent = cook_timer / current_throwable.fuse_time
		beep_interval = lerp(1.0, 0.1, cook_percent)
		
		beep_timer += delta
		if beep_timer >= beep_interval:
			beep_audio.play()
			beep_timer = 0.0
	
	# Auto-throw when fully cooked
	if current_throwable.auto_throw_at_max and cook_timer >= current_throwable.fuse_time:
		print("Auto-throwing!")
		throw_projectile()

func release_throw():
	"""Release to throw"""
	if not is_cooking:
		return
	
	if cook_timer < current_throwable.min_cook_time:
		print("Not cooked enough!")
		return
	
	throw_projectile()

func throw_projectile():
	"""Spawn and throw the projectile"""
	if not current_throwable or not current_throwable.projectile_scene:
		print("No projectile scene!")
		return
	
	# Calculate throw vector
	var throw_origin = camera.global_position
	var throw_direction = -camera.global_transform.basis.z
	
	# Apply arc (throw upward angle)
	throw_direction.y += current_throwable.throw_arc
	throw_direction = throw_direction.normalized()
	
	# Spawn projectile
	var projectile = current_throwable.projectile_scene.instantiate()
	weapon_manager.get_tree().root.add_child(projectile)
	projectile.global_position = throw_origin + throw_direction * 1.0
	
	# Initialize projectile
	if projectile.has_method("initialize"):
		projectile.initialize(
			current_throwable,
			throw_direction * current_throwable.throw_force,
			cook_timer
		)
	elif projectile is RigidBody3D:
		projectile.linear_velocity = throw_direction * current_throwable.throw_force
	
	# Play throw sound
	if current_throwable.throw_sound:
		play_sound(current_throwable.throw_sound)
	
	# Remove from inventory
	consume_throwable()
	
	# Reset state
	reset_cooking()
	hide_trajectory()
	
	print("Threw %s!" % current_throwable.throwable_name)
	
	# Check for next throwable of same type
	check_for_next_throwable()

func cancel_cooking():
	"""Cancel cooking/throwing"""
	if is_cooking:
		print("Cooking cancelled")
		reset_cooking()
		hide_trajectory()

func reset_cooking():
	"""Reset cooking state"""
	is_cooking = false
	cook_timer = 0.0
	beep_timer = 0.0
	show_preview = false
	if beep_audio:
		beep_audio.stop()

func update_trajectory_preview():
	"""Calculate and display throw trajectory"""
	if not current_throwable or not current_throwable.show_trajectory:
		return
	
	trajectory_points.clear()
	
	var start_pos = camera.global_position
	var direction = -camera.global_transform.basis.z
	direction.y += current_throwable.throw_arc
	direction = direction.normalized()
	
	var velocity = direction * current_throwable.throw_force
	var gravity = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	var position = start_pos
	
	var time_step = current_throwable.trajectory_point_spacing
	var max_points = current_throwable.trajectory_point_count
	
	for i in range(max_points):
		trajectory_points.append(position)
		
		# Update position with physics
		velocity.y -= gravity * time_step
		velocity *= (1.0 - current_throwable.air_resistance * time_step)
		position += velocity * time_step
		
		# Check for ground collision
		var space_state = weapon_manager.get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(
			trajectory_points[i] if i > 0 else start_pos,
			position
		)
		query.collision_mask = 1  # World layer
		
		var result = space_state.intersect_ray(query)
		if result:
			trajectory_points.append(result.position)
			break
	
	draw_trajectory()

func draw_trajectory():
	"""Draw the trajectory line"""
	if trajectory_points.size() < 2:
		trajectory_line.visible = false
		return
	
	trajectory_line.visible = true
	
	var immediate_mesh = trajectory_line.mesh as ImmediateMesh
	immediate_mesh.clear_surfaces()
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	
	for point in trajectory_points:
		immediate_mesh.surface_add_vertex(trajectory_line.to_local(point))
	
	immediate_mesh.surface_end()

func hide_trajectory():
	"""Hide trajectory preview"""
	show_preview = false
	if trajectory_line:
		trajectory_line.visible = false

func consume_throwable():
	"""Remove one throwable from inventory"""
	if not inventory_component:
		return
	
	# Find throwable in inventory
	for item in inventory_component.get_all_items():
		if item.type == "throwable" and item.attributes.get("throwable_id") == current_throwable.throwable_id:
			item.stack_count -= 1
			if item.stack_count <= 0:
				inventory_component.remove_item(item)
			return

func check_for_next_throwable():
	"""Auto-equip next throwable of same type"""
	if not inventory_component:
		return
	
	var throwable_id = current_throwable.throwable_id
	
	# Check hotbar for same throwable
	for i in range(inventory_component.hotbar_slots):
		var item = inventory_component.hotbar[i]
		if item and item.type == "throwable" and item.attributes.get("throwable_id") == throwable_id:
			if item.stack_count > 0:
				# Still have some, keep equipped
				return
	
	# No more of this type, unequip
	weapon_manager.switcher.unequip_current_weapon()

func get_cook_percentage() -> float:
	"""Get cooking progress 0-1"""
	if not current_throwable or not is_cooking:
		return 0.0
	return clamp(cook_timer / current_throwable.fuse_time, 0.0, 1.0)

func get_remaining_fuse() -> float:
	"""Get remaining fuse time"""
	if not current_throwable or not is_cooking:
		return 0.0
	return max(0.0, current_throwable.fuse_time - cook_timer)

func play_sound(sound: AudioStream, pitch: float = 1.0):
	"""Play 3D sound"""
	var audio = AudioStreamPlayer3D.new()
	weapon_manager.add_child(audio)
	audio.stream = sound
	audio.pitch_scale = pitch * randf_range(0.95, 1.05)
	audio.play()
	await audio.finished
	audio.queue_free()
