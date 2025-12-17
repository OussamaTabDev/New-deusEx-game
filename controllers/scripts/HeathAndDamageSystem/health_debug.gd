### Health System Debug & Test Interface
#class_name HealthDebugUI
extends Control
#
### References
#@export var health_component: PlayerHealthComponent
#@export var healing_manager: HealingManager
#@export var weapon_modifier: WeaponHealthModifier  # NEW: Weapon system integration
#
### UI Containers
#@onready var limb_panel: VBoxContainer = %LimbPanel
#@onready var state_label: Label = %StateLabel
#@onready var total_health_label: Label = %TotalHealthLabel
#@onready var effects_panel: VBoxContainer = %EffectsPanel
#@onready var log_text: RichTextLabel = %LogText
#@onready var healing_progress: ProgressBar = %HealingProgress
#@onready var weapon_panel: VBoxContainer = %WeaponPanel  # NEW: Weapon stats panel
#
### Limb display data
#var limb_bars: Dictionary = {}
#var limb_labels: Dictionary = {}
#
### Test healing items
#var test_items: Dictionary = {}
#
#func _ready():
	#_create_test_items()
	#_setup_ui()
	#_connect_signals()
	#_log("=== Health System Debug Ready ===")
#
#func _process(_delta: float):
	#if health_component:
		#_update_display()
#
### ============================================
### UI SETUP
### ============================================
#
#func _setup_ui():
	## Create limb monitoring UI
	#for part in LimbData.BodyPart.values():
		#var limb_name = LimbData.get_limb_name(part)
		#
		## Container for each limb
		#var limb_container = HBoxContainer.new()
		#limb_container.custom_minimum_size = Vector2(0, 40)
		#
		## Limb name label
		#var name_label = Label.new()
		#name_label.text = limb_name
		#name_label.custom_minimum_size = Vector2(100, 0)
		#limb_container.add_child(name_label)
		#
		## Health bar
		#var health_bar = ProgressBar.new()
		#health_bar.min_value = 0
		#health_bar.max_value = 100
		#health_bar.value = 100
		#health_bar.custom_minimum_size = Vector2(200, 0)
		#health_bar.show_percentage = true
		#limb_container.add_child(health_bar)
		#limb_bars[part] = health_bar
		#
		## Status label
		#var status_label = Label.new()
		#status_label.text = "HEALTHY"
		#status_label.custom_minimum_size = Vector2(100, 0)
		#limb_container.add_child(status_label)
		#limb_labels[part] = status_label
		#
		## Damage buttons
		#var damage_10 = Button.new()
		#damage_10.text = "-10"
		#damage_10.pressed.connect(_test_damage.bind(part, 10))
		#limb_container.add_child(damage_10)
		#
		#var damage_25 = Button.new()
		#damage_25.text = "-25"
		#damage_25.pressed.connect(_test_damage.bind(part, 25))
		#limb_container.add_child(damage_25)
		#
		#var damage_50 = Button.new()
		#damage_50.text = "-50"
		#damage_50.pressed.connect(_test_damage.bind(part, 50))
		#limb_container.add_child(damage_50)
		#
		## Heal button
		#var heal_btn = Button.new()
		#heal_btn.text = "Heal"
		#heal_btn.pressed.connect(_test_heal.bind(part))
		#limb_container.add_child(heal_btn)
		#
		#limb_panel.add_child(limb_container)
	#
	## Add global action buttons
	#_add_global_buttons()
