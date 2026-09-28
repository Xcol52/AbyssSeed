class_name BiomeProfileSnapshot
extends RefCounted

## Immutable by convention.

var biome_id: int
var display_name: String

var criteria: Array[BiomeCriterionSnapshot]

## Affects dominant-biome selection only.
## It does not alter the raw suitability value.
var dominance_bias: float

## A value below zero means that trench tier is not restricted.
var minimum_trench_tier: int
var maximum_trench_tier: int


func _init(
	new_biome_id: int,
	new_display_name: String,
	new_criteria: Array[BiomeCriterionSnapshot],
	new_dominance_bias: float = 1.0,
	new_minimum_trench_tier: int = -1,
	new_maximum_trench_tier: int = -1
) -> void:
	biome_id = new_biome_id
	display_name = new_display_name
	criteria = new_criteria

	dominance_bias = new_dominance_bias

	minimum_trench_tier = new_minimum_trench_tier
	maximum_trench_tier = new_maximum_trench_tier


func get_validation_error() -> String:
	if biome_id < 0 or biome_id >= BiomeIds.COUNT:
		return "Biome profile has an invalid biome ID."

	if display_name.is_empty():
		return "Biome profile requires a display name."

	if criteria.is_empty():
		return (
			"Biome profile %s requires at least one criterion."
			% display_name
		)

	if (
		not is_finite(dominance_bias)
		or dominance_bias <= 0.0
	):
		return (
			"Biome profile dominance bias must be positive."
		)

	var uses_trench_restriction := (
		minimum_trench_tier >= 0
		or maximum_trench_tier >= 0
	)

	if uses_trench_restriction:
		if (
			minimum_trench_tier < 0
			or maximum_trench_tier < minimum_trench_tier
			or maximum_trench_tier
				> GeologyChunkData.TRENCH_TIER_EXTREME
		):
			return (
				"Biome profile has an invalid trench-tier range."
			)

	for criterion in criteria:
		if criterion == null:
			return "Biome profile contains a null criterion."

		var criterion_error := (
			criterion.get_validation_error()
		)

		if not criterion_error.is_empty():
			return (
				"Invalid criterion in %s: %s"
				% [
					display_name,
					criterion_error
				]
			)

	return ""
