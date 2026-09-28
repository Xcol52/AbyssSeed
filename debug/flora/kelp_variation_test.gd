extends Node3D

const TIER_COUNT: int = (
	FloraPlacementCandidate.KELP_MORPHOLOGY_TIER_COUNT
)

const X_SPACING: float = 4.5
const HEIGHT_ROW_Z: float = 1.5
const TEMPERATURE_ROW_Z: float = -6.5

@onready var _camera: Camera3D = $Camera3D
@onready var _status_label: Label = (
	$CanvasLayer/MarginContainer/StatusLabel
)


func _ready() -> void:
	_camera.look_at(
		Vector3(0.0, 5.0, -2.5),
		Vector3.UP
	)

	_run_test()


func _run_test() -> void:
	## Clear both caches so this test cannot display meshes or materials
	## retained from before the morphology update.
	KelpProceduralMeshFactory.clear_cache()
	FloraMaterialFactory.clear_cache()

	var report: Array[String] = []

	report.append("Kelp morphology and temperature test")
	report.append("")
	report.append(
		"Front row: tiers 0-%d, all at temperature 0.5."
		% (TIER_COUNT - 1)
	)
	report.append(
		"Every plant should be taller and broader than the one "
		+ "to its left."
	)
	report.append("")
	report.append(
		"Back row: one fixed morphology tier, depth factors 0.0-1.0."
	)
	report.append(
		"Color should move from dark green at 250 m on the left to "
		+ "bright green/yellow at 20 m on the right."
	)
	report.append("")

	var all_heights_increase := true
	var previous_height := -INF

	for tier in range(TIER_COUNT):
		var mesh := (
			KelpProceduralMeshFactory.create_mesh(tier)
		)

		var material := (
			FloraMaterialFactory.get_material(
				FloraIds.GIANT_KELP,
				tier
			)
		)

		if mesh == null:
			all_heights_increase = false
			report.append(
				"ERROR: tier %d returned no mesh." % tier
			)
			continue

		if material == null:
			all_heights_increase = false
			report.append(
				"ERROR: tier %d returned no material." % tier
			)
			continue

		var actual_height := mesh.get_aabb().size.y
		var nominal_height := (
			KelpProceduralMeshFactory.get_nominal_height(
				tier
			)
		)

		if (
			tier > 0
			and actual_height
				<= previous_height + 0.001
		):
			all_heights_increase = false

		previous_height = actual_height

		report.append(
			(
				"Tier %d: segments=%d, nominal=%.2f m, "
				+ "mesh AABB=%.2f m"
			)
			% [
				tier,
				KelpProceduralMeshFactory.get_segment_count(
					tier
				),
				nominal_height,
				actual_height,
			]
		)

		var x_position := _get_x_position(tier)

		_create_single_instance(
			"HeightTier%d" % tier,
			mesh,
			material,
			Vector3(
				x_position,
				0.0,
				HEIGHT_ROW_Z
			),
			0.5,
			float(tier) / maxf(
				float(TIER_COUNT - 1),
				1.0
			)
		)

	var color_test_tier := clampi(
		TIER_COUNT / 2,
		0,
		TIER_COUNT - 1
	)

	var color_mesh := (
		KelpProceduralMeshFactory.create_mesh(
			color_test_tier
		)
	)

	var color_material := (
		FloraMaterialFactory.get_material(
			FloraIds.GIANT_KELP,
			color_test_tier
		)
	)

	if color_mesh == null or color_material == null:
		report.append("")
		report.append(
			"ERROR: the temperature test could not create "
			+ "its mesh or material."
		)
	else:
		_create_temperature_row(
			color_mesh,
			color_material
		)

		var strength_value: Variant = (
			color_material.get_shader_parameter(
				"temperature_color_strength"
			)
		)

		if strength_value == null:
			report.append("")
			report.append(
				"ERROR: temperature_color_strength is absent "
				+ "from the active shader."
			)
		else:
			var strength := float(strength_value)

			report.append("")
			report.append(
				"Temperature color strength: %.3f"
				% strength
			)

			if strength <= 0.0:
				report.append(
					"ERROR: temperature coloring is disabled "
					+ "on the giant-kelp material."
				)

	report.append("")

	if all_heights_increase:
		report.append(
			"PASS: every kelp mesh tier has increasing height."
		)
	else:
		report.append(
			"FAIL: one or more kelp mesh tiers did not "
			+ "increase in height."
		)

	report.append(
		"Color must be checked visually in the back row."
	)

	_status_label.text = "\n".join(report)

	for line in report:
		print(line)


func _create_single_instance(
	node_name: String,
	mesh: ArrayMesh,
	material: ShaderMaterial,
	world_position: Vector3,
	temperature_factor: float,
	animation_phase: float
) -> void:
	var multimesh := MultiMesh.new()

	## These options must be configured before instance_count.
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	multimesh.instance_count = 1
	multimesh.visible_instance_count = 1

	multimesh.set_instance_transform(
		0,
		Transform3D(
			Basis.IDENTITY,
			world_position
		)
	)

	multimesh.set_instance_custom_data(
		0,
		Color(
			clampf(animation_phase, 0.0, 1.0),
			clampf(temperature_factor, 0.0, 1.0),
			0.0,
			1.0
		)
	)

	var instance := MultiMeshInstance3D.new()

	instance.name = node_name
	instance.multimesh = multimesh
	instance.material_override = material
	instance.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	)

	add_child(instance)


func _create_temperature_row(
	mesh: ArrayMesh,
	material: ShaderMaterial
) -> void:
	var multimesh := MultiMesh.new()

	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	multimesh.instance_count = TIER_COUNT
	multimesh.visible_instance_count = TIER_COUNT

	for index in range(TIER_COUNT):
		var factor := (
			float(index)
			/ maxf(
				float(TIER_COUNT - 1),
				1.0
			)
		)

		multimesh.set_instance_transform(
			index,
			Transform3D(
				Basis.IDENTITY,
				Vector3(
					_get_x_position(index),
					0.0,
					TEMPERATURE_ROW_Z
				)
			)
		)

		## R is sway phase. B is normalized depth growth.
		multimesh.set_instance_custom_data(
			index,
			Color(
				factor,
				0.5,
				factor,
				1.0
			)
		)

	var instance := MultiMeshInstance3D.new()

	instance.name = "TemperatureVariationRow"
	instance.multimesh = multimesh
	instance.material_override = material
	instance.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	)

	add_child(instance)


func _get_x_position(
	index: int
) -> float:
	return (
		(
			float(index)
			- float(TIER_COUNT - 1) * 0.5
		)
		* X_SPACING
	)
