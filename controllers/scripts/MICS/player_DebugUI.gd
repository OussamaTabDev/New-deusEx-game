class_name PlayerDebugUI
extends Control

# References
@export var player: CharacterBody3D
@export var state_machine: StateMachine
@export var enable_debug: bool = false
# UI Elements
var left_panel: PanelContainer
var left_label: RichTextLabel
var left_title: Label
var left_prev_btn: Button
var left_next_btn: Button

var right_panel: PanelContainer
var right_label: RichTextLabel
var right_title: Label
var right_prev_btn: Button
var right_next_btn: Button

var update_timer: Timer

# Toggle visibility
var is_visible: bool = true

# Panel categories
enum PanelType {
	STATE_MACHINE,
	MOVEMENT,
	INPUT,
	PHYSICS,
	CLIMBING,
	RAYCASTS,
	PARAMETERS,
	PERFORMANCE
}

var left_current_panel: int = PanelType.STATE_MACHINE
var right_current_panel: int = PanelType.RAYCASTS

var panel_names = {
	PanelType.STATE_MACHINE: "State Machine",
	PanelType.MOVEMENT: "Movement",
	PanelType.INPUT: "Input",
	PanelType.PHYSICS: "Physics State",
	PanelType.CLIMBING: "Climbing/Ledge",
	PanelType.RAYCASTS: "Raycasts",
	PanelType.PARAMETERS: "Parameters",
	PanelType.PERFORMANCE: "Performance"
}

func _ready():
	if not  enable_debug:
		return 
	_create_left_panel()
	_create_right_panel()
	
	# Create update timer
	update_timer = Timer.new()
	update_timer.wait_time = 0.05
	update_timer.timeout.connect(_update_debug_info)
	add_child(update_timer)
	update_timer.start()

func _create_left_panel():
	# Main container
	left_panel = PanelContainer.new()
	left_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	left_panel.position = Vector2(10, 10)
	add_child(left_panel)
	
	# Style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.75)
	style.border_color = Color(0.2, 0.6, 0.8, 1)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	left_panel.add_theme_stylebox_override("panel", style)
	
	# VBox for layout
	var vbox = VBoxContainer.new()
	left_panel.add_child(vbox)
	
	# Header with navigation
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 5)
	vbox.add_child(header)
	
	# Previous button
	left_prev_btn = Button.new()
	left_prev_btn.text = "◄"
	left_prev_btn.custom_minimum_size = Vector2(30, 30)
	left_prev_btn.pressed.connect(_on_left_prev)
	header.add_child(left_prev_btn)
	
	# Title
	left_title = Label.new()
	left_title.custom_minimum_size = Vector2(280, 30)
	left_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	left_title.add_theme_font_size_override("font_size", 16)
	left_title.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0))
	header.add_child(left_title)
	
	# Next button
	left_next_btn = Button.new()
	left_next_btn.text = "►"
	left_next_btn.custom_minimum_size = Vector2(30, 30)
	left_next_btn.pressed.connect(_on_left_next)
	header.add_child(left_next_btn)
	
	# Content label
	left_label = RichTextLabel.new()
	left_label.bbcode_enabled = true
	left_label.fit_content = true
	left_label.scroll_active = false
	left_label.custom_minimum_size = Vector2(350, 200)
	left_label.add_theme_font_size_override("normal_font_size", 13)
	vbox.add_child(left_label)
	
	_update_left_title()

func _create_right_panel():
	# Main container
	right_panel = PanelContainer.new()
	right_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right_panel.position = Vector2(-10, 10)
	right_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(right_panel)
	
	# Style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.75)
	style.border_color = Color(0.8, 0.4, 0.2, 1)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	right_panel.add_theme_stylebox_override("panel", style)
	
	# VBox for layout
	var vbox = VBoxContainer.new()
	right_panel.add_child(vbox)
	
	# Header with navigation
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 5)
	vbox.add_child(header)
	
	# Previous button
	right_prev_btn = Button.new()
	right_prev_btn.text = "◄"
	right_prev_btn.custom_minimum_size = Vector2(30, 30)
	right_prev_btn.pressed.connect(_on_right_prev)
	header.add_child(right_prev_btn)
	
	# Title
	right_title = Label.new()
	right_title.custom_minimum_size = Vector2(280, 30)
	right_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	right_title.add_theme_font_size_override("font_size", 16)
	right_title.add_theme_color_override("font_color", Color(1.0, 0.6, 0.3))
	header.add_child(right_title)
	
	# Next button
	right_next_btn = Button.new()
	right_next_btn.text = "►"
	right_next_btn.custom_minimum_size = Vector2(30, 30)
	right_next_btn.pressed.connect(_on_right_next)
	header.add_child(right_next_btn)
	
	# Content label
	right_label = RichTextLabel.new()
	right_label.bbcode_enabled = true
	right_label.fit_content = true
	right_label.scroll_active = false
	right_label.custom_minimum_size = Vector2(350, 200)
	right_label.add_theme_font_size_override("normal_font_size", 13)
	vbox.add_child(right_label)
	
	_update_right_title()

