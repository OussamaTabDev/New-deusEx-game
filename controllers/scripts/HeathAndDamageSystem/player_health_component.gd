class_name PlayerHealthComponent
extends HealthComponent

## Player-specific effects
signal screen_effect_triggered(effect_type: String, intensity: float)
signal movement_impaired(speed_multiplier: float)
signal aim_impaired(accuracy_multiplier: float)

@export var player: Player

## Effect modifiers (applied to player stats)
var speed_modifier: float = 1.0
var accuracy_modifier: float = 1.0
var reload_speed_modifier: float = 1.0
var melee_damage_modifier: float = 1.0

## Screen effects
var screen_blur_amount: float = 0.0
var screen_desaturation: float = 0.0
var heartbeat_intensity: float = 0.0


func _ready():
    super._ready()
    
    if not player:
        player = get_parent() as Player
    
    # Connect to signals for visual feedback
    limb_critical.connect(_on_limb_critical)
    limb_destroyed.connect(_on_limb_destroyed)
    state_changed.connect(_on_state_changed)

func _process(delta: float):
    #super._process(delta)
    _update_screen_effects(delta)
    
## Override limb effects for player
func _apply_limb_effects(limb: LimbData.Limb) -> void:
    _recalculate_all_effects()

func _recalculate_all_effects() -> void:
    # Reset modifiers
    speed_modifier = 1.0
    accuracy_modifier = 1.0
    reload_speed_modifier = 1.0
    melee_damage_modifier = 1.0
    screen_blur_amount = 0.0
    screen_desaturation = 0.0
    heartbeat_intensity = 0.0
    
    # Apply effects based on limb damage
    var head = get_limb(LimbData.BodyPart.HEAD)
    var torso = get_limb(LimbData.BodyPart.TORSO)
    var left_arm = get_limb(LimbData.BodyPart.LEFT_ARM)
    var right_arm = get_limb(LimbData.BodyPart.RIGHT_ARM)
    var left_leg = get_limb(LimbData.BodyPart.LEFT_LEG)
    var right_leg = get_limb(LimbData.BodyPart.RIGHT_LEG)
    
    # HEAD EFFECTS - Vision and consciousness
    if head.get_health_percent() < 0.5:
        screen_blur_amount = (1.0 - head.get_health_percent() * 2.0) * 0.5
    if head.get_health_percent() < 0.25:
        screen_desaturation = (1.0 - head.get_health_percent() * 4.0) * 0.6
    
    # TORSO EFFECTS - Stamina and vitality
    if torso.get_health_percent() < 0.5:
        heartbeat_intensity = 1.0 - torso.get_health_percent() * 2.0
    if torso.get_health_percent() < 0.3:
        speed_modifier *= 0.85
    if torso.get_health_percent() < 0.15:
        screen_desaturation = max(screen_desaturation, 0.8)
        heartbeat_intensity = 1.0
    
    # ARM EFFECTS - Combat effectiveness
    var arm_avg_health = (left_arm.get_health_percent() + right_arm.get_health_percent()) / 2.0
    if right_arm.get_health_percent() < 0.4:
        reload_speed_modifier *= 0.7
        accuracy_modifier *= 0.75
    if left_arm.get_health_percent() < 0.4:
        accuracy_modifier *= 0.8
    if right_arm.get_health_percent() < 0.2:
        melee_damage_modifier *= 0.6
    
    # LEG EFFECTS - Mobility
    var leg_avg_health = (left_leg.get_health_percent() + right_leg.get_health_percent()) / 2.0
    if left_leg.get_health_percent() < 0.4 or right_leg.get_health_percent() < 0.4:
        speed_modifier *= 0.7
    if left_leg.get_health_percent() < 0.25 or right_leg.get_health_percent() < 0.25:
        speed_modifier *= 0.5  # Severe limp
    if left_leg.is_destroyed() or right_leg.is_destroyed():
        speed_modifier *= 0.3  # Crawling speed
    
    # Apply modifiers to player
    _apply_modifiers_to_player()
    
    # Emit signals for UI/effects
    screen_effect_triggered.emit("blur", screen_blur_amount)
    screen_effect_triggered.emit("desaturation", screen_desaturation)
    screen_effect_triggered.emit("heartbeat", heartbeat_intensity)
    movement_impaired.emit(speed_modifier)
    aim_impaired.emit(accuracy_modifier)

