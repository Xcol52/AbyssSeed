class_name FloraCatalogSnapshot
extends RefCounted

## Immutable by convention.
var species: Array[FloraSpeciesSnapshot]


func _init(
	new_species: Array[FloraSpeciesSnapshot]
) -> void:
	species = new_species


static func create_default() -> FloraCatalogSnapshot:
	var entries: Array[FloraSpeciesSnapshot] = []

	entries.append(
		FloraSpeciesSnapshot.new(
			FloraIds.GIANT_KELP,
			FloraIds.get_display_name(
				FloraIds.GIANT_KELP
			),
			24.0,
			0.65,
			0.48,
			0.18,
			420.0,
			0.68,
			0.75,
			1.35,
			false,
			_affinities([
				0.90, # Sunlit shelf
				0.85, # Rocky reef
				0.20, # Sandy shelf
				0.05, # Continental slope
				0.00, # Deep rocky slope
				0.00, # Abyssal sediment plain
				0.00, # Hydrothermal field
				0.00, # Trench wall
				0.00, # Trench floor
				0.00, # Extreme-trench refuge
			]),
			[
				_c(
					BiomeEvidenceChannels.DEPTH,
					4.0,
					12.0,
					110.0,
					260.0,
					1.2
				),
				_c(
					BiomeEvidenceChannels.LIGHT,
					0.025,
					0.12,
					1.0,
					1.0,
					1.3
				),
				_c(
					BiomeEvidenceChannels.NUTRIENTS,
					0.08,
					0.28,
					1.0,
					1.0
				),
				_c(
					BiomeEvidenceChannels.ROCK_SUBSTRATE,
					0.08,
					0.25,
					1.0,
					1.0,
					0.75
				),
				_c(
					BiomeEvidenceChannels.SLOPE_DEGREES,
					0.0,
					0.0,
					32.0,
					62.0,
					0.65
				),
				_c(
					BiomeEvidenceChannels.CURRENT_EXPOSURE,
					0.0,
					0.12,
					0.80,
					1.0,
					0.55
				)
			]
		)
	)

	entries.append(
		FloraSpeciesSnapshot.new(
			FloraIds.SEAGRASS,
			FloraIds.get_display_name(
				FloraIds.SEAGRASS
			),
			10.0,
			0.70,
			0.58,
			0.16,
			260.0,
			0.78,
			0.70,
			1.25,
			true,
			_affinities([
				0.85, # Sunlit shelf
				0.15, # Rocky reef
				1.00, # Sandy shelf
				0.00, # Continental slope
				0.00, # Deep rocky slope
				0.00, # Abyssal sediment plain
				0.00, # Hydrothermal field
				0.00, # Trench wall
				0.00, # Trench floor
				0.00, # Extreme-trench refuge
			]),
			[
				_c(
					BiomeEvidenceChannels.DEPTH,
					2.0,
					4.0,
					75.0,
					180.0,
					1.2
				),
				_c(
					BiomeEvidenceChannels.LIGHT,
					0.035,
					0.16,
					1.0,
					1.0,
					1.3
				),
				_c(
					BiomeEvidenceChannels.NUTRIENTS,
					0.06,
					0.22,
					1.0,
					1.0
				),
				_c(
					BiomeEvidenceChannels.SAND_SUBSTRATE,
					0.20,
					0.48,
					1.0,
					1.0,
					1.2
				),
				_c(
					BiomeEvidenceChannels.SLOPE_DEGREES,
					0.0,
					0.0,
					9.0,
					20.0,
					1.1
				),
				_c(
					BiomeEvidenceChannels
						.GEOLOGICAL_STABILITY,
					0.20,
					0.55,
					1.0,
					1.0,
					0.65
				)
			]
		)
	)

	entries.append(
		FloraSpeciesSnapshot.new(
			FloraIds.REEF_MACROALGAE,
			FloraIds.get_display_name(
				FloraIds.REEF_MACROALGAE
			),
			16.0,
			0.58,
			0.42,
			0.18,
			280.0,
			0.62,
			0.60,
			1.50,
			true,
			_affinities([
				0.50, # Sunlit shelf
				1.00, # Rocky reef
				0.05, # Sandy shelf
				0.15, # Continental slope
				0.05, # Deep rocky slope
				0.00, # Abyssal sediment plain
				0.00, # Hydrothermal field
				0.00, # Trench wall
				0.00, # Trench floor
				0.00, # Extreme-trench refuge
			]),
			[
				_c(
					BiomeEvidenceChannels.DEPTH,
					4.0,
					12.0,
					220.0,
					500.0
				),
				_c(
					BiomeEvidenceChannels.LIGHT,
					0.012,
					0.06,
					1.0,
					1.0,
					1.2
				),
				_c(
					BiomeEvidenceChannels.ROCK_SUBSTRATE,
					0.18,
					0.45,
					1.0,
					1.0,
					1.3
				),
				_c(
					BiomeEvidenceChannels.ROUGHNESS_STRENGTH,
					0.02,
					0.12,
					1.0,
					1.0,
					0.75
				),
				_c(
					BiomeEvidenceChannels.NUTRIENTS,
					0.06,
					0.25,
					1.0,
					1.0
				),
				_c(
					BiomeEvidenceChannels
						.BIOLOGICAL_POTENTIAL,
					0.03,
					0.14,
					1.0,
					1.0,
					0.65
				)
			]
		)
	)

	entries.append(
		FloraSpeciesSnapshot.new(
			FloraIds.RED_FAN_ALGAE,
			FloraIds.get_display_name(
				FloraIds.RED_FAN_ALGAE
			),
			14.0,
			0.62,
			0.34,
			0.16,
			220.0,
			0.66,
			0.55,
			1.40,
			true,
			_affinities([
				0.18, # Sunlit shelf
				0.80, # Rocky reef
				0.02, # Sandy shelf
				0.50, # Continental slope
				0.45, # Deep rocky slope
				0.00, # Abyssal sediment plain
				0.00, # Hydrothermal field
				0.04, # Trench wall
				0.00, # Trench floor
				0.00, # Extreme-trench refuge
			]),
			[
				_c(
					BiomeEvidenceChannels.DEPTH,
					20.0,
					60.0,
					420.0,
					900.0,
					1.1
				),
				_c(
					BiomeEvidenceChannels.LIGHT,
					0.002,
					0.012,
					0.20,
					0.50,
					1.4
				),
				_c(
					BiomeEvidenceChannels.ROCK_SUBSTRATE,
					0.20,
					0.48,
					1.0,
					1.0,
					1.3
				),
				_c(
					BiomeEvidenceChannels.CURRENT_EXPOSURE,
					0.0,
					0.0,
					0.70,
					1.0,
					0.55
				),
				_c(
					BiomeEvidenceChannels.NUTRIENTS,
					0.04,
					0.20,
					1.0,
					1.0,
					0.85
				),
				_c(
					BiomeEvidenceChannels.SLOPE_DEGREES,
					1.0,
					4.0,
					48.0,
					76.0,
					0.65
				)
			]
		)
	)

	entries.append(
		FloraSpeciesSnapshot.new(
			FloraIds.CORALLINE_ALGAE,
			FloraIds.get_display_name(
				FloraIds.CORALLINE_ALGAE
			),
			8.0,
			0.55,
			0.52,
			0.15,
			180.0,
			0.50,
			0.50,
			1.40,
			true,
			_affinities([
				0.35, # Sunlit shelf
				1.00, # Rocky reef
				0.05, # Sandy shelf
				0.22, # Continental slope
				0.16, # Deep rocky slope
				0.00, # Abyssal sediment plain
				0.00, # Hydrothermal field
				0.04, # Trench wall
				0.00, # Trench floor
				0.00, # Extreme-trench refuge
			]),
			[
				_c(
					BiomeEvidenceChannels.DEPTH,
					2.0,
					8.0,
					300.0,
					650.0
				),
				_c(
					BiomeEvidenceChannels.LIGHT,
					0.004,
					0.02,
					0.70,
					1.0,
					1.2
				),
				_c(
					BiomeEvidenceChannels.ROCK_SUBSTRATE,
					0.20,
					0.50,
					1.0,
					1.0,
					1.4
				),
				_c(
					BiomeEvidenceChannels
						.GEOLOGICAL_STABILITY,
					0.25,
					0.55,
					1.0,
					1.0,
					0.75
				),
				_c(
					BiomeEvidenceChannels.SLOPE_DEGREES,
					0.0,
					0.0,
					50.0,
					75.0,
					0.55
				),
				_c(
					BiomeEvidenceChannels.ROUGHNESS_STRENGTH,
					0.0,
					0.0,
					0.70,
					1.0,
					0.45
				)
			]
		)
	)

	return FloraCatalogSnapshot.new(entries)


