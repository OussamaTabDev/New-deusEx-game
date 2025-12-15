class_name UnifiedInteractionComponent
extends Node3D

## Unified interaction system that handles:
## - Layer 4: Grabbable objects (RigidBody3D)
## - Layer 8: Lootable items (PickupableItem)
## - Layer 4+8: Press to loot, Hold to grab
## - Layer 12: Interactables (doors, elevators, etc.)

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
# signal interactable_lost()
# signal interaction_completed(interactable: InteractableComponent)
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

@export_group("UI")
@export var interact_control: Control
@export var primary_action_label: Label  # Main action (Pickup/Grab/Interact)
@export var secondary_action_label: Label  # Secondary action (Hold to Grab/Alt Interact)
@export var item_name_label: Label  # Item/object name
@export var key_prompt_label: Label  # Key binding display [F]

# ============================================================================
# SETTINGS
# ============================================================================
@export_group("Detection Settings")
@export var interact_action: String = "interact"
@export var throw_action: String = "throw"
@export var max_interaction_distance: float = 3.0
@export var hold_threshold: float = 0.3  # Time to hold before grabbing
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

# Grab state
var held_object: RigidBody3D = null
var is_holding_object: bool = false
var original_gravity_scale: float = 1.0
var original_linear_damp: float = 0.0
var original_angular_damp: float = 0.0
var hold_offset_center: Vector3 = Vector3.ZERO

enum TargetType {
    NONE,
    LOOT_ONLY,        # Layer 8 only
    GRAB_ONLY,        # Layer 4 only
    LOOT_AND_GRAB,    # Layer 4 + 8
    INTERACTABLE,     # Layer 12
    CONTAINER         # ContainerComponent
}

# ============================================================================
# INITIALIZATION
# ============================================================================
func _ready() -> void:
    _validate_references()
    _setup_defaults()

func _validate_references() -> void:
    if not interaction_raycast:
        push_error("UnifiedInteractionComponent: RayCast3D not assigned!")
        return
    
    if not inventory_handler:
        inventory_handler = get_node_or_null("../InventoryHandlerComponenent")
    
    if not inventory_handler:
        push_warning("UnifiedInteractionComponent: InventoryHandler not found!")
    
    # Auto-find player if not assigned
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
    # Create default hold position if missing
    if not hold_position:
        var default_hold = Node3D.new()
        default_hold.name = "DefaultHoldPosition"
        if get_parent().name.to_lower().contains("camera"):
            get_parent().add_child(default_hold)
        else:
            add_child(default_hold)
        default_hold.position = Vector3(0.5, -0.5, -2.0)
        hold_position = default_hold

# ============================================================================
# MAIN LOOP
# ============================================================================
func _physics_process(delta: float) -> void:
    _update_detection()
    _handle_input(delta)
    
    # Update held object physics
    if is_holding_object and held_object:
        _apply_hold_forces(delta)

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
    
    # Determine what we're looking at based on collision layers
    var new_target: Node = null
    var new_type: TargetType = TargetType.NONE
    
    var layers = _get_collision_layers(collider)
    
    # Check collision layers and find components
    var pickup_item = _find_pickupable(collider)
    var container = _find_container(collider)
    var interactable = _find_interactable(collider)
    var rigid_body = _find_rigid_body(collider)
    
    # Determine target type based on layers and components
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
    
    # Update target if changed
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
            _handle_loot_target(target)
        
        TargetType.GRAB_ONLY:
            _handle_grab_target(target)
        
        TargetType.LOOT_AND_GRAB:
            _handle_dual_target(target)
        
        TargetType.INTERACTABLE:
            _handle_interactable_target(target)
        
        TargetType.CONTAINER:
            _handle_container_target(target)

func _handle_loot_target(target: Node) -> void:
    var pickup = target as PickupableItem
    item_detected.emit(pickup)
    
    if pickup.has_method("set_highlighted"):
        pickup.set_highlighted(true)
    
    _apply_scanner(pickup)
    
    var item_name = _get_item_display_name(pickup)
    _update_ui("Pick up", "", item_name)

func _handle_grab_target(target: Node) -> void:
    if is_holding_object:
        _update_ui("Drop", "", target.name)
    else:
        _update_ui("Grab", "", target.name)

func _handle_dual_target(target: Node) -> void:
    var pickup = _find_pickupable(target)
    if pickup:
        if pickup.has_method("set_highlighted"):
            pickup.set_highlighted(true)
        _apply_scanner(pickup)
        var item_name = _get_item_display_name(pickup)
        _update_ui("Pick up", "Hold to Grab", item_name)
    else:
        _update_ui("Pick up", "Hold to Grab", target.name)

func _handle_interactable_target(target: Node) -> void:
    var interactable = target as InteractableComponent
    interactable_detected.emit(interactable)
    
    if interactable.has_method("on_looked_at"):
        interactable.on_looked_at()
    
    var prompt = interactable.get_interaction_prompt()
    var alt_prompt = ""
    if interactable.has_alternative_interaction:
        alt_prompt = "Hold: " + interactable.alt_interaction_prompt
    
    _update_ui(prompt, alt_prompt, "")

