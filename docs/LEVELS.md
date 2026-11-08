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
`scripts/levels/depth_layer.gd` adds depth to the flat side view with **one camera model** for everything: a vanishing point sits `RISE` (600 px) above the camera centre, and a point at depth `z` behind the walking plane is drawn at `vp + (p - vp) * EYE / (EYE + z)`.
- **Ground:** the surface reaches `FLOOR_BACK` behind the walking line and a fixed lip `FLOOR_FRONT` in front of it, with a perspective grid, a fogged far edge and pit walls that appear when you look at them from the pit side. Feet stand on the original line, which is inside the floor band.
- **Platforms (static and moving):** real boxes (`draw_platform`): back edge converging toward the vanishing point, a top surface, a front face with the neon edge, and the side that faces the camera. Underside is drawn if a platform is above the horizon.
- **Camera movement:** the vanishing point follows the camera in x and y, so floors and platforms shift correctly while the camera moves or zooms.
- **Contact shadows:** every actor gets a soft ellipse on the surface below it (ground, platform or moving platform); it shrinks and fades with height.
- Tuning constants are at the top of the script: `EYE`, `RISE`, `FLOOR_BACK`, `PLAT_BACK`, `PLAT_FRONT`.
- Test: `Godot --path . res://tests/shot_depth.tscn -- <out_prefix> [seed]` writes `_start`, `_pit`, `_platform` screenshots.
