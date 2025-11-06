@tool
extends CenterContainer

# ============================================================================
# BASIC CROSSHAIR SETTINGS
# ============================================================================
@export_category("Crosshair Settings")
@export var crosshairThickness: float = 2.0:
	set(value):
		crosshairThickness = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

@export var crosshairSize: float = 10.0:
	set(value):
		crosshairSize = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

@export var crosshairGap: float = 5.0:
	set(value):
		crosshairGap = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

@export var crosshairColor: Color = Color.WHITE:
	set(value):
		crosshairColor = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

# ============================================================================
# STYLE SETTINGS
# ============================================================================
@export_group("Style Settings")
@export var crosshairLinesVisible: bool = true:
	set(value):
		crosshairLinesVisible = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

@export_enum("Line", "Arrow", "Inverse Arrow") var crosshairLineStyle: int = 0:
	set(value):
		crosshairLineStyle = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

@export_enum("None", "Round", "Square") var crosshairLineCap: int = 0:
	set(value):
		crosshairLineCap = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

@export var crosshairDot: bool = false:
	set(value):
		crosshairDot = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

@export_enum("Square", "Circle", "Diamond", "Cross", "Plus") var dotShape: int = 0:
	set(value):
		dotShape = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

@export_range(0.0, 10.0, 0.1) var dotCornerRadius: float = 0.0:
	set(value):
		dotCornerRadius = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

@export_range(0.1, 5.0, 0.1) var dotScale: float = 1.0:
	set(value):
		dotScale = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

@export var crosshairTStyle: bool = false:
	set(value):
		crosshairTStyle = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

# ============================================================================
# ADVANCED SHAPE MODES
# ============================================================================
@export_group("Advanced Shape Modes")
@export_enum("Standard", "Quad Brackets", "Tech Spikes", "Cross Arcs", "Rotating Hex", "Iris Aperture") var shapeMode: int = 0:
	set(value):
		shapeMode = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

@export var bracketCornerSize: float = 15.0:
	set(value):
		bracketCornerSize = value
		update_crosshair()

@export var spikeLength: float = 8.0:
	set(value):
		spikeLength = value
		update_crosshair()

@export var arcSegments: int = 16:
	set(value):
		arcSegments = max(4, value)
		update_crosshair()

@export var geometryRotationSpeed: float = 20.0:
	set(value):
		geometryRotationSpeed = value

@export var irisSegmentCount: int = 8:
	set(value):
		irisSegmentCount = clamp(value, 4, 16)
		update_crosshair()

# ============================================================================
# VISUAL EFFECTS
# ============================================================================
@export_group("Visual Effects")
@export var enableBloom: bool = false:
	set(value):
		enableBloom = value
		update_crosshair()

@export_range(0.0, 5.0, 0.1) var bloomIntensity: float = 1.0:
	set(value):
		bloomIntensity = value
		update_crosshair()

@export var enableChromaticAberration: bool = false
@export_range(0.0, 5.0, 0.1) var chromaticAberrationAmount: float = 1.0

@export var enableGlitchEffect: bool = false
@export_range(0.0, 1.0, 0.01) var glitchIntensity: float = 0.3

@export var enableDistortionRing: bool = false
@export_range(0.0, 10.0, 0.5) var distortionRadius: float = 25.0
@export_range(0.0, 5.0, 0.1) var distortionWaveSpeed: float = 2.0

@export var edgeSoftness: float = 0.0:
	set(value):
		edgeSoftness = max(0.0, value)
		update_crosshair()

@export var adaptiveOpacity: bool = false
@export_range(0.1, 1.0, 0.05) var minOpacity: float = 0.3
@export_range(0.1, 1.0, 0.05) var maxOpacity: float = 1.0

# ============================================================================
# SMART CONTEXT REACTIONS
# ============================================================================
@export_group("Context Reactions")
@export var enableInteractionPulse: bool = false
@export_range(0.5, 3.0, 0.1) var interactionPulseScale: float = 1.3
@export var interactionPulseColor: Color = Color(0.3, 0.8, 1.0)

@export var enableEnemyDetection: bool = false
@export var enemyDetectionColor: Color = Color(1.0, 0.3, 0.2)
@export_range(0.0, 1.0, 0.05) var enemyDetectionBlend: float = 0.5

@export var enableHitConfirm: bool = false
@export var hitConfirmColor: Color = Color(1.0, 0.5, 0.0)
@export_range(0.1, 1.0, 0.05) var hitConfirmDuration: float = 0.2

@export var enableDamageFeedback: bool = false
@export var damageFeedbackColor: Color = Color(1.0, 0.0, 0.0)

# ============================================================================
# MOTION & WEAPON FEEDBACK
# ============================================================================
@export_group("Motion Feedback")
@export var enableRecoilBloom: bool = false
@export_range(0.0, 50.0, 1.0) var maxRecoilBloom: float = 20.0
@export_range(0.1, 2.0, 0.05) var recoilRecoverySpeed: float = 0.8

@export var enableMovementBloom: bool = false
@export_range(0.0, 20.0, 0.5) var maxMovementBloom: float = 10.0

@export var enableLandingCompression: bool = false
@export_range(0.0, 1.0, 0.05) var landingCompressionAmount: float = 0.5
@export_range(0.1, 1.0, 0.05) var landingRecoverySpeed: float = 0.3

@export var enableBreathSync: bool = false
@export_range(0.5, 3.0, 0.1) var breathSyncSpeed: float = 1.5
@export_range(0.0, 3.0, 0.1) var breathSyncAmplitude: float = 1.0

