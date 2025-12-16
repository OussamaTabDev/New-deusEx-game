class_name InventoryUI extends Control

## UI for Deus Ex-style grid-based inventory system
## Features: Anchored dragging, Grid Snapping, Valid/Invalid visual feedback, Merging, Rotation, Quick Transfer

signal ui_closed()
signal item_used(item: InventoryItem)
signal container_closed()

@export var cell_size := 64
@export var CELL_SPACING: int = 2
const GRID_PADDING = 10
const TOOLTIP_OFFSET = Vector2(15, 15)

# --- CONFIGURATION ---
@export var hotbar_always_visible: bool = true

const COLOR_VALID_DROP = Color(0.2, 0.8, 0.2, 0.5) # Green
const COLOR_INVALID_DROP = Color(0.8, 0.2, 0.2, 0.5) # Red
const COLOR_MERGE_DROP = Color(0.2, 0.5, 0.8, 0.5) # Blue for merge/swap
const COLOR_GAMEPAD_CURSOR = Color(1.0, 0.8, 0.2, 0.4) # Gold highlight for controller

@onready var background: ColorRect = $Background
@onready var main_container: MarginContainer = $MarginContainer # Wraps grids and equipment
@onready var player_grid: Control = $MarginContainer/HBoxContainer/PlayerPanel/VBoxContainer/PlayerGrid
@onready var container_grid: Control = $MarginContainer/HBoxContainer/ContainerPanel/VBoxContainer/ContainerGrid
@onready var equipment_panel: PanelContainer = $MarginContainer/HBoxContainer/EquipmentPanel
@onready var container_panel: PanelContainer = $MarginContainer/HBoxContainer/ContainerPanel

@onready var hotbar_panel: PanelContainer = $"../BottomPanel/PanelContainer"
@onready var hotbar_container: HBoxContainer = $"../BottomPanel/PanelContainer/VBoxContainer/Hotbar"

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
var original_orientation: Vector2i = Vector2i.ZERO # Stores original width/height if rotation is cancelled

# Advanced Drag State
var drag_floating_icon: Control = null
var drag_grid_ghost: Control = null
var drag_anchor_offset: Vector2i = Vector2i.ZERO
var current_hover_grid: Control = null
var current_drop_valid: bool = false
var current_drop_pos: Vector2i = Vector2i(-1, -1)
var current_hover_item: InventoryItem = null # The item we are hovering over (for merge/swap)

# Grid visual state
var player_grid_cells: Array[Panel] = []
var container_grid_cells: Array[Panel] = []
var equipment_slots: Dictionary = {}
var hotbar_slots: Array[Panel] = []
var item_visuals: Dictionary = {}

var context_menu_item: InventoryItem = null
var context_menu_source: String = ""

# --- CONTROLLER SUPPORT ---
var is_controller_mode: bool = false
var gamepad_cursor_pos: Vector2i = Vector2i(0, 0)
var gamepad_active_panel: String = "player" # "player", "container", "hotbar"
var gamepad_cursor_visual: Panel = null
var last_input_time: int = 0
const INPUT_DELAY_MS: int = 150 # Prevent super fast scrolling

func _ready():
    # Visibility initialization
    # visible = false # Always true so hotbar can show
    # main_container.visible = false
    # background.visible = false
    hide()
    # Connect Buttons
    auto_organize_btn.pressed.connect(_on_auto_organize_pressed)
    close_btn.pressed.connect(_on_close_pressed)
    loot_all_btn.pressed.connect(_on_loot_all_pressed)
    close_container_btn.pressed.connect(_on_close_container_pressed)
    
    # Context Menu
    context_menu.id_pressed.connect(_on_context_menu_item_selected)
    context_menu.add_item("Use", 0)
    context_menu.add_item("Equip", 1)
    context_menu.add_item("Unequip", 2)
    context_menu.add_separator()
    context_menu.add_item("Split Stack", 3)
    context_menu.add_separator()
    context_menu.add_item("Drop", 4)
    context_menu.add_item("Examine", 5)
    
    _initialize_player_grid()
    _initialize_equipment_slots()
    _initialize_hotbar()

    # Ghost for dragging
    drag_grid_ghost = Panel.new()
    drag_grid_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var style = StyleBoxFlat.new()
    style.set_corner_radius_all(4)
    drag_grid_ghost.add_theme_stylebox_override("panel", style)
    drag_grid_ghost.visible = false
    add_child(drag_grid_ghost) 

    # Cursor for Controller
    gamepad_cursor_visual = Panel.new()
    gamepad_cursor_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var cursor_style = StyleBoxFlat.new()
    cursor_style.bg_color = COLOR_GAMEPAD_CURSOR
    cursor_style.border_color = Color.WHITE
    cursor_style.set_border_width_all(2)
    gamepad_cursor_visual.add_theme_stylebox_override("panel", cursor_style)
    gamepad_cursor_visual.visible = false
    add_child(gamepad_cursor_visual)

    refresh_display()

