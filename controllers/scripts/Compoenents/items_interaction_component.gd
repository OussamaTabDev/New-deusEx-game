class_name UnifiedInteractionComponent
extends Node3D

## Main interaction system that detects targets and delegates to specialized handlers
## Handles detection, input routing, and UI updates

# ============================================================================
# SIGNALS
# ============================================================================
signal item_detected(item: PickupableItem)
signal item_lost()
signal container_detected(container: ContainerComponent)
signal object_grabbed(object: RigidBody3D)
signal object_dropped(object: RigidBody3D)
signal object_thrown(object: RigidBody3D, velocity: Vector3)
signal interactable_detected(interactable: InteractableComponent)
signal interaction_failed(reason: String)
signal pickup_failed(reason: String)

# ============================================================================
# REFERENCES
# ============================================================================
@export_group("References")
@export var interaction_raycast: RayCast3D
@export var inventory_handler: InventoryHandlerComponenent
@export var camera_controller: Node
@export var hold_position: Node3D
@export var cyber_scanner: CyberScanner
@export var player: CharacterBody3D

@export_group("Handlers")
@export var loot_handler: LootInteractionHandler
@export var grab_handler: GrabInteractionHandler
@export var small_grab_handler: SmallGrabInteractionHandler
@export var interactable_handler: InteractableInteractionHandler

@export_group("UI")
@export var interact_control: Control
@export var primary_action_label: Label
@export var secondary_action_label: Label
@export var item_name_label: Label
@export var key_prompt_label: Label

# ============================================================================
# SETTINGS
# ============================================================================
@export_group("Detection Settings")
@export var interact_action: String = "interact"
@export var throw_action: String = "throw"
@export var throw_action_alt: String = "throw_alt"
@export var max_interaction_distance: float = 3.0
@export var hold_threshold: float = 0.3
@export var is_scan_enabled: bool = false
@export var show_interaction_prompt: bool = true

@export_group("Grab Settings")
@export var max_pickup_mass: float = 50.0
@export var throw_force: float = 50.0
@export var break_distance: float = 2.0
@export var hold_power: float = 20.0
@export var rotation_power: float = 20.0

# ============================================================================
# INTERNAL STATE
# ============================================================================
var current_target: Node = null
var target_type: TargetType = TargetType.NONE
var input_hold_time: float = 0.0
var is_holding_input: bool = false

enum TargetType {
	NONE,
	LOOT_ONLY,
	GRAB_ONLY,
	LOOT_AND_GRAB,
	INTERACTABLE,
	CONTAINER
}

# ============================================================================
# INITIALIZATION
# ============================================================================
func _ready() -> void:
	_validate_references()
	_setup_defaults()
	_validate_handlers()

func _validate_references() -> void:
	if not interaction_raycast:
		push_error("UnifiedInteractionComponent: RayCast3D not assigned!")
		return
	
	if not inventory_handler:
		inventory_handler = get_node_or_null("../InventoryHandlerComponenent")
	
	if not inventory_handler:
		push_warning("UnifiedInteractionComponent: InventoryHandler not found!")
	
	if not player:
		var parent = get_parent()
		while parent:
			if parent is CharacterBody3D:
				player = parent
				break
			parent = parent.get_parent()
	
	if not player:
		push_warning("UnifiedInteractionComponent: Could not find CharacterBody3D.")

func _setup_defaults() -> void:
	if not hold_position:
		var default_hold = Node3D.new()
		default_hold.name = "DefaultHoldPosition"
		if get_parent().name.to_lower().contains("camera"):
			get_parent().add_child(default_hold)
		else:
			add_child(default_hold)
		default_hold.position = Vector3(0.5, -0.5, -2.0)
		hold_position = default_hold

func _validate_handlers() -> void:
	if not loot_handler:
		push_error("UnifiedInteractionComponent: LootInteractionHandler not assigned!")
	else:
		loot_handler.initialize(self)
	
	if not grab_handler:
		push_error("UnifiedInteractionComponent: GrabInteractionHandler not assigned!")
	else:
		grab_handler.initialize(self)
		grab_handler.object_grabbed.connect(_on_object_grabbed)
		grab_handler.object_dropped.connect(_on_object_dropped)
		grab_handler.object_thrown.connect(_on_object_thrown)
	
	if not small_grab_handler:
		push_error("UnifiedInteractionComponent: SmallGrabInteractionHandler not assigned!")
	else:
		small_grab_handler.initialize(self)
		small_grab_handler.small_object_grabbed.connect(_on_small_object_grabbed)
		small_grab_handler.small_object_dropped.connect(_on_small_object_dropped)
		small_grab_handler.small_object_thrown.connect(_on_small_object_thrown)
	
	if not interactable_handler:
		push_error("UnifiedInteractionComponent: InteractableInteractionHandler not assigned!")
	else:
		interactable_handler.initialize(self)

