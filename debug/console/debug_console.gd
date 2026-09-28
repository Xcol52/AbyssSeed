class_name DebugConsole
extends CanvasLayer

class GeometryFullbrightState:
	extends RefCounted

	var instance: GeometryInstance3D
	var material_override: Material
	var visibility_range_begin: float
	var visibility_range_end: float

	func _init(
		target_instance: GeometryInstance3D
	) -> void:
		instance = target_instance
		material_override = target_instance.material_override
		visibility_range_begin = (
			target_instance.visibility_range_begin
		)
		visibility_range_end = (
			target_instance.visibility_range_end
		)


class EnvironmentFullbrightState:
	extends RefCounted

	var world_environment: WorldEnvironment
	var environment_resource: Environment

	var background_mode: int
	var background_color: Color
	var background_energy_multiplier: float

	var ambient_light_source: int
	var ambient_light_color: Color
	var ambient_light_energy: float
	var ambient_light_sky_contribution: float

	func _init(
		target_world_environment: WorldEnvironment,
		target_environment: Environment
	) -> void:
		world_environment = target_world_environment
		environment_resource = target_environment

		background_mode = target_environment.background_mode
		background_color = target_environment.background_color
		background_energy_multiplier = (
			target_environment.background_energy_multiplier
		)

		ambient_light_source = (
			target_environment.ambient_light_source
		)

		ambient_light_color = (
			target_environment.ambient_light_color
		)

		ambient_light_energy = (
			target_environment.ambient_light_energy
		)

		ambient_light_sky_contribution = (
			target_environment
				.ambient_light_sky_contribution
		)


class CameraFullbrightState:
	extends RefCounted

	var camera: Camera3D
	var far_distance: float

	func _init(
		target_camera: Camera3D
	) -> void:
		camera = target_camera
		far_distance = target_camera.far


const TRENCH_WORLD_X: float = 5000.0
const TRENCH_WORLD_Z: float = 5000.0
const DEBUG_ENCOUNTER_SEED: int = 9001

const FULLBRIGHT_CAMERA_FAR_DISTANCE: float = 100000.0

const DEBUG_CAMERA_SCENE: PackedScene = preload(
	"res://debug/camera/debug_camera.tscn"
)


@onready var _command_history: RichTextLabel = (
	%CommandHistory as RichTextLabel
)

@onready var _command_input: LineEdit = (
	%CommandInput as LineEdit
)


var _player: AtmosphericDiveSuit
var _initialized: bool = false

var _debug_camera: DebugCamera
var _player_camera: Camera3D

var _player_process_enabled: bool = true
var _player_input_enabled: bool = false
var _player_unhandled_input_enabled: bool = true
var _player_unhandled_key_input_enabled: bool = false

var _fullbright_enabled: bool = false
var _fullbright_material: StandardMaterial3D
var _fullbright_ocean_material: StandardMaterial3D

## Instance ID -> GeometryFullbrightState
var _geometry_fullbright_states: Dictionary = {}

## Instance ID -> EnvironmentFullbrightState
var _environment_fullbright_states: Dictionary = {}

## Instance ID -> CameraFullbrightState
var _camera_fullbright_states: Dictionary = {}


func _ready() -> void:
	if not _validate_required_nodes():
		set_process_unhandled_input(false)
		return

	_command_input.text_submitted.connect(
		_on_command_submitted
	)

	_command_input.gui_input.connect(
		_on_command_input_gui_input
	)

	_create_fullbright_materials()
	visible = false


func initialize(
	player_suit: AtmosphericDiveSuit
) -> bool:
	if _initialized:
		push_error(
			"DebugConsole can only be initialized once."
		)
		return false

	if (
		player_suit == null
		or not is_instance_valid(player_suit)
	):
		push_error(
			"DebugConsole requires a valid AtmosphericDiveSuit."
		)
		return false

	_player = player_suit
	_player_camera = _find_camera(_player)
	_initialized = true

	if _player_camera == null:
		push_error(
			"DebugConsole could not find the player's Camera3D."
		)
		return false

	return true


func _unhandled_input(
	input_event: InputEvent
) -> void:
	var key_event: InputEventKey = (
		input_event as InputEventKey
	)

	if (
		key_event == null
		or not key_event.pressed
		or key_event.echo
	):
		return

	if visible:
		if (
			key_event.physical_keycode == KEY_ESCAPE
			or _is_console_toggle_key(key_event)
		):
			_set_console_open(false)
			get_viewport().set_input_as_handled()

		return

	if _is_console_toggle_key(key_event):
		_set_console_open(true)
		get_viewport().set_input_as_handled()


