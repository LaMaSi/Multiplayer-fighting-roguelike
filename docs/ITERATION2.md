# Iteration 2: "Make it fun" plus weapon classes (handoff spec)

Context: the first playtests ran fine. All 30 moves from `PLAN.md` are implemented, levels are completable, reward picking works. This iteration fixes feel and readability first, then adds weapon classes. Work in the phases below, and playtest-check after each phase. Do not start a phase before the previous one runs without errors.

## Decisions already made

| Topic | Decision |
|---|---|
| X / Y moves | Split: **X = universal** (identical for every class, exactly 10 moves), **Y = adaptive** (modified by class, exactly 10 moves). Biggest class difference lives in B moves. See `DESIGN.md` for the co-op philosophy that overrides everything here |
| Class pick | Player chooses the class. Moves are random |
| Start loadout | 3 random B moves (class), 1 random Y (adaptive) and 1 random X (universal), no reroll at start. Other slots get filled by rewards/shops. See `ECONOMY.md` |
| B slots | Always weapon-specific. 5 B slots (B, up, side, down, back/other side), 8 moves per class; 3 are rolled at run start and 5 unlock through personal level-ups |
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
7. **Top UI rework**: show only HP, Style meter, combo counter and the objective. Remove the permanent move list. The move display becomes a toggle (default **off**). The toggle and the **Move Lab** move to a new **Testing Options** section in the menu.
8. **Visual separation** (foreground vs background vs interactables):
   - Darken and desaturate backgrounds, and add a little atmospheric haze, so that anything bright is gameplay.
   - Give the ground a clear lit strip/edge line.
   - Interactables (destructibles, pickups, throwables) get one consistent rim outline or glow colour that nothing else uses. Pickups pulse gently.
   - The destructible with the black-background sprite: fix the alpha (transparent background; check the import setting "Fix Alpha Border" and that the texture really has transparency) or redraw it in code like the other props.

## 2. Phase B: goal, urgency, run start

1. **Run start loadout screen** (after class pick): each player gets 3 random B moves (class, ★), 1 random Y (★) and 1 random X (★, an attack). The screen shows both loadouts side by side with names and short descriptions. No re-roll (re-rolls are a meta unlock, see `ECONOMY.md`). Then it starts the first level.
2. **Objective banner**: at the start of a level a short line such as "Break through to the generator" fades in and then remains as a small HUD line.
3. **Wave locks**: the camera locks at arena points. Enemies spawn in waves (2-3 waves per arena). When cleared, a blinking **GO >>** arrow appears and the camera unlocks. This gives pacing and the feeling of progress.
4. **Level end rank**: S/A/B/C/D from combo peak, damage taken, time against a par time and containers broken. The rank influences the reward quality (e.g. S offers 4 move cards instead of 3, or an extra upgrade).
5. **Urgency without a hard timer**: the waves, the par-time rank bonus and an optional "danger" background track layer at low HP. Do not add a failing timer in this iteration.
6. **Reward screen rework** per `DESIGN.md` §3: (a) a shared X/Y move choice (3 cards, simultaneous picks, RPS on clashes), then (b) a personal level-up for each player (3 own cards: new B move, empower, max HP, team card, generic super). Also the loadout swap from `DESIGN.md` §4.

## 3. Phase C: classes (do after A and B are stable)

### 3.1 Design review: is the hybrid generic/weapon idea good?

Yes, with three clear tiers, so the player always knows what a move does:

| Tier | Slots | Behaviour | Marker |
|---|---|---|---|
| **Weapon** | B (5 slots) | Class-specific, 8 per class, strongest and defines the playstyle | class colour icon |
| **Adaptive** | Y (5 slots, one random Y at start) | Same move for everyone, but a class modifier table changes reach, speed, damage, visual (fist, blade, hammer, glowing hand). 10 moves | "adapts" tag |
| **Universal (off-hand)** | X (5 slots, one random X at start) | Never changes: punches, small projectile, block, grab, heal, co-op moves, Pocket Mine. Name/description says so (e.g. "Off-hand Jab"). 10 moves | "off-hand" tag |

