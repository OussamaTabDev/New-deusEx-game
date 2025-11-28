class_name InventoryUI extends Control

## UI for Deus Ex-style grid-based inventory system
## Features: Anchored dragging, Grid Snapping, Valid/Invalid visual feedback

signal ui_closed()
signal item_used(item: InventoryItem)
signal container_closed()

const cell_size = 64
@export var CELL_SPACING: int = 2
const GRID_PADDING = 10
const TOOLTIP_OFFSET = Vector2(15, 15)

# Colors for the "Ghost" drag preview
const COLOR_VALID_DROP = Color(0.2, 0.8, 0.2, 0.5) # Green
const COLOR_INVALID_DROP = Color(0.8, 0.2, 0.2, 0.5) # Red

# Node references
@onready var background: ColorRect = $Background
@onready var player_grid: Control = $MarginContainer/HBoxContainer/PlayerPanel/VBoxContainer/PlayerGrid
@onready var container_grid: Control = $MarginContainer/HBoxContainer/ContainerPanel/VBoxContainer/ContainerGrid
@onready var equipment_panel: PanelContainer = $MarginContainer/HBoxContainer/EquipmentPanel
@onready var container_panel: PanelContainer = $MarginContainer/HBoxContainer/ContainerPanel
@onready var hotbar: HBoxContainer = $BottomPanel/PanelContainer/VBoxContainer/Hotbar
@onready var tooltip: PanelContainer = $Tooltip
@onready var context_menu: PopupMenu = $ContextMenu
@onready var weight_label: Label = $MarginContainer/HBoxContainer/PlayerPanel/VBoxContainer/WeightLabel
@onready var auto_organize_btn: Button = $MarginContainer/HBoxContainer/PlayerPanel/VBoxContainer/Actions/AutoOrganizeButton
@onready var close_btn: Button = $MarginContainer/HBoxContainer/PlayerPanel/VBoxContainer/Actions/CloseButton
@onready var loot_all_btn: Button = $MarginContainer/HBoxContainer/ContainerPanel/VBoxContainer/Actions/LootAllButton
@onready var close_container_btn: Button = $MarginContainer/HBoxContainer/ContainerPanel/VBoxContainer/Actions/CloseContainerButton

# Tooltip child nodes
@onready var tooltip_item_name: Label = $Tooltip/MarginContainer/VBoxContainer/ItemName
@onready var tooltip_description: Label = $Tooltip/MarginContainer/VBoxContainer/ItemDescription
@onready var tooltip_stats: Label = $Tooltip/MarginContainer/VBoxContainer/ItemStats

# Core references
var inventory_component: InventoryComponent
var current_container: ContainerComponent

# Drag & drop state
var dragged_item: InventoryItem = null
var drag_source: String = ""  # "player", "container", "equipment"
var is_dragging: bool = false

# Advanced Drag State
var drag_floating_icon: Control = null # The icon following the mouse
var drag_grid_ghost: Control = null    # The snapped rectangle on the grid
var drag_anchor_offset: Vector2i = Vector2i.ZERO # Which cell of the item did we grab?
var current_hover_grid: Control = null
var current_drop_valid: bool = false
var current_drop_pos: Vector2i = Vector2i(-1, -1)

# Grid visual state
var player_grid_cells: Array[Panel] = []
var container_grid_cells: Array[Panel] = []
var equipment_slots: Dictionary = {}
var hotbar_slots: Array[Panel] = []
var item_visuals: Dictionary = {}  # InventoryItem -> TextureRect

# Context menu state
var context_menu_item: InventoryItem = null
var context_menu_source: String = ""

