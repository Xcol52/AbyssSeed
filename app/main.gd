extends Node

const DEBUG_CONSOLE_SCENE: PackedScene = preload(
	"res://debug/console/debug_console.tscn"
)

const DEPTH_LIGHTING_CONTROLLER_SCENE: PackedScene = preload(
	"res://world/lighting/depth_lighting_controller.tscn"
)

const DIVE_SUIT_HUD_SCENE: PackedScene = preload(
	"res://player/dive_suit/dive_suit_hud.tscn"
)


@export_category("World Bootstrap")

## Packed scene whose root must use the OceanWorld class.
@export var world_scene: PackedScene

## Definition supplied to the world before it enters the SceneTree.
@export var world_definition: WorldDefinition


@export_category("Player Observer")

## Preferred player location relative to Main.
@export var observer_path: NodePath = NodePath(
	"AtmosphericDiveSuit"
)

## Fallback designation if the player is moved elsewhere in the scene.
@export var observer_group: StringName = &"player"


@export_category("Presentation")

@export var enable_depth_lighting: bool = true


@export_category("Debug")

@export var enable_depth_gauge: bool = false
@export var enable_debug_console: bool = true

@export_category("Player HUD")

@export var enable_dive_suit_hud: bool = true


var _world: OceanWorld
var _player: AtmosphericDiveSuit
var _observer: Node3D

var _depth_lighting_controller: DepthLightingController

var _debug_hud_layer: CanvasLayer
var _depth_gauge: DebugDepthGauge
var _debug_console: DebugConsole
var _dive_suit_hud_layer: CanvasLayer
var _dive_suit_hud: DiveSuitHUD


func _ready() -> void:
	_player = _resolve_player()
	_observer = _player

	_bootstrap_world()


func _resolve_player() -> AtmosphericDiveSuit:
	if observer_path != NodePath():
		var path_node: Node = get_node_or_null(
			observer_path
		)

		var path_player: AtmosphericDiveSuit = (
			path_node as AtmosphericDiveSuit
		)

		if path_player != null:
			return path_player

	if observer_group != StringName():
		var grouped_node: Node = (
			get_tree().get_first_node_in_group(
				observer_group
			)
		)

		var grouped_player: AtmosphericDiveSuit = (
			grouped_node as AtmosphericDiveSuit
		)

		if grouped_player != null:
			return grouped_player

	return null


func _bootstrap_world() -> void:
	if world_scene == null:
		push_error(
			"Main requires a world_scene."
		)
		return

	if world_definition == null:
		push_error(
			"Main requires a WorldDefinition."
		)
		return

	if _player == null:
		push_error(
			"Main requires an AtmosphericDiveSuit at "
			+ "observer_path or in observer_group."
		)
		return

	if _observer == null:
		push_error(
			"Main could not resolve the player observer."
		)
		return

	var candidate: Node = world_scene.instantiate()

	var world: OceanWorld = (
		candidate as OceanWorld
	)

	if world == null:
		candidate.free()

		push_error(
			"The configured world_scene root "
			+ "must inherit OceanWorld."
		)
		return

	if not world.configure(
		world_definition,
		_observer
	):
		world.free()
		return

	_world = world
	add_child(_world)

	var surface_query: Callable = Callable(
		_world,
		&"query_active_seafloor"
	)

	if not _player.initialize(surface_query):
		push_error(
			"Main could not initialize AtmosphericDiveSuit."
		)

		remove_child(_world)
		_world.free()
		_world = null
		return

	if enable_depth_lighting:
		_install_depth_lighting()

	if enable_depth_gauge:
		_install_depth_gauge()

	if enable_dive_suit_hud:
		_install_dive_suit_hud()

	if enable_debug_console:
		_install_debug_console()


func _install_depth_lighting() -> void:
	if (
		_world == null
		or _player == null
		or _depth_lighting_controller != null
	):
		return

	var target_environment: WorldEnvironment = (
		_find_world_environment(_world)
	)

	if target_environment == null:
		target_environment = WorldEnvironment.new()
		target_environment.name = "DepthWorldEnvironment"
		target_environment.environment = Environment.new()
		_world.add_child(target_environment)
	elif target_environment.environment == null:
		target_environment.environment = Environment.new()

	var target_light: DirectionalLight3D = (
		_find_directional_light(_world)
	)

	if target_light == null:
		target_light = DirectionalLight3D.new()
		target_light.name = "DepthDirectionalLight"
		target_light.rotation_degrees = Vector3(
			-55.0,
			-25.0,
			0.0
		)

		target_light.light_color = Color(
			0.72,
			0.86,
			1.0,
			1.0
		)

		target_light.light_energy = 1.5
		target_light.shadow_enabled = true
		_world.add_child(target_light)


	var controller_node: Node = (
		DEPTH_LIGHTING_CONTROLLER_SCENE.instantiate()
	)

	var controller: DepthLightingController = (
		controller_node as DepthLightingController
	)

	if controller == null:
		controller_node.free()

		push_error(
			"Depth lighting scene root must inherit "
			+ "DepthLightingController."
		)
		return

	controller.world_environment = target_environment
	controller.directional_light = target_light
	controller.target_node = _player

	var ocean_settings: OceanSettings = (
		world_definition.ocean_settings
	)

	if ocean_settings != null:
		controller.ocean_surface_y = (
			ocean_settings.ocean_height
		)

	_depth_lighting_controller = controller
	_world.add_child(_depth_lighting_controller)