Why this works: it solves the problem that the Hammer can't hit up close (an off-hand punch is the answer, so the dead zone becomes a choice rather than a handicap) and the Magic user always has a free attack while B moves are on cooldown. It also keeps the move reward pool large, because most rewards work for everyone.

Risks to watch:
- **Homogenisation**: if universal moves are as strong as B moves, class choice stops mattering. Rule: universal moves get a lower damage ceiling and little knockback, and B moves must win in DPS. Check this in the Move Lab.
- **Balance explosion**: do not hand-tune every adaptive move per class. Use one table of multipliers per class (reach, startup, recovery, damage, knockback), plus an optional per-move override only when a combination looks wrong.
- **Readability**: always show the tier tag on reward cards.
- **Generic count**: exactly 10 universal (X) and 10 adaptive (Y).
- Magic: no mana bar. Its B-move cost design is part of the super meter planning session (`DESIGN.md` §5).

### 3.2 Proposed split of the existing 30 moves

- **Retire**: Dodge Roll Strike (replaced by the RT dash). New: **Pocket Mine** (universal).
- **Universal, X (10)** and **Adaptive, Y (10)**: fully specified in `CLASS_MOVES.md` §6 and §7 (class modifier table, co-op hooks, Magic marks).
- **Class B moves (8 per class):** fully specified in `CLASS_MOVES.md` (Brawler, Sword, Hammer, Magic), including LT versions, co-op hooks, the Magic mark system and the weapon supers.
- Total pool is 52 moves, 25 of them new (see `CLASS_MOVES.md` §8).

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
- New `ClassData` resource: multipliers, cooldown settings, visual skin, list of 8 weapon moves, starter-pool rules.
- Loadout slots: `X, B, B_UP, B_SIDE, B_DOWN, B_BACK` plus `Y` and `X` directions as before. B slots only accept WEAPON moves of the player's class.
- Reward cards show tier and class tag. Reward flow is described in `DESIGN.md` §3.
- Stickfigure weapon rendering: sword (line with glow), hammer (thick line with block head), glowing hands for Magic. Keep it code-drawn.
- Add a save-data version field now so older saves don't break when classes arrive.

### 3.5 Class base poses (from your sketch: `docs/concepts/class_base_poses.png`)

Each class has its own **idle/base pose**, and the walk, crouch, dash and hit-reaction poses are built as offsets from it, so all of a class's animations share one silhouette. The sketch is a rough reference, not exact.

| Class | Base pose (from the sketch) | Weapon anchor | Idle motion |
|---|---|---|---|
| **Fist (Brawler)** | Compact boxer guard: one fist raised near the head with a bent elbow, the other hand lower in front, legs apart, knees slightly bent. | none (fists, small glow on the knuckles) | bounce on the toes, small head bob |
| **Sword** | Upright, slightly leaning forward. The sword arm extended out front, **blade angled up and forward**; the back arm relaxed. Legs apart in a lunge-ready stance. | blade attached to the front hand, about 1.5x the arm length | the blade tip drifts and flicks slowly, small breathing |
| **Hammer** | Wide, low, heavy stance, shoulders hunched. A long shaft held across the body with **both hands**, the big **rectangular head resting low at the back/side**, the head line pulling the body down. | hammer shaft on both hands, a block head at the end | slow sway, the head sinks at the end of the breath |
| **Magic** | Upright and floating, arms **spread wide at both sides** with open raised palms, legs close together. A glow around both hands. | no weapon, glow at the hands | the hands orbit and bob, the figure hovers about 2-4 px |