func _ready():
	visible = false
	
	# Setup buttons
	auto_organize_btn.pressed.connect(_on_auto_organize_pressed)
	close_btn.pressed.connect(_on_close_pressed)
	loot_all_btn.pressed.connect(_on_loot_all_pressed)
	close_container_btn.pressed.connect(_on_close_container_pressed)
	
	# Setup context menu
	context_menu.id_pressed.connect(_on_context_menu_item_selected)
	context_menu.add_item("Use", 0)
	context_menu.add_item("Equip", 1)
	context_menu.add_item("Unequip", 2)
	context_menu.add_separator()
	context_menu.add_item("Split Stack", 3)
	context_menu.add_separator()
	context_menu.add_item("Drop", 4)
	context_menu.add_item("Examine", 5)
	
	# Initialize grids
	_initialize_player_grid()
	_initialize_equipment_slots()
	_initialize_hotbar()

	# Create the ghost node specifically
	drag_grid_ghost = Panel.new()
	drag_grid_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style = StyleBoxFlat.new()
	style.set_corner_radius_all(4)
	drag_grid_ghost.add_theme_stylebox_override("panel", style)
	drag_grid_ghost.visible = false
	# We add it to the scene, but we will reparent it dynamically to the active grid
	add_child(drag_grid_ghost) 

func _initialize_player_grid():
	if not inventory_component:
		return
	
	var total_width = inventory_component.grid_columns * cell_size + max(0, inventory_component.grid_columns - 1) * CELL_SPACING
	var total_height = inventory_component.grid_rows * cell_size + max(0, inventory_component.grid_rows - 1) * CELL_SPACING
	player_grid.custom_minimum_size = Vector2(total_width, total_height)
	
	player_grid_cells.clear()
	for y in range(inventory_component.grid_rows):
		for x in range(inventory_component.grid_columns):
			var cell = Panel.new()
			cell.custom_minimum_size = Vector2(cell_size, cell_size)
			cell.size = Vector2(cell_size, cell_size)
			cell.position = Vector2(
				x * (cell_size + CELL_SPACING),
				y * (cell_size + CELL_SPACING)
			)
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			
			var style = StyleBoxFlat.new()
			style.bg_color = Color(0.2, 0.2, 0.2, 0.5)
			style.border_color = Color(0.4, 0.4, 0.4)
			style.set_border_width_all(1)
			cell.add_theme_stylebox_override("panel", style)
			
			player_grid.add_child(cell)
			player_grid_cells.append(cell)

func _initialize_equipment_slots():
	var slot_names = ["head", "body", "hands", "primary_weapon", "secondary_weapon", "melee", "belt_1", "belt_2"]
	for slot_name in slot_names:
		var slot_panel = equipment_panel.get_node_or_null("VBoxContainer/" + slot_name)
		if slot_panel:
			equipment_slots[slot_name] = slot_panel
			slot_panel.gui_input.connect(_on_equipment_slot_input.bind(slot_name))

func _initialize_hotbar():
	for i in range(8):
		var slot = Panel.new()
		slot.custom_minimum_size = Vector2(cell_size, cell_size)
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.15, 0.15, 0.15, 0.8)
		style.border_color = Color(0.5, 0.5, 0.5)
		style.set_border_width_all(2)
		slot.add_theme_stylebox_override("panel", style)
		
		var label = Label.new()
		label.text = str(i + 1)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.add_child(label)
		hotbar.add_child(slot)
		hotbar_slots.append(slot)

func _initialize_container_grid(container: ContainerComponent):
	for cell in container_grid_cells:
		cell.queue_free()
	container_grid_cells.clear()
	
	var total_width = container.inventory.grid_columns * cell_size + max(0, container.inventory.grid_columns - 1) * CELL_SPACING
	var total_height = container.inventory.grid_rows * cell_size + max(0, container.inventory.grid_rows - 1) * CELL_SPACING
	container_grid.custom_minimum_size = Vector2(total_width, total_height)
	
	for y in range(container.inventory.grid_rows):
		for x in range(container.inventory.grid_columns):
			var cell = Panel.new()
			cell.custom_minimum_size = Vector2(cell_size, cell_size)
			cell.position = Vector2(
				x * (cell_size + CELL_SPACING),
				y * (cell_size + CELL_SPACING)
			)
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			
			var style = StyleBoxFlat.new()
			style.bg_color = Color(0.2, 0.2, 0.25, 0.5)
			style.border_color = Color(0.4, 0.4, 0.5)
			style.set_border_width_all(1)
			cell.add_theme_stylebox_override("panel", style)
			
			container_grid.add_child(cell)
			container_grid_cells.append(cell)

