# Aerial combat rework and the Lance

Status: first implementation, **not yet run or playtested** (no engine was available when it was written). Numbers are first guesses for the Move Lab. Everything here is code under `scripts/`; the tests added to `tests/smoke_classes.gd` and `tests/run_setup_test.gd` have not been run either.

## 1. Decisions (from the design discussion)

- **No combo cap.** Infinite combos are fine in a co-op game: player skill is the only limiter. What must be guarded against is an enemy that *combos itself* (stuck in geometry or a loop with no player input, several hits a second). See "Open items".
- **Passing is rewarded.** When one player catches an enemy that the *partner* launched, the juggle is restored to full strength and the enemy hangs briefly. This replaces the earlier idea of a juggle limit.
- **Elites and bosses stay combo-able but cannot be thrown** (Grab and Throw, Home Run, Whip Fling). Not implemented: elites are only a run-map node type so far; `can_be_grabbed()` is the natural hook.
- **Class-scaled air rules.** Every class gets a small version; the Lance gets a bigger one.
- **Class `jump` stat is now wired** (it was unused before). Hammer 0.95 and Magic 1.05 therefore jump slightly differently than before.
- **Parked:** Scythe (elements through weapon imbue, which depends on the marks session in `MARKS.md`), Whip (pull/tether controller, see the discussion in `CLASS_MOVES.md` once written). **Magic**: element chosen per slot is the preferred direction for its marks.

## 2. Air rules (all classes)

| Rule | Behaviour | Code |
|---|---|---|
| Air hang | A melee hit that connects while you are airborne sets `hang_t`: for N frames gravity is x0.3 and falling speed is capped. N = 8 (base) or 18 (Lance). | `Actor._st_attack`, `Fighter.on_hit_landed`, `ClassData.air()` |
| Air refund | The first connecting hit of each move refunds the air dash, the air jump and the launcher jump-cancel, up to `refunds` times per air time (1 base, 3 Lance). Landing resets everything. | `Fighter.on_hit_landed` |
| Launcher jump-cancel | After a launcher (tag `launcher`) connects and reaches its cancel frame, pressing Jump cancels into a jump (x1.05, scaled by the class jump) to follow the enemy. Once per air time; moves that lift you off the ground (Uppercut, Rising Dragon) still allow it. | `Fighter._attack_extra` |
| Air variant | A move can name an `air_variant` that is used instead when its slot is pressed in the air (Lance Thrust becomes Air Thrust). | `MoveData.air_variant`, `Fighter._try_slot` |
| Catch | A hit on a launched enemy by a different player than the last hitter restores a full-strength launch (`juggle_hits` reset) and gives the enemy a 12-frame hang. A hit made while the attacker is airborne gives a 6-frame hang. | `Actor.take_hit`, `Actor._start_launch`, `Actor._st_launched` |
| Sky relay | A relay hit made while the attacker is airborne deals x1.25 and shows "SKY RELAY". | `Coop.pre_hit` |
| Air parry | A successful parry in the air bounces you up and refunds the air options. Applies to every parry-type move (Sword Parry, Riposte Step, Lance Air Parry). | `Fighter._do_parry` |
| Skyhook | A hit with `reset_juggle` restores a full launch on a launched enemy. | `HitInfo.reset_juggle` |

## 3. Lance: aerial relay

Long narrow reach, high jump, innate double jump. Every Lance move works on the ground and in the air.

| | Speed | HP | Jump | Reach (Y moves) | Startup | Recovery | Dmg | KB | Air |
|---|---|---|---|---|---|---|---|---|---|
| Lance | 1.05 | 95 | 1.15 | x1.6 | x0.95 | x1.0 | x0.95 | x0.9 | 3 refunds, 18-frame hang, double jump |

