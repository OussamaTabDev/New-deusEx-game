@tool
## Dynamic FPS Crosshair System for Godot 4.5
extends Control

# ============================================================================
# SIGNALS
# ============================================================================
signal spread_changed(new_spread: float)
signal hitmarker_shown()
signal profile_loaded(profile_name: String)
signal crosshair_toggled(is_enabled: bool)

# ============================================================================
# ENUMS
# ============================================================================
enum RenderMode { CANVAS_LAYER, VIEWPORT, WORLD }
enum DotShape { CIRCLE, SQUARE, TEXTURE }
enum EasingType { LINEAR, EASE_IN, EASE_OUT, EASE_IN_OUT, EXPO }
enum ArmTextureMode { STRETCH, TILE, FIT }

# ============================================================================
# GLOBAL LAYOUT
# ============================================================================
@export_group("Global Layout")
@export var enabled: bool = true:
	set(value):
		enabled = value
		crosshair_toggled.emit(enabled)
		queue_redraw()

@export var render_mode: RenderMode = RenderMode.CANVAS_LAYER:
	set(value):
		render_mode = value
		# No visual change in editor? Might not need redraw, but safe to include
		queue_redraw()

@export_range(0, 100) var canvas_layer_index: int = 10:
	set(value):
		canvas_layer_index = value
		# This affects rendering layer, not geometry—no redraw needed, but harmless
		queue_redraw()

@export var anchor: Vector2 = Vector2(0.5, 0.5):
	set(value):
		anchor = value
		queue_redraw()

@export var position_offset: Vector2 = Vector2.ZERO:
	set(value):
		position_offset = value
		queue_redraw()

@export_range(0.01, 10.0, 0.01) var crosshair_scale: float = 1.0:
	set(value):
		crosshair_scale = value
		queue_redraw()

@export var z_index_custom: int = 0:
	set(value):
		z_index_custom = value
		queue_redraw()

# ============================================================================
# APPEARANCE
# ============================================================================
@export_group("Appearance")
@export var base_color: Color = Color.WHITE:
	set(value):
		base_color = value
		queue_redraw()

@export var secondary_color: Color = Color(1, 1, 1, 0):
	set(value):
		secondary_color = value
		queue_redraw()

@export_range(0.0, 1.0, 0.01) var opacity: float = 1.0:
	set(value):
		opacity = value
		queue_redraw()

@export var outline_enabled: bool = true:
	set(value):
		outline_enabled = value
		queue_redraw()

@export var outline_color: Color = Color.BLACK:
	set(value):
		outline_color = value
		queue_redraw()

@export_range(0.0, 10.0, 0.1) var outline_thickness: float = 1.0:
	set(value):
		outline_thickness = value
		queue_redraw()

@export var shadow_enabled: bool = false:
	set(value):
		shadow_enabled = value
		queue_redraw()

@export var shadow_offset: Vector2 = Vector2(2, 2):
	set(value):
		shadow_offset = value
		queue_redraw()

@export_range(0.0, 20.0, 0.5) var shadow_blur: float = 4.0:
	set(value):
		shadow_blur = value
		queue_redraw()

@export var use_texture: bool = false:
	set(value):
		use_texture = value
		queue_redraw()

@export var texture: Texture2D = null:
	set(value):
		texture = value
		queue_redraw()

# ============================================================================
# CENTER DOT
# ============================================================================
@export_group("Center Dot")
@export var dot_enabled: bool = false:
	set(value):
		dot_enabled = value
		queue_redraw()

@export_range(1.0, 50.0, 0.5) var dot_size: float = 4.0:
	set(value):
		dot_size = value
		queue_redraw()

@export var dot_shape: DotShape = DotShape.CIRCLE:
	set(value):
		dot_shape = value
		queue_redraw()

@export var dot_color: Color = Color.WHITE:
	set(value):
		dot_color = value
		queue_redraw()

# ============================================================================
# ARMS / BARS
# ============================================================================
@export_group("Arms")
@export var arms_enabled: bool = true:
	set(value):
		arms_enabled = value
		queue_redraw()

@export_range(2, 8) var arm_count: int = 4:
	set(value):
		arm_count = value
		queue_redraw()

@export_range(1.0, 100.0, 0.5) var arm_length: float = 10.0:
	set(value):
		arm_length = value
		queue_redraw()

