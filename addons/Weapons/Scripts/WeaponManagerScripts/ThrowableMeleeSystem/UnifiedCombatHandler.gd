# UnifiedCombatHandler.gd - Manages switching between weapons, melee, and throwables
extends Node
class_name UnifiedCombatHandler

enum CombatType {
	NONE,
	WEAPON,
	MELEE,
	THROWABLE
}

var weapon_manager: WeaponManager
var melee_system: MeleeSystem
var throwable_system: ThrowableSystem
var weapon_switcher: WeaponSwitcher
var inventory_component: InventoryComponent
var player: CharacterBody3D

var current_combat_type: CombatType = CombatType.NONE
var current_hotbar_slot: int = -1

# Input actions
@export var primary_action: String = "fire"  # Shoot/Light Attack/Hold to Cook
@export var secondary_action: String = "fire_alt"  # Aim/Heavy Attack/Cancel
@export var reload_action: String = "reload"
@export var block_action: String = "block"  # Right click for melee block

func _ready():
	pass

func initialize(wm: WeaponManager, ms: MeleeSystem, ts: ThrowableSystem, ws: WeaponSwitcher, inv: InventoryComponent, plr: CharacterBody3D):
	"""Initialize with all systems"""
	weapon_manager = wm
	melee_system = ms
	throwable_system = ts
	weapon_switcher = ws
	inventory_component = inv
	player = plr

func switch_to_hotbar_slot(slot: int):
	"""Unified switching for any combat type"""
	if not inventory_component:
		return
	
	if slot < 0 or slot >= inventory_component.hotbar_slots:
		return
	
	var item = inventory_component.hotbar[slot]
	if not item:
		print("Empty hotbar slot %d" % (slot + 1))
		return
	
	# Determine item type and switch
	match item.type:
		"weapon":
			switch_to_weapon(slot, item)
		"melee":
			switch_to_melee(slot, item)
		"throwable":
			switch_to_throwable(slot, item)
		_:
			print("Unknown item type: %s" % item.type)

func switch_to_weapon(slot: int, item: InventoryItem):
	"""Switch to firearm weapon"""
	if current_combat_type == CombatType.WEAPON:
		var current_weapon_id = weapon_manager.cW.weaponId if weapon_manager.cW else -1
		var new_weapon_id = int(item.attributes.weapon_id)
		if current_weapon_id == new_weapon_id:
			return  # Already equipped
	
	# Clear other systems
	clear_melee()
	clear_throwable()
	
	# Switch weapon via weapon switcher
	weapon_switcher.switch_to_hotbar_slot(slot)
	
	current_combat_type = CombatType.WEAPON
	current_hotbar_slot = slot
	print("Equipped weapon: %s" % item.display_name)

func switch_to_melee(slot: int, item: InventoryItem):
	"""Switch to melee weapon"""
	if not item.attributes.has("melee_id"):
		print("Item missing melee_id!")
		return
	
	var melee_id = int(item.attributes.melee_id)
	var melee_resource = get_melee_resource(melee_id)
	
	if not melee_resource:
		print("Melee resource %d not found!" % melee_id)
		return
	
	# Clear other systems
	clear_weapon()
	clear_throwable()
	
	# Equip melee
	var melee_model = spawn_melee_model(melee_resource)
	melee_system.set_current_melee(melee_resource, melee_model)
	
	current_combat_type = CombatType.MELEE
	current_hotbar_slot = slot
	print("Equipped melee: %s" % item.display_name)

func switch_to_throwable(slot: int, item: InventoryItem):
	"""Switch to throwable item"""
	if not item.attributes.has("throwable_id"):
		print("Item missing throwable_id!")
		return
	
	var throwable_id = int(item.attributes.throwable_id)
	var throwable_resource = get_throwable_resource(throwable_id)
	
	if not throwable_resource:
		print("Throwable resource %d not found!" % throwable_id)
		return
	
	# Check if we have any in inventory
	if item.stack_count <= 0:
		print("No %s remaining!" % item.display_name)
		return
	
	# Clear other systems
	clear_weapon()
	clear_melee()
	
	# Equip throwable
	var throwable_model = spawn_throwable_model(throwable_resource)
	throwable_system.set_current_throwable(throwable_resource, throwable_model)
	
	current_combat_type = CombatType.THROWABLE
	current_hotbar_slot = slot
	print("Equipped throwable: %s (x%d)" % [item.display_name, item.stack_count])

