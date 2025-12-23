# Complete Melee & Throwable System - Setup Guide

## 📦 What You're Getting

A complete combat system that seamlessly integrates:
- ✅ **Firearms** (existing system)
- ✅ **Melee Weapons** (swords, axes, fists, etc.)
- ✅ **Throwables** (grenades, knives, molotovs, flashbangs)

All managed through a **unified hotbar system** with smart switching!

---

## 📁 File Structure

```
Your Project/
├── Resources/
│   ├── MeleeWeaponResource.gd       # Defines melee weapons
│   └── ThrowableResource.gd          # Defines throwables
│
├── Systems/
│   ├── MeleeSystem.gd                # Melee combat logic
│   ├── ThrowableSystem.gd            # Throwable mechanics
│   ├── UnifiedCombatHandler.gd       # Switches between all types
│   ├── MeleeDatabase.gd              # Stores melee resources
│   └── ThrowableDatabase.gd          # Stores throwable resources
│
├── Projectiles/
│   ├── GrenadeProjectile.gd          # Spawned grenade
│   └── KnifeProjectile.gd            # Spawned knife/axe
│
└── WeaponManager_Integrated.gd       # Updated main manager
```

---

## 🎯 Scene Hierarchy

```
WeaponManager (Node3D)
├── WeaponDatabase (Node)
├── WeaponSwitcher (Node)
├── WeaponInputHandler (Node)
├── WeaponVisualsManager (Node)
├── WeaponDropPickup (Node)
├── WeaponHealthChecker (Node)
│
├── MeleeSystem (Node) ⭐ NEW
├── ThrowableSystem (Node) ⭐ NEW
├── MeleeDatabase (Node) ⭐ NEW
├── ThrowableDatabase (Node) ⭐ NEW
├── UnifiedCombatHandler (Node) ⭐ NEW
│
├── WeaponContainer (Node3D)
├── ShootManager (existing)
├── ReloadManager (existing)
├── AmmunitionManager (existing)
└── AnimationManager (existing)
```

---

## 🚀 Step-by-Step Setup

### Step 1: Add New Scripts to WeaponManager

1. **Add child nodes** to your WeaponManager:
   - Create `MeleeSystem` (Node) → Attach `MeleeSystem.gd`
   - Create `ThrowableSystem` (Node) → Attach `ThrowableSystem.gd`
   - Create `MeleeDatabase` (Node) → Attach `MeleeDatabase.gd`
   - Create `ThrowableDatabase` (Node) → Attach `ThrowableDatabase.gd`
   - Create `UnifiedCombatHandler` (Node) → Attach `UnifiedCombatHandler.gd`

2. **Replace WeaponManager.gd** with `WeaponManager_Integrated.gd`

### Step 2: Create Resource Files

#### Create Melee Weapons

1. Create a new `.tres` file in your project
2. Set Resource Type to `MeleeWeaponResource`
3. Configure stats:

```gdscript
# Example: Sword
weapon_id: 1
weapon_name: "Sword"
light_damage: 35.0
heavy_damage: 70.0
attack_range: 2.5
max_combo_hits: 3
can_block: true
can_charge: true
```

4. **Add to MeleeDatabase:**
   - Select MeleeDatabase node
   - In Inspector → `melee_resources` → Add your `.tres` file

#### Create Throwables

1. Create a new `.tres` file
2. Set Resource Type to `ThrowableResource`
3. Configure:

```gdscript
# Example: Grenade
throwable_id: 1
throwable_name: "Frag Grenade"
throwable_type: GRENADE
can_cook: true
fuse_time: 3.0
explosion_damage: 100.0
explosion_radius: 8.0
```

4. **Add to ThrowableDatabase:**
   - Select ThrowableDatabase node
   - In Inspector → `throwable_resources` → Add your `.tres` file

### Step 3: Setup Projectile Scenes

#### Grenade Scene
```
GrenadeProjectile (RigidBody3D)
├── CollisionShape3D (SphereShape3D)
├── MeshInstance3D (Visual model)
└── AudioStreamPlayer3D (Beeping sound)
```
- Attach `GrenadeProjectile.gd`
- Set Mass to 0.5
- Enable Contact Monitor
- Set Max Contacts to 10

