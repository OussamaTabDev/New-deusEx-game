extends Node3D
class_name CameraDetectionVisualizer

## ============================================================================
## CAMERA DETECTION RANGE VISUALIZER
## Shows players where the camera can detect them
## ============================================================================

@export_group("Visual Settings")
@export var show_visualization: bool = true ## Toggle visibility
@export var visualization_type: VisualizationType = VisualizationType.CONE_3D ## Type of visualization
@export var cone_color: Color = Color(1.0, 0.0, 0.0, 0.3) ## Detection cone color
@export var cone_outline_color: Color = Color(1.0, 0.0, 0.0, 0.8) ## Outline color
@export var show_floor_projection: bool = true ## Show cone projection on floor
@export var floor_projection_color: Color = Color(1.0, 0.0, 0.0, 0.2) ## Floor indicator color

@export_group("Animation")
@export var animate_pulse: bool = true ## Pulse effect
@export var pulse_speed: float = 2.0 ## Pulse animation speed
@export var pulse_intensity: float = 0.3 ## How much opacity changes

@export_group("Dynamic Colors")
@export var change_color_by_state: bool = true ## Match camera state colors
@export var patrol_color: Color = Color(0.0, 1.0, 0.0, 0.3) ## Patrol mode color
@export var chase_color: Color = Color(1.0, 0.0, 0.0, 0.5) ## Chase mode color
@export var search_color: Color = Color(1.0, 1.0, 0.0, 0.35) ## Search mode color
@export var disabled_color: Color = Color(0.3, 0.3, 0.3, 0.2) ## Disabled color

@export_group("References")
@export var security_camera: SecurityCamera ## Reference to the camera script

enum VisualizationType {
	CONE_3D,           ## 3D cone mesh
	FLOOR_DECAL,       ## Floor projection only
	WIREFRAME,         ## Wireframe cone
	CONE_WITH_RAYS,    ## Cone + edge rays
	FULL_PACKAGE       ## Everything combined
}

# Mesh instances
var cone_mesh_instance: MeshInstance3D
var floor_decal: Decal
var edge_rays: Node3D
var outline_mesh: MeshInstance3D

# Animation
var time_elapsed: float = 0.0

# Materials
var cone_material: StandardMaterial3D
var outline_material: StandardMaterial3D
var floor_material: StandardMaterial3D

func _ready() -> void:
	if not security_camera:
		push_error("CameraDetectionVisualizer: No SecurityCamera reference assigned!")
		return
	
	_create_visualization()
	_update_visualization()

func _process(delta: float) -> void:
	if not show_visualization or not security_camera:
		return
	
	time_elapsed += delta
	
	# Update visualization based on camera state
	_update_visualization()
	
	# Animate pulse effect
	if animate_pulse:
		_animate_pulse()

## ============================================================================
## VISUALIZATION CREATION
## ============================================================================

func _create_visualization() -> void:
	match visualization_type:
		VisualizationType.CONE_3D:
			_create_3d_cone()
		VisualizationType.FLOOR_DECAL:
			_create_floor_projection()
		VisualizationType.WIREFRAME:
			_create_wireframe_cone()
		VisualizationType.CONE_WITH_RAYS:
			_create_3d_cone()
			_create_edge_rays()
		VisualizationType.FULL_PACKAGE:
			_create_3d_cone()
			_create_floor_projection()
			_create_edge_rays()
			_create_outline()

func _create_3d_cone() -> void:
	cone_mesh_instance = MeshInstance3D.new()
	add_child(cone_mesh_instance)
	
	# Create cone mesh
	var cone_mesh = _generate_cone_mesh(
		security_camera.vision_distance,
		security_camera.fov_radius,
		security_camera.max_rotation_x,
		security_camera.max_rotation_y
	)
	
	cone_mesh_instance.mesh = cone_mesh
	
	# Create material
	cone_material = StandardMaterial3D.new()
	cone_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cone_material.albedo_color = cone_color
	cone_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	cone_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	cone_mesh_instance.material_override = cone_material

