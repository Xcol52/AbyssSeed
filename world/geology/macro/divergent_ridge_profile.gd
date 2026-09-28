class_name DivergentRidgeProfile
extends RefCounted

const BOUNDARY_CLASS_INTERIOR: int = 0
const BOUNDARY_CLASS_DIVERGENT: int = 1
const BOUNDARY_CLASS_CONVERGENT: int = 2
const BOUNDARY_CLASS_TRANSFORM: int = 3

## Normal motion must be meaningful before a boundary is treated as
## divergent or convergent.
const MINIMUM_NORMAL_RATE: float = 0.05

## A normal component must be at least this fraction of the tangential
## component. Otherwise, the boundary is treated as transform-dominant.
const NORMAL_TO_SHEAR_RATIO: float = 0.65


static func classify_boundary(
	normal_rate: float,
	tangent_rate: float
) -> int:
	var compression_rate := clampf(
		maxf(normal_rate, 0.0),
		0.0,
		1.0
	)

	var extension_rate := clampf(
		maxf(-normal_rate, 0.0),
		0.0,
		1.0
	)

	var shear_rate := clampf(
		absf(tangent_rate),
		0.0,
		1.0
	)

	if (
		extension_rate >= MINIMUM_NORMAL_RATE
		and extension_rate
		>= shear_rate * NORMAL_TO_SHEAR_RATIO
	):
		return BOUNDARY_CLASS_DIVERGENT

	if (
		compression_rate >= MINIMUM_NORMAL_RATE
		and compression_rate
		>= shear_rate * NORMAL_TO_SHEAR_RATIO
	):
		return BOUNDARY_CLASS_CONVERGENT

	return BOUNDARY_CLASS_TRANSFORM


## A gameplay-oriented activity scalar.
##
## Square-root remapping makes moderate spreading visible without requiring
## unrealistically large elevation amplitudes.
static func calculate_activity(
	extension_rate: float,
	oceanic_pair: float,
	regional_multiplier: float
) -> float:
	if (
		not is_finite(extension_rate)
		or not is_finite(oceanic_pair)
		or not is_finite(regional_multiplier)
	):
		return 0.0

	var normalized_extension := clampf(
		extension_rate,
		0.0,
		1.0
	)

	var oceanic_eligibility := clampf(
		0.35 + oceanic_pair * 0.65,
		0.35,
		1.0
	)

	return clampf(
		sqrt(normalized_extension)
		* oceanic_eligibility
		* regional_multiplier,
		0.0,
		1.0
	)


## Smooth profile with:
##
## - 1.0 at the boundary
## - 0.5 at half-width
## - 0.0 at and beyond the configured width
static func calculate_influence(
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


static func calculate_ridge_contribution(
	ridge_potential: float,
	ridge_uplift_meters: float
) -> float:
	return (
		clampf(ridge_potential, 0.0, 1.0)
		* maxf(ridge_uplift_meters, 0.0)
	)


static func calculate_rift_contribution(
	rift_potential: float,
	rift_depth_meters: float
) -> float:
	return (
		-clampf(rift_potential, 0.0, 1.0)
		* maxf(rift_depth_meters, 0.0)
	)
