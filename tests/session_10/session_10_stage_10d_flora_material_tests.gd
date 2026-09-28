extends Node

const EPSILON: float = 0.0001

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	FloraMaterialFactory.clear_cache()
	FloraProceduralMeshFactory.clear_cache()

	_test_material_creation()
	_test_material_sharing()
	_test_mesh_material_assignment()
	_test_species_parameters()
	_test_sway_toggle()
	_test_current_direction()
	_test_coralline_is_nearly_static()
	_test_invalid_species()

	print("")
	print(
		"Session 10 Stage 10D flora material tests: "
		+ "%d passed, %d failed"
		% [_passed, _failed]
	)

	get_tree().quit(_failed)


func _test_material_creation() -> void:
	var all_valid := true

	for species_id in range(FloraIds.COUNT):
		var material := (
			FloraMaterialFactory.get_material(
				species_id
			)
		)

		if material == null:
			all_valid = false
			break

		if material.shader == null:
			all_valid = false
			break

		if material.shader.resource_path != (
			"res://world/flora/presentation/"
			+ "shaders/flora_sway.gdshader"
		):
			all_valid = false
			break

	_expect(
		all_valid,
		"Every flora species has a sway shader material."
	)


func _test_material_sharing() -> void:
	var sharing_valid := true

	for species_id in range(FloraIds.COUNT):
		var first := (
			FloraMaterialFactory.get_material(
				species_id
			)
		)

		var second := (
			FloraMaterialFactory.get_material(
				species_id
			)
		)

		if first == null or first != second:
			sharing_valid = false
			break

	_expect(
		sharing_valid,
		"Each species reuses one shared material."
	)


func _test_mesh_material_assignment() -> void:
	var assignments_valid := true

	for species_id in range(FloraIds.COUNT):
		var mesh := (
			FloraProceduralMeshFactory.create_mesh(
				species_id
			)
		)

		var expected_material := (
			FloraMaterialFactory.get_material(
				species_id
			)
		)

		if mesh == null or expected_material == null:
			assignments_valid = false
			break

		var actual_material := (
			mesh.surface_get_material(0)
		)

		if actual_material != expected_material:
			assignments_valid = false
			break

	_expect(
		assignments_valid,
		"Procedural meshes use their shared species materials."
	)


func _test_species_parameters() -> void:
	var parameters_valid := true

	for species_id in range(FloraIds.COUNT):
		var material := (
			FloraMaterialFactory.get_material(
				species_id
			)
		)

		if material == null:
			parameters_valid = false
			break

		var sway_strength := float(
			material.get_shader_parameter(
				"sway_strength"
			)
		)

		var sway_speed := float(
			material.get_shader_parameter(
				"sway_speed"
			)
		)

		var model_height := float(
			material.get_shader_parameter(
				"model_height"
			)
		)

		var roughness := float(
			material.get_shader_parameter(
				"roughness"
			)
		)

		if (
			sway_strength < 0.0
			or sway_speed < 0.0
			or model_height <= 0.0
			or roughness < 0.0
			or roughness > 1.0
		):
			parameters_valid = false
			break

		if not is_equal_approx(
			model_height,
			FloraProceduralMeshFactory
				.get_nominal_height(species_id)
		):
			parameters_valid = false
			break

	_expect(
		parameters_valid,
		"Species shader parameters are valid."
	)


func _test_sway_toggle() -> void:
	FloraMaterialFactory.set_sway_enabled(false)

	var disabled_valid := true

	for species_id in range(FloraIds.COUNT):
		var material := (
			FloraMaterialFactory.get_material(
				species_id
			)
		)

		var value := float(
			material.get_shader_parameter(
				"sway_enabled"
			)
		)

		if absf(value) > EPSILON:
			disabled_valid = false
			break

	_expect(
		disabled_valid,
		"Sway can be disabled for all shared materials."
	)

	FloraMaterialFactory.set_sway_enabled(true)

	var enabled_valid := true

	for species_id in range(FloraIds.COUNT):
		var material := (
			FloraMaterialFactory.get_material(
				species_id
			)
		)

		var value := float(
			material.get_shader_parameter(
				"sway_enabled"
			)
		)

		if absf(value - 1.0) > EPSILON:
			enabled_valid = false
			break

	_expect(
		enabled_valid,
		"Sway can be enabled for all shared materials."
	)


func _test_current_direction() -> void:
	var requested := Vector2(
		-0.4,
		0.8
	).normalized()

	FloraMaterialFactory.set_current_direction(
		requested
	)

	var direction_valid := true

	for species_id in range(FloraIds.COUNT):
		var material := (
			FloraMaterialFactory.get_material(
				species_id
			)
		)

		var actual := (
			material.get_shader_parameter(
				"current_direction"
			) as Vector2
		)

		if not actual.is_equal_approx(requested):
			direction_valid = false
			break

	_expect(
		direction_valid,
		"Current direction updates every shared material."
	)

	FloraMaterialFactory.set_current_direction(
		Vector2(1.0, 0.25)
	)


func _test_coralline_is_nearly_static() -> void:
	var kelp_strength := (
		FloraMaterialFactory.get_sway_strength(
			FloraIds.GIANT_KELP
		)
	)

	var coralline_strength := (
		FloraMaterialFactory.get_sway_strength(
			FloraIds.CORALLINE_ALGAE
		)
	)

	_expect(
		coralline_strength
			< kelp_strength * 0.05,
		"Coralline algae is nearly static compared with kelp."
	)


func _test_invalid_species() -> void:
	_expect(
		FloraMaterialFactory.get_material(-1) == null
			and FloraMaterialFactory.get_material(
				FloraIds.COUNT
			) == null,
		"Invalid flora IDs do not produce materials."
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
