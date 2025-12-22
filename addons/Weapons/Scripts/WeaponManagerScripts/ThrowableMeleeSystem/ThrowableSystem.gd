# ThrowableSystem.gd - Handles throwable items (grenades, knives, etc.)

extends Node
class_name ThrowableSystem

var weapon_manager: WeaponManager
var inventory_component: InventoryComponent
var player: CharacterBody3D
var camera: Camera3D

# Throwable settings
@export_group("Throw Settings")
@export var throw_force: float = 15.0
@export var throw_upward_angle: float = 15.0  # Degrees
@export var max_throw_distance: float = 30.0
@export var trajectory_preview: bool = true
@export var trajectory_points: int = 20

# Cooking grenade
var is_cooking_grenade: bool = false
var cook_start_time: float = 0.0
var current_throwable: InventoryItem = null
var current_throwable_slot: int = -1

# Preview
var trajectory_line: Line3D
var throw_preview_enabled: bool = false

# Throwable data
var throwable_instances: Dictionary = {}  # weapon_id -> PackedScene


func _ready():
	if trajectory_preview:
		_create_trajectory_line()


func _process(delta: float):
	if is_cooking_grenade:
		_update_cooking(delta)
	
	if throw_preview_enabled:
		_update_trajectory_preview()


func _create_trajectory_line():
	"""Create visual trajectory preview"""
	trajectory_line = Line3D.new()
	add_child(trajectory_line)
	trajectory_line.visible = false
	trajectory_line.width = 2.0
	# Set material for line visibility


func is_item_throwable(item: InventoryItem) -> bool:
	"""Check if item can be thrown"""
	if not item:
		return false
	
	return item.type == "throwable" or item.attributes.get("is_throwable", false)


func get_throw_type(item: InventoryItem) -> String:
	"""Get throwable type: grenade, knife, molotov, etc."""
	return item.attributes.get("throw_type", "generic")


func start_throw(item: InventoryItem, hotbar_slot: int):
	"""Begin throw sequence"""
	if not is_item_throwable(item):
		print("Item is not throwable!")
		return
	
	current_throwable = item
	current_throwable_slot = hotbar_slot
	
	var throw_type = get_throw_type(item)
	
	match throw_type:
		"grenade":
			_start_grenade_cook()
		"knife", "throwable_weapon":
			_instant_throw()
		"molotov", "flashbang":
			_start_grenade_cook()  # Similar to grenade
		_:
			_instant_throw()


func _start_grenade_cook():
	"""Start cooking a grenade"""
	is_cooking_grenade = true
	cook_start_time = Time.get_ticks_msec() / 1000.0
	throw_preview_enabled = true
	
	# Play pull pin animation/sound
	_play_throwable_animation("pull_pin")
	_play_throwable_sound("pin_pull")
	
	print("Cooking grenade... Release to throw!")


func _update_cooking(delta: float):
	"""Update grenade cook timer"""
	var cook_time = (Time.get_ticks_msec() / 1000.0) - cook_start_time
	var max_cook_time = current_throwable.attributes.get("max_cook_time", 3.0)
	
	# Auto-throw if cooked too long
	if cook_time >= max_cook_time:
		print("Grenade cooked too long - auto throwing!")
		execute_throw()


func release_throw():
	"""Release throw button - execute throw"""
	if is_cooking_grenade:
		execute_throw()


func cancel_throw():
	"""Cancel throw (re-equip previous weapon?)"""
	is_cooking_grenade = false
	throw_preview_enabled = false
	current_throwable = null
	current_throwable_slot = -1
	
	if trajectory_line:
		trajectory_line.visible = false