func get_species(
	species_id: int
) -> FloraSpeciesSnapshot:
	for entry in species:
		if entry.species_id == species_id:
			return entry

	return null


func get_validation_error() -> String:
	if species.size() != FloraIds.COUNT:
		return (
			"Flora catalog must contain exactly %d species."
			% FloraIds.COUNT
		)

	var encountered_ids: Dictionary = {}

	for entry in species:
		if entry == null:
			return "Flora catalog contains a null species."

		var entry_error: String = (
			entry.get_validation_error()
		)

		if not entry_error.is_empty():
			return entry_error

		if encountered_ids.has(entry.species_id):
			return (
				"Flora catalog contains duplicate species ID %d."
				% entry.species_id
			)

		encountered_ids[entry.species_id] = true

	for species_id in range(FloraIds.COUNT):
		if not encountered_ids.has(species_id):
			return (
				"Flora catalog is missing species ID %d."
				% species_id
			)

	return ""


static func _affinities(
	values: Array
) -> PackedFloat32Array:
	var packed := PackedFloat32Array()

	for value in values:
		packed.append(float(value))

	return packed


static func _c(
	channel_id: int,
	minimum: float,
	ideal_minimum: float,
	ideal_maximum: float,
	maximum: float,
	weight: float = 1.0
) -> FloraCriterionSnapshot:
	return FloraCriterionSnapshot.new(
		channel_id,
		minimum,
		ideal_minimum,
		ideal_maximum,
		maximum,
		weight
	)
