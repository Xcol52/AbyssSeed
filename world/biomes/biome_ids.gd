class_name BiomeIds
extends RefCounted

const SUNLIT_SHELF: int = 0
const ROCKY_REEF: int = 1
const SANDY_SHELF: int = 2
const CONTINENTAL_SLOPE: int = 3
const DEEP_ROCKY_SLOPE: int = 4
const ABYSSAL_SEDIMENT_PLAIN: int = 5
const HYDROTHERMAL_FIELD: int = 6
const TRENCH_WALL: int = 7
const TRENCH_FLOOR: int = 8
const EXTREME_TRENCH_REFUGE: int = 9

const COUNT: int = 10


static func get_display_name(
	biome_id: int
) -> String:
	match biome_id:
		SUNLIT_SHELF:
			return "Sunlit shelf"

		ROCKY_REEF:
			return "Rocky reef"

		SANDY_SHELF:
			return "Sandy shelf"

		CONTINENTAL_SLOPE:
			return "Continental slope"

		DEEP_ROCKY_SLOPE:
			return "Deep rocky slope"

		ABYSSAL_SEDIMENT_PLAIN:
			return "Abyssal sediment plain"

		HYDROTHERMAL_FIELD:
			return "Hydrothermal field"

		TRENCH_WALL:
			return "Trench wall"

		TRENCH_FLOOR:
			return "Trench floor"

		EXTREME_TRENCH_REFUGE:
			return "Extreme-trench refuge"

		_:
			return "Unknown biome"
