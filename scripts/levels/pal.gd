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
