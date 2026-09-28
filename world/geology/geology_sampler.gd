class_name GeologySampler
extends RefCounted

const MINIMUM_SITE_SEARCH_RADIUS: int = 2
const SURFACE_SOFT_LIMIT_START_FRACTION: float = 0.72
const RELIEF_EPSILON: float = 0.000001

## Geological elevation uses sea level as Y = 0.0.
const ORIGIN_SHELF_INNER_RADIUS: float = 100.0
const ORIGIN_SHELF_OUTER_RADIUS: float = 350.0
const ORIGIN_SHALLOW_ELEVATION: float = -20.0
const ORIGIN_MINIMUM_RELIEF_ATTENUATION: float = 0.15

const BOUNDARY_STRATA_TERRACE_HEIGHT: float = 15.0
const BOUNDARY_STRATA_RISE_START: float = 0.18
const BOUNDARY_STRATA_RISE_END: float = 0.82
const BOUNDARY_STRATA_WEIGHT_MULTIPLIER: float = 1.5

var _snapshot: GeologyGenerationSnapshot
var _site_search_radius: int = MINIMUM_SITE_SEARCH_RADIUS

var _site_cache: Dictionary = {}
var _interior_descriptor_cache: Dictionary = {}
var _convergent_descriptor_cache: Dictionary = {}

var _warp_x_noise: FastNoiseLite
var _warp_z_noise: FastNoiseLite
var _continental_noise: FastNoiseLite
var _basin_noise: FastNoiseLite
var _regional_noise: FastNoiseLite
var _trench_variation_noise: FastNoiseLite

var _depth_province_profile: DepthProvinceProfile


func _init(
	generation_snapshot: GeologyGenerationSnapshot
) -> void:
	assert(generation_snapshot != null)

	_snapshot = generation_snapshot

	_site_cache.clear()
	_interior_descriptor_cache.clear()
	_convergent_descriptor_cache.clear()

	_site_search_radius = _calculate_site_search_radius()

	_warp_x_noise = _create_noise(
		GeologyChannels.WARP_X,
		_snapshot.boundary_warp_frequency
	)

	_warp_z_noise = _create_noise(
		GeologyChannels.WARP_Z,
		_snapshot.boundary_warp_frequency
	)

	_continental_noise = _create_noise(
		GeologyChannels.CONTINENTAL_FIELD,
		_snapshot.continental_field_frequency
	)

	_basin_noise = _create_noise(
		GeologyChannels.BASIN_FIELD,
		_snapshot.basin_field_frequency
	)

	_regional_noise = _create_noise(
		GeologyChannels.REGIONAL_VARIATION,
		_snapshot.regional_variation_frequency
	)

	_trench_variation_noise = _create_noise(
		ConvergentProfile.TRENCH_VARIATION_NOISE_CHANNEL,
		_snapshot
			.convergent_relief
			.depth_variation_frequency
	)

	_depth_province_profile = DepthProvinceProfile.new(
		_snapshot.geology_seed,
		_snapshot.depth_provinces
	)


func generate_chunk(
	chunk_coordinate: Vector2i,
	chunk_size: float,
	cells_per_axis: int
) -> GeologyChunkData:
	if _snapshot == null:
		return null

	if not _snapshot.get_validation_error().is_empty():
		return null

	if (
		not is_finite(chunk_size)
		or chunk_size <= 0.0
		or cells_per_axis < 1
	):
		return null

	var cell_size: float = (
		chunk_size
		/ float(cells_per_axis)
	)

	var world_origin: Vector2 = Vector2(
		float(chunk_coordinate.x) * chunk_size,
		float(chunk_coordinate.y) * chunk_size
	)

	return generate_region(
		world_origin,
		cells_per_axis,
		cell_size,
		chunk_coordinate
	)


func generate_region(
	world_origin: Vector2,
	cells_per_axis: int,
	cell_size: float,
	logical_coordinate: Vector2i = Vector2i.ZERO
) -> GeologyChunkData:
	if _snapshot == null:
		return null

	if not _snapshot.get_validation_error().is_empty():
		return null

	if (
		cells_per_axis < 1
		or not is_finite(cell_size)
		or cell_size <= 0.0
	):
		return null

	var data: GeologyChunkData = GeologyChunkData.new(
		logical_coordinate,
		cells_per_axis,
		cell_size,
		world_origin
	)

	var samples_per_axis: int = cells_per_axis + 1

	data.resize(
		samples_per_axis
		* samples_per_axis
	)

	for local_z in range(samples_per_axis):
		for local_x in range(samples_per_axis):
			var world_xz: Vector2 = (
				world_origin
				+ Vector2(
					float(local_x) * cell_size,
					float(local_z) * cell_size
				)
			)

			var index: int = (
				local_z * samples_per_axis
				+ local_x
			)

			_sample_into(
				data,
				index,
				world_xz
			)

	return data


