class_name FaunaCoordinator
extends Node

const SCHOOL_HEADING_TURN_RATE: float = 0.85


class SchoolState:
	extends RefCounted

	var descriptor: FaunaPopulationDescriptor
	var species: FaunaSpeciesSnapshot

	var position: Vector3 = Vector3.ZERO
	var velocity: Vector3 = Vector3.ZERO
	var forward: Vector3 = Vector3.FORWARD

	var behavior_state: int = (
		FaunaTypes.BehaviorState.WANDER
	)

	var presentation: FaunaSchoolPresentation


class IndividualState:
	extends RefCounted

	var runtime_id: int = 0

	var descriptor: FaunaPopulationDescriptor
	var species: FaunaSpeciesSnapshot

	var position: Vector3 = Vector3.ZERO
	var velocity: Vector3 = Vector3.ZERO
	var forward: Vector3 = Vector3.FORWARD

	var behavior_state: int = (
		FaunaTypes.BehaviorState.WANDER
	)

	var variant_index: int = 0
	var animation_phase: float = 0.0
	var palette_factor: float = 0.0
	var size_factor: float = 1.0


class PositionSearchResult:
	extends RefCounted

	var found: bool = false
	var world_position: Vector3 = Vector3.ZERO
	var distance_squared: float = INF


@export_category("Activation")

@export_range(1.0, 10000.0, 1.0)
var activation_distance: float = 620.0

@export_range(1.0, 10000.0, 1.0)
var deactivation_distance: float = 760.0

@export_range(1, 128, 1)
var maximum_active_schools: int = 24

@export_range(1, 1024, 1)
var maximum_active_individuals: int = 96


@export_category("Simulation")

@export_range(1.0, 60.0, 1.0)
var simulation_hz: float = 20.0

@export_range(0.05, 5.0, 0.05)
var activation_check_interval: float = 0.50


var _initialized: bool = false

var _observer: Node3D
var _presentation_root: Node3D
var _catalog: FaunaCatalogSnapshot

var _ocean_height: float = 0.0

## Optional callable:
##
##     surface_query.call(world_position)
##
## It should return TerrainSurfaceQueryResult.
var _surface_query: Callable = Callable()

## stable population ID -> FaunaPopulationDescriptor
var _descriptors_by_id: Dictionary = {}

## chunk coordinate -> Array[int population IDs]
var _population_ids_by_chunk: Dictionary = {}

## stable population ID -> SchoolState
var _schools_by_population: Dictionary = {}

var _individuals: Array[IndividualState] = []

## Vector2i(species_id, variant_id) -> MultiMeshInstance3D
var _individual_batches: Dictionary = {}

## Vector2i(species_id, variant_id) -> Array[IndividualState]
var _individual_bucket_states: Dictionary = {}

var _simulation_accumulator: float = 0.0
var _activation_accumulator: float = 0.0
var _simulation_time: float = 0.0

var _individual_presentation_dirty: bool = false


func _ready() -> void:
	set_physics_process(false)


func initialize(
	observer: Node3D,
	presentation_root: Node3D,
	catalog: FaunaCatalogSnapshot,
	ocean_height: float,
	surface_query: Callable = Callable()
) -> bool:
	if _initialized:
		push_error(
			"FaunaCoordinator can only be initialized once."
		)
		return false

	if observer == null or not is_instance_valid(observer):
		push_error(
			"FaunaCoordinator requires a valid observer."
		)
		return false

	if (
		presentation_root == null
		or not is_instance_valid(presentation_root)
	):
		push_error(
			"FaunaCoordinator requires DynamicEntitiesRoot."
		)
		return false

	if catalog == null:
		push_error(
			"FaunaCoordinator requires a fauna catalog."
		)
		return false

	var catalog_error: String = (
		catalog.get_validation_error()
	)

	if not catalog_error.is_empty():
		push_error(catalog_error)
		return false

	if not is_finite(ocean_height):
		push_error(
			"FaunaCoordinator requires a finite ocean height."
		)
		return false

	if deactivation_distance <= activation_distance:
		push_error(
			"Fauna deactivation distance must exceed "
			+ "activation distance."
		)
		return false

	if simulation_hz <= 0.0:
		push_error(
			"Fauna simulation frequency must be positive."
		)
		return false

	_observer = observer
	_presentation_root = presentation_root
	_catalog = catalog
	_ocean_height = ocean_height
	_surface_query = surface_query

	_initialized = true
	set_physics_process(true)

	return true