@export_range(0.5, 20.0, 0.1) var arm_thickness: float = 2.0:
	set(value):
		arm_thickness = value
		queue_redraw()

@export_range(0.0, 100.0, 0.5) var arm_gap: float = 6.0:
	set(value):
		arm_gap = value
		queue_redraw()

@export_range(-180.0, 180.0, 1.0) var arm_rotation: float = 0.0:
	set(value):
		arm_rotation = value
		queue_redraw()

@export var arm_curved: bool = false:
	set(value):
		arm_curved = value
		queue_redraw()

@export var arm_texture_mode: ArmTextureMode = ArmTextureMode.STRETCH:
	set(value):
		arm_texture_mode = value
		queue_redraw()

@export_subgroup("Per-Arm Overrides")
@export var use_per_arm_override: bool = false:
	set(value):
		use_per_arm_override = value
		queue_redraw()

@export var arm_up_length: float = 10.0:
	set(value):
		arm_up_length = value
		queue_redraw()

@export var arm_down_length: float = 10.0:
	set(value):
		arm_down_length = value
		queue_redraw()

@export var arm_left_length: float = 10.0:
	set(value):
		arm_left_length = value
		queue_redraw()

@export var arm_right_length: float = 10.0:
	set(value):
		arm_right_length = value
		queue_redraw()

# ============================================================================
# CIRCLE / RING
# ============================================================================
@export_group("Ring")
@export var ring_enabled: bool = false:
	set(value):
		ring_enabled = value
		queue_redraw()

@export_range(5.0, 200.0, 1.0) var ring_radius: float = 20.0:
	set(value):
		ring_radius = value
		queue_redraw()

@export_range(0.5, 20.0, 0.1) var ring_thickness: float = 2.0:
	set(value):
		ring_thickness = value
		queue_redraw()

@export_range(8, 128) var ring_segments: int = 64:
	set(value):
		ring_segments = value
		queue_redraw()

@export_range(0.0, 1.0, 0.01) var ring_fill: float = 1.0:
	set(value):
		ring_fill = value
		queue_redraw()

# ============================================================================
# SPREAD & DYNAMICS
# ============================================================================
@export_group("Spread & Dynamics")
@export var base_spread: float = 0.0:
	set(value):
		base_spread = value
		queue_redraw()

@export var movement_spread_scale: float = 1.0:
	set(value):
		movement_spread_scale = value
		queue_redraw()

@export_range(0.0, 200.0, 1.0) var max_spread: float = 50.0:
	set(value):
		max_spread = value
		queue_redraw()

@export_range(0.0, 50.0, 0.5) var min_spread: float = 0.0:
	set(value):
		min_spread = value
		queue_redraw()

@export_range(0.1, 50.0, 0.1) var spread_smoothing: float = 10.0:
	set(value):
		spread_smoothing = value
		queue_redraw()

@export var spread_easing: EasingType = EasingType.EASE_OUT:
	set(value):
		spread_easing = value
		queue_redraw()

# ============================================================================
# SPREAD WEIGHTS
# ============================================================================
@export_group("Spread Weights")
@export_range(0.0, 2.0, 0.05) var movement_weight: float = 0.5:
	set(value):
		movement_weight = value
		queue_redraw()

@export_range(0.0, 2.0, 0.05) var velocity_weight: float = 0.5:
	set(value):
		velocity_weight = value
		queue_redraw()

@export_range(0.0, 2.0, 0.05) var in_air_weight: float = 1.0:
	set(value):
		in_air_weight = value
		queue_redraw()

@export_range(-1.0, 1.0, 0.05) var crouch_weight: float = 0.2:
	set(value):
		crouch_weight = value
		queue_redraw()

@export_range(0.0, 2.0, 0.05) var sprint_weight: float = 1.0:
	set(value):
		sprint_weight = value
		queue_redraw()

@export_range(-2.0, 0.0, 0.05) var aim_weight: float = -0.8:
	set(value):
		aim_weight = value
		queue_redraw()

@export_range(0.0, 50.0, 0.5) var fire_bloom_amount: float = 6.0:
	set(value):
		fire_bloom_amount = value
		queue_redraw()

@export_range(0.1, 30.0, 0.5) var fire_bloom_decay_rate: float = 8.0:
	set(value):
		fire_bloom_decay_rate = value
		queue_redraw()