func _create_outline() -> void:
	outline_mesh = MeshInstance3D.new()
	add_child(outline_mesh)
	
	var outline = _generate_cone_wireframe(
		security_camera.vision_distance,
		security_camera.fov_radius
	)
	
	outline_mesh.mesh = outline
	
	outline_material = StandardMaterial3D.new()
	outline_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	outline_material.albedo_color = cone_outline_color
	outline_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	outline_mesh.material_override = outline_material

func _create_wireframe_cone() -> void:
	_create_outline()

func _create_floor_projection() -> void:
	floor_decal = Decal.new()
	add_child(floor_decal)
	
	# Position decal below camera
	floor_decal.position = Vector3(0, -security_camera.global_position.y, 0)
	floor_decal.size = Vector3(
		security_camera.fov_radius * 2,
		10.0,
		security_camera.vision_distance
	)
	
	# Create decal texture (cone-shaped gradient)
	var decal_texture = _create_cone_gradient_texture()
	floor_decal.texture_albedo = decal_texture
	floor_decal.modulate = floor_projection_color

func _create_edge_rays() -> void:
	edge_rays = Node3D.new()
	add_child(edge_rays)
	
	# Create ray lines at cone edges
	var ray_count = 8
	for i in range(ray_count):
		var angle = (i / float(ray_count)) * TAU
		var ray = _create_ray_line(angle)
		edge_rays.add_child(ray)

func _create_ray_line(angle: float) -> MeshInstance3D:
	var ray_mesh = MeshInstance3D.new()
	
	var start = Vector3.ZERO
	var end_x = sin(angle) * security_camera.fov_radius
	var end_z = cos(angle) * security_camera.vision_distance
	var end = Vector3(end_x, 0, end_z)
	
	var immediate_mesh = ImmediateMesh.new()
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	immediate_mesh.surface_add_vertex(start)
	immediate_mesh.surface_add_vertex(end)
	immediate_mesh.surface_end()
	
	ray_mesh.mesh = immediate_mesh
	
	var ray_material = StandardMaterial3D.new()
	ray_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ray_material.albedo_color = cone_outline_color
	ray_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	ray_mesh.material_override = ray_material
	
	return ray_mesh

## ============================================================================
## MESH GENERATION
## ============================================================================

func _generate_cone_mesh(distance: float, radius: float, _rot_x: float, _rot_y: float) -> ArrayMesh:
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	
	var vertices = PackedVector3Array()
	var indices = PackedInt32Array()
	
	# Cone apex at camera position
	var apex = Vector3.ZERO
	
	# Generate cone base circle
	var segments = 32
	var base_vertices = []
	
	for i in range(segments):
		var angle = (i / float(segments)) * TAU
		var x = sin(angle) * radius
		var z = cos(angle) * distance
		base_vertices.append(Vector3(x, 0, z))
	
	# Add apex
	vertices.append(apex)
	var apex_index = 0
	
	# Add base vertices
	for v in base_vertices:
		vertices.append(v)
	
	# Create cone sides (triangles from apex to base)
	for i in range(segments):
		var base_idx1 = i + 1
		var base_idx2 = ((i + 1) % segments) + 1
		
		indices.append(apex_index)
		indices.append(base_idx1)
		indices.append(base_idx2)
	
	# Create cone base (filled circle)
	var center_index = vertices.size()
	var center_pos = Vector3(0, 0, distance * 0.5)
	vertices.append(center_pos)
	
	for i in range(segments):
		var idx1 = i + 1
		var idx2 = ((i + 1) % segments) + 1
		
		indices.append(center_index)
		indices.append(idx2)
		indices.append(idx1)
	
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	return mesh