func register_chunk_data(
	fauna_data: FaunaChunkData
) -> bool:
	if not _initialized:
		push_error(
			"FaunaCoordinator must be initialized before "
			+ "registering chunk data."
		)
		return false

	if fauna_data == null:
		return false

	var validation_error: String = (
		fauna_data.get_validation_error()
	)

	if not validation_error.is_empty():
		push_error(validation_error)
		return false

	unregister_chunk_data(
		fauna_data.chunk_coordinate
	)

	var population_ids: Array[int] = []

	for descriptor in fauna_data.populations:
		if descriptor == null:
			continue

		_descriptors_by_id[
			descriptor.stable_id
		] = descriptor

		population_ids.append(
			descriptor.stable_id
		)

	_population_ids_by_chunk[
		fauna_data.chunk_coordinate
	] = population_ids

	return true


func unregister_chunk_data(
	chunk_coordinate: Vector2i
) -> void:
	var stored_value: Variant = (
		_population_ids_by_chunk.get(
			chunk_coordinate,
			[]
		)
	)

	if not stored_value is Array:
		_population_ids_by_chunk.erase(
			chunk_coordinate
		)
		return

	var stored_ids: Array = stored_value as Array

	for population_id_value in stored_ids:
		var population_id: int = int(
			population_id_value
		)

		_deactivate_population(population_id)
		_descriptors_by_id.erase(population_id)

	_population_ids_by_chunk.erase(
		chunk_coordinate
	)


func get_descriptor_count() -> int:
	return _descriptors_by_id.size()


func get_active_school_count() -> int:
	return _schools_by_population.size()


func get_active_individual_count() -> int:
	return _individuals.size()


## Aggregate-school collision/query API.
##
## This tests one school volume rather than every rendered member.
func query_school_populations_in_sphere(
	world_center: Vector3,
	radius: float
) -> Array[int]:
	var matches: Array[int] = []

	if radius < 0.0:
		return matches

	for school_value in _schools_by_population.values():
		var school: SchoolState = (
			school_value as SchoolState
		)

		if school == null:
			continue

		var aggregate_radius: float = (
			school.descriptor.home_radius * 0.30
		)

		var allowed_distance: float = (
			radius + aggregate_radius
		)

		var distance_squared: float = (
			school.position.distance_squared_to(
				world_center
			)
		)

		if (
			distance_squared
			<= allowed_distance * allowed_distance
		):
			matches.append(
				school.descriptor.stable_id
			)

	return matches


func _physics_process(
	delta: float
) -> void:
	if not _initialized:
		return

	_activation_accumulator += delta
	_simulation_accumulator += delta

	if (
		_activation_accumulator
		>= activation_check_interval
	):
		_activation_accumulator = 0.0
		_update_activation()

	var simulation_step: float = (
		1.0 / maxf(simulation_hz, 1.0)
	)

	var completed_steps: int = 0

	while (
		_simulation_accumulator >= simulation_step
		and completed_steps < 2
	):
		_simulation_accumulator -= simulation_step
		_simulation_time += simulation_step

		_simulate(simulation_step)
		completed_steps += 1