# ============================================================================
# MAIN LOOP
# ============================================================================
func _physics_process(delta: float) -> void:
	_update_detection()
	_handle_input(delta)
	grab_handler.update_physics(delta)
	small_grab_handler.update_physics(delta)

# ============================================================================
# DETECTION SYSTEM
# ============================================================================
func _update_detection() -> void:
	if not interaction_raycast or not interaction_raycast.is_colliding():
		_clear_target()
		return
	
	var collider = interaction_raycast.get_collider()
	if not collider:
		_clear_target()
		return
	
	var distance = global_position.distance_to(collider.global_position)
	if distance > max_interaction_distance:
		_clear_target()
		return
	
	var new_target: Node = null
	var new_type: TargetType = TargetType.NONE
	
	var layers = _get_collision_layers(collider)
	
	var pickup_item = _find_pickupable(collider)
	var container = _find_container(collider)
	var interactable = _find_interactable(collider)
	var rigid_body = _find_rigid_body(collider)
	
	if 12 in layers and interactable:
		new_target = interactable
		new_type = TargetType.INTERACTABLE
	elif container:
		new_target = container
		new_type = TargetType.CONTAINER
	elif 4 in layers and 8 in layers and pickup_item and rigid_body:
		new_target = collider
		new_type = TargetType.LOOT_AND_GRAB
	elif 8 in layers and pickup_item:
		new_target = pickup_item
		new_type = TargetType.LOOT_ONLY
	elif 4 in layers and rigid_body:
		new_target = rigid_body
		new_type = TargetType.GRAB_ONLY
	
	if new_target != current_target or new_type != target_type:
		_set_target(new_target, new_type)

func _get_collision_layers(node: Node) -> Array[int]:
	var layers: Array[int] = []
	if node is CollisionObject3D:
		var mask = node.collision_layer
		for i in range(32):
			if mask & (1 << i):
				layers.append(i + 1)
	return layers

# ============================================================================
# TARGET MANAGEMENT
# ============================================================================
func _set_target(target: Node, type: TargetType) -> void:
	_clear_target()
	
	current_target = target
	target_type = type
	
	if not target:
		return
	
	match type:
		TargetType.LOOT_ONLY:
			loot_handler.handle_loot_target(target, self)
		TargetType.GRAB_ONLY:
			grab_handler.handle_grab_target(target, self)
		TargetType.LOOT_AND_GRAB:
			loot_handler.handle_dual_target(target, self)
		TargetType.INTERACTABLE:
			interactable_handler.handle_interactable_target(target, self)
		TargetType.CONTAINER:
			loot_handler.handle_container_target(target, self)

func _clear_target() -> void:
	if current_target:
		match target_type:
			TargetType.LOOT_ONLY, TargetType.LOOT_AND_GRAB:
				loot_handler.clear_loot_target(current_target)
			TargetType.INTERACTABLE:
				interactable_handler.clear_interactable_target(current_target)
		item_lost.emit()
	
	current_target = null
	target_type = TargetType.NONE
	_update_ui("", "", "")

# ============================================================================
# INPUT HANDLING
# ============================================================================
func _handle_input(delta: float) -> void:
	# Check if holding any object (big or small)
	var is_holding_any = grab_handler.is_holding() or small_grab_handler.is_holding()
	var is_holding_alt = small_grab_handler.is_holding()
	if Input.is_action_just_pressed(throw_action) and is_holding_any:
		if grab_handler.is_holding():
			grab_handler.throw_object()
		# elif small_grab_handler.is_holding():
		# 	small_grab_handler.throw_small_object()
		return

	if Input.is_action_just_pressed(throw_action_alt) and is_holding_alt:
		if small_grab_handler.is_holding():
			small_grab_handler.throw_small_object()
		return

	if Input.is_action_pressed(interact_action):
		if not is_holding_input:
			is_holding_input = true
			input_hold_time = 0.0
		else:
			input_hold_time += delta
	
	if Input.is_action_just_released(interact_action):
		if is_holding_any:
			if grab_handler.is_holding():
				grab_handler.drop_object()
				return
			elif small_grab_handler.is_holding() and not current_target:
				small_grab_handler.drop_small_object()
		if current_target:
			if input_hold_time < hold_threshold:
				_handle_press_interaction()
			else:
				_handle_hold_interaction()
		
		is_holding_input = false
		input_hold_time = 0.0

