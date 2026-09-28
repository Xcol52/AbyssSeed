class_name GiantSquidMeshFactory
extends RefCounted

const TOTAL_LENGTH_METERS: float = 50.0
const TENTACLE_LENGTH_METERS: float = 30.0

# A 5'6" player is approximately 1.6764 meters tall.
const EYE_DIAMETER_METERS: float = 1.6764
const EYE_RADIUS_METERS: float = EYE_DIAMETER_METERS * 0.5

const BODY_SURFACE_INDEX: int = 0
const TENTACLE_SURFACE_INDEX: int = 1
const EYE_SURFACE_INDEX: int = 2
const BEAK_SURFACE_INDEX: int = 3

const BODY_RING_SIDES: int = 12
const TENTACLE_COUNT: int = 10
const TENTACLE_SEGMENTS: int = 24
const TENTACLE_SIDES: int = 6

static var _mesh_cache: ArrayMesh


static func create_mesh() -> ArrayMesh:
	if _mesh_cache != null:
		return _mesh_cache

	var mesh: ArrayMesh = ArrayMesh.new()

	mesh.resource_name = "Giant Squid Fixed Apex Mesh"

	mesh = _append_body_surface(mesh)
	mesh = _append_tentacle_surface(mesh)
	mesh = _append_eye_surface(mesh)
	mesh = _append_beak_surface(mesh)

	_mesh_cache = mesh
	return _mesh_cache


static func clear_cache() -> void:
	_mesh_cache = null


static func get_total_length() -> float:
	return TOTAL_LENGTH_METERS


static func get_eye_diameter() -> float:
	return EYE_DIAMETER_METERS


static func get_tentacle_count() -> int:
	return TENTACLE_COUNT


static func _append_body_surface(
	mesh: ArrayMesh
) -> ArrayMesh:
	var tool: SurfaceTool = SurfaceTool.new()

	tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	tool.set_material(
		GiantSquidMaterialFactory.get_body_material()
	)

	var ring_z: PackedFloat32Array = PackedFloat32Array([
		-9.0,
		-7.0,
		-4.0,
		0.0,
		4.0,
		7.0,
		9.5,
		11.0,
	])

	var ring_radius_x: PackedFloat32Array = (
		PackedFloat32Array([
			2.2,
			4.0,
			5.1,
			5.5,
			4.9,
			3.9,
			2.2,
			0.45,
		])
	)

	var ring_radius_y: PackedFloat32Array = (
		PackedFloat32Array([
			1.8,
			3.4,
			4.2,
			4.5,
			4.0,
			3.1,
			1.8,
			0.35,
		])
	)

	for ring_index: int in range(ring_z.size() - 1):
		for side_index: int in range(BODY_RING_SIDES):
			var next_side: int = (
				(side_index + 1) % BODY_RING_SIDES
			)

			var angle_a: float = (
				float(side_index)
				* TAU
				/ float(BODY_RING_SIDES)
			)

			var angle_b: float = (
				float(next_side)
				* TAU
				/ float(BODY_RING_SIDES)
			)

			var point_00: Vector3 = Vector3(
				cos(angle_a)
					* ring_radius_x[ring_index],
				sin(angle_a)
					* ring_radius_y[ring_index],
				ring_z[ring_index]
			)

			var point_01: Vector3 = Vector3(
				cos(angle_b)
					* ring_radius_x[ring_index],
				sin(angle_b)
					* ring_radius_y[ring_index],
				ring_z[ring_index]
			)

			var point_10: Vector3 = Vector3(
				cos(angle_a)
					* ring_radius_x[ring_index + 1],
				sin(angle_a)
					* ring_radius_y[ring_index + 1],
				ring_z[ring_index + 1]
			)

			var point_11: Vector3 = Vector3(
				cos(angle_b)
					* ring_radius_x[ring_index + 1],
				sin(angle_b)
					* ring_radius_y[ring_index + 1],
				ring_z[ring_index + 1]
			)

			_add_quad(
				tool,
				point_00,
				point_01,
				point_11,
				point_10,
				Color.WHITE,
				Color.WHITE
			)

	# Arrowhead-like fins near the rear/top of the mantle.
	_add_triangle(
		tool,
		Vector3(0.0, 0.0, 6.5),
		Vector3(7.4, 0.0, 9.0),
		Vector3(0.0, 0.0, 12.0),
		Color.WHITE,
		Color.WHITE,
		Color.WHITE
	)

	_add_triangle(
		tool,
		Vector3(0.0, 0.0, 6.5),
		Vector3(0.0, 0.0, 12.0),
		Vector3(-7.4, 0.0, 9.0),
		Color.WHITE,
		Color.WHITE,
		Color.WHITE
	)

	tool.generate_normals()

	var committed_mesh: ArrayMesh = tool.commit(mesh)
	return committed_mesh


