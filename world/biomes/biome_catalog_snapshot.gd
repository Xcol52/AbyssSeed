class_name BiomeCatalogSnapshot
extends RefCounted

## Immutable by convention.
var profiles: Array[BiomeProfileSnapshot]


func _init(
	new_profiles: Array[BiomeProfileSnapshot]
) -> void:
	profiles = new_profiles


static func create_default() -> BiomeCatalogSnapshot:
	var default_profiles: Array[BiomeProfileSnapshot] = []

	default_profiles.append(
		BiomeProfileSnapshot.new(
			BiomeIds.SUNLIT_SHELF,
			BiomeIds.get_display_name(
				BiomeIds.SUNLIT_SHELF
			),
			[
				_c(
					BiomeEvidenceChannels.DEPTH,
					2.0,
					2.0,
					100.0,
					320.0,
					1.2
				),
				_c(
					BiomeEvidenceChannels.LIGHT,
					0.025,
					0.12,
					1.0,
					1.0,
					1.0
				),
				_c(
					BiomeEvidenceChannels.SHALLOW_PROVINCE,
					0.15,
					0.55,
					1.0,
					1.0,
					1.0
				),
				_c(
					BiomeEvidenceChannels
						.GEOLOGICAL_STABILITY,
					0.15,
					0.50,
					1.0,
					1.0,
					0.65
				),
				_c(
					BiomeEvidenceChannels
						.BIOLOGICAL_POTENTIAL,
					0.025,
					0.15,
					1.0,
					1.0,
					0.70
				)
			]
		)
	)

	default_profiles.append(
		BiomeProfileSnapshot.new(
			BiomeIds.ROCKY_REEF,
			BiomeIds.get_display_name(
				BiomeIds.ROCKY_REEF
			),
			[
				_c(
					BiomeEvidenceChannels.DEPTH,
					5.0,
					15.0,
					180.0,
					500.0
				),
				_c(
					BiomeEvidenceChannels.LIGHT,
					0.01,
					0.07,
					1.0,
					1.0
				),
				_c(
					BiomeEvidenceChannels.ROCK_SUBSTRATE,
					0.20,
					0.50,
					1.0,
					1.0,
					1.2
				),
				_c(
					BiomeEvidenceChannels.SLOPE_DEGREES,
					2.0,
					8.0,
					38.0,
					70.0
				),
				_c(
					BiomeEvidenceChannels.ROUGHNESS_STRENGTH,
					0.04,
					0.18,
					1.0,
					1.0
				),
				_c(
					BiomeEvidenceChannels
						.BIOLOGICAL_POTENTIAL,
					0.04,
					0.18,
					1.0,
					1.0,
					0.75
				)
			],
			1.03
		)
	)

	default_profiles.append(
		BiomeProfileSnapshot.new(
			BiomeIds.SANDY_SHELF,
			BiomeIds.get_display_name(
				BiomeIds.SANDY_SHELF
			),
			[
				_c(
					BiomeEvidenceChannels.DEPTH,
					5.0,
					15.0,
					220.0,
					550.0
				),
				_c(
					BiomeEvidenceChannels.SHALLOW_PROVINCE,
					0.15,
					0.50,
					1.0,
					1.0
				),
				_c(
					BiomeEvidenceChannels.SAND_SUBSTRATE,
					0.20,
					0.50,
					1.0,
					1.0,
					1.3
				),
				_c(
					BiomeEvidenceChannels.SLOPE_DEGREES,
					0.0,
					0.0,
					8.0,
					22.0
				),
				_c(
					BiomeEvidenceChannels.ROUGHNESS_STRENGTH,
					0.0,
					0.0,
					0.30,
					0.70
				),
				_c(
					BiomeEvidenceChannels
						.GEOLOGICAL_STABILITY,
					0.20,
					0.55,
					1.0,
					1.0,
					0.70
				)
			],
			1.02
		)
	)

	default_profiles.append(
		BiomeProfileSnapshot.new(
			BiomeIds.CONTINENTAL_SLOPE,
			BiomeIds.get_display_name(
				BiomeIds.CONTINENTAL_SLOPE
			),
			[
				_c(
					BiomeEvidenceChannels.DEPTH,
					140.0,
					350.0,
					1700.0,
					2700.0,
					1.2
				),
				_c(
					BiomeEvidenceChannels.DEEP_PROVINCE,
					0.025,
					0.20,
					1.0,
					1.0
				),
				_c(
					BiomeEvidenceChannels.SLOPE_DEGREES,
					3.0,
					9.0,
					45.0,
					78.0,
					1.2
				),
				_c(
					BiomeEvidenceChannels.ROCK_SUBSTRATE,
					0.10,
					0.30,
					1.0,
					1.0
				),
				_c(
					BiomeEvidenceChannels.PROVINCE_TRANSITION,
					0.01,
					0.12,
					1.0,
					1.0,
					0.65
				)
			]
		)
	)

	default_profiles.append(
		BiomeProfileSnapshot.new(
			BiomeIds.DEEP_ROCKY_SLOPE,
			BiomeIds.get_display_name(
				BiomeIds.DEEP_ROCKY_SLOPE
			),
			[
				_c(
					BiomeEvidenceChannels.DEPTH,
					750.0,
					1250.0,
					3500.0,
					4700.0,
					1.1
				),
				_c(
					BiomeEvidenceChannels.LIGHT,
					0.0,
					0.0,
					0.02,
					0.08,
					0.60
				),
				_c(
					BiomeEvidenceChannels.ROCK_SUBSTRATE,
					0.20,
					0.50,
					1.0,
					1.0,
					1.2
				),
				_c(
					BiomeEvidenceChannels.SLOPE_DEGREES,
					6.0,
					14.0,
					55.0,
					82.0,
					1.2
				),
				_c(
					BiomeEvidenceChannels.ROUGHNESS_STRENGTH,
					0.05,
					0.22,
					1.0,
					1.0
				)
			]
		)
	)

	default_profiles.append(
		BiomeProfileSnapshot.new(
			BiomeIds.ABYSSAL_SEDIMENT_PLAIN,
			BiomeIds.get_display_name(
				BiomeIds.ABYSSAL_SEDIMENT_PLAIN
			),
			[
				_c(
					BiomeEvidenceChannels.DEPTH,
					1750.0,
					2250.0,
					4300.0,
					5250.0,
					1.1
				),
				_c(
					BiomeEvidenceChannels.ABYSSAL_PROVINCE,
					0.15,
					0.55,
					1.0,
					1.0,
					1.2
				),
				_c(
					BiomeEvidenceChannels
						.SOFT_SEDIMENT_SUBSTRATE,
					0.20,
					0.50,
					1.0,
					1.0,
					1.3
				),
				_c(
					BiomeEvidenceChannels.SLOPE_DEGREES,
					0.0,
					0.0,
					6.0,
					16.0
				),
				_c(
					BiomeEvidenceChannels.ROUGHNESS_STRENGTH,
					0.0,
					0.0,
					0.22,
					0.55
				),
				_c(
					BiomeEvidenceChannels
						.GEOLOGICAL_STABILITY,
					0.20,
					0.50,
					1.0,
					1.0,
					0.65
				)
			],
			1.02
		)
	)

	default_profiles.append(
		BiomeProfileSnapshot.new(
			BiomeIds.HYDROTHERMAL_FIELD,
			BiomeIds.get_display_name(
				BiomeIds.HYDROTHERMAL_FIELD
			),
			[
				_c(
					BiomeEvidenceChannels.DEPTH,
					150.0,
					500.0,
					5000.0,
					6000.0,
					0.65
				),
				_c(
					BiomeEvidenceChannels.VOLCANIC_POTENTIAL,
					0.15,
					0.50,
					1.0,
					1.0,
					1.5
				),
				_c(
					BiomeEvidenceChannels.ROCK_SUBSTRATE,
					0.15,
					0.42,
					1.0,
					1.0
				),
				_c(
					BiomeEvidenceChannels.NUTRIENTS,
					0.10,
					0.35,
					1.0,
					1.0,
					1.1
				),
				_c(
					BiomeEvidenceChannels
						.BIOLOGICAL_POTENTIAL,
					0.04,
					0.18,
					1.0,
					1.0,
					1.1
				)
			],
			1.12
		)
	)

	default_profiles.append(
		BiomeProfileSnapshot.new(
			BiomeIds.TRENCH_WALL,
			BiomeIds.get_display_name(
				BiomeIds.TRENCH_WALL
			),
			[
				_c(
					BiomeEvidenceChannels.DEPTH,
					2500.0,
					3300.0,
					5800.0,
					6000.0
				),
				_c(
					BiomeEvidenceChannels.TRENCH_POTENTIAL,
					0.05,
					0.30,
					1.0,
					1.0,
					1.5
				),
				_c(
					BiomeEvidenceChannels.SLOPE_DEGREES,
					6.0,
					18.0,
					72.0,
					89.0,
					1.4
				),
				_c(
					BiomeEvidenceChannels.ROCK_SUBSTRATE,
					0.20,
					0.48,
					1.0,
					1.0
				)
			],
			1.08,
			GeologyChunkData.TRENCH_TIER_ORDINARY,
			GeologyChunkData.TRENCH_TIER_EXTREME
		)
	)

	default_profiles.append(
		BiomeProfileSnapshot.new(
			BiomeIds.TRENCH_FLOOR,
			BiomeIds.get_display_name(
				BiomeIds.TRENCH_FLOOR
			),
			[
				_c(
					BiomeEvidenceChannels.DEPTH,
					3200.0,
					3850.0,
					6000.0,
					6000.0,
					1.2
				),
				_c(
					BiomeEvidenceChannels.TRENCH_POTENTIAL,
					0.08,
					0.40,
					1.0,
					1.0,
					1.5
				),
				_c(
					BiomeEvidenceChannels.SLOPE_DEGREES,
					0.0,
					0.0,
					10.0,
					25.0,
					1.3
				),
				_c(
					BiomeEvidenceChannels.ROUGHNESS_STRENGTH,
					0.0,
					0.0,
					0.50,
					0.90,
					0.65
				)
			],
			1.10,
			GeologyChunkData.TRENCH_TIER_ORDINARY,
			GeologyChunkData.TRENCH_TIER_EXTREME
		)
	)

	default_profiles.append(
		BiomeProfileSnapshot.new(
			BiomeIds.EXTREME_TRENCH_REFUGE,
			BiomeIds.get_display_name(
				BiomeIds.EXTREME_TRENCH_REFUGE
			),
			[
				_c(
					BiomeEvidenceChannels.DEPTH,
					5000.0,
					5550.0,
					6000.0,
					6000.0,
					1.4
				),
				_c(
					BiomeEvidenceChannels.TRENCH_POTENTIAL,
					0.20,
					0.62,
					1.0,
					1.0,
					1.6
				),
				_c(
					BiomeEvidenceChannels.SLOPE_DEGREES,
					0.0,
					0.0,
					18.0,
					42.0
				),
				_c(
					BiomeEvidenceChannels.NUTRIENTS,
					0.05,
					0.20,
					1.0,
					1.0,
					0.75
				),
				_c(
					BiomeEvidenceChannels.ABYSSAL_PROVINCE,
					0.20,
					0.60,
					1.0,
					1.0
				)
			],
			1.20,
			GeologyChunkData.TRENCH_TIER_EXTREME,
			GeologyChunkData.TRENCH_TIER_EXTREME
		)
	)

	return BiomeCatalogSnapshot.new(
		default_profiles
	)


func get_validation_error() -> String:
	if profiles.size() != BiomeIds.COUNT:
		return (
			"Default biome catalog must contain exactly %d profiles."
			% BiomeIds.COUNT
		)

	var encountered_ids: Dictionary = {}

	for profile in profiles:
		if profile == null:
			return "Biome catalog contains a null profile."

		var profile_error := profile.get_validation_error()

		if not profile_error.is_empty():
			return profile_error

		if encountered_ids.has(profile.biome_id):
			return (
				"Biome catalog contains duplicate biome ID %d."
				% profile.biome_id
			)

		encountered_ids[profile.biome_id] = true

	for biome_id in range(BiomeIds.COUNT):
		if not encountered_ids.has(biome_id):
			return (
				"Biome catalog is missing biome ID %d."
				% biome_id
			)

	return ""


static func _c(
	channel_id: int,
	minimum: float,
	ideal_minimum: float,
	ideal_maximum: float,
	maximum: float,
	weight: float = 1.0
) -> BiomeCriterionSnapshot:
	return BiomeCriterionSnapshot.new(
		channel_id,
		minimum,
		ideal_minimum,
		ideal_maximum,
		maximum,
		weight
	)
