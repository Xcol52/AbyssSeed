class_name GiantSquidController
extends Node3D

signal distant_call_emitted(
	world_position: Vector3
)

signal water_movement_changed(
	intensity: float,
	world_position: Vector3
)

signal drag_requested(
	target: Node3D,
	toward_position: Vector3,
	strength: float
)

enum BehaviorState {
	PATROL,
	OBSERVE,
	STALK,
	WARNING,
	DRAG,
	RETURN_HOME,
}

const CALL_AUDIO_PATH: String = (
	"res://audio/fauna/giant_squid/"
	+ "giant_squid_call.ogg"
)

const AWARENESS_DISTANCE: float = 520.0
const WATCH_DISTANCE: float = 85.0
const DRAG_DISTANCE: float = 75.0

const MINIMUM_OBSERVATION_TIME: float = 12.0
const MAXIMUM_OBSERVATION_TIME: float = 24.0

const MINIMUM_STALK_TIME: float = 7.0
const DRAG_DURATION: float = 11.0

const CRUISE_SPEED: float = 2.8
const APPROACH_SPEED: float = 4.4
const DRAG_SPEED: float = 5.2

const TURN_RATE: float = 0.38
const DRAG_STRENGTH: float = 7.0

const SURFACE_AVOIDANCE_DISTANCE: float = 500.0
const FLOOR_CLEARANCE: float = 35.0

var _descriptor: FaunaPopulationDescriptor
var _species: FaunaSpeciesSnapshot

var _target: Node3D
var _surface_query: Callable = Callable()

var _ocean_height: float = 0.0

var _mesh_instance: MeshInstance3D
var _tentacle_material: ShaderMaterial
var _audio_player: AudioStreamPlayer3D

const TENTACLE_PARAMETER_RESPONSE: float = 1.35

var _tentacle_activity_current: float = 0.24
var _tentacle_speed_current: float = 0.28
var _tentacle_coordination_current: float = 0.18
var _tentacle_curl_current: float = 0.30
var _tentacle_contraction_current: float = 0.12

var _behavior_state: int = BehaviorState.PATROL
var _state_elapsed: float = 0.0
var _observation_duration: float = 16.0
var _stalk_duration: float = 8.0

var _velocity: Vector3 = Vector3.ZERO
var _forward: Vector3 = Vector3.FORWARD

var _warning_mask: int = 1
var _call_played: bool = false
var _last_water_intensity: float = -1.0


func initialize(
	descriptor: FaunaPopulationDescriptor,
	species: FaunaSpeciesSnapshot,
	target: Node3D,
	ocean_height: float,
	surface_query: Callable = Callable()
) -> bool:
	if descriptor == null or species == null:
		return false

	if descriptor.species_id != FaunaIds.GIANT_SQUID:
		return false

	if (
		species.trophic_role
		!= FaunaTypes.TrophicRole.APEX_PREDATOR
	):
		return false

	_descriptor = descriptor
	_species = species
	_target = target
	_ocean_height = ocean_height
	_surface_query = surface_query

	name = "GiantSquid_%d" % descriptor.stable_id

	global_position = descriptor.home_position

	_forward = Vector3(
		sin(descriptor.initial_heading_radians),
		0.0,
		-cos(descriptor.initial_heading_radians)
	).normalized()

	_velocity = _forward * CRUISE_SPEED * 0.4

	var duration_factor: float = (
		StableSeed.seed_to_unit_float(
			descriptor.behavior_seed
		)
	)

	_observation_duration = lerpf(
		MINIMUM_OBSERVATION_TIME,
		MAXIMUM_OBSERVATION_TIME,
		duration_factor
	)

	var stalk_seed: int = StableSeed.derive_channel_seed(
		descriptor.behavior_seed,
		1
	)

	_stalk_duration = lerpf(
		MINIMUM_STALK_TIME,
		MINIMUM_STALK_TIME + 6.0,
		StableSeed.seed_to_unit_float(stalk_seed)
	)

	var warning_seed: int = StableSeed.derive_channel_seed(
		descriptor.behavior_seed,
		2
	)

	_warning_mask = (
		abs(warning_seed) % 7
	) + 1

	_create_presentation()
	_create_audio_player()

	set_physics_process(true)
	return true


func get_population_id() -> int:
	if _descriptor == null:
		return 0

	return _descriptor.stable_id


func get_behavior_state() -> int:
	return _behavior_state


func get_behavior_state_name() -> String:
	match _behavior_state:
		BehaviorState.PATROL:
			return "Patrol"

		BehaviorState.OBSERVE:
			return "Observe"

		BehaviorState.STALK:
			return "Stalk"

		BehaviorState.WARNING:
			return "Warning"

		BehaviorState.DRAG:
			return "Drag"

		BehaviorState.RETURN_HOME:
			return "Return home"

		_:
			return "Unknown"


