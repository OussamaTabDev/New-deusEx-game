# ============================================================================
# IMMERSIVE DOOR COMPONENT (Tween + Collision + Lock)
# ============================================================================
class_name DoorInteractable
extends InteractableComponent

# --- Tween & Physics Settings ---
@export_group("Door Movement")
@export var open_angle: float = 90.0
@export var duration: float = 0.6
@export var push_force: float = 1.0 # Multiplier for opening speed/feel

@export_group("Door Logic")
@export var auto_close: bool = true
@export var auto_close_delay: float = 3.0

@export_group("Door Sounds")
@export var open_sound: AudioStreamPlayer3D
@export var close_sound: AudioStreamPlayer3D


@export_group("Lock System")
@export var can_be_locked: bool = false
@export var starts_locked: bool = false
@export var lock_sound: AudioStreamPlayer3D

# --- References ---
# Assumes structure: Root -> Door (StaticBody) -> CollisionShape3D
var door_body: Node3D 
var collision_shape: CollisionShape3D 

# --- State ---
enum DoorState { CLOSED, OPENING, OPEN, CLOSING }
var current_state: DoorState = DoorState.CLOSED
var is_locked: bool = false
var auto_close_timer: float = 0.0

func _ready() -> void:
	super._ready()
	door_body = get_parent()
	collision_shape =  $CollisionShape3D
	interaction_prompt = "Open Door"
	
	# Setup alternative interaction for locking
	if can_be_locked:
		has_alternative_interaction = true
		alt_interaction_prompt = "Lock Door" if not starts_locked else "Unlock Door"
		is_locked = starts_locked
		
	# Ensure interaction prompt is correct at start
	if is_locked:
		interaction_prompt = "Locked"

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	
	# Auto-close logic
	if auto_close and current_state == DoorState.OPEN and not is_locked:
		auto_close_timer -= delta
		if auto_close_timer <= 0:
			_close_door()

func _perform_interaction(player: Node) -> void:
	if is_locked:
		print("Door is locked!")
		if lock_sound:
			lock_sound.play()
		return
	
	match current_state:
		DoorState.CLOSED:
			_open_door(player) # Pass player to calculate direction
		DoorState.OPEN:
			_close_door()
		_:
			pass  # Ignore if animating

func _perform_alt_interaction(player: Node) -> void:
	# Toggle lock state
	is_locked = !is_locked
	
	if lock_sound:
		lock_sound.play()
	
	# Update prompts
	alt_interaction_prompt = "Unlock Door" if is_locked else "Lock Door"
	interaction_prompt = "Locked" if is_locked else "Open Door"
	
	print("Door %s" % ("locked" if is_locked else "unlocked"))

func _open_door(player_node: Node = null) -> void:
	current_state = DoorState.OPENING

	var direction = 1.0
	if player_node:
		var local_pos = to_local(player_node.global_position)
		if local_pos.z > 0:
			direction = -1.0
	
	var target_rot = -1 * open_angle * direction

	if open_sound:
		open_sound.play()

	await _run_door_tween(target_rot)

	current_state = DoorState.OPEN
	auto_close_timer = auto_close_delay
	interaction_prompt = "Close Door"


func _close_door() -> void:
	current_state = DoorState.CLOSING
	
	if close_sound:
		close_sound.play()

	# --- 1. Animate back to 0 ---
	await _run_door_tween(0.0)

	# --- 2. Finish ---
	current_state = DoorState.CLOSED
	interaction_prompt = "Open Door" if not is_locked else "Locked"

# Helper function to handle the heavy lifting
func _run_door_tween(target_rot_y: float) -> void:
	# Disable collision to prevent physics glitches while moving
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(door_body, "rotation_degrees:y", target_rot_y, duration)
	
	await tween.finished
	
	# Re-enable collision
	if collision_shape:
		collision_shape.set_deferred("disabled", false)

func _can_interact_custom() -> bool:
	# Can only interact when fully open or closed (not during animation)
	return (current_state == DoorState.OPEN or current_state == DoorState.CLOSED)

func _can_alt_interact_custom() -> bool:
	# Can only lock/unlock when door is closed
	return can_be_locked and current_state == DoorState.CLOSED

func get_blocked_prompt() -> String:
	if is_locked:
		return "Locked"
	if current_state == DoorState.OPENING:
		return "Opening..."
	elif current_state == DoorState.CLOSING:
		return "Closing..."
	return super.get_blocked_prompt()