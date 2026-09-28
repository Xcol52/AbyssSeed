class_name AtmosphericDiveSuit
extends Node3D

## Diegetic player controller for the atmospheric dive suit.
##
## Movement and seafloor collision are resolved mathematically. This
## controller does not use CharacterBody3D, RigidBody3D, CollisionShape3D,
## or move_and_slide().

const BREATHING_AUDIO_PATH: String = (
	"res://audio/dive_suit/breathing_idle.ogg"
)

const SWIMMING_AUDIO_PATH: String = (
	"res://audio/dive_suit/swimming_active.ogg"
)

## The root can rise slightly above sea level so the camera can breach the
## animated ocean surface.
const MAX_SURFACE_Y: float = 0.2

## Upward requested movement is removed at sea level. Existing upward
## momentum may carry the suit as high as MAX_SURFACE_Y before being stopped.
const SURFACE_SWIM_LIMIT_Y: float = 0.0

## Minimum distance between the suit origin and the queried seafloor.
const MIN_SURFACE_CLEARANCE: float = 1.5

const MINIMUM_AUDIO_LINEAR_GAIN: float = 0.0001


@export_category("Movement")

@export_range(0.1, 50.0, 0.1)
var maximum_swim_speed: float = 1000.0

## Active-input acceleration in meters per second squared.
@export_range(0.1, 50.0, 0.1)
var acceleration: float = 200.0

## Exponential-style interpolation rate used when no movement is requested.
## A value of 8.0 removes approximately 99.97 percent of residual velocity
## in one second at stable frame rates.
@export_range(0.1, 30.0, 0.1)
var idle_velocity_damping: float = 500.0


@export_category("View")

## Mouse-look rotation in radians per mouse pixel.
@export_range(0.0001, 0.02, 0.0001)
var mouse_sensitivity: float = 0.002

@export_range(1.0, 89.9, 0.1)
var pitch_limit_degrees: float = 89.0


@export_category("Buoyancy Bob")

@export_range(0.0, 0.25, 0.001)
var idle_bob_amplitude: float = 0.025

@export_range(1.0, 30.0, 0.1)
var idle_bob_period_seconds: float = 10.0

@export_range(0.1, 10.0, 0.1)
var idle_bob_blend_speed: float = 1.5


@export_category("Audio")

@export_range(0.1, 10.0, 0.1)
var audio_crossfade_speed: float = 2.0


@export_category("Flashlight")

@export var flashlight_starts_enabled: bool = true


@onready var _pitch_pivot: Node3D = (
	%PitchPivot as Node3D
)

@onready var _camera: Camera3D = (
	%Camera3D as Camera3D
)

@onready var _flashlight: SpotLight3D = (
	%DiveSuitFlashlight as SpotLight3D
)

@onready var _idle_breathing: AudioStreamPlayer = (
	%IdleBreathing as AudioStreamPlayer
)

@onready var _active_swimming: AudioStreamPlayer = (
	%ActiveSwimming as AudioStreamPlayer
)


var _initialized: bool = false

## Injected after OceanWorld enters the SceneTree.
##
## Expected signature:
##
##     Callable.call(world_position: Vector3)
##         -> TerrainSurfaceQueryResult
var _surface_query: Callable = Callable()

var _velocity: Vector3 = Vector3.ZERO
var _pitch_radians: float = 0.0

var _camera_base_local_position: Vector3 = Vector3.ZERO
var _bob_time_seconds: float = 0.0
var _bob_weight: float = 0.0

var _audio_activity: float = 0.0

var _flashlight_enabled: bool = true
var _flashlight_key_was_pressed: bool = false


func _ready() -> void:
	if not _validate_required_nodes():
		set_process(false)
		set_process_unhandled_input(false)
		return

	_pitch_radians = _pitch_pivot.rotation.x
	_camera_base_local_position = _camera.position

	_flashlight_enabled = flashlight_starts_enabled
	_flashlight.visible = _flashlight_enabled

	_load_audio_stream(
		BREATHING_AUDIO_PATH,
		_idle_breathing
	)

	_load_audio_stream(
		SWIMMING_AUDIO_PATH,
		_active_swimming
	)
	_idle_breathing.bus = &"Master"
	_active_swimming.bus = &"Master"
	_start_available_audio()
	_enforce_surface_ceiling()

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func initialize(
	surface_query: Callable
) -> bool:
	if _initialized:
		push_error(
			"AtmosphericDiveSuit can only be initialized once."
		)
		return false

	if not surface_query.is_valid():
		push_error(
			"AtmosphericDiveSuit requires a valid terrain "
			+ "surface query callable."
		)
		return false

	_surface_query = surface_query
	_initialized = true

	return true


