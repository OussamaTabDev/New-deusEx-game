@tool
extends CenterContainer

@export_category("Crosshair settings")
## The thickness of the lines.
@export var crosshairThickness: float = 2.0:
	set(value):
		crosshairThickness = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

## The length of the lines.
@export var crosshairSize: float = 10.0:
	set(value):
		crosshairSize = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

## The distance between the middle of the screen and the starts of the lines.
@export var crosshairGap: float = 5.0:
	set(value):
		crosshairGap = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

## The color of the crosshair.
@export var crosshairColor: Color = Color.WHITE:
	set(value):
		crosshairColor = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()


@export_group("Style settings")
## Toggle visibility of the main crosshair lines.
@export var crosshairLinesVisible: bool = true:
	set(value):
		crosshairLinesVisible = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

## List of possible styles for the crosshair lines.
@export_enum(
	"Line",
	"Arrow",
	"Inverse Arrow"
) var crosshairLineStyle: int = 0:
	set(value):
		crosshairLineStyle = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

## Line cap style for the ends of lines
@export_enum(
	"None",
	"Round",
	"Square"
) var crosshairLineCap: int = 0:
	set(value):
		crosshairLineCap = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

## Toggle for the middle dot.
@export var crosshairDot: bool = false:
	set(value):
		crosshairDot = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

## Shape of the center dot
@export_enum(
	"Square",
	"Circle",
	"Diamond",
	"Cross",
	"Plus"
) var dotShape: int = 0:
	set(value):
		dotShape = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

## Corner radius for square/diamond dot (0 = sharp corners)
@export_range(0.0, 10.0, 0.1) var dotCornerRadius: float = 0.0:
	set(value):
		dotCornerRadius = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

## Scale multiplier for the center dot size.
@export_range(0.1, 5.0, 0.1) var dotScale: float = 1.0:
	set(value):
		dotScale = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

## Toggle to make the crosshair T style meaning the top line is removed.
@export var crosshairTStyle: bool = false:
	set(value):
		crosshairTStyle = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()


@export_subgroup("Outline settings")
## Toggle for an outline for the lines.
@export var crosshairOutline: bool = false:
	set(value):
		crosshairOutline = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

## The thickness of the outline.
@export var crosshairOutlineThickness: float = 1.0:
	set(value):
		crosshairOutlineThickness = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

## Color of the outline (default: black)
@export var crosshairOutlineColor: Color = Color.BLACK:
	set(value):
		crosshairOutlineColor = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()


@export_subgroup("Horizontal lines settings")
## Toggle to add horizontal lines at the beginning of the crosshair lines.
@export var crosshairHorizontalLines: bool = false:
	set(value):
		crosshairHorizontalLines = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

## The position of the horizontal lines along their local Y-Axis.
@export var crosshairHorizontalLinesPosition: float = 0.0:
	set(value):
		crosshairHorizontalLinesPosition = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

## The thickness of the horizontal lines.
@export var crosshairHorizontalLinesThickness: float = 0.0:
	set(value):
		crosshairHorizontalLinesThickness = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

## The width of the horizontal lines.
@export var crosshairHorizontalLinesLength: float = 0.0:
	set(value):
		crosshairHorizontalLinesLength = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()


@export_group("Circle Mode")
## Enable full circle around center
@export var circleMode: bool = false:
	set(value):
		circleMode = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

## Radius of the circle
@export_range(5.0, 100.0, 0.5) var circleRadius: float = 20.0:
	set(value):
		circleRadius = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

## Thickness of the circle line
@export_range(1.0, 10.0, 0.1) var circleThickness: float = 2.0:
	set(value):
		circleThickness = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

## Color of the circle (uses crosshair color if transparent)
@export var circleColor: Color = Color(1, 1, 1, 0):
	set(value):
		circleColor = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

## Enable circle outline
@export var circleOutline: bool = false:
	set(value):
		circleOutline = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

## Thickness of circle outline
@export_range(0.5, 5.0, 0.1) var circleOutlineThickness: float = 1.0:
	set(value):
		circleOutlineThickness = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

## Color of the circle outline
@export var circleOutlineColor: Color = Color.BLACK:
	set(value):
		circleOutlineColor = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

@export_subgroup("Split Circle")
## Enable split circle (breaks circle into segments)
@export var splitCircle: bool = false:
	set(value):
		splitCircle = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

## Number of gaps in the circle (e.g., 4 = traditional split circle)
@export_range(2, 8, 1) var circleGapCount: int = 4:
	set(value):
		circleGapCount = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

