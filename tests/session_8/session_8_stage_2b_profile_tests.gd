extends Node

const EPSILON: float = 0.000001

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	_test_boundary_classification()
	_test_influence_profiles()
	_test_activity_and_contributions()

	print("")
	print(
		"Session 8 Stage 2B profiles: "
		+ "%d passed, %d failed"
		% [
			_passed,
			_failed
		]
	)

	if _failed == 0:
		get_tree().quit(0)
	else:
		get_tree().quit(1)


func _test_boundary_classification() -> void:
	_expect_equal_int(
		DivergentRidgeProfile.classify_boundary(
			-0.60,
			0.10
		),
		DivergentRidgeProfile
			.BOUNDARY_CLASS_DIVERGENT,
		"Extension-dominant boundary is divergent."
	)

	_expect_equal_int(
		DivergentRidgeProfile.classify_boundary(
			0.60,
			0.10
		),
		DivergentRidgeProfile
			.BOUNDARY_CLASS_CONVERGENT,
		"Compression-dominant boundary is convergent."
	)

	_expect_equal_int(
		DivergentRidgeProfile.classify_boundary(
			-0.10,
			0.80
		),
		DivergentRidgeProfile
			.BOUNDARY_CLASS_TRANSFORM,
		"Shear-dominant boundary is transform."
	)

	_expect_equal_int(
		DivergentRidgeProfile.classify_boundary(
			-0.01,
			0.0
		),
		DivergentRidgeProfile
			.BOUNDARY_CLASS_TRANSFORM,
		"Negligible extension does not create a ridge."
	)


func _test_influence_profiles() -> void:
	_expect_close(
		DivergentRidgeProfile.calculate_influence(
			0.0,
			1400.0
		),
		1.0,
		"Influence is one at the center."
	)

	_expect_close(
		DivergentRidgeProfile.calculate_influence(
			700.0,
			1400.0
		),
		0.5,
		"Influence is one half at half-width."
	)

	_expect_close(
		DivergentRidgeProfile.calculate_influence(
			1400.0,
			1400.0
		),
		0.0,
		"Influence is zero at the edge."
	)

	_expect_close(
		DivergentRidgeProfile.calculate_influence(
			1800.0,
			1400.0
		),
		0.0,
		"Influence remains zero beyond the edge."
	)

	var ridge_at_300 := (
		DivergentRidgeProfile.calculate_influence(
			300.0,
			1400.0
		)
	)

	var rift_at_300 := (
		DivergentRidgeProfile.calculate_influence(
			300.0,
			180.0
		)
	)

	_expect(
		ridge_at_300 > 0.0,
		"Broad ridge remains active at 300 meters."
	)

	_expect_close(
		rift_at_300,
		0.0,
		"Narrow rift is inactive at 300 meters."
	)


func _test_activity_and_contributions() -> void:
	var activity := (
		DivergentRidgeProfile.calculate_activity(
			0.25,
			1.0,
			1.0
		)
	)

	_expect_close(
		activity,
		0.5,
		"Square-root extension remapping."
	)

	_expect_close(
		DivergentRidgeProfile.calculate_activity(
			0.0,
			1.0,
			1.0
		),
		0.0,
		"Zero extension produces zero activity."
	)

	var ridge_contribution := (
		DivergentRidgeProfile
		.calculate_ridge_contribution(
			0.5,
			180.0
		)
	)

	_expect_close(
		ridge_contribution,
		90.0,
		"Ridge contribution is positive."
	)

	var rift_contribution := (
		DivergentRidgeProfile
		.calculate_rift_contribution(
			0.5,
			70.0
		)
	)

	_expect_close(
		rift_contribution,
		-35.0,
		"Rift contribution is negative."
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
			"%s Expected %.8f, received %.8f."
			% [
				description,
				expected,
				actual
			]
		)
	)


func _expect_equal_int(
	actual: int,
	expected: int,
	description: String
) -> void:
	_expect(
		actual == expected,
		(
			"%s Expected %d, received %d."
			% [
				description,
				expected,
				actual
			]
		)
	)
