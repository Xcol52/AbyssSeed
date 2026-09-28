class_name FloraPlacementSampler
extends RefCounted

const SUITABILITY_EPSILON: float = 0.000001
const BIOME_AFFINITY_WEIGHT: float = 1.5

## Giant-kelp morphology tuning.
##
## These values are authored tuning constants, not values derived from
## the visual reference.
const KELP_NEIGHBOR_RADIUS: float = 72.0
const KELP_NEIGHBOR_COUNT_FOR_FULL_DENSITY: float = 5.0

## Keep the visual temperature factor linear so the kelp material colors
## remain the endpoints of the full placement temperature range.
const KELP_TEMPERATURE_CONTRAST: float = 1.0
const KELP_TEMPERATURE_MIDPOINT: float = 0.50

const KELP_DENSITY_WEIGHT: float = 0.40
const KELP_DEPTH_WEIGHT: float = 0.25
const KELP_DARKNESS_WEIGHT: float = 0.35
const KELP_SURFACE_CLEARANCE: float = 2.0
const KELP_SEGMENT_HEIGHT: float = 0.60
const KELP_BASE_SEGMENT_COUNT: int = 6
const KELP_SEGMENTS_PER_TIER: int = 4
const KELP_MINIMUM_SIZE_FACTOR: float = 0.62
const KELP_MAXIMUM_SIZE_FACTOR: float = 1.65

## Used only when a future catalog accidentally omits one of the
## environmental criteria needed for kelp morphology.
const KELP_FALLBACK_MAXIMUM_DEPTH: float = 250.0
const KELP_FALLBACK_MINIMUM_TEMPERATURE: float = -2.0
const KELP_FALLBACK_MAXIMUM_TEMPERATURE: float = 24.0

var _flora_seed: int
var _catalog: FloraCatalogSnapshot
var _validation_error: String = ""

## species_id -> FloraSpeciesSnapshot
var _species_by_id: Dictionary = {}

## species_id -> FastNoiseLite
##
## Do not share one FloraPlacementSampler instance between concurrent
## worker threads. Construct one sampler set per worker.
var _patch_noises: Dictionary = {}


func _init(
	flora_seed: int,
	catalog: FloraCatalogSnapshot
) -> void:
	assert(catalog != null)

	_flora_seed = flora_seed
	_catalog = catalog
	_validation_error = _catalog.get_validation_error()

	if not _validation_error.is_empty():
		return

	for species in _catalog.species:
		_species_by_id[species.species_id] = species

		var patch_noise := FastNoiseLite.new()

		patch_noise.seed = StableSeed.derive_channel_seed(
			_flora_seed,
			FloraChannels.for_species(
				FloraChannels.PATCH_NOISE_BASE,
				species.species_id
			)
		)

		patch_noise.frequency = 1.0 / species.patch_size
		patch_noise.noise_type = (
			FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		)
		patch_noise.fractal_type = (
			FastNoiseLite.FRACTAL_FBM
		)
		patch_noise.fractal_octaves = 3
		patch_noise.fractal_gain = 0.5
		patch_noise.fractal_lacunarity = 2.0

		_patch_noises[species.species_id] = patch_noise


func get_validation_error() -> String:
	return _validation_error