## Size of each gap in degrees
@export_range(5.0, 90.0, 1.0) var circleGapSize: float = 20.0:
	set(value):
		circleGapSize = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

## Rotation offset for circle gaps (0-360)
@export_range(0.0, 360.0, 1.0) var circleRotationOffset: float = 0.0:
	set(value):
		circleRotationOffset = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()


@export_group("Dynamic Effects")
## Toggle for if the lines should move based on input.
@export var crosshairDynamic: bool = false:
	set(value):
		crosshairDynamic = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

## Controls the maximum amount of offset the lines should have.
@export var crosshairMaxDynamicOffset: float = 10.0:
	set(value):
		crosshairMaxDynamicOffset = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()


@export_subgroup("Breathing Animation")
## Enable gentle pulsing animation for crosshair lines
@export var breathingEnabled: bool = false:
	set(value):
		breathingEnabled = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

## Speed of breathing animation
@export_range(0.1, 5.0, 0.1) var breathingSpeed: float = 1.0:
	set(value):
		breathingSpeed = value

## Amplitude of breathing (how much it expands/contracts)
@export_range(0.5, 10.0, 0.1) var breathingAmplitude: float = 2.0:
	set(value):
		breathingAmplitude = value

## Breathing waveform type
@export_enum(
	"Sine",
	"Smooth Step",
	"Triangle",
	"Square"
) var breathingWaveform: int = 0:
	set(value):
		breathingWaveform = value


@export_subgroup("Dot Breathing")
## Enable breathing animation for center dot
@export var dotBreathingEnabled: bool = false:
	set(value):
		dotBreathingEnabled = value

## Dot breathing speed (independent from main breathing)
@export_range(0.1, 5.0, 0.1) var dotBreathingSpeed: float = 1.0:
	set(value):
		dotBreathingSpeed = value

## Dot breathing amplitude (scale multiplier)
@export_range(0.1, 3.0, 0.05) var dotBreathingAmplitude: float = 0.3:
	set(value):
		dotBreathingAmplitude = value

## Dot breathing waveform
@export_enum(
	"Sine",
	"Smooth Step",
	"Triangle",
	"Square"
) var dotBreathingWaveform: int = 0:
	set(value):
		dotBreathingWaveform = value

## Phase offset for dot (0-1, controls sync with main breathing)
@export_range(0.0, 1.0, 0.05) var dotBreathingPhase: float = 0.0:
	set(value):
		dotBreathingPhase = value


@export_subgroup("Circle Breathing")
## Enable breathing animation for circle
@export var circleBreathingEnabled: bool = false:
	set(value):
		circleBreathingEnabled = value

## Circle breathing speed
@export_range(0.1, 5.0, 0.1) var circleBreathingSpeed: float = 1.0:
	set(value):
		circleBreathingSpeed = value

## Circle breathing amplitude (radius change)
@export_range(0.5, 20.0, 0.5) var circleBreathingAmplitude: float = 3.0:
	set(value):
		circleBreathingAmplitude = value

## Circle breathing waveform
@export_enum(
	"Sine",
	"Smooth Step",
	"Triangle",
	"Square"
) var circleBreathingWaveform: int = 0:
	set(value):
		circleBreathingWaveform = value

## Phase offset for circle (0-1, controls sync with main breathing)
@export_range(0.0, 1.0, 0.05) var circleBreathingPhase: float = 0.0:
	set(value):
		circleBreathingPhase = value

## Enable circle rotation animation
@export var circleRotationEnabled: bool = false:
	set(value):
		circleRotationEnabled = value

## Circle rotation speed (degrees per second)
@export_range(-360.0, 360.0, 1.0) var circleRotationSpeed: float = 30.0:
	set(value):
		circleRotationSpeed = value

## Enable pulsing thickness for circle
@export var circleThicknessPulse: bool = false:
	set(value):
		circleThicknessPulse = value

## Circle thickness pulse amplitude
@export_range(0.1, 5.0, 0.1) var circleThicknessPulseAmplitude: float = 1.0:
	set(value):
		circleThicknessPulseAmplitude = value


# Line nodes
@onready var TopLineRef: Node2D = $TopLine
@onready var BottomLineRef: Node2D = $BottomLine
@onready var LeftLineRef: Node2D = $LeftLine
@onready var RightLineRef: Node2D = $RightLine
@onready var CircleLineRef: Line2D = $CircleLine  # ADD THIS
@onready var CircleOutlineRef: Line2D = $CircleOutline  # ADD THIS

# Animation variables
var breathingTime: float = 0.0
var dotBreathingTime: float = 0.0
var circleBreathingTime: float = 0.0
var circleRotationTime: float = 0.0
var currentSprintOffset: float = 0.0
var targetSprintOffset: float = 0.0

