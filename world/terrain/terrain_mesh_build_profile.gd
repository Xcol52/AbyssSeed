class_name TerrainMeshBuildProfile
extends RefCounted

var validation_usec: int = 0
var surface_array_assembly_usec: int = 0
var mesh_resource_setup_usec: int = 0
var mesh_submission_usec: int = 0
var total_usec: int = 0

var cells_per_axis: int = 0
var cell_count: int = 0
var triangle_count: int = 0
var emitted_vertex_count: int = 0
var index_count: int = 0


func reset() -> void:
	validation_usec = 0
	surface_array_assembly_usec = 0
	mesh_resource_setup_usec = 0
	mesh_submission_usec = 0
	total_usec = 0

	cells_per_axis = 0
	cell_count = 0
	triangle_count = 0
	emitted_vertex_count = 0
	index_count = 0


func set_topology(
	new_cells_per_axis: int
) -> void:
	cells_per_axis = new_cells_per_axis
	cell_count = cells_per_axis * cells_per_axis
	triangle_count = cell_count * 2
	emitted_vertex_count = triangle_count * 3
	index_count = 0


func get_accounted_usec() -> int:
	return (
		validation_usec
		+ surface_array_assembly_usec
		+ mesh_resource_setup_usec
		+ mesh_submission_usec
	)


func get_unattributed_usec() -> int:
	return maxi(
		0,
		total_usec - get_accounted_usec()
	)