#### Knife Scene
```
KnifeProjectile (RigidBody3D)
├── CollisionShape3D (BoxShape3D or CapsuleShape3D)
├── MeshInstance3D (Knife model)
└── GPUParticles3D (Trail effect)
```
- Attach `KnifeProjectile.gd`
- Set Mass to 0.3
- Enable Contact Monitor

### Step 4: Configure Input Actions

Add these to **Project Settings → Input Map:**

```
block (Right Mouse Button)
```

Existing actions should work:
- `fire` (Left Mouse) - Shoot/Light Attack/Cook Grenade
- `fire_alt` (Right Mouse Alt) - Heavy Attack/Cancel Cook
- `reload` (R) - Still for weapons

### Step 5: Setup Inventory Items

#### Add Melee Items to Inventory
```gdscript
# Example inventory item
var sword_item = InventoryItem.new()
sword_item.id = "melee_sword"
sword_item.display_name = "Iron Sword"
sword_item.type = "melee"
sword_item.attributes = {
    "melee_id": 1  # Must match MeleeWeaponResource.weapon_id
}
```

#### Add Throwable Items
```gdscript
var grenade_item = InventoryItem.new()
grenade_item.id = "throwable_grenade"
grenade_item.display_name = "Frag Grenade"
grenade_item.type = "throwable"
grenade_item.stackable = true
grenade_item.stack_count = 3
grenade_item.attributes = {
    "throwable_id": 1  # Must match ThrowableResource.throwable_id
}
```

### Step 6: Export Variables in Inspector

**WeaponManager Inspector:**
- Assign `stamina_system` (if you have one)

**MeleeSystem Inspector:**
- All set automatically via code

**ThrowableSystem Inspector:**
- All set automatically

---

## 🎮 How It Works

### Unified Hotbar Switching

**Press Number Keys (1-8):**
- Slot has **weapon** → Equips firearm
- Slot has **melee** → Equips melee weapon
- Slot has **throwable** → Equips throwable

The system automatically:
- ✅ Detects item type
- ✅ Clears previous combat mode
- ✅ Loads appropriate system
- ✅ Updates HUD

### Combat Controls

#### Firearms
- **Left Click** - Shoot
- **R** - Reload
- **Mouse Wheel** - Switch weapons

#### Melee
- **Left Click** - Light attack
- **Hold Left Click** - Charge heavy attack
- **Release** - Unleash charged attack
- **Right Click** - Block
- **Combo** - Attack within timing window

#### Throwables
- **Hold Left Click** - Cook grenade
- **Release** - Throw
- **Right Click** - Cancel cooking
- **Trajectory Preview** - Shows throw arc

---

## 🔥 Feature Highlights

### Melee System
✅ **3-Hit Combo Chain** - Attack quickly for combos
✅ **Charge Heavy Attacks** - Hold to power up
✅ **Blocking System** - Reduce incoming damage
✅ **Perfect Block Window** - Time it right for 95% reduction
✅ **Backstab Detection** - Extra damage from behind
✅ **Execute System** - Finish low-health enemies
✅ **Stamina Integration** - Attacks cost stamina
✅ **Multi-Target Cone Detection** - Hit multiple enemies

### Throwable System
✅ **Grenade Cooking** - Hold to reduce fuse
✅ **Auto-Throw at Max** - Safety feature
✅ **Real-Time Trajectory Preview** - See where it'll land
✅ **Physics-Based Throwing** - Realistic arc
✅ **Multiple Types:**
  - 💥 Frag Grenades (explosion damage)
  - 🔥 Molotovs (fire area damage)
  - ⚡ Flashbangs (blind enemies)
  - 💨 Smoke Grenades (visual cover)
  - 🗡️ Knives (stick to surfaces/enemies)
  - 🪓 Axes (throwable melee)

### Grenade Features
✅ **Damage Falloff** - Less damage at edge
✅ **Physics Force** - Ragdolls and objects fly
✅ **Beeping Audio** - Speeds up near explosion
✅ **Fire Areas** - Molotovs create burning zones
✅ **Flash Effects** - Flashbangs blind players/enemies

