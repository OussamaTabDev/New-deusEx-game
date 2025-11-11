class_name InteractController extends RayCast3D 


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if is_colliding():
		var collider = get_collider()
		# print("Colliding with: %s" % collider.name)
		# if Input.is_action_just_pressed("interact"):
		# 	if collider.has_method("interact"):
		# 		collider.interact()
		# 	else:
		# 		print("The object does not have an interact method.")
	else:
		# print("Not colliding with anything.")
		pass