func _handle_press_interaction() -> void:
	match target_type:
		TargetType.LOOT_ONLY:
			loot_handler.pickup_item(_find_pickupable(current_target), self)
		TargetType.GRAB_ONLY:
			var rb = current_target as RigidBody3D
			# Determine if small or big grab
			if small_grab_handler.should_use_small_grab(rb):
				small_grab_handler.grab_small_object(rb)
			else:
				grab_handler.grab_object(rb)
		TargetType.LOOT_AND_GRAB:
			loot_handler.pickup_item(_find_pickupable(current_target), self)
		TargetType.INTERACTABLE:
			interactable_handler.interact_with(current_target as InteractableComponent)
		TargetType.CONTAINER:
			loot_handler.open_container(current_target as ContainerComponent, self)

func _handle_hold_interaction() -> void:
	match target_type:
		TargetType.LOOT_AND_GRAB:
			var rb = _find_rigid_body(current_target)
			# Determine if small or big grab for hold interaction
			if small_grab_handler.should_use_small_grab(rb):
				small_grab_handler.grab_small_object(rb)
			else:
				grab_handler.grab_object(rb)
		TargetType.INTERACTABLE:
			interactable_handler.alt_interact_with(current_target as InteractableComponent)

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================
func _on_object_grabbed(obj: RigidBody3D) -> void:
	object_grabbed.emit(obj)
	_clear_target()

func _on_object_dropped(obj: RigidBody3D) -> void:
	object_dropped.emit(obj)

func _on_object_thrown(obj: RigidBody3D, vel: Vector3) -> void:
	object_thrown.emit(obj, vel)

func _on_small_object_grabbed(obj: RigidBody3D) -> void:
	object_grabbed.emit(obj)
	_clear_target()

func _on_small_object_dropped(obj: RigidBody3D) -> void:
	object_dropped.emit(obj)

func _on_small_object_thrown(obj: RigidBody3D, vel: Vector3) -> void:
	object_thrown.emit(obj, vel)

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================
func _find_pickupable(node: Node, check_self = true) -> PickupableItem:
	if node is PickupableItem and check_self:
		return node
	for child in node.get_children():
		if child is PickupableItem:
			return child
	if node.get_parent() is PickupableItem:
		return node.get_parent()
	return null

func _find_container(node: Node) -> ContainerComponent:
	if node is ContainerComponent:
		return node
	for child in node.get_children():
		if child is ContainerComponent:
			return child
	if node.get_parent() is ContainerComponent:
		return node.get_parent()
	return null

func _find_interactable(node: Node) -> InteractableComponent:
	if node is InteractableComponent:
		return node
	for child in node.get_children():
		if child is InteractableComponent:
			return child
	if node.get_parent() is InteractableComponent:
		return node.get_parent()
	return null

func _find_rigid_body(node: Node) -> RigidBody3D:
	if node is RigidBody3D:
		return node
	if node.get_parent() is RigidBody3D:
		return node.get_parent()
	return null

func _update_ui(primary_action: String, secondary_action: String, target_name: String) -> void:
	if not interact_control:
		return
	
	var should_show = show_interaction_prompt and (primary_action != "" or target_name != "")
	
	if should_show:
		var key_name = InputActions.get_action_key(interact_action)
		
		if key_prompt_label:
			key_prompt_label.text = "[%s]" % key_name
			key_prompt_label.visible = true
		
		if primary_action_label:
			primary_action_label.text = primary_action
			primary_action_label.visible = (primary_action != "")
		
		if secondary_action_label:
			secondary_action_label.text = secondary_action
			secondary_action_label.visible = (secondary_action != "")
		
		if item_name_label:
			item_name_label.text = target_name
			item_name_label.visible = (target_name != "")
		
		interact_control.visible = true
	else:
		interact_control.visible = false
		if key_prompt_label:
			key_prompt_label.visible = false
		if primary_action_label:
			primary_action_label.visible = false
		if secondary_action_label:
			secondary_action_label.visible = false
		if item_name_label:
			item_name_label.visible = false

# ============================================================================
# PUBLIC API
# ============================================================================
func get_current_target() -> Node:
	return current_target

func get_target_type() -> TargetType:
	return target_type

func is_holding_any() -> bool:
	return grab_handler.is_holding() or small_grab_handler.is_holding()

func is_holding_big() -> bool:
	return grab_handler.is_holding()

func is_holding_small() -> bool:
	return small_grab_handler.is_holding()

func force_drop() -> void:
	if grab_handler.is_holding():
		grab_handler.drop_object()
	if small_grab_handler.is_holding():
		small_grab_handler.drop_small_object()
