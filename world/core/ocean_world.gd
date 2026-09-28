class_name OceanWorld
extends Node

var _definition: WorldDefinition
var _observer: Node3D


@onready var _fauna_coordinator: FaunaCoordinator = (
	$SystemsRoot/FaunaCoordinator
)

@onready var _fauna_generation_bridge: FaunaGenerationBridge = (
	$SystemsRoot/FaunaGenerationBridge
)

@onready var _dynamic_entities_root: Node3D = (
	$WorldContent/DynamicEntitiesRoot
)

@onready var _ocean_surface: OceanSurface = (
	$WorldContent/OceanRoot/OceanSurface
)

@onready var _giant_squid_coordinator: GiantSquidCoordinator = (
	$SystemsRoot/GiantSquidCoordinator
)

@onready var _chunk_coordinator: ChunkCoordinator = (
	$SystemsRoot/ChunkCoordinator
)

@onready var _flora_coordinator: FloraCoordinator = (
	$SystemsRoot/FloraCoordinator
)

@onready var _streamed_chunks_root: Node3D = (
	$WorldContent/StreamedChunksRoot
)

@onready var _flora_root: Node3D = (
	$WorldContent/FloraRoot
)




func configure(
	definition: WorldDefinition,
	observer: Node3D
) -> bool:
	if is_inside_tree():
		printerr(
			"OceanWorld must be configured before entering "
			+ "the SceneTree."
		)
		return false

	if _definition != null:
		printerr(
			"OceanWorld can only be configured once."
		)
		return false

	if definition == null:
		printerr(
			"OceanWorld requires a WorldDefinition."
		)
		return false

	if observer == null or not is_instance_valid(observer):
		printerr(
			"OceanWorld requires a valid observer."
		)
		return false

	var validation_errors := definition.validate()

	if not validation_errors.is_empty():
		for message in validation_errors:
			printerr(
				"Invalid WorldDefinition: %s"
				% message
			)

		return false

	_definition = definition
	_observer = observer

	return true


func _ready() -> void:
	if _definition == null or _observer == null:
		printerr(
			"OceanWorld entered the SceneTree without "
			+ "configuration."
		)
		return

	if (
		_ocean_surface == null
		or not is_instance_valid(_ocean_surface)
	):
		printerr(
			"OceanWorld requires OceanSurface."
		)
		return

	if (
		_chunk_coordinator == null
		or not is_instance_valid(_chunk_coordinator)
	):
		printerr(
			"OceanWorld requires ChunkCoordinator."
		)
		return

	if (
		_flora_coordinator == null
		or not is_instance_valid(_flora_coordinator)
	):
		printerr(
			"OceanWorld requires FloraCoordinator."
		)
		return

	if (
		_fauna_coordinator == null
		or not is_instance_valid(_fauna_coordinator)
	):
		printerr(
			"OceanWorld requires FaunaCoordinator."
		)
		return

	if (
		_fauna_generation_bridge == null
		or not is_instance_valid(_fauna_generation_bridge)
	):
		printerr(
			"OceanWorld requires FaunaGenerationBridge."
		)
		return

	if (
		_streamed_chunks_root == null
		or not is_instance_valid(_streamed_chunks_root)
	):
		printerr(
			"OceanWorld requires StreamedChunksRoot."
		)
		return

	if (
		_dynamic_entities_root == null
		or not is_instance_valid(_dynamic_entities_root)
	):
		printerr(
			"OceanWorld requires DynamicEntitiesRoot."
		)
		return

	if (
		_flora_root == null
		or not is_instance_valid(_flora_root)
	):
		printerr(
			"OceanWorld requires FloraRoot."
		)
		return

	if not _ocean_surface.initialize(
		_definition.ocean_settings,
		_observer
	):
		printerr(
			"OceanWorld could not initialize OceanSurface."
		)
		return

	## FloraCoordinator connects before terrain generation begins, so it
	## receives every activation signal.
	if not _flora_coordinator.initialize(
		_chunk_coordinator,
		_flora_root,
		_observer,
		_definition.world_seed,
		_definition.generation_version,
		_definition.grid_settings.chunk_size,
		_definition.environment_settings,
		_ocean_surface.global_position.y
	):
		printerr(
			"OceanWorld could not initialize FloraCoordinator."
		)
		return

	var fauna_catalog: FaunaCatalogSnapshot = (
		FaunaCatalogSnapshot.create_default()
	)

	if not _fauna_coordinator.initialize(
		_observer,
		_dynamic_entities_root,
		fauna_catalog,
		_ocean_surface.global_position.y,
		Callable(self, "query_active_seafloor")
	):
		printerr(
			"OceanWorld could not initialize FaunaCoordinator."
		)
		return

	if not _giant_squid_coordinator.initialize(
		_observer,
		_dynamic_entities_root,
		fauna_catalog,
		_ocean_surface.global_position.y,
		Callable(self, "query_active_seafloor")
	):
		printerr(
			"OceanWorld could not initialize GiantSquidCoordinator."
		)
		return

	if not _fauna_generation_bridge.initialize(
		_chunk_coordinator,
		_fauna_coordinator,
		_giant_squid_coordinator,
		_definition.world_seed,
		_definition.generation_version,
		_definition.ocean_settings,
		_definition.environment_settings,
		fauna_catalog
	):
		printerr(
			"OceanWorld could not initialize FaunaGenerationBridge."
		)
		return

	if not _chunk_coordinator.initialize(
		_observer,
		_observer,
		_streamed_chunks_root,
		_definition.world_seed,
		_definition.generation_version,
		_definition.grid_settings,
		_definition.terrain_settings,
		_definition.geology_settings,
		_definition.ocean_settings,
		_definition.environment_settings,
		_definition.chunk_streaming_settings,
		_definition.chunk_generation_settings
	):
		printerr(
			"OceanWorld could not initialize ChunkCoordinator."
		)

		_flora_coordinator.clear_all()
		return


