# Quick Setup Checklist

## Step-by-Step Setup Guide

### 1. Backup Original
- [ ] Save a backup of your original WeaponManager.gd
- [ ] Test your current system works before migrating

### 2. Create Files
- [ ] Create `WeaponManager.gd` (main coordinator)
- [ ] Create `WeaponDatabase.gd`
- [ ] Create `WeaponSwitcher.gd`
- [ ] Create `WeaponInputHandler.gd`
- [ ] Create `WeaponVisualsManager.gd`
- [ ] Create `WeaponDropPickup.gd`
- [ ] Create `WeaponHealthChecker.gd`

### 3. Setup Scene Hierarchy

**In your scene tree:**
```
YourPlayer
└── WeaponManager (Node3D) <- Attach WeaponManager.gd
    ├── WeaponDatabase (Node) <- Attach WeaponDatabase.gd
    ├── WeaponSwitcher (Node) <- Attach WeaponSwitcher.gd
    ├── WeaponInputHandler (Node) <- Attach WeaponInputHandler.gd
    ├── WeaponVisualsManager (Node) <- Attach WeaponVisualsManager.gd
    ├── WeaponDropPickup (Node) <- Attach WeaponDropPickup.gd
    ├── WeaponHealthChecker (Node) <- Attach WeaponHealthChecker.gd
    ├── WeaponContainer (Node3D) <- Your existing container
    ├── ShootManager <- Your existing manager
    ├── ReloadManager <- Your existing manager
    ├── AmmunitionManager <- Your existing manager
    └── AnimationManager <- Your existing manager
```

### 4. Configure WeaponManager Inspector

**Assign these exported variables:**

#### Managers Section
- [ ] `shootManager` → Your ShootManager node
- [ ] `reloadManager` → Your ReloadManager node
- [ ] `ammoManager` → Your AmmunitionManager node
- [ ] `animManager` → Your AnimationManager node

#### Node References Section
- [ ] `player` → Your CharacterBody3D
- [ ] `state_machine` → Your StateMachine node
- [ ] `cameraHolder` → Your CameraController
- [ ] `cameraRecoilHolder` → Your camera recoil node
- [ ] `camera` → Your Camera3D
- [ ] `weaponContainer` → Your weapon container Node3D
- [ ] `animPlayer` → Your AnimationPlayer
- [ ] `hud` → Your HUD CanvasLayer
- [ ] `linkComponent` → Your link component
- [ ] `combat_health` → Your CombatHealthComponent
- [ ] `interaction_raycast` → Your interaction RayCast3D
- [ ] `inventory_component` → Your InventoryComponent

### 5. Configure WeaponDatabase

**In WeaponDatabase Inspector:**
- [ ] Set `weaponResources` array with all your weapon resources
- [ ] Verify all weapon IDs are unique
- [ ] Test that weapons load correctly

### 6. Configure Input Actions

**Verify in Project Settings → Input Map:**
- [ ] `fire` action exists
- [ ] `fire_alt` action exists
- [ ] `reload` action exists
- [ ] `interact` action exists (F key)
- [ ] `throw` action exists
- [ ] `drop_weapon` action exists

### 7. Configure Drop Settings (Optional)

**In WeaponDropPickup node Inspector:**
- [ ] `drop_force` (default: 5.0)
- [ ] `drop_forward_force` (default: 3.0)
- [ ] `drop_upward_force` (default: 2.0)

### 8. Test Basic Functions

- [ ] Start game - no errors in console
- [ ] Pick up a weapon
- [ ] Switch weapons with number keys (1-8)
- [ ] Scroll weapons with mouse wheel
- [ ] Shoot current weapon
- [ ] Reload current weapon
- [ ] Drop weapon with drop key
- [ ] Hold F to unequip

### 9. Test Advanced Functions

- [ ] Visual recoil appears when shooting
- [ ] Muzzle flash displays
- [ ] Bullet holes appear
- [ ] Weapon sounds play
- [ ] FOV kick works
- [ ] Health system integration (if applicable)
- [ ] Arm damage prevents weapon use (if applicable)

### 10. Common Issues & Solutions

#### Components not found
**Problem:** "Invalid get index 'database'" or similar
**Solution:** 
- Check node names match exactly (WeaponDatabase, WeaponSwitcher, etc.)
- Verify nodes are direct children of WeaponManager
- Make sure scripts are attached correctly

#### Weapons won't switch
**Problem:** Pressing number keys does nothing
**Solution:**
- Check inventory_component is assigned
- Verify weapons are in the hotbar
- Ensure weapon IDs match between inventory and database

#### Visual effects missing
**Problem:** No recoil, muzzle flash, or sounds
**Solution:**
- Verify weapon_container reference is set
- Check camera reference is assigned
- Confirm preloaded scenes paths are correct

#### Input not working
**Problem:** Can't shoot or reload
**Solution:**
- Verify all input actions exist in Project Settings
- Check state_machine allows shooting (can_shoot = true)
- Ensure canUseWeapon = true

### 11. Performance Check

- [ ] No lag when switching weapons
- [ ] Smooth visual effects
- [ ] No memory leaks (check with profiler)
- [ ] Console shows no warnings

### 12. Final Verification

- [ ] All original features work
- [ ] No errors in console during gameplay
- [ ] Code is cleaner and more organized
- [ ] Each component is independent
- [ ] Easy to locate specific functionality

## Success Criteria

✅ **You're done when:**
1. All weapons can be picked up
2. All weapons can be switched via hotbar
3. Shooting, reloading work perfectly
4. Visual effects appear correctly
5. Dropping weapons works
6. Health system integration works (if applicable)
7. No errors in console
8. Code is easier to read and maintain

## Rollback Plan

**If something goes wrong:**
1. Stop the game
2. Close Godot
3. Restore your backed-up WeaponManager.gd
4. Reopen Godot
5. Check the specific error
6. Fix in the modular version
7. Try again

## Support

If you encounter issues:
1. Check console for error messages
2. Verify all references are assigned
3. Compare with original functionality
4. Test one component at a time
5. Check node names and hierarchy

## Notes

- Keep your original WeaponManager.gd until you're confident the new system works
- Test incrementally - don't change everything at once
- If a feature doesn't work, compare with the original code
- Each component should work independently