# Dynamic offset variables
var crosshairDynamicOffset: float = 0.0
var crosshairStaticOffset: float = 0.0
var currentDotScale: float = 1.0
var currentCircleRadius: float = 20.0
var currentCircleThickness: float = 2.0
var currentCircleRotation: float = 0.0

# Config dictionary
var crosshairConfig: Dictionary


func _ready() -> void:
	update_crosshair()
	if Engine.is_editor_hint():
		connect("hidden", Callable(self, "update_crosshair"))


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	var needs_redraw = false
	
	# Main breathing animation (affects crosshair lines)
	if breathingEnabled:
		breathingTime += delta * breathingSpeed
		var breathingOffset = calculate_wave(breathingTime, breathingWaveform) * breathingAmplitude
		update_static_offset(breathingOffset)
	
	# Dot breathing animation
	if dotBreathingEnabled and crosshairDot:
		dotBreathingTime += delta * dotBreathingSpeed
		var phase_offset = dotBreathingPhase * TAU
		var wave = calculate_wave(dotBreathingTime + phase_offset / TAU, dotBreathingWaveform)
		currentDotScale = dotScale + (wave * dotBreathingAmplitude)
		needs_redraw = true
	else:
		currentDotScale = dotScale
	
	# Circle breathing animation
	if circleBreathingEnabled and circleMode:
		circleBreathingTime += delta * circleBreathingSpeed
		var phase_offset = circleBreathingPhase * TAU
		var wave = calculate_wave(circleBreathingTime + phase_offset / TAU, circleBreathingWaveform)
		currentCircleRadius = circleRadius + (wave * circleBreathingAmplitude)
		needs_redraw = true
	else:
		currentCircleRadius = circleRadius
	
	# Circle rotation animation
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


func valid_config(config: Dictionary) -> bool:
	if config.size() != crosshairConfig.size():
		push_warning("Config validation failed due to size mismatch.")
		return false

	if not config.has_all(crosshairConfig.keys()):
		push_warning("Config validation failed due to key mismatch.")
		return false

	for key in config:
		if typeof(config[key]) != typeof(crosshairConfig[key]):
			push_warning(
				"Expected type '" +
				type_string(typeof(crosshairConfig[key])) +
				"' for '" + key +
				"' but got type '" +
				type_string(typeof(config[key])) + "'."
			)
			return false

	return true


func get_config_string() -> String:
	var dict: Dictionary = crosshairConfig.duplicate()
	dict["color"] = [dict["color"].r, dict["color"].g, dict["color"].b, dict["color"].a]
	dict["circleColor"] = [dict["circleColor"].r, dict["circleColor"].g, dict["circleColor"].b, dict["circleColor"].a]
	dict["outlineColor"] = [dict["outlineColor"].r, dict["outlineColor"].g, dict["outlineColor"].b, dict["outlineColor"].a]
	return JSON.stringify(dict)


func parse_config_string(configString: String) -> void:
	var config = JSON.parse_string(configString)
	if config == null:
		print("Incorrect config string!")
		return

	config["color"] = Color(config["color"][0], config["color"][1], config["color"][2], config["color"][3])
	config["circleColor"] = Color(config["circleColor"][0], config["circleColor"][1], config["circleColor"][2], config["circleColor"][3])
	config["outlineColor"] = Color(config["outlineColor"][0], config["outlineColor"][1], config["outlineColor"][2], config["outlineColor"][3])
	config["lineStyle"] = int(config["lineStyle"])
	config["lineCap"] = int(config["lineCap"])
	config["dotShape"] = int(config["dotShape"])
	config["circleGapCount"] = int(config["circleGapCount"])
	config["breathingWaveform"] = int(config["breathingWaveform"])
	config["dotBreathingWaveform"] = int(config["dotBreathingWaveform"])
	config["circleBreathingWaveform"] = int(config["circleBreathingWaveform"])

	get_crosshair_settings(config)


