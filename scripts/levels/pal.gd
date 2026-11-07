class_name Pal
## Central colour roles (see docs/STYLEGUIDE.md). Starting point of the future Palette: only the
## roles under comparison live here for now.
static var terrain_pink := true


## Surfaces you stand on: ground edge and platforms.
static func terrain() -> Color:
	return Color(2.0, 0.7, 1.2) if terrain_pink else Color(2.0, 1.2, 0.4)


## Things you can break, grab or reach: crates, barrels, vases, pickups, exit.
static func interact() -> Color:
	return Color(2.0, 1.2, 0.4) if terrain_pink else Color(1.5, 2.0, 1.7)


## Limited background palette (variant 4): 3 flat sky bands, 3 building tones from one hue ramp,
## one window colour, one ground colour. Nothing else may appear in the backdrop.
const BG_SKY := [Color(0.09, 0.06, 0.18), Color(0.15, 0.09, 0.26), Color(0.24, 0.12, 0.30)]
const BG_SKY_SPLIT := [0.42, 0.76]  ## where the bands change, as a fraction of the sky height
const BG_BUILDING := [Color(0.19, 0.11, 0.27), Color(0.13, 0.08, 0.20), Color(0.08, 0.05, 0.14)]  ## far, mid, near
const BG_WINDOW := Color(0.55, 0.38, 0.38, 0.30)
const BG_GROUND := Color(0.05, 0.03, 0.10)


## Synthwave backdrop (variant 5), from the reference images: one gradient sky with a striped sun,
## dark silhouettes that read against the horizon glow, cool rim light and tidy rows of lit windows.
const SYNTH_SKY := [Color(0.05, 0.02, 0.14), Color(0.17, 0.05, 0.34), Color(0.55, 0.11, 0.50), Color(1.0, 0.38, 0.42)]
const SYNTH_SKY_AT := [0.0, 0.45, 0.8, 1.0]
const SYNTH_FILL := [Color(0.25, 0.08, 0.36), Color(0.17, 0.06, 0.28), Color(0.10, 0.04, 0.19)]  ## far, mid, near
const SYNTH_RIM := [Color(0.5, 0.3, 0.9, 0.0), Color(0.45, 0.3, 0.9, 0.35), Color(0.3, 0.75, 1.0, 0.4)]
const SYNTH_HAZE := Color(0.95, 0.3, 0.5)
const SYNTH_HAZE_A := [0.30, 0.18, 0.08]
const SYNTH_WIN := [Color(0.25, 0.75, 0.95), Color(0.85, 0.3, 0.7)]
const SYNTH_WIN_A := [0.0, 0.45, 0.6]
const SYNTH_SUN := [Color(1.0, 0.85, 0.3), Color(1.0, 0.35, 0.6)]
