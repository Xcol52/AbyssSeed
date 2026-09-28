class_name BiomeSuitabilitySampler
extends RefCounted

const SUITABILITY_EPSILON: float = 0.000001

var _catalog: BiomeCatalogSnapshot
var _validation_error: String = ""


func _init(
	catalog_snapshot: BiomeCatalogSnapshot
) -> void:
	assert(catalog_snapshot != null)

	_catalog = catalog_snapshot
	_validation_error = _catalog.get_validation_error()


func get_validation_error() -> String:
	return _validation_error


func evaluate(
	environment: EnvironmentSample
) -> BiomeSuitabilityResult:
	if environment == null:
		return null

	if _catalog == null:
		return null

	if not _validation_error.is_empty():
		return null

	var weights := PackedFloat32Array()
	weights.resize(BiomeIds.COUNT)

	var dominant_biome_id := -1
	var dominant_suitability := 0.0
	var dominant_score := -INF

	var total_suitability := 0.0

	for profile in _catalog.profiles:
		var suitability := _evaluate_profile(
			profile,
			environment
		)

		weights[profile.biome_id] = suitability
		total_suitability += suitability

		var dominance_score := (
			suitability
			* profile.dominance_bias
		)

		var should_select := (
			dominant_biome_id < 0
			or dominance_score > dominant_score
		)

		if (
			not should_select
			and is_equal_approx(
				dominance_score,
				dominant_score
			)
			and profile.biome_id < dominant_biome_id
		):
			should_select = true

		if should_select:
			dominant_biome_id = profile.biome_id
			dominant_suitability = suitability
			dominant_score = dominance_score

	return BiomeSuitabilityResult.new(
		weights,
		dominant_biome_id,
		dominant_suitability,
		total_suitability
	)


func _evaluate_profile(
	profile: BiomeProfileSnapshot,
	environment: EnvironmentSample
) -> float:
	if profile.minimum_trench_tier >= 0:
		if (
			environment.trench_tier
			< profile.minimum_trench_tier
			or environment.trench_tier
			> profile.maximum_trench_tier
		):
			return 0.0

	var weighted_log_sum := 0.0
	var total_weight := 0.0

	for criterion in profile.criteria:
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


static func _evaluate_criterion(
	criterion: BiomeCriterionSnapshot,
	value: float
) -> float:
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
