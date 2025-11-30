class_name PickupableItem
extends Node3D

## Component attached to items in the world that can be picked up
## Place on parent of StaticBody3D/RigidBody3D with collision shape on layer 8

signal picked_up(by_player: Player)
signal grabbed(by_player: Player)

@export_group("Item Data")
@export var item_id: String = "" ## ID from ItemDatabase
@export var item_data: InventoryItem ## Pre-configured item data
@export var auto_load_from_id: bool = true
@export var stack_count: int = 1 ## How many of this item to pick up

@export_group("Pickup Settings")
@export var can_be_grabbed: bool = true ## Can also be grabbed as RigidBody
@export var destroy_on_pickup: bool = true
@export var pickup_sound: AudioStream

@export_group("Visual")
@export var highlight_on_look: bool = true
@export var highlight_material: Material

# Internal
var original_materials: Array[Material] = []
var is_highlighted: bool = false
var item 
var _stack_count = stack_count
func _ready() -> void:
	item = get_parent()
	# Auto-load item data from database
	if auto_load_from_id and item_id != "" and not item_data:
		item_data = ItemDatabase.create_item(item_id, _stack_count)
		if not item_data:
			push_error("PickupableItem: Failed to load item '%s' from database" % item_id)
	
	# If item_data exists but stack_count was set manually, update it
	if item_data and _stack_count > 1:
		item_data.stack_count = _stack_count
	
	# Validate collision layer
	_validate_collision_setup()
	
	# Store original materials for highlighting
	if highlight_on_look:
		_store_materials()

func _validate_collision_setup() -> void:
	"""Ensure proper collision layer setup for pickup detection"""
	var has_collision = false
	
	# Check for CollisionShape3D children
	for child in get_children():
		if child is CollisionShape3D:
			var parent_body = child.get_parent()
			if parent_body is StaticBody3D or parent_body is RigidBody3D:
				# Verify layer 8 is enabled
				if not (parent_body.collision_layer & 256): # 256 = 2^8
					push_warning("PickupableItem '%s': Collision layer 8 not enabled! Pickup detection won't work." % name)
				else:
					has_collision = true
				break
	
	if not has_collision:
		push_warning("PickupableItem '%s': No collision shape found on layer 8!" % name)

func _store_materials() -> void:
	"""Store original materials for all MeshInstance3D children"""
	for child in _get_all_mesh_instances(item):
		if child is MeshInstance3D:
			for i in child.get_surface_override_material_count():
				var mat = child.get_surface_override_material(i)
				if mat:
					original_materials.append(mat)

func _get_all_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	for child in node.get_children():
		if child is MeshInstance3D:
			meshes.append(child)
		meshes.append_array(_get_all_mesh_instances(child))
	return meshes

## Called when item is picked up into inventory
func on_picked_up() -> void:
	picked_up.emit(get_tree().get_first_node_in_group("player"))
	
	if pickup_sound:
		_play_pickup_sound()
	
	if destroy_on_pickup:
		item.queue_free()
	else:
		# Hide and disable collision instead
		item.visible = false
		item._disable_collision()

## Called when item is grabbed (RigidBody interaction)
func on_grabbed() -> void:
	grabbed.emit(get_tree().get_first_node_in_group("player"))

func _play_pickup_sound() -> void:
	var audio_player = AudioStreamPlayer3D.new()
	get_tree().root.add_child(audio_player)
	audio_player.stream = pickup_sound
	audio_player.global_position = global_position
	audio_player.play()
	audio_player.finished.connect(audio_player.queue_free)

func _disable_collision() -> void:
	for child in get_children():
		if child is CollisionShape3D:
			child.disabled = true

## Highlight system (called by PickupInteractionComponent)
func set_highlighted(enabled: bool) -> void:
	if not highlight_on_look or not highlight_material:
		return
	
	if enabled == is_highlighted:
		return
	
	is_highlighted = enabled
	
	for mesh in _get_all_mesh_instances(item):
		if enabled:
			# Apply highlight material
			for i in mesh.get_surface_override_material_count():
				mesh.set_surface_override_material(i, highlight_material)
		else:
			# Restore original materials
			for i in mesh.get_surface_override_material_count():
				if i < original_materials.size():
					mesh.set_surface_override_material(i, original_materials[i])

## Public API
func get_item_data() -> InventoryItem:
	return item_data

func set_item_data(new_data: InventoryItem) -> void:
	item_data = new_data
	item_id = new_data.id if new_data else ""

## Helper to create pickup from item data
static func create_pickup(item: InventoryItem, position: Vector3, scene_root: Node) -> PickupableItem:
	"""Factory method to spawn a pickup in the world from inventory item data"""
	if not item or item.scene_path == "":
		push_error("PickupableItem.create_pickup: Invalid item or missing scene_path")
		return null
	
	var scene = load(item.scene_path)
	if not scene:
		push_error("PickupableItem.create_pickup: Failed to load scene '%s'" % item.scene_path)
		return null
	
	var instance = scene.instantiate()
	scene_root.add_child(instance)
	instance.global_position = position
	
	# Find PickupableItem component
	var pickup_component = instance as PickupableItem
	if not pickup_component:
		# Check children
		for child in instance.get_children():
			if child is PickupableItem:
				pickup_component = child
				break
	
	if pickup_component:
		pickup_component.set_item_data(item)
		pickup_component.stack_count = item.stack_count
	
	return pickup_component
