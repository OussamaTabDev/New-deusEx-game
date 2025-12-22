# WeaponHealthChecker.gd - Monitors arm health and weapon restrictions
extends Node
class_name WeaponHealthChecker

var weapon_manager: WeaponManager
var combat_health: CombatHealthComponent
var hud: CanvasLayer

func can_equip_weapon() -> bool:
	"""Check if player can equip weapons based on arm health"""
	if not combat_health:
		return true  # No health system, allow everything
	
	return combat_health.can_equip_weapon()

func show_arm_damaged_message():
	"""Show message about damaged arm preventing weapon use"""
	if hud and hud.has_method("show_message"):
		hud.show_message("⚠️ Right arm too damaged to use weapons!")
	else:
		print("⚠️ RIGHT ARM TOO DAMAGED - HEAL TO 5%+ TO USE WEAPONS")

func get_restriction_status() -> String:
	"""Get current weapon restriction status for HUD"""
	if not combat_health or not combat_health.player_health:
		return ""
	
	var right_arm = combat_health.player_health.get_limb(LimbData.BodyPart.RIGHT_ARM)
	
	if right_arm.is_destroyed():
		return "⚠️ RIGHT ARM DESTROYED - CANNOT USE WEAPONS"
	elif right_arm.get_health_percent() < 0.3:
		return "⚠️ RIGHT ARM CRITICAL (%.0f%%) - HEAL TO 30%+ TO USE WEAPONS" % (right_arm.get_health_percent() * 100)
	elif right_arm.get_health_percent() < 0.5:
		return "⚠️ Right Arm Damaged (%.0f%%) - Reduced effectiveness" % (right_arm.get_health_percent() * 100)
	
	return ""

func check_health(delta: float):
	"""Continuously check if we can still use weapons"""
	if weapon_manager.cW != null:
		if not can_equip_weapon():
			print("⚠️ Right arm too damaged - dropping weapon!")
			weapon_manager.drop_current_weapon()
