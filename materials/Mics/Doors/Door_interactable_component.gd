# ============================================================================
# IMMERSIVE SIM DOOR SYSTEM - Core Component
# ============================================================================
class_name DoorInteractable
extends InteractableComponent

# --- Door Type Selection ---
@export_enum("Standard", "Sliding", "Keypad", "Biometric", "Breakable") var door_type: String = "Standard"

# --- Movement Settings ---
@export_group("Door Movement")
@export var open_angle: float = 90.0
@export var slide_distance: float = 2.0
@export var duration: float = 0.6
@export var push_force: float = 1.0

@export_group("Door Logic")
@export var auto_close: bool = true
@export var auto_close_delay: float = 3.0
@export var can_be_forced: bool = true # Can be opened with enough force

# --- Health System ---
@export_group("Health & Destruction")
@export var has_health: bool = true
@export var max_health: float = 100.0
@export var destroyed_scene: PackedScene # Scene to spawn when destroyed
@export var apply_impact_force: bool = true
@export var explosion_force: float = 500.0
@export var destruction_delay: float = 0.1

# --- Visual Feedback ---
@export_group("Visual Effects")
@export var damage_material: Material # Overlay when damaged
@export var damage_threshold: float = 50.0 # When to show damage
@export var hit_particle: PackedScene # Particle effect on hit
@export var destroy_particle: PackedScene # Particle effect on destruction
@export var spark_particle: PackedScene # Electric sparks for keypad failures

# --- Audio ---
@export_group("Door Sounds")
@export var open_sound: AudioStreamPlayer3D
@export var close_sound: AudioStreamPlayer3D
@export var lock_sound: AudioStreamPlayer3D
@export var unlock_sound: AudioStreamPlayer3D
@export var denied_sound: AudioStreamPlayer3D
@export var hit_sound: AudioStreamPlayer3D
@export var break_sound: AudioStreamPlayer3D
@export var keypad_beep: AudioStreamPlayer3D
@export var keypad_error: AudioStreamPlayer3D

# --- Lock System ---
@export_group("Lock System")
@export var can_be_locked: bool = false
@export var starts_locked: bool = false
@export var lock_type: String = "key" # key, keypad, biometric
@export var required_key_id: String = "" # For key locks
@export var keypad_code: String = "1234" # For keypad locks
@export var authorized_ids: Array[String] = [] # For biometric

# --- Keypad System ---
@export_group("Keypad (0-9 Input)")
@export var keypad_enabled: bool = false
@export var keypad_max_digits: int = 4
@export var keypad_timeout: float = 5.0
@export var show_keypad_ui: bool = true

# --- References ---
@export var door_body: Node3D
@export var door_collision: CollisionShape3D
@export var mesh_instance: MeshInstance3D

# --- State ---
enum DoorState { CLOSED, OPENING, OPEN, CLOSING, DESTROYED }
var current_state: DoorState = DoorState.CLOSED
var is_locked: bool = false
var current_health: float = 100.0
var auto_close_timer: float = 0.0

# Keypad state
var keypad_input: String = ""
var keypad_timer: float = 0.0
var is_entering_code: bool = false

# Visual state
var original_material: Material
var is_damaged: bool = false

signal door_opened
signal door_closed
signal door_destroyed
signal door_damaged(amount: float)
signal code_entered(code: String, success: bool)

func _ready() -> void:
	super._ready()
	
	# Auto-detect references if not set
	if not door_body:
		door_body = get_parent()
	if not mesh_instance and door_body:
		mesh_instance = door_body.get_node_or_null("MeshInstance3D")
	
	# Store original material
	if mesh_instance and mesh_instance.get_surface_override_material_count() > 0:
		original_material = mesh_instance.get_surface_override_material(0)
	
	# Initialize health
	current_health = max_health
	
	# Setup interaction prompts
	_update_interaction_prompt()
	
	# Lock system setup
	if can_be_locked:
		has_alternative_interaction = true
		is_locked = starts_locked
		_update_alt_interaction_prompt()
	
	# Keypad setup
	if door_type == "Keypad" or keypad_enabled:
		keypad_enabled = true
		can_be_locked = true
		is_locked = starts_locked

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	
	# Auto-close logic
	if auto_close and current_state == DoorState.OPEN and not is_locked:
		auto_close_timer -= delta
		if auto_close_timer <= 0:
			_close_door()
	
	# Keypad timeout
	if is_entering_code:
		keypad_timer -= delta
		if keypad_timer <= 0:
			_reset_keypad()

