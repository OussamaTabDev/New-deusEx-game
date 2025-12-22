# Example ItemDatabase Entries

## Copy these to your ItemDatabase.gd

```gdscript
# ====================
# THROWABLE ITEMS
# ====================

items["grenade_frag"] = {
    "id": "grenade_frag",
    "display_name": "Frag Grenade",
    "description": "High explosive fragmentation grenade. Cook for 3 seconds.",
    "type": "throwable",
    "icon": preload("res://UI/Icons/grenade_frag.png"),
    "scene_path": "res://Weapons/Throwables/FragGrenade.tscn",
    "width": 1,
    "height": 1,
    "stackable": true,
    "max_stack": 5,
    "weight": 0.4,
    "value": 50,
    "attributes": {
        "throw_type": "grenade",
        "throwable_scene": "res://Weapons/Throwables/FragGrenade.tscn",
        "damage": 100,
        "blast_radius": 5.0,
        "fuse_time": 3.0,
        "max_cook_time": 3.0,
        "is_throwable": true
    }
}

items["grenade_smoke"] = {
    "id": "grenade_smoke",
    "display_name": "Smoke Grenade",
    "description": "Creates a smoke screen for 10 seconds.",
    "type": "throwable",
    "icon": preload("res://UI/Icons/grenade_smoke.png"),
    "scene_path": "res://Weapons/Throwables/SmokeGrenade.tscn",
    "width": 1,
    "height": 1,
    "stackable": true,
    "max_stack": 5,
    "weight": 0.3,
    "value": 30,
    "attributes": {
        "throw_type": "grenade",
        "throwable_scene": "res://Weapons/Throwables/SmokeGrenade.tscn",
        "damage": 0,
        "fuse_time": 2.0,
        "smoke_duration": 10.0,
        "smoke_radius": 8.0,
        "is_throwable": true
    }
}

items["grenade_flashbang"] = {
    "id": "grenade_flashbang",
    "display_name": "Flashbang",
    "description": "Blinds and deafens enemies in a 6m radius.",
    "type": "throwable",
    "icon": preload("res://UI/Icons/grenade_flash.png"),
    "scene_path": "res://Weapons/Throwables/Flashbang.tscn",
    "width": 1,
    "height": 1,
    "stackable": true,
    "max_stack": 5,
    "weight": 0.3,
    "value": 40,
    "attributes": {
        "throw_type": "flashbang",
        "throwable_scene": "res://Weapons/Throwables/Flashbang.tscn",
        "damage": 5,
        "blast_radius": 6.0,
        "fuse_time": 1.5,
        "blind_duration": 5.0,
        "is_throwable": true
    }
}

items["molotov"] = {
    "id": "molotov",
    "display_name": "Molotov Cocktail",
    "description": "Creates a fire area that damages over time.",
    "type": "throwable",
    "icon": preload("res://UI/Icons/molotov.png"),
    "scene_path": "res://Weapons/Throwables/Molotov.tscn",
    "width": 1,
    "height": 1,
    "stackable": true,
    "max_stack": 3,
    "weight": 0.5,
    "value": 35,
    "attributes": {
        "throw_type": "molotov",
        "throwable_scene": "res://Weapons/Throwables/Molotov.tscn",
        "damage": 15,  # Per tick
        "damage_tick_rate": 0.5,
        "fire_duration": 8.0,
        "fire_radius": 4.0,
        "is_throwable": true
    }
}

items["knife_throwing"] = {
    "id": "knife_throwing",
    "display_name": "Throwing Knife",
    "description": "Balanced knife designed for throwing.",
    "type": "throwable",
    "icon": preload("res://UI/Icons/knife_throwing.png"),
    "scene_path": "res://Weapons/Throwables/ThrowingKnife.tscn",
    "width": 1,
    "height": 2,
    "stackable": true,
    "max_stack": 10,
    "weight": 0.2,
    "value": 15,
    "attributes": {
        "throw_type": "knife",
        "throwable_scene": "res://Weapons/Throwables/ThrowingKnife.tscn",
        "damage": 50,
        "is_throwable": true
    }
}

items["axe_throwing"] = {
    "id": "axe_throwing",
    "display_name": "Throwing Axe",
    "description": "Heavy throwing axe. High damage but slower throw.",
    "type": "throwable",
    "icon": preload("res://UI/Icons/axe_throwing.png"),
    "scene_path": "res://Weapons/Throwables/ThrowingAxe.tscn",
    "width": 2,
    "height": 2,
    "stackable": true,
    "max_stack": 5,
    "weight": 1.0,
    "value": 40,
    "attributes": {
        "throw_type": "throwable_weapon",
        "throwable_scene": "res://Weapons/Throwables/ThrowingAxe.tscn",
        "damage": 80,
        "is_throwable": true
    }
}

items["shuriken"] = {
    "id": "shuriken",
    "display_name": "Shuriken",
    "description": "Ninja throwing star. Fast but low damage.",
    "type": "throwable",
    "icon": preload("res://UI/Icons/shuriken.png"),
    "scene_path": "res://Weapons/Throwables/Shuriken.tscn",
    "width": 1,
    "height": 1,
    "stackable": true,
    "max_stack": 20,
    "weight": 0.05,
    "value": 5,
    "attributes": {
        "throw_type": "throwable_weapon",
        "throwable_scene": "res://Weapons/Throwables/Shuriken.tscn",
        "damage": 25,
        "is_throwable": true
    }
}

# ====================
# MELEE WEAPONS
# ====================

items["knife_combat"] = {
    "id": "knife_combat",
    "display_name": "Combat Knife",
    "description": "Military-grade combat knife. Fast attacks with piercing damage.",
    "type": "melee",
    "icon": preload("res://UI/Icons/knife_combat.png"),
    "scene_path": "res://Weapons/Melee/CombatKnife.tscn",
    "width": 1,
    "height": 2,
    "stackable": false,
    "weight": 0.3,
    "value": 150,
    "attributes": {
        "is_melee": true,
        "melee_id": 1,
        "damage": 35,
        "attack_speed": 0.4,
        "range": 2.0,
        "damage_type": "pierce",
        "can_block": false,
        "can_backstab": true
    }
}

items["bat_baseball"] = {
    "id": "bat_baseball",
    "display_name": "Baseball Bat",
    "description": "Wooden bat. Good reach and knockback.",
    "type": "melee",
    "icon": preload("res://UI/Icons/bat_baseball.png"),
    "scene_path": "res://Weapons/Melee/BaseballBat.tscn",
    "width": 1,
    "height": 3,
    "stackable": false,
    "weight": 1.2,
    "value": 80,
    "attributes": {
        "is_melee": true,
        "melee_id": 2,
        "damage": 45,
        "attack_speed": 0.7,
        "range": 2.5,
        "knockback": 8.0,
        "damage_type": "blunt",
        "can_block": true,
        "block_damage_reduction": 0.6
    }
}

items["sword_katana"] = {
    "id": "sword_katana",
    "display_name": "Katana",
    "description": "Japanese sword. High damage with fast combos.",
    "type": "melee",
    "icon": preload("res://UI/Icons/sword_katana.png"),
    "scene_path": "res://Weapons/Melee/Katana.tscn",
    "width": 1,
    "height": 3,
    "stackable": false,
    "weight": 1.5,
    "value": 500,
    "attributes": {
        "is_melee": true,
        "melee_id": 3,
        "damage": 60,
        "attack_speed": 0.5,
        "range": 2.8,
        "knockback": 4.0,
        "damage_type": "slash",
        "can_block": true,
        "can_parry": true,
        "max_combo": 4,
        "block_damage_reduction": 0.7
    }
}

items["axe_fire"] = {
    "id": "axe_fire",
    "display_name": "Fire Axe",
    "description": "Heavy firefighter axe. Slow but devastating damage.",
    "type": "melee",
    "icon": preload("res://UI/Icons/axe_fire.png"),
    "scene_path": "res://Weapons/Melee/FireAxe.tscn",
    "width": 2,
    "height": 3,
    "stackable": false,
    "weight": 3.0,
    "value": 200,
    "attributes": {
        "is_melee": true,
        "melee_id": 4,
        "damage": 75,
        "attack_speed": 1.0,
        "range": 2.6,
        "knockback": 12.0,
        "damage_type": "slash",
        "heavy_damage_multiplier": 3.0,
        "can_block": false
    }
}

items["crowbar"] = {
    "id": "crowbar",
    "display_name": "Crowbar",
    "description": "Versatile tool. Medium damage and speed.",
    "type": "melee",
    "icon": preload("res://UI/Icons/crowbar.png"),
    "scene_path": "res://Weapons/Melee/Crowbar.tscn",
    "width": 1,
    "height": 2,
    "stackable": false,
    "weight": 1.8,
    "value": 50,
    "attributes": {
        "is_melee": true,
        "melee_id": 5,
        "damage": 40,
        "attack_speed": 0.6,
        "range": 2.2,
        "knockback": 6.0,
        "damage_type": "blunt",
        "can_block": true,
        "can_break_doors": true
    }
}

items["machete"] = {
    "id": "machete",
    "display_name": "Machete",
    "description": "Jungle blade. Fast slashing attacks.",
    "type": "melee",
    "icon": preload("res://UI/Icons/machete.png"),
    "scene_path": "res://Weapons/Melee/Machete.tscn",
    "width": 1,
    "height": 3,
    "stackable": false,
    "weight": 0.8,
    "value": 120,
    "attributes": {
        "is_melee": true,
        "melee_id": 6,
        "damage": 50,
        "attack_speed": 0.45,
        "range": 2.4,
        "knockback": 3.0,
        "damage_type": "slash",
        "max_combo": 3
    }
}

items["hammer_sledge"] = {
    "id": "hammer_sledge",
    "display_name": "Sledgehammer",
    "description": "Two-handed hammer. Massive damage but very slow.",
    "type": "melee",
    "icon": preload("res://UI/Icons/hammer_sledge.png"),
    "scene_path": "res://Weapons/Melee/Sledgehammer.tscn",
    "width": 2,
    "height": 4,
    "stackable": false,
    "weight": 5.0,
    "value": 300,
    "attributes": {
        "is_melee": true,
        "melee_id": 7,
        "damage": 90,
        "attack_speed": 1.5,
        "range": 2.8,
        "knockback": 15.0,
        "damage_type": "blunt",
        "heavy_damage_multiplier": 4.0,
        "stamina_cost": 20.0,
        "can_break_walls": true
    }
}

items["baton_police"] = {
    "id": "baton_police",
    "display_name": "Police Baton",
    "description": "Standard issue baton. Quick attacks with blocking.",
    "type": "melee",
    "icon": preload("res://UI/Icons/baton_police.png"),
    "scene_path": "res://Weapons/Melee/PoliceBaton.tscn",
    "width": 1,
    "height": 2,
    "stackable": false,
    "weight": 0.6,
    "value": 90,
    "attributes": {
        "is_melee": true,
        "melee_id": 8,
        "damage": 30,
        "attack_speed": 0.35,
        "range": 2.0,
        "knockback": 4.0,
        "damage_type": "blunt",
        "can_block": true,
        "block_damage_reduction": 0.65,
        "max_combo": 4
    }
}

items["spear"] = {
    "id": "spear",
    "display_name": "Spear",
    "description": "Long reach piercing weapon. Good for keeping distance.",
    "type": "melee",
    "icon": preload("res://UI/Icons/spear.png"),
    "scene_path": "res://Weapons/Melee/Spear.tscn",
    "width": 1,
    "height": 4,
    "stackable": false,
    "weight": 2.0,
    "value": 180,
    "attributes": {
        "is_melee": true,
        "melee_id": 9,
        "damage": 55,
        "attack_speed": 0.8,
        "range": 3.5,
        "knockback": 7.0,
        "damage_type": "pierce",
        "can_block": false,
        "thrust_attack": true
    }
}

items["chainsaw"] = {
    "id": "chainsaw",
    "display_name": "Chainsaw",
    "description": "Motorized terror. Continuous damage but requires fuel.",
    "type": "melee",
    "icon": preload("res://UI/Icons/chainsaw.png"),
    "scene_path": "res://Weapons/Melee/Chainsaw.tscn",
    "width": 3,
    "height": 2,
    "stackable": false,
    "weight": 6.0,
    "value": 800,
    "attributes": {
        "is_melee": true,
        "melee_id": 10,
        "damage": 20,  # Per tick
        "damage_tick_rate": 0.1,
        "attack_speed": 0.0,  # Continuous
        "range": 2.2,
        "damage_type": "slash",
        "requires_fuel": true,
        "fuel_consumption": 1.0,  # Per second
        "can_block": false,
        "is_continuous": true
    }
}
```

