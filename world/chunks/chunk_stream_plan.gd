class_name ChunkStreamPlan
extends RefCounted

## Coordinates required by the current load-radius policy.
var desired_coordinates: Array[Vector2i]

## Missing desired coordinates in generation-priority order.
var generation_queue: Array[Vector2i]

## Active coordinates that exceed the unload radius.
var unload_coordinates: Array[Vector2i]


func _init(
	planned_desired_coordinates: Array[Vector2i],
	planned_generation_queue: Array[Vector2i],
	planned_unload_coordinates: Array[Vector2i]
) -> void:
	desired_coordinates = planned_desired_coordinates
	generation_queue = planned_generation_queue
	unload_coordinates = planned_unload_coordinates
