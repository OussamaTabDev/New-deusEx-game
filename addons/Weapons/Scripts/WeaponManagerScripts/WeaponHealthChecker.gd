# WeaponHealthChecker.gd - Checks if player can use weapons based on limb health

extends Node
class_name WeaponHealthChecker

var combat_health: CombatHealthComponent
var hud: CanvasLayer


func can_equip_weapon() -> bool:
    """Check if player's right arm is healthy enough to use weapons"""
    if not combat_health:
        return true  # No health system = allow everything
    
    return combat_health.can_equip_weapon()


func show_arm_damaged_message():
    """Display message about damaged arm"""
    if hud and hud.has_method("show_message"):
        hud.show_message("⚠️ Right arm too damaged to use weapons!")
    else:
        print("⚠️ RIGHT ARM TOO DAMAGED - HEAL TO 5%+ TO USE WEAPONS")


func get_weapon_restriction_status() -> String:
    """Get current weapon restriction status message"""
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


func show_restriction_if_needed():
    """Show restriction message in HUD if needed"""
    var restriction = get_weapon_restriction_status()
    if restriction != "" and hud and hud.has_method("show_restriction"):
        hud.show_restriction(restriction)
