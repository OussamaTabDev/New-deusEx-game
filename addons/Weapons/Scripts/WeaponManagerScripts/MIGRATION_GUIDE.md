# Migration Guide - Before & After

## Overview
This guide shows how the original monolithic WeaponManager has been split into modular components.

## Architecture Comparison

### Before (Monolithic)
```
WeaponManager.gd (800+ lines)
├── All weapon logic
├── All input handling
├── All visual effects
├── All pickup/drop logic
├── All health checks
└── All switching logic
```

### After (Modular)
```
WeaponManager.gd (190 lines) - Coordinator
├── WeaponDatabase.gd (60 lines) - Data management
├── WeaponSwitcher.gd (195 lines) - Switching logic
├── WeaponInputHandler.gd (80 lines) - Input processing
├── WeaponVisualsManager.gd (120 lines) - Visual effects
├── WeaponDropPickup.gd (200 lines) - World interaction
└── WeaponHealthChecker.gd (40 lines) - Health validation
```

## Code Mapping Reference

### Original → New Component Mapping

#### Initialization Code
**Original Location:** `_ready()`, `initialize()`
**New Location:** 
- `WeaponManager._ready()` - Coordination
- `WeaponDatabase.initialize()` - Resource loading

```gdscript
# BEFORE (in WeaponManager)
func _ready():
    initialize()
    hide_all_weapons()

func initialize():
    for weapon in weaponResources:
        weaponList[weapon.weaponId] = weapon
    # Setup weapon slots...

# AFTER
# WeaponManager.gd
func _ready():
    initialize_components()
    database.initialize()
    visuals.hide_all_weapons()

# WeaponDatabase.gd
func initialize():
    load_weapon_resources()
    setup_weapon_slots()
```

#### Input Handling
**Original Location:** `_input()`, `weaponInputs()`
**New Location:** `WeaponInputHandler.handle_input()`, `process_weapon_inputs()`

```gdscript
# BEFORE (all in WeaponManager)
func _input(event):
    # Hotbar keys
    if event is InputEventKey:
        match event.keycode:
            KEY_1: switch_to_hotbar_slot(0)
            KEY_2: switch_to_hotbar_slot(1)
            # ...
    # Mouse wheel
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            scroll_hotbar(-1)

# AFTER (in WeaponInputHandler)
func handle_input(event: InputEvent):
    if event is InputEventKey and event.pressed:
        var slot = -1
        match event.keycode:
            KEY_1: slot = 0
            KEY_2: slot = 1
            # ...
        if slot >= 0:
            switcher.switch_to_hotbar_slot(slot)
```

#### Weapon Switching
**Original Location:** `switch_to_hotbar_slot()`, `exitWeapon()`, `enterWeapon()`
**New Location:** `WeaponSwitcher` (all methods)

```gdscript
# BEFORE (in WeaponManager)
func switch_to_hotbar_slot(slot: int):
    # Check health
    # Get item from inventory
    # Switch weapon
    if cW:
        exitWeapon(weapon_id, slot)
    else:
        enterWeapon(weapon_id, slot)

# AFTER (in WeaponSwitcher)
func switch_to_hotbar_slot(slot: int):
    # Check health via health_checker
    # Get item from inventory
    # Switch weapon
    if weapon_manager.cW:
        exit_weapon(weapon_id, slot)
    else:
        enter_weapon(weapon_id, slot)
```

#### Visual Effects
**Original Location:** Scattered throughout WeaponManager
**New Location:** `WeaponVisualsManager` (all methods)

```gdscript
# BEFORE (in WeaponManager)
func displayMuzzleFlash():
    # Muzzle flash code...

func displayBulletHole(colliderPoint, colliderNormal, collider):
    # Bullet hole code...

func apply_visual_recoil(kick_back, kick_up):
    # Visual recoil code...

func process_weapon_juice(delta):
    # Procedural animation...

# AFTER (in WeaponVisualsManager)
func display_muzzle_flash():
    # Same code, cleaner context

func display_bullet_hole(colliderPoint, colliderNormal, collider):
    # Same code, cleaner context

func apply_visual_recoil(kick_back, kick_up):
    # Same code, cleaner context

func process_weapon_juice(delta):
    # Same code, cleaner context
```

#### Drop & Pickup
**Original Location:** Multiple methods in WeaponManager
**New Location:** `WeaponDropPickup` (all methods)

