# Design Audit: holes and inconsistencies

Status: review of `PLAN.md`, `ITERATION2.md`, `DESIGN.md` and `CLASS_MOVES.md`. Doc inconsistencies are already fixed (section 3). The real design holes are in section 1 and 2, each with a proposed default that I'll implement unless you object. Items marked **[decide]** need your answer.

Decided in this session: upgrades are lost when a move is replaced.

## 0. Resolution log (latest, after your answers)

| # | Status | Outcome |
|---|---|---|
| 1 | **Moved** | Own session: `MARKS.md` |
| 2 | Accepted | RB = interact/grab (see `DESIGN.md` §9 controller map); LB = Duo trigger |
| 3 | **Solved** | Ghost can operate puzzles and cross gaps (`DESIGN.md` §9) |
| 4 | **Decided** | Dead player becomes a ghost (`DESIGN.md` §9) |
| 5 | **Decided** | Respawn at last safe ground; pits must be obvious and hard to fall in by accident |
| 6 | **Decided** | Local hit-stop |
| 7 | **Open** | Map nodes and shops: `ECONOMY.md` §2 |
| 8 | **Decided** | Meta meter fills with level score (also on death); spend points on moves (one after another) and generic features: `ECONOMY.md` §1 |
| 9 | Open | Duo Special content (class pair proposal stands); trigger decided: both press LB, needs the shared meter |
| 10 | **Resolved** | Loadout is 3 random B + 1 random Y + 1 random X, no reroll at start; rerolls are a meta unlock |
| 11 | **Decided** | Individual special meters plus one shared team meter (`DESIGN.md` §5) |
| 12 | **Dropped** | Not an issue (like Street Fighter); the parser just needs a generous buffer |
| 13 | Open | Pillar Smash vs RB throw: unchanged default |
| 18 | **Dropped** | Effort estimates removed from all docs |

(The detailed table below is the original audit text.)

## 1. Design holes that can break the game (fix before building)

