class_name TerrainGenerationResult
extends RefCounted

const STATUS_SUCCEEDED: int = 0
const STATUS_FAILED: int = 1

var snapshot: TerrainGenerationSnapshot
var status: int
var chunk_data: TerrainChunkData
var error_message: String
var sampling_usec: int

## Worker-prepared immutable geometry.
var mesh_data: TerrainMeshData
var geometry_preparation_usec: int
var mesh_preparation_profile: TerrainMeshPreparationProfile


func _init(
	result_snapshot: TerrainGenerationSnapshot,
	result_status: int,
	result_chunk_data: TerrainChunkData,
	result_error_message: String,
	result_sampling_usec: int,
	result_mesh_data: TerrainMeshData = null,
	result_geometry_preparation_usec: int = 0,
	result_mesh_preparation_profile: TerrainMeshPreparationProfile = null
) -> void:
	snapshot = result_snapshot
	status = result_status
	chunk_data = result_chunk_data
	error_message = result_error_message
	sampling_usec = result_sampling_usec

	mesh_data = result_mesh_data
	geometry_preparation_usec = (
		result_geometry_preparation_usec
	)
	mesh_preparation_profile = (
		result_mesh_preparation_profile
	)


static func create_success(
	result_snapshot: TerrainGenerationSnapshot,
	result_chunk_data: TerrainChunkData,
	result_sampling_usec: int,
	result_mesh_data: TerrainMeshData = null,
	result_geometry_preparation_usec: int = 0,
	result_mesh_preparation_profile: TerrainMeshPreparationProfile = null
) -> TerrainGenerationResult:
	return TerrainGenerationResult.new(
		result_snapshot,
		STATUS_SUCCEEDED,
		result_chunk_data,
		"",
		result_sampling_usec,
		result_mesh_data,
		result_geometry_preparation_usec,
		result_mesh_preparation_profile
	)


static func create_failure(
	result_snapshot: TerrainGenerationSnapshot,
	result_error_message: String,
	result_sampling_usec: int,
	result_geometry_preparation_usec: int = 0,
	result_mesh_preparation_profile: TerrainMeshPreparationProfile = null
) -> TerrainGenerationResult:
	return TerrainGenerationResult.new(
		result_snapshot,
		STATUS_FAILED,
		null,
		result_error_message,
		result_sampling_usec,
		null,
		result_geometry_preparation_usec,
		result_mesh_preparation_profile
	)