### Knife/Axe Features
✅ **Stick to Surfaces** - Embed in walls/enemies
✅ **Bleed Damage** - Damage over time when stuck
✅ **Trail Effects** - Visual while flying
✅ **Auto-Align** - Rotates to flight direction

---

## 💻 Code Examples

### Creating a Melee Weapon Resource
```gdscript
# res://Resources/Melee/Sword.tres
extends MeleeWeaponResource

@export_group("Basic Info")
weapon_id = 1
weapon_name = "Iron Sword"

@export_group("Combat Stats")
light_damage = 35.0
heavy_damage = 70.0
attack_range = 2.5
attack_cone_angle = 90.0

@export_group("Combo")
max_combo_hits = 3
combo_timeout = 1.5
combo_damage_multiplier = 1.3

@export_group("Blocking")
can_block = true
block_damage_reduction = 0.7

@export_group("Special")
can_backstab = true
backstab_damage_multiplier = 2.5
```

### Creating a Throwable Resource
```gdscript
# res://Resources/Throwables/FragGrenade.tres
extends ThrowableResource

@export_group("Basic Info")
throwable_id = 1
throwable_name = "Frag Grenade"
throwable_type = ThrowableType.GRENADE

@export_group("Cooking")
can_cook = true
fuse_time = 3.0
auto_throw_at_max = true

@export_group("Damage")
explosion_damage = 100.0
explosion_radius = 8.0
damage_falloff = true

@export_group("Physics")
throw_force = 15.0
explosion_force = 1000.0
```

### Using from Code
```gdscript
# Check current combat type
if weapon_manager.is_using_melee():
    print("Player is using melee!")

# Get combat mode
var mode = weapon_manager.get_combat_type()
match mode:
    UnifiedCombatHandler.CombatType.WEAPON:
        print("Shooting")
    UnifiedCombatHandler.CombatType.MELEE:
        print("Melee combat")
    UnifiedCombatHandler.CombatType.THROWABLE:
        print("Throwing")
```

---

## 🐛 Troubleshooting

### Melee not attacking
- ✅ Check `stamina_system` is assigned
- ✅ Verify melee_id in inventory matches resource
- ✅ Ensure state_machine allows combat (can_shoot = true)

### Grenade not exploding
- ✅ Check `projectile_scene` is set in ThrowableResource
- ✅ Verify GrenadeProjectile script is attached
- ✅ Ensure `initialize()` is called

### Trajectory not showing
- ✅ Check `show_trajectory = true` in ThrowableResource
- ✅ Verify camera reference is set

### Knife not sticking
- ✅ Set `can_stick = true` in ThrowableResource
- ✅ Check collision layers/masks
- ✅ Enable Contact Monitor on RigidBody3D

---

## 🎨 HUD Integration

Your HUD should implement these optional methods for full integration:

```gdscript
# HUD.gd
func show_combo(current: int, max: int):
    combo_label.text = "COMBO x%d" % current

func show_charge(percent: float):
    charge_bar.value = percent * 100

func show_status(text: String):
    status_label.text = text

func show_cook_timer(time: float):
    cook_label.text = "%.1fs" % time
```

---

## 🔄 Migration from Old WeaponManager

1. **Backup** your current WeaponManager.gd
2. **Replace** with WeaponManager_Integrated.gd
3. **Add** 5 new child nodes (see hierarchy)
4. **Test** firearms still work
5. **Add** melee and throwable resources
6. **Configure** inventory items
7. **Test** all combat types

---

## 🎯 Next Steps

1. ✅ Setup scene hierarchy
2. ✅ Create melee weapon resources
3. ✅ Create throwable resources
4. ✅ Setup projectile scenes
5. ✅ Add inventory items
6. ✅ Test all three combat types
7. ✅ Polish animations and effects

---

## 📝 Summary

You now have a **complete unified combat system** with:
- **Firearms** (shooting, reloading, ammo)
- **Melee** (combos, blocking, backstabs)
- **Throwables** (cooking, trajectory, explosions)

All managed through **one hotbar** with **smart type detection**!

🎉 **Happy Coding!**