#
#func _add_global_buttons():
	#var separator = HSeparator.new()
	#limb_panel.add_child(separator)
	#
	#var button_container = HBoxContainer.new()
	#
	## Full heal
	#var full_heal = Button.new()
	#full_heal.text = "Full Heal All"
	#full_heal.pressed.connect(_test_full_heal)
	#button_container.add_child(full_heal)
	#
	## Critical damage to random limb
	#var critical_dmg = Button.new()
	#critical_dmg.text = "Critical Random"
	#critical_dmg.pressed.connect(_test_critical_random)
	#button_container.add_child(critical_dmg)
	#
	## Test bleeding
	#var bleed_test = Button.new()
	#bleed_test.text = "Cause Bleeding"
	#bleed_test.pressed.connect(_test_bleeding)
	#button_container.add_child(bleed_test)
	#
	## Clear log
	#var clear_log = Button.new()
	#clear_log.text = "Clear Log"
	#clear_log.pressed.connect(_clear_log)
	#button_container.add_child(clear_log)
	#
	#limb_panel.add_child(button_container)
#
#func _create_test_items():
	## Create test healing items
	#var bandage = HealingItem.new()
	#bandage.display_name = "Bandage"
	#bandage.heal_amount = 25
	#bandage.use_time = 2.0
	#bandage.stops_bleeding = true
	#test_items["bandage"] = bandage
	#
	#var medkit = HealingItem.new()
	#medkit.display_name = "Medkit"
	#medkit.heal_amount = 75
	#medkit.use_time = 5.0
	#medkit.stops_bleeding = true
	## medkit.can_heal_all = true
	#test_items["medkit"] = medkit
	#
	#var stimpack = HealingItem.new()
	#stimpack.display_name = "Stimpack"
	#stimpack.heal_amount = 50
	#stimpack.use_time = 1.0
	#stimpack.stops_bleeding = false
	#test_items["stimpack"] = stimpack
#
### ============================================
### SIGNAL CONNECTIONS
### ============================================
#
#func _connect_signals():
	#if not health_component:
		#push_warning("No health_component assigned!")
		#return
	#
	## Health component signals
	#health_component.limb_damaged.connect(_on_limb_damaged)
	#health_component.limb_critical.connect(_on_limb_critical)
	#health_component.limb_destroyed.connect(_on_limb_destroyed)
	#health_component.character_died.connect(_on_character_died)
	#health_component.health_changed.connect(_on_health_changed)
	#health_component.state_changed.connect(_on_state_changed)
	#
	## Player-specific signals
	#if health_component is PlayerHealthComponent:
		#health_component.screen_effect_triggered.connect(_on_screen_effect)
		#health_component.movement_impaired.connect(_on_movement_impaired)
		#health_component.aim_impaired.connect(_on_aim_impaired)
	#
	## Healing manager signals
	#if healing_manager:
		#healing_manager.healing_started.connect(_on_healing_started)
		#healing_manager.healing_progress.connect(_on_healing_progress)
		#healing_manager.healing_complete.connect(_on_healing_complete)
		#healing_manager.healing_interrupted.connect(_on_healing_interrupted)
#
### ============================================
### DISPLAY UPDATE
### ============================================
#
#func _update_display():
	#if not health_component:
		#return
	#
	## Update total health
	#var total_hp = health_component.total_health
	#var max_hp = health_component.max_total_health
	#var hp_percent = (total_hp / max_hp) * 100.0
	#total_health_label.text = "Total Health: %.1f / %.1f (%.1f%%)" % [total_hp, max_hp, hp_percent]
	#
	## Update state
	#var state_name = _get_state_name(health_component.current_state)
	#var state_color = _get_state_color(health_component.current_state)
	#state_label.text = "State: %s" % state_name
	#state_label.modulate = state_color
	#
	## Update limb bars
	#for part in LimbData.BodyPart.values():
		#var limb = health_component.get_limb(part)
		#if not limb:
			#continue
		#
		#var health_percent = limb.get_health_percent() * 100.0
		#var bar = limb_bars.get(part)
		#var label = limb_labels.get(part)
		#
		#if bar:
			#bar.value = health_percent
			## Color based on health
			#if health_percent > 60:
				#bar.modulate = Color.GREEN
			#elif health_percent > 30:
				#bar.modulate = Color.YELLOW
			#elif health_percent > 10:
				#bar.modulate = Color.ORANGE
			#else:
				#bar.modulate = Color.RED
		#
		#if label:
			#var status = ""
			#if limb.is_destroyed():
				#status = "DESTROYED"
			#elif limb.is_critical():
				#status = "CRITICAL"
			#elif limb.is_bleeding:
				#status = "BLEEDING"
			#else:
				#status = "OK"
			#label.text = status
	#
	## Update effects panel
	#_update_effects_display()
