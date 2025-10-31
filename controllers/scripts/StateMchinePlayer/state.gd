class_name State
extends Node

# Reference to the player
var player: CharacterBody3D
var state_machine: Node

func _ready():
	# Wait for state machine to be ready
	await owner.ready
	player = owner as CharacterBody3D
	state_machine = get_parent()

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