func _sample_into(
	data: GeologyChunkData,
	index: int,
	world_xz: Vector2
) -> void:
	## The origin shelf is evaluated exclusively from absolute world
	## coordinates. Chunk coordinates, sample indices, and generation
	## order do not affect it.
	var origin_radius: float = sqrt(
		world_xz.x * world_xz.x
		+ world_xz.y * world_xz.y
	)

	var origin_blend_factor: float = _smoothstep(
		ORIGIN_SHELF_INNER_RADIUS,
		ORIGIN_SHELF_OUTER_RADIUS,
		origin_radius
	)

	var origin_relief_attenuation: float = clampf(
		origin_blend_factor
			+ ORIGIN_MINIMUM_RELIEF_ATTENUATION,
		ORIGIN_MINIMUM_RELIEF_ATTENUATION,
		1.0
	)

	var warped_xz: Vector2 = _warp_coordinate(
		world_xz
	)

	var base_cell: Vector2i = Vector2i(
		int(
			floor(
				warped_xz.x
					/ _snapshot.plate_cell_size
			)
		),
		int(
			floor(
				warped_xz.y
					/ _snapshot.plate_cell_size
			)
		)
	)

	var candidate_sites: Array[GeologyPlateSite] = []

	var nearest_site: GeologyPlateSite = null
	var nearest_power_distance: float = INF

	for offset_z in range(
		-_site_search_radius,
		_site_search_radius + 1
	):
		for offset_x in range(
			-_site_search_radius,
			_site_search_radius + 1
		):
			var site_cell: Vector2i = (
				base_cell
				+ Vector2i(
					offset_x,
					offset_z
				)
			)

			var site: GeologyPlateSite = _get_site(
				site_cell
			)

			candidate_sites.append(site)

			var geometric_distance_squared: float = (
				warped_xz.distance_squared_to(
					site.position
				)
			)

			var power_distance: float = (
				geometric_distance_squared
					- site.influence_weight
			)

			var is_better_candidate: bool = (
				nearest_site == null
					or power_distance
						< nearest_power_distance
			)

			if (
				not is_better_candidate
				and power_distance
					== nearest_power_distance
				and site.plate_id
					< nearest_site.plate_id
			):
				is_better_candidate = true

			if is_better_candidate:
				nearest_site = site
				nearest_power_distance = power_distance

	assert(nearest_site != null)

	var neighboring_site: GeologyPlateSite = null
	var estimated_boundary_distance: float = INF

	for site in candidate_sites:
		if site.plate_id == nearest_site.plate_id:
			continue

		var geometric_distance_squared: float = (
			warped_xz.distance_squared_to(
				site.position
			)
		)

		var candidate_power_distance: float = (
			geometric_distance_squared
				- site.influence_weight
		)

		var site_separation: float = (
			nearest_site.position.distance_to(
				site.position
			)
		)

		if site_separation <= RELIEF_EPSILON:
			continue

		var score_difference: float = maxf(
			0.0,
			candidate_power_distance
				- nearest_power_distance
		)

		var candidate_boundary_distance: float = (
			score_difference
				/ (2.0 * site_separation)
		)

		var is_closer_boundary: bool = (
			neighboring_site == null
				or candidate_boundary_distance
					< estimated_boundary_distance
		)

		if (
			not is_closer_boundary
			and candidate_boundary_distance
				== estimated_boundary_distance
			and site.plate_id
				< neighboring_site.plate_id
		):
			is_closer_boundary = true

		if is_closer_boundary:
			neighboring_site = site
			estimated_boundary_distance = (
				candidate_boundary_distance
			)

	assert(neighboring_site != null)

	var boundary_proximity: float = (
		1.0
		- _smoothstep(
			0.0,
			_snapshot.boundary_influence_width,
			estimated_boundary_distance
		)
	)

	var boundary_normal: Vector2 = (
		neighboring_site.position
			- nearest_site.position
	).normalized()

	var boundary_tangent: Vector2 = Vector2(
		-boundary_normal.y,
		boundary_normal.x
	)

	var relative_motion: Vector2 = (
		nearest_site.motion
			- neighboring_site.motion
	)

	var motion_normalization: float = maxf(
		RELIEF_EPSILON,
		_snapshot.maximum_motion * 2.0
	)

	var normal_rate: float = (
		relative_motion.dot(
			boundary_normal
		)
		/ motion_normalization
	)

	var tangent_rate: float = (
		absf(
			relative_motion.dot(
				boundary_tangent
			)
		)
		/ motion_normalization
	)

	var compression_rate: float = clampf(
		maxf(normal_rate, 0.0),
		0.0,
		1.0
	)

	var extension_rate: float = clampf(
		maxf(-normal_rate, 0.0),
		0.0,
		1.0
	)

	var normalized_shear_rate: float = clampf(
		tangent_rate,
		0.0,
		1.0
	)

	var boundary_class: int = (
		DivergentRidgeProfile.classify_boundary(
			normal_rate,
			normalized_shear_rate
		)
	)

	var compression: float = (
		compression_rate
		* boundary_proximity
	)

	var extension: float = (
		extension_rate
		* boundary_proximity
	)

	var shear: float = (
		normalized_shear_rate
		* boundary_proximity
	)

	var neighbor_blend: float = (
		boundary_proximity
		* 0.5
	)

	var continental: float = lerpf(
		nearest_site.continental_affinity,
		neighboring_site.continental_affinity,
		neighbor_blend
	)

	var regional_noise_value: float = (
		_regional_noise.get_noise_2d(
			world_xz.x,
			world_xz.y
		)
	)

	var regional_multiplier: float = clampf(
		1.0
			+ regional_noise_value
				* _snapshot.regional_variation_strength,
		0.25,
		1.75
	)

	## Depth provinces are evaluated before boundary formations because
	## trench eligibility depends on the surrounding ocean depth.
	var base_depth: float = lerpf(
		_snapshot.oceanic_depth,
		_snapshot.continental_depth,
		continental
	)

	var province_influences: Vector4 = (
		_depth_province_profile.sample_influences(
			world_xz
		)
	)

	var shallow_province_influence: float = (
		province_influences.x
	)

	var deep_province_influence: float = (
		province_influences.y
	)

	var abyssal_province_influence: float = (
		province_influences.z
	)

	var province_transition_influence: float = (
		province_influences.w
	)

	var province_target_depth: float = (
		_depth_province_profile
			.calculate_target_depth(
				world_xz,
				base_depth,
				province_influences
			)
	)

	var province_elevation: float = (
		DepthProvinceProfile
			.calculate_elevation_contribution(
				base_depth,
				province_target_depth
			)
	)

	var oceanic_pair: float = (
		(1.0 - nearest_site.continental_affinity)
		* (
			1.0
			- neighboring_site.continental_affinity
		)
	)

	var continental_pair: float = (
		nearest_site.continental_affinity
		* neighboring_site.continental_affinity
	)

	var ridge_influence: float = 0.0
	var rift_influence: float = 0.0
	var divergent_activity: float = 0.0

	if (
		boundary_class
		== GeologyChunkData.BOUNDARY_CLASS_DIVERGENT
	):
		ridge_influence = (
			DivergentRidgeProfile.calculate_influence(
				estimated_boundary_distance,
				_snapshot.ridge_influence_width
			)
		)

		rift_influence = (
			DivergentRidgeProfile.calculate_influence(
				estimated_boundary_distance,
				_snapshot.rift_influence_width
			)
		)

		divergent_activity = (
			DivergentRidgeProfile.calculate_activity(
				extension_rate,
				oceanic_pair,
				regional_multiplier
			)
		)

	var ridge: float = clampf(
		divergent_activity
			* ridge_influence,
		0.0,
		1.0
	)

	var rift: float = clampf(
		divergent_activity
			* rift_influence,
		0.0,
		1.0
	)

	var raw_ridge_elevation: float = (
		DivergentRidgeProfile
			.calculate_ridge_contribution(
				ridge,
				_snapshot.ridge_uplift
			)
		* origin_relief_attenuation
	)

	var rift_elevation: float = (
		DivergentRidgeProfile
			.calculate_rift_contribution(
				rift,
				_snapshot.rift_depth
			)
		* origin_relief_attenuation
	)

	var convergent_influence: float = 0.0
	var convergent_potential: float = 0.0

	var trench_influence: float = 0.0
	var trench: float = 0.0
	var trench_tier: int = (
		GeologyChunkData.TRENCH_TIER_NONE
	)
	var trench_target_depth: float = 0.0

	var overriding_plate_id: int = 0
	var sample_is_overriding: bool = false

	var overriding_uplift_influence: float = 0.0
	var overriding_uplift_potential: float = 0.0

	if (
		boundary_class
		== GeologyChunkData.BOUNDARY_CLASS_CONVERGENT
	):
		var descriptor: ConvergentBoundaryDescriptor = (
			_get_convergent_descriptor(
				nearest_site,
				neighboring_site
			)
		)

		overriding_plate_id = (
			descriptor.overriding_plate_id
		)

		sample_is_overriding = (
			nearest_site.plate_id
			== overriding_plate_id
		)

		var signed_boundary_distance: float = (
			-estimated_boundary_distance
		)

		if sample_is_overriding:
			signed_boundary_distance = (
				estimated_boundary_distance
			)

		var convergence_activity: float = (
			ConvergentProfile
				.calculate_convergence_activity(
					compression_rate
				)
		)

		convergence_activity = clampf(
			convergence_activity
				* clampf(
					regional_multiplier,
					0.80,
					1.20
				),
			0.0,
			1.0
		)

		convergent_influence = (
			ConvergentProfile.calculate_influence(
				estimated_boundary_distance,
				_snapshot
					.convergent_relief
					.influence_width
			)
		)

		convergent_potential = clampf(
			convergence_activity
				* convergent_influence,
			0.0,
			1.0
		)

		var selected_trench_tier: int = (
			descriptor.trench_tier
		)

		var selected_descending_width: float = (
			ConvergentProfile.get_descending_width(
				selected_trench_tier,
				_snapshot.convergent_relief
			)
		)

		var selected_overriding_width: float = (
			ConvergentProfile.get_overriding_width(
				selected_trench_tier,
				_snapshot.convergent_relief
			)
		)

		var selected_floor_fraction: float = (
			ConvergentProfile.get_floor_fraction(
				selected_trench_tier,
				_snapshot.convergent_relief
			)
		)

		trench_influence = (
			ConvergentProfile.calculate_trench_influence(
				signed_boundary_distance,
				selected_descending_width,
				selected_overriding_width,
				selected_floor_fraction
			)
		)

		var subduction_eligibility: float = (
			ConvergentProfile
				.calculate_subduction_eligibility(
					nearest_site.continental_affinity,
					neighboring_site.continental_affinity
				)
		)

		var depth_eligibility: float = (
			ConvergentProfile
				.calculate_depth_eligibility(
					selected_trench_tier,
					province_target_depth,
					deep_province_influence,
					abyssal_province_influence
				)
		)

		## Along a clean plate-pair edge, the next competing boundary is
		## relatively distant. Near a junction, two boundary distances
		## become similar.
		var alternate_boundary_distance: float = INF

		for alternate_site in candidate_sites:
			if (
				alternate_site.plate_id
					== nearest_site.plate_id
				or alternate_site.plate_id
					== neighboring_site.plate_id
			):
				continue

			var alternate_distance_squared: float = (
				warped_xz.distance_squared_to(
					alternate_site.position
				)
			)

			var alternate_power_distance: float = (
				alternate_distance_squared
					- alternate_site.influence_weight
			)

			var alternate_site_separation: float = (
				nearest_site.position.distance_to(
					alternate_site.position
				)
			)

			if (
				alternate_site_separation
				<= RELIEF_EPSILON
			):
				continue

			var alternate_score_difference: float = maxf(
				0.0,
				alternate_power_distance
					- nearest_power_distance
			)

			var candidate_alternate_distance: float = (
				alternate_score_difference
					/ (
						2.0
						* alternate_site_separation
					)
			)

			alternate_boundary_distance = minf(
				alternate_boundary_distance,
				candidate_alternate_distance
			)

		var raw_boundary_corridor_factor: float = 1.0

		if is_finite(alternate_boundary_distance):
			var junction_clearance: float = maxf(
				0.0,
				alternate_boundary_distance
					- estimated_boundary_distance
			)

			var junction_fade_distance: float = maxf(
				1200.0,
				(
					selected_descending_width
					+ selected_overriding_width
				) * 0.30
			)

			raw_boundary_corridor_factor = _smoothstep(
				0.0,
				junction_fade_distance,
				junction_clearance
			)

		var junction_suppression_strength: float = 0.25

		match selected_trench_tier:
			GeologyChunkData.TRENCH_TIER_MAJOR:
				junction_suppression_strength = 0.60

			GeologyChunkData.TRENCH_TIER_EXTREME:
				junction_suppression_strength = 1.0

		var boundary_corridor_factor: float = lerpf(
			1.0,
			raw_boundary_corridor_factor,
			junction_suppression_strength
		)

		trench = clampf(
			convergence_activity
				* trench_influence
				* subduction_eligibility
				* depth_eligibility
				* boundary_corridor_factor,
			0.0,
			1.0
		)

		if (
			selected_trench_tier
				!= GeologyChunkData.TRENCH_TIER_NONE
			and subduction_eligibility
				> RELIEF_EPSILON
			and depth_eligibility
				> RELIEF_EPSILON
		):
			trench_tier = selected_trench_tier

			var variation_value: float = (
				_trench_variation_noise.get_noise_2d(
					warped_xz.x,
					warped_xz.y
				)
			)

			trench_target_depth = (
				ConvergentProfile.calculate_target_depth(
					trench_tier,
					_snapshot.convergent_relief,
					variation_value
				)
			)

		overriding_uplift_influence = (
			ConvergentProfile.calculate_uplift_influence(
				signed_boundary_distance,
				_snapshot
					.convergent_relief
					.uplift_peak_offset,
				_snapshot
					.convergent_relief
					.uplift_width
			)
		)

		var overriding_affinity: float = (
			nearest_site.continental_affinity
		)

		if not sample_is_overriding:
			overriding_affinity = (
				neighboring_site.continental_affinity
			)

		var uplift_geology_factor: float = clampf(
			0.25
				+ overriding_affinity * 0.55
				+ continental_pair * 0.20,
			0.25,
			1.0
		)

		overriding_uplift_potential = clampf(
			convergence_activity
				* overriding_uplift_influence
				* uplift_geology_factor,
			0.0,
			1.0
		)

	var volcanic: float = clampf(
		ridge * 0.90
			+ trench * 0.65,
		0.0,
		1.0
	)

	var stability: float = clampf(
		1.0
		- maxf(
			convergent_potential,
			maxf(
				compression,
				maxf(
					ridge,
					shear
				)
			)
		),
		0.0,
		1.0
	)

	var sediment: float = clampf(
		stability
		* (
			0.35
			+ continental * 0.65
		)
		* (
			1.0
			- volcanic * 0.5
		),
		0.0,
		1.0
	)

	var plate_interior_influence: float = _smoothstep(
		0.0,
		_snapshot
			.interior_relief
			.boundary_fade_width,
		estimated_boundary_distance
	)

	var interior_descriptor: PlateInteriorReliefDescriptor = (
		_get_interior_descriptor(
			nearest_site
		)
	)

	var raw_interior_relief: Vector4 = (
		PlateInteriorReliefProfile.sample(
			interior_descriptor,
			world_xz,
			plate_interior_influence
		)
	)

	var raw_hill_elevation: float = (
		maxf(
			raw_interior_relief.x,
			0.0
		)
		* origin_relief_attenuation
	)

	var raw_terrace_elevation: float = (
		raw_interior_relief.y
		* origin_relief_attenuation
	)

	var raw_massif_elevation: float = (
		maxf(
			raw_interior_relief.z,
			0.0
		)
		* origin_relief_attenuation
	)

	var depression_elevation: float = (
		minf(
			raw_interior_relief.w,
			0.0
		)
		* origin_relief_attenuation
	)

	var basin_variation: float = (
		_basin_noise.get_noise_2d(
			world_xz.x,
			world_xz.y
		)
		* _snapshot.basin_relief_amplitude
		* origin_relief_attenuation
	)

	## Abyssal provinces favor sediment accumulation without assigning
	## a fixed biome or generating sediment-wave geometry.
	sediment = clampf(
		sediment
			* (
				1.0
				- abyssal_province_influence
					* 0.25
			)
			+ abyssal_province_influence
				* 0.25,
		0.0,
		1.0
	)

	var raw_shear_elevation: float = (
		shear
		* regional_noise_value
		* _snapshot.shear_relief
		* origin_relief_attenuation
	)

	var effective_broad_depth: float = maxf(
		_snapshot.trench_depth,
		_snapshot
			.convergent_relief
			.broad_depression_depth
	)

	var convergent_depression_elevation: float = (
		ConvergentProfile
			.calculate_broad_depression_contribution(
				convergent_potential,
				effective_broad_depth
			)
		* origin_relief_attenuation
	)

	var pre_trench_elevation: float = (
		-base_depth
		+ province_elevation
		+ basin_variation
		+ raw_ridge_elevation
		+ rift_elevation
		+ convergent_depression_elevation
		+ raw_hill_elevation
		+ raw_terrace_elevation
		+ raw_massif_elevation
		+ depression_elevation
		+ raw_shear_elevation
	)

	var trench_elevation: float = (
		ConvergentProfile.calculate_trench_contribution(
			pre_trench_elevation,
			trench_target_depth,
			trench
		)
		* origin_relief_attenuation
	)

	var minimum_uplift: float = minf(
		_snapshot.continental_collision_uplift,
		_snapshot
			.convergent_relief
			.maximum_uplift
	)

	var uplift_amplitude: float = lerpf(
		minimum_uplift,
		_snapshot
			.convergent_relief
			.maximum_uplift,
		clampf(
			overriding_uplift_potential,
			0.0,
			1.0
		)
	)

	var raw_overriding_uplift: float = (
		ConvergentProfile.calculate_uplift_contribution(
			overriding_uplift_potential,
			uplift_amplitude
		)
		* origin_relief_attenuation
	)

	var non_positive_height: float = (
		-base_depth
		+ province_elevation
		+ basin_variation
		+ rift_elevation
		+ convergent_depression_elevation
		+ trench_elevation
		+ depression_elevation
		+ minf(
			raw_terrace_elevation,
			0.0
		)
		+ minf(
			raw_shear_elevation,
			0.0
		)
	)

	var raw_positive_relief: float = (
		raw_ridge_elevation
		+ raw_hill_elevation
		+ raw_massif_elevation
		+ maxf(
			raw_terrace_elevation,
			0.0
		)
		+ raw_overriding_uplift
		+ maxf(
			raw_shear_elevation,
			0.0
		)
	)

	var maximum_seabed_elevation: float = (
		-_snapshot.minimum_seabed_depth
	)

	var minimum_seabed_elevation: float = (
		-_snapshot.maximum_seabed_depth
	)

	var surface_headroom_scale: float = (
		_calculate_positive_relief_scale(
			non_positive_height,
			raw_positive_relief,
			maximum_seabed_elevation
		)
	)

	var ridge_elevation: float = (
		raw_ridge_elevation
		* surface_headroom_scale
	)

	var hill_elevation: float = (
		raw_hill_elevation
		* surface_headroom_scale
	)

	var massif_elevation: float = (
		raw_massif_elevation
		* surface_headroom_scale
	)

	var terrace_elevation: float = (
		minf(
			raw_terrace_elevation,
			0.0
		)
		+ maxf(
			raw_terrace_elevation,
			0.0
		)
		* surface_headroom_scale
	)

	var overriding_uplift_elevation: float = (
		raw_overriding_uplift
		* surface_headroom_scale
	)

	var shear_elevation: float = (
		minf(
			raw_shear_elevation,
			0.0
		)
		+ maxf(
			raw_shear_elevation,
			0.0
		)
		* surface_headroom_scale
	)

	var combined_interior_elevation: float = (
		hill_elevation
		+ terrace_elevation
		+ massif_elevation
		+ depression_elevation
	)

	var unrestricted_macro_height: float = (
		-base_depth
		+ province_elevation
		+ basin_variation
		+ ridge_elevation
		+ rift_elevation
		+ convergent_depression_elevation
		+ trench_elevation
		+ overriding_uplift_elevation
		+ shear_elevation
		+ combined_interior_elevation
	)

	## Compression, extension, and shear are continuous boundary fields.
	## Their maximum describes the strongest local tectonic process.
	var tectonic_activity: float = maxf(
		compression,
		maxf(
			extension,
			shear
		)
	)

	## Strata is applied to the assembled tectonic result before the
	## protected origin shelf blend. It can therefore shape distant
	## active cliffs without changing the inner 100-meter shelf.
	unrestricted_macro_height = _apply_boundary_strata(
		unrestricted_macro_height,
		boundary_proximity,
		tectonic_activity,
		world_xz
	)

	## The strata pass never bypasses the authoritative seabed envelope.
	unrestricted_macro_height = clampf(
		unrestricted_macro_height,
		minimum_seabed_elevation,
		maximum_seabed_elevation
	)

	## This is the final origin-shelf override:
	##
	## r <= 100 m: exactly -20 m
	## 100 m < r < 350 m: smooth transition
	## r >= 350 m: unrestricted geology, including boundary strata
	var macro_height: float = lerpf(
		ORIGIN_SHALLOW_ELEVATION,
		unrestricted_macro_height,
		origin_blend_factor
	)

	macro_height = clampf(
		macro_height,
		minimum_seabed_elevation,
		maximum_seabed_elevation
	)

	data.primary_plate_ids[index] = (
		nearest_site.plate_id
	)

	data.neighboring_plate_ids[index] = (
		neighboring_site.plate_id
	)

	data.boundary_classes[index] = boundary_class

	data.continental_affinity[index] = continental
	data.boundary_proximity[index] = boundary_proximity

	data.compression_strength[index] = compression
	data.extension_strength[index] = extension
	data.shear_strength[index] = shear

	data.ridge_influence[index] = ridge_influence
	data.rift_influence[index] = rift_influence

	data.ridge_potential[index] = ridge
	data.rift_potential[index] = rift

	data.ridge_elevation_contribution[index] = (
		ridge_elevation
	)

	data.rift_elevation_contribution[index] = (
		rift_elevation
	)

	data.plate_interior_influence[index] = (
		plate_interior_influence
	)

	data.hill_elevation_contribution[index] = (
		hill_elevation
	)

	data.terrace_elevation_contribution[index] = (
		terrace_elevation
	)

	data.massif_elevation_contribution[index] = (
		massif_elevation
	)

	data.interior_depression_elevation_contribution[
		index
	] = depression_elevation

	data.combined_interior_elevation_contribution[
		index
	] = combined_interior_elevation

	data.surface_headroom_scale[index] = (
		surface_headroom_scale
	)

	data.convergent_influence[index] = (
		convergent_influence
	)

	data.convergent_potential[index] = (
		convergent_potential
	)

	data.convergent_depression_elevation_contribution[
		index
	] = convergent_depression_elevation

	data.trench_influence[index] = trench_influence
	data.trench_potential[index] = trench
	data.trench_tiers[index] = trench_tier

	data.trench_target_depth[index] = (
		trench_target_depth
	)

	data.trench_elevation_contribution[index] = (
		trench_elevation
	)

	data.overriding_plate_ids[index] = (
		overriding_plate_id
	)

	if sample_is_overriding:
		data.sample_is_on_overriding_plate[index] = 1
	else:
		data.sample_is_on_overriding_plate[index] = 0

	data.overriding_uplift_influence[index] = (
		overriding_uplift_influence
	)

	data.overriding_uplift_potential[index] = (
		overriding_uplift_potential
	)

	data.overriding_uplift_elevation_contribution[
		index
	] = overriding_uplift_elevation

	data.shallow_province_influence[index] = (
		shallow_province_influence
	)

	data.deep_province_influence[index] = (
		deep_province_influence
	)

	data.abyssal_province_influence[index] = (
		abyssal_province_influence
	)

	data.province_transition_influence[index] = (
		province_transition_influence
	)

	data.province_target_depth[index] = (
		province_target_depth
	)

	data.province_elevation_contribution[index] = (
		province_elevation
	)

	data.volcanic_potential[index] = volcanic
	data.sediment_potential[index] = sediment
	data.macro_elevation[index] = macro_height