func _update_activation() -> void:
	if (
		_observer == null
		or not is_instance_valid(_observer)
	):
		return

	var observer_position: Vector3 = (
		_observer.global_position
	)

	var deactivate_squared: float = (
		deactivation_distance
		* deactivation_distance
	)

	var active_population_ids: Array[int] = []
	var active_population_set: Dictionary = {}

	for population_id_value in (
		_schools_by_population.keys()
	):
		var population_id: int = int(
			population_id_value
		)

		active_population_ids.append(population_id)
		active_population_set[population_id] = true

	for individual in _individuals:
		if individual == null:
			continue

		var population_id: int = (
			individual.descriptor.stable_id
		)

		if active_population_set.has(population_id):
			continue

		active_population_ids.append(population_id)
		active_population_set[population_id] = true

	for population_id in active_population_ids:
		var descriptor: FaunaPopulationDescriptor = (
			_descriptors_by_id.get(population_id)
			as FaunaPopulationDescriptor
		)

		if descriptor == null:
			_deactivate_population(population_id)
			continue

		var home_distance_squared: float = (
			descriptor.home_position
			.distance_squared_to(observer_position)
		)

		if home_distance_squared > deactivate_squared:
			_deactivate_population(population_id)

	var eligible: Array[FaunaPopulationDescriptor] = []

	var activate_squared: float = (
		activation_distance
		* activation_distance
	)

	for descriptor_value in _descriptors_by_id.values():
		var descriptor: FaunaPopulationDescriptor = (
			descriptor_value
			as FaunaPopulationDescriptor
		)

		if descriptor == null:
			continue

		if _is_population_active(
			descriptor.stable_id
		):
			continue

		var home_distance_squared: float = (
			descriptor.home_position
			.distance_squared_to(observer_position)
		)

		if home_distance_squared <= activate_squared:
			eligible.append(descriptor)

	eligible.sort_custom(
		func(
			left: FaunaPopulationDescriptor,
			right: FaunaPopulationDescriptor
		) -> bool:
			var left_distance: float = (
				left.home_position.distance_squared_to(
					observer_position
				)
			)

			var right_distance: float = (
				right.home_position.distance_squared_to(
					observer_position
				)
			)

			if not is_equal_approx(
				left_distance,
				right_distance
			):
				return left_distance < right_distance

			return left.stable_id < right.stable_id
	)

	for descriptor in eligible:
		_activate_population(descriptor)


func _activate_population(
	descriptor: FaunaPopulationDescriptor
) -> void:
	if descriptor == null:
		return

	if _is_population_active(descriptor.stable_id):
		return

	var species: FaunaSpeciesSnapshot = (
		_catalog.get_species(
			descriptor.species_id
		)
	)

	if species == null:
		return

	if (
		species.trophic_role
		== FaunaTypes.TrophicRole.APEX_PREDATOR
	):
		## Apex predators are deliberately deferred.
		return

	if (
		species.presentation_mode
		== FaunaTypes.PresentationMode.SCHOOL_AGGREGATE
	):
		if (
			_schools_by_population.size()
			>= maximum_active_schools
		):
			return

		_activate_school(
			descriptor,
			species
		)
		return

	var representative_count: int = mini(
		descriptor.initial_population,
		species.maximum_representatives
	)

	var available_slots: int = (
		maximum_active_individuals
		- _individuals.size()
	)

	representative_count = mini(
		representative_count,
		available_slots
	)

	if representative_count <= 0:
		return

	for member_index in range(representative_count):
		var individual: IndividualState = (
			_create_individual_state(
				descriptor,
				species,
				member_index
			)
		)

		_individuals.append(individual)

	_individual_presentation_dirty = true


func _activate_school(
	descriptor: FaunaPopulationDescriptor,
	species: FaunaSpeciesSnapshot
) -> void:
	var school: SchoolState = SchoolState.new()

	school.descriptor = descriptor
	school.species = species
	school.position = descriptor.home_position

	school.forward = Vector3(
		sin(descriptor.initial_heading_radians),
		0.0,
		-cos(descriptor.initial_heading_radians)
	).normalized()

	school.velocity = (
		school.forward
		* species.cruise_speed
		* 0.70
	)

	school.behavior_state = (
		FaunaTypes.BehaviorState.WANDER
	)

	var presentation: FaunaSchoolPresentation = (
		FaunaSchoolPresentation.new()
	)

	if not presentation.initialize(
		descriptor,
		species
	):
		presentation.free()
		return

	school.presentation = presentation

	_presentation_root.add_child(presentation)

	_schools_by_population[
		descriptor.stable_id
	] = school


