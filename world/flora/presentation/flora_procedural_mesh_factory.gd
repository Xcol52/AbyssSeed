class_name FloraProceduralMeshFactory
extends RefCounted

## Procedural validation meshes for the initial flora catalog.
##
## Every model:
##
## - Uses a ground-level pivot.
## - Uses vertex colors.
## - Contains one mesh surface.
## - Is suitable for later MultiMesh presentation.
## - Is immutable after construction.

static var _mesh_cache: Dictionary = {}


static func create_mesh(
	species_id: int
) -> ArrayMesh:
	if _mesh_cache.has(species_id):
		return _mesh_cache[species_id] as ArrayMesh

	var mesh: ArrayMesh = null

	match species_id:
		FloraIds.GIANT_KELP:
			mesh = _create_giant_kelp()

		FloraIds.SEAGRASS:
			mesh = _create_seagrass()

		FloraIds.REEF_MACROALGAE:
			mesh = _create_reef_macroalgae()

		FloraIds.RED_FAN_ALGAE:
			mesh = _create_red_fan_algae()

		FloraIds.CORALLINE_ALGAE:
			mesh = _create_coralline_algae()

		_:
			return null

	if mesh != null:
		mesh.resource_name = (
			"%s Procedural Mesh"
			% FloraIds.get_display_name(species_id)
		)

		_mesh_cache[species_id] = mesh

	return mesh


static func clear_cache() -> void:
	_mesh_cache.clear()


static func get_nominal_height(
	species_id: int
) -> float:
	match species_id:
		FloraIds.GIANT_KELP:
			return 7.2

		FloraIds.SEAGRASS:
			return 1.45

		FloraIds.REEF_MACROALGAE:
			return 2.25

		FloraIds.RED_FAN_ALGAE:
			return 2.0

		FloraIds.CORALLINE_ALGAE:
			return 0.16

		_:
			return 0.0


static func get_base_color(
	species_id: int
) -> Color:
	match species_id:
		FloraIds.GIANT_KELP:
			return Color(0.30, 0.46, 0.08, 1.0)

		FloraIds.SEAGRASS:
			return Color(0.18, 0.58, 0.22, 1.0)

		FloraIds.REEF_MACROALGAE:
			return Color(0.43, 0.29, 0.08, 1.0)

		FloraIds.RED_FAN_ALGAE:
			return Color(0.68, 0.08, 0.18, 1.0)

		FloraIds.CORALLINE_ALGAE:
			return Color(0.72, 0.24, 0.48, 1.0)

		_:
			return Color.MAGENTA


static func _create_giant_kelp() -> ArrayMesh:
	var material := FloraMaterialFactory.get_material(
		FloraIds.GIANT_KELP
	)

	var tool := _begin_mesh(material)

	var stalk_color := Color(
		0.24,
		0.34,
		0.055,
		1.0
	)

	var blade_color := get_base_color(
		FloraIds.GIANT_KELP
	)

	_add_tapered_cylinder(
		tool,
		Vector3(0.0, 0.0, 0.0),
		Vector3(0.05, 6.65, 0.0),
		0.11,
		0.055,
		7,
		stalk_color
	)

	for leaf_index in range(11):
		var height := 0.85 + float(leaf_index) * 0.51

		var angle := (
			float(leaf_index) * 2.399963
			+ 0.35
		)

		var leaf_length := (
			1.25
			+ 0.12 * float(leaf_index % 4)
		)

		var leaf_width := (
			0.32
			+ 0.045 * float(leaf_index % 3)
		)

		var color_factor := (
			0.82
			+ 0.055 * float(leaf_index % 4)
		)

		_add_kelp_leaf(
			tool,
			Vector3(0.03, height, 0.0),
			angle,
			leaf_length,
			leaf_width,
			_shade(blade_color, color_factor)
		)

	for crown_index in range(5):
		var angle := (
			float(crown_index) * TAU / 5.0
			+ 0.25
		)

		_add_blade(
			tool,
			Vector3(0.04, 6.25, 0.0),
			1.15 + 0.16 * float(crown_index % 2),
			0.26,
			0.42,
			angle,
			_shade(
				blade_color,
				0.92 + 0.04 * float(crown_index)
			),
			5
		)

	return _finish_mesh(tool)


