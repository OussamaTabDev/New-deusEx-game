# MovementStatsProvider.gd
# Provides real-time, injury-aware movement parameters to state machine states

class_name MovementStatsProvider
extends Node

# Signals (optional, for debugging or external reactions)
signal speed_updated(walk: float, sprint: float, crouch: float)
signal jump_updated(jump_vel: float)

# Exposed calculated values — read-only from outside
var walk_speed: float = 0.0
var sprint_speed: float = 0.0
var crouch_speed: float = 0.0
var swim_speed: float = 0.0

var jump_velocity: float = 0.0
var speed_multiplier: float = 1.0

# References
@export var player: Player
@export var injury_effects: MovementInjuryEffects

func _ready():
	if not player:
		player = get_parent() as Player
		if not player:
			push_error("MovementStatsProvider: No Player found!")

func update_stats():
	if not player or not injury_effects:
		return

	# Get base speeds from player
	var base_walk = player.WALK_SPEED
	var base_sprint = player.SPRINT_SPEED
	var base_crouch = player.CROUCH_SPEED
	var base_swim_speed = player.SWIM_SPEED

	var base_jump = player.JUMP_VELOCITY

	# Apply injury effects multiplier
	var mult = injury_effects.get_speed_multiplier()
	
	walk_speed = base_walk * mult
	sprint_speed = base_sprint * mult
	crouch_speed = base_crouch * mult
	swim_speed = base_swim_speed * mult
	
	# Jump reduction based on leg health (you can refine this)
	var leg_health = injury_effects._leg_avg_health  # Access internal cache safely
	if leg_health < 0.6:
		var reduction = lerp(1.0, injury_effects.jump_height_reduction, 1.0 - (leg_health / 0.6))
		jump_velocity = base_jump * reduction
	else:
		jump_velocity = base_jump

	speed_multiplier = mult

	# Optional: emit signals
	speed_updated.emit(walk_speed, sprint_speed, crouch_speed)
	jump_updated.emit(jump_velocity)