class_name StateMachine
extends Node

@export var initial_state: State

var current_state: State
var states: Dictionary = {}

func _ready():
	# Wait for owner to be ready
	await owner.ready
	
	# Register all child states
	for child in get_children():
		if child is State:
			states[child.name.to_lower()] = child
	
	# Set initial state
	if initial_state:
		current_state = initial_state
		current_state.enter()

func _process(delta: float):
	if current_state:
		current_state.update(delta)

func _physics_process(delta: float):
	if current_state:
		current_state.physics_update(delta)
		
		# Check for state transitions
		var next_state = current_state.check_transitions()
		if next_state and next_state != current_state:
			transition_to(next_state)

func transition_to(new_state: State):
	if current_state:
		current_state.exit()
	
	current_state = new_state
	current_state.enter()
	
	# Debug output (optional, remove in production)
	print("Transitioned to: ", current_state.name)

func get_state(state_name: String) -> State:
	return states.get(state_name.to_lower())