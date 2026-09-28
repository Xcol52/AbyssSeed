class_name FaunaIds
extends RefCounted

const SHELF_BAITFISH: int = 0
const KELP_GRAZER: int = 1
const REEF_HUNTER: int = 2
const GIANT_SQUID: int = 3

const COUNT: int = 4


static func get_display_name(
	species_id: int
) -> String:
	match species_id:
		SHELF_BAITFISH:
			return "Shelf baitfish"

		KELP_GRAZER:
			return "Kelp grazer"

		REEF_HUNTER:
			return "Reef hunter"

		GIANT_SQUID:
			return "Giant squid"

		_:
			return "Unknown fauna"
