# Levels: movement first

The game is about movement. The camera stays wide (zoom 0.45–0.85, `camera_rig.gd`), levels have gaps, different
ground heights and higher platforms, and characters pass through each other instead of blocking.

## Terrain
- The ground is a list of segments (`ground_segs`), each with its own top height. Gaps are the space between
  segments. Falling = respawn on the last safe ground with a small damage hit (shared lives untouched).
- Height steps 40–120 px, gaps 180–360 px. Every gap must be crossable with one jump + run (apex ~178 px),
  every platform reachable (single jump <= 170 px, higher tiers need double jump or a platform chain), and every
  platform underside must clear the tallest walker (boss ~129 px).
- Platform tiers above the local ground: 150 / 210 / 270 px.

## Ledge grab (Phase 3)
- Reaching the edge of a gap or platform while falling grabs the ledge and hangs (invulnerable).
- Alone: 3 s to pull yourself up. With the partner nearby pressing interact: instant pull-up. Jump or Down = drop.

## Crowds
- Players and enemies never block each other. While bodies overlap, movement is slowed to 50 % (`Actor.crowd_mult`).
- Only barriers (Bulwark Plant) block bodies (collision layer 5).

## Doors (Phase 5)
- A level can contain doors. A door leads to a single-screen room inside the same level (state is kept).
- Colour + shape say what is inside: red hexagon = challenge room (hard enemies, extra coins or a move choice),
  gold arch = move shop. Both players enter together; leaving returns to the door.

## 2.5D depth (drawing only, collision is unchanged)
`scripts/levels/depth_layer.gd` adds depth to the flat side view with **one camera model** for everything: a vanishing point sits `RISE` (0 px: at the camera centre, so platforms above it are seen from below) above the camera centre, and a point at depth `z` behind the walking plane is drawn at `vp + (p - vp) * EYE / (EYE + z)`.
- **Ground:** the surface reaches `FLOOR_BACK` behind the walking line and a fixed lip `FLOOR_FRONT` in front of it, with a perspective grid, a fogged far edge and pit walls that appear when you look at them from the pit side. Feet stand on the original line, which is inside the floor band.
- **Platforms (static and moving):** real boxes (`draw_platform`): back edge converging toward the vanishing point, a top surface, a front face with the neon edge, and the side that faces the camera. Underside is drawn if a platform is above the horizon.
- **Camera movement:** the vanishing point follows the camera in x and y, so floors and platforms shift correctly while the camera moves or zooms.
- **Contact shadows:** every actor gets a soft ellipse on the surface below it (ground, platform or moving platform); it shrinks and fades with height.
- Tuning constants are at the top of the script: `EYE`, `RISE`, `FLOOR_BACK`, `PLAT_BACK`, `PLAT_FRONT`.
- Test: `Godot --path . res://tests/shot_depth.tscn -- <out_prefix> [seed]` writes `_start`, `_pit`, `_platform` screenshots.

