# Design Philosophy and Co-op Systems

This file overrides other docs when they conflict. `PLAN.md` is the original plan; `ITERATION2.md` is the work breakdown.

## 1. The pillar

**This is a co-op game first.** Two players with two controllers, one team. Every design decision must make players *look at each other, depend on each other, or enable each other*. A feature that is fun but could just as well exist in a single-player game is allowed only if it does not weaken the pillar.

### The Co-op Test (run it on every feature, every PR, every reward and every enemy)

1. **Interaction:** does this create a moment where one player's action changes what the other player can or should do?
2. **Communication:** would two players need to say something to each other ("cover me", "launch him", "I take the sword card")?
3. **Dependence:** can one player do it alone just as well? If yes, can we make the *team version* clearly better?
4. **Fairness:** does it avoid making one player a spectator (no waiting while the other does a long solo task, no solo-only screens)?
5. **Clarity:** can both players see at a glance what is expected of them (icons, rings, arrows, colours)?

If a feature fails 1-3 it needs a co-op twist or gets cut. If it fails 4 or 5 it must be redesigned.

### Anti-patterns to avoid

- Separate individual scores/ranks. Use a **team** rank.
- Pick screens where players choose in sequence (one waits).
- Pure buffs that only help yourself. Prefer ones that help the partner or need the partner.
- Long solo tasks where the partner just stands around.
- Co-op that is only "being on the same screen".

### Audit of current features (to apply in the next iteration)

| Feature | Status | Action |
|---|---|---|
| Shared combo counter, juggle relay | good | Keep. Make relay bonuses visible and loud |
| Revive | good | Keep. Add a revive-ring visual and a "carry me" option later |
| Reward screen (sequential picks) | **fails** | Replace with §3 |
| Random run-start loadout | partial | Players may **swap one move with each other** on the loadout screen (§4) |
| Class pick | ok | Class gives a *role* (see §6 class synergies) |
| Level-up: +HP / empower a move | partial | Make it a joint choice: one option for each player or one team upgrade |
| Rank at level end | partial | Team rank; add bonus points for relay hits and rescues |
| RT dash | neutral | Add: dash through the partner to give them a short speed boost? (optional, test) |
| Super meter | **unclear** | Own planning session, §5 |

## 2. Decisions made

- X = universal moves (identical for all classes, at least 10), Y = adaptive moves (modified by class, at least 10), B = weapon moves (8 per class).
- Magic is unlocked through meta progression. Brawler, Sword and Hammer (decide in a later review) are available from the start; Magic locked.
- **No separate mana bar.** Magic's heavy cost is solved through the super meter session (§5).

## 3. Reward screen (replaces sequential picks)

Goal: a short, tense, funny moment that both players share.

1. Show **3 random move cards**. Cards are drawn so that each player has at least one card they can use (class restriction is shown on the card).
2. **Both players pick at the same time** (stick to a card, press A to lock in). Each sees a cursor of the other.
3. **Different cards:** both get their pick. The third card is discarded.
4. **Same card (a clash):** play **Rock-Paper-Scissors** with face buttons: **X = rock, Y = paper, B = scissors**. 3-2-1 countdown, then reveal. Ties repeat.
   - The **winner** keeps the card.
   - The **loser** chooses from the **remaining two** cards.
5. Edge cases:
   - A class-locked card cannot be clashed over by a player who can't use it (they can still point at it, but not lock in).
   - If only one player can use any given card, no clash is possible.
   - If a player cannot use any remaining card (e.g. only an incompatible one left), offer a heal/upgrade instead.
   - Players who disconnect/don't press in 15 s auto-pick the leftmost card they can use.
6. After picking, each player chooses which slot gets the new move (can be done simultaneously).
7. Juice: cards flip in, clash animation with both hands "slamming" on the card, the RPS countdown with screen shake, and a loser's "ahh" reaction.

Same system for **level-ups and upgrades**: 3 team-upgrade cards (e.g. +max HP for both, empower a move for one, bigger revive window), with the same clash rule.

## 4. Run start

- Each player picks a class (Magic locked until unlocked).
- The game rolls random moves into each player's starting slots: B, side+B, up+B (from their class), X (from the universal pool). Y slots are empty at start.
- Loadout screen shows both players' rolls side by side, with one re-roll per player per run and **one move swap**: a player may trade one of their rolled moves with their partner's (if the class rules allow it). This forces a quick conversation ("take my fireball?").