func _handle_container_target(target: Node) -> void:
    var container = target as ContainerComponent
    container_detected.emit(container)
    _update_ui("Open", "", container.container_name)

func _clear_target() -> void:
    if current_target:
        match target_type:
            TargetType.LOOT_ONLY, TargetType.LOOT_AND_GRAB:
                var pickup = _find_pickupable(current_target)
                if pickup:
                    if pickup.has_method("set_highlighted"):
                        pickup.set_highlighted(false)
                    _remove_scanner(pickup)
            
            TargetType.INTERACTABLE:
                var interactable = current_target as InteractableComponent
                if interactable and interactable.has_method("on_look_away"):
                    interactable.on_look_away()
        
        item_lost.emit()
    
    current_target = null
    target_type = TargetType.NONE
    _update_ui("", "", "")

# ============================================================================
# INPUT HANDLING
# ============================================================================
func _handle_input(delta: float) -> void:
    # Handle throw action for held objects
    if Input.is_action_just_pressed(throw_action) and is_holding_object:
        _throw_object()
        return
    
    # Track hold time
    if Input.is_action_pressed(interact_action):
        if not is_holding_input:
            is_holding_input = true
            input_hold_time = 0.0
        else:
            input_hold_time += delta
    
    # Handle release
    if Input.is_action_just_released(interact_action):
        if is_holding_object:
            _drop_object()
        elif current_target:
            if input_hold_time < hold_threshold:
                _handle_press_interaction()
            else:
                _handle_hold_interaction()
        
        is_holding_input = false
        input_hold_time = 0.0

func _handle_press_interaction() -> void:
    match target_type:
        TargetType.LOOT_ONLY:
            _pickup_item(_find_pickupable(current_target))
        
        TargetType.GRAB_ONLY:
            _grab_object(current_target as RigidBody3D)
        
        TargetType.LOOT_AND_GRAB:
            _pickup_item(_find_pickupable(current_target))
        
        TargetType.INTERACTABLE:
            _interact_with(current_target as InteractableComponent)
        
        TargetType.CONTAINER:
            _open_container(current_target as ContainerComponent)

func _handle_hold_interaction() -> void:
    match target_type:
        TargetType.LOOT_AND_GRAB:
            _grab_object(_find_rigid_body(current_target))
        
        TargetType.INTERACTABLE:
            var interactable = current_target as InteractableComponent
            if interactable.has_alternative_interaction:
                _alt_interact_with(interactable)

# ============================================================================
# LOOT SYSTEM
# ============================================================================
func _pickup_item(pickup: PickupableItem) -> void:
    if not pickup or not inventory_handler:
        interaction_failed.emit("No inventory handler")
        return
    
    var base_item = pickup.item_data

    if not base_item:
        interaction_failed.emit("Invalid item data")
        return
    # print("Picking up: %s" % base_item.display_name)

    var total_count = pickup.stack_count
    var max_stack = base_item.max_stack
    var items_to_add: Array[InventoryItem] = []

    if base_item.display_name in inventory_handler.inventory_component.get_all_display_name_items() and base_item.type == "weapon":
        print("Already have weapon: %s" % base_item.display_name)
        var _pickup = _find_pickupable(pickup , false)
        base_item = _pickup.item_data
        total_count = _pickup.stack_count
        max_stack = base_item.max_stack
        if not base_item:
            interaction_failed.emit("Invalid item data")
            return
    
    while total_count > 0:
        var chunk = base_item.duplicate()
        chunk.stack_count = min(total_count, max_stack)
        items_to_add.append(chunk)
        total_count -= max_stack
    
    var all_succeeded = true
    for item in items_to_add:
        if not inventory_handler.pickup_item(item):
            all_succeeded = false
            break
    
    if all_succeeded:
        pickup.on_picked_up(self)
        _clear_target()
    else:
        interaction_failed.emit("Inventory full")

func _open_container(container: ContainerComponent) -> void:
    if not inventory_handler:
        interaction_failed.emit("No inventory handler")
        return
    inventory_handler.interact_with_container(container)

# ============================================================================
# GRAB SYSTEM
# ============================================================================
func _grab_object(rb: RigidBody3D) -> void:
    if not rb:
        return
    
    # Validation checks
    if rb.mass > max_pickup_mass:
        interaction_failed.emit("Too heavy")
        return
    
    if global_position.distance_to(rb.global_position) > max_interaction_distance:
        return
    
    # Prevent grabbing while sprinting
    if player and player.has_node("state_machine"):
        var state_machine = player.get_node("state_machine")
        if state_machine.current_state.name == "SprintingState":
            return
    
    # Drop current object if holding one
    if is_holding_object:
        _drop_object()
    
    held_object = rb
    is_holding_object = true
    
    # Store and modify physics
    original_gravity_scale = held_object.gravity_scale
    original_linear_damp = held_object.linear_damp
    original_angular_damp = held_object.angular_damp
    
    held_object.gravity_scale = 0.0
    held_object.linear_damp = 1.0
    held_object.angular_damp = 1.0
    
    # Calculate center offset
    var aabb = held_object.get_aabb()
    if aabb.size == Vector3.ZERO:
        hold_offset_center = Vector3.ZERO
    else:
        var center_local = aabb.position + aabb.size / 2.0
        hold_offset_center = -center_local
    
    # Prevent player collision
    if player:
        player.add_collision_exception_with(held_object)
        held_object.add_collision_exception_with(player)
    
    object_grabbed.emit(held_object)
    _clear_target()

