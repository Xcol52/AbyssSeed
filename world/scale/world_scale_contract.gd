class_name WorldScaleContract
extends RefCounted

## Session 8 world-scale contract:
##
## - One Godot world unit represents one meter.
## - Y is elevation and increases upward.
## - Sea level comes from the initialized ocean configuration.
## - Depth is positive downward from sea level.
## - Geological contributions are signed vertical offsets in meters.
## - Geological widths are horizontal distances in meters.
const METERS_PER_WORLD_UNIT: float = 1.0


static func world_units_to_meters(
	world_units: float
) -> float:
	return world_units * METERS_PER_WORLD_UNIT


static func depth_below_sea_level(
	sea_level_meters: float,
	elevation_meters: float
) -> float:
	return sea_level_meters - elevation_meters


static func bottom_clearance(
	observer_elevation_meters: float,
	seafloor_elevation_meters: float
) -> float:
	return (
		observer_elevation_meters
		- seafloor_elevation_meters
	)


static func format_distance(
	distance_meters: float
) -> String:
	var normalized_distance := distance_meters

	if absf(normalized_distance) < 0.0005:
		normalized_distance = 0.0

	var magnitude := absf(normalized_distance)

	if magnitude >= 1000.0:
		return (
			"%.2f km"
			% (normalized_distance / 1000.0)
		)

	if magnitude >= 100.0:
		return "%.0f m" % normalized_distance

	return "%.1f m" % normalized_distance


static func format_depth(
	depth_meters: float
) -> String:
	if depth_meters >= 0.0:
		return format_distance(depth_meters)

	return (
		"%s above sea level"
		% format_distance(absf(depth_meters))
	)


## Returns a readable 1, 2, or 5 × 10^n depth limit.
static func get_nice_depth_limit(
	required_depth_meters: float
) -> float:
	var required_depth := maxf(
		100.0,
		required_depth_meters
	)

	var exponent: float = floor(
		log(required_depth)
		/ log(10.0)
	)

	var magnitude: float = pow(
		10.0,
		exponent
	)

	var normalized := required_depth / magnitude
	var multiplier := 10.0

	if normalized <= 1.0:
		multiplier = 1.0
	elif normalized <= 2.0:
		multiplier = 2.0
	elif normalized <= 5.0:
		multiplier = 5.0

	return multiplier * magnitude
