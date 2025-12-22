# Godot Scene Setup Guide

## Scene Tree Structure

```
Player
├── WeaponManager (Node3D)
│   ├── WeaponDatabase (Node)
│   ├── WeaponSwitcher (Node)
│   ├── WeaponInputHandler (Node)
│   ├── WeaponVisualsManager (Node)
│   ├── WeaponDropPickup (Node)
│   ├── WeaponHealthChecker (Node)
│   ├── WeaponContainer (Node3D)
│   │   ├── WeaponSlot1 (Node3D)
│   │   ├── WeaponSlot2 (Node3D)
│   │   └── ...
│   ├── ShootManager (Node)
│   ├── ReloadManager (Node)
│   ├── AmmunitionManager (Node)
│   ├── AnimationManager (Node3D)
│   └── AnimationPlayer
├── CameraHolder (Node3D)
│   ├── CameraRecoilHolder (Node3D)
│   │   └── Camera3D
│   └── InteractionRaycast (RayCast3D)
├── CombatHealthComponent (Node)
├── InventoryComponent (Node)
└── StateMachine (Node)
```

## Step-by-Step Setup

### 1. Create Component Nodes

Right-click WeaponManager → Add Child Node

Add these 6 nodes as children:
```
- Node (name: WeaponDatabase)
- Node (name: WeaponSwitcher)
- Node (name: WeaponInputHandler)
- Node (name: WeaponVisualsManager)
- Node (name: WeaponDropPickup)
- Node (name: WeaponHealthChecker)
```

### 2. Attach Scripts

For each component:
1. Select the node
2. Click script icon in Inspector
3. Choose "Load" and select the corresponding .gd file

### 3. Configure WeaponManager Inspector

#### Weapon Components Group:
```
Weapon Database     → Drag WeaponDatabase node
Weapon Switcher     → Drag WeaponSwitcher node
Weapon Inputs       → Drag WeaponInputHandler node
Weapon Visuals      → Drag WeaponVisualsManager node
Weapon Drop Pickup  → Drag WeaponDropPickup node
Weapon Health Check → Drag WeaponHealthChecker node
```

#### External Nodes Group (keep existing):
```
Player              → CharacterBody3D
Camera              → Camera3D
Camera Holder       → CameraController
Camera Recoil       → Node3D
Weapon Container    → %WeaponContainer
Hud                 → CanvasLayer
Interaction Raycast → RayCast3D
```

#### Sub-Managers Group (keep existing):
```
Shoot Manager       → %ShootManager
Reload Manager      → %ReloadManager
Ammo Manager        → %AmmunitionManager
Anim Player         → %AnimationPlayer
Anim Manager        → %AnimationManager
Link Component      → %LinkComponent
```

#### State System Group (keep existing):
```
State Machine       → StateMachine node
```

#### Systems Group (keep existing):
```
Combat Health       → CombatHealthComponent
Inventory Component → InventoryComponent
```

### 4. Configure WeaponDatabase

Move the `weaponResources` array from WeaponManager to WeaponDatabase:

**WeaponDatabase Inspector:**
```
Weapon Resources → [Array of WeaponResource]
  - Element 0: Pistol
  - Element 1: Rifle
  - Element 2: Shotgun
  - etc.
```

### 5. Configure WeaponInputHandler

**WeaponInputHandler Inspector:**
```
Shoot Action:     "fire"
Shoot Alt Action: "fire_alt"
Reload Action:    "reload"
Interact Action:  "interact"
Throw Action:     "throw"
Drop Key:         "drop_weapon"
```

### 6. Configure WeaponDropPickup

**WeaponDropPickup Inspector:**
```
Drop Force:         5.0
Drop Forward Force: 3.0
Drop Upward Force:  2.0
```

### 7. Configure WeaponVisualsManager

No exports needed - it auto-initializes from camera and container references.

### 8. Configure WeaponHealthChecker

No exports needed - it uses references passed from WeaponManager.

## Component Dependencies Diagram

