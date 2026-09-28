extends Node3D

const MODEL_SPACING: float = 5.0
const AUTO_ROTATION_SPEED: float = 0.22
const CURRENT_ROTATION_STEP: float = PI / 8.0

var _model_holders: Array[Node3D] = []

var _auto_rotate: bool = true
var _sway_enabled: bool = true

var _current_angle: float = atan2(
	FloraMaterialFactory.get_current_direction().y,
	FloraMaterialFactory.get_current_direction().x
)

@onready var _models_root: Node3D = %ModelsRoot
@onready var _camera: Camera3D = %GalleryCamera
@onready var _status_label: Label = %StatusLabel


func _ready() -> void:
	FloraMaterialFactory.set_sway_enabled(
		_sway_enabled
	)

	_create_gallery()

	_camera.look_at(
		Vector3(0.0, 2.7, 0.0),
		Vector3.UP
	)

	_update_status()


func _process(delta: float) -> void:
	if not _auto_rotate:
		return

	for holder in _model_holders:
		holder.rotate_y(
			AUTO_ROTATION_SPEED * delta
		)


func _unhandled_input(
	event: InputEvent
) -> void:
	if event is not InputEventKey:
		return

	var key_event := event as InputEventKey

	if not key_event.pressed or key_event.echo:
		return

	match key_event.keycode:
		KEY_SPACE:
			_auto_rotate = not _auto_rotate
			_update_status()

		KEY_S:
			_sway_enabled = not _sway_enabled

			FloraMaterialFactory.set_sway_enabled(
				_sway_enabled
			)

			_update_status()

		KEY_C:
			_rotate_current_direction()
			_update_status()

		KEY_LEFT:
			_rotate_models(-0.18)

		KEY_RIGHT:
			_rotate_models(0.18)

		KEY_R:
			_reset_gallery()

		KEY_ESCAPE:
			get_tree().quit()


func _create_gallery() -> void:
	for child in _models_root.get_children():
		child.queue_free()

	_model_holders.clear()

	var start_x := (
		-float(FloraIds.COUNT - 1)
		* MODEL_SPACING
		* 0.5
	)

	for species_id in range(FloraIds.COUNT):
		var mesh := (
			FloraProceduralMeshFactory.create_mesh(
				species_id
			)
		)

		if mesh == null:
			push_error(
				"Could not create flora model for species %d."
				% species_id
			)
			continue

		var holder := Node3D.new()

		holder.name = (
			"Model_%s"
			% FloraIds.get_display_name(species_id)
				.replace(" ", "_")
		)

		holder.position = Vector3(
			start_x
				+ float(species_id)
				* MODEL_SPACING,
			0.0,
			0.0
		)

		_models_root.add_child(holder)
		_model_holders.append(holder)

		_add_pedestal(holder, species_id)
		_add_model(holder, species_id, mesh)
		_add_label(holder, species_id)


func _add_model(
	holder: Node3D,
	species_id: int,
	mesh: ArrayMesh
) -> void:
	var mesh_instance := MeshInstance3D.new()

	mesh_instance.name = "FloraMesh"
	mesh_instance.mesh = mesh

	holder.add_child(mesh_instance)

	if species_id == FloraIds.CORALLINE_ALGAE:
		mesh_instance.position.y = 0.015


func _add_pedestal(
	holder: Node3D,
	species_id: int
) -> void:
	var pedestal_mesh := CylinderMesh.new()

	pedestal_mesh.top_radius = 1.15
	pedestal_mesh.bottom_radius = 1.28
	pedestal_mesh.height = 0.28
	pedestal_mesh.radial_segments = 32

	var material := StandardMaterial3D.new()

	material.albedo_color = Color(
		0.08,
		0.115,
		0.13,
		1.0
	)

	material.roughness = 0.92

	var accent := (
		FloraProceduralMeshFactory.get_base_color(
			species_id
		)
	)

	material.emission_enabled = true
	material.emission = accent * 0.08

	pedestal_mesh.material = material

	var pedestal := MeshInstance3D.new()

	pedestal.name = "Pedestal"
	pedestal.mesh = pedestal_mesh
	pedestal.position.y = -0.14

	holder.add_child(pedestal)


func _add_label(
	holder: Node3D,
	species_id: int
) -> void:
	var label := Label3D.new()

	label.name = "SpeciesLabel"

	label.text = (
		"%d  %s\n%.2f m nominal height"
		% [
			species_id,
			FloraIds.get_display_name(species_id),
			FloraProceduralMeshFactory
				.get_nominal_height(species_id)
		]
	)

	label.position = Vector3(
		0.0,
		-0.52,
		0.65
	)

	label.font_size = 34
	label.outline_size = 8

	label.modulate = Color(
		0.90,
		0.97,
		1.0,
		1.0
	)

	label.no_depth_test = true

	holder.add_child(label)


func _rotate_models(
	amount: float
) -> void:
	_auto_rotate = false

	for holder in _model_holders:
		holder.rotate_y(amount)

	_update_status()


func _rotate_current_direction() -> void:
	_current_angle += CURRENT_ROTATION_STEP

	var direction := Vector2(
		cos(_current_angle),
		sin(_current_angle)
	)

	FloraMaterialFactory.set_current_direction(
		direction
	)


func _reset_gallery() -> void:
	for holder in _model_holders:
		holder.rotation = Vector3.ZERO

	_auto_rotate = true
	_sway_enabled = true
	_current_angle = atan2(0.25, 1.0)

	FloraMaterialFactory.set_sway_enabled(true)

	FloraMaterialFactory.set_current_direction(
		Vector2(1.0, 0.25)
	)

	_update_status()


func _update_status() -> void:
	var rotation_state := (
		"ON" if _auto_rotate else "OFF"
	)

	var sway_state := (
		"ON" if _sway_enabled else "OFF"
	)

	var current := (
		FloraMaterialFactory.get_current_direction()
	)

	_status_label.text = (
		"Procedural Flora Material and Sway Gallery\n"
		+ "Space: auto-rotate | "
		+ "S: sway | "
		+ "C: rotate current | "
		+ "Left/Right: rotate models | "
		+ "R: reset | Esc: close\n"
		+ "Auto-rotate: %s | Sway: %s | "
		% [
			rotation_state,
			sway_state
		]
		+ "Current: (%.2f, %.2f)"
		% [
			current.x,
			current.y
		]
	)
