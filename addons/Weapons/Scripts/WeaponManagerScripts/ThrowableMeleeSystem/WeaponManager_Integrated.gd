# # WeaponManager.gd - Main Coordinator with Melee & Throwable Integration
# extends Node3D
# class_name WeaponManager

# # Core weapon components
# @onready var database: WeaponDatabase = $WeaponDatabase
# @onready var switcher: WeaponSwitcher = $WeaponSwitcher
# @onready var input_handler: WeaponInputHandler = $WeaponInputHandler
# @onready var visuals: WeaponVisualsManager = $WeaponVisualsManager
# @onready var drop_pickup: WeaponDropPickup = $WeaponDropPickup
# @onready var health_checker: WeaponHealthChecker = $WeaponHealthChecker

# # NEW: Melee & Throwable components
# @onready var melee_system: MeleeSystem = $MeleeSystem
# @onready var throwable_system: ThrowableSystem = $ThrowableSystem
# @onready var melee_database: MeleeDatabase = $MeleeDatabase
# @onready var throwable_database: ThrowableDatabase = $ThrowableDatabase
# @onready var unified_combat: UnifiedCombatHandler = $UnifiedCombatHandler

# # External managers (already existing)
# @export var shootManager: ShootManager
# @export var reloadManager: ReloadManager
# @export var ammoManager: AmmunitionManager
# @export var animManager: Node3D

# # Node references
# @export var player: CharacterBody3D
# @export var state_machine: StateMachine
# @export var cameraHolder: CameraController
# @export var cameraRecoilHolder: Node3D
# @export var camera: Camera3D
# @export var weaponContainer: Node3D
# @export var animPlayer: AnimationPlayer
# @export var hud: CanvasLayer
# @export var linkComponent: Node3D
# @export var combat_health: CombatHealthComponent
# @export var interaction_raycast: RayCast3D
# @export var inventory_component: InventoryComponent
# @export var stamina_system: Node  # NEW: For melee stamina costs

# # Preloaded scenes
# @onready var audioManager: PackedScene = preload("../../Misc/Scenes/AudioManagerScene.tscn")
# @onready var bulletDecal: PackedScene = preload("../../Weapons/Scenes/BulletDecalScene.tscn")

# # State
# var cW = null  # Current weapon
# var pW = null  # Previous weapon
# var cWModel = null
# var canChangeWeapons: bool = true
# var canUseWeapon: bool = true
# var unequipped_weapon: bool = false

# func _ready():
# 	initialize_components()
# 	setup_connections()
# 	database.initialize()
# 	visuals.hide_all_weapons()

# func initialize_components():
# 	# Pass references to all components
# 	database.weapon_container = weaponContainer
	
# 	switcher.weapon_manager = self
# 	switcher.database = database
# 	switcher.inventory_component = inventory_component
# 	switcher.anim_manager = animManager
# 	switcher.anim_player = animPlayer
# 	switcher.player = player
	
# 	input_handler.weapon_manager = self
# 	input_handler.switcher = switcher
# 	input_handler.inventory_component = inventory_component
# 	input_handler.interaction_raycast = interaction_raycast
	
# 	visuals.weapon_manager = self
# 	visuals.weapon_container = weaponContainer
# 	visuals.camera = camera
# 	visuals.state_machine = state_machine
	
# 	drop_pickup.weapon_manager = self
# 	drop_pickup.database = database
# 	drop_pickup.inventory_component = inventory_component
# 	drop_pickup.player = player
	
# 	health_checker.weapon_manager = self
# 	health_checker.combat_health = combat_health
# 	health_checker.hud = hud
	
# 	# NEW: Initialize melee & throwable systems
# 	melee_system.weapon_manager = self
# 	melee_system.player = player
# 	melee_system.camera = camera
# 	melee_system.stamina_system = stamina_system
# 	melee_system.animation_player = animPlayer
	
# 	throwable_system.weapon_manager = self
# 	throwable_system.player = player
# 	throwable_system.camera = camera
# 	throwable_system.inventory_component = inventory_component
	
# 	# Initialize unified combat handler
# 	unified_combat.initialize(self, melee_system, throwable_system, switcher, inventory_component, player)
	
# 	# Link inventory to ammo manager
# 	if inventory_component and ammoManager:
# 		ammoManager.inventory_component = inventory_component

# func setup_connections():
# 	if inventory_component:
# 		inventory_component.hotbar_item_used.connect(_on_hotbar_used)

# func _input(event):
# 	input_handler.handle_input(event)

# func _process(delta: float):
# 	health_checker.check_health(delta)
# 	visuals.process_weapon_juice(delta)
	
# 	# Process appropriate combat system
# 	unified_combat.process_combat_input()
	
# 	# Auto reload for weapons only
# 	if unified_combat.current_combat_type == UnifiedCombatHandler.CombatType.WEAPON:
# 		if cW != null and cWModel != null and canUseWeapon:
# 			reloadManager.autoReload()
	
# 	if hud != null:
# 		display_stats()

# func _on_hotbar_used(slot: int, item: InventoryItem):
# 	"""Unified hotbar handling for weapons, melee, and throwables"""
# 	unified_combat.switch_to_hotbar_slot(slot)
	
# 	# Also handle consumables
# 	if item.type == "consumable":
# 		use_consumable(item)

