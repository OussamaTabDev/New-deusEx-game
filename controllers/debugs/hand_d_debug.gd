## Complete Health System Debug Panel
## Add this as a Control node in your scene and assign the player reference
class_name HealthSystemDebugPanel
extends Control

## Exports for easy setup
@export_group("References")
@export var player: Player
@export var auto_find_player: bool = true
## Internal references
@export var health_component: PlayerHealthComponent
@export var healing_manager: HealingManager

@export_group("Debug Settings")
@export var update_interval: float = 0.1
@export var show_detailed_logs: bool = true
@export var enable_auto_tests: bool = false


## UI Elements (created automatically)
var limb_buttons: Dictionary = {}
var status_labels: Dictionary = {}
var effect_labels: Dictionary = {}
var console_output: RichTextLabel
var healing_progress_bar: ProgressBar

## State tracking
var update_timer: float = 0.0
var test_healing_item: HealingItem


func _ready():
	# Auto-find player if needed
	if auto_find_player and not player:
		player = get_tree().get_first_node_in_group("player")
	
	if not player:
		push_error("HealthSystemDebugPanel: No player assigned or found!")
		return
	if not health_component:
		health_component = player.get_node_or_null("PlayerHealthComponent")
	# Get health component
	if not health_component:
		push_error("HealthSystemDebugPanel: Player has no PlayerHealthComponent!")
		return
	if not healing_manager:
	# Get or create healing manager
		healing_manager = player.get_node_or_null("HealingManager")
	if not healing_manager:
		healing_manager = HealingManager.new()
		healing_manager.name = "HealingManager"
		player.add_child(healing_manager)
		log_message("Created HealingManager component", Color.YELLOW)
	
	# Setup test healing item
	_create_test_healing_item()
	
	# Connect all signals
	_connect_signals()
	
	# Build UI
	_build_ui()
	
	log_message("=== HEALTH DEBUG PANEL INITIALIZED ===", Color.GREEN)
	log_message("Player: %s" % player.name, Color.CYAN)
	log_message("Hitbox Mode: %s" % ("PRECISE" if health_component.use_precise_hitboxes else "FALLBACK"), Color.CYAN)
	
	if enable_auto_tests:
		_run_auto_tests()


func _process(delta: float):
	update_timer += delta
	if update_timer >= update_interval:
		update_timer = 0.0
		_update_status_display()


## === UI BUILDING ===

func _build_ui():
	# Clear existing children
	for child in get_children():
		child.queue_free()
	
	# Main container
	var main_vbox = VBoxContainer.new()
	main_vbox.anchor_right = 1.0
	main_vbox.anchor_bottom = 1.0
	add_child(main_vbox)
	
	# Title
	var title = Label.new()
	title.text = "=== HEALTH SYSTEM DEBUG PANEL ==="
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	main_vbox.add_child(title)
	
	var separator1 = HSeparator.new()
	main_vbox.add_child(separator1)
	
	# Split into left and right panels
	var h_split = HSplitContainer.new()
	h_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(h_split)
	
	# LEFT PANEL - Controls
	var left_panel = _build_control_panel()
	h_split.add_child(left_panel)
	
	# RIGHT PANEL - Status & Console
	var right_panel = _build_status_panel()
	h_split.add_child(right_panel)