func is_dragging() -> bool:
	return _behavior_state == BehaviorState.DRAG


func get_observation_duration() -> float:
	return _observation_duration


func _create_presentation() -> void:
	_mesh_instance = MeshInstance3D.new()

	_mesh_instance.name = "GiantSquidMesh"
	_mesh_instance.mesh = GiantSquidMeshFactory.create_mesh()

	_mesh_instance.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	)

	_tentacle_material = (
		GiantSquidMaterialFactory
		.create_instance_tentacle_material()
	)

	_mesh_instance.set_surface_override_material(
		GiantSquidMeshFactory.TENTACLE_SURFACE_INDEX,
		_tentacle_material
	)

	add_child(_mesh_instance)


func _create_audio_player() -> void:
	_audio_player = AudioStreamPlayer3D.new()
	_audio_player.name = "DistantCallAudio"
	_audio_player.max_distance = 1800.0
	_audio_player.unit_size = 120.0

	if ResourceLoader.exists(CALL_AUDIO_PATH):
		var loaded_resource: Resource = load(
			CALL_AUDIO_PATH
		)

		var audio_stream: AudioStream = (
			loaded_resource as AudioStream
		)

		if audio_stream != null:
			_audio_player.stream = audio_stream

	add_child(_audio_player)


func _physics_process(
	delta: float
) -> void:
	if _descriptor == null:
		return

	_state_elapsed += delta

	if (
		_target == null
		or not is_instance_valid(_target)
	):
		_simulate_patrol(delta)
		_apply_motion(delta)
		_update_tentacle_activity(delta)
		return

	var target_position: Vector3 = (
		_target.global_position
	)

	var target_distance: float = (
		global_position.distance_to(
			target_position
		)
	)

	var target_too_shallow: bool = (
		target_position.y
		> _descriptor.home_position.y + 650.0
	)

	if target_too_shallow:
		_change_state(BehaviorState.RETURN_HOME)

	if target_distance > AWARENESS_DISTANCE:
		if (
			_behavior_state
			!= BehaviorState.RETURN_HOME
		):
			_change_state(BehaviorState.PATROL)

		_simulate_patrol(delta)
	else:
		_simulate_encounter(
			target_position,
			target_distance,
			delta
		)

	_apply_motion(delta)
	_update_water_warning(target_distance)
	_update_tentacle_activity(delta)


func _simulate_encounter(
	target_position: Vector3,
	target_distance: float,
	delta: float
) -> void:
	match _behavior_state:
		BehaviorState.PATROL:
			_change_state(BehaviorState.OBSERVE)
			_simulate_observation(
				target_position,
				delta
			)

		BehaviorState.OBSERVE:
			_simulate_observation(
				target_position,
				delta
			)

			_try_warning_behaviors()

			if (
				_state_elapsed
				>= _observation_duration
			):
				_change_state(BehaviorState.STALK)

		BehaviorState.STALK:
			_simulate_stalk(
				target_position,
				target_distance,
				delta
			)

			_try_warning_behaviors()

			if (
				_state_elapsed >= _stalk_duration
				and target_distance <= DRAG_DISTANCE
			):
				_change_state(BehaviorState.WARNING)

		BehaviorState.WARNING:
			_simulate_observation(
				target_position,
				delta
			)

			_try_warning_behaviors()

			if _state_elapsed >= 3.0:
				_change_state(BehaviorState.DRAG)

		BehaviorState.DRAG:
			_simulate_drag(delta)

			if _state_elapsed >= DRAG_DURATION:
				_change_state(
					BehaviorState.RETURN_HOME
				)

		BehaviorState.RETURN_HOME:
			_simulate_return_home(delta)

			if (
				global_position.distance_to(
					_descriptor.home_position
				) <= 35.0
			):
				_change_state(
					BehaviorState.PATROL
				)


func _simulate_observation(
	target_position: Vector3,
	delta: float
) -> void:
	var desired_direction: Vector3 = (
		target_position - global_position
	)

	if not desired_direction.is_zero_approx():
		desired_direction = desired_direction.normalized()

	var lateral: Vector3 = desired_direction.cross(
		Vector3.UP
	)

	var orbit_direction: Vector3 = (
		desired_direction * 0.20
		+ lateral * 0.32
	)

	if orbit_direction.is_zero_approx():
		orbit_direction = _forward

	_velocity = _velocity.move_toward(
		orbit_direction.normalized()
			* CRUISE_SPEED
			* 0.35,
		TURN_RATE * delta
	)