func _unhandled_input(event: InputEvent) -> void:
	if not is_entering_code:
		return
	
	# Handle keypad number input (0-9)
	if event is InputEventKey and event.pressed:
		var key_code = event.keycode
		
		# Numbers 0-9
		if key_code >= KEY_0 and key_code <= KEY_9:
			var digit = str(key_code - KEY_0)
			_add_keypad_digit(digit)
		elif key_code >= KEY_KP_0 and key_code <= KEY_KP_9:
			var digit = str(key_code - KEY_KP_0)
			_add_keypad_digit(digit)
		elif key_code == KEY_ENTER or key_code == KEY_KP_ENTER:
			_submit_keypad_code()
		elif key_code == KEY_BACKSPACE:
			_remove_keypad_digit()
		elif key_code == KEY_ESCAPE:
			_reset_keypad()

func _perform_interaction(player: Node) -> void:
	if current_state == DoorState.DESTROYED:
		return
	
	# Check lock status
	if is_locked:
		# Try different unlock methods based on door type
		match door_type:
			"Keypad":
				_start_keypad_entry()
			"Biometric":
				_attempt_biometric_unlock(player)
			_:
				_play_denied_feedback()
		return
	
	# Standard door operation
	match current_state:
		DoorState.CLOSED:
			_open_door(player)
		DoorState.OPEN:
			_close_door()
		_:
			pass

func _perform_alt_interaction(player: Node) -> void:
	if current_state != DoorState.CLOSED or door_type == "Keypad":
		return
	
	# Toggle lock
	is_locked = !is_locked
	
	if is_locked and lock_sound:
		lock_sound.play()
	elif not is_locked and unlock_sound:
		unlock_sound.play()
	
	_update_interaction_prompt()
	_update_alt_interaction_prompt()

# --- Door Movement ---
func _open_door(player_node: Node = null) -> void:
	current_state = DoorState.OPENING
	
	if open_sound:
		open_sound.play()
	
	# Determine opening direction/method based on type
	match door_type:
		"Sliding":
			await _run_sliding_animation()
		_:
			var direction = _get_opening_direction(player_node)
			var target_rot = -1* open_angle * direction
			await _run_door_tween(target_rot)
	
	current_state = DoorState.OPEN
	auto_close_timer = auto_close_delay
	_update_interaction_prompt()
	door_opened.emit()

func _close_door() -> void:
	current_state = DoorState.CLOSING
	
	if close_sound:
		close_sound.play()
	
	match door_type:
		"Sliding":
			await _run_sliding_animation(true)
		_:
			await _run_door_tween(0.0)
	
	current_state = DoorState.CLOSED
	_update_interaction_prompt()
	door_closed.emit()

func _run_door_tween(target_rot_y: float) -> void:
	if door_collision:
		door_collision.set_deferred("disabled", true)
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(door_body, "rotation_degrees:y", target_rot_y, duration)
	
	await tween.finished
	
	if door_collision:
		door_collision.set_deferred("disabled", false)

func _run_sliding_animation(closing: bool = false) -> void:
	if door_collision:
		door_collision.set_deferred("disabled", true)
	
	var target_pos = Vector3.ZERO
	if not closing:
		target_pos = door_body.basis.x * slide_distance
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(door_body, "position", target_pos, duration)
	
	await tween.finished
	
	if door_collision:
		door_collision.set_deferred("disabled", false)

