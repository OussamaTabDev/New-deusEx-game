class_name DoorMechanism
extends Node3D

# --- Configuration ---
@export_group("Door Settings")
@export var open_angle: float = 90.0
@export var duration: float = 0.6
@export var push_force: float = 1.0 # Multiplier for opening direction

# --- References ---
# We assume $Door is a StaticBody3D or AnimatableBody3D so it has collision
@onready var door_body: Node3D = $Door 
# We need the collider to disable it. Adjust path if your collision shape is named differently.
@onready var collision_shape: CollisionShape3D = $Door/CollisionShape3D

# --- State ---
var is_open: bool = false
var is_moving: bool = false

func _ready() -> void:
	# Ensure the door starts in the correct rotation
	door_body.rotation_degrees.y = 0.0

# Call this function from your Player script or Interaction Raycast
# Pass the player's global_position so the door knows which way to open
func interact(user_position: Vector3 = Vector3.ZERO) -> void:
	if is_moving:
		return # Prevent spamming while animation plays

	var target_y_rotation: float = 0.0

	if is_open:
		# Close the door (return to 0)
		target_y_rotation = 0.0
	else:
		# Open the door
		# ImSim Logic: Open AWAY from the user
		var direction = 1.0
		if user_position != Vector3.ZERO:
			# Convert user position to local space to check if they are in front or behind
			var local_user_pos = to_local(user_position)
			# If Z is positive, user is 'front', open negative. If Z negative, open positive.
			direction = -1.0 if local_user_pos.z > 0 else 1.0
		
		target_y_rotation = -1 * open_angle * direction

	_animate_door(target_y_rotation)

func _animate_door(target_rot: float) -> void:
	is_moving = true
	
	# 1. Disable collision to prevent physics jank/pushing the player
	if collision_shape:
		collision_shape.set_deferred("disabled", true)

	# 2. Setup the Tween
	var tween = create_tween()
	# Cubic or Quintic gives a heavy, realistic weight to the door
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# 3. Animate rotation
	tween.tween_property(door_body, "rotation_degrees:y", target_rot, duration)
	
	# 4. Connect finish signal
	tween.finished.connect(_on_tween_finished.bind(target_rot))

func _on_tween_finished(final_rot: float) -> void:
	is_moving = false
	
	# Re-enable collision so the door is solid again
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
	
	# Update state
	is_open = not is_zero_approx(final_rot)