class_name StepHandlerComponent extends Node

@export_category("References")
@export var player: Player

@export_category("Step Settings")
@export var surface_threshold: float = 0.3
@export var step_height: float = 0.8
@export var climb_duration: float = 0.15  # Time in seconds to complete the climb

const FEET_ADJUSTED_HEIGHT: float = 0.05
const MIN_STEP_HEIGHT: float = 0.1
const MIN_MOVEMENT_LENGTH: float = 0.1
const MIN_DOT_VALUE: float = 0.5

var _step_status: String = ""
var _climb_target_y: float = 0.0
var _climb_start_y: float = 0.0
var _climb_progress: float = 0.0
var _is_climbing: bool = false

var step_status: String:
	get:
		return _step_status
	set(value):
		_step_status = value

func _physics_process(delta: float):
	if _is_climbing:
		_climb_progress += delta / climb_duration
		if _climb_progress > 1.0:
			_climb_progress = 1.0
		
		# Smooth easing: ease-in-out quadratic
		var t: float = _climb_progress
		var eased_t: float
		if t < 0.5:
			eased_t = 2.0 * t * t
		else:
			eased_t = 1.0 - pow(-2.0 * t + 2.0, 2) / 2.0
		
		player.global_position.y = lerp(_climb_start_y, _climb_target_y, eased_t)
		
		if _climb_progress >= 1.0:
			_finish_climb()

func _finish_climb():
	_is_climbing = false
	_climb_progress = 0.0
	player.velocity = player.previous_velocity

func handle_step_climbing():
	if _is_climbing:
		return  # Avoid triggering new climbs while already climbing

	step_status = "No vertical collision detected"
	for i in player.get_slide_collision_count():
		var collision = player.get_slide_collision(i)
		if _is_vertical_surface(collision):
			var measured_height = _measure_step_height(collision)
			if measured_height > MIN_STEP_HEIGHT and measured_height <= step_height and _is_valid_step_direction(collision):
				# Start smooth climb
				_climb_start_y = player.global_position.y
				_climb_target_y = _climb_start_y + measured_height
				_climb_progress = 0.0
				_is_climbing = true
				
				step_status = "Step Found! Height: " + str(measured_height)
			else:
				step_status = "Step too high: " + str(measured_height)
			break

func _check_collision_normal(collision: KinematicCollision3D):
	var normal = collision.get_normal()
	if abs(normal.y) > surface_threshold:
		return false
	return true

func _check_collision_surface(collision: KinematicCollision3D) -> bool:
	var space_state = player.get_world_3d().direct_space_state
	var collision_point = collision.get_position()

	var player_feet = _get_player_feet_position()
	collision_point.y = player_feet.y

	var query = PhysicsRayQueryParameters3D.create(player_feet, collision_point)
	query.collision_mask = player.collision_mask
	query.exclude = [player.get_rid()]

	var result = space_state.intersect_ray(query)
	if result and abs(result.normal.y) <= surface_threshold:
		step_status = "Raycast: Vertical Collision Found! " + str(result.normal)
		return true

	step_status = "No vertical collision detected"
	return false

func _is_vertical_surface(collision: KinematicCollision3D) -> bool:
	var normal = collision.get_normal()
	if abs(normal.y) <= surface_threshold:
		step_status = "CollisionShape: Vertical Collision Found! " + str(normal)
		return true

	return _check_collision_surface(collision)

func _get_player_feet_position() -> Vector3:
	var feet_pos = player.global_position
	# feet_pos.y -= player.get_node("CollisionShape3D").shape.height / 2
	# feet_pos.y += FEET_ADJUSTED_HEIGHT
	return feet_pos

func _measure_step_height(collision: KinematicCollision3D) -> float:
	var space_state = player.get_world_3d().direct_space_state
	var collision_point = collision.get_position()

	var player_feet = _get_player_feet_position()
	var player_head_y = player.global_position.y + (player.get_node("CollisionShape3D").shape.height / 2)

	var ray_start = Vector3(collision_point.x, player_head_y, collision_point.z)
	var ray_end = Vector3(collision_point.x, player_feet.y, collision_point.z)

	var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.collision_mask = player.collision_mask
	query.exclude = [player.get_rid()]

	var result = space_state.intersect_ray(query)
	if result:
		return result.position.y - player_feet.y

	return 0.0

func _is_valid_step_direction(collision: KinematicCollision3D) -> bool:
	var collision_normal = collision.get_normal()
	var input_dir = player._get_input_direction()
	var movement_direction = player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)
	
	if movement_direction.length() > MIN_MOVEMENT_LENGTH:
		movement_direction = movement_direction.normalized()
		var dot_product = movement_direction.dot(-collision_normal)
		return dot_product > MIN_DOT_VALUE
	
	return false