# func display_stats():
# 	"""Display appropriate stats based on combat type"""
# 	match unified_combat.current_combat_type:
# 		UnifiedCombatHandler.CombatType.WEAPON:
# 			display_weapon_stats()
# 		UnifiedCombatHandler.CombatType.MELEE:
# 			display_melee_stats()
# 		UnifiedCombatHandler.CombatType.THROWABLE:
# 			display_throwable_stats()
# 		_:
# 			display_empty_stats()

# func display_weapon_stats():
# 	"""Display weapon stats"""
# 	if not cW:
# 		display_empty_stats()
# 		return
	
# 	hud.displayWeaponName(cW.weaponName)
# 	hud.displayTotalAmmoInMag(cW.totalAmmoInMag, cW.nbProjShotsAtSameTime)
	
# 	var total_ammo = ammoManager.get_ammo_count(cW.ammoType)
# 	hud.displayTotalAmmo(total_ammo, cW.nbProjShotsAtSameTime)
	
# 	var restriction = health_checker.get_restriction_status()
# 	if restriction != "" and hud.has_method("show_restriction"):
# 		hud.show_restriction(restriction)

# func display_melee_stats():
# 	"""Display melee weapon stats"""
# 	if not melee_system.current_melee:
# 		display_empty_stats()
# 		return
	
# 	var melee = melee_system.current_melee
# 	hud.displayWeaponName(melee.weapon_name)
	
# 	# Show combo counter
# 	if melee_system.combo_count > 0:
# 		if hud.has_method("show_combo"):
# 			hud.show_combo(melee_system.combo_count, melee.max_combo_hits)
	
# 	# Show charge progress
# 	if melee_system.is_charging and hud.has_method("show_charge"):
# 		var charge_percent = melee_system.charge_time / melee.max_charge_time
# 		hud.show_charge(charge_percent)
	
# 	# Show if blocking
# 	if melee_system.is_blocking and hud.has_method("show_status"):
# 		hud.show_status("BLOCKING")

# func display_throwable_stats():
# 	"""Display throwable stats"""
# 	if not throwable_system.current_throwable:
# 		display_empty_stats()
# 		return
	
# 	var throwable = throwable_system.current_throwable
	
# 	# Get count from inventory
# 	var count = 0
# 	for item in inventory_component.get_all_items():
# 		if item.type == "throwable" and item.attributes.get("throwable_id") == throwable.throwable_id:
# 			count = item.stack_count
# 			break
	
# 	hud.displayWeaponName("%s (x%d)" % [throwable.throwable_name, count])
	
# 	# Show cooking progress
# 	if throwable_system.is_cooking:
# 		if hud.has_method("show_cook_timer"):
# 			var remaining = throwable_system.get_remaining_fuse()
# 			hud.show_cook_timer(remaining)
		
# 		# Show trajectory preview is already handled by ThrowableSystem

# func display_empty_stats():
# 	"""Display empty/unarmed stats"""
# 	hud.displayWeaponName("Unarmed")
# 	hud.displayTotalAmmoInMag(0, 1)
# 	hud.displayTotalAmmo(0, 1)

# func use_consumable(item: InventoryItem):
# 	if item.attributes.has("heal_amount"):
# 		var heal = item.attributes.heal_amount
# 		if player.has_method("heal"):
# 			player.heal(heal)
# 		print("Healed %d HP" % heal)
	
# 	if item.attributes.has("stamina_amount"):
# 		var stamina = item.attributes.stamina_amount
# 		if player.has_method("restore_stamina"):
# 			player.restore_stamina(stamina)
	
# 	item.stack_count -= 1
# 	if item.stack_count <= 0:
# 		inventory_component.remove_item(item)

# # Public API methods
# func display_muzzle_flash():
# 	visuals.display_muzzle_flash()

# func display_bullet_hole(collider_point: Vector3, collider_normal: Vector3, collider: Object):
# 	visuals.display_bullet_hole(collider_point, collider_normal, collider)

# func weapon_sound_management(sound_name: AudioStream, sound_speed: float):
# 	visuals.weapon_sound_management(sound_name, sound_speed)

# func apply_visual_recoil(kick_back: float, kick_up: float):
# 	visuals.apply_visual_recoil(kick_back, kick_up)

# func pickup_weapon(weapon_id: int) -> bool:
# 	return drop_pickup.pickup_weapon(weapon_id)

# func pickup_ammo(ammo_type: String, amount: int) -> bool:
# 	if not ammoManager:
# 		return false
# 	return ammoManager.add_ammo(ammo_type, amount)

# func attempt_pickup_unique(weapon_id: int) -> bool:
# 	return drop_pickup.attempt_pickup_unique(weapon_id)

# func drop_current_weapon():
# 	drop_pickup.drop_current_weapon()

# # NEW: Get current combat type for external systems
# func get_combat_type() -> UnifiedCombatHandler.CombatType:
# 	return unified_combat.current_combat_type

# func is_using_melee() -> bool:
# 	return unified_combat.current_combat_type == UnifiedCombatHandler.CombatType.MELEE

# func is_using_throwable() -> bool:
# 	return unified_combat.current_combat_type == UnifiedCombatHandler.CombatType.THROWABLE