@export var enableSprintFade: bool = false
@export_range(0.0, 1.0, 0.05) var sprintFadeAmount: float = 0.3

# ============================================================================
# OUTLINE SETTINGS
# ============================================================================
@export_subgroup("Outline Settings")
@export var crosshairOutline: bool = false:
	set(value):
		crosshairOutline = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

@export var crosshairOutlineThickness: float = 1.0:
	set(value):
		crosshairOutlineThickness = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

@export var crosshairOutlineColor: Color = Color.BLACK:
	set(value):
		crosshairOutlineColor = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

# ============================================================================
# HORIZONTAL LINES
# ============================================================================
@export_subgroup("Horizontal Lines Settings")
@export var crosshairHorizontalLines: bool = false:
	set(value):
		crosshairHorizontalLines = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

@export var crosshairHorizontalLinesPosition: float = 0.0:
	set(value):
		crosshairHorizontalLinesPosition = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

@export var crosshairHorizontalLinesThickness: float = 0.0:
	set(value):
		crosshairHorizontalLinesThickness = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

@export var crosshairHorizontalLinesLength: float = 0.0:
	set(value):
		crosshairHorizontalLinesLength = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

# ============================================================================
# CIRCLE MODE
# ============================================================================
@export_group("Circle Mode")
@export var circleMode: bool = false:
	set(value):
		circleMode = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

@export_range(5.0, 100.0, 0.5) var circleRadius: float = 20.0:
	set(value):
		circleRadius = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

@export_range(1.0, 10.0, 0.1) var circleThickness: float = 2.0:
	set(value):
		circleThickness = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

@export var circleColor: Color = Color(1, 1, 1, 0):
	set(value):
		circleColor = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

@export var circleOutline: bool = false:
	set(value):
		circleOutline = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

@export_range(0.5, 5.0, 0.1) var circleOutlineThickness: float = 1.0:
	set(value):
		circleOutlineThickness = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

@export var circleOutlineColor: Color = Color.BLACK:
	set(value):
		circleOutlineColor = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

@export_subgroup("Split Circle")
@export var splitCircle: bool = false:
	set(value):
		splitCircle = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

@export_range(2, 8, 1) var circleGapCount: int = 4:
	set(value):
		circleGapCount = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

@export_range(5.0, 90.0, 1.0) var circleGapSize: float = 20.0:
	set(value):
		circleGapSize = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

@export_range(0.0, 360.0, 1.0) var circleRotationOffset: float = 0.0:
	set(value):
		circleRotationOffset = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

# ============================================================================
# DYNAMIC EFFECTS
# ============================================================================
@export_group("Dynamic Effects")
@export var crosshairDynamic: bool = false:
	set(value):
		crosshairDynamic = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

@export var crosshairMaxDynamicOffset: float = 10.0:
	set(value):
		crosshairMaxDynamicOffset = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

# ============================================================================
# BREATHING ANIMATION
# ============================================================================
@export_subgroup("Breathing Animation")
@export var breathingEnabled: bool = false:
	set(value):
		breathingEnabled = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

@export_range(0.1, 5.0, 0.1) var breathingSpeed: float = 1.0
@export_range(0.5, 10.0, 0.1) var breathingAmplitude: float = 2.0
@export_enum("Sine", "Smooth Step", "Triangle", "Square") var breathingWaveform: int = 0

@export_subgroup("Dot Breathing")
@export var dotBreathingEnabled: bool = false
@export_range(0.1, 5.0, 0.1) var dotBreathingSpeed: float = 1.0
@export_range(0.1, 3.0, 0.05) var dotBreathingAmplitude: float = 0.3
@export_enum("Sine", "Smooth Step", "Triangle", "Square") var dotBreathingWaveform: int = 0
@export_range(0.0, 1.0, 0.05) var dotBreathingPhase: float = 0.0

@export_subgroup("Circle Breathing")
@export var circleBreathingEnabled: bool = false
@export_range(0.1, 5.0, 0.1) var circleBreathingSpeed: float = 1.0
@export_range(0.5, 20.0, 0.5) var circleBreathingAmplitude: float = 3.0
@export_enum("Sine", "Smooth Step", "Triangle", "Square") var circleBreathingWaveform: int = 0
@export_range(0.0, 1.0, 0.05) var circleBreathingPhase: float = 0.0
@export var circleRotationEnabled: bool = false
@export_range(-360.0, 360.0, 1.0) var circleRotationSpeed: float = 30.0
@export var circleThicknessPulse: bool = false
@export_range(0.1, 5.0, 0.1) var circleThicknessPulseAmplitude: float = 1.0

# ============================================================================
# ANIMATION EASING
# ============================================================================
@export_group("Animation Easing")
@export_enum("Linear", "Elastic", "Bounce", "Back") var transitionEasing: int = 0
@export_range(0.1, 2.0, 0.05) var transitionSpeed: float = 1.0

# ============================================================================
# PRESET SYSTEM
# ============================================================================
@export_group("Preset System")
@export_enum("Custom", "Minimalist", "Tech", "Classic FPS", "Immersive Sim", "Psychic", "Broken HUD") var currentPreset: int = 0:
	set(value):
		currentPreset = value
		if value > 0:
			load_preset(value)

# ============================================================================
# INTERNAL VARIABLES
# ============================================================================
@onready var TopLineRef: Node2D = $TopLine
@onready var BottomLineRef: Node2D = $BottomLine
@onready var LeftLineRef: Node2D = $LeftLine
@onready var RightLineRef: Node2D = $RightLine
@onready var CircleLineRef: Line2D = $CircleLine
@onready var CircleOutlineRef: Line2D = $CircleOutline