func open_inventory():
	visible = true
	refresh_display()

func close_inventory():
	visible = false
	if current_container:
		close_container()
	ui_closed.emit()

func open_container(container: ContainerComponent):
	current_container = container
	container_panel.visible = true
	_initialize_container_grid(container)
	refresh_display()

func close_container():
	if current_container:
		current_container.close()
		current_container = null
	container_panel.visible = false
	container_closed.emit()

func refresh_display():
	_clear_item_visuals()
	_update_weight_label()
	
	if inventory_component:
		_display_inventory_items(inventory_component, player_grid, "player")
		_display_equipment_items()
		_display_hotbar_items()
	
	if current_container:
		_display_inventory_items(current_container.inventory, container_grid, "container")

func _clear_item_visuals():
	for visual in item_visuals.values():
		if is_instance_valid(visual):
			visual.queue_free()
	item_visuals.clear()

func _display_inventory_items(inv: InventoryComponent, grid: Control, source: String):
	var items = inv.get_all_items()
	for item in items:
		# Don't render the item being dragged in the grid
		if is_dragging and item == dragged_item:
			continue
			
		if item.grid_x >= 0 and item.grid_y >= 0:
			var visual = _create_item_visual(item, source)
			visual.position = Vector2(
				item.grid_x * (cell_size + CELL_SPACING),
				item.grid_y * (cell_size + CELL_SPACING)
			)
			grid.add_child(visual)
			item_visuals[item] = visual

func _display_equipment_items():
	if not inventory_component: return
	for slot_name in equipment_slots.keys():
		var slot_panel = equipment_slots[slot_name]
		var item = inventory_component.equipment_slots.get(slot_name)
		
		for child in slot_panel.get_children():
			if child is TextureRect: child.queue_free()
		
		if item and item.icon:
			# If dragging this specific equipped item, don't show it in slot
			if is_dragging and item == dragged_item: continue
				
			var visual = TextureRect.new()
			visual.texture = item.icon
			visual.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			visual.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			visual.custom_minimum_size = Vector2(cell_size - 8, cell_size - 8)
			visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot_panel.add_child(visual)

func _display_hotbar_items():
	if not inventory_component: return
	for i in range(hotbar_slots.size()):
		var slot = hotbar_slots[i]
		var item = inventory_component.hotbar[i]
		
		for child in slot.get_children():
			if child is TextureRect: child.queue_free()
		
		if item and item.icon:
			var visual = TextureRect.new()
			visual.texture = item.icon
			visual.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			visual.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			visual.custom_minimum_size = Vector2(cell_size - 8, cell_size - 8)
			visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(visual)
			
			if item.stackable and item.stack_count > 1:
				var count_label = Label.new()
				count_label.text = str(item.stack_count)
				count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
				count_label.add_theme_font_size_override("font_size", 14)
				count_label.add_theme_color_override("font_outline_color", Color.BLACK)
				count_label.add_theme_constant_override("outline_size", 2)
				visual.add_child(count_label)

func _create_item_visual(item: InventoryItem, source: String) -> Control:
	var item_node = Panel.new()
	item_node.name = "Item_%s" % item.id
	
	var width_px = item.width * cell_size + max(0, item.width - 1) * CELL_SPACING 
	var height_px = item.height * cell_size + max(0, item.height - 1) * CELL_SPACING
	item_node.custom_minimum_size = Vector2(width_px, height_px)
	item_node.size = Vector2(width_px, height_px)

	var texture_rect = TextureRect.new()
	texture_rect.texture = item.icon
	texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.anchor_right = 1.0
	texture_rect.anchor_bottom = 1.0
	item_node.add_child(texture_rect)

	texture_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	# Connect input directly to handle dragging logic
	texture_rect.gui_input.connect(_on_item_gui_input.bind(item, source))
	texture_rect.mouse_entered.connect(_on_item_mouse_entered.bind(item))
	texture_rect.mouse_exited.connect(_on_item_mouse_exited)

	if item.stackable and item.stack_count > 1:
		var label = Label.new()
		label.text = str(item.stack_count)
		label.anchor_right = 1.0
		label.anchor_bottom = 1.0
		label.offset_right = -2
		label.offset_bottom = -2
		label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		label.grow_vertical = Control.GROW_DIRECTION_BEGIN
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		item_node.add_child(label)

	return item_node