static func _append_tentacle_surface(
	mesh: ArrayMesh
) -> ArrayMesh:
	var tool: SurfaceTool = SurfaceTool.new()

	tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	tool.set_material(
		GiantSquidMaterialFactory.get_tentacle_material()
	)

	for tentacle_index: int in range(TENTACLE_COUNT):
		var phase_factor: float = (
			float(tentacle_index)
			/ float(TENTACLE_COUNT)
		)

		for segment_index: int in range(TENTACLE_SEGMENTS):
			var factor_a: float = (
				float(segment_index)
				/ float(TENTACLE_SEGMENTS)
			)

			var factor_b: float = (
				float(segment_index + 1)
				/ float(TENTACLE_SEGMENTS)
			)

			var center_a: Vector3 = _get_tentacle_point(
				tentacle_index,
				factor_a
			)

			var center_b: Vector3 = _get_tentacle_point(
				tentacle_index,
				factor_b
			)

			var tangent_a: Vector3 = _get_tentacle_tangent(
				tentacle_index,
				factor_a
			)

			var tangent_b: Vector3 = _get_tentacle_tangent(
				tentacle_index,
				factor_b
			)

			var radius_a: float = lerpf(
				0.72,
				0.16,
				factor_a
			)

			var radius_b: float = lerpf(
				0.72,
				0.16,
				factor_b
			)

			var color_a: Color = Color(
				phase_factor,
				factor_a,
				phase_factor,
				1.0
			)

			var color_b: Color = Color(
				phase_factor,
				factor_b,
				phase_factor,
				1.0
			)

			for side_index: int in range(TENTACLE_SIDES):
				var next_side: int = (
					(side_index + 1) % TENTACLE_SIDES
				)

				var angle_a: float = (
					float(side_index)
					* TAU
					/ float(TENTACLE_SIDES)
				)

				var angle_b: float = (
					float(next_side)
					* TAU
					/ float(TENTACLE_SIDES)
				)

				var point_00: Vector3 = (
					_get_tube_point(
						center_a,
						tangent_a,
						radius_a,
						angle_a
					)
				)

				var point_01: Vector3 = (
					_get_tube_point(
						center_a,
						tangent_a,
						radius_a,
						angle_b
					)
				)

				var point_10: Vector3 = (
					_get_tube_point(
						center_b,
						tangent_b,
						radius_b,
						angle_a
					)
				)

				var point_11: Vector3 = (
					_get_tube_point(
						center_b,
						tangent_b,
						radius_b,
						angle_b
					)
				)

				_add_quad(
					tool,
					point_00,
					point_01,
					point_11,
					point_10,
					color_a,
					color_b
				)

	tool.generate_normals()

	var committed_mesh: ArrayMesh = tool.commit(mesh)
	return committed_mesh


static func _append_eye_surface(
	mesh: ArrayMesh
) -> ArrayMesh:
	var tool: SurfaceTool = SurfaceTool.new()

	tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	tool.set_material(
		GiantSquidMaterialFactory.get_eye_material()
	)

	_add_low_poly_sphere(
		tool,
		Vector3(
			5.0,
			0.0,
			-3.2
		),
		EYE_RADIUS_METERS
	)

	_add_low_poly_sphere(
		tool,
		Vector3(
			-5.0,
			0.0,
			-3.2
		),
		EYE_RADIUS_METERS
	)

	tool.generate_normals()

	var committed_mesh: ArrayMesh = tool.commit(mesh)
	return committed_mesh


