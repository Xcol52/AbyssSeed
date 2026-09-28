class_name FaunaGenerationBridge
extends Node


## Connects deterministic FaunaPopulationSampler output to streamed
## terrain lifecycle.
##
## This initial implementation is main-thread bounded. Population
## generation remains data-only and can later be moved to worker jobs
## without changing FaunaChunkData or FaunaCoordinator.
class PendingGeneration:
	extends RefCounted

	var chunk_coordinate: Vector2i = Vector2i.ZERO
	var terrain_data: TerrainChunkData
	var activation_token: int = 0

	func _init(
		new_chunk_coordinate: Vector2i,
		new_terrain_data: TerrainChunkData,
		new_activation_token: int
	) -> void:
		chunk_coordinate = new_chunk_coordinate
		terrain_data = new_terrain_data
		activation_token = new_activation_token


## Preserve the previously established fauna seed namespace.
## Do not change this during a Variant-inference correction.
const FAUNA_SUBSYSTEM_ID: int = 1178686798


@export_range(1, 4, 1)
var max_chunk_generations_per_frame: int = 1

@export var print_chunk_counts: bool = false


var _initialized: bool = false

var _chunk_coordinator: ChunkCoordinator
var _fauna_coordinator: FaunaCoordinator

var _environment_sampler: EnvironmentSampler
var _biome_sampler: BiomeSuitabilitySampler
var _fauna_sampler: FaunaPopulationSampler

var _giant_squid_coordinator: GiantSquidCoordinator
var _giant_squid_sampler: GiantSquidRegionalSampler

var _pending: Array[PendingGeneration] = []

## Coordinate -> current queued activation token.
var _queued_tokens: Dictionary = {}

## Coordinate -> current active activation token.
var _active_tokens: Dictionary = {}

var _next_activation_token: int = 1

var _generated_chunk_count: int = 0
var _generated_population_count: int = 0


func _ready() -> void:
	set_process(false)


func initialize(
	chunk_coordinator: ChunkCoordinator,
	fauna_coordinator: FaunaCoordinator,
	giant_squid_coordinator: GiantSquidCoordinator,
	world_seed: int,
	generation_version: int,
	ocean_settings: OceanSettings,
	environment_settings: EnvironmentSettings,
	catalog: FaunaCatalogSnapshot
) -> bool:
	if _initialized:
		push_error(
			"FaunaGenerationBridge can only be initialized once."
		)
		return false

	if (
		chunk_coordinator == null
		or not is_instance_valid(chunk_coordinator)
	):
		push_error(
			"FaunaGenerationBridge requires ChunkCoordinator."
		)
		return false

	if (
		fauna_coordinator == null
		or not is_instance_valid(fauna_coordinator)
	):
		push_error(
			"FaunaGenerationBridge requires FaunaCoordinator."
		)
		return false

	if (
		giant_squid_coordinator == null
		or not is_instance_valid(
			giant_squid_coordinator
		)
	):
		push_error(
			"FaunaGenerationBridge requires "
			+ "GiantSquidCoordinator."
		)
		return false

	if ocean_settings == null:
		push_error(
			"FaunaGenerationBridge requires OceanSettings."
		)
		return false

	if environment_settings == null:
		push_error(
			"FaunaGenerationBridge requires "
			+ "EnvironmentSettings."
		)
		return false

	if catalog == null:
		push_error(
			"FaunaGenerationBridge requires a fauna catalog."
		)
		return false

	var catalog_error: String = (
		catalog.get_validation_error()
	)

	if not catalog_error.is_empty():
		push_error(
			"Invalid fauna catalog: %s"
			% catalog_error
		)
		return false

	var environment_seed: int = (
		StableSeed.derive_subsystem_seed(
			world_seed,
			generation_version,
			WorldSubsystemIds.ENVIRONMENT
		)
	)

	var environment_snapshot: EnvironmentGenerationSnapshot = (
		EnvironmentGenerationSnapshot.from_settings(
			environment_seed,
			ocean_settings,
			environment_settings
		)
	)

	if environment_snapshot == null:
		push_error(
			"FaunaGenerationBridge could not create "
			+ "its environment snapshot."
		)
		return false

	var environment_error: String = (
		environment_snapshot.get_validation_error()
	)

	if not environment_error.is_empty():
		push_error(
			"Invalid fauna environment snapshot: %s"
			% environment_error
		)
		return false

	_environment_sampler = EnvironmentSampler.new(
		environment_snapshot
	)

	var biome_catalog: BiomeCatalogSnapshot = (
		BiomeCatalogSnapshot.create_default()
	)

	if biome_catalog == null:
		push_error(
			"FaunaGenerationBridge could not create "
			+ "the biome catalog."
		)
		return false

	_biome_sampler = BiomeSuitabilitySampler.new(
		biome_catalog
	)

	var biome_error: String = (
		_biome_sampler.get_validation_error()
	)

	if not biome_error.is_empty():
		push_error(
			"Invalid fauna biome sampler: %s"
			% biome_error
		)
		return false

	var fauna_seed: int = (
		StableSeed.derive_subsystem_seed(
			world_seed,
			generation_version,
			FAUNA_SUBSYSTEM_ID
		)
	)

	_fauna_sampler = FaunaPopulationSampler.new(
		fauna_seed,
		catalog
	)
	_giant_squid_sampler = (
		GiantSquidRegionalSampler.new(
			fauna_seed
		)
	)
	_giant_squid_coordinator = (
		giant_squid_coordinator
	)

	var fauna_error: String = (
		_fauna_sampler.get_validation_error()
	)

	if not fauna_error.is_empty():
		push_error(
			"Invalid fauna population sampler: %s"
			% fauna_error
		)
		return false

	_chunk_coordinator = chunk_coordinator
	_fauna_coordinator = fauna_coordinator

	if not _chunk_coordinator.chunk_activated.is_connected(
		_on_chunk_activated
	):
		_chunk_coordinator.chunk_activated.connect(
			_on_chunk_activated
		)

	if not _chunk_coordinator.chunk_deactivated.is_connected(
		_on_chunk_deactivated
	):
		_chunk_coordinator.chunk_deactivated.connect(
			_on_chunk_deactivated
		)

	_initialized = true
	set_process(true)

	return true


