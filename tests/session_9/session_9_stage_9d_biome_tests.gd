extends Node

const EPSILON: float = 0.0001

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	var catalog := BiomeCatalogSnapshot.create_default()
	var catalog_error := catalog.get_validation_error()

	_expect(
		catalog_error.is_empty(),
		"Default biome catalog validates."
	)

	if not catalog_error.is_empty():
		push_error(catalog_error)
		get_tree().quit(1)
		return

	var sampler := BiomeSuitabilitySampler.new(
		catalog
	)

	_test_sunlit_overlap(sampler)
	_test_sandy_shelf(sampler)
	_test_abyssal_plain(sampler)
	_test_hydrothermal_field(sampler)
	_test_trench_tier_restrictions(sampler)
	_test_extreme_refuge(sampler)
	_test_determinism_and_ranges(sampler)

	print("")
	print(
		"Session 9 Stage 9D biome tests: "
		+ "%d passed, %d failed"
		% [_passed, _failed]
	)

	get_tree().quit(_failed)


func _test_sunlit_overlap(
	sampler: BiomeSuitabilitySampler
) -> void:
	var sample := _sample(
		90.0,
		0.34,
		0.60,
		0.78,
		22.0,
		0.65,
		0.70,
		0.15,
		0.25,
		0.20,
		0.0,
		GeologyChunkData.TRENCH_TIER_NONE,
		0.85,
		0.15,
		0.0,
		0.25,
		0.72,
		0.18,
		0.10,
		0.65
	)

	var result := sampler.evaluate(sample)

	_expect(
		result != null,
		"Sunlit shelf sample can be evaluated."
	)

	if result == null:
		return

	_expect(
		result.get_weight(BiomeIds.SUNLIT_SHELF) > 0.50,
		"Sunlit shelf has strong suitability."
	)

	_expect(
		result.get_weight(BiomeIds.ROCKY_REEF) > 0.50,
		"Rocky reef overlaps a suitable sunlit shelf."
	)

	_expect(
		result.total_suitability > 1.0,
		"Biome weights overlap instead of summing to one."
	)


func _test_sandy_shelf(
	sampler: BiomeSuitabilitySampler
) -> void:
	var sample := _sample(
		110.0,
		0.27,
		0.55,
		0.90,
		2.0,
		0.05,
		0.08,
		0.05,
		0.75,
		0.02,
		0.0,
		GeologyChunkData.TRENCH_TIER_NONE,
		0.90,
		0.10,
		0.0,
		0.12,
		0.10,
		0.82,
		0.08,
		0.50
	)

	var result := sampler.evaluate(sample)

	_expect(
		result != null
			and result.get_weight(
				BiomeIds.SANDY_SHELF
			) > 0.70,
		"Flat sandy shelf produces strong sandy suitability."
	)


func _test_abyssal_plain(
	sampler: BiomeSuitabilitySampler
) -> void:
	var sample := _sample(
		3000.0,
		0.0,
		0.48,
		0.85,
		3.0,
		0.08,
		0.10,
		0.03,
		0.82,
		0.02,
		0.0,
		GeologyChunkData.TRENCH_TIER_NONE,
		0.0,
		0.15,
		0.85,
		0.10,
		0.10,
		0.15,
		0.75,
		0.30
	)

	var result := sampler.evaluate(sample)

	_expect(
		result != null
			and result.get_weight(
				BiomeIds.ABYSSAL_SEDIMENT_PLAIN
			) > 0.70,
		"A stable, flat abyssal sediment area is suitable."
	)


func _test_hydrothermal_field(
	sampler: BiomeSuitabilitySampler
) -> void:
	var sample := _sample(
		2400.0,
		0.0,
		0.88,
		0.15,
		18.0,
		0.48,
		0.75,
		0.92,
		0.10,
		0.82,
		0.0,
		GeologyChunkData.TRENCH_TIER_NONE,
		0.0,
		0.50,
		0.50,
		0.35,
		0.86,
		0.06,
		0.08,
		0.82
	)

	var result := sampler.evaluate(sample)

	_expect(
		result != null
			and result.get_weight(
				BiomeIds.HYDROTHERMAL_FIELD
			) > 0.75,
		"Volcanic rock with nutrients supports vents."
	)

	if result != null:
		_expect(
			result.dominant_biome_id
				== BiomeIds.HYDROTHERMAL_FIELD,
			"Hydrothermal field wins dominant debug selection."
		)


