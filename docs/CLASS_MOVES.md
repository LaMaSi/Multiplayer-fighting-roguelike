# Class Moves (B slots) and the Move Pool

Status: proposal for review. The names of the existing moves (✔ = already implemented) come from `PLAN.md`. Sections: B (2-5), X (6), Y (7), overview and totals (8), supers (9). Everything marked NEW still needs to be built. Overrides: `DESIGN.md` wins on the co-op rules.

## 1. Rules for B moves

- 5 B slots: **B, B+Up, B+Forward, B+Down, B+Back** (forward/back relative to facing). Every class has **8 B moves**, so 5 are unlocked later **through the personal level-up** (`DESIGN.md` §3.2), and B moves are never part of the shared X/Y card choice.
- B slots accept only moves of the player's own class. The moves are slot-agnostic: any of the 8 can go in any of the 5 slots.
- **Starter roll** (run start): B, B+Forward and B+Up get 3 random ★ moves from the class, plus 1 random ★ Y and 1 random ★ X (an attack). Rules for the roll: no two B moves with the same role, and at least one B move must be usable at mid range.
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
| 7 | NEW Home Run ★ | S | M | Swing that launches enemies **or your partner** far horizontally (a human projectile) | longer range | Partner becomes a flying kick; a way to cross gaps (couples with the grab/throw; see `DESIGN.md` §8) |
| 8 | NEW Bulwark Plant | M | M | Plant the hammer, creating a barrier pillar that blocks projectiles and melee for about 4 s | taller and longer | The partner can shelter behind it; the pillar can also be launched with Home Run |

**Super (weapon):** *Meteor Drop*. Jump and crash down with a large radius. Team rider: the shockwave launches every enemy for the partner.

## 5. Magic (locked in meta progression): ranged, glowing hands. Role: **Primer and zoner**

> **Pending:** all marks and detonation content here is a draft. It is being collected in `MARKS.md` for its own session.

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

## 6. X moves: Universal (10), identical for every class

X has 5 slots (X, X+Up, X+Forward, X+Down, X+Back) and a pool of **10** moves, so 5 are spares for rewards. Slot-agnostic. One random ★ X move is equipped at run start (an attack: Off-hand Jab, Spark Shot or Grab & Throw). The names make clear that X moves are *the same for everyone* (off-hand actions, not weapon actions).

| # | Move | Speed | H | What it does | LT version | Co-op hook |
|---|---|---|---|---|---|---|
| 1 | NEW Off-hand Jab ★ | F | M | Quick 2-hit jab with the free hand; low damage, tiny knockback. Always available, always close range | third hit | Fast combo filler that keeps the shared combo alive |
| 2 | NEW Spark Shot ★ | M | M | Small straight projectile, not affected by the weapon | larger, slightly pierces | Pokes enemies off a **channeling or reviving** partner |
| 3 | ✔ Guard Block | F | H/M | Hold to block high and mid hits (not low); chip damage | perfect-block window fills Style meter | **Back-to-back:** when blocking within about 1.5 m of the partner, damage taken by both is reduced |
| 4 | ✔ Grab & Throw ★ | M | M | Grab a close enemy and throw it as a projectile that bowls over others | longer throw | A thrown enemy is a **relay hit** target for the partner |
| 5 | ✔ Pull Hook | M | M | Hook pulls an enemy to you | pulls and stuns | Pull enemies **onto the partner's charged move**, or pull a downed partner out of a hazard |
| 6 | ✔ Grapple Dash (replaced Ally Toss) | S | - | Hook the nearest enemy and reel yourself in with a hard hit | longer hook range | Closes any gap; the opposite of Pull Hook |
| 7 | ✔ Heal Pulse | M | - | Area heal pulse (cooldown about 15 s). **Partner heals 100%, you heal about 25%** | wider radius | You cannot heal yourself well, so you need the partner (and vice versa) |
| 8 | ✔ Taunt Roar (was Rage Taunt) | M | - | Draws enemy aggro to you for about 4 s with 30% damage reduction | wider and longer | The "tank" move. Lets the partner flank, channel or revive |
| 9 | ✔ Boost Spark | F | - | Buffs the **partner's** next hit (more damage and knockback) if within range; gives nothing to you | buffs the next two hits | Pure partner-enabling; stacks with relay hits |
| 10 | NEW Pocket Mine | M | L | Drop a proximity mine; explodes on enemies stepping on it | bigger blast | The **partner can hit the mine** to trigger or bat it into a group |

