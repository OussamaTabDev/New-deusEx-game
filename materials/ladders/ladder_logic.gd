@tool
extends Area3D

@export var ladder_collision: StaticBody3D
@export var area_collision_shape: CollisionShape3D

@export var mid_ladder: MeshInstance3D
@export var t_ladder: MeshInstance3D
@export var b_ladder: MeshInstance3D

@export_range(0, 50) var max_pieces: int = 3:
	set(value):
		max_pieces = value
		if Engine.is_editor_hint():
			_update_ladder()

var original_process_mode: ProcessMode
var mid_ladder_instances: Array[MeshInstance3D] = []
var mid_piece_height: float = 1.0
var waterStates =["SwimmingState" , "SurfaceSwimmingState" , "SprintSwimmingState"]

func _ready():
	# CRITICAL: Make all shapes unique when instance loads
	_make_shapes_unique()
	
	if not Engine.is_editor_hint():
		body_shape_entered.connect(_on_body_shape_entered)
		body_exited.connect(_on_body_exited)
		area_shape_entered.connect(_on_area_shape_entered)
		area_shape_exited.connect(_on_area_shape_exited)
		
		if ladder_collision:
			original_process_mode = ladder_collision.process_mode
		
		# Check for water on startup (after connections are made)
		call_deferred("_check_initial_water_overlap")
	
	_calculate_piece_height()
	_update_ladder()

# NEW FUNCTION: Check if ladder is in water when game starts
func _check_initial_water_overlap():
	# Wait for physics to be fully ready
	await get_tree().physics_frame
	
	# Check all overlapping areas
	var overlapping_areas = get_overlapping_areas()
	var is_in_water = false
	
	for area in overlapping_areas:
		if area.is_in_group("water_area"):
			is_in_water = true
			print("Ladder detected in water on startup - disabling collision")
			break
	
	if is_in_water and area_collision_shape:
		area_collision_shape.disabled = true

# NEW FUNCTION: Makes all collision shapes unique for this instance
func _make_shapes_unique():
	# Make Area3D collision shape unique
	if area_collision_shape and area_collision_shape.shape:
		area_collision_shape.shape = area_collision_shape.shape.duplicate()
	
	# Make StaticBody3D collision shape unique
	if ladder_collision:
		for child in ladder_collision.get_children():
			if child is CollisionShape3D and child.shape:
				child.shape = child.shape.duplicate()

func _calculate_piece_height():
	if mid_ladder and mid_ladder.mesh:
		var aabb = mid_ladder.mesh.get_aabb()
		mid_piece_height = aabb.size.y

func _update_ladder():
	if not mid_ladder or not t_ladder or not b_ladder or not ladder_collision:
		return
	
	_calculate_piece_height()
	
	# Clear existing mid pieces
	for child in ladder_collision.get_children():
		if child is MeshInstance3D and child != mid_ladder and child != t_ladder and child != b_ladder:
			child.queue_free()
	
	mid_ladder_instances.clear()
	mid_ladder.visible = false
	
	# Create mid pieces
	for i in range(max_pieces):
		var piece: MeshInstance3D
		if i == 0:
			piece = mid_ladder
			piece.visible = true
		else:
			piece = mid_ladder.duplicate()
			ladder_collision.add_child(piece)
			piece.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else owner
		
		piece.position.y = i * mid_piece_height
		mid_ladder_instances.append(piece)
	
	# Position top ladder
	var top_offset = max_pieces * mid_piece_height
	t_ladder.position.y = top_offset
	
	# Update collisions
	_update_collisions(top_offset)

func _update_collisions(total_height: float):
	var top_height = 0.0
	if t_ladder and t_ladder.mesh:
		top_height = t_ladder.mesh.get_aabb().size.y
	
	var ladder_total_height = total_height + top_height
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
	
	# Update Area3D collision
	if not area_collision_shape:
		area_collision_shape = CollisionShape3D.new()
		add_child(area_collision_shape)
		area_collision_shape.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else owner
	
	# Create NEW unique shape (not reusing existing)
	area_collision_shape.shape = BoxShape3D.new()
	var area_box_shape = area_collision_shape.shape as BoxShape3D
	area_box_shape.size = combined_aabb.size
	
	area_collision_shape.position = combined_aabb.get_center()
	area_collision_shape.position.x += 0.05
	
	# Update ladder collision (StaticBody3D)
	if ladder_collision:
		var ladder_collision_shape: CollisionShape3D = null
		
		for child in ladder_collision.get_children():
			if child is CollisionShape3D:
				ladder_collision_shape = child
				break
		
		if not ladder_collision_shape:
			ladder_collision_shape = CollisionShape3D.new()
			ladder_collision.add_child(ladder_collision_shape)
			ladder_collision_shape.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else owner
		
		# Create NEW unique shape
		ladder_collision_shape.shape = BoxShape3D.new()
		var ladder_box_shape = ladder_collision_shape.shape as BoxShape3D
		
		# Reduce height to 90%
		var reduced_aabb = combined_aabb
		reduced_aabb.size.y *= 0.9
		reduced_aabb.position.y += (combined_aabb.size.y - reduced_aabb.size.y) / 2
		
		ladder_box_shape.size = reduced_aabb.size
		ladder_collision_shape.position = reduced_aabb.get_center()
		ladder_collision_shape.position.x += 0.05

func _on_body_shape_entered(_body_rid, body, _body_shape_idx, local_shape_idx):
	if body.is_in_group("Player"):
		if not body.state_machine.current_state.name in waterStates:
			var local_shape_owner = shape_find_owner(local_shape_idx)
			var local_shape_node = shape_owner_get_owner(local_shape_owner) as CollisionShape3D
			
			var ladderDir = (local_shape_node.global_position - global_position).normalized()
			body.set_current_ladder(local_shape_node, ladderDir)
			
			if body.state_machine:
				body.state_machine.transition_to(body.state_machine.get_state("LadderClimbState"))

func _on_body_exited(body):
	if body.is_in_group("Player"):
		if not body.state_machine.current_state.name in waterStates:
			body.on_ladder = false
			body.current_ladder_shape = null
			body.current_ladder_up_direction = Vector3.ZERO
			if ladder_collision:
				ladder_collision.process_mode = original_process_mode
			if body.state_machine and body.state_machine.current_state.name == "LadderClimbState":
				body.state_machine.transition_to(body.state_machine.get_state("FallingState"))

func rebuild_ladder():
	_update_ladder()

func _on_area_shape_entered(area_rid: RID, area: Area3D, area_shape_index: int, local_shape_index: int) -> void:
	if area.is_in_group("water_area"):
		print("Ladder entered water - disabling collision")
		if area_collision_shape:
			area_collision_shape.disabled = true

func _on_area_shape_exited(area_rid: RID, area: Area3D, area_shape_index: int, local_shape_index: int) -> void:
	if area.is_in_group("water_area"):
		print("Ladder exited water - enabling collision")
		if area_collision_shape:
			area_collision_shape.disabled = false