func _create_individual_state(
	descriptor: FaunaPopulationDescriptor,
	species: FaunaSpeciesSnapshot,
	member_index: int
) -> IndividualState:
	var individual: IndividualState = (
		IndividualState.new()
	)

	individual.runtime_id = (
		StableSeed.derive_channel_seed(
			descriptor.behavior_seed,
			10000 + member_index
		)
	)

	individual.descriptor = descriptor
	individual.species = species

	var angle: float = (
		StableSeed.seed_to_unit_float(
			StableSeed.derive_channel_seed(
				individual.runtime_id,
				1
			)
		) * TAU
	)

	var radius: float = (
		StableSeed.seed_to_unit_float(
			StableSeed.derive_channel_seed(
				individual.runtime_id,
				2
			)
		)
		* descriptor.home_radius
		* 0.35
	)

	var vertical_range: float = minf(
		descriptor.maximum_altitude
			- descriptor.minimum_altitude,
		4.0
	)

	var vertical_offset: float = (
		StableSeed.seed_to_unit_float(
			StableSeed.derive_channel_seed(
				individual.runtime_id,
				3
			)
		) * 2.0 - 1.0
	) * vertical_range * 0.30

	individual.position = (
		descriptor.home_position
		+ Vector3(
			cos(angle) * radius,
			vertical_offset,
			sin(angle) * radius
		)
	)

	var heading: float = (
		descriptor.initial_heading_radians
		+ (
			StableSeed.seed_to_unit_float(
				StableSeed.derive_channel_seed(
					individual.runtime_id,
					4
				)
			) - 0.5
		) * 1.2
	)

	individual.forward = Vector3(
		sin(heading),
		0.0,
		-cos(heading)
	).normalized()

	individual.velocity = (
		individual.forward
		* species.cruise_speed
		* 0.70
	)

	individual.behavior_state = (
		FaunaTypes.BehaviorState.WANDER
	)

	individual.variant_index = _positive_mod(
		individual.runtime_id,
		species.procedural_variant_count
	)

	individual.animation_phase = (
		StableSeed.seed_to_unit_float(
			StableSeed.derive_channel_seed(
				individual.runtime_id,
				5
			)
		)
	)

	individual.palette_factor = (
		StableSeed.seed_to_unit_float(
			StableSeed.derive_channel_seed(
				individual.runtime_id,
				6
			)
		)
	)

	individual.size_factor = lerpf(
		0.90,
		1.10,
		StableSeed.seed_to_unit_float(
			StableSeed.derive_channel_seed(
				individual.runtime_id,
				7
			)
		)
	)

	return individual


func _deactivate_population(
	population_id: int
) -> void:
	var school: SchoolState = (
		_schools_by_population.get(population_id)
		as SchoolState
	)

	if school != null:
		if (
			school.presentation != null
			and is_instance_valid(
				school.presentation
			)
		):
			school.presentation.queue_free()

		_schools_by_population.erase(
			population_id
		)

	var retained: Array[IndividualState] = []
	var removed_individual: bool = false

	for individual in _individuals:
		if individual == null:
			continue

		if (
			individual.descriptor.stable_id
			== population_id
		):
			removed_individual = true
			continue

		retained.append(individual)

	_individuals = retained

	if removed_individual:
		_individual_presentation_dirty = true


func _is_population_active(
	population_id: int
) -> bool:
	if _schools_by_population.has(population_id):
		return true

	for individual in _individuals:
		if individual == null:
			continue

		if (
			individual.descriptor.stable_id
			== population_id
		):
			return true

	return false


func _simulate(
	delta: float
) -> void:
	if _individual_presentation_dirty:
		_rebuild_individual_batches()

	var predator_positions: Array[Vector3] = []

	for individual in _individuals:
		if individual == null:
			continue

		if (
			individual.species.trophic_role
			== FaunaTypes.TrophicRole.PREDATOR
		):
			predator_positions.append(
				individual.position
			)

	for school_value in _schools_by_population.values():
		var school: SchoolState = (
			school_value as SchoolState
		)

		if school == null:
			continue

		_simulate_school(
			school,
			predator_positions,
			delta
		)

	for individual in _individuals:
		if individual == null:
			continue

		_simulate_individual(
			individual,
			predator_positions,
			delta
		)

	_update_individual_transforms()