## Containers and ceiling spikes
- **Crates, barrels and TNT crates are 3D boxes** drawn in the same depth camera as the platforms (`Prop._draw_box`, `_draw_barrel`): visible top, the side facing the camera, a front face, and a contact shadow. Vases and springs stay flat.
- **You can stand on them.** Each idle container carries a thin one-way platform on its top (layer 2, like the level's platforms): players and enemies land on it from above, can drop through with down, and walk through the sides (the sides are not solid, in line with "bodies never block each other"). The platform is off while the container is held, flying or dead, and if it is smashed under you, you fall. Containers draw behind fighters (z -1) so a player on top is not covered; held and thrown ones draw in front.
- **Ceiling spikes** (`SpikeTrap.ceiling`, hazard kind `ceiling_spikes {x, y, w}`) hang under a few raised platforms. They only spawn where the underside is 110 to 270 px above the local ground (`SpikeTrap.AIR_MIN_H` / `AIR_MAX_H`), at most 3 per level. They hurt **enemies only**, and only flying ones (launched, thrown or airborne): a walking enemy, even the tall boss, passes underneath, and players are never hurt. A hit slams the enemy back down for the follow-up.
- Test: `Godot --path . res://tests/props_test.tscn [-- <out_prefix>]`.

## Battle screens: ceiling
- When an arena locks, a solid **ceiling** (`ArenaCeiling`, 470 px above the base ground, 560 px for boss arenas) drops in with the walls and lifts away when the fight ends. It is a layer-1 body: jumps and launched or thrown bodies stop against it and fall back into the fight. It is drawn in the depth camera, so you see its underside with light strips.

## Branching path: tunnels
- Fight, elite and treasure levels can contain a **tunnel** (`StreetsLevel._gen_terrain`, 1 per level, 2 in long levels): 460 to 640 px of flat ground under a thick roof. **Through:** walk the ground under the roof (dark interior, ceiling lights, a few containers). **Over:** jump up (the roof is a normal one-way platform at the low tier, 150 px) and cross the roof, which carries 3 containers. Both routes meet again at the end.
- The roof is in `platforms` (so ledge grabs, enemy climbing and shadows work) and in `tunnel_roofs` (drawn thick, with the far wall and lamps: `DepthLayer._draw_tunnel`). Other platforms and movers are cleared from the tunnel's span, and doors are never placed in or next to it.
- Test: `Godot --path . res://tests/shot_tunnel.tscn -- <out_prefix>` (generates levels until one has a tunnel, checks both routes and the arena ceiling, and writes screenshots).

## Launch trails
- An enemy sent flying leaves a subtle fading ribbon (`LaunchTrail`). Colour: the player who hit it; an object (crate, explosion) thrown by a player gives that player's colour; an enemy's attack, a hazard or an unattributed explosion gives red. Test: `tests/trail_test.tscn`.

## Ceiling spikes (revised)
- Ceiling spikes **never hang lower than half a screen**: their tips must be at least `SpikeTrap.AIR_MIN_H` (about 424 px, half the screen height at the closest camera zoom) above the local ground, so characters can always walk and jump freely underneath. `LevelBase._spawn_hazards` refuses any that are lower.
- They hang from the **battle screen ceiling** (`ArenaCeiling`): 2 to 4 clusters along its underside (tips about 446 px up), switched on once the ceiling has dropped in and off while it lifts away. They hurt enemies only, and only flying ones (launched, thrown, airborne); a hit slams the enemy back down for the follow-up. They no longer appear under platforms or tunnel roofs.

## Doors: set back, with a clear zone
- **Challenge, shop and exit doors stand in the depth of the floor** (`Door.DEPTH` = 100 px behind the walking line): drawn smaller and higher in the shared depth camera, with a soft shadow, and behind containers and fighters (z -8). The interaction is unchanged (stand at the door's x on the walking line, press RB), and the prompt stays on the walking line.
- **Clear zone:** no container, spike trap, spring or bumper is placed on the ground within `LevelBase.DOOR_CLEAR` (190 px) of a door or the exit door (`near_door()`), both in generation and as a guard when spawning, so it also holds for hand-made levels. Containers on platforms above a door are still allowed.

## Finish line (replaces the exit door)
- `exit_x` is now a **finish line**, and only a ground effect: a checkered strip across the whole floor depth with a soft glow (`DepthLayer._draw_finish`). Once the fights are done, walking both players across it ends the level (unchanged trigger).
- **Safe zone:** nothing is placed within `LevelBase.FINISH_CLEAR` (half a screen, about 753 px) of the line: no containers (platform ones included), spikes, springs, bumpers, doors, tunnels or arenas. The terrain there stays flat, there are no moving platforms, and at most **one** platform. Fight levels are 600 px longer (6800) so the tunnel, arenas and doors still fit.
- **Bonus target** (`BonusPole`): a round target (a bullseye, no visible track) sliding up and down **directly above the finish strip**, so crossing the line is the one try. Its centre moves between 320 and 440 px up (radius 30), so a single jump (~180) cannot reach it: a double jump gets the low end and a partner throw the high end. Players' attacks and projectiles can hit it; each hit pays 3 to 8 coins (more when it is high). Test: `tests/finish_test.tscn`.

## Doors (revised)
- Challenge doors are lit (bright outline, halo, floor glow). Standing close shows a panel with the reward: `+N COINS` and, on some doors, `+ MOVE`. Whether a challenge door pays a move choice is decided when the level is built (`doors_spec.pick`), so the panel is truthful.

## HUD: low health
- At 30% health or less the HP blocks turn red (the frame and the ring keep the player's colour), and that player's whole panel pulses gently, faster the lower it gets (`Hud.LOW_HP`).

## Vases
- Vases are now 3D too (a body of revolution in the depth camera: curved bands, an elliptical mouth) and are **set back 70 px** behind the walking line (`Prop.VASE_DEPTH`): drawn smaller and higher with their own shadow, so they read as background decoration. They have no standable top. When a vase is hit and flies, it comes forward to the walking line (`_depth` slides back to 0) and draws in front. Hits still register where it stands on the walking line.