func _get_convergent_descriptor(
	first_site: GeologyPlateSite,
	second_site: GeologyPlateSite
) -> ConvergentBoundaryDescriptor:
	var lower_plate_id: int = first_site.plate_id
	var higher_plate_id: int = second_site.plate_id

	if lower_plate_id > higher_plate_id:
		lower_plate_id = second_site.plate_id
		higher_plate_id = first_site.plate_id

	var by_higher_id: Dictionary = {}

	if _convergent_descriptor_cache.has(
		lower_plate_id
	):
		var stored_map: Variant = (
			_convergent_descriptor_cache.get(
				lower_plate_id
			)
		)

		if stored_map is Dictionary:
			by_higher_id = stored_map

	if by_higher_id.has(higher_plate_id):
		var cached_descriptor: ConvergentBoundaryDescriptor = (
			by_higher_id.get(higher_plate_id)
				as ConvergentBoundaryDescriptor
		)

		if cached_descriptor != null:
			return cached_descriptor

	var descriptor: ConvergentBoundaryDescriptor = (
		ConvergentProfile.create_descriptor(
			_snapshot.geology_seed,
			first_site,
			second_site,
			_snapshot.convergent_relief
		)
	)

	by_higher_id[higher_plate_id] = descriptor

	_convergent_descriptor_cache[
		lower_plate_id
	] = by_higher_id

	return descriptor


