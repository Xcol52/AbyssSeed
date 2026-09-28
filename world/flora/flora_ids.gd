class_name FloraIds
extends RefCounted

const GIANT_KELP: int = 0
const SEAGRASS: int = 1
const REEF_MACROALGAE: int = 2
const RED_FAN_ALGAE: int = 3
const CORALLINE_ALGAE: int = 4

const COUNT: int = 5


static func get_display_name(
	species_id: int
) -> String:
	match species_id:
		GIANT_KELP:
			return "Giant kelp"

		SEAGRASS:
			return "Seagrass"

		REEF_MACROALGAE:
			return "Reef macroalgae"

		RED_FAN_ALGAE:
			return "Red fan algae"

		CORALLINE_ALGAE:
			return "Coralline algae"

		_:
			return "Unknown flora"
