class_name StateMachine
extends Node

@export var initial_state: State
@export var player: CharacterBody3D
var current_state: State
var previous_state: State  # <-- new variable to track previous state
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
    
    # Save the current state as previous before switching
    previous_state = current_state
    
    current_state = new_state
    current_state.enter()
    
    # Debug output
    print("Transitioned to: ", current_state.name, " (from: ", previous_state.name if previous_state else "None", ")")

func get_state(state_name: String) -> State:
    return states.get(state_name.to_lower())

# Optional helper to go back to previous state
func revert_to_previous_state():
    if previous_state:
        transition_to(previous_state)