func _get_interior_descriptor(
	plate_site: GeologyPlateSite
) -> PlateInteriorReliefDescriptor:
	if _interior_descriptor_cache.has(
		plate_site.plate_id
	):
		var cached_descriptor: PlateInteriorReliefDescriptor = (
			_interior_descriptor_cache.get(
				plate_site.plate_id
			)
				as PlateInteriorReliefDescriptor
		)

		if cached_descriptor != null:
			return cached_descriptor

	var descriptor: PlateInteriorReliefDescriptor = (
		PlateInteriorReliefProfile.create_descriptor(
			_snapshot.geology_seed,
			plate_site,
			_snapshot.plate_cell_size,
			_snapshot.interior_relief
		)
	)

	_interior_descriptor_cache[
		plate_site.plate_id
	] = descriptor

	return descriptor


func _get_site(
	cell_coordinate: Vector2i
) -> GeologyPlateSite:
	if _site_cache.has(cell_coordinate):
		var cached_site: GeologyPlateSite = (
			_site_cache.get(cell_coordinate)
				as GeologyPlateSite
		)

		if cached_site != null:
			return cached_site

	var jitter_x: float = _unit_spatial_value(
		GeologyChannels.SITE_JITTER_X,
		cell_coordinate
	)

	var jitter_z: float = _unit_spatial_value(
		GeologyChannels.SITE_JITTER_Z,
		cell_coordinate
	)

	var jitter_extent: float = (
		_snapshot.plate_cell_size
		* _snapshot.plate_site_jitter
		* 0.5
	)

	var cell_center: Vector2 = Vector2(
		(
			float(cell_coordinate.x)
			+ 0.5
		) * _snapshot.plate_cell_size,
		(
			float(cell_coordinate.y)
			+ 0.5
		) * _snapshot.plate_cell_size
	)

	var site_position: Vector2 = (
		cell_center
		+ Vector2(
			(jitter_x * 2.0 - 1.0)
				* jitter_extent,
			(jitter_z * 2.0 - 1.0)
				* jitter_extent
		)
	)

	var motion_angle: float = (
		_unit_spatial_value(
			GeologyChannels.MOTION_ANGLE,
			cell_coordinate
		)
		* TAU
	)

	var motion_magnitude: float = lerpf(
		_snapshot.minimum_motion,
		_snapshot.maximum_motion,
		_unit_spatial_value(
			GeologyChannels.MOTION_MAGNITUDE,
			cell_coordinate
		)
	)

	var motion: Vector2 = (
		Vector2(
			cos(motion_angle),
			sin(motion_angle)
		)
		* motion_magnitude
	)

	var continuous_continental_signal: float = (
		_continental_noise.get_noise_2d(
			site_position.x,
			site_position.y
		)
		* 0.5
		+ 0.5
	)

	var local_plate_variation: float = (
		_unit_spatial_value(
			GeologyChannels.PLATE_VARIATION,
			cell_coordinate
		)
	)

	var combined_continental_signal: float = clampf(
		continuous_continental_signal * 0.85
			+ local_plate_variation * 0.15,
		0.0,
		1.0
	)

	var site_continental_affinity: float = _smoothstep(
		0.38,
		0.62,
		combined_continental_signal
	)

	var size_signal: float = _unit_spatial_value(
		GeologyChannels.SITE_SIZE_WEIGHT,
		cell_coordinate
	)

	var signed_size_signal: float = (
		size_signal * 2.0
		- 1.0
	)

	var influence_weight: float = (
		signed_size_signal
		* _snapshot.plate_size_variation
		* _snapshot.plate_cell_size
		* _snapshot.plate_cell_size
	)

	var plate_id: int = _plate_id_from_cell(
		cell_coordinate
	)

	var site: GeologyPlateSite = GeologyPlateSite.new(
		cell_coordinate,
		plate_id,
		site_position,
		motion,
		site_continental_affinity,
		influence_weight
	)

	_site_cache[cell_coordinate] = site
	return site


