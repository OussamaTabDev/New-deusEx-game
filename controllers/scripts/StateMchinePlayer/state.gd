class_name State
extends Node

# Reference to the player
var player: CharacterBody3D
var state_machine: StateMachine
var CAMERA_CONTROLLER: CameraController
var movement_stats_provider : MovementStatsProvider

@export_group("Weapon Permissions")
@export var can_shoot: bool = true
@export var can_reload: bool = true
@export var hide_weapon: bool = false
@export var weapon_bob_multiplier: float = 1.0
@export var weapon_offset: Vector3 = Vector3.ZERO # For lowering gun while sprinting

func _ready():
	# Wait for state machine to be ready
	await owner.ready
	state_machine = get_parent()
	player = state_machine.player
	CAMERA_CONTROLLER = player.CAMERA_CONTROLLER
	movement_stats_provider = state_machine.movement_stats_provider

# Called when entering the state
func enter() -> void:
	pass

# Called when exiting the state
func exit() -> void:
	pass

# Called every frame (replaces _process)
func update(delta: float) -> void:
	pass

# Called every physics frame (replaces _physics_process)
func physics_update(delta: float) -> void:
	pass

# Returns the next state to transition to, or null to stay in current state
func check_transitions() -> State:
	return null