# ============================================================================
# ADS (AIM DOWN SIGHTS)
# ============================================================================
@export_group("ADS")
@export var ads_enabled: bool = true:
	set(value):
		ads_enabled = value
		queue_redraw()

@export_range(0.0, 2.0, 0.05) var ads_scale: float = 0.5:
	set(value):
		ads_scale = value
		queue_redraw()

@export_range(0.0, 1.0, 0.05) var ads_opacity: float = 0.9:
	set(value):
		ads_opacity = value
		queue_redraw()

@export_range(0.01, 2.0, 0.01) var ads_transition_time: float = 0.12:
	set(value):
		ads_transition_time = value
		queue_redraw()

@export var ads_ease: EasingType = EasingType.EASE_IN_OUT:
	set(value):
		ads_ease = value
		queue_redraw()

# ============================================================================
# HITMARKER
# ============================================================================
@export_group("Hitmarker")
@export var hitmarker_enabled: bool = true:
	set(value):
		hitmarker_enabled = value
		queue_redraw()

@export_range(0.05, 2.0, 0.05) var hitmarker_duration: float = 0.25:
	set(value):
		hitmarker_duration = value
		queue_redraw()

@export_range(1.0, 5.0, 0.1) var hitmarker_scale: float = 1.4:
	set(value):
		hitmarker_scale = value
		queue_redraw()

@export var hitmarker_color: Color = Color.WHITE:
	set(value):
		hitmarker_color = value
		queue_redraw()

@export var hitmarker_sound: AudioStream = null:
	set(value):
		hitmarker_sound = value
		queue_redraw()

# ============================================================================
# COLOR STATES
# ============================================================================
@export_group("Color States")
@export var target_seen_color: Color = Color.RED:
	set(value):
		target_seen_color = value
		queue_redraw()

@export_range(0.0, 1.0, 0.05) var target_seen_opacity: float = 1.0:
	set(value):
		target_seen_opacity = value
		queue_redraw()

# ============================================================================
# ACCESSIBILITY
# ============================================================================
@export_group("Accessibility")
@export var high_contrast_mode: bool = false:
	set(value):
		high_contrast_mode = value
		queue_redraw()

@export var large_size_mode: bool = false:
	set(value):
		large_size_mode = value
		queue_redraw()

@export var colorblind_friendly: bool = false:
	set(value):
		colorblind_friendly = value
		queue_redraw()

# ============================================================================
# PERFORMANCE
# ============================================================================
@export_group("Performance")
@export_range(15, 120) var update_rate: int = 60:
	set(value):
		update_rate = value
		update_interval = 1.0 / float(update_rate)
		queue_redraw()  # optional, but safe

@export var use_subpixel: bool = true:
	set(value):
		use_subpixel = value
		queue_redraw()

# ============================================================================
# PERSISTENCE
# ============================================================================
@export_group("Persistence")
@export var save_profiles: bool = true:
	set(value):
		save_profiles = value
		queue_redraw()

@export var profiles_path: String = "user://crosshair_profiles.json":
	set(value):
		profiles_path = value
		queue_redraw()

# ============================================================================
# INTERNAL STATE (NOT EXPORTED – no setters needed)
# ============================================================================
var current_spread: float = 0.0
var target_spread: float = 0.0
var fire_bloom: float = 0.0

var is_aiming: bool = false
var ads_progress: float = 0.0

var is_sprinting: bool = false
var is_airborne: bool = false
var is_crouching: bool = false
var is_targeting: bool = false

var movement_speed: float = 0.0
var player_velocity: Vector3 = Vector3.ZERO

var hitmarker_timer: float = 0.0
var is_showing_hitmarker: bool = false

var custom_spread_override: float = -1.0

var screen_center: Vector2

var update_accumulator: float = 0.0
var update_interval: float = 1.0 / 60.0

# ============================================================================
# BUILT-IN METHODS
# ============================================================================
func _ready() -> void:
	set_process(true)
	update_interval = 1.0 / float(update_rate)
	_calculate_screen_center()
	queue_redraw()

func _process(delta: float) -> void:
	update_accumulator += delta
	
	# Update at specified rate
	if update_accumulator >= update_interval:
		update_accumulator -= update_interval
		_update_spread(delta)
		_update_hitmarker(delta)
		_update_ads(delta)

