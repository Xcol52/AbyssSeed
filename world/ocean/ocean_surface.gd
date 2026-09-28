class_name OceanSurface
extends Node3D

var _settings: OceanSettings
var _observer: Node3D
var _ocean_mesh: ArrayMesh

var _initialized: bool = false
var _has_snapped_center: bool = false
var _snapped_center_x: float = 0.0
var _snapped_center_z: float = 0.0

@onready var _mesh_instance: MeshInstance3D = %OceanMesh
@onready var _ocean_space: Node3D = get_parent() as Node3D


func _ready() -> void:
	# OceanWorld enables processing only after explicit initialization.
	set_process(false)


func initialize(settings: OceanSettings, observer: Node3D) -> bool:
	if _initialized:
		push_error("OceanSurface can only be initialized once.")
		return false

	if not is_node_ready():
		push_error(
			"OceanSurface must be initialized after it has entered the SceneTree."
		)
		return false

	if settings == null:
		push_error("OceanSurface requires OceanSettings.")
		return false

	if observer == null or not is_instance_valid(observer):
		push_error("OceanSurface requires a valid observer.")
		return false

	if _ocean_space == null:
		push_error("OceanSurface must be parented to a Node3D.")
		return false

	var validation_errors := settings.validate()
	if not validation_errors.is_empty():
		for message in validation_errors:
			push_error("Invalid OceanSettings: %s" % message)
		return false

	_settings = settings
	_observer = observer

	# This is the only mesh construction performed by this component.
	_ocean_mesh = _generate_mesh(_settings)
	_mesh_instance.mesh = _ocean_mesh

	_initialized = true
	_recenter_to_observer(true)
	set_process(true)

	return true


func _process(_delta: float) -> void:
	if _observer == null or not is_instance_valid(_observer):
		set_process(false)
		return

	_recenter_to_observer(false)


func _recenter_to_observer(force: bool) -> void:
	# Convert from the observer's global coordinates into OceanRoot-local space.
	# This remains valid if WorldContent is later moved by floating-origin logic.
	var observer_position := _ocean_space.to_local(_observer.global_position)

	var target_x := snappedf(
		observer_position.x,
		_settings.recenter_distance
	)
	var target_z := snappedf(
		observer_position.z,
		_settings.recenter_distance
	)

	if (
		not force
		and _has_snapped_center
		and target_x == _snapped_center_x
		and target_z == _snapped_center_z
	):
		return

	_snapped_center_x = target_x
	_snapped_center_z = target_z
	_has_snapped_center = true

	position = Vector3(
		_snapped_center_x,
		_settings.ocean_height,
		_snapped_center_z
	)


func _generate_mesh(settings: OceanSettings) -> ArrayMesh:
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var cells_per_axis := settings.mesh_resolution
	var vertices_per_axis := cells_per_axis + 1
	var half_size := settings.grid_size * 0.5

	# Generate shared grid vertices.
	for z_index in range(vertices_per_axis):
		var z_ratio := float(z_index) / float(cells_per_axis)
		var z_position := -half_size + z_ratio * settings.grid_size

		for x_index in range(vertices_per_axis):
			var x_ratio := float(x_index) / float(cells_per_axis)
			var x_position := -half_size + x_ratio * settings.grid_size

			surface_tool.set_normal(Vector3.UP)
			surface_tool.set_uv(Vector2(x_ratio, z_ratio))
			surface_tool.add_vertex(
				Vector3(x_position, 0.0, z_position)
			)

	# Connect each group of four vertices with two indexed triangles.
	for z_index in range(cells_per_axis):
		for x_index in range(cells_per_axis):
			var top_left := z_index * vertices_per_axis + x_index
			var top_right := top_left + 1
			var bottom_left := top_left + vertices_per_axis
			var bottom_right := bottom_left + 1

			# Winding produces an upward-facing geometric normal.
			surface_tool.add_index(top_left)
			surface_tool.add_index(bottom_left)
			surface_tool.add_index(top_right)

			surface_tool.add_index(top_right)
			surface_tool.add_index(bottom_left)
			surface_tool.add_index(bottom_right)

	var mesh := ArrayMesh.new()
	mesh.resource_name = "Procedural Ocean Grid"
	surface_tool.commit(mesh)

	return mesh
