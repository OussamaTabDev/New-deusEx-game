class_name PlayerAudioComponent
extends Node

## Handles all player audio including footsteps, jumps, slides, and landings
## Syncs footsteps with camera head bob for natural movement feel

# ============================================================
# REFERENCES
# ============================================================
@export var player: CharacterBody3D
@export var footstep_player: Node  # Your FootstepPlayer node
@export var footstep_surface_detector: FootstepSurfaceDetector

# ============================================================
# AUDIO SETTINGS
# ============================================================
@export_category("Volume Settings")
@export var walk_volume_db: float = -38.0
@export var sprint_volume_db: float = -30.0
@export var crouch_volume_db: float = -60.0

@export_category("Movement Sounds")
@export var jump_sound: AudioStream
@export var slide_sound: AudioStream
@export var dash_sound: AudioStream
@export var climb_sound: AudioStream  # Looping climb/ladder sound
@export var wallrun_sound: AudioStream  # Looping wallrun sound
@export var swim_sound: AudioStream  # Looping swim sound
@export var water_splash_enter: AudioStream
@export var water_splash_exit: AudioStream

@export_subgroup("Audio Players")
@export var jump_audio_player: AudioStreamPlayer3D
@export var slide_audio_player: AudioStreamPlayer3D
@export var dash_audio_player: AudioStreamPlayer3D
@export var climb_audio_player: AudioStreamPlayer3D
@export var wallrun_audio_player: AudioStreamPlayer3D
@export var swim_audio_player: AudioStreamPlayer3D
@export var water_splash_player: AudioStreamPlayer3D

@export_category("Landing Audio")
@export var landing_audio_player: AudioStreamPlayer3D
@export var landing_threshold: float = -2.0
@export var max_landing_velocity: float = -8.0
@export var min_landing_velocity: float = -2.0
@export var max_volume_db: float = 0.0
@export var min_volume_db: float = -40.0
@export var max_pitch: float = 0.8
@export var min_pitch: float = 0.7

@export_category("Footstep Timing")
@export var footstep_speed_threshold: float = 0.5  # Minimum speed to play footsteps
@export var phase_trigger_tolerance: float = 0.1  # How precise the phase detection is (0.0-0.5)

# ============================================================
# INTERNAL STATE
# ============================================================
var _footstep_triggered_left: bool = false
var _footstep_triggered_right: bool = false
var _last_bob_height: float = 0.0
var _previous_velocity: Vector3 = Vector3.ZERO
var _was_in_air: bool = false

# ============================================================
# INITIALIZATION
# ============================================================
func _ready():
	if not player:
		push_error("PlayerAudioComponent: Player reference not set!")
	
	# Auto-find or create audio players if not set
	if not jump_audio_player:
		jump_audio_player = _find_or_create_audio_player("JumpAudioPlayer")
	if not slide_audio_player:
		slide_audio_player = _find_or_create_audio_player("SlideAudioPlayer")
	if not landing_audio_player:
		landing_audio_player = _find_or_create_audio_player("LandingAudioPlayer")
	if not dash_audio_player:
		dash_audio_player = _find_or_create_audio_player("DashAudioPlayer")
	if not climb_audio_player:
		climb_audio_player = _find_or_create_audio_player("ClimbAudioPlayer")
	if not wallrun_audio_player:
		wallrun_audio_player = _find_or_create_audio_player("WallRunAudioPlayer")
	if not swim_audio_player:
		swim_audio_player = _find_or_create_audio_player("SwimAudioPlayer")
	if not water_splash_player:
		water_splash_player = _find_or_create_audio_player("WaterSplashPlayer")

func _find_or_create_audio_player(node_name: String) -> AudioStreamPlayer3D:
	var existing = get_node_or_null(node_name)
	if existing and existing is AudioStreamPlayer3D:
		return existing
	
	var new_player = AudioStreamPlayer3D.new()
	new_player.name = node_name
	add_child(new_player)
	return new_player

# ============================================================
# PHYSICS UPDATE
# ============================================================
func _physics_process(_delta: float):
	if not player:
		return
	
	# Check for landing
	_check_landing()
	
	_previous_velocity = player.velocity