# Animation timers
var breathingTime: float = 0.0
var dotBreathingTime: float = 0.0
var circleBreathingTime: float = 0.0
var circleRotationTime: float = 0.0
var geometryRotationTime: float = 0.0
var distortionTime: float = 0.0
var glitchTimer: float = 0.0

# Dynamic state variables
var currentSprintOffset: float = 0.0
var targetSprintOffset: float = 0.0
var crosshairDynamicOffset: float = 0.0
var crosshairStaticOffset: float = 0.0
var currentDotScale: float = 1.0
var currentCircleRadius: float = 20.0
var currentCircleThickness: float = 2.0
var currentCircleRotation: float = 0.0
var currentOpacity: float = 1.0
var currentBloomScale: float = 1.0

# Context reaction states
var isLookingAtInteractable: bool = false
var isEnemyInSight: bool = false
var hitConfirmTimer: float = 0.0
var damageFlashTimer: float = 0.0
var interactionPulseTime: float = 0.0

# Motion feedback states
var currentRecoilBloom: float = 0.0
var targetRecoilBloom: float = 0.0
var currentMovementSpeed: float = 0.0
var landingCompressionTimer: float = 0.0
var currentLandingCompression: float = 0.0
var isSprinting: bool = false

# Config dictionary
var crosshairConfig: Dictionary

# ============================================================================
# CORE FUNCTIONS
# ============================================================================
func _ready() -> void:
	update_crosshair()
	if Engine.is_editor_hint():
		connect("hidden", Callable(self, "update_crosshair"))

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	var needs_redraw = false
	
	# Main breathing animation
	if breathingEnabled:
		breathingTime += delta * breathingSpeed
		var breathingOffset = calculate_wave(breathingTime, breathingWaveform) * breathingAmplitude
		update_static_offset(breathingOffset)
	
	# Dot breathing
	if dotBreathingEnabled and crosshairDot:
		dotBreathingTime += delta * dotBreathingSpeed
		var phase_offset = dotBreathingPhase * TAU
		var wave = calculate_wave(dotBreathingTime + phase_offset / TAU, dotBreathingWaveform)
		currentDotScale = dotScale + (wave * dotBreathingAmplitude)
		needs_redraw = true
	else:
		currentDotScale = dotScale
	
	# Circle breathing
	if circleBreathingEnabled and circleMode:
		circleBreathingTime += delta * circleBreathingSpeed
		var phase_offset = circleBreathingPhase * TAU
		var wave = calculate_wave(circleBreathingTime + phase_offset / TAU, circleBreathingWaveform)
		currentCircleRadius = circleRadius + (wave * circleBreathingAmplitude)
		needs_redraw = true
	else:
		currentCircleRadius = circleRadius
	
	# Circle rotation
	if circleRotationEnabled and circleMode:
		circleRotationTime += delta
		currentCircleRotation = fmod(circleRotationSpeed * circleRotationTime, 360.0)
		needs_redraw = true
	else:
		currentCircleRotation = circleRotationOffset
	
	# Circle thickness pulse
	if circleThicknessPulse and circleMode:
		var pulse_wave = calculate_wave(circleBreathingTime, circleBreathingWaveform)
		currentCircleThickness = circleThickness + (pulse_wave * circleThicknessPulseAmplitude)
		needs_redraw = true
	else:
		currentCircleThickness = circleThickness
	
	# Geometry rotation for advanced shapes
	if shapeMode in [3, 4, 5]:
		geometryRotationTime += delta
		needs_redraw = true
	
	# Interaction pulse
	if enableInteractionPulse and isLookingAtInteractable:
		interactionPulseTime += delta * 3.0
		currentBloomScale = 1.0 + sin(interactionPulseTime) * 0.2
		needs_redraw = true
	else:
		currentBloomScale = 1.0
	
	# Hit confirm feedback
	if hitConfirmTimer > 0.0:
		hitConfirmTimer -= delta
		needs_redraw = true
	
	# Damage feedback
	if damageFlashTimer > 0.0:
		damageFlashTimer -= delta
		needs_redraw = true
	
	# Recoil bloom recovery
	if currentRecoilBloom > 0.0:
		currentRecoilBloom = lerp(currentRecoilBloom, 0.0, delta * recoilRecoverySpeed * 5.0)
		needs_redraw = true
	
	# Landing compression recovery
	if landingCompressionTimer > 0.0:
		landingCompressionTimer -= delta
		currentLandingCompression = lerp(currentLandingCompression, 0.0, delta / landingRecoverySpeed)
		needs_redraw = true
	
	# Distortion ring animation
	if enableDistortionRing:
		distortionTime += delta * distortionWaveSpeed
		needs_redraw = true
	
	# Glitch effect
	if enableGlitchEffect:
		glitchTimer += delta
		if randf() < glitchIntensity * 0.1:
			needs_redraw = true
	
	if needs_redraw:
		queue_redraw()

func calculate_wave(time: float, waveform: int) -> float:
	var normalized_time = fmod(time, 1.0)
	
	match waveform:
		0: # Sine
			return sin(time * PI)
		1: # Smooth Step
			var t = sin(time * PI * 0.5)
			return t * t * (3.0 - 2.0 * t)
		2: # Triangle
			return 1.0 - abs(fmod(time * 2.0, 2.0) - 1.0)
		3: # Square
			return 1.0 if sin(time * TAU) > 0 else -1.0
		_:
			return sin(time * PI)

# ============================================================================
# PUBLIC API - CONTEXT REACTIONS
# ============================================================================
func set_looking_at_interactable(looking: bool) -> void:
	isLookingAtInteractable = looking
	if looking:
		interactionPulseTime = 0.0

