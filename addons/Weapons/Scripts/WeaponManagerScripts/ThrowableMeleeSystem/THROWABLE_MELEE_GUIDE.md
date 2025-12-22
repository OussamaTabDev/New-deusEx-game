# Throwables & Melee Combat System

## Overview
Complete throwable and melee combat system integrated with your existing weapon manager.

## Components Created

### 1. **ThrowableSystem.gd**
Handles all throwable items (grenades, knives, molotovs)
- Grenade cooking mechanic
- Trajectory preview
- Multiple throwable types
- Physics-based throwing

### 2. **MeleeSystem.gd**
Full melee combat system
- Light/heavy attacks
- Combo system
- Blocking and parrying
- Fist combat (unarmed)
- Cone-based hit detection

### 3. **GrenadeProjectile.gd**
Spawned grenade instance
- Fuse timer with cooking
- Explosion damage with falloff
- Physics-based explosion force
- Beeping audio feedback

### 4. **KnifeProjectile.gd**
Thrown knife instance
- Sticks to surfaces
- Aligns to flight direction
- Trail effects
- Damage on impact

### 5. **MeleeWeaponResource.gd**
Resource definition for melee weapons
- Stats (damage, speed, range)
- Attack types and combos
- Blocking properties
- Animations and sounds

### 6. **CombatInputHandler.gd**
Unified combat input coordinator
- Routes inputs based on mode
- Handles mode switching
- Quick melee from any mode

## Scene Setup

### Add Components to Player

```
Player
├── WeaponManager
│   └── (existing components)
├── CombatSystem (Node)
│   ├── ThrowableSystem (Node)
│   ├── MeleeSystem (Node)
│   └── CombatInputHandler (Node)
└── (other components)
```

### Inspector Configuration

#### ThrowableSystem:
```
Weapon Manager      → WeaponManager node
Inventory Component → InventoryComponent
Player              → Player (CharacterBody3D)
Camera              → Camera3D

Throw Force         → 15.0
Throw Upward Angle  → 15.0
Max Throw Distance  → 30.0
Trajectory Preview  → true
Trajectory Points   → 20
```

#### MeleeSystem:
```
Weapon Manager      → WeaponManager node
Player              → Player (CharacterBody3D)
Camera              → Camera3D
Animation Manager   → AnimationManager node
Combat Health       → CombatHealthComponent

Melee Range         → 2.0
Melee Angle         → 60.0
Combo Window        → 0.5
Heavy Charge Time   → 1.0
Block Damage Reduction → 0.5
Hit Layers          → 1 (Physics layer mask)
Show Hit Indicator  → true
```

#### CombatInputHandler:
```
Weapon Input Handler → WeaponInputHandler
Throwable System    → ThrowableSystem
Melee System        → MeleeSystem
Inventory Component → InventoryComponent
State Machine       → StateMachine

Fire Action         → "fire"
Fire Alt Action     → "fire_alt"
Reload Action       → "reload"
Melee Action        → "melee"
Throw Action        → "throw"
Block Action        → "block"
```

## Input Map Setup

Add these actions to Project Settings → Input Map:

```
melee        → Left Click (or dedicated key)
throw        → G key
block        → Right Click (when melee equipped)
fire_alt     → Right Click (heavy attack/scope)
```

## Creating Throwable Items

### Example: Frag Grenade

1. **Create Grenade Scene:**
```
GrenadeProjectile (RigidBody3D)
├── MeshInstance3D (your grenade model)
├── CollisionShape3D (SphereShape3D)
├── AudioPlayer (AudioStreamPlayer3D)
└── BeepTimer (Timer)
```

2. **Attach GrenadeProjectile.gd**

3. **Configure Inspector:**
```
Damage          → 100
Blast Radius    → 5.0
Fuse Time       → 3.0
Explosion Force → 20.0
Explosion Scene → (your explosion effect)
Beep Sound      → (beep audio)
Explosion Sound → (boom audio)
```

4. **Add to ItemDatabase:**
```gdscript
{
    "id": "grenade_frag",
    "display_name": "Frag Grenade",
    "type": "throwable",
    "stackable": true,
    "max_stack": 5,
    "attributes": {
        "throw_type": "grenade",
        "throwable_scene": "res://Weapons/Throwables/FragGrenade.tscn",
        "damage": 100,
        "blast_radius": 5.0,
        "fuse_time": 3.0,
        "max_cook_time": 3.0
    }
}
```

### Example: Throwing Knife

1. **Create Knife Scene:**
```
KnifeProjectile (RigidBody3D)
├── MeshInstance3D (knife model, pointy end forward)
├── CollisionShape3D (BoxShape3D)
└── AudioPlayer (AudioStreamPlayer3D)
```

2. **Attach KnifeProjectile.gd**

3. **Configure:**
```
Damage          → 50
Stick On Hit    → true
Despawn Time    → 10.0
Impact Sound    → (thud sound)
Whoosh Sound    → (whoosh sound)
```

4. **Add to ItemDatabase:**
```gdscript
{
    "id": "knife_throwing",
    "display_name": "Throwing Knife",
    "type": "throwable",
    "stackable": true,
    "max_stack": 10,
    "attributes": {
        "throw_type": "knife",
        "throwable_scene": "res://Weapons/Throwables/ThrowingKnife.tscn",
        "damage": 50,
        "is_throwable": true
    }
}
```

## Creating Melee Weapons

### Example: Combat Knife

1. **Create MeleeWeaponResource:**
Right-click in FileSystem → New Resource → MeleeWeaponResource

