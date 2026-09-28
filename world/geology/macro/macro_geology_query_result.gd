class_name MacroGeologyQueryResult
extends RefCounted

enum BoundaryClass {
	INTERIOR = 0,
	DIVERGENT = 1,
	CONVERGENT = 2,
	TRANSFORM = 3,
}

var valid: bool = false
var error_message: String = ""

## The plate containing the queried point.
var primary_plate_id: int = 0

## The neighboring plate associated with the nearest boundary.
var neighboring_plate_id: int = 0

## Stable ordering independent of which side was queried.
var canonical_plate_a_id: int = 0
var canonical_plate_b_id: int = 0

var boundary_class: int = BoundaryClass.INTERIOR

## Unsigned geometric distance to the boundary.
var distance_to_boundary_meters: float = 0.0

## Negative on canonical plate A and positive on canonical plate B.
var signed_distance_to_boundary_meters: float = 0.0

## -1 on canonical plate A, +1 on canonical plate B, and 0 when
## there is no neighboring-plate relationship.
var canonical_side: int = 0

## Smooth 0–1 proximity field using a configured influence width.
var boundary_influence: float = 0.0

## Stable 0–1 art-direction scalar for this canonical plate pair.
## This is not a physical spreading rate or tectonic force.
var boundary_strength: float = 0.0


func has_boundary_relationship() -> bool:
	return (
		valid
		and primary_plate_id != neighboring_plate_id
		and boundary_class != BoundaryClass.INTERIOR
	)


func is_within_boundary_influence() -> bool:
	return (
		has_boundary_relationship()
		and boundary_influence > 0.0
	)


func get_boundary_class_name() -> String:
	return boundary_class_to_string(
		boundary_class
	)


static func boundary_class_to_string(
	boundary_class_value: int
) -> String:
	match boundary_class_value:
		BoundaryClass.INTERIOR:
			return "interior"

		BoundaryClass.DIVERGENT:
			return "divergent"

		BoundaryClass.CONVERGENT:
			return "convergent"

		BoundaryClass.TRANSFORM:
			return "transform"

		_:
			return "unknown"