func _build_control_panel() -> Control:
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(400, 0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)
	
	# === DAMAGE SECTION ===
	var damage_label = Label.new()
	damage_label.text = "DAMAGE CONTROLS"
	damage_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(damage_label)
	
	for limb in LimbData.BodyPart.values():
		var limb_name = LimbData.get_limb_name(limb)
		var hbox = HBoxContainer.new()
		
		var label = Label.new()
		label.text = limb_name
		label.custom_minimum_size = Vector2(100, 0)
		hbox.add_child(label)
		
		# Small damage
		var btn_small = Button.new()
		btn_small.text = "-10"
		btn_small.custom_minimum_size = Vector2(50, 0)
		btn_small.pressed.connect(_on_damage_limb.bind(limb, 10.0, DamageTypes.Type.BULLET))
		hbox.add_child(btn_small)
		
		# Medium damage
		var btn_med = Button.new()
		btn_med.text = "-30"
		btn_med.custom_minimum_size = Vector2(50, 0)
		btn_med.pressed.connect(_on_damage_limb.bind(limb, 30.0, DamageTypes.Type.BULLET))
		hbox.add_child(btn_med)
		
		# Large damage
		var btn_large = Button.new()
		btn_large.text = "-50"
		btn_large.custom_minimum_size = Vector2(50, 0)
		btn_large.pressed.connect(_on_damage_limb.bind(limb, 50.0, DamageTypes.Type.EXPLOSION))
		hbox.add_child(btn_large)
		
		# Critical damage
		var btn_crit = Button.new()
		btn_crit.text = "CRIT"
		btn_crit.custom_minimum_size = Vector2(50, 0)
		btn_crit.pressed.connect(_on_damage_limb.bind(limb, 80.0, DamageTypes.Type.EXPLOSION))
		hbox.add_child(btn_crit)
		
		vbox.add_child(hbox)
		limb_buttons[limb] = hbox
	
	vbox.add_child(HSeparator.new())
	
	# === HEALING SECTION ===
	var healing_label = Label.new()
	healing_label.text = "HEALING CONTROLS"
	healing_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(healing_label)
	
	# Heal all button
	var heal_all_btn = Button.new()
	heal_all_btn.text = "HEAL ALL (+50)"
	heal_all_btn.pressed.connect(_on_heal_all)
	vbox.add_child(heal_all_btn)
	
	# Full restore button
	var restore_btn = Button.new()
	restore_btn.text = "FULL RESTORE"
	restore_btn.pressed.connect(_on_full_restore)
	vbox.add_child(restore_btn)
	
	# Healing item test
	var heal_item_btn = Button.new()
	heal_item_btn.text = "USE MEDKIT (Torso)"
	heal_item_btn.pressed.connect(_on_use_healing_item.bind(LimbData.BodyPart.TORSO))
	vbox.add_child(heal_item_btn)
	
	# Healing progress bar
	healing_progress_bar = ProgressBar.new()
	healing_progress_bar.value = 0
	healing_progress_bar.visible = false
	vbox.add_child(healing_progress_bar)
	
	# Interrupt healing
	var interrupt_btn = Button.new()
	interrupt_btn.text = "INTERRUPT HEALING"
	interrupt_btn.pressed.connect(_on_interrupt_healing)
	vbox.add_child(interrupt_btn)
	
	vbox.add_child(HSeparator.new())
	
	# === TEST SCENARIOS ===
	var test_label = Label.new()
	test_label.text = "TEST SCENARIOS"
	test_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(test_label)
	
	var test_gunshot = Button.new()
	test_gunshot.text = "Test: Gunshot Wound"
	test_gunshot.pressed.connect(_test_gunshot_wound)
	vbox.add_child(test_gunshot)
	
	var test_explosion = Button.new()
	test_explosion.text = "Test: Explosion Damage"
	test_explosion.pressed.connect(_test_explosion_damage)
	vbox.add_child(test_explosion)
	
	var test_critical = Button.new()
	test_critical.text = "Test: Critical State"
	test_critical.pressed.connect(_test_critical_state)
	vbox.add_child(test_critical)
	
	var test_bleed = Button.new()
	test_bleed.text = "Test: Bleeding System"
	test_bleed.pressed.connect(_test_bleeding)
	vbox.add_child(test_bleed)
	
	return scroll