| # | Hole | Why it matters | Proposed default |
|---|---|---|---|
| 1 | **Mark detonation has no skill gate.** Any hit by the partner detonates a mark, so the Brawler's first Jab consumes it | Primer play becomes automatic; detonations are tiny; no communication | Only a **finisher hit** detonates: any launch, knockback at least medium, a B move, or an LT move. Jabs and Flurry do not. The mark glows brighter when "ready to detonate" **[decide]** |
| 2 | **One button for too many jobs.** RB is proposed for grab/throw, and "interact" (hack terminal, levers), revive and carry also need a button. Revive was "hold X/Y/B", which would trigger attacks | Accidental attacks while reviving; conflicts when near a partner and a terminal | RB is the single **interact/grab** verb with a priority order: downed partner (revive) > terminal/lever > partner (grab) > enemy > container. Hold to revive/hack, tap to grab |
| 3 | **Dead or downed player at a co-op obstacle.** Gap needing a throw, two-lever door, hack terminal: nothing works if the partner is down | The level softlocks | Obstacles that need both players get a fallback after a downed timer (a bridge extends, a lever auto-holds) and the level can only be left when the partner is revived or respawned |
| 4 | **Dead player is a spectator.** Revives are limited per level, so the other can fight solo while the first just watches | Fails Co-op Test #4 | A permanently downed player respawns at the next wave lock at 30% HP (so no spectating for more than one wave). Run ends only when both are down at once |
| 5 | **Pits and falling.** Throwing the partner over gaps implies pits, but there is no fall rule | A bad throw means the partner dies | Falling = respawn at the last ground point with minor damage and a short fade, no death |
| 6 | **Global hit-stop freezes the partner too.** Relay hits get "bigger hit-stop" and Duo Specials use slow-motion | The other player's inputs stall; feels laggy in co-op | Hit-stop is **local** (attacker and victim only), screen shake and zoom are global but small. Global slow-motion only for bosses and Duo Specials |
| 7 | **Map node choice no longer chooses a reward.** Every level gives both rewards now, but the plan's node map had reward-type nodes | The map choice has no meaning; and two players must agree on a node | Nodes differ by **risk and bonus** (elite = harder + an extra card, container-rich, rest = heal, mystery), and both players vote at the same time; disagreement = rock-paper-scissors as in rewards **[decide]** |
| 8 | **Meta unlocks are undefined.** The plan says "15 of 30 moves start locked", but the pool is now 52, with classes | No economy design | Lock Magic and about 14 of the 52 moves (B moves of the other three classes mostly open). Currency from level ranks, relay hits and rescues (not plain kills) **[decide]** |
| 9 | **Duo Specials are undefined.** The plan says they depend on the "Y-slot moves", but Y is empty at the start and adaptive | Unknown content; impossible to build | Duo Special is chosen by the **class pair** (4 classes = 10 combos, built as 4 first: Brawler+Any, Sword+Any, Hammer+Any, Magic+Any versions), with a generic fallback |
| 10 | **Loadout swap on the run-start screen is impossible.** B moves are class-locked, X start is the fixed Off-hand Jab, Y is empty | The designed "trade a move" conversation can't happen | Drop it. Same-class pairs may swap one rolled B move. Re-roll is **joint**: both must press to re-roll once |
| 11 | **Super meter owner is still open** (shared Link vs individual). Duo thresholds, LT cost and supers all depend on it | Blocks meter UI, Duo Specials, generic supers | Shared Link meter (see `DESIGN.md` §5) **[decide]** |
| 12 | **Motion inputs vs everything.** Double quarter-circle + X/B conflicts with crouch, down+button moves, forward+button moves and the RT dash; LT hold has to be "at move start" or "at release" for charge moves | Misfires; supers by accident; LT ambiguity | Motion parser with priority (see `DESIGN.md` §5), and LT is read **when the move starts** (for charge moves: when charging starts). The crouch pose is not triggered by a motion input in progress |
| 13 | **Pillar Smash (Y) vs the new RB throw** both break and throw crates. Also Pocket Mine vs Guard Block etc. are fine | Redundant | Pillar Smash keeps the *smash*; RB does carrying and throwing. Pillar Smash replaced if redundant after playtest |

## 2. Balance and scope risks

| # | Risk | Proposed handling |
|---|---|---|
| 14 | Hammer very slow + dead zone + crouch/dash might be miserable alone | Play it with the Off-hand Jab and Whirlwind Haul; test early. Hammer reward: guard break and launch power |
| 15 | Magic is a pure support class and is locked: new players never see its best moves | Show Magic in a tutorial hint; the Primer role is the first unlock |
| 16 | The adaptive Y design means 40 variants (10 moves x 4 classes) of animations | Use the modifier table first; per-class visuals only for the weapon trail |
| 17 | Co-op elements (terminal, charge-ups, levers, throws, marks) are many | First Streets levels get only 4 (terminal, charge-up B moves, two-lever door, shielded enemy); others are added per biome |
| 18 | Time estimates in `ITERATION2.md` leave out several systems | Updated in the doc (section 3) |
| 19 | Enemy tokens/aggro: Taunt Roar, aggro rules, wave locks and 2-player scaling need one AI "director" rule set | One doc section before M3-like work: tokens per wave, aggro by recent taunt/damage |

## 3. Inconsistencies already fixed in the docs

- "at least 10" X/Y moves changed to exactly 10 (`DESIGN.md` §2).
- Spare B moves: "3 spares" corrected to 5 unlocked by level-ups (`ITERATION2.md`).
- Removed stale mana references (HUD, `ClassData`, effort table, "out of mana").
- X start: fixed Off-hand Jab (not random), and the run-start loadout screen text matches (`DESIGN.md` §4, `ITERATION2.md` Phase B).
- Replacement flow: upgrades lost on replacement (`DESIGN.md` §3.3).
- Mark names unified: **Flame, Volt, Frost** (the old docs said fire/shock/oil/slow). Focus Call uses "target", not "mark".
- Open question numbering in `CLASS_MOVES.md`.
- `PLAN.md` carries a note listing which parts are superseded.