func _on_command_input_gui_input(
	input_event: InputEvent
) -> void:
	var key_event: InputEventKey = (
		input_event as InputEventKey
	)

	if (
		key_event == null
		or not key_event.pressed
		or key_event.echo
	):
		return

	if (
		key_event.physical_keycode == KEY_ESCAPE
		or _is_console_toggle_key(key_event)
	):
		_set_console_open(false)
		_command_input.accept_event()


func _is_console_toggle_key(
	key_event: InputEventKey
) -> bool:
	return (
		key_event.physical_keycode == KEY_QUOTELEFT
		or key_event.physical_keycode == KEY_SLASH
	)


func _set_console_open(
	is_open: bool
) -> void:
	visible = is_open

	if is_open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_command_input.text = "/"
		_command_input.caret_column = (
			_command_input.text.length()
		)
		_command_input.grab_focus()
		return

	_command_input.clear()
	_command_input.release_focus()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_command_submitted(
	submitted_text: String
) -> void:
	var normalized_command: String = (
		submitted_text.strip_edges()
	)

	_append_output(
		"> %s" % normalized_command
	)

	if normalized_command.begins_with("/"):
		normalized_command = normalized_command.substr(1)

	normalized_command = normalized_command.strip_edges()

	if normalized_command.is_empty():
		_prepare_next_command()
		return

	var command_parts: PackedStringArray = (
		normalized_command.split(
			" ",
			false
		)
	)

	if command_parts.is_empty():
		_prepare_next_command()
		return

	var command_name: String = (
		command_parts[0].to_lower()
	)

	match command_name:
		"help":
			_print_help()

		"tp":
			_handle_teleport_command(
				command_parts
			)

		"spawn":
			_handle_spawn_giant_squid_command(
				command_parts
			)

		"summon":
			_handle_spawn_giant_squid_command(
				command_parts
			)

		"fullbright":
			_handle_fullbright_command(
				command_parts
			)

		"debug_camera":
			_handle_debug_camera_command(
				command_parts
			)

		_:
			_append_output(
				"Unknown command: /%s"
				% command_name
			)

	if visible:
		_prepare_next_command()


func _handle_fullbright_command(
	command_parts: PackedStringArray
) -> void:
	if command_parts.size() > 2:
		_append_output(
			"Usage: /fullbright [on|off]"
		)
		return

	var target_enabled: bool = not _fullbright_enabled

	if command_parts.size() == 2:
		var state_text: String = (
			command_parts[1].to_lower()
		)

		match state_text:
			"on":
				target_enabled = true

			"off":
				target_enabled = false

			_:
				_append_output(
					"Usage: /fullbright [on|off]"
				)
				return

	_set_fullbright_enabled(target_enabled)

	if _fullbright_enabled:
		_append_output(
			"Fullbright enabled: shader materials, "
			+ "distance culling, and normal camera range "
			+ "are overridden."
		)
	else:
		_append_output(
			"Fullbright disabled: captured rendering "
			+ "state restored."
		)


func _set_fullbright_enabled(
	is_enabled: bool
) -> void:
	if is_enabled == _fullbright_enabled:
		return

	_fullbright_enabled = is_enabled

	if _fullbright_enabled:
		_enable_fullbright()
	else:
		_disable_fullbright()


func _enable_fullbright() -> void:
	var scene_tree: SceneTree = get_tree()
	var search_root: Node = scene_tree.current_scene

	if search_root == null:
		search_root = scene_tree.root

	_apply_fullbright_to_subtree(search_root)

	var node_added_callback: Callable = Callable(
		self,
		&"_on_scene_node_added"
	)

	if not scene_tree.node_added.is_connected(
		node_added_callback
	):
		scene_tree.node_added.connect(
			node_added_callback
		)


