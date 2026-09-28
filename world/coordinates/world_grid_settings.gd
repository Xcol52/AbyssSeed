class_name WorldGridSettings
extends Resource

const MAX_CELLS_PER_AXIS: int = 512

@export_category("Chunk Grid")

## Width and depth of one logical chunk, in meters.
@export_range(1.0, 100000.0, 1.0)
var chunk_size: float = 256.0

## Number of terrain cells along each horizontal axis.
## Each mesh has cells_per_axis + 1 vertices per axis.
@export_range(1, 512, 1)
var cells_per_axis: int = 32


func get_cell_size() -> float:
	return chunk_size / float(cells_per_axis)


func validate() -> PackedStringArray:
	var errors := PackedStringArray()

	if not is_finite(chunk_size) or chunk_size <= 0.0:
		errors.append("chunk_size must be finite and greater than zero.")

	if cells_per_axis < 1:
		errors.append("cells_per_axis must be at least 1.")
	elif cells_per_axis > MAX_CELLS_PER_AXIS:
		errors.append(
			"cells_per_axis must not exceed %d."
			% MAX_CELLS_PER_AXIS
		)

	return errors
