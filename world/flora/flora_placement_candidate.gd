class_name FloraPlacementCandidate
extends RefCounted

## Immutable by convention after construction/finalization.

const KELP_MORPHOLOGY_TIER_COUNT: int = 6

var stable_id: int
var species_id: int

var candidate_cell: Vector2i

## Position and normal use procedural world space.
var world_position: Vector3
var surface_normal: Vector3

var yaw_radians: float
var uniform_scale: float

var suitability: float
var placement_probability: float
var patch_strength: float

var align_to_surface: bool

## Giant-kelp morphology data.
##
## These values are deterministic environmental results. They are not
## generated from stable-ID random rolls.
var kelp_nearby_count: int
var kelp_density_factor: float
var kelp_depth_factor: float
var kelp_darkness_factor: float
var kelp_growth_factor: float
var kelp_morphology_tier: int
var kelp_temperature_factor: float
var kelp_depth_below_surface: float


func _init(
	new_stable_id: int,
	new_species_id: int,
	new_candidate_cell: Vector2i,
	new_world_position: Vector3,
	new_surface_normal: Vector3,
	new_yaw_radians: float,
	new_uniform_scale: float,
	new_suitability: float,
	new_placement_probability: float,
	new_patch_strength: float,
	new_align_to_surface: bool,
	new_kelp_nearby_count: int = 0,
	new_kelp_density_factor: float = 0.0,
	new_kelp_depth_factor: float = 0.0,
	new_kelp_darkness_factor: float = 0.0,
	new_kelp_growth_factor: float = 0.0,
	new_kelp_morphology_tier: int = 0,
	new_kelp_temperature_factor: float = 0.0,
	new_kelp_depth_below_surface: float = 0.0
) -> void:
	stable_id = new_stable_id
	species_id = new_species_id

	candidate_cell = new_candidate_cell

	world_position = new_world_position
	surface_normal = new_surface_normal

	yaw_radians = new_yaw_radians
	uniform_scale = new_uniform_scale

	suitability = new_suitability
	placement_probability = new_placement_probability
	patch_strength = new_patch_strength

	align_to_surface = new_align_to_surface

	kelp_nearby_count = new_kelp_nearby_count
	kelp_density_factor = new_kelp_density_factor
	kelp_depth_factor = new_kelp_depth_factor
	kelp_darkness_factor = new_kelp_darkness_factor
	kelp_growth_factor = new_kelp_growth_factor
	kelp_morphology_tier = new_kelp_morphology_tier
	kelp_temperature_factor = new_kelp_temperature_factor
	kelp_depth_below_surface = new_kelp_depth_below_surface


func get_validation_error() -> String:
	if species_id < 0 or species_id >= FloraIds.COUNT:
		return "Flora candidate has an invalid species ID."

	if (
		not is_finite(world_position.x)
		or not is_finite(world_position.y)
		or not is_finite(world_position.z)
	):
		return "Flora candidate position must be finite."

	if (
		not is_finite(surface_normal.x)
		or not is_finite(surface_normal.y)
		or not is_finite(surface_normal.z)
	):
		return "Flora candidate surface normal must be finite."

	if surface_normal.is_zero_approx():
		return "Flora candidate surface normal cannot be zero."

	if surface_normal.y < 0.0:
		return "Flora candidate surface normal must face upward."

	if not is_equal_approx(
		surface_normal.length(),
		1.0
	):
		return "Flora candidate surface normal must be normalized."

	if not is_finite(yaw_radians):
		return "Flora candidate yaw must be finite."

	if (
		not is_finite(uniform_scale)
		or uniform_scale <= 0.0
	):
		return "Flora candidate scale must be positive."

	if (
		not is_finite(suitability)
		or suitability < 0.0
		or suitability > 1.0
	):
		return (
			"Flora candidate suitability must be "
			+ "between zero and one."
		)

	if (
		not is_finite(placement_probability)
		or placement_probability < 0.0
		or placement_probability > 1.0
	):
		return (
			"Flora candidate placement probability must be "
			+ "between zero and one."
		)

	if (
		not is_finite(patch_strength)
		or patch_strength < 0.0
		or patch_strength > 1.0
	):
		return (
			"Flora candidate patch strength must be "
			+ "between zero and one."
		)

	if kelp_nearby_count < 0:
		return "Kelp nearby count cannot be negative."

	var kelp_factors: Array[float] = [
		kelp_density_factor,
		kelp_depth_factor,
		kelp_darkness_factor,
		kelp_growth_factor,
		kelp_temperature_factor,
	]

	for factor in kelp_factors:
		if (
			not is_finite(factor)
			or factor < 0.0
			or factor > 1.0
		):
			return (
				"Kelp morphology factors must be finite "
				+ "and between zero and one."
			)

	if (
		not is_finite(kelp_depth_below_surface)
		or kelp_depth_below_surface < 0.0
	):
		return "Kelp depth below surface must be finite and non-negative."

	if (
		kelp_morphology_tier < 0
		or kelp_morphology_tier
			>= KELP_MORPHOLOGY_TIER_COUNT
	):
		return "Kelp morphology tier is outside its valid range."

	if species_id == FloraIds.GIANT_KELP:
		if not is_equal_approx(uniform_scale, 1.0):
			return (
				"Giant kelp must use unit instance scale. "
				+ "Its size belongs in its generated mesh."
			)

	return ""
