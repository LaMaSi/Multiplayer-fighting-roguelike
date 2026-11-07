# UI screens (as built)

Look and colour rules: `STYLEGUIDE.md`. All screens share `scripts/ui/ui_kit.gd`.

## HUD (`scripts/ui/hud.gd`)
- Per player: a ring with the HP number and player tag, 10 HP blocks (an orange chip shows recent damage), and a big super meter under it.
- Super meter: calm below half; **gold with a soft pulse** at 50% or more (enough for a Duo / super); **burning** (strong pulse, flames, "SUPER READY") when full. The 50% mark is `Hud.METER_USABLE`.
- Shared combo counter (top centre): italic and tilted, punches on every hit, grows a little and takes a new tilt every 5 hits, glow and colour heat up with the tier. Size growth is capped on purpose so it never covers the screen.
- Shared lives (`Coop.revives_left` of `Coop.revives_max`) as stickfigure heads at top centre.
- Boss bar, GO arrow and banners use the same style.
- The move grid is **hidden by default**; press **F2** to show it (planned home: a Testing Options menu).
- F11 toggles fullscreen, F1 the debug overlay.

## Level complete (`scripts/ui/level_complete_view.gd`)
- Shown by the HUD after `LevelBase._complete()`. Data comes from `LevelStats.compute()`: six stats (combo peak, damage taken, time against `par_time`, containers broken, relay hits, rescues), each with an S to D tile, a team rank, a team score and the coins earned.
- Counters live in `Coop` (`stat_*`) and reset every level. Thresholds are constants at the top of `scripts/run/level_stats.gd`.
- During a run the rank scales the coins (S x1.25 ... D x0.8) and gives a small extra heal (S +10, A +5 on top of the normal 25%). Coins are banked when the level is cleared.
- Not built yet: the unlock-progress (meta) meter and the extra reward card for an S rank, because the meta layer and card bonus are not implemented.

## Shop (`scripts/ui/shop_screen.gd`, scene `scenes/shop.tscn`)
- A new **shop** node on the run map (about 1.3 per run on average). One shared wallet (`RunState.coins`).
- Stock of 4: a new move for each player (placed in their first free slot; an empty-slot-free player gets an upgrade instead), an empower upgrade, and one team item (extra life, +20 max HP for both, or team heal). Prices are placeholders.
- Every purchase is a vote: move the cursor with the stick, **A** votes, **B** withdraws. The item is bought when **both** players vote for the same card. Same for **Reroll** (price rises each time) and **Leave**.
- Extra lives persist for the rest of the run (`RunState.bonus_revives`).
- "Shop (preview)" in the main menu opens it with 260 coins for testing.
- Open design questions are in `ECONOMY.md` §2; this is the first playable version of that draft.

## Tests
- `tests/shop_test.tscn`: scripted votes, purchase, refusal, reroll (prints PASS/FAIL).
- `tests/smoke_scenes.tscn`: loads every scene and checks shops appear on the map.
- `tests/ui_real_test.tscn`: real HUD and level complete screenshots.
- Run with a virtual display on a server: `xvfb-run -a godot --path . res://tests/<name>.tscn -- <args>`.


## Start screen (`scripts/ui/main_menu.gd`)
- Synthwave backdrop (`ScreenBackdrop`), tilted neon title, button list, and the two players standing on screen in the classes they last chose.
- Main page: NEW RUN, TRAINING ROOM, UNLOCKS (placeholder for the meta progression), OPTIONS, TESTING, QUIT. There are no class selectors on this page any more.
- Options (shared with the pause menu, `scripts/ui/options_list.gd`): fullscreen, friendly fire and its damage, move grid, hit explosion size, screen effect.
- Testing: full test level, shop preview, Magic class unlock.
- Stick up/down moves, left/right changes a value, A selects, B goes back; either player can drive it.

## Weapon choice and move reveal (`scripts/ui/run_setup.gd`)
- NEW RUN opens this screen. Each player picks Brawler, Sword, Hammer, Magic (locked until unlocked) or **Random**: stick up/down, A locks in, B unlocks, B with nobody locked goes back. A live preview figure shows the weapon, with the role, description and speed / health / reach / damage bars.
- When both are locked in, the run is created (`RunState.start_run()`) and the **reveal** shows what each player rolled: **B, UP + B, SIDE + B, X and Y** (nothing else at the start, in particular no UP + Y). Rows roll in one after another; a random pick is tagged RANDOM and shows the class it became. A skips the roll, then both players press A to start.
- TRAINING ROOM opens the same screen (`RunSetup.mode = "training"`) and goes straight into the training room with the chosen classes, no reveal.
- Test: `tests/run_setup_test.tscn`.

## Pause menu (`scripts/ui/pause_menu.gd`)
- Start / Esc. Pages: main, options, testing, move lab, loadout. The game HUD is hidden while paused.
- Main page: Resume, Loadout, Options, Testing (training room and non-run only), Restart, Quit, plus a status panel with shared coins, hearts and a read-only view of both loadouts.
- Move Lab (any move in any slot) stays under Testing for the training room.

## Loadout screen (`scripts/ui/loadout_view.gd`)
- Reached from the pause menu and from the run map (**Y**, between levels). Both players edit their own 3x4 grid at the same time.
- Stick moves the cursor, **A** lifts a move, **A** on another slot drops it and the two moves swap, **B** cancels (or leaves when nobody is holding anything).
- Slot rules follow the classes: X = off-hand moves, Y = adaptive moves, B = the player's own weapon moves. A move cannot be dropped on the wrong kind of slot and the screen says why. Upgrades belong to the move and travel with it.
- The detail card shows the move's kind, tags, description and any upgrades it carries.
- Tests: `tests/ui_menus_test.tscn` (swap rules, real input, screenshots).
