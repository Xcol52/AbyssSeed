extends Node

const EPSILON: float = 0.0001

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	var catalog := FloraCatalogSnapshot.create_default()
	var catalog_error: String = (
		catalog.get_validation_error()
	)

	_expect(
		catalog_error.is_empty(),
		"Default flora catalog validates."
	)

	if not catalog_error.is_empty():
		printerr(catalog_error)
		get_tree().quit(1)
		return

	var biome_catalog := (
		BiomeCatalogSnapshot.create_default()
	)

	var biome_sampler := BiomeSuitabilitySampler.new(
		biome_catalog
	)

	_expect(
		biome_sampler.get_validation_error().is_empty(),
		"Biome sampler validates for flora tests."
	)

	var flora_seed := (
		StableSeed.derive_subsystem_seed(
			1337,
			9,
			WorldSubsystemIds.FLORA
		)
	)

	var flora_sampler := FloraPlacementSampler.new(
		flora_seed,
		catalog
	)

	_expect(
		flora_sampler.get_validation_error().is_empty(),
		"Flora sampler validates."
	)

	_test_catalog_identity(catalog)
	_test_sunlit_rocky_habitat(
		flora_sampler,
		biome_sampler
	)
	_test_sandy_habitat(
		flora_sampler,
		biome_sampler
	)
	_test_low_light_rocky_habitat(
		flora_sampler,
		biome_sampler
	)
	_test_aphotic_habitats(
		flora_sampler,
		biome_sampler
	)
	_test_determinism(
		flora_sampler,
		biome_sampler
	)

	print("")
	print(
		"Session 10 Stage 10A flora tests: "
		+ "%d passed, %d failed"
		% [_passed, _failed]
	)

	get_tree().quit(_failed)


func _test_catalog_identity(
	catalog: FloraCatalogSnapshot
) -> void:
	_expect(
		catalog.species.size() == FloraIds.COUNT,
		"Catalog contains every flora species."
	)

	var expected_names: Array[String] = [
		"Giant kelp",
		"Seagrass",
		"Reef macroalgae",
		"Red fan algae",
		"Coralline algae",
	]

	var identities_valid := true

	for species_id in range(FloraIds.COUNT):
		var entry := catalog.get_species(species_id)

		if (
			entry == null
			or entry.species_id != species_id
			or entry.display_name
				!= expected_names[species_id]
		):
			identities_valid = false
			break

	_expect(
		identities_valid,
		"Flora IDs and display names are stable."
	)

	var every_species_requires_light := true

	for entry in catalog.species:
		var has_light_criterion := false
		var light_minimum := 0.0

		for criterion in entry.criteria:
			if (
				criterion.channel_id
				== BiomeEvidenceChannels.LIGHT
			):
				has_light_criterion = true
				light_minimum = criterion.minimum
				break

		if (
			not has_light_criterion
			or light_minimum <= 0.0
		):
			every_species_requires_light = false
			break

	_expect(
		every_species_requires_light,
		"Every flora species has a positive light requirement."
	)


func _test_sunlit_rocky_habitat(
	flora_sampler: FloraPlacementSampler,
	biome_sampler: BiomeSuitabilitySampler
) -> void:
	var environment := _sample(
		90.0,
		0.34,
		0.60,
		0.45,
		0.78,
		22.0,
		0.70,
		0.72,
		0.18,
		0.10,
		0.05,
		0.0,
		GeologyChunkData.TRENCH_TIER_NONE,
		0.85,
		0.15,
		0.0,
		0.25,
		0.08,
		0.20,
		0.65
	)

	var biomes := biome_sampler.evaluate(environment)

	_expect(
		flora_sampler.evaluate_species(
			FloraIds.GIANT_KELP,
			environment,
			biomes
		) > 0.40,
		"Sunlit rocky shelf supports giant kelp."
	)

	_expect(
		flora_sampler.evaluate_species(
			FloraIds.REEF_MACROALGAE,
			environment,
			biomes
		) > 0.35,
		"Sunlit rocky shelf supports reef macroalgae."
	)

	_expect(
		flora_sampler.evaluate_species(
			FloraIds.CORALLINE_ALGAE,
			environment,
			biomes
		) > 0.35,
		"Stable rock supports coralline algae."
	)


func _test_sandy_habitat(
	flora_sampler: FloraPlacementSampler,
	biome_sampler: BiomeSuitabilitySampler
) -> void:
	var environment := _sample(
		80.0,
		0.40,
		0.55,
		0.25,
		0.90,
		2.0,
		0.08,
		0.08,
		0.84,
		0.08,
		0.0,
		0.0,
		GeologyChunkData.TRENCH_TIER_NONE,
		0.90,
		0.10,
		0.0,
		0.12,
		0.02,
		0.20,
		0.55
	)

	var biomes := biome_sampler.evaluate(environment)

	_expect(
		flora_sampler.evaluate_species(
			FloraIds.SEAGRASS,
			environment,
			biomes
		) > 0.40,
		"Shallow stable sand supports seagrass."
	)

	_expect(
		flora_sampler.evaluate_species(
			FloraIds.REEF_MACROALGAE,
			environment,
			biomes
		) <= EPSILON,
		"Sandy habitat rejects rock-dependent macroalgae."
	)


