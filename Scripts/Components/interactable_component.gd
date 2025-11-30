class_name InteractableComponent
extends Node3D

## Base component for any interactable object (items, containers, etc.)

enum InteractionType {
	PICKUP,      # Item pickups
	CONTAINER,   # Chests, lockers, etc.
	CUSTOM       # Custom interaction (doors, switches, etc.)
}

signal interacted(player: Player)
signal looked_at()
signal looked_away()

@export var interaction_type: InteractionType = InteractionType.PICKUP
@export var interaction_prompt: String = "Pick Up"
@export var custom_prompt: String = ""  # Override prompt if needed
@export var enabled: bool = true
@export var one_time_use: bool = false  # Disable after first interaction
@export var highlight_on_look: bool = true
@export var collision_layer: int = 3  # Layer 3 for interactables (0b100)

var area: Area3D
var collision_shape: CollisionShape3D
var is_being_looked_at: bool = false
var has_been_used: bool = false

func _ready():
	_setup_area()
	_setup_collision()

func _setup_area():
	area = Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 0
	area.set_collision_layer_value(collision_layer, true)
	area.monitoring = false
	area.monitorable = true
	add_child(area)

func _setup_collision():
	collision_shape = CollisionShape3D.new()
	
	# Auto-detect shape from parent node
	var parent = get_parent()
	
	if parent is MeshInstance3D:
		var mesh = parent.mesh
		if mesh:
			# Create shape from mesh
			collision_shape.shape = mesh.create_trimesh_shape()
	elif parent is StaticBody3D or parent is RigidBody3D or parent is CharacterBody3D:
		# Try to find existing collision shape
		for child in parent.get_children():
			if child is CollisionShape3D:
				collision_shape.shape = child.shape.duplicate()
				break
	
	# Fallback to sphere if no shape found
	if not collision_shape.shape:
		var sphere = SphereShape3D.new()
		sphere.radius = 0.5
		collision_shape.shape = sphere
	
	area.add_child(collision_shape)

func can_interact() -> bool:
	if not enabled:
		return false
	
	if one_time_use and has_been_used:
		return false
	
	return true

func interact(player: Player):
	if not can_interact():
		return
	
	interacted.emit(player)
	
	if one_time_use:
		has_been_used = true
		enabled = false
	
	# Handle different interaction types
	match interaction_type:
		InteractionType.PICKUP:
			_handle_pickup()
		InteractionType.CONTAINER:
			_handle_container()
		InteractionType.CUSTOM:
			pass  # Handled by signal

func _handle_pickup():
	var parent = get_parent()
	
	# Remove the pickup from the world
	if parent:
		parent.queue_free()

func _handle_container():
	# Container opening is handled by InteractionComponent
	pass

func on_look_at():
	if is_being_looked_at:
		return
	
	is_being_looked_at = true
	looked_at.emit()
	
	if highlight_on_look:
		_apply_highlight(true)

func on_look_away():
	if not is_being_looked_at:
		return
	
	is_being_looked_at = false
	looked_away.emit()
	
	if highlight_on_look:
		_apply_highlight(false)

func _apply_highlight(active: bool):
	var parent = get_parent()
	
	if parent is MeshInstance3D:
		if active:
			# Add highlight material overlay
			var material = StandardMaterial3D.new()
			material.albedo_color = Color(1, 1, 0, 0.3)
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			parent.material_overlay = material
		else:
			parent.material_overlay = null

func get_prompt() -> String:
	if custom_prompt != "":
		return custom_prompt
	
	match interaction_type:
		InteractionType.PICKUP:
			return "Pick Up"
		InteractionType.CONTAINER:
			return "Open"
		InteractionType.CUSTOM:
			return "Interact"
	
	return interaction_prompt

func set_enabled(value: bool):
	enabled = value

func set_custom_shape(shape: Shape3D):
	if collision_shape:
		collision_shape.shape = shape