func _initialize_player_grid():
    if not inventory_component: return
    
    var total_width = inventory_component.grid_columns * cell_size + max(0, inventory_component.grid_columns - 1) * CELL_SPACING
    var total_height = inventory_component.grid_rows * cell_size + max(0, inventory_component.grid_rows - 1) * CELL_SPACING
    player_grid.custom_minimum_size = Vector2(total_width, total_height)
    
    player_grid_cells.clear()
    for y in range(inventory_component.grid_rows):
        for x in range(inventory_component.grid_columns):
            var cell = Panel.new()
            cell.custom_minimum_size = Vector2(cell_size, cell_size)
            cell.size = Vector2(cell_size, cell_size)
            cell.position = Vector2(x * (cell_size + CELL_SPACING), y * (cell_size + CELL_SPACING))
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
    for i in range(inventory_component.hotbar_slots):
        var slot = Panel.new()
        slot.custom_minimum_size = Vector2(cell_size, cell_size)
        var style = StyleBoxFlat.new()
        style.bg_color = Color(0.15, 0.15, 0.15, 0.8)
        style.border_color = Color(0.5, 0.5, 0.5)
        style.set_border_width_all(2)
        slot.add_theme_stylebox_override("panel", style)
        
        var label = Label.new()
        label.text = str((i + 1) % 10)
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        slot.add_child(label)
        
        # --- FIX: Connect Input AND Hover signals ---
        slot.gui_input.connect(_on_hotbar_slot_input.bind(i))
        
        # This enables the "Examine" debug tooltip when hovering
        slot.mouse_entered.connect(func(): 
            if inventory_component.hotbar[i]: 
                _on_item_mouse_entered(inventory_component.hotbar[i])
        )
        slot.mouse_exited.connect(_on_item_mouse_exited)
        # ---------------------------------------------
        
        hotbar_container.add_child(slot)
        hotbar_slots.append(slot)
    
    hotbar_container.get_node("../Label").text = "Hotbar [1-%s]" % (inventory_component.hotbar_slots % 10)

func _initialize_container_grid(container: ContainerComponent):
    for cell in container_grid_cells: cell.queue_free()
    container_grid_cells.clear()
    
    var total_width = container.inventory.grid_columns * cell_size + max(0, container.inventory.grid_columns - 1) * CELL_SPACING
    var total_height = container.inventory.grid_rows * cell_size + max(0, container.inventory.grid_rows - 1) * CELL_SPACING
    container_grid.custom_minimum_size = Vector2(total_width, total_height)
    
    for y in range(container.inventory.grid_rows):
        for x in range(container.inventory.grid_columns):
            var cell = Panel.new()
            cell.custom_minimum_size = Vector2(cell_size, cell_size)
            cell.position = Vector2(x * (cell_size + CELL_SPACING), y * (cell_size + CELL_SPACING))
            cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
            var style = StyleBoxFlat.new()
            style.bg_color = Color(0.2, 0.2, 0.25, 0.5)
            style.border_color = Color(0.4, 0.4, 0.5)
            style.set_border_width_all(1)
            cell.add_theme_stylebox_override("panel", style)
            container_grid.add_child(cell)
            container_grid_cells.append(cell)

func open_inventory():
    # We don't toggle 'visible' because that hides the hotbar. 
    # We toggle the main container and background.
    main_container.visible = true
    background.visible = true
    hotbar_panel.visible = true
    show()
    refresh_display()

func close_inventory():
    # main_container.visible = false
    # background.visible = false
    hide()
    gamepad_cursor_visual.visible = false
    if current_container: close_container()
    
    # visible = false
    if not hotbar_always_visible:
        hotbar_panel.visible = false
    ui_closed.emit()

func is_inventory_open() -> bool:
    return main_container.visible

func open_container(container: ContainerComponent):
    current_container = container
    container_panel.visible = true
    _initialize_container_grid(container)
    refresh_display()
    
    # Auto-focus container when opening with controller
    if is_controller_mode:
        gamepad_active_panel = "container"
        gamepad_cursor_pos = Vector2i(0, 0)
        _update_gamepad_cursor()