func _generate_cone_wireframe(distance: float, radius: float) -> ImmediateMesh:
	var mesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	
	var apex = Vector3.ZERO
	var segments = 32
	
	# Base circle
	for i in range(segments):
		var angle1 = (i / float(segments)) * TAU
		var angle2 = ((i + 1) / float(segments)) * TAU
		
		var p1 = Vector3(sin(angle1) * radius, 0, cos(angle1) * distance)
		var p2 = Vector3(sin(angle2) * radius, 0, cos(angle2) * distance)
		
		mesh.surface_add_vertex(p1)
		mesh.surface_add_vertex(p2)
	
	# Lines from apex to base (only draw 8 lines for clarity)
	for i in range(8):
		var angle = (i / 8.0) * TAU
		var base_point = Vector3(sin(angle) * radius, 0, cos(angle) * distance)
		
		mesh.surface_add_vertex(apex)
		mesh.surface_add_vertex(base_point)
	
	mesh.surface_end()
	return mesh

func _create_cone_gradient_texture() -> GradientTexture2D:
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1, 1, 1, 1))
	gradient.add_point(1.0, Color(1, 1, 1, 0))
	
	var gradient_texture = GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.fill = GradientTexture2D.FILL_RADIAL
	gradient_texture.width = 256
	gradient_texture.height = 256
	
	return gradient_texture

## ============================================================================
## UPDATES & ANIMATION
## ============================================================================

func _update_visualization() -> void:
	if not security_camera:
		return
	
	visible = show_visualization
	
	if change_color_by_state:
		_update_color_by_camera_state()
	
	# Update scale/shape based on camera FOV settings
	_update_cone_size()

func _update_color_by_camera_state() -> void:
	var state = security_camera.get_camera_state()
	var target_color: Color
	
	match state:
		SecurityCamera.CameraState.DISABLED:
			target_color = disabled_color
		SecurityCamera.CameraState.PATROL, SecurityCamera.CameraState.STATIC, SecurityCamera.CameraState.IDLE:
			target_color = patrol_color
		SecurityCamera.CameraState.CHASE:
			target_color = chase_color
		SecurityCamera.CameraState.SEARCH, SecurityCamera.CameraState.WAITING_AT_OBSTACLE:
			target_color = search_color
		_:
			target_color = cone_color
	
	# Apply to all visual elements
	if cone_material:
		cone_material.albedo_color = target_color
	
	if floor_decal:
		floor_decal.modulate = Color(target_color.r, target_color.g, target_color.b, target_color.a * 0.7)
	
	# Outline stays more visible
	if outline_material:
		outline_material.albedo_color = Color(target_color.r, target_color.g, target_color.b, target_color.a * 2.0)

func _update_cone_size() -> void:
	# Dynamically adjust visualization if camera settings change
	if cone_mesh_instance:
		var new_mesh = _generate_cone_mesh(
			security_camera.vision_distance,
			security_camera.fov_radius,
			security_camera.max_rotation_x,
			security_camera.max_rotation_y
		)
		cone_mesh_instance.mesh = new_mesh

func _animate_pulse() -> void:
	var pulse = (sin(time_elapsed * pulse_speed) + 1.0) * 0.5  # 0 to 1
	var alpha_modifier = 1.0 + (pulse * pulse_intensity)
	
	if cone_material:
		var base_color = cone_material.albedo_color
		cone_material.albedo_color = Color(
			base_color.r,
			base_color.g,
			base_color.b,
			clamp(base_color.a * alpha_modifier, 0.0, 1.0)
		)

## ============================================================================
## PUBLIC API
## ============================================================================

func set_visibility(visible_state: bool) -> void:
	show_visualization = visible_state

func set_visualization_type(type: VisualizationType) -> void:
	visualization_type = type
	_clear_visualization()
	_create_visualization()

func set_cone_color(color: Color) -> void:
	cone_color = color
	if cone_material:
		cone_material.albedo_color = color

func _clear_visualization() -> void:
	for child in get_children():
		child.queue_free()
	
	cone_mesh_instance = null
	floor_decal = null
	edge_rays = null
	outline_mesh = null