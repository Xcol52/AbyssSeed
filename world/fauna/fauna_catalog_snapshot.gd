class_name FaunaCatalogSnapshot
extends RefCounted

## Immutable by convention.

var species: Array[FaunaSpeciesSnapshot]

## species_id -> FaunaSpeciesSnapshot
var _species_by_id: Dictionary = {}


func _init(
	new_species: Array[FaunaSpeciesSnapshot]
) -> void:
	species = new_species

	for entry in species:
		if entry != null:
			_species_by_id[entry.species_id] = entry


func get_species(
	species_id: int
) -> FaunaSpeciesSnapshot:
	return (
		_species_by_id.get(species_id)
		as FaunaSpeciesSnapshot
	)


func get_validation_error() -> String:
	if species.size() != FaunaIds.COUNT:
		return (
			"Fauna catalog must contain exactly %d species."
			% FaunaIds.COUNT
		)

	var encountered: Dictionary = {}

	for entry in species:
		if entry == null:
			return "Fauna catalog contains a null species."

		var error := entry.get_validation_error()

		if not error.is_empty():
			return (
				"Invalid fauna species %s: %s"
				% [entry.display_name, error]
			)

		if encountered.has(entry.species_id):
			return (
				"Fauna catalog contains duplicate species ID %d."
				% entry.species_id
			)

		encountered[entry.species_id] = true

	for species_id in range(FaunaIds.COUNT):
		if not encountered.has(species_id):
			return (
				"Fauna catalog is missing species ID %d."
				% species_id
			)

	return ""


static func create_default() -> FaunaCatalogSnapshot:
	var entries: Array[FaunaSpeciesSnapshot] = []

	entries.append(_create_shelf_baitfish())
	entries.append(_create_kelp_grazer())
	entries.append(_create_reef_hunter())
	entries.append(_create_giant_squid())

	return FaunaCatalogSnapshot.new(entries)


static func _create_shelf_baitfish() -> FaunaSpeciesSnapshot:
	var result := FaunaSpeciesSnapshot.new()

	result.species_id = FaunaIds.SHELF_BAITFISH
	result.display_name = FaunaIds.get_display_name(
		result.species_id
	)

	result.presentation_mode = (
		FaunaTypes.PresentationMode.SCHOOL_AGGREGATE
	)
	result.trophic_role = FaunaTypes.TrophicRole.HERBIVORE
	result.model_mode = (
		FaunaTypes.ModelMode.PROCEDURAL_VARIANTS
	)
	result.ownership_mode = (
		FaunaTypes.OwnershipMode.CHUNK_HOME
	)

	result.candidate_spacing = 220.0
	result.jitter_fraction = 0.72
	result.base_spawn_probability = 0.76
	result.minimum_suitability = 0.24
	result.patch_size = 620.0
	result.patchiness = 0.55

	result.minimum_population = 48
	result.maximum_population = 180
	result.maximum_representatives = 96

	result.home_radius = 42.0
	result.minimum_altitude = 8.0
	result.maximum_altitude = 34.0
	result.cruise_speed = 2.1
	result.flee_speed = 5.4
	result.turn_rate = 3.2
	result.threat_distance = 52.0
	result.pursuit_distance = 0.0

	## Half a foot is approximately 0.1524 meters.
	result.body_length = 0.1524
	result.procedural_variant_count = 4

	result.cold_color = Color(0.18,0.34,0.43,1.0)
	result.warm_color = Color(0.55,0.74,0.46,1.0)

	return result

