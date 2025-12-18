extends Node3D
class_name HiteffectComponenent
@export var rigid_body: RigidBody3D = null

func hitscanHit(propulForce : float, propulDir: Vector3, propulPos : Vector3):
	apply_hitscan_hit(propulForce, propulDir, propulPos)
	
func projectileHit(propulForce : float, propulDir: Vector3):
	apply_projectile_hit(propulForce, propulDir)



## For instant impacts (Bullets, Punches)
func apply_hitscan_hit(force: float, direction: Vector3, world_position: Vector3):
	if not rigid_body or direction == Vector3.ZERO:
		return
	
	# 1. Calculate the local offset from the center of mass
	# apply_impulse expects a position relative to the object's origin
	var local_hit_pos = world_position - rigid_body.global_transform.origin
	
	# 2. Apply Impulse (Instant change in momentum)
	# Using impulse for hits is more realistic than force for instant events
	rigid_body.apply_impulse(direction.normalized() * force, local_hit_pos)

## For continuous/projectile impacts (Wind, Water streams, or Rocket blasts)
func apply_projectile_hit(force: float, impact_direction: Vector3):
	if not rigid_body or impact_direction == Vector3.ZERO:
		return

	# 3. Calculate "Kick"
	# Instead of central force, we use an impulse at the center for a clean 'thump'
	# Or use apply_central_impulse to avoid accidental torque
	rigid_body.apply_central_impulse(impact_direction.normalized() * force)