func _build_status_panel() -> Control:
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# === STATUS DISPLAY ===
	var status_label = Label.new()
	status_label.text = "CURRENT STATUS"
	status_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(status_label)
	
	var status_panel = PanelContainer.new()
	var status_vbox = VBoxContainer.new()
	status_panel.add_child(status_vbox)
	vbox.add_child(status_panel)
	
	# Create status labels
	for key in ["state", "total_health", "speed", "accuracy", "reload", "can_sprint", "is_limping"]:
		var lbl = Label.new()
		lbl.text = "%s: ..." % key
		status_vbox.add_child(lbl)
		status_labels[key] = lbl
	
	vbox.add_child(HSeparator.new())
	
	# === LIMB HEALTH DISPLAY ===
	var limb_label = Label.new()
	limb_label.text = "LIMB HEALTH"
	limb_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(limb_label)
	
	var limb_panel = PanelContainer.new()
	var limb_vbox = VBoxContainer.new()
	limb_panel.add_child(limb_vbox)
	vbox.add_child(limb_panel)
	
	for limb in LimbData.BodyPart.values():
		var limb_name = LimbData.get_limb_name(limb)
		var lbl = Label.new()
		lbl.text = "%s: 100%%" % limb_name
		limb_vbox.add_child(lbl)
		status_labels["limb_%d" % limb] = lbl
	
	vbox.add_child(HSeparator.new())
	
	# === EFFECTS DISPLAY ===
	var effects_label = Label.new()
	effects_label.text = "ACTIVE EFFECTS"
	effects_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(effects_label)
	
	var effects_panel = PanelContainer.new()
	var effects_vbox = VBoxContainer.new()
	effects_panel.add_child(effects_vbox)
	vbox.add_child(effects_panel)
	
	for key in ["blur", "desaturation", "heartbeat"]:
		var lbl = Label.new()
		lbl.text = "%s: 0.0" % key
		effects_vbox.add_child(lbl)
		effect_labels[key] = lbl
	
	vbox.add_child(HSeparator.new())
	
	# === CONSOLE OUTPUT ===
	var console_label = Label.new()
	console_label.text = "CONSOLE LOG"
	console_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(console_label)
	
	console_output = RichTextLabel.new()
	console_output.bbcode_enabled = true
	console_output.scroll_following = true
	console_output.custom_minimum_size = Vector2(0, 300)
	console_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(console_output)
	
	# Clear console button
	var clear_btn = Button.new()
	clear_btn.text = "Clear Console"
	clear_btn.pressed.connect(_clear_console)
	vbox.add_child(clear_btn)
	
	return vbox


## === SIGNAL CONNECTIONS ===

func _connect_signals():
	# Health component signals
	health_component.limb_damaged.connect(_on_limb_damaged)
	health_component.limb_critical.connect(_on_limb_critical)
	health_component.limb_destroyed.connect(_on_limb_destroyed)
	health_component.character_died.connect(_on_character_died)
	health_component.health_changed.connect(_on_health_changed)
	health_component.state_changed.connect(_on_state_changed)
	
	# Player-specific signals
	health_component.screen_effect_triggered.connect(_on_screen_effect)
	health_component.movement_impaired.connect(_on_movement_impaired)
	health_component.aim_impaired.connect(_on_aim_impaired)
	
	# Healing manager signals
	healing_manager.healing_started.connect(_on_healing_started)
	healing_manager.healing_progress.connect(_on_healing_progress)
	healing_manager.healing_complete.connect(_on_healing_complete)
	healing_manager.healing_interrupted.connect(_on_healing_interrupted)


## === BUTTON CALLBACKS ===

func _on_damage_limb(limb: LimbData.BodyPart, amount: float, dmg_type: DamageTypes.Type):
	var damage_info = DamageTypes.DamageInfo.new(amount, dmg_type)
	damage_info.hit_position = player.global_position
	health_component.apply_damage_to_limb(limb, damage_info)
	log_message("Applied %.1f %s damage to %s" % [amount, DamageTypes.Type.keys()[dmg_type], LimbData.get_limb_name(limb)], Color.ORANGE_RED)


func _on_heal_all():
	health_component.heal_all(50.0, false)
	log_message("Healed all limbs by 50 HP", Color.GREEN)


func _on_full_restore():
	health_component.heal_all(999.0, true)
	log_message("Full restore: All limbs healed and bleeding stopped", Color.LIGHT_GREEN)


func _on_use_healing_item(limb: LimbData.BodyPart):
	if healing_manager.can_use_item():
		healing_manager.use_item(test_healing_item, health_component, limb)
		log_message("Started using healing item on %s" % LimbData.get_limb_name(limb), Color.CYAN)
	else:
		log_message("Cannot use healing item - already healing!", Color.RED)