func close_container():
    if current_container:
        current_container.close()
        current_container = null
    container_panel.visible = false
    container_closed.emit()
    
    if gamepad_active_panel == "container":
        gamepad_active_panel = "player"

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
        if is_instance_valid(visual): visual.queue_free()
    item_visuals.clear()

func _display_inventory_items(inv: InventoryComponent, grid: Control, source: String):
    var items = inv.get_all_items()
    for item in items:
        if is_dragging and item == dragged_item: continue
        if item.grid_x >= 0 and item.grid_y >= 0:
            var visual = _create_item_visual(item, source)
            visual.position = Vector2(item.grid_x * (cell_size + CELL_SPACING), item.grid_y * (cell_size + CELL_SPACING))
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
            if is_dragging and item == dragged_item: continue
            var visual = TextureRect.new()
            visual.texture = item.icon
            visual.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
            visual.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
            visual.custom_minimum_size = Vector2(cell_size - 8, cell_size - 8)
            visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
            visual.position = Vector2(4, 4)
            slot_panel.add_child(visual)

func _display_hotbar_items():
    if not inventory_component: return
    for i in range(hotbar_slots.size()):
        var slot = hotbar_slots[i]
        # Safety check if hotbar array is smaller than slots
        if i >= inventory_component.hotbar.size(): break
        
        var item = inventory_component.hotbar[i]
        for child in slot.get_children():
            if child is TextureRect: child.queue_free()
            
        if item and item.icon:
            var visual = TextureRect.new()
            visual.texture = item.icon
            visual.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
            visual.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
            visual.custom_minimum_size = Vector2(cell_size - 8, cell_size - 8)
            visual.size = Vector2(cell_size - 8, cell_size - 8)
            visual.position = Vector2(4, 4)
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
                count_label.anchor_right = 1.0
                count_label.anchor_bottom = 1.0
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
    texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    texture_rect.anchor_right = 1.0
    texture_rect.anchor_bottom = 1.0
    item_node.add_child(texture_rect)

    texture_rect.mouse_filter = Control.MOUSE_FILTER_STOP
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

# --- ADVANCED DRAG AND DROP & INPUT ---

func _input(event):
    if not visible: return
    
    # Hotkey assignment: 1-9, 0 to assign hovered item to hotbar slot
    if event is InputEventKey and event.pressed and not is_dragging:
        var hotbar_index = -1
        match event.keycode:
            KEY_1: hotbar_index = 0
            KEY_2: hotbar_index = 1
            KEY_3: hotbar_index = 2
            KEY_4: hotbar_index = 3
            KEY_5: hotbar_index = 4
            KEY_6: hotbar_index = 5
            KEY_7: hotbar_index = 6
            KEY_8: hotbar_index = 7
            KEY_9: hotbar_index = 8
            KEY_0: hotbar_index = 9  # Maps to 10th slot (index 9)

        if hotbar_index >= 0 and hotbar_index < inventory_component.hotbar_slots:
            var hovered_item = _get_hovered_item_under_mouse()
            if hovered_item and _can_assign_to_hotbar(hovered_item):
                # Clear any previous instance of this item in hotbar
                for i in range(inventory_component.hotbar.size()):
                    if inventory_component.hotbar[i] == hovered_item:
                        inventory_component.hotbar[i] = null

                # Assign to new slot
                inventory_component.hotbar[hotbar_index] = hovered_item
                refresh_display()
                get_viewport().set_input_as_handled()
                
    # Switch to controller mode on input
    if event is InputEventJoypadButton or event is InputEventJoypadMotion:
        if not is_controller_mode:
            is_controller_mode = true
            gamepad_cursor_visual.visible = is_inventory_open()
    elif event is InputEventMouse:
        if is_controller_mode:
            is_controller_mode = false
            gamepad_cursor_visual.visible = false

    # Controller Logic Handler
    if is_controller_mode and is_inventory_open():
        _handle_controller_input(event)
        return # Skip mouse logic if using controller

    # Mouse Logic
    if event.is_action_pressed("ui_cancel"):
        if is_dragging:
            _cancel_drag()
        else:
            close_inventory()
        get_viewport().set_input_as_handled()
        
    # Rotate Item with 'R'
    if is_dragging and event is InputEventKey:
        if event.pressed and event.keycode == KEY_R:
            _rotate_dragged_item()
    
    if is_dragging:
        if event is InputEventMouseMotion:
            _process_drag_motion()
        if event is InputEventMouseButton:
            if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
                _end_drag()

