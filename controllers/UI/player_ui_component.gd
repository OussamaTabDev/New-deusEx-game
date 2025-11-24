## PlayerUIComponent.gd
## Handles all UI-related functionality for the player including pause menu, 
## inventory, crosshair, and UI state management
class_name PlayerUIComponent
extends Node

## Emits when ESC/Menu input is pressed
signal menu_pressed(player_interaction_component)
## Emits when inventory toggle is requested
signal toggle_inventory_interface()
## Used to hide UI elements like crosshair when another interface is active
signal toggled_interface(is_showing_ui: bool)

## Reference to Pause menu node
@export var pause_menu: NodePath
## Reference to Player HUD node
@export var player_hud: NodePath
@export var player_interaction_component: PlayerInteractionComponent

## Flag to track if any UI is currently displayed
var is_showing_ui: bool = false
## Flag to track if movement is paused (for menus/dialogs)
var is_movement_paused: bool = false

var config = ConfigFile.new()


func _ready():
	_setup_pause_menu()


func _setup_pause_menu():
	if pause_menu:
		var pause_menu_node = get_node(pause_menu)
		if pause_menu_node:
			pause_menu_node.resume.connect(_on_pause_menu_resume)
			pause_menu_node.close_pause_menu()
	else:
		push_error("Player has no reference to pause menu.")


func _input(event):
	if event.is_action_pressed("menu"):
		_handle_menu_input()
	
	if event.is_action_pressed("inventory"):
		_handle_inventory_input()


func _handle_menu_input():
	if CogitoSceneManager.is_currently_loading:
		return
	
	# If external UI is open (Readables, Keypad, etc)
	if is_showing_ui:
		menu_pressed.emit(player_interaction_component)
		
		# If inventory is open, close it
		if _is_inventory_open():
			toggle_inventory_interface.emit()
	
	# If no UI is open and not paused, open pause menu
	elif not is_movement_paused and not _is_player_dead():
		if not _is_currently_tweening():
			pause_movement()
			_open_pause_menu()
		else:
			_send_hint("Wait until I'm seated or standing")


func _handle_inventory_input():
	if _is_player_dead():
		return
	
	# Only toggle inventory if no external UI is open OR if inventory itself is open
	if not is_showing_ui:
		toggle_inventory_interface.emit()
	elif is_showing_ui and _is_inventory_open():
		toggle_inventory_interface.emit()


func pause_movement():
	"""Pauses player movement and shows cursor if using keyboard/mouse"""
	if not is_movement_paused:
		is_movement_paused = true
		# Only show mouse cursor if input device is KBM
		if InputHelper.device_index == -1:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func resume_movement():
	"""Resumes player movement and captures cursor"""
	if is_movement_paused:
		is_movement_paused = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func toggle_ui_visibility(visible: bool):
	"""Toggle UI elements visibility (like crosshair)"""
	is_showing_ui = visible
	toggled_interface.emit(visible)


func _open_pause_menu():
	if pause_menu:
		get_node(pause_menu).open_pause_menu()


func _on_pause_menu_resume():
	"""Called when pause menu is closed"""
	_reload_options()
	resume_movement()


func _reload_options():
	"""Reload user options that may have changed while paused"""
	var err = config.load(OptionsConstants.config_file_name)
	if err == OK:
		print("Options reloaded successfully")
	else:
		push_warning("Failed to reload options: " + str(err))


# Helper methods that would need to be connected to parent player
func _is_inventory_open() -> bool:
	if player_hud:
		var hud = get_node(player_hud)
		if hud and hud.has_node("inventory_interface"):
			return hud.inventory_interface.is_inventory_open
	return false


func _is_player_dead() -> bool:
	# This would be set by the parent player
	return get_parent().is_dead if get_parent() else false


func _is_currently_tweening() -> bool:
	# This would be set by the parent player
	return get_parent().currently_tweening if get_parent() else false


func _send_hint(hint_text: String):
	if player_interaction_component:
		player_interaction_component.send_hint(null, hint_text)


func set_player_interaction_component(component: PlayerInteractionComponent):
	player_interaction_component = component