func _drop_object() -> void:
    if not is_holding_object or not held_object:
        return
    
    # Restore physics
    held_object.gravity_scale = original_gravity_scale
    held_object.linear_damp = original_linear_damp
    held_object.angular_damp = original_angular_damp
    
    # Restore collisions
    if player:
        player.remove_collision_exception_with(held_object)
        held_object.remove_collision_exception_with(player)
    
    # Apply momentum
    if player:
        held_object.linear_velocity += player.velocity
    
    object_dropped.emit(held_object)
    
    held_object = null
    is_holding_object = false

func _throw_object() -> void:
    if not is_holding_object or not held_object:
        return
    
    var thrown_obj = held_object
    var dir = -hold_position.global_transform.basis.z
    
    _drop_object()
    
    thrown_obj.apply_central_impulse(dir * throw_force)
    object_thrown.emit(thrown_obj, dir * throw_force)

func _apply_hold_forces(delta: float) -> void:
    if not is_instance_valid(held_object):
        is_holding_object = false
        held_object = null
        return
    
    var target_pos = hold_position.global_position
    var current_pos = held_object.global_position
    
    # Break distance check
    if target_pos.distance_to(current_pos) > break_distance:
        _drop_object()
        return
    
    # Position calculation
    var center_offset_rotated = held_object.global_transform.basis * hold_offset_center
    var desired_pivot_pos = target_pos + center_offset_rotated
    var target_velocity = (desired_pivot_pos - held_object.global_position) * hold_power
    held_object.linear_velocity = target_velocity
    
    # Rotation calculation
    var target_basis = hold_position.global_transform.basis
    var current_basis = held_object.global_transform.basis
    var rot_diff = target_basis * current_basis.inverse()
    var quat_diff = rot_diff.get_rotation_quaternion()
    var axis = quat_diff.get_axis().normalized()
    var angle = quat_diff.get_angle()
    
    if angle > PI:
        angle -= 2 * PI
    
    held_object.angular_velocity = axis * angle * rotation_power

# ============================================================================
# INTERACTABLE SYSTEM
# ============================================================================
func _interact_with(interactable: InteractableComponent) -> void:
    if not interactable:
        return
    
    if interactable.can_interact():
        interactable.interact(player if player else self)
    else:
        interaction_failed.emit(interactable.get_blocked_prompt())

func _alt_interact_with(interactable: InteractableComponent) -> void:
    if not interactable:
        return
    
    if interactable.has_method("alt_interact"):
        interactable.alt_interact(player if player else self)
    else:
        interactable.interact(player if player else self)

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================
func _find_pickupable(node: Node , check_self = true) -> PickupableItem:
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

func _get_item_display_name(pickup: PickupableItem) -> String:
    if not pickup.item_data:
        return "Unknown"
    
    var item_name = pickup.item_data.display_name
    var count = pickup.stack_count
    if pickup.item_data.stackable and count > 1:
        return "%s (x%d)" % [item_name, count]
    return item_name

func _apply_scanner(pickup: PickupableItem) -> void:
    if cyber_scanner and is_scan_enabled:
        cyber_scanner._on_scanning(true)
        pickup.apply_to_scanner(cyber_scanner)
        pickup.set_scanning_layer(true)

func _remove_scanner(pickup: PickupableItem) -> void:
    if cyber_scanner and is_scan_enabled:
        pickup.set_scanning_layer(false)
        cyber_scanner._on_scanning(false)

func _update_ui(primary_action: String, secondary_action: String, target_name: String) -> void:
    if not interact_control:
        return
    
    # Determine if we should show UI
    var should_show = show_interaction_prompt and (primary_action != "" or target_name != "")
    
    if should_show:
        # Get key binding
        var key_name = InputActions.get_action_key(interact_action)
        
        # Update key prompt label
        if key_prompt_label:
            key_prompt_label.text = "[%s]" % key_name
            key_prompt_label.visible = true
        
        # Update primary action label
        if primary_action_label:
            primary_action_label.text = primary_action
            primary_action_label.visible = (primary_action != "")
        
        # Update secondary action label
        if secondary_action_label:
            secondary_action_label.text = secondary_action
            secondary_action_label.visible = (secondary_action != "")
        
        # Update item/target name label
        if item_name_label:
            item_name_label.text = target_name
            item_name_label.visible = (target_name != "")
        
        # Show the parent control
        interact_control.visible = true
        
    else:
        # Hide everything
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

func is_holding() -> bool:
    return is_holding_object

func force_drop() -> void:
    if is_holding_object:
        _drop_object()