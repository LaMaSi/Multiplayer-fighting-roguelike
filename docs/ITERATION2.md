# Iteration 2: "Make it fun" plus weapon classes (handoff spec)

Context: the first playtests ran fine. All 30 moves from `PLAN.md` are implemented, levels are completable, reward picking works. This iteration fixes feel and readability first, then adds weapon classes. Work in the phases below, and playtest-check after each phase. Do not start a phase before the previous one runs without errors.

## Decisions already made

| Topic | Decision |
|---|---|
| X / Y moves | Split: **X = universal** (identical for every class, at least 10 moves), **Y = adaptive** (modified by class, at least 10 moves). Biggest class difference lives in B moves. See `DESIGN.md` for the co-op philosophy that overrides everything here |
| Class pick | Player chooses the class. Moves are random |
| Start loadout | Only X, B, side+B and up+B are filled. No Y moves at start. The other slots are empty and get filled by rewards |
| B slots | Always weapon-specific. 5 B slots (B, up, side, down, back/other side), 8 moves per class, so 3 are spares/rewards |
| Magic resource | **No separate mana bar.** How Magic's heavy move cost works is decided in the super meter planning session (`DESIGN.md` §5). Do not implement mana. Magic is locked in meta progression |
| Level goal | Objective banner, "GO" arrow, wave locks, end-of-level rank and score |
| Fonts / screen | Cyberpunk font(s), fullscreen on start |

## 1. Phase A: quick feel and readability wins (no new systems)

