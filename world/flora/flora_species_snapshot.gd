class_name FloraSpeciesSnapshot
extends RefCounted

## Immutable by convention.

var species_id: int
var display_name: String

## One deterministic candidate cell per this many meters.
var candidate_spacing: float

## Fraction of candidate-cell width available for jitter.
## A value of 0.6 permits offsets up to 0.3 cell widths.
var jitter_fraction: float

## Maximum probability after suitability and patching.
var base_spawn_probability: float

## Candidates below this suitability are rejected.
var minimum_suitability: float

## Broad deterministic patch structure.
var patch_size: float
var patchiness: float

var minimum_scale: float
var maximum_scale: float

var align_to_surface: bool

## One affinity per BiomeIds value.
var biome_affinities: PackedFloat32Array

var criteria: Array[FloraCriterionSnapshot]


func _init(
	new_species_id: int,
	new_display_name: String,
	new_candidate_spacing: float,
	new_jitter_fraction: float,
	new_base_spawn_probability: float,
	new_minimum_suitability: float,
	new_patch_size: float,
	new_patchiness: float,
	new_minimum_scale: float,
	new_maximum_scale: float,
	new_align_to_surface: bool,
	new_biome_affinities: PackedFloat32Array,
	new_criteria: Array[FloraCriterionSnapshot]
) -> void:
	species_id = new_species_id
	display_name = new_display_name

	candidate_spacing = new_candidate_spacing
	jitter_fraction = new_jitter_fraction

	base_spawn_probability = new_base_spawn_probability
	minimum_suitability = new_minimum_suitability

	patch_size = new_patch_size
	patchiness = new_patchiness

	minimum_scale = new_minimum_scale
	maximum_scale = new_maximum_scale

	align_to_surface = new_align_to_surface

	biome_affinities = new_biome_affinities.duplicate()
	criteria = new_criteria


func get_biome_affinity(
	biome_id: int
) -> float:
	if (
		biome_id < 0
		or biome_id >= biome_affinities.size()
	):
		return 0.0

	return biome_affinities[biome_id]


func get_validation_error() -> String:
	if species_id < 0 or species_id >= FloraIds.COUNT:
		return "Flora species has an invalid species ID."

	if display_name.is_empty():
		return "Flora species requires a display name."

	if (
		not is_finite(candidate_spacing)
		or candidate_spacing <= 0.0
	):
		return "Flora candidate spacing must be positive."

	if (
		not is_finite(jitter_fraction)
		or jitter_fraction < 0.0
		or jitter_fraction > 0.90
	):
		return (
			"Flora jitter fraction must be between "
			+ "zero and 0.90."
		)

	if (
		not is_finite(base_spawn_probability)
		or base_spawn_probability < 0.0
		or base_spawn_probability > 1.0
	):
		return (
			"Flora base spawn probability must be "
			+ "between zero and one."
		)

	if (
		not is_finite(minimum_suitability)
		or minimum_suitability < 0.0
		or minimum_suitability >= 1.0
	):
		return (
			"Flora minimum suitability must be at least "
			+ "zero and less than one."
		)

	if not is_finite(patch_size) or patch_size <= 0.0:
		return "Flora patch size must be positive."

	if (
		not is_finite(patchiness)
		or patchiness < 0.0
		or patchiness > 1.0
	):
		return "Flora patchiness must be between zero and one."

	if (
		not is_finite(minimum_scale)
		or not is_finite(maximum_scale)
		or minimum_scale <= 0.0
		or maximum_scale < minimum_scale
	):
		return "Flora scale range is invalid."

	if biome_affinities.size() != BiomeIds.COUNT:
		return (
			"Flora biome affinities must contain exactly %d values."
			% BiomeIds.COUNT
		)

	var has_affinity := false

	for affinity in biome_affinities:
		if (
			not is_finite(affinity)
			or affinity < 0.0
			or affinity > 1.0
		):
			return (
				"Flora biome affinities must be between "
				+ "zero and one."
			)

		if affinity > 0.0:
			has_affinity = true

	if not has_affinity:
		return "Flora species requires at least one biome affinity."

	if criteria.is_empty():
		return "Flora species requires environmental criteria."

	for criterion in criteria:
		if criterion == null:
			return "Flora species contains a null criterion."

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
