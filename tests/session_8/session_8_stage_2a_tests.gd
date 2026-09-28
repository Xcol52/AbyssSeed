extends Node

const EPSILON: float = 0.000001

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	_test_boundary_class_names()
	_test_canonical_pair_and_side()
	_test_determinism_and_query_order()
	_test_influence_profile_and_validation()
	_test_interior_relationship()
	_test_class_coverage_and_negative_ids()

	print("")
	print(
		(
			"Session 8 Stage 2A: "
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


func _test_boundary_class_names() -> void:
	_expect_equal_string(
		MacroGeologyQueryResult
		.boundary_class_to_string(
			MacroGeologyQueryResult
			.BoundaryClass
			.INTERIOR
		),
		"interior",
		"Interior class name."
	)

	_expect_equal_string(
		MacroGeologyQueryResult
		.boundary_class_to_string(
			MacroGeologyQueryResult
			.BoundaryClass
			.DIVERGENT
		),
		"divergent",
		"Divergent class name."
	)

	_expect_equal_string(
		MacroGeologyQueryResult
		.boundary_class_to_string(
			MacroGeologyQueryResult
			.BoundaryClass
			.CONVERGENT
		),
		"convergent",
		"Convergent class name."
	)

	_expect_equal_string(
		MacroGeologyQueryResult
		.boundary_class_to_string(
			MacroGeologyQueryResult
			.BoundaryClass
			.TRANSFORM
		),
		"transform",
		"Transform class name."
	)


func _test_canonical_pair_and_side() -> void:
	var from_plate_b := (
		MacroGeologyQuery.sample_relationship(
			1337,
			42,
			7,
			120.0,
			1000.0
		)
	)

	var from_plate_a := (
		MacroGeologyQuery.sample_relationship(
			1337,
			7,
			42,
			120.0,
			1000.0
		)
	)

	_expect(
		from_plate_b.valid,
		"Plate-B query is valid."
	)

	_expect_equal_int(
		from_plate_b.canonical_plate_a_id,
		7,
		"Canonical plate A is the lower ID."
	)

	_expect_equal_int(
		from_plate_b.canonical_plate_b_id,
		42,
		"Canonical plate B is the higher ID."
	)

	_expect_equal_int(
		from_plate_b.primary_plate_id,
		42,
		"Primary plate remains unchanged."
	)

	_expect_equal_int(
		from_plate_b.neighboring_plate_id,
		7,
		"Neighboring plate remains unchanged."
	)

	_expect_equal_int(
		from_plate_b.canonical_side,
		1,
		"Canonical plate B has positive side."
	)

	_expect(
		from_plate_a.valid,
		"Plate-A query is valid."
	)

	_expect_equal_int(
		from_plate_a.canonical_plate_a_id,
		from_plate_b.canonical_plate_a_id,
		"Canonical plate A is side-independent."
	)

	_expect_equal_int(
		from_plate_a.canonical_plate_b_id,
		from_plate_b.canonical_plate_b_id,
		"Canonical plate B is side-independent."
	)

	_expect_equal_int(
		from_plate_a.boundary_class,
		from_plate_b.boundary_class,
		"Boundary class is side-independent."
	)

	_expect_close(
		from_plate_a.boundary_strength,
		from_plate_b.boundary_strength,
		"Boundary strength is side-independent."
	)

	_expect_equal_int(
		from_plate_a.canonical_side,
		-1,
		"Canonical plate A has negative side."
	)

	_expect_close(
		from_plate_a.signed_distance_to_boundary_meters,
		-from_plate_b.signed_distance_to_boundary_meters,
		"Signed distance changes across the boundary."
	)

	_expect(
		from_plate_a.has_boundary_relationship(),
		"Distinct plates form a boundary relationship."
	)


func _test_determinism_and_query_order() -> void:
	var first := (
		MacroGeologyQuery.sample_relationship(
			9001,
			18,
			73,
			250.0,
			1800.0
		)
	)

	var second := (
		MacroGeologyQuery.sample_relationship(
			9001,
			18,
			73,
			250.0,
			1800.0
		)
	)

	_expect_equal_int(
		first.boundary_class,
		second.boundary_class,
		"Repeated boundary class is deterministic."
	)

	_expect_close(
		first.boundary_strength,
		second.boundary_strength,
		"Repeated boundary strength is deterministic."
	)

	_expect_close(
		first.boundary_influence,
		second.boundary_influence,
		"Repeated boundary influence is deterministic."
	)

	var unrelated := (
		MacroGeologyQuery.sample_relationship(
			123,
			2,
			91,
			40.0,
			500.0
		)
	)

	_expect(
		unrelated.valid,
		"Interleaved unrelated query is valid."
	)

	var third := (
		MacroGeologyQuery.sample_relationship(
			9001,
			18,
			73,
			250.0,
			1800.0
		)
	)

	_expect_equal_int(
		first.boundary_class,
		third.boundary_class,
		"Query order does not change class."
	)

	_expect_close(
		first.boundary_strength,
		third.boundary_strength,
		"Query order does not change strength."
	)


func _test_influence_profile_and_validation() -> void:
	var center := (
		MacroGeologyQuery.sample_relationship(
			1337,
			1,
			2,
			0.0,
			1000.0
		)
	)

	_expect(
		center.valid,
		"Boundary-center query is valid."
	)

	_expect_close(
		center.boundary_influence,
		1.0,
		"Boundary-center influence is one."
	)

	var half_width := (
		MacroGeologyQuery.sample_relationship(
			1337,
			1,
			2,
			500.0,
			1000.0
		)
	)

	_expect_close(
		half_width.boundary_influence,
		0.5,
		"Half-width influence is one half."
	)

	var edge := (
		MacroGeologyQuery.sample_relationship(
			1337,
			1,
			2,
			1000.0,
			1000.0
		)
	)

	_expect_close(
		edge.boundary_influence,
		0.0,
		"Influence is zero at the outer edge."
	)

	var outside := (
		MacroGeologyQuery.sample_relationship(
			1337,
			1,
			2,
			1500.0,
			1000.0
		)
	)

	_expect_close(
		outside.boundary_influence,
		0.0,
		"Influence remains zero outside."
	)

	var negative_distance := (
		MacroGeologyQuery.sample_relationship(
			1337,
			1,
			2,
			-1.0,
			1000.0
		)
	)

	_expect(
		not negative_distance.valid,
		"Negative boundary distance is invalid."
	)

	_expect(
		not negative_distance.error_message.is_empty(),
		"Invalid distance reports an error."
	)

	var zero_width := (
		MacroGeologyQuery.sample_relationship(
			1337,
			1,
			2,
			0.0,
			0.0
		)
	)

	_expect(
		not zero_width.valid,
		"Zero influence width is invalid."
	)


func _test_interior_relationship() -> void:
	var interior := (
		MacroGeologyQuery.sample_relationship(
			1337,
			55,
			55,
			250.0,
			1000.0
		)
	)

	_expect(
		interior.valid,
		"Interior query is valid."
	)

	_expect_equal_int(
		interior.boundary_class,
		MacroGeologyQueryResult
			.BoundaryClass
			.INTERIOR,
		"Matching plate IDs produce interior class."
	)

	_expect(
		not interior.has_boundary_relationship(),
		"Interior has no boundary relationship."
	)

	_expect_close(
		interior.boundary_influence,
		0.0,
		"Interior boundary influence is zero."
	)

	_expect_equal_int(
		interior.canonical_side,
		0,
		"Interior has no canonical side."
	)


func _test_class_coverage_and_negative_ids() -> void:
	var found_divergent: bool = false
	var found_convergent: bool = false
	var found_transform: bool = false

	for neighboring_id in range(1, 512):
		var result := (
			MacroGeologyQuery.sample_relationship(
				1337,
				0,
				neighboring_id,
				0.0,
				1000.0
			)
		)

		match result.boundary_class:
			MacroGeologyQueryResult.BoundaryClass.DIVERGENT:
				found_divergent = true

			MacroGeologyQueryResult.BoundaryClass.CONVERGENT:
				found_convergent = true

			MacroGeologyQueryResult.BoundaryClass.TRANSFORM:
				found_transform = true

		if (
			found_divergent
			and found_convergent
			and found_transform
		):
			break

	_expect(
		found_divergent,
		"Deterministic model produces divergent pairs."
	)

	_expect(
		found_convergent,
		"Deterministic model produces convergent pairs."
	)

	_expect(
		found_transform,
		"Deterministic model produces transform pairs."
	)

	var negative_ids := (
		MacroGeologyQuery.sample_relationship(
			1337,
			-25,
			-100,
			75.0,
			600.0
		)
	)

	_expect(
		negative_ids.valid,
		"Negative plate IDs are supported."
	)

	_expect_equal_int(
		negative_ids.canonical_plate_a_id,
		-100,
		"Negative canonical plate A is stable."
	)

	_expect_equal_int(
		negative_ids.canonical_plate_b_id,
		-25,
		"Negative canonical plate B is stable."
	)

	var negative_ids_swapped := (
		MacroGeologyQuery.sample_relationship(
			1337,
			-100,
			-25,
			75.0,
			600.0
		)
	)

	_expect_equal_int(
		negative_ids.boundary_class,
		negative_ids_swapped.boundary_class,
		"Negative-ID class is side-independent."
	)

	_expect_close(
		negative_ids.boundary_strength,
		negative_ids_swapped.boundary_strength,
		"Negative-ID strength is side-independent."
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


func _expect_equal_string(
	actual: String,
	expected: String,
	description: String
) -> void:
	_expect(
		actual == expected,
		(
			"%s Expected '%s', received '%s'."
			% [
				description,
				expected,
				actual
			]
		)
	)
