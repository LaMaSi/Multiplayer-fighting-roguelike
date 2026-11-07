# Co-op Stickfigure Brawler Roguelike: Project Plan (Godot 4.5)

Status: v2, decisions confirmed by the user (see §1). It gets updated at the end of each milestone and is the source of truth.

## 1. Decisions locked in

| Topic | Decision |
|---|---|
| Engine / language | Godot 4.5.1 (installed at `C:\Users\lara\Documents\Godot 4.5.1 stable\`), GDScript, 2D, no external plugins |
| Players | 2 local players, Xbox controllers (Godot's `Input` joypad API); keyboard fallback for P1/P2 via an input abstraction |
| Playfield | **Flat 2D side-scroller with platforms** (one-way platforms, drop-through with Down+A, ledges). No depth lanes |
| Workflow | Claude works directly in this folder, in a local git repo (one commit per milestone, so any milestone can be rolled back). Claude runs the game headless with the Godot 4.5.1 console build to catch script errors and run smoke tests; the user playtests after each milestone and reports back |
| Art | **Fully procedural, nothing downloaded**: neon stickfigures, backdrops, props, particles AND audio (synthesized in code) (see §3) |
| Directions | Forward/back **relative to facing**. "Right" slot = forward, "Left" slot = back; Up/Down are absolute |
| Player contact | Players **body-block** each other. Friendly fire is **on by default with damage + knockback**, toggleable in the pause menu (when off, partner hits pass through harmlessly) |
| Co-op pillars | All four are core: shared combo + juggle relay, team-up moves, Duo Specials, loadout synergy |
| Moves | 15 slots (X/Y/B x neutral/up/right/down/left), pool of 30 moves, 5 equipped at run start; A = jump |
| Run | Branching node map, 3 biomes: Streets, Wasteland, Ruins; boss per biome |
| Rewards | Shared pick: both players on one screen, take turns choosing |
| Failure | Revive partner; both down means the run ends. Each run earns currency that unlocks moves into the reward pool (persistent meta layer) |
| Meter | Per-player super meter (no shared meter). Duo Specials need both players above a threshold |
| Co-op | Shared combo counter, juggle relay, team-up moves, friendly-fire toggle, revive |

## 2. Multiplayer design (the "feels like true co-op" part)

The principle is that **actions of one player should create opportunities for the other**.

1. **Shared combo counter.** Hits by either player feed one combo. Each player has a tinted combo colour. The multiplier grows with *relay hits*, where the players alternate in the same combo (x1.5 per handoff, capped). The combo decays after about 1.5 s with no hit. Higher combos improve drop rates for containers and meter.
2. **Juggle passing.** A launched enemy enters an "airborne" state with its own gravity and hit-stun scaling. Launchers (Uppercut, Rising Dragon, Anti-air Hook) are meant to be followed up by the partner. A hit while airborne from the *other* player is a **Relay hit**: bonus damage, a bigger hit-stop, and a unique spark colour.
3. **Team-up moves** (no extra buttons; they emerge from normal moves plus proximity):
   - **Alley-oop**: one player launches, the partner spikes (Dive Kick / Pillar Smash) for a massive downward slam.
   - **Ally Toss** (a move in the pool): throw your partner as a flying kick. They can steer slightly and hit everything on the way.
   - **Baton**: a "buff" move (Boost Spark) charges the partner's next hit.
   - **Pinball**: knock an enemy into your partner's attack hitbox for a double-hit.
4. **Duo Specials.** Each player has their own super meter filled by dealing damage and landing relay hits. When *both* are at 50% or more, they can press a pair-trigger (LB+RB at the same time, within a short window) to fire a combined super. The specific special depends on the two players' equipped *Y-slot* moves, which makes it build-dependent. A first version has 3 specials (Shockwave Duo, Crossfire, Tornado).
5. **Revive.** A downed player lies on the floor with a ring that fills while the partner stands beside them holding X/Y/B. It takes about 2 s and the revive is interruptible. Revives are limited per level (shown as hearts), and the revived player comes back at 30% HP with brief invulnerability.
6. **Friendly fire + body blocking.** Players are solid to each other (they can jump over each other and dodge-dash through). Friendly fire is **on by default**: partner hits deal damage (default 50% of normal, adjustable in the pause menu) plus full knockback/hit-stun, so you can launch each other for combos or chaos. A pause-menu toggle turns it off entirely (then partner hits pass through harmlessly, but Ally Toss and buffs still work). Safeguards: a player can never be killed by friendly fire (it stops at 1 HP), and when two players overlap for >0.5 s a gentle shove separates them, so nobody traps a partner in a corner.
7. **Camera.** One shared camera follows the midpoint and zooms to keep both players in view. A soft tether stops players from being separated by more than one screen width. If one lags behind, the other is allowed to go ahead but slowly pulls the partner along.
8. **Shared pick screen.** Moves are offered as 3 cards. Players alternate who picks (alternating first pick). Either player can swap which slot receives a new move. The screen shows both loadouts side by side.

## 3. Graphics style (cheap but juicy)

**Neon stickfigures + painted flat parallax backdrops.** It needs no sprite sheets and no hand-animated frames.

- **Characters**: a skeleton of ~12 `Node2D` joints (head, neck, torso, 2x(upper arm, lower arm), hip, 2x(thigh, shin)). Limbs are drawn with `Line2D` or `_draw()` using round caps, with a glow via `WorldEnvironment` (Glow) plus an outline. Players are coloured (P1 cyan, P2 magenta). Enemies get per-type shapes and colours.
- **Animation**: pose keyframes stored as data (resource files with per-joint angles, plus an offset for the root). Moves play pose sequences with easing curves for anticipation, strike and recovery. Idle, walk and jump are procedural (sine-based). Because poses are data, all 30 moves can be authored as small tables rather than animation clips.
- **Juice toolbox**:
  - Hit-stop (frame freeze, 3-8 frames scaled by hit weight; relay hits freeze longer)
  - Screen shake (trauma-based), small zoom punch on heavy hits
  - Squash and stretch on the target, white flash shader on hit
  - Impact sparks/rings, afterimage trails on fast moves, dust on landing/dashes
  - Damage numbers that scale with combo, a big combo counter that pulses
  - Slow-motion on boss defeat and duo specials, chromatic aberration pulse
  - Ragdoll-ish limb flail on knockback (secondary motion with springs)
- **Backgrounds**: 3-4 parallax layers of flat-colour silhouettes made with `Polygon2D`/gradients, plus palette swaps for each biome and some ambient particles (embers, dust, rain). Nothing needs to be downloaded.
- **Audio (decision: fully procedural, no downloads)**:
  - SFX are synthesized at startup in code (an sfxr-style generator that fills an `AudioStreamWAV`: square/saw/noise oscillators, envelopes, pitch sweeps, filters) and cached. Hit, whoosh, block, pickup, crate-break, UI blips, with pitch variation per hit and per combo level so the combo "sings".
  - Music: a small step sequencer in code (bass/arp/drum patterns per biome in a chosen scale) rendering loops to `AudioStreamWAV`. Simple but fitting for a neon look.
  - Font: Godot's built-in default font at first; if a nicer one is wanted later, an OFL font from Google Fonts can be dropped in (the user's call).
  - Fallback if procedural audio disappoints: Kenney.nl (CC0) *Impact Sounds*/*Interface Sounds*, or OpenGameArt CC0. Licence must be checked on the page before use.
- **Platforms and level look**: platforms are neon-outlined slabs drawn in code. Level layouts are built from a small set of hand-authored "chunks" (arena sections with platforms and spawn points) stitched together per biome, so every level is data, not hand-placed scenes.

## 4. Combat system

- **Fixed-timestep state machine** per fighter: `Idle, Walk, Jump, Fall, Attack(move, phase), Block, HitStun, Launched, Knockdown, Downed, Dead`.
- **Move data** as `Resource` files (`MoveData`): `startup`, `active`, `recovery` frames, hitbox shapes/offsets per frame, damage, hitstun, knockback vector and its type (launch, push, spike, pull), hit-stop, meter gain, movement during the move, projectile scene, cancel windows, flags (`low`, `overhead`, `air_ok`, `armor`, `counter`, `grab`), and a pose-sequence ref.
- **Hit/hurtboxes** via `Area2D` with collision layers (player hit, enemy hit, projectile, props). Hit IDs prevent multi-hits per swing.
- **Input**: an input layer reads direction + face button into a `MoveInput` (e.g. `Y_RIGHT`), with an input buffer (~6 frames), so each slot maps to a move. Air versions use the same slot and fall back when no air variant is defined.
- **Slots**: `X, X_UP, X_RIGHT, X_DOWN, X_LEFT`, same for Y and B. "Right" = forward and "Left" = back, relative to facing (decided). Direction comes from the left stick or D-pad.
- **Controller map (proposal)**: A = jump (Down+A = drop through a platform), X/Y/B + direction = moves, LT = dash/dodge, RT = interact (pick up / throw container, revive), LB+RB together = Duo Special, Start = pause.
- **Platforms**: the fighter uses `CharacterBody2D` with one-way platform collision. Enemies mostly stay on the platform they spawn on or jump between linked platforms via authored "jump links", which keeps AI simple and robust. Launched enemies can land on platforms, which also makes juggles more interesting.

### The 30-move pool (starter = 5)

| # | Name | Slot suggestion | Trait |
|---|---|---|---|
| 1 | Jab Chain *(start)* | X | 3-hit combo |
| 2 | Uppercut *(start)* | X+Up | launcher |
| 3 | Dash Punch *(start)* | X+Right | gap closer |
| 4 | Leg Sweep *(start)* | X+Down | low, trips |
| 5 | Back Kick *(start)* | X+Left | hits behind |
| 6 | Fireball | any | projectile |
| 7 | Boomerang Disc | any | returns, hits twice |
| 8 | Spread Shot | any | 3-way projectile |
| 9 | Ground Wave | any | low projectile |
| 10 | Guard Block | any | blocks frontal hits |
| 11 | Parry Counter | any | timed counter with a big payoff |
| 12 | Reflect Shield | any | reflects projectiles |
| 13 | Dodge Roll Strike | any | i-frames, then a hit |
| 14 | Spin Kick | any | 360 multi-hit |
| 15 | Cyclone | any | moving whirlwind |
| 16 | Shockwave Stomp | any | ground AoE, hits low |
| 17 | Dive Kick | air | downward slam / spike |
| 18 | Rising Dragon | any | invuln launcher |
| 19 | Anti-air Hook | any | hits upwards |
| 20 | Heavy Haymaker | any | slow, huge knockback |
| 21 | Wall-bounce Elbow | any | bounces enemies off walls |
| 22 | Flurry | any | rapid jabs, low knockback |
| 23 | Grab & Throw | any | throws an enemy as a projectile |
| 24 | Pull Hook | any | drags enemy to you |
| 25 | Teleport Strike | any | blink behind enemy |
| 26 | Ally Toss | any | throw partner as a kick |
| 27 | Heal Pulse | any | heals a bit on hit (small) |
| 28 | Rage Taunt | any | self buff: damage up, defence down |
| 29 | Boost Spark | any | buff on partner's next hit |
| 30 | Pillar Smash | any | smashes/throws crates farther, breaks them faster |

Final tuning happens during playtesting; the list is a starting point.

## 5. Run structure

- **Node map**: each biome is a branching map of about 6-8 nodes: Fight, Elite, Treasure (container-heavy room), Rest, Mystery, ending in the biome Boss. Both players are on the same map and move together.
- **Level rewards** (shown on the map nodes): *New Move* (3 cards, shared pick), *Level Up* (+max HP, or empower a move: +damage, +knockback, -recovery, etc.), *Upgrade a move* (a tier boost), *Heal*. Not every node gives a move, as requested.
- **Meta layer**: souls/currency from each run buys unlocks that add moves into the reward pool (start with 15 unlocked, the other 15 purchasable), plus a few permanent perks (e.g. starting HP).
- **Difficulty**: Streets (basic), Wasteland (harder), Ruins (hardest). Enemy HP/damage also scales with the number of nodes cleared.

## 6. Biomes and enemies

| Biome | Palette | Enemies (attack patterns) |
|---|---|---|
| Streets | warm night, purple/orange neon | **Thug** (walk-up punch), **Biker** (charges in a straight line), **Bottle Thrower** (ranged arc), **Boss: Big Boss** (ground slam + summon) |
| Wasteland | dusty orange/teal | **Raider** (shield, needs back hits or guard-break), **Scrapper** (fast, jumps in), **Sniper** (telegraphed laser), **Boss: Warlord** (charge + dynamite) |
| Ruins | deep blue/violet, glowing runes | **Wraith** (teleports behind), **Golem** (armoured, slow, huge hit), **Caster** (projectile patterns), **Boss: Ruin Titan** (multi-phase) |

Every enemy has a telegraph (visible wind-up) so the game is readable. A simple per-enemy state machine plus an AI director limits how many enemies attack at the same time (a token system), so brawls feel fair and not chaotic.

## 7. Destructible containers

Crates, barrels, vases (themed per biome) that have HP and can be hit, thrown, or used as a throwable weapon (pick up and throw, e.g. with Pillar Smash or Grab). They can contain: health pickups (small/medium), temporary power-ups (damage up, speed up, shield, meter fill, magnet) and currency. The combo size increases the drop chance. Thrown containers damage enemies.

## 8. Technical structure

```
project.godot
autoload/   GameState.gd  Input mapping, RunState, SaveData, Juice (shake/hitstop), Audio
scenes/     main menu, level, map, reward, players, enemies, props, UI
scripts/
  fighter/  fighter.gd, state machine, pose player, hitboxes
  moves/    MoveData.gd and move .tres files
  enemies/  base_enemy.gd, ai, one script per enemy type
  levels/   level_loader, spawner, camera rig, parallax
  run/      map generation, rewards, meta unlocks
docs/       PLAN.md
tests/      headless smoke tests (run with godot --headless -s)
```

- Data-driven: moves, enemies, rewards and levels are `Resource` files or JSON so that balancing doesn't need code changes.
- Save game via `FileAccess` in `user://`.
- Debug overlay (F1): hitboxes, FPS, state names, spawn buttons, give-move menu, to make your playtesting reports precise.
- Input actions registered in code so P1/P2 devices (`device 0/1`) and keyboard fallbacks work without editing `project.godot` by hand.

## 9. Milestones (each one is playable and committed separately)

0. **Before M0**: **Git is not installed on this PC** (checked). The user wants a local repo with a commit per milestone, so first install Git for Windows (https://git-scm.com/download/win, or `winget install Git.Git`), then `git init` and commit this plan. Godot 4.5.1 console already verified to run headless on this project (it only reports "no main scene", as expected for an empty project).
1. **M0 Skeleton**: project setup, input abstraction (2 pads + keyboard), one stickfigure per player with walk/jump on a test level with floor and one-way platforms, player-player body blocking, debug overlay.
2. **M1 Combat core**: skeleton poses, `MoveData`, the 5 starter moves, hit/hurt boxes, hit-stop/shake/flash, dummy enemy, first procedural SFX. **Stop and tune feel with the user before moving on**: this milestone decides if the game feels juicy.
3. **M2 Co-op core**: shared camera, shared combo counter, juggle relay, revive, friendly-fire (damage + toggle), first team-up moves (Ally Toss, alley-oop spike) and the loadout-synergy hooks (buff-the-partner moves).
4. **M3 Enemies and Streets**: 4 enemy types + boss, token AI, containers + pickups, a full Streets level with parallax.
5. **M4 Moves**: implement the remaining 25 moves in batches of ~6 (projectiles, defensives, slams, utility, co-op moves).
6. **M5 Run loop**: node map, rewards (shared pick), level-ups, move upgrades.
7. **M6 Biomes**: Wasteland and Ruins enemies, bosses and backdrops.
8. **M7 Duo specials, meta unlocks, menus, save/load**.
9. **M8 Juice and polish pass**: audio, particles, balancing from your feedback.

## 10. Risks and mitigations

- **Limited playtesting by Claude**: Claude can run the game headless (parse errors, runtime errors, scripted-input smoke tests such as "spawn dummy, force a move, assert damage dealt"), but cannot judge feel or see the screen live. Mitigation: data-driven code, the debug overlay, small milestones, and a playtest checklist at the end of each milestone. Controller input can only be verified by the user.
- **Platforms + juggles + body blocking interact badly** (stuck players, enemies falling out of the world): kill-plane respawn, shove-apart rule, friendly fire cannot kill, and unit-style smoke tests for these in M0/M2.
- **Fully procedural art and audio may look/sound too plain**: decided deliberately for zero licensing risk; the juice toolbox and glow carry the look. A CC0 audio fallback is documented in §3.
- **Scope of 30 moves x co-op interactions**: each move is authored as data and gets a one-line "co-op interaction" note; the pool is built in batches (M4) and can be cut to ~24 without breaking the design.
- **Pose animation looks stiff**: use eased pose tweens and springs for secondary motion; tune in M1 before building 25 more moves.
- **Moves balance**: tune using the data files, not scripts.
- **Scope**: the milestones are ordered so the game is fun and complete after M3 even if later milestones take long.
