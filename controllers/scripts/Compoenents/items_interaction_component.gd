class_name PickupInteractionComponent
extends Node3D

## Component for detecting and picking up items using ShapeCast3D
## Handles both inventory pickups and container interactions
## Works alongside RigidBodyInteractionComponent for grab/pickup priority

signal item_detected(item: PickupableItem)
signal item_lost()
signal container_detected(container: ContainerComponent)
signal pickup_failed(reason: String)

# --- Configuration ---
@export_group("References")
@export var shape_cast: ShapeCast3D ## ShapeCast for detecting pickups (collision layer 8)
@export var inventory_handler: InventoryHandlerComponenent
@export var camera_controller: Node

@export_group("Settings")
@export var pickup_action: String = "interact" ## Quick press
@export var hold_threshold: float = 0.3 ## Hold time before triggering grab instead
@export var max_pickup_distance: float = 3.0
@export var show_pickup_prompt: bool = true

@export_group("UI")
@export var pickup_label: Label ## Optional: UI label showing item name

# --- Internal State ---
var current_target: Node = null ## Current detected item or container
var is_item: bool = false
var is_container: bool = false
var input_hold_time: float = 0.0
var is_holding_input: bool = false

func _ready() -> void:
	# Validate references
	if not shape_cast:
		push_error("PickupInteractionComponent: ShapeCast3D not assigned!")
		return
	
	# Auto-find inventory handler if not assigned
	if not inventory_handler:
		inventory_handler = get_node_or_null("../InventoryHandlerComponenent")
	
	if not inventory_handler:
		push_warning("PickupInteractionComponent: InventoryHandler not found!")
	
	# Configure ShapeCast
	# shape_cast.enabled = true
	# shape_cast.collision_mask = 256 ## Layer 8 (2^8 = 256)
	# shape_cast.max_results = 10

func _physics_process(delta: float) -> void:
	_update_detection()
	_handle_input(delta)

func _update_detection() -> void:
	if not shape_cast or not shape_cast.is_colliding():
		_clear_target()
		return
	
	var closest_target: Node = null
	var closest_distance: float = INF
	
	# Check all collision results
	for i in range(shape_cast.get_collision_count()):
		var collider = shape_cast.get_collider(i)
		if not collider:
			continue
		# Skip if too far
		var distance = global_position.distance_to(collider.global_position)
		if distance > max_pickup_distance:
			continue
		
		# Check for PickupableItem or ContainerComponent
		var pickup_item = _find_pickupable(collider)
		var container = _find_container(collider)
		
		if pickup_item and distance < closest_distance:
			closest_target = pickup_item
			closest_distance = distance
		elif container and distance < closest_distance:
			closest_target = container
			closest_distance = distance
	
	# Update current target
	if closest_target != current_target:
		_set_target(closest_target)

func _find_pickupable(node: Node) -> PickupableItem:
	"""Recursively search for PickupableItem component"""
	if node is PickupableItem:
		return node
	
	for child in node.get_children():
		if child is PickupableItem:
			return child
	
	# Check parent (for cases where collision shape is child of pickup)
	if node.get_parent() is PickupableItem:
		return node.get_parent()
	
	return null

func _find_container(node: Node) -> ContainerComponent:
	"""Recursively search for ContainerComponent"""
	if node is ContainerComponent:
		return node
	
	for child in node.get_children():
		if child is ContainerComponent:
			return child
	
	if node.get_parent() is ContainerComponent:
		return node.get_parent()
	
	return null

func _set_target(target: Node) -> void:
	_clear_target()
	
	current_target = target
	
	if target is PickupableItem:
		is_item = true
		item_detected.emit(target)
		_update_ui(target.item_data.display_name)
	elif target is ContainerComponent:
		is_container = true
		container_detected.emit(target)
		_update_ui(target.container_name)

func _clear_target() -> void:
	if current_target:
		item_lost.emit()
	
	current_target = null
	is_item = false
	is_container = false
	_update_ui("")

func _update_ui(text: String) -> void:
	if pickup_label and show_pickup_prompt:
		if text != "":
			pickup_label.text = "[E] Pick up %s" % text if is_item else "[E] Open %s" % text
			pickup_label.visible = true
		else:
			pickup_label.visible = false

func _handle_input(delta: float) -> void:
	# Track hold time for grab vs pickup priority
	if Input.is_action_pressed(pickup_action):
		if not is_holding_input:
			is_holding_input = true
			input_hold_time = 0.0
		else:
			input_hold_time += delta
	
	# Quick press = pickup (if hold threshold not reached)
	if Input.is_action_just_released(pickup_action):
		if input_hold_time < hold_threshold and current_target:
			_attempt_interaction()
		
		is_holding_input = false
		input_hold_time = 0.0

func _attempt_interaction() -> void:
	if not current_target:
		return
	
	if is_item:
		_pickup_item(current_target as PickupableItem)
	elif is_container:
		_open_container(current_target as ContainerComponent)

func _pickup_item(pickup: PickupableItem) -> void:
	if not inventory_handler:
		pickup_failed.emit("No inventory handler")
		return
	
	var item = pickup.item_data
	if not item:
		pickup_failed.emit("Invalid item data")
		return
	
	# Check if item can be grabbed (has RigidBody component)
	if pickup.can_be_grabbed:
		# Priority system: Quick press = pickup, Hold = grab (handled by RigidBodyInteractionComponent)
		pass
	
	# Attempt to add to inventory
	if inventory_handler.pickup_item(item):
		# Success - destroy pickup from world
		pickup.on_picked_up()
		_clear_target()
	else:
		pickup_failed.emit("Inventory full")

func _open_container(container: ContainerComponent) -> void:
	if not inventory_handler:
		pickup_failed.emit("No inventory handler")
		return
	
	# Get player reference
	var player = _get_player()
	if not player:
		pickup_failed.emit("Player not found")
		return
	
	inventory_handler.interact_with_container(container)

func _get_player() -> Player:
	"""Find player in scene tree"""
	var node = self
	while node:
		if node is Player:
			return node
		node = node.get_parent()
	return null

## Public API
func force_pickup(item: InventoryItem) -> bool:
	"""Directly add item to inventory without world pickup"""
	if inventory_handler:
		return inventory_handler.pickup_item(item)
	return false

func get_current_target() -> Node:
	return current_target

func is_looking_at_pickup() -> bool:
	return is_item

func is_looking_at_container() -> bool:
	return is_container