func set_enemy_in_sight(in_sight: bool) -> void:
	isEnemyInSight = in_sight

func trigger_hit_confirm() -> void:
	if enableHitConfirm:
		hitConfirmTimer = hitConfirmDuration

func trigger_damage_feedback() -> void:
	if enableDamageFeedback:
		damageFlashTimer = 0.3

# ============================================================================
# PUBLIC API - MOTION FEEDBACK
# ============================================================================
func add_recoil(amount: float) -> void:
	if enableRecoilBloom:
		targetRecoilBloom = min(targetRecoilBloom + amount, maxRecoilBloom)
		currentRecoilBloom = targetRecoilBloom

func set_movement_speed(speed: float) -> void:
	if enableMovementBloom:
		currentMovementSpeed = speed

func trigger_landing() -> void:
	if enableLandingCompression:
		currentLandingCompression = landingCompressionAmount
		landingCompressionTimer = landingRecoverySpeed

func set_sprinting(sprinting: bool) -> void:
	isSprinting = sprinting

# ============================================================================
# PRESET SYSTEM
# ============================================================================
func load_preset(preset: int) -> void:
	match preset:
		1: # Minimalist
			crosshairLinesVisible = true
			crosshairDot = true
			crosshairThickness = 1.5
			crosshairSize = 6.0
			crosshairGap = 3.0
			crosshairColor = Color.WHITE
			circleMode = false
			breathingEnabled = false
			shapeMode = 0
		
		2: # Tech
			crosshairLinesVisible = true
			crosshairDot = true
			crosshairThickness = 2.0
			crosshairSize = 12.0
			crosshairGap = 8.0
			crosshairColor = Color(0.3, 0.8, 1.0)
			circleMode = true
			circleRadius = 25.0
			splitCircle = true
			circleGapCount = 4
			circleRotationEnabled = true
			circleRotationSpeed = 30.0
			enableBloom = true
			bloomIntensity = 2.0
			shapeMode = 1
		
		3: # Classic FPS
			crosshairLinesVisible = true
			crosshairDot = false
			crosshairThickness = 2.5
			crosshairSize = 10.0
			crosshairGap = 5.0
			crosshairColor = Color(0.0, 1.0, 0.0)
			circleMode = false
			crosshairOutline = true
			crosshairOutlineThickness = 1.0
			shapeMode = 0
		
		4: # Immersive Sim
			crosshairLinesVisible = true
			crosshairDot = true
			dotShape = 1
			crosshairThickness = 1.5
			crosshairSize = 8.0
			crosshairGap = 6.0
			crosshairColor = Color(0.9, 0.9, 0.9, 0.8)
			breathingEnabled = true
			breathingSpeed = 0.8
			breathingAmplitude = 1.5
			enableInteractionPulse = true
			enableHitConfirm = true
			adaptiveOpacity = true
			shapeMode = 0
		
		5: # Psychic
			crosshairLinesVisible = true
			crosshairDot = true
			dotShape = 2
			crosshairThickness = 1.8
			crosshairSize = 10.0
			crosshairGap = 7.0
			crosshairColor = Color(0.8, 0.2, 1.0)
			circleMode = true
			circleRadius = 30.0
			circleBreathingEnabled = true
			circleBreathingSpeed = 1.5
			circleBreathingAmplitude = 5.0
			enableDistortionRing = true
			enableBloom = true
			bloomIntensity = 3.0
			shapeMode = 5
		
		6: # Broken HUD
			crosshairLinesVisible = true
			crosshairDot = true
			crosshairThickness = 2.0
			crosshairSize = 9.0
			crosshairGap = 5.0
			crosshairColor = Color(1.0, 0.3, 0.2)
			enableGlitchEffect = true
			glitchIntensity = 0.4
			enableChromaticAberration = true
			chromaticAberrationAmount = 2.0
			shapeMode = 0
	
	update_crosshair()

# ============================================================================
# CROSSHAIR UPDATE FUNCTIONS
# ============================================================================
func update_dynamic_offset(amount: float) -> void:
	var offsetAmount: float = (amount * crosshairMaxDynamicOffset)
	if crosshairDynamic and amount > 0:
		TopLineRef.position.y = -offsetAmount
		BottomLineRef.position.y = offsetAmount
		LeftLineRef.position.x = -offsetAmount
		RightLineRef.position.x = offsetAmount

func update_static_offset(amount: float) -> void:
	crosshairStaticOffset = amount
	update_crosshair()

func update_line_style(style: int):
	match style:
		0:
			return null
		1:
			return preload("res://addons/customizableCrosshair/crosshair/curves/arrow.tres")
		2:
			return preload("res://addons/customizableCrosshair/crosshair/curves/inverseArrow.tres")
		_:
			return null

func get_line_cap_style(cap: int) -> Line2D.LineCapMode:
	match cap:
		0:
			return Line2D.LINE_CAP_NONE
		1:
			return Line2D.LINE_CAP_ROUND
		2:
			return Line2D.LINE_CAP_BOX
		_:
			return Line2D.LINE_CAP_NONE

