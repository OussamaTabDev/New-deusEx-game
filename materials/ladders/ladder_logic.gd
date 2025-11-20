@tool
extends Area3D

@export var ladder_collision: StaticBody3D  # StaticBody3D containing meshes and collision
@export var area_collision_shape: CollisionShape3D  # Area3D's collision shape

# Ladder mesh pieces (children of StaticBody3D)
@export var mid_ladder: MeshInstance3D
@export var t_ladder: MeshInstance3D  # Top piece
@export var b_ladder: MeshInstance3D  # Bottom piece

@export_range(3, 20) var max_pieces: int = 3:
	set(value):
		max_pieces = value
		if Engine.is_editor_hint():
			_update_ladder()

var original_process_mode: ProcessMode
var mid_ladder_instances: Array[MeshInstance3D] = []
var mid_piece_height: float = 1.0  # Height of each middle piece

func _ready():
	if not Engine.is_editor_hint():
		body_shape_entered.connect(_on_body_shape_entered)
		body_exited.connect(_on_body_exited)
		if ladder_collision:
			original_process_mode = ladder_collision.process_mode
	
	_calculate_piece_height()
	_update_ladder()

func _calculate_piece_height():
	# Calculate the height of one mid_ladder piece
	if mid_ladder and mid_ladder.mesh:
		var aabb = mid_ladder.mesh.get_aabb()
		mid_piece_height = aabb.size.y

func _update_ladder():
	if not mid_ladder or not t_ladder or not b_ladder or not ladder_collision:
		return
	
	_calculate_piece_height()
	
	# Clear ALL existing mid pieces (including duplicates from previous updates)
	# First, remove all duplicated pieces from the scene
	for child in ladder_collision.get_children():
		if child is MeshInstance3D and child != mid_ladder and child != t_ladder and child != b_ladder:
			child.queue_free()
	
	# Clear the instances array
	mid_ladder_instances.clear()
	
	# Hide the original mid_ladder (it's just a template)
	mid_ladder.visible = false
	
	# Create mid pieces
	for i in range(max_pieces):
		var piece: MeshInstance3D
		if i == 0:
			# Use the original mid_ladder for the first piece
			piece = mid_ladder
			piece.visible = true
		else:
			# Duplicate for additional pieces
			piece = mid_ladder.duplicate()
			ladder_collision.add_child(piece)
			piece.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else owner
		
		# Position the piece
		piece.position.y = i * mid_piece_height
		mid_ladder_instances.append(piece)
	
	# Position top ladder
	var top_offset = max_pieces * mid_piece_height
	t_ladder.position.y = top_offset
	
	# Update collisions
	_update_collisions(top_offset)

func _update_collisions(total_height: float):
	# Get the height of top piece for accurate total height
	var top_height = 0.0
	if t_ladder and t_ladder.mesh:
		top_height = t_ladder.mesh.get_aabb().size.y
	
	var ladder_total_height = total_height + top_height
	
	# Calculate combined AABB from all visible ladder meshes
	var combined_aabb = AABB()
	var first_mesh = true
	
	# Get AABB from bottom piece
	if b_ladder and b_ladder.visible and b_ladder.mesh:
		combined_aabb = b_ladder.mesh.get_aabb()
		combined_aabb.position += b_ladder.position
		first_mesh = false
	
	# Add all mid pieces
	for piece in mid_ladder_instances:
		if piece and piece.visible and piece.mesh:
			var piece_aabb = piece.mesh.get_aabb()
			piece_aabb.position += piece.position
			if first_mesh:
				combined_aabb = piece_aabb
				first_mesh = false
			else:
				combined_aabb = combined_aabb.merge(piece_aabb)
	
	# Add top piece
	if t_ladder and t_ladder.visible and t_ladder.mesh:
		var top_aabb = t_ladder.mesh.get_aabb()
		top_aabb.position += t_ladder.position
		if first_mesh:
			combined_aabb = top_aabb
		else:
			combined_aabb = combined_aabb.merge(top_aabb)
	
	# Update or create Area3D collision (this node's collision)
	if not area_collision_shape:
		area_collision_shape = CollisionShape3D.new()
		add_child(area_collision_shape)
		area_collision_shape.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else owner
	
	# Create/update shape (full visual height, rotated 90 degrees)
	if not area_collision_shape.shape or not area_collision_shape.shape is BoxShape3D:
		area_collision_shape.shape = BoxShape3D.new()
	
	var area_box_shape = area_collision_shape.shape as BoxShape3D
	area_box_shape.size = combined_aabb.size
	
	# Rotate 90 degrees on X axis and move 0.05 on X axis
	area_collision_shape.position = combined_aabb.get_center()
	area_collision_shape.position.x += 0.05
	# area_collision_shape.rotation_degrees.x = 90
	
	# Update or create ladder collision (StaticBody3D's collision shape)
	# Use a duplicate of area collision with reduced height
	if ladder_collision:
		var ladder_collision_shape: CollisionShape3D = null
		
		# Find existing collision shape
		for child in ladder_collision.get_children():
			if child is CollisionShape3D:
				ladder_collision_shape = child
				break
		
		# Create if doesn't exist
		if not ladder_collision_shape:
			ladder_collision_shape = CollisionShape3D.new()
			ladder_collision.add_child(ladder_collision_shape)
			ladder_collision_shape.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else owner
		
		# Create/update shape (reduced height from area collision)
		if not ladder_collision_shape.shape or not ladder_collision_shape.shape is BoxShape3D:
			ladder_collision_shape.shape = BoxShape3D.new()
		
		var ladder_box_shape = ladder_collision_shape.shape as BoxShape3D
		# Reduce height to 90% of the area collision
		var reduced_aabb = combined_aabb
		reduced_aabb.size.y *= 0.9
		reduced_aabb.position.y += (combined_aabb.size.y - reduced_aabb.size.y) / 2
		
		ladder_box_shape.size = reduced_aabb.size
		ladder_collision_shape.position = reduced_aabb.get_center()
		ladder_collision_shape.position.x += 0.05
		# ladder_collision_shape.rotation_degrees.x = 90

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
		
		# if body.state_machine.previous_state.name == "LadderClimbState" and body.state_machine.current_state.name != "LadderClimbState":
		# 	if body.state_machine:
		# 		body.state_machine.transition_to(body.state_machine.get_state("LadderClimbState"))

func _on_body_exited(body):
	if body.is_in_group("Player"):
		body.on_ladder = false
		body.current_ladder_shape = null
		body.current_ladder_up_direction = Vector3.ZERO
		if ladder_collision:
			ladder_collision.process_mode = original_process_mode
		if body.state_machine and body.state_machine.current_state.name == "LadderClimbState":
				body.state_machine.transition_to(body.state_machine.get_state("FallingState"))

# Call this if you want to manually update the ladder at runtime
func rebuild_ladder():
	_update_ladder()
