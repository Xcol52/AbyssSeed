class_name TerrainGenerationWorker
extends RefCounted


## This object is job-local. It has no scheduler, coordinator, Node,
## observer, settings Resource, SceneTree, or rendering references.
func execute(
	snapshot: TerrainGenerationSnapshot,
	mailbox: TerrainResultMailbox
) -> void:
	var sampling_started_at := Time.get_ticks_usec()

	var validation_error := snapshot.get_validation_error()

	if not validation_error.is_empty():
		var invalid_result := (
			TerrainGenerationResult.create_failure(
				snapshot,
				validation_error,
				Time.get_ticks_usec()
				- sampling_started_at
			)
		)

		mailbox.publish(invalid_result)
		return

	var chunk_data := (
		TerrainSampler.generate_from_snapshot(
			snapshot
		)
	)

	var sampling_usec := (
		Time.get_ticks_usec()
		- sampling_started_at
	)

	if chunk_data == null:
		mailbox.publish(
			TerrainGenerationResult.create_failure(
				snapshot,
				"TerrainSampler returned no chunk data.",
				sampling_usec
			)
		)
		return

	var mesh_preparation_profile := (
		TerrainMeshPreparationProfile.new()
	)

	var mesh_data := TerrainMeshPreparer.prepare(
		chunk_data,
		mesh_preparation_profile
	)

	var geometry_preparation_usec := (
		mesh_preparation_profile.total_usec
	)

	if mesh_data == null:
		mailbox.publish(
			TerrainGenerationResult.create_failure(
				snapshot,
				(
					"TerrainMeshPreparer returned "
					+ "no mesh data."
				),
				sampling_usec,
				geometry_preparation_usec,
				mesh_preparation_profile
			)
		)
		return

	mailbox.publish(
		TerrainGenerationResult.create_success(
			snapshot,
			chunk_data,
			sampling_usec,
			mesh_data,
			geometry_preparation_usec,
			mesh_preparation_profile
		)
	)