func _on_interrupt_healing():
	healing_manager.interrupt_healing()


## === SIGNAL HANDLERS ===

func _on_limb_damaged(limb: LimbData.BodyPart, damage: float, damage_type: DamageTypes.Type):
	if show_detailed_logs:
		log_message("⚠ %s took %.1f damage (%s)" % [LimbData.get_limb_name(limb), damage, DamageTypes.Type.keys()[damage_type]], Color.YELLOW)


func _on_limb_critical(limb: LimbData.BodyPart):
	log_message("🔴 CRITICAL: %s is critically damaged!" % LimbData.get_limb_name(limb), Color.RED)


func _on_limb_destroyed(limb: LimbData.BodyPart):
	log_message("💀 DESTROYED: %s has been destroyed!" % LimbData.get_limb_name(limb), Color.DARK_RED)


func _on_character_died(cause: String):
	log_message("💀💀💀 PLAYER DIED: %s 💀💀💀" % cause, Color.DARK_RED)


func _on_health_changed(total: float, max_total: float):
	if show_detailed_logs:
		log_message("Health: %.1f / %.1f (%.1f%%)" % [total, max_total, (total/max_total)*100], Color.LIGHT_BLUE)


func _on_state_changed(state: HealthComponent.CharacterState):
	var state_name = ["NORMAL", "WOUNDED", "CRITICAL", "NEAR_DEATH", "DEAD"][state]
	log_message("🔄 State changed: %s" % state_name, Color.ORANGE)


func _on_screen_effect(effect_type: String, intensity: float):
	if show_detailed_logs:
		log_message("Screen effect: %s = %.2f" % [effect_type, intensity], Color.PINK)


func _on_movement_impaired(speed_mult: float):
	if show_detailed_logs:
		log_message("Movement: %.0f%% speed" % (speed_mult * 100), Color.LIGHT_BLUE)


func _on_aim_impaired(accuracy_mult: float):
	if show_detailed_logs:
		log_message("Aim: %.0f%% accuracy" % (accuracy_mult * 100), Color.LIGHT_BLUE)


func _on_healing_started(item: HealingItem, limb: LimbData.BodyPart):
	healing_progress_bar.visible = true
	healing_progress_bar.value = 0
	log_message("🔧 Started healing %s" % LimbData.get_limb_name(limb), Color.LIGHT_GREEN)


func _on_healing_progress(progress: float):
	healing_progress_bar.value = progress * 100


func _on_healing_complete(item: HealingItem):
	healing_progress_bar.visible = false
	log_message("✅ Healing complete!", Color.GREEN)


func _on_healing_interrupted():
	healing_progress_bar.visible = false
	log_message("❌ Healing interrupted!", Color.ORANGE)


## === STATUS UPDATE ===