func get_pending_generation_count() -> int:
	return _pending.size()


func get_generated_chunk_count() -> int:
	return _generated_chunk_count


func get_generated_population_count() -> int:
	return _generated_population_count


func _process(
	_delta: float
) -> void:
	if not _initialized:
		return

	var processed_this_frame: int = 0

	while (
		processed_this_frame
			< max_chunk_generations_per_frame
		and not _pending.is_empty()
	):
		## Avoid pop_front(). It returns Variant even when the source
		## array is typed.
		var pending: PendingGeneration = _pending[0]
		_pending.remove_at(0)

		processed_this_frame += 1

		if pending == null:
			continue

		var queued_token: int = int(
			_queued_tokens.get(
				pending.chunk_coordinate,
				-1
			)
		)

		if queued_token == pending.activation_token:
			_queued_tokens.erase(
				pending.chunk_coordinate
			)

		if not _is_current(pending):
			continue

		var fauna_data: FaunaChunkData = (
			_fauna_sampler.generate_chunk(
				pending.terrain_data,
				_environment_sampler,
				_biome_sampler
			)
		)

		## Chunk unloading or coordinate reuse may occur while the
		## generation call is being processed.
		if not _is_current(pending):
			continue

		if fauna_data == null:
			push_warning(
				"Fauna generation returned null for chunk %s."
				% str(pending.chunk_coordinate)
			)
			continue

		var validation_error: String = (
			fauna_data.get_validation_error()
		)

		if not validation_error.is_empty():
			push_error(
				"Invalid fauna data for chunk %s: %s"
				% [
					str(pending.chunk_coordinate),
					validation_error,
				]
			)
			continue

		var registered: bool = (
			_fauna_coordinator.register_chunk_data(
				fauna_data
			)
		)
		

		if not registered:
			push_error(
				"FaunaCoordinator rejected chunk %s."
				% str(pending.chunk_coordinate)
			)
			continue
			


		var giant_squid_descriptor: FaunaPopulationDescriptor = (
			_giant_squid_sampler.generate_for_chunk(
			pending.terrain_data,
			_environment_sampler
			)
		)

		if giant_squid_descriptor != null:
			var giant_squid_registered: bool = (
				_giant_squid_coordinator
				.register_descriptor(
					giant_squid_descriptor
				)
			)

			if giant_squid_registered:
				print(
					"Giant squid regional home discovered: %d"
					% giant_squid_descriptor.stable_id
				)

		_generated_chunk_count += 1
		_generated_population_count += (
			fauna_data.get_population_count()
		)
		
	

		if print_chunk_counts:
			print(
				"Fauna chunk %s: %d population homes"
				% [
					str(pending.chunk_coordinate),
					fauna_data.get_population_count(),
				]
			)


