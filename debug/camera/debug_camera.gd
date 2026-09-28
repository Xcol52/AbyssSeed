class_name DebugCamera
extends Node3D

@export_category("Movement")

@export_range(0.1, 5000.0, 0.1)
var movement_speed: float = 80.0

@export_range(1.0, 20.0, 0.1)
var boost_multiplier: float = 5.0


@export_category("View")

@export_range(0.0001, 0.02, 0.0001)
var mouse_sensitivity: float = 0.002

@export_range(1.0, 89.9, 0.1)
var pitch_limit_degrees: float = 89.0


@onready var _pitch_pivot: Node3D = (
	%PitchPivot as Node3D
)

@onready var _camera: Camera3D = (
	%Camera3D as Camera3D
)

@onready var _flashlight: SpotLight3D = (
	%DebugFlashlight as SpotLight3D
)


var _source_transform: Transform3D = Transform3D.IDENTITY
var _source_fov: float = 70.0
var _source_near: float = 0.05
var _source_far: float = 900.0
var _has_source_camera: bool = false

var _pitch_radians: float = 0.0
var _flashlight_enabled: bool = true
var _flashlight_key_was_pressed: bool = false


func initialize_from_camera(
	source_camera: Camera3D
) -> bool:
	if (
		source_camera == null
		or not is_instance_valid(source_camera)
	):
		push_error(
			"DebugCamera requires a valid source Camera3D."
		)
		return false

	_source_transform = source_camera.global_transform
	_source_fov = source_camera.fov
	_source_near = source_camera.near
	_source_far = source_camera.far
	_has_source_camera = true

	if is_node_ready():
		_apply_source_camera_state()

	return true


func _ready() -> void:
	if not _validate_required_nodes():
		set_process(false)
		set_process_unhandled_input(false)
		return

	if _has_source_camera:
		_apply_source_camera_state()
	else:
		_pitch_radians = _pitch_pivot.rotation.x

	_camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(
	delta: float
) -> void:
	_update_flashlight_toggle()

	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return

	if _is_text_entry_focused():
		return

	var local_input: Vector3 = Vector3.ZERO

	if Input.is_physical_key_pressed(KEY_W):
		local_input.z -= 1.0

	if Input.is_physical_key_pressed(KEY_S):
		local_input.z += 1.0

	if Input.is_physical_key_pressed(KEY_A):
		local_input.x -= 1.0

	if Input.is_physical_key_pressed(KEY_D):
		local_input.x += 1.0

	var vertical_input: float = 0.0

	if Input.is_physical_key_pressed(KEY_E):
		vertical_input += 1.0

	if Input.is_physical_key_pressed(KEY_Q):
		vertical_input -= 1.0

	if local_input.is_zero_approx() and is_zero_approx(vertical_input):
		return

	if local_input.length_squared() > 1.0:
		local_input = local_input.normalized()

	var movement_direction: Vector3 = Vector3.ZERO

	if not local_input.is_zero_approx():
		movement_direction = (
			_pitch_pivot.global_transform.basis
			* local_input
		)

	if not is_zero_approx(vertical_input):
		movement_direction += Vector3.UP * vertical_input

	if movement_direction.is_zero_approx():
		return

	movement_direction = movement_direction.normalized()

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
		and not _is_text_entry_focused()
	):
		rotation.y -= (
			mouse_motion_event.relative.x
			* mouse_sensitivity
		)

		var pitch_limit_radians: float = deg_to_rad(
			pitch_limit_degrees
		)

		_pitch_radians = clampf(
			_pitch_radians
				- mouse_motion_event.relative.y
					* mouse_sensitivity,
			-pitch_limit_radians,
			pitch_limit_radians
		)

		_pitch_pivot.rotation.x = _pitch_radians

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
		and not _is_text_entry_focused()
	):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()


func _apply_source_camera_state() -> void:
	if (
		_pitch_pivot == null
		or _camera == null
	):
		return

	global_position = _source_transform.origin

	var source_forward: Vector3 = (
		-_source_transform.basis.z
	).normalized()

	var source_right: Vector3 = (
		_source_transform.basis.x
	).normalized()

	var horizontal_forward: Vector2 = Vector2(
		source_forward.x,
		source_forward.z
	)

	var yaw_radians: float = 0.0

	if horizontal_forward.length_squared() > 0.000001:
		yaw_radians = atan2(
			-source_forward.x,
			-source_forward.z
		)
	else:
		yaw_radians = atan2(
			-source_right.z,
			source_right.x
		)

	_pitch_radians = asin(
		clampf(
			source_forward.y,
			-1.0,
			1.0
		)
	)

	rotation = Vector3(
		0.0,
		yaw_radians,
		0.0
	)

	_pitch_pivot.rotation = Vector3(
		_pitch_radians,
		0.0,
		0.0
	)

	_camera.fov = _source_fov
	_camera.near = _source_near
	_camera.far = _source_far


func _update_flashlight_toggle() -> void:
	var flashlight_key_is_pressed: bool = (
		Input.is_physical_key_pressed(KEY_F)
	)

	if (
		flashlight_key_is_pressed
		and not _flashlight_key_was_pressed
		and not _is_text_entry_focused()
	):
		_flashlight_enabled = not _flashlight_enabled
		_flashlight.visible = _flashlight_enabled

	_flashlight_key_was_pressed = (
		flashlight_key_is_pressed
	)


func _is_text_entry_focused() -> bool:
	var focused_control: Control = (
		get_viewport().gui_get_focus_owner()
	)

	return focused_control is LineEdit


func _validate_required_nodes() -> bool:
	if _pitch_pivot == null:
		push_error(
			"DebugCamera requires PitchPivot."
		)
		return false

	if _camera == null:
		push_error(
			"DebugCamera requires PitchPivot/Camera3D."
		)
		return false

	if _flashlight == null:
		push_error(
			"DebugCamera requires DebugFlashlight."
		)
		return false

	return true


func get_camera() -> Camera3D:
	return _camera


func _exit_tree() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