func update_crosshair() -> void:
	if !TopLineRef or !BottomLineRef or !LeftLineRef or !RightLineRef:
		return

	var lines: Array = [TopLineRef, BottomLineRef, LeftLineRef, RightLineRef]
	var crosshairOffset: float = crosshairGap
	
	# Apply motion feedback
	if enableRecoilBloom:
		crosshairOffset += currentRecoilBloom
	if enableMovementBloom:
		crosshairOffset += currentMovementSpeed * maxMovementBloom * 0.1
	if enableLandingCompression:
		crosshairOffset -= currentLandingCompression * crosshairGap
	
	for i in range(lines.size()):
		var LineRef = lines[i]
		if crosshairLinesVisible:
			LineRef.visible = !(crosshairTStyle and i == 0)
		else:
			LineRef.visible = false
	
	if crosshairDynamic or breathingEnabled:
		crosshairOffset += crosshairStaticOffset

	var offset: float = crosshairHorizontalLinesLength if crosshairHorizontalLinesLength != 0 else crosshairGap
	var thickness: float = crosshairHorizontalLinesPosition if crosshairHorizontalLinesPosition != 0 else crosshairThickness
	var horizontalLineThickness: float = crosshairHorizontalLinesThickness if crosshairHorizontalLinesThickness != 0 else crosshairThickness

	var horizontalLineOffset: float = crosshairOffset + (thickness / 2)
	var horizontalLinePoint: float = (offset + crosshairThickness) / 2
	var horizontalLinePoints: PackedVector2Array = [
		Vector2(-horizontalLinePoint, -horizontalLineOffset),
		Vector2(horizontalLinePoint, -horizontalLineOffset),
		Vector2(-horizontalLinePoint, horizontalLineOffset),
		Vector2(horizontalLinePoint, horizontalLineOffset),
		Vector2(-horizontalLineOffset, horizontalLinePoint),
		Vector2(-horizontalLineOffset, -horizontalLinePoint),
		Vector2(horizontalLineOffset, horizontalLinePoint),
		Vector2(horizontalLineOffset, -horizontalLinePoint)
	]

	if crosshairHorizontalLines:
		crosshairOffset += crosshairThickness / 2

	var lineStartPoint: float = crosshairOffset + (crosshairThickness / 2)
	var lineEndPoint: float = crosshairSize + crosshairOffset + (crosshairThickness / 2)
	var linePoints: PackedVector2Array = [
		Vector2(0.0, -lineStartPoint),
		Vector2(0.0, -lineEndPoint),
		Vector2(0.0, lineStartPoint),
		Vector2(0.0, lineEndPoint),
		Vector2(-lineStartPoint, 0.0),
		Vector2(-lineEndPoint, 0.0),
		Vector2(lineStartPoint, 0.0),
		Vector2(lineEndPoint, 0.0)
	]

	var dir: int = sign(crosshairOffset)
	var horizontalLineOutlineDirections: PackedVector2Array = [
		Vector2(-dir, 0),
		Vector2(dir, 0),
		Vector2(-dir, 0),
		Vector2(dir, 0),
		Vector2(0, dir),
		Vector2(0, -dir),
		Vector2(0, dir),
		Vector2(0, -dir)
	]

	if crosshairTStyle:
		TopLineRef.visible = false
	else:
		TopLineRef.visible = true

	var capStyle = get_line_cap_style(crosshairLineCap)
	var finalColor = get_current_color()

	for i in range(lines.size()):
		var LineRef = lines[i]
		var start = i * 2
		var end = start + 2

		LineRef.points = linePoints.slice(start, end)
		LineRef.width = crosshairThickness
		LineRef.default_color = finalColor
		LineRef.width_curve = update_line_style(crosshairLineStyle)
		LineRef.begin_cap_mode = capStyle
		LineRef.end_cap_mode = capStyle

		if crosshairOutline:
			var OutlineRef: Line2D = LineRef.get_child(0)
			if OutlineRef:
				OutlineRef.visible = true
				OutlineRef.points = PackedVector2Array([
					linePoints[start] - linePoints[start].normalized() * crosshairOutlineThickness * dir,
					linePoints[start + 1] + linePoints[start + 1].normalized() * crosshairOutlineThickness * dir
				])
				OutlineRef.width = crosshairThickness + crosshairOutlineThickness * 2
				OutlineRef.default_color = crosshairOutlineColor
				OutlineRef.width_curve = update_line_style(crosshairLineStyle)
				OutlineRef.begin_cap_mode = capStyle
				OutlineRef.end_cap_mode = capStyle
		else:
			var OutlineRef: Line2D = LineRef.get_child(0)
			if OutlineRef:
				OutlineRef.visible = false

		if crosshairHorizontalLines:
			var HorizontalLineRef: Line2D = LineRef.get_child(1)
			if HorizontalLineRef:
				HorizontalLineRef.visible = true
				HorizontalLineRef.points = horizontalLinePoints.slice(start, end)
				HorizontalLineRef.width = horizontalLineThickness
				HorizontalLineRef.default_color = finalColor
				HorizontalLineRef.begin_cap_mode = capStyle
				HorizontalLineRef.end_cap_mode = capStyle

				if crosshairOutline:
					var HOutlineRef: Line2D = HorizontalLineRef.get_child(0)
					if HOutlineRef:
						HOutlineRef.visible = true
						HOutlineRef.points = PackedVector2Array([
							horizontalLinePoints[start] + horizontalLineOutlineDirections[start] * crosshairOutlineThickness,
							horizontalLinePoints[start + 1] + horizontalLineOutlineDirections[start + 1] * crosshairOutlineThickness
						])
						HOutlineRef.width = horizontalLineThickness + crosshairOutlineThickness * 2
						HOutlineRef.default_color = crosshairOutlineColor
						HOutlineRef.begin_cap_mode = capStyle
						HOutlineRef.end_cap_mode = capStyle
				else:
					var HOutlineRef: Line2D = HorizontalLineRef.get_child(0)
					if HOutlineRef:
						HOutlineRef.visible = false
		else:
			var HorizontalLineRef: Line2D = LineRef.get_child(1)
			if HorizontalLineRef:
				HorizontalLineRef.visible = false

	queue_redraw()