Cut from the pool (decision to confirm): **Reflect Shield** (covered by the Sword's Deflect Stance and Magic's Mirror Ward) and **Back Kick** (the Brawler's B+Back slot and the Hammer's Whirlwind Haul cover hitting behind). If you want them to stay, put them in Y (see §7 open questions).

## 7. Y moves: Adaptive (10), changed by the class

Y has 5 slots and a pool of **10** moves, so 5 spares for rewards. **One random ★ Y move is equipped at run start.** Every Y move is built once, then modified by the class's multiplier table. This keeps the content cost low (10 moves, not 40).

### Class modifier table (starting values, tune in the Move Lab)

| | Reach | Startup | Recovery | Damage | Knockback | Special |
|---|---|---|---|---|---|---|
| Brawler | x1.0 | x0.85 | x0.9 | x0.9 | x0.9 | combo timer +0.3 s |
| Sword | x1.5 | x1.15 | x1.1 | x1.1 | x1.0 | adds a thin blade trail |
| Hammer | x1.8 (dead zone at very close range) | x1.7 | x1.5 | x1.8 | x1.8 | breaks guard on hit |
| Magic | x1.2 (energy) | x1.0 | x1.0 | x0.8 | x1.0 | applies the move's **mark** |

### The 10 moves

| # | Move | Base (speed, height) | What it does | Co-op hook | Magic mark |
|---|---|---|---|---|---|
| 1 | ✔ Uppercut ★ | M, M | Launcher | Launches for the partner's juggle | Flame |
| 2 | ✔ Leg Sweep ★ | M, L | Low trip | Trips for the partner's smash | Frost |
| 3 | ✔ Spin Kick | M, M | 360 multi-hit | Pushes enemies away from a channeling partner | Volt |
| 4 | ✔ Cyclone | M, M | Moving whirlwind that drags enemies | Carries enemies to the partner's position | Volt |
| 5 | ✔ Shockwave Stomp | S, L | Ground AoE shockwave | Stuns a group the partner can then hit | Frost |
| 6 | ✔ Dive Kick | M, H | Air-only downward spike | The spike half of the **alley-oop** (launcher + spike) | Flame |
| 7 | ✔ Anti-air Hook | F, M | Hits upwards in front | Catches an enemy the partner launched (relay hit) | Volt |
| 8 | ✔ Pillar Smash | S, M | Smashes crates/props and throws them | Throws crates through enemy lines; partner's relay hit on the crate | none (telekinesis lift) |
| 9 | ✔ Flurry ★ | F, M | Rapid low-knockback hits | Keeps the shared combo alive | Flame |
| 10 | NEW Slide Strike ★ | F, L | Low slide that ends in a crouch | Slides under attacks, carries an enemy to the partner | Frost |

