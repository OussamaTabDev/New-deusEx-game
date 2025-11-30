extends Control

## Simple UI for displaying interaction prompts
## Connect this to PlayerInteractionComponent's signals

@onready var prompt_label: Label = $Panel/PromptLabel

func _ready() -> void:
	hide()
	
	# Find and connect to PlayerInteractionComponent
	var player_interaction = _find_player_interaction(get_tree().root)
	if player_interaction:
		player_interaction.interaction_prompt_changed.connect(_on_prompt_changed)

func _find_player_interaction(node: Node) -> PlayerInteractionComponent:
	if node is PlayerInteractionComponent:
		return node
	for child in node.get_children():
		var result = _find_player_interaction(child)
		if result:
			return result
	return null

func _on_prompt_changed(text: String, show: bool) -> void:
	if show and not text.is_empty():
		prompt_label.text = text
		show()
	else:
		hide()