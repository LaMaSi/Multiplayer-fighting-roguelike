# Class Moves (B slots) and the Move Pool

Status: proposal for review. The names of the existing moves (✔ = already implemented) come from `PLAN.md`. Everything marked NEW still needs to be built. Overrides: `DESIGN.md` wins on the co-op rules.

## 1. Rules for B moves

- 5 B slots: **B, B+Up, B+Forward, B+Down, B+Back** (forward/back relative to facing). Every class has **8 B moves**, so 3 are spares for rewards.
- B slots accept only moves of the player's own class. The moves are slot-agnostic: any of the 8 can go in any of the 5 slots.
- **Starter roll** (run start): B, B+Forward and B+Up are filled with random moves from the class marked ★ (starter-safe). Rules for the roll: no two moves with the same role, and at least one move must be usable at mid range.
- **LT version:** holding LT during the move spends a little Style meter for a stronger/larger version (listed per move).
- **Height:** H = high (crouch avoids it), M = mid, L = low. Applies to the hit and to projectiles.
- **Co-op hook:** every move should pass the Co-op Test in `DESIGN.md`. The hook column says how the move creates something for the partner. A move without a clear hook gets one before it ships.
- Speed: F = fast, M = medium, S = slow, VS = very slow.

## 2. Brawler: fists, fastest, short reach. Role: **Relay and juggle**

Identity: keeps combos alive and passes enemies between the players. Weak at range.

| # | Move | Speed | H | What it does | LT version | Co-op hook |
|---|---|---|---|---|---|---|
| 1 | ✔ Jab Chain ★ | F | M | 3-hit combo, the third hit pushes slightly | 4th hit with a launch | Each hit adds to the shared combo; the final push sets up the partner |
| 2 | ✔ Dash Punch ★ | F | M | Forward lunge punch, closes gaps | longer dash and armour on startup | Dash *through* the partner's launched enemy for a relay hit |
| 3 | ✔ Rising Dragon | M | M | Invulnerable uppercut launcher | higher launch | Launches the enemy for the partner to juggle |
| 4 | ✔ Heavy Haymaker | S | M | Slow, very high knockback punch | extra wall bounce | Sends enemies flying into the partner's range |
| 5 | ✔ Wall-bounce Elbow ★ | M | M | Elbow that bounces enemies off walls | bounces twice | Bounce returns the enemy towards the center for the partner |
| 6 | NEW Counter Palm | M | M | Counter stance; if hit during the window, the attacker is staggered | larger window | A successful counter opens a **relay window**: the partner's next hit on the enemy is empowered |
| 7 | NEW Shoulder Rush ★ | M | M | Armoured short charge that shoves enemies | longer and pulls enemies along | Shoves enemies away from a **downed or channeling partner** |
| 8 | NEW Pop-up Kick | F | L→launch | Quick kick that lifts a grounded or falling enemy; low damage | two lifts | Keeps the juggle alive when the partner's launcher is ending (extends the combo timer) |

**Super (weapon):** *Hundred Fists*. A barrage that ends in a launcher. Team rider: the launch opens a free relay window for the partner.

## 3. Sword: medium-slow, long reach. Role: **Guard and counter**

Identity: controls space and protects. Many parry-type moves. Rewards timing over mashing.

| # | Move | Speed | H | What it does | LT version | Co-op hook |
|---|---|---|---|---|---|---|
| 1 | NEW Long Slash ★ | M | M | Wide horizontal slash, long reach; 2-hit string | third overhead hit | Wide arc catches enemies on both sides of the partner |
| 2 | NEW Thrust Lunge ★ | M | M | Forward piercing lunge, hits every enemy in a line | longer lunge | Pierces *past* the partner's target so both hit |
| 3 | NEW Rising Slash | M | M | Upward arc that launches; reaches higher than the fist | bigger arc | Launcher for the partner |
| 4 | NEW Low Cut | M | L | Low sweep that trips | wider, 2 hits | Trips enemies the partner can then smash |
| 5 | NEW Wind Slash | M | M | Crescent projectile with short range | bigger and pierces | Hits enemies attacking the partner from a distance |
| 6 | ✔ Parry Counter ★ | F | M | Timed parry that ripostes | wider timing window | **Cover Parry:** parry bubble also covers a partner standing close; perfect parry fills Style meter |
| 7 | NEW Deflect Stance | M | M | Hold-stance: parries projectiles and reflects them; no counter | wider cone | Reflected projectiles hit enemies near the partner |
| 8 | NEW Riposte Step | M | M | Hop backwards; if hit during the step, auto-counter | longer hop | Retreating towards the partner and counters for them |