static func _create_seagrass() -> ArrayMesh:
	var material := FloraMaterialFactory.get_material(
		FloraIds.SEAGRASS
	)

	var tool := _begin_mesh(material)
	var base_color := get_base_color(
		FloraIds.SEAGRASS
	)

	for blade_index in range(18):
		var ratio := float(blade_index) / 18.0
		var angle := (
			float(blade_index) * 2.399963
			+ ratio * 0.4
		)

		var radius := (
			0.07
			+ 0.30 * float(blade_index % 5) / 4.0
		)

		var base := Vector3(
			cos(angle) * radius,
			0.0,
			sin(angle) * radius
		)

		var height := (
			0.68
			+ 0.16 * float(blade_index % 5)
		)

		var width := (
			0.055
			+ 0.012 * float(blade_index % 3)
		)

		var lean := (
			0.12
			+ 0.055 * float(blade_index % 4)
		)

		_add_blade(
			tool,
			base,
			height,
			width,
			lean,
			angle,
			_shade(
				base_color,
				0.72
				+ 0.055 * float(blade_index % 5)
			),
			5
		)

	return _finish_mesh(tool)


static func _create_reef_macroalgae() -> ArrayMesh:
	var material := FloraMaterialFactory.get_material(
		FloraIds.REEF_MACROALGAE
	)

	var tool := _begin_mesh(material)

	var stem_color := Color(
		0.28,
		0.19,
		0.045,
		1.0
	)

	var leaf_color := get_base_color(
		FloraIds.REEF_MACROALGAE
	)

	var trunk_top := Vector3(
		0.0,
		1.45,
		0.0
	)

	_add_tapered_cylinder(
		tool,
		Vector3.ZERO,
		trunk_top,
		0.13,
		0.07,
		7,
		stem_color
	)

	for branch_index in range(7):
		var angle := (
			float(branch_index) * TAU / 7.0
			+ 0.24
		)

		var start_height := (
			0.42
			+ 0.14 * float(branch_index % 4)
		)

		var start := Vector3(
			0.0,
			start_height,
			0.0
		)

		var direction := Vector3(
			cos(angle),
			0.72 + 0.08 * float(branch_index % 2),
			sin(angle)
		).normalized()

		var branch_length := (
			0.78
			+ 0.10 * float(branch_index % 3)
		)

		var end := start + direction * branch_length

		_add_tapered_cylinder(
			tool,
			start,
			end,
			0.075,
			0.035,
			6,
			stem_color
		)

		_add_blade(
			tool,
			end - Vector3(0.0, 0.06, 0.0),
			0.58 + 0.08 * float(branch_index % 2),
			0.23,
			0.20,
			angle,
			_shade(
				leaf_color,
				0.78
				+ 0.06 * float(branch_index % 4)
			),
			4
		)

	for crown_index in range(4):
		var angle := (
			float(crown_index) * TAU / 4.0
			+ 0.65
		)

		_add_blade(
			tool,
			trunk_top - Vector3(0.0, 0.08, 0.0),
			0.76,
			0.25,
			0.28,
			angle,
			_shade(
				leaf_color,
				0.88
				+ 0.035 * float(crown_index)
			),
			5
		)

	return _finish_mesh(tool)