func _draw() -> void:
	if not enabled:
		return
	
	_calculate_screen_center()
	
	var final_opacity = opacity
	var final_scale = crosshair_scale
	var final_color = base_color
	
	# Apply ADS modifications
	if ads_enabled and is_aiming:
		final_scale *= lerp(1.0, ads_scale, ads_progress)
		final_opacity *= lerp(1.0, ads_opacity, ads_progress)
	
	# Apply targeting color
	if is_targeting:
		final_color = target_seen_color
		final_opacity = target_seen_opacity
	
	# Apply high contrast mode
	if high_contrast_mode:
		final_color = Color.WHITE
		outline_enabled = true
		outline_color = Color.BLACK
		outline_thickness = 2.0
	
	# Apply large size mode
	if large_size_mode:
		final_scale *= 1.5
	
	# Apply hitmarker
	if is_showing_hitmarker and hitmarker_enabled:
		final_scale *= hitmarker_scale
		final_color = hitmarker_color
	
	final_color.a = final_opacity
	
	# Draw shadow first
	if shadow_enabled:
		_draw_crosshair_elements(screen_center + shadow_offset, final_scale, Color(0, 0, 0, final_opacity * 0.5))
	
	# Draw outline
	if outline_enabled:
		var outline_col = outline_color
		outline_col.a = final_opacity
		_draw_crosshair_elements(screen_center, final_scale, outline_col, outline_thickness)
	
	# Draw main crosshair
	_draw_crosshair_elements(screen_center, final_scale, final_color)

func _draw_crosshair_elements(center: Vector2, scale_mult: float, color: Color, extra_thickness: float = 0.0) -> void:
	var spread_offset = current_spread * scale_mult
	var gap = (arm_gap + spread_offset) * scale_mult
	
	# Draw center dot
	if dot_enabled:
		var dot_sz = dot_size * scale_mult
		match dot_shape:
			DotShape.CIRCLE:
				draw_circle(center, dot_sz / 2.0, dot_color if extra_thickness == 0 else color)
			DotShape.SQUARE:
				var half = dot_sz / 2.0
				draw_rect(Rect2(center - Vector2(half, half), Vector2(dot_sz, dot_sz)), 
					dot_color if extra_thickness == 0 else color, true)
	
	# Draw arms
	if arms_enabled:
		var thickness = (arm_thickness + extra_thickness) * scale_mult
		var angle_step = 360.0 / float(arm_count)
		
		for i in range(arm_count):
			var angle_deg = (i * angle_step) + arm_rotation
			var angle_rad = deg_to_rad(angle_deg)
			var direction = Vector2(cos(angle_rad), sin(angle_rad))
			
			var length = arm_length
			if use_per_arm_override and arm_count == 4:
				match i:
					0: length = arm_up_length
					1: length = arm_right_length
					2: length = arm_down_length
					3: length = arm_left_length
			
			length *= scale_mult
			
			var start = center + direction * gap
			var end = center + direction * (gap + length)
			
			if arm_curved:
				_draw_curved_line(start, end, color, thickness)
			else:
				draw_line(start, end, color, thickness, true)
	
	# Draw ring
	if ring_enabled:
		var radius = (ring_radius + spread_offset) * scale_mult
		var thickness = (ring_thickness + extra_thickness) * scale_mult
		_draw_ring(center, radius, thickness, color, ring_segments, ring_fill)

func _draw_ring(center: Vector2, radius: float, thickness: float, color: Color, segments: int, fill_amount: float) -> void:
	var angle_step = TAU / float(segments)
	var angle_max = TAU * fill_amount
	
	for i in range(int(segments * fill_amount)):
		var angle1 = i * angle_step
		var angle2 = (i + 1) * angle_step
		
		if angle2 > angle_max:
			angle2 = angle_max
		
		var p1_outer = center + Vector2(cos(angle1), sin(angle1)) * radius
		var p2_outer = center + Vector2(cos(angle2), sin(angle2)) * radius
		
		draw_line(p1_outer, p2_outer, color, thickness, true)