func _on_chunk_activated(
	chunk_coordinate: Vector2i,
	world_chunk: WorldChunk
) -> void:
	if not _initialized:
		return

	var terrain_data: TerrainChunkData = (
		_extract_terrain_data(world_chunk)
	)

	if terrain_data == null:
		push_error(
			"FaunaGenerationBridge could not obtain "
			+ "TerrainChunkData for chunk %s."
			% str(chunk_coordinate)
		)
		return

	## Replacing a coordinate invalidates any previously registered
	## descriptor data and runtime fish associated with it.
	_fauna_coordinator.unregister_chunk_data(
		chunk_coordinate
	)

	var activation_token: int = (
		_next_activation_token
	)

	_next_activation_token += 1

	_active_tokens[
		chunk_coordinate
	] = activation_token

	_queued_tokens[
		chunk_coordinate
	] = activation_token

	var pending: PendingGeneration = (
		PendingGeneration.new(
			chunk_coordinate,
			terrain_data,
			activation_token
		)
	)

	_pending.append(pending)


func _on_chunk_deactivated(
	chunk_coordinate: Vector2i
) -> void:
	if not _initialized:
		return

	## Erasing the active token makes every queued record from this
	## activation stale.
	_active_tokens.erase(chunk_coordinate)
	_queued_tokens.erase(chunk_coordinate)

	_remove_pending_coordinate(
		chunk_coordinate
	)

	_fauna_coordinator.unregister_chunk_data(
		chunk_coordinate
	)


func _remove_pending_coordinate(
	chunk_coordinate: Vector2i
) -> void:
	var retained: Array[PendingGeneration] = []

	for pending in _pending:
		if pending == null:
			continue

		if pending.chunk_coordinate == chunk_coordinate:
			continue

		retained.append(pending)

	_pending = retained


func _is_current(
	pending: PendingGeneration
) -> bool:
	if pending == null:
		return false

	var active_token: int = int(
		_active_tokens.get(
			pending.chunk_coordinate,
			-1
		)
	)

	return active_token == pending.activation_token


static func _extract_terrain_data(
	world_chunk: WorldChunk
) -> TerrainChunkData:
	if world_chunk == null:
		return null

	if not is_instance_valid(world_chunk):
		return null

	var getter_names: Array[StringName] = [
		&"get_chunk_data",
		&"get_terrain_data",
		&"get_retained_terrain_data",
		&"get_terrain_chunk_data",
	]

	for getter_name in getter_names:
		if not world_chunk.has_method(getter_name):
			continue

		var getter_value: Variant = (
			world_chunk.call(getter_name)
		)

		var getter_data: TerrainChunkData = (
			getter_value as TerrainChunkData
		)

		if getter_data != null:
			return getter_data

	## Compatibility fallback: inspect script variables rather than
	## inferring a TerrainChunkData field name.
	var property_list: Array[Dictionary] = (
		world_chunk.get_property_list()
	)

	for property_info in property_list:
		var usage_value: Variant = (
			property_info.get("usage", 0)
		)

		var usage_flags: int = int(usage_value)

		if (
			usage_flags
			& PROPERTY_USAGE_SCRIPT_VARIABLE
		) == 0:
			continue

		var name_value: Variant = (
			property_info.get(
				"name",
				StringName()
			)
		)

		var property_name: StringName = StringName(
			str(name_value)
		)

		if property_name.is_empty():
			continue

		var property_value: Variant = (
			world_chunk.get(property_name)
		)

		var terrain_data: TerrainChunkData = (
			property_value as TerrainChunkData
		)

		if terrain_data != null:
			return terrain_data

	return null


func _exit_tree() -> void:
	set_process(false)

	if (
		_chunk_coordinator != null
		and is_instance_valid(_chunk_coordinator)
	):
		if (
			_chunk_coordinator
				.chunk_activated
				.is_connected(_on_chunk_activated)
		):
			_chunk_coordinator.chunk_activated.disconnect(
				_on_chunk_activated
			)

		if (
			_chunk_coordinator
				.chunk_deactivated
				.is_connected(_on_chunk_deactivated)
		):
			_chunk_coordinator.chunk_deactivated.disconnect(
				_on_chunk_deactivated
			)

	_pending.clear()
	_queued_tokens.clear()
	_active_tokens.clear()

	_initialized = false
