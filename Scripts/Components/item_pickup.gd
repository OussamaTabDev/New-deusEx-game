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
# @expport var can_be_grabbed: bool = true ## Can also be grabbed as RigidBody
@export var destroy_on_pickup: bool = true
@export var pickup_sound: AudioStream

@export_subgroup("Pickup Animation")
@export var collect_duration: float = 0.25 ## Time it takes to fly to player
@export var collect_offset: Vector3 = Vector3(0, 0.3, 0) ## Vertical lift before pickup

@export_group("Visual")
@export var highlight_on_look: bool = true
@export var highlight_material: Material

@export_group("Cyber Scanner Params")
@export var is_scannable: bool = true
@export var scanner_color: Color = Color(0, 1, 1, 1)
@export var initial_outline_pixel_size: float = 2.0
@export var final_outline_pixel_size: float = 6.0
@export var initial_fill_transparency: float = 0.3
@export var final_fill_transparency: float = 1.0
@export var initial_pixelize_power: float = 0.0
@export var final_pixelize_power: float = 8.0

# Internal
var original_materials: Array[Material] = []
var is_highlighted: bool = false
var item
var _stack_count = stack_count

func _ready() -> void:
	if "stack_count" in get_parent().get_parent():
		_stack_count = get_parent().get_parent().stack_count if get_parent().get_parent().stack_count > 0 else stack_count
	item = get_parent() as Node3D

	if not item:
		push_error("PickupableItem must be a child of the scene root node (StaticBody/RigidBody).")
		return

	if auto_load_from_id and item_id != "" and not item_data:
		item_data = ItemDatabase.create_item(item_id, _stack_count)
		if not item_data:
			push_error("PickupableItem: Failed to load item '%s' from database" % item_id)
	print(item_data.display_name)
	if item_data and _stack_count > 1:
		item_data.stack_count = _stack_count
	
	_validate_collision_setup()
	
	if highlight_on_look:
		_store_materials()

func _validate_collision_setup() -> void:
	var has_collision = false
	for child in get_children():
		if child is CollisionShape3D:
			var parent_body = child.get_parent()
			if parent_body is StaticBody3D or parent_body is RigidBody3D:
				if not (parent_body.collision_layer & 256):
					push_warning("PickupableItem '%s': Collision layer 8 not enabled!" % name)
				else:
					has_collision = true
				break
	if not has_collision:
		push_warning("PickupableItem '%s': No collision shape found on layer 8!" % name)

func _store_materials() -> void:
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
func on_picked_up(source) -> void:
	_disable_collision()
	set_highlighted(false)
	set_scanning_layer(false)  # Ensure layer is reset

	if pickup_sound:
		_play_pickup_sound()

	if source and item:
		_animate_to_player(source.global_position)
	else:
		picked_up.emit(source)
		if destroy_on_pickup:
			item.queue_free()
		else:
			item.visible = false