func _draw_curved_line(start: Vector2, end: Vector2, color: Color, thickness: float) -> void:
	var segments = 8
	var control = (start + end) / 2.0 + (end - start).orthogonal().normalized() * 5.0
	
	for i in range(segments):
		var t1 = float(i) / float(segments)
		var t2 = float(i + 1) / float(segments)
		var p1 = _quadratic_bezier(start, control, end, t1)
		var p2 = _quadratic_bezier(start, control, end, t2)
		draw_line(p1, p2, color, thickness, true)

func _quadratic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var u = 1.0 - t
	return u * u * p0 + 2.0 * u * t * p1 + t * t * p2

# ============================================================================
# SPREAD UPDATE
# ============================================================================
func _update_spread(delta: float) -> void:
	# Calculate target spread from all sources
	var accumulated_spread = base_spread
	
	# Movement contribution
	if movement_speed > 0.0:
		accumulated_spread += movement_speed * movement_weight * movement_spread_scale
	
	# Velocity contribution
	if player_velocity.length() > 0.0:
		var vel_factor = clamp(player_velocity.length() / 300.0, 0.0, 1.0)
		accumulated_spread += vel_factor * velocity_weight * movement_spread_scale
	
	# State modifiers
	if is_airborne:
		accumulated_spread += max_spread * in_air_weight * 0.3
	
	if is_sprinting:
		accumulated_spread += max_spread * sprint_weight * 0.4
	
	if is_crouching:
		accumulated_spread += max_spread * crouch_weight * 0.1
	
	if is_aiming:
		accumulated_spread += max_spread * aim_weight
	
	# Fire bloom
	if fire_bloom > 0.0:
		accumulated_spread += fire_bloom
		fire_bloom = max(0.0, fire_bloom - fire_bloom_decay_rate * delta * 60.0)
	
	# Custom override
	if custom_spread_override >= 0.0:
		accumulated_spread = custom_spread_override
	
	target_spread = clamp(accumulated_spread, min_spread, max_spread)
	
	# Smooth interpolation
	var smooth_factor = clamp(delta * spread_smoothing, 0.0, 1.0)
	smooth_factor = _apply_easing(smooth_factor, spread_easing)
	
	var old_spread = current_spread
	current_spread = lerp(current_spread, target_spread, smooth_factor)
	
	if abs(current_spread - old_spread) > 0.01:
		spread_changed.emit(current_spread)
		queue_redraw()

func _update_ads(delta: float) -> void:
	var target_progress = 1.0 if is_aiming else 0.0
	var transition_speed = 1.0 / ads_transition_time
	var progress_delta = delta * transition_speed
	progress_delta = _apply_easing(progress_delta, ads_ease)
	
	ads_progress = move_toward(ads_progress, target_progress, progress_delta)
	
	if abs(ads_progress - target_progress) > 0.01:
		queue_redraw()

func _update_hitmarker(delta: float) -> void:
	if is_showing_hitmarker:
		hitmarker_timer -= delta
		if hitmarker_timer <= 0.0:
			is_showing_hitmarker = false
			queue_redraw()

func _apply_easing(t: float, easing: EasingType) -> float:
	match easing:
		EasingType.LINEAR:
			return t
		EasingType.EASE_IN:
			return t * t
		EasingType.EASE_OUT:
			return 1.0 - (1.0 - t) * (1.0 - t)
		EasingType.EASE_IN_OUT:
			return t * t * (3.0 - 2.0 * t)
		EasingType.EXPO:
			return t * t * t
		_:
			return t

# ============================================================================
# PUBLIC API
# ============================================================================
func set_enabled(is_enabled: bool) -> void:
	enabled = is_enabled

func set_scale_(scale_value: float) -> void:
	crosshair_scale = scale_value

func set_base_color(color: Color) -> void:
	base_color = color

func on_player_movement(speed: float) -> void:
	movement_speed = speed

func on_player_velocity(vel: Vector3) -> void:
	player_velocity = vel

func on_player_airborne(airborne: bool) -> void:
	is_airborne = airborne

func on_shot() -> void:
	fire_bloom = clamp(fire_bloom + fire_bloom_amount, 0.0, max_spread)
	queue_redraw()

func set_ads(active: bool) -> void:
	is_aiming = active

func set_sprinting(sprinting: bool) -> void:
	is_sprinting = sprinting

func set_crouching(crouching: bool) -> void:
	is_crouching = crouching

func set_custom_spread(value: float) -> void:
	custom_spread_override = value

