class_name TerrainGenerationSnapshot
extends RefCounted

## This object is immutable by convention after construction.
## Every field is a copied value. No Resource or Node references exist.

var request_id: int
var world_session_id: int
var chunk_coordinate: Vector2i
var generation_version: int
var terrain_subsystem_seed: int

var chunk_size: float
var cells_per_axis: int

var base_seabed_depth: float
var test_elevation_amplitude: float
var test_noise_frequency: float
var geology_snapshot: GeologyGenerationSnapshot

## Profiling metadata only. It does not affect generation.
var enqueued_at_usec: int


func _init(
	new_request_id: int,
	new_world_session_id: int,
	new_chunk_coordinate: Vector2i,
	new_generation_version: int,
	new_terrain_subsystem_seed: int,
	new_chunk_size: float,
	new_cells_per_axis: int,
	new_base_seabed_depth: float,
	new_test_elevation_amplitude: float,
	new_test_noise_frequency: float,
	new_enqueued_at_usec: int,
	new_geology_snapshot: GeologyGenerationSnapshot = null
) -> void:
	request_id = new_request_id
	world_session_id = new_world_session_id
	chunk_coordinate = new_chunk_coordinate
	generation_version = new_generation_version
	terrain_subsystem_seed = new_terrain_subsystem_seed
	geology_snapshot = new_geology_snapshot

	chunk_size = new_chunk_size
	cells_per_axis = new_cells_per_axis

	base_seabed_depth = new_base_seabed_depth
	test_elevation_amplitude = new_test_elevation_amplitude
	test_noise_frequency = new_test_noise_frequency

	enqueued_at_usec = new_enqueued_at_usec


func get_cell_size() -> float:
	return chunk_size / float(cells_per_axis)


func get_validation_error() -> String:
	if request_id < 1:
		return "request_id must be positive."

	if world_session_id < 1:
		return "world_session_id must be positive."

	if generation_version < 1:
		return "generation_version must be at least 1."

	if not is_finite(chunk_size) or chunk_size <= 0.0:
		return "chunk_size must be finite and greater than zero."

	if cells_per_axis < 1:
		return "cells_per_axis must be at least 1."

	if (
		not is_finite(base_seabed_depth)
		or base_seabed_depth <= 0.0
	):
		return (
			"base_seabed_depth must be finite "
			+ "and greater than zero."
		)

	if (
		not is_finite(test_elevation_amplitude)
		or test_elevation_amplitude < 0.0
	):
		return (
			"test_elevation_amplitude must be finite "
			+ "and non-negative."
		)

	if (
		not is_finite(test_noise_frequency)
		or test_noise_frequency <= 0.0
	):
		return (
			"test_noise_frequency must be finite "
			+ "and greater than zero."
		)
	if geology_snapshot != null:
		var geology_error := (
			geology_snapshot.get_validation_error()
		)

		if not geology_error.is_empty():
			return "Invalid geology snapshot: %s" % geology_error

	return ""
