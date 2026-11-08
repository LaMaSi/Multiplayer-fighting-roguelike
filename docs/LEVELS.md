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