func evaluate_species(
	species_id: int,
	environment: EnvironmentSample,
	biome_result: BiomeSuitabilityResult
) -> float:
	if environment == null or biome_result == null:
		return 0.0

	if not _validation_error.is_empty():
		return 0.0

	var species := (
		_species_by_id.get(species_id)
		as FloraSpeciesSnapshot
	)

	if species == null:
		return 0.0

	var biome_suitability := 0.0

	for biome_id in range(BiomeIds.COUNT):
		var affinity := species.get_biome_affinity(
			biome_id
		)

		if affinity <= 0.0:
			continue

		var weighted_biome_suitability := (
			biome_result.get_weight(biome_id)
			* affinity
		)

		biome_suitability = maxf(
			biome_suitability,
			weighted_biome_suitability
		)

	if biome_suitability <= SUITABILITY_EPSILON:
		return 0.0

	var weighted_log_sum := (
		log(
			maxf(
				biome_suitability,
				SUITABILITY_EPSILON
			)
		)
		* BIOME_AFFINITY_WEIGHT
	)

	var total_weight := BIOME_AFFINITY_WEIGHT

	for criterion in species.criteria:
		var evidence_value := _get_evidence_value(
			environment,
			criterion.channel_id
		)

		var criterion_suitability := (
			_evaluate_criterion(
				criterion,
				evidence_value
			)
		)

		if criterion_suitability <= SUITABILITY_EPSILON:
			return 0.0

		weighted_log_sum += (
			log(criterion_suitability)
			* criterion.weight
		)

		total_weight += criterion.weight

	if total_weight <= SUITABILITY_EPSILON:
		return 0.0

	return clampf(
		exp(weighted_log_sum / total_weight),
		0.0,
		1.0
	)


func generate_chunk(
	terrain_data: TerrainChunkData,
	environment_sampler: EnvironmentSampler,
	biome_sampler: BiomeSuitabilitySampler
) -> FloraChunkData:
	if not _validation_error.is_empty():
		return null

	if (
		terrain_data == null
		or environment_sampler == null
		or biome_sampler == null
	):
		return null

	if terrain_data.geology_data == null:
		return null

	if (
		terrain_data.cells_per_axis < 1
		or not is_finite(terrain_data.cell_size)
		or terrain_data.cell_size <= 0.0
	):
		return null

	var world_origin := (
		terrain_data.geology_data.world_origin
	)

	if (
		not is_finite(world_origin.x)
		or not is_finite(world_origin.y)
	):
		return null

	var chunk_size := (
		float(terrain_data.cells_per_axis)
		* terrain_data.cell_size
	)

	if not is_finite(chunk_size) or chunk_size <= 0.0:
		return null

	var world_maximum := (
		world_origin
		+ Vector2.ONE * chunk_size
	)

	var candidates: Array[FloraPlacementCandidate] = []

	for species in _catalog.species:
		_generate_species_candidates(
			species,
			terrain_data,
			environment_sampler,
			biome_sampler,
			world_origin,
			world_maximum,
			candidates
		)

	## Kelp morphology is finalized only after all accepted kelp in the
	## authoritative chunk are known.
	_finalize_kelp_morphology(
		candidates,
		world_origin,
		world_maximum
	)

	candidates.sort_custom(
		_candidate_less_than
	)

	return FloraChunkData.new(
		terrain_data.chunk_coordinate,
		world_origin,
		chunk_size,
		candidates
	)


