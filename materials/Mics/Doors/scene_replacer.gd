@tool
extends Node
class_name SceneReplacer

## Component that replaces its parent Node3D with a premade scene
## Attach this as a child to any Node3D you want to be replaceable

@export_group("Replacement Settings")
@export_file("*.tscn") var replacement_scene_path: String = ""
@export var replace_on_ready: bool = false
@export var trigger_key: Key = KEY_NONE ## Press this key to trigger replacement at runtime

@export_group("Copy Options")
@export var copy_transform: bool = true
@export var copy_properties: bool = true
@export var copy_children: bool = true
@export var preserve_name: bool = true

@export_group("Advanced")
@export var delete_original: bool = true
@export var keep_this_component: bool = false ## Keep SceneReplacer component in new instance

## Properties to exclude from copying
const EXCLUDED_PROPERTIES = [
	"script", "Script Variables", "Node", "", "Ordering", 
	"Transform", "transform", "global_transform"
]

var _replaced: bool = false

func _ready() -> void:
	if not Engine.is_editor_hint() and replace_on_ready and not replacement_scene_path.is_empty():
		call_deferred("perform_replacement")

func _input(event: InputEvent) -> void:
	if not Engine.is_editor_hint() and trigger_key != KEY_NONE:
		if event is InputEventKey and event.pressed and event.keycode == trigger_key:
			perform_replacement()

## Main function to perform the replacement
func perform_replacement() -> Node:
	if _replaced:
		push_warning("Already replaced!")
		return null
	
	var target_node = get_parent()
	
	if target_node == null:
		push_error("SceneReplacer has no parent to replace!")
		return null
	
	if not target_node is Node3D:
		push_error("Parent must be a Node3D!")
		return null
	
	if replacement_scene_path.is_empty():
		push_error("No replacement scene path specified!")
		return null
	
	# Load and instantiate the scene
	var packed_scene = load(replacement_scene_path) as PackedScene
	if packed_scene == null:
		push_error("Failed to load scene: %s" % replacement_scene_path)
		return null
	
	var new_instance = packed_scene.instantiate()
	if new_instance == null:
		push_error("Failed to instantiate scene!")
		return null
	
	# Store original data
	var parent = target_node.get_parent()
	if parent == null:
		push_error("Target node has no parent!")
		new_instance.queue_free()
		return null
	
	var original_index = target_node.get_index()
	var original_name = target_node.name
	var original_owner = target_node.owner
	
	# Copy transform first
	if copy_transform and new_instance is Node3D:
		new_instance.transform = target_node.transform
	
	# Copy properties
	if copy_properties:
		_copy_node_properties(target_node, new_instance)
	
	# Handle children
	if copy_children:
		_transfer_children(target_node, new_instance)
	
	# Keep this component if requested
	if keep_this_component:
		var this_component_dup = self.duplicate(DUPLICATE_USE_INSTANTIATION)
		target_node.remove_child(self)
		new_instance.add_child(this_component_dup)
		if Engine.is_editor_hint():
			this_component_dup.owner = get_tree().edited_scene_root
	
	# Remove old node and add new one
	parent.remove_child(target_node)
	parent.add_child(new_instance)
	parent.move_child(new_instance, original_index)
	
	# Set name
	if preserve_name:
		new_instance.name = original_name
	
	# Set owner for editor
	if Engine.is_editor_hint():
		new_instance.owner = get_tree().edited_scene_root
		_set_owner_recursive(new_instance, get_tree().edited_scene_root)
	else:
		new_instance.owner = original_owner
	
	_replaced = true
	
	print("✓ Replaced '%s' with: %s" % [original_name, replacement_scene_path])
	
	# Clean up original
	if delete_original:
		target_node.queue_free()
	
	return new_instance

## Copy properties from source to target
func _copy_node_properties(source: Node, target: Node) -> void:
	var property_list = source.get_property_list()
	var copied_count = 0
	
	for prop in property_list:
		var prop_name = prop["name"]
		
		# Skip excluded properties
		if _should_skip_property(prop_name, prop):
			continue
		
		# Only copy storable properties
		if prop["usage"] & PROPERTY_USAGE_STORAGE:
			if prop_name in target:
				var value = source.get(prop_name)
				target.set(prop_name, value)
				copied_count += 1
	
	if copied_count > 0:
		print("  Copied %d properties" % copied_count)

## Check if property should be skipped
func _should_skip_property(prop_name: String, prop_info: Dictionary) -> bool:
	# Exclude specific properties
	if prop_name in EXCLUDED_PROPERTIES:
		return true
	
	# Exclude internal properties
	if prop_name.begins_with("_"):
		return true
	
	# Exclude categories and groups
	if prop_info["usage"] & PROPERTY_USAGE_CATEGORY:
		return true
	if prop_info["usage"] & PROPERTY_USAGE_GROUP:
		return true
	
	return false

## Transfer children from source to target
func _transfer_children(source: Node, target: Node) -> void:
	var children_to_move = []
	
	# Collect children (except this component)
	for child in source.get_children():
		if child != self:
			children_to_move.append(child)
	
	# Move each child
	for child in children_to_move:
		source.remove_child(child)
		target.add_child(child)
		
		# Set owner for editor
		if Engine.is_editor_hint():
			_set_owner_recursive(child, get_tree().edited_scene_root)
	
	if children_to_move.size() > 0:
		print("  Transferred %d children" % children_to_move.size())

## Recursively set owner
func _set_owner_recursive(node: Node, new_owner: Node) -> void:
	node.owner = new_owner
	for child in node.get_children():
		_set_owner_recursive(child, new_owner)

## Editor function - call from inspector
func replace() -> void:
	if Engine.is_editor_hint():
		perform_replacement()