Parry-type moves: #6, #7, #8 (3 of 8).

**Super (weapon):** *Phantom Cuts*. Dash through enemies with many slashes. Team rider: finishes with a launch that opens a relay window for the partner.

## 4. Hammer: very slow, very long reach, dead zone up close, very strong. Role: **Breaker and launcher**

Identity: break guards, send things far. Cannot hit very close (the X moves and the dash cover close range). Needs the partner to cover its slow startup, which is the whole point.

| # | Move | Speed | H | What it does | LT version | Co-op hook |
|---|---|---|---|---|---|---|
| 1 | NEW Overhead Smash ★ | VS | H | Huge downward smash, spikes and ground-bounces enemies | bigger shockwave | The ground-bounce re-launches the enemy for the partner |
| 2 | NEW Side Sweep ★ | S | M | Wide horizontal swing with very long reach, big knockback | wider and 2 hits | Sweeps enemies into the partner's attack |
| 3 | NEW Sky Launcher | S | M | Upward swing, very high launch | even higher | The big juggle opener |
| 4 | NEW Quake Line | S | L | Slam that sends a shockwave line along the ground; trips | longer line | The line trips a group so the partner can clean up |
| 5 | NEW Whirlwind Haul | S | M | Spinning swing that hits in front and behind; fixes the dead zone partly | extra spin | Pushes enemies off a partner who is channeling |
| 6 | NEW Guard Breaker | VS (charge) | M | **Charged** slam that breaks shields and armour and stuns; hold to charge | full-charge area | The partner must cover the charge, and a **stunned** enemy is a free relay target |
| 7 | NEW Home Run ★ | S | M | Swing that launches enemies **or your partner** far horizontally (a human projectile) | longer range | Partner becomes a flying kick; a way to cross gaps (couples with Ally Toss) |
| 8 | NEW Bulwark Plant | M | M | Plant the hammer, creating a barrier pillar that blocks projectiles and melee for about 4 s | taller and longer | The partner can shelter behind it; the pillar can also be launched with Home Run |

**Super (weapon):** *Meteor Drop*. Jump and crash down with a large radius. Team rider: the shockwave launches every enemy for the partner.

## 5. Magic (locked in meta progression): ranged, glowing hands. Role: **Primer and zoner**

Identity: sets up the partner's big hits. Lowest HP, slow projectiles, no strong close-range tools (the X moves are the answer). No mana bar; B moves use **cooldowns** (visible on the player), and LT versions use Style meter. This is the **proposed** direction from `DESIGN.md` §5; it will change if you pick the other option.

### Mark system
- Three marks: **Flame**, **Volt**, **Frost**. An enemy carries one mark at a time (6 s). The marked enemy glows in the mark's colour.
- **Detonation:** any hit by the *other* player detonates the mark (full effect). Magic's own hits detonate at half power. The mark is then consumed.
  - Flame: area explosion.
  - Volt: chain lightning to nearby enemies plus a short stun.
  - Frost: freezes; the next hit shatters for a bonus and a launch.
- Bosses and elites: detonation deals a capped % of their HP.
- Detonating a mark fills the team's Style meter (see `DESIGN.md` §5).

| # | Move | Speed | H | What it does | Cooldown | LT version | Co-op hook |
|---|---|---|---|---|---|---|---|
| 1 | ✔ Fireball ★ | M | M | Large slow projectile, Flame mark | 3 s | larger, explodes immediately | Partner detonates the Flame mark |
| 2 | ✔ Spread Shot | M | M | 3-way small projectiles, Flame mark each | 4 s | 5-way | Marks several enemies for a partner area attack |
| 3 | ✔ Boomerang Disc ★ | M | M | Disc that hits out and back, Volt mark | 4 s | returns twice | Two hits mean two marks/detonations windows for the partner |
| 4 | ✔ Ground Wave | M | L | Low wave along the ground, Frost mark, slows | 4 s | wider | Frozen enemies are an easy target for the partner |
| 5 | ✔ Teleport Strike | F | M | Blink behind an enemy and strike; detonates a mark on it at half power | 6 s | detonates at full power | Blink to a partner in trouble, or flank for them |
| 6 | NEW Arcane Beam | S (channel) | M | Hold to channel a beam that applies marks over time; interrupted if hit | 8 s | wider, longer | A **channel** the partner must protect (co-op charge-up) |
| 7 | NEW Gravity Well | M | - | Zone for about 3 s that pulls enemies together | 10 s | bigger and longer | Groups enemies for the partner's area move or the Hammer sweep |
| 8 | NEW Mirror Ward | F | - | Shield bubble on you or your partner (aim at them): absorbs one hit then reflects a small blast | 10 s | covers both players | A pure support move: protects the partner, and rewards Style meter on absorb |

