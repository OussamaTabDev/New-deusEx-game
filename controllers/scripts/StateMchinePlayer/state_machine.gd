class_name StateMachine
extends Node

@export var initial_state: State
@export var player: CharacterBody3D
@export var movement_stats_provider: Node # Generic
@export var injury_effects: MovementInjuryEffects # Reference to the script above

var current_state: State
var previous_state: State
var states: Dictionary = {}

func _ready():
    await owner.ready
    for child in get_children():
        if child is State:
            print(child.name)
            states[child.name.to_lower()] = child
            # Optional: Inject dependencies into states automatically
            if "player" in child: child.player = player
            if "injury_effects" in child: child.injury_effects = injury_effects

    if initial_state:
        current_state = initial_state
        current_state.enter()

func _process(delta: float):
    if current_state:
        current_state.update(delta)

func _physics_process(delta: float):
    if current_state:
        current_state.physics_update(delta)
        
        var next_state = current_state.check_transitions()
        if next_state and next_state != current_state:
            transition_to(next_state)

## Standard transition request (Subject to Injury Guards)
func transition_to(new_state: State):
    if not new_state: return
    
    # 1. ASK THE INJURY SYSTEM FOR PERMISSION
    if injury_effects:
        var can_enter = injury_effects.can_enter_state(new_state.name)
        
        if not can_enter:
            # The injury system says NO. 
            # Check if it suggests a "Degraded" version (e.g. Sprint -> Walk)
            var fallback_name = injury_effects.get_fallback_state(new_state.name)
            var fallback_state = get_state(fallback_name)
            
            if fallback_state:
                print("Injury System redirected ", new_state.name, " to ", fallback_state.name)
                new_state = fallback_state
            else:
                # No fallback provided, simply abort the transition.
                # The player stays in their current state.
                return

    # 2. EXECUTE TRANSITION
    _execute_transition(new_state)

## Forces a switch ignoring standard checks (Called by InjurySystem when leg breaks mid-run)
func force_transition(state_name: String):
    var target = get_state(state_name)
    if target and target != current_state:
        print("Forced Injury Transition to: ", state_name)
        _execute_transition(target)

## Internal helper to actually swap the states
func _execute_transition(new_state: State):
    if current_state:
        current_state.exit()
    
    # TRICK: Add a physical "thud" when changing states
    if player.weapon_manager.animManager:
        player.weapon_manager.animManager.apply_impulse(Vector3(0, -0.05, 0), Vector3(0.05, 0, 0))
        
    previous_state = current_state
    current_state = new_state
    current_state.enter()

func get_current_state_name() -> String:
    return current_state.name if current_state else ""
    
func get_state(state_name: String) -> State:
    return states.get(state_name.to_lower())