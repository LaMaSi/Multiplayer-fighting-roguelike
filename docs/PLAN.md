# Co-op Stickfigure Brawler Roguelike: Project Plan (Godot 4.5)

Status: proposal v1. It gets updated at the end of each milestone and is the source of truth.

## 1. Decisions locked in

| Topic | Decision |
|---|---|
| Engine / language | Godot 4.5, GDScript, 2D, no external plugins |
| Players | 2 local players, Xbox controllers (Godot's `Input` joypad API); keyboard fallback for P1/P2 via an input abstraction |
| Workflow | Claude writes and pushes to branch `claude/gifted-lamport-71ms3x`. You pull, open in Godot 4.5, playtest, and report back. Claude can't run the game |
| Art | Neon stickfigures drawn in code over painted parallax backdrops (see §3) |
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
6. **Friendly-fire toggle.** Off by default (setting in the pause menu and per run). When on, partner hits deal 0 damage but cause knockback/hit-stun, so you can launch each other for fun or to set up combos.
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
- **Audio** (the one place to use packs; verify the licence on the page before using any file):
  - **Kenney.nl** (CC0): *Impact Sounds*, *Interface Sounds*, *Digital Audio* and the *Fonts* pack.
  - **jsfxr / sfxr** (free, in-browser): generate punchy retro hit/whoosh/pickup sounds yourself in seconds; the output is yours.
  - **OpenGameArt.org** CC0 music tracks, or **Kevin MacLeod / incompetech** (CC-BY, needs credit) for biome music; or **Freesound** CC0 filter.
  - Fonts: Kenney Fonts or Google Fonts (OFL).
  - I'm naming these from memory, so please check the current licence terms before shipping.

## 4. Combat system

- **Fixed-timestep state machine** per fighter: `Idle, Walk, Jump, Fall, Attack(move, phase), Block, HitStun, Launched, Knockdown, Downed, Dead`.
- **Move data** as `Resource` files (`MoveData`): `startup`, `active`, `recovery` frames, hitbox shapes/offsets per frame, damage, hitstun, knockback vector and its type (launch, push, spike, pull), hit-stop, meter gain, movement during the move, projectile scene, cancel windows, flags (`low`, `overhead`, `air_ok`, `armor`, `counter`, `grab`), and a pose-sequence ref.
- **Hit/hurtboxes** via `Area2D` with collision layers (player hit, enemy hit, projectile, props). Hit IDs prevent multi-hits per swing.
- **Input**: an input layer reads direction + face button into a `MoveInput` (e.g. `Y_RIGHT`), with an input buffer (~6 frames), so each slot maps to a move. Air versions use the same slot and fall back when no air variant is defined.
- **Slots**: `X, X_UP, X_RIGHT, X_DOWN, X_LEFT`, same for Y and B. "Right" and "Left" are relative to facing: forward/back is clearer, and this is easy to flip if you want absolute directions.

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

1. **M0 Skeleton**: project setup, input abstraction (2 pads + keyboard), one stickfigure per player with walk/jump on a flat floor, debug overlay.
2. **M1 Combat core**: skeleton poses, `MoveData`, the 5 starter moves, hit/hurt boxes, hit-stop/shake/flash, dummy enemy.
3. **M2 Co-op core**: shared camera, shared combo counter, juggle relay, revive, friendly-fire toggle.
4. **M3 Enemies and Streets**: 4 enemy types + boss, token AI, containers + pickups, a full Streets level with parallax.
5. **M4 Moves**: implement the remaining 25 moves in batches of ~6 (projectiles, defensives, slams, utility, co-op moves).
6. **M5 Run loop**: node map, rewards (shared pick), level-ups, move upgrades.
7. **M6 Biomes**: Wasteland and Ruins enemies, bosses and backdrops.
8. **M7 Duo specials, meta unlocks, menus, save/load**.
9. **M8 Juice and polish pass**: audio, particles, balancing from your feedback.

## 10. Risks and mitigations

- **No in-session playtesting**: keep the code simple and data-driven, add the debug overlay, and ship in small milestones. You report issues, I fix them.
- **Pose animation looks stiff**: use eased pose tweens and springs for secondary motion; tune in M1 before building 25 more moves.
- **Moves balance**: tune using the data files, not scripts.
- **Scope**: the milestones are ordered so the game is fun and complete after M3 even if later milestones take long.