#
#func _update_effects_display():
	#if not health_component is PlayerHealthComponent:
		#return
	#
	#var effects_text = "[b]Active Effects:[/b]\n"
	#effects_text += "Speed: %.2f%%\n" % (health_component.speed_modifier * 100)
	#effects_text += "Accuracy: %.2f%%\n" % (health_component.accuracy_modifier * 100)
	#effects_text += "Reload Speed: %.2f%%\n" % (health_component.reload_speed_modifier * 100)
	#effects_text += "Melee Damage: %.2f%%\n" % (health_component.melee_damage_modifier * 100)
	#effects_text += "\n[b]Screen Effects:[/b]\n"
	#effects_text += "Blur: %.2f\n" % health_component.screen_blur_amount
	#effects_text += "Desaturation: %.2f\n" % health_component.screen_desaturation
	#effects_text += "Heartbeat: %.2f\n" % health_component.heartbeat_intensity
	#
	#if health_component.is_limping():
		#effects_text += "\n[color=yellow]⚠ LIMPING[/color]"
	#if not health_component.can_sprint():
		#effects_text += "\n[color=red]⚠ CANNOT SPRINT[/color]"
	#
	#if effects_panel and effects_panel.get_child_count() > 0:
		#var label = effects_panel.get_child(0) as RichTextLabel
		#if label:
			#label.text = effects_text
	#
	## Update weapon modifiers display
	#_update_weapon_display()
#
### ============================================
### TEST FUNCTIONS
### ============================================
#
#func _test_damage(limb: LimbData.BodyPart, amount: float):
	#if not health_component:
		#return
	#
	#var limb_name = LimbData.get_limb_name(limb)
	#_log("[color=orange]Testing: %d damage to %s[/color]" % [amount, limb_name])
	#
	#var damage_info = DamageTypes.DamageInfo.new(amount, DamageTypes.Type.BULLET)
	#health_component.apply_damage_to_limb(limb, damage_info)
#
#func _test_heal(limb: LimbData.BodyPart):
	#if not health_component:
		#return
	#
	#var limb_name = LimbData.get_limb_name(limb)
	#_log("[color=green]Testing: Heal %s[/color]" % limb_name)
	#
	#health_component.heal_limb(limb, 30, true)
#
#func _test_full_heal():
	#if not health_component:
		#return
	#
	#_log("[color=green]Testing: Full heal all limbs[/color]")
	#health_component.heal_all(1000, true)
#
#func _test_critical_random():
	#if not health_component:
		#return
	#
	#var parts = LimbData.BodyPart.values()
	#var random_limb = parts[randi() % parts.size()]
	#var limb_name = LimbData.get_limb_name(random_limb)
	#
	#_log("[color=red]Testing: Critical damage to %s[/color]" % limb_name)
	#
	#var damage_info = DamageTypes.DamageInfo.new(85, DamageTypes.Type.EXPLOSION)
	#health_component.apply_damage_to_limb(random_limb, damage_info)
#
#func _test_bleeding():
	#if not health_component:
		#return
	#
	#_log("[color=purple]Testing: Cause bleeding on torso[/color]")
	#
	#var damage_info = DamageTypes.DamageInfo.new(50, DamageTypes.Type.BULLET)
	#health_component.apply_damage_to_limb(LimbData.BodyPart.TORSO, damage_info)
