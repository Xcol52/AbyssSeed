extends Node3D

@export_category("Movement")

@export_range(0.1, 1000.0, 0.1)
var movement_speed: float = 20.0

@export_range(1.0, 20.0, 0.1)
var boost_multiplier: float = 4.0


@export_category("View")

## Mouse-look rotation in radians per mouse pixel.
@export_range(0.0001, 0.02, 0.0001)
var mouse_sensitivity: float = 0.002

@export_range(1.0, 89.9, 0.1)
var pitch_limit_degrees: float = 89.0


@export_category("Flashlight")

@export var flashlight_starts_enabled: bool = true

@export_range(1.0, 500.0, 1.0)
var flashlight_range: float = 150.0

@export_range(1.0, 89.0, 1.0)
var flashlight_spot_angle: float = 40.0

@export_range(0.0, 32.0, 0.1)
var flashlight_energy: float = 12.0

@export var flashlight_shadows_enabled: bool = true


@onready var _pitch_pivot: Node3D = (
	$PitchPivot as Node3D
)

@onready var _camera: Camera3D = (
	$PitchPivot/Camera3D as Camera3D
)

var _pitch: float = 0.0

var _flashlight: SpotLight3D
var _flashlight_enabled: bool = true
var _flashlight_key_was_pressed: bool = false


func _ready() -> void:
	if _pitch_pivot == null:
		push_error(
			"DebugObserver requires PitchPivot."
		)
		set_process(false)
		set_process_unhandled_input(false)
		return

	if _camera == null:
		push_error(
			"DebugObserver requires PitchPivot/Camera3D."
		)
		set_process(false)
		set_process_unhandled_input(false)
		return

	_pitch = _pitch_pivot.rotation.x

	_flashlight_enabled = flashlight_starts_enabled
	_install_flashlight()

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(
	delta: float
) -> void:
	_update_flashlight_toggle()

	var input_direction: Vector3 = Vector3.ZERO

	if Input.is_physical_key_pressed(KEY_W):
		input_direction.z -= 1.0

	if Input.is_physical_key_pressed(KEY_S):
		input_direction.z += 1.0

	if Input.is_physical_key_pressed(KEY_A):
		input_direction.x -= 1.0

	if Input.is_physical_key_pressed(KEY_D):
		input_direction.x += 1.0

	if input_direction.is_zero_approx():
		return

	## PitchPivot contains pitch and inherits yaw from DebugObserver.
	## Transforming movement through its global basis preserves the
	## established camera-relative movement, including vertical motion
	## when looking upward or downward.
	var camera_basis: Basis = (
		_pitch_pivot.global_transform.basis
	)

	var movement_direction: Vector3 = (
		camera_basis * input_direction
	).normalized()

	var active_speed: float = movement_speed

	if Input.is_physical_key_pressed(KEY_SHIFT):
		active_speed *= boost_multiplier

	global_position += (
		movement_direction
		* active_speed
		* delta
	)


func _unhandled_input(
	input_event: InputEvent
) -> void:
	var mouse_motion_event: InputEventMouseMotion = (
		input_event as InputEventMouseMotion
	)

	if (
		mouse_motion_event != null
		and Input.mouse_mode
			== Input.MOUSE_MODE_CAPTURED
	):
		rotation.y -= (
			mouse_motion_event.relative.x
			* mouse_sensitivity
		)

		var pitch_limit_radians: float = deg_to_rad(
			pitch_limit_degrees
		)

		_pitch = clampf(
			_pitch
				- mouse_motion_event.relative.y
					* mouse_sensitivity,
			-pitch_limit_radians,
			pitch_limit_radians
		)

		_pitch_pivot.rotation.x = _pitch

		get_viewport().set_input_as_handled()
		return

	if input_event.is_action_pressed(&"ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
		return

	var mouse_button_event: InputEventMouseButton = (
		input_event as InputEventMouseButton
	)

	if (
		mouse_button_event != null
		and mouse_button_event.pressed
		and Input.mouse_mode
			!= Input.MOUSE_MODE_CAPTURED
	):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()


func _install_flashlight() -> void:
	var existing_node: Node = _camera.get_node_or_null(
		"DebugFlashlight"
	)

	if existing_node != null:
		var existing_flashlight: SpotLight3D = (
			existing_node as SpotLight3D
		)

		if existing_flashlight == null:
			push_error(
				"Camera child DebugFlashlight exists, "
				+ "but it is not a SpotLight3D."
			)
			return

		_flashlight = existing_flashlight
	else:
		_flashlight = SpotLight3D.new()
		_flashlight.name = "DebugFlashlight"
		_camera.add_child(_flashlight)

	## A Camera3D and SpotLight3D both point along local negative Z.
	## Parenting the light directly to the camera keeps the beam aligned
	## without introducing another orientation system.
	_flashlight.position = Vector3.ZERO
	_flashlight.rotation = Vector3.ZERO

	_flashlight.light_color = Color(
		0.72,
		0.87,
		1.0,
		1.0
	)

	_flashlight.light_energy = flashlight_energy
	_flashlight.light_indirect_energy = 0.0
	_flashlight.light_specular = 0.55

	_flashlight.spot_range = flashlight_range
	_flashlight.spot_angle = flashlight_spot_angle

	_flashlight.spot_attenuation = 0.72
	_flashlight.spot_angle_attenuation = 0.85

	_flashlight.shadow_enabled = (
		flashlight_shadows_enabled
	)

	_flashlight.visible = _flashlight_enabled


func _update_flashlight_toggle() -> void:
	var flashlight_key_is_pressed: bool = (
		Input.is_physical_key_pressed(KEY_F)
	)

	if (
		flashlight_key_is_pressed
		and not _flashlight_key_was_pressed
	):
		_set_flashlight_enabled(
			not _flashlight_enabled
		)

	_flashlight_key_was_pressed = (
		flashlight_key_is_pressed
	)


func _set_flashlight_enabled(
	is_enabled: bool
) -> void:
	_flashlight_enabled = is_enabled

	if (
		_flashlight != null
		and is_instance_valid(_flashlight)
	):
		_flashlight.visible = _flashlight_enabled


func is_flashlight_enabled() -> bool:
	return _flashlight_enabled


func set_flashlight_enabled(
	is_enabled: bool
) -> void:
	_set_flashlight_enabled(is_enabled)
