# WeaponInputHandler.gd - Handles all weapon input processing

extends Node
class_name WeaponInputHandler

var weapon_switcher: WeaponSwitcher
var weapon_drop_pickup: WeaponDropPickup
var weapon_health_checker: WeaponHealthChecker
var shootManager: ShootManager
var reloadManager: ReloadManager
var state_machine: StateMachine
var interaction_raycast: RayCast3D
var inventory_component: InventoryComponent

# Input actions
@export var shoot_action: String = "fire"
@export var shoot_alt_action: String = "fire_alt"
@export var reload_action: String = "reload"
@export var interact_action: String = "interact"
@export var throw_action: String = "throw"
@export var drop_key: String = "drop_weapon"

# Hold-to-unequip tracking
var is_holding_f: bool = false
var f_hold_duration: float = 0.0
const F_UNEQUIP_THRESHOLD: float = 0.3

# State references (updated by WeaponManager)
var cW = null
var unequipped_weapon: bool = false
var canChangeWeapons: bool = true
var canUseWeapon: bool = true


func handle_input(event: InputEvent, current_weapon, current_slot: int):
    """Process input events for weapon system"""
    
    # Handle F key for unequip
    if event is InputEventKey and event.keycode == InputActions.get_action_key_number(interact_action):
        if event.pressed and not interaction_raycast.is_colliding():
            is_holding_f = true
            f_hold_duration = 0.0
        elif event.is_released():
            is_holding_f = false
            f_hold_duration = 0.0
    
    # Hotbar number keys (1-8)
    if event is InputEventKey and event.pressed:
        var slot = _get_hotbar_slot_from_key(event.keycode)
        if slot >= 0:
            weapon_switcher.switch_to_hotbar_slot(slot, inventory_component, current_weapon, current_slot)
    
    # Mouse wheel scrolling
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            _scroll_hotbar(-1, current_slot)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            _scroll_hotbar(1, current_slot)
        elif event.button_index == MOUSE_BUTTON_LEFT and unequipped_weapon:
            # Re-equip on left click when unequipped
            var prev_slot = weapon_switcher.equip_previous_weapon(weapon_switcher.pW, inventory_component)
            if prev_slot >= 0:
                weapon_switcher.switch_to_hotbar_slot(prev_slot, inventory_component, current_weapon, current_slot)


func process_hold_unequip(delta: float):
    """Process hold F to unequip"""
    if is_holding_f and cW != null:
        f_hold_duration += delta
        if f_hold_duration >= F_UNEQUIP_THRESHOLD and canChangeWeapons:
            is_holding_f = false
            f_hold_duration = 0.0
            # Signal to unequip (WeaponManager handles this)


func process_weapon_inputs(ignore_next_shoot: bool):
    """Process weapon firing and reload inputs"""
    if not weapon_health_checker.can_equip_weapon() and cW != null:
        return
    
    # Drop weapon
    if Input.is_action_just_pressed(drop_key):
        weapon_drop_pickup.drop_current_weapon(cW, null, -1)
        return
    
    var current_state = state_machine.current_state
    
    # Check state permissions
    if not current_state.can_shoot:
        return
    
    if cW:
        # Auto vs Semi-Auto
        if cW.canAutoShoot:
            if Input.is_action_pressed(shoot_action) and not ignore_next_shoot:
                shootManager.shoot()
        else:
            if Input.is_action_just_pressed(shoot_action) and not ignore_next_shoot:
                shootManager.shoot()
        
        # Reload
        if Input.is_action_just_pressed(reload_action):
            reloadManager.reload()


func _get_hotbar_slot_from_key(keycode: int) -> int:
    """Convert keycode to hotbar slot number"""
    match keycode:
        KEY_1: return 0
        KEY_2: return 1
        KEY_3: return 2
        KEY_4: return 3
        KEY_5: return 4
        KEY_6: return 5
        KEY_7: return 6
        KEY_8: return 7
    return -1


func _scroll_hotbar(direction: int, current_slot: int):
    """Scroll through hotbar slots"""
    if not inventory_component:
        return
    
    var start_slot = current_slot if current_slot >= 0 else 0
    var checked = 0
    var next_slot = start_slot
    
    # Find next occupied slot
    while checked < inventory_component.hotbar_slots:
        next_slot = (next_slot + direction) % inventory_component.hotbar_slots
        if next_slot < 0:
            next_slot = inventory_component.hotbar_slots - 1
        
        var item = inventory_component.hotbar[next_slot]
        if item and item.type == "weapon":
            weapon_switcher.switch_to_hotbar_slot(next_slot, inventory_component, cW, current_slot)
            return
        
        checked += 1
        if next_slot == start_slot:
            break
