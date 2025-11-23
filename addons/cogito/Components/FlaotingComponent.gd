# WaterFloating.gd
# Attach this as a child to a RigidBody3D you want to float
class_name WaterFloating
extends Node3D

@export var rigid_body: RigidBody3D:
	set(value):
		rigid_body = value
		if rigid_body:
			_original_mass = rigid_body.mass

@export var floating_force: float = 10.0  # Scales buoyant force (tune for object weight)
@export var water_drag: float = 0.05
@export var water_angular_drag: float = 0.05

var water_area = null
var is_in_water: bool = false
var submerged: bool = false
var _original_mass: float = 1.0

# Cached sample points in local rigid body space
var _sample_points: Array[Vector3] = []

func _ready() -> void:
	if rigid_body == null:
		rigid_body = get_parent() as RigidBody3D
		if rigid_body == null:
			push_error("WaterFloating: No RigidBody3D assigned and not attached as child to one!")
			return
		else:
			_original_mass = rigid_body.mass

	# Generate sample points once (based on current shape)
	_generate_sample_points()

func _generate_sample_points() -> void:
	_sample_points.clear()
	if not rigid_body:
		return

	# Use AABB to get bounds
	var aabb = rigid_body.get_aabb()
	if aabb == AABB():
		# Fallback if no shape yet (e.g., at startup)
		# Use a small default box
		aabb = AABB(-Vector3(0.5, 0.5, 0.5), Vector3(1, 1, 1))

	var min = aabb.position
	var max = aabb.position + aabb.size

	# Sample 4 corners at the bottom + center
	_sample_points = [
		Vector3(min.x, min.y, min.z),
		Vector3(max.x, min.y, min.z),
		Vector3(min.x, min.y, max.z),
		Vector3(max.x, min.y, max.z),
		Vector3((min.x + max.x) * 0.5, min.y, (min.z + max.z) * 0.5)
	]

func _physics_process(delta: float) -> void:
	if not is_in_water or not rigid_body or not water_area:
		submerged = false
		return

	var water_surface_y = water_area.get_surface_y()
	var total_buoyancy = Vector3.ZERO
	var submerged_points = 0

	for local_point in _sample_points:
		var global_point = rigid_body.global_transform * local_point
		var depth = water_surface_y - global_point.y
		if depth > 0.0:
			submerged_points += 1
			# Buoyant force proportional to depth and area represented by this point
			total_buoyancy += Vector3.UP * floating_force * depth

	submerged = submerged_points > 0

	if submerged:
		rigid_body.apply_central_force(total_buoyancy)

# Apply drag during physics integration
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if not submerged:
		return

	var submerged_ratio = float(_sample_points.filter(func(p): 
		var gp = rigid_body.global_transform * p
		return water_area.get_surface_y() - gp.y > 0.0
	).size()) / _sample_points.size()

	# Clamp ratio to avoid 0 when floating barely
	submerged_ratio = clamp(submerged_ratio, 0.0, 1.0)

	# Apply drag scaled by how much is underwater
	state.linear_velocity *= 1.0 - (water_drag * submerged_ratio)
	state.angular_velocity *= 1.0 - (water_angular_drag * submerged_ratio)