func _disable_fullbright() -> void:
	var scene_tree: SceneTree = get_tree()

	if scene_tree != null:
		var node_added_callback: Callable = Callable(
			self,
			&"_on_scene_node_added"
		)

		if scene_tree.node_added.is_connected(
			node_added_callback
		):
			scene_tree.node_added.disconnect(
				node_added_callback
			)

	for state_value: Variant in (
		_geometry_fullbright_states.values()
	):
		var geometry_state: GeometryFullbrightState = (
			state_value as GeometryFullbrightState
		)

		if (
			geometry_state == null
			or geometry_state.instance == null
			or not is_instance_valid(
				geometry_state.instance
			)
		):
			continue

		geometry_state.instance.material_override = (
			geometry_state.material_override
		)

		geometry_state.instance.visibility_range_begin = (
			geometry_state.visibility_range_begin
		)

		geometry_state.instance.visibility_range_end = (
			geometry_state.visibility_range_end
		)

	for state_value: Variant in (
		_environment_fullbright_states.values()
	):
		var environment_state: EnvironmentFullbrightState = (
			state_value as EnvironmentFullbrightState
		)

		if environment_state == null:
			continue

		var environment_resource: Environment = (
			environment_state.environment_resource
		)

		if (
			environment_resource == null
			or not is_instance_valid(
				environment_resource
			)
		):
			continue

		environment_resource.background_mode = (
			environment_state.background_mode
		)

		environment_resource.background_color = (
			environment_state.background_color
		)

		environment_resource.background_energy_multiplier = (
			environment_state
				.background_energy_multiplier
		)

		environment_resource.ambient_light_source = (
			environment_state.ambient_light_source
		)

		environment_resource.ambient_light_color = (
			environment_state.ambient_light_color
		)

		environment_resource.ambient_light_energy = (
			environment_state.ambient_light_energy
		)

		environment_resource.ambient_light_sky_contribution = (
			environment_state
				.ambient_light_sky_contribution
		)

	for state_value: Variant in (
		_camera_fullbright_states.values()
	):
		var camera_state: CameraFullbrightState = (
			state_value as CameraFullbrightState
		)

		if (
			camera_state == null
			or camera_state.camera == null
			or not is_instance_valid(camera_state.camera)
		):
			continue

		camera_state.camera.far = (
			camera_state.far_distance
		)

	_geometry_fullbright_states.clear()
	_environment_fullbright_states.clear()
	_camera_fullbright_states.clear()


func _on_scene_node_added(
	added_node: Node
) -> void:
	if not _fullbright_enabled:
		return

	_apply_fullbright_to_subtree(added_node)


func _apply_fullbright_to_subtree(
	root_node: Node
) -> void:
	if root_node == null:
		return

	var geometry_instance: GeometryInstance3D = (
		root_node as GeometryInstance3D
	)

	if geometry_instance != null:
		_apply_fullbright_to_geometry(
			geometry_instance
		)

	var world_environment: WorldEnvironment = (
		root_node as WorldEnvironment
	)

	if world_environment != null:
		_apply_fullbright_to_environment(
			world_environment
		)

	var camera: Camera3D = (
		root_node as Camera3D
	)

	if camera != null:
		_apply_fullbright_to_camera(camera)

	var child_count: int = root_node.get_child_count()

	for child_index in range(child_count):
		var child_node: Node = root_node.get_child(
			child_index
		)

		_apply_fullbright_to_subtree(child_node)


func _apply_fullbright_to_geometry(
	geometry_instance: GeometryInstance3D
) -> void:
	if not is_instance_valid(geometry_instance):
		return

	var instance_id: int = (
		geometry_instance.get_instance_id()
	)

	if not _geometry_fullbright_states.has(
		instance_id
	):
		var geometry_state: GeometryFullbrightState = (
			GeometryFullbrightState.new(
				geometry_instance
			)
		)

		_geometry_fullbright_states[
			instance_id
		] = geometry_state

	if _is_ocean_geometry(geometry_instance):
		geometry_instance.material_override = (
			_fullbright_ocean_material
		)
	else:
		geometry_instance.material_override = (
			_fullbright_material
		)

	## Zero disables GeometryInstance distance-range culling.
	geometry_instance.visibility_range_begin = 0.0
	geometry_instance.visibility_range_end = 0.0