**Super (weapon):** *Starfall*. Rain of marks across the screen (all three types). Team rider: the partner's next hits detonate marks in a chain across all enemies.

## 6. The rest of the pool

### Universal (X), 12 moves: identical for every class

| Move | Role |
|---|---|
| ✔ Off-hand Jab (start in X) | basic close attack (NEW as a universal; replaces the starter Jab Chain on X) |
| ✔ Back Kick | hits behind |
| ✔ Guard Block | block |
| ✔ Reflect Shield | reflects projectiles |
| ✔ Grab & Throw | throws an enemy as a projectile |
| ✔ Pull Hook | pulls an enemy to you |
| ✔ Ally Toss | throws the partner as a kick |
| ✔ Heal Pulse | small heal on hit |
| ✔ Rage Taunt | self buff, draws aggro |
| ✔ Boost Spark | buffs the partner's next hit |
| NEW Pocket Mine | drops a proximity mine (replaces Dodge Roll Strike) |
| NEW Spark Shot | small off-hand projectile, never affected by weapon |

### Adaptive (Y), 10 moves: modified by the class's multiplier table

| Move | Role | Notes |
|---|---|---|
| ✔ Uppercut | launcher | Brawler: fast fist; Sword: arc; Hammer: slow, big |
| ✔ Leg Sweep | low trip | |
| ✔ Spin Kick | 360 multi-hit | |
| ✔ Cyclone | moving whirlwind | |
| ✔ Shockwave Stomp | ground AoE | |
| ✔ Dive Kick | air spike | |
| ✔ Anti-air Hook | hits upwards | |
| ✔ Pillar Smash | breaks and throws crates | |
| ✔ Flurry | rapid low-knockback hits | |
| NEW Slide Strike | low sliding attack that ends in a crouch | |

### Retired
- Dodge Roll Strike (replaced by the RT dash and Pocket Mine).

### Reassignment of the 30 original moves
- Brawler B: Jab Chain, Dash Punch, Rising Dragon, Heavy Haymaker, Wall-bounce Elbow
- Magic B: Fireball, Spread Shot, Boomerang Disc, Ground Wave, Teleport Strike
- Sword B: Parry Counter
- Universal X: Back Kick, Guard Block, Reflect Shield, Grab & Throw, Pull Hook, Ally Toss, Heal Pulse, Rage Taunt, Boost Spark
- Adaptive Y: Uppercut, Leg Sweep, Spin Kick, Cyclone, Shockwave Stomp, Dive Kick, Anti-air Hook, Pillar Smash, Flurry
- Retired: Dodge Roll Strike

### Totals
- Class B moves: 32 (8 per class), of which 11 are existing (5 Brawler, 5 Magic, 1 Sword) and 21 are new.
- Universal 12 (2 new), Adaptive 10 (1 new). Total pool: 54 moves, 24 new.

## 7. Weapon supers (one per class, fixed for now)

| Class | Super | Team rider |
|---|---|---|
| Brawler | Hundred Fists | the launch opens a relay window |
| Sword | Phantom Cuts | finishes with a launch for the partner |
| Hammer | Meteor Drop | the shockwave launches all enemies for the partner |
| Magic | Starfall | the partner's hits chain-detonate the marks |

Input: down, down-forward, forward, twice, then B. The generic super (1 of 8, X) is still to be designed.

## 8. Open questions

1. Magic as Primer/Zoner or as a pure glass-cannon artillery? (see `DESIGN.md` §5)
2. Are the cooldown values OK (3-10 s), and should cooldowns be visible as small rings on the hands?
3. Hammer's Home Run launching the partner: allowed with friendly fire off? Default: yes, a partner launch never damages the partner.
4. Do the generic supers (8) get a design pass next?
5. Starter roll: should the first B move be guaranteed to be a ★ move? Default: all three rolled slots use ★ moves.