func execute_throw():
	"""Actually throw the item"""
	if not current_throwable:
		return
	
	is_cooking_grenade = false
	throw_preview_enabled = false
	
	# Calculate throw direction
	var throw_dir = _calculate_throw_direction()
	
	# Spawn throwable instance
	var throwable_instance = _spawn_throwable_instance()
	
	if throwable_instance:
		# Position and launch
		throwable_instance.global_position = camera.global_position + camera.global_transform.basis.z * -0.5
		
		if throwable_instance is RigidBody3D:
			throwable_instance.linear_velocity = throw_dir * throw_force
			throwable_instance.angular_velocity = Vector3(
				randf_range(-5, 5),
				randf_range(-5, 5),
				randf_range(-5, 5)
			)
		
		# Pass cook time if grenade
		if throwable_instance.has_method("set_cook_time"):
			var cook_time = (Time.get_ticks_msec() / 1000.0) - cook_start_time
			throwable_instance.set_cook_time(cook_time)
		
		# Pass damage/stats
		if throwable_instance.has_method("set_stats"):
			throwable_instance.set_stats({
				"damage": current_throwable.attributes.get("damage", 100),
				"blast_radius": current_throwable.attributes.get("blast_radius", 5.0),
				"fuse_time": current_throwable.attributes.get("fuse_time", 3.0)
			})
	
	# Play throw animation
	_play_throwable_animation("throw")
	_play_throwable_sound("throw")
	
	# Consume item from inventory
	current_throwable.stack_count -= 1
	if current_throwable.stack_count <= 0:
		inventory_component.remove_item(current_throwable)
		inventory_component.hotbar[current_throwable_slot] = null
	
	# Hide trajectory
	if trajectory_line:
		trajectory_line.visible = false
	
	# Clear state
	current_throwable = null
	current_throwable_slot = -1
	
	print("Throwable launched!")


func _calculate_throw_direction() -> Vector3:
	"""Calculate throw direction with arc"""
	var forward = -camera.global_transform.basis.z
	
	# Apply upward angle
	var angle_rad = deg_to_rad(throw_upward_angle)
	var throw_dir = forward.rotated(camera.global_transform.basis.x, -angle_rad)
	
	return throw_dir.normalized()


func _spawn_throwable_instance() -> Node3D:
	"""Create throwable instance in world"""
	if not current_throwable:
		return null
	
	var scene_path = current_throwable.attributes.get("throwable_scene", "")
	if scene_path == "":
		print("No throwable_scene defined in item!")
		return null
	
	var throwable_scene = load(scene_path)
	if not throwable_scene:
		print("Failed to load throwable scene: %s" % scene_path)
		return null
	
	var instance = throwable_scene.instantiate()
	get_tree().get_root().add_child(instance)
	
	return instance


func _update_trajectory_preview():
	"""Show predicted throw arc"""
	if not trajectory_line or not throw_preview_enabled:
		return
	
	trajectory_line.visible = true
	trajectory_line.clear_points()
	
	# Calculate trajectory points
	var start_pos = camera.global_position
	var throw_dir = _calculate_throw_direction()
	var velocity = throw_dir * throw_force
	
	var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
	var time_step = 0.1
	
	for i in range(trajectory_points):
		var time = i * time_step
		var pos = start_pos + velocity * time
		pos.y -= 0.5 * gravity * time * time
		
		trajectory_line.add_point(pos)
		
		# Stop at max distance
		if start_pos.distance_to(pos) > max_throw_distance:
			break


func _play_throwable_animation(anim_name: String):
	"""Play throwable animation"""
	# Implement with your animation system
	pass


func _play_throwable_sound(sound_name: String):
	"""Play throwable sound"""
	# Implement with your audio system
	pass


# Helper class for trajectory line (if not using built-in)
class Line3D extends MeshInstance3D:
	var points: PackedVector3Array = []
	var width: float = 2.0
	
	func _ready():
		mesh = ImmediateMesh.new()
	
	func clear_points():
		points.clear()
	
	func add_point(point: Vector3):
		points.append(point)
		_update_mesh()
	
	func _update_mesh():
		if points.size() < 2:
			return
		
		var immediate_mesh = mesh as ImmediateMesh
		immediate_mesh.clear_surfaces()
		immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		
		for point in points:
			immediate_mesh.surface_add_vertex(point)
		
		immediate_mesh.surface_end()
		
func _instant_throw():
	pass