func _test_low_light_rocky_habitat(
	flora_sampler: FloraPlacementSampler,
	biome_sampler: BiomeSuitabilitySampler
) -> void:
	var environment := _sample(
		350.0,
		0.03,
		0.60,
		0.40,
		0.75,
		20.0,
		0.45,
		0.75,
		0.15,
		0.10,
		0.05,
		0.0,
		GeologyChunkData.TRENCH_TIER_NONE,
		0.15,
		0.65,
		0.20,
		0.55,
		0.15,
		0.25,
		0.50
	)

	var biomes := biome_sampler.evaluate(environment)

	_expect(
		flora_sampler.evaluate_species(
			FloraIds.RED_FAN_ALGAE,
			environment,
			biomes
		) > 0.15,
		"Low-light rocky habitat supports red fan algae."
	)

	_expect(
		flora_sampler.evaluate_species(
			FloraIds.SEAGRASS,
			environment,
			biomes
		) <= EPSILON,
		"Deep low-light rock rejects seagrass."
	)


func _test_aphotic_habitats(
	flora_sampler: FloraPlacementSampler,
	biome_sampler: BiomeSuitabilitySampler
) -> void:
	var hydrothermal_environment := _sample(
		2500.0,
		0.0,
		0.86,
		0.55,
		0.15,
		18.0,
		0.55,
		0.82,
		0.08,
		0.10,
		0.92,
		0.0,
		GeologyChunkData.TRENCH_TIER_NONE,
		0.0,
		0.50,
		0.50,
		0.35,
		0.86,
		0.08,
		0.82
	)

	var hydrothermal_biomes := biome_sampler.evaluate(
		hydrothermal_environment
	)

	_expect(
		_all_flora_rejected(
			flora_sampler,
			hydrothermal_environment,
			hydrothermal_biomes
		),
		"Aphotic hydrothermal habitat contains no flora."
	)

	var abyssal_environment := _sample(
		3000.0,
		0.0,
		0.52,
		0.38,
		0.90,
		2.0,
		0.08,
		0.10,
		0.15,
		0.75,
		0.0,
		0.0,
		GeologyChunkData.TRENCH_TIER_NONE,
		0.0,
		0.10,
		0.90,
		0.12,
		0.02,
		0.82,
		0.32
	)

	var abyssal_biomes := biome_sampler.evaluate(
		abyssal_environment
	)

	_expect(
		_all_flora_rejected(
			flora_sampler,
			abyssal_environment,
			abyssal_biomes
		),
		"Aphotic abyssal habitat contains no flora."
	)


func _test_determinism(
	flora_sampler: FloraPlacementSampler,
	biome_sampler: BiomeSuitabilitySampler
) -> void:
	var environment := _sample(
		90.0,
		0.34,
		0.60,
		0.45,
		0.78,
		22.0,
		0.70,
		0.72,
		0.18,
		0.10,
		0.05,
		0.0,
		GeologyChunkData.TRENCH_TIER_NONE,
		0.85,
		0.15,
		0.0,
		0.25,
		0.08,
		0.20,
		0.65
	)

	var biomes := biome_sampler.evaluate(environment)
	var deterministic := true

	for species_id in range(FloraIds.COUNT):
		var first := flora_sampler.evaluate_species(
			species_id,
			environment,
			biomes
		)

		var second := flora_sampler.evaluate_species(
			species_id,
			environment,
			biomes
		)

		if first != second:
			deterministic = false
			break

	_expect(
		deterministic,
		"Repeated flora suitability is deterministic."
	)


func _all_flora_rejected(
	flora_sampler: FloraPlacementSampler,
	environment: EnvironmentSample,
	biomes: BiomeSuitabilityResult
) -> bool:
	for species_id in range(FloraIds.COUNT):
		var suitability := flora_sampler.evaluate_species(
			species_id,
			environment,
			biomes
		)

		if suitability > EPSILON:
			return false

	return true


func _sample(
	depth: float,
	light: float,
	nutrients: float,
	current: float,
	stability: float,
	slope_degrees: float,
	roughness_strength: float,
	rock: float,
	sand: float,
	soft_sediment: float,
	volcanic: float,
	trench: float,
	trench_tier: int,
	shallow: float,
	deep: float,
	abyssal: float,
	transition: float,
	ridge: float,
	sediment: float,
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
		clampf(slope_degrees / 35.0, 0.0, 1.0),
		roughness_strength * 30.0,
		roughness_strength,
		light,
		4.0,
		1.0 + depth / 10.06,
		nutrients,
		current,
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
	printerr("FAILED: %s" % description)
