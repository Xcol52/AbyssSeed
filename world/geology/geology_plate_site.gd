class_name GeologyPlateSite
extends RefCounted

var cell_coordinate: Vector2i
var plate_id: int
var position: Vector2
var motion: Vector2
var continental_affinity: float

## Signed power-diagram weight measured in squared world meters.
## Positive values tend to produce larger regions.
## Negative values tend to produce smaller regions.
var influence_weight: float


func _init(
	new_cell_coordinate: Vector2i,
	new_plate_id: int,
	new_position: Vector2,
	new_motion: Vector2,
	new_continental_affinity: float,
	new_influence_weight: float
) -> void:
	cell_coordinate = new_cell_coordinate
	plate_id = new_plate_id
	position = new_position
	motion = new_motion
	continental_affinity = new_continental_affinity
	influence_weight = new_influence_weight
