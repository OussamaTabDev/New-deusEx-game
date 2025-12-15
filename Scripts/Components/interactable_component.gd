class_name InteractableComponent 
extends Node3D

## Base class for all interactable objects (doors, elevators, buttons, levers, etc.)
## Add this to your object and set collision layer to 12

signal interacted(player: Node)
signal interaction_started()
signal interaction_finished()
signal alt_interacted(player: Node)

@export_group("Interaction Settings")
@export var interaction_prompt: String = "Interact"
@export var can_interact_multiple_times: bool = true
@export var interaction_cooldown: float = 0.0
@export var require_key_item: String = ""  # Optional: Item name required to interact

@export_group("Alternative Interaction")
@export var has_alternative_interaction: bool = false
@export var alt_interaction_prompt: String = "Alt Interact"
@export var alt_require_key_item: String = ""

@export_group("Visual Feedback")
@export var highlight_on_look: bool = true
@export var highlight_material: Material = null

var _is_being_looked_at: bool = false
var _can_currently_interact: bool = true
var _cooldown_timer: float = 0.0
var _has_been_used: bool = false
var _original_materials: Array = []

func _ready() -> void:
	# Store original materials for highlighting
	if highlight_on_look and highlight_material:
		_store_original_materials()

func _physics_process(delta: float) -> void:
	# Handle cooldown
	if _cooldown_timer > 0:
		_cooldown_timer -= delta
		if _cooldown_timer <= 0:
			_can_currently_interact = true

# ============================================================================
# PUBLIC METHODS (Called by UnifiedInteractionComponent)
# ============================================================================

## Returns the prompt text to display in UI
func get_interaction_prompt() -> String:
	if not can_interact():
		return get_blocked_prompt()
	return interaction_prompt

## Returns alternative interaction prompt
func get_alt_interaction_prompt() -> String:
	return alt_interaction_prompt

## Check if alternative interaction exists
func has_alt_interaction() -> bool:
	return has_alternative_interaction

## Checks if alt interaction is allowed
func can_alt_interact() -> bool:
	if not has_alternative_interaction:
		return false
	return _can_alt_interact_custom()

## Checks if interaction is allowed
func can_interact() -> bool:
	if not can_interact_multiple_times and _has_been_used:
		return false
	if not _can_currently_interact:
		return false
	return _can_interact_custom()

## Main interaction method - override in child classes
func interact(player: Node) -> void:
	if not can_interact():
		return
	
	interaction_started.emit()
	_has_been_used = true
	
	# Check for required key item
	if require_key_item != "":
		if not _player_has_key_item(player):
			_on_missing_key_item(player)
			return
	
	# Call the custom interaction logic
	_perform_interaction(player)
	
	# Start cooldown if applicable
	if interaction_cooldown > 0:
		_can_currently_interact = false
		_cooldown_timer = interaction_cooldown
	
	interacted.emit(player)
	interaction_finished.emit()

## Alternative interaction method - override in child classes
func alt_interact(player: Node) -> void:
	if not can_alt_interact():
		return
	
	interaction_started.emit()
	
	# Check for required key item
	if alt_require_key_item != "":
		if not _player_has_key_item(player):
			_on_missing_key_item(player)
			return
	
	# Call the custom alt interaction logic
	_perform_alt_interaction(player)
	
	alt_interacted.emit(player)
	interaction_finished.emit()

## Called when player looks at this object
func on_looked_at() -> void:
	_is_being_looked_at = true
	if highlight_on_look:
		_apply_highlight()
	_on_looked_at_custom()

## Called when player looks away
func on_look_away() -> void:
	_is_being_looked_at = false
	if highlight_on_look:
		_remove_highlight()
	_on_look_away_custom()

# ============================================================================
# OVERRIDE THESE IN CHILD CLASSES
# ============================================================================

## Override: Custom interaction logic (open door, call elevator, etc.)
func _perform_interaction(player: Node) -> void:
	push_warning("InteractableComponent: _perform_interaction() not implemented in " + name)

## Override: Alternative interaction logic
func _perform_alt_interaction(player: Node) -> void:
	push_warning("InteractableComponent: _perform_alt_interaction() not implemented in " + name)

## Override: Additional conditions for interaction
func _can_interact_custom() -> bool:
	return true

## Override: Additional conditions for alt interaction
func _can_alt_interact_custom() -> bool:
	return true

## Override: Custom behavior when looked at
func _on_looked_at_custom() -> void:
	pass

## Override: Custom behavior when look away
func _on_look_away_custom() -> void:
	pass

## Override: Custom prompt when interaction is blocked
func get_blocked_prompt() -> String:
	if not can_interact_multiple_times and _has_been_used:
		return "Already Used"
	if not _can_currently_interact:
		return "On Cooldown"
	return "Cannot Interact"

# ============================================================================
# INTERNAL HELPERS
# ============================================================================

func _player_has_key_item(player: Node) -> bool:
	# Try to find inventory handler on player
	if player.has_node("InventoryHandlerComponenent"):
		var inventory = player.get_node("InventoryHandlerComponenent")
		if inventory.has_method("has_item"):
			return inventory.has_item(require_key_item)
	return false

func _on_missing_key_item(player: Node) -> void:
	print("Player needs: " + require_key_item)
	# You can emit a signal here or show a message

func _store_original_materials() -> void:
	var parent = get_parent()
	if parent is MeshInstance3D:
		var mesh = parent as MeshInstance3D
		for i in range(mesh.get_surface_override_material_count()):
			_original_materials.append(mesh.get_surface_override_material(i))

func _apply_highlight() -> void:
	if not highlight_material:
		return
	var parent = get_parent()
	if parent is MeshInstance3D:
		var mesh = parent as MeshInstance3D
		for i in range(mesh.get_surface_override_material_count()):
			mesh.set_surface_override_material(i, highlight_material)

func _remove_highlight() -> void:
	var parent = get_parent()
	if parent is MeshInstance3D:
		var mesh = parent as MeshInstance3D
		for i in range(_original_materials.size()):
			mesh.set_surface_override_material(i, _original_materials[i])