class_name FaunaProceduralMeshFactory
extends RefCounted

static var _mesh_cache: Dictionary = {}


static func create_mesh(
	species: FaunaSpeciesSnapshot,
	variant_index: int
) -> ArrayMesh:
	if species == null:
		return null

	var variant := clampi(
		variant_index,
		0,
		species.procedural_variant_count - 1
	)

	var key := Vector2i(
		species.species_id,
		variant
	)

	if _mesh_cache.has(key):
		return _mesh_cache[key] as ArrayMesh

	var mesh := _build_fish(
		species,
		variant
	)

	if mesh != null:
		mesh.resource_name = (
			"%s Procedural Variant %d"
			% [species.display_name, variant]
		)

		_mesh_cache[key] = mesh

	return mesh


static func clear_cache() -> void:
	_mesh_cache.clear()


static func _build_fish(
	species: FaunaSpeciesSnapshot,
	variant: int
) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var variant_ratio := (
		float(variant)
		/ maxf(
			float(species.procedural_variant_count - 1),
			1.0
		)
	)

	var length_factor := lerpf(
		0.90,
		1.10,
		variant_ratio
	)

	var depth_factor := (
		0.90
		+ 0.13 * float((variant + 1) % 3)
	)

	var width_factor := (
		0.88
		+ 0.12 * float((variant + 2) % 4)
	)

	var length := species.body_length * length_factor

	var width_ratio := 0.20
	var depth_ratio := 0.27

	match species.species_id:
		FaunaIds.SHELF_BAITFISH:
			width_ratio = 0.17
			depth_ratio = 0.24

		FaunaIds.KELP_GRAZER:
			width_ratio = 0.30
			depth_ratio = 0.42

		FaunaIds.REEF_HUNTER:
			width_ratio = 0.19
			depth_ratio = 0.27

	var half_width := (
		length * width_ratio * width_factor
	)

	var half_depth := (
		length * depth_ratio * depth_factor
	)

	var ring_z := PackedFloat32Array([
		-length * 0.50,
		-length * 0.32,
		0.0,
		length * 0.27,
		length * 0.43,
	])

	var ring_size := PackedFloat32Array([
		0.05,
		0.72,
		1.0,
		0.68,
		0.20,
	])

	const RING_SIDES: int = 8

	for ring_index in range(ring_z.size() - 1):
		var tail_weight_a := clampf(
			(
				ring_z[ring_index]
				/ length
				- 0.05
			) / 0.40,
			0.0,
			1.0
		)

		var tail_weight_b := clampf(
			(
				ring_z[ring_index + 1]
				/ length
				- 0.05
			) / 0.40,
			0.0,
			1.0
		)

		for side_index in range(RING_SIDES):
			var next_side := (
				(side_index + 1) % RING_SIDES
			)

			var angle_a := (
				float(side_index)
				* TAU / float(RING_SIDES)
			)

			var angle_b := (
				float(next_side)
				* TAU / float(RING_SIDES)
			)

			var point_00 := Vector3(
				cos(angle_a)
					* half_width
					* ring_size[ring_index],
				sin(angle_a)
					* half_depth
					* ring_size[ring_index],
				ring_z[ring_index]
			)

			var point_01 := Vector3(
				cos(angle_b)
					* half_width
					* ring_size[ring_index],
				sin(angle_b)
					* half_depth
					* ring_size[ring_index],
				ring_z[ring_index]
			)

			var point_10 := Vector3(
				cos(angle_a)
					* half_width
					* ring_size[ring_index + 1],
				sin(angle_a)
					* half_depth
					* ring_size[ring_index + 1],
				ring_z[ring_index + 1]
			)

			var point_11 := Vector3(
				cos(angle_b)
					* half_width
					* ring_size[ring_index + 1],
				sin(angle_b)
					* half_depth
					* ring_size[ring_index + 1],
				ring_z[ring_index + 1]
			)

			_add_triangle(
				tool,
				point_00,
				point_01,
				point_11,
				Color(1.0, 1.0, 1.0, tail_weight_a),
				Color(1.0, 1.0, 1.0, tail_weight_a),
				Color(1.0, 1.0, 1.0, tail_weight_b)
			)

			_add_triangle(
				tool,
				point_00,
				point_11,
				point_10,
				Color(1.0, 1.0, 1.0, tail_weight_a),
				Color(1.0, 1.0, 1.0, tail_weight_b),
				Color(1.0, 1.0, 1.0, tail_weight_b)
			)

	var tail_base_z := length * 0.42
	var tail_tip_z := length * 0.70

	## Vertical tail fin. The fish model faces negative Z.
	_add_triangle(
		tool,
		Vector3(0.0, 0.0, tail_base_z),
		Vector3(
			0.0,
			half_depth * 1.25,
			tail_tip_z
		),
		Vector3(
			0.0,
			-half_depth * 1.25,
			tail_tip_z
		),
		Color(0.88, 0.92, 1.0, 1.0),
		Color(0.88, 0.92, 1.0, 1.0),
		Color(0.88, 0.92, 1.0, 1.0)
	)

	## Dorsal fin.
	_add_triangle(
		tool,
		Vector3(
			0.0,
			half_depth * 0.72,
			-length * 0.08
		),
		Vector3(
			0.0,
			half_depth * 1.55,
			length * 0.12
		),
		Vector3(
			0.0,
			half_depth * 0.55,
			length * 0.24
		),
		Color(0.78, 0.84, 0.92, 0.20),
		Color(0.78, 0.84, 0.92, 0.45),
		Color(0.78, 0.84, 0.92, 0.72)
	)

	## Pectoral fins.
	_add_triangle(
		tool,
		Vector3(
			half_width * 0.48,
			0.0,
			-length * 0.15
		),
		Vector3(
			half_width * 1.55,
			-half_depth * 0.20,
			length * 0.05
		),
		Vector3(
			half_width * 0.42,
			-half_depth * 0.22,
			length * 0.15
		),
		Color(0.82, 0.88, 0.95, 0.08),
		Color(0.82, 0.88, 0.95, 0.40),
		Color(0.82, 0.88, 0.95, 0.50)
	)

	_add_triangle(
		tool,
		Vector3(
			-half_width * 0.48,
			0.0,
			-length * 0.15
		),
		Vector3(
			-half_width * 0.42,
			-half_depth * 0.22,
			length * 0.15
		),
		Vector3(
			-half_width * 1.55,
			-half_depth * 0.20,
			length * 0.05
		),
		Color(0.82, 0.88, 0.95, 0.08),
		Color(0.82, 0.88, 0.95, 0.50),
		Color(0.82, 0.88, 0.95, 0.40)
	)

	tool.generate_normals()

	return tool.commit() as ArrayMesh


static func _add_triangle(
	tool: SurfaceTool,
	point_a: Vector3,
	point_b: Vector3,
	point_c: Vector3,
	color_a: Color,
	color_b: Color,
	color_c: Color
) -> void:
	var normal := (
		(point_b - point_a)
		.cross(point_c - point_a)
	)

	if normal.is_zero_approx():
		return

	tool.set_color(color_a)
	tool.add_vertex(point_a)

	tool.set_color(color_b)
	tool.add_vertex(point_b)

	tool.set_color(color_c)
	tool.add_vertex(point_c)