static func _append_beak_surface(
	mesh: ArrayMesh
) -> ArrayMesh:
	var tool: SurfaceTool = SurfaceTool.new()

	tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	tool.set_material(
		GiantSquidMaterialFactory.get_beak_material()
	)

	var vertex_color: Color = Color.WHITE

	# The beak sits at the center of the tentacle crown. Two opposing,
	# low-poly wedges produce a recognizable cephalopod beak without
	# introducing coplanar geometry or texture assets.
	var upper_left: Vector3 = Vector3(
		-0.78,
		0.12,
		-8.55
	)

	var upper_right: Vector3 = Vector3(
		0.78,
		0.12,
		-8.55
	)

	var upper_back: Vector3 = Vector3(
		0.0,
		0.94,
		-8.78
	)

	var upper_tip: Vector3 = Vector3(
		0.0,
		-0.04,
		-10.65
	)

	_add_tetrahedron(
		tool,
		upper_left,
		upper_right,
		upper_back,
		upper_tip,
		vertex_color
	)

	var lower_left: Vector3 = Vector3(
		-0.70,
		-0.12,
		-8.55
	)

	var lower_back: Vector3 = Vector3(
		0.0,
		-0.82,
		-8.75
	)

	var lower_right: Vector3 = Vector3(
		0.70,
		-0.12,
		-8.55
	)

	var lower_tip: Vector3 = Vector3(
		0.0,
		0.05,
		-10.35
	)

	_add_tetrahedron(
		tool,
		lower_left,
		lower_back,
		lower_right,
		lower_tip,
		vertex_color
	)

	tool.generate_normals()

	var committed_mesh: ArrayMesh = tool.commit(mesh)
	return committed_mesh


static func _add_tetrahedron(
	tool: SurfaceTool,
	point_a: Vector3,
	point_b: Vector3,
	point_c: Vector3,
	tip: Vector3,
	vertex_color: Color
) -> void:
	_add_triangle(
		tool,
		point_a,
		point_b,
		point_c,
		vertex_color,
		vertex_color,
		vertex_color
	)

	_add_triangle(
		tool,
		point_a,
		tip,
		point_b,
		vertex_color,
		vertex_color,
		vertex_color
	)

	_add_triangle(
		tool,
		point_b,
		tip,
		point_c,
		vertex_color,
		vertex_color,
		vertex_color
	)

	_add_triangle(
		tool,
		point_c,
		tip,
		point_a,
		vertex_color,
		vertex_color,
		vertex_color
	)


static func _get_tentacle_point(
	tentacle_index: int,
	factor: float
) -> Vector3:
	var base_angle: float = (
		float(tentacle_index)
		* TAU
		/ float(TENTACLE_COUNT)
	)

	var spread: float = (
		sin(factor * PI)
		* (
			4.0
			+ float(tentacle_index % 3) * 1.1
		)
	)

	var curl: float = (
		sin(
			factor * PI * 1.65
			+ base_angle * 1.7
		)
		* factor
		* 2.2
	)

	var radial_distance: float = 2.25 + spread

	return Vector3(
		cos(base_angle) * radial_distance
			+ cos(base_angle + PI * 0.5) * curl,
		sin(base_angle) * radial_distance * 0.72
			+ sin(factor * PI * 2.0 + base_angle)
				* factor
				* 1.4,
		-8.0 - TENTACLE_LENGTH_METERS * factor
	)