func _update_weight_label():
	if not inventory_component: return
	if inventory_component.enable_weight_limit:
		weight_label.visible = true
		weight_label.text = "Weight: %.1f / %.1f" % [inventory_component.current_weight, inventory_component.max_weight]
	else:
		weight_label.visible = false

# --- ADVANCED DRAG AND DROP SYSTEM ---

func _input(event):
	if not visible: return
	
	if event.is_action_pressed("ui_cancel"):
		if is_dragging:
			_cancel_drag()
		else:
			close_inventory()
		get_viewport().set_input_as_handled()
	
	if is_dragging:
		if event is InputEventMouseMotion:
			_process_drag_motion()
		
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
				_end_drag()

func _on_item_gui_input(event: InputEvent, item: InventoryItem, source: String):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_start_drag(item, source)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if not is_dragging:
				_show_context_menu(item, source, get_global_mouse_position())
		
		# Important: Stop propagation so we don't click grid underneath
		get_viewport().set_input_as_handled() 

func _start_drag(item: InventoryItem, source: String):
	dragged_item = item
	drag_source = source
	is_dragging = true
	
	# 1. Calculate Anchor Offset (The specific cell clicked within the item)
	# This prevents the item from "jumping" to top-left corner when grabbed
	var item_visual = item_visuals.get(item)
	if item_visual:
		var local_click_pos = item_visual.get_local_mouse_position()
		var col = int(local_click_pos.x / (cell_size + CELL_SPACING))
		var row = int(local_click_pos.y / (cell_size + CELL_SPACING))
		# Clamp to ensure we are within item bounds
		drag_anchor_offset = Vector2i(
			clamp(col, 0, item.width - 1),
			clamp(row, 0, item.height - 1)
		)
	else:
		# Fallback if dragging from equipment/hotbar
		drag_anchor_offset = Vector2i(0, 0)

	# 2. Create Floating Icon (follows mouse exactly)
	drag_floating_icon = TextureRect.new()
	drag_floating_icon.texture = item.icon
	drag_floating_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	drag_floating_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	drag_floating_icon.custom_minimum_size = Vector2(item.width * cell_size, item.height * cell_size)
	drag_floating_icon.size = drag_floating_icon.custom_minimum_size
	drag_floating_icon.modulate = Color(1, 1, 1, 0.8)
	drag_floating_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Center the specific anchor cell on the mouse
	drag_floating_icon.set_meta("center_offset", Vector2(
		(drag_anchor_offset.x * (cell_size + CELL_SPACING)) + (cell_size / 2.0),
		(drag_anchor_offset.y * (cell_size + CELL_SPACING)) + (cell_size / 2.0)
	))
	add_child(drag_floating_icon)
	
	# 3. Setup Grid Ghost (Snaps to grid)
	drag_grid_ghost.visible = false
	drag_grid_ghost.size = Vector2(
		item.width * cell_size + (item.width - 1) * CELL_SPACING,
		item.height * cell_size + (item.height - 1) * CELL_SPACING
	)
	
	# Hide the original item immediately for visual clarity
	if item_visual:
		item_visual.visible = false
		
	_process_drag_motion()

