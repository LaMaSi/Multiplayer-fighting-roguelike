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
| Reward screen (sequential picks) | **fails** | Replace with §3 (shared X/Y choice with RPS clash, plus personal level-up) |
| Random run-start loadout | partial | Players may **swap one move with each other** on the loadout screen (§4) |
| Class pick | ok | Class gives a *role* (see §6 class synergies) |
| Level-up: +HP / empower / new B move | partial | Personal choice (§3.2) with simultaneous picks, visible partner cards and a guaranteed team card |
| Rank at level end | partial | Team rank; add bonus points for relay hits and rescues |
| RT dash | neutral | Add: dash through the partner to give them a short speed boost? (optional, test) |
| Super meter | partly decided | Style meter, §5. Open: owner (shared Link vs individual) |

## 2. Decisions made

- X = universal moves (identical for all classes, at least 10), Y = adaptive moves (modified by class, at least 10), B = weapon moves (8 per class).
- Magic is unlocked through meta progression. Brawler, Sword and Hammer (decide in a later review) are available from the start; Magic locked.
- **No separate mana bar.** Magic's heavy cost is solved through the super meter session (§5).

## 3. Rewards after a level: two parts

Clearing a level gives **both** of these, one after the other (the shared choice first, then the personal level-up). Each is a short, tense moment.

### 3.1 Shared move choice (X and Y moves only)

Goal: the team decides together what the team can do.

1. Show **3 random move cards**, all **X or Y moves** (never B moves). X moves are universal and Y moves are adaptive, so **every card is usable by both players**. There are no class-locked cards here.
2. **Both players pick at the same time** (stick to a card, press A to lock in). Each sees the other's cursor.
3. **Different cards:** both get their pick. The third card is discarded.
4. **Same card (a clash):** play **Rock-Paper-Scissors** with face buttons: **X = rock, Y = paper, B = scissors**. 3-2-1 countdown, then reveal. Ties repeat.
   - The **winner** keeps the card.
   - The **loser** chooses from the **remaining two** cards.
5. After picking, each player chooses which X or Y slot gets the move (simultaneously). If all of that button's slots are full, the player chooses which equipped move to replace (see 3.3).
6. Players who don't press within 15 s auto-pick the leftmost card.
7. Juice: cards flip in, both hands "slam" the card in a clash, a screen-shake countdown, the loser's reaction.

### 3.2 Personal level-up (individual choice, B moves live here)

Goal: your build, your character, your decision, but visible to your partner.

1. Each player gets their **own set of 3 level-up cards**, drawn from their own pool. Both choose **at the same time**, and each can see the other's cards and cursor, so they can talk about it.
2. **Card types:**
   - **New B move:** one of your class's remaining B moves (a player starts with 3 of 8; 5 can be unlocked). You then choose the B slot it goes into. **All new B moves come only from level-ups.**
   - **Empower a move:** pick one of your equipped moves and upgrade it (more damage, reach, less recovery, or a better LT version; tiers with a cap).
   - **Max HP:** more health.
   - **Style/meter perks:** e.g. faster fill from relay hits.
   - **Generic super:** choose 1 of the 8 generic supers (proposed way to acquire it).
   - **For my partner (a team card):** a perk that benefits the **partner** or both of you (e.g. partner +max HP, faster revive, stronger Heal Pulse). At least **one team card** is in every set, so there is always a way to choose the team over yourself.
3. Cards are weighted so each set has at most one B move card, and shows the move's tier and class tag.
4. No clash rule here (the sets are different). Both confirm to continue.
5. **Rank bonus:** a high team rank (S) adds a 4th card to both sets and to the shared choice; a low rank (D) removes one.

### 3.3 Pacing and replacement (decided)

- Every level gives both rewards. Slots fill up after a few levels, and that is intended: **replacing moves is a normal part of the game**, not an edge case.
- When a card's button has no empty slot, the player picks **which equipped move it replaces** (shown side by side, with the old move's stats). Replacing is never forced; a player can also decline a card (take no move) if they prefer their current kit.
- Replacement choices drive the build conversation: "I'll drop my Spin Kick for it", so the screen shows both players' loadouts at all times.
- Replaced moves return to the pool and can be offered again later.
- Personal B-move cards work the same way: if all 5 B slots are full, the player chooses which B move gets replaced.
- Because moves rotate, empower upgrades on a move are lost when it is replaced (to be decided: keep the upgrade with the slot, or with the move; default: with the move).

### 3.4 Co-op test for this system
- Shared choice: pass (communication, clash, shared consequence).
- Personal level-up: weaker on its own, so it has mitigations: simultaneous picks, visible partner cards, the guaranteed team card, shared rank bonus.

## 4. Run start

- Each player picks a class (Magic locked until unlocked).
- The game rolls random moves into each player's starting slots: B, side+B, up+B (from their class), X (from the universal pool). Y slots are empty at start.
- Loadout screen shows both players' rolls side by side, with one re-roll per player per run and **one move swap**: a player may trade one of their rolled moves with their partner's (if the class rules allow it). This forces a quick conversation ("take my fireball?").

## 5. Super meter: decisions so far and open items

Nickname: the **Style meter**. Anything cool and cooperative fills it. Status: partly decided, the open items are at the end.

