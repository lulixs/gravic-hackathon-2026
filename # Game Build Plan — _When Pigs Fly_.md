**\# Game Build Plan — "When Pigs Fly"**

**\#\# Context**

A 1.5-day hackathon game. A fly fights through four levels — Tutorial, Basement, Garden, and Castle — to defeat the Flying Pig. The existing codebase has player movement (WASD \+ CharacterBody2D), an AnimationTree (idle/walk with l/r blend), and a mouse-orbiting sword with block (RMB). Everything else needs to be built. All new art uses placeholder \`ColorRect\` nodes until real assets arrive.

Each gameplay level follows the same structure: **\*\*multiple enemy rooms → puzzle gate → boss fight → weapon drop\*\***. The tutorial is a linear on-rails intro with no puzzle and no boss.

**\#\#\# What exists**

| File | What it does |  
|------|-------------|  
| \`lil\_dude.gd\` | CharacterBody2D, IDLE/WALK enum, WASD movement, \`updateDir()\` sets blend params |  
| \`sword.gd\` | \`extends Sprite2D\`, orbits player toward mouse (INNER/OUTER\_RADIUS ring), RMB block lerp |  
| \`lil\_dude.tscn\` | CharacterBody2D → Sprite2D(frames), CollisionShape2D, AnimationPlayer, Sword(Sprite2D+sword.gd), AnimationTree |  
| \`env.tscn\` | Node2D → TileMapLayer(bricks) \+ CharacterBody2D instance |  
| \`project.godot\` | 320×240 @ 4x window, WASD input actions, main\_scene=env.tscn, Godot 4.6 |  
| \`assets/\` | lil-dude.png, sword.png, bricks.png, blades.png |

**\#\#\# Resolution change**  
Update \`project.godot\` to 1024×768 native (no pixel-art upscale). The existing tile map in \`env.tscn\` is 320×240-sized and will need more tiles placed in all level scenes to cover the larger viewport.

**\---**

**\#\# Level Structure**

\`\`\`  
Level 0 — Tutorial (linear, no puzzle, no boss)  
  Goal: teach every control before the player enters the real game  
  Enemies: 3 docile spiders (wander, don't attack, can be killed)  
  Sequence: move → attack/charge → block → dodge → upgrade menu  
  Reward: Dagger weapon pickup spawns after all 3 spiders die  
  Exit: walk to door after collecting Dagger → Basement

Level 1 — Basement  
  Enemies: baby spider, spider sack  
  Hazard:  cobwebs (slow player 90%)  
  Puzzle:  pipe rotation puzzle → clears exit door  
  Boss:    Mother Spider (plants sacks, spits webs)  
  Drop:    Flatsword

Level 2 — Garden  
  Enemies: worm, grasshopper  
  Hazard:  mud patches (slow)  
  Puzzle:  TBD (pressure plates / gate)  
  Boss:    Garden Snake (screen-wrap lunge)  
  Drop:    Broadsword

Level 3 — Castle  
  Enemies: TBD  
  Boss:    Flying Pig (final)  
\`\`\`

**\---**

**\#\# Architecture**

\`\`\`  
GameManager (autoload)  
  ├── hp, stamina, xp, current\_weapon  
  ├── signal hp\_changed(new\_val, max\_val)  
  ├── signal stamina\_changed(new\_val, max\_val)  
  └── signal xp\_changed(new\_val)

lil\_dude.gd  
  ├── states: IDLE, WALK, DODGE, HURT, DEAD  
  ├── take\_damage(amount) — ignored during DODGE (i-frames)  
  ├── DODGE: short burst in dir, 25 stamina cost, 0.25s duration, i-frames active  
  ├── HURT: 0.5s i-frame timer, modulate blink  
  ├── cobwebbed: bool set by cobweb.gd → speed × 0.1  
  └── charging: bool set by sword signal → speed × 0.5

sword.gd (extends Sprite2D, child of player)  
  ├── SwordState: IDLE → CHARGING → ATTACKING → COOLDOWN  
  ├── hitbox: Area2D created programmatically in \_ready()  
  └── stamina check \+ drain via GameManager

Each level scene:  
  └── Node2D  
        ├── TileMapLayer (1024×768 room coverage)  
        ├── HUD (CanvasLayer)  
        ├── UpgradeMenu (CanvasLayer, WHEN\_PAUSED)  
        ├── Player  
        ├── Enemies / Hazards  
        └── Puzzle / Boss / Door trigger  
\`\`\`

**\---**

**\#\# New Files**

**\#\#\# Autoload**  
\- **\*\*\`scripts/game\_manager.gd\`\*\*** — extends Node. \`@export\` vars: \`max\_hp=100\`, \`hp\`, \`max\_stamina=100\`, \`stamina\`, \`xp=0\`, \`current\_weapon="stick"\`. Signals: \`hp\_changed(val, max)\`, \`stamina\_changed(val, max)\`, \`xp\_changed(val)\`. Methods: \`take\_damage(n)\`, \`heal(n)\`, \`drain\_stamina(n) → bool\` (returns false if insufficient), \`restore\_stamina(n)\`, \`add\_xp(n)\`, \`set\_weapon(id)\`. Registered in project.godot as \`GameManager\`.

**\#\#\# HUD**  
\- **\*\*\`scenes/hud.tscn\`\*\*** \+ **\*\*\`scripts/hud.gd\`\*\*** — CanvasLayer. VBoxContainer top-left, two ProgressBars 150px wide (hp=red, stamina=yellow). Connects to GameManager signals in \`\_ready()\`.

**\#\#\# Upgrade Menu**  
\- **\*\*\`scripts/upgrade\_menu.gd\`\*\*** — CanvasLayer, \`process\_mode \= PROCESS\_MODE\_WHEN\_PAUSED\`. C key toggles \+ \`get\_tree().paused\`. Three buttons: Max HP \+20 (50 XP), Max Stamina \+20 (50 XP), Damage \+10% (75 XP).

**\#\#\# Tutorial**  
\- **\*\*\`scripts/tutorial\_prompt.gd\`\*\*** — CanvasLayer with a Label (centered bottom). Manages a queue of \`{action: String, message: String}\` steps; shows message, waits for the action to be performed once, then advances. Steps:  
  1\. \`"move"\` → "Use WASD to move"  
  2\. \`"attack"\` → "Left-click to attack; hold for a charged strike"  
  3\. \`"block"\` → "Right-click to block"  
  4\. \`"dodge"\` → "Shift to dodge — costs stamina"  
  5\. \`"upgrade\_menu"\` → "Press C to open upgrades"  
  6\. \`"kill\_all"\` → "Defeat the spiders to find your first weapon"  
  Detection: \`tutorial\_prompt.gd\` checks input events for actions 1–5, and listens for \`enemies\_remaining \== 0\` for step 6\.  
\- **\*\*\`levels/level\_0\_tutorial.tscn\`\*\*** — TileMapLayer, HUD, UpgradeMenu, TutorialPrompt, Player (start left), 3 docile\_spider instances (spaced across room), Dagger pickup (hidden until all spiders die), exit door Area2D (inactive until Dagger collected). Script \`scripts/level\_0.gd\`: on \`enemies\_remaining \== 0\` → show Dagger pickup; on pickup collected → activate door; door \`body\_entered\` player → \`change\_scene\_to\_file("res://levels/level\_1\_basement.tscn")\`.

**\#\#\# Enemies**  
\- **\*\*\`scripts/enemy\_base.gd\`\*\*** — extends CharacterBody2D. Creates CircleShape2D CollisionShape2D in \`\_ready()\` (radius 8). \`take\_damage(n)\`: hp \-= n; 0.4s i-frame timer \+ modulate blink. \`die()\`: spawn xp\_orb \+ 20% health\_orb, queue\_free. Creates hitbox Area2D (layer 2, mask 1\) in \`\_ready()\`, connects \`body\_entered\` → player \`take\_damage(damage)\`. Add self to group \`"enemy"\` in \`\_ready()\`.  
\- **\*\*\`scripts/baby\_spider.gd\`\*\*** — extends enemy\_base. \`@export var docile := false\`. If docile: wander (random direction change every 2s, no chase, hitbox disabled). If not docile: chase player when within 150px.  
\- **\*\*\`scripts/spider\_sack.gd\`\*\*** — extends enemy\_base. Timer-based hop (upward impulse every 2s), spawn 2 baby\_spiders every 5s, throw garbage\_pellet every 3s.  
\- **\*\*\`scripts/garbage\_pellet.gd\`\*\*** — extends Area2D. Moves in a fixed direction; \`body\_entered\` player → \`take\_damage\`, queue\_free.  
\- **\*\*\`scripts/mother\_spider.gd\`\*\*** — extends enemy\_base. Plant spider\_sack every 6s; spit web\_projectile every 4s. On death: emit \`boss\_died\`, spawn Flatsword pickup.  
\- **\*\*\`scripts/web\_projectile.gd\`\*\*** — extends Area2D. Spawns cobweb on wall hit or 1.5s timeout.  
\- **\*\*\`scripts/worm.gd\`\*\*** — extends enemy\_base. Slow straight-line patrol; high HP.  
\- **\*\*\`scripts/grasshopper.gd\`\*\*** — extends enemy\_base. Pounce toward player when within 150px (large velocity burst, 1.5s cooldown).  
\- **\*\*\`scripts/garden\_snake.gd\`\*\*** — extends enemy\_base. Wraps screen edges. Timer-based lunge. On death: spawn Broadsword pickup.

**\#\#\# Pickups & Hazards**  
\- **\*\*\`scripts/xp\_orb.gd\`\*\*** — Area2D. In \`\_physics\_process\`: lerp toward player if within 50px. \`body\_entered\` → \`GameManager.add\_xp(value)\`, queue\_free.  
\- **\*\*\`scripts/health\_orb.gd\`\*\*** — same; \`GameManager.heal(20)\`.  
\- **\*\*\`scripts/weapon\_pickup.gd\`\*\*** — Area2D. \`@export var weapon\_id\`. \`body\_entered\` → \`GameManager.set\_weapon(weapon\_id)\`, queue\_free.  
\- **\*\*\`scripts/cobweb.gd\`\*\*** — Area2D \+ RectangleShape2D 48×48. \`body\_entered\`/\`body\_exited\` set \`body.cobwebbed\`. Auto-despawn after 10s.

**\#\#\# Puzzle**  
\- **\*\*\`scripts/pipe\_puzzle.gd\`\*\*** — \`@export var pipes: Array\[Node2D\]\`, \`@export var correct\_indices: Array\[int\]\`. Press E near pipe → \`rotation\_degrees \+= 90\`, \`rotation\_index \= (rotation\_index \+ 1\) % 4\`. On \`check\_solution()\` match: emit \`puzzle\_solved\`.

**\#\#\# Weapons (Resource)**  
\- **\*\*\`scripts/weapon\_resource.gd\`\*\*** — \`extends Resource\`. \`@export\` fields: \`id\`, \`display\_name\`, \`damage\_multiplier: float\`, \`stamina\_jab: float\`, \`stamina\_slash: float\`. Data files: \`data/stick.tres\`, \`data/dagger.tres\`, \`data/flatsword.tres\`, \`data/broadsword.tres\`. sword.gd loads via \`ResourceLoader.load("res://data/" \+ GameManager.current\_weapon \+ ".tres")\`.

**\#\#\# Level Scenes**  
\- **\*\*\`levels/level\_0\_tutorial.tscn\`\*\*** — see Tutorial section above  
\- **\*\*\`levels/level\_1\_basement.tscn\`\*\*** — TileMapLayer covering 1024×768, HUD, UpgradeMenu, Player, 3 spider\_sacks \+ 6 baby\_spiders (docile=false), 4 cobwebs (random non-spawn positions), pipe puzzle. Script: enemy-clear counter → activate puzzle → on \`puzzle\_solved\` → \`change\_scene\_to\_file("res://levels/level\_1\_boss.tscn")\`.  
\- **\*\*\`levels/level\_1\_boss.tscn\`\*\*** — Mother Spider center, HUD, Player at entrance. Script: on \`boss\_died\` → \`change\_scene\_to\_file("res://levels/level\_2\_garden.tscn")\`.  
\- **\*\*\`levels/level\_2\_garden.tscn\`\*\*** — Green placeholder background, worms \+ grasshoppers, garden puzzle, Snake boss room transition.  
\- **\*\*\`levels/level\_2\_boss.tscn\`\*\*** — Garden Snake.  
\- Level 3 deferred to stretch time.

**\---**

**\#\# Modifications to Existing Files**

**\#\#\# \`project.godot\`**  
1\. Resolution: \`viewport\_width=1024\`, \`viewport\_height=768\`, \`window\_width\_override=1024\`, \`window\_height\_override=768\`, \`stretch/mode="canvas\_items"\` (remove integer scale).  
2\. Autoload: \`\[autoload\]\\nGameManager="\*res://scripts/game\_manager.gd"\`  
3\. New input actions: \`interact\` (E), \`upgrade\_menu\` (C), \`attack\` (MOUSE\_BUTTON\_LEFT), \`dodge\` (Shift)  
4\. \`run/main\_scene\` → \`"res://levels/level\_0\_tutorial.tscn"\`

**\#\#\# \`lil\_dude.gd\`**  
\- Expand enum: \`{IDLE, WALK, DODGE, HURT, DEAD}\`  
\- Add vars: \`var cobwebbed := false\`, \`var charging := false\`, \`var i\_frames := false\`  
\- Constants: \`const DODGE\_SPEED \= 400.0\`, \`const DODGE\_DURATION \= 0.25\`, \`const DODGE\_STAMINA \= 25.0\`  
\- Speed multiplier in \`walk()\`: \`var mult \= 0.1 if cobwebbed else (0.5 if charging else 1.0)\`; apply to \`MAX\_SPEED\`  
\- DODGE state: on \`Input.is\_action\_just\_pressed("dodge")\` and \`GameManager.drain\_stamina(DODGE\_STAMINA)\` succeeds and not HURT/DEAD: set \`i\_frames \= true\`, store \`dodge\_dir \= dir\` (or last known dir), enter DODGE, set \`velocity \= dodge\_dir \* DODGE\_SPEED\`, start 0.25s timer. On timeout: \`i\_frames \= false\`, return IDLE/WALK.  
\- \`take\_damage(amount)\`: if \`i\_frames\`: return. Else: \`GameManager.take\_damage(amount)\`, enter HURT, \`i\_frames \= true\`, start 0.5s i-frame timer. Blink \`$frames.modulate\` with accumulator in HURT's \`\_physics\_process\`. On timeout: \`i\_frames \= false\`, return IDLE/WALK.  
\- DEAD: if \`GameManager.hp \<= 0\` → \`queue\_free()\`  
\- Stamina regen in \`\_physics\_process\`: \`GameManager.restore\_stamina(20 \* delta)\` when not HURT/DEAD  
\- Connect to sword's \`charging\_changed\` signal in \`\_ready()\`  
\- Add to group \`"player"\` in \`\_ready()\`

**\#\#\# \`sword.gd\`**  
\- Add \`enum SwordState {IDLE, CHARGING, ATTACKING, COOLDOWN}\`  
\- \`var sword\_state := SwordState.IDLE\`, \`var charge\_time := 0.0\`  
\- \`signal charging\_changed(is\_charging)\`  
\- \`\_ready()\`: create hitbox Area2D programmatically (CircleShape2D radius 10, layer 4, mask 2, monitoring=false); connect \`body\_entered\` → \`\_on\_hitbox\_body\_entered\`.  
\- State machine in \`\_physics\_process\`:  
  \- IDLE → CHARGING: \`Input.is\_action\_just\_pressed("attack")\` \+ \`GameManager.stamina \>= cost\`; emit \`charging\_changed.emit(true)\`  
  \- CHARGING: \`charge\_time \+= delta\`; on \`just\_released\` → compute \`damage \= base \* (1.0 \+ charge\_time)\` (capped at 3×); ATTACKING; \`hitbox.monitoring \= true\`; 0.15s timer  
  \- ATTACKING → COOLDOWN: timer fires, \`hitbox.monitoring \= false\`; 0.3s timer  
  \- COOLDOWN → IDLE: timer fires; \`charging\_changed.emit(false)\`; \`charge\_time \= 0.0\`  
\- \`\_on\_hitbox\_body\_entered(body)\`: if \`body.is\_in\_group("enemy")\`: \`body.take\_damage(damage)\`  
\- Drain stamina via \`GameManager.drain\_stamina(cost)\` on entering CHARGING

**\---**

**\#\# Build Order**

\`\`\`  
Phase 1 — Core combat loop (Day 1 AM)  
  \[1\] project.godot: resolution \+ autoload \+ input actions  
  \[2\] game\_manager.gd  
  \[3\] sword.gd: attack states \+ hitbox  
  \[4\] lil\_dude.gd: DODGE \+ HURT/DEAD \+ take\_damage \+ i\_frames  
  \[5\] hud.tscn \+ hud.gd  
  \[6\] enemy\_base.gd \+ baby\_spider.gd (docile=false)  
  \[7\] xp\_orb.gd \+ health\_orb.gd  
  \[8\] Temp test scene (copy env.tscn) with a few baby spiders  
      → smoke test: move, attack, kill, loot, take damage, dodge, die

Phase 2 — Tutorial \+ Basement (Day 1 PM)  
  \[9\]  tutorial\_prompt.gd \+ level\_0\_tutorial.tscn (docile spiders)  
  \[10\] weapon\_pickup.gd \+ weapon\_resource.gd \+ data/\*.tres  
  \[11\] spider\_sack.gd \+ garbage\_pellet.gd  
  \[12\] cobweb.gd  
  \[13\] upgrade\_menu.gd (WHEN\_PAUSED)  
  \[14\] levels/level\_1\_basement.tscn (enemies \+ cobwebs \+ pipe puzzle)  
  \[15\] pipe\_puzzle.gd; enemy-clear gate  
  \[16\] mother\_spider.gd \+ web\_projectile.gd \+ level\_1\_boss.tscn  
  \[17\] Scene transitions: tutorial → basement → boss → garden

Phase 3 — Garden level (Day 2 AM, stretch)  
  \[18\] worm.gd \+ grasshopper.gd  
  \[19\] levels/level\_2\_garden.tscn \+ garden puzzle  
  \[20\] garden\_snake.gd \+ level\_2\_boss.tscn \+ Broadsword drop

Phase 4 — Castle (stretch)  
  \[21\] Level 3 enemies \+ Flying Pig boss  
\`\`\`

**\---**

**\#\# Placeholders**

| System | Placeholder |  
|--------|-------------|  
| Docile spider | ColorRect light gray 16×12 |  
| Baby spider | ColorRect dark gray 16×12 |  
| Spider sack | ColorRect brown 20×20 |  
| Mother Spider | ColorRect red 64×48 \+ Label |  
| Worm | ColorRect pink 40×12 |  
| Grasshopper | ColorRect green 18×18 |  
| Garden Snake | ColorRect dark green 80×20 \+ Label |  
| XP orb | ColorRect yellow 8×8 |  
| Health orb | ColorRect red 8×8 |  
| Cobweb | ColorRect white α=0.5, 48×48 |  
| Weapon pickup | ColorRect purple 12×12 \+ Label(weapon name) |  
| HP/Stamina bars | ProgressBar 150px wide, red/yellow fill |  
| Tutorial prompt | Label centered bottom, black background panel |

**\---**

**\#\# Technical Notes**

1\. **\*\*i-frame flag\*\***: \`i\_frames\` is the single source of truth for invincibility — set during both DODGE and HURT states; \`take\_damage()\` checks it first and returns immediately if true.  
2\. **\*\*Dodge direction\*\***: capture \`dir\` at the moment Shift is pressed; if \`dir \== Vector2.ZERO\`, use last non-zero movement direction stored in a \`last\_dir\` var.  
3\. **\*\*Stamina drain order\*\***: \`GameManager.drain\_stamina(n)\` returns \`bool\`; only proceed with dodge/attack if it returns \`true\` (sufficient stamina). This prevents negative stamina.  
4\. **\*\*Pause system\*\***: UpgradeMenu sets \`process\_mode \= PROCESS\_MODE\_WHEN\_PAUSED\` in \`\_ready()\`. TutorialPrompt also needs this if showing during pause.  
5\. **\*\*Collision layers\*\***: player=layer 1/mask 2+4; enemies=layer 2/mask 1; sword hitbox=layer 4/mask 2\. Add groups \`"player"\` and \`"enemy"\` in \`\_ready()\` for hitbox body-entered type checks.  
6\. **\*\*Sword hitbox placement\*\***: Area2D created programmatically in \`sword.gd\`'s \`\_ready()\`. It is a child of the Sword Sprite2D, so it moves with the sword as it orbits the player.  
7\. **\*\*AnimationTree\*\***: existing idle/walk nodes untouched. HURT blinks via \`$frames.modulate\` toggling; DODGE could flash \`$frames.modulate.a \= 0.5\`; DEAD hides \`$frames\`.  
8\. **\*\*Resolution\*\***: 1024×768 native — the existing env.tscn tilemap covers only \~320×240. All new level scenes need tile coverage for the full viewport.  
9\. **\*\*Tutorial enemy-clear\*\***: connect each docile spider's \`tree\_exited\` to a counter in level\_0.gd; when count reaches 0, make the Dagger pickup visible.

**\---**

**\#\# Verification**

1\. \`F5\` → tutorial loads at 1024×768; player spawns, prompts display bottom-center.  
2\. Follow prompts: WASD moves, LMB attacks, RMB blocks, Shift dodges (stamina bar drops), C opens upgrade menu.  
3\. Kill 3 docile spiders → Dagger pickup appears → collect → \`GameManager.current\_weapon\` \= "dagger".  
4\. Walk to exit door → Basement loads.  
5\. Basement: walk into baby spider → HP decreases → i-frame blink → can't take damage during blink.  
6\. Dodge through enemy → no damage taken during dodge.  
7\. Charge attack → player slows 50% → release → more damage than tap.  
8\. Stand on cobweb → 90% slow → step off → normal speed.  
9\. Kill all enemies → pipe puzzle activates → solve → boss room loads.  
10\. Kill Mother Spider → Flatsword pickup → collect → weapon swap.  
