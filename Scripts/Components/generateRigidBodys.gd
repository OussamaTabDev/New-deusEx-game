@tool
extends Node3D

## Automatically generates RigidBody3D with CollisionShape3D for all MeshInstance3D children
## Attach this script to any Node3D and run it in the editor or at runtime

@export var generate_on_ready: bool = true
@export var collision_shape_type: CollisionShapeType = CollisionShapeType.CONVEX
@export var rigid_body_mass: float = 1.0
@export var rigid_body_gravity_scale: float = 1.0

enum CollisionShapeType {
	CONVEX,      # ConvexPolygonShape3D - best for complex shapes
	TRIMESH,     # ConcaveMeshShape3D - for static/non-moving objects
	BOX,         # BoxShape3D - simple box approximation
	SPHERE,      # SphereShape3D - simple sphere approximation
	CYLINDER     # CylinderShape3D - simple cylinder approximation
}

func _ready() -> void:
	if generate_on_ready:
		generate_rigid_bodies()

func generate_rigid_bodies() -> void:
	var mesh_instances = _find_all_mesh_instances(self)
	
	if mesh_instances.is_empty():
		print("No MeshInstance3D nodes found!")
		return
	
	print("Found %d MeshInstance3D nodes" % mesh_instances.size())
	
	for mesh_inst in mesh_instances:
		_process_mesh_instance(mesh_inst)
	
	print("Rigid body generation complete!")

func _find_all_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	
	for child in node.get_children():
		if child is MeshInstance3D:
			result.append(child)
		# Recursively search children
		result.append_array(_find_all_mesh_instances(child))
	
	return result

func _process_mesh_instance(mesh_inst: MeshInstance3D) -> void:
	# Skip if already has a RigidBody3D parent
	if mesh_inst.get_parent() is RigidBody3D:
		print("Skipping %s - already has RigidBody3D parent" % mesh_inst.name)
		return
	
	if mesh_inst.mesh == null:
		print("Skipping %s - no mesh assigned" % mesh_inst.name)
		return
	
	# Store original parent and transform
	var original_parent = mesh_inst.get_parent()
	var original_transform = mesh_inst.transform
	
	# Create RigidBody3D
	var rigid_body = RigidBody3D.new()
	rigid_body.name = mesh_inst.name + "_RigidBody"
	rigid_body.mass = rigid_body_mass
	rigid_body.gravity_scale = rigid_body_gravity_scale
	
	# Create CollisionShape3D
	var collision_shape = CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	
	# Generate appropriate shape based on type
	var shape = _create_collision_shape(mesh_inst.mesh, collision_shape_type)
	if shape == null:
		print("Failed to create collision shape for %s" % mesh_inst.name)
		rigid_body.queue_free()
		return
	
	collision_shape.shape = shape
	
	# Reparent: Remove mesh from current parent
	original_parent.remove_child(mesh_inst)
	
	# Add rigid body to original parent with mesh's transform
	original_parent.add_child(rigid_body)
	rigid_body.transform = original_transform
	rigid_body.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else get_tree().current_scene
	
	# Add collision shape to rigid body
	rigid_body.add_child(collision_shape)
	collision_shape.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else get_tree().current_scene
	
	# Add mesh instance to rigid body with identity transform
	rigid_body.add_child(mesh_inst)
	mesh_inst.transform = Transform3D.IDENTITY
	mesh_inst.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else get_tree().current_scene
	
	print("Created RigidBody3D for %s" % mesh_inst.name)

func _create_collision_shape(mesh: Mesh, shape_type: CollisionShapeType) -> Shape3D:
	match shape_type:
		CollisionShapeType.CONVEX:
			return mesh.create_convex_shape()
		
		CollisionShapeType.TRIMESH:
			return mesh.create_trimesh_shape()
		
		CollisionShapeType.BOX:
			var aabb = mesh.get_aabb()
			var box = BoxShape3D.new()
			box.size = aabb.size
			return box
		
		CollisionShapeType.SPHERE:
			var aabb = mesh.get_aabb()
			var sphere = SphereShape3D.new()
			sphere.radius = aabb.size.length() / 2.0
			return sphere
		
		CollisionShapeType.CYLINDER:
			var aabb = mesh.get_aabb()
			var cylinder = CylinderShape3D.new()
			cylinder.height = aabb.size.y
			cylinder.radius = max(aabb.size.x, aabb.size.z) / 2.0
			return cylinder
	
	return null

# Editor utility function - call this from editor to generate
func generate() -> void:
	generate_rigid_bodies()