static func _get_tentacle_tangent(
	tentacle_index: int,
	factor: float
) -> Vector3:
	const DELTA: float = 0.002

	var previous_factor: float = maxf(
		factor - DELTA,
		0.0
	)

	var next_factor: float = minf(
		factor + DELTA,
		1.0
	)

	var previous_point: Vector3 = _get_tentacle_point(
		tentacle_index,
		previous_factor
	)

	var next_point: Vector3 = _get_tentacle_point(
		tentacle_index,
		next_factor
	)

	var tangent: Vector3 = next_point - previous_point

	if tangent.is_zero_approx():
		return Vector3.FORWARD

	return tangent.normalized()


static func _get_tube_point(
	center: Vector3,
	tangent: Vector3,
	radius: float,
	angle: float
) -> Vector3:
	var frame_reference: Vector3 = Vector3.UP

	if absf(tangent.dot(frame_reference)) > 0.92:
		frame_reference = Vector3.RIGHT

	var side: Vector3 = tangent.cross(
		frame_reference
	).normalized()

	var up: Vector3 = side.cross(
		tangent
	).normalized()

	return (
		center
		+ side * cos(angle) * radius
		+ up * sin(angle) * radius
	)


static func _add_low_poly_sphere(
	tool: SurfaceTool,
	center: Vector3,
	radius: float
) -> void:
	const LATITUDE_SEGMENTS: int = 6
	const LONGITUDE_SEGMENTS: int = 10

	for latitude_index: int in range(LATITUDE_SEGMENTS):
		var latitude_a: float = (
			-PI * 0.5
			+ PI
				* float(latitude_index)
				/ float(LATITUDE_SEGMENTS)
		)

		var latitude_b: float = (
			-PI * 0.5
			+ PI
				* float(latitude_index + 1)
				/ float(LATITUDE_SEGMENTS)
		)

		for longitude_index: int in range(
			LONGITUDE_SEGMENTS
		):
			var next_longitude: int = (
				(longitude_index + 1)
				% LONGITUDE_SEGMENTS
			)

			var longitude_a: float = (
				float(longitude_index)
				* TAU
				/ float(LONGITUDE_SEGMENTS)
			)

			var longitude_b: float = (
				float(next_longitude)
				* TAU
				/ float(LONGITUDE_SEGMENTS)
			)

			var point_00: Vector3 = (
				center
				+ _sphere_point(
					latitude_a,
					longitude_a
				) * radius
			)

			var point_01: Vector3 = (
				center
				+ _sphere_point(
					latitude_a,
					longitude_b
				) * radius
			)

			var point_10: Vector3 = (
				center
				+ _sphere_point(
					latitude_b,
					longitude_a
				) * radius
			)

			var point_11: Vector3 = (
				center
				+ _sphere_point(
					latitude_b,
					longitude_b
				) * radius
			)

			_add_quad(
				tool,
				point_00,
				point_01,
				point_11,
				point_10,
				Color.WHITE,
				Color.WHITE
			)


static func _sphere_point(
	latitude: float,
	longitude: float
) -> Vector3:
	var latitude_cosine: float = cos(latitude)

	return Vector3(
		latitude_cosine * cos(longitude),
		sin(latitude),
		latitude_cosine * sin(longitude)
	)


static func _add_quad(
	tool: SurfaceTool,
	point_00: Vector3,
	point_01: Vector3,
	point_11: Vector3,
	point_10: Vector3,
	color_a: Color,
	color_b: Color
) -> void:
	_add_triangle(
		tool,
		point_00,
		point_01,
		point_11,
		color_a,
		color_a,
		color_b
	)

	_add_triangle(
		tool,
		point_00,
		point_11,
		point_10,
		color_a,
		color_b,
		color_b
	)


static func _add_triangle(
	tool: SurfaceTool,
	point_a: Vector3,
	point_b: Vector3,
	point_c: Vector3,
	color_a: Color,
	color_b: Color,
	color_c: Color
) -> void:
	var cross_product: Vector3 = (
		(point_b - point_a).cross(
			point_c - point_a
		)
	)

	if cross_product.is_zero_approx():
		return

	tool.set_color(color_a)
	tool.add_vertex(point_a)

	tool.set_color(color_b)
	tool.add_vertex(point_b)

	tool.set_color(color_c)
	tool.add_vertex(point_c)
