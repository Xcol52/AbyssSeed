extends Node

const INSTANCES_PER_SPECIES: int = 3
const TEST_CHUNK_SIZE: float = 64.0
const EPSILON: float = 0.0001

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	FloraMaterialFactory.clear_cache()
	FloraProceduralMeshFactory.clear_cache()

	_test_presenter_creation()
	_test_species_grouping()
	_test_local_positions()
	_test_surface_alignment()
	_test_upright_alignment()
	_test_custom_data()
	_test_shared_resources()
	_test_empty_chunk()
	_test_reinitialization_rejected()

	print("")
	print(
		"Session 10 Stage 10E flora MultiMesh tests: "
		+ "%d passed, %d failed"
		% [_passed, _failed]
	)

	get_tree().quit(_failed)


func _test_presenter_creation() -> void:
	var presenter := _create_initialized_presenter()

	_expect(
		presenter != null
			and presenter.is_initialized(),
		"FloraChunkPresenter initializes from valid flora data."
	)

	if presenter == null:
		return

	_expect(
		presenter.get_total_instance_count()
			== FloraIds.COUNT
				* INSTANCES_PER_SPECIES,
		"Presenter includes every flora candidate."
	)

	presenter.free()


func _test_species_grouping() -> void:
	var presenter := _create_initialized_presenter()

	if presenter == null:
		_expect(
			false,
			"Species-grouping presenter was created."
		)
		return

	var grouping_valid := (
		presenter.get_presented_species_count()
		== FloraIds.COUNT
	)

	if grouping_valid:
		for species_id in range(FloraIds.COUNT):
			if (
				presenter.get_species_instance_count(
					species_id
				)
				!= INSTANCES_PER_SPECIES
			):
				grouping_valid = false
				break

	_expect(
		grouping_valid,
		"Candidates are grouped into one MultiMesh per species."
	)

	_expect(
		presenter.get_child_count()
			== FloraIds.COUNT,
		"Presenter creates no per-plant child Nodes."
	)

	presenter.free()


func _test_local_positions() -> void:
	var data := _create_flora_data()
	var presenter := FloraChunkPresenter.new()

	add_child(presenter)

	var initialized := presenter.initialize(data)

	var positions_valid := initialized

	if initialized:
		var candidate := data.candidates[0]

		var multimesh := (
			presenter.get_species_multimesh(
				candidate.species_id
			)
		)

		if multimesh == null:
			positions_valid = false
		else:
			var transform := (
				multimesh.get_instance_transform(0)
			)

			var expected := Vector3(
				candidate.world_position.x
					- data.world_origin.x,
				candidate.world_position.y,
				candidate.world_position.z
					- data.world_origin.y
			)

			positions_valid = (
				transform.origin.is_equal_approx(
					expected
				)
			)

	_expect(
		positions_valid,
		"World-space candidates become chunk-local transforms."
	)

	_expect(
		presenter.position.is_equal_approx(
			Vector3(
				data.world_origin.x,
				0.0,
				data.world_origin.y
			)
		),
		"Presenter is positioned at the flora chunk origin."
	)

	presenter.free()


func _test_surface_alignment() -> void:
	var data := _create_flora_data()
	var presenter := FloraChunkPresenter.new()

	add_child(presenter)

	var initialized := presenter.initialize(data)
	var alignment_valid := initialized

	if initialized:
		var candidate := _find_candidate(
			data,
			FloraIds.SEAGRASS,
			0
		)

		var multimesh := (
			presenter.get_species_multimesh(
				FloraIds.SEAGRASS
			)
		)

		if candidate == null or multimesh == null:
			alignment_valid = false
		else:
			var transform := (
				multimesh.get_instance_transform(0)
			)

			var transformed_up := (
				transform.basis.y.normalized()
			)

			alignment_valid = (
				transformed_up.dot(
					candidate.surface_normal
				) > 0.9999
			)

	_expect(
		alignment_valid,
		"Surface-aligned flora follows the candidate normal."
	)

	presenter.free()


func _test_upright_alignment() -> void:
	var data := _create_flora_data()
	var presenter := FloraChunkPresenter.new()

	add_child(presenter)

	var initialized := presenter.initialize(data)
	var upright_valid := initialized

	if initialized:
		var multimesh := (
			presenter.get_species_multimesh(
				FloraIds.GIANT_KELP
			)
		)

		if multimesh == null:
			upright_valid = false
		else:
			var transform := (
				multimesh.get_instance_transform(0)
			)

			upright_valid = (
				transform.basis.y.normalized()
					.dot(Vector3.UP)
				> 0.9999
			)

	_expect(
		upright_valid,
		"Upright flora does not inherit terrain tilt."
	)

	presenter.free()


