extends Node3D
class_name HitEffectComponent

@export var rigid_body: RigidBody3D = null

## For instant hits (bullets/hitscan) where you know exactly where it landed
func hitscan_hit(force: float, direction: Vector3, hit_position: Vector3):
    if not rigid_body or direction == Vector3.ZERO:
        return
    
    # apply_impulse expects a position RELATIVE to the body's origin
    var local_hit_pos = hit_position - rigid_body.global_position
    
    # We use impulse for an instantaneous "kick"
    rigid_body.apply_impulse(direction.normalized() * force, local_hit_pos)

## For physical projectiles or generic pushes
func projectile_hit(force: float, direction: Vector3, hit_position: Vector3 = Vector3.ZERO):
    if not rigid_body:
        return

    var impulse_vector = direction.normalized() * force
    
    if hit_position == Vector3.ZERO:
        # If no specific hit point, apply to center of mass so it doesn't spin wildly
        rigid_body.apply_central_impulse(impulse_vector)
    else:
        var local_hit_pos = hit_position - rigid_body.global_position
        rigid_body.apply_impulse(impulse_vector, local_hit_pos)

func apply_realistic_kick(force: float, direction: Vector3, hit_pos: Vector3):
    var lift = Vector3.UP * (force * 0.1) # Add 10% of force as upward lift
    var final_force = (direction.normalized() * force) + lift
    var local_pos = hit_pos - rigid_body.global_position
    
    rigid_body.apply_impulse(final_force, local_pos)