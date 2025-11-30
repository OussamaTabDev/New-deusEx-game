class_name PickupInteractionComponent
extends Node3D

signal item_detected(item: PickupableItem)
signal item_lost()
signal container_detected(container: ContainerComponent)
signal pickup_failed(reason: String)

@export_group("References")
@export var shape_cast: ShapeCast3D
@export var inventory_handler: InventoryHandlerComponenent
@export var camera_controller: Node
@export var cyber_scanner: CyberScanner  # ← Add this reference

@export_group("Settings")
@export var pickup_action: String = "interact"
@export var hold_threshold: float = 0.3
@export var max_pickup_distance: float = 3.0
@export var show_pickup_prompt: bool = true

@export_subgroup("Selection Heuristics")
@export_range(0.0, 10.0) var centering_bias: float = 4.0

@export_group("UI")
@export var interact_control: Control
@export var pickup_label: Label

var current_target: Node = null
var is_item: bool = false
var is_container: bool = false
var input_hold_time: float = 0.0
var is_holding_input: bool = false

func _ready() -> void:
    if not shape_cast:
        push_error("PickupInteractionComponent: ShapeCast3D not assigned!")
        return
    if not inventory_handler:
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
    var cast_origin = shape_cast.global_position
    var cast_forward = -shape_cast.global_transform.basis.z.normalized()

    for i in range(shape_cast.get_collision_count()):
        var collider = shape_cast.get_collider(i)
        if not collider:
            continue
        var distance = global_position.distance_to(collider.global_position)
        if distance > max_pickup_distance:
            continue

        var pickup_item = _find_pickupable(collider)
        var container = _find_container(collider)
        var potential_target = pickup_item if pickup_item else container

        if potential_target:
            var score = _get_selection_score(potential_target, cast_origin, cast_forward)
            if score < best_score:
                best_score = score
                best_target = potential_target

    if best_target != current_target:
        _set_target(best_target)

func _get_selection_score(target_node: Node, ray_origin: Vector3, ray_dir: Vector3) -> float:
    var target_pos = target_node.global_position
    var dist_to_player = global_position.distance_to(target_pos)
    var to_target = target_pos - ray_origin
    var projection_length = to_target.dot(ray_dir)
    var point_on_ray = ray_origin + (ray_dir * projection_length)
    var dist_from_center_axis = point_on_ray.distance_to(target_pos)
    return dist_to_player + (dist_from_center_axis * centering_bias)

func _find_pickupable(node: Node) -> PickupableItem:
    if node is PickupableItem:
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

func _set_target(target: Node) -> void:
    _clear_target()
    current_target = target

    if target is PickupableItem:
        is_item = true
        item_detected.emit(target)

        if target.has_method("set_highlighted"):
            target.set_highlighted(true)

        # === SCANNER INTEGRATION ===
        if cyber_scanner:
            cyber_scanner.scanning_viewport.visible = true
            cyber_scanner._on_scanning(true)

            target.apply_to_scanner(cyber_scanner)
            target.set_scanning_layer(true)

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
    if current_target is PickupableItem:
        if current_target.has_method("set_highlighted"):
            current_target.set_highlighted(false)
        if cyber_scanner:
            current_target.set_scanning_layer(false)  # ← restore layers
            cyber_scanner._on_scanning(true)
            cyber_scanner.scanning_viewport.visible = false

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
        var key_name = "F"
        if InputMap.has_action(pickup_action):
            var events = InputMap.action_get_events(pickup_action)
            if events.size() > 0:
                key_name = events[0].as_text().split(" ")[0]
        pickup_label.text = "[%s] %s %s" % [key_name, "Pick up" if is_item else "Open", text]
        interact_control.visible = true
        pickup_label.visible = true
    else:
        interact_control.visible = false
        pickup_label.visible = false

func _handle_input(delta: float) -> void:
    if Input.is_action_pressed(pickup_action):
        if not is_holding_input:
            is_holding_input = true
            input_hold_time = 0.0
        else:
            input_hold_time += delta

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

    var total_count = pickup.stack_count
    var max_stack = base_item.max_stack
    var items_to_add: Array[InventoryItem] = []

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
        pickup_failed.emit("Inventory full")

func _open_container(container: ContainerComponent) -> void:
    if not inventory_handler:
        pickup_failed.emit("No inventory handler")
        return
    inventory_handler.interact_with_container(container)

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