func _get_opening_direction(player_node: Node) -> float:
	if not player_node:
		return 1.0
	
	var local_pos = door_body.to_local(player_node.global_position)
	return -1.0 if local_pos.z > 0 else 1.0

# --- Health & Damage System ---
func take_damage(amount: float, impact_position: Vector3 = Vector3.ZERO, impact_force: Vector3 = Vector3.ZERO) -> void:
	if not has_health or current_state == DoorState.DESTROYED:
		return
	
	current_health -= amount
	door_damaged.emit(amount)
	
	# Visual feedback
	_spawn_hit_particle(impact_position)
	_apply_damage_overlay()
	
	if hit_sound:
		hit_sound.play()
	
	# Check for destruction
	if current_health <= 0:
		_destroy_door(impact_force)
	elif can_be_forced and current_health < damage_threshold and is_locked:
		# Force open if damaged enough
		is_locked = false
		_update_interaction_prompt()

func _destroy_door(impact_force: Vector3 = Vector3.ZERO) -> void:
	current_state = DoorState.DESTROYED
	
	if break_sound:
		break_sound.play()
	
	# Spawn destruction particles
	if destroy_particle:
		var particles = destroy_particle.instantiate()
		get_tree().current_scene.add_child(particles)
		particles.global_position = door_body.global_position
		particles.emitting = true
	
	# Wait a frame for physics to settle
	await get_tree().create_timer(destruction_delay).timeout
	
	# Spawn destroyed scene with rigidbodies
	if destroyed_scene:
		var destroyed_instance = destroyed_scene.instantiate()
		get_tree().current_scene.add_child(destroyed_instance)
		destroyed_instance.global_position = door_body.global_position
		destroyed_instance.global_rotation = door_body.global_rotation
		
		# Apply forces to all rigidbodies in the destroyed scene
		_apply_explosion_forces(destroyed_instance, impact_force)
	
	# Hide original door
	door_body.visible = false
	if door_collision:
		door_collision.set_deferred("disabled", true)
	
	door_destroyed.emit()

func _apply_explosion_forces(root: Node, impact_force: Vector3) -> void:
	if not apply_impact_force:
		return
	
	var rigidbodies = _get_all_rigidbodies(root)
	var center = door_body.global_position
	
	for rb in rigidbodies:
		if rb is RigidBody3D:
			var direction = (rb.global_position - center).normalized()
			var force = direction * explosion_force + impact_force
			rb.apply_central_impulse(force)
			# Add random spin
			rb.apply_torque_impulse(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * explosion_force * 0.1)

func _get_all_rigidbodies(node: Node) -> Array:
	var bodies = []
	if node is RigidBody3D:
		bodies.append(node)
	for child in node.get_children():
		bodies.append_array(_get_all_rigidbodies(child))
	return bodies

# --- Visual Effects ---
func _spawn_hit_particle(pos: Vector3) -> void:
	if not hit_particle:
		return
	
	var particles = hit_particle.instantiate()
	get_tree().current_scene.add_child(particles)
	particles.global_position = pos if pos != Vector3.ZERO else door_body.global_position
	particles.emitting = true

func _apply_damage_overlay() -> void:
	if is_damaged or not mesh_instance or not damage_material:
		return
	
	if current_health <= damage_threshold:
		is_damaged = true
		mesh_instance.set_surface_override_material(0, damage_material)

# --- Keypad System ---
func _start_keypad_entry() -> void:
	is_entering_code = true
	keypad_input = ""
	keypad_timer = keypad_timeout
	
	if show_keypad_ui:
		_show_keypad_ui()
	
	print("Enter code (0-9, Enter to submit, Esc to cancel)")

func _add_keypad_digit(digit: String) -> void:
	if keypad_input.length() >= keypad_max_digits:
		return
	
	keypad_input += digit
	keypad_timer = keypad_timeout
	
	if keypad_beep:
		keypad_beep.play()
	
	_update_keypad_ui()
	
	# Auto-submit if max digits reached
	if keypad_input.length() >= keypad_max_digits:
		_submit_keypad_code()

