class_name FloraGenerationJob
extends RefCounted


static func execute(
	chunk_coordinate: Vector2i,
	activation_token: int,
	request_revision: int,
	terrain_data: TerrainChunkData,
	environment_snapshot: EnvironmentGenerationSnapshot,
	flora_seed: int
) -> FloraGenerationResult:
	var start_usec: int = Time.get_ticks_usec()

	if terrain_data == null:
		return _failure(
			chunk_coordinate,
			activation_token,
			request_revision,
			"Flora worker received no TerrainChunkData.",
			start_usec
		)

	if environment_snapshot == null:
		return _failure(
			chunk_coordinate,
			activation_token,
			request_revision,
			"Flora worker received no environment snapshot.",
			start_usec
		)

	var biome_catalog := (
		BiomeCatalogSnapshot.create_default()
	)

	var biome_sampler := BiomeSuitabilitySampler.new(
		biome_catalog
	)

	var biome_error: String = (
		biome_sampler.get_validation_error()
	)

	if not biome_error.is_empty():
		return _failure(
			chunk_coordinate,
			activation_token,
			request_revision,
			biome_error,
			start_usec
		)

	var flora_catalog := (
		FloraCatalogSnapshot.create_default()
	)

	var flora_sampler := FloraPlacementSampler.new(
		flora_seed,
		flora_catalog
	)

	var flora_error: String = (
		flora_sampler.get_validation_error()
	)

	if not flora_error.is_empty():
		return _failure(
			chunk_coordinate,
			activation_token,
			request_revision,
			flora_error,
			start_usec
		)

	## Every worker job creates isolated sampler instances. In
	## particular, FastNoiseLite-backed placement samplers are never
	## shared concurrently.
	var environment_sampler := EnvironmentSampler.new(
		environment_snapshot
	)

	var flora_data := flora_sampler.generate_chunk(
		terrain_data,
		environment_sampler,
		biome_sampler
	)

	if flora_data == null:
		return _failure(
			chunk_coordinate,
			activation_token,
			request_revision,
			"Flora placement returned no chunk data.",
			start_usec
		)

	var validation_error: String = (
		flora_data.get_validation_error()
	)

	if not validation_error.is_empty():
		return _failure(
			chunk_coordinate,
			activation_token,
			request_revision,
			validation_error,
			start_usec
		)

	var generation_usec: int = (
		Time.get_ticks_usec()
		- start_usec
	)

	return FloraGenerationResult.new(
		chunk_coordinate,
		activation_token,
		request_revision,
		flora_data,
		"",
		generation_usec,
		0,
		flora_data.get_candidate_count()
	)


static func execute_and_publish(
	chunk_coordinate: Vector2i,
	activation_token: int,
	request_revision: int,
	terrain_data: TerrainChunkData,
	environment_snapshot: EnvironmentGenerationSnapshot,
	flora_seed: int,
	mailbox: FloraResultMailbox
) -> void:
	var result: FloraGenerationResult = execute(
		chunk_coordinate,
		activation_token,
		request_revision,
		terrain_data,
		environment_snapshot,
		flora_seed
	)

	mailbox.publish(result)


static func _failure(
	chunk_coordinate: Vector2i,
	activation_token: int,
	request_revision: int,
	message: String,
	start_usec: int
) -> FloraGenerationResult:
	return FloraGenerationResult.new(
		chunk_coordinate,
		activation_token,
		request_revision,
		null,
		message,
		Time.get_ticks_usec() - start_usec,
		0,
		0
	)
