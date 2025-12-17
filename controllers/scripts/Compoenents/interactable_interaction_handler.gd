class_name InteractableInteractionHandler
extends Node

## Handles interactions with interactable objects (doors, elevators, buttons, etc.)

var main_component: UnifiedInteractionComponent

# ============================================================================
# INITIALIZATION
# ============================================================================
func initialize(component: UnifiedInteractionComponent) -> void:
	main_component = component

# ============================================================================
# TARGET HANDLING
# ============================================================================
func handle_interactable_target(target: Node, component: UnifiedInteractionComponent) -> void:
	var interactable = target as InteractableComponent
	component.interactable_detected.emit(interactable)
	
	if interactable.has_method("on_looked_at"):
		interactable.on_looked_at()
	
	var prompt = interactable.get_interaction_prompt()
	var alt_prompt = ""
	if interactable.has_alternative_interaction:
		alt_prompt = "Hold: " + interactable.alt_interaction_prompt
	
	component._update_ui(prompt, alt_prompt, "")

func clear_interactable_target(target: Node) -> void:
	var interactable = target as InteractableComponent
	if interactable and interactable.has_method("on_look_away"):
		interactable.on_look_away()

# ============================================================================
# INTERACTION ACTIONS
# ============================================================================
func interact_with(interactable: InteractableComponent) -> void:
	if not interactable or not main_component:
		return
	
	if interactable.can_interact():
		var actor = main_component.player if main_component.player else main_component
		interactable.interact(actor)
	else:
		main_component.interaction_failed.emit(interactable.get_blocked_prompt())

func alt_interact_with(interactable: InteractableComponent) -> void:
	if not interactable or not main_component:
		return
	
	var actor = main_component.player if main_component.player else main_component
	
	if interactable.has_method("alt_interact"):
		interactable.alt_interact(actor)
	else:
		interactable.interact(actor)