extends Node

var _passed: int = 0
var _failed: int = 0

@onready var _observer: Node3D = %Observer
@onready var _presentation_root: Node3D = %PresentationRoot
@onready var _coordinator: FaunaCoordinator = %FaunaCoordinator


func _ready() -> void:
	await _run_tests()

	print("")
	print(
		"Session 11 Stage 11A fauna tests: "
		+ "%d passed, %d failed"
		% [_passed, _failed]
	)

	get_tree().quit(_failed)


func _run_tests() -> void:
	var catalog := FaunaCatalogSnapshot.create_default()

	_test_catalog(catalog)
	_test_procedural_mesh_cache(catalog)

	if _failed > 0:
		return

	var initialized := _coordinator.initialize(
		_observer,
		_presentation_root,
		catalog,
		0.0,
		Callable()
	)

	_expect(
		initialized,
		"FaunaCoordinator initializes with valid dependencies."
	)

	if not initialized:
		return

	var fauna_data := _create_synthetic_fauna_data()

	_expect(
		fauna_data.get_validation_error().is_empty(),
		"Synthetic FaunaChunkData validates."
	)

	var registered := _coordinator.register_chunk_data(
		fauna_data
	)

	_expect(
		registered,
		"Valid fauna descriptor data registers."
	)

	_expect_equal(
		_coordinator.get_descriptor_count(),
		3,
		"All three population descriptors are retained."
	)

	## Wait for activation and at least one simulation/presentation pass.
	await get_tree().create_timer(0.40).timeout

	_expect_equal(
		_coordinator.get_active_school_count(),
		1,
		"One aggregate baitfish school activates."
	)

	_expect(
		_coordinator.get_active_individual_count() >= 2,
		"Individual herbivores and predators activate."
	)

	_expect(
		_presentation_root.get_child_count() > 0,
		"Active fauna creates presentation beneath "
		+ "DynamicEntitiesRoot equivalent."
	)

	var school_matches := (
		_coordinator.query_school_populations_in_sphere(
			Vector3(60.0, -20.0, 60.0),
			10.0
		)
	)

	_expect(
		school_matches.has(1001),
		"Aggregate school collision queries return "
		+ "the stable population ID."
	)

	_coordinator.unregister_chunk_data(
		Vector2i.ZERO
	)

	await get_tree().process_frame
	await get_tree().process_frame

	_expect_equal(
		_coordinator.get_descriptor_count(),
		0,
		"Unregistering a chunk removes its descriptors."
	)

	_expect_equal(
		_coordinator.get_active_school_count(),
		0,
		"Unregistering a chunk removes its active school."
	)

	_expect_equal(
		_coordinator.get_active_individual_count(),
		0,
		"Unregistering a chunk removes its active individuals."
	)


func _test_catalog(
	catalog: FaunaCatalogSnapshot
) -> void:
	_expect(
		catalog != null,
		"Default fauna catalog exists."
	)

	if catalog == null:
		return

	var error: String = catalog.get_validation_error()

	_expect(
		error.is_empty(),
		"Default fauna catalog validates."
	)

	_expect_equal(
		catalog.species.size(),
		FaunaIds.COUNT,
		"Default catalog contains every fauna species."
	)

	var baitfish := catalog.get_species(
		FaunaIds.SHELF_BAITFISH
	)

	var grazer := catalog.get_species(
		FaunaIds.KELP_GRAZER
	)

	var hunter := catalog.get_species(
		FaunaIds.REEF_HUNTER
	)

	_expect(
		baitfish != null
		and baitfish.presentation_mode
			== FaunaTypes.PresentationMode.SCHOOL_AGGREGATE,
		"Baitfish use aggregate-school presentation."
	)

	_expect(
		baitfish != null
		and baitfish.trophic_role
			== FaunaTypes.TrophicRole.HERBIVORE,
		"Baitfish presentation mode and trophic role "
		+ "remain independent."
	)

	_expect(
		grazer != null
		and grazer.presentation_mode
			== FaunaTypes.PresentationMode.INDIVIDUAL
		and grazer.trophic_role
			== FaunaTypes.TrophicRole.HERBIVORE,
		"Kelp grazers are individual herbivores."
	)

	_expect(
		hunter != null
		and hunter.presentation_mode
			== FaunaTypes.PresentationMode.INDIVIDUAL
		and hunter.trophic_role
			== FaunaTypes.TrophicRole.PREDATOR,
		"Reef hunters are individual predators."
	)

	_expect(
		baitfish != null
		and is_equal_approx(
			baitfish.body_length,
			0.1524
		),
		"Baitfish length is approximately half a foot."
	)


func _test_procedural_mesh_cache(
	catalog: FaunaCatalogSnapshot
) -> void:
	FaunaProceduralMeshFactory.clear_cache()

	var all_meshes_valid := true
	var cache_is_stable := true

	for species_id in range(FaunaIds.COUNT):
		var species := catalog.get_species(species_id)

		if species == null:
			all_meshes_valid = false
			continue

		for variant in range(
			species.procedural_variant_count
		):
			var first := (
				FaunaProceduralMeshFactory.create_mesh(
					species,
					variant
				)
			)

			var second := (
				FaunaProceduralMeshFactory.create_mesh(
					species,
					variant
				)
			)

			if (
				first == null
				or first.get_surface_count() < 1
				or first.get_aabb().size.length()
					<= 0.0
			):
				all_meshes_valid = false

			if first != second:
				cache_is_stable = false

	_expect(
		all_meshes_valid,
		"Every bounded procedural fish variant "
		+ "contains valid geometry."
	)

	_expect(
		cache_is_stable,
		"Repeated variant requests reuse cached meshes."
	)


func _create_synthetic_fauna_data() -> FaunaChunkData:
	var populations: Array[FaunaPopulationDescriptor] = []

	populations.append(
		FaunaPopulationDescriptor.new(
			1001,
			FaunaIds.SHELF_BAITFISH,
			Vector2i(0, 0),
			Vector2i.ZERO,
			Vector3(60.0, -20.0, 60.0),
			80,
			8.0,
			30.0,
			40.0,
			0.85,
			0.90,
			0.80,
			0.0,
			2001,
			FaunaTypes.OwnershipMode.CHUNK_HOME
		)
	)

	populations.append(
		FaunaPopulationDescriptor.new(
			1002,
			FaunaIds.KELP_GRAZER,
			Vector2i(1, 0),
			Vector2i.ZERO,
			Vector3(82.0, -16.0, 66.0),
			5,
			1.5,
			11.0,
			27.0,
			0.78,
			0.82,
			0.74,
			0.8,
			2002,
			FaunaTypes.OwnershipMode.CHUNK_HOME
		)
	)

	populations.append(
		FaunaPopulationDescriptor.new(
			1003,
			FaunaIds.REEF_HUNTER,
			Vector2i(2, 0),
			Vector2i.ZERO,
			Vector3(110.0, -18.0, 80.0),
			2,
			4.0,
			24.0,
			75.0,
			0.73,
			0.76,
			0.68,
			1.7,
			2003,
			FaunaTypes.OwnershipMode.CHUNK_HOME
		)
	)

	return FaunaChunkData.new(
		Vector2i.ZERO,
		Vector2.ZERO,
		256.0,
		populations
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
		"FAIL: %s"
		% description
	)


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
