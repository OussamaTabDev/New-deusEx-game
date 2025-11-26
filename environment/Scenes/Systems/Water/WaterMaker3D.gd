@tool
extends CSGBox3D

# --- VOXEL SETTINGS ---
@export_group("Voxel Style")
@export var voxel_resolution := 64.0 ## Higher is smaller pixels
@export var animation_fps := 12.0 ## Low FPS (e.g. 8-12) gives a retro feel
@export var water_texture_move_speed := Vector3(0.05, 0.05, 0.0) # Speed needs to be higher for stepped movement
@export var water_texture_uv_scale := 1.0

# --- STANDARD SETTINGS ---
@export_group("Visuals")
@export var water_color := Color(0.31, 0.54, 0.87, 0.8) # Made less transparent for pixel art look
@export var fog_color := Color(0, 0.043, 0.157)
@export_range(0.0, 250.0) var fog_fade_dist := 5.0

# --- EDGE OUTLINE ---
@export_group("Water Edge Outline")
@export var enable_edge_outline := true:
	set(value):
		enable_edge_outline = value
		_update_edge_outlines()
@export var edge_outline_width := 0.15:
	set(value):
		edge_outline_width = value
		_update_edge_outlines()
@export var edge_outline_color := Color(0.2, 0.4, 0.7, 1.0): # Full alpha usually looks better for voxels
	set(value):
		edge_outline_color = value
		_update_edge_colors()
@export var edge_pixelation := 8:
	set(value):
		edge_pixelation = max(1, value)
		_update_edge_outlines()
@export var edge_animation_speed := 2.0 

# --- PHYSICS ---
@export_group("Physics")
@export var depth_resistance_multiplier := 0.5
@export var min_depth_velocity := -5.0

static var last_frame_drew_underwater_effect : int = -999

var edge_outline_meshes := []
var previous_size := Vector3.ZERO

# Animation accumulators for "Stop Motion" feel
var _time_accumulator := 0.0
var _current_uv_offset := Vector2.ZERO
var _current_edge_pulse := 0.0

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
		{"pos": Vector3(0, size.y/2+0.02, size.z/2), "size": Vector3(size.x, 0.01, edge_outline_width), "axis": "x"},
		{"pos": Vector3(0, size.y/2+0.02, -size.z/2), "size": Vector3(size.x, 0.01, edge_outline_width), "axis": "x"},
		{"pos": Vector3(size.x/2, size.y/2+0.02, 0), "size": Vector3(edge_outline_width, 0.01, size.z), "axis": "z"},
		{"pos": Vector3(-size.x/2, size.y/2+0.02, 0), "size": Vector3(edge_outline_width, 0.01, size.z), "axis": "z"}
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
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	for i in range(segments):
		var offset = -((edge_size.x if axis == "x" else edge_size.z) / 2.0) + (i * segment_length)
		var pixel_width = segment_length * 0.85 # Slight gap defines the "voxel" look
		
		# Create a small quad for each pixel
		var v1: Vector3; var v2: Vector3; var v3: Vector3; var v4: Vector3
		
		if axis == "x":
			v1 = Vector3(offset, 0, -edge_size.z/2)
			v2 = Vector3(offset + pixel_width, 0, -edge_size.z/2)
			v3 = Vector3(offset + pixel_width, 0, edge_size.z/2)
			v4 = Vector3(offset, 0, edge_size.z/2)
		else: # axis == "z"
			v1 = Vector3(-edge_size.x/2, 0, offset)
			v2 = Vector3(edge_size.x/2, 0, offset)
			v3 = Vector3(edge_size.x/2, 0, offset + pixel_width)
			v4 = Vector3(-edge_size.x/2, 0, offset + pixel_width)
		
		st.set_uv(Vector2(0, 0)); st.add_vertex(v1)
		st.set_uv(Vector2(1, 0)); st.add_vertex(v2)
		st.set_uv(Vector2(1, 1)); st.add_vertex(v3)
		st.set_uv(Vector2(0, 0)); st.add_vertex(v1)
		st.set_uv(Vector2(1, 1)); st.add_vertex(v3)
		st.set_uv(Vector2(0, 1)); st.add_vertex(v4)
		
	st.generate_normals()
	st.commit(array_mesh)
	
	mesh_instance.mesh = array_mesh
	mesh_instance.position = pos
	
	# Create material for edge
	var mat = StandardMaterial3D.new()
	mat.albedo_color = edge_outline_color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	
	mesh_instance.material_override = mat
	
	return mesh_instance

func should_draw_camera_underwater_effect():
	var camera := get_viewport().get_camera_3d() if get_viewport() else null
	if not camera: return false
	var aabb = self.global_transform * self.get_aabb().grow(0.025)
	if not aabb.has_point(camera.global_position): return false
	if last_frame_drew_underwater_effect == Engine.get_process_frames(): return false
	
	if not %CameraPosShapeCast3D: return false
	
	%CameraPosShapeCast3D.global_position = camera.global_position
	%CameraPosShapeCast3D.force_shapecast_update()
	for i in %CameraPosShapeCast3D.get_collision_count():
		if %CameraPosShapeCast3D.get_collider(i) == %SwimmableArea3D:
			return true
	return false