func _animate_to_player(player_position: Vector3) -> void:
	# 1. Disable Physics immediately
	if item is RigidBody3D:
		var rb := item as RigidBody3D
		rb.freeze = true # Better than setting velocity to zero to prevent physics fighting
		rb.collision_layer = 0 # Prevent colliding with player while flying

	var target_position = player_position + collect_offset
	
	# Randomize rotation axis for that "Zero-G Tumble" look
	var random_rot_axis = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
	var tumble_force = 12.0 # How fast it spins

	var tween = create_tween()
	tween.set_parallel(true)

	# 2. MOVEMENT: The "Magnetic Snap"
	# TRANS_BACK with EASE_IN makes it pull back slightly (anticipation) 
	# and then rocket towards the player.
	tween.tween_property(item, "global_position", target_position, collect_duration)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_IN)

	# 3. ROTATION: Chaos
	# Rotate on all 3 axes, not just Y. Accelerate the spin as it gets closer.
	tween.tween_property(item, "rotation", item.rotation + (random_rot_axis * tumble_force), collect_duration)\
		.set_trans(Tween.TRANS_EXPO)\
		.set_ease(Tween.EASE_IN)

	# 4. SCALE: The "Stretch and Implode"
	# We use a sub-sequence for scaling specifically
	# Step A: Pop slightly bigger (Anticipation)
	tween.tween_property(item, "scale", item.scale * 1.4, collect_duration * 0.2)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Step B: Shrink to almost nothing (Implosion)
	# Note: We delay this so it happens right as it hits the player
	tween.tween_property(item, "scale", Vector3.ZERO, collect_duration * 0.3)\
		.set_delay(collect_duration * 0.7)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

	# 5. MATERIAL FLASH (Optional but very "Dishonored")
	# Instead of fading transparency (which looks soft), we flash the emission 
	# or albedo to white to simulate energy absorption.
	for mesh in _get_all_mesh_instances(item):
		var mat = mesh.get_active_material(0)
		if mat: # Ensure material exists
			var unique_mat = mat.duplicate()
			mesh.set_surface_override_material(0, unique_mat)
			
			# Flash to bright white/energy color
			# If using StandardMaterial3D, we can boost emission or albedo
			if unique_mat is StandardMaterial3D:
				unique_mat.emission_enabled = true
				unique_mat.emission = Color(1.5, 1.5, 1.5) # Bright white HDR
				unique_mat.emission_energy_multiplier = 0.0
				
				# Ramp up energy as it gets closer
				tween.tween_property(unique_mat, "emission_energy_multiplier", 5.0, collect_duration)\
					.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)

	tween.chain().tween_callback(_cleanup_after_collection)

func _cleanup_after_collection() -> void:
	picked_up.emit(get_tree().get_first_node_in_group("player"))
	if destroy_on_pickup and is_instance_valid(item):
		item.queue_free()
	elif is_instance_valid(item):
		item.visible = false

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
	for child in item.get_children():
		if child is CollisionShape3D:
			child.disabled = true

func set_highlighted(enabled: bool) -> void:
	if not highlight_on_look or not highlight_material:
		return
	if enabled == is_highlighted:
		return
	is_highlighted = enabled
	for mesh in _get_all_mesh_instances(item):
		mesh.material_overlay = highlight_material if enabled else null

# === SCANNER INTEGRATION ===
func set_scanning_layer(enabled: bool) -> void:
	if not is_scannable:
		return

	for mesh in _get_all_mesh_instances(item):
		if mesh is MeshInstance3D:
			if enabled:
				if not mesh.has_meta("original_layers"):
					mesh.set_meta("original_layers", mesh.layers)
				
				# Enable layer 1 + layer 2 together
				mesh.layers = (1 << 0) | (1 << 1)   # = 3

			else:
				if mesh.has_meta("original_layers"):
					mesh.layers = mesh.get_meta("original_layers")
				else:
					mesh.layers = (1 << 0)  # default layer 1 only (value = 1)


func apply_to_scanner(scanner: CyberScanner) -> void:
	scanner.set_param(scanner_color, "color")
	scanner.set_param(initial_outline_pixel_size, "initial_outline_pixel_size")
	scanner.set_param(final_outline_pixel_size, "final_outline_pixel_size")
	scanner.set_param(initial_fill_transparency, "initial_fill_transparency")
	scanner.set_param(final_fill_transparency, "final_fill_transparency")
	scanner.set_param(initial_pixelize_power, "initial_pixelize_power")
	scanner.set_param(final_pixelize_power, "final_pixelize_power")
	
## Public API
func get_item_data() -> InventoryItem:
	return item_data

func set_item_data(new_data: InventoryItem) -> void:
	item_data = new_data
	item_id = new_data.id if new_data else ""

static func create_pickup(item: InventoryItem, position: Vector3, scene_root: Node) -> PickupableItem:
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
	var pickup_component = instance as PickupableItem
	if not pickup_component:
		for child in instance.get_children():
			if child is PickupableItem:
				pickup_component = child
				break
	if pickup_component:
		pickup_component.set_item_data(item)
		pickup_component.stack_count = item.stack_count
	return pickup_component
