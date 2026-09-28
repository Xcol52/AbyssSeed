class_name TerrainMeshPreparationProfile
extends RefCounted

## Written only by the worker before publication.
## Read only by the main thread afterward.

var validation_usec: int = 0
var packed_array_allocation_usec: int = 0
var geometry_population_usec: int = 0
var data_object_setup_usec: int = 0
var total_usec: int = 0

var cells_per_axis: int = 0
var cell_count: int = 0
var triangle_count: int = 0
var emitted_vertex_count: int = 0
var index_count: int = 0
var raw_payload_bytes: int = 0


func reset() -> void:
	validation_usec = 0
	packed_array_allocation_usec = 0
	geometry_population_usec = 0
	data_object_setup_usec = 0
	total_usec = 0

	cells_per_axis = 0
	cell_count = 0
	triangle_count = 0
	emitted_vertex_count = 0
	index_count = 0
	raw_payload_bytes = 0


func set_topology(
	new_cells_per_axis: int
) -> void:
	cells_per_axis = new_cells_per_axis

	cell_count = (
		cells_per_axis
		* cells_per_axis
	)

	triangle_count = cell_count * 2
	emitted_vertex_count = triangle_count * 3

	## Flat per-face normals and colors retain the unindexed topology.
	index_count = 0


func get_accounted_usec() -> int:
	return (
		validation_usec
		+ packed_array_allocation_usec
		+ geometry_population_usec
		+ data_object_setup_usec
	)


func get_unattributed_usec() -> int:
	return maxi(
		0,
		total_usec - get_accounted_usec()
	)
