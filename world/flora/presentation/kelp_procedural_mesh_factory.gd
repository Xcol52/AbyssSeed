class_name KelpProceduralMeshFactory
extends RefCounted

const SEGMENT_HEIGHT: float = 0.60
const BASE_SEGMENT_COUNT: int = 6
const SEGMENTS_PER_TIER: int = 4

const MINIMUM_SIZE_FACTOR: float = 0.62
const MAXIMUM_SIZE_FACTOR: float = 1.65

static var _mesh_cache: Dictionary = {}


static func create_mesh(
	morphology_tier: int
) -> ArrayMesh:
	var tier := _validate_tier(morphology_tier)

	if _mesh_cache.has(tier):
		return _mesh_cache[tier] as ArrayMesh

	var mesh := _create_giant_kelp(tier)

	if mesh != null:
		mesh.resource_name = (
			"Giant Kelp Morphology Tier %d"
			% tier
		)

		_mesh_cache[tier] = mesh

	return mesh


static func clear_cache() -> void:
	_mesh_cache.clear()


static func get_segment_count(
	morphology_tier: int
) -> int:
	var tier := _validate_tier(morphology_tier)

	return (
		BASE_SEGMENT_COUNT
		+ tier * SEGMENTS_PER_TIER
	)


static func get_size_factor(
	morphology_tier: int
) -> float:
	var tier := _validate_tier(morphology_tier)

	var denominator := maxf(
		float(
			FloraPlacementCandidate
				.KELP_MORPHOLOGY_TIER_COUNT - 1
		),
		1.0
	)

	return lerpf(
		MINIMUM_SIZE_FACTOR,
		MAXIMUM_SIZE_FACTOR,
		float(tier) / denominator
	)


static func get_nominal_height(
	morphology_tier: int
) -> float:
	var segment_count := get_segment_count(
		morphology_tier
	)

	var size_factor := get_size_factor(
		morphology_tier
	)

	return (
		float(segment_count) * SEGMENT_HEIGHT
		+ 1.20 * size_factor
	)


static func _validate_tier(
	morphology_tier: int
) -> int:
	return clampi(
		morphology_tier,
		0,
		FloraPlacementCandidate
			.KELP_MORPHOLOGY_TIER_COUNT - 1
	)


static func _create_giant_kelp(
	morphology_tier: int
) -> ArrayMesh:
	var material := FloraMaterialFactory.get_material(
		FloraIds.GIANT_KELP,
		morphology_tier
	)

	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_material(material)

	var segment_count := get_segment_count(
		morphology_tier
	)

	var size_factor := get_size_factor(
		morphology_tier
	)

	var stalk_color := Color(
		0.18,
		0.29,
		0.065,
		1.0
	)

	var blade_color := Color(
		0.30,
		0.46,
		0.08,
		1.0
	)

	for segment_index in range(segment_count):
		var start := _get_stalk_point(
			segment_index
		)

		var end := _get_stalk_point(
			segment_index + 1
		)

		var height_ratio := (
			float(segment_index)
			/ maxf(float(segment_count), 1.0)
		)

		var start_radius := lerpf(
			0.115,
			0.056,
			height_ratio
		) * size_factor

		var end_radius := lerpf(
			0.115,
			0.056,
			float(segment_index + 1)
				/ maxf(float(segment_count), 1.0)
		) * size_factor

		_add_tapered_cylinder(
			tool,
			start,
			end,
			start_radius,
			end_radius,
			7,
			_shade(
				stalk_color,
				0.84 + height_ratio * 0.16
			)
		)

		if segment_index < 1:
			continue

		var angle := (
			float(segment_index) * 2.399963
			+ 0.35
		)

		var leaf_length := (
			1.08
			+ 0.10 * float(segment_index % 4)
		) * size_factor

		var leaf_width := (
			0.28
			+ 0.035 * float(segment_index % 3)
		) * size_factor

		var leaf_base := end + Vector3(
			0.0,
			-0.12,
			0.0
		)

		_add_kelp_leaf(
			tool,
			leaf_base,
			angle,
			leaf_length,
			leaf_width,
			_shade(
				blade_color,
				0.78
				+ 0.055
				* float(segment_index % 4)
			)
		)

	var crown_base := _get_stalk_point(
		segment_count
	)

	for crown_index in range(5):
		var crown_angle := (
			float(crown_index) * TAU / 5.0
			+ 0.25
		)

		_add_blade(
			tool,
			crown_base - Vector3(0.0, 0.12, 0.0),
			(
				1.04
				+ 0.13
				* float(crown_index % 2)
			) * size_factor,
			0.25 * size_factor,
			0.40 * size_factor,
			crown_angle,
			_shade(
				blade_color,
				0.90
				+ 0.035
				* float(crown_index)
			),
			5
		)

	return tool.commit() as ArrayMesh


## The centerline bends through additional fixed-length segments.
## No tier stretches an existing segment.
static func _get_stalk_point(
	point_index: int
) -> Vector3:
	var index_value := float(point_index)

	return Vector3(
		0.032 * sin(index_value * 0.58),
		index_value * SEGMENT_HEIGHT,
		0.027 * (
			cos(index_value * 0.47) - 1.0
		)
	)


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

	var axial_segments := clampi(
		ceili(axis.length() / 0.30),
		1,
		8
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
				center_a + radial_a * radius_a
			)

			var lower_b := (
				center_a + radial_b * radius_a
			)

			var upper_a := (
				center_b + radial_a * radius_b
			)

			var upper_b := (
				center_b + radial_b * radius_b
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
	const SEGMENTS: int = 6

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

	for segment_index in range(SEGMENTS):
		var ratio_a := (
			float(segment_index)
			/ float(SEGMENTS)
		)

		var ratio_b := (
			float(segment_index + 1)
			/ float(SEGMENTS)
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
		color
	)

	_add_triangle(
		tool,
		point_a,
		point_c,
		point_d,
		color
	)


static func _add_triangle(
	tool: SurfaceTool,
	point_a: Vector3,
	point_b: Vector3,
	point_c: Vector3,
	color: Color
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
		Vector2(0.0, 0.0)
	)

	_add_vertex(
		tool,
		point_b,
		normal,
		color,
		Vector2(1.0, 0.0)
	)

	_add_vertex(
		tool,
		point_c,
		normal,
		color,
		Vector2(1.0, 1.0)
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