func _update_status_display():
	if not health_component:
		return
	
	# Overall status
	var state_names = ["NORMAL", "WOUNDED", "CRITICAL", "NEAR_DEATH", "DEAD"]
	status_labels["state"].text = "State: %s" % state_names[health_component.current_state]
	status_labels["total_health"].text = "Total Health: %.1f%%" % (health_component.get_total_health_percent() * 100)
	status_labels["speed"].text = "Speed Modifier: %.0f%%" % (health_component.get_speed_modifier() * 100)
	status_labels["accuracy"].text = "Accuracy: %.0f%%" % (health_component.get_accuracy_modifier() * 100)
	status_labels["reload"].text = "Reload Speed: %.0f%%" % (health_component.get_reload_speed_modifier() * 100)
	status_labels["can_sprint"].text = "Can Sprint: %s" % ("YES" if health_component.can_sprint() else "NO")
	status_labels["is_limping"].text = "Limping: %s" % ("YES" if health_component.is_limping() else "NO")
	
	# Color code state
	var state_color = Color.WHITE
	match health_component.current_state:
		HealthComponent.CharacterState.WOUNDED:
			state_color = Color.YELLOW
		HealthComponent.CharacterState.CRITICAL:
			state_color = Color.ORANGE
		HealthComponent.CharacterState.NEAR_DEATH:
			state_color = Color.RED
		HealthComponent.CharacterState.DEAD:
			state_color = Color.DARK_RED
	status_labels["state"].add_theme_color_override("font_color", state_color)
	
	# Limb health
	for limb in LimbData.BodyPart.values():
		var limb_data = health_component.get_limb(limb)
		if limb_data:
			var percent = limb_data.get_health_percent() * 100
			var status = ""
			if limb_data.is_destroyed():
				status = " [DESTROYED]"
			elif limb_data.is_critical():
				status = " [CRITICAL]"
			elif limb_data.is_bleeding:
				status = " [BLEEDING]"
			
			var label = status_labels["limb_%d" % limb]
			label.text = "%s: %.1f%% %s" % [LimbData.get_limb_name(limb), percent, status]
			
			# Color code
			var color = Color.GREEN
			if limb_data.is_destroyed():
				color = Color.DARK_RED
			elif limb_data.is_critical():
				color = Color.RED
			elif percent < 50:
				color = Color.ORANGE
			label.add_theme_color_override("font_color", color)
	
	# Effects
	effect_labels["blur"].text = "Blur: %.2f" % health_component.screen_blur_amount
	effect_labels["desaturation"].text = "Desaturation: %.2f" % health_component.screen_desaturation
	effect_labels["heartbeat"].text = "Heartbeat: %.2f" % health_component.heartbeat_intensity


## === TEST SCENARIOS ===

func _test_gunshot_wound():
	log_message("=== GUNSHOT WOUND TEST ===", Color.CYAN)
	var damage = DamageTypes.DamageInfo.new(35.0, DamageTypes.Type.BULLET)
	health_component.apply_damage_to_limb(LimbData.BodyPart.LEFT_ARM, damage)
	await get_tree().create_timer(0.5).timeout
	health_component.apply_damage_to_limb(LimbData.BodyPart.TORSO, damage)


func _test_explosion_damage():
	log_message("=== EXPLOSION DAMAGE TEST ===", Color.CYAN)
	var damage = DamageTypes.DamageInfo.new(25.0, DamageTypes.Type.EXPLOSION)
	for limb in [LimbData.BodyPart.TORSO, LimbData.BodyPart.LEFT_LEG, LimbData.BodyPart.RIGHT_LEG]:
		health_component.apply_damage_to_limb(limb, damage)
		await get_tree().create_timer(0.2).timeout


func _test_critical_state():
	log_message("=== CRITICAL STATE TEST ===", Color.CYAN)
	var heavy_damage = DamageTypes.DamageInfo.new(70.0, DamageTypes.Type.BULLET)
	health_component.apply_damage_to_limb(LimbData.BodyPart.HEAD, heavy_damage)


func _test_bleeding():
	log_message("=== BLEEDING TEST ===", Color.CYAN)
	var bleed_damage = DamageTypes.DamageInfo.new(45.0, DamageTypes.Type.BULLET)
	health_component.apply_damage_to_limb(LimbData.BodyPart.LEFT_LEG, bleed_damage)


func _run_auto_tests():
	await get_tree().create_timer(2.0).timeout
	log_message("=== RUNNING AUTO TESTS ===", Color.MAGENTA)
	
	await get_tree().create_timer(1.0).timeout
	_test_gunshot_wound()
	
	await get_tree().create_timer(3.0).timeout
	_on_heal_all()
	
	await get_tree().create_timer(2.0).timeout
	_test_explosion_damage()


## === HELPER FUNCTIONS ===

func _create_test_healing_item():
	test_healing_item = HealingItem.new()
	test_healing_item.display_name = "Test Medkit"
	test_healing_item.heal_amount = 50.0
	test_healing_item.use_time = 2.0
	test_healing_item.stops_bleeding = true


func log_message(message: String, color: Color = Color.WHITE):
	if console_output:
		var time = Time.get_ticks_msec() / 1000.0
		console_output.append_text("[color=#%s][%.2fs] %s[/color]\n" % [color.to_html(), time, message])
	print("[HealthDebug] %s" % message)


func _clear_console():
	console_output.clear()
	log_message("Console cleared", Color.GRAY)
