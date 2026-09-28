extends Node3D

const GALLERY_ORIGIN := Vector2(
	-15.0,
	-10.0
)

const GALLERY_CHUNK_SIZE: float = 30.0
const GRID_SIZE: int = 3
const GRID_SPACING: float = 1.15
const CURRENT_ROTATION_STEP: float = PI / 8.0

var _presenter: FloraChunkPresenter
var _sway_enabled: bool = true

var _current_angle: float = atan2(
	FloraMaterialFactory.get_current_direction().y,
	FloraMaterialFactory.get_current_direction().x
)

@onready var _flora_root: Node3D = %FloraRoot
@onready var _camera: Camera3D = %GalleryCamera
@onready var _status_label: Label = %StatusLabel


func _ready() -> void:
	FloraMaterialFactory.set_sway_enabled(true)

	_presenter = FloraChunkPresenter.new()
	_flora_root.add_child(_presenter)

	if not _presenter.initialize(
		_create_gallery_data()
	):
		push_error(
			"Could not initialize the flora MultiMesh gallery."
		)
		return

	_add_species_labels()

	_camera.look_at(
		Vector3(0.0, 2.8, 0.0),
		Vector3.UP
	)

	_update_status()


func _unhandled_input(
	event: InputEvent
) -> void:
	if event is not InputEventKey:
		return

	var key_event := event as InputEventKey

	if not key_event.pressed or key_event.echo:
		return

	match key_event.keycode:
		KEY_S:
			_sway_enabled = not _sway_enabled

			FloraMaterialFactory.set_sway_enabled(
				_sway_enabled
			)

			_update_status()

		KEY_C:
			_current_angle += CURRENT_ROTATION_STEP

			FloraMaterialFactory.set_current_direction(
				Vector2(
					cos(_current_angle),
					sin(_current_angle)
				)
			)

			_update_status()

		KEY_R:
			_sway_enabled = true
			_current_angle = atan2(0.25, 1.0)

			FloraMaterialFactory.set_sway_enabled(true)

			FloraMaterialFactory.set_current_direction(
				Vector2(1.0, 0.25)
			)

			_update_status()

		KEY_ESCAPE:
			get_tree().quit()


func _create_gallery_data() -> FloraChunkData:
	var candidates: Array[FloraPlacementCandidate] = []

	var catalog := FloraCatalogSnapshot.create_default()

	for species_id in range(FloraIds.COUNT):
		var species := catalog.get_species(species_id)

		var species_center_x := (
			-10.0
			+ float(species_id) * 5.0
		)

		for row in range(GRID_SIZE):
			for column in range(GRID_SIZE):
				var local_x := (
					species_center_x
					+ (
						float(column)
						- 1.0
					) * GRID_SPACING
				)

				var local_z := (
					(
						float(row)
						- 1.0
					) * GRID_SPACING
				)

				var candidate_cell := Vector2i(
					column,
					row
				)

				var normal := Vector3(
					0.035
						* float(column - 1),
					1.0,
					0.025
						* float(row - 1)
				).normalized()

				var instance_index := (
					row * GRID_SIZE
					+ column
				)

				candidates.append(
					FloraPlacementCandidate.new(
						10000
							+ species_id * 100
							+ instance_index,
						species_id,
						candidate_cell,
						Vector3(
							local_x,
							0.0,
							local_z
						),
						normal,
						float(instance_index)
							* 0.48,
						0.72
							+ 0.08
							* float(
								instance_index % 4
							),
						0.82,
						0.70,
						0.76,
						species.align_to_surface
					)
				)

	return FloraChunkData.new(
		Vector2i.ZERO,
		GALLERY_ORIGIN,
		GALLERY_CHUNK_SIZE,
		candidates
	)


func _add_species_labels() -> void:
	for species_id in range(FloraIds.COUNT):
		var label := Label3D.new()

		label.text = (
			"%s\n%d instances"
			% [
				FloraIds.get_display_name(
					species_id
				),
				GRID_SIZE * GRID_SIZE,
			]
		)

		label.position = Vector3(
			-10.0
				+ float(species_id) * 5.0,
			-0.35,
			2.2
		)

		label.font_size = 34
		label.outline_size = 8
		label.no_depth_test = true

		_flora_root.add_child(label)


func _update_status() -> void:
	var current := (
		FloraMaterialFactory.get_current_direction()
	)

	_status_label.text = (
		"Stage 10E Flora MultiMesh Gallery\n"
		+ "S: toggle sway | "
		+ "C: rotate current | "
		+ "R: reset | Esc: close\n"
		+ "Sway: %s | Current: (%.2f, %.2f) | "
		% [
			"ON" if _sway_enabled else "OFF",
			current.x,
			current.y,
		]
		+ "%d instances in %d MultiMesh Nodes"
		% [
			_presenter.get_total_instance_count(),
			_presenter.get_presented_species_count(),
		]
	)