func _generate_species_candidates(
	species: FloraSpeciesSnapshot,
	terrain_data: TerrainChunkData,
	environment_sampler: EnvironmentSampler,
	biome_sampler: BiomeSuitabilitySampler,
	world_minimum: Vector2,
	world_maximum: Vector2,
	output: Array[FloraPlacementCandidate]
) -> void:
	if species == null:
		return

	var spacing := species.candidate_spacing

	if not is_finite(spacing) or spacing <= 0.0:
		return

	var minimum_cell_x := (
		floori(world_minimum.x / spacing)
		- 1
	)

	var minimum_cell_z := (
		floori(world_minimum.y / spacing)
		- 1
	)

	var maximum_cell_x := (
		floori(world_maximum.x / spacing)
		+ 1
	)

	var maximum_cell_z := (
		floori(world_maximum.y / spacing)
		+ 1
	)

	for candidate_z in range(
		minimum_cell_z,
		maximum_cell_z + 1
	):
		for candidate_x in range(
			minimum_cell_x,
			maximum_cell_x + 1
		):
			var candidate_cell := Vector2i(
				candidate_x,
				candidate_z
			)

			var world_xz := _create_candidate_position(
				species,
				candidate_cell
			)

			if (
				world_xz.x < world_minimum.x
				or world_xz.y < world_minimum.y
				or world_xz.x >= world_maximum.x
				or world_xz.y >= world_maximum.y
			):
				continue

			var environment := (
				environment_sampler.sample_world(
					terrain_data,
					world_xz
				)
			)

			if environment == null:
				continue

			if (
				species.species_id == FloraIds.GIANT_KELP
				and not _supports_kelp_tier_zero(
					environment.depth_below_surface
				)
			):
				continue

			var biome_result := biome_sampler.evaluate(
				environment
			)

			if biome_result == null:
				continue

			var suitability := evaluate_species(
				species.species_id,
				environment,
				biome_result
			)

			if suitability < species.minimum_suitability:
				continue

			var patch_strength := _sample_patch_strength(
				species,
				world_xz
			)

			var patch_factor := lerpf(
				1.0,
				patch_strength,
				species.patchiness
			)

			var suitability_factor := _smoothstep(
				species.minimum_suitability,
				1.0,
				suitability
			)

			var placement_probability := clampf(
				species.base_spawn_probability
					* suitability_factor
					* patch_factor,
				0.0,
				1.0
			)

			if placement_probability <= 0.0:
				continue

			var spawn_roll := _unit_spatial_value(
				FloraChannels.for_species(
					FloraChannels.SPAWN_ROLL_BASE,
					species.species_id
				),
				candidate_cell
			)

			if spawn_roll >= placement_probability:
				continue

			var yaw_roll := _unit_spatial_value(
				FloraChannels.for_species(
					FloraChannels.YAW_ROLL_BASE,
					species.species_id
				),
				candidate_cell
			)

			var stable_id := (
				StableSeed.derive_spatial_seed(
					_flora_seed,
					FloraChannels.for_species(
						FloraChannels.IDENTITY_BASE,
						species.species_id
					),
					candidate_cell
				)
			)

			var surface_normal := _sample_surface_normal(
				terrain_data,
				world_xz
			)

			var world_position := Vector3(
				world_xz.x,
				environment.seabed_elevation,
				world_xz.y
			)

			var instance_scale := 1.0

			if species.species_id != FloraIds.GIANT_KELP:
				var scale_roll := _unit_spatial_value(
					FloraChannels.for_species(
						FloraChannels.SCALE_ROLL_BASE,
						species.species_id
					),
					candidate_cell
				)

				instance_scale = lerpf(
					species.minimum_scale,
					species.maximum_scale,
					scale_roll
				)

			var kelp_depth_factor := 0.0
			var kelp_darkness_factor := 0.0
			var kelp_temperature_factor := 0.0

			if species.species_id == FloraIds.GIANT_KELP:
				kelp_depth_factor = (
					_get_environmental_growth_factor(
						species,
						BiomeEvidenceChannels.DEPTH,
						environment.depth_below_surface,
						false
					)
				)

				kelp_darkness_factor = (
					_get_environmental_growth_factor(
						species,
						BiomeEvidenceChannels.LIGHT,
						environment.light_availability,
						true
					)
				)

				kelp_temperature_factor = clampf(
	(
		kelp_temperature_factor
		- KELP_TEMPERATURE_MIDPOINT
	) * KELP_TEMPERATURE_CONTRAST
		+ 0.5,
	0.0,
	1.0
)

			var candidate := FloraPlacementCandidate.new(
				stable_id,
				species.species_id,
				candidate_cell,
				world_position,
				surface_normal,
				yaw_roll * TAU,
				instance_scale,
				suitability,
				placement_probability,
				patch_strength,
				species.align_to_surface,
				0,
				0.0,
				kelp_depth_factor,
				kelp_darkness_factor,
				0.0,
				0,
				kelp_temperature_factor,
				environment.depth_below_surface
			)

			output.append(candidate)


