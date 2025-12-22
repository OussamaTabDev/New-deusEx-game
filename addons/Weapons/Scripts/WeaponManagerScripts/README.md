# Modular Weapon Manager System

## Overview
This is a refactored, modular version of the WeaponManager system split into specialized components for better maintainability and organization.

## File Structure

```
WeaponManager.gd              # Main coordinator (190 lines)
├── WeaponDatabase.gd         # Manages weapon resources (60 lines)
├── WeaponSwitcher.gd         # Handles weapon switching (195 lines)
├── WeaponInputHandler.gd     # Processes all inputs (80 lines)
├── WeaponVisualsManager.gd   # Visual effects & juice (120 lines)
├── WeaponDropPickup.gd       # Drop/pickup logic (200 lines)
└── WeaponHealthChecker.gd    # Monitors arm health (40 lines)
```

## Scene Setup in Godot

### Node Hierarchy
```
WeaponManager (Node3D)
├── WeaponDatabase (Node)
├── WeaponSwitcher (Node)
├── WeaponInputHandler (Node)
├── WeaponVisualsManager (Node)
├── WeaponDropPickup (Node)
├── WeaponHealthChecker (Node)
├── WeaponContainer (Node3D)
│   └── [Weapon slots...]
├── ShootManager (existing)
├── ReloadManager (existing)
├── AmmunitionManager (existing)
└── AnimationManager (existing)
```

### Setup Instructions

1. **Create the Main Node**
   - Create a Node3D named `WeaponManager`
   - Attach the `WeaponManager.gd` script

2. **Add Component Nodes**
   - Add child Node named `WeaponDatabase` with `WeaponDatabase.gd` script
   - Add child Node named `WeaponSwitcher` with `WeaponSwitcher.gd` script
   - Add child Node named `WeaponInputHandler` with `WeaponInputHandler.gd` script
   - Add child Node named `WeaponVisualsManager` with `WeaponVisualsManager.gd` script
   - Add child Node named `WeaponDropPickup` with `WeaponDropPickup.gd` script
   - Add child Node named `WeaponHealthChecker` with `WeaponHealthChecker.gd` script

3. **Assign References in WeaponManager**
   In the Inspector for WeaponManager node, assign:
   - All existing managers (ShootManager, ReloadManager, etc.)
   - Player references
   - Camera references
   - UI references
   - All other exported variables

4. **Configure WeaponDatabase**
   - Set the `weaponResources` array with your weapon resources

5. **Configure Input Actions**
   Make sure these input actions exist in Project Settings:
   - `fire`
   - `fire_alt`
   - `reload`
   - `interact`
   - `throw`
   - `drop_weapon`

## Component Responsibilities

### WeaponManager (Main)
- Coordinates all components
- Manages references and initialization
- Public API for other systems
- Display stats and HUD updates

### WeaponDatabase
- Loads and stores weapon resources
- Maps weapon IDs to resources
- Manages weapon slots in container
- Provides weapon lookup functions

### WeaponSwitcher
- Handles weapon equip/unequip logic
- Manages hotbar slot switching
- Scroll wheel navigation
- Hold-F to unequip
- Previous weapon re-equip

### WeaponInputHandler
- Processes all input events
- Hotbar number keys (1-8)
- Mouse wheel scrolling
- Shoot/reload inputs
- Drop weapon input
- State-based input filtering

### WeaponVisualsManager
- Procedural weapon animation (sway, recoil)
- Muzzle flash effects
- Bullet hole decals
- Weapon sounds with pitch variation
- FOV kick effects

### WeaponDropPickup
- Weapon pickup from world
- Unique weapon validation
- CS:GO-style weapon dropping
- Spawning dropped weapons with physics
- Inventory integration

### WeaponHealthChecker
- Monitors right arm health
- Enforces weapon restrictions
- Auto-drops weapon if arm too damaged
- Provides HUD status messages

## Benefits of This Structure

### 1. **Maintainability**
- Each component has a single, clear responsibility
- Changes to one system don't affect others
- Easy to locate and fix bugs

### 2. **Readability**
- Smaller files (40-200 lines vs 800+ lines)
- Clear naming conventions
- Logical organization

### 3. **Extensibility**
- Easy to add new features to specific components
- Can create new components without touching existing code
- Components can be reused in different projects

### 4. **Testing**
- Each component can be tested independently
- Easier to isolate issues
- Clear interfaces between components

### 5. **Collaboration**
- Different developers can work on different components
- Less merge conflicts
- Clearer code ownership

## Migration Notes

### What Changed
- Monolithic script split into 7 files
- All functionality preserved
- Component references use `@onready` or initialization
- Main API remains the same

### What Stayed the Same
- External managers (ShootManager, ReloadManager, etc.)
- Weapon resources structure
- Inventory integration
- All gameplay functionality
- Input action names

## Usage Examples

### Picking Up a Weapon
```gdscript
# From an interactable weapon in the world
if weapon_manager.attempt_pickup_unique(weapon_id):
    print("Weapon picked up!")
```

### Dropping Current Weapon
```gdscript
weapon_manager.drop_current_weapon()
```

### Checking Weapon Status
```gdscript
if weapon_manager.cW:
    print("Current weapon: ", weapon_manager.cW.weaponName)
```

### Adding Visual Effects
```gdscript
weapon_manager.apply_visual_recoil(0.05, 0.03)
weapon_manager.display_muzzle_flash()
```

## Future Improvements

Potential enhancements that fit this structure:

1. **WeaponAttachments.gd**
   - Scope management
   - Attachments system
   - Stat modifications

2. **WeaponSkinSystem.gd**
   - Weapon skins/materials
   - Visual customization

3. **WeaponStatistics.gd**
   - Track kills, shots fired
   - Accuracy metrics
   - Achievement integration

4. **WeaponUpgradeSystem.gd**
   - Weapon leveling
   - Unlock system
   - Stat progression

## Troubleshooting

### "Invalid get index 'database'" Error
- Make sure WeaponDatabase node is a direct child of WeaponManager
- Check the node is named exactly "WeaponDatabase"

### Weapons Not Switching
- Verify inventory_component is assigned
- Check hotbar_item_used signal is connected
- Ensure weapon_id in inventory matches database

### Visual Recoil Not Working
- Confirm weapon_container reference is set
- Check camera reference is assigned
- Verify state_machine has current_state

### Health Checker Not Working
- Assign combat_health component
- Verify LimbData system is functioning
- Check can_equip_weapon() method exists

## Credits
Refactored from original monolithic WeaponManager.gd
Maintains all original functionality with improved organization