static func _create_red_fan_algae() -> ArrayMesh:
	var material := FloraMaterialFactory.get_material(
		FloraIds.RED_FAN_ALGAE
	)

	var tool := _begin_mesh(material)

	var stem_color := Color(
		0.34,
		0.035,
		0.07,
		1.0
	)

	var fan_color := get_base_color(
		FloraIds.RED_FAN_ALGAE
	)

	var fan_center := Vector3(
		0.0,
		0.62,
		0.0
	)

	_add_tapered_cylinder(
		tool,
		Vector3.ZERO,
		fan_center,
		0.09,
		0.055,
		7,
		stem_color
	)

	var fan_points: Array[Vector3] = []
	var fan_segments := 12

	for index in range(fan_segments + 1):
		var ratio := (
			float(index)
			/ float(fan_segments)
		)

		var angle := lerpf(
			deg_to_rad(14.0),
			deg_to_rad(166.0),
			ratio
		)

		var radius := (
			1.03
			+ 0.10 * sin(float(index) * 2.1)
		)

		fan_points.append(
			fan_center
			+ Vector3(
				cos(angle) * radius,
				sin(angle) * radius,
				0.0
			)
		)

	for index in range(fan_segments):
		var color := _shade(
			fan_color,
			0.77
			+ 0.035 * float(index % 5)
		)

		_add_triangle(
			tool,
			fan_center,
			fan_points[index],
			fan_points[index + 1],
			color,
			Vector2(0.5, 0.0),
			Vector2(
				float(index) / float(fan_segments),
				1.0
			),
			Vector2(
				float(index + 1)
				/ float(fan_segments),
				1.0
			)
		)

	for rib_index in range(0, fan_segments + 1, 2):
		var rib_end := (
			fan_points[rib_index]
			+ Vector3(0.0, 0.0, 0.012)
		)

		_add_tapered_cylinder(
			tool,
			fan_center
				+ Vector3(0.0, 0.0, 0.012),
			rib_end,
			0.020,
			0.008,
			5,
			stem_color
		)

	return _finish_mesh(tool)


static func _create_coralline_algae() -> ArrayMesh:
	var material := FloraMaterialFactory.get_material(
		FloraIds.CORALLINE_ALGAE
	)

	var tool := _begin_mesh(material)

	var base_color := get_base_color(
		FloraIds.CORALLINE_ALGAE
	)

	_add_irregular_patch(
		tool,
		Vector3(-0.22, 0.022, 0.04),
		0.72,
		11,
		0.8,
		_shade(base_color, 0.88)
	)

	_add_irregular_patch(
		tool,
		Vector3(0.48, 0.032, -0.18),
		0.46,
		9,
		1.7,
		_shade(base_color, 1.06)
	)

	_add_irregular_patch(
		tool,
		Vector3(0.22, 0.042, 0.43),
		0.34,
		8,
		2.4,
		_shade(base_color, 0.76)
	)

	_add_irregular_patch(
		tool,
		Vector3(-0.54, 0.052, -0.35),
		0.28,
		7,
		0.25,
		_shade(base_color, 1.14)
	)

	for nodule_index in range(6):
		var angle := float(nodule_index) * TAU / 6.0

		var center := Vector3(
			cos(angle) * 0.43,
			0.045,
			sin(angle) * 0.43
		)

		_add_tapered_cylinder(
			tool,
			center,
			center + Vector3(0.0, 0.08, 0.0),
			0.075,
			0.035,
			6,
			_shade(
				base_color,
				0.82
				+ 0.055 * float(nodule_index)
			)
		)

	return _finish_mesh(tool)




static func _begin_mesh(
	material: Material
) -> SurfaceTool:
	var tool := SurfaceTool.new()

	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_material(material)

	return tool


static func _finish_mesh(
	tool: SurfaceTool
) -> ArrayMesh:
	var committed := tool.commit()

	return committed as ArrayMesh