func _finalize_kelp_morphology(
	candidates: Array[FloraPlacementCandidate],
	world_minimum: Vector2,
	world_maximum: Vector2
) -> void:
	var kelp_candidates: Array[FloraPlacementCandidate] = []

	for candidate in candidates:
		if (
			candidate != null
			and candidate.species_id == FloraIds.GIANT_KELP
		):
			kelp_candidates.append(candidate)

	if kelp_candidates.is_empty():
		return

	var radius_squared := (
		KELP_NEIGHBOR_RADIUS
		* KELP_NEIGHBOR_RADIUS
	)

	for candidate in kelp_candidates:
		var nearby_count := 0

		for neighbor in kelp_candidates:
			if neighbor == candidate:
				continue

			var offset := Vector2(
				neighbor.world_position.x
					- candidate.world_position.x,
				neighbor.world_position.z
					- candidate.world_position.z
			)

			if offset.length_squared() <= radius_squared:
				nearby_count += 1

		## FloraPlacementSampler owns only one terrain chunk. Estimate
		## the missing neighborhood area near an owning-chunk edge rather
		## than pretending unavailable neighboring flora were sampled.
		var coverage := _estimate_neighborhood_coverage(
			Vector2(
				candidate.world_position.x,
				candidate.world_position.z
			),
			world_minimum,
			world_maximum
		)

		var compensated_count := (
			float(nearby_count)
			/ maxf(coverage, 0.20)
		)

		var density_factor := clampf(
			compensated_count
				/ KELP_NEIGHBOR_COUNT_FOR_FULL_DENSITY,
			0.0,
			1.0
		)

		var growth_factor := clampf(
			density_factor * KELP_DENSITY_WEIGHT
				+ candidate.kelp_depth_factor
					* KELP_DEPTH_WEIGHT
				+ candidate.kelp_darkness_factor
					* KELP_DARKNESS_WEIGHT,
			0.0,
			1.0
		)

		var tier := clampi(
			floori(
				growth_factor
				* float(
					FloraPlacementCandidate
						.KELP_MORPHOLOGY_TIER_COUNT
				)
			),
			0,
			FloraPlacementCandidate
				.KELP_MORPHOLOGY_TIER_COUNT - 1
		)

		var maximum_supported_tier := (
			_get_maximum_supported_kelp_tier(
				candidate.kelp_depth_below_surface
			)
		)

		tier = mini(tier, maximum_supported_tier)

		candidate.kelp_nearby_count = nearby_count
		candidate.kelp_density_factor = density_factor
		candidate.kelp_growth_factor = growth_factor
		candidate.kelp_morphology_tier = tier


static func _supports_kelp_tier_zero(
	depth_below_surface: float
) -> bool:
	if not is_finite(depth_below_surface):
		return false

	return (
		_get_kelp_nominal_height(0)
		<= depth_below_surface - KELP_SURFACE_CLEARANCE
	)


static func _get_maximum_supported_kelp_tier(
	depth_below_surface: float
) -> int:
	var maximum_supported_tier := -1
	var available_height := (
		depth_below_surface - KELP_SURFACE_CLEARANCE
	)

	for tier in range(
		FloraPlacementCandidate.KELP_MORPHOLOGY_TIER_COUNT
	):
		if _get_kelp_nominal_height(tier) <= available_height:
			maximum_supported_tier = tier

	return maximum_supported_tier


static func _get_kelp_nominal_height(
	tier: int
) -> float:
	var clamped_tier := clampi(
		tier,
		0,
		FloraPlacementCandidate.KELP_MORPHOLOGY_TIER_COUNT - 1
	)
	var denominator := maxf(
		float(
			FloraPlacementCandidate.KELP_MORPHOLOGY_TIER_COUNT - 1
		),
		1.0
	)
	var size_factor := lerpf(
		KELP_MINIMUM_SIZE_FACTOR,
		KELP_MAXIMUM_SIZE_FACTOR,
		float(clamped_tier) / denominator
	)
	var segment_count := (
		KELP_BASE_SEGMENT_COUNT
		+ clamped_tier * KELP_SEGMENTS_PER_TIER
	)

	return (
		float(segment_count) * KELP_SEGMENT_HEIGHT
		+ 1.20 * size_factor
	)


