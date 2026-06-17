# Basement (Level 1) — Change Summary

A log of the work done turning the reworked basement into a full, playable level:
camera, ramp, the merged tutorial, the combat/boss progression, and assorted fixes.

## 1. Player camera (room-based, fade transitions)

- `scripts/level_1.gd` drives a **room camera**: the player's `Camera2D` follows the
  player but is clamped to the bounds of whichever room (`Area2D` + `CollisionPolygon2D`)
  it's currently in.
- Walking into a new room **fades to black**, snaps the camera limits to the new room,
  then fades back in (`_start_transition` / `FADE_TIME`).
- Camera limits are computed from each room's polygon bounding box (`_room_bounds`).

## 2. Ramp movement

- `lil_dude.gd`: while on the `ramp` Area2D, holding left/right applies a **constant
  vertical speed** (up when moving right, down when moving left) for a 22.5° slope
  illusion. Horizontal velocity is untouched; releasing input lets normal friction stop
  the player (gated on input direction, not velocity).
- `level_1.gd` `_connect_ramp()` toggles the player's `on_ramp` flag on enter/exit.

## 3. Tutorial merged into the basement

The old `level_0_tutorial` was folded in so the basement is now the game's opening level.

- **`project.godot`**: `run/main_scene` now points at `level_1_basement.tscn`.
- **room0 (start):** `GameManager.reset()` (fresh stick), intro narrative dialogue, then
  the action-hint tutorial prompts (WASD / attack / block / dodge / upgrade menu).
- **room1:** entry dialogue, then **3 docile spiders** (don't fight back). Clearing them
  reveals a **Dagger** pickup and **Key #1**; the key auto-opens **Door #1** (room1→room2).
- Reused systems: `scenes/dialogue_box.tscn`, `scenes/tutorial_prompt.tscn`,
  `scenes/hud.tscn`, `scenes/upgrade_menu.tscn`, `scenes/weapon_pickup.tscn`,
  `scenes/baby_spider.tscn` (`docile = true`).
- New: `scripts/key_pickup.gd` + `scenes/key_pickup.tscn` (key item using `items.png`).

## 4. Combat rooms, second key, boss, exit to level 2

- **room2 (pits):** 4 **hostile** spiders spaced on the ledges.
- **room4 (lower-left chamber):** 2 **egg sacs** (`spider_sack`) + 2 guard spiders.
  Defeating the sacs + guards drops **Key #2** (sac-spawned babies don't block it),
  which auto-opens **Door #2** (room4 → hall / `Area2D2`).
- **Area2D3 (final arena):** the **Broodmother** boss. On death she reveals the
  **Flatsword** pickup; collecting it teleports the player to
  `levels/level_2_garden.tscn` with the flatsword equipped (weapon persists via
  `GameManager`).
- **`level_1.gd` refactor:** enemy tracking moved from the global `"enemy"` group to
  explicit per-encounter node references, so each room's reward fires independently.
- One-time narration on entering room2 / room4 / the boss arena.

## 5. Enemy room-awareness (don't aggro across rooms)

- `enemy_base.player_in_same_room()` reads room rects off the player's camera. The
  basement now **publishes its room rects** to the camera as metadata
  (`level_1._publish_rooms_to_camera`), and `enemy_base._level_rooms()` reads that meta.
- Hostile `baby_spider`s **hold still** (no wandering) while the player isn't in their
  room — they only move once the player shares the room.
- **Pits delay:** room2's detection rect is inset 64px (`PITS_ACTIVATION_INSET`) so its
  spiders wake only after the player steps ~2 tiles in.

## 6. Boss arena lock-in

- A `BossGate` (barrier + collision) seals the hall→arena entrance the moment the player
  enters `Area2D3` (`_set_boss_gate_closed`). It stays sealed until the boss is killed —
  the player exits only via the flatsword → level 2.

## 7. Dash-only wall

- `scripts/dash_wall.gd` (on the `dash_wall` StaticBody2D): the player can pass through
  **only while dashing** — it opens a collision exception during the dodge and
  re-solidifies once the dash ends *and* the player has cleared the wall (so they can't
  get stuck inside).
- `lil_dude.gd` exposes `is_dashing()` (true during the DODGE state).

## 8. Camera architecture fix (level 1 → level 2 transition)

- `room_camera.gd` existed but was **never attached** to the player's `Camera2D`, so any
  level calling `Camera2D.setup()` (level 0, level 2) crashed on load — which broke the
  level 1 → level 2 hand-off.
- Fix: attached `room_camera.gd` to the `Camera2D` in `lil_dude.tscn`, and made it
  **inert until `setup()` is called** (default `rooms = []`) so it doesn't interfere with
  the basement's own camera while still serving the other levels.

## 9. UI / polish

- Removed the floating name labels over pickups (`weapon_pickup`, `key_pickup`).
- Tutorial tooltips shrunk and word-wrapped to fit the 512px viewport; they auto-dismiss
  once the player reaches the pits room.
- Door art uses the 2-tile sprite from `assets/items.png` (`region Rect2(32,0,32,64)`).

## 10. Bug fixes

- `scripts/level_0.gd`: removed a stray `d` that was a parse error.
- `scripts/level_2.gd`: fixed `plawayer` typo → `player` (parse error).

## Key files

- `scripts/level_1.gd` — camera, ramp wiring, full basement gameplay flow.
- `lil_dude.gd` — ramp drift, `is_dashing()`.
- `room_camera.gd`, `lil_dude.tscn` — room camera attached + inert-until-setup.
- `scripts/enemy_base.gd`, `scripts/baby_spider.gd` — room-aware aggro.
- `scripts/key_pickup.gd` / `scenes/key_pickup.tscn`, `scripts/dash_wall.gd` — new.
- `levels/level_1_basement.tscn` — all the enemies, pickups, doors, gates, dash wall.