func clear_custom_spread() -> void:
	custom_spread_override = -1.0

func world_targeted(state: bool) -> void:
	is_targeting = state
	queue_redraw()

func show_hitmarker() -> void:
	if hitmarker_enabled:
		is_showing_hitmarker = true
		hitmarker_timer = hitmarker_duration
		hitmarker_shown.emit()
		
		if hitmarker_sound:
			_play_hitmarker_sound()
		
		queue_redraw()

func _play_hitmarker_sound() -> void:
	var player = AudioStreamPlayer.new()
	add_child(player)
	player.stream = hitmarker_sound
	player.play()
	await player.finished
	player.queue_free()

# ============================================================================
# PROFILES
# ============================================================================
func set_profile(profile_name: String) -> bool:
	var presets = _get_default_presets()
	
	if profile_name in presets:
		_apply_profile(presets[profile_name])
		profile_loaded.emit(profile_name)
		return true
	
	# Try loading from file
	if save_profiles and FileAccess.file_exists(profiles_path):
		var loaded = load_profiles()
		if loaded and profile_name in loaded:
			_apply_profile(loaded[profile_name])
			profile_loaded.emit(profile_name)
			return true
	
	return false

func _apply_profile(data: Dictionary) -> void:
	for key in data:
		if key in self:
			set(key, data[key])
	queue_redraw()

func save_profile(profile_name: String) -> bool:
	if not save_profiles:
		return false
	
	var profiles = load_profiles()
	if profiles == null:
		profiles = {}
	
	profiles[profile_name] = _export_current_settings()
	
	var file = FileAccess.open(profiles_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(profiles, "\t"))
		file.close()
		return true
	
	return false

func load_profiles(path: String = "") -> Dictionary:
	var load_path = path if path != "" else profiles_path
	
	if not FileAccess.file_exists(load_path):
		return {}
	
	var file = FileAccess.open(load_path, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			return json.data
	
	return {}

func _export_current_settings() -> Dictionary:
	return {
		"base_color": base_color,
		"arm_length": arm_length,
		"arm_thickness": arm_thickness,
		"arm_gap": arm_gap,
		"dot_enabled": dot_enabled,
		"dot_size": dot_size,
		"ring_enabled": ring_enabled,
		"ring_radius": ring_radius,
		"base_spread": base_spread,
		"max_spread": max_spread,
		"movement_weight": movement_weight,
		"fire_bloom_amount": fire_bloom_amount,
		"ads_scale": ads_scale,
	}

func _get_default_presets() -> Dictionary:
	return {
		"Default": {
			"dot_enabled": false,
			"arms_enabled": true,
			"arm_length": 8.0,
			"arm_thickness": 2.0,
			"arm_gap": 6.0,
			"base_spread": 2.0,
			"movement_weight": 0.6,
			"ads_scale": 0.6,
		},
		"Sniper": {
			"dot_enabled": true,
			"dot_size": 2.0,
			"arms_enabled": false,
			"ring_enabled": true,
			"ring_radius": 28.0,
			"ring_thickness": 1.5,
			"base_spread": 0.2,
			"ads_scale": 0.2,
			"high_contrast_mode": true,
		},
		"Arcade": {
			"base_color": Color.CYAN,
			"arm_length": 20.0,
			"arm_thickness": 3.0,
			"hitmarker_scale": 2.0,
			"fire_bloom_amount": 12.0,
			"fire_bloom_decay_rate": 15.0,
		},
		"Minimal": {
			"dot_enabled": true,
			"dot_size": 3.0,
			"arms_enabled": false,
			"ring_enabled": false,
			"opacity": 0.6,
		},
		"Riot": {
			"arm_length": 12.0,
			"arm_thickness": 3.0,
			"arm_gap": 4.0,
			"dot_enabled": true,
			"base_spread": 5.0,
			"movement_weight": 0.8,
		},
	}

# @export var base_color: Color = Color.WHITE:
# 	set(value):
# 		base_color = value
# 		_toggle_refresh()

func _toggle_refresh():
	if enabled and not Engine.is_editor_hint():
		var was_enabled = enabled
		enabled = false
		enabled = was_enabled
# ============================================================================
# UTILITY
# ============================================================================
func _calculate_screen_center() -> void:
	screen_center = get_viewport_rect().size * anchor + position_offset