func _test_custom_data() -> void:
	var data := _create_flora_data()
	var presenter := FloraChunkPresenter.new()

	add_child(presenter)

	var initialized := presenter.initialize(data)
	var custom_data_valid := initialized

	if initialized:
		var candidate := data.candidates[0]

		var multimesh := (
			presenter.get_species_multimesh(
				candidate.species_id
			)
		)

		if (
			multimesh == null
			or not multimesh.use_custom_data
		):
			custom_data_valid = false
		else:
			var custom_data := (
				multimesh.get_instance_custom_data(0)
			)

			custom_data_valid = (
				custom_data.r >= 0.0
				and custom_data.r <= 1.0
				and absf(
					custom_data.g
					- candidate.suitability
				) <= EPSILON
				and absf(
					custom_data.b
					- candidate.patch_strength
				) <= EPSILON
				and absf(
					custom_data.a
					- candidate.placement_probability
				) <= EPSILON
			)

	_expect(
		custom_data_valid,
		"MultiMesh custom data carries phase and ecology values."
	)

	presenter.free()


func _test_shared_resources() -> void:
	var presenter := _create_initialized_presenter()

	if presenter == null:
		_expect(
			false,
			"Shared-resource presenter was created."
		)
		return

	var resources_valid := true

	for species_id in range(FloraIds.COUNT):
		var instance := (
			presenter.get_species_instance(
				species_id
			)
		)

		var multimesh := (
			presenter.get_species_multimesh(
				species_id
			)
		)

		if instance == null or multimesh == null:
			resources_valid = false
			break

		if multimesh.mesh != (
			FloraProceduralMeshFactory.create_mesh(
				species_id
			)
		):
			resources_valid = false
			break

		if instance.material_override != (
			FloraMaterialFactory.get_material(
				species_id
			)
		):
			resources_valid = false
			break

	_expect(
		resources_valid,
		"MultiMeshes reuse shared species meshes and materials."
	)

	presenter.free()


func _test_empty_chunk() -> void:
	var empty_candidates: Array[FloraPlacementCandidate] = []

	var data := FloraChunkData.new(
		Vector2i(4, -2),
		Vector2(256.0, -128.0),
		TEST_CHUNK_SIZE,
		empty_candidates
	)

	var presenter := FloraChunkPresenter.new()

	add_child(presenter)

	var initialized := presenter.initialize(data)

	_expect(
		initialized
			and presenter.get_total_instance_count() == 0
			and presenter.get_presented_species_count() == 0
			and presenter.get_child_count() == 0,
		"An empty flora chunk creates no MultiMesh Nodes."
	)

	presenter.free()


func _test_reinitialization_rejected() -> void:
	var data := _create_flora_data()
	var presenter := FloraChunkPresenter.new()

	add_child(presenter)

	var first := presenter.initialize(data)
	var second := presenter.initialize(data)

	_expect(
		first and not second,
		"FloraChunkPresenter rejects repeated initialization."
	)

	presenter.free()


func _create_initialized_presenter() -> FloraChunkPresenter:
	var presenter := FloraChunkPresenter.new()

	add_child(presenter)

	if not presenter.initialize(
		_create_flora_data()
	):
		presenter.free()
		return null

	return presenter


func _create_flora_data() -> FloraChunkData:
	var world_origin := Vector2(
		100.0,
		-200.0
	)

	var candidates: Array[FloraPlacementCandidate] = []

	var catalog := FloraCatalogSnapshot.create_default()

	for species_id in range(FloraIds.COUNT):
		var species := catalog.get_species(species_id)

		for instance_index in range(
			INSTANCES_PER_SPECIES
		):
			var candidate_cell := Vector2i(
				instance_index,
				0
			)

			var world_position := Vector3(
				world_origin.x
					+ 4.0
					+ float(species_id) * 10.0
					+ float(instance_index) * 2.0,
				-20.0
					+ float(species_id),
				world_origin.y
					+ 4.0
					+ float(instance_index) * 4.0
			)

			var normal := Vector3(
				0.08,
				1.0,
				-0.04
			).normalized()

			var candidate := (
				FloraPlacementCandidate.new(
					1000
						+ species_id * 100
						+ instance_index,
					species_id,
					candidate_cell,
					world_position,
					normal,
					0.2
						* float(instance_index),
					0.85
						+ 0.1
						* float(instance_index),
					0.72,
					0.64,
					0.58,
					species.align_to_surface
				)
			)

			candidates.append(candidate)

	return FloraChunkData.new(
		Vector2i(2, -3),
		world_origin,
		TEST_CHUNK_SIZE,
		candidates
	)


func _find_candidate(
	data: FloraChunkData,
	species_id: int,
	species_index: int
) -> FloraPlacementCandidate:
	var current_index := 0

	for candidate in data.candidates:
		if candidate.species_id != species_id:
			continue

		if current_index == species_index:
			return candidate

		current_index += 1

	return null


func _expect(
	condition: bool,
	description: String
) -> void:
	if condition:
		_passed += 1
		return

	_failed += 1
	printerr("FAILED: %s" % description)
