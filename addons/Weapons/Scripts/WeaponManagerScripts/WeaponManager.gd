# WeaponManager.gd - Main Coordinator
extends Node3D
class_name WeaponManager

# Core components
@onready var database: WeaponDatabase = $WeaponDatabase
@onready var switcher: WeaponSwitcher = $WeaponSwitcher
@onready var input_handler: WeaponInputHandler = $WeaponInputHandler
@onready var visuals: WeaponVisualsManager = $WeaponVisualsManager
@onready var drop_pickup: WeaponDropPickup = $WeaponDropPickup
@onready var health_checker: WeaponHealthChecker = $WeaponHealthChecker

# External managers (already existing)
@export var shootManager: ShootManager
@export var reloadManager: ReloadManager
@export var ammoManager: AmmunitionManager
@export var animManager: Node3D

# Node references
@export var player: CharacterBody3D
@export var state_machine: StateMachine
@export var cameraHolder: CameraController
@export var cameraRecoilHolder: Node3D
@export var camera: Camera3D
@export var weaponContainer: Node3D
@export var animPlayer: AnimationPlayer
@export var hud: CanvasLayer
@export var linkComponent: Node3D
@export var combat_health: CombatHealthComponent
@export var interaction_raycast: RayCast3D
@export var inventory_component: InventoryComponent

# Preloaded scenes
@onready var audioManager: PackedScene = preload("../../../Misc/Scenes/AudioManagerScene.tscn")
@onready var bulletDecal: PackedScene = preload("../../../Weapons/Scenes/BulletDecalScene.tscn")

# State
var cW = null  # Current weapon
var pW = null  # Previous weapon
var cWModel = null
var canChangeWeapons: bool = true
var canUseWeapon: bool = true
var unequipped_weapon: bool = false

func _ready():
	initialize_components()
	setup_connections()
	database.initialize()
	visuals.hide_all_weapons()

func initialize_components():
	# Pass references to all components
	database.weapon_container = weaponContainer
	
	switcher.weapon_manager = self
	switcher.database = database
	switcher.inventory_component = inventory_component
	switcher.anim_manager = animManager
	switcher.anim_player = animPlayer
	switcher.player = player
	
	input_handler.weapon_manager = self
	input_handler.switcher = switcher
	input_handler.inventory_component = inventory_component
	input_handler.interaction_raycast = interaction_raycast
	
	visuals.weapon_manager = self
	visuals.weapon_container = weaponContainer
	visuals.camera = camera
	visuals.state_machine = state_machine
	
	drop_pickup.weapon_manager = self
	drop_pickup.database = database
	drop_pickup.inventory_component = inventory_component
	drop_pickup.player = player
	
	health_checker.weapon_manager = self
	health_checker.combat_health = combat_health
	health_checker.hud = hud
	
	# Link inventory to ammo manager
	if inventory_component and ammoManager:
		ammoManager.inventory_component = inventory_component

func setup_connections():
	if inventory_component:
		inventory_component.hotbar_item_used.connect(_on_hotbar_used)

func _input(event):
	input_handler.handle_input(event)

func _process(delta: float):
	health_checker.check_health(delta)
	visuals.process_weapon_juice(delta)
	
	if cW != null and cWModel != null and canUseWeapon:
		input_handler.process_weapon_inputs()
		reloadManager.autoReload()
	
	if hud != null:
		display_stats()

func _on_hotbar_used(slot: int, item: InventoryItem):
	if item.type == "weapon":
		switcher.switch_to_hotbar_slot(slot)
	elif item.type == "consumable":
		use_consumable(item)

func display_stats():
	if not cW:
		hud.displayWeaponName("No Weapon")
		hud.displayTotalAmmoInMag(0, 1)
		hud.displayTotalAmmo(0, 1)
		
		var restriction = health_checker.get_restriction_status()
		if restriction != "" and hud.has_method("show_restriction"):
			hud.show_restriction(restriction)
		return
	
	hud.displayWeaponName(cW.weaponName)
	hud.displayTotalAmmoInMag(cW.totalAmmoInMag, cW.nbProjShotsAtSameTime)
	
	var total_ammo = ammoManager.get_ammo_count(cW.ammoType)
	hud.displayTotalAmmo(total_ammo, cW.nbProjShotsAtSameTime)
	
	var restriction = health_checker.get_restriction_status()
	if restriction != "" and hud.has_method("show_restriction"):
		hud.show_restriction(restriction)

func use_consumable(item: InventoryItem):
	if item.attributes.has("heal_amount"):
		var heal = item.attributes.heal_amount
		if player.has_method("heal"):
			player.heal(heal)
		print("Healed %d HP" % heal)
	
	if item.attributes.has("stamina_amount"):
		var stamina = item.attributes.stamina_amount
		if player.has_method("restore_stamina"):
			player.restore_stamina(stamina)
	
	item.stack_count -= 1
	if item.stack_count <= 0:
		inventory_component.remove_item(item)

# Public API methods
func display_muzzle_flash():
	visuals.display_muzzle_flash()

func display_bullet_hole(collider_point: Vector3, collider_normal: Vector3, collider: Object):
	visuals.display_bullet_hole(collider_point, collider_normal, collider)

func weapon_sound_management(sound_name: AudioStream, sound_speed: float):
	visuals.weapon_sound_management(sound_name, sound_speed)

func apply_visual_recoil(kick_back: float, kick_up: float):
	visuals.apply_visual_recoil(kick_back, kick_up)

func pickup_weapon(weapon_id: int) -> bool:
	return drop_pickup.pickup_weapon(weapon_id)

func pickup_ammo(ammo_type: String, amount: int) -> bool:
	if not ammoManager:
		return false
	return ammoManager.add_ammo(ammo_type, amount)

func attempt_pickup_unique(weapon_id: int) -> bool:
	return drop_pickup.attempt_pickup_unique(weapon_id)

func drop_current_weapon():
	drop_pickup.drop_current_weapon()

func weaponSoundManagement(soundName : AudioStream, soundSpeed : float):
	var audioIns : AudioStreamPlayer3D = audioManager.instantiate()
	get_tree().get_root().add_child.call_deferred(audioIns)
	await get_tree().process_frame
	
	if audioIns.is_inside_tree():
		audioIns.global_transform = cW.weaponSlot.attackPoint.global_transform
		audioIns.bus = "Sfx"
		var random_pitch = randf_range(0.95, 1.05)
		audioIns.pitch_scale = soundSpeed * random_pitch
		audioIns.stream = soundName
		audioIns.play()
