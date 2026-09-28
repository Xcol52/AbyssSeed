class_name TerrainMeshPreparer
extends RefCounted

const FLOOR_DARK: Color = Color(
	0.018,
	0.045,
	0.058,
	1.0
)
const FLOOR_LIGHT: Color = Color(
	0.07,
	0.13,
	0.14,
	1.0
)
const STEEP_COLOR: Color = Color(
	0.10,
	0.15,
	0.15,
	1.0
)

## Approximately normalized. This provides stable baked face variation
## without requiring lights or per-chunk height normalization.
const FAKE_LIGHT_DIRECTION: Vector3 = Vector3(
	-0.405,
	0.862,
	-0.304
)


## Worker-safe, data-only geometry preparation.
##
## This function creates no Resource, ArrayMesh, Node, or SceneTree
## reference.
static func prepare(
	chunk_data: TerrainChunkData,
	preparation_profile: TerrainMeshPreparationProfile = null
) -> TerrainMeshData:
	var profiling_enabled := preparation_profile != null
	var preparation_started_usec: int = 0

	if profiling_enabled:
		preparation_profile.reset()
		preparation_started_usec = Time.get_ticks_usec()

	var validation_error := get_validation_error(
		chunk_data
	)

	if not validation_error.is_empty():
		_finish_failed_profile(
			preparation_profile,
			preparation_started_usec
		)
		return null

	var cells := chunk_data.cells_per_axis
	var cell_size := chunk_data.cell_size

	if profiling_enabled:
		preparation_profile.set_topology(cells)

		preparation_profile.validation_usec = (
			Time.get_ticks_usec()
			- preparation_started_usec
		)

	var emitted_vertex_count := (
		cells
		* cells
		* 6
	)

	var stage_started_usec: int = 0

	if profiling_enabled:
		stage_started_usec = Time.get_ticks_usec()

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()

	vertices.resize(emitted_vertex_count)
	normals.resize(emitted_vertex_count)
	uvs.resize(emitted_vertex_count)
	colors.resize(emitted_vertex_count)

	if profiling_enabled:
		preparation_profile.packed_array_allocation_usec = (
			Time.get_ticks_usec()
			- stage_started_usec
		)

		stage_started_usec = Time.get_ticks_usec()

	var write_index: int = 0

	for local_z in range(cells):
		for local_x in range(cells):
			var x0 := float(local_x) * cell_size
			var x1 := float(local_x + 1) * cell_size
			var z0 := float(local_z) * cell_size
			var z1 := float(local_z + 1) * cell_size

			var point_00 := Vector3(
				x0,
				chunk_data.get_height(
					local_x,
					local_z
				),
				z0
			)
			var point_10 := Vector3(
				x1,
				chunk_data.get_height(
					local_x + 1,
					local_z
				),
				z0
			)
			var point_01 := Vector3(
				x0,
				chunk_data.get_height(
					local_x,
					local_z + 1
				),
				z1
			)
			var point_11 := Vector3(
				x1,
				chunk_data.get_height(
					local_x + 1,
					local_z + 1
				),
				z1
			)

			var uv_00 := Vector2(
				float(local_x) / float(cells),
				float(local_z) / float(cells)
			)
			var uv_10 := Vector2(
				float(local_x + 1) / float(cells),
				float(local_z) / float(cells)
			)
			var uv_01 := Vector2(
				float(local_x) / float(cells),
				float(local_z + 1) / float(cells)
			)
			var uv_11 := Vector2(
				float(local_x + 1) / float(cells),
				float(local_z + 1) / float(cells)
			)

			## Triangle 1: point_00, point_01, point_10.
			var first_normal := (
				(point_01 - point_00)
				.cross(point_10 - point_00)
				.normalized()
			)

			var first_color := _calculate_face_color(
				first_normal
			)

			vertices[write_index] = point_00
			normals[write_index] = first_normal
			uvs[write_index] = uv_00
			colors[write_index] = first_color

			vertices[write_index + 1] = point_01
			normals[write_index + 1] = first_normal
			uvs[write_index + 1] = uv_01
			colors[write_index + 1] = first_color

			vertices[write_index + 2] = point_10
			normals[write_index + 2] = first_normal
			uvs[write_index + 2] = uv_10
			colors[write_index + 2] = first_color

			write_index += 3

			## Triangle 2: point_10, point_01, point_11.
			var second_normal := (
				(point_01 - point_10)
				.cross(point_11 - point_10)
				.normalized()
			)

			var second_color := _calculate_face_color(
				second_normal
			)

			vertices[write_index] = point_10
			normals[write_index] = second_normal
			uvs[write_index] = uv_10
			colors[write_index] = second_color

			vertices[write_index + 1] = point_01
			normals[write_index + 1] = second_normal
			uvs[write_index + 1] = uv_01
			colors[write_index + 1] = second_color

			vertices[write_index + 2] = point_11
			normals[write_index + 2] = second_normal
			uvs[write_index + 2] = uv_11
			colors[write_index + 2] = second_color

			write_index += 3

	assert(write_index == emitted_vertex_count)

	if profiling_enabled:
		preparation_profile.geometry_population_usec = (
			Time.get_ticks_usec()
			- stage_started_usec
		)

		stage_started_usec = Time.get_ticks_usec()

	var mesh_data := TerrainMeshData.new(
		chunk_data.chunk_coordinate,
		cells,
		vertices,
		normals,
		uvs,
		colors
	)

	if profiling_enabled:
		preparation_profile.data_object_setup_usec = (
			Time.get_ticks_usec()
			- stage_started_usec
		)

		preparation_profile.raw_payload_bytes = (
			mesh_data.get_raw_payload_size_bytes()
		)

		preparation_profile.total_usec = (
			Time.get_ticks_usec()
			- preparation_started_usec
		)

	return mesh_data