2. **Configure Resource:**
```
Melee ID         → 1
Weapon Name      → "Combat Knife"
Weapon Type      → "knife"
Damage           → 35.0
Attack Speed     → 0.4
Range            → 2.0
Knockback        → 3.0
Stamina Cost     → 8.0
Damage Type      → "pierce"

Has Light Attack → true
Has Heavy Attack → true
Can Block        → false
Max Combo        → 3

Light Attack Anims → ["knife_slash_1", "knife_slash_2", "knife_stab"]
Heavy Attack Anim  → "knife_heavy_stab"
```

3. **Add to ItemDatabase:**
```gdscript
{
    "id": "knife_combat",
    "display_name": "Combat Knife",
    "type": "melee",
    "stackable": false,
    "attributes": {
        "is_melee": true,
        "melee_id": 1,
        "damage": 35,
        "damage_type": "pierce"
    }
}
```

### Example: Baseball Bat

```
Melee ID         → 2
Weapon Name      → "Baseball Bat"
Weapon Type      → "bat"
Damage           → 45.0
Attack Speed     → 0.7
Range            → 2.5
Knockback        → 8.0
Damage Type      → "blunt"

Can Block        → true
Block Damage Reduction → 0.6
```

## Usage Examples

### Throwing Grenades:
1. Add grenade to inventory
2. Place in hotbar
3. Press G to start cooking
4. Aim (trajectory shows)
5. Release G to throw
6. Grenade explodes after fuse time

### Melee Combat:
1. Equip melee weapon (or go unarmed)
2. Left click for light attacks
3. Build combo (up to max_combo)
4. Hold Right Click to charge heavy
5. Release Right Click for heavy attack
6. Right Click (tap) to block incoming damage

### Quick Melee:
- Press melee button while holding gun
- Performs quick melee attack
- Doesn't switch from gun

## Advanced Features

### Grenade Cooking
```gdscript
# Hold throw button
is_cooking = true
cook_start_time = current_time

# Release when ready
execute_throw()
# Grenade has less fuse time based on cook_time
```

### Combo System
```gdscript
# Each light attack increments combo
combo_count += 1  # 1, 2, 3

# Plays different animation per combo
anim = "attack_light_%d" % combo_count

# Reset if too much time passes
if time_since_last > combo_window:
    combo_count = 0
```

### Blocking
```gdscript
# Hold block button
melee_system.start_block()

# When hit while blocking:
blocked_damage = incoming_damage * block_damage_reduction
consume_stamina(incoming_damage * 0.5)
```

### Trajectory Preview
```gdscript
# Shows arc while cooking grenade
for i in range(trajectory_points):
    time = i * time_step
    pos = start + velocity * time
    pos.y -= 0.5 * gravity * time * time
    line.add_point(pos)
```

## Combat Modes

The system automatically detects combat mode:

```
RANGED    → Gun equipped → Fire shoots, melee is quick attack
MELEE     → Melee equipped → Fire is light attack, alt is heavy
THROWABLE → Throwing → Trajectory preview, release to throw
UNARMED   → Nothing equipped → Punches/kicks
```

## Animation Requirements

### Melee Animations:
- `attack_light_1` - First combo attack
- `attack_light_2` - Second combo attack
- `attack_light_3` - Third combo attack
- `attack_heavy` - Heavy attack
- `heavy_charge` - Charging heavy (looping)
- `block_start` - Raise guard
- `block` - Hold guard (looping)
- `block_end` - Lower guard

### Fist Animations:
- `punch_1` - Jab
- `punch_2` - Cross
- `punch_3` - Hook

### Throwable Animations:
- `pull_pin` - Pull grenade pin
- `throw` - Throw motion

## Damage Types

```
"slash"     → Swords, knives (slashing)
"pierce"    → Stabbing, arrows
"blunt"     → Bats, hammers, fists
"explosive" → Grenades, bombs
```

## Hit Detection

### Melee:
- Cone-based multi-raycast
- Configurable angle and range
- Detects multiple targets
- Line of sight required

### Grenade:
- Sphere overlap query
- Distance-based falloff
- Applies explosion force
- Damages through walls (optional)

## Events & Signals

You can add signals for:
```gdscript
signal throwable_thrown(item, trajectory)
signal grenade_exploded(position, damage)
signal melee_hit(target, damage, combo)
signal combo_broken()
signal heavy_attack_charged()
signal block_successful(damage_blocked)
```

## HUD Integration

Display combat state:
```gdscript
var state = combat_input_handler.get_combat_state()

# Show:
- Grenade cook timer
- Combo counter
- Block stamina bar
- Trajectory line
- Heavy charge indicator
```

## Tips & Best Practices

1. **Melee Range:** Keep around 2.0 - 2.5 units
2. **Combo Window:** 0.4 - 0.6 seconds feels good
3. **Heavy Charge:** 0.8 - 1.2 seconds minimum
4. **Grenade Cook:** 2-4 seconds fuse time
5. **Trajectory Points:** 15-25 for smooth preview
6. **Hit Detection:** Use 5-7 rays for cone

## Troubleshooting

### Grenades don't explode:
- Check fuse_time is set
- Verify explosion_scene is assigned
- Check timer is starting in _ready()

### Melee doesn't hit:
- Check melee_range
- Verify hit_layers matches target layer
- Check camera is assigned
- Print raycast results for debugging

### Trajectory doesn't show:
- Enable trajectory_preview
- Check Line3D material
- Verify throw_preview_enabled is true

### Blocking doesn't work:
- Check can_block in MeleeWeaponResource
- Verify block_action input exists
- Check is_blocking state

## Performance Notes

- Trajectory only updates while cooking
- Hit detection is raycast-based (fast)
- Grenades clean up after explosion
- Stuck knives despawn after time

## Next Steps

1. Create your grenade/knife scenes
2. Add throwable items to ItemDatabase
3. Create MeleeWeaponResources
4. Setup animations
5. Configure input actions
6. Add hit effects and sounds
7. Test each combat mode
