class_name WallRunningState
extends State

# Adjust these variables or move them to your Player script
const WALL_RUN_SPEED = 10.0
const WALL_JUMP_VELOCITY = 12.0
const WALL_PUSH_AWAY_FORCE = 8.0 # How hard to push off the wall
const WALL_GRAVITY = 4.0 # Lower than normal gravity to "stick" a bit

var wall_normal: Vector3

func enter() -> void:
	# Get the normal of the wall we collided with
	# Note: get_slide_collision(0) gets the last collision from move_and_slide
	if player.get_slide_collision_count() > 0:
		var collision = player.get_slide_collision(0)
		wall_normal = collision.get_normal()
		
		# Optional: Tilt camera based on which side the wall is
		# var is_wall_left = wall_normal.dot(player.transform.basis.x) > 0
		# player.tilt_camera(is_wall_left)
	else:
		# Safety fallback if we entered this state without actually touching a wall
		state_machine.change_state("FallingState")

func exit() -> void:
	# Optional: Reset camera tilt
	# player.reset_camera_tilt()
	pass

func physics_update(delta: float) -> void:
	# 1. Update Wall Normal continuously (in case wall curves)
	if player.is_on_wall() and player.get_slide_collision_count() > 0:
		var collision = player.get_slide_collision(0)
		wall_normal = collision.get_normal()
	
	# 2. Calculate direction along the wall
	# Cross product of wall normal and UP gives a vector parallel to the wall
	var wall_forward = Vector3.UP.cross(wall_normal)
	
	# Check if we need to flip the direction based on where the player is looking
	if wall_forward.dot(player.transform.basis.z) > 0:
		wall_forward = -wall_forward
		
	# 3. Apply Movement
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	if input_dir.y < 0: # Moving forward
		player.velocity.x = wall_forward.x * WALL_RUN_SPEED
		player.velocity.z = wall_forward.z * WALL_RUN_SPEED
	else:
		# Decelerate if not holding forward
		player.velocity.x = move_toward(player.velocity.x, 0, WALL_RUN_SPEED * delta)
		player.velocity.z = move_toward(player.velocity.z, 0, WALL_RUN_SPEED * delta)

	# 4. Push slightly INTO the wall to ensure is_on_wall() stays true
	player.velocity -= wall_normal * 0.5 

	# 5. Apply reduced gravity (slow slide down)
	player.velocity.y -= WALL_GRAVITY * delta
	
	player.move_and_slide()

func check_transitions() -> State:
	# Landed on ground
	if player.is_on_floor():
		return state_machine.get_state("WalkingState")
	
	# No longer touching wall (fell off edge or moved away)
	if not player.is_on_wall():
		return state_machine.get_state("FallingState")
		
	# Wall Jump
	if Input.is_action_just_pressed("jump"):
		# Apply jump force UP + AWAY from wall
		player.velocity.y = WALL_JUMP_VELOCITY
		player.velocity += wall_normal * WALL_PUSH_AWAY_FORCE
		return state_machine.get_state("JumpingState")
	
	return null