func _simulate_school(
	school: SchoolState,
	predator_positions: Array[Vector3],
	delta: float
) -> void:
	var desired_direction: Vector3 = Vector3.ZERO

	var desired_speed: float = (
		school.species.cruise_speed
	)

	var threat: PositionSearchResult = (
		_nearest_position(
			school.position,
			predator_positions
		)
	)

	if (
		threat.found
		and threat.distance_squared
			<= (
				school.species.threat_distance
				* school.species.threat_distance
			)
	):
		desired_direction = (
			school.position
			- threat.world_position
		).normalized()

		desired_speed = school.species.flee_speed

		school.behavior_state = (
			FaunaTypes.BehaviorState.FLEE
		)
	else:
		var home_offset: Vector3 = (
			school.descriptor.home_position
			- school.position
		)

		if (
			home_offset.length()
			> school.descriptor.home_radius
		):
			desired_direction = (
				home_offset.normalized()
			)

			school.behavior_state = (
				FaunaTypes.BehaviorState.RETURN_HOME
			)
		else:
			var seed_phase: float = (
				StableSeed.seed_to_unit_float(
					school.descriptor.behavior_seed
				) * TAU
			)

			var angle: float = (
				school.descriptor
					.initial_heading_radians
				+ sin(
					_simulation_time * 0.31
					+ seed_phase
				) * 0.35
			)

			desired_direction = Vector3(
				sin(angle),
				sin(
					_simulation_time * 0.23
					+ seed_phase * 1.7
				) * 0.04,
				-cos(angle)
			).normalized()

			school.behavior_state = (
				FaunaTypes.BehaviorState.WANDER
			)

	school.velocity = school.velocity.move_toward(
		desired_direction * desired_speed,
		school.species.turn_rate * delta
	)

	school.position += school.velocity * delta

	school.position = _constrain_position(
		school.position,
		school.descriptor
	)

	if not school.velocity.is_zero_approx():
		var target_forward := school.velocity.normalized()
		var heading_factor := clampf(
			SCHOOL_HEADING_TURN_RATE * delta,
			0.0,
			1.0
		)

		school.forward = (
			school.forward
			.slerp(target_forward, heading_factor)
			.normalized()
		)

	if (
		school.presentation != null
		and is_instance_valid(school.presentation)
	):
		school.presentation.apply_runtime_transform(
			school.position,
			school.forward
		)


func _simulate_individual(
	individual: IndividualState,
	predator_positions: Array[Vector3],
	delta: float
) -> void:
	var desired_direction: Vector3 = Vector3.ZERO

	var desired_speed: float = (
		individual.species.cruise_speed
	)

	if (
		individual.species.trophic_role
		== FaunaTypes.TrophicRole.PREDATOR
	):
		var target: PositionSearchResult = (
			_find_nearest_prey(
				individual.position,
				individual.runtime_id
			)
		)

		if (
			target.found
			and target.distance_squared
				<= (
					individual.species
						.pursuit_distance
					* individual.species
						.pursuit_distance
				)
		):
			desired_direction = (
				target.world_position
				- individual.position
			).normalized()

			desired_speed = (
				individual.species.flee_speed
			)

			individual.behavior_state = (
				FaunaTypes.BehaviorState.PURSUE
			)
	else:
		var threat: PositionSearchResult = (
			_nearest_position(
				individual.position,
				predator_positions
			)
		)

		if (
			threat.found
			and threat.distance_squared
				<= (
					individual.species
						.threat_distance
					* individual.species
						.threat_distance
				)
		):
			desired_direction = (
				individual.position
				- threat.world_position
			).normalized()

			desired_speed = (
				individual.species.flee_speed
			)

			individual.behavior_state = (
				FaunaTypes.BehaviorState.FLEE
			)

	if desired_direction.is_zero_approx():
		var home_offset: Vector3 = (
			individual.descriptor.home_position
			- individual.position
		)

		if (
			home_offset.length()
			> individual.descriptor.home_radius
		):
			desired_direction = (
				home_offset.normalized()
			)

			individual.behavior_state = (
				FaunaTypes.BehaviorState.RETURN_HOME
			)
		else:
			var phase: float = (
				individual.animation_phase * TAU
			)

			var angle: float = (
				individual.descriptor
					.initial_heading_radians
				+ sin(
					_simulation_time * 0.37
					+ phase
				) * 1.45
			)

			desired_direction = Vector3(
				sin(angle),
				sin(
					_simulation_time * 0.29
					+ phase * 1.8
				) * 0.16,
				-cos(angle)
			).normalized()

			individual.behavior_state = (
				FaunaTypes.BehaviorState.WANDER
			)

	individual.velocity = individual.velocity.move_toward(
		desired_direction * desired_speed,
		individual.species.turn_rate * delta
	)

	individual.position += individual.velocity * delta

	individual.position = _constrain_position(
		individual.position,
		individual.descriptor
	)

	if not individual.velocity.is_zero_approx():
		individual.forward = (
			individual.velocity.normalized()
		)