func _process_drag_motion():
	if not drag_floating_icon: return
	
	var global_mouse = get_global_mouse_position()
	
	# Update Floating Icon
	var offset = drag_floating_icon.get_meta("center_offset")
	drag_floating_icon.global_position = global_mouse - offset
	
	# Determine which grid we are over
	current_hover_grid = null
	var inv_to_check: InventoryComponent = null
	
	if player_grid.get_global_rect().has_point(global_mouse):
		current_hover_grid = player_grid
		inv_to_check = inventory_component
	elif current_container and container_grid.get_global_rect().has_point(global_mouse):
		current_hover_grid = container_grid
		inv_to_check = current_container.inventory
		
	# Update Ghost Logic
	if current_hover_grid and inv_to_check:
		# Convert mouse to local grid coordinates
		var local_pos = current_hover_grid.get_local_mouse_position()
		var grid_step = cell_size + CELL_SPACING
		
		# Calculate raw grid cell under mouse
		var raw_x = int(local_pos.x / grid_step)
		var raw_y = int(local_pos.y / grid_step)
		
		# Apply Anchor Offset to find the Item's Top-Left origin
		var target_x = raw_x - drag_anchor_offset.x
		var target_y = raw_y - drag_anchor_offset.y
		
		current_drop_pos = Vector2i(target_x, target_y)
		
		# Check validity (Collision check)
		# Note: We pass the dragged item so the logic ignores the item's *current* position
		# assuming your inventory component handles "check_collision(item, x, y, ignore_self)"
		current_drop_valid = inv_to_check.can_place_item(dragged_item, target_x, target_y)
		
		# Visual Snap
		drag_grid_ghost.get_parent().remove_child(drag_grid_ghost)
		current_hover_grid.add_child(drag_grid_ghost)
		drag_grid_ghost.visible = true
		drag_grid_ghost.position = Vector2(
			target_x * grid_step,
			target_y * grid_step
		)
		
		# Color feedback
		var sb = drag_grid_ghost.get_theme_stylebox("panel")
		if current_drop_valid:
			sb.bg_color = COLOR_VALID_DROP
		else:
			sb.bg_color = COLOR_INVALID_DROP
			
	else:
		drag_grid_ghost.visible = false
		current_drop_pos = Vector2i(-1, -1)
		current_drop_valid = false

func _end_drag():
	if not is_dragging: return
	
	# Execute Move
	if current_hover_grid and current_drop_valid and current_drop_pos.x >= 0:
		var target_inv = null
		if current_hover_grid == player_grid: target_inv = inventory_component
		elif current_hover_grid == container_grid: target_inv = current_container.inventory
		
		var source_inv = _get_inventory_from_source(drag_source)
		
		if target_inv and source_inv:
			# Logic: If moving within same inventory
			if source_inv == target_inv:
				source_inv.move_item(dragged_item, current_drop_pos.x, current_drop_pos.y)
			else:
				# Moving between inventories
				if source_inv.remove_item(dragged_item):
					if not target_inv.place_item(dragged_item, current_drop_pos.x, current_drop_pos.y):
						# Rollback if failed (shouldn't happen if validation was correct)
						source_inv.add_item(dragged_item)
	
	_cancel_drag()
	refresh_display()

func _cancel_drag():
	is_dragging = false
	dragged_item = null
	drag_source = ""
	current_drop_pos = Vector2i(-1, -1)
	
	if drag_floating_icon:
		drag_floating_icon.queue_free()
		drag_floating_icon = null
		
	if drag_grid_ghost:
		drag_grid_ghost.visible = false
		if drag_grid_ghost.get_parent():
			drag_grid_ghost.get_parent().remove_child(drag_grid_ghost)
		# Add back to main tree so it isn't deleted if grid refreshes
		add_child(drag_grid_ghost)

func _get_inventory_from_source(source: String) -> InventoryComponent:
	match source:
		"player": return inventory_component
		"container": return current_container.inventory if current_container else null
	return null

# Context menu & Equipment handling (Kept mostly the same, just ensured drag interaction)

