# Uncomment if you want to see the cursor in the editor
@tool
extends CenterContainer

@export_category("Crosshair settings")
## The thickness of the lines.
@export var crosshairThickness: float:
	set(value):
		crosshairThickness = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

## The length of the lines.
@export var crosshairSize: float:
	set(value):
		crosshairSize = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

## The distance between the middle of the screen and the starts of the lines.
@export var crosshairGap: float:
	set(value):
		crosshairGap = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

## The color of the crosshair.
@export var crosshairColor: Color:
	set(value):
		crosshairColor = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()


@export_group("Style settings")
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

## Toggle for the middle dot.
@export var crosshairDot: bool:
	set(value):
		crosshairDot = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

## Toggle to make the crosshair T style meaning the top line is removed.
@export var crosshairTStyle: bool:
	set(value):
		crosshairTStyle = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()


@export_subgroup("Outline settings")
## Toggle for an outline for the lines.
@export var crosshairOutline: bool:
	set(value):
		crosshairOutline = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

## The thickness of the outline.
@export var crosshairOutlineThickness: float:
	set(value):
		crosshairOutlineThickness = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()


@export_subgroup("Horizontal lines settings")
## Toggle to add horizontal lines at the beginning of the crosshair lines.
@export var crosshairHorizontalLines: bool:
	set(value):
		crosshairHorizontalLines = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

## The position of the horizontal lines along their local Y-Axis.
## If set to 0 the horizontal lines will be at the start of the crosshair lines.
@export var crosshairHorizontalLinesPosition: float:
	set(value):
		crosshairHorizontalLinesPosition = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

## The thickness of the horizontal lines.
## If set to 0 crosshairThickness will be used instead.
@export var crosshairHorizontalLinesThickness: float:
	set(value):
		crosshairHorizontalLinesThickness = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

## The width of the horizontal lines.
## If set to 0 crosshairGap will be used instead.
@export var crosshairHorizontalLinesLength: float:
	set(value):
		crosshairHorizontalLinesLength = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()


@export_group("Optional settings")
## Toggle for if the lines should move based on input.
@export var crosshairDynamic: bool:
	set(value):
		crosshairDynamic = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()

## Controls the maximum amount of offset the lines should have.
@export var crosshairMaxDynamicOffset: float:
	set(value):
		crosshairMaxDynamicOffset = value
		if Engine.is_editor_hint() or !is_inside_tree():
			update_crosshair()


# Line nodes
@onready var TopLineRef: Node2D = $TopLine
@onready var BottomLineRef: Node2D = $BottomLine
@onready var LeftLineRef: Node2D = $LeftLine
@onready var RightLineRef: Node2D = $RightLine

# Both of these are only used when dynamic crosshair enabled
var crosshairDynamicOffset: float
var crosshairStaticOffset: float

# A dictionary that holds all the config values for the crosshair
var crosshairConfig: Dictionary


func _ready() -> void:
	update_crosshair()
	if Engine.is_editor_hint():
		connect("hidden", Callable(self, "update_crosshair"))


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
	return JSON.stringify(dict)


func parse_config_string(configString: String) -> void:
	var config = JSON.parse_string(configString)
	if config == null:
		print("Incorrect config string!")
		return

	config["color"] = Color(config["color"][0], config["color"][1], config["color"][2], config["color"][3])
	config["lineStyle"] = int(config["lineStyle"])  # Ensure correct type

	get_crosshair_settings(config)


func get_crosshair_settings(config: Dictionary) -> void:
	if valid_config(config):
		crosshairThickness = config["thickness"]
		crosshairSize = config["size"]
		crosshairGap = config["gap"]
		crosshairColor = config["color"]
		crosshairLineStyle = config["lineStyle"]
		crosshairDot = config["dot"]
		crosshairTStyle = config["tStyle"]
		crosshairOutline = config["outline"]
		crosshairOutlineThickness = config["outlineThickness"]
		crosshairHorizontalLines = config["horizontalLines"]
		crosshairHorizontalLinesPosition = config["horizontalLinesPosition"]
		crosshairHorizontalLinesThickness = config["horizontalLinesThickness"]
		crosshairHorizontalLinesLength = config["horizontalLinesLength"]
		crosshairDynamic = config["dynamic"]
		crosshairMaxDynamicOffset = config["maxDynamicOffset"]
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


func update_crosshair_config() -> void:
	crosshairConfig = {
		"thickness": crosshairThickness,
		"size": crosshairSize,
		"gap": crosshairGap,
		"color": crosshairColor,
		"lineStyle": crosshairLineStyle,
		"dot": crosshairDot,
		"tStyle": crosshairTStyle,
		"outline": crosshairOutline,
		"outlineThickness": crosshairOutlineThickness,
		"horizontalLines": crosshairHorizontalLines,
		"horizontalLinesPosition": crosshairHorizontalLinesPosition,
		"horizontalLinesThickness": crosshairHorizontalLinesThickness,
		"horizontalLinesLength": crosshairHorizontalLinesLength,
		"dynamic": crosshairDynamic,
		"maxDynamicOffset": crosshairMaxDynamicOffset
	}


func update_crosshair() -> void:
	# Avoid errors if node tree isn't ready yet (e.g., during editor property changes)
	if !TopLineRef or !BottomLineRef or !LeftLineRef or !RightLineRef:
		return

	var lines: Array = [TopLineRef, BottomLineRef, LeftLineRef, RightLineRef]
	var crosshairOffset: float = crosshairGap

	if crosshairDynamic:
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

	for i in range(lines.size()):
		var LineRef = lines[i]
		var start = i * 2
		var end = start + 2

		LineRef.points = linePoints.slice(start, end)
		LineRef.width = crosshairThickness
		LineRef.default_color = crosshairColor
		LineRef.width_curve = update_line_style(crosshairLineStyle)

		if crosshairOutline:
			var OutlineRef: Line2D = LineRef.get_child(0)
			if OutlineRef:
				OutlineRef.visible = true
				OutlineRef.points = PackedVector2Array([
					linePoints[start] - linePoints[start].normalized() * crosshairOutlineThickness * dir,
					linePoints[start + 1] + linePoints[start + 1].normalized() * crosshairOutlineThickness * dir
				])
				OutlineRef.width = crosshairThickness + crosshairOutlineThickness * 2
				OutlineRef.width_curve = update_line_style(crosshairLineStyle)
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

				if crosshairOutline:
					var HOutlineRef: Line2D = HorizontalLineRef.get_child(0)
					if HOutlineRef:
						HOutlineRef.visible = true
						HOutlineRef.points = PackedVector2Array([
							horizontalLinePoints[start] + horizontalLineOutlineDirections[start] * crosshairOutlineThickness,
							horizontalLinePoints[start + 1] + horizontalLineOutlineDirections[start + 1] * crosshairOutlineThickness
						])
						HOutlineRef.width = horizontalLineThickness + crosshairOutlineThickness * 2
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
	if crosshairDot:
		if crosshairOutline:
			draw_rect(
				Rect2(
					-(crosshairThickness / 2 + crosshairOutlineThickness),
					-(crosshairThickness / 2 + crosshairOutlineThickness),
					crosshairThickness + crosshairOutlineThickness * 2,
					crosshairThickness + crosshairOutlineThickness * 2
				),
				Color.BLACK
			)
		draw_rect(
			Rect2(
				-crosshairThickness / 2,
				-crosshairThickness / 2,
				crosshairThickness,
				crosshairThickness
			),
			crosshairColor
		)