static func get_validation_error(
	chunk_data: TerrainChunkData
) -> String:
	if chunk_data == null:
		return "TerrainMeshPreparer requires TerrainChunkData."

	if chunk_data.cells_per_axis < 1:
		return (
			"TerrainChunkData requires at least one cell per axis."
		)

	if (
		not is_finite(chunk_data.cell_size)
		or chunk_data.cell_size <= 0.0
	):
		return (
			"TerrainChunkData requires a positive finite cell size."
		)

	var vertices_per_axis := (
		chunk_data.cells_per_axis + 1
	)

	var expected_height_count := (
		vertices_per_axis
		* vertices_per_axis
	)

	if (
		chunk_data.height_values.size()
		!= expected_height_count
	):
		return (
			"TerrainChunkData height count is invalid. "
			+ "Expected %d, received %d."
			% [
				expected_height_count,
				chunk_data.height_values.size()
			]
		)

	return ""


static func _finish_failed_profile(
	preparation_profile: TerrainMeshPreparationProfile,
	preparation_started_usec: int
) -> void:
	if preparation_profile == null:
		return

	var now_usec := Time.get_ticks_usec()

	preparation_profile.validation_usec = maxi(
		0,
		now_usec - preparation_started_usec
	)

	preparation_profile.total_usec = (
		preparation_profile.validation_usec
	)


static func _calculate_face_color(
	normal: Vector3
) -> Color:
	var light_factor := clampf(
		normal.dot(FAKE_LIGHT_DIRECTION),
		0.0,
		1.0
	)

	var slope_factor := (
		1.0
		- clampf(
			normal.dot(Vector3.UP),
			0.0,
			1.0
		)
	)

	var face_color := FLOOR_DARK.lerp(
		FLOOR_LIGHT,
		0.2 + light_factor * 0.55
	)

	return face_color.lerp(
		STEEP_COLOR,
		slope_factor * 0.35
	)