func get_chunk_coordinator() -> ChunkCoordinator:
	return _chunk_coordinator


func get_flora_coordinator() -> FloraCoordinator:
	return _flora_coordinator


func get_world_definition() -> WorldDefinition:
	return _definition


func get_observer() -> Node3D:
	return _observer


func get_sea_level_meters() -> float:
	if (
		_ocean_surface == null
		or not is_instance_valid(_ocean_surface)
	):
		return 0.0

	return _ocean_surface.global_position.y


func get_chunk_coordinate_for_world_position(
	world_position: Vector3
) -> Vector2i:
	if (
		_definition == null
		or _definition.grid_settings == null
	):
		return Vector2i.ZERO

	return TerrainSurfaceQuery.world_to_chunk_coordinate(
		world_position,
		_definition.grid_settings.chunk_size
	)


func query_active_seafloor(
	world_position: Vector3
) -> TerrainSurfaceQueryResult:
	var canonical_coordinate := (
		get_chunk_coordinate_for_world_position(
			world_position
		)
	)

	var unavailable_result := (
		TerrainSurfaceQueryResult.create_unavailable(
			world_position,
			canonical_coordinate
		)
	)

	if (
		_definition == null
		or _definition.grid_settings == null
		or _chunk_coordinator == null
		or not is_instance_valid(_chunk_coordinator)
	):
		return unavailable_result

	var chunk_size: float = (
		_definition.grid_settings.chunk_size
	)

	if chunk_size <= 0.0:
		return unavailable_result

	var candidate_coordinates: Array[Vector2i] = [
		canonical_coordinate
	]

	var local_x: float = (
		world_position.x
		- float(canonical_coordinate.x)
			* chunk_size
	)

	var local_z: float = (
		world_position.z
		- float(canonical_coordinate.y)
			* chunk_size
	)

	var boundary_epsilon: float = 0.0001

	var on_minimum_x_boundary: bool = (
		absf(local_x) <= boundary_epsilon
	)

	var on_minimum_z_boundary: bool = (
		absf(local_z) <= boundary_epsilon
	)

	if on_minimum_x_boundary:
		candidate_coordinates.append(
			canonical_coordinate
			+ Vector2i(-1, 0)
		)

	if on_minimum_z_boundary:
		candidate_coordinates.append(
			canonical_coordinate
			+ Vector2i(0, -1)
		)

	if (
		on_minimum_x_boundary
		and on_minimum_z_boundary
	):
		candidate_coordinates.append(
			canonical_coordinate
			+ Vector2i(-1, -1)
		)

	for candidate_coordinate in candidate_coordinates:
		var result := (
			_chunk_coordinator
			.query_active_surface_in_chunk(
				candidate_coordinate,
				world_position
			)
		)

		if result.available:
			return result

	return unavailable_result


func query_active_environment(
	world_position: Vector3
) -> EnvironmentSample:
	if (
		_chunk_coordinator == null
		or not is_instance_valid(_chunk_coordinator)
	):
		return null

	return _chunk_coordinator.query_active_environment(
		world_position,
		_chunk_coordinator.get_environment_sampler()
	)


func query_active_flora(
	chunk_coordinate: Vector2i
) -> FloraChunkData:
	if (
		_flora_coordinator == null
		or not is_instance_valid(_flora_coordinator)
	):
		return null

	return _flora_coordinator.get_chunk_data(
		chunk_coordinate
	)


func get_cached_flora_chunk(
	chunk_coordinate: Vector2i
) -> FloraChunkData:
	return query_active_flora(
		chunk_coordinate
	)


func get_presented_flora_chunk_count() -> int:
	if (
		_flora_coordinator == null
		or not is_instance_valid(_flora_coordinator)
	):
		return 0

	return _flora_coordinator.get_presented_chunk_count()


func get_presented_flora_instance_count() -> int:
	if (
		_flora_coordinator == null
		or not is_instance_valid(_flora_coordinator)
	):
		return 0

	return (
		_flora_coordinator
		.get_total_presented_instance_count()
	)