#
#func _test_use_healing_item(item_name: String, limb: LimbData.BodyPart = LimbData.BodyPart.TORSO):
	#if not healing_manager or not health_component:
		#return
	#
	#var item = test_items.get(item_name)
	#if not item:
		#_log("[color=red]Error: Item '%s' not found[/color]" % item_name)
		#return
	#
	#if healing_manager.use_item(item, health_component, limb):
		#_log("[color=cyan]Using %s on %s[/color]" % [item_name, LimbData.get_limb_name(limb)])
	#else:
		#_log("[color=yellow]Cannot use item - already healing[/color]")
#
### ============================================
### SIGNAL HANDLERS
### ============================================
#
#func _on_limb_damaged(limb: LimbData.BodyPart, damage: float, damage_type: DamageTypes.Type):
	#var limb_name = LimbData.get_limb_name(limb)
	#var type_name = DamageTypes.Type.keys()[damage_type]
	#_log("💥 %s took %.1f %s damage" % [limb_name, damage, type_name])
#
#func _on_limb_critical(limb: LimbData.BodyPart):
	#var limb_name = LimbData.get_limb_name(limb)
	#_log("[color=orange]⚠️ WARNING: %s is CRITICAL![/color]" % limb_name)
#
#func _on_limb_destroyed(limb: LimbData.BodyPart):
	#var limb_name = LimbData.get_limb_name(limb)
	#_log("[color=red]☠️ CRITICAL: %s DESTROYED![/color]" % limb_name)
#
#func _on_character_died(cause: String):
	#_log("[color=red][b]💀 PLAYER DIED: %s[/b][/color]" % cause)
#
#func _on_health_changed(total: float, max_total: float):
	#var percent = (total / max_total) * 100.0
	#_log("❤️ Health: %.1f/%.1f (%.1f%%)" % [total, max_total, percent])
#
#func _on_state_changed(state: HealthComponent.CharacterState):
	#var state_name = _get_state_name(state)
	#_log("[color=yellow]🔄 State changed to: %s[/color]" % state_name)
#
#func _on_screen_effect(effect_type: String, intensity: float):
	#_log("🎬 Screen effect: %s = %.2f" % [effect_type, intensity])
#
#func _on_movement_impaired(multiplier: float):
	#_log("🏃 Movement speed: %.1f%%" % (multiplier * 100))
#
#func _on_aim_impaired(multiplier: float):
	#_log("🎯 Aim accuracy: %.1f%%" % (multiplier * 100))
#
#func _on_healing_started(item: HealingItem, limb: LimbData.BodyPart):
	#var limb_name = LimbData.get_limb_name(limb)
	#_log("[color=green]💊 Healing started: %s on %s (%.1fs)[/color]" % [item.item_name, limb_name, item.use_time])
#
#func _on_healing_progress(progress: float):
	#if healing_progress:
		#healing_progress.value = progress * 100
#
#func _on_healing_complete(item: HealingItem):
	#_log("[color=green]✅ Healing complete: %s[/color]" % item.item_name)
	#if healing_progress:
		#healing_progress.value = 0
#
#func _on_healing_interrupted():
	#_log("[color=yellow]❌ Healing interrupted![/color]")
	#if healing_progress:
		#healing_progress.value = 0
#
### ============================================
### HELPER FUNCTIONS
### ============================================
#
#func _get_state_name(state: HealthComponent.CharacterState) -> String:
	#match state:
		#HealthComponent.CharacterState.NORMAL:
			#return "NORMAL"
		#HealthComponent.CharacterState.WOUNDED:
			#return "WOUNDED"
		#HealthComponent.CharacterState.CRITICAL:
			#return "CRITICAL"
		#HealthComponent.CharacterState.NEAR_DEATH:
			#return "NEAR DEATH"
		#HealthComponent.CharacterState.DEAD:
			#return "DEAD"
		#_:
			#return "UNKNOWN"