```
WeaponManager
├─→ WeaponDatabase ───────┐
├─→ WeaponSwitcher        │
│   ├─ uses: Database ────┘
│   ├─ uses: Visuals
│   └─ uses: HealthChecker
├─→ WeaponInputHandler
│   ├─ uses: Switcher
│   ├─ uses: DropPickup
│   ├─ uses: HealthChecker
│   ├─ uses: ShootManager
│   └─ uses: ReloadManager
├─→ WeaponVisualsManager
│   └─ uses: Camera, Container
├─→ WeaponDropPickup
│   ├─ uses: Database
│   ├─ uses: Inventory
│   └─ uses: Player
└─→ WeaponHealthChecker
    ├─ uses: CombatHealth
    └─ uses: HUD
```

## Testing Checklist

After setup, test these features:

### Basic Functionality
- [ ] Weapons appear in scene correctly
- [ ] Can equip weapon from hotbar (press 1-8)
- [ ] Can scroll weapons with mouse wheel
- [ ] Weapon switches with proper animation
- [ ] HUD shows weapon name and ammo

### Input Controls
- [ ] Left click shoots (auto or semi-auto)
- [ ] R reloads weapon
- [ ] Hold F to unequip (0.3s)
- [ ] Drop weapon key works
- [ ] Mouse wheel scrolls through occupied slots

### Visual Effects
- [ ] Weapon kicks back on shooting
- [ ] FOV pulses on shot
- [ ] Camera smoothly returns to default
- [ ] State-based offsets work (crouch, slide, etc.)

### Drop/Pickup System
- [ ] Dropped weapon has physics
- [ ] Dropped weapon flies forward
- [ ] Can pickup dropped weapons
- [ ] Can't pickup duplicate unique weapons
- [ ] Weapons auto-equip when inventory empty

### Arm Damage System
- [ ] Can use weapon with healthy arm
- [ ] Weapon drops when arm damaged below threshold
- [ ] HUD shows arm damage warning
- [ ] Can't pickup weapons with destroyed arm
- [ ] Warning message appears on attempt

### Inventory Integration
- [ ] Weapons appear in inventory UI
- [ ] Ammo system tracks correctly
- [ ] Hotbar reflects current weapon
- [ ] Consumables work from hotbar

## Common Issues & Fixes

### "weapon_database is null"
**Fix:** Make sure WeaponDatabase node is assigned in WeaponManager inspector

### "No weapon in hotbar slot X"
**Fix:** Drag weapon from inventory to hotbar slot

### "Already have this weapon"
**Fix:** This is expected for unique weapons - working correctly

### Visual effects not working
**Fix:** Check WeaponVisualsManager has camera and container references

### Can't drop weapons
**Fix:** Check "drop_weapon" input action exists in Project Settings

### Arm damage not working
**Fix:** Ensure CombatHealthComponent is assigned and has player_health

## Performance Notes

- ✅ No performance overhead from splitting code
- ✅ Same function calls, just better organized
- ✅ All components are lightweight Node classes
- ✅ No unnecessary updates - only process when needed

## Backup Instructions

Before applying changes:
1. Duplicate your WeaponManager scene
2. Save as "WeaponManager_OLD.tscn"
3. Export your WeaponManager script to "WeaponManager_OLD.gd"
4. Then apply new modular system

## Rollback Instructions

If something breaks:
1. Delete new component nodes
2. Re-attach WeaponManager_OLD.gd script
3. Reassign all inspector references
4. Test thoroughly

## Next Steps

After successful setup:
1. Test all weapon functionality
2. Verify inventory integration
3. Test arm damage system
4. Check HUD updates correctly
5. Test in different player states

## Need Help?

Common debugging steps:
1. Check Output console for error messages
2. Verify all node references are assigned
3. Ensure scripts are attached correctly
4. Test one component at a time
5. Use print() statements to trace flow

## Future Enhancements

Easy additions with this architecture:
- **WeaponModSystem.gd** - Attachments, scopes, grips
- **WeaponUpgradeSystem.gd** - Damage/accuracy upgrades
- **WeaponSkinSystem.gd** - Visual customization
- **WeaponAudioSystem.gd** - Advanced sound FX
- **WeaponParticleSystem.gd** - Shell casings, smoke