## Deterministically estimates how much of a kelp neighborhood lies inside
## the supplied owning chunk. This prevents all chunk-edge kelp from being
## treated as automatically isolated.
static func _estimate_neighborhood_coverage(
	center: Vector2,
	world_minimum: Vector2,
	world_maximum: Vector2
) -> float:
	const GRID_RADIUS: int = 3

	var samples_inside_circle := 0
	var samples_inside_chunk := 0

	for sample_z in range(
		-GRID_RADIUS,
		GRID_RADIUS + 1
	):
		for sample_x in range(
			-GRID_RADIUS,
			GRID_RADIUS + 1
		):
			var normalized_offset := Vector2(
				float(sample_x) / float(GRID_RADIUS),
				float(sample_z) / float(GRID_RADIUS)
			)

			if normalized_offset.length_squared() > 1.0:
				continue

			samples_inside_circle += 1

			var sample_position := (
				center
				+ normalized_offset
					* KELP_NEIGHBOR_RADIUS
			)

			if (
				sample_position.x >= world_minimum.x
				and sample_position.y >= world_minimum.y
				and sample_position.x < world_maximum.x
				and sample_position.y < world_maximum.y
			):
				samples_inside_chunk += 1

	if samples_inside_circle <= 0:
		return 1.0

	return clampf(
		float(samples_inside_chunk)
			/ float(samples_inside_circle),
		0.0,
		1.0
	)


func _get_environmental_growth_factor(
	species: FloraSpeciesSnapshot,
	channel_id: int,
	value: float,
	invert_result: bool
) -> float:
	if not is_finite(value):
		return 0.0

	for criterion in species.criteria:
		if criterion.channel_id != channel_id:
			continue

		var factor := _normalize_range(
			criterion.minimum,
			criterion.maximum,
			value
		)

		return 1.0 - factor if invert_result else factor

	var fallback_factor := 0.0

	match channel_id:
		BiomeEvidenceChannels.DEPTH:
			fallback_factor = clampf(
				value / KELP_FALLBACK_MAXIMUM_DEPTH,
				0.0,
				1.0
			)

		BiomeEvidenceChannels.LIGHT:
			fallback_factor = clampf(value, 0.0, 1.0)

		BiomeEvidenceChannels.TEMPERATURE:
			fallback_factor = _normalize_range(
				KELP_FALLBACK_MINIMUM_TEMPERATURE,
				KELP_FALLBACK_MAXIMUM_TEMPERATURE,
				value
			)

		_:
			fallback_factor = 0.0

	return (
		1.0 - fallback_factor
		if invert_result
		else fallback_factor
	)


static func _normalize_range(
	minimum: float,
	maximum: float,
	value: float
) -> float:
	if is_equal_approx(minimum, maximum):
		return 0.5

	return clampf(
		(value - minimum) / (maximum - minimum),
		0.0,
		1.0
	)


func _create_candidate_position(
	species: FloraSpeciesSnapshot,
	candidate_cell: Vector2i
) -> Vector2:
	var spacing := species.candidate_spacing

	var center := Vector2(
		(
			float(candidate_cell.x)
			+ 0.5
		) * spacing,
		(
			float(candidate_cell.y)
			+ 0.5
		) * spacing
	)

	var jitter_x := (
		_unit_spatial_value(
			FloraChannels.for_species(
				FloraChannels.CANDIDATE_JITTER_X_BASE,
				species.species_id
			),
			candidate_cell
		)
		* 2.0
		- 1.0
	)

	var jitter_z := (
		_unit_spatial_value(
			FloraChannels.for_species(
				FloraChannels.CANDIDATE_JITTER_Z_BASE,
				species.species_id
			),
			candidate_cell
		)
		* 2.0
		- 1.0
	)

	var maximum_jitter := (
		spacing
		* species.jitter_fraction
		* 0.5
	)

	return center + Vector2(
		jitter_x * maximum_jitter,
		jitter_z * maximum_jitter
	)


