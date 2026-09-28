class_name SeabedPrototype
extends Node3D

## Exactly one fixed test chunk is generated in Session 3.
@export var test_chunk_coordinate: Vector2i = Vector2i.ZERO

var _initialized: bool = false
var _chunk_data: TerrainChunkData
var _mesh: ArrayMesh

@onready var _mesh_instance: MeshInstance3D = %SeabedMesh


func initialize(
	world_seed: int,
	generation_version: int,
	grid_settings: WorldGridSettings,
	terrain_settings: TerrainSettings
) -> bool:
	if _initialized:
		push_error("SeabedPrototype can only be initialized once.")
		return false

	if not is_node_ready():
		push_error(
			"SeabedPrototype must be inside the SceneTree before initialization."
		)
		return false

	if generation_version < 1:
		push_error("generation_version must be at least 1.")
		return false

	if grid_settings == null:
		push_error("SeabedPrototype requires WorldGridSettings.")
		return false

	if terrain_settings == null:
		push_error("SeabedPrototype requires TerrainSettings.")
		return false

	var terrain_subsystem_seed := (
		StableSeed.derive_subsystem_seed(
			world_seed,
			generation_version,
			WorldSubsystemIds.TERRAIN
		)
	)

	var request := TerrainGenerationRequest.new(
		test_chunk_coordinate,
		terrain_subsystem_seed,
		generation_version,
		grid_settings,
		terrain_settings
	)

	var sampler := TerrainSampler.new()
	var generated_data := sampler.generate(request)

	if generated_data == null:
		push_error("SeabedPrototype terrain generation failed.")
		return false

	var generated_mesh := TerrainMeshBuilder.build(
		generated_data
	)

	if generated_mesh == null:
		push_error("SeabedPrototype mesh construction failed.")
		return false

	var chunk_origin := (
		WorldCoordinates.chunk_to_world_origin(
			test_chunk_coordinate,
			grid_settings
		)
	)

	position = Vector3(
		chunk_origin.x,
		0.0,
		chunk_origin.y
	)

	_chunk_data = generated_data
	_mesh = generated_mesh
	_mesh_instance.mesh = _mesh

	_initialized = true
	return true