func _apply_fullbright_to_environment(
	world_environment: WorldEnvironment
) -> void:
	var environment_resource: Environment = (
		world_environment.environment
	)

	if environment_resource == null:
		return

	var instance_id: int = (
		world_environment.get_instance_id()
	)

	if not _environment_fullbright_states.has(
		instance_id
	):
		var environment_state: EnvironmentFullbrightState = (
			EnvironmentFullbrightState.new(
				world_environment,
				environment_resource
			)
		)

		_environment_fullbright_states[
			instance_id
		] = environment_state

	environment_resource.background_mode = (
		Environment.BG_COLOR
	)

	environment_resource.background_color = Color(
		0.18,
		0.32,
		0.38,
		1.0
	)

	environment_resource.background_energy_multiplier = 1.0

	environment_resource.ambient_light_source = (
		Environment.AMBIENT_SOURCE_COLOR
	)

	environment_resource.ambient_light_color = Color.WHITE
	environment_resource.ambient_light_energy = 1.0
	environment_resource.ambient_light_sky_contribution = 0.0


func _apply_fullbright_to_camera(
	camera: Camera3D
) -> void:
	var instance_id: int = camera.get_instance_id()

	if not _camera_fullbright_states.has(instance_id):
		var camera_state: CameraFullbrightState = (
			CameraFullbrightState.new(camera)
		)

		_camera_fullbright_states[
			instance_id
		] = camera_state

	camera.far = maxf(
		camera.far,
		FULLBRIGHT_CAMERA_FAR_DISTANCE
	)


func _is_ocean_geometry(
	geometry_instance: GeometryInstance3D
) -> bool:
	var current_node: Node = geometry_instance

	while current_node != null:
		if (
			current_node.name == &"OceanMesh"
			or current_node.name == &"OceanSurface"
			or current_node.name == &"OceanRoot"
		):
			return true

		current_node = current_node.get_parent()

	return false


func _create_fullbright_materials() -> void:
	_fullbright_material = StandardMaterial3D.new()
	_fullbright_material.resource_name = (
		"Debug Fullbright Material"
	)

	_fullbright_material.shading_mode = (
		BaseMaterial3D.SHADING_MODE_UNSHADED
	)

	_fullbright_material.cull_mode = (
		BaseMaterial3D.CULL_DISABLED
	)

	_fullbright_material.albedo_color = Color(
		0.72,
		0.86,
		0.76,
		1.0
	)

	_fullbright_ocean_material = StandardMaterial3D.new()
	_fullbright_ocean_material.resource_name = (
		"Debug Fullbright Ocean Material"
	)

	_fullbright_ocean_material.shading_mode = (
		BaseMaterial3D.SHADING_MODE_UNSHADED
	)

	_fullbright_ocean_material.cull_mode = (
		BaseMaterial3D.CULL_DISABLED
	)

	_fullbright_ocean_material.transparency = (
		BaseMaterial3D.TRANSPARENCY_ALPHA
	)

	_fullbright_ocean_material.albedo_color = Color(
		0.08,
		0.55,
		0.70,
		0.16
	)


func _handle_debug_camera_command(
	command_parts: PackedStringArray
) -> void:
	if command_parts.size() > 2:
		_append_output(
			"Usage: /debug_camera [on|off]"
		)
		return

	var currently_enabled: bool = (
		_debug_camera != null
		and is_instance_valid(_debug_camera)
	)

	var target_enabled: bool = not currently_enabled

	if command_parts.size() == 2:
		var state_text: String = (
			command_parts[1].to_lower()
		)

		match state_text:
			"on":
				target_enabled = true

			"off":
				target_enabled = false

			_:
				_append_output(
					"Usage: /debug_camera [on|off]"
				)
				return

	if target_enabled:
		_enable_debug_camera()
	else:
		_disable_debug_camera()

	_set_console_open(false)