func _get_hovered_item_under_mouse() -> InventoryItem:
    if not is_inventory_open():
        return null
    var mouse_pos = get_global_mouse_position()
    # Check player grid
    if player_grid.get_global_rect().has_point(mouse_pos):
        var local = player_grid.get_global_transform().affine_inverse() * mouse_pos
        var col = int(local.x / (cell_size + CELL_SPACING))
        var row = int(local.y / (cell_size + CELL_SPACING))
        return inventory_component.get_item_at(col, row)
    # Check container grid
    if current_container and container_grid.get_global_rect().has_point(mouse_pos):
        var local = container_grid.get_global_transform().affine_inverse() * mouse_pos
        var col = int(local.x / (cell_size + CELL_SPACING))
        var row = int(local.y / (cell_size + CELL_SPACING))
        return current_container.inventory.get_item_at(col, row)
    return null

func _can_assign_to_hotbar(item: InventoryItem) -> bool:
    print("item:" , item.display_name , " , type :" , item.type)
    return item.type in ["weapon", "medkit", "tool"]

func _handle_controller_input(event):
    var current_time = Time.get_ticks_msec()
    if current_time - last_input_time < INPUT_DELAY_MS:
        if event is InputEventJoypadMotion: return 
    
    var moved = false
    var direction = Vector2i.ZERO
    
    # 1. Navigation Direction
    if event.is_action_pressed("ui_right"):
        direction = Vector2i.RIGHT
    elif event.is_action_pressed("ui_left"):
        direction = Vector2i.LEFT
    elif event.is_action_pressed("ui_down"):
        direction = Vector2i.DOWN
    elif event.is_action_pressed("ui_up"):
        direction = Vector2i.UP
        
    if direction != Vector2i.ZERO:
        _move_smart_cursor(direction)
        moved = true

    # 2. Panel Switching (Back/Select button)
    if event.is_action_pressed("ui_focus_next"): 
        _cycle_gamepad_panel()
        moved = true

    if moved:
        last_input_time = current_time
        # _clamp_gamepad_cursor() # Removed: handled inside _move_smart_cursor now
        _update_gamepad_cursor()
        
        if is_dragging:
             # Simulate drag motion with cursor
            drag_floating_icon.global_position = gamepad_cursor_visual.global_position
            _process_drag_motion_logic(gamepad_cursor_visual.global_position)

    # 3. Actions (Pick up / Drop / Rotate etc...)
    if event.is_action_pressed("ui_accept"): 
        if is_dragging: _end_drag()
        else: _gamepad_pick_up()
            
    elif event.is_action_pressed("ui_select"): 
        if not is_dragging:
            var item = _get_item_at_cursor()
            if item: _quick_transfer(item, _get_source_from_panel(gamepad_active_panel))
            
    elif event.is_action_pressed("ui_cancel"):
        if is_dragging: _cancel_drag()
        else: close_inventory()

    elif event.is_action_pressed("ui_focus_prev"): 
        if is_dragging: _rotate_dragged_item()

func _cycle_gamepad_panel():
    match gamepad_active_panel:
        "player":
            if current_container: gamepad_active_panel = "container"
            else: gamepad_active_panel = "hotbar"
        "container":
            gamepad_active_panel = "player"
        "hotbar":
            gamepad_active_panel = "player"
    
    gamepad_cursor_pos = Vector2i(0, 0) # Reset to top-left of new panel

func _clamp_gamepad_cursor():
    var limit_x = 0
    var limit_y = 0
    
    match gamepad_active_panel:
        "player":
            if inventory_component:
                limit_x = inventory_component.grid_columns - 1
                limit_y = inventory_component.grid_rows - 1
        "container":
            if current_container:
                limit_x = current_container.inventory.grid_columns - 1
                limit_y = current_container.inventory.grid_rows - 1
        "hotbar":
            limit_x = 7 # 0-7 for 8 slots
            limit_y = 0

    gamepad_cursor_pos.x = clamp(gamepad_cursor_pos.x, 0, limit_x)
    gamepad_cursor_pos.y = clamp(gamepad_cursor_pos.y, 0, limit_y)