func _on_equipment_slot_input(event: InputEvent, slot_name: String):
	if not inventory_component: return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if is_dragging and dragged_item:
			var source_inv = _get_inventory_from_source(drag_source)
			if source_inv and dragged_item.equip_slot == slot_name:
				source_inv.remove_item(dragged_item)
				inventory_component.equip_item(dragged_item, slot_name)
				_cancel_drag()
				refresh_display()
		else:
			var item = inventory_component.equipment_slots.get(slot_name)
			if item:
				if inventory_component.unequip_item(slot_name):
					refresh_display()

func _show_context_menu(item: InventoryItem, source: String, mouse_pos: Vector2):
	context_menu_item = item
	context_menu_source = source
	context_menu.clear()
	match item.type:
		"consumable": context_menu.add_item("Use", 0)
		"weapon", "armor": if source == "player": context_menu.add_item("Equip", 1)
	if item.equip_slot != "none":
		var equipped = inventory_component.equipment_slots.get(item.equip_slot)
		if equipped == item: context_menu.add_item("Unequip", 2)
	if item.stackable and item.stack_count > 1:
		context_menu.add_separator()
		context_menu.add_item("Split Stack", 3)
	context_menu.add_separator()
	context_menu.add_item("Drop", 4)
	context_menu.add_item("Examine", 5)
	context_menu.position = mouse_pos
	context_menu.popup()

func _on_context_menu_item_selected(id: int):
	if not context_menu_item: return
	var inv = _get_inventory_from_source(context_menu_source)
	if not inv: return
	match id:
		0: _use_item(context_menu_item)
		1: 
			if context_menu_item.equip_slot != "none":
				inv.remove_item(context_menu_item)
				inventory_component.equip_item(context_menu_item, context_menu_item.equip_slot)
		2: inventory_component.unequip_item(context_menu_item.equip_slot)
		3: _split_stack(context_menu_item, inv)
		4: inv.remove_item(context_menu_item)
		5: _examine_item(context_menu_item)
	refresh_display()

func _use_item(item: InventoryItem):
	item_used.emit(item)
	match item.type:
		"consumable":
			if item.stackable:
				item.stack_count -= 1
				if item.stack_count <= 0: inventory_component.remove_item(item)
			else: inventory_component.remove_item(item)

func _split_stack(item: InventoryItem, inv: InventoryComponent):
	if not item.stackable or item.stack_count <= 1: return
	var split_amount = int(item.stack_count / 2)
	var new_item = inv.split_stack(item, split_amount)
	if new_item:
		var pos = inv.find_free_space(new_item)
		if pos.x >= 0: inv.place_item(new_item, pos.x, pos.y)

func _examine_item(item: InventoryItem):
	print("Examining: ", item.display_name, " - ", item.description)

func _on_item_mouse_entered(item: InventoryItem): _show_tooltip(item)
func _on_item_mouse_exited(): _hide_tooltip()
func _show_tooltip(item: InventoryItem):
	if is_dragging: return
	tooltip_item_name.text = item.display_name
	tooltip_description.text = item.description
	var stats_text = "Type: " + item.type.capitalize() + "\nWeight: %.2f\n" % item.weight
	if item.stackable: stats_text += "Stack: %d/%d\n" % [item.stack_count, item.max_stack]
	if item.attributes.size() > 0:
		stats_text += "\nAttributes:\n"
		for key in item.attributes.keys(): stats_text += "  %s: %s\n" % [key, str(item.attributes[key])]
	tooltip_stats.text = stats_text
	tooltip.visible = true
	_update_tooltip_position()
func _hide_tooltip(): tooltip.visible = false
func _update_tooltip_position(): if tooltip.visible: tooltip.position = get_global_mouse_position() + TOOLTIP_OFFSET
func _process(_delta): if tooltip.visible: _update_tooltip_position()
func _on_auto_organize_pressed(): if inventory_component: inventory_component.auto_organize(); refresh_display()
func _on_close_pressed(): close_inventory()
func _on_loot_all_pressed(): if current_container and inventory_component: current_container.loot_all(inventory_component); refresh_display()
func _on_close_container_pressed(): close_container()
