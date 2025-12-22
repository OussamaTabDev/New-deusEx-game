# CombatInputHandler.gd - Unified combat input system (UPDATED)

extends Node
class_name CombatInputHandler

# System references
var weapon_input_handler: WeaponInputHandler
var throwable_system: ThrowableSystem
var melee_system: MeleeSystem
var inventory_component: InventoryComponent
var state_machine: StateMachine
var weapon_manager: WeaponManager  # NEW: Direct reference to manager

# Input actions
@export_group("Combat Actions")
@export var fire_action: String = "fire"
@export var fire_alt_action: String = "fire_alt"
@export var reload_action: String = "reload"
@export var melee_action: String = "melee"
@export var throw_action: String = "throw"
@export var block_action: String = "block"

# State tracking
var is_throwing: bool = false


func _input(event: InputEvent):
	"""Route inputs to appropriate combat system"""
	
	# Get current equipment type from weapon manager
	var equipment_type = weapon_manager.get_current_equipment_type()
	
	# --- MELEE ATTACK INPUT ---
	if event.is_action_pressed(melee_action):
		_handle_melee_input(equipment_type)
	
	# --- THROW INPUT ---
	if event.is_action_pressed(throw_action):
		_handle_throw_start(equipment_type)
	
	if event.is_action_released(throw_action):
		_handle_throw_release()
	
	# --- BLOCK INPUT ---
	if event.is_action_pressed(block_action):
		_handle_block_start(equipment_type)
	
	if event.is_action_released(block_action):
		_handle_block_release(equipment_type)
	
	# --- ALT FIRE / HEAVY ATTACK ---
	if event.is_action_pressed(fire_alt_action):
		_handle_alt_fire(equipment_type)
	
	if event.is_action_released(fire_alt_action):
		_handle_alt_fire_release(equipment_type)


func _handle_melee_input(equipment_type: int):
	"""Handle melee attack input"""
	match equipment_type:
		weapon_manager.EquipmentType.RANGED:
			# Quick melee while holding gun
			print("Quick melee from ranged!")
			melee_system.attempt_light_attack()
		
		weapon_manager.EquipmentType.MELEE:
			# Standard melee attack
			print("Melee attack!")
			melee_system.attempt_light_attack()
		
		weapon_manager.EquipmentType.NONE:
			# Punch (unarmed)
			print("Unarmed punch!")
			melee_system.attempt_light_attack()
		
		weapon_manager.EquipmentType.THROWABLE:
			# Can't melee while preparing throwable
			pass


func _handle_throw_start(equipment_type: int):
	"""Start throw sequence"""
	# Don't throw if already throwing
	if is_throwing:
		return
	
	# Check if currently holding a throwable item
	if equipment_type == weapon_manager.EquipmentType.THROWABLE:
		# Already holding throwable, just start cooking
		if throwable_system.current_throwable:
			print("Starting throw for current throwable")
			throwable_system._start_grenade_cook()
			is_throwing = true
	else:
		# Check hotbar for throwables
		var throwable_data = _get_throwable_from_hotbar()
		
		if throwable_data.item:
			print("Found throwable in hotbar slot %d" % throwable_data.slot)
			throwable_system.start_throw(throwable_data.item, throwable_data.slot)
			is_throwing = true
		else:
			print("No throwable in hotbar!")


func _handle_throw_release():
	"""Release throw"""
	if is_throwing:
		print("Releasing throw!")
		throwable_system.release_throw()
		is_throwing = false


func _handle_block_start(equipment_type: int):
	"""Start blocking"""
	if equipment_type == weapon_manager.EquipmentType.MELEE:
		print("Start blocking")
		melee_system.start_block()


func _handle_block_release(equipment_type: int):
	"""Stop blocking"""
	if equipment_type == weapon_manager.EquipmentType.MELEE:
		print("Stop blocking")
		melee_system.stop_block()


func _handle_alt_fire(equipment_type: int):
	"""Handle alt fire / heavy attack"""
	match equipment_type:
		weapon_manager.EquipmentType.RANGED:
			# Alt fire for gun (scope, grenade launcher, etc.)
			# This is handled by weapon input handler
			pass
		
		weapon_manager.EquipmentType.MELEE:
			# Start heavy attack
			print("Start heavy attack charge")
			melee_system.attempt_heavy_attack()
		
		weapon_manager.EquipmentType.NONE:
			# Heavy punch (unarmed)
			print("Heavy unarmed attack")
			melee_system.attempt_heavy_attack()


func _handle_alt_fire_release(equipment_type: int):
	"""Release alt fire / heavy attack"""
	if equipment_type == weapon_manager.EquipmentType.MELEE or equipment_type == weapon_manager.EquipmentType.NONE:
		print("Release heavy attack")
		melee_system.release_heavy_attack()


func _get_throwable_from_hotbar() -> Dictionary:
	"""Find throwable item in hotbar"""
	if not inventory_component:
		return {"item": null, "slot": -1}
	
	for i in range(inventory_component.hotbar_slots):
		var item = inventory_component.hotbar[i]
		if item and throwable_system.is_item_throwable(item):
			return {"item": item, "slot": i}
	
	return {"item": null, "slot": -1}


func get_combat_state() -> Dictionary:
	"""Get current combat state for HUD/UI"""
	var equipment_type = weapon_manager.get_current_equipment_type() if weapon_manager else 0
	
	return {
		"equipment_type": equipment_type,
		"is_throwing": is_throwing,
		"is_meleeing": melee_system.is_attacking if melee_system else false,
		"is_blocking": melee_system.is_blocking if melee_system else false,
		"combo_count": melee_system.combo_count if melee_system else 0
	}