#
#func _get_state_color(state: HealthComponent.CharacterState) -> Color:
	#match state:
		#HealthComponent.CharacterState.NORMAL:
			#return Color.GREEN
		#HealthComponent.CharacterState.WOUNDED:
			#return Color.YELLOW
		#HealthComponent.CharacterState.CRITICAL:
			#return Color.ORANGE
		#HealthComponent.CharacterState.NEAR_DEATH:
			#return Color.RED
		#HealthComponent.CharacterState.DEAD:
			#return Color.DARK_RED
		#_:
			#return Color.WHITE
#
#func _log(message: String):
	#if not log_text:
		#print(message)
		#return
	#
	#var time = Time.get_ticks_msec() / 1000.0
	#log_text.append_text("[%.2f] %s\n" % [time, message])
	#
	## Auto-scroll to bottom
	#await get_tree().process_frame
	#log_text.scroll_to_line(log_text.get_line_count())
#
#func _clear_log():
	#if log_text:
		#log_text.clear()
	#_log("=== Log cleared ===")
#
### ============================================
### WEAPON MODIFIER DISPLAY
### ============================================
#
#func _update_weapon_display():
	#"""Update weapon modifier display"""
	#if not weapon_modifier or not weapon_panel:
		#return
	#
	## Create or update weapon stats label
	#var weapon_label: RichTextLabel
	#if weapon_panel.get_child_count() == 0:
		#weapon_label = RichTextLabel.new()
		#weapon_label.bbcode_enabled = true
		#weapon_label.fit_content = true
		#weapon_label.scroll_active = false
		#weapon_panel.add_child(weapon_label)
	#else:
		#weapon_label = weapon_panel.get_child(0) as RichTextLabel
	#
	#if not weapon_label:
		#return
	#
	#var stats = weapon_modifier.get_weapon_effectiveness()
	#
	#var weapon_text = "[b]🔫 WEAPON PERFORMANCE:[/b]\n"
	#weapon_text += _format_stat("Accuracy", stats.accuracy)
	#weapon_text += _format_stat("Reload Speed", stats.reload_speed)
	#weapon_text += _format_stat("Recoil Control", 1.0 / stats.recoil if stats.recoil > 0 else 1.0)
	#weapon_text += _format_stat("Weapon Stability", 1.0 / stats.sway if stats.sway > 0 else 1.0)
	#weapon_text += _format_stat("Melee Damage", stats.melee_damage)
	#
	#weapon_label.text = weapon_text
#
#func _format_stat(name: String, value: float) -> String:
	#"""Format stat with color based on value"""
	#var percent = value * 100
	#var color = "green"
	#
	#if percent < 50:
		#color = "red"
	#elif percent < 75:
		#color = "orange"
	#elif percent < 90:
		#color = "yellow"
	#
	#return "%s: [color=%s]%.1f%%[/color]\n" % [name, color, percent]
#
### ============================================
### INPUT TESTING (Optional keyboard shortcuts)
### ============================================
#
#func _input(event: InputEvent):
	#if not event is InputEventKey or not event.pressed:
		#return
	#
	#match event.keycode:
		#KEY_F1: # Test head damage
			#_test_damage(LimbData.BodyPart.HEAD, 20)
		#KEY_F2: # Test torso damage
			#_test_damage(LimbData.BodyPart.TORSO, 20)
		#KEY_F3: # Test arm damage
			#_test_damage(LimbData.BodyPart.RIGHT_ARM, 20)
		#KEY_F4: # Test leg damage
			#_test_damage(LimbData.BodyPart.LEFT_LEG, 20)
		#KEY_F5: # Full heal
			#_test_full_heal()
		#KEY_F6: # Critical random
			#_test_critical_random()
		#KEY_H: # Use bandage
			#_test_use_healing_item("bandage")
		#KEY_M: # Use medkit
			#_test_use_healing_item("medkit")
		#KEY_S: # Use stimpack
			#_test_use_healing_item("stimpack")