## 5. Super meter: planning session (OPEN, to decide before implementing anything)

Problem: we have a per-player meter, Duo Specials needing both players at 50%, Magic needing "lots of meter", and no clear design for what the meter does. Under the pillar, the meter should reward **cooperation**, not solo damage.

Questions to settle:
1. What does the meter fill from? (damage dealt, relay hits, healing/reviving/protecting the partner, taking hits for the partner)
2. Is it shared by the team, individual, or both (e.g. individual fill, team spend)?
3. What is it spent on? (Duo Specials, solo supers, empowering the partner's next move, Magic's B moves)
4. How does Magic use it without becoming a meter-hog that blocks the partner?
5. Do Duo Specials depend on the moves/classes the two players have equipped?

Candidate designs to evaluate:
- **A. Link meter (shared):** one team gauge shown between the players. Fills from relay hits, protecting a charging partner, reviving, and staying close. Spent only on Duo Specials and "Link" versions of B moves. Magic's strongest B moves have a Link version.
- **B. Giving meter:** each player has their own meter, and it fills mainly from actions that help the partner. You can *give* meter to your partner with a move. Duo Special needs both players at the threshold.
- **C. Hybrid:** individual meters for solo supers (fill from own damage), plus a small team Link bonus. More complex, risks diluting the pillar.

Recommendation to test first: **A (Link meter)**, because it is the most direct answer to the pillar, and simple to read.

## 6. Co-op level elements (ideas to implement, ordered by estimated value)

**Priority 1: protect / operate**
- **Hack terminal / chest / gate:** one player interacts and channels (progress ring). Taking damage pauses (not resets) the progress. The partner must keep enemies off. Rewards: loot crates, shortcut doors, healing station.
- **Charge-up B moves** (Hammer slam, Magic beam): hold to charge, uninterrupted. If hit, the charge breaks. The partner protects. Charged moves are the strongest in the game, so you *want* cover.
- **Shielded enemies:** need a guard break from one player and then a launcher from the partner within 1 s. Alone it's possible but much slower.

**Priority 2: positioning and simultaneous actions**
- **Two-lever door:** levers are far apart. Both must be held for 2 s. Enemies spawn near them.
- **Ally Toss gaps:** a gap too wide to jump. One tosses the other across. The one on the other side lowers a bridge/opens a gate.
- **Carry objects:** one player carries a heavy power cell (can't attack, slowed) to a socket while the other clears the path. They can swap with a throw.
- **Pincer enemies:** armoured front, weak back. A player must hit from behind while the partner holds attention (taunt/aggro).

**Priority 3: combo and status synergy**
- **Prime and detonate:** certain moves put a *mark* (shock, fire, oil) on an enemy. A different player's matching move detonates it for big damage. Self-detonation is weaker.
- **Aggro tokens:** the AI picks the player with the most recent taunt/high threat. Players can intentionally take the heat (tank) while the partner flanks.
- **Relay objectives:** "Combo challenge" arenas: the exit unlocks after both players score a number of relay hits.

**Priority 4: boss ideas**
- **Boss grab:** the boss grabs one player. The other must break them free by hitting a weak point; the grabbed player can mash to reduce time.
- **Two weak points:** opposite sides of the boss; must be damaged within a window of each other.
- **Phase break:** the shield phase is only broken by a Duo Special, or two relay hits in a row.

**Priority 5: support systems**
- **Heal station:** only one player at a time can use it, and it heals the *other* (you can't heal yourself).
- **Pull out:** a grab that pulls a downed or trapped partner out of a hazard.
- **Heart link:** after a level, a small shared HP pool refill depends on team rank.
- **Hazard rooms:** timed lasers / crushers where one player must hold a switch off while the other passes, then swap.

### Class synergies (roles)
- Hammer *breaks guards* and *launches*; Sword *parries* and counters; Brawler *relays* and *juggles*; Magic *primes* enemies and *zones*.
- Each class pair gets a small bonus (e.g. Hammer + Magic: a Hammer slam on a primed enemy triggers a bigger blast).

## 7. Open questions
1. Is Hammer available from the start, or part of an early unlock?
2. How much should solo play be supported (one controller)? Default: not at all, same as in the plan.
3. Super meter design (§5).
4. Which §6 elements go in the first Streets levels? Default: protect/operate terminal, charge-up B moves, two-lever door, shielded enemy.