func get_crosshair_settings(config: Dictionary) -> void:
	if valid_config(config):
		crosshairThickness = config["thickness"]
		crosshairSize = config["size"]
		crosshairGap = config["gap"]
		crosshairColor = config["color"]
		crosshairLineStyle = config["lineStyle"]
		crosshairLineCap = config["lineCap"]
		crosshairDot = config["dot"]
		dotShape = config["dotShape"]
		dotCornerRadius = config["dotCornerRadius"]
		crosshairTStyle = config["tStyle"]
		crosshairOutline = config["outline"]
		crosshairOutlineThickness = config["outlineThickness"]
		crosshairOutlineColor = config["outlineColor"]
		crosshairHorizontalLines = config["horizontalLines"]
		crosshairHorizontalLinesPosition = config["horizontalLinesPosition"]
		crosshairHorizontalLinesThickness = config["horizontalLinesThickness"]
		crosshairHorizontalLinesLength = config["horizontalLinesLength"]
		circleMode = config["circleMode"]
		circleRadius = config["circleRadius"]
		circleThickness = config["circleThickness"]
		circleColor = config["circleColor"]
		circleOutline = config["circleOutline"]
		circleOutlineThickness = config["circleOutlineThickness"]
		circleOutlineColor = config["circleOutlineColor"]
		splitCircle = config["splitCircle"]
		circleGapCount = config["circleGapCount"]
		circleGapSize = config["circleGapSize"]
		circleRotationOffset = config["circleRotationOffset"]
		crosshairDynamic = config["dynamic"]
		crosshairMaxDynamicOffset = config["maxDynamicOffset"]
		breathingEnabled = config["breathingEnabled"]
		breathingSpeed = config["breathingSpeed"]
		breathingAmplitude = config["breathingAmplitude"]
		breathingWaveform = config["breathingWaveform"]
		dotBreathingEnabled = config["dotBreathingEnabled"]
		dotBreathingSpeed = config["dotBreathingSpeed"]
		dotBreathingAmplitude = config["dotBreathingAmplitude"]
		dotBreathingWaveform = config["dotBreathingWaveform"]
		dotBreathingPhase = config["dotBreathingPhase"]
		circleBreathingEnabled = config["circleBreathingEnabled"]
		circleBreathingSpeed = config["circleBreathingSpeed"]
		circleBreathingAmplitude = config["circleBreathingAmplitude"]
		circleBreathingWaveform = config["circleBreathingWaveform"]
		circleBreathingPhase = config["circleBreathingPhase"]
		circleRotationEnabled = config["circleRotationEnabled"]
		circleRotationSpeed = config["circleRotationSpeed"]
		circleThicknessPulse = config["circleThicknessPulse"]
		circleThicknessPulseAmplitude = config["circleThicknessPulseAmplitude"]
		update_crosshair()
	else:
		push_warning("Invalid config.")


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


func update_crosshair_config() -> void:
	crosshairConfig = {
		"thickness": crosshairThickness,
		"size": crosshairSize,
		"gap": crosshairGap,
		"color": crosshairColor,
		"lineStyle": crosshairLineStyle,
		"lineCap": crosshairLineCap,
		"dot": crosshairDot,
		"dotShape": dotShape,
		"dotCornerRadius": dotCornerRadius,
		"tStyle": crosshairTStyle,
		"outline": crosshairOutline,
		"outlineThickness": crosshairOutlineThickness,
		"outlineColor": crosshairOutlineColor,
		"horizontalLines": crosshairHorizontalLines,
		"horizontalLinesPosition": crosshairHorizontalLinesPosition,
		"horizontalLinesThickness": crosshairHorizontalLinesThickness,
		"horizontalLinesLength": crosshairHorizontalLinesLength,
		"circleMode": circleMode,
		"circleRadius": circleRadius,
		"circleThickness": circleThickness,
		"circleColor": circleColor,
		"circleOutline": circleOutline,
		"circleOutlineThickness": circleOutlineThickness,
		"circleOutlineColor": circleOutlineColor,
		"splitCircle": splitCircle,
		"circleGapCount": circleGapCount,
		"circleGapSize": circleGapSize,
		"circleRotationOffset": circleRotationOffset,
		"dynamic": crosshairDynamic,
		"maxDynamicOffset": crosshairMaxDynamicOffset,
		"breathingEnabled": breathingEnabled,
		"breathingSpeed": breathingSpeed,
		"breathingAmplitude": breathingAmplitude,
		"breathingWaveform": breathingWaveform,
		"dotBreathingEnabled": dotBreathingEnabled,
		"dotBreathingSpeed": dotBreathingSpeed,
		"dotBreathingAmplitude": dotBreathingAmplitude,
		"dotBreathingWaveform": dotBreathingWaveform,
		"dotBreathingPhase": dotBreathingPhase,
		"circleBreathingEnabled": circleBreathingEnabled,
		"circleBreathingSpeed": circleBreathingSpeed,
		"circleBreathingAmplitude": circleBreathingAmplitude,
		"circleBreathingWaveform": circleBreathingWaveform,
		"circleBreathingPhase": circleBreathingPhase,
		"circleRotationEnabled": circleRotationEnabled,
		"circleRotationSpeed": circleRotationSpeed,
		"circleThicknessPulse": circleThicknessPulse,
		"circleThicknessPulseAmplitude": circleThicknessPulseAmplitude,
	}


