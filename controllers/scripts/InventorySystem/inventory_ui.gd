class_name InventoryUI extends Control

## Main UI controller for the inventory system

signal ui_closed()

@export var inventory_component: InventoryComponent
@export var cell_size: Vector2 = Vector2(64, 64)
@export var cell_spacing: int = 2

@onready var player_grid: Control = $MarginContainer/HBoxContainer/PlayerPanel/VBoxContainer/PlayerGrid
@onready var equipment_panel: Control = $MarginContainer/HBoxContainer/EquipmentPanel
@onready var container_panel: Control = $MarginContainer/HBoxContainer/ContainerPanel
@onready var hotbar: HBoxContainer = $BottomPanel/PanelContainer/VBoxContainer/Hotbar
#@onready var hotbar: HBoxContainer = $MarginContainer/HBoxContainer/BottomPanel/Hotbar
@onready var tooltip: PanelContainer = $Tooltip
@onready var context_menu: PopupMenu = $ContextMenu
#@onready var weight_label: Label = $MarginContainer/HBoxContainer/PlayerPanel/WeightLabel
@onready var weight_label: Label = $MarginContainer/HBoxContainer/PlayerPanel/VBoxContainer/WeightLabel

# Drag and drop state
var dragged_item: InventoryItem = null
var drag_preview: Control = null
var drag_offset: Vector2 = Vector2.ZERO
var drag_original_pos: Vector2i = Vector2i.ZERO

# Container state
var current_container: InventoryComponent = null

# UI item nodes cache
var item_nodes: Dictionary = {}

func _ready():
	if not inventory_component:
		push_error("InventoryUI: No inventory component assigned!")
		return
	
	_setup_ui()
	_connect_signals()
	hide()

func _setup_ui():
	# Setup player grid
	_setup_grid(player_grid, inventory_component.grid_columns, inventory_component.grid_rows)
	
	# Setup equipment slots
	_setup_equipment_panel()
	
	# Setup hotbar
	_setup_hotbar()
	
	# Setup context menu
	_setup_context_menu()
	
	# Hide container panel initially
	container_panel.hide()

func _setup_grid(grid: Control, columns: int, rows: int):
	# Create grid cells
	for y in range(rows):
		for x in range(columns):
			var cell = Panel.new()
			cell.custom_minimum_size = cell_size
			cell.position = Vector2(x * (cell_size.x + cell_spacing), y * (cell_size.y + cell_spacing))
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			grid.add_child(cell)
	
	grid.custom_minimum_size = Vector2(
		columns * (cell_size.x + cell_spacing),
		rows * (cell_size.y + cell_spacing)
	)

func _setup_equipment_panel():
	# Create equipment slots
	var slots = ["head", "body", "hands", "belt_1", "belt_2", "primary_weapon", "secondary_weapon", "melee"]
	
	for slot in slots:
		var slot_panel = Panel.new()
		slot_panel.name = slot
		slot_panel.custom_minimum_size = cell_size
		equipment_panel.add_child(slot_panel)

func _setup_hotbar():
	for i in range(inventory_component.hotbar_slots):
		var slot = Panel.new()
		slot.name = "Hotbar_%d" % i
		slot.custom_minimum_size = cell_size
		hotbar.add_child(slot)

func _setup_context_menu():
	context_menu.clear()
	context_menu.add_item("Use", 0)
	context_menu.add_item("Equip", 1)
	context_menu.add_item("Drop", 2)
	context_menu.add_item("Split Stack", 3)
	context_menu.add_item("Rotate", 4)
	context_menu.add_item("Examine", 5)
	context_menu.id_pressed.connect(_on_context_menu_selected)

func _connect_signals():
	inventory_component.item_added.connect(_on_item_added)
	inventory_component.item_removed.connect(_on_item_removed)
	inventory_component.item_moved.connect(_on_item_moved)
	inventory_component.item_equipped.connect(_on_item_equipped)
	inventory_component.item_unequipped.connect(_on_item_unequipped)