static func _add_triangle(
	tool: SurfaceTool,
	point_a: Vector3,
	point_b: Vector3,
	point_c: Vector3,
	color: Color,
	uv_a: Vector2 = Vector2.ZERO,
	uv_b: Vector2 = Vector2.RIGHT,
	uv_c: Vector2 = Vector2.ONE
) -> void:
	var normal := (
		(point_b - point_a)
		.cross(point_c - point_a)
	)

	if normal.is_zero_approx():
		return

	normal = normal.normalized()

	_add_vertex(
		tool,
		point_a,
		normal,
		color,
		uv_a
	)

	_add_vertex(
		tool,
		point_b,
		normal,
		color,
		uv_b
	)

	_add_vertex(
		tool,
		point_c,
		normal,
		color,
		uv_c
	)


static func _add_quad(
	tool: SurfaceTool,
	point_a: Vector3,
	point_b: Vector3,
	point_c: Vector3,
	point_d: Vector3,
	color: Color
) -> void:
	_add_triangle(
		tool,
		point_a,
		point_b,
		point_c,
		color,
		Vector2(0.0, 0.0),
		Vector2(1.0, 0.0),
		Vector2(1.0, 1.0)
	)

	_add_triangle(
		tool,
		point_a,
		point_c,
		point_d,
		color,
		Vector2(0.0, 0.0),
		Vector2(1.0, 1.0),
		Vector2(0.0, 1.0)
	)


static func _add_vertex(
	tool: SurfaceTool,
	position: Vector3,
	normal: Vector3,
	color: Color,
	uv: Vector2
) -> void:
	tool.set_normal(normal)
	tool.set_color(color)
	tool.set_uv(uv)
	tool.add_vertex(position)


static func _add_tapered_cylinder(
	tool: SurfaceTool,
	start: Vector3,
	end: Vector3,
	start_radius: float,
	end_radius: float,
	sides: int,
	color: Color
) -> void:
	var axis := end - start

	if axis.is_zero_approx() or sides < 3:
		return

	var direction := axis.normalized()
	var reference_axis := Vector3.UP

	if absf(direction.dot(reference_axis)) > 0.94:
		reference_axis = Vector3.RIGHT

	var tangent := (
		direction.cross(reference_axis).normalized()
	)

	var bitangent := (
		direction.cross(tangent).normalized()
	)

	## Long stems need intermediate vertices so the sway shader can
	## produce curvature rather than moving only the top endpoint.
	var axial_segments := clampi(
		ceili(axis.length() / 0.42),
		1,
		24
	)

	for axial_index in range(axial_segments):
		var ratio_a := (
			float(axial_index)
			/ float(axial_segments)
		)

		var ratio_b := (
			float(axial_index + 1)
			/ float(axial_segments)
		)

		var center_a := start + axis * ratio_a
		var center_b := start + axis * ratio_b

		var radius_a := lerpf(
			start_radius,
			end_radius,
			ratio_a
		)

		var radius_b := lerpf(
			start_radius,
			end_radius,
			ratio_b
		)

		for side_index in range(sides):
			var next_index := (
				(side_index + 1) % sides
			)

			var angle_a := (
				float(side_index)
				* TAU / float(sides)
			)

			var angle_b := (
				float(next_index)
				* TAU / float(sides)
			)

			var radial_a := (
				tangent * cos(angle_a)
				+ bitangent * sin(angle_a)
			)

			var radial_b := (
				tangent * cos(angle_b)
				+ bitangent * sin(angle_b)
			)

			var lower_a := (
				center_a
				+ radial_a * radius_a
			)

			var lower_b := (
				center_a
				+ radial_b * radius_a
			)

			var upper_a := (
				center_b
				+ radial_a * radius_b
			)

			var upper_b := (
				center_b
				+ radial_b * radius_b
			)

			_add_quad(
				tool,
				lower_a,
				lower_b,
				upper_b,
				upper_a,
				color
			)


