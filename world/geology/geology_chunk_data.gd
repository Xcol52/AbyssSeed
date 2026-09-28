class_name GeologyChunkData
extends RefCounted

const BOUNDARY_CLASS_INTERIOR: int = 0
const BOUNDARY_CLASS_DIVERGENT: int = 1
const BOUNDARY_CLASS_CONVERGENT: int = 2
const BOUNDARY_CLASS_TRANSFORM: int = 3

const TRENCH_TIER_NONE: int = 0
const TRENCH_TIER_ORDINARY: int = 1
const TRENCH_TIER_MAJOR: int = 2
const TRENCH_TIER_EXTREME: int = 3

var chunk_coordinate: Vector2i
var cells_per_axis: int
var cell_size: float
var world_origin: Vector2

var primary_plate_ids := PackedInt64Array()
var neighboring_plate_ids := PackedInt64Array()
var boundary_classes := PackedByteArray()

var continental_affinity := PackedFloat32Array()
var boundary_proximity := PackedFloat32Array()

var compression_strength := PackedFloat32Array()
var extension_strength := PackedFloat32Array()
var shear_strength := PackedFloat32Array()

var ridge_influence := PackedFloat32Array()
var rift_influence := PackedFloat32Array()

var ridge_potential := PackedFloat32Array()
var rift_potential := PackedFloat32Array()

var ridge_elevation_contribution := PackedFloat32Array()
var rift_elevation_contribution := PackedFloat32Array()

## Stage 3A plate-interior channels.
var plate_interior_influence := PackedFloat32Array()
var hill_elevation_contribution := PackedFloat32Array()
var terrace_elevation_contribution := PackedFloat32Array()
var massif_elevation_contribution := PackedFloat32Array()

var interior_depression_elevation_contribution := (
	PackedFloat32Array()
)

var combined_interior_elevation_contribution := (
	PackedFloat32Array()
)

var surface_headroom_scale := PackedFloat32Array()

## Stage 3B convergent channels.
var convergent_influence := PackedFloat32Array()
var convergent_potential := PackedFloat32Array()

var convergent_depression_elevation_contribution := (
	PackedFloat32Array()
)

var trench_influence := PackedFloat32Array()
var trench_potential := PackedFloat32Array()
var trench_tiers := PackedByteArray()
var trench_target_depth := PackedFloat32Array()
var trench_elevation_contribution := PackedFloat32Array()

var overriding_plate_ids := PackedInt64Array()
var sample_is_on_overriding_plate := PackedByteArray()

var overriding_uplift_influence := PackedFloat32Array()
var overriding_uplift_potential := PackedFloat32Array()

var overriding_uplift_elevation_contribution := (
	PackedFloat32Array()
)

## Stage 3C depth-province channels.
var shallow_province_influence := PackedFloat32Array()
var deep_province_influence := PackedFloat32Array()
var abyssal_province_influence := PackedFloat32Array()
var province_transition_influence := PackedFloat32Array()

var province_target_depth := PackedFloat32Array()

var province_elevation_contribution := (
	PackedFloat32Array()
)

var volcanic_potential := PackedFloat32Array()
var sediment_potential := PackedFloat32Array()

var macro_elevation := PackedFloat32Array()


func _init(
	generated_chunk_coordinate: Vector2i,
	generated_cells_per_axis: int,
	generated_cell_size: float,
	generated_world_origin: Vector2
) -> void:
	chunk_coordinate = generated_chunk_coordinate
	cells_per_axis = generated_cells_per_axis
	cell_size = generated_cell_size
	world_origin = generated_world_origin


func resize(sample_count: int) -> void:
	assert(sample_count > 0)

	primary_plate_ids.resize(sample_count)
	neighboring_plate_ids.resize(sample_count)
	boundary_classes.resize(sample_count)

	continental_affinity.resize(sample_count)
	boundary_proximity.resize(sample_count)

	compression_strength.resize(sample_count)
	extension_strength.resize(sample_count)
	shear_strength.resize(sample_count)

	ridge_influence.resize(sample_count)
	rift_influence.resize(sample_count)

	ridge_potential.resize(sample_count)
	rift_potential.resize(sample_count)

	ridge_elevation_contribution.resize(sample_count)
	rift_elevation_contribution.resize(sample_count)

	plate_interior_influence.resize(sample_count)
	hill_elevation_contribution.resize(sample_count)
	terrace_elevation_contribution.resize(sample_count)
	massif_elevation_contribution.resize(sample_count)

	interior_depression_elevation_contribution.resize(
		sample_count
	)

	combined_interior_elevation_contribution.resize(
		sample_count
	)

	surface_headroom_scale.resize(sample_count)

	convergent_influence.resize(sample_count)
	convergent_potential.resize(sample_count)

	convergent_depression_elevation_contribution.resize(
		sample_count
	)

	trench_influence.resize(sample_count)
	trench_potential.resize(sample_count)
	trench_tiers.resize(sample_count)
	trench_target_depth.resize(sample_count)
	trench_elevation_contribution.resize(sample_count)

	overriding_plate_ids.resize(sample_count)
	sample_is_on_overriding_plate.resize(sample_count)

	overriding_uplift_influence.resize(sample_count)
	overriding_uplift_potential.resize(sample_count)

	overriding_uplift_elevation_contribution.resize(
		sample_count
	)

	shallow_province_influence.resize(sample_count)
	deep_province_influence.resize(sample_count)
	abyssal_province_influence.resize(sample_count)

	province_transition_influence.resize(
		sample_count
	)

	province_target_depth.resize(sample_count)

	province_elevation_contribution.resize(
		sample_count
	)

	volcanic_potential.resize(sample_count)
	sediment_potential.resize(sample_count)

	macro_elevation.resize(sample_count)


func get_samples_per_axis() -> int:
	return cells_per_axis + 1


func get_sample_count() -> int:
	var samples_per_axis := get_samples_per_axis()

	return (
		samples_per_axis
		* samples_per_axis
	)


func get_index(
	local_sample_x: int,
	local_sample_z: int
) -> int:
	var samples_per_axis := get_samples_per_axis()

	assert(local_sample_x >= 0)
	assert(local_sample_z >= 0)
	assert(local_sample_x < samples_per_axis)
	assert(local_sample_z < samples_per_axis)

	return (
		local_sample_z * samples_per_axis
		+ local_sample_x
	)