func _input(event):
	if not visible:
		return
	
	# Handle hotbar keys
	if event is InputEventKey and event.pressed:
		for i in range(inventory_component.hotbar_slots):
			if event.keycode == KEY_1 + i:
				inventory_component.use_hotbar_slot(i)
	
	# Handle close
	if event.is_action_pressed("ui_cancel"):
		close_inventory()
		get_viewport().set_input_as_handled()

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_start_drag(event.position)
			else:
				_end_drag(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_show_context_menu(event.position)
	
	elif event is InputEventMouseMotion and dragged_item:
		_update_drag(event.position)

func open_inventory():
	show()
	_refresh_ui()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close_inventory():
	hide()
	ui_closed.emit()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func open_container(container: InventoryComponent):
	current_container = container
	container_panel.show()
	_refresh_container_ui()

func close_container():
	current_container = null
	container_panel.hide()

func _refresh_ui():
	# Clear existing UI items
	for node in item_nodes.values():
		node.queue_free()
	item_nodes.clear()
	
	# Recreate items
	for item in inventory_component.get_all_items():
		_create_item_node(item)
	
	# Update equipment
	_refresh_equipment()
	
	# Update hotbar
	_refresh_hotbar()
	
	# Update weight
	_update_weight_display()

func _create_item_node(item: InventoryItem) -> Control:
	var item_node = Panel.new()
	item_node.name = "Item_%s" % item.id
	item_node.custom_minimum_size = Vector2(
		item.width * cell_size.x + (item.width - 1) * cell_spacing,
		item.height * cell_size.y + (item.height - 1) * cell_spacing
	)
	
	# Add icon
	var texture_rect = TextureRect.new()
	texture_rect.texture = item.icon
	texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.anchor_right = 1.0
	texture_rect.anchor_bottom = 1.0
	item_node.add_child(texture_rect)
	
	# Add stack count label
	if item.stackable and item.stack_count > 1:
		var label = Label.new()
		label.text = str(item.stack_count)
		label.anchor_left = 1.0
		label.anchor_top = 1.0
		label.anchor_right = 1.0
		label.anchor_bottom = 1.0
		label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		label.grow_vertical = Control.GROW_DIRECTION_BEGIN
		item_node.add_child(label)
	
	# Position
	item_node.position = Vector2(
		item.grid_x * (cell_size.x + cell_spacing),
		item.grid_y * (cell_size.y + cell_spacing)
	)
	
	player_grid.add_child(item_node)
	item_nodes[item] = item_node
	
	# Connect hover for tooltip
	item_node.mouse_entered.connect(_on_item_hover.bind(item))
	item_node.mouse_exited.connect(_on_item_unhover)
	
	return item_node

func _refresh_equipment():
	for slot in inventory_component.equipment_slots.keys():
		var slot_node = equipment_panel.get_node_or_null(slot)
		if not slot_node:
			continue
		
		# Clear existing children
		for child in slot_node.get_children():
			child.queue_free()
		
		var item = inventory_component.equipment_slots[slot]
		if item:
			var texture_rect = TextureRect.new()
			texture_rect.texture = item.icon
			texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			texture_rect.anchor_right = 1.0
			texture_rect.anchor_bottom = 1.0
			slot_node.add_child(texture_rect)

func _refresh_hotbar():
	for i in range(inventory_component.hotbar_slots):
		var slot_node = hotbar.get_node("Hotbar_%d" % i)
		if not slot_node:
			continue
		
		# Clear existing children
		for child in slot_node.get_children():
			child.queue_free()
		
		var item = inventory_component.hotbar[i]
		if item:
			var texture_rect = TextureRect.new()
			texture_rect.texture = item.icon
			texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			texture_rect.anchor_right = 1.0
			texture_rect.anchor_bottom = 1.0
			slot_node.add_child(texture_rect)

func _refresh_container_ui():
	# Similar to _refresh_ui but for container
	pass

func _update_weight_display():
	if weight_label and inventory_component.enable_weight_limit:
		weight_label.text = "Weight: %.1f / %.1f" % [
			inventory_component.current_weight,
			inventory_component.max_weight
		]
		weight_label.show()
	else:
		weight_label.hide()

func _start_drag(pos: Vector2):
	var item = _get_item_at_position(pos)
	if item:
		dragged_item = item
		drag_original_pos = Vector2i(item.grid_x, item.grid_y)
		
		# Create drag preview
		drag_preview = _create_drag_preview(item)
		add_child(drag_preview)
		
		# Remove from current position visually
		if item_nodes.has(item):
			item_nodes[item].modulate.a = 0.5

func _end_drag(pos: Vector2):
	if not dragged_item:
		return
	
	var grid_pos = _screen_to_grid(pos)
	
	if grid_pos.x >= 0 and grid_pos.y >= 0:
		# Try to place at new position
		if inventory_component.move_item(dragged_item, grid_pos.x, grid_pos.y):
			pass # Success
		else:
			# Return to original position
			pass
	
	# Cleanup
	if drag_preview:
		drag_preview.queue_free()
		drag_preview = null
	
	if item_nodes.has(dragged_item):
		item_nodes[dragged_item].modulate.a = 1.0
	
	dragged_item = null
	_refresh_ui()

func _update_drag(pos: Vector2):
	if drag_preview:
		drag_preview.position = pos - drag_offset

func _create_drag_preview(item: InventoryItem) -> Control:
	var preview = Panel.new()
	preview.custom_minimum_size = Vector2(
		item.width * cell_size.x,
		item.height * cell_size.y
	)
	preview.modulate.a = 0.7
	
	var texture_rect = TextureRect.new()
	texture_rect.texture = item.icon
	texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	texture_rect.anchor_right = 1.0
	texture_rect.anchor_bottom = 1.0
	preview.add_child(texture_rect)
	
	return preview

func _get_item_at_position(pos: Vector2) -> InventoryItem:
	var grid_pos = _screen_to_grid(pos)
	if grid_pos.x >= 0 and grid_pos.y >= 0:
		return inventory_component.get_item_at(grid_pos.x, grid_pos.y)
	return null

func _screen_to_grid(screen_pos: Vector2) -> Vector2i:
	var local_pos = player_grid.get_local_mouse_position()
	var x = int(local_pos.x / (cell_size.x + cell_spacing))
	var y = int(local_pos.y / (cell_size.y + cell_spacing))
	
	if x >= 0 and x < inventory_component.grid_columns and y >= 0 and y < inventory_component.grid_rows:
		return Vector2i(x, y)
	return Vector2i(-1, -1)

func _show_context_menu(pos: Vector2):
	var item = _get_item_at_position(pos)
	if item:
		context_menu.position = get_global_mouse_position()
		context_menu.popup()

func _on_context_menu_selected(id: int):
	# Get item under mouse
	var item = _get_item_at_position(get_local_mouse_position())
	if not item:
		return
	
	match id:
		0: # Use
			_use_item(item)
		1: # Equip
			if item.equip_slot != "":
				inventory_component.equip_item(item, item.equip_slot)
		2: # Drop
			inventory_component.remove_item(item)
		3: # Split Stack
			if item.stackable and item.stack_count > 1:
				var new_item = inventory_component.split_stack(item, item.stack_count / 2)
				if new_item:
					inventory_component.add_item(new_item)
		4: # Rotate
			inventory_component.rotate_item(item)
		5: # Examine
			_show_item_details(item)

func _use_item(item: InventoryItem):
	match item.type:
		"consumable":
			# Use consumable
			pass
		"key":
			# Use key
			pass

func _show_item_details(item: InventoryItem):
	# Show detailed item info in a popup
	pass

func _on_item_hover(item: InventoryItem):
	tooltip.show()
	var tooltip_label = tooltip.get_node_or_null("Label")
	if tooltip_label:
		tooltip_label.text = "%s\n%s\nWeight: %.1f" % [
			item.display_name,
			item.description,
			item.weight
		]
	tooltip.position = get_global_mouse_position() + Vector2(10, 10)

func _on_item_unhover():
	tooltip.hide()

# Signal callbacks
func _on_item_added(item: InventoryItem, x: int, y: int):
	_refresh_ui()

func _on_item_removed(item: InventoryItem):
	_refresh_ui()

func _on_item_moved(item: InventoryItem, from_x: int, from_y: int, to_x: int, to_y: int):
	_refresh_ui()

func _on_item_equipped(item: InventoryItem, slot: String):
	_refresh_equipment()
	_refresh_ui()

func _on_item_unequipped(item: InventoryItem, slot: String):
	_refresh_equipment()
	_refresh_ui()