static func _add_blade(
	tool: SurfaceTool,
	base: Vector3,
	height: float,
	width: float,
	lean: float,
	angle: float,
	color: Color,
	segments: int
) -> void:
	if segments < 1:
		return

	var forward := Vector3(
		cos(angle),
		0.0,
		sin(angle)
	)

	var side := Vector3(
		-sin(angle),
		0.0,
		cos(angle)
	)

	for segment_index in range(segments):
		var ratio_a := (
			float(segment_index)
			/ float(segments)
		)

		var ratio_b := (
			float(segment_index + 1)
			/ float(segments)
		)

		var center_a := (
			base
			+ Vector3.UP * height * ratio_a
			+ forward
				* lean
				* ratio_a
				* ratio_a
		)

		var center_b := (
			base
			+ Vector3.UP * height * ratio_b
			+ forward
				* lean
				* ratio_b
				* ratio_b
		)

		var width_a := (
			width
			* maxf(
				0.035,
				1.0 - ratio_a * ratio_a
			)
		)

		var width_b := (
			width
			* maxf(
				0.035,
				1.0 - ratio_b * ratio_b
			)
		)

		_add_quad(
			tool,
			center_a - side * width_a,
			center_a + side * width_a,
			center_b + side * width_b,
			center_b - side * width_b,
			color
		)


static func _add_kelp_leaf(
	tool: SurfaceTool,
	base: Vector3,
	angle: float,
	length: float,
	width: float,
	color: Color
) -> void:
	var segments := 6

	var direction := Vector3(
		cos(angle),
		0.0,
		sin(angle)
	)

	var side := Vector3(
		-sin(angle),
		0.0,
		cos(angle)
	)

	for segment_index in range(segments):
		var ratio_a := (
			float(segment_index)
			/ float(segments)
		)

		var ratio_b := (
			float(segment_index + 1)
			/ float(segments)
		)

		var center_a := (
			base
			+ direction * length * ratio_a
			+ Vector3.UP
				* (
					0.12 * ratio_a
					+ 0.16 * sin(ratio_a * PI)
				)
			+ side
				* 0.05
				* sin(ratio_a * TAU)
		)

		var center_b := (
			base
			+ direction * length * ratio_b
			+ Vector3.UP
				* (
					0.12 * ratio_b
					+ 0.16 * sin(ratio_b * PI)
				)
			+ side
				* 0.05
				* sin(ratio_b * TAU)
		)

		var width_a := (
			width
			* maxf(
				0.04,
				sin(ratio_a * PI)
			)
		)

		var width_b := (
			width
			* maxf(
				0.04,
				sin(ratio_b * PI)
			)
		)

		_add_quad(
			tool,
			center_a - side * width_a,
			center_a + side * width_a,
			center_b + side * width_b,
			center_b - side * width_b,
			color
		)


static func _add_irregular_patch(
	tool: SurfaceTool,
	center: Vector3,
	radius: float,
	segments: int,
	phase: float,
	color: Color
) -> void:
	if segments < 3:
		return

	var points: Array[Vector3] = []

	for index in range(segments):
		var angle := (
			float(index) * TAU / float(segments)
			+ phase
		)

		var variation := (
			0.78
			+ 0.16 * sin(
				float(index) * 2.37
				+ phase
			)
			+ 0.07 * cos(
				float(index) * 3.11
				- phase
			)
		)

		points.append(
			center
			+ Vector3(
				cos(angle) * radius * variation,
				0.012 * sin(float(index) * 1.7),
				sin(angle) * radius * variation
			)
		)

	for index in range(segments):
		var next_index := (
			(index + 1) % segments
		)

		## Reversed ring order produces an upward-facing normal.
		_add_triangle(
			tool,
			center,
			points[next_index],
			points[index],
			color,
			Vector2(0.5, 0.5),
			Vector2(1.0, 1.0),
			Vector2(0.0, 1.0)
		)


static func _shade(
	color: Color,
	factor: float
) -> Color:
	return Color(
		clampf(color.r * factor, 0.0, 1.0),
		clampf(color.g * factor, 0.0, 1.0),
		clampf(color.b * factor, 0.0, 1.0),
		color.a
	)
