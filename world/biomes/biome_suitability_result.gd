class_name BiomeSuitabilityResult
extends RefCounted

## Raw overlapping suitability values.
##
## They are not normalized to sum to one. Multiple biomes can have high
## suitability at the same location.
var weights: PackedFloat32Array

var dominant_biome_id: int
var dominant_suitability: float

var total_suitability: float


func _init(
	new_weights: PackedFloat32Array,
	new_dominant_biome_id: int,
	new_dominant_suitability: float,
	new_total_suitability: float
) -> void:
	weights = new_weights.duplicate()

	dominant_biome_id = new_dominant_biome_id
	dominant_suitability = new_dominant_suitability
	total_suitability = new_total_suitability


func get_weight(
	biome_id: int
) -> float:
	if biome_id < 0 or biome_id >= weights.size():
		return 0.0

	return weights[biome_id]


func get_normalized_weight(
	biome_id: int
) -> float:
	if total_suitability <= 0.000001:
		return 0.0

	return get_weight(biome_id) / total_suitability
