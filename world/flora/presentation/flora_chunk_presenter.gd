class_name FloraChunkPresenter
extends Node3D

## Giant kelp uses one MultiMesh per represented morphology tier.
## Other species continue using one MultiMesh per species.

var _initialized: bool = false
var _flora_data: FloraChunkData

## species_id -> Array[MultiMeshInstance3D]
var _instances_by_species: Dictionary = {}

var _total_instance_count: int = 0


func initialize(
	flora_data: FloraChunkData
) -> bool:
	if _initialized:
		push_error(
			"FloraChunkPresenter can only be initialized once."
		)
		return false

	if flora_data == null:
		push_error(
			"FloraChunkPresenter requires FloraChunkData."
		)
		return false

	var validation_error := (
		flora_data.get_validation_error()
	)

	if not validation_error.is_empty():
		push_error(
			"Invalid FloraChunkData: %s"
			% validation_error
		)
		return false

	_flora_data = flora_data

	name = "FloraChunk_%d_%d" % [
		flora_data.chunk_coordinate.x,
		flora_data.chunk_coordinate.y,
	]

	position = Vector3(
		flora_data.world_origin.x,
		0.0,
		flora_data.world_origin.y
	)

	for species_id in range(FloraIds.COUNT):
		if species_id == FloraIds.GIANT_KELP:
			for tier in range(
				FloraPlacementCandidate
					.KELP_MORPHOLOGY_TIER_COUNT
			):
				if not _build_species_multimesh(
					species_id,
					tier
				):
					_clear_presented_instances()
					_flora_data = null
					return false
		else:
			if not _build_species_multimesh(
				species_id,
				-1
			):
				_clear_presented_instances()
				_flora_data = null
				return false

	_initialized = true
	return true


func is_initialized() -> bool:
	return _initialized


func set_render_allowed(
	allowed: bool
) -> void:
	visible = allowed


func set_visibility_distance(
	distance: float
) -> void:
	for instance_array_value in _instances_by_species.values():
		var instance_array := instance_array_value as Array

		for instance_value in instance_array:
			var instance := (
				instance_value as MultiMeshInstance3D
			)

			if instance != null:
				instance.visibility_range_end = maxf(
					0.0,
					distance
				)


func get_chunk_coordinate() -> Vector2i:
	if _flora_data == null:
		return Vector2i.ZERO

	return _flora_data.chunk_coordinate


func get_flora_data() -> FloraChunkData:
	return _flora_data


func get_total_instance_count() -> int:
	return _total_instance_count


func get_species_instance_count(
	species_id: int
) -> int:
	var count := 0

	for multimesh in get_species_multimeshes(species_id):
		if multimesh != null:
			count += multimesh.instance_count

	return count


## Compatibility helper. For giant kelp this returns the first represented
## morphology tier. Use get_species_instances() when every tier is needed.
func get_species_instance(
	species_id: int
) -> MultiMeshInstance3D:
	var instances := get_species_instances(species_id)

	if instances.is_empty():
		return null

	return instances[0]


func get_species_instances(
	species_id: int
) -> Array[MultiMeshInstance3D]:
	var result: Array[MultiMeshInstance3D] = []
	var stored_value: Variant = _instances_by_species.get(
		species_id,
		[]
	)

	if not stored_value is Array:
		return result

	for instance_value in stored_value:
		var instance := (
			instance_value as MultiMeshInstance3D
		)

		if instance != null:
			result.append(instance)

	return result


## Compatibility helper. Giant kelp may now have several MultiMeshes.
func get_species_multimesh(
	species_id: int
) -> MultiMesh:
	var multimeshes := get_species_multimeshes(
		species_id
	)

	if multimeshes.is_empty():
		return null

	return multimeshes[0]


func get_species_multimeshes(
	species_id: int
) -> Array[MultiMesh]:
	var result: Array[MultiMesh] = []

	for instance in get_species_instances(species_id):
		if instance.multimesh != null:
			result.append(instance.multimesh)

	return result


func get_presented_species_count() -> int:
	return _instances_by_species.size()


