class_name TerrainChunkData
extends RefCounted

## This class contains generated data only.
var chunk_coordinate: Vector2i
var cells_per_axis: int
var cell_size: float
var height_values: PackedFloat32Array
var geology_data: GeologyChunkData

func _init(
	generated_chunk_coordinate: Vector2i,
	generated_cells_per_axis: int,
	generated_cell_size: float,
	generated_height_values: PackedFloat32Array,
	generated_geology_data: GeologyChunkData = null
) -> void:
	chunk_coordinate = generated_chunk_coordinate
	cells_per_axis = generated_cells_per_axis
	cell_size = generated_cell_size
	height_values = generated_height_values
	geology_data = generated_geology_data


func get_vertices_per_axis() -> int:
	return cells_per_axis + 1


func get_height(
	local_sample_x: int,
	local_sample_z: int
) -> float:
	var vertices_per_axis := get_vertices_per_axis()

	assert(local_sample_x >= 0)
	assert(local_sample_z >= 0)
	assert(local_sample_x < vertices_per_axis)
	assert(local_sample_z < vertices_per_axis)

	var index := (
		local_sample_z * vertices_per_axis
		+ local_sample_x
	)

	return height_values[index]
