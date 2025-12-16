extends Node3D

@export var raycast : RayCast3D
@export var max_retraction_dist : float = 0.1 # Maximum distance the gun can move back
@export var smooth_speed : float = 4.0 # How fast the gun reacts (higher = snappier)
@export var weapon_manager : WeaponManager

var original_position := Vector3.ZERO
var ray_length : float = 0.75
var cw = null :
	get:
		if not weapon_manager or not weapon_manager.cW :
			return null
		return weapon_manager.cW

var attack_point_z : float :
	get:
		if cw:
			return cw.weaponSlot.attackPoint.position.z
		return ray_length

## now we need to adapt each weapon with this code by using the attackPoint (because it postion in last of weapon)
func _ready() -> void:
	original_position = position
	
	# Calculate the full length of the ray based on its target position
	# (Assuming the ray points in -Z, we take the absolute length)
	ray_length = abs(raycast.target_position.z)

func _process(delta: float) -> void:
	var target_z = original_position.z
	raycast_setup()
	if raycast.is_colliding():
		# 1. Get the global point where the ray hit the wall
		var collision_point = raycast.get_collision_point()
		
		# 2. Calculate the distance from the ray start to the wall
		var dist_to_wall = raycast.global_position.distance_to(collision_point)
		
		# 3. Calculate how much we need to pull back
		# If the wall is closer than the ray length, we calculate the difference
		if dist_to_wall < ray_length:
			var push_amount = ray_length - dist_to_wall
			
			# Clamp it so it doesn't go back further than your limit
			push_amount = clamp(push_amount, 0.0, max_retraction_dist)
			
			# Add this amount to the original Z position (pushing it back)
			target_z = original_position.z + push_amount

	# 4. Apply the movement smoothly
	position.z = lerp(position.z, target_z, delta * smooth_speed)


func raycast_setup():
	if cw and not raycast.is_colliding():
		if abs(attack_point_z) < 0.6:
			raycast.target_position.z = -abs(attack_point_z + 0.1) # Slight offset to avoid clipping
		else:
			raycast.target_position.z = -abs(attack_point_z - 1.) # Slight offset to avoid clipping
			
		ray_length = abs(raycast.target_position.z)
