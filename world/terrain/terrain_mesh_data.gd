class_name TerrainMeshData
extends RefCounted

const VECTOR3_BYTES: int = 12
const VECTOR2_BYTES: int = 8
const COLOR_BYTES: int = 16

var _chunk_coordinate: Vector2i
var _cells_per_axis: int

## These arrays are immutable by ownership convention after construction.
## The read-only accessors must not be used to mutate their contents.
var _vertices: PackedVector3Array
var _normals: PackedVector3Array
var _uvs: PackedVector2Array
var _colors: PackedColorArray


func _init(
	generated_chunk_coordinate: Vector2i,
	generated_cells_per_axis: int,
	generated_vertices: PackedVector3Array,
	generated_normals: PackedVector3Array,
	generated_uvs: PackedVector2Array,
	generated_colors: PackedColorArray
) -> void:
	_chunk_coordinate = generated_chunk_coordinate
	_cells_per_axis = generated_cells_per_axis

	_vertices = generated_vertices
	_normals = generated_normals
	_uvs = generated_uvs
	_colors = generated_colors


func get_validation_error() -> String:
	if _cells_per_axis < 1:
		return "TerrainMeshData requires at least one cell per axis."

	var expected_vertex_count := (
		_cells_per_axis
		* _cells_per_axis
		* 6
	)

	if _vertices.size() != expected_vertex_count:
		return (
			"TerrainMeshData vertex count is invalid. "
			+ "Expected %d, received %d."
			% [
				expected_vertex_count,
				_vertices.size()
			]
		)

	if _normals.size() != expected_vertex_count:
		return (
			"TerrainMeshData normal count is invalid. "
			+ "Expected %d, received %d."
			% [
				expected_vertex_count,
				_normals.size()
			]
		)

	if _uvs.size() != expected_vertex_count:
		return (
			"TerrainMeshData UV count is invalid. "
			+ "Expected %d, received %d."
			% [
				expected_vertex_count,
				_uvs.size()
			]
		)

	if _colors.size() != expected_vertex_count:
		return (
			"TerrainMeshData color count is invalid. "
			+ "Expected %d, received %d."
			% [
				expected_vertex_count,
				_colors.size()
			]
		)

	return ""


func get_chunk_coordinate() -> Vector2i:
	return _chunk_coordinate


func get_cells_per_axis() -> int:
	return _cells_per_axis


func get_cell_count() -> int:
	return (
		_cells_per_axis
		* _cells_per_axis
	)


func get_triangle_count() -> int:
	return get_cell_count() * 2


func get_vertex_count() -> int:
	return _vertices.size()


func get_index_count() -> int:
	return 0


## These return the published arrays without duplicating their storage.
## Callers must treat the returned arrays as read-only.
func get_vertices_read_only() -> PackedVector3Array:
	return _vertices


func get_normals_read_only() -> PackedVector3Array:
	return _normals


func get_uvs_read_only() -> PackedVector2Array:
	return _uvs


func get_colors_read_only() -> PackedColorArray:
	return _colors


func get_raw_payload_size_bytes() -> int:
	return (
		_vertices.size() * VECTOR3_BYTES
		+ _normals.size() * VECTOR3_BYTES
		+ _uvs.size() * VECTOR2_BYTES
		+ _colors.size() * COLOR_BYTES
	)
