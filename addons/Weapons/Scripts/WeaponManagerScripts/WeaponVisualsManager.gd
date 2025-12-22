# WeaponVisualsManager.gd - Manages weapon visual effects and animations

extends Node
class_name WeaponVisualsManager

var camera: Camera3D
var weaponContainer: Node3D

# Juice variables
var default_fov: float = 75.0
var initial_container_pos: Vector3
var initial_container_rot: Vector3

# Procedural recoil
var procedural_recoil_pos: Vector3 = Vector3.ZERO
var procedural_recoil_rot: Vector3 = Vector3.ZERO

# State-based offset
var state_procedural_offset: Vector3 = Vector3.ZERO


func initialize():
    """Store default values for juice calculations"""
    if camera:
        default_fov = camera.fov
    
    if weaponContainer:
        initial_container_pos = weaponContainer.position
        initial_container_rot = weaponContainer.rotation


func process_weapon_juice(delta: float, state_machine: StateMachine):
    """Process all visual effects each frame"""
    
    # Update state-based offset
    var target_offset = Vector3.ZERO
    if state_machine.current_state:
        target_offset = state_machine.current_state.weapon_offset
    
    state_procedural_offset = state_procedural_offset.lerp(target_offset, delta * 10.0)
    
    # Weapon kickback (lerp back to zero)
    procedural_recoil_pos = procedural_recoil_pos.lerp(Vector3.ZERO, delta * 10.0)
    procedural_recoil_rot = procedural_recoil_rot.lerp(Vector3.ZERO, delta * 10.0)
    
    # Apply to weapon container
    if weaponContainer:
        weaponContainer.position = initial_container_pos + procedural_recoil_pos + state_procedural_offset
        weaponContainer.rotation = initial_container_rot + procedural_recoil_rot
    
    # FOV recovery
    if camera:
        camera.fov = lerp(camera.fov, default_fov, delta * 5.0)


func apply_visual_recoil(kick_back: float, kick_up: float):
    """Apply visual recoil kick to weapon"""
    procedural_recoil_pos.z += kick_back
    procedural_recoil_rot.x += kick_up
    procedural_recoil_rot.z += randf_range(-0.02, 0.02)
    
    # FOV punch
    if camera:
        camera.fov += 1.0


func reset_to_defaults():
    """Reset all visual effects to default"""
    procedural_recoil_pos = Vector3.ZERO
    procedural_recoil_rot = Vector3.ZERO
    state_procedural_offset = Vector3.ZERO
    
    if weaponContainer:
        weaponContainer.position = initial_container_pos
        weaponContainer.rotation = initial_container_rot
    
    if camera:
        camera.fov = default_fov
