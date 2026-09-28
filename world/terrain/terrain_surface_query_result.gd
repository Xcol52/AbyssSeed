class_name TerrainSurfaceQueryResult
extends RefCounted

var available: bool = false

var requested_world_position: Vector3 = Vector3.ZERO
var surface_world_position: Vector3 = Vector3.ZERO

var chunk_coordinate: Vector2i = Vector2i.ZERO
var cell_coordinate: Vector2i = Vector2i.ZERO
var local_position_xz: Vector2 = Vector2.ZERO

## Zero identifies point_00, point_01, point_10.
## One identifies point_10, point_01, point_11.
var triangle_index: int = -1

var surface_elevation_meters: float = 0.0


static func create_unavailable(
	requested_position: Vector3,
	requested_chunk_coordinate: Vector2i
) -> TerrainSurfaceQueryResult:
	var result := TerrainSurfaceQueryResult.new()

	result.requested_world_position = requested_position
	result.chunk_coordinate = requested_chunk_coordinate

	return result
