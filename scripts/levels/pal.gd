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
