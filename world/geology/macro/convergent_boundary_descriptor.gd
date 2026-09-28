class_name ConvergentBoundaryDescriptor
extends RefCounted

## Cached deterministic properties for one canonical plate pair.

var lower_plate_id: int
var higher_plate_id: int

var overriding_plate_id: int
var trench_tier: int


func _init(
	new_lower_plate_id: int,
	new_higher_plate_id: int,
	new_overriding_plate_id: int,
	new_trench_tier: int
) -> void:
	lower_plate_id = new_lower_plate_id
	higher_plate_id = new_higher_plate_id
	overriding_plate_id = new_overriding_plate_id
	trench_tier = new_trench_tier