func _move_smart_cursor(dir: Vector2i):
    # Hotbar is simple 1D array, keep standard movement
    if gamepad_active_panel == "hotbar":
        gamepad_cursor_pos.x += dir.x
        _clamp_gamepad_cursor() # Helper from original code
        return

    # Get the grid dimensions based on active panel
    var max_x = 0
    var max_y = 0
    var active_inv: InventoryComponent = null
    
    if gamepad_active_panel == "player":
        active_inv = inventory_component
        max_x = inventory_component.grid_columns
        max_y = inventory_component.grid_rows
    elif gamepad_active_panel == "container" and current_container:
        active_inv = current_container.inventory
        max_x = current_container.inventory.grid_columns
        max_y = current_container.inventory.grid_rows
    
    if active_inv == null: return

    # --- STEP 1: CALCULATE START POINT ---
    # If we are on an item, we want to move from its EDGE, not the cursor position.
    var current_item = active_inv.get_item_at(gamepad_cursor_pos.x, gamepad_cursor_pos.y)
    
    var start_x = gamepad_cursor_pos.x
    var start_y = gamepad_cursor_pos.y
    
    # Only skip over the current item if we are NOT dragging.
    # If dragging, we often want precise placement next to the item.
    if current_item and not is_dragging:
        if dir == Vector2i.RIGHT:
            # Start from the rightmost edge of the item
            start_x = current_item.grid_x + current_item.width - 1
        elif dir == Vector2i.DOWN:
            # Start from the bottom edge
            start_y = current_item.grid_y + current_item.height - 1
        elif dir == Vector2i.LEFT:
            start_x = current_item.grid_x
        elif dir == Vector2i.UP:
            start_y = current_item.grid_y

    # --- STEP 2: APPLY MOVEMENT ---
    var target_x = start_x + dir.x
    var target_y = start_y + dir.y

    # Clamp to grid boundaries
    target_x = clamp(target_x, 0, max_x - 1)
    target_y = clamp(target_y, 0, max_y - 1)
    
    # --- STEP 3: SNAP TO TARGET ITEM (Navigation Only) ---
    # If we landed on a NEW item, snap cursor to its Top-Left (Anchor) 
    # so we select the whole "pack", not just a random cell inside it.
    if not is_dragging:
        var target_item = active_inv.get_item_at(target_x, target_y)
        if target_item:
            # We hit an item! Snap to its origin.
            target_x = target_item.grid_x
            target_y = target_item.grid_y

    gamepad_cursor_pos = Vector2i(target_x, target_y)

func _update_gamepad_cursor():
    var target_parent = null
    var local_pos = Vector2.ZERO
    var cell_w = cell_size + CELL_SPACING
    
    match gamepad_active_panel:
        "player":
            target_parent = player_grid
            local_pos = Vector2(gamepad_cursor_pos.x * cell_w, gamepad_cursor_pos.y * cell_w)
        "container":
            target_parent = container_grid
            local_pos = Vector2(gamepad_cursor_pos.x * cell_w, gamepad_cursor_pos.y * cell_w)
        "hotbar":
            target_parent = hotbar_container.get_child(gamepad_cursor_pos.x)
            local_pos = Vector2.ZERO # Local to the slot

    if target_parent:
        if gamepad_cursor_visual.get_parent() != target_parent:
            gamepad_cursor_visual.get_parent().remove_child(gamepad_cursor_visual)
            target_parent.add_child(gamepad_cursor_visual)
        
        gamepad_cursor_visual.visible = true
        
        # --- NEW VISUAL LOGIC ---
        var current_w = cell_size
        var current_h = cell_size
        
        # If hovering an item (and not dragging), resize cursor to fit the item
        if not is_dragging and (gamepad_active_panel == "player" or gamepad_active_panel == "container"):
            var item = _get_item_at_cursor()
            if item:
                current_w = item.width * cell_size + max(0, item.width - 1) * CELL_SPACING
                current_h = item.height * cell_size + max(0, item.height - 1) * CELL_SPACING
        
        gamepad_cursor_visual.size = Vector2(current_w, current_h)
        # ------------------------
        
        gamepad_cursor_visual.position = local_pos
        gamepad_cursor_visual.move_to_front()

func _gamepad_pick_up():
    var item = _get_item_at_cursor()
    if item:
        _start_drag(item, _get_source_from_panel(gamepad_active_panel))

func _get_item_at_cursor() -> InventoryItem:
    match gamepad_active_panel:
        "player":
            return inventory_component.get_item_at(gamepad_cursor_pos.x, gamepad_cursor_pos.y)
        "container":
            if current_container:
                return current_container.inventory.get_item_at(gamepad_cursor_pos.x, gamepad_cursor_pos.y)
        "hotbar":
            if gamepad_cursor_pos.x < inventory_component.hotbar.size():
                return inventory_component.hotbar[gamepad_cursor_pos.x]
    return null

func _get_source_from_panel(panel_name: String) -> String:
    match panel_name:
        "player": return "player"
        "container": return "container"
        "hotbar": return "hotbar" # Treat as player for logic, but tracked separately
    return "player"

# --- HOTBAR INPUT ---

