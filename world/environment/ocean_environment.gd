class_name OceanEnvironment
extends WorldEnvironment

## This component owns rendering atmosphere only.
## It does not change terrain residency, chunk streaming, procedural
## environmental sampling, or gameplay light calculations.

const AMBIENT_LIGHT_COLOR: Color = Color(
	0.02,
	0.10,
	0.28,
	1.0
)

const SUN_LIGHT_COLOR: Color = Color(
	0.70,
	0.84,
	0.95,
	1.0
)

const AMBIENT_LIGHT_ENERGY: float = 0.08

const SUN_LIGHT_ENERGY: float = 0.0


func _ready() -> void:
	var configured_environment: Environment = Environment.new()

	configured_environment.resource_name = (
		"Ocean Lighting Environment"
	)

	_configure_background(configured_environment)
	_configure_ambient_light(configured_environment)

	environment = configured_environment

	## OceanWorld may itself have been added dynamically by Main.
	## Deferring the search ensures the complete runtime hierarchy has
	## entered the SceneTree before the sun is inspected.
	call_deferred(&"_configure_directional_light")


func _configure_background(
	configured_environment: Environment
) -> void:
	configured_environment.background_mode = (
		Environment.BG_COLOR
	)

	configured_environment.background_color = Color(
		0.004,
		0.014,
		0.028,
		1.0
	)
	configured_environment.background_energy_multiplier = 1.0


func _configure_ambient_light(
	configured_environment: Environment
) -> void:
	configured_environment.ambient_light_source = (
		Environment.AMBIENT_SOURCE_COLOR
	)

	configured_environment.ambient_light_color = (
		AMBIENT_LIGHT_COLOR
	)

	configured_environment.ambient_light_energy = (
		AMBIENT_LIGHT_ENERGY
	)

	configured_environment.ambient_light_sky_contribution = 0.0


func _configure_directional_light() -> void:
	var scene_tree: SceneTree = get_tree()
	var search_root: Node = scene_tree.current_scene

	if search_root == null:
		search_root = scene_tree.root

	var directional_light: DirectionalLight3D = (
		_find_directional_light(search_root)
	)

	if directional_light == null:
		return

	## Keep the directional node available for scene dependencies, but let
	## the environment and water shader provide the visible depth response.
	directional_light.light_color = SUN_LIGHT_COLOR
	directional_light.light_energy = SUN_LIGHT_ENERGY


static func _find_directional_light(
	root_node: Node
) -> DirectionalLight3D:
	if root_node == null:
		return null

	var root_light: DirectionalLight3D = (
		root_node as DirectionalLight3D
	)

	if root_light != null:
		return root_light

	var child_count: int = root_node.get_child_count()

	for child_index in range(child_count):
		var child_node: Node = root_node.get_child(
			child_index
		)

		var child_light: DirectionalLight3D = (
			_find_directional_light(child_node)
		)

		if child_light != null:
			return child_light

	return null
