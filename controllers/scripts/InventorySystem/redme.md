# PRD: Deus Ex (original) Inventory System — Implementation for Godot

## Summary

Build a Godot-ready recreation of the original *Deus Ex* (2000) inventory system as a drop-in gameplay module. The module should reproduce the feel and functional behaviour of the original: tactile grid-based item placement, equipment slots, stacking, ammo management, container (loot) interactions, and quick-item hotkeys. It must be modular, data-driven, and easy to integrate into a Godot 4 project.

---

## Goals & Success Criteria

* **Functional parity** with the original *Deus Ex* inventory feel (grid placement, stacking, equip/unequip, ammo handling). Not necessarily pixel-perfect visuals.
* **Playable in Godot 4**: API friendly for designers and scripters (GDScript/TS compatible).
* **Modular & data-driven**: items defined in JSON/TOML/CSV (or Godot Resources) so designers change values without code.
* **Performant** for inventories with dozens of items and many containers.
* **Accessible UX**: supports keyboard and mouse, gamepad-friendly controls.

Success metrics:

* Inventory UI opens and is fully interactive within 0.5s in a typical scene.
* Item operations (drag/drop, equip, split stacks) complete without perceptible stutter.
* Integration example scene + demo ship provided.

---

## Scope (In / Out)

**Includes:**

* Grid-based inventory with variable-size item footprints (1x1, 1x2, 2x1, etc.)
* Item stacking and splitting
* Equipment slots (head, body, hands, belts, weapon slots)
* Ammo as stack tied to weapons (shared ammo types)
* Containers/loot (open container to view its own grid and transfer items)
* Drag & drop, right-click context menu, double-click use/equip
* Hotbar / quick select for items (numbered keys + mouse wheel)
* Save/load serialization
* Inventory Combine system 

---

## Target Platforms

* Desktop (Windows/Linux/macOS)
* Optional: gamepad-friendly controls for consoles/PC controllers

---

## User Stories

1. **As a player**, I can open my inventory and drag an item to rearrange it on the grid.
2. **As a player**, I can move items into a container and take them out.
3. **As a player**, I can equip a weapon to a weapon slot and its ammo stack is recognized.
4. **As a player**, I can split an item stack (e.g. bullets) into two stacks.
5. **As a designer**, I can add new items via a data file and the inventory will display them with correct size, icon, and properties.
6. **As a player**, I can press 1..8 to use the corresponding hotbar slot.

---

## Functional Requirements

### Item Data Model

Each item is represented by a data resource (JSON or Godot `.tres`) containing:

* `id` (string)
* `display_name` (string)
* `description` (string)
* `icon_path` (string/resource)
* `width`, `height` (grid footprint integers)
* `stackable` (bool)
* `max_stack` (int)
* `weight` (float)
* `type` (enum: `weapon`, `ammo`, `consumable`, `key`, `tool`, `misc`)
* `equip_slot` (nullable, enum)
* `attributes` (dictionary for extensible metadata e.g. damage, ammo_type)
* `spawn_count` (for loot generation)

### Inventory Model

* `columns`, `rows` (grid size)
* `slots` grid storing item references and origin coordinates
* Methods: `can_place(item, x, y)`, `place(item, x, y)`, `remove(item)`, `find_free_space(item)`, `split_stack(item, count)`


### Equipment Model

* Fixed equipment slots (Head, Body, Hands, Primary, Secondary, Belt, etc.)
* Equipping/unequipping rules (e.g., only one primary weapon equipped into primary slot)

### Containers

* Containers are inventories with their own grid. Opening shows player inventory and container inventory side-by-side.
* Transfer operations: `transfer_to(container, item, x, y)` with fallback to `find_free_space`.

### Hotbar

* A separate quick-access array (size configurable, default 8) referencing inventory items.
* Hotbar actions: use/equip/drop quickly.

### Interactions & Input

* Mouse drag & drop
* Right-click opens context menu with: `Use`, `Equip`, `Split`, `Drop`, `Examine` , `Rotate` 
* Button to Auto orgonizing
* Double-click Use / Equip
* Keyboard: arrows to navigate, Enter/Space to pick/place, numbers for hotbar, Shift to stack-split modifier.
* Gamepad: d-pad for selection, face buttons for actions, L/R for swapping grids.

---

## UX / UI Design

### Layout

