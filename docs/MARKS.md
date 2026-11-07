# Marks and Detonation: planning batch (OPEN, needs its own session)

Everything related to marks, detonation and the Magic class's role is collected here. Other docs only point to this file. Until the session is done, nothing mark-related should be implemented beyond a placeholder (a `mark` field on enemies that does nothing).

## 1. Current draft (from `CLASS_MOVES.md`, not final)

- Three marks: **Flame**, **Volt**, **Frost**. One mark per enemy at a time, lasting about 6 s. The enemy glows in the mark's colour.
- **Detonation:** a hit by the *other* player detonates the mark at full power. Magic's own hits detonate at half power. The mark is consumed.
  - Flame: area explosion.
  - Volt: chain lightning to nearby enemies plus a short stun.
  - Frost: freeze; the next hit shatters it for a bonus and a launch.
- Bosses and elites: detonation deals a capped % of their HP.
- Detonating a mark gives the **shared team meter** (see `DESIGN.md` §5).
- Magic B moves that apply marks: Fireball (Flame), Spread Shot (Flame), Boomerang Disc (Volt), Ground Wave (Frost), Arcane Beam (applies over time). Teleport Strike detonates at half power.
- Magic's **Y moves** (adaptive) also apply a mark by element: Uppercut Flame, Leg Sweep Frost, Spin Kick Volt, Cyclone Volt, Shockwave Stomp Frost, Dive Kick Flame, Anti-air Hook Volt, Flurry Flame, Slide Strike Frost; Pillar Smash none.
- Magic role (proposal): **Primer / Zoner**. Lowest HP, slow projectiles, cooldowns on B moves (visible), LT empowered versions use the individual meter. Alternative: glass-cannon artillery.
- Weapon super *Starfall*: rain of marks of all three types, and the partner's next hits chain-detonate them.
- Level element: **prime and detonate** (a different player's finisher hit detonates), and class synergy Hammer + Magic (a Hammer slam on a primed enemy triggers a bigger blast).
- Related but separate: **Focus Call** (proposed X move) tags a "target" that takes bonus damage from the partner. It is not an elemental mark; the session decides whether two systems are too many.

## 2. Open questions for the session

1. **Detonation trigger** (hole #1 in `AUDIT.md`): any hit, or only finisher hits (a launch, medium or stronger knockback, a B move, an LT move)? Proposal: finisher-only, with a visible "ready" glow.
2. **Who can apply marks?** Only Magic, or also moves from other classes and the environment (oil barrels, electric boxes)?
3. **The effects:** are three marks and these three effects right? Does the second mark replace the first, stack, or combine (e.g. Flame + Frost)?
4. **Duration and visibility:** is 6 s right; how do we show the ready-to-detonate state clearly for both players, and for colour-blind players?
5. **Magic's identity:** Primer/Zoner or glass-cannon artillery? Does a Magic player have anything fun to do when playing with another Magic player?
6. **Do Magic's Y moves apply marks?** It makes Magic the only class with an extra system on Y. Keep or drop?
7. **Damage balance:** how much of the damage budget lives in detonation versus the direct hit, and what is the boss/elite cap?
8. **Team meter reward** from detonation and from detonations by the Magic player himself.
9. **Focus Call vs marks:** keep both, merge, or drop one.
10. **Enemy interactions:** resistances, enemies that remove marks, Magic-pose enemies that apply marks to players (the same system reversed).
11. **Weapon super rider and Duo Special:** does Starfall's chain detonation need the partner's hit?
12. **Cooldowns:** the values (3-10 s) and the visual ring on the hands.
