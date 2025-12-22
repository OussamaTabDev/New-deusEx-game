# Modular Weapon Manager Architecture

## Overview
The WeaponManager has been split into 6 specialized components, each handling a specific aspect of the weapon system.

## Component Structure

```
WeaponManager (Main Orchestrator)
├── WeaponDatabase (Resource Management)
├── WeaponSwitcher (Equip/Unequip Logic)
├── WeaponInputHandler (Input Processing)
├── WeaponVisualsManager (Visual Effects)
├── WeaponDropPickup (Drop/Pickup System)
└── WeaponHealthChecker (Arm Damage Checks)
```

## Component Responsibilities

### 1. **WeaponManager.gd** (Main Orchestrator)
- Coordinates all subsystems
- Manages current weapon state (cW, pW, cWModel)
- Handles main process loop
- Connects signals and updates HUD
- Acts as the public API for external systems

**Key Methods:**
- `_ready()` - Initialize all components
- `_process()` - Update loop coordination
- `switch_to_hotbar_slot()` - Trigger weapon switching
- `enterWeapon()` / `exitWeapon()` - Execute weapon transitions

### 2. **WeaponDatabase.gd** (Resource Management)
- Loads weapon resources from array
- Stores weapons in dictionary (weaponList)
- Links weapons to their 3D slots
- Provides weapon lookup functions

**Key Methods:**
- `initialize()` - Load all weapon resources
- `get_weapon(id)` - Get weapon by ID
- `has_weapon(id)` - Check if weapon exists
- `get_weapon_scene_path(id)` - Get dropped weapon scene

### 3. **WeaponSwitcher.gd** (Equip/Unequip Logic)
- Validates weapon switching requests
- Plays equip/unequip animations
- Manages transition timing
- Handles previous weapon re-equipping

**Key Methods:**
- `switch_to_hotbar_slot()` - Validate and prepare switch
- `play_unequip()` - Execute unequip sequence
- `play_equip()` - Execute equip sequence
- `hide_all_weapons()` - Hide all weapon models

### 4. **WeaponInputHandler.gd** (Input Processing)
- Processes all weapon-related inputs
- Handles hotbar number keys (1-8)
- Manages mouse wheel scrolling
- Implements hold-F-to-unequip
- Routes shooting/reloading inputs

**Key Methods:**
- `handle_input()` - Process InputEvent
- `process_hold_unequip()` - Track F key hold
- `process_weapon_inputs()` - Handle shoot/reload
- `_scroll_hotbar()` - Mouse wheel navigation

### 5. **WeaponVisualsManager.gd** (Visual Effects)
- Procedural weapon animations
- Recoil kick effects
- FOV "breathing" on shoot
- State-based weapon offsets
- Smooth lerping of all effects

**Key Methods:**
- `initialize()` - Store default positions
- `process_weapon_juice()` - Update visuals each frame
- `apply_visual_recoil()` - Add recoil kick
- `reset_to_defaults()` - Clear all effects

### 6. **WeaponDropPickup.gd** (Drop/Pickup System)
- Adds weapons to inventory
- Drops weapons with CS:GO physics
- Checks for duplicate weapons
- Spawns dropped weapon instances
- Handles unique weapon restrictions

**Key Methods:**
- `pickup_weapon()` - Add weapon to inventory
- `drop_current_weapon()` - Drop equipped weapon
- `attempt_pickup_unique()` - Unique weapon validation
- `spawn_dropped_weapon()` - Create world instance

### 7. **WeaponHealthChecker.gd** (Arm Damage System)
- Checks right arm health percentage
- Enforces weapon usage restrictions
- Displays damage warnings in HUD
- Prevents equipping when arm is damaged

**Key Methods:**
- `can_equip_weapon()` - Check if arm is healthy enough
- `get_weapon_restriction_status()` - Get warning message
- `show_arm_damaged_message()` - Display HUD warning

## Setup Instructions

### In Godot Editor:

1. **Create Component Nodes:**
   - Add each component as a Node child of WeaponManager
   - Name them exactly: WeaponDatabase, WeaponSwitcher, etc.

2. **Assign Scripts:**
   - Attach the corresponding .gd file to each node

3. **Configure WeaponManager Exports:**
   ```
   Weapon Components:
   - weapon_database → WeaponDatabase node
   - weapon_switcher → WeaponSwitcher node
   - weapon_inputs → WeaponInputHandler node
   - weapon_visuals → WeaponVisualsManager node
   - weapon_drop_pickup → WeaponDropPickup node
   - weapon_health_checker → WeaponHealthChecker node
   
   External Nodes:
   - Keep all existing references (player, camera, etc.)
   
   Sub-Managers:
   - Keep all existing references (shootManager, reloadManager, etc.)
   ```

4. **WeaponDatabase Setup:**
   - Move `weaponResources` export from WeaponManager to WeaponDatabase
   - Assign your weapon resource array there

5. **WeaponInputHandler Setup:**
   - Configure input action strings (shoot_action, reload_action, etc.)
   - Set drop_key action name

6. **WeaponDropPickup Setup:**
   - Adjust drop physics values (drop_force, drop_forward_force, etc.)

## Benefits of This Architecture

### ✅ **Separation of Concerns**
Each component has one clear responsibility

### ✅ **Easy to Maintain**
Bug fixes are isolated to specific files

### ✅ **Easy to Extend**
Want to add weapon mods? Create WeaponModSystem.gd

### ✅ **Easy to Test**
Can test each component independently

### ✅ **Better Performance**
No performance cost - same code, better organization

### ✅ **Team Friendly**
Multiple people can work on different components

## Communication Flow

```
Input Event
    ↓
WeaponInputHandler (validates)
    ↓
WeaponManager (coordinates)
    ↓
WeaponSwitcher (executes)
    ↓
WeaponVisuals (animates)
```

## Common Tasks

### Adding a New Weapon:
1. Add WeaponResource to WeaponDatabase.weaponResources
2. Create weapon slot in scene
3. Add to ItemDatabase if droppable

### Changing Input Bindings:
1. Modify WeaponInputHandler exports
2. Update project input map

### Adjusting Visual Effects:
1. Edit WeaponVisualsManager parameters
2. Tune lerp speeds and kick amounts

### Adding Weapon Restrictions:
1. Extend WeaponHealthChecker.can_equip_weapon()
2. Add new restriction messages

## Migration Notes

If you have existing code that calls WeaponManager methods:
- ✅ All public methods still work the same
- ✅ `cW`, `pW`, `cWModel` are still accessible
- ✅ No breaking changes to external API

The refactor is **internal only** - existing code continues to work.

## File Summary

| File | Lines | Purpose |
|------|-------|---------|
| WeaponManager.gd | ~250 | Main orchestrator |
| WeaponDatabase.gd | ~50 | Resource loading |
| WeaponSwitcher.gd | ~130 | Equip/unequip logic |
| WeaponInputHandler.gd | ~140 | Input handling |
| WeaponVisualsManager.gd | ~75 | Visual effects |
| WeaponDropPickup.gd | ~170 | Drop/pickup mechanics |
| WeaponHealthChecker.gd | ~45 | Health restrictions |

**Total:** ~860 lines (original was ~650 lines)
**Note:** Slight increase due to component interfaces, but much better organized!
