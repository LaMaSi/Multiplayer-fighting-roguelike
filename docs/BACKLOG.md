# Backlog: ideas for later iterations

Ideas the owner wants, parked until the current work is done. Not scheduled. Add new items at the top.

## High-impact knockdowns (Smash Bros style)

**Request:** a high-impact hit makes players and enemies fall to the ground, and they have to get back up, with a short invincible window while getting up.

**What exists today** (from a quick look at `scripts/actors/actor.gd` and `fighter.gd`, not yet verified in play): actors have `launched`, `down` and `getup` states, and the getup state grants about 0.6 s of `invuln`. So knockdown after a launch already exists in some form.

**What this item would change (to be designed when picked up):**
- Trigger on *impact strength*, not only on launch moves: any hit above a threshold (heavy B moves, finishers, big combos, enemy bosses) knocks the target down.
- Applies equally to players and enemies, so players can be knocked down too (and get a get-up input).
- The get-up has a short invincibility window, long enough to escape but short enough that it cannot be abused to stall.
- Smash-like details to decide: get-up options (stand, roll, attack), a "tech" input that cancels the knockdown if pressed just before landing, and how downed enemies interact with the combo counter, juggle relay and revive rules.
- Balance questions: how long enemies stay down (tokens / AI director), whether bosses are immune or have armour, and how the invincibility interacts with co-op combos (see `DESIGN.md`).

**Related docs:** `DESIGN.md` (co-op rules, juggle relay), `PLAN.md` §4 (state machine includes Knockdown), `CLASS_MOVES.md` (impact values per move).

## Combo counter display size

Decided in the HUD iteration: the combo number must not cover much of the screen. Growth per tier is capped (see `tests/mock_hud.gd`, `_combo_juicy`). Revisit if it feels too small in play.