static func _sample_surface_normal(
	terrain_data: TerrainChunkData,
	world_xz: Vector2
) -> Vector3:
	if terrain_data == null:
		return Vector3.UP

	if terrain_data.geology_data == null:
		return Vector3.UP

	var cells_per_axis := terrain_data.cells_per_axis
	var cell_size := terrain_data.cell_size

	if (
		cells_per_axis < 1
		or not is_finite(cell_size)
		or cell_size <= 0.0
	):
		return Vector3.UP

	var samples_per_axis := cells_per_axis + 1
	var required_sample_count := (
		samples_per_axis
		* samples_per_axis
	)

	if terrain_data.height_values.size() < required_sample_count:
		return Vector3.UP

	var world_origin := (
		terrain_data.geology_data.world_origin
	)

	if (
		not is_finite(world_origin.x)
		or not is_finite(world_origin.y)
	):
		return Vector3.UP

	var local_x := world_xz.x - world_origin.x
	var local_z := world_xz.y - world_origin.y

	if not is_finite(local_x) or not is_finite(local_z):
		return Vector3.UP

	var cell_x := clampi(
		floori(local_x / cell_size),
		0,
		cells_per_axis - 1
	)

	var cell_z := clampi(
		floori(local_z / cell_size),
		0,
		cells_per_axis - 1
	)

	var cell_origin_x := float(cell_x) * cell_size
	var cell_origin_z := float(cell_z) * cell_size

	var factor_x := clampf(
		(local_x - cell_origin_x) / cell_size,
		0.0,
		1.0
	)

	var factor_z := clampf(
		(local_z - cell_origin_z) / cell_size,
		0.0,
		1.0
	)

	var top_left_index := (
		cell_z * samples_per_axis
		+ cell_x
	)

	var top_right_index := top_left_index + 1
	var bottom_left_index := (
		top_left_index
		+ samples_per_axis
	)
	var bottom_right_index := bottom_left_index + 1

	var height_top_left := float(
		terrain_data.height_values[top_left_index]
	)
	var height_top_right := float(
		terrain_data.height_values[top_right_index]
	)
	var height_bottom_left := float(
		terrain_data.height_values[bottom_left_index]
	)
	var height_bottom_right := float(
		terrain_data.height_values[bottom_right_index]
	)

	if (
		not is_finite(height_top_left)
		or not is_finite(height_top_right)
		or not is_finite(height_bottom_left)
		or not is_finite(height_bottom_right)
	):
		return Vector3.UP

	var derivative_x := (
		lerpf(
			height_top_right - height_top_left,
			height_bottom_right - height_bottom_left,
			factor_z
		)
		/ cell_size
	)

	var derivative_z := (
		lerpf(
			height_bottom_left - height_top_left,
			height_bottom_right - height_top_right,
			factor_x
		)
		/ cell_size
	)

	var normal := Vector3(
		-derivative_x,
		1.0,
		-derivative_z
	)

	if normal.is_zero_approx():
		return Vector3.UP

	return normal.normalized()


func _sample_patch_strength(
	species: FloraSpeciesSnapshot,
	world_xz: Vector2
) -> float:
	var noise := (
		_patch_noises.get(species.species_id)
		as FastNoiseLite
	)

	if noise == null:
		return 1.0

	var patch_value := clampf(
		noise.get_noise_2d(
			world_xz.x,
			world_xz.y
		) * 0.5 + 0.5,
		0.0,
		1.0
	)

	return _smoothstep(
		0.30,
		0.78,
		patch_value
	)


func _unit_spatial_value(
	channel_id: int,
	coordinate: Vector2i
) -> float:
	var value_seed := StableSeed.derive_spatial_seed(
		_flora_seed,
		channel_id,
		coordinate
	)

	return StableSeed.seed_to_unit_float(
		value_seed
	)