func _find_world_environment(
	root_node: Node
) -> WorldEnvironment:
	if root_node == null:
		return null

	var environment_node: WorldEnvironment = (
		root_node as WorldEnvironment
	)

	if environment_node != null:
		return environment_node

	var child_count: int = root_node.get_child_count()

	for child_index: int in range(child_count):
		var child_node: Node = root_node.get_child(
			child_index
		)

		var child_environment: WorldEnvironment = (
			_find_world_environment(child_node)
		)

		if child_environment != null:
			return child_environment

	return null


func _find_directional_light(
	root_node: Node
) -> DirectionalLight3D:
	if root_node == null:
		return null

	var directional_light: DirectionalLight3D = (
		root_node as DirectionalLight3D
	)

	if directional_light != null:
		return directional_light

	var child_count: int = root_node.get_child_count()

	for child_index: int in range(child_count):
		var child_node: Node = root_node.get_child(
			child_index
		)

		var child_light: DirectionalLight3D = (
			_find_directional_light(child_node)
		)

		if child_light != null:
			return child_light

	return null


func _install_depth_gauge() -> void:
	if _world == null or _observer == null:
		return

	if _debug_hud_layer == null:
		_debug_hud_layer = CanvasLayer.new()
		_debug_hud_layer.name = "DebugHUD"
		add_child(_debug_hud_layer)

	if _depth_gauge != null:
		return

	_depth_gauge = DebugDepthGauge.new()
	_depth_gauge.name = "DepthGauge"

	_debug_hud_layer.add_child(
		_depth_gauge
	)

	_depth_gauge.configure(
		_world,
		_observer
	)


func _install_dive_suit_hud() -> void:
	if _world == null or _observer == null:
		return

	if _dive_suit_hud != null:
		return

	_dive_suit_hud_layer = CanvasLayer.new()
	_dive_suit_hud_layer.name = "DiveSuitHUDLayer"
	add_child(_dive_suit_hud_layer)

	var hud_node: Node = DIVE_SUIT_HUD_SCENE.instantiate()
	var hud: DiveSuitHUD = hud_node as DiveSuitHUD

	if hud == null:
		hud_node.free()
		_dive_suit_hud_layer.free()
		_dive_suit_hud_layer = null
		push_error(
			"Dive suit HUD scene root must inherit DiveSuitHUD."
		)
		return

	hud.name = "DiveSuitHUD"
	_dive_suit_hud_layer.add_child(hud)

	if not hud.configure(_world, _observer):
		hud.free()
		_dive_suit_hud_layer.free()
		_dive_suit_hud_layer = null
		return

	_dive_suit_hud = hud


func _install_debug_console() -> void:
	if _player == null:
		return

	if _debug_console != null:
		return

	var console_node: Node = (
		DEBUG_CONSOLE_SCENE.instantiate()
	)

	var console: DebugConsole = (
		console_node as DebugConsole
	)

	if console == null:
		console_node.free()

		push_error(
			"Debug console scene root must inherit DebugConsole."
		)
		return

	if not console.initialize(_player):
		console.free()

		push_error(
			"Main could not initialize DebugConsole."
		)
		return

	_debug_console = console
	add_child(_debug_console)


func set_depth_lighting_enabled(
	is_enabled: bool
) -> void:
	enable_depth_lighting = is_enabled

	if (
		is_enabled
		and _depth_lighting_controller == null
	):
		_install_depth_lighting()

	if _depth_lighting_controller != null:
		_depth_lighting_controller.set_updates_enabled(
			is_enabled
		)


func set_debug_depth_gauge_enabled(
	is_enabled: bool
) -> void:
	enable_depth_gauge = is_enabled

	if (
		is_enabled
		and _depth_gauge == null
	):
		_install_depth_gauge()

	if _debug_hud_layer != null:
		_debug_hud_layer.visible = is_enabled

	if _depth_gauge != null:
		_depth_gauge.set_monitoring_enabled(
			is_enabled
		)


func set_debug_console_enabled(
	is_enabled: bool
) -> void:
	enable_debug_console = is_enabled

	if (
		is_enabled
		and _debug_console == null
	):
		_install_debug_console()

	if _debug_console == null:
		return

	if is_enabled:
		return

	_debug_console.close_console()
	_debug_console.visible = false


func set_dive_suit_hud_enabled(
	is_enabled: bool
) -> void:
	enable_dive_suit_hud = is_enabled

	if (
		is_enabled
		and _dive_suit_hud == null
	):
		_install_dive_suit_hud()

	if _dive_suit_hud != null:
		_dive_suit_hud.set_monitoring_enabled(
			is_enabled
		)


func get_world() -> OceanWorld:
	return _world


func get_player() -> AtmosphericDiveSuit:
	return _player


func get_observer() -> Node3D:
	return _observer


func get_world_definition() -> WorldDefinition:
	return world_definition


func get_depth_lighting_controller() -> DepthLightingController:
	return _depth_lighting_controller


func get_depth_gauge() -> DebugDepthGauge:
	return _depth_gauge


func get_debug_console() -> DebugConsole:
	return _debug_console
