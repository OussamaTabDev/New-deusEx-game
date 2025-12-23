# WeaponSwitcher.gd - Handles weapon switching and equipping
extends Node
class_name WeaponSwitcher

var weapon_manager: WeaponManager
var database: WeaponDatabase
var inventory_component: InventoryComponent
var anim_manager: Node3D
var anim_player: AnimationPlayer
var player: CharacterBody3D

var currentHotbarSlot: int = -1  # Current active hotbar slot
var is_holding_f: bool = false
var f_hold_duration: float = 0.0
const F_UNEQUIP_THRESHOLD: float = 0.3  # seconds

var ignore_next_shoot: bool = false

func _process(delta: float) -> void:
	# Process F key hold for unequipping
	process_f_hold(delta)

func switch_to_hotbar_slot(slot: int):
	"""Switch to weapon in specific hotbar slot"""
	
	# Check if able to equip weapons
	if not weapon_manager.health_checker.can_equip_weapon():
		print("❌ Cannot equip weapon - Right arm too damaged!")
		weapon_manager.health_checker.show_arm_damaged_message()
		return
	
	if not inventory_component:
		return
	
	if slot < 0 or slot >= inventory_component.hotbar_slots:
		return
	
	# Get item from hotbar
	var item = inventory_component.hotbar[slot]
	# Must be a weapon
	if not item or item.type != "weapon":
		print("No weapon in hotbar slot %d" % (slot + 1))
		return
	
	# Must have weapon_id attribute
	if not item.attributes.has("weapon_id"):
		return
	
	var weapon_id = int(item.attributes.weapon_id)
	
	# Check if weapon exists
	if not database.has_weapon(weapon_id):
		print("Weapon ID %d not found!" % weapon_id)
		return
	
	# Don't switch to same weapon
	if weapon_manager.cW and weapon_manager.cW.weaponId == weapon_id:
		return
	
	# Switch to this weapon
	if weapon_manager.cW:
		exit_weapon(weapon_id, slot)
	else:
		enter_weapon(weapon_id, slot)


func exit_weapon(nextWeaponId: int, nextSlot: int):
	"""Unequip current weapon based on WeaponResource.unequipTime"""
	var cW = weapon_manager.cW
	
	if nextWeaponId == cW.weaponId:
		return
	
	weapon_manager.pW = cW
	weapon_manager.canChangeWeapons = false
	weapon_manager.canUseWeapon = false
	weapon_manager.unequipped_weapon = true
	
	# Cancel current actions
	if cW.isShooting: cW.isShooting = false
	if cW.isReloading: cW.isReloading = false
	
	# Play Animation
	if cW.unequipAnimName != "":
		anim_manager.playAnimation("UnequipAnim%s" % cW.weaponName, cW.unequipAnimSpeed, false)
		if cW.unequipSound:
			weapon_manager.weapon_sound_management(cW.unequipSound, cW.unequipSoundSpeed)
	
	# Wait for the EXACT time defined in WeaponResource
	if cW.unequipTime > 0:
		await weapon_manager.get_tree().create_timer(cW.unequipTime).timeout
	
	# Hide current model
	if weapon_manager.cWModel:
		weapon_manager.cWModel.visible = false
	
	# Enter next weapon
	enter_weapon(nextWeaponId, nextSlot)

func enter_weapon(nextWeaponId: int, slot: int):
	"""Equip new weapon based on WeaponResource.equipTime"""
	
	# Check if physically able to equip weapons
	if not weapon_manager.health_checker.can_equip_weapon():
		print("❌ Cannot equip weapon - Right arm too damaged!")
		weapon_manager.canChangeWeapons = true
		return
	
	if player.is_graping():
		return
	
	# Load the new resource
	weapon_manager.cW = database.get_weapon(nextWeaponId)
	currentHotbarSlot = slot
	weapon_manager.cWModel = weapon_manager.cW.weaponSlot.model
	
	# Make Visible
	weapon_manager.cWModel.visible = true
	
	# Update Managers
	weapon_manager.shootManager.getCurrentWeapon(weapon_manager.cW)
	weapon_manager.reloadManager.getCurrentWeapon(weapon_manager.cW)
	anim_manager.getCurrentWeapon(weapon_manager.cW, weapon_manager.cWModel)
	
	# Play Sound & Animation
	if weapon_manager.cW.equipSound:
		weapon_manager.weapon_sound_management(weapon_manager.cW.equipSound, weapon_manager.cW.equipSoundSpeed)
	
	anim_player.playback_default_blend_time = weapon_manager.cW.animBlendTime
	
	if weapon_manager.cW.equipAnimName != "":
		anim_manager.playAnimation("EquipAnim%s" % weapon_manager.cW.weaponName, weapon_manager.cW.equipAnimSpeed, false)
	
	# Wait for the EXACT time defined in WeaponResource
	if weapon_manager.cW.equipTime > 0:
		await weapon_manager.get_tree().create_timer(weapon_manager.cW.equipTime).timeout
	
	# Enable control
	if not weapon_manager.cW: return 
	if weapon_manager.cW.isShooting: weapon_manager.cW.isShooting = false
	if weapon_manager.cW.isReloading: weapon_manager.cW.isReloading = false
	
	weapon_manager.unequipped_weapon = false
	weapon_manager.canUseWeapon = true
	weapon_manager.canChangeWeapons = true
	ignore_next_shoot = false
	
	print("Equipped: %s (Slot %d)" % [weapon_manager.cW.weaponName, slot + 1])