# ============================================================================
# COLOR CALCULATION
# ============================================================================
func get_current_color() -> Color:
	var finalColor = crosshairColor
	
	# Hit confirm takes priority
	if hitConfirmTimer > 0.0:
		var blend = hitConfirmTimer / hitConfirmDuration
		finalColor = finalColor.lerp(hitConfirmColor, blend)
	
	# Damage feedback
	elif damageFlashTimer > 0.0:
		var blend = damageFlashTimer / 0.3
		finalColor = finalColor.lerp(damageFeedbackColor, blend * 0.7)
	
	# Enemy detection
	elif enableEnemyDetection and isEnemyInSight:
		finalColor = finalColor.lerp(enemyDetectionColor, enemyDetectionBlend)
	
	# Interaction pulse
	elif enableInteractionPulse and isLookingAtInteractable:
		var pulse = abs(sin(interactionPulseTime))
		finalColor = finalColor.lerp(interactionPulseColor, pulse * 0.5)
	
	# Sprint fade
	if enableSprintFade and isSprinting:
		finalColor.a *= (1.0 - sprintFadeAmount)
	
	# Adaptive opacity
	if adaptiveOpacity:
		finalColor.a = lerp(minOpacity, maxOpacity, currentOpacity)
	
	return finalColor

# ============================================================================
# DRAWING FUNCTIONS
# ============================================================================
func _draw() -> void:
	# Draw center dot
	if crosshairDot:
		draw_center_dot()
	
	# Draw circle
	if circleMode:
		draw_circle_crosshair()
	
	# Draw advanced shapes
	match shapeMode:
		1: # Quad Brackets
			draw_quad_brackets()
		2: # Tech Spikes
			draw_tech_spikes()
		3: # Cross Arcs
			draw_cross_arcs()
		4: # Rotating Hex
			draw_rotating_hex()
		5: # Iris Aperture
			draw_iris_aperture()
	
	# Draw special effects
	if enableDistortionRing:
		draw_distortion_ring()
	
	if enableBloom:
		draw_bloom_effect()

func draw_center_dot() -> void:
	var baseDotSize = crosshairThickness
	var dotSize = baseDotSize * currentDotScale
	var halfSize = dotSize / 2
	var finalColor = get_current_color()
	
	# Apply chromatic aberration
	if enableChromaticAberration:
		var offset = chromaticAberrationAmount
		draw_dot_shape(Vector2(-offset, 0), dotSize, Color(1, 0, 0, finalColor.a * 0.5))
		draw_dot_shape(Vector2(offset, 0), dotSize, Color(0, 0, 1, finalColor.a * 0.5))
	
	# Apply glitch effect
	if enableGlitchEffect and randf() < glitchIntensity * 0.05:
		var glitchOffset = Vector2(randf_range(-2, 2), randf_range(-2, 2))
		draw_dot_shape(glitchOffset, dotSize, finalColor)
		return
	
	draw_dot_shape(Vector2.ZERO, dotSize, finalColor)

func draw_dot_shape(offset: Vector2, dotSize: float, color: Color) -> void:
	var halfSize = dotSize / 2
	
	match dotShape:
		0: # Square
			if crosshairOutline:
				draw_rounded_rect(
					Rect2(
						offset + Vector2(-(halfSize + crosshairOutlineThickness), -(halfSize + crosshairOutlineThickness)),
						Vector2(dotSize + crosshairOutlineThickness * 2, dotSize + crosshairOutlineThickness * 2)
					),
					crosshairOutlineColor,
					dotCornerRadius
				)
			draw_rounded_rect(
				Rect2(offset - Vector2(halfSize, halfSize), Vector2(dotSize, dotSize)),
				color,
				dotCornerRadius
			)
		
		1: # Circle
			if crosshairOutline:
				draw_circle(offset, halfSize + crosshairOutlineThickness, crosshairOutlineColor)
			draw_circle(offset, halfSize, color)
		
		2: # Diamond
			var points = PackedVector2Array([
				offset + Vector2(0, -halfSize),
				offset + Vector2(halfSize, 0),
				offset + Vector2(0, halfSize),
				offset + Vector2(-halfSize, 0)
			])
			if crosshairOutline:
				var outlinePoints = PackedVector2Array([
					offset + Vector2(0, -(halfSize + crosshairOutlineThickness)),
					offset + Vector2(halfSize + crosshairOutlineThickness, 0),
					offset + Vector2(0, halfSize + crosshairOutlineThickness),
					offset + Vector2(-(halfSize + crosshairOutlineThickness), 0)
				])
				draw_polygon(outlinePoints, PackedColorArray([crosshairOutlineColor]))
			draw_polygon(points, PackedColorArray([color]))
		
		3: # Cross
			var crossThickness = dotSize * 0.3
			if crosshairOutline:
				draw_line(offset + Vector2(0, -halfSize - crosshairOutlineThickness), offset + Vector2(0, halfSize + crosshairOutlineThickness), crosshairOutlineColor, crossThickness + crosshairOutlineThickness * 2)
				draw_line(offset + Vector2(-halfSize - crosshairOutlineThickness, 0), offset + Vector2(halfSize + crosshairOutlineThickness, 0), crosshairOutlineColor, crossThickness + crosshairOutlineThickness * 2)
			draw_line(offset + Vector2(0, -halfSize), offset + Vector2(0, halfSize), color, crossThickness)
			draw_line(offset + Vector2(-halfSize, 0), offset + Vector2(halfSize, 0), color, crossThickness)
		
		4: # Plus
			var plusSize = dotSize * 0.8
			var plusThickness = dotSize * 0.25
			if crosshairOutline:
				draw_rect(Rect2(offset + Vector2(-plusThickness / 2 - crosshairOutlineThickness, -plusSize / 2 - crosshairOutlineThickness), Vector2(plusThickness + crosshairOutlineThickness * 2, plusSize + crosshairOutlineThickness * 2)), crosshairOutlineColor)
				draw_rect(Rect2(offset + Vector2(-plusSize / 2 - crosshairOutlineThickness, -plusThickness / 2 - crosshairOutlineThickness), Vector2(plusSize + crosshairOutlineThickness * 2, plusThickness + crosshairOutlineThickness * 2)), crosshairOutlineColor)
			draw_rect(Rect2(offset + Vector2(-plusThickness / 2, -plusSize / 2), Vector2(plusThickness, plusSize)), color)
			draw_rect(Rect2(offset + Vector2(-plusSize / 2, -plusThickness / 2), Vector2(plusSize, plusThickness)), color)

