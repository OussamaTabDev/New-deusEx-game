# WeaponVisualsManager.gd - Handles visual effects and weapon juice
extends Node
class_name WeaponVisualsManager

var weapon_manager: WeaponManager
var weapon_container: Node3D
var camera: Camera3D
var state_machine: StateMachine

@onready var audioManager: PackedScene = preload("../../../Misc/Scenes/AudioManagerScene.tscn")
@onready var bulletDecal: PackedScene = preload("../../../Weapons/Scenes/BulletDecalScene.tscn")

# Juice variables
var default_fov: float = 75.0
var initial_container_pos: Vector3
var initial_container_rot: Vector3

# Current "kick" amount
var procedural_recoil_pos: Vector3 = Vector3.ZERO
var procedural_recoil_rot: Vector3 = Vector3.ZERO
var state_procedural_offset: Vector3 = Vector3.ZERO

func _ready():
	# Store defaults for juice calculations
	if camera:
		default_fov = camera.fov
	if weapon_container:
		initial_container_pos = weapon_container.position
		initial_container_rot = weapon_container.rotation

func hide_all_weapons():
	"""Hide all weapon models"""
	if not weapon_manager or not weapon_manager.database:
		return
	
	for weapon_id in weapon_manager.database.get_all_weapons().keys():
		var weapon = weapon_manager.database.get_weapon(weapon_id)
		if weapon.weaponSlot and weapon.weaponSlot.model:
			weapon.weaponSlot.model.visible = false

func process_weapon_juice(delta: float):
	"""Process procedural animation and visual feedback"""
	var target_offset = Vector3.ZERO
	if state_machine.current_state:
		target_offset = state_machine.current_state.weapon_offset
	
	state_procedural_offset = state_procedural_offset.lerp(target_offset, delta * 10.0)
	
	# Weapon Kickback (Lerp back to zero)
	procedural_recoil_pos = procedural_recoil_pos.lerp(Vector3.ZERO, delta * 10.0)
	procedural_recoil_rot = procedural_recoil_rot.lerp(Vector3.ZERO, delta * 10.0)
	
	# Apply to the Weapon Container
	weapon_container.position = initial_container_pos + procedural_recoil_pos
	weapon_container.rotation = initial_container_rot + procedural_recoil_rot
	
	# FOV Recovery
	if camera:
		camera.fov = lerp(camera.fov, default_fov, delta * 5.0)

func apply_visual_recoil(kick_back: float, kick_up: float):
	"""Apply visual recoil to weapon"""
	procedural_recoil_pos.z += kick_back
	procedural_recoil_rot.x += kick_up
	procedural_recoil_rot.z += randf_range(-0.02, 0.02)
	
	if camera:
		camera.fov += 1.0

func display_muzzle_flash():
	"""Display muzzle flash effect"""
	if not weapon_manager.cW or weapon_manager.cW.muzzleFlashRef == null:
		return
	
	var muzzleFlashInstance = weapon_manager.cW.muzzleFlashRef.instantiate()
	weapon_manager.add_child(muzzleFlashInstance)
	muzzleFlashInstance.global_position = weapon_manager.cW.weaponSlot.muzzleFlashSpawner.global_position
	muzzleFlashInstance.layers = 5
	muzzleFlashInstance.emitting = true

func display_bullet_hole(colliderPoint: Vector3, colliderNormal: Vector3, collider: Object):
	"""Display bullet hole decal"""
	var bulletDecalInstance = bulletDecal.instantiate()
	if collider is Node3D:
		bulletDecalInstance.scale /= collider.scale
		collider.add_child(bulletDecalInstance)
	else:
		weapon_manager.get_tree().get_root().add_child(bulletDecalInstance)
	bulletDecalInstance.global_position = colliderPoint
	bulletDecalInstance.look_at(colliderPoint - colliderNormal, Vector3.UP)
	bulletDecalInstance.rotate_object_local(Vector3(1.0, 0.0, 0.0), 90)

func weapon_sound_management(soundName: AudioStream, soundSpeed: float):
	"""Play weapon sound with randomized pitch"""
	var audioIns: AudioStreamPlayer3D = audioManager.instantiate()
	weapon_manager.get_tree().get_root().add_child.call_deferred(audioIns)
	await weapon_manager.get_tree().process_frame
	
	if audioIns.is_inside_tree():
		audioIns.global_transform = weapon_manager.cW.weaponSlot.attackPoint.global_transform
		audioIns.bus = "Sfx"
		var random_pitch = randf_range(0.95, 1.05)
		audioIns.pitch_scale = soundSpeed * random_pitch
		audioIns.stream = soundName
		audioIns.play()