* Two panes side-by-side: Player inventory (left) and Container/World inventory (right) when applicable.
* Equipment slots displayed as small fixed cells above or beside the player grid.
* Hotbar displayed at bottom (1..8).
* Item tooltip shows name, description, weight, and attributes on hover.

### Visual Behaviors

* Items snap to grid cells; while dragging show translucent preview of placement (green = valid, red = invalid).
* Show stack count on icon when `stackable`.
* When equipping a weapon, animate icon moving to equipment slot and highlight active weapon slot.

### Accessibility

* Keyboard focus high-contrast highlight for selected cell.
* Tooltips readable with configurable font size.

---

## Godot Implementation Notes

### Node Structure (suggested)

```
InventorySystem (Node)
├─ Resources/
│  └─ item_database.tres (or JSON importer)
├─ Scenes/
│  ├─ InventoryUI.tscn (Control)
│  │  ├─ PlayerGrid (GridContainer/CustomGrid)
│  │  ├─ ContainerGrid (GridContainer/CustomGrid)
│  │  ├─ EquipmentPane (Control)
│  │  └─ Hotbar (HBoxContainer)
│  └─ InventoryItem.tscn (TextureRect + scripts)
└─ Scripts/
   ├─ inventory.gd (model)
   ├─ item.gd (data wrapper)
   ├─ equipment.gd
   ├─ container.gd
   └─ inventory_ui.gd (handles input + visuals)
```

### Key Godot Patterns

* Use `Resource` or `.tres` for item definitions so they can be edited in the editor.
* `CustomControl` for grid to map (x,y) -> cell rect and handle snapping.
* Signals: `item_moved(item, from_inv, to_inv)`, `item_equipped(item, slot)`, `stack_split(item, amount)`.
* Use `PackedScene` for `InventoryItem` UI nodes to spawn icons.
* Serialization: inventory save as small JSON with item ids, amounts, and grid coordinates.

---

## Edge Cases & Rules

* If an item doesn't fit when transferring, attempt to place in the next free spot; if none, cancel transfer.
* Splitting a stack with odd number: floor/ceil rules shown in UI.
* Dropping an equipped item must unequip first (with optional confirmation).
* Ammo association: ammo items have `ammo_type`; weapons reference `ammo_type` and may draw ammo from any matching stack in the inventory when firing.
* Stack merging: when placing a stack onto another of same `id`, merge up to `max_stack`, leftover become separate stack and attempt to place in free space.

---

## Technical Constraints & Performance

* Keep UI updates localized to changed cells to avoid redrawing whole grid every frame.
* Pool `InventoryItem` UI nodes to reduce allocations during heavy looting.
* Limit grid size to a reasonable value (e.g., 8x10 by default) and lazy-load container UIs for many open containers.

---

## Art & Icons

* Placeholder icons provided; designers will substitute final art.
* Icons should be square PNGs with alpha, 64x64 or 128x128 resolution for crisp scaling.

---

## Milestones & Deliverables

1. **Spec & Data model** (this doc) — complete.
2. **Core model** — implement `Item`, `Inventory`, `Equipment` resources + unit tests.
3. **UI prototype** — grid UI, drag & drop, basic tooltip.
4. **Ammo & Weapon linking** — equip system + ammo consumption.
5. **Container interactions + hotbar**.
6. **Polish & optimization** — pooling, animations, accessibility.
7. **Example scene & documentation** — integration guide + sample items.

---

## Example Item JSON (minimal)

```json
{
  "id": "9mm_rounds",
  "display_name": "9mm Rounds",
  "description": "Standard 9mm ammunition.",
  "icon_path": "res://icons/9mm.png", # or new feature in 4.4 id
  "scene_path": "res://icons/9mm.tscn", # sames here 
  "width": 2,
  "height": 1, # can rotate w 1 h 2
  "stackable": true,
  "max_stack": 50,
  "weight": 0.02, # just visually not in gameplay
  "type": "ammo",
  "attributes": {"ammo_type": "9mm"}
}
```

---

## Notes / TODOs for fidelity to original *Deus Ex*

* If you want exact pixel-perfect behaviour (e.g. exact slot sizes, whether original had weight or just slot limits, quirks in stack merge behavior), I can fetch reference screenshots and design notes and update the PRD to match 1:1.

---

### Contact / Handoff

When you open the project in Godot, the example scene should include an `InventorySystem` node that exposes a sample item DB and a `DemoPlayer` with an example container in the scene for testing. Include a README with integration steps (API calls and signals).

*End of PRD*