# ============================================================
# FOOTSTEP SYSTEM (Called from CameraController)
# ============================================================
func process_footstep_sync(bob_time: float, bob_freq: float, bob_amp: float, state_name: String) -> void:
	"""
	Call this from CameraController's _update_camera() during head bob calculation.
	bob_time: The t_bob value from camera
	bob_freq: BOB_FREQ from camera
	bob_amp: BOB_AMP from camera
	state_name: Current state machine state
	"""
	if not player or not footstep_player:
		return
	
	# Only play footsteps when moving on ground
	if not player.is_on_floor() or player.velocity.length() < footstep_speed_threshold:
		_reset_footstep_triggers()
		return
	
	# Calculate current phase of bob cycle (0 to 2π)
	var current_phase = fmod(bob_time * bob_freq, TAU) / 2 
	
	# LEFT FOOT: Trigger at bottom of sine wave (around π)
	var left_trigger_min = PI * (1.0 - phase_trigger_tolerance)
	var left_trigger_max = PI * (1.0 + phase_trigger_tolerance)
	
	if current_phase > left_trigger_min and current_phase < left_trigger_max:
		if not _footstep_triggered_left:
			_footstep_triggered_left = true
			play_footstep(state_name)
	elif current_phase < left_trigger_min * 0.9 or current_phase > left_trigger_max * 1.1:
		_footstep_triggered_left = false
	
	# RIGHT FOOT: Trigger at top of sine wave (around 0 or 2π)
	var right_trigger = PI * phase_trigger_tolerance
	
	if current_phase < right_trigger or current_phase > (TAU - right_trigger):
		if not _footstep_triggered_right:
			_footstep_triggered_right = true
			play_footstep(state_name)
	elif current_phase > right_trigger * 2.0 and current_phase < (TAU - right_trigger * 2.0):
		_footstep_triggered_right = false

func process_footstep_sync_simple(bob_time: float, bob_freq: float, bob_amp: float, state_name: String) -> void:
	"""
	Simpler alternative: Triggers on downward zero-crossing of bob cycle.
	More predictable but only one footstep per cycle instead of two.
	"""
	if not player or not footstep_player:
		return
	
	if not player.is_on_floor() or player.velocity.length() < footstep_speed_threshold:
		_last_bob_height = 0.0
		return
	
	var bob_height = sin(bob_time * bob_freq) * bob_amp
	
	# Trigger on downward zero crossing
	if _last_bob_height > 0.0 and bob_height <= 0.0:
		play_footstep(state_name)
	
	_last_bob_height = bob_height

func _reset_footstep_triggers() -> void:
	_footstep_triggered_left = false
	_footstep_triggered_right = false

# ============================================================
# FOOTSTEP PLAYBACK
# ============================================================
func play_footstep(state_name: String) -> void:
	"""Plays a footstep sound with appropriate volume for the current state"""
	if not footstep_player:
		return
	
	# States that shouldn't play footsteps
	var silent_states = [
		"IdleState",
		"JumpingState",
		"FallingState",
		"ClimbState",
		"DashState",
		"SlidingState",
		"WallRunState",
		"LadderClimbState",
		"SwimmingState",
		"SprintSwimmingState",
		"SurfaceSwimmingState"
	]
	
	if state_name in silent_states:
		return
	
	# Set volume based on state
	match state_name:
		"SprintingState":
			footstep_player.volume_db = sprint_volume_db
		"CrouchWalkingState":
			footstep_player.volume_db = crouch_volume_db
		"WalkingState":
			footstep_player.volume_db = walk_volume_db
		_:
			# Default to walk volume for any other walking states
			footstep_player.volume_db = walk_volume_db
	
	# Play the footstep (assuming your FootstepPlayer has this method)
	if footstep_player.has_method("_play_interaction"):
		footstep_player._play_interaction("footstep")
	elif footstep_player.has_method("play"):
		footstep_player.play()

# ============================================================
# MOVEMENT SOUNDS
# ============================================================
func play_jump_sound() -> void:
	"""Call this when player jumps"""
	if jump_audio_player and jump_sound:
		jump_audio_player.stream = jump_sound
		jump_audio_player.play()

func play_slide_sound() -> void:
	"""Call this when player starts sliding"""
	if slide_audio_player and slide_sound:
		slide_audio_player.stream = slide_sound
		slide_audio_player.play()

func stop_slide_sound() -> void:
	"""Call this when player stops sliding"""
	if slide_audio_player:
		slide_audio_player.stop()

func play_dash_sound() -> void:
	"""Call this when player dashes"""
	if dash_audio_player and dash_sound:
		dash_audio_player.stream = dash_sound
		dash_audio_player.play()

func play_climb_sound() -> void:
	"""Call this when player starts climbing (looping)"""
	if climb_audio_player and climb_sound:
		climb_audio_player.stream = climb_sound
		if not climb_audio_player.playing:
			climb_audio_player.play()

func stop_climb_sound() -> void:
	"""Call this when player stops climbing"""
	if climb_audio_player:
		climb_audio_player.stop()