func _calculate_site_search_radius() -> int:
	var maximum_axis_reach: float = (
		0.5
		+ _snapshot.plate_site_jitter
			* 0.5
	)

	var guaranteed_distance_squared: float = (
		2.0
		* maximum_axis_reach
		* maximum_axis_reach
	)

	var required_excluded_separation: float = sqrt(
		guaranteed_distance_squared
		+ 2.0
			* _snapshot.plate_size_variation
	)

	var radius_threshold: float = (
		required_excluded_separation
		- 0.5
		+ _snapshot.plate_site_jitter
			* 0.5
	)

	return maxi(
		MINIMUM_SITE_SEARCH_RADIUS,
		int(floor(radius_threshold)) + 1
	)


func _warp_coordinate(
	world_xz: Vector2
) -> Vector2:
	if _snapshot.boundary_warp_amplitude <= 0.0:
		return world_xz

	return (
		world_xz
		+ Vector2(
			_warp_x_noise.get_noise_2d(
				world_xz.x,
				world_xz.y
			),
			_warp_z_noise.get_noise_2d(
				world_xz.x,
				world_xz.y
			)
		) * _snapshot.boundary_warp_amplitude
	)


func _create_noise(
	channel_id: int,
	frequency: float
) -> FastNoiseLite:
	var noise: FastNoiseLite = FastNoiseLite.new()

	noise.seed = StableSeed.derive_channel_seed(
		_snapshot.geology_seed,
		channel_id
	)

	noise.frequency = frequency
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_type = FastNoiseLite.FRACTAL_NONE

	return noise