func _input(event):
	# Toggle debug UI with F3
	if event.is_action_pressed("ui_text_completion_replace") and enable_debug:
		is_visible = !is_visible
		left_panel.visible = is_visible
		right_panel.visible = is_visible

func _on_left_prev():
	left_current_panel = (left_current_panel - 1) % panel_names.size()
	if left_current_panel < 0:
		left_current_panel = panel_names.size() - 1
	_update_left_title()

func _on_left_next():
	left_current_panel = (left_current_panel + 1) % panel_names.size()
	_update_left_title()

func _on_right_prev():
	right_current_panel = (right_current_panel - 1) % panel_names.size()
	if right_current_panel < 0:
		right_current_panel = panel_names.size() - 1
	_update_right_title()

func _on_right_next():
	right_current_panel = (right_current_panel + 1) % panel_names.size()
	_update_right_title()

func _update_left_title():
	left_title.text = panel_names[left_current_panel]

func _update_right_title():
	right_title.text = panel_names[right_current_panel]

func _update_debug_info():
	if !player or !state_machine or !is_visible:
		return
	
	left_label.text = _get_panel_content(left_current_panel)
	right_label.text = _get_panel_content(right_current_panel)

func _get_panel_content(panel_type: int) -> String:
	var text = ""
	
	match panel_type:
		PanelType.STATE_MACHINE:
			text += "[b][color=cyan]State Machine Info[/color][/b]\n\n"
			text += "[b]Current State:[/b]\n"
			text += "  [color=lime]%s[/color]\n\n" % state_machine.get_current_state_name()
			if state_machine.previous_state:
				text += "[b]Previous State:[/b]\n"
				text += "  [color=gray]%s[/color]\n\n" % state_machine.previous_state.name
			text += "[color=gray][i]The state machine controls\nplayer behavior modes[/i][/color]"
		
		PanelType.MOVEMENT:
			text += "[b][color=cyan]Movement Data[/color][/b]\n\n"
			text += "[b]Position:[/b]\n"
			text += "  %s\n\n" % _format_vector3(player.global_transform.origin)
			text += "[b]Velocity:[/b]\n"
			text += "  %s\n\n" % _format_vector3(player.velocity)
			text += "[b]Speed:[/b] [color=white]%.2f m/s[/color]\n" % player.velocity.length()
			text += "[b]H-Speed:[/b] [color=white]%.2f m/s[/color]\n" % Vector2(player.velocity.x, player.velocity.z).length()
			text += "[b]V-Speed:[/b] [color=white]%.2f m/s[/color]\n" % player.velocity.y
			text += "[b]Current Speed:[/b] [color=white]%.2f[/color]\n" % player.SPEED
		
		PanelType.INPUT:
			text += "[b][color=cyan]Input States[/color][/b]\n\n"
			var input_dir = player.get_movement_input()
			text += "[b]Input Vector:[/b]\n"
			text += "  %s\n\n" % _format_vector2(input_dir)
			text += "[b]Move Direction:[/b]\n"
			text += "  %s\n\n" % _format_vector3(player.get_move_direction())
			text += "[b]States:[/b]\n"
			text += "  Moving: [color=%s]%s[/color]\n" % ["lime" if player.is_moving() else "red", "YES" if player.is_moving() else "NO"]
			text += "  Sprinting: [color=%s]%s[/color]\n" % ["lime" if player.is_sprinting() else "red", "YES" if player.is_sprinting() else "NO"]
			text += "  Crouching: [color=%s]%s[/color]\n" % ["lime" if player.is_crouching() else "red", "YES" if player.is_crouching() else "NO"]
			text += "  Leaning: [color=%s]%s[/color]\n" % ["lime" if player.is_leaning() else "red", "YES" if player.is_leaning() else "NO"]
		
		PanelType.PHYSICS:
			text += "[b][color=cyan]Physics State[/color][/b]\n\n"
			text += "[b]Ground Detection:[/b]\n"
			text += "  On Floor: [color=%s]%s[/color]\n" % ["lime" if player.is_on_floor() else "red", "YES" if player.is_on_floor() else "NO"]
			text += "  On Wall: [color=%s]%s[/color]\n" % ["lime" if player.is_on_wall() else "red", "YES" if player.is_on_wall() else "NO"]
			text += "  On Ceiling: [color=%s]%s[/color]\n\n" % ["lime" if player.is_on_ceiling() else "red", "YES" if player.is_on_ceiling() else "NO"]
			if player.is_on_wall():
				text += "[b]Wall Normal:[/b]\n"
				text += "  %s\n" % _format_vector3(player.get_wall_normal())
		
		PanelType.CLIMBING:
			text += "[b][color=cyan]Climbing & Ledge[/color][/b]\n\n"
			text += "[b]Abilities:[/b]\n"
			text += "  Can Climb:\n    [color=%s]%s[/color]\n" % ["lime" if player.can_climb() else "red", "YES" if player.can_climb() else "NO"]
			text += "  Ledge Detected:\n    [color=%s]%s[/color]\n" % ["lime" if player.is_ledge_detect() else "red", "YES" if player.is_ledge_detect() else "NO"]
			text += "  Can Wall Run:\n    [color=%s]%s[/color]\n" % ["lime" if player.can_wall_run() else "red", "YES" if player.can_wall_run() else "NO"]
			text += "  Wall Run Enabled:\n    [color=%s]%s[/color]\n\n" % ["lime" if player.can_wall_run_bool else "red", "YES" if player.can_wall_run_bool else "NO"]
			text += "[b]Hit Data:[/b]\n"
			text += "  Hit Point 2:\n    %s\n" % _format_vector3(player.hit_point2)
			text += "  Distance: [color=white]%.2f[/color]\n" % player.current_distance
		
		PanelType.RAYCASTS:
			text += "[b][color=cyan]Raycast Detection[/color][/b]\n\n"
			text += "[b]Cast States:[/b]\n"
			text += "  Head Cast:\n    [color=%s]%s[/color]\n" % ["orange" if player.head_Cast.is_colliding() else "gray", "COLLIDING" if player.head_Cast.is_colliding() else "Clear"]
			text += "  Chest Cast:\n    [color=%s]%s[/color]\n" % ["orange" if player.chest_Cast.is_colliding() else "gray", "COLLIDING" if player.chest_Cast.is_colliding() else "Clear"]
			text += "  Mid Chest:\n    [color=%s]%s[/color]\n" % ["orange" if player.mid_chest_Cast.is_colliding() else "gray", "COLLIDING" if player.mid_chest_Cast.is_colliding() else "Clear"]
			text += "  Upper Chest:\n    [color=%s]%s[/color]\n" % ["orange" if player.upperchest_Cast.is_colliding() else "gray", "COLLIDING" if player.upperchest_Cast.is_colliding() else "Clear"]
			text += "  H Cast Up:\n    [color=%s]%s[/color]\n" % ["orange" if player.h_cast_up.is_colliding() else "gray", "COLLIDING" if player.h_cast_up.is_colliding() else "Clear"]
			text += "  R Cast:\n    [color=%s]%s[/color]\n" % ["orange" if player.r_cast.is_colliding() else "gray", "COLLIDING" if player.r_cast.is_colliding() else "Clear"]
		
		PanelType.PARAMETERS:
			text += "[b][color=cyan]Movement Parameters[/color][/b]\n\n"
			text += "[b]Speed Settings:[/b]\n"
			text += "  Walk Speed:\n    [color=white]%.2f[/color]\n" % player.WALK_SPEED
			text += "  Sprint Speed:\n    [color=white]%.2f[/color]\n" % player.SPRINT_SPEED
			text += "  Jump Velocity:\n    [color=white]%.2f[/color]\n\n" % player.JUMP_VELOCITY
			text += "[b]Physics:[/b]\n"
			text += "  Gravity:\n    [color=white]%.2f[/color]\n\n" % player.gravity
			text += "[b]Dash Direction:[/b]\n"
			text += "  %s\n" % _format_vector3(player.dash_direction)
		
		PanelType.PERFORMANCE:
			text += "[b][color=cyan]Performance Metrics[/color][/b]\n\n"
			text += "[b]Frame Rates:[/b]\n"
			text += "  FPS:\n    [color=lime]%d[/color]\n" % Engine.get_frames_per_second()
			text += "  Physics FPS:\n    [color=lime]%.1f[/color]\n\n" % (1.0 / get_physics_process_delta_time() if get_physics_process_delta_time() > 0 else 0)
			text += "[b]Memory:[/b]\n"
			text += "  Static: [color=white]%.2f MB[/color]\n" % (OS.get_static_memory_usage() / 1048576.0)
			text += "\n[color=gray][i]Press F3 to toggle UI[/i][/color]"
	
	return text

func _format_vector3(vec: Vector3) -> String:
	return "[color=white]X: %.2f Y: %.2f Z: %.2f[/color]" % [vec.x, vec.y, vec.z]

func _format_vector2(vec: Vector2) -> String:
	return "[color=white]X: %.2f Y: %.2f[/color]" % [vec.x, vec.y]