func _remove_keypad_digit() -> void:
	if keypad_input.length() > 0:
		keypad_input = keypad_input.substr(0, keypad_input.length() - 1)
		keypad_timer = keypad_timeout
		_update_keypad_ui()

func _submit_keypad_code() -> void:
	var success = (keypad_input == keypad_code)
	code_entered.emit(keypad_input, success)
	
	if success:
		is_locked = false
		if unlock_sound:
			unlock_sound.play()
		_update_interaction_prompt()
	else:
		if keypad_error:
			keypad_error.play()
		if spark_particle:
			_spawn_spark_effect()
	
	_reset_keypad()

func _reset_keypad() -> void:
	is_entering_code = false
	keypad_input = ""
	keypad_timer = 0.0
	_hide_keypad_ui()

func _spawn_spark_effect() -> void:
	if not spark_particle:
		return
	
	var sparks = spark_particle.instantiate()
	get_tree().current_scene.add_child(sparks)
	sparks.global_position = door_body.global_position + door_body.basis.z * 0.5
	sparks.emitting = true

# --- Biometric System ---
func _attempt_biometric_unlock(player: Node) -> void:
	# Check if player has required ID (implement based on your player system)
	var player_id = _get_player_id(player)
	
	if player_id in authorized_ids:
		is_locked = false
		if unlock_sound:
			unlock_sound.play()
		_update_interaction_prompt()
	else:
		_play_denied_feedback()
		if spark_particle:
			_spawn_spark_effect()

func _get_player_id(player: Node) -> String:
	# Override this based on your player implementation
	if player.has_method("get_id"):
		return player.get_id()
	return ""

# --- UI Helpers (Placeholder - implement based on your UI system) ---
func _show_keypad_ui() -> void:
	# Implement UI display
	pass

func _update_keypad_ui() -> void:
	# Update UI with current input (masked as asterisks)
	var display = ""
	for i in keypad_input.length():
		display += "*"
	# Show on UI
	pass

func _hide_keypad_ui() -> void:
	# Hide UI
	pass

# --- Feedback ---
func _play_denied_feedback() -> void:
	if denied_sound:
		denied_sound.play()
	
	# Visual shake effect
	if door_body:
		var tween = create_tween()
		var original_pos = door_body.position
		tween.tween_property(door_body, "position", original_pos + Vector3(0.05, 0, 0), 0.05)
		tween.tween_property(door_body, "position", original_pos - Vector3(0.05, 0, 0), 0.05)
		tween.tween_property(door_body, "position", original_pos, 0.05)

# --- Prompt Updates ---
func _update_interaction_prompt() -> void:
	if current_state == DoorState.DESTROYED:
		interaction_prompt = ""
		return
	
	if is_locked:
		match door_type:
			"Keypad":
				interaction_prompt = "Enter Code"
			"Biometric":
				interaction_prompt = "Scan ID"
			_:
				interaction_prompt = "Locked"
	elif current_state == DoorState.OPEN:
		interaction_prompt = "Close Door"
	else:
		interaction_prompt = "Open Door"

func _update_alt_interaction_prompt() -> void:
	if door_type == "Keypad" or door_type == "Biometric":
		has_alternative_interaction = false
		return
	
	alt_interaction_prompt = "Unlock" if is_locked else "Lock"

func _can_interact_custom() -> bool:
	return current_state in [DoorState.OPEN, DoorState.CLOSED] and current_state != DoorState.DESTROYED

func _can_alt_interact_custom() -> bool:
	return can_be_locked and current_state == DoorState.CLOSED and door_type not in ["Keypad", "Biometric"]

func get_blocked_prompt() -> String:
	if current_state == DoorState.DESTROYED:
		return "Destroyed"
	if is_locked and not keypad_enabled:
		return "Locked"
	if current_state == DoorState.OPENING:
		return "Opening..."
	elif current_state == DoorState.CLOSING:
		return "Closing..."
	return super.get_blocked_prompt()