@tool
extends CSGBox3D

@export var water_texture_move_speed := Vector3(0.0025, 0.0025, 0.0025)
@export var water_texture_uv_scale := 0.04
@export var water_color := Color(0.3098039329052, 0.54117649793625, 0.86666667461395, 0.38823530077934)
@export var fog_color := Color(0, 0.04313725605607, 0.15686275064945)
@export_range(0.0, 250.0) var fog_fade_dist := 5.0

# Edge outline properties
@export_group("Water Edge Outline")
@export var enable_edge_outline := true:
	set(value):
		enable_edge_outline = value
		_update_edge_outlines()
@export var edge_outline_width := 0.15:  # Width of the pixelated border
	set(value):
		edge_outline_width = value
		_update_edge_outlines()
@export var edge_outline_color := Color(0.2, 0.4, 0.7, 0.6):  # Slightly darker blue
	set(value):
		edge_outline_color = value
		_update_edge_colors()
@export var edge_pixelation := 8:  # Number of pixels/segments per unit
	set(value):
		edge_pixelation = max(1, value)
		_update_edge_outlines()
@export var edge_animation_speed := 0.5  # Speed of edge animation

# Depth mechanics
@export var depth_resistance_multiplier := 0.5
@export var min_depth_velocity := -5.0

static var last_frame_drew_underwater_effect : int = -999

var edge_outline_meshes := []
var edge_time := 0.0
var previous_size := Vector3.ZERO

func _ready():
	self.process_priority = 999
	previous_size = size
	_update_edge_outlines()

func _update_edge_outlines():
	if not is_inside_tree():
		return
	_create_edge_outlines()

func _update_edge_colors():
	if not is_inside_tree():
		return
	for mesh in edge_outline_meshes:
		if is_instance_valid(mesh):
			var mat = mesh.material_override as StandardMaterial3D
			if mat:
				mat.albedo_color = edge_outline_color

func _create_edge_outlines():
	# Clear existing edge meshes properly
	for mesh in edge_outline_meshes:
		if is_instance_valid(mesh) and mesh.get_parent() == self:
			remove_child(mesh)
			mesh.queue_free()
	edge_outline_meshes.clear()
	
	if not enable_edge_outline:
		return
	
	# Create 4 edge strips (one for each side)
	var edges = [
		{"pos": Vector3(0, size.y/2+0.02, size.z/2), "size": Vector3(size.x, 0.01, edge_outline_width), "axis": "x"},  # Front
		{"pos": Vector3(0, size.y/2+0.02, -size.z/2), "size": Vector3(size.x, 0.01, edge_outline_width), "axis": "x"},  # Back
		{"pos": Vector3(size.x/2, size.y/2+0.02, 0), "size": Vector3(edge_outline_width, 0.01, size.z), "axis": "z"},  # Right
		{"pos": Vector3(-size.x/2, size.y/2+0.02, 0), "size": Vector3(edge_outline_width, 0.01, size.z), "axis": "z"}  # Left
	]
	
	for edge_data in edges:
		var edge_mesh = _create_pixelated_edge(edge_data["pos"], edge_data["size"], edge_data["axis"])
		add_child(edge_mesh)
		edge_mesh.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else owner
		edge_outline_meshes.append(edge_mesh)

func _create_pixelated_edge(pos: Vector3, edge_size: Vector3, axis: String) -> MeshInstance3D:
	var mesh_instance = MeshInstance3D.new()
	var array_mesh = ArrayMesh.new()
	
	# Calculate number of segments based on pixelation
	var segments = int(edge_size.x if axis == "x" else edge_size.z) * edge_pixelation
	var segment_length = (edge_size.x if axis == "x" else edge_size.z) / segments
	
	# Create pixelated segments
	for i in range(segments):
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		
		var offset = -((edge_size.x if axis == "x" else edge_size.z) / 2.0) + (i * segment_length)
		var pixel_width = segment_length * 0.8  # Gap between pixels
		
		# Create a small quad for each pixel
		var v1: Vector3
		var v2: Vector3
		var v3: Vector3
		var v4: Vector3
		
		if axis == "x":
			v1 = Vector3(offset, 0, -edge_size.z/2)
			v2 = Vector3(offset + pixel_width, 0, -edge_size.z/2)
			v3 = Vector3(offset + pixel_width, 0, edge_size.z/2)
			v4 = Vector3(offset, 0, edge_size.z/2)
		else:  # axis == "z"
			v1 = Vector3(-edge_size.x/2, 0, offset)
			v2 = Vector3(edge_size.x/2, 0, offset)
			v3 = Vector3(edge_size.x/2, 0, offset + pixel_width)
			v4 = Vector3(-edge_size.x/2, 0, offset + pixel_width)
		
		# Add vertices with UVs
		st.set_uv(Vector2(0, 0))
		st.add_vertex(v1)
		st.set_uv(Vector2(1, 0))
		st.add_vertex(v2)
		st.set_uv(Vector2(1, 1))
		st.add_vertex(v3)
		
		st.set_uv(Vector2(0, 0))
		st.add_vertex(v1)
		st.set_uv(Vector2(1, 1))
		st.add_vertex(v3)
		st.set_uv(Vector2(0, 1))
		st.add_vertex(v4)
		
		st.generate_normals()
		st.commit(array_mesh)
	
	mesh_instance.mesh = array_mesh
	mesh_instance.position = pos
	
	# Create material for edge
	var mat = StandardMaterial3D.new()
	mat.albedo_color = edge_outline_color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.disable_receive_shadows = true
	mat.no_depth_test = false
	
	mesh_instance.material_override = mat
	
	return mesh_instance