func _test_trench_tier_restrictions(
	sampler: BiomeSuitabilitySampler
) -> void:
	var non_trench := _sample(
		5800.0,
		0.0,
		0.50,
		0.40,
		5.0,
		0.15,
		0.20,
		0.10,
		0.20,
		0.05,
		1.0,
		GeologyChunkData.TRENCH_TIER_NONE,
		0.0,
		0.0,
		1.0,
		0.05,
		0.55,
		0.10,
		0.35,
		0.45
	)

	var result := sampler.evaluate(non_trench)

	_expect(
		result != null
			and result.get_weight(
				BiomeIds.TRENCH_FLOOR
			) <= EPSILON,
		"Trench-floor biome rejects non-trench terrain."
	)

	_expect(
		result != null
			and result.get_weight(
				BiomeIds.EXTREME_TRENCH_REFUGE
			) <= EPSILON,
		"Extreme refuge rejects non-extreme terrain."
	)


func _test_extreme_refuge(
	sampler: BiomeSuitabilitySampler
) -> void:
	var sample := _sample(
		5900.0,
		0.0,
		0.58,
		0.35,
		6.0,
		0.15,
		0.22,
		0.25,
		0.20,
		0.10,
		0.95,
		GeologyChunkData.TRENCH_TIER_EXTREME,
		0.0,
		0.0,
		1.0,
		0.08,
		0.55,
		0.10,
		0.35,
		0.48
	)

	var result := sampler.evaluate(sample)

	_expect(
		result != null
			and result.get_weight(
				BiomeIds.EXTREME_TRENCH_REFUGE
			) > 0.75,
		"Extreme trench floor supports refuge suitability."
	)

	if result != null:
		_expect(
			result.dominant_biome_id
				== BiomeIds.EXTREME_TRENCH_REFUGE,
			"Extreme refuge wins dominant debug selection."
		)


func _test_determinism_and_ranges(
	sampler: BiomeSuitabilitySampler
) -> void:
	var sample := _sample(
		900.0,
		0.01,
		0.42,
		0.60,
		20.0,
		0.55,
		0.50,
		0.12,
		0.35,
		0.08,
		0.0,
		GeologyChunkData.TRENCH_TIER_NONE,
		0.05,
		0.85,
		0.10,
		0.60,
		0.65,
		0.20,
		0.15,
		0.38
	)

	var first := sampler.evaluate(sample)
	var second := sampler.evaluate(sample)

	_expect(
		first != null and second != null,
		"Repeated biome evaluation returns results."
	)

	if first == null or second == null:
		return

	var all_valid := true
	var all_equal := true

	for biome_id in range(BiomeIds.COUNT):
		var first_weight := first.get_weight(biome_id)
		var second_weight := second.get_weight(biome_id)

		if first_weight < 0.0 or first_weight > 1.0:
			all_valid = false

		if first_weight != second_weight:
			all_equal = false

	_expect(
		all_valid,
		"Every raw biome suitability is normalized."
	)

	_expect(
		all_equal,
		"Biome suitability evaluation is deterministic."
	)


func _sample(
	depth: float,
	light: float,
	nutrients: float,
	stability: float,
	slope_degrees: float,
	slope_strength: float,
	roughness_strength: float,
	volcanic: float,
	sediment: float,
	ridge: float,
	trench: float,
	trench_tier: int,
	shallow: float,
	deep: float,
	abyssal: float,
	transition: float,
	rock: float,
	sand: float,
	soft_sediment: float,
	biological: float
) -> EnvironmentSample:
	var seabed_elevation := -depth

	return EnvironmentSample.new(
		Vector2(100.0, 200.0),
		seabed_elevation,
		depth,
		seabed_elevation,
		0.0,
		slope_degrees,
		slope_strength,
		roughness_strength * 30.0,
		roughness_strength,
		light,
		4.0,
		1.0 + depth / 10.06,
		nutrients,
		0.50,
		stability,
		volcanic,
		sediment,
		ridge,
		trench,
		trench_tier,
		0.10,
		0.10,
		0.10,
		shallow,
		deep,
		abyssal,
		transition,
		rock,
		sand,
		soft_sediment,
		biological
	)


func _expect(
	condition: bool,
	description: String
) -> void:
	if condition:
		_passed += 1
		return

	_failed += 1
	push_error("FAILED: %s" % description)