func _enable_debug_camera() -> void:
	if (
		_debug_camera != null
		and is_instance_valid(_debug_camera)
	):
		_append_output(
			"Debug camera is already enabled."
		)
		return

	if not _has_valid_player():
		_append_output(
			"Debug camera failed: player is unavailable."
		)
		return

	if (
		_player_camera == null
		or not is_instance_valid(_player_camera)
	):
		_player_camera = _find_camera(_player)

	if _player_camera == null:
		_append_output(
			"Debug camera failed: player Camera3D "
			+ "was not found."
		)
		return

	var camera_node: Node = (
		DEBUG_CAMERA_SCENE.instantiate()
	)

	var debug_camera: DebugCamera = (
		camera_node as DebugCamera
	)

	if debug_camera == null:
		camera_node.free()

		_append_output(
			"Debug camera scene root must inherit "
			+ "DebugCamera."
		)
		return

	if not debug_camera.initialize_from_camera(
		_player_camera
	):
		debug_camera.free()

		_append_output(
			"Debug camera initialization failed."
		)
		return

	_player_process_enabled = _player.is_processing()
	_player_input_enabled = _player.is_processing_input()

	_player_unhandled_input_enabled = (
		_player.is_processing_unhandled_input()
	)

	_player_unhandled_key_input_enabled = (
		_player.is_processing_unhandled_key_input()
	)

	_player.set_process(false)
	_player.set_process_input(false)
	_player.set_process_unhandled_input(false)
	_player.set_process_unhandled_key_input(false)

	var scene_tree: SceneTree = get_tree()
	var camera_parent: Node = scene_tree.current_scene

	if camera_parent == null:
		camera_parent = scene_tree.root

	_debug_camera = debug_camera
	camera_parent.add_child(_debug_camera)

	_append_output(
		"Debug camera enabled. WASD moves relative "
		+ "to view; Q/E move vertically; Shift boosts speed."
	)


func _disable_debug_camera() -> void:
	if (
		_debug_camera == null
		or not is_instance_valid(_debug_camera)
	):
		_debug_camera = null
		_append_output(
			"Debug camera is already disabled."
		)
		return

	_debug_camera.queue_free()
	_debug_camera = null

	if _has_valid_player():
		_player.set_process(
			_player_process_enabled
		)

		_player.set_process_input(
			_player_input_enabled
		)

		_player.set_process_unhandled_input(
			_player_unhandled_input_enabled
		)

		_player.set_process_unhandled_key_input(
			_player_unhandled_key_input_enabled
		)

	if (
		_player_camera != null
		and is_instance_valid(_player_camera)
	):
		_player_camera.make_current()

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	_append_output(
		"Debug camera disabled; player camera restored."
	)


func _handle_teleport_command(
	command_parts: PackedStringArray
) -> void:
	if not _has_valid_player():
		_append_output(
			"Teleport failed: player is unavailable."
		)
		return

	if command_parts.size() == 2:
		var destination_name: String = (
			command_parts[1].to_lower()
		)

		if destination_name == "trench":
			var succeeded: bool = (
				_player.teleport_to_world_xz(
					TRENCH_WORLD_X,
					TRENCH_WORLD_Z
				)
			)

			if succeeded:
				_append_output(
					"Teleported to trench at "
					+ "X=5000, Z=5000."
				)
			else:
				_append_output(
					"Trench teleport failed."
				)

			return

	if command_parts.size() != 3:
		_append_output(
			"Usage: /tp <x> <z> or /tp trench"
		)
		return

	var x_text: String = command_parts[1]
	var z_text: String = command_parts[2]

	if (
		not x_text.is_valid_float()
		or not z_text.is_valid_float()
	):
		_append_output(
			"Teleport failed: X and Z must be numbers."
		)
		return

	var world_x: float = x_text.to_float()
	var world_z: float = z_text.to_float()

	if (
		not is_finite(world_x)
		or not is_finite(world_z)
	):
		_append_output(
			"Teleport failed: coordinates must be finite."
		)
		return

	if not _player.teleport_to_world_xz(
		world_x,
		world_z
	):
		_append_output(
			"Teleport failed."
		)
		return

	_append_output(
		"Teleported to X=%.2f, Z=%.2f."
		% [
			world_x,
			world_z,
		]
	)