func update_crosshair() -> void:
	if !TopLineRef or !BottomLineRef or !LeftLineRef or !RightLineRef:
		return

	var lines: Array = [TopLineRef, BottomLineRef, LeftLineRef, RightLineRef]
	var crosshairOffset: float = crosshairGap
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

	for i in range(lines.size()):
		var LineRef = lines[i]
		var start = i * 2
		var end = start + 2

		LineRef.points = linePoints.slice(start, end)
		LineRef.width = crosshairThickness
		LineRef.default_color = crosshairColor
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
				HorizontalLineRef.default_color = crosshairColor
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
	update_crosshair_config()


func _draw() -> void:
	# Draw center dot
	if crosshairDot:
		draw_center_dot()
	
	# Draw circle
	if circleMode:
		draw_circle_crosshair()


func draw_center_dot() -> void:
	var baseDotSize = crosshairThickness
	var dotSize = baseDotSize * currentDotScale
	var halfSize = dotSize / 2
	
	match dotShape:
		0: # Square
			if crosshairOutline:
				draw_rounded_rect(
					Rect2(
						-(halfSize + crosshairOutlineThickness),
						-(halfSize + crosshairOutlineThickness),
						dotSize + crosshairOutlineThickness * 2,
						dotSize + crosshairOutlineThickness * 2
					),
					crosshairOutlineColor,
					dotCornerRadius
				)
			draw_rounded_rect(
				Rect2(-halfSize, -halfSize, dotSize, dotSize),
				crosshairColor,
				dotCornerRadius
			)
		
		1: # Circle
			if crosshairOutline:
				draw_circle(Vector2.ZERO, halfSize + crosshairOutlineThickness, crosshairOutlineColor)
			draw_circle(Vector2.ZERO, halfSize, crosshairColor)
		
		2: # Diamond
			var points = PackedVector2Array([
				Vector2(0, -halfSize),
				Vector2(halfSize, 0),
				Vector2(0, halfSize),
				Vector2(-halfSize, 0)
			])
			if crosshairOutline:
				var outlinePoints = PackedVector2Array([
					Vector2(0, -(halfSize + crosshairOutlineThickness)),
					Vector2(halfSize + crosshairOutlineThickness, 0),
					Vector2(0, halfSize + crosshairOutlineThickness),
					Vector2(-(halfSize + crosshairOutlineThickness), 0)
				])
				draw_polygon(outlinePoints, PackedColorArray([crosshairOutlineColor]))
			draw_polygon(points, PackedColorArray([crosshairColor]))
		
		3: # Cross
			var crossThickness = dotSize * 0.3
			if crosshairOutline:
				draw_line(Vector2(0, -halfSize - crosshairOutlineThickness), Vector2(0, halfSize + crosshairOutlineThickness), crosshairOutlineColor, crossThickness + crosshairOutlineThickness * 2)
				draw_line(Vector2(-halfSize - crosshairOutlineThickness, 0), Vector2(halfSize + crosshairOutlineThickness, 0), crosshairOutlineColor, crossThickness + crosshairOutlineThickness * 2)
			draw_line(Vector2(0, -halfSize), Vector2(0, halfSize), crosshairColor, crossThickness)
			draw_line(Vector2(-halfSize, 0), Vector2(halfSize, 0), crosshairColor, crossThickness)
		
		4: # Plus
			var plusSize = dotSize * 0.8
			var plusThickness = dotSize * 0.25
			if crosshairOutline:
				draw_rect(Rect2(-plusThickness / 2 - crosshairOutlineThickness, -plusSize / 2 - crosshairOutlineThickness, plusThickness + crosshairOutlineThickness * 2, plusSize + crosshairOutlineThickness * 2), crosshairOutlineColor)
				draw_rect(Rect2(-plusSize / 2 - crosshairOutlineThickness, -plusThickness / 2 - crosshairOutlineThickness, plusSize + crosshairOutlineThickness * 2, plusThickness + crosshairOutlineThickness * 2), crosshairOutlineColor)
			draw_rect(Rect2(-plusThickness / 2, -plusSize / 2, plusThickness, plusSize), crosshairColor)
			draw_rect(Rect2(-plusSize / 2, -plusThickness / 2, plusSize, plusThickness), crosshairColor)


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
	var finalColor = circleColor if circleColor.a > 0 else crosshairColor
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