func _find_nearest_prey(
	origin: Vector3,
	excluded_runtime_id: int
) -> PositionSearchResult:
	var search_result: PositionSearchResult = (
		PositionSearchResult.new()
	)

	for individual in _individuals:
		if individual == null:
			continue

		if individual.runtime_id == excluded_runtime_id:
			continue

		if (
			individual.species.trophic_role
			!= FaunaTypes.TrophicRole.HERBIVORE
		):
			continue

		var distance_squared: float = (
			origin.distance_squared_to(
				individual.position
			)
		)

		if (
			not search_result.found
			or distance_squared
				< search_result.distance_squared
		):
			search_result.found = true
			search_result.distance_squared = (
				distance_squared
			)
			search_result.world_position = (
				individual.position
			)

	for school_value in _schools_by_population.values():
		var school: SchoolState = (
			school_value as SchoolState
		)

		if school == null:
			continue

		if (
			school.species.trophic_role
			!= FaunaTypes.TrophicRole.HERBIVORE
		):
			continue

		var distance_squared: float = (
			origin.distance_squared_to(
				school.position
			)
		)

		if (
			not search_result.found
			or distance_squared
				< search_result.distance_squared
		):
			search_result.found = true
			search_result.distance_squared = (
				distance_squared
			)
			search_result.world_position = (
				school.position
			)

	return search_result


func _constrain_position(
	world_position: Vector3,
	descriptor: FaunaPopulationDescriptor
) -> Vector3:
	var constrained_position: Vector3 = world_position

	var fallback_floor: float = (
		descriptor.home_position.y
		- (
			descriptor.minimum_altitude
			+ descriptor.maximum_altitude
		) * 0.5
	)

	var floor_height: float = fallback_floor

	if _surface_query.is_valid():
		var query_value: Variant = (
			_surface_query.call(
				constrained_position
			)
		)

		var query_result: TerrainSurfaceQueryResult = (
			query_value as TerrainSurfaceQueryResult
		)

		if (
			query_result != null
			and query_result.available
		):
			floor_height = (
				query_result.surface_elevation_meters
			)

	var minimum_y: float = (
		floor_height
		+ maxf(
			descriptor.minimum_altitude,
			0.65
		)
	)

	var maximum_y: float = minf(
		floor_height + descriptor.maximum_altitude,
		_ocean_height - 1.0
	)

	if maximum_y < minimum_y:
		maximum_y = minimum_y

	constrained_position.y = clampf(
		constrained_position.y,
		minimum_y,
		maximum_y
	)

	return constrained_position


func _rebuild_individual_batches() -> void:
	_clear_individual_batches()
	_individual_bucket_states.clear()

	for individual in _individuals:
		if individual == null:
			continue

		var bucket_key: Vector2i = Vector2i(
			individual.species.species_id,
			individual.variant_index
		)

		var bucket_value: Variant = (
			_individual_bucket_states.get(
				bucket_key,
				[]
			)
		)

		var bucket: Array = []

		if bucket_value is Array:
			bucket = bucket_value as Array

		bucket.append(individual)

		_individual_bucket_states[
			bucket_key
		] = bucket

	for key_value in _individual_bucket_states.keys():
		var bucket_key: Vector2i = (
			key_value as Vector2i
		)

		var states_value: Variant = (
			_individual_bucket_states.get(
				bucket_key,
				[]
			)
		)

		if not states_value is Array:
			continue

		var states: Array = states_value as Array

		states.sort_custom(
			func(
				left: IndividualState,
				right: IndividualState
			) -> bool:
				return (
					left.runtime_id
					< right.runtime_id
				)
		)

		var species: FaunaSpeciesSnapshot = (
			_catalog.get_species(bucket_key.x)
		)

		if species == null:
			continue

		var mesh: ArrayMesh = (
			FaunaProceduralMeshFactory.create_mesh(
				species,
				bucket_key.y
			)
		)

		var material: ShaderMaterial = (
			FaunaMaterialFactory.get_material(
				species
			)
		)

		if mesh == null or material == null:
			continue

		var multimesh: MultiMesh = MultiMesh.new()

		multimesh.transform_format = (
			MultiMesh.TRANSFORM_3D
		)

		multimesh.use_custom_data = true
		multimesh.mesh = mesh
		multimesh.instance_count = states.size()
		multimesh.visible_instance_count = states.size()

		for index in range(states.size()):
			var individual: IndividualState = (
				states[index] as IndividualState
			)

			if individual == null:
				continue

			multimesh.set_instance_custom_data(
				index,
				Color(
					individual.animation_phase,
					individual.palette_factor,
					1.0,
					1.0
				)
			)

		var instance_node: MultiMeshInstance3D = (
			MultiMeshInstance3D.new()
		)

		instance_node.name = (
			"%sVariant%dMultiMesh"
			% [
				species.display_name,
				bucket_key.y,
			]
		)

		instance_node.multimesh = multimesh
		instance_node.material_override = material

		instance_node.cast_shadow = (
			GeometryInstance3D
			.SHADOW_CASTING_SETTING_OFF
		)

		_presentation_root.add_child(instance_node)

		_individual_batches[
			bucket_key
		] = instance_node

	_individual_presentation_dirty = false

	_update_individual_transforms()