func _on_hotbar_slot_input(event: InputEvent, index: int):
    if event is InputEventMouseButton:
        # [FIX] RIGHT CLICK: Remove item instantly
        if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
            if not is_dragging:
                inventory_component.hotbar[index] = null
                refresh_display()
                # Optional: Hide tooltip since item is gone
                _hide_tooltip()

        # [FIX] LEFT CLICK: Drag logic
        elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
            if is_dragging:
                # If holding an item, try to DROP it here
                _attempt_drop_to_hotbar(index)
            else:
                # If NOT holding, PICK IT UP (Start Dragging)
                var item = inventory_component.hotbar[index]
                if item:
                    # 1. Clear the slot (so we can move it or drop it in void to remove)
                    inventory_component.hotbar[index] = null
                    refresh_display()
                    
                    # 2. ACTUALLY Start the drag (This was missing before!)
                    _start_drag(item, "hotbar")

func _attempt_drop_to_hotbar(index: int):
    if not dragged_item: return
    
    # RESTRICTION: Check if item is allowed (e.g. no ammo)
    if not _can_equip_to_hotbar(dragged_item):
        return

    # [FIX] NO DUPLICATE LOGIC
    # Loop through all hotbar slots. If we find this item, clear it.
    for i in range(inventory_component.hotbar.size()):
        if inventory_component.hotbar[i] == dragged_item:
            inventory_component.hotbar[i] = null

    # Assign to the new slot
    inventory_component.hotbar[index] = dragged_item
    
    # Stop dragging (Success)
    _cancel_drag(true) 
    refresh_display()

func _can_equip_to_hotbar(item: InventoryItem) -> bool:
    if item.type == "ammo": return false
    if item.type == "misc": return false # Assuming 'misc' is useless
    if item.type == "junk": return false
    return true

# --- EXISTING MOUSE INPUT LOGIC ---

func _on_item_gui_input(event: InputEvent, item: InventoryItem, source: String):
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed:
                # Quick Transfer (Ctrl + Click)
                if Input.is_key_pressed(KEY_CTRL):
                    _quick_transfer(item, source)
                else:
                    _start_drag(item, source)
        elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
            if not is_dragging:
                _show_context_menu(item, source, get_global_mouse_position())
        get_viewport().set_input_as_handled() 

func _quick_transfer(item: InventoryItem, source: String):
    var source_inv = _get_inventory_from_source(source)
    var target_inv = null
    
    if source == "player":
        if current_container: target_inv = current_container.inventory
    elif source == "container":
        target_inv = inventory_component
        
    if source_inv and target_inv:
        source_inv.transfer_item(item, target_inv)
        refresh_display()

func _start_drag(item: InventoryItem, source: String):
    dragged_item = item
    drag_source = source
    is_dragging = true
    original_orientation = Vector2i(item.width, item.height) # Save original shape
    
    var item_visual = item_visuals.get(item)
    if item_visual:
        var local_click_pos = item_visual.get_local_mouse_position()
        var col = int(local_click_pos.x / (cell_size + CELL_SPACING))
        var row = int(local_click_pos.y / (cell_size + CELL_SPACING))
        drag_anchor_offset = Vector2i(clamp(col, 0, item.width - 1), clamp(row, 0, item.height - 1))
    else:
        drag_anchor_offset = Vector2i(0, 0)
    
    # Create Floating Icon
    drag_floating_icon = TextureRect.new()
    drag_floating_icon.z_index = 2
    drag_floating_icon.texture = item.icon
    drag_floating_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    drag_floating_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    
    # Set size based on current dimensions
    var dims = Vector2(item.width * cell_size, item.height * cell_size)
    drag_floating_icon.custom_minimum_size = dims
    drag_floating_icon.size = dims
    # Set pivot to center for nice rotation
    drag_floating_icon.pivot_offset = dims / 2.0
    
    drag_floating_icon.modulate = Color(1, 1, 1, 0.8)
    drag_floating_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    
    _update_floating_icon_offset()
    add_child(drag_floating_icon)
    
    if item_visual: item_visual.visible = false
    
    if is_controller_mode:
        _update_gamepad_drag_visual()
        # drag_floating_icon.global_position = gamepad_cursor_visual.global_position
        _process_drag_motion_logic(gamepad_cursor_visual.global_position)
    else:
        _process_drag_motion()