func clear_weapon():
	"""Clear equipped weapon"""
	if current_combat_type == CombatType.WEAPON and weapon_manager.cW:
		weapon_switcher.unequip_current_weapon()

func clear_melee():
	"""Clear equipped melee"""
	if current_combat_type == CombatType.MELEE:
		melee_system.clear_melee()

func clear_throwable():
	"""Clear equipped throwable"""
	if current_combat_type == CombatType.THROWABLE:
		throwable_system.clear_throwable()

func process_combat_input():
	"""Process input based on current combat type"""
	match current_combat_type:
		CombatType.WEAPON:
			process_weapon_input()
		CombatType.MELEE:
			process_melee_input()
		CombatType.THROWABLE:
			process_throwable_input()

func process_weapon_input():
	"""Handle weapon shooting"""
	if not weapon_manager.cW or not weapon_manager.canUseWeapon:
		return
	
	var current_state = weapon_manager.state_machine.current_state
	if not current_state.can_shoot:
		return
	
	# Shooting
	if weapon_manager.cW.canAutoShoot:
		if Input.is_action_pressed(primary_action):
			weapon_manager.shootManager.shoot()
	else:
		if Input.is_action_just_pressed(primary_action):
			weapon_manager.shootManager.shoot()
	
	# Reloading
	if Input.is_action_just_pressed(reload_action):
		weapon_manager.reloadManager.reload()

func process_melee_input():
	"""Handle melee attacks"""
	if not melee_system.current_melee:
		return
	
	var current_state = weapon_manager.state_machine.current_state
	if not current_state.can_shoot:
		return
	
	# Light attack
	if Input.is_action_just_pressed(primary_action):
		if melee_system.is_charging:
			melee_system.release_charged_attack()
		else:
			melee_system.light_attack()
	
	# Heavy attack / Charge
	if Input.is_action_pressed(secondary_action):
		if not melee_system.is_attacking and not melee_system.is_charging:
			melee_system.start_charge()
	
	if Input.is_action_just_released(secondary_action):
		if melee_system.is_charging:
			melee_system.release_charged_attack()
	
	# Blocking
	if Input.is_action_pressed(block_action):
		if not melee_system.is_blocking:
			melee_system.start_block()
	elif melee_system.is_blocking:
		melee_system.stop_block()

func process_throwable_input():
	"""Handle throwable cooking and throwing"""
	if not throwable_system.current_throwable:
		return
	
	var current_state = weapon_manager.state_machine.current_state
	if not current_state.can_shoot:
		return
	
	# Start cooking / instant throw
	if Input.is_action_just_pressed(primary_action):
		if not throwable_system.is_cooking:
			throwable_system.start_cooking()
	
	# Release throw
	if Input.is_action_just_released(primary_action):
		if throwable_system.is_cooking:
			throwable_system.release_throw()
	
	# Cancel
	if Input.is_action_just_pressed(secondary_action):
		if throwable_system.is_cooking:
			throwable_system.cancel_cooking()

func get_melee_resource(melee_id: int) -> MeleeWeaponResource:
	"""Get melee resource from database"""
	# You should create a MeleeDatabase similar to WeaponDatabase
	# For now, this is a placeholder
	if weapon_manager.has_node("MeleeDatabase"):
		return weapon_manager.get_node("MeleeDatabase").get_melee(melee_id)
	return null

func get_throwable_resource(throwable_id: int) -> ThrowableResource:
	"""Get throwable resource from database"""
	# You should create a ThrowableDatabase
	if weapon_manager.has_node("ThrowableDatabase"):
		return weapon_manager.get_node("ThrowableDatabase").get_throwable(throwable_id)
	return null

func spawn_melee_model(melee: MeleeWeaponResource) -> Node3D:
	"""Spawn melee weapon model in weapon container"""
	if not melee.weapon_scene:
		return null
	
	var model = melee.weapon_scene.instantiate()
	weapon_manager.weaponContainer.add_child(model)
	return model

func spawn_throwable_model(throwable: ThrowableResource) -> Node3D:
	"""Spawn throwable model in hand"""
	# For now, just return null
	# You can create a simple preview model later
	return null

func get_current_type_string() -> String:
	"""Get current combat type as string"""
	match current_combat_type:
		CombatType.WEAPON: return "Weapon"
		CombatType.MELEE: return "Melee"
		CombatType.THROWABLE: return "Throwable"
		_: return "Unarmed"