1. **Fullscreen on start**: project setting `display/window/size/mode` = fullscreen. Keep an F11 toggle and a setting in options. Make sure the UI scales (stretch mode `canvas_items`, aspect `keep`).
2. **Eyes**: black filled half-circle eyes (flat side on top, a slight inward tilt for a "cool, not angry" look). Pupils/eyes shift towards the aim vector (the left stick, falling back to facing direction). Smooth with a low-pass filter, clamp the offset to the head radius, blink occasionally, and squint on hit. Cosmetic only.
3. **Dodge dash on RT**: a short straight dash with a few invulnerability frames at the start, a brief cooldown (about 0.7 s), usable in the air once. Direction = stick direction (or facing). Afterimage trail and dust. It is not a roll. The existing move **Dodge Roll Strike** is too similar: retire it and replace it with a new universal move, **Pocket Mine** (drops a proximity mine that launches enemies). Optionally allow an attack out of the dash (dash-cancel into X) later; not now.
4. **Crouch**: holding down eases (about 6-8 frames, an ease curve, no snap) into a crouch pose. Crouching avoids **high** hits and projectiles. It does not avoid mid or low. Needs a `height` tag on every attack and projectile: `HIGH / MID / LOW`. Enemy telegraphs must show the height (e.g. high attacks are a different spark colour, and the enemy's arm is raised). Down + face-button moves must fire from the crouch without extra startup lag (use the input buffer).
5. **Hit explosion too dominant**: shrink it, lower alpha, draw it on a layer *behind* the fighters, and let hit-stop, flash, shake and a thin directional slash line carry the impact. The model silhouette must always stay readable. Add a debug slider for impact scale.
6. **Cyberpunk fonts** (all SIL OFL on Google Fonts; check the licence on download): Orbitron or Audiowide for headings and big combo numbers, Rajdhani or Chakra Petch for body and HUD, Share Tech Mono for the debug overlay. Pick two at most.
7. **Top UI rework**: show only HP, super meter (and mana for Magic), combo counter and the objective. Remove the permanent move list. The move display becomes a toggle (default **off**). The toggle and the **Move Lab** move to a new **Testing Options** section in the menu.
8. **Visual separation** (foreground vs background vs interactables):
   - Darken and desaturate backgrounds, and add a little atmospheric haze, so that anything bright is gameplay.
   - Give the ground a clear lit strip/edge line.
   - Interactables (destructibles, pickups, throwables) get one consistent rim outline or glow colour that nothing else uses. Pickups pulse gently.
   - The destructible with the black-background sprite: fix the alpha (transparent background; check the import setting "Fix Alpha Border" and that the texture really has transparency) or redraw it in code like the other props.

## 2. Phase B: goal, urgency, run start

1. **Run start loadout screen** (after class pick): each player gets random moves for B, side+B, up+B (from their class) and X (from a pool of basic generic attacks, so the player always has a useful X). The screen shows both loadouts side by side with names and short descriptions, plus one re-roll per player per run. Then it starts the first level.
2. **Objective banner**: at the start of a level a short line such as "Break through to the generator" fades in and then remains as a small HUD line.
3. **Wave locks**: the camera locks at arena points. Enemies spawn in waves (2-3 waves per arena). When cleared, a blinking **GO >>** arrow appears and the camera unlocks. This gives pacing and the feeling of progress.
4. **Level end rank**: S/A/B/C/D from combo peak, damage taken, time against a par time and containers broken. The rank influences the reward quality (e.g. S offers 4 move cards instead of 3, or an extra upgrade).
6. **Reward screen rework**: simultaneous picks, rock-paper-scissors on clashes, per `DESIGN.md` §3. Also the loadout swap from `DESIGN.md` §4.
5. **Urgency without a hard timer**: the waves, the par-time rank bonus and an optional "danger" background track layer at low HP. Do not add a failing timer in this iteration.

## 3. Phase C: classes (do after A and B are stable)

### 3.1 Design review: is the hybrid generic/weapon idea good?

Yes, with three clear tiers, so the player always knows what a move does:

| Tier | Slots | Behaviour | Marker |
|---|---|---|---|
| **Weapon** | B (5 slots) | Class-specific, 8 per class, strongest and defines the playstyle | class colour icon |
| **Adaptive** | Y (5 slots, empty at start) | Same move for everyone, but a class modifier table changes reach, speed, damage, visual (fist, blade, hammer, glowing hand). At least 10 moves | "adapts" tag |
| **Universal (off-hand)** | X (5 slots, X neutral filled at start with Off-hand Jab) | Never changes: punches, small projectile, block, grab, heal, co-op moves, Pocket Mine. Name/description says so (e.g. "Off-hand Jab"). At least 10 moves | "off-hand" tag |

Why this works: it solves the problem that the Hammer can't hit up close (an off-hand punch is the answer, so the dead zone becomes a choice rather than a handicap) and the Magic user always has a free attack when out of mana. It also keeps the move reward pool large, because most rewards work for everyone.

Risks to watch:
- **Homogenisation**: if universal moves are as strong as B moves, class choice stops mattering. Rule: universal moves get a lower damage ceiling and little knockback, and B moves must win in DPS. Check this in the Move Lab.
- **Balance explosion**: do not hand-tune every adaptive move per class. Use one table of multipliers per class (reach, startup, recovery, damage, knockback), plus an optional per-move override only when a combination looks wrong.
- **Readability**: always show the tier tag on reward cards.
- **Generic count**: at least 10 universal (X) and at least 10 adaptive (Y), so 20+ in total.
- Magic: no mana bar. Its B-move cost design is part of the super meter planning session (`DESIGN.md` §5).

### 3.2 Proposed split of the existing 30 moves

- **Retire**: Dodge Roll Strike (replaced by the RT dash). New: **Pocket Mine** (universal).
- **Universal, X (12)**: Off-hand Jab (start), Back Kick, Guard Block, Reflect Shield, Grab & Throw, Pull Hook, Ally Toss, Heal Pulse, Rage Taunt, Boost Spark, Pocket Mine, Spark Shot (small projectile, not affected by weapon).
- **Adaptive, Y (9 existing + at least 1 new)**: Uppercut, Leg Sweep, Spin Kick, Cyclone, Shockwave Stomp, Dive Kick, Anti-air Hook, Pillar Smash, Flurry, plus one new adaptive move to reach 10.
- **Brawler B moves (8)**: Jab Chain, Dash Punch, Rising Dragon, Heavy Haymaker, Wall-bounce Elbow, plus 3 new.
- **Magic B moves (8)**: Fireball, Spread Shot, Boomerang Disc, Ground Wave, Teleport Strike, plus 3 new.
- **Sword B moves (8)**: Parry Counter, plus 7 new (many parries, long reach, medium-slow).
- **Hammer B moves (8)**: all new (cannot hit very close, very slow, long reach, very strong).
- Total pool is about 50 moves, with about 21 new moves to design. The rest is reuse.

### 3.3 Class definitions

| Class | Speed | Reach | Notes |
|---|---|---|---|
| Brawler | fastest | short | fists; default; unlocked from the start |
| Sword | medium-slow | long | many parry/counter moves, rewards timing |
| Hammer | very slow | very long, dead zone up close | very high damage and knockback; needs the off-hand and dash for close defence |
| Magic | medium | ranged | glowing hands; ranged focus; heavy B-move cost mechanic TBD (super meter session) |

Magic is locked behind meta progression. Brawler is available from the start; Sword and Hammer availability is an open question (`DESIGN.md` §7).

### 3.4 Technical changes

- `MoveData` gets: `tier` (WEAPON / ADAPTIVE / UNIVERSAL), `class_id` (only for WEAPON), `height` (HIGH / MID / LOW), `meter_cost` (reserved, 0 until the super meter design is done).
- New `ClassData` resource: multipliers, mana settings, visual skin, list of 8 weapon moves, starter-pool rules.
- Loadout slots: `X, B, B_UP, B_SIDE, B_DOWN, B_BACK` plus `Y` and `X` directions as before. B slots only accept WEAPON moves of the player's class.
- Reward cards show tier, class tag and who can use them. Reward flow is described in `DESIGN.md` §3.
- Stickfigure weapon rendering: sword (line with glow), hammer (thick line with block head), glowing hands for Magic. Keep it code-drawn.
- Add a save-data version field now so older saves don't break when classes arrive.

## 4. Suggested order and effort

| Phase | Content | Estimated effort |
|---|---|---|
| A | quick wins | about 1.5-2.5 h |
| B | goal, waves, rank, run-start screen | about 2-3 h |
| C1 | class framework, move data refactor, tags | about 2 h |
| C2 | Brawler B moves (3 new), Magic and mana | about 2-3 h |
| C3 | Sword (7 new) | about 2 h |
| C4 | Hammer (8 new) | about 2 h |

## 5. Open questions with my default (change if you disagree)

1. Magic is locked in meta progression (decided). Sword and Hammer: **Default: available from the start.**
2. Starting X: **decided, Off-hand Jab (universal), so every class can hit up close.**
3. Do both players have to be different classes? **Default: no restriction, but mixed classes get a small Duo Special flavour later.**
4. B slot directions: forward/back relative to facing. **Default: yes.**
5. Rank effect on reward quality: **Default: S gives an extra card, D gives one fewer.**
6. Should crouch also allow crouch-walking? **Default: no, stationary crouch only.**

## 6. Prompt to paste tomorrow

> Read `docs/PLAN.md` and `docs/ITERATION2.md` in the repo. Start with Phase A, one item at a time, and run the game after each to check for errors. Commit after each item. When Phase A is finished, stop and list what I should playtest. Do not start Phase B until I confirm. Keep moves, classes and balancing in data files. Add everything to the Move Lab / Testing Options so I can inspect it.
