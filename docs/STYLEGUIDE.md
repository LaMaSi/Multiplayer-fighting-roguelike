# Style Guide: colour

Status: **implemented in the game** (HUD, level complete, shop, synthwave backdrop). Terrain = pink and interactables = amber were used for the build; §3 lists what is still open. Written from an audit of every `Color(...)` in `scripts/` and `autoload/`. The goal is that a player can tell what a thing *is* from its colour alone, at a glance and at phone size.

## 1. Principles

1. **Background is quiet, gameplay is loud.** Everything in the backdrop is dark, desaturated and foggy. Only gameplay objects are saturated and bright.
2. **One hue = one job.** A hue is reserved for one role (§2). If two things share a colour, they must not share a role.
3. **Glow is a budget.** Values above 1.0 (HDR) make a thing glow. Only gameplay objects may exceed 1.0. Backdrop colours stay at 0.6 or below.
4. **Shape backs up colour.** Never rely on colour alone (enemy types differ by silhouette, pickups by icon).
5. **Few colours, many values.** Variation comes from brightness and alpha, not from new hues.

## 2. Roles

| Role | Hue family | Current values | Used for |
|---|---|---|---|
| Player 1 | cyan | `(0.15, 1.0, 1.28)` | P1 figure, P1 HUD, P1 hit sparks |
| Player 2 | lime green | `(0.55, 1.28, 0.15)` | P2 figure, P2 HUD, P2 hit sparks |
| Enemy | red to orange-red only | Thug `(1.3, 0.3, 0.08)`, Boss `(1.45, 0.08, 0.08)` | enemy figures, enemy health bars, enemy telegraphs |
| Terrain (stand here) | pink / magenta | ground `(2.0, 0.7, 1.2)` | ground edge, platform top edge and rim, level walls |
| Interactable | amber / gold | crate `(2.0, 1.2, 0.4)` | crates, barrels, vases, pickups, exit door. Nothing else may use amber |
| Danger / hit | white-hot plus red | `(2.5, 0.5, 0.4)` | hit flashes, damage numbers, enemy warnings |
| UI text | off-white | `(1, 1, 1)` | HUD, menus (player colours only on the player's own panel) |
| Background | muted warm purple/brown | see §4 | skyline, haze, sky |

## 3. Conflicts in the current game (decision needed)

| Conflict | Why it hurts | Proposed fix |
|---|---|---|
| Platforms are amber `(2.0, 1.2, 0.4)`, the same as crates and pickups | You can't tell "stand here" from "break/grab this" | **Platforms become pink/magenta like the ground** (Streets `neon_plat`) |
| Biker is yellow `(1.3, 1.0, 0.08)` | Reads as an interactable or pickup | Orange-red, differ by silhouette (helmet, bulk) |
| Bottle Thrower is magenta `(1.2, 0.12, 0.5)` | Reads as terrain | Crimson / dark red, keep the hood silhouette |
| Hood/cap accessories and the exit door share gold with pickups | Exit is an interactable, fine, but must be the brightest amber | Keep gold, add a pulse |
| About 60 one-off HDR colours (e.g. several near-identical golds `(2.0,1.7,0.5)`, `(2.0,1.8,0.4)`, `(2.2,1.9,0.6)`) | Colours drift apart over time | Replace with named palette entries (§5) |

**Decision for you:** terrain as pink (fewest changes, recommended) or terrain as amber (then crates and pickups need a new colour, for example white-blue).

## 4. Background rules (the chosen "heavy fog" look)

- Buildings: no roof outlines, flat fill, desaturated about 60% and dimmed to 60%, pulled toward the haze colour (`sky_bottom` darkened 35%). Far layers get more fog than near layers.
- Windows: alpha about 0.18, density about a third of the original. A window must never be brighter than a pickup.
- Max brightness for any backdrop colour: **0.6 per channel**, and no HDR glow.
- The sky gradient is the only large warm area in the background. Keep it low-saturation near the buildings.
- Platforms are drawn with a lit top edge, a body, a dark underside and a soft shadow, so they read as solid objects.

## 5. Implementation plan

1. Add one `Palette` script (autoload or `class_name`) with named constants for every role in §2: `P1`, `P2`, `ENEMY`, `ENEMY_BOSS`, `TERRAIN`, `INTERACT`, `HIT`, `UI_TEXT`, plus the background tokens.
2. Replace the magic numbers in `fighter.gd`, `enemy.gd`, `prop.gd`, `pickup.gd`, `level_base.gd`, `streets_level.gd` and `hud.gd`.
3. Per-biome themes override only the background and the terrain hue, never the roles for players, enemies or interactables.
4. Add a debug screenshot that renders one swatch per role so changes can be reviewed side by side.

## 6. Open questions

- Terrain pink vs amber (§3).
- Should interactables get a thin white rim on top of amber for extra separation?
- Per-biome terrain hue (Wasteland, Ruins): same role, different hue, or the same pink everywhere?


## 7. As built (UI iteration)

- **Shared kit:** `scripts/ui/ui_kit.gd` holds the colour roles, fonts and drawing helpers; every screen uses it.
- **Fonts (OFL, in `assets/fonts/`):** Orbitron (headings, big numbers), Rajdhani Bold (labels, body).
- **UI colour rule:** flat colours at or below 1.0, so UI does not glow. Only three things glow on purpose: the combo counter, the rank letter, and a usable or full super meter.
- **Player colours:** P1 cyan `(0.2, 0.9, 1.0)`, P2 lime `(0.55, 0.98, 0.2)`. Coins and prices amber `(1.0, 0.72, 0.25)`. Titles and accents pink `(1.0, 0.4, 0.72)`.
- **Backdrop (variant 5, "synthwave"):** striped sun, one purple-magenta-orange gradient, three building layers that get darker toward the front with rim light, lit window columns, setbacks and antennas. Colours are in `scripts/levels/pal.gd`. Older variants (0 to 4) are kept for comparison; `Backdrop.variant` selects.
- **Screens:** HUD (`scripts/ui/hud.gd`), level complete (`scripts/ui/level_complete_view.gd`, data from `scripts/run/level_stats.gd`), shop (`scripts/ui/shop_screen.gd`).
- **Mockups and screenshot tests:** `tests/mock_hud.gd`, `tests/mock_screens.gd`, `tests/shot_bg.gd`, `tests/ui_real_test.gd`, `tests/shop_test.gd`.
