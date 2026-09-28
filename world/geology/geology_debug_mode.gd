class_name GeologyDebugMode
extends RefCounted

const PLATE_ID: int = 0
const CONTINENTAL_AFFINITY: int = 1
const BOUNDARY_PROXIMITY: int = 2
const COMPRESSION: int = 3
const EXTENSION: int = 4
const SHEAR: int = 5
const RIDGE_POTENTIAL: int = 6
const TRENCH_POTENTIAL: int = 7
const VOLCANIC_POTENTIAL: int = 8
const SEDIMENT_POTENTIAL: int = 9
const MACRO_ELEVATION: int = 10

const COUNT: int = 11


static func get_mode_name(mode: int) -> String:
	match mode:
		PLATE_ID:
			return "Plate Identity"
		CONTINENTAL_AFFINITY:
			return "Continental Affinity"
		BOUNDARY_PROXIMITY:
			return "Boundary Proximity"
		COMPRESSION:
			return "Compression"
		EXTENSION:
			return "Extension"
		SHEAR:
			return "Shear"
		RIDGE_POTENTIAL:
			return "Ridge Potential"
		TRENCH_POTENTIAL:
			return "Trench Potential"
		VOLCANIC_POTENTIAL:
			return "Volcanic Potential"
		SEDIMENT_POTENTIAL:
			return "Sediment Potential"
		MACRO_ELEVATION:
			return "Macro Elevation"
		_:
			return "Unknown"
