extends Node3D

const DEBUG_HOME: Vector3 = Vector3(
	0.0,
	-1000.0,
	0.0
)

@export_range(1.0, 100.0, 1.0)
var movement_speed: float = 24.0

@export_range(0.01, 1.0, 0.01)
var mouse_sensitivity: float = 0.12

@onready var _camera: Camera3D = $Camera3D

@onready var _presentation_root: Node3D = (
	$DynamicEntitiesRoot
)

@onready var _coordinator: GiantSquidCoordinator = (
	$GiantSquidCoordinator
)

@onready var _status_label: Label = (
	$CanvasLayer/MarginContainer/StatusLabel
)

var _catalog: FaunaCatalogSnapshot
var _squid_id: int = 0

var _pitch: float = 0.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	_catalog = FaunaCatalogSnapshot.create_default()

	var initialized: bool = _coordinator.initialize(
		_camera,
		_presentation_root,
		_catalog,
		0.0,
		Callable()
	)

	if not initialized:
		push_error(
			"Giant squid debug coordinator failed "
			+ "to initialize."
		)
		return

	_force_encounter()


func _unhandled_input(
	event: InputEvent
) -> void:
	var mouse_event: InputEventMouseMotion = (
		event as InputEventMouseMotion
	)

	if (
		mouse_event != null
		and Input.mouse_mode
			== Input.MOUSE_MODE_CAPTURED
	):
		rotation_degrees.y -= (
			mouse_event.relative.x
			* mouse_sensitivity
		)

		_pitch = clampf(
			_pitch
				- mouse_event.relative.y
					* mouse_sensitivity,
			-89.0,
			89.0
		)

		_camera.rotation_degrees.x = _pitch

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if (
		event is InputEventMouseButton
		and event.pressed
		and Input.mouse_mode
			!= Input.MOUSE_MODE_CAPTURED
	):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event is InputEventKey:
		var key_event: InputEventKey = (
			event as InputEventKey
		)

		if (
			key_event.pressed
			and not key_event.echo
			and key_event.keycode == KEY_R
		):
			_force_encounter()


func _process(
	delta: float
) -> void:
	var input_vector: Vector2 = Vector2.ZERO

	if Input.is_key_pressed(KEY_A):
		input_vector.x -= 1.0

	if Input.is_key_pressed(KEY_D):
		input_vector.x += 1.0

	if Input.is_key_pressed(KEY_W):
		input_vector.y -= 1.0

	if Input.is_key_pressed(KEY_S):
		input_vector.y += 1.0

	var vertical: float = 0.0

	if Input.is_key_pressed(KEY_E):
		vertical += 1.0

	if Input.is_key_pressed(KEY_Q):
		vertical -= 1.0

	var movement: Vector3 = (
		_camera.global_basis.x * input_vector.x
		+ -_camera.global_basis.z * -input_vector.y
		+ Vector3.UP * vertical
	)

	if not movement.is_zero_approx():
		global_position += (
			movement.normalized()
			* movement_speed
			* delta
		)

	_update_status()


func _force_encounter() -> void:
	if _squid_id != 0:
		_coordinator.unregister_descriptor(
			_squid_id
		)

	_squid_id = _coordinator.force_debug_encounter(
		DEBUG_HOME,
		9001
	)


func _update_status() -> void:
	var state_name: String = "Inactive"

	var controller: GiantSquidController = (
		_coordinator.get_active_controller(
			_squid_id
		)
	)

	if controller != null:
		state_name = (
			controller.get_behavior_state_name()
		)

	var status_template: String = (
		"Giant Squid Debug\n"
		+ "WASD: move | Q/E: descend/ascend | "
		+ "R: reset encounter | Esc: release mouse\n"
		+ "Position: (%.1f, %.1f, %.1f)\n"
		+ "State: %s\n"
		+ "Active squid: %d"
	)

	_status_label.text = status_template % [
		_camera.global_position.x,
		_camera.global_position.y,
		_camera.global_position.z,
		state_name,
		_coordinator.get_active_count(),
	]
