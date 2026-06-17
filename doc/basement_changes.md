# Basement (Level 1) — Change & Merge Log

Tracks the reworked basement (Luke's branch) and how it was merged into `Harry`
while keeping Harry's character/weapon art, enemy animations, and the intro/ending
cutscenes. Source review notes: `basementChanges.txt`.

## Game flow (after merge)

`intro_cutscene` → **Level 1 / Basement (Luke, includes the old tutorial)** →
Level 2 / Garden → Level 3 / Castle → `ending_cutscene`.

- `project.godot` `run/main_scene` = `intro_cutscene.tscn`; the cutscene's
  `NEXT_SCENE` now loads `level_1_basement.tscn`.
- The standalone `level_0_tutorial` scene + `level_0.gd` were **removed** — the
  tutorial is folded into the basement's first rooms.

## Luke's basement work (taken wholesale)

1. **Room camera** — `level_1.gd` clamps the player's `Camera2D` to the current
   room (`Area2D` + polygon); entering a new room fades to black, snaps limits,
   fades back (`FADE_TIME`).
2. **Ramp movement** — `lil_dude.gd`: on the `ramp` Area2D, left/right applies a
   constant vertical drift (22.5° slope feel). `level_1._connect_ramp()` toggles it.
3. **Merged tutorial** — room0 `GameManager.reset()` + intro dialogue + control-hint
   prompts (WASD / attack / block / dodge / upgrade). room1: 3 docile spiders →
   Dagger + Key #1 (auto-opens Door #1).
4. **Combat / boss progression** — room2 pits (4 hostile spiders, woken only after a
   64px inset, `PITS_ACTIVATION_INSET`); room4 (2 egg sacs + 2 guards → Key #2 →
   Door #2); final arena = **Broodmother**, who drops the **Flatsword** that
   teleports to `level_2_garden.tscn`.
5. **Room-aware aggro** — `level_1._publish_rooms_to_camera()` writes room rects to
   the camera as metadata; `enemy_base._level_rooms()` reads `cam.get_meta("rooms")`.
   Hostile spiders hold still until the player shares their room.
6. **Boss gate** — a `BossGate` seals the arena on entry until the Broodmother dies.
7. **Dash wall** — `dash_wall.gd` passable only while dashing; `lil_dude.is_dashing()`.
8. **Camera fix** — `room_camera.gd` attached to the player `Camera2D` in
   `lil_dude.tscn`, inert until `setup()` (default `rooms = []`) so levels 2/3 work.
9. **Polish** — pickup name labels removed (`weapon_pickup`, `key_pickup`); tooltips
   shrunk/word-wrapped for the 512×384 viewport; door art from `items.png`.
10. **New files** — `key_pickup.gd/.tscn`, `dash_wall.gd`, `assets/items.png`.
11. **Resolution** — viewport set to **512×384** (Luke's), integer stretch.

## Kept from Harry (assets / features preserved)

- **Character & enemy art**: animated `baby_spider` (4-frame `Spiders/spider_*.png`),
  `spider_sack` real sac art, BigPig / Snakes / Grasshoppers / PigGuards /
  MotherSpider / Frog / Weapons, `fly.png`.
- **Weapon pickups**: real weapon sprites via `_load_icon()` (Luke's label removal
  kept on top — icon shows, floating name gone).
- **Cutscenes**: `intro_cutscene` (Pig + wardens) and `ending_cutscene` (wings →
  Pig explodes → red → THE END), re-laid-out proportionally for 512×384.
- **Levels 2–3**: garden/castle dialogue, mid-fight (`half_health`) lines, the
  Broodmother/Bullfrog/Boarden/Flying-Pig story beats.
- **Balance**: stamina pool halved (50), +50% XP on orb pickup.

## Files merged by hand (both sides needed)

- `scripts/enemy_base.gd` — kept Harry's `half_health` signal **and** added Luke's
  `cam.get_meta("rooms")` room lookup.
- `scripts/baby_spider.gd` — kept Harry's two-direction animation **and** adopted
  Luke's "hold still until the player enters the room" behavior (auto-merged).
- `project.godot` — Luke's display (512×384) + input maps, Harry's `main_scene`
  (the intro cutscene).