func should_draw_camera_underwater_effect():
	var camera := get_viewport().get_camera_3d() if get_viewport() else null
	if not camera: return false
	var aabb = self.global_transform * self.get_aabb().grow(0.025)
	if not aabb.has_point(camera.global_position): return false
	if last_frame_drew_underwater_effect == Engine.get_process_frames(): return false
	
	%CameraPosShapeCast3D.global_position = camera.global_position
	%CameraPosShapeCast3D.force_shapecast_update()
	var camera_is_in_water_area3d := false
	for i in %CameraPosShapeCast3D.get_collision_count():
		if %CameraPosShapeCast3D.get_collider(i) == %SwimmableArea3D:
			return true
	return false

func _update_mesh():
	if get_node_or_null("%CollisionShape3D"):
		%CollisionShape3D.shape.size = self.size
	
	# Recreate edge outlines if size changed
	if size != previous_size:
		previous_size = size
		_update_edge_outlines()

func _process(delta):
	_update_mesh()
	
	if self.material is StandardMaterial3D:
		if not Engine.is_editor_hint():
			self.material.uv1_offset += water_texture_move_speed * delta
		self.material.uv1_scale = Vector3(water_texture_uv_scale,water_texture_uv_scale,water_texture_uv_scale)
		self.material.albedo_color = water_color
	
	%FogVolume.material.set_shader_parameter("albedo", fog_color)
	%FogVolume.material.set_shader_parameter("emission", fog_color)
	%FogVolume.size = self.size
	%FogVolume.fade_distance = self.fog_fade_dist
	
	# Animate edge outlines
	if enable_edge_outline and edge_outline_meshes.size() > 0:
		edge_time += delta * edge_animation_speed
		_animate_edges()
	
	if not Engine.is_editor_hint():
		if should_draw_camera_underwater_effect():
			%WaterRippleOverlay.visible = true
			%FogVolume.material.set_shader_parameter("edge_fade", 0.1)
			last_frame_drew_underwater_effect = Engine.get_process_frames()
		else:
			%WaterRippleOverlay.visible = false
			%FogVolume.material.set_shader_parameter("edge_fade", 1.1)

func _animate_edges():
	for i in range(edge_outline_meshes.size()):
		if not is_instance_valid(edge_outline_meshes[i]):
			continue
		
		var mesh = edge_outline_meshes[i]
		var mat = mesh.material_override as StandardMaterial3D
		if mat:
			# Pulse the edge opacity
			var pulse = (sin(edge_time + i * 0.5) + 1.0) / 2.0
			var animated_color = edge_outline_color
			animated_color.a = edge_outline_color.a * (0.5 + pulse * 0.5)
			mat.albedo_color = animated_color

func get_surface_y():
	# print("sufrace:" )
	return global_position.y + size.y / 2

func _on_swimmable_area_3d_body_shape_entered(body_rid: RID, body: Node3D, body_shape_index: int, local_shape_index: int) -> void:
	if body.is_in_group("Player"):
		body.in_water = true
		body.current_water_body = %SwimmableArea3D
		
		var entry_speed = abs(body.velocity.y)
		var was_falling_fast = body.velocity.y < min_depth_velocity
		
		if body.state_machine:
			var swimming_state = body.state_machine.get_state("SwimmingState")
			
			if was_falling_fast and swimming_state:
				swimming_state.entry_velocity = body.velocity * depth_resistance_multiplier
				print("Player diving deep! Entry speed: ", entry_speed)
			
			body.state_machine.transition_to(swimming_state)
	else:
		if body.get_node("FlaotingComponent"):
			body.get_node("FlaotingComponent").is_in_water = true
			print(get_surface_y())
			body.get_node("FlaotingComponent").water_area = self

func _on_swimmable_area_3d_body_shape_exited(body_rid: RID, body: Node3D, body_shape_index: int, local_shape_index: int) -> void:
	if body.is_in_group("Player"):
		body.in_water = false
		body.current_water_body = null
		print("The player exited water")
	else:
		if body.get_node("FlaotingComponent"):
			body.get_node("FlaotingComponent").is_in_water = false
			body.get_node("FlaotingComponent").water_area = null