func _handle_spawn_giant_squid_command(
	command_parts: PackedStringArray
) -> void:
	var targets_giant_squid: bool = false

	if command_parts.size() == 2:
		targets_giant_squid = (
			command_parts[1].to_lower()
			== "giant_squid"
		)
	elif command_parts.size() == 3:
		targets_giant_squid = (
			command_parts[1].to_lower() == "giant"
			and command_parts[2].to_lower() == "squid"
		)

	if not targets_giant_squid:
		_append_output(
			"Usage: /spawn giant squid"
		)
		return

	if not _has_valid_player():
		_append_output(
			"Spawn failed: player is unavailable."
		)
		return

	var active_camera: Camera3D = (
		get_viewport().get_camera_3d()
	)

	if (
		active_camera == null
		or not is_instance_valid(active_camera)
	):
		_append_output(
			"Spawn failed: no active Camera3D."
		)
		return

	var camera_forward: Vector3 = (
		-active_camera.global_transform.basis.z
	)

	if camera_forward.is_zero_approx():
		_append_output(
			"Spawn failed: camera direction is invalid."
		)
		return

	camera_forward = camera_forward.normalized()

	# Keep the encounter close enough to emerge inside the revised
	# flashlight range, but far enough away that the 50-meter procedural
	# squid does not begin directly on top of the camera.
	var spawn_position: Vector3 = (
		active_camera.global_position
		+ camera_forward * 35.0
		+ Vector3.DOWN * 3.0
	)

	# Never place the debug encounter above the ocean surface when the
	# player or debug camera is breaching.
	spawn_position.y = minf(
		spawn_position.y,
		-2.0
	)

	var scene_tree: SceneTree = get_tree()
	var search_root: Node = scene_tree.current_scene

	if search_root == null:
		search_root = scene_tree.root

	var coordinator: Node = (
		_find_encounter_coordinator(search_root)
	)

	if coordinator == null:
		_append_output(
			"Spawn failed: GiantSquidCoordinator "
			+ "was not found."
		)
		return

	var encounter_result: Variant = coordinator.call(
		&"force_debug_encounter",
		spawn_position,
		DEBUG_ENCOUNTER_SEED
	)

	if not (encounter_result is int):
		_append_output(
			"Spawn failed: coordinator returned "
			+ "an invalid stable ID."
		)
		return

	var stable_id: int = int(encounter_result)

	if stable_id == 0:
		_append_output(
			"Spawn failed: encounter request was rejected."
		)
		return

	_append_output(
		"Giant squid spawned 35 meters ahead "
		+ "at (%.1f, %.1f, %.1f), ID %d."
		% [
			spawn_position.x,
			spawn_position.y,
			spawn_position.z,
			stable_id,
		]
	)


func _find_encounter_coordinator(
	root_node: Node
) -> Node:
	if root_node == null:
		return null

	if root_node.has_method(
		&"force_debug_encounter"
	):
		return root_node

	var child_count: int = root_node.get_child_count()

	for child_index in range(child_count):
		var child_node: Node = root_node.get_child(
			child_index
		)

		var coordinator: Node = (
			_find_encounter_coordinator(child_node)
		)

		if coordinator != null:
			return coordinator

	return null


func _find_camera(
	root_node: Node
) -> Camera3D:
	if root_node == null:
		return null

	var root_camera: Camera3D = (
		root_node as Camera3D
	)

	if root_camera != null:
		return root_camera

	var child_count: int = root_node.get_child_count()

	for child_index in range(child_count):
		var child_node: Node = root_node.get_child(
			child_index
		)

		var child_camera: Camera3D = (
			_find_camera(child_node)
		)

		if child_camera != null:
			return child_camera

	return null


func _print_help() -> void:
	_append_output("Available commands:")
	_append_output("  /tp <x> <z>")
	_append_output("  /tp trench")
	_append_output("  /spawn giant squid")
	_append_output("  /summon giant_squid")
	_append_output("  /fullbright [on|off]")
	_append_output("  /debug_camera [on|off]")


func _prepare_next_command() -> void:
	_command_input.text = "/"
	_command_input.caret_column = (
		_command_input.text.length()
	)
	_command_input.grab_focus()


func _append_output(
	output_text: String
) -> void:
	if _command_history == null:
		return

	_command_history.append_text(
		output_text + "\n"
	)


func _has_valid_player() -> bool:
	return (
		_initialized
		and _player != null
		and is_instance_valid(_player)
	)


func _validate_required_nodes() -> bool:
	if _command_history == null:
		push_error(
			"DebugConsole requires CommandHistory."
		)
		return false

	if _command_input == null:
		push_error(
			"DebugConsole requires CommandInput."
		)
		return false

	return true


func is_console_open() -> bool:
	return visible


func is_fullbright_enabled() -> bool:
	return _fullbright_enabled


func is_debug_camera_enabled() -> bool:
	return (
		_debug_camera != null
		and is_instance_valid(_debug_camera)
	)


func close_console() -> void:
	_set_console_open(false)


func _exit_tree() -> void:
	if _fullbright_enabled:
		_set_fullbright_enabled(false)

	if (
		_debug_camera != null
		and is_instance_valid(_debug_camera)
	):
		_disable_debug_camera()