func _unit_spatial_value(
	channel_id: int,
	coordinate: Vector2i
) -> float:
	var value_seed: int = StableSeed.derive_spatial_seed(
		_snapshot.geology_seed,
		channel_id,
		coordinate
	)

	return StableSeed.seed_to_unit_float(
		value_seed
	)


static func _apply_boundary_strata(
	raw_elevation: float,
	boundary_proximity: float,
	tectonic_activity: float,
	world_xz: Vector2
) -> float:
	if not is_finite(raw_elevation):
		return raw_elevation

	## World coordinates are part of the stable helper contract. The
	## current terrace datum is globally aligned and does not perturb
	## its height by position.
	if (
		not is_finite(world_xz.x)
		or not is_finite(world_xz.y)
	):
		return raw_elevation

	if (
		not is_finite(boundary_proximity)
		or not is_finite(tectonic_activity)
	):
		return raw_elevation

	var normalized_boundary_proximity: float = clampf(
		boundary_proximity,
		0.0,
		1.0
	)

	var normalized_tectonic_activity: float = clampf(
		tectonic_activity,
		0.0,
		1.0
	)

	var cliff_weight: float = clampf(
		normalized_boundary_proximity
			* normalized_tectonic_activity
			* BOUNDARY_STRATA_WEIGHT_MULTIPLIER,
		0.0,
		1.0
	)

	if cliff_weight <= RELIEF_EPSILON:
		return raw_elevation

	var terrace_division: float = (
		raw_elevation
		/ BOUNDARY_STRATA_TERRACE_HEIGHT
	)

	## floor() is required because seabed elevations are normally
	## negative. Integer truncation would select the wrong interval.
	var terrace_index: float = floor(
		terrace_division
	)

	var fractional_height: float = clampf(
		terrace_division
			- terrace_index,
		0.0,
		1.0
	)

	var stepped_elevation: float = (
		terrace_index
		* BOUNDARY_STRATA_TERRACE_HEIGHT
	)

	var rounded_fraction: float = _smoothstep(
		BOUNDARY_STRATA_RISE_START,
		BOUNDARY_STRATA_RISE_END,
		fractional_height
	)

	var strata_elevation: float = (
		stepped_elevation
		+ rounded_fraction
			* BOUNDARY_STRATA_TERRACE_HEIGHT
	)

	return lerpf(
		raw_elevation,
		strata_elevation,
		cliff_weight
	)