static func _create_giant_squid() -> FaunaSpeciesSnapshot:
	var result: FaunaSpeciesSnapshot = (
		FaunaSpeciesSnapshot.new()
	)

	result.species_id = FaunaIds.GIANT_SQUID
	result.display_name = FaunaIds.get_display_name(
		result.species_id
	)

	result.presentation_mode = (
		FaunaTypes.PresentationMode.INDIVIDUAL
	)

	result.trophic_role = (
		FaunaTypes.TrophicRole.APEX_PREDATOR
	)

	result.model_mode = (
		FaunaTypes.ModelMode.AUTHORED_MESH
	)

	result.ownership_mode = (
		FaunaTypes.OwnershipMode.REGIONAL_HOME
	)

	# The regular chunk sampler does not spawn this species. This
	# spacing remains valid catalog data while regional generation is
	# handled by GiantSquidRegionalSampler.
	result.candidate_spacing = 8192.0
	result.jitter_fraction = 0.60
	result.base_spawn_probability = 0.0
	result.minimum_suitability = 0.82
	result.patch_size = 8192.0
	result.patchiness = 0.0

	result.minimum_population = 1
	result.maximum_population = 1
	result.maximum_representatives = 1

	result.home_radius = 1800.0
	result.minimum_altitude = 35.0
	result.maximum_altitude = 220.0

	result.cruise_speed = 2.8
	result.flee_speed = 6.0
	result.turn_rate = 0.38

	result.threat_distance = 500.0
	result.pursuit_distance = 420.0

	result.body_length = 50.0

	# The squid has one fixed mesh, not per-individual procedural
	# morphology. This stays at one to satisfy the existing snapshot
	# validation contract.
	result.procedural_variant_count = 1

	result.cold_color = Color(
		0.68,
		0.70,
		0.74,
		1.0
	)

	result.warm_color = Color(
		0.93,
		0.88,
		0.86,
		1.0
	)

	return result


static func _create_kelp_grazer() -> FaunaSpeciesSnapshot:
	var result := FaunaSpeciesSnapshot.new()

	result.species_id = FaunaIds.KELP_GRAZER
	result.display_name = FaunaIds.get_display_name(
		result.species_id
	)

	result.presentation_mode = (
		FaunaTypes.PresentationMode.INDIVIDUAL
	)
	result.trophic_role = FaunaTypes.TrophicRole.HERBIVORE
	result.model_mode = (
		FaunaTypes.ModelMode.PROCEDURAL_VARIANTS
	)
	result.ownership_mode = (
		FaunaTypes.OwnershipMode.CHUNK_HOME
	)

	result.candidate_spacing = 135.0
	result.jitter_fraction = 0.65
	result.base_spawn_probability = 0.60
	result.minimum_suitability = 0.28
	result.patch_size = 380.0
	result.patchiness = 0.42

	result.minimum_population = 3
	result.maximum_population = 10
	result.maximum_representatives = 8

	result.home_radius = 27.0
	result.minimum_altitude = 1.5
	result.maximum_altitude = 11.0
	result.cruise_speed = 1.15
	result.flee_speed = 3.7
	result.turn_rate = 2.8
	result.threat_distance = 34.0
	result.pursuit_distance = 0.0

	result.body_length = 0.62
	result.procedural_variant_count = 4

	result.cold_color = Color(0.09,0.29,0.24,1.0)
	result.warm_color = Color(0.48,0.69,0.17,1.0)

	return result


static func _create_reef_hunter() -> FaunaSpeciesSnapshot:
	var result := FaunaSpeciesSnapshot.new()

	result.species_id = FaunaIds.REEF_HUNTER
	result.display_name = FaunaIds.get_display_name(
		result.species_id
	)

	result.presentation_mode = (
		FaunaTypes.PresentationMode.INDIVIDUAL
	)
	result.trophic_role = FaunaTypes.TrophicRole.PREDATOR
	result.model_mode = (
		FaunaTypes.ModelMode.PROCEDURAL_VARIANTS
	)
	result.ownership_mode = (
		FaunaTypes.OwnershipMode.CHUNK_HOME
	)

	result.candidate_spacing = 340.0
	result.jitter_fraction = 0.68
	result.base_spawn_probability = 0.42
	result.minimum_suitability = 0.32
	result.patch_size = 760.0
	result.patchiness = 0.50

	result.minimum_population = 1
	result.maximum_population = 3
	result.maximum_representatives = 3

	result.home_radius = 75.0
	result.minimum_altitude = 4.0
	result.maximum_altitude = 24.0
	result.cruise_speed = 2.4
	result.flee_speed = 4.8
	result.turn_rate = 2.0
	result.threat_distance = 0.0
	result.pursuit_distance = 115.0

	result.body_length = 1.45
	result.procedural_variant_count = 4

	result.cold_color = Color(0.16,0.20,0.25,1.0)
	result.warm_color = Color(0.46,0.39,0.19,1.0)

	return result