func _simulate_stalk(
	target_position: Vector3,
	target_distance: float,
	delta: float
) -> void:
	var desired_direction: Vector3 = (
		target_position - global_position
	)

	if desired_direction.is_zero_approx():
		return

	desired_direction = desired_direction.normalized()

	var speed: float = APPROACH_SPEED

	if target_distance <= WATCH_DISTANCE:
		speed = CRUISE_SPEED * 0.20

	_velocity = _velocity.move_toward(
		desired_direction * speed,
		TURN_RATE * 1.5 * delta
	)


func _simulate_drag(
	delta: float
) -> void:
	var home_direction: Vector3 = (
		_descriptor.home_position
		- global_position
	)

	if not home_direction.is_zero_approx():
		home_direction = home_direction.normalized()

	_velocity = _velocity.move_toward(
		home_direction * DRAG_SPEED,
		TURN_RATE * 1.6 * delta
	)

	if (
		_target != null
		and is_instance_valid(_target)
	):
		drag_requested.emit(
			_target,
			_descriptor.home_position,
			DRAG_STRENGTH
		)

		if _target.has_method(
			&"apply_leviathan_drag"
		):
			_target.call(
				&"apply_leviathan_drag",
				_descriptor.home_position,
				DRAG_STRENGTH,
				delta
			)


func _simulate_patrol(
	delta: float
) -> void:
	var phase: float = (
		StableSeed.seed_to_unit_float(
			_descriptor.behavior_seed
		) * TAU
	)

	var time_value: float = (
		Time.get_ticks_msec() * 0.001
	)

	var patrol_direction: Vector3 = Vector3(
		sin(time_value * 0.08 + phase),
		sin(time_value * 0.05 + phase) * 0.10,
		-cos(time_value * 0.08 + phase)
	).normalized()

	var home_offset: Vector3 = (
		_descriptor.home_position
		- global_position
	)

	if (
		home_offset.length()
		> _descriptor.home_radius * 0.45
	):
		patrol_direction = (
			home_offset.normalized()
		)

	_velocity = _velocity.move_toward(
		patrol_direction * CRUISE_SPEED,
		TURN_RATE * delta
	)


func _simulate_return_home(
	delta: float
) -> void:
	var home_direction: Vector3 = (
		_descriptor.home_position
		- global_position
	)

	if home_direction.is_zero_approx():
		_velocity = _velocity.move_toward(
			Vector3.ZERO,
			TURN_RATE * delta
		)
		return

	_velocity = _velocity.move_toward(
		home_direction.normalized()
			* APPROACH_SPEED,
		TURN_RATE * 1.4 * delta
	)


func _apply_motion(
	delta: float
) -> void:
	global_position += _velocity * delta

	global_position = _constrain_position(
		global_position
	)

	if not _velocity.is_zero_approx():
		var desired_forward: Vector3 = (
			_velocity.normalized()
		)

		var blend_factor: float = clampf(
			TURN_RATE * delta,
			0.0,
			1.0
		)

		var blended_forward: Vector3 = (
			_forward.lerp(
				desired_forward,
				blend_factor
			)
		)

		if not blended_forward.is_zero_approx():
			_forward = blended_forward.normalized()

	basis = _basis_from_forward(_forward)


func _constrain_position(
	world_position: Vector3
) -> Vector3:
	var result: Vector3 = world_position

	var fallback_floor: float = (
		_descriptor.home_position.y
		- GiantSquidRegionalSampler.HOME_ALTITUDE
	)

	var floor_height: float = fallback_floor

	if _surface_query.is_valid():
		var query_value: Variant = (
			_surface_query.call(result)
		)

		var query_result: TerrainSurfaceQueryResult = (
			query_value as TerrainSurfaceQueryResult
		)

		if (
			query_result != null
			and query_result.available
		):
			floor_height = (
				query_result
				.surface_elevation_meters
			)

	var minimum_y: float = (
		floor_height + FLOOR_CLEARANCE
	)

	var maximum_y: float = minf(
		floor_height
			+ _descriptor.maximum_altitude,
		_ocean_height
			- SURFACE_AVOIDANCE_DISTANCE
	)

	if maximum_y < minimum_y:
		maximum_y = minimum_y

	result.y = clampf(
		result.y,
		minimum_y,
		maximum_y
	)

	return result


func _try_warning_behaviors() -> void:
	if (
		_warning_mask & 1
		and not _call_played
		and _state_elapsed >= 2.5
	):
		_call_played = true

		if (
			_audio_player != null
			and _audio_player.stream != null
		):
			_audio_player.play()

		distant_call_emitted.emit(
			global_position
		)


