class_name TerrainGenerationRequest
extends RefCounted

## Treat all fields as immutable after construction.
var chunk_coordinate: Vector2i
var terrain_subsystem_seed: int
var generation_version: int
var grid_settings: WorldGridSettings
var terrain_settings: TerrainSettings


func _init(
	requested_chunk_coordinate: Vector2i,
	requested_terrain_subsystem_seed: int,
	requested_generation_version: int,
	requested_grid_settings: WorldGridSettings,
	requested_terrain_settings: TerrainSettings
) -> void:
	chunk_coordinate = requested_chunk_coordinate
	terrain_subsystem_seed = requested_terrain_subsystem_seed
	generation_version = requested_generation_version
	grid_settings = requested_grid_settings
	terrain_settings = requested_terrain_settings


func validate() -> PackedStringArray:
	var errors := PackedStringArray()

	if generation_version < 1:
		errors.append("generation_version must be at least 1.")

	if grid_settings == null:
		errors.append("grid_settings is required.")
	else:
		for message in grid_settings.validate():
			errors.append("grid_settings: %s" % message)

	if terrain_settings == null:
		errors.append("terrain_settings is required.")
	else:
		for message in terrain_settings.validate():
			errors.append("terrain_settings: %s" % message)

	return errors