Implementation notes:
- A `BasePose` resource per class (angles for all joints and root offset). The pose player blends from the base pose into move poses and back to it, so recovery always returns to the class silhouette.
- Weapons are separate nodes parented to the hand joints, so a move can rotate the weapon independently of the arm, which gives the Hammer and Sword their sweeping arcs.
- The Hammer pose is two-handed, so both hand joints must hold the shaft during all Hammer moves. Add one IK helper for "two hands on one shaft".
- The crouch (down) is derived per class: Hammer sinks the head low, Sword goes to a low guard, Fist tucks the guard, Magic lowers the floating height.
- The eyes follow the stick on all classes. Their size and shape stay the same so players recognise their stickfigure.
- Silhouettes need to be clearly different at gameplay size. Check by shrinking the sprites to the camera size.

### 3.6 Enemy weapon poses

The same base-pose system is used for **enemies**. Every enemy gets a weapon archetype and a base pose, so the **pose tells the player what the enemy will do** (a readability tool, and it also saves art work).

| Archetype (pose) | Reads as | Enemy examples |
|---|---|---|
| **Fist** (guard) | fast, close range, combos | Thug, Scrapper |
| **Sword** (blade angled up) | medium reach, parries/counters | Raider (machete and shield), Warlord (boss) |
| **Hammer** (low, two-handed) | slow, heavy, huge reach, guard-break | Biker (pipe or wrench), Golem, Big Boss, Ruin Titan |
| **Magic** (arms spread, floating) | ranged, projectiles, teleports | Bottle Thrower (throwing pose), Sniper (aiming variant), Wraith, Caster |

- Enemies reuse the **class modifier table** for their base reach/speed/damage scale, then each enemy type overrides what it needs. This keeps enemies consistent with what the players feel from the same weapon.
- Telegraph: the wind-up pose is the weapon archetype's wind-up, held longer for heavy attacks. Heights (high/mid/low) are shown by the arm/weapon position (see Phase A, crouch).
- Enemy look: warm red/orange (Streets) or biome palette, thicker outline than the players, simple head shape per type, no eyes following a stick (a fixed "stare" at their target instead). Players must be able to tell a player from an enemy at a glance, even on small screens.
- Co-op readability: the pose also hints at the best counter. Hammer-pose enemies need a guard breaker or a rescue, Magic-pose enemies must be flanked, Sword-pose enemies punish solo mashing.
- Variants: elites reuse the base type with a different weapon pose (e.g. a Thug with a pipe becomes a Hammer-pose thug), giving variety without new rigs.
- Later: mirror bosses that copy a player class (a Sword boss who parries) to test teamwork.

## 4. Suggested order

1. Phase A: quick wins
2. Phase B: goal, waves, rank, run-start screen
3. Phase C: classes (C1 framework, C2 Brawler and Magic move pieces, C3 Sword, C4 Hammer)
4. Phase D: rewards and economy (after `ECONOMY.md`), grab/throw and interact (RB), ghost, two meters and supers
5. Marks and Magic: only after the `MARKS.md` session

## 5. Open questions with my default (change if you disagree)

1. Magic is locked in meta progression (decided). Sword and Hammer: **Default: available from the start.**
2. Starting X: **decided: a random attack-type X move**, so every class can hit up close.
3. Do both players have to be different classes? **Default: no restriction, but mixed classes get a small Duo Special flavour later.**
4. B slot directions: forward/back relative to facing. **Default: yes.**
5. Rank effect on reward quality: **Default: S gives an extra card, D gives one fewer.**
6. Should crouch also allow crouch-walking? **Default: no, stationary crouch only.**

## 6. Prompt to paste tomorrow

> Read `docs/PLAN.md` and `docs/ITERATION2.md` in the repo. Start with Phase A, one item at a time, and run the game after each to check for errors. Commit after each item. When Phase A is finished, stop and list what I should playtest. Do not start Phase B until I confirm. Keep moves, classes and balancing in data files. Add everything to the Move Lab / Testing Options so I can inspect it.