func _update_gamepad_drag_visual():
    if not drag_floating_icon or not gamepad_cursor_visual: return
    
    # 1. Get Global Center of the Cursor Cell (The 1x1 yellow box)
    var cursor_center = gamepad_cursor_visual.global_position + (gamepad_cursor_visual.size / 2.0)
    
    # 2. Position the Drag Icon so its CENTER is exactly on the Cursor Center
    # This ensures that even for 2x2 items, the "crosshair" is on your cursor.
    drag_floating_icon.global_position = cursor_center - (drag_floating_icon.size / 2.0)

func _update_floating_icon_offset():
    # Recalculates center based on the anchor and CURRENT dimensions (handling rotation)
    drag_floating_icon.set_meta("center_offset", Vector2(
        (drag_anchor_offset.x * (cell_size + CELL_SPACING)) + (cell_size / 2.0),
        (drag_anchor_offset.y * (cell_size + CELL_SPACING)) + (cell_size / 2.0)
    ))

func _rotate_dragged_item():
    if not dragged_item: return
    
    # Swap dimensions logic
    var old_w = dragged_item.width
    dragged_item.width = dragged_item.height
    dragged_item.height = old_w
    
    # Swap anchor offset to keep mouse relative pos valid
    var old_anchor_x = drag_anchor_offset.x
    drag_anchor_offset.x = drag_anchor_offset.y
    drag_anchor_offset.y = old_anchor_x
    
    # Update visuals (Actually rotate the node visually)
    var dims = Vector2(dragged_item.width * cell_size, dragged_item.height * cell_size)
    drag_floating_icon.custom_minimum_size = dims
    drag_floating_icon.size = dims
    drag_floating_icon.pivot_offset = dims / 2.0
    
    _update_floating_icon_offset()
    
    if is_controller_mode:
        _process_drag_motion_logic(gamepad_cursor_visual.global_position)
    else:
        _process_drag_motion()

func _process_drag_motion():
    if not drag_floating_icon: return
    var global_mouse = get_global_mouse_position()
    
    var offset = drag_floating_icon.get_meta("center_offset")
    drag_floating_icon.global_position = global_mouse - offset
    
    _process_drag_motion_logic(global_mouse)

func _process_drag_motion_logic(pointer_global_pos: Vector2):
    current_hover_grid = null
    var inv_to_check: InventoryComponent = null
    
    # Check grids
    if player_grid.get_global_rect().has_point(pointer_global_pos):
        current_hover_grid = player_grid
        inv_to_check = inventory_component
    elif current_container and container_grid.get_global_rect().has_point(pointer_global_pos):
        current_hover_grid = container_grid
        inv_to_check = current_container.inventory
        
    # Check Hotbar for Drop
    if not current_hover_grid:
         for i in range(hotbar_slots.size()):
            if hotbar_slots[i].get_global_rect().has_point(pointer_global_pos):
                # We can drop here, but we don't show the grid ghost
                # Maybe show a highlight on the slot
                drag_grid_ghost.visible = false
                current_drop_valid = _can_equip_to_hotbar(dragged_item)
                return

    if current_hover_grid and inv_to_check:
        var local_pos = current_hover_grid.get_global_transform().affine_inverse() * pointer_global_pos
        var grid_step = cell_size + CELL_SPACING
        var raw_x = int(local_pos.x / grid_step)
        var raw_y = int(local_pos.y / grid_step)
        
        # If Controller, snap exactly
        if is_controller_mode:
            raw_x = gamepad_cursor_pos.x
            raw_y = gamepad_cursor_pos.y

        var target_x = raw_x - drag_anchor_offset.x
        var target_y = raw_y - drag_anchor_offset.y
        
        current_drop_pos = Vector2i(target_x, target_y)
        
        # Check for merging or swapping
        current_hover_item = inv_to_check.get_item_at(raw_x, raw_y)
        
        # Standard placement check
        var fits = inv_to_check.can_place_item(dragged_item, target_x, target_y, dragged_item)
        
        # Merge check: Only if exactly 1 item is under mouse and it matches
        var can_merge = false
        if current_hover_item and current_hover_item != dragged_item:
            if current_hover_item.id == dragged_item.id and current_hover_item.stackable:
                can_merge = true
        
        current_drop_valid = fits or can_merge
        
        # Update Ghost
        drag_grid_ghost.get_parent().remove_child(drag_grid_ghost)
        current_hover_grid.add_child(drag_grid_ghost)
        drag_grid_ghost.visible = true
        drag_grid_ghost.size = Vector2(dragged_item.width * cell_size + CELL_SPACING * (dragged_item.width - 1), dragged_item.height * cell_size + CELL_SPACING * (dragged_item.height - 1))
        
        if can_merge:
            # Snap to the target item we are merging into
            drag_grid_ghost.position = Vector2(current_hover_item.grid_x * grid_step, current_hover_item.grid_y * grid_step)
            drag_grid_ghost.size = Vector2(current_hover_item.width * cell_size, current_hover_item.height * cell_size)
            drag_grid_ghost.get_theme_stylebox("panel").bg_color = COLOR_MERGE_DROP
        else:
            drag_grid_ghost.position = Vector2(target_x * grid_step, target_y * grid_step)
            drag_grid_ghost.get_theme_stylebox("panel").bg_color = COLOR_VALID_DROP if fits else COLOR_INVALID_DROP
            
    else:
        drag_grid_ghost.visible = false
        current_drop_pos = Vector2i(-1, -1)
        current_drop_valid = false

