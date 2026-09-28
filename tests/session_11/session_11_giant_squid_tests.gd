extends Node

var _passed: int = 0
var _failed: int = 0

@onready var _observer: Node3D = %Observer
@onready var _presentation_root: Node3D = %PresentationRoot
@onready var _coordinator: GiantSquidCoordinator = %Coordinator


func _ready() -> void:
	await _run_tests()

	print("")
	print(
		"Giant squid tests: %d passed, %d failed"
		% [_passed, _failed]
	)

	get_tree().quit(_failed)


func _run_tests() -> void:
	_test_catalog()
	_test_habitat_restrictions()
	_test_regional_determinism()
	_test_mesh_scale()

	var catalog: FaunaCatalogSnapshot = (
		FaunaCatalogSnapshot.create_default()
	)

	var initialized: bool = _coordinator.initialize(
		_observer,
		_presentation_root,
		catalog,
		0.0,
		Callable()
	)

	_expect(
		initialized,
		"GiantSquidCoordinator initializes."
	)

	if not initialized:
		return

	var stable_id: int = (
		_coordinator.force_debug_encounter(
			Vector3(
				0.0,
				-1000.0,
				0.0
			),
			7001
		)
	)

	_expect(
		stable_id != 0,
		"Debug encounter returns a stable ID."
	)

	await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout

	_expect_equal(
		_coordinator.get_active_count(),
		1,
		"Debug encounter activates one squid."
	)

	var controller: GiantSquidController = (
		_coordinator.get_active_controller(
			stable_id
		)
	)

	_expect(
		controller != null,
		"Active squid controller is available."
	)

	if controller != null:
		_expect(
			controller.get_observation_duration()
				>= 12.0,
			"Squid has a substantial observation delay."
		)

		_expect(
			not controller.is_dragging(),
			"Squid does not immediately enter drag behavior."
		)


func _test_catalog() -> void:
	var catalog: FaunaCatalogSnapshot = (
		FaunaCatalogSnapshot.create_default()
	)

	var error: String = (
		catalog.get_validation_error()
	)

	_expect(
		error.is_empty(),
		"Extended fauna catalog validates."
	)

	var species: FaunaSpeciesSnapshot = (
		catalog.get_species(
			FaunaIds.GIANT_SQUID
		)
	)

	_expect(
		species != null,
		"Giant squid species exists."
	)

	if species == null:
		return

	_expect(
		species.trophic_role
			== FaunaTypes.TrophicRole.APEX_PREDATOR,
		"Giant squid is an apex predator."
	)

	_expect(
		species.ownership_mode
			== FaunaTypes.OwnershipMode.REGIONAL_HOME,
		"Giant squid uses regional ownership."
	)

	_expect(
		species.model_mode
			== FaunaTypes.ModelMode.AUTHORED_MESH,
		"Giant squid uses one fixed mesh model."
	)


func _test_habitat_restrictions() -> void:
	_expect(
		GiantSquidRegionalSampler
			.is_habitat_eligible(
				5600.0,
				0.0001,
				0.94,
				0.91
			),
		"Lightless extreme trench habitat is accepted."
	)

	_expect(
		not GiantSquidRegionalSampler
			.is_habitat_eligible(
				800.0,
				0.0001,
				0.94,
				0.91
			),
		"Shallow habitat is rejected."
	)

	_expect(
		not GiantSquidRegionalSampler
			.is_habitat_eligible(
				5600.0,
				0.20,
				0.94,
				0.91
			),
		"Surface-lit habitat is rejected."
	)

	_expect(
		not GiantSquidRegionalSampler
			.is_habitat_eligible(
				5600.0,
				0.0001,
				0.30,
				0.91
			),
		"Deep non-trench habitat is rejected."
	)

	_expect(
		not GiantSquidRegionalSampler
			.is_habitat_eligible(
				5600.0,
				0.0001,
				0.94,
				0.20
			),
		"Non-abyssal habitat is rejected."
	)


func _test_regional_determinism() -> void:
	var test_seed: int = 915721
	var region: Vector2i = Vector2i(-4, 7)

	var first_position: Vector2 = (
		GiantSquidRegionalSampler
			.get_candidate_position(
				test_seed,
				region
			)
	)

	var second_position: Vector2 = (
		GiantSquidRegionalSampler
			.get_candidate_position(
				test_seed,
				region
			)
	)

	var first_id: int = (
		GiantSquidRegionalSampler.get_stable_id(
			test_seed,
			region
		)
	)

	var second_id: int = (
		GiantSquidRegionalSampler.get_stable_id(
			test_seed,
			region
		)
	)

	_expect(
		first_position == second_position,
		"Regional candidate position is deterministic."
	)

	_expect_equal(
		first_id,
		second_id,
		"Regional stable ID is deterministic."
	)

	var negative_region_position: Vector2 = (
		GiantSquidRegionalSampler
			.get_candidate_position(
				test_seed,
				Vector2i(-1, -1)
			)
	)

	_expect(
		negative_region_position.x < 0.0
			and negative_region_position.y < 0.0,
		"Negative regional coordinates remain negative."
	)


func _test_mesh_scale() -> void:
	GiantSquidMeshFactory.clear_cache()

	var first: ArrayMesh = (
		GiantSquidMeshFactory.create_mesh()
	)

	var second: ArrayMesh = (
		GiantSquidMeshFactory.create_mesh()
	)

	_expect(
		first != null,
		"Giant squid mesh exists."
	)

	_expect(
		first == second,
		"Giant squid reuses one cached mesh."
	)

	if first == null:
		return

	var bounds: AABB = first.get_aabb()
	var total_z_length: float = bounds.size.z

	_expect(
		total_z_length >= 48.0
			and total_z_length <= 55.0,
		"Giant squid mesh is approximately 50 meters long."
	)

	_expect_equal(
		first.get_surface_count(),
		3,
		"Mesh has body, tentacle, and eye surfaces."
	)

	_expect_equal(
		GiantSquidMeshFactory.get_tentacle_count(),
		10,
		"Mesh contains ten tentacles."
	)

	_expect(
		absf(
			GiantSquidMeshFactory.get_eye_diameter()
				- 1.6764
		) <= 0.0001,
		"Eye diameter matches a 5'6\" player."
	)


func _expect(
	condition: bool,
	description: String
) -> void:
	if condition:
		_passed += 1
		return

	_failed += 1
	push_error("FAIL: %s" % description)


func _expect_equal(
	actual: int,
	expected: int,
	description: String
) -> void:
	_expect(
		actual == expected,
		"%s Expected %d, received %d."
		% [
			description,
			expected,
			actual,
		]
	)