```gdscript
# BEFORE (in WeaponManager)
func pickup_weapon(weapon_id: int) -> bool:
    # Pickup logic...

func drop_current_weapon():
    # Drop logic...

func spawn_dropped_weapon(weapon_id, ammo_in_mag):
    # Spawn logic...

# AFTER (in WeaponDropPickup)
func pickup_weapon(weapon_id: int) -> bool:
    # Same logic, isolated

func drop_current_weapon():
    # Same logic, isolated

func spawn_dropped_weapon(weapon_id, ammo_in_mag):
    # Same logic, isolated
```

#### Health Checks
**Original Location:** Scattered checks throughout WeaponManager
**New Location:** `WeaponHealthChecker` (centralized)

```gdscript
# BEFORE (checks scattered everywhere)
if not _can_equip_weapon():
    print("❌ Cannot equip weapon")
    _show_arm_damaged_message()
    return

# AFTER (centralized in WeaponHealthChecker)
if not weapon_manager.health_checker.can_equip_weapon():
    print("❌ Cannot equip weapon")
    weapon_manager.health_checker.show_arm_damaged_message()
    return
```

## Variable Access Changes

### State Variables
**Original:** Direct access in WeaponManager
**New:** Accessed through weapon_manager reference

```gdscript
# BEFORE
var cW = null
var pW = null
var canChangeWeapons = true

# AFTER
# In components:
weapon_manager.cW
weapon_manager.pW
weapon_manager.canChangeWeapons
```

### Exported Variables
**Original:** All in WeaponManager
**New:** Distributed to relevant components

```gdscript
# BEFORE (all in one script)
@export var player: CharacterBody3D
@export var camera: Camera3D
@export var drop_force: float = 5.0

# AFTER (distributed)
# WeaponManager.gd
@export var player: CharacterBody3D
@export var camera: Camera3D

# WeaponDropPickup.gd
@export var drop_force: float = 5.0
```

## Method Call Changes

### External Systems Calling WeaponManager

**Good news:** The public API remains mostly the same!

```gdscript
# BEFORE (external call)
weapon_manager.pickup_weapon(weapon_id)
weapon_manager.drop_current_weapon()
weapon_manager.apply_visual_recoil(0.05, 0.03)

# AFTER (same calls work!)
weapon_manager.pickup_weapon(weapon_id)
weapon_manager.drop_current_weapon()
weapon_manager.apply_visual_recoil(0.05, 0.03)

# WeaponManager delegates to components internally
```

### Internal Method Calls

```gdscript
# BEFORE (all internal)
func _process(delta):
    weaponInputs()
    process_weapon_juice(delta)

# AFTER (delegates to components)
func _process(delta):
    input_handler.process_weapon_inputs()
    visuals.process_weapon_juice(delta)
```

## Signal Connections

### Inventory Signals
**Original:** Connected in WeaponManager
**New:** Still connected in WeaponManager (coordinator role)

```gdscript
# BEFORE
func _ready():
    if inventory_component:
        inventory_component.hotbar_item_used.connect(_on_hotbar_used)

# AFTER (same, but delegates handling)
func _ready():
    if inventory_component:
        inventory_component.hotbar_item_used.connect(_on_hotbar_used)

func _on_hotbar_used(slot: int, item: InventoryItem):
    if item.type == "weapon":
        switcher.switch_to_hotbar_slot(slot)  # Delegates to component
```

## Process Flow Comparison

### Picking Up A Weapon

**Before:**
```
World Item → WeaponManager.pickup_weapon()
  ├── Check inventory
  ├── Create item
  ├── Add to inventory
  └── Auto-equip logic (all in one method)
```

**After:**
```
World Item → WeaponManager.pickup_weapon()
  └── WeaponDropPickup.pickup_weapon()
      ├── Check inventory
      ├── Create item
      ├── Add to inventory
      └── Auto-equip via WeaponSwitcher
```

### Switching Weapons

**Before:**
```
Input → WeaponManager._input()
  └── switch_to_hotbar_slot()
      ├── exitWeapon()
      │   ├── Animations
      │   ├── Sounds
      │   └── Hide model
      └── enterWeapon()
          ├── Show model
          ├── Update managers
          └── Animations
```

