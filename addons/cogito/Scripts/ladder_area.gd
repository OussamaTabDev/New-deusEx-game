extends Area3D

@export var ladder_collision: CollisionObject3D
var original_process_mode: ProcessMode

func _ready():
	body_shape_entered.connect(_on_body_shape_entered)
	body_exited.connect(_on_body_exited)
	if ladder_collision:
		original_process_mode = ladder_collision.process_mode

func _on_body_shape_entered(_body_rid, body, _body_shape_idx, local_shape_idx):
	if body.is_in_group("Player"):
		var local_shape_owner = shape_find_owner(local_shape_idx)
		var local_shape_node = shape_owner_get_owner(local_shape_owner) as CollisionShape3D
		
		var ladderDir = (local_shape_node.global_position - global_position).normalized()
		
		# Store ladder data in player
		body.set_current_ladder(local_shape_node, ladderDir)
		
		# Request state transition
		if body.state_machine:
			body.state_machine.transition_to(body.state_machine.get_state("LadderClimbState"))
		
		if body.state_machine.previous_state.name == "LadderClimbState"  and body.state_machine.current_state.name  != "LadderClimbState":
			#ladder_collision
			#await get_tree().create_timer(0.1).timeout
			#ladder_collision.disabled = false 
			if body.state_machine:
				body.state_machine.transition_to(body.state_machine.get_state("LadderClimbState"))
				
		return

func _on_body_exited(body):
	if body.is_in_group("Player"):
		body.on_ladder = false
		body.current_ladder_shape = null
		body.current_ladder_up_direction = Vector3.ZERO
		if ladder_collision:
			ladder_collision.process_mode = original_process_mode
