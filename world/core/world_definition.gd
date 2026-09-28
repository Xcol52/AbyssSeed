class_name WorldDefinition
extends Resource

@export_category("World Identity")

@export var world_seed: int = 1337
@export var generation_version: int = 1

@export_category("Subsystem Settings")

@export var ocean_settings: OceanSettings
@export var grid_settings: WorldGridSettings
@export var terrain_settings: TerrainSettings
@export var geology_settings: GeologySettings
@export var environment_settings: EnvironmentSettings
@export var chunk_streaming_settings: ChunkStreamingSettings
@export var chunk_generation_settings: ChunkGenerationSettings


func validate() -> PackedStringArray:
	var errors := PackedStringArray()

	if generation_version < 1:
		errors.append(
			"generation_version must be at least 1."
		)

	if ocean_settings == null:
		errors.append("ocean_settings is required.")
	else:
		for message in ocean_settings.validate():
			errors.append(
				"ocean_settings: %s" % message
			)

	if grid_settings == null:
		errors.append("grid_settings is required.")
	else:
		for message in grid_settings.validate():
			errors.append(
				"grid_settings: %s" % message
			)

	if terrain_settings == null:
		errors.append("terrain_settings is required.")
	else:
		for message in terrain_settings.validate():
			errors.append(
				"terrain_settings: %s" % message
			)

	if geology_settings == null:
		errors.append("geology_settings is required.")
	else:
		for message in geology_settings.validate():
			errors.append(
				"geology_settings: %s" % message
			)

	if environment_settings == null:
		errors.append(
			"environment_settings is required."
		)
	else:
		for message in environment_settings.validate():
			errors.append(
				"environment_settings: %s"
				% message
			)

	if chunk_streaming_settings == null:
		errors.append(
			"chunk_streaming_settings is required."
		)
	else:
		for message in chunk_streaming_settings.validate():
			errors.append(
				"chunk_streaming_settings: %s"
				% message
			)

	if chunk_generation_settings == null:
		errors.append(
			"chunk_generation_settings is required."
		)
	else:
		for message in chunk_generation_settings.validate():
			errors.append(
				"chunk_generation_settings: %s"
				% message
			)

	return errors
