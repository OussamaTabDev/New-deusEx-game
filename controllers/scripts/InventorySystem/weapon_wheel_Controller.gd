extends ColorRect
class_name Wheel_handler

@export var weapon_wheel_ui: RadialMenu
@export var inventory_ui: InventoryUI
@export var weapon_manager: WeaponManager
@export var open_key: String = "wheel_key"
@export var with_hold: bool = true

@export_range(0.01, 1.0) var wheel_time_scale: float = 0.01
var is_wheel_open: bool = false
var original_time_scale: float = 1.0

func _ready() -> void:
	if not weapon_wheel_ui:
		push_error("Wheel_handler: weapon_wheel_ui is not assigned!")
		return
	if not inventory_ui:
		push_error("Wheel_handler: inventory_ui is not assigned!")
		return
	if not weapon_manager:
		push_error("Wheel_handler: weapon_manager is not assigned!")
		return

	weapon_wheel_ui.hide()
	# We still connect signals for non-hold mode (e.g. click-to-select)
	weapon_wheel_ui.item_selected.connect(_on_wheel_item_selected)
	weapon_wheel_ui.canceled.connect(_on_wheel_canceled)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed(open_key):
		_open_wheel()
	elif with_hold and event.is_action_released(open_key):
		# ✅ COMMIT on release — no click needed
		_commit_and_close_wheel()

func _process(_delta: float) -> void:
	if with_hold and Input.is_action_pressed(open_key):
		if not is_wheel_open:
			_open_wheel()

# --- Open Wheel ---
func _open_wheel() -> void:
	if is_wheel_open or not inventory_ui or not inventory_ui.inventory_component:
		return

	var hotbar = inventory_ui.inventory_component.hotbar
	var items: Array = []

	for i in range(min(hotbar.size(), 10)):
		var item = hotbar[i]
		if not item:
			continue
		items.append({
			'texture': item.icon,
			'title': item.display_name,
			'id': i
		})

	if items.is_empty():
		return

	original_time_scale = Engine.time_scale
	Engine.time_scale = wheel_time_scale
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	weapon_wheel_ui.set_items(items)
	var pos = get_viewport().get_visible_rect().get_center()
	weapon_wheel_ui.open_menu(pos)
	is_wheel_open = true

	show()

# --- Commit selection ON KEY RELEASE (hold mode) ---
func _commit_and_close_wheel() -> void:
	if not is_wheel_open:
		return

	# ✅ Get the currently hovered item index (from mouse direction)
	var selected_index = weapon_wheel_ui.selected  # This is auto-updated by _physics_process

	_close_wheel()

	# Switch weapon only if a valid slot is selected
	if selected_index >= 0:
		weapon_manager.switch_to_hotbar_slot(selected_index)

# --- Close without committing (e.g. ESC or cancel) ---
func _close_wheel() -> void:
	if not is_wheel_open:
		return

	weapon_wheel_ui.close_menu()
	is_wheel_open = false

	Engine.time_scale = original_time_scale
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hide()
# --- Signal handlers (used in NON-hold mode or explicit click) ---
func _on_wheel_item_selected(id: int, _position: Vector2) -> void:
	# This is for click-to-select (when with_hold = false)
	_close_wheel()
	weapon_manager.switch_to_hotbar_slot(id)
	
func _on_wheel_canceled() -> void:
	_close_wheel()

# --- Auto-hover selection ---
func _physics_process(_delta: float) -> void:
	if not is_wheel_open:
		return

	var selected_index = weapon_wheel_ui.get_selected_by_mouse()
	if selected_index != weapon_wheel_ui.selected:
		weapon_wheel_ui.set_selected_item(selected_index)
		