static func _candidate_less_than(
	left: FloraPlacementCandidate,
	right: FloraPlacementCandidate
) -> bool:
	if left.species_id != right.species_id:
		return left.species_id < right.species_id

	if left.candidate_cell.y != right.candidate_cell.y:
		return left.candidate_cell.y < right.candidate_cell.y

	if left.candidate_cell.x != right.candidate_cell.x:
		return left.candidate_cell.x < right.candidate_cell.x

	return left.stable_id < right.stable_id


static func _evaluate_criterion(
	criterion: FloraCriterionSnapshot,
	value: float
) -> float:
	if criterion == null:
		return 0.0

	if not is_finite(value):
		return 0.0

	if (
		value < criterion.minimum
		or value > criterion.maximum
	):
		return 0.0

	if value < criterion.ideal_minimum:
		return _smoothstep(
			criterion.minimum,
			criterion.ideal_minimum,
			value
		)

	if value <= criterion.ideal_maximum:
		return 1.0

	return (
		1.0
		- _smoothstep(
			criterion.ideal_maximum,
			criterion.maximum,
			value
		)
	)


static func _get_evidence_value(
	environment: EnvironmentSample,
	channel_id: int
) -> float:
	match channel_id:
		BiomeEvidenceChannels.DEPTH:
			return environment.depth_below_surface

		BiomeEvidenceChannels.LIGHT:
			return environment.light_availability

		BiomeEvidenceChannels.TEMPERATURE:
			return environment.temperature_celsius

		BiomeEvidenceChannels.NUTRIENTS:
			return environment.nutrient_potential

		BiomeEvidenceChannels.CURRENT_EXPOSURE:
			return environment.current_exposure

		BiomeEvidenceChannels.GEOLOGICAL_STABILITY:
			return environment.geological_stability

		BiomeEvidenceChannels.SLOPE_DEGREES:
			return environment.slope_degrees

		BiomeEvidenceChannels.SLOPE_STRENGTH:
			return environment.slope_strength

		BiomeEvidenceChannels.ROUGHNESS_STRENGTH:
			return environment.roughness_strength

		BiomeEvidenceChannels.ROCK_SUBSTRATE:
			return environment.rock_substrate

		BiomeEvidenceChannels.SAND_SUBSTRATE:
			return environment.sand_substrate

		BiomeEvidenceChannels.SOFT_SEDIMENT_SUBSTRATE:
			return environment.soft_sediment_substrate

		BiomeEvidenceChannels.BIOLOGICAL_POTENTIAL:
			return environment.biological_potential

		BiomeEvidenceChannels.VOLCANIC_POTENTIAL:
			return environment.volcanic_potential

		BiomeEvidenceChannels.SEDIMENT_POTENTIAL:
			return environment.sediment_potential

		BiomeEvidenceChannels.RIDGE_POTENTIAL:
			return environment.ridge_potential

		BiomeEvidenceChannels.TRENCH_POTENTIAL:
			return environment.trench_potential

		BiomeEvidenceChannels.SHALLOW_PROVINCE:
			return environment.shallow_province_influence

		BiomeEvidenceChannels.DEEP_PROVINCE:
			return environment.deep_province_influence

		BiomeEvidenceChannels.ABYSSAL_PROVINCE:
			return environment.abyssal_province_influence

		BiomeEvidenceChannels.PROVINCE_TRANSITION:
			return environment.province_transition_influence

		_:
			return 0.0


static func _smoothstep(
	edge_zero: float,
	edge_one: float,
	value: float
) -> float:
	if is_equal_approx(edge_zero, edge_one):
		return 1.0

	var factor := clampf(
		(value - edge_zero)
			/ (edge_one - edge_zero),
		0.0,
		1.0
	)

	return (
		factor
		* factor
		* (3.0 - 2.0 * factor)
	)