func draw_rounded_rect(rect: Rect2, color: Color, radius: float) -> void:
	if radius <= 0:
		draw_rect(rect, color)
	else:
		var points = PackedVector2Array()
		var segments = 8
		var corners = [
			rect.position,
			rect.position + Vector2(rect.size.x, 0),
			rect.position + rect.size,
			rect.position + Vector2(0, rect.size.y)
		]
		var offsets = [
			Vector2(radius, radius),
			Vector2(-radius, radius),
			Vector2(-radius, -radius),
			Vector2(radius, -radius)
		]
		var angles = [PI, PI * 0.5, 0, PI * 1.5]
		
		for i in range(4):
			var center = corners[i] + offsets[i]
			var start_angle = angles[i]
			for j in range(segments + 1):
				var angle = start_angle + (PI * 0.5 * j / segments)
				points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		
		draw_polygon(points, PackedColorArray([color]))

func draw_circle_crosshair() -> void:
	var finalColor = circleColor if circleColor.a > 0 else get_current_color()
	var pointCount = 64
	var activeRadius = currentCircleRadius
	var activeThickness = currentCircleThickness
	var activeRotation = currentCircleRotation
	
	if splitCircle:
		var segmentAngle = 360.0 / circleGapCount
		var gapHalf = deg_to_rad(circleGapSize / 2.0)
		
		for i in range(circleGapCount):
			var segmentStart = deg_to_rad(i * segmentAngle + activeRotation)
			var segmentEnd = deg_to_rad((i + 1) * segmentAngle + activeRotation)
			var arcStart = segmentStart + gapHalf
			var arcEnd = segmentEnd - gapHalf
			
			if arcEnd > arcStart:
				var arcPoints = PackedVector2Array()
				var segmentPoints = int(pointCount / circleGapCount)
				
				for j in range(segmentPoints + 1):
					var t = float(j) / segmentPoints
					var angle = lerp(arcStart, arcEnd, t)
					arcPoints.append(Vector2(cos(angle), sin(angle)) * activeRadius)
				
				if circleOutline:
					draw_polyline(arcPoints, circleOutlineColor, activeThickness + circleOutlineThickness * 2, true)
				draw_polyline(arcPoints, finalColor, activeThickness, true)
	else:
		var circlePoints = PackedVector2Array()
		var angleOffset = deg_to_rad(activeRotation)
		
		for i in range(pointCount + 1):
			var angle = (TAU * i / pointCount) + angleOffset
			circlePoints.append(Vector2(cos(angle), sin(angle)) * activeRadius)
		
		if circleOutline:
			draw_polyline(circlePoints, circleOutlineColor, activeThickness + circleOutlineThickness * 2, true)
		draw_polyline(circlePoints, finalColor, activeThickness, true)

# ============================================================================
# ADVANCED SHAPE DRAWING
# ============================================================================
func draw_quad_brackets() -> void:
	var finalColor = get_current_color()
	var cornerSize = bracketCornerSize
	var thickness = crosshairThickness
	var gap = crosshairGap + crosshairStaticOffset
	
	# Top-left bracket
	var tl_points = PackedVector2Array([
		Vector2(-gap - cornerSize, -gap),
		Vector2(-gap, -gap),
		Vector2(-gap, -gap - cornerSize)
	])
	draw_polyline(tl_points, finalColor, thickness, false)
	
	# Top-right bracket
	var tr_points = PackedVector2Array([
		Vector2(gap + cornerSize, -gap),
		Vector2(gap, -gap),
		Vector2(gap, -gap - cornerSize)
	])
	draw_polyline(tr_points, finalColor, thickness, false)
	
	# Bottom-left bracket
	var bl_points = PackedVector2Array([
		Vector2(-gap - cornerSize, gap),
		Vector2(-gap, gap),
		Vector2(-gap, gap + cornerSize)
	])
	draw_polyline(bl_points, finalColor, thickness, false)
	
	# Bottom-right bracket
	var br_points = PackedVector2Array([
		Vector2(gap + cornerSize, gap),
		Vector2(gap, gap),
		Vector2(gap, gap + cornerSize)
	])
	draw_polyline(br_points, finalColor, thickness, false)