static func _calculate_positive_relief_scale(
	non_positive_height: float,
	raw_positive_relief: float,
	maximum_seabed_elevation: float
) -> float:
	if raw_positive_relief <= RELIEF_EPSILON:
		return 1.0

	var available_headroom: float = (
		maximum_seabed_elevation
		- non_positive_height
	)

	if available_headroom <= RELIEF_EPSILON:
		return 0.0

	var linear_limit: float = (
		available_headroom
		* SURFACE_SOFT_LIMIT_START_FRACTION
	)

	if raw_positive_relief <= linear_limit:
		return 1.0

	var soft_range: float = maxf(
		available_headroom - linear_limit,
		RELIEF_EPSILON
	)

	var excess_relief: float = (
		raw_positive_relief
		- linear_limit
	)

	var applied_relief: float = (
		linear_limit
		+ soft_range
		* (
			1.0
			- exp(
				-excess_relief
				/ soft_range
			)
		)
	)

	return clampf(
		applied_relief
			/ raw_positive_relief,
		0.0,
		1.0
	)


static func _plate_id_from_cell(
	cell_coordinate: Vector2i
) -> int:
	return (
		(int(cell_coordinate.x) << 32)
		| (
			int(cell_coordinate.y)
			& 0xFFFFFFFF
		)
	)


static func _smoothstep(
	edge_zero: float,
	edge_one: float,
	value: float
) -> float:
	if is_equal_approx(edge_zero, edge_one):
		return 0.0

	var factor: float = clampf(
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
