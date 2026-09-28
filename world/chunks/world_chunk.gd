class_name WorldChunk
extends Node3D

var _initialized: bool = false
var _chunk_coordinate: Vector2i = Vector2i.ZERO
var _chunk_data: TerrainChunkData
var _mesh: ArrayMesh

@onready var _mesh_instance: MeshInstance3D = %TerrainMesh


func initialize(
	chunk_data: TerrainChunkData,
	mesh: ArrayMesh
) -> bool:
	if _initialized:
		push_error("WorldChunk can only be initialized once.")
		return false

	if not is_node_ready():
		push_error(
			"WorldChunk must be inside the SceneTree before initialization."
		)
		return false

	if chunk_data == null:
		push_error("WorldChunk requires TerrainChunkData.")
		return false

	if mesh == null:
		push_error("WorldChunk requires an ArrayMesh.")
		return false

	_chunk_coordinate = chunk_data.chunk_coordinate
	_chunk_data = chunk_data
	_mesh = mesh

	var chunk_size := (
		float(_chunk_data.cells_per_axis)
		* _chunk_data.cell_size
	)

	position = Vector3(
		float(_chunk_coordinate.x) * chunk_size,
		0.0,
		float(_chunk_coordinate.y) * chunk_size
	)

	_mesh_instance.mesh = _mesh
	_initialized = true

	return true


func get_chunk_coordinate() -> Vector2i:
	return _chunk_coordinate


func get_chunk_data() -> TerrainChunkData:
	return _chunk_data