func draw_tech_spikes() -> void:
	var finalColor = get_current_color()
	var gap = crosshairGap + crosshairStaticOffset
	var spikeLen = spikeLength
	var thickness = crosshairThickness
	
	# Four directional spikes
	var directions = [
		Vector2(0, -1),  # Top
		Vector2(0, 1),   # Bottom
		Vector2(-1, 0),  # Left
		Vector2(1, 0)    # Right
	]
	
	for dir in directions:
		var start = dir * gap
		var end = dir * (gap + spikeLen)
		var perpendicular = Vector2(-dir.y, dir.x) * (thickness * 1.5)
		
		var spike = PackedVector2Array([
			start + perpendicular,
			end,
			start - perpendicular
		])
		draw_polyline(spike, finalColor, thickness * 0.5, false)

func draw_cross_arcs() -> void:
	var finalColor = get_current_color()
	var gap = crosshairGap + crosshairStaticOffset
	var size = crosshairSize
	var thickness = crosshairThickness
	var rotation = deg_to_rad(geometryRotationTime * geometryRotationSpeed)
	
	var directions = [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]
	
	for dir in directions:
		var arcPoints = PackedVector2Array()
		var centerDist = gap + size / 2
		var arcRadius = size / 2
		var arcStart = -PI / 6
		var arcEnd = PI / 6
		
		for i in range(arcSegments + 1):
			var t = float(i) / arcSegments
			var angle = lerp(arcStart, arcEnd, t)
			var localPoint = Vector2(sin(angle), cos(angle)) * arcRadius
			
			# Rotate and translate
			var rotatedDir = dir.rotated(rotation)
			var perpendicular = Vector2(-rotatedDir.y, rotatedDir.x)
			var point = rotatedDir * centerDist + perpendicular * localPoint.x + rotatedDir * localPoint.y
			arcPoints.append(point)
		
		draw_polyline(arcPoints, finalColor, thickness, false)

func draw_rotating_hex() -> void:
	var finalColor = get_current_color()
	var gap = crosshairGap + crosshairStaticOffset
	var size = crosshairSize * 1.5
	var thickness = crosshairThickness
	var rotation = deg_to_rad(geometryRotationTime * geometryRotationSpeed)
	
	var hexPoints = PackedVector2Array()
	for i in range(7):
		var angle = (TAU / 6) * i + rotation
		var point = Vector2(cos(angle), sin(angle)) * (gap + size)
		hexPoints.append(point)
	
	draw_polyline(hexPoints, finalColor, thickness, true)

func draw_iris_aperture() -> void:
	var finalColor = get_current_color()
	var gap = crosshairGap + crosshairStaticOffset
	var size = crosshairSize
	var thickness = crosshairThickness
	var rotation = deg_to_rad(geometryRotationTime * geometryRotationSpeed)
	
	var segmentAngle = TAU / irisSegmentCount
	
	for i in range(irisSegmentCount):
		var angle = i * segmentAngle + rotation
		var innerRadius = gap
		var outerRadius = gap + size
		
		var p1 = Vector2(cos(angle), sin(angle)) * innerRadius
		var p2 = Vector2(cos(angle + segmentAngle * 0.4), sin(angle + segmentAngle * 0.4)) * outerRadius
		var p3 = Vector2(cos(angle + segmentAngle * 0.6), sin(angle + segmentAngle * 0.6)) * outerRadius
		var p4 = Vector2(cos(angle + segmentAngle), sin(angle + segmentAngle)) * innerRadius
		
		var blade = PackedVector2Array([p1, p2, p3, p4, p1])
		draw_polyline(blade, finalColor, thickness * 0.7, false)

# ============================================================================
# SPECIAL EFFECTS
# ============================================================================
func draw_distortion_ring() -> void:
	var finalColor = get_current_color()
	finalColor.a *= 0.3
	var radius = distortionRadius
	var pointCount = 48
	
	var points = PackedVector2Array()
	for i in range(pointCount + 1):
		var angle = (TAU * i / pointCount)
		var wave = sin(angle * 4 + distortionTime * TAU) * 2.0
		var r = radius + wave
		points.append(Vector2(cos(angle), sin(angle)) * r)
	
	draw_polyline(points, finalColor, 1.0, true)

func draw_bloom_effect() -> void:
	if !enableBloom:
		return
	
	var finalColor = get_current_color()
	finalColor.a *= 0.2 * bloomIntensity
	
	var bloomScale = 1.0 + (bloomIntensity * 0.3) * currentBloomScale
	
	# Draw enlarged, transparent version
	var gap = (crosshairGap + crosshairStaticOffset) * bloomScale
	var size = crosshairSize * bloomScale
	var thickness = crosshairThickness * bloomScale
	
	var directions = [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]
	
	for dir in directions:
		var start = dir * gap
		var end = dir * (gap + size)
		draw_line(start, end, finalColor, thickness)

# ============================================================================
# CONFIG FUNCTIONS (Existing code preserved)
# ============================================================================
func valid_config(config: Dictionary) -> bool:
	if config.size() != crosshairConfig.size():
		push_warning("Config validation failed due to size mismatch.")
		return false
	if not config.has_all(crosshairConfig.keys()):
		push_warning("Config validation failed due to key mismatch.")
		return false
	for key in config:
		if typeof(config[key]) != typeof(crosshairConfig[key]):
			push_warning("Type mismatch for key: " + key)
			return false
	return true

func get_config_string() -> String:
	var dict: Dictionary = crosshairConfig.duplicate()
	dict["color"] = [dict["color"].r, dict["color"].g, dict["color"].b, dict["color"].a]
	dict["circleColor"] = [dict["circleColor"].r, dict["circleColor"].g, dict["circleColor"].b, dict["circleColor"].a]
	dict["outlineColor"] = [dict["outlineColor"].r, dict["outlineColor"].g, dict["outlineColor"].b, dict["outlineColor"].a]
	return JSON.stringify(dict)