func _end_drag():
    if not is_dragging: return
    var success = false
    var pointer_pos = gamepad_cursor_visual.global_position if is_controller_mode else get_global_mouse_position()

    # 1. Hotbar Drop Logic
    for i in range(hotbar_slots.size()):
        if hotbar_slots[i].get_global_rect().has_point(pointer_pos):
            _attempt_drop_to_hotbar(i)
            return  # _attempt_drop_to_hotbar handles cancel & refresh

    # 2. Grid Drop Logic (Player or Container)
    if current_hover_grid and current_drop_valid:
        var target_inv = null
        if current_hover_grid == player_grid:
            target_inv = inventory_component
        elif current_hover_grid == container_grid:
            target_inv = current_container.inventory if current_container else null

        var source_inv = _get_inventory_from_source(drag_source)
        if target_inv and source_inv:
            var raw_x = current_drop_pos.x + drag_anchor_offset.x
            var raw_y = current_drop_pos.y + drag_anchor_offset.y
            var item_under_mouse = target_inv.get_item_at(raw_x, raw_y)

            # Merge Logic
            if item_under_mouse and item_under_mouse != dragged_item and \
               item_under_mouse.id == dragged_item.id and dragged_item.stackable:
                success = target_inv.try_merge_stack(dragged_item, item_under_mouse)

            # Same-inventory move
            elif source_inv == target_inv:
                success = source_inv.move_item(dragged_item, current_drop_pos.x, current_drop_pos.y)

            # Cross-inventory move
            else:
                if source_inv.remove_item(dragged_item):
                    if target_inv.place_item(dragged_item, current_drop_pos.x, current_drop_pos.y):
                        success = true
                    else:
                        # Rollback on failure
                        source_inv.add_item(dragged_item)
                        success = false

    # 3. DROP ITEM FROM INVENTORY IF RELEASED OUTSIDE VALID AREAS

    if not success:
        var source_inv = _get_inventory_from_source(drag_source)
        if source_inv:
            var item_to_drop = dragged_item
            var drop_source = drag_source
            source_inv.remove_item(item_to_drop)
            source_inv.drop_item(item_to_drop, drop_source) 
            success = true

    _cancel_drag(success)
    refresh_display()

func _cancel_drag(success: bool = false):
    # CRITICAL FIX: If failed and we rotated, revert dimensions BEFORE refreshing
    if dragged_item and not success:
        dragged_item.width = original_orientation.x
        dragged_item.height = original_orientation.y
        
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
        add_child(drag_grid_ghost)

func _get_inventory_from_source(source: String) -> InventoryComponent:
    match source:
        "player": return inventory_component
        "container": return current_container.inventory if current_container else null
    return null

# Context menu & Equipment handling (Standard)
func _on_equipment_slot_input(event: InputEvent, slot_name: String):
    if not inventory_component: return
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
        if is_dragging and dragged_item:
            var source_inv = _get_inventory_from_source(drag_source)
            if source_inv and dragged_item.equip_slot == slot_name:
                source_inv.remove_item(dragged_item)
                inventory_component.equip_item(dragged_item, slot_name)
                _cancel_drag(true)
                refresh_display()
        else:
            var item = inventory_component.equipment_slots.get(slot_name)
            if item and inventory_component.unequip_item(slot_name): refresh_display()

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
            if _can_assign_to_hotbar(context_menu_item):
                inventory_component.set_on_empty_hotbar_slot(context_menu_item)

            elif context_menu_item.equip_slot != "none":
                inv.remove_item(context_menu_item)
                inventory_component.equip_item(context_menu_item, context_menu_item.equip_slot)
        2: inventory_component.unequip_item(context_menu_item.equip_slot)
        3: _split_stack(context_menu_item, inv)
        4: inv.drop_item(context_menu_item , "Player")
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

func _examine_item(item: InventoryItem): print("Examining: ", item.display_name, " - ", item.description)
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
