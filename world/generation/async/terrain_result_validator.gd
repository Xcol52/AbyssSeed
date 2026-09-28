class_name TerrainResultValidator
extends RefCounted


static func is_current(
	result: TerrainGenerationResult,
	is_still_desired: bool,
	is_already_active: bool,
	expected_request_id: int,
	expected_world_session_id: int,
	expected_generation_version: int
) -> bool:
	if result == null or result.snapshot == null:
		return false

	if not is_still_desired:
		return false

	if is_already_active:
		return false

	if (
		result.snapshot.request_id
		!= expected_request_id
	):
		return false

	if (
		result.snapshot.world_session_id
		!= expected_world_session_id
	):
		return false

	if (
		result.snapshot.generation_version
		!= expected_generation_version
	):
		return false

	return true