func _update_mesh():
	if get_node_or_null("%CollisionShape3D"):
		%CollisionShape3D.shape.size = self.size
	
	if size != previous_size:
		previous_size = size
		_update_edge_outlines()

func _process(delta):
	_update_mesh()
	
	# --- UPDATE FOG ---
	if get_node_or_null("%FogVolume"):
		%FogVolume.material.set_shader_parameter("albedo", fog_color)
		%FogVolume.material.set_shader_parameter("emission", fog_color)
		%FogVolume.size = self.size
		%FogVolume.fade_distance = self.fog_fade_dist
	
	# --- STEPPED ANIMATION LOGIC ---
	# We accumulate delta and only update visuals when we cross the FPS threshold
	_time_accumulator += delta
	var step_time = 1.0 / animation_fps
	
	if _time_accumulator >= step_time:
		# How many frames passed?
		var steps = floor(_time_accumulator / step_time)
		_time_accumulator -= steps * step_time
		
		# Update internal values based on how many "steps" occurred
		_current_uv_offset += Vector2(water_texture_move_speed.x, water_texture_move_speed.y) * steps
		_current_edge_pulse += steps * edge_animation_speed * 0.1
		
		# --- UPDATE MATERIAL ---
		if self.material is ShaderMaterial:
			# Update Shader Params
			self.material.set_shader_parameter("albedo", water_color)
			self.material.set_shader_parameter("voxel_size", voxel_resolution)
			self.material.set_shader_parameter("uv_scale", Vector2(water_texture_uv_scale, water_texture_uv_scale))
			self.material.set_shader_parameter("uv_offset", _current_uv_offset)
			
		elif self.material is StandardMaterial3D:
			# Fallback for standard material (won't be perfectly pixelated)
			self.material.uv1_offset = Vector3(_current_uv_offset.x, _current_uv_offset.y, 0)
			self.material.uv1_scale = Vector3(water_texture_uv_scale, water_texture_uv_scale, water_texture_uv_scale)
			self.material.albedo_color = water_color
			# Force nearest neighbor for StandardMaterial
			self.material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

		# --- UPDATE EDGES (Stepped) ---
		if enable_edge_outline and edge_outline_meshes.size() > 0:
			_animate_edges_stepped(_current_edge_pulse)
	
	# --- UNDERWATER EFFECT ---
	if not Engine.is_editor_hint() and get_node_or_null("%WaterRippleOverlay"):
		if should_draw_camera_underwater_effect():
			%WaterRippleOverlay.visible = true
			if get_node_or_null("%FogVolume"):
				%FogVolume.material.set_shader_parameter("edge_fade", 0.1)
			last_frame_drew_underwater_effect = Engine.get_process_frames()
		else:
			%WaterRippleOverlay.visible = false
			if get_node_or_null("%FogVolume"):
				%FogVolume.material.set_shader_parameter("edge_fade", 1.1)

func _animate_edges_stepped(pulse_time: float):
	for i in range(edge_outline_meshes.size()):
		if not is_instance_valid(edge_outline_meshes[i]):
			continue
		
		var mesh = edge_outline_meshes[i]
		var mat = mesh.material_override as StandardMaterial3D
		if mat:
			# Stepped pulse calculation
			var pulse = (sin(pulse_time + i * 0.5) + 1.0) / 2.0
			# Quantize the pulse to 4 steps for retro feel
			pulse = floor(pulse * 4.0) / 4.0
			
			var animated_color = edge_outline_color
			animated_color.a = edge_outline_color.a * (0.5 + pulse * 0.5)
			mat.albedo_color = animated_color

func get_surface_y():
	return global_position.y + size.y / 2

func _on_swimmable_area_3d_body_shape_entered(body_rid: RID, body: Node3D, body_shape_index: int, local_shape_index: int) -> void:
	if body.is_in_group("Player"):
		body.in_water = true
		body.current_water_body = %SwimmableArea3D
		
		if body.state_machine:
			var swimming_state = body.state_machine.get_state("SwimmingState")
			if body.velocity.y < min_depth_velocity and swimming_state:
				swimming_state.entry_velocity = body.velocity * depth_resistance_multiplier
			body.state_machine.transition_to(swimming_state)
	elif body.has_node("FlaotingComponent"):
		var floater = body.get_node("FlaotingComponent")
		floater.is_in_water = true
		floater.water_area = self

func _on_swimmable_area_3d_body_shape_exited(body_rid: RID, body: Node3D, body_shape_index: int, local_shape_index: int) -> void:
	if body.is_in_group("Player"):
		body.in_water = false
		body.current_water_body = null
	elif body.has_node("FlaotingComponent"):
		var floater = body.get_node("FlaotingComponent")
		floater.is_in_water = false
		floater.water_area = null