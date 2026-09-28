class_name MacroGeologyQuery
extends RefCounted

## Increment this only when the deterministic boundary relationship model
## intentionally changes.
const BOUNDARY_MODEL_VERSION: int = 1

## The initial model uses a deliberately simple art-directed distribution:
##
## - 36% divergent
## - 36% convergent
## - 28% transform
##
## These values classify canonical plate pairs. They do not simulate plate
## velocity or stress.
const DIVERGENT_CLASS_LIMIT: float = 0.36
const CONVERGENT_CLASS_LIMIT: float = 0.72

## Boundary strength varies within this range so every boundary remains
## recognizable while still avoiding uniform terrain formations.
const MINIMUM_BOUNDARY_STRENGTH: float = 0.60
const MAXIMUM_BOUNDARY_STRENGTH: float = 1.00

const U31_MASK: int = 0x7fffffff
const U31_MAXIMUM: float = 2147483647.0

const CLASS_HASH_SALT: int = 0x13579bdf
const STRENGTH_HASH_SALT: int = 0x02468ace


## Converts an existing plate relationship into the canonical macro-geology
## contract.
##
## The caller remains responsible for obtaining:
##
## - Primary plate ID
## - Neighboring plate ID
## - Geometric distance to their boundary
##
## This function does not perform another plate-site search.
static func sample_relationship(
	world_seed: int,
	primary_plate_id: int,
	neighboring_plate_id: int,
	distance_to_boundary_meters: float,
	boundary_influence_width_meters: float
) -> MacroGeologyQueryResult:
	var result := MacroGeologyQueryResult.new()

	result.primary_plate_id = primary_plate_id
	result.neighboring_plate_id = neighboring_plate_id

	result.distance_to_boundary_meters = (
		distance_to_boundary_meters
	)

	if not is_finite(distance_to_boundary_meters):
		result.error_message = (
			"Boundary distance must be finite."
		)
		return result

	if distance_to_boundary_meters < 0.0:
		result.error_message = (
			"Boundary distance cannot be negative."
		)
		return result

	if (
		not is_finite(boundary_influence_width_meters)
		or boundary_influence_width_meters <= 0.0
	):
		result.error_message = (
			"Boundary influence width must be "
			+ "positive and finite."
		)
		return result

	if primary_plate_id == neighboring_plate_id:
		result.valid = true

		result.canonical_plate_a_id = (
			primary_plate_id
		)

		result.canonical_plate_b_id = (
			primary_plate_id
		)

		result.boundary_class = (
			MacroGeologyQueryResult
			.BoundaryClass
			.INTERIOR
		)

		result.canonical_side = 0
		result.signed_distance_to_boundary_meters = 0.0
		result.boundary_influence = 0.0
		result.boundary_strength = 0.0

		return result

	result.canonical_plate_a_id = mini(
		primary_plate_id,
		neighboring_plate_id
	)

	result.canonical_plate_b_id = maxi(
		primary_plate_id,
		neighboring_plate_id
	)

	if primary_plate_id == result.canonical_plate_a_id:
		result.canonical_side = -1
	else:
		result.canonical_side = 1

	result.signed_distance_to_boundary_meters = (
		distance_to_boundary_meters
		* float(result.canonical_side)
	)

	var class_hash := _hash_boundary_pair(
		world_seed,
		result.canonical_plate_a_id,
		result.canonical_plate_b_id,
		CLASS_HASH_SALT
	)

	var class_roll := _hash_to_unit_float(
		class_hash
	)

	result.boundary_class = _classify_roll(
		class_roll
	)

	var strength_hash := _hash_boundary_pair(
		world_seed,
		result.canonical_plate_a_id,
		result.canonical_plate_b_id,
		STRENGTH_HASH_SALT
	)

	var strength_roll := _hash_to_unit_float(
		strength_hash
	)

	result.boundary_strength = lerpf(
		MINIMUM_BOUNDARY_STRENGTH,
		MAXIMUM_BOUNDARY_STRENGTH,
		strength_roll
	)

	result.boundary_influence = (
		calculate_smooth_influence(
			distance_to_boundary_meters,
			boundary_influence_width_meters
		)
	)

	result.valid = true
	return result


## Produces a smooth profile with:
##
## - 1.0 at the boundary center
## - 0.5 at half-width
## - 0.0 at or beyond the influence width
static func calculate_smooth_influence(
	distance_meters: float,
	influence_width_meters: float
) -> float:
	if (
		not is_finite(distance_meters)
		or not is_finite(influence_width_meters)
		or distance_meters < 0.0
		or influence_width_meters <= 0.0
	):
		return 0.0

	var linear_influence := clampf(
		1.0
		- distance_meters
		/ influence_width_meters,
		0.0,
		1.0
	)

	return (
		linear_influence
		* linear_influence
		* (3.0 - 2.0 * linear_influence)
	)


static func _classify_roll(
	normalized_roll: float
) -> int:
	if normalized_roll < DIVERGENT_CLASS_LIMIT:
		return (
			MacroGeologyQueryResult
			.BoundaryClass
			.DIVERGENT
		)

	if normalized_roll < CONVERGENT_CLASS_LIMIT:
		return (
			MacroGeologyQueryResult
			.BoundaryClass
			.CONVERGENT
		)

	return (
		MacroGeologyQueryResult
		.BoundaryClass
		.TRANSFORM
	)


static func _hash_boundary_pair(
	world_seed: int,
	canonical_plate_a_id: int,
	canonical_plate_b_id: int,
	hash_salt: int
) -> int:
	var mixed_value := _mix_u31(
		_fold_to_u31(world_seed)
		^ hash_salt
		^ BOUNDARY_MODEL_VERSION
	)

	mixed_value = _mix_u31(
		mixed_value
		^ _fold_to_u31(canonical_plate_a_id)
	)

	mixed_value = _mix_u31(
		mixed_value
		^ _fold_to_u31(canonical_plate_b_id)
	)

	return mixed_value


static func _fold_to_u31(
	value: int
) -> int:
	var lower_bits := value & U31_MASK

	var upper_bits := (
		(value >> 31)
		& U31_MASK
	)

	return (
		(lower_bits ^ upper_bits)
		& U31_MASK
	)


static func _mix_u31(
	value: int
) -> int:
	var mixed_value := value & U31_MASK

	mixed_value = (
		mixed_value
		^ (mixed_value >> 16)
	) & U31_MASK

	mixed_value = (
		mixed_value * 1103515245
		+ 12345
	) & U31_MASK

	mixed_value = (
		mixed_value
		^ (mixed_value >> 11)
	) & U31_MASK

	mixed_value = (
		mixed_value * 214013
		+ 2531011
	) & U31_MASK

	mixed_value = (
		mixed_value
		^ (mixed_value >> 15)
	) & U31_MASK

	return mixed_value


static func _hash_to_unit_float(
	hash_value: int
) -> float:
	return clampf(
		float(hash_value & U31_MASK)
		/ U31_MAXIMUM,
		0.0,
		1.0
	)