| # | Move | Id | What it does | Co-op hook |
|---|---|---|---|---|
| 1 | Pole Vault ★ | `pole_vault` | Jab-launch that carries you up with the enemy. A launcher, so it can be jump-cancelled. | Starts an air juggle alone; the partner can take over. |
| 2 | Thrust ★ | `thrust` | Long narrow thrust that pierces. In the air it becomes Air Thrust (`thrust_air`): stabs down at 45 degrees and pops a juggled enemy. | Pierces past the partner's target. |
| 3 | Plunge ★ | `plunge` | Air-only dive (hops up from the ground like Dive Kick). Pins the target in place (long stun, no knockback) for about a second. | A pinned enemy is a free Hammer target. |
| 4 | Windmill | `windmill` | Spinning lance, three hits, the last launches. Small lifts keep you afloat. | Pushes enemies off a channeling partner. |
| 5 | Skyhook | `skyhook` | Launcher that restores a worn-out juggle. | Extends the partner's launches. |
| 6 | Vault Over | `vault_over` | Leap over an enemy or the partner, invulnerable in the air. No damage. | Reposition to a partner in trouble. |
| 7 | Javelin | `javelin` | Thrown lance that pins what it hits (stun 70, no knockback). | A pinned enemy is a relay target. |
| 8 | Air Parry | `air_parry` | Parry window; in the air a success bounces you up and refunds your air options. | Defensive counterpart for aerial play. |

Super (not implemented): *Heaven's Fall*. Leap high, then rain down piercing strikes; the hit enemies end up launched for the partner's sky relay.

The weapon is a classic **lance**, drawn after a spear-fighting pose reference: a long straight pole (about 200 px) held in both hands, spread wide and mid-shaft (the rear hand is solved onto the pole with arm IK, so both hands stay on it in every pose), with a triangular spearhead, a collar and a small pennon. The idle stance is a wide, low lunge with the lance carried level; the thrust is a long flat extension. Reach in front of the front hand is unchanged (104 px), so the authored hitboxes still match. Drawn in code in `stick_figure.gd`; rendered and checked for the idle and the main attack poses, not yet for every move.

Not done for the Lance: LT versions, the weapon super, the tip mechanic (see below), per-move `wp_rot` polish.

**Tip mechanic (built):** a Lance strike that lands with the **spearhead** (the triangular head, about 56 px at the tip) instead of the shaft deals x1.4 damage and x1.15 knockback, +2 hit-stop frames, and shows a ring and a "TIP" callout. The check is geometric (`StickFigure.head_touches`, used from `AttackRunner._connect`): where the head is on screen when the hit connects. Measured with Thrust: enemies 30 to 70 px away take 7.0 (shaft), 90 to 170 px take 9.8 (tip). Radial moves (Windmill) and projectiles never tip; Pole Vault and Skyhook point upward, so they tip against enemies that are already in the air.

## 4. Combos with existing moves (estimates from the constants, not simulated)

Gravity 2300, jump -880 (apex about 168 px), Uppercut launches at -760, Rising Slash at -820. After an Uppercut hit, the attacker is already lifted about 30 px by the move itself and the enemy is about 65 px up at the Uppercut's cancel frame (frame 12). A jump-cancel sets the jump speed to about -924, so the attacker passes the enemy after roughly 5 frames and can reach it with a normal air attack. The enemy stays in the air for about 0.55 s after the cancel, enough for one or two follow-ups; the hang and refunds extend that. Expected combos:

- **Uppercut (Y), jump-cancel, then any air-capable move** (Flurry, a sword slash, a Lance thrust). Slide Strike and the other ground-only moves are excluded.
- **Sword Rising Slash, jump-cancel, Long Slash / Wind Slash in the air.**
- **Sword Parry in the air** now bounces you up (a side effect of the shared air-parry rule).
- **Brawler Rising Dragon:** lifts the attacker high; the jump-cancel is available from its last hit.
- **Hammer Sky Launcher** is the natural hand-off: the Lance partner catches with Skyhook or Air Thrust.
- The jump-cancel is once per air time unless a connecting air hit refunds it, so a base-class chain is launcher, one or two air hits, then fall. The Lance can chain longer.

## 5. Open items

1. **Self-comboing enemies** (stuck against geometry or a hazard): not guarded yet. Proposal: combo and meter credit only for hits whose source is a player action, plus a check that ignores repeated hits on an enemy that is stationary and wedged.
2. **Refund cap** (1 base, 3 Lance) is the one limit left; it only caps air mobility, not combo length.
3. **UI:** the Lance is in the weapon-choice screen (six rows now, spacing computed from the row count) and the random pool. Layout unchecked on screen.
4. **Unlock:** the Lance is available from the start.
5. **Camera and stage ceiling** with taller combos: unchecked.
6. **Elite throw rule:** to implement with the elite enemy type.
