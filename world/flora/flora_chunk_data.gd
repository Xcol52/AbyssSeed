class_name FloraChunkData
extends RefCounted

## Immutable by convention after construction.

var chunk_coordinate: Vector2i
var world_origin: Vector2
var chunk_size: float

var candidates: Array[FloraPlacementCandidate]


func _init(
	new_chunk_coordinate: Vector2i,
	new_world_origin: Vector2,
	new_chunk_size: float,
	new_candidates: Array[FloraPlacementCandidate]
) -> void:
	chunk_coordinate = new_chunk_coordinate
	world_origin = new_world_origin
	chunk_size = new_chunk_size
	candidates = new_candidates


func get_candidate_count() -> int:
	return candidates.size()

func get_validation_error() -> String:
	if not is_finite(world_origin.x):
		return "Flora chunk world-origin X must be finite."

	if not is_finite(world_origin.y):
		return "Flora chunk world-origin Z must be finite."

	if not is_finite(chunk_size) or chunk_size <= 0.0:
		return "Flora chunk size must be positive."

	var encountered_ids: Dictionary = {}

	for index in range(candidates.size()):
		var candidate := candidates[index]

		if candidate == null:
			return "Flora chunk contains a null candidate."

		var candidate_error: String = (
			candidate.get_validation_error()
		)

		if not candidate_error.is_empty():
			return (
				"Invalid flora candidate at index %d: %s"
				% [index, candidate_error]
			)

		if encountered_ids.has(candidate.stable_id):
			return (
				"Flora chunk contains duplicate stable ID %d."
				% candidate.stable_id
			)

		encountered_ids[candidate.stable_id] = true

		if (
			candidate.world_position.x < world_origin.x
			or candidate.world_position.z < world_origin.y
			or candidate.world_position.x
				>= world_origin.x + chunk_size
			or candidate.world_position.z
				>= world_origin.y + chunk_size
		):
			return (
				"Flora candidate lies outside its owning "
				+ "half-open chunk domain."
			)

		if (
			index > 0
			and _candidate_less_than(
				candidate,
				candidates[index - 1]
			)
		):
			return (
				"Flora candidates are not in stable order."
			)

	return ""


static func _candidate_less_than(
	left: FloraPlacementCandidate,
	right: FloraPlacementCandidate
) -> bool:
	if left.species_id != right.species_id:
		return left.species_id < right.species_id

	if left.candidate_cell.y != right.candidate_cell.y:
		return (
			left.candidate_cell.y
			< right.candidate_cell.y
		)

	if left.candidate_cell.x != right.candidate_cell.x:
		return (
			left.candidate_cell.x
			< right.candidate_cell.x
		)

	return left.stable_id < right.stable_id

func get_species_count(
	species_id: int
) -> int:
	var count := 0

	for candidate in candidates:
		if candidate.species_id == species_id:
			count += 1

	return count


func get_species_candidates(
	species_id: int
) -> Array[FloraPlacementCandidate]:
	var matching: Array[FloraPlacementCandidate] = []

	for candidate in candidates:
		if candidate.species_id == species_id:
			matching.append(candidate)

	return matching