### Decided
- **Fills from** (in rough order of reward):
  1. Relay hits and shared combos (largest)
  2. Protecting and rescuing the partner (guarding a charging partner, reviving, taking a hit for them, healing them)
  3. Perfect dodges and perfect parries ("coolness": anything awesome is rewarded, even solo)
  Plain damage dealt fills little or nothing, so spamming alone is a poor way to build meter.
- **Empowered moves:** holding **LT** while performing a move spends a little meter to make it a slightly stronger / larger version (bigger hitbox, more damage, extra effect). Mainly for B moves, but this applies to any move that has an empowered variant.
- **Supers:**
  - **Generic super** (choose 1 of 8 as a build choice): input **down, down-forward, forward, twice (a double quarter-circle forward), then X**.
  - **Weapon super:** same motion, then **B**. One fixed super per class for now, to be expanded later.
  - **Duo Specials** remain: both players have enough meter and press the pair trigger.
- **Spent on:** Duo Specials, empowered moves (LT), solo supers.

### Co-op check on these decisions
- Solo supers can be played alone, so they compete with the pillar. Mitigation: every super gets a **team rider** (a bonus when the partner is in range or when it follows a relay hit: it may extend the combo window, heal the partner a little, or let the partner's next hit be empowered for free). Needs one rider design per super.
- Perfect dodge/parry is a solo reward. That is fine as long as protect/relay actions are worth more. Tune: relay and rescue = 2-3x the perfect-dodge amount.

### Technical risks
- A double quarter-circle on a stick is hard and conflicts with crouch (down), down+face-button moves and the RT dash. Needs a motion-input parser with a buffer of about 25-30 frames, leniency on diagonals, and priority over ordinary moves when a full motion is detected. Make the window generous.
- If the generic super is X + motion, it conflicts with X-slot moves; parse the motion first.
- The generic super choice (1 of 8) needs a slot in the build: likely a reward type. Open.

### Open (needs a decision)
1. **Meter owner: not answered.** Default to test first: one shared **Link meter** between the players (supports the pillar the most). If you want individual meters, then the partner can gift meter.
2. How is the generic super acquired (run start choice, reward card, both)?
3. Do supers require a full meter, and what are the thresholds for: empowered move (about 10%), super (about 50%), Duo Special (about 50% for each or a shared 75%)?
4. The 8 generic supers and 4 weapon supers still need to be listed.

### Magic: rethink (no mana bar)
Current problem: "Magic costs a lot of meter" made Magic a resource problem, not an identity. Magic should differ from Brawler/Sword/Hammer by **what it does for the team**, not by what it costs.

Proposal (co-op first): **Magic is the Primer / Zoner.**
- B moves are ranged, slow-moving projectiles and zones that **mark** enemies (fire, shock, oil, slow). Marks do small damage alone.
- A different player's hit (or Magic's own empowered hit) **detonates** the mark for a large bonus, plus meter for the team. Marks = the enemy visibly glows.
- Weakness: lowest HP of the classes, slow projectile speed, and no strong close-range tools (it has the universal X moves).
- Cost: cooldowns on Magic's B moves (visible on the player), instead of a resource bar. LT empowered versions cost meter like every class.
- This turns the Magic player into the person who sets up the other player's big hits. Great for communication ("mark him!", "detonate now!").

Alternative if you prefer a more individual fantasy: Magic as pure glass-cannon artillery (strongest ranged damage, shortest HP, longest cooldowns).

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

## 8. Proposal: default Grab and Throw for every character (needs your OK)

Today throwing only exists as the X moves **Grab & Throw** and **Ally Toss** (and the Hammer's Home Run), so a player only has it if the reward cards happened to give it. Proposal: make **grab and throw a built-in verb for everyone**, since it is the core co-op action (crossing gaps, rescuing, launching enemies, carrying things).

- **Button: RB** (unused). One context-sensitive grab:
  - **Partner nearby:** pick them up. Hold RB to carry, aim with the stick, **release RB to throw**. The thrown partner has some air control, can attack in flight (a flying kick = a relay hit) and takes no damage from it (with friendly fire off).
  - **Enemy nearby:** pick it up and throw it as a projectile that bowls into other enemies. Armoured enemies, elites and bosses cannot be grabbed unless **stunned** (for example by the Hammer's Guard Breaker), which gives that move a partner.
  - **Container nearby:** pick it up and throw it (matches the destructible containers in the plan).
- **Rules to avoid frustration:**
  - The partner can **mash to break free** or be flagged as "not ready" (a partner who is attacking, dashing or in hit-stun cannot be grabbed).
  - The carrier is slowed and cannot attack while carrying.
  - Short cooldown (about 2 s) after each throw to prevent spamming.
  - A throw can never drop the partner into a bottomless pit without them seeing a landing marker (the target spot is shown while aiming).
- **Conflict fix:** the Duo Special pair-trigger was LB+RB. Change it to **both players press LB within 0.5 s**.
- **Effects on the move pool:** Grab & Throw and Ally Toss become redundant and leave the X pool, replaced by two new X moves:
  - **Swap Step:** swap places with the partner instantly (rescue from a corner, reposition for a charge-up, pull them out of danger).
  - **Focus Call:** mark an enemy for the partner: your partner's hits on it deal bonus damage for about 5 s (a communication tool).
  - Totals stay at 52 moves (X: 5 existing, 5 new; 27 new overall).
- The Hammer's **Home Run** stays as the long-range version. Ally Toss's old role (gap crossing) is now the default throw.

Co-op test: passes strongly (communication: "throw me over", rescue, relay hits), and it adds a bit of fun chaos.
