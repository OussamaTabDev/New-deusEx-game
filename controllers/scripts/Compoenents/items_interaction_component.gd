class_name PickupInteractionComponent
extends Node3D

## Component for detecting and picking up items using ShapeCast3D.
## Handles both inventory pickups and container interactions
## Works alongside RigidBodyInteractionComponent for grab/pickup priority

signal item_detected(item: PickupableItem)
signal item_lost()
signal container_detected(container: ContainerComponent)
signal pickup_failed(reason: String)

# --- Configuration ---
@export_group("References")
@export var shape_cast: ShapeCast3D ## ShapeCast for detecting pickups (collision layer 8)
@export var inventory_handler: InventoryHandlerComponenent # Typo fixed in class name if needed
@export var camera_controller: Node

@export_group("Settings")
@export var pickup_action: String = "interact" ## Quick press
@export var hold_threshold: float = 0.3 ## Hold time before triggering grab instead
@export var max_pickup_distance: float = 3.0
@export var show_pickup_prompt: bool = true

@export_subgroup("Selection Heuristics")
@export_range(0.0, 10.0) var centering_bias: float = 4.0 ## Higher values prioritize objects in the center of the screen over closer objects on the edge.

@export_group("UI")
@export var interact_control: Control ## Optional: UI label showing item name
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
        # Note: Ensure the class name matches your project (Component vs Componenent)
        inventory_handler = get_node_or_null("../InventoryHandlerComponenent")
    
    if not inventory_handler:
        push_warning("PickupInteractionComponent: InventoryHandler not found!")

func _physics_process(delta: float) -> void:
    _update_detection()
    _handle_input(delta)

func _update_detection() -> void:
    if not shape_cast or not shape_cast.is_colliding():
        _clear_target()
        return
    
    var best_target: Node = null
    var best_score: float = INF
    
    # Get the ray properties for "Center" calculation
    # We assume the ShapeCast is facing forward (Negative Z)
    var cast_origin = shape_cast.global_position
    var cast_forward = -shape_cast.global_transform.basis.z.normalized()
    
    # Check all collision results
    for i in range(shape_cast.get_collision_count()):
        var collider = shape_cast.get_collider(i)
        if not collider:
            continue 
            
        var distance = global_position.distance_to(collider.global_position)
        
        # 1. Distance Hard Check
        if distance > max_pickup_distance:
            continue
        
        # 2. Identify Type
        var potential_target = null
        var pickup_item = _find_pickupable(collider)
        var container = _find_container(collider)
        
        if pickup_item:
            potential_target = pickup_item
        elif container:
            potential_target = container
            
        if potential_target:
            # 3. Calculate Score (Distance vs Center Alignment)
            var score = _get_selection_score(potential_target, cast_origin, cast_forward)
            
            # Lower score is better
            if score < best_score:
                best_score = score
                best_target = potential_target
    
    # Update current target
    if best_target != current_target:
        _set_target(best_target)

func _get_selection_score(target_node: Node, ray_origin: Vector3, ray_dir: Vector3) -> float:
    """
    Calculates a score based on distance and alignment with the look-ray.
    Lower score = Better match.
    """
    var target_pos = target_node.global_position
    
    # A: Physical Distance to player
    var dist_to_player = global_position.distance_to(target_pos)
    
    # B: Perpendicular distance from the center aiming ray (The "Center" check)
    # Vector from ray start to object
    var to_target = target_pos - ray_origin
    # Project that vector onto the forward ray to find the point on the line closest to object
    var projection_length = to_target.dot(ray_dir)
    var point_on_ray = ray_origin + (ray_dir * projection_length)
    # Calculate how far the object is from that center line
    var dist_from_center_axis = point_on_ray.distance_to(target_pos)
    
    # Combine: Score = Distance + (OffCenterAmount * Bias)
    # If centering_bias is high, an object must be very centered to be picked
    return dist_to_player + (dist_from_center_axis * centering_bias)

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
    _clear_target()  # This will unhighlight previous target

    current_target = target

    if target is PickupableItem:
        is_item = true
        item_detected.emit(target)
        
        # Highlight logic
        if target.has_method("set_highlighted"):
            target.set_highlighted(true)

        var item_name = "Unknown"
        if target.item_data:
            item_name = target.item_data.display_name
            var count = target.stack_count
            if target.item_data.stackable and count > 1:
                item_name = "%s (x%d)" % [item_name, count]
        
        _update_ui(item_name)

    elif target is ContainerComponent:
        is_container = true
        container_detected.emit(target)
        _update_ui(target.container_name)

func _clear_target() -> void:
    # Unhighlight current item
    if current_target and current_target is PickupableItem:
        if current_target.has_method("set_highlighted"):
            current_target.set_highlighted(false)

    if current_target:
        item_lost.emit()

    current_target = null
    is_item = false
    is_container = false
    _update_ui("")

func _update_ui(text: String) -> void:
    if not pickup_label or not interact_control:
        return
        
    if show_pickup_prompt and text != "":
        # Safe input action check to prevent errors if action doesn't exist
        var key_name = "F"
        if InputMap.has_action(pickup_action):
            var events = InputMap.action_get_events(pickup_action)
            if events.size() > 0:
                key_name = events[0].as_text().split(" ")[0] # Simple key name extraction
        
        pickup_label.text = "[%s] %s %s" % [key_name, "Pick up" if is_item else "Open", text]
        interact_control.visible = true
        pickup_label.visible = true
    else:
        interact_control.visible = false
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
    
    var base_item = pickup.item_data
    if not base_item:
        pickup_failed.emit("Invalid item data")
        return
    
    # Use actual stack count from the world object
    var total_count = pickup.stack_count
    var max_stack = base_item.max_stack
    var items_to_add: Array[InventoryItem] = []

    # Split into valid chunks
    while total_count > 0:
        var chunk = base_item.duplicate()
        chunk.stack_count = min(total_count, max_stack)
        items_to_add.append(chunk)
        total_count -= max_stack

    # Try to add all chunks
    var all_succeeded = true
    for item in items_to_add:
        if not inventory_handler.pickup_item(item):
            all_succeeded = false
            break # Stop on first failure

    if all_succeeded:
        # Success: remove pickup from world
        pickup.on_picked_up(self)
        _clear_target()
    else:
        pickup_failed.emit("Inventory full")

func _open_container(container: ContainerComponent) -> void:
    if not inventory_handler:
        pickup_failed.emit("No inventory handler")
        return
    
    inventory_handler.interact_with_container(container)

## Public API
func force_pickup(item: InventoryItem) -> bool:
    if inventory_handler:
        return inventory_handler.pickup_item(item)
    return false

func get_current_target() -> Node:
    return current_target

func is_looking_at_pickup() -> bool:
    return is_item

func is_looking_at_container() -> bool:
    return is_container