func _update_individual_transforms() -> void:
	for key_value in _individual_bucket_states.keys():
		var bucket_key: Vector2i = (
			key_value as Vector2i
		)

		var instance_node: MultiMeshInstance3D = (
			_individual_batches.get(bucket_key)
			as MultiMeshInstance3D
		)

		if (
			instance_node == null
			or instance_node.multimesh == null
		):
			continue

		var states_value: Variant = (
			_individual_bucket_states.get(
				bucket_key,
				[]
			)
		)

		if not states_value is Array:
			continue

		var states: Array = states_value as Array

		for index in range(states.size()):
			var individual: IndividualState = (
				states[index] as IndividualState
			)

			if individual == null:
				continue

			var orientation: Basis = (
				_basis_from_forward(
					individual.forward
				)
			)

			orientation = orientation.scaled(
				Vector3.ONE
				* individual.size_factor
			)

			instance_node.multimesh.set_instance_transform(
				index,
				Transform3D(
					orientation,
					individual.position
				)
			)


func _clear_individual_batches() -> void:
	for instance_value in _individual_batches.values():
		var instance_node: MultiMeshInstance3D = (
			instance_value as MultiMeshInstance3D
		)

		if (
			instance_node != null
			and is_instance_valid(instance_node)
		):
			instance_node.queue_free()

	_individual_batches.clear()


static func _nearest_position(
	origin: Vector3,
	positions: Array[Vector3]
) -> PositionSearchResult:
	var search_result: PositionSearchResult = (
		PositionSearchResult.new()
	)

	for candidate_position in positions:
		var distance_squared: float = (
			origin.distance_squared_to(
				candidate_position
			)
		)

		if (
			not search_result.found
			or distance_squared
				< search_result.distance_squared
		):
			search_result.found = true
			search_result.distance_squared = (
				distance_squared
			)
			search_result.world_position = (
				candidate_position
			)

	return search_result


static func _basis_from_forward(
	forward: Vector3
) -> Basis:
	var direction: Vector3 = forward

	if direction.is_zero_approx():
		direction = Vector3.FORWARD
	else:
		direction = direction.normalized()

	## The procedural fish model faces negative Z.
	var z_axis: Vector3 = -direction
	var y_axis: Vector3 = Vector3.UP

	if absf(z_axis.dot(y_axis)) > 0.98:
		y_axis = Vector3.FORWARD

	var x_axis: Vector3 = (
		y_axis.cross(z_axis).normalized()
	)

	y_axis = z_axis.cross(x_axis).normalized()

	return Basis(
		x_axis,
		y_axis,
		z_axis
	)


static func _positive_mod(
	value: int,
	divisor: int
) -> int:
	if divisor <= 0:
		return 0

	var modulus: int = value % divisor

	if modulus < 0:
		modulus += divisor

	return modulus


func _exit_tree() -> void:
	set_physics_process(false)

	_clear_individual_batches()
	_individual_bucket_states.clear()

	for school_value in _schools_by_population.values():
		var school: SchoolState = (
			school_value as SchoolState
		)

		if school == null:
			continue

		if (
			school.presentation != null
			and is_instance_valid(
				school.presentation
			)
		):
			school.presentation.queue_free()

	_schools_by_population.clear()
	_individuals.clear()
	_descriptors_by_id.clear()
	_population_ids_by_chunk.clear()

	_initialized = false