func _update_water_warning(
	target_distance: float
) -> void:
	var intensity: float = clampf(
		1.0
			- target_distance
				/ AWARENESS_DISTANCE,
		0.0,
		1.0
	)

	if _behavior_state == BehaviorState.DRAG:
		intensity = 1.0

	if (
		absf(
			intensity
			- _last_water_intensity
		) < 0.05
	):
		return

	_last_water_intensity = intensity

	water_movement_changed.emit(
		intensity,
		global_position
	)

	if (
		_target != null
		and is_instance_valid(_target)
		and _target.has_method(
			&"set_large_creature_water_movement"
		)
	):
		_target.call(
			&"set_large_creature_water_movement",
			intensity,
			global_position
		)


func _update_tentacle_activity(
	delta: float
) -> void:
	if _tentacle_material == null:
		return

	var target_activity: float = 0.24
	var target_speed: float = 0.28
	var target_coordination: float = 0.18
	var target_curl: float = 0.30
	var target_contraction: float = 0.12

	match _behavior_state:
		BehaviorState.PATROL:
			# Slow, loose, mostly independent movement.
			target_activity = 0.24
			target_speed = 0.28
			target_coordination = 0.18
			target_curl = 0.30
			target_contraction = 0.12

		BehaviorState.OBSERVE:
			# The body remains restrained while the distal portions
			# curl and inspect the surrounding water.
			target_activity = 0.34
			target_speed = 0.24
			target_coordination = 0.28
			target_curl = 0.62
			target_contraction = 0.10

		BehaviorState.STALK:
			# More deliberate motion with increasing group alignment.
			target_activity = 0.55
			target_speed = 0.38
			target_coordination = 0.58
			target_curl = 0.45
			target_contraction = 0.28

		BehaviorState.WARNING:
			# Broad, readable movement that signals an imminent threat.
			target_activity = 0.78
			target_speed = 0.50
			target_coordination = 0.78
			target_curl = 0.72
			target_contraction = 0.48

		BehaviorState.DRAG:
			# Strong, coordinated pulling movement.
			target_activity = 1.15
			target_speed = 0.72
			target_coordination = 0.92
			target_curl = 0.30
			target_contraction = 0.90

		BehaviorState.RETURN_HOME:
			target_activity = 0.48
			target_speed = 0.42
			target_coordination = 0.58
			target_curl = 0.34
			target_contraction = 0.30

	# Exponential interpolation makes the visual behavior transition
	# smoothly even though the controller's behavior state is discrete.
	var blend_factor: float = clampf(
		1.0
			- exp(
				-TENTACLE_PARAMETER_RESPONSE
				* maxf(delta, 0.0)
			),
		0.0,
		1.0
	)

	_tentacle_activity_current = lerpf(
		_tentacle_activity_current,
		target_activity,
		blend_factor
	)

	_tentacle_speed_current = lerpf(
		_tentacle_speed_current,
		target_speed,
		blend_factor
	)

	_tentacle_coordination_current = lerpf(
		_tentacle_coordination_current,
		target_coordination,
		blend_factor
	)

	_tentacle_curl_current = lerpf(
		_tentacle_curl_current,
		target_curl,
		blend_factor
	)

	_tentacle_contraction_current = lerpf(
		_tentacle_contraction_current,
		target_contraction,
		blend_factor
	)

	_tentacle_material.set_shader_parameter(
		"activity",
		_tentacle_activity_current
	)

	_tentacle_material.set_shader_parameter(
		"movement_speed",
		_tentacle_speed_current
	)

	_tentacle_material.set_shader_parameter(
		"coordination",
		_tentacle_coordination_current
	)

	_tentacle_material.set_shader_parameter(
		"curl_strength",
		_tentacle_curl_current
	)

	_tentacle_material.set_shader_parameter(
		"contraction",
		_tentacle_contraction_current
	)


func _change_state(
	new_state: int
) -> void:
	if _behavior_state == new_state:
		return

	_behavior_state = new_state
	_state_elapsed = 0.0
	_call_played = false


static func _basis_from_forward(
	forward: Vector3
) -> Basis:
	var direction: Vector3 = forward

	if direction.is_zero_approx():
		direction = Vector3.FORWARD
	else:
		direction = direction.normalized()

	var z_axis: Vector3 = -direction
	var y_axis: Vector3 = Vector3.UP

	if absf(z_axis.dot(y_axis)) > 0.98:
		y_axis = Vector3.FORWARD

	var x_axis: Vector3 = (
		y_axis.cross(z_axis).normalized()
	)

	y_axis = z_axis.cross(x_axis).normalized()

	return Basis(
		x_axis,
		y_axis,
		z_axis
	)