func _apply_modifiers_to_player() -> void:
    if not player:
        return
    
    # Modify player movement speed
    player.SPEED = player.WALK_SPEED * speed_modifier
    
    # You can access camera controller for aim sway
    if player.CAMERA_CONTROLLER:
        # This would require adding aim_sway_multiplier to your camera controller
        # player.CAMERA_CONTROLLER.aim_sway_multiplier = accuracy_modifier
        pass

func _update_screen_effects(delta: float) -> void:
    # Smooth screen effects over time
    # You can implement post-processing here or emit to a separate effect manager
    pass

## Signal handlers
func _on_limb_critical(limb: LimbData.BodyPart) -> void:
    print("WARNING: %s is critically damaged!" % LimbData.get_limb_name(limb))
    # Play sound effect, show warning UI, etc.

func _on_limb_destroyed(limb: LimbData.BodyPart) -> void:
    print("CRITICAL: %s has been destroyed!" % LimbData.get_limb_name(limb))
    # Play critical sound, show dramatic effect

func _on_state_changed(new_state: CharacterState) -> void:
    match new_state:
        CharacterState.WOUNDED:
            print("Player is wounded")
        CharacterState.CRITICAL:
            print("Player is in critical condition!")
        CharacterState.NEAR_DEATH:
            print("Player is near death!")
        CharacterState.DEAD:
            _handle_player_death()

func _handle_player_death() -> void:
    if player:
        # Disable player controls
        player.set_physics_process(false)
        player.set_process_input(false)
        # You can trigger death animation, game over screen, etc.
        print("PLAYER DIED")

## Hitbox detection helper
func detect_hit_limb(hit_position: Vector3, hit_normal: Vector3) -> LimbData.BodyPart:
    if not player:
        return LimbData.BodyPart.TORSO  # Default
    
    # Get local hit position
    var local_hit = player.global_transform.inverse() * hit_position
    
    # Simple hitbox detection based on Y height and X/Z position
    # You can refine this based on your character model
    
    if local_hit.y > 1.5:  # Head height
        return LimbData.BodyPart.HEAD
    elif local_hit.y > 0.8:  # Torso height
        return LimbData.BodyPart.TORSO
    elif local_hit.y > 0.3:  # Arms/upper legs
        if abs(local_hit.x) > 0.2:  # Sides
            return LimbData.BodyPart.RIGHT_ARM if local_hit.x > 0 else LimbData.BodyPart.LEFT_ARM
        else:
            return LimbData.BodyPart.TORSO
    else:  # Lower legs
        return LimbData.BodyPart.RIGHT_LEG if local_hit.x > 0 else LimbData.BodyPart.LEFT_LEG

## Public API for damage from external sources
func take_damage(damage_amount: float, damage_type: DamageTypes.Type, hit_pos: Vector3 = Vector3.ZERO, source: Node = null) -> void:
    var limb = detect_hit_limb(hit_pos, Vector3.UP)
    
    var damage_info = DamageTypes.DamageInfo.new(damage_amount, damage_type, source)
    damage_info.hit_position = hit_pos
    
    apply_damage_to_limb(limb, damage_info)

## Getters for external systems
func get_speed_modifier() -> float:
    return speed_modifier

func get_accuracy_modifier() -> float:
    return accuracy_modifier

func get_reload_speed_modifier() -> float:
    return reload_speed_modifier

func can_sprint() -> bool:
    var left_leg = get_limb(LimbData.BodyPart.LEFT_LEG)
    var right_leg = get_limb(LimbData.BodyPart.RIGHT_LEG)
    return left_leg.get_health_percent() > 0.25 and right_leg.get_health_percent() > 0.25

func is_limping() -> bool:
    var left_leg = get_limb(LimbData.BodyPart.LEFT_LEG)
    var right_leg = get_limb(LimbData.BodyPart.RIGHT_LEG)
    return left_leg.get_health_percent() < 0.4 or right_leg.get_health_percent() < 0.4