func equip_previous_weapon():
	"""Re-equip the previous weapon if available"""
	print("Re-equipping previous weapon...")
	
	if not weapon_manager.pW:
		return
	
	var weapon_id = weapon_manager.pW.weaponId
	for i in range(inventory_component.hotbar_slots):
		var item = inventory_component.hotbar[i]
		if item and item.type == "weapon" and item.attributes.get("weapon_id") == weapon_id:
			switch_to_hotbar_slot(i)
			return

func unequip_current_weapon():
	"""Unequips the current weapon and clears state"""
	if not weapon_manager.cW:
		return
	
	weapon_manager.pW = weapon_manager.cW
	weapon_manager.unequipped_weapon = true
	weapon_manager.canChangeWeapons = false
	weapon_manager.canUseWeapon = false
	
	# Cancel actions
	weapon_manager.cW.isShooting = false
	weapon_manager.cW.isReloading = false
	
	# Play unequip anim/sound
	if weapon_manager.cW.unequipAnimName != "":
		anim_manager.playAnimation("UnequipAnim%s" % weapon_manager.cW.weaponName, weapon_manager.cW.unequipAnimSpeed, false)
		if weapon_manager.cW.unequipSound:
			weapon_manager.weapon_sound_management(weapon_manager.cW.unequipSound, weapon_manager.cW.unequipSoundSpeed)
	
	# Wait for unequip time
	if weapon_manager.cW.unequipTime > 0:
		await weapon_manager.get_tree().create_timer(weapon_manager.cW.unequipTime).timeout
	
	# Hide model
	if weapon_manager.cWModel:
		weapon_manager.cWModel.visible = false
	
	# Clear references
	weapon_manager.cW = null
	weapon_manager.cWModel = null
	currentHotbarSlot = -1
	
	# Re-enable controls
	weapon_manager.canUseWeapon = true
	weapon_manager.canChangeWeapons = true
	
	print("Weapon unequipped (via F hold)")

func scroll_hotbar(direction: int):
	"""Scroll through hotbar slots"""
	if not inventory_component:
		return
	
	var start_slot = currentHotbarSlot if currentHotbarSlot >= 0 else 0
	var checked = 0
	var next_slot = start_slot
	
	# Find next occupied slot
	while checked < inventory_component.hotbar_slots:
		next_slot = (next_slot + direction) % inventory_component.hotbar_slots
		if next_slot < 0:
			next_slot = inventory_component.hotbar_slots - 1
		
		var item = inventory_component.hotbar[next_slot]
		if item and item.type == "weapon":
			switch_to_hotbar_slot(next_slot)
			return
		
		checked += 1
		if next_slot == start_slot:
			break

func process_f_hold(delta: float):
	"""Process F key hold for unequipping"""
	if is_holding_f and weapon_manager.cW != null:
		f_hold_duration += delta
		if f_hold_duration >= F_UNEQUIP_THRESHOLD and weapon_manager.canChangeWeapons:
			is_holding_f = false
			f_hold_duration = 0.0
			unequip_current_weapon()
	
	if player.is_graping():
		unequip_current_weapon()

func sync_hotbar_with_inventory(item: InventoryItem, hotbar_index: int):
	"""Sync hotbar changes from inventory UI to weapon manager"""
	if item and hotbar_index >= 0 :
		# Find weapon item in inventory
		var weapon_item = null
		for inv_item in inventory_component.get_all_items():
			if inv_item.type == "weapon" and inv_item.attributes.get("weapon_id") == item.attributes.get("weapon_id"):
				weapon_item = inv_item
				break
		
		if not weapon_item:
			print("Weapon not found in inventory!")
			return
		# Update currentHotbarSlot if needed
		if item == weapon_item:
			currentHotbarSlot = hotbar_index