func play_wallrun_sound() -> void:
	"""Call this when player starts wall running (looping)"""
	if wallrun_audio_player and wallrun_sound:
		wallrun_audio_player.stream = wallrun_sound
		if not wallrun_audio_player.playing:
			wallrun_audio_player.play()

func stop_wallrun_sound() -> void:
	"""Call this when player stops wall running"""
	if wallrun_audio_player:
		wallrun_audio_player.stop()

func play_swim_sound() -> void:
	"""Call this when player is swimming (looping)"""
	if swim_audio_player and swim_sound:
		swim_audio_player.stream = swim_sound
		if not swim_audio_player.playing:
			swim_audio_player.play()

func stop_swim_sound() -> void:
	"""Call this when player stops swimming"""
	if swim_audio_player:
		swim_audio_player.stop()

func play_water_splash(entering: bool = true) -> void:
	"""Call this when player enters/exits water"""
	if water_splash_player:
		if entering and water_splash_enter:
			water_splash_player.stream = water_splash_enter
			water_splash_player.play()
		elif not entering and water_splash_exit:
			water_splash_player.stream = water_splash_exit
			water_splash_player.play()

# ============================================================
# STATE-BASED AUDIO MANAGEMENT
# ============================================================
func handle_state_audio(state_name: String, is_entering: bool = true) -> void:
	"""
	Automatically handles all state-based audio.
	Call this from your state machine when entering/exiting states.
	
	Usage in your State class:
	func enter(previous_state):
	    player.audio_component.handle_state_audio(name, true)
	
	func exit(next_state):
	    player.audio_component.handle_state_audio(name, false)
	"""
	
	if is_entering:
		match state_name:
			"JumpingState":
				play_jump_sound()
			
			"SlidingState":
				play_slide_sound()
			
			"DashState":
				play_dash_sound()
			
			"ClimbState", "LadderClimbState":
				play_climb_sound()
			
			"WallRunState":
				play_wallrun_sound()
			
			"SwimmingState", "SprintSwimmingState", "SurfaceSwimmingState":
				play_swim_sound()
				# Check if just entered water
				if player and player.has_method("is_in_water"):
					play_water_splash(true)
	else:
		# Exiting state - stop looping sounds
		match state_name:
			"SlidingState":
				stop_slide_sound()
			
			"ClimbState", "LadderClimbState":
				stop_climb_sound()
			
			"WallRunState":
				stop_wallrun_sound()
			
			"SwimmingState", "SprintSwimmingState", "SurfaceSwimmingState":
				stop_swim_sound()
				# Check if just exited water
				if player and player.has_method("is_in_water"):
					if not player.is_in_water():
						play_water_splash(false)

# ============================================================
# LANDING DETECTION & SOUND
# ============================================================
func _check_landing() -> void:
	"""Automatically detects landing and plays appropriate sound"""
	var is_in_air = not player.is_on_floor()
	var just_landed = _was_in_air and not is_in_air
	
	if just_landed:
		var fall_velocity = _previous_velocity.y
		
		if fall_velocity < landing_threshold:
			_play_landing_sound(fall_velocity)
	
	_was_in_air = is_in_air

func _play_landing_sound(fall_velocity: float) -> void:
	"""Plays landing sound with dynamic volume and pitch based on fall speed"""
	if not landing_audio_player:
		return
	
	# Clamp velocity to our range
	var clamped_velocity = clamp(fall_velocity, max_landing_velocity, min_landing_velocity)
	
	# Calculate normalized impact strength (0.0 = soft, 1.0 = hard)
	var impact_strength = inverse_lerp(min_landing_velocity, max_landing_velocity, clamped_velocity)
	
	# Set volume and pitch based on impact
	landing_audio_player.volume_db = lerp(min_volume_db, max_volume_db, impact_strength)
	landing_audio_player.pitch_scale = lerp(max_pitch, min_pitch, impact_strength)
	
	landing_audio_player.play()

# ============================================================
# LEGACY COMPATIBILITY
# ============================================================
func _audio_process(state: String) -> void:
	"""
	Legacy method for manual footstep triggering from states.
	Kept for backwards compatibility but recommend using sync method instead.
	"""
	play_footstep(state)

# ============================================================
# PUBLIC HELPERS
# ============================================================
func set_footstep_volume(volume_db: float) -> void:
	"""Temporarily override footstep volume"""
	if footstep_player:
		footstep_player.volume_db = volume_db

func is_playing_footsteps() -> bool:
	"""Check if footsteps are currently playing"""
	if not footstep_player:
		return false
	if footstep_player.has_method("playing"):
		return footstep_player.playing
	return false