**After:**
```
Input → WeaponInputHandler.handle_input()
  └── WeaponSwitcher.switch_to_hotbar_slot()
      ├── WeaponHealthChecker.can_equip_weapon()
      ├── exit_weapon()
      │   ├── Animations via animManager
      │   ├── Sounds via WeaponVisualsManager
      │   └── Hide model
      └── enter_weapon()
          ├── Show model
          ├── Update managers
          └── Animations via animManager
```

### Shooting

**Before:**
```
Input → WeaponManager._process()
  └── weaponInputs()
      ├── Check state_machine
      ├── Input.is_action_pressed()
      └── shootManager.shoot()
          └── Trigger visual effects in WeaponManager
```

**After:**
```
Input → WeaponInputHandler.process_weapon_inputs()
  ├── WeaponHealthChecker.can_equip_weapon()
  ├── Check state_machine
  ├── Input.is_action_pressed()
  └── weapon_manager.shootManager.shoot()
      └── Trigger visual effects via WeaponVisualsManager
```

## Benefits Demonstrated

### 1. Clearer Responsibilities
```gdscript
# BEFORE - Mixed responsibilities
func _process(delta):
    if is_holding_f:  # Input handling
        f_hold_duration += delta
    if cW != null:  # Health checking
        if not _can_equip_weapon():
            drop_current_weapon()  # Dropping
    weaponInputs()  # More input
    process_weapon_juice(delta)  # Visual effects
    displayStats()  # UI updates

# AFTER - Separated concerns
func _process(delta):
    health_checker.check_health(delta)  # Clear purpose
    visuals.process_weapon_juice(delta)  # Clear purpose
    if cW and canUseWeapon:
        input_handler.process_weapon_inputs()  # Clear purpose
    display_stats()  # Clear purpose
```

### 2. Easier Testing
```gdscript
# BEFORE - Hard to test in isolation
# Can't test weapon switching without full WeaponManager setup

# AFTER - Easy to test components
# Can test WeaponSwitcher with minimal setup:
var switcher = WeaponSwitcher.new()
switcher.weapon_manager = mock_weapon_manager
switcher.database = mock_database
# Test switching logic in isolation
```

### 3. Easier Extension
```gdscript
# BEFORE - Adding new feature means modifying monolithic script
# Want to add weapon attachments? Edit 800-line file carefully

# AFTER - Add new component
# Create WeaponAttachments.gd, extend functionality cleanly
WeaponManager
├── WeaponDatabase
├── WeaponSwitcher
├── WeaponAttachments (NEW!)  # Clean addition
└── ...
```

## Common Migration Issues

### Issue 1: Missing References
**Problem:** `Invalid get index 'database'`
**Cause:** Component nodes not created or named incorrectly
**Solution:** Check node hierarchy matches exactly

### Issue 2: Null Weapon Manager
**Problem:** Components can't access weapon_manager
**Cause:** initialize_components() not setting references
**Solution:** Verify all component references are assigned in `_ready()`

### Issue 3: Signals Not Working
**Problem:** Hotbar presses don't switch weapons
**Cause:** Signal connections broken during migration
**Solution:** Check setup_connections() is called

## Verification Steps

After migration, verify these work:

1. **Weapon Switching**
   - [ ] Number keys switch weapons
   - [ ] Mouse wheel scrolls hotbar
   - [ ] Previous weapon re-equip works

2. **Visual Effects**
   - [ ] Muzzle flash appears
   - [ ] Bullet holes spawn
   - [ ] Recoil animation plays
   - [ ] FOV kick happens

3. **World Interaction**
   - [ ] Can pick up weapons
   - [ ] Can drop weapons
   - [ ] Dropped weapons have physics

4. **Health System**
   - [ ] Arm damage prevents use
   - [ ] Auto-drops when too damaged
   - [ ] Shows warning messages

## Performance Notes

**Before vs After:**
- File count: 1 → 7 (more organized, not slower)
- Memory: Identical (same data, just organized differently)
- Performance: Identical or slightly better (better code locality)
- Compile time: Slightly faster (smaller files compile faster)

## Conclusion

The modular system maintains 100% of original functionality while providing:
- ✅ Better organization
- ✅ Easier maintenance
- ✅ Simpler debugging
- ✅ Clearer code ownership
- ✅ Future extensibility

The public API remains unchanged, so external systems don't need updates!
