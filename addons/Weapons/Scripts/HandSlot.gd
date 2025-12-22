extends Node
class_name HandSlot

## ============================================
## HAND SLOT - Represents a single hand (right or left)
## Inspired by Dishonored & Deathloop
## ============================================

signal item_equipped(item: WeaponResource)
signal item_unequipped(item: WeaponResource)
signal hand_blocked()
signal hand_unblocked()

enum HandType {
	RIGHT,
	LEFT
}

enum HandState {
	EMPTY,      # Nothing in hand
	OCCUPIED,   # Holding something
	BLOCKED,    # Blocked by other hand's two-handed weapon
	EQUIPPING,  # Animation playing
	UNEQUIPPING # Animation playing
}

## ============================================
## CORE PROPERTIES
## ============================================
@export var hand_type: HandType = HandType.RIGHT
var state: HandState = HandState.EMPTY

# Current item in this hand
var current_item: WeaponResource = null
var current_item_slot: WeaponSlot = null
var current_model: Node3D = null

# Timers for equip/unequip
var action_timer: float = 0.0
var is_action_in_progress: bool = false

## ============================================
## HELPER FUNCTIONS
## ============================================

func is_right_hand() -> bool:
	return hand_type == HandType.RIGHT

func is_left_hand() -> bool:
	return hand_type == HandType.LEFT

func is_empty() -> bool:
	return state == HandState.EMPTY

func is_occupied() -> bool:
	return state == HandState.OCCUPIED

func is_blocked() -> bool:
	return state == HandState.BLOCKED

func is_busy() -> bool:
	"""Check if hand is doing something (equipping/unequipping)"""
	return state in [HandState.EQUIPPING, HandState.UNEQUIPPING]

func get_hand_name() -> String:
	return "Right Hand" if is_right_hand() else "Left Hand"

## ============================================
## COMPATIBILITY CHECKS
## ============================================

func can_hold(item: WeaponResource) -> bool:
	"""Check if this hand can hold the given item"""
	if not item:
		return false
	
	# Check state
	if state == HandState.BLOCKED:
		return false
	
	if is_busy():
		return false
	
	# Check hand requirements
	match item.hand_requirement:
		WeaponResource.HandRequirement.ANY:
			return true  # Can go in any hand
		
		WeaponResource.HandRequirement.RIGHT_HAND:
			return is_right_hand()
		
		WeaponResource.HandRequirement.LEFT_HAND:
			return is_left_hand()
		
		WeaponResource.HandRequirement.DUAL:
			# Two-handed weapons can only go in right hand
			return is_right_hand()
		
		_:
			return false

## ============================================
## ITEM MANAGEMENT
## ============================================

func equip_item(item: WeaponResource, weapon_slot: WeaponSlot) -> bool:
	"""Equip an item in this hand"""
	if not can_hold(item):
		push_warning("%s cannot hold %s" % [get_hand_name(), item.weaponName])
		return false
	
	# If already holding something, unequip first
	if current_item:
		unequip_item()
		await item_unequipped
	
	current_item = item
	current_item_slot = weapon_slot
	current_model = weapon_slot.model
	
	# Start equip animation
	state = HandState.EQUIPPING
	is_action_in_progress = true
	action_timer = item.equipTime
	
	# Show model
	if current_model:
		current_model.visible = true
		
		# Set position based on hand
		if is_left_hand() and item.leftHandPosition.size() >= 2:
			current_model.position = item.leftHandPosition[0]
			current_model.rotation = item.leftHandPosition[1]
		else:
			current_model.position = item.position[0]
			current_model.rotation = item.position[1]
	
	return true

func finish_equip() -> void:
	"""Called when equip animation finishes"""
	state = HandState.OCCUPIED
	is_action_in_progress = false
	item_equipped.emit(current_item)

func unequip_item() -> void:
	"""Unequip current item"""
	if not current_item:
		return
	
	state = HandState.UNEQUIPPING
	is_action_in_progress = true
	action_timer = current_item.unequipTime

func finish_unequip() -> void:
	"""Called when unequip animation finishes"""
	if current_model:
		current_model.visible = false
	
	var old_item = current_item
	
	current_item = null
	current_item_slot = null
	current_model = null
	
	state = HandState.EMPTY
	is_action_in_progress = false
	
	item_unequipped.emit(old_item)

func block() -> void:
	"""Block this hand (called when other hand equips two-handed weapon)"""
	if state == HandState.BLOCKED:
		return
	
	# Unequip anything currently held
	if current_item:
		unequip_item()
		await item_unequipped
	
	state = HandState.BLOCKED
	hand_blocked.emit()

func unblock() -> void:
	"""Unblock this hand (called when other hand unequips two-handed weapon)"""
	if state != HandState.BLOCKED:
		return
	
	state = HandState.EMPTY
	hand_unblocked.emit()

func clear() -> void:
	"""Clear hand without animations (instant)"""
	if current_model:
		current_model.visible = false
	
	current_item = null
	current_item_slot = null
	current_model = null
	state = HandState.EMPTY
	is_action_in_progress = false

## ============================================
## PROCESS
## ============================================

func _process(delta: float) -> void:
	if not is_action_in_progress:
		return
	
	action_timer -= delta
	
	if action_timer <= 0:
		match state:
			HandState.EQUIPPING:
				finish_equip()
			HandState.UNEQUIPPING:
				finish_unequip()

## ============================================
## ACTION CHECKS
## ============================================

func can_shoot() -> bool:
	"""Check if this hand can shoot"""
	if not current_item:
		return false
	
	if state != HandState.OCCUPIED:
		return false
	
	if current_item.isShooting or current_item.isReloading:
		return false
	
	return true

func can_reload() -> bool:
	"""Check if this hand can reload"""
	if not current_item:
		return false
	
	if state != HandState.OCCUPIED:
		return false
	
	if not current_item.hasToReload:
		return false
	
	if current_item.isReloading:
		return false
	
	return true

func can_alt_fire() -> bool:
	"""Check if this hand can perform alt-fire"""
	if not current_item:
		return false
	
	if state != HandState.OCCUPIED:
		return false
	
	if not current_item.has_alt_fire():
		return false
	
	return true

## ============================================
## DEBUG
## ============================================

func get_state_string() -> String:
	"""Get readable state string"""
	match state:
		HandState.EMPTY:
			return "Empty"
		HandState.OCCUPIED:
			return "Occupied: %s" % (current_item.weaponName if current_item else "???")
		HandState.BLOCKED:
			return "Blocked"
		HandState.EQUIPPING:
			return "Equipping..."
		HandState.UNEQUIPPING:
			return "Unequipping..."
		_:
			return "Unknown"

func print_status() -> void:
	print("[%s] %s" % [get_hand_name(), get_state_string()])