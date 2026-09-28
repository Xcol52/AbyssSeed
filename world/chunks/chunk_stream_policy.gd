class_name ChunkStreamPolicy
extends RefCounted


static func create_plan(
	observer_chunk: Vector2i,
	active_coordinates: Array[Vector2i],
	settings: ChunkStreamingSettings,
	horizontal_forward: Vector2
) -> ChunkStreamPlan:
	assert(settings != null)
	assert(settings.load_radius >= 0)
	assert(settings.unload_radius > settings.load_radius)

	var desired_coordinates := get_desired_coordinates(
		observer_chunk,
		settings.load_radius
	)

	var active_set: Dictionary = {}
	for coordinate in active_coordinates:
		active_set[coordinate] = true

	var missing_coordinates: Array[Vector2i] = []

	for coordinate in desired_coordinates:
		if not active_set.has(coordinate):
			missing_coordinates.append(coordinate)

	var unload_coordinates: Array[Vector2i] = []

	for coordinate in active_coordinates:
		if not is_within_radius(
			coordinate,
			observer_chunk,
			settings.unload_radius
		):
			unload_coordinates.append(coordinate)

	var ordered_generation_queue := order_for_generation(
		missing_coordinates,
		observer_chunk,
		horizontal_forward,
		settings.forward_priority_bias
	)

	return ChunkStreamPlan.new(
		desired_coordinates,
		ordered_generation_queue,
		unload_coordinates
	)


## Returns a complete square neighborhood. A radius of two produces 25
## coordinates.
static func get_desired_coordinates(
	center: Vector2i,
	radius: int
) -> Array[Vector2i]:
	assert(radius >= 0)

	var coordinates: Array[Vector2i] = []

	for offset_z in range(-radius, radius + 1):
		for offset_x in range(-radius, radius + 1):
			coordinates.append(
				Vector2i(
					center.x + offset_x,
					center.y + offset_z
				)
			)

	return coordinates


static func is_within_radius(
	coordinate: Vector2i,
	center: Vector2i,
	radius: int
) -> bool:
	assert(radius >= 0)

	return get_chunk_distance(coordinate, center) <= radius


## Chebyshev distance matches the square residency neighborhood.
static func get_chunk_distance(
	first: Vector2i,
	second: Vector2i
) -> int:
	var distance_x: int = abs(first.x - second.x)
	var distance_z: int = abs(first.y - second.y)

	if distance_x > distance_z:
		return distance_x

	return distance_z


## Returns a new, deterministically ordered array.
static func order_for_generation(
	coordinates: Array[Vector2i],
	observer_chunk: Vector2i,
	horizontal_forward: Vector2,
	forward_priority_bias: float
) -> Array[Vector2i]:
	assert(forward_priority_bias >= 0.0)
	assert(forward_priority_bias < 0.5)

	var normalized_forward := horizontal_forward

	if normalized_forward.is_zero_approx():
		normalized_forward = Vector2(0.0, -1.0)
	else:
		normalized_forward = normalized_forward.normalized()

	var ordered: Array[Vector2i] = []
	var seen: Dictionary = {}

	# The queues are deliberately small, so insertion sorting keeps the
	# comparison behavior explicit and deterministic.
	for coordinate in coordinates:
		if seen.has(coordinate):
			continue

		seen[coordinate] = true

		var insertion_index := ordered.size()

		for index in range(ordered.size()):
			if _comes_before(
				coordinate,
				ordered[index],
				observer_chunk,
				normalized_forward,
				forward_priority_bias
			):
				insertion_index = index
				break

		ordered.insert(insertion_index, coordinate)

	return ordered


static func _comes_before(
	first: Vector2i,
	second: Vector2i,
	observer_chunk: Vector2i,
	horizontal_forward: Vector2,
	forward_priority_bias: float
) -> bool:
	var first_score := _calculate_priority_score(
		first,
		observer_chunk,
		horizontal_forward,
		forward_priority_bias
	)
	var second_score := _calculate_priority_score(
		second,
		observer_chunk,
		horizontal_forward,
		forward_priority_bias
	)

	if not is_equal_approx(first_score, second_score):
		return first_score < second_score

	# Stable coordinate ordering resolves exact ties.
	if first.x != second.x:
		return first.x < second.x

	return first.y < second.y


static func _calculate_priority_score(
	coordinate: Vector2i,
	observer_chunk: Vector2i,
	horizontal_forward: Vector2,
	forward_priority_bias: float
) -> float:
	var offset := coordinate - observer_chunk
	var distance_squared := float(
		offset.x * offset.x + offset.y * offset.y
	)

	if distance_squared <= 0.0:
		return 0.0

	var direction := Vector2(
		float(offset.x),
		float(offset.y)
	).normalized()

	var forward_alignment := direction.dot(horizontal_forward)

	# Squared distance changes in whole-number increments. Because the
	# camera bias is below 0.5, it cannot make a farther chunk outrank
	# a nearer chunk.
	return (
		distance_squared
		- forward_alignment * forward_priority_bias
	)
