extends Node

const TEST_EPSILON: float = 0.0001

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	_test_plate_interior_identity()
	_test_inactive_boundary_identity()
	_test_full_weight_changes_nonterrace_elevation()
	_test_exact_terrace_level_is_stable()
	_test_fractional_rounding()
	_test_partial_weight_is_linear_blend()
	_test_negative_elevation_continuity()
	_test_determinism()
	_test_world_coordinate_stability()
	_test_invalid_coordinate_safety()

	print(
		"Boundary strata tests: %d passed, %d failed"
		% [_passed, _failed]
	)

	get_tree().quit(_failed)


func _test_plate_interior_identity() -> void:
	var raw_elevation: float = -347.25

	var result: float = GeologySampler._apply_boundary_strata(
		raw_elevation,
		0.0,
		1.0,
		Vector2(1000.0, -2000.0)
	)

	_expect_close(
		result,
		raw_elevation,
		TEST_EPSILON,
		"Plate interiors preserve raw elevation."
	)


func _test_inactive_boundary_identity() -> void:
	var raw_elevation: float = -347.25

	var result: float = GeologySampler._apply_boundary_strata(
		raw_elevation,
		1.0,
		0.0,
		Vector2.ZERO
	)

	_expect_close(
		result,
		raw_elevation,
		TEST_EPSILON,
		"Inactive boundaries preserve raw elevation."
	)


func _test_full_weight_changes_nonterrace_elevation() -> void:
	var raw_elevation: float = -103.0

	var result: float = GeologySampler._apply_boundary_strata(
		raw_elevation,
		1.0,
		1.0,
		Vector2.ZERO
	)

	_expect_true(
		not is_equal_approx(result, raw_elevation),
		"Active boundaries reshape nonterrace elevations."
	)


func _test_exact_terrace_level_is_stable() -> void:
	var raw_elevation: float = -90.0

	var result: float = GeologySampler._apply_boundary_strata(
		raw_elevation,
		1.0,
		1.0,
		Vector2.ZERO
	)

	_expect_close(
		result,
		raw_elevation,
		TEST_EPSILON,
		"Exact terrace levels remain stable."
	)


func _test_fractional_rounding() -> void:
	var lower_plateau_result: float = (
		GeologySampler._apply_boundary_strata(
			-88.5,
			1.0,
			1.0,
			Vector2.ZERO
		)
	)

	var central_result: float = (
		GeologySampler._apply_boundary_strata(
			-82.5,
			1.0,
			1.0,
			Vector2.ZERO
		)
	)

	var upper_plateau_result: float = (
		GeologySampler._apply_boundary_strata(
			-76.5,
			1.0,
			1.0,
			Vector2.ZERO
		)
	)

	_expect_close(
		lower_plateau_result,
		-90.0,
		TEST_EPSILON,
		"Lower terrace region is flattened."
	)

	_expect_close(
		central_result,
		-82.5,
		TEST_EPSILON,
		"Terrace midpoint remains centered."
	)

	_expect_close(
		upper_plateau_result,
		-75.0,
		TEST_EPSILON,
		"Upper terrace region is flattened."
	)


func _test_partial_weight_is_linear_blend() -> void:
	var raw_elevation: float = -88.5

	var full_result: float = GeologySampler._apply_boundary_strata(
		raw_elevation,
		1.0,
		1.0,
		Vector2.ZERO
	)

	var partial_result: float = (
		GeologySampler._apply_boundary_strata(
			raw_elevation,
			0.5,
			0.5,
			Vector2.ZERO
		)
	)

	var expected_weight: float = 0.375

	var expected_result: float = lerpf(
		raw_elevation,
		full_result,
		expected_weight
	)

	_expect_close(
		partial_result,
		expected_result,
		TEST_EPSILON,
		"Partial strata strength uses the required cliff weight."
	)


func _test_negative_elevation_continuity() -> void:
	var below_boundary: float = (
		GeologySampler._apply_boundary_strata(
			-90.0001,
			1.0,
			1.0,
			Vector2.ZERO
		)
	)

	var above_boundary: float = (
		GeologySampler._apply_boundary_strata(
			-89.9999,
			1.0,
			1.0,
			Vector2.ZERO
		)
	)

	_expect_true(
		absf(above_boundary - below_boundary) < 0.001,
		"Rounded strata remain continuous across negative intervals."
	)


func _test_determinism() -> void:
	var world_xz: Vector2 = Vector2(
		-8192.25,
		16384.75
	)

	var first_result: float = (
		GeologySampler._apply_boundary_strata(
			-413.27,
			0.91,
			0.84,
			world_xz
		)
	)

	var second_result: float = (
		GeologySampler._apply_boundary_strata(
			-413.27,
			0.91,
			0.84,
			world_xz
		)
	)

	_expect_close(
		first_result,
		second_result,
		0.0,
		"Repeated strata evaluation is deterministic."
	)


func _test_world_coordinate_stability() -> void:
	var first_result: float = (
		GeologySampler._apply_boundary_strata(
			-413.27,
			0.91,
			0.84,
			Vector2(-1000.0, 2000.0)
		)
	)

	var second_result: float = (
		GeologySampler._apply_boundary_strata(
			-413.27,
			0.91,
			0.84,
			Vector2(3000.0, -4000.0)
		)
	)

	_expect_close(
		first_result,
		second_result,
		0.0,
		"Current strata levels do not drift with world position."
	)


func _test_invalid_coordinate_safety() -> void:
	var raw_elevation: float = -250.0

	var result: float = GeologySampler._apply_boundary_strata(
		raw_elevation,
		1.0,
		1.0,
		Vector2(INF, 0.0)
	)

	_expect_close(
		result,
		raw_elevation,
		0.0,
		"Invalid world coordinates preserve raw elevation."
	)


func _expect_true(
	condition: bool,
	description: String
) -> void:
	if condition:
		_passed += 1
		return

	_failed += 1
	push_error("FAIL: %s" % description)


func _expect_close(
	actual: float,
	expected: float,
	tolerance: float,
	description: String
) -> void:
	_expect_true(
		absf(actual - expected) <= tolerance,
		"%s Expected %.6f, received %.6f."
		% [
			description,
			expected,
			actual,
		]
	)