## Quick Reference Table

### Throwables

| Item | Damage | Radius | Fuse | Stack | Best For |
|------|--------|--------|------|-------|----------|
| Frag Grenade | 100 | 5m | 3s | 5 | High damage |
| Flashbang | 5 | 6m | 1.5s | 5 | Stunning |
| Smoke | 0 | 8m | 2s | 5 | Cover |
| Molotov | 15/tick | 4m | - | 3 | Area denial |
| Knife | 50 | - | - | 10 | Silent kills |
| Axe | 80 | - | - | 5 | Heavy damage |
| Shuriken | 25 | - | - | 20 | Rapid fire |

### Melee Weapons

| Item | Damage | Speed | Range | Type | Special |
|------|--------|-------|-------|------|---------|
| Combat Knife | 35 | Fast | 2.0m | Pierce | Backstab |
| Baseball Bat | 45 | Medium | 2.5m | Blunt | Block |
| Katana | 60 | Fast | 2.8m | Slash | Parry |
| Fire Axe | 75 | Slow | 2.6m | Slash | Heavy |
| Crowbar | 40 | Medium | 2.2m | Blunt | Utility |
| Machete | 50 | Fast | 2.4m | Slash | Combo |
| Sledgehammer | 90 | Very Slow | 2.8m | Blunt | Crushing |
| Baton | 30 | Very Fast | 2.0m | Blunt | Block |
| Spear | 55 | Slow | 3.5m | Pierce | Reach |
| Chainsaw | 20/tick | Continuous | 2.2m | Slash | DPS |

## Damage Type Chart

```
SLASH   → Swords, machetes, axes
          Good vs unarmored
          Medium vs armor
          
PIERCE  → Knives, spears, arrows
          Good vs armor
          Medium vs unarmored
          
BLUNT   → Bats, hammers, fists
          Good vs armor
          Medium vs unarmored
          Bonus knockback
          
EXPLOSIVE → Grenades, rockets
            Ignores armor
            Area damage
```

## Balancing Guidelines

### Attack Speed:
- Very Fast: 0.3 - 0.4s
- Fast: 0.4 - 0.5s
- Medium: 0.6 - 0.8s
- Slow: 0.9 - 1.2s
- Very Slow: 1.3s+

### Damage Balance:
```
Fast weapons:  25-40 damage
Medium:        40-60 damage
Slow:          60-80 damage
Very Slow:     80-100 damage
```

### Range Balance:
```
Short:   1.8 - 2.2m (knives, fists)
Medium:  2.2 - 2.6m (bats, swords)
Long:    2.8 - 3.5m (spears, pole arms)
```
