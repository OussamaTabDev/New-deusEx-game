class_name CyberScanner
extends Node3D

@export var main_camera: Camera3D
@export var scanning_viewport: SubViewportContainer

func _ready() -> void:
	# scanning_viewport.custom_minimum_size = Vector2(1920, 1080) # display size
	# scanning_viewport.size = Vector2(128, 128)                  # render resolution

	# scanning_viewport.size = Vector2(256, 256)
	%ScanningCamera.cull_mask = 2  # Only render layer 2

func _process(delta: float) -> void:
	if main_camera:
		%ScanningCamera.global_transform = main_camera.global_transform

func set_param(value, shader_param_name):
	scanning_viewport.material.set_shader_parameter(shader_param_name, value)

func get_param(shader_param_name):
	return scanning_viewport.material.get_shader_parameter(shader_param_name)

func _on_scanning(enabled: bool) -> void:
	scanning_viewport.visible = enabled
	if enabled:
		# if get_param("visibility") < 0.5:
			print("will now")
			set_param(1.0, "visibility")
			set_param(0.0, "scanning_progress")
			var tween = get_tree().create_tween()
			tween.tween_method(set_param.bind("scanning_progress"), 0.0, 1.0, 1.2)
		# else: already visible — optional: restart animation if desired
	else:
		var tween = get_tree().create_tween()
		tween.tween_method(set_param.bind("visibility"), get_param("visibility"), 0.0, 0.2)

func _on_color_picker_changed(color: Color) -> void:
	set_param(color, "color")

func _on_init_outline_value_changed(value: float) -> void:
	set_param(value, "initial_outline_pixel_size")

func _on_final_outline_value_changed(value: float) -> void:
	set_param(value, "final_outline_pixel_size")

func _on_init_fill_value_changed(value: float) -> void:
	set_param(value, "initial_fill_transparency")

func _on_final_fill_value_changed(value: float) -> void:
	set_param(value, "final_fill_transparency")

func _on_init_pixel_value_changed(value: float) -> void:
	set_param(value, "initial_pixelize_power")

func _on_final_pixel_value_changed(value: float) -> void:
	set_param(value, "final_pixelize_power")
