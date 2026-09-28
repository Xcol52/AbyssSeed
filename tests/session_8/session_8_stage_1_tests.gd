extends Node

const EPSILON: float = 0.0001

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	_test_world_scale()
	_test_chunk_coordinates()
	_test_triangle_sampling()
	_test_shared_border()

	print("")
	print(
		(
			"Session 8 Stage 1: "
			+ "%d passed, %d failed"
		)
		% [
			_passed,
			_failed
		]
	)

	if _failed == 0:
		get_tree().quit(0)
	else:
		get_tree().quit(1)


func _test_world_scale() -> void:
	_expect_close(
		WorldScaleContract.METERS_PER_WORLD_UNIT,
		1.0,
		"One world unit equals one meter."
	)

	_expect_close(
		WorldScaleContract.depth_below_sea_level(
			0.0,
			-600.0
		),
		600.0,
		"Depth below zero sea level."
	)

	_expect_close(
		WorldScaleContract.depth_below_sea_level(
			100.0,
			-500.0
		),
		600.0,
		"Depth uses configured sea level."
	)

	_expect_close(
		WorldScaleContract.bottom_clearance(
			-600.0,
			-3400.0
		),
		2800.0,
		"Bottom clearance."
	)


func _test_chunk_coordinates() -> void:
	_expect_vector_equal(
		TerrainSurfaceQuery.world_to_chunk_coordinate(
			Vector3(
				300.0,
				0.0,
				700.0
			),
			256.0
		),
		Vector2i(1, 2),
		"Positive chunk coordinate."
	)

	_expect_vector_equal(
		TerrainSurfaceQuery.world_to_chunk_coordinate(
			Vector3(
				-0.01,
				0.0,
				-0.01
			),
			256.0
		),
		Vector2i(-1, -1),
		"Negative near-origin coordinate."
	)

	_expect_vector_equal(
		TerrainSurfaceQuery.world_to_chunk_coordinate(
			Vector3(
				-256.0,
				0.0,
				0.0
			),
			256.0
		),
		Vector2i(-1, 0),
		"Exact negative chunk boundary."
	)

	_expect_vector_equal(
		TerrainSurfaceQuery.world_to_chunk_coordinate(
			Vector3(
				-256.01,
				0.0,
				0.0
			),
			256.0
		),
		Vector2i(-2, 0),
		"Coordinate beyond negative boundary."
	)


func _test_triangle_sampling() -> void:
	## One cell:
	##
	## h00 = 0
	## h10 = 10
	## h01 = 20
	## h11 = 40
	var chunk_data := TerrainChunkData.new(
		Vector2i.ZERO,
		1,
		1.0,
		PackedFloat32Array([
			0.0,
			10.0,
			20.0,
			40.0
		])
	)

	var point_00: TerrainSurfaceQueryResult = (
		TerrainSurfaceQuery.sample_local(
			chunk_data,
			Vector2(0.0, 0.0)
		)
	)

	_expect(
		point_00.available,
		"Point 00 is available."
	)

	_expect_close(
		point_00.surface_elevation_meters,
		0.0,
		"Point 00 elevation."
	)

	var point_11: TerrainSurfaceQueryResult = (
		TerrainSurfaceQuery.sample_local(
			chunk_data,
			Vector2(1.0, 1.0)
		)
	)

	_expect(
		point_11.available,
		"Point 11 is available."
	)

	_expect_close(
		point_11.surface_elevation_meters,
		40.0,
		"Point 11 elevation."
	)

	var first_triangle: TerrainSurfaceQueryResult = (
		TerrainSurfaceQuery.sample_local(
			chunk_data,
			Vector2(0.25, 0.25)
		)
	)

	_expect(
		first_triangle.available,
		"First triangle is available."
	)

	_expect_close(
		first_triangle.surface_elevation_meters,
		7.5,
		"First triangle interpolation."
	)

	var second_triangle: TerrainSurfaceQueryResult = (
		TerrainSurfaceQuery.sample_local(
			chunk_data,
			Vector2(0.75, 0.75)
		)
	)

	_expect(
		second_triangle.available,
		"Second triangle is available."
	)

	_expect_close(
		second_triangle.surface_elevation_meters,
		27.5,
		"Second triangle interpolation."
	)

	var diagonal: TerrainSurfaceQueryResult = (
		TerrainSurfaceQuery.sample_local(
			chunk_data,
			Vector2(0.5, 0.5)
		)
	)

	_expect_close(
		diagonal.surface_elevation_meters,
		15.0,
		"Shared triangle diagonal."
	)

	var outside: TerrainSurfaceQueryResult = (
		TerrainSurfaceQuery.sample_local(
			chunk_data,
			Vector2(-1.0, 0.5)
		)
	)

	_expect(
		not outside.available,
		"Out-of-bounds sample is unavailable."
	)


func _test_shared_border() -> void:
	var left_chunk := TerrainChunkData.new(
		Vector2i(0, 0),
		1,
		1.0,
		PackedFloat32Array([
			0.0,
			10.0,
			20.0,
			30.0
		])
	)

	var right_chunk := TerrainChunkData.new(
		Vector2i(1, 0),
		1,
		1.0,
		PackedFloat32Array([
			10.0,
			40.0,
			30.0,
			50.0
		])
	)

	var left_result: TerrainSurfaceQueryResult = (
		TerrainSurfaceQuery.sample_local(
			left_chunk,
			Vector2(1.0, 0.4)
		)
	)

	var right_result: TerrainSurfaceQueryResult = (
		TerrainSurfaceQuery.sample_local(
			right_chunk,
			Vector2(0.0, 0.4)
		)
	)

	_expect(
		(
			left_result.available
			and right_result.available
		),
		"Both shared-border samples are available."
	)

	_expect_close(
		left_result.surface_elevation_meters,
		right_result.surface_elevation_meters,
		"Shared-border elevations are equal."
	)


func _expect(
	condition: bool,
	description: String
) -> void:
	if condition:
		_passed += 1
		return

	_failed += 1

	push_error(
		"FAILED: %s"
		% description
	)


func _expect_close(
	actual: float,
	expected: float,
	description: String
) -> void:
	_expect(
		absf(actual - expected) <= EPSILON,
		(
			"%s Expected %.6f, received %.6f."
			% [
				description,
				expected,
				actual
			]
		)
	)


func _expect_vector_equal(
	actual: Vector2i,
	expected: Vector2i,
	description: String
) -> void:
	_expect(
		actual == expected,
		(
			"%s Expected %s, received %s."
			% [
				description,
				str(expected),
				str(actual)
			]
		)
	)