Per-class look of the same move (the Uppercut as an example): Brawler = quick fist, Sword = rising arc slash, Hammer = slow, huge upward swing (dead zone at the base), Magic = palm burst with a Flame mark. (Marks detonate on finisher hits only, see `AUDIT.md` #1.) Other Y moves follow the same rule.

Design guards:
- Y moves must never outclass B moves in damage per second, since B moves define the class.
- Hammer's dead zone applies to all its Y moves with a long reach, so the Hammer player prefers X moves up close (that is the intended trade).
- Y moves marked ★ are the likeliest first reward offers (an easy first Y).

## 8. Overview: slots, start loadout and counts

| Button | Slots | Pool | Start equipped | Nature |
|---|---|---|---|---|
| **X** | X, X+Up, X+Fwd, X+Down, X+Back | 10 universal | 1 random ★ X | same for everyone |
| **Y** | Y, Y+Up, Y+Fwd, Y+Down, Y+Back | 10 adaptive | 1 random ★ Y | modified by the class |
| **B** | B, B+Up, B+Fwd, B+Down, B+Back | 8 per class (32 total) | 3 random ★ from the class | class-specific, strongest |
| **A** | - | - | - | jump |
| **RT** | - | - | - | dash |
| **LT (hold)** | - | - | - | empowered version, spends the individual special meter |

Start loadout: **5 moves** (3 B, 1 X, 1 Y). Down-forward x2 + X/B = generic or weapon super.

### Totals
- B: 32 moves (11 existing, 21 new). X: 10 moves (7 existing, 3 new). Y: 10 moves (9 existing, 1 new).
- **52 moves in the pool, 25 of them new.**
- Cut or retired: Dodge Roll Strike (replaced by RT dash), Reflect Shield, Back Kick (decision to confirm).

### Reassignment of the 30 original moves
- Brawler B: Jab Chain, Dash Punch, Rising Dragon, Heavy Haymaker, Wall-bounce Elbow
- Magic B: Fireball, Spread Shot, Boomerang Disc, Ground Wave, Teleport Strike
- Sword B: Parry Counter
- X: Guard Block, Grab & Throw, Pull Hook, Ally Toss, Heal Pulse, Rage Taunt (renamed Taunt Roar), Boost Spark
- Y: Uppercut, Leg Sweep, Spin Kick, Cyclone, Shockwave Stomp, Dive Kick, Anti-air Hook, Pillar Smash, Flurry
- Cut: Dodge Roll Strike, Reflect Shield, Back Kick

## 9. Weapon supers (one per class, fixed for now)

| Class | Super | Team rider |
|---|---|---|
| Brawler | Hundred Fists | the launch opens a relay window |
| Sword | Phantom Cuts | finishes with a launch for the partner |
| Hammer | Meteor Drop | the shockwave launches all enemies for the partner |
| Magic | Starfall | the partner's hits chain-detonate the marks |

Input: down, down-forward, forward, twice, then B. The generic super (1 of 8, X) is still to be designed.

## 10. Open questions

1. Magic as Primer/Zoner or as a pure glass-cannon artillery? (see `DESIGN.md` §5)
2. Are the cooldown values OK (3-10 s), and should cooldowns be visible as small rings on the hands?
3. Hammer's Home Run launching the partner: allowed with friendly fire off? Default: yes, a partner launch never damages the partner.
4. Do the generic supers (8) get a design pass next?
5. Cut Reflect Shield and Back Kick as proposed, or keep them (they'd need to replace Pocket Mine / Slide Strike)?
6. Heal Pulse heals the partner fully and yourself about 25%: OK?
7. Hammer and Magic Y moves (reach dead zone, marks): tune after the first playtest.
8. Starter roll: should the first B move be guaranteed to be a ★ move? Default: all three rolled slots use ★ moves.

## 11. Charging (hold the button for up to 3 seconds)

Some moves can be **charged**: tap the button and the move plays normally; hold it and the figure winds up at the move's charge point, building charge for up to **3 s (180 frames)**. A full charge multiplies the hit's **damage** by `1 + charge_dmg` and its **knockback** by `1 + charge_kb` (projectiles also grow by up to 60 %); a partial charge gives a proportional bonus. Releasing plays the move out, and at full charge it releases by itself.

- **Data** (`MoveData`): `charge_max` (180), `charge_dmg`, `charge_kb`, plus the existing `hold`/`hold_frame` (the frame to wait at, just before the first hit or shot). The table `MoveDB.CHARGE` lists them; the badge tag `charge` is added automatically.
- **Which moves**: every category has some. **B:** Heavy Haymaker (Brawler), Thrust Lunge (Sword), Overhead Smash, Guard Breaker, Side Sweep and Sky Launcher (Hammer), Fireball (Magic). **X:** Spark Shot and Shockwave Clap (the Off-hand Jab stays a quick, weak punch). **Y:** Uppercut and Spin Kick.

| Move | Category | Full charge |
|---|---|---|
| Shockwave Clap | X | +80 % damage, +150 % knockback, **double range** (the blast and its ring grow) |
| Spark Shot | X | +150 % damage, +100 % knockback, bigger shot |
| Uppercut | Y | +100 % damage, **+200 % knockback** (a huge launch), +50 % distance |
| Spin Kick | Y | +100 % damage, +80 % knockback, **about 3x the travel distance** |
| Heavy Haymaker | B Brawler | +120 % damage, +90 % knockback |
| Thrust Lunge | B Sword | +100 % damage, +90 % knockback, **about twice the lunge distance**; the hit stays active along the longer path |
| Overhead Smash | B Hammer | +100 % damage, +80 % knockback |
| Guard Breaker | B Hammer | +120 % damage, +80 % knockback (was 1.5 s of charge) |
| Side Sweep | B Hammer | +100 % damage, +90 % knockback, +80 % step distance |
| Sky Launcher | B Hammer | +120 % damage, +70 % knockback, a higher jump with the launch |
| Fireball | B Magic | +100 % damage, +80 % knockback, bigger fireball |

- **Movement:** a charge also stretches the move's own movement (`charge_move`, the 4th number in `MoveDB.CHARGE`; the optional 5th, `charge_range`, grows the hitbox): lunges (`vel` events) cover about `1 + charge_move` times the distance, drives (`drive`) are `1 + charge_move` times as fast, and jumps rise higher. Launch speeds scale with the square root of the bonus because friction and gravity make distance grow with the square of the speed. Moves with movement: Spin Kick (+180 %), Thrust Lunge (+100 %), Side Sweep and Sky Launcher (+80 %), Heavy Haymaker (+70 %), Uppercut (+50 %). The Thrust Lunge's hit window also stretches (`charge_stretch`) so a longer lunge keeps hitting along its path. The card badge shows `+DIST` for these.
- **Co-op:** the charging player stands still and unarmoured while the ring fills, which is exactly what the partner can cover (see `DESIGN.md` charge-up elements).
- **Feedback:** energy **orbs gather** towards the body: only a few at first (3), more as the charge builds (15 at full), turning from translucent white into the player's colour; a rising tick every half second, a spark burst and a "MAX" label at full charge (`ChargeFx`, no ring). The body glows a little more as it charges.
- **Attack cards:** a chargeable move shows **only an icon**, a simplified hourglass (two triangles meeting at their tips) in a small gold tile (`UiKit.charge_chip`), on the reward, shop, loadout, run setup and pause screens. There is no text and no tag.
- **Test:** `tests/charge_test.tscn` (coverage by category and class, 3 s, damage and knockback scaling, partial charge).

**Short presses:** the charge ring, the ticks and the glow only start after the button has been held 14 frames (`AttackRunner.CHARGE_SHOW_FRAMES`), so a quick tap just plays the move.

## 12. Pull Hook and containers
The Pull Hook no longer damages or launches containers: it **drags them along the ground to the player** (`Prop` handles hits of kind `pull`).

## 13. Class stat bars (run setup)
The bars show hand-authored 1 to 10 `ratings` per class (`ClassData`), so every class has a clear low and a clear high:

| Class | Speed | Health | Reach | Damage |
|---|---|---|---|---|
| Brawler | 9 | 5 | 2 | 3 |
| Sword | 4 | 5 | 7 | 5 |
| Hammer | 2 | 9 | 7 | 10 |
| Magic | 6 | 2 | 10 | 3 |
