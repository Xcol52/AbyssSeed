class_name OceanSettings
extends Resource

## Prevents an accidental editor value from creating an excessively large mesh.
const MAX_MESH_RESOLUTION: int = 512

@export_category("Geometry")

## Full width and depth of the square surface, in meters.
@export_range(1.0, 100000.0, 1.0)
var grid_size: float = 2048.0

## Number of quadrilateral cells along each axis.
## The resulting vertex count is (mesh_resolution + 1) squared.
@export_range(1, 512, 1)
var mesh_resolution: int = 128

## Ocean elevation in OceanRoot-local coordinates.
@export var ocean_height: float = 0.0

@export_category("Recentering")

## Distance between valid snapped surface centers.
@export_range(0.1, 10000.0, 0.1)
var recenter_distance: float = 32.0


func validate() -> PackedStringArray:
	var errors := PackedStringArray()

	if not is_finite(grid_size) or grid_size <= 0.0:
		errors.append("grid_size must be a finite value greater than zero.")

	if mesh_resolution < 1:
		errors.append("mesh_resolution must be at least 1.")
	elif mesh_resolution > MAX_MESH_RESOLUTION:
		errors.append(
			"mesh_resolution must not exceed %d." % MAX_MESH_RESOLUTION
		)

	if not is_finite(ocean_height):
		errors.append("ocean_height must be finite.")

	if not is_finite(recenter_distance) or recenter_distance <= 0.0:
		errors.append(
			"recenter_distance must be a finite value greater than zero."
		)
	elif is_finite(grid_size) and recenter_distance > grid_size:
		errors.append("recenter_distance must not exceed grid_size.")

	return errors
