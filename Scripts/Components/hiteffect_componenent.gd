extends Node3D
class_name HiteffectComponenent
@export var rigid_body: RigidBody3D = null

func hitscanHit(propulForce : float, propulDir: Vector3, propulPos : Vector3):
	var hitPos : Vector3 = propulPos - global_transform.origin #set the position to launch the object at
	if propulDir != Vector3.ZERO: rigid_body.apply_impulse(propulDir * propulForce, hitPos)
	
func projectileHit(propulForce : float, propulDir: Vector3):
	if propulDir != Vector3.ZERO: rigid_body.apply_central_force((global_transform.origin - propulDir) * propulForce)
	