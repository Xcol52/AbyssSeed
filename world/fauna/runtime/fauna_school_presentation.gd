class_name FaunaSchoolPresentation
extends Node3D

var _descriptor: FaunaPopulationDescriptor
var _species: FaunaSpeciesSnapshot
var _instance: MultiMeshInstance3D
var _member_local_transforms: Array[Transform3D] = []


func initialize(
	descriptor: FaunaPopulationDescriptor,
	species: FaunaSpeciesSnapshot
) -> bool:
	if descriptor == null or species == null:
		return false

	if (
		species.presentation_mode
		!= FaunaTypes.PresentationMode.SCHOOL_AGGREGATE
	):
		return false

	_descriptor = descriptor
	_species = species

	name = (
		"School_%s_%d"
		% [species.display_name, descriptor.stable_id]
	)

	var variant := _positive_mod(
		descriptor.stable_id,
		species.procedural_variant_count
	)

	var mesh := FaunaProceduralMeshFactory.create_mesh(
		species,
		variant
	)

	var material := FaunaMaterialFactory.get_material(
		species
	)

	if mesh == null or material == null:
		return false

	var visual_count := mini(
		descriptor.initial_population,
		species.maximum_representatives
	)

	var multimesh := MultiMesh.new()

	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	multimesh.instance_count = visual_count
	multimesh.visible_instance_count = visual_count

	var school_width := descriptor.home_radius * 0.16
	var school_length := descriptor.home_radius * 0.28
	var vertical_radius := maxf(
		descriptor.home_radius * 0.08,
		0.5
	)
	var member_positions := _generate_poisson_positions(
		descriptor,
		visual_count,
		school_width,
		vertical_radius,
		school_length
	)
	_member_local_transforms.clear()

	for member_index in range(visual_count):
		var member_seed := StableSeed.derive_channel_seed(
			descriptor.behavior_seed,
			1000 + member_index
		)
		var local_position: Vector3 = member_positions[member_index]

		var local_yaw := (
			StableSeed.seed_to_unit_float(
				StableSeed.derive_channel_seed(
					member_seed,
					4
				)
			) - 0.5
		) * 0.46

		var scale_factor := lerpf(
			2.40,
			3.20,
			StableSeed.seed_to_unit_float(
				StableSeed.derive_channel_seed(
					member_seed,
					5
				)
			)
		)

		var instance_basis := Basis(
			Vector3.UP,
			local_yaw
		).scaled(
			Vector3.ONE * scale_factor
		)

		var local_transform := Transform3D(
			instance_basis,
			local_position
		)
		_member_local_transforms.append(local_transform)
		multimesh.set_instance_transform(member_index, local_transform)

		multimesh.set_instance_custom_data(
			member_index,
			Color(
				StableSeed.seed_to_unit_float(
					member_seed
				),
				StableSeed.seed_to_unit_float(
					StableSeed.derive_channel_seed(
						member_seed,
						6
					)
				),
				lerpf(
					0.75,
					1.20,
					StableSeed.seed_to_unit_float(
						StableSeed.derive_channel_seed(
							member_seed,
							7
						)
					)
				),
				1.0
			)
		)

	multimesh.custom_aabb = AABB(
		Vector3(
			-school_width - 1.0,
			-vertical_radius - 1.0,
			-school_length - 1.0
		),
		Vector3(
			school_width * 2.0 + 2.0,
			vertical_radius * 2.0 + 2.0,
			school_length * 2.0 + 2.0
		)
	)

	_instance = MultiMeshInstance3D.new()
	_instance.name = "SchoolMultiMesh"
	_instance.multimesh = multimesh
	_instance.material_override = material
	_instance.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)

	add_child(_instance)

	position = descriptor.home_position
	return true


static func _generate_poisson_positions(
	descriptor: FaunaPopulationDescriptor,
	count: int,
	width: float,
	height: float,
	length: float
) -> Array[Vector3]:
	var positions: Array[Vector3] = []

	if count <= 0:
		return positions

	var ellipsoid_volume := (
		4.0 / 3.0
		* PI
		* width
		* height
		* length
	)
	var spacing := maxf(
		descriptor.home_radius * 0.012,
		pow(ellipsoid_volume / float(count), 1.0 / 3.0)
			* 0.56
	)
	var maximum_attempts := count * 140

	for attempt in range(maximum_attempts):
		var candidate_seed := StableSeed.derive_channel_seed(
			descriptor.behavior_seed,
			200000 + attempt * 3
		)
		var candidate := Vector3(
			StableSeed.seed_to_unit_float(candidate_seed) * 2.0 - 1.0,
			StableSeed.seed_to_unit_float(
				StableSeed.derive_channel_seed(candidate_seed, 1)
			) * 2.0 - 1.0,
			StableSeed.seed_to_unit_float(
				StableSeed.derive_channel_seed(candidate_seed, 2)
			) * 2.0 - 1.0
		)

		if (
			candidate.x * candidate.x
			+ candidate.y * candidate.y
			+ candidate.z * candidate.z
			> 1.0
		):
			continue

		var local_position := Vector3(
			candidate.x * width,
			candidate.y * height,
			candidate.z * length
		)
		var has_neighbor := false

		for existing_position in positions:
			if existing_position.distance_to(local_position) < spacing:
				has_neighbor = true
				break

		if has_neighbor:
			continue

		positions.append(local_position)

		if positions.size() >= count:
			break

	## A deterministic fallback keeps the representative count stable if
	## the requested population is dense for the selected school volume.
	for fallback_index in range(positions.size(), count):
		var fallback_seed := StableSeed.derive_channel_seed(
			descriptor.behavior_seed,
			300000 + fallback_index * 3
		)
		positions.append(Vector3(
			(
				StableSeed.seed_to_unit_float(fallback_seed)
				* 2.0 - 1.0
			) * width * 0.92,
			(
				StableSeed.seed_to_unit_float(
					StableSeed.derive_channel_seed(fallback_seed, 1)
				) * 2.0 - 1.0
			) * height * 0.92,
			(
				StableSeed.seed_to_unit_float(
					StableSeed.derive_channel_seed(fallback_seed, 2)
				) * 2.0 - 1.0
			) * length * 0.92
		))

	return positions


func apply_runtime_transform(
	world_position: Vector3,
	forward: Vector3
) -> void:
	position = world_position
	basis = Basis.IDENTITY

	if _instance == null or _instance.multimesh == null:
		return

	var heading_basis := _basis_from_forward(forward)
	for member_index in range(_member_local_transforms.size()):
		var local_transform := _member_local_transforms[member_index]
		_instance.multimesh.set_instance_transform(
			member_index,
			Transform3D(
				heading_basis * local_transform.basis,
				local_transform.origin
			)
		)


func get_population_id() -> int:
	if _descriptor == null:
		return 0

	return _descriptor.stable_id


static func _basis_from_forward(
	forward: Vector3
) -> Basis:
	var direction := forward

	if direction.is_zero_approx():
		direction = Vector3.FORWARD
	else:
		direction = direction.normalized()

	## Fish model forward is negative Z.
	var z_axis := -direction
	var y_axis := Vector3.UP

	if absf(z_axis.dot(y_axis)) > 0.98:
		y_axis = Vector3.FORWARD

	var x_axis := y_axis.cross(z_axis).normalized()
	y_axis = z_axis.cross(x_axis).normalized()

	return Basis(
		x_axis,
		y_axis,
		z_axis
	)


static func _positive_mod(
	value: int,
	divisor: int
) -> int:
	if divisor <= 0:
		return 0

	var result := value % divisor

	if result < 0:
		result += divisor

	return result
