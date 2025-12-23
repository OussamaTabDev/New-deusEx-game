# WeaponInputHandler.gd - Handles all weapon-related input
extends Node
class_name WeaponInputHandler

var weapon_manager: WeaponManager
var switcher: WeaponSwitcher
var inventory_component: InventoryComponent
var interaction_raycast: RayCast3D

@export var shoot_action: String = "fire"
@export var shoot_alt_action: String = "fire_alt"
@export var reload_action: String = "reload"
@export var interact_action: String = "interact"
@export var throw_action: String = "throw"
@export var drop_key: String = "drop_weapon"

func handle_input(event: InputEvent):
	if not weapon_manager.canChangeWeapons:
		return
	
	# Handle F key press/release for unequip
	if event is InputEventKey and event.keycode == InputActions.get_action_key_number(interact_action):
		if event.pressed and not interaction_raycast.is_colliding():
			switcher.is_holding_f = true
			switcher.f_hold_duration = 0.0
		elif event.is_released():
			switcher.is_holding_f = false
			switcher.f_hold_duration = 0.0
	
	# Hotbar number keys (1-8)
	if event is InputEventKey and event.pressed:
		var slot = -1
		
		match event.keycode:
			KEY_1: slot = 0
			KEY_2: slot = 1
			KEY_3: slot = 2
			KEY_4: slot = 3
			KEY_5: slot = 4
			KEY_6: slot = 5
			KEY_7: slot = 6
			KEY_8: slot = 7
			KEY_9: slot = 8
			KEY_0: slot = 9
			
		
		if slot >= 0:
			switcher.switch_to_hotbar_slot(slot)
	
	# Mouse wheel scroll through hotbar
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				switcher.scroll_hotbar(-1)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				switcher.scroll_hotbar(1)
	
	# Re-equip on left click when unequipped
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT and weapon_manager.unequipped_weapon:
				switcher.ignore_next_shoot = true
				switcher.equip_previous_weapon()

func process_weapon_inputs():
	"""Process weapon inputs during gameplay"""
	
	# Check if able to use weapons before any input
	if not weapon_manager.health_checker.can_equip_weapon() and weapon_manager.cW != null:
		weapon_manager.drop_current_weapon()
		return
	
	if Input.is_action_just_pressed(drop_key):
		weapon_manager.drop_current_weapon()
	
	var current_state = weapon_manager.state_machine.current_state
	
	# Check State Permissions
	if not current_state.can_shoot:
		return
	
	if weapon_manager.cW:
		# Auto vs Semi-Auto input logic
		if weapon_manager.cW.canAutoShoot:
			if Input.is_action_pressed(shoot_action) and not switcher.ignore_next_shoot:
				weapon_manager.shootManager.shoot()
		else:
			if Input.is_action_just_pressed(shoot_action) and not switcher.ignore_next_shoot:
				weapon_manager.shootManager.shoot()
		
		if Input.is_action_just_pressed(reload_action):
			weapon_manager.reloadManager.reload()
