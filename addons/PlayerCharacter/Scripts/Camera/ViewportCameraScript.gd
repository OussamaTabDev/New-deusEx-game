extends Camera3D

@export var cam : Camera3D

func _process(_delta : float):
	global_transform = cam.global_transform
