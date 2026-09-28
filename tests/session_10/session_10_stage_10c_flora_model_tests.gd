extends Node

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	FloraProceduralMeshFactory.clear_cache()

	_test_every_species_has_a_mesh()
	_test_mesh_geometry()
	_test_ground_level_pivots()
	_test_materials()
	_test_deterministic_cache()
	_test_invalid_species()

	print("")
	print(
		"Session 10 Stage 10C flora model tests: "
		+ "%d passed, %d failed"
		% [_passed, _failed]
	)

	get_tree().quit(_failed)


func _test_every_species_has_a_mesh() -> void:
	var all_present := true

	for species_id in range(FloraIds.COUNT):
		var mesh := (
			FloraProceduralMeshFactory.create_mesh(
				species_id
			)
		)

		if mesh == null:
			all_present = false
			break

	_expect(
		all_present,
		"Every flora species has a procedural mesh."
	)


func _test_mesh_geometry() -> void:
	var geometry_valid := true

	for species_id in range(FloraIds.COUNT):
		var mesh := (
			FloraProceduralMeshFactory.create_mesh(
				species_id
			)
		)

		if mesh == null or mesh.get_surface_count() != 1:
			geometry_valid = false
			break

		var arrays := mesh.surface_get_arrays(0)

		if arrays.size() <= Mesh.ARRAY_VERTEX:
			geometry_valid = false
			break

		var vertices := (
			arrays[Mesh.ARRAY_VERTEX]
			as PackedVector3Array
		)

		if vertices.size() < 18:
			geometry_valid = false
			break

		if vertices.size() % 3 != 0:
			geometry_valid = false
			break

	_expect(
		geometry_valid,
		"Every flora mesh contains triangle geometry."
	)


func _test_ground_level_pivots() -> void:
	var pivots_valid := true

	for species_id in range(FloraIds.COUNT):
		var mesh := (
			FloraProceduralMeshFactory.create_mesh(
				species_id
			)
		)

		if mesh == null:
			pivots_valid = false
			break

		var bounds := mesh.get_aabb()
		var minimum_y := bounds.position.y
		var maximum_y := (
			bounds.position.y
			+ bounds.size.y
		)

		if minimum_y < -0.02 or minimum_y > 0.10:
			pivots_valid = false
			break

		if maximum_y <= 0.05:
			pivots_valid = false
			break

	_expect(
		pivots_valid,
		"Flora meshes use ground-level pivots."
	)


func _test_materials() -> void:
	var materials_valid := true

	for species_id in range(FloraIds.COUNT):
		var mesh := (
			FloraProceduralMeshFactory.create_mesh(
				species_id
			)
		)

		if mesh == null:
			materials_valid = false
			break

		var material := mesh.surface_get_material(0)
		var standard := material as StandardMaterial3D

		if standard == null:
			materials_valid = false
			break

		if not standard.vertex_color_use_as_albedo:
			materials_valid = false
			break

		if (
			standard.cull_mode
			!= BaseMaterial3D.CULL_DISABLED
		):
			materials_valid = false
			break

	_expect(
		materials_valid,
		"Flora meshes use two-sided vertex-color materials."
	)


func _test_deterministic_cache() -> void:
	var cache_valid := true

	for species_id in range(FloraIds.COUNT):
		var first := (
			FloraProceduralMeshFactory.create_mesh(
				species_id
			)
		)

		var second := (
			FloraProceduralMeshFactory.create_mesh(
				species_id
			)
		)

		if first == null or second == null:
			cache_valid = false
			break

		if first != second:
			cache_valid = false
			break

	_expect(
		cache_valid,
		"Repeated model requests reuse deterministic meshes."
	)


func _test_invalid_species() -> void:
	_expect(
		FloraProceduralMeshFactory.create_mesh(-1) == null
			and FloraProceduralMeshFactory.create_mesh(
				FloraIds.COUNT
			) == null,
		"Invalid flora IDs do not produce meshes."
	)


func _expect(
	condition: bool,
	description: String
) -> void:
	if condition:
		_passed += 1
		return

	_failed += 1
	printerr("FAILED: %s" % description)