func _process(
	delta: float
) -> void:
	_update_flashlight_toggle()

	if not _initialized:
		return

	var requested_movement: Vector3 = (
		_read_movement_input()
	)

	## Sea level suppresses only upward input. Horizontal components remain
	## intact, allowing the suit to swim along the surface.
	if (
		global_position.y >= SURFACE_SWIM_LIMIT_Y
		and requested_movement.y > 0.0
	):
		requested_movement.y = 0.0

	var has_movement_input: bool = (
		not requested_movement.is_zero_approx()
	)

	if has_movement_input:
		var desired_velocity: Vector3 = (
			requested_movement
			* maximum_swim_speed
		)

		_velocity = _velocity.move_toward(
			desired_velocity,
			acceleration * delta
		)
	else:
		## Clamp the interpolation weight so long frames cannot overshoot.
		var damping_weight: float = clampf(
			idle_velocity_damping * delta,
			0.0,
			1.0
		)

		_velocity = _velocity.lerp(
			Vector3.ZERO,
			damping_weight
		)

		if _velocity.length_squared() <= 0.000001:
			_velocity = Vector3.ZERO

	var intended_global_position: Vector3 = (
		global_position
		+ _velocity * delta
	)

	global_position = intended_global_position

	_apply_floor_constraint()
	_enforce_surface_ceiling()

	_update_idle_bobbing(
		delta,
		has_movement_input
	)

	_update_audio(
		delta,
		has_movement_input
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


func _read_movement_input() -> Vector3:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return Vector3.ZERO

	## Explicitly suppress movement while a console or other LineEdit owns
	## keyboard focus.
	if _is_text_entry_focused():
		return Vector3.ZERO

	var local_input: Vector3 = Vector3.ZERO

	if Input.is_physical_key_pressed(KEY_W):
		local_input.z -= 1.0

	if Input.is_physical_key_pressed(KEY_S):
		local_input.z += 1.0

	if Input.is_physical_key_pressed(KEY_A):
		local_input.x -= 1.0

	if Input.is_physical_key_pressed(KEY_D):
		local_input.x += 1.0

	if local_input.is_zero_approx():
		return Vector3.ZERO

	if local_input.length_squared() > 1.0:
		local_input = local_input.normalized()

	## PitchPivot contains camera pitch and inherits root yaw. Transforming
	## the complete local input through this basis preserves vertical camera
	## orientation. Looking down and pressing W therefore swims downward.
	var movement_direction: Vector3 = (
		_pitch_pivot.global_transform.basis
		* local_input
	)

	if movement_direction.is_zero_approx():
		return Vector3.ZERO

	return movement_direction.normalized()


func _is_text_entry_focused() -> bool:
	var focused_control: Control = (
		get_viewport().gui_get_focus_owner()
	)

	return focused_control is LineEdit


func _apply_floor_constraint() -> void:
	if not _surface_query.is_valid():
		return

	var query_result: Variant = _surface_query.call(
		global_position
	)

	var surface_result: TerrainSurfaceQueryResult = (
		query_result as TerrainSurfaceQueryResult
	)

	if surface_result == null:
		return

	if not surface_result.available:
		return

	var minimum_allowed_y: float = (
		surface_result.surface_elevation_meters
		+ MIN_SURFACE_CLEARANCE
	)

	if global_position.y >= minimum_allowed_y:
		return

	var constrained_position: Vector3 = global_position
	constrained_position.y = minimum_allowed_y
	global_position = constrained_position

	if _velocity.y < 0.0:
		_velocity.y = 0.0


func _enforce_surface_ceiling() -> void:
	if global_position.y <= MAX_SURFACE_Y:
		return

	var constrained_position: Vector3 = global_position
	constrained_position.y = MAX_SURFACE_Y
	global_position = constrained_position

	if _velocity.y > 0.0:
		_velocity.y = 0.0


func teleport_to_world_xz(
	world_x: float,
	world_z: float
) -> bool:
	if (
		not is_finite(world_x)
		or not is_finite(world_z)
	):
		return false

	var target_position: Vector3 = global_position
	target_position.x = world_x
	target_position.z = world_z

	global_position = target_position
	_velocity = Vector3.ZERO

	## If destination terrain is already resident, enforce its floor
	## immediately. If it is not resident yet, the normal process path will
	## enforce the floor as soon as streaming makes the query available.
	_apply_floor_constraint()
	_enforce_surface_ceiling()

	return true


func _update_idle_bobbing(
	delta: float,
	has_movement_input: bool
) -> void:
	_bob_time_seconds += delta

	var target_bob_weight: float = 1.0

	if has_movement_input:
		target_bob_weight = 0.0

	_bob_weight = move_toward(
		_bob_weight,
		target_bob_weight,
		idle_bob_blend_speed * delta
	)

	var safe_period: float = maxf(
		idle_bob_period_seconds,
		0.001
	)

	var bob_phase: float = (
		_bob_time_seconds
		* TAU
		/ safe_period
	)

	var bob_offset: float = (
		sin(bob_phase)
		* idle_bob_amplitude
		* _bob_weight
	)

	_camera.position = (
		_camera_base_local_position
		+ Vector3.UP * bob_offset
	)


func _update_audio(
	delta: float,
	has_movement_input: bool
) -> void:
	var target_activity: float = 0.0

	if (
		has_movement_input
		and _velocity.length_squared() > 0.01
	):
		target_activity = 1.0

	_audio_activity = move_toward(
		_audio_activity,
		target_activity,
		audio_crossfade_speed * delta
	)

	if (
		_idle_breathing.stream != null
		and not _idle_breathing.playing
	):
		_idle_breathing.play()

	if (
		_active_swimming.stream != null
		and not _active_swimming.playing
	):
		_active_swimming.play()

	var breathing_gain: float = maxf(
		1.0 - _audio_activity,
		MINIMUM_AUDIO_LINEAR_GAIN
	)

	var swimming_gain: float = maxf(
		_audio_activity,
		MINIMUM_AUDIO_LINEAR_GAIN
	)

	_idle_breathing.volume_db = linear_to_db(
		breathing_gain
	)

	_active_swimming.volume_db = linear_to_db(
		swimming_gain
	)


func _update_flashlight_toggle() -> void:
	var flashlight_key_is_pressed: bool = (
		Input.is_physical_key_pressed(KEY_F)
	)

	if (
		flashlight_key_is_pressed
		and not _flashlight_key_was_pressed
	):
		set_flashlight_enabled(
			not _flashlight_enabled
		)

	_flashlight_key_was_pressed = (
		flashlight_key_is_pressed
	)


func _load_audio_stream(
	asset_path: String,
	audio_player: AudioStreamPlayer
) -> void:
	if audio_player == null:
		return

	if not ResourceLoader.exists(asset_path):
		return

	var loaded_resource: Resource = ResourceLoader.load(
		asset_path
	)

	var loaded_stream: AudioStream = (
		loaded_resource as AudioStream
	)

	if loaded_stream == null:
		push_warning(
			"AtmosphericDiveSuit could not load AudioStream: %s"
			% asset_path
		)
		return

	audio_player.stream = loaded_stream


func _start_available_audio() -> void:
	if _idle_breathing.stream != null:
		_idle_breathing.volume_db = 0.0
		_idle_breathing.play()

	if _active_swimming.stream != null:
		_active_swimming.volume_db = -80.0
		_active_swimming.play()


func _validate_required_nodes() -> bool:
	if _pitch_pivot == null:
		push_error(
			"AtmosphericDiveSuit requires PitchPivot."
		)
		return false

	if _camera == null:
		push_error(
			"AtmosphericDiveSuit requires "
			+ "PitchPivot/Camera3D."
		)
		return false

	if _flashlight == null:
		push_error(
			"AtmosphericDiveSuit requires "
			+ "Camera3D/DiveSuitFlashlight."
		)
		return false

	if _idle_breathing == null:
		push_error(
			"AtmosphericDiveSuit requires IdleBreathing."
		)
		return false

	if _active_swimming == null:
		push_error(
			"AtmosphericDiveSuit requires ActiveSwimming."
		)
		return false

	return true


func get_velocity() -> Vector3:
	return _velocity


func is_initialized() -> bool:
	return _initialized


func is_flashlight_enabled() -> bool:
	return _flashlight_enabled


func set_flashlight_enabled(
	is_enabled: bool
) -> void:
	_flashlight_enabled = is_enabled

	if (
		_flashlight != null
		and is_instance_valid(_flashlight)
	):
		_flashlight.visible = _flashlight_enabled


func _exit_tree() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