func _build_species_multimesh(
	species_id: int,
	morphology_tier: int
) -> bool:
	var candidate_count := _count_species_candidates(
		species_id,
		morphology_tier
	)

	if candidate_count == 0:
		return true

	var mesh: ArrayMesh = null
	var material: ShaderMaterial = null

	if species_id == FloraIds.GIANT_KELP:
		mesh = KelpProceduralMeshFactory.create_mesh(
			morphology_tier
		)

		material = FloraMaterialFactory.get_material(
			species_id,
			morphology_tier
		)
	else:
		mesh = FloraProceduralMeshFactory.create_mesh(
			species_id
		)

		material = FloraMaterialFactory.get_material(
			species_id
		)

	if mesh == null:
		push_error(
			"Missing procedural flora mesh for species %d."
			% species_id
		)
		return false

	if material == null:
		push_error(
			"Missing flora material for species %d."
			% species_id
		)
		return false

	var multimesh := MultiMesh.new()

	if species_id == FloraIds.GIANT_KELP:
		multimesh.resource_name = (
			"Giant Kelp Tier %d Chunk MultiMesh"
			% morphology_tier
		)
	else:
		multimesh.resource_name = (
			"%s Chunk MultiMesh"
			% FloraIds.get_display_name(species_id)
		)

	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	multimesh.instance_count = candidate_count
	multimesh.visible_instance_count = candidate_count

	var output_index := 0

	for candidate in _flora_data.candidates:
		if not _candidate_matches_bucket(
			candidate,
			species_id,
			morphology_tier
		):
			continue

		multimesh.set_instance_transform(
			output_index,
			_create_instance_transform(candidate)
		)

		## Custom-data contract:
		##
		## R: deterministic animation phase
		## G: kelp temperature factor for giant kelp;
		##    habitat suitability for other species
		## B: kelp depth growth factor for giant kelp;
		##    patch strength for other species
		## A: placement probability
		var green_channel := candidate.suitability
		var blue_channel := candidate.patch_strength

		if candidate.species_id == FloraIds.GIANT_KELP:
			green_channel = (
				candidate.kelp_temperature_factor
			)
			blue_channel = (
				candidate.kelp_depth_factor
			)

		multimesh.set_instance_custom_data(
			output_index,
			Color(
				StableSeed.seed_to_unit_float(
					candidate.stable_id
				),
				green_channel,
				blue_channel,
				candidate.placement_probability
			)
		)

		output_index += 1

	if output_index != candidate_count:
		push_error(
			"Flora candidate count changed while building "
			+ "species %d." % species_id
		)
		return false

	var instance := MultiMeshInstance3D.new()

	if species_id == FloraIds.GIANT_KELP:
		instance.name = (
			"GiantKelpTier%dMultiMesh"
			% morphology_tier
		)
	else:
		instance.name = (
			"%sMultiMesh"
			% _get_species_node_name(species_id)
		)

	instance.multimesh = multimesh
	instance.material_override = material
	instance.cast_shadow = (
		GeometryInstance3D
		.SHADOW_CASTING_SETTING_OFF
	)

	instance.set_meta(
		"flora_species_id",
		species_id
	)

	if species_id == FloraIds.GIANT_KELP:
		instance.set_meta(
			"kelp_morphology_tier",
			morphology_tier
		)

	add_child(instance)

	var species_instances: Array = (
		_instances_by_species.get(
			species_id,
			[]
		)
	)

	species_instances.append(instance)
	_instances_by_species[species_id] = species_instances

	_total_instance_count += candidate_count
	return true


func _count_species_candidates(
	species_id: int,
	morphology_tier: int
) -> int:
	var count := 0

	for candidate in _flora_data.candidates:
		if _candidate_matches_bucket(
			candidate,
			species_id,
			morphology_tier
		):
			count += 1

	return count


static func _candidate_matches_bucket(
	candidate: FloraPlacementCandidate,
	species_id: int,
	morphology_tier: int
) -> bool:
	if candidate == null:
		return false

	if candidate.species_id != species_id:
		return false

	if species_id != FloraIds.GIANT_KELP:
		return true

	return (
		candidate.kelp_morphology_tier
		== morphology_tier
	)


func _create_instance_transform(
	candidate: FloraPlacementCandidate
) -> Transform3D:
	var orientation := Basis.IDENTITY

	if candidate.align_to_surface:
		orientation = _create_surface_basis(
			candidate.surface_normal
		)

		orientation = (
			orientation
			* Basis(
				Vector3.UP,
				candidate.yaw_radians
			)
		)
	else:
		orientation = Basis(
			Vector3.UP,
			candidate.yaw_radians
		)

	## Giant kelp receives all dimensions from its generated morphology
	## mesh. It is deliberately never scaled by its instance transform.
	if candidate.species_id != FloraIds.GIANT_KELP:
		orientation = orientation.scaled(
			Vector3.ONE * candidate.uniform_scale
		)

	var local_position := Vector3(
		candidate.world_position.x
			- _flora_data.world_origin.x,
		candidate.world_position.y,
		candidate.world_position.z
			- _flora_data.world_origin.y
	)

	return Transform3D(
		orientation,
		local_position
	)


static func _create_surface_basis(
	surface_normal: Vector3
) -> Basis:
	var up := surface_normal

	if up.is_zero_approx():
		up = Vector3.UP
	else:
		up = up.normalized()

	if up.y < 0.0:
		up = -up

	var x_axis := (
		Vector3.RIGHT
		- up * Vector3.RIGHT.dot(up)
	)

	if x_axis.is_zero_approx():
		x_axis = (
			Vector3.FORWARD
			- up * Vector3.FORWARD.dot(up)
		)

	if x_axis.is_zero_approx():
		return Basis.IDENTITY

	x_axis = x_axis.normalized()

	var z_axis := x_axis.cross(up).normalized()

	return Basis(
		x_axis,
		up,
		z_axis
	)


static func _get_species_node_name(
	species_id: int
) -> String:
	match species_id:
		FloraIds.GIANT_KELP:
			return "GiantKelp"

		FloraIds.SEAGRASS:
			return "Seagrass"

		FloraIds.REEF_MACROALGAE:
			return "ReefMacroalgae"

		FloraIds.RED_FAN_ALGAE:
			return "RedFanAlgae"

		FloraIds.CORALLINE_ALGAE:
			return "CorallineAlgae"

		_:
			return "UnknownFlora"


func _clear_presented_instances() -> void:
	for instance_array_value in _instances_by_species.values():
		var instance_array := instance_array_value as Array

		for instance_value in instance_array:
			var instance := (
				instance_value as MultiMeshInstance3D
			)

			if instance == null:
				continue

			if instance.get_parent() == self:
				remove_child(instance)

			instance.free()

	_instances_by_species